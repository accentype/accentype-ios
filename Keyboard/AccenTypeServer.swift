//
//  AccenTypeServer.swift
//  AccenTypeComm
//
//  Created by Markus Cozowicz on 7/28/15.
//  Copyright (c) 2015 Markus Cozowicz. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import PriorityQueue
import CoreData

/**
    Communication backend to retrieve suggestions.
*/
@objc
public class AccenTypeServer: GCDAsyncUdpSocketDelegate {
    var server: String
    var port: CUnsignedShort
    var enableCache: Bool
    var requestTimeout: NSTimeInterval
    
    var requests: [UInt16: Request]
    var requestQueue: PriorityQueue<Request>

    var socket:GCDAsyncUdpSocket!
    var requestId: UInt16
    
    var managedContext: NSManagedObjectContext!

    /**
        Initializes AccenTypeServer.
    
        :param: server  The server used to retrieve suggestions.
        :param: port    The port used to communicate with server.
    */
    public init (server: String, port: CUnsignedShort, enableCache: Bool = true, requestTimeout: NSTimeInterval = 20) {
        self.server = server
        self.port = port
        self.enableCache = enableCache
        self.requestTimeout = requestTimeout
        self.requests = [UInt16: Request]()
        self.requestQueue = PriorityQueue<Request>({ $0.expirationDate.compare($1.expirationDate) == NSComparisonResult.OrderedAscending })
        self.requestId = 0;

        if (enableCache) {
            // setup local database
            let modelURL = NSBundle.mainBundle().URLForResource("AccenType", withExtension: "momd")
            let mom = NSManagedObjectModel(contentsOfURL: modelURL!)
           
            let options = [NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true]
            let psc = NSPersistentStoreCoordinator(managedObjectModel: mom!)
            var error: NSError? = nil

            let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
            let storeURL = (urls[urls.endIndex-1]).URLByAppendingPathComponent("AccenType")
            
            var store = psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: options, error: &error)
            if (store == nil) {
                println("Failed to load store")
            }
        
            self.managedContext = NSManagedObjectContext()
            managedContext.persistentStoreCoordinator = psc
        }
        else {
            self.managedContext = nil
        }
        
        setupConnection()
    }
    
    /**
        Setup UDP connection.
    */
    func setupConnection() {
        var error : NSError?
        self.socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        self.socket.connectToHost(self.server, onPort: self.port, error: &error)
        self.socket.beginReceiving(&error)
    }
    
    public convenience init(enableCache: Bool = true, requestTimeout: NSTimeInterval = 20) {
        // self.init(server: "accentype.cloudapp.net", port: 10100)
        self.init(server: "accentypeheader.cloudapp.net", port: 10100, enableCache: enableCache, requestTimeout: requestTimeout)
    }
    
    /**
        Number of outstanding requests.
    */
    var outstandingRequests : Int {
        get {
            return self.requests.count;
        }
    }
    
    /**
        Clears any timed out request.
    */
    func clearTimedOutRequests() {
        let now = NSDate()
        
        var oldest = self.requestQueue.peek()
        while (oldest != nil && now.compare(oldest!.expirationDate) == NSComparisonResult.OrderedDescending) {
            // println("removing " + String(oldest!.id))
            self.requestQueue.pop()
            self.requests.removeValueForKey(oldest!.id)
            oldest = self.requestQueue.peek()
        }
    }
    
    /**
        Convenience function to read from buffer.
    
        :param: data    The buffer to read from.
        :param: target  The variable to write to.
        :param: offset  The offset to read from. Gets updated on successful read.
        :param: length  Number of bytes to read. Defaults to sizeof(UInt8).
        :returns:       True if read was successful, false otherwise.
    */
    func read(data:NSData, target:UnsafeMutablePointer<Void>, inout offset:Int, length:Int = sizeof(UInt8)) -> Bool {
        if (offset + length > data.length) {
            return false;
        }
        
        data.getBytes(target, range: NSRange(location: offset, length: length))
        offset += length
        
        return true
    }
    
    /**
        Parses the server response.
    
        :param: data    The buffer to read parse from.
        :param: poffset The offset in the buffer to start.
        :returns:       The suggestion list.
    */
    func parseResponse(data: NSData, poffset: Int) -> [[String]]? {
        
        var offset = poffset
        
        var wordCount: UInt8 = 0
        if (!self.read(data, target: &wordCount, offset: &offset)) {
            return nil
        }
        
        var suggestionsPerWord = [[String]]()
        suggestionsPerWord.reserveCapacity(Int(wordCount))
        
        for var i = 0; i < Int(wordCount); i++ {
            
            var suggestionCount: UInt8 = 0
            if (!self.read(data, target: &suggestionCount, offset: &offset)) {
                return nil
            }
            
            var suggestions = [String]()
            suggestions.reserveCapacity(Int(suggestionCount))
            
            for var j = 0; j < Int(suggestionCount); j++ {
                var strlen: UInt8 = 0;
                if (!self.read(data, target: &strlen, offset: &offset)) {
                    return nil
                }
                
                if (offset + Int(strlen) > data.length) {
                    return nil
                }
                
                var suggestion = data.subdataWithRange(NSRange(location: offset, length: Int(strlen)))
                offset += Int(strlen)
                
                suggestions.append(NSString(data: suggestion, encoding: NSUTF8StringEncoding) as! String)
            }
            
            suggestionsPerWord.append(suggestions)
        }
        
        return suggestionsPerWord
    }
    
    /**
        Callback triggered by GCDAsyncUdpSocket. Guaranteed to run on GCD.
    */
    public func udpSocket(udpSocket: GCDAsyncUdpSocket!, didReceiveData data: NSData!, fromAddress: NSData!, withFilterContext: AnyObject!) {
        self.clearTimedOutRequests()
      
        if (udpSocket == nil || data == nil) {
            return;
        }
        
        // track offset within file
        var offset: Int = 0;
       
        // read client side request id
        var requestId: UInt16 = 0;
        if (!self.read(data, target: &requestId, offset: &offset, length: sizeof(UInt16))) {
            return;
        }
        
        // parse response
        var suggestionsPerWord = self.parseResponse(data, poffset: offset)
        if suggestionsPerWord == nil {
            return
        }
        
        // look for request
        var request = self.requests.removeValueForKey(requestId)
        if request == nil {
            return
        }
        
        // complete the request
        request!.completion(result: suggestionsPerWord!)
        
        if (!self.enableCache) {
            return
        }
        
        // store in DB
        let entity =  NSEntityDescription.entityForName("InputEntity", inManagedObjectContext: self.managedContext)
        
        let prediction = NSManagedObject(entity: entity!, insertIntoManagedObjectContext:managedContext)
        prediction.setValue(request!.input, forKey: "input")
        prediction.setValue(
            data.subdataWithRange(NSRange(location: sizeof(UInt16), length: data.length - sizeof(UInt16))),
            forKey: "prediction")
        prediction.setValue(NSDate(), forKey: "lastAccess")

        var error: NSError?
        if !self.managedContext.save(&error) {
            println("Could not save \(error), \(error?.userInfo)")
        }
    }
    
    /**
        Retrieves suggestions for each word in `text`. Words are splitted by space.

        :param: text        The text to get suggestions for.
        :param: completion  Callback triggered when server returns result (potentially never called)
    */
    func getSuggestion(text: String, completion: (result: [[String]]) -> Void) {
        // make sure there is no concurrent access
        dispatch_async(dispatch_get_main_queue()) {
            self.clearTimedOutRequests()
            
            if (self.enableCache) {
                // check local cache first
                let fetchRequest = NSFetchRequest(entityName:"InputEntity")

                let predicate = NSPredicate(format: "input == %@", text)
                fetchRequest.predicate = predicate
                
                var error: NSError?
                let fetchedResults = self.managedContext.executeFetchRequest(fetchRequest, error: &error) as? [NSManagedObject]
                
                if fetchedResults?.count > 0 {
                    // println("Found " + text + " in cache")
                    var data = fetchedResults![0].valueForKey("prediction") as! NSData
                    
                    var suggestionsPerWord = self.parseResponse(data, poffset: 0)
                    
                    completion(result: suggestionsPerWord!)
                    
                    return
                }
            }
            
            var localRequestId = self.requestId++

            // register request locally
            var request = Request(id: localRequestId, input: text, requestTimeout: self.requestTimeout, completion: completion)
        
            self.requests.updateValue(request, forKey: localRequestId)
            self.requestQueue.push(request)

            // build request
            let data = NSMutableData()
            data.appendBytes(&localRequestId, length: sizeof(Int16))
            data.appendData(text.dataUsingEncoding(NSASCIIStringEncoding)!)
            
            // send request to server
            self.socket.sendData(data, withTimeout: 1, tag: 0)
        }
    }

    /**
        Internal class to track outstanding requests.
    */
    class Request {
        var id: UInt16
        var completion: (result: [[String]]) -> Void
        var expirationDate: NSDate
        var input: String
        
        init (id: UInt16, input: String, requestTimeout:NSTimeInterval, completion: (result: [[String]]) -> Void) {
            self.id = id
            self.input = input
            self.completion = completion
            self.expirationDate = NSDate().dateByAddingTimeInterval(requestTimeout)
        }
    }
    
    /**
        Expands the suggestion list into individual sentences.
    
        :param: suggestions     The suggestions per word list.
        :returns:               Individual sentences.
    */
    static func expandSuggestions(suggestions:[[String]]) -> ExpandedSequence {
        return ExpandedSequence(suggestions)
    }
}

/** 
    Expanded sequence
*/
struct ExpandedSequence : SequenceType {
    typealias Generator = GeneratorOf<String>
    var array:[[String]]
    
    init(_ array:[[String]]) {
        self.array = array
    }
    
    func generate() -> GeneratorOf<String> {
        var indices = [Int](count: self.array.count, repeatedValue:0)
        var endReached = false
        
        return GeneratorOf<String> {
            if (endReached) {
                return nil
            }
            
            let words = map(enumerate(self.array)) {
                (index, element) in
                return element[indices[index]]
            }
            
            var result = " ".join(words)
            
            var index = indices.count - 1;
            while (index >= 0)
            {
                indices[index]++
                if (indices[index] < self.array[index].count)
                {
                    return result
                }
                
                indices[index] = 0
                index--
            }
            
            endReached = true
            return result
        }

    }
}
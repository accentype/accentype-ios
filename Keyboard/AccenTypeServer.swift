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

/**
    Communication backend to retrieve suggestions.
*/
@objc
public class AccenTypeServer: GCDAsyncUdpSocketDelegate {
    var server: String;
    var port: CUnsignedShort;
    
    var requests: [UInt16: Request];
    var requestQueue: PriorityQueue<Request>;

    var socket:GCDAsyncUdpSocket!;
    var requestId: UInt16;

    /**
        Initializes AccenTypeServer.
    
        :param: server  The server used to retrieve suggestions.
        :param: port    The port used to communicate with server.
    */
    public init (server: String, port: CUnsignedShort) {
        self.server = server
        self.port = port
        self.requests = [UInt16: Request]()
        self.requestQueue = PriorityQueue<Request>({ $0.expirationDate.compare($1.expirationDate) == NSComparisonResult.OrderedAscending })
        self.requestId = 0;
        
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
    
    public convenience init() {
        // self.init(server: "accentype.cloudapp.net", port: 10100)
        self.init(server: "accentypeheader.cloudapp.net", port: 10100)
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
        Callback triggered by GCDAsyncUdpSocket. Guaranteed to run on GCD.
    */
    public func udpSocket(udpSocket: GCDAsyncUdpSocket!, didReceiveData data: NSData!, fromAddress: NSData!, withFilterContext: AnyObject!) {
        self.clearTimedOutRequests()
      
        if (udpSocket == nil || data == nil) {
            return;
        }
        
        var offset: Int = 0;
       
        var requestId: UInt16 = 0;
        if (!self.read(data, target: &requestId, offset: &offset, length: sizeof(UInt16))) {
            return;
        }
        
        var wordCount: UInt8 = 0;
        if (!self.read(data, target: &wordCount, offset: &offset)) {
            return;
        }
        
        var suggestionsPerWord = [[String]]();
        suggestionsPerWord.reserveCapacity(Int(wordCount))
        
        for var i = 0; i < Int(wordCount); i++ {
            
            var suggestionCount: UInt8 = 0;
            if (!self.read(data, target: &suggestionCount, offset: &offset)) {
                return;
            }
            
            var suggestions = [String]()
            suggestions.reserveCapacity(Int(suggestionCount))
            
            for var j = 0; j < Int(suggestionCount); j++ {
                var strlen: UInt8 = 0;
                if (!self.read(data, target: &strlen, offset: &offset)) {
                    return;
                }
            
                if (offset + Int(strlen) > data.length) {
                    return;
                }
                
                var suggestion = data.subdataWithRange(NSRange(location: offset, length: Int(strlen)))
                offset += Int(strlen)
            
                suggestions.append(NSString(data: suggestion, encoding: NSUTF8StringEncoding) as! String)
            }
            
            suggestionsPerWord.append(suggestions)
        }
        
        var request = self.requests.removeValueForKey(requestId)
        request?.completion(result: suggestionsPerWord)
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
            
            var localRequestId = self.requestId++

            let data = NSMutableData()
            data.appendBytes(&localRequestId, length: sizeof(Int16))
            data.appendData(text.dataUsingEncoding(NSASCIIStringEncoding)!)
        
            self.socket.sendData(data, withTimeout: 1, tag: 0)
        
            var request = Request(id: localRequestId, completion: completion)
        
            self.requests.updateValue(request, forKey: localRequestId)
            self.requestQueue.push(request)
        }
    }

    /**
        Internal class to track outstanding requests.
    */
    class Request {
        var id: UInt16;
        var completion: (result: [[String]]) -> Void;
        var expirationDate: NSDate;
        
        init (id: UInt16, completion: (result: [[String]]) -> Void) {
            self.id = id
            self.completion = completion
            self.expirationDate = NSDate().dateByAddingTimeInterval(5)
        }
    }
}


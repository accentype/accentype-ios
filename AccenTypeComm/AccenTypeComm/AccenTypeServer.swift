//
//  AccenTypeServer.swift
//  AccenTypeComm
//
//  Created by Markus Cozowicz on 7/28/15.
//  Copyright (c) 2015 Markus Cozowicz. All rights reserved.
//

import Foundation

@objc
class AccenTypeServer: GCDAsyncUdpSocketDelegate {
    var server: String;
    var port: CUnsignedShort;
    
    var requests: [UInt16: Request];
    var requestQueue: PriorityQueue<Request>;

    var socket:GCDAsyncUdpSocket!;
    var requestId: UInt16;

    init (server: String, port: CUnsignedShort) {
        self.server = server
        self.port = port
        self.requests = [UInt16: Request]()
        self.requestQueue = PriorityQueue<Request>({ $0.expirationDate.compare($1.expirationDate) == NSComparisonResult.OrderedAscending })
        self.requestId = 0;
        
        setupConnection()
    }
    
    func setupConnection() {
        var error : NSError?
        self.socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        self.socket.connectToHost(self.server, onPort: self.port, error: &error)
        self.socket.beginReceiving(&error)
    }
    
    convenience init() {
        // self.init(server: "accentype.cloudapp.net", port: 10100)
        self.init(server: "accentypeheader.cloudapp.net", port: 10100)
    }
    
    func clearTimedOut() {
        let now = NSDate()
        
        var oldest = self.requestQueue.peek()
        while (oldest != nil && now.compare(oldest!.expirationDate) == NSComparisonResult.OrderedDescending) {
            self.requestQueue.pop()
            self.requests.removeValueForKey(oldest!.id)
            oldest = self.requestQueue.peek()
        }
    }
    
    func read(data:NSData, target:UnsafeMutablePointer<Void>, inout offset:Int, length:Int = sizeof(UInt8)) -> Bool {
        if (offset + length > data.length) {
            return false;
        }
        
        data.getBytes(target, range: NSRange(location: offset, length: length))
        offset += length
        
        return true
    }
    
    func udpSocket(udpSocket: GCDAsyncUdpSocket!, didReceiveData data: NSData!, fromAddress: NSData!, withFilterContext: AnyObject!) {
        self.clearTimedOut()
        
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
    
    func getSuggestion(word: String, completion: (result: [[String]]) -> Void) {
        // make sure there is no concurrent access
        dispatch_async(dispatch_get_main_queue()) {
            self.clearTimedOut()
            
            var localRequestId = self.requestId++

            let data = NSMutableData()
            data.appendBytes(&localRequestId, length: sizeof(Int16))
            data.appendData(word.dataUsingEncoding(NSASCIIStringEncoding)!)
        
            self.socket.sendData(data, withTimeout: 1, tag: 0)
        
            var request = Request(id: localRequestId, completion: completion)
        
            self.requests.updateValue(request, forKey: localRequestId)
            self.requestQueue.push(request)
        }
    }

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


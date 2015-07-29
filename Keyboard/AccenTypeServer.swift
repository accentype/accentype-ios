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
    
    var requests: [Int16: Request];
    var requestQueue: PriorityQueue<Request>;

    var socket:GCDAsyncUdpSocket!;
    var requestId: Int16;

    init (server: String, port: CUnsignedShort) {
        self.server = server
        self.port = port
        self.requests = [Int16: Request]()
        self.requestQueue = PriorityQueue<Request>({ $0.creationDate.compare($1.creationDate) == NSComparisonResult.OrderedAscending })
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
    
    func udpSocket(udpSocket: GCDAsyncUdpSocket!, didReceiveData data: NSData!, fromAddress: NSData!, withFilterContext: AnyObject!) {

        var offset: Int = 0;
       
        var requestId: Int16 = 0;
        data.getBytes(&requestId, range: NSRange(location: offset, length: sizeof(Int16)))
        offset += sizeof(Int16)
        
        var wordCount: Int8 = 0;
            
        data.getBytes(&wordCount, range: NSRange(location: offset,length: sizeof(Int8)))
        offset += sizeof(Int8)
        
        var suggestionsPerWord = [[String]]();
        suggestionsPerWord.reserveCapacity(Int(wordCount))
        
        for var i = 0; i < Int(wordCount); i++ {
            
            var suggestionCount: Int8 = 0;
            
            data.getBytes(&suggestionCount, range: NSRange(location: offset,length: sizeof(Int8)))
            offset += sizeof(Int8)
            
            var suggestions = [String]()
            suggestions.reserveCapacity(Int(suggestionCount))
            
            for var j = 0; j < Int(suggestionCount); j++ {
                var strlen: Int8 = 0;
                data.getBytes(&strlen, range: NSRange(location: offset, length: sizeof(Int8)))
                offset += sizeof(Int8)
            
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
        dispatch_async(dispatch_get_main_queue()) {
            var localRequestId = self.requestId++

            let data = NSMutableData()
            data.appendBytes(&localRequestId, length: sizeof(Int16))
            data.appendData(word.dataUsingEncoding(NSASCIIStringEncoding)!)
        
            self.socket.sendData(data, withTimeout: 1, tag: 0)
        
            var request = Request(id: localRequestId, completion: completion)
        
            self.requests.updateValue(request, forKey: localRequestId)
            // TODO: manage for time out
            // self.requestQueue.push(request)
        }
    }

    class Request {
        var id: Int16;
        var completion: (result: [[String]]) -> Void;
        
        // http://www.globalnerdy.com/2015/01/26/how-to-work-with-dates-and-times-in-swift-part-one/
        var creationDate = NSDate();
        
        init (id: Int16, completion: (result: [[String]]) -> Void) {
            self.id = id
            self.completion = completion
        }
    }
}


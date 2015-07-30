//
//  Accentype_Tests.swift
//  Accentype Tests
//
//  Created by Markus Cozowicz on 7/29/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import XCTest

class Accentype_Tests: XCTestCase {
    
    func testSuggestion() {
        self.measureBlock() {
            var expectation = self.expectationWithDescription("Suggestion response")
            
            // This is an example of a functional test case.
            var server = AccenTypeServer(enableCache: false)
            
            server.getSuggestion("xin chao") {
                (var suggestionsPerWord) in
                
                XCTAssertGreaterThan(suggestionsPerWord.count, 0);
                XCTAssertGreaterThan(suggestionsPerWord[0].count, 0);
                
                expectation.fulfill()
             }
            
            self.waitForExpectationsWithTimeout(5, handler: nil)
        }
    }
    
    func testSuggestionMultiple() {
        var server = AccenTypeServer(enableCache: false)
        
        for i in 1...10 {
            var expectationXin = self.expectationWithDescription("Suggestion response: xin")
            
            server.getSuggestion("xin chao") {
                (var suggestionsPerWord) in
            
                XCTAssertGreaterThan(suggestionsPerWord.count, 0);
                XCTAssertGreaterThan(suggestionsPerWord[0].count, 0);
                
                XCTAssertEqual(suggestionsPerWord[0][0], "xin")
                
                expectationXin.fulfill()
            }
            
            var expectationThe = self.expectationWithDescription("Suggestion response: the")
            server.getSuggestion("the la sao") {
                (var suggestionsPerWord) in
                
                XCTAssertGreaterThan(suggestionsPerWord.count, 0);
                XCTAssertGreaterThan(suggestionsPerWord[0].count, 0);
                
                XCTAssertNotEqual(suggestionsPerWord[0][0], "xin")
                
                expectationThe.fulfill()
            }
        }
        
        self.waitForExpectationsWithTimeout(15, handler: nil)
    }
    
    func delay(delay:Double, closure:()->()) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay * Double(NSEC_PER_SEC))
            ),
            dispatch_get_main_queue(), closure)
    }
    
    func testSuggestionTimeout() {
        var server = AccenTypeServer(server: "nonexisting.com", port: 123, enableCache: false, requestTimeout: 5)
        
        var expectation = self.expectationWithDescription("Suggestion response")
        
        XCTAssertEqual(server.outstandingRequests, 0)
        
        server.getSuggestion("xin chao") {
            (var suggestionsPerWord) in
            
            XCTFail("should never return")
        }
        
        delay(1) {
            XCTAssertEqual(server.outstandingRequests, 1)
        }
        
        delay(7) {
            server.getSuggestion("the") {
                (var suggestionsPerWord) in
                
                XCTFail("should never return")
            }
        }
        
        delay (8) {
            XCTAssertEqual(server.outstandingRequests, 1)
            
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testSuggestionExpansion() {
        let input = [["a", "b"],["x"], ["1","2","3"]];
        var expected = ["a x 1", "a x 2", "a x 3", "b x 1", "b x 2", "b x 3"]
        var actual = AccenTypeServer.expandSuggestions(input)
        
        var count = 0
        for w in actual {
            XCTAssertEqual(w, expected[count])
            count++
        }

        XCTAssertEqual(count, 6)
    }
    
    func testCaching() {
        var expectation1 = self.expectationWithDescription("Suggestion response")
        var expectation2 = self.expectationWithDescription("Suggestion response")
        
        // This is an example of a functional test case.
        var server1 = AccenTypeServer()
        
        server1.getSuggestion("xin chao") {
            (var suggestionsPerWord) in
            
            XCTAssertGreaterThan(suggestionsPerWord.count, 0);
            XCTAssertGreaterThan(suggestionsPerWord[0].count, 0);
            
            expectation1.fulfill()
        }
        
        var server2 = AccenTypeServer(server: "nonexisting.com", port: 123, enableCache: true)
        delay(1) {
            server1.getSuggestion("xin chao") {
                (var suggestionsPerWord) in
                
                XCTAssertGreaterThan(suggestionsPerWord.count, 0);
                XCTAssertGreaterThan(suggestionsPerWord[0].count, 0);
                
                expectation2.fulfill()
            }
        }
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
        
    }
}

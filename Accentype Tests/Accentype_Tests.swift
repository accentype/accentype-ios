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
            var server = AccenTypeServer()
            
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
        var server = AccenTypeServer()
        
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
        var server = AccenTypeServer(server: "nonexisting.com", port: 123);
        
        var expectation = self.expectationWithDescription("Suggestion response")
        
        XCTAssertEqual(server.outstandingRequests, 0)
        
        server.getSuggestion("xin chao") {
            (var suggestionsPerWord) in
            
            XCTFail("should never return")
        }
        
        delay(1) {
            XCTAssertEqual(server.outstandingRequests, 1)
        }
        
        delay(8) {
            server.getSuggestion("the") {
                (var suggestionsPerWord) in
                
                XCTFail("should never return")
            }
        
            XCTAssertEqual(server.outstandingRequests, 1)
            
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(15, handler: nil)
    }
}

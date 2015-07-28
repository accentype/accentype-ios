//
//  ViewController.swift
//  AccenTypeComm
//
//  Created by Markus Cozowicz on 7/28/15.
//  Copyright (c) 2015 Markus Cozowicz. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var server: AccenTypeServer!;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        println("Markus")
        
        // Override point for customization after application launch.
        self.server = AccenTypeServer()
        
        // thế là sao
        // xin chao
        self.server.getSuggestion("the la sao") {
            (var suggestionsPerWord) in
            
            for suggestions in suggestionsPerWord {
                println("answer: " + (",".join(suggestions)))
            }
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}


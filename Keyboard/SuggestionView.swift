//
//  SuggestionView.swift
//  TastyImitationKeyboard
//
//  Created by Chenkai Liu on 7/28/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit

protocol SuggestionStringUpdateDelegate
{
    func updateString(updateString: String)
}

class SuggestionView: BannerViewCollectionView {

    // Constants
    let suggestionMargin = CGFloat(10)
    let maxSuggestionCount = 10
    var suggestions = [String]()
    
    // Variables
    var keyboardDelegate : SuggestionStringUpdateDelegate?
    var server = AccenTypeServer()

    required init(globalColors: GlobalColors.Type?, darkMode: Bool, solidColorMode: Bool) {
        super.init(globalColors: globalColors, darkMode: darkMode, solidColorMode: solidColorMode)
        self.setObserversForNotifications()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setNeedsLayout() {
        super.setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }

    func setObserversForNotifications() -> Void {
        
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "inputUpdated:",
            name: notification_inputChanged,
            object: nil)
        
        
    }
    
    func setupSuggestions(suggestions : [String])
    {
        // Remove all subviews alls
        self.subviews.map({ $0.removeFromSuperview() })
        self.suggestions = suggestions
        
        var currentXOrigin = CGFloat(0)
        
        for var index = 0; index < suggestions.count; index++
        {
            var wordsuggest = suggestions[index];
            
            // Set title to word suggestion
            let button   = UIButton.buttonWithType(UIButtonType.System) as! UIButton
            button.setTitle(wordsuggest, forState: UIControlState.Normal)
            button.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
            button.setTitleColor(UIColor.blackColor(), forState: UIControlState.Highlighted)
            button.titleLabel?.font = UIFont.systemFontOfSize(18)
            button.tag = index
            button.backgroundColor = UIColor(red: CGFloat(173)/CGFloat(255), green: CGFloat(180)/CGFloat(255), blue: CGFloat(190)/CGFloat(255), alpha: 1.0)
            
            // Set the size of the selection to what's required
            var buttonSize : CGSize = button.sizeThatFits(CGSizeMake(CGFloat.max, self.frame.height))
            buttonSize.width += suggestionMargin
            button.frame = CGRectMake(currentXOrigin, CGFloat(0), CGFloat(buttonSize.width), self.frame.height)
            currentXOrigin += buttonSize.width
            
            // Add right border to button
            var borderLayer = CALayer()
            borderLayer.frame = CGRectMake(button.frame.width - 1, button.frame.origin.y, CGFloat(1), button.frame.height)
            borderLayer.backgroundColor = UIColor(red: CGFloat(213)/CGFloat(255), green: CGFloat(216)/CGFloat(255), blue: CGFloat(225)/CGFloat(255), alpha: 1.0).CGColor
            button.layer.addSublayer(borderLayer)
            
            button.addTarget(self, action: "suggestionPressed:", forControlEvents: UIControlEvents.TouchUpInside)
            button.addTarget(self, action: "suggestionTouchDown:", forControlEvents: UIControlEvents.TouchDown)
            button.addTarget(self, action: "resetSuggestionViewColor:", forControlEvents: UIControlEvents.TouchUpOutside)
            button.addTarget(self, action: "resetSuggestionViewColor:", forControlEvents: UIControlEvents.TouchDragExit)
            button.addTarget(self, action: "resetSuggestionViewColor:", forControlEvents: UIControlEvents.TouchCancel)
            
            self.addSubview(button)
        }
        
        self.contentSize = CGSizeMake(currentXOrigin, self.frame.size.height)
        self.alwaysBounceHorizontal = true
    }
    
    func suggestionPressed(sender : UIButton!)
    {
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.15 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            sender.backgroundColor = UIColor(red: CGFloat(173)/CGFloat(255), green: CGFloat(180)/CGFloat(255), blue: CGFloat(190)/CGFloat(255), alpha: 1.0)
        }
        
        if (self.keyboardDelegate != nil)
        {
            self.keyboardDelegate?.updateString(suggestions[sender.tag])
        }
    }
    
    func resetSuggestionViewColor(sender: UIButton!)
    {
        sender.backgroundColor = UIColor(red: CGFloat(173)/CGFloat(255), green: CGFloat(180)/CGFloat(255), blue: CGFloat(190)/CGFloat(255), alpha: 1.0)
    }
    
    func suggestionTouchDown(sender: UIButton!)
    {
        sender.backgroundColor = UIColor(red: CGFloat(235)/CGFloat(255), green: CGFloat(237)/CGFloat(255), blue: CGFloat(239)/CGFloat(255), alpha: 1.0)
    }
    
    // Called when the input is updatd, need to fetch new suggestions
    func inputUpdated(notification : NSNotification)
    {
        let userInfo : Dictionary<String, String!> = notification.userInfo as! Dictionary<String, String!>
        let sourceString = userInfo["text"]!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        let string =  Utils.unaccentString(sourceString)
        
        // If we have empty or whitespace strings, then don't bother sending to the server
        if string!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) == "" {
            self.setupSuggestions([String]())
            return
        }
        
        self.server.getSuggestion(string!, completion: { (result) -> Void in
            
            // Get flatten suggestions
            var flattenSuggestions : ExpandedSequence = AccenTypeServer.expandSuggestions(result)
            var suggestions = [String]()
            var count = 0
            
            for w in flattenSuggestions
            {
                suggestions.append(w)
                // Cap the number of returns
                if (count++ >= self.maxSuggestionCount) {
                    break
                }
            }
            
            self.setupSuggestions(suggestions)

            let currentString = userInfo["text"]!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            if (currentString == sourceString && currentString != suggestions[0]) {
                self.keyboardDelegate?.updateString(suggestions[0])
            }
        })
    }
}

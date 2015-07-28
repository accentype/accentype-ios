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
    let suggestions = ["hellö", "holafsdkfdk", "hillo", "halo", "hurry", "hurt", "hurtz", "hermit", "herky"]
    
    // Variables
    var keyboardDelegate : SuggestionStringUpdateDelegate?
    
    required init(globalColors: GlobalColors.Type?, darkMode: Bool, solidColorMode: Bool) {
        super.init(globalColors: globalColors, darkMode: darkMode, solidColorMode: solidColorMode)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setNeedsLayout() {
        super.setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.setupSuggestions()
    }

    func setupSuggestions()
    {
        var currentXOrigin = CGFloat(0)
        
        for var index = 0; index < suggestions.count; index++
        {
            var wordsuggest = suggestions[index];
            
            // Set title to word suggestion
            let button   = UIButton.buttonWithType(UIButtonType.System) as! UIButton
            button.setTitle(wordsuggest, forState: UIControlState.Normal)
            button.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
            button.setTitleColor(UIColor.blackColor(), forState: UIControlState.Highlighted)
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
    
    func suggestionTouchDown(sender: UIButton!)
    {
        sender.backgroundColor = UIColor(red: CGFloat(235)/CGFloat(255), green: CGFloat(237)/CGFloat(255), blue: CGFloat(239)/CGFloat(255), alpha: 1.0)
    }
}

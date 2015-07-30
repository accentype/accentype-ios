//
//  Accentype_Vietnamese.swift
//  TransliteratingKeyboard
//
//  Created by Alexei Baboulevitch on 9/24/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

/*
This is the demo keyboard. If you're implementing your own keyboard, simply follow the example here and then
set the name of your KeyboardViewController subclass in the Info.plist file.
*/

let kCatTypeEnabled = "kCatTypeEnabled"

class Accentype_Vietnamese: KeyboardViewController, SuggestionStringUpdateDelegate {
    
    // Constants
    let takeDebugScreenshot: Bool = false
    
    // Properties
    var server = AccenTypeServer()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        NSUserDefaults.standardUserDefaults().registerDefaults([kCatTypeEnabled: true])
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func keyPressed(key: Key) {
        if let textDocumentProxy = self.textDocumentProxy as? UITextDocumentProxy {
            
            let keyOutput = key.outputForCase(self.shiftState.uppercase())
            self.insertText(keyOutput, shouldAutoReplace: true)
            
        }
    }
    
    override func setupKeys() {
        super.setupKeys()
        
        if takeDebugScreenshot {
            if self.layout == nil {
                return
            }
            
            for page in keyboard.pages {
                for rowKeys in page.rows {
                    for key in rowKeys {
                        if let keyView = self.layout!.viewForKey(key) {
                            keyView.addTarget(self, action: "takeScreenshotDelay", forControlEvents: .TouchDown)
                        }
                    }
                }
            }
        }
    }
    
    override func createBanner() -> SuggestionView? {
        var bannerView = SuggestionView(globalColors: self.dynamicType.globalColors, darkMode: false, solidColorMode: self.solidColorMode())
        bannerView.keyboardDelegate = self
        return bannerView
    }
    
    func takeScreenshotDelay() {
        var timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: Selector("takeScreenshot"), userInfo: nil, repeats: false)
    }
    
    func takeScreenshot() {
        if !CGRectIsEmpty(self.view.bounds) {
            UIDevice.currentDevice().beginGeneratingDeviceOrientationNotifications()
            
            let oldViewColor = self.view.backgroundColor
            self.view.backgroundColor = UIColor(hue: (216/360.0), saturation: 0.05, brightness: 0.86, alpha: 1)
            
            var rect = self.view.bounds
            UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)
            var context = UIGraphicsGetCurrentContext()
            self.view.drawViewHierarchyInRect(self.view.bounds, afterScreenUpdates: true)
            var capturedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            let name = (self.interfaceOrientation.isPortrait ? "Screenshot-Portrait" : "Screenshot-Landscape")
            var imagePath = "/Users/archagon/Documents/Programming/OSX/RussianPhoneticKeyboard/External/tasty-imitation-keyboard/\(name).png"
            UIImagePNGRepresentation(capturedImage).writeToFile(imagePath, atomically: true)
            
            self.view.backgroundColor = oldViewColor
        }
    }
    
    func deleteString(string: String, ignoreAccent : Bool) -> Void
    {
        let textDocumentProxy = self.textDocumentProxy as? UITextDocumentProxy
        var stringToDelete : String? = string
        var stringContext : String? = textDocumentProxy?.documentContextBeforeInput
        
        // If nothing to delete, return
        if (stringToDelete == nil || stringContext == nil || stringToDelete!.isEmpty || stringContext!.isEmpty)
        {
            return
        }
        
        if (ignoreAccent)
        {
            stringToDelete = Utils.unaccentString(string)
            stringContext = Utils.unaccentString(stringContext!)
        }
        
        let range = stringContext!.rangeOfString(stringToDelete!)
        if range != nil
        {
            var numberOfCharsToDelete = distance(advance(range!.startIndex, 1) , textDocumentProxy!.documentContextBeforeInput!.endIndex)
            self.deleteCharactersWithLength(numberOfCharsToDelete)
        }
    }
    
    func deleteCharactersWithLength(numberOfLetters: Int) -> Void
    {
        let textDocumentProxy = self.textDocumentProxy as? UITextDocumentProxy
        
        if textDocumentProxy != nil
        {
            for _ in 1...numberOfLetters {
                textDocumentProxy!.deleteBackward()
            }
        }
    }
    
    func insertText(newText : String, shouldAutoReplace : Bool) -> Void
    {
        if let textDocumentProxy = self.textDocumentProxy as? UITextDocumentProxy {
            textDocumentProxy.insertText(newText)
            NSNotificationCenter.defaultCenter().postNotificationName(
                notification_inputChanged,
                object: nil,
                userInfo: ["text" : Utils.currentInputContext(textDocumentProxy.documentContextBeforeInput),
                           "shouldAutoReplace" : shouldAutoReplace])
        }
    }
    
    // Suggestion view banner delegate. Invoked when the user clicks on a suggestion
    func updateString(updateString: String)
    {
        if let textDocumentProxy = self.textDocumentProxy as? UITextDocumentProxy {
                self.deleteCharactersWithLength(count(updateString))
                self.insertText(updateString, shouldAutoReplace: false)
        }
    }
}

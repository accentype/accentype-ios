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
    
    let takeDebugScreenshot: Bool = false
    
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
            
            //////////
            println("Context before input: \(textDocumentProxy.documentContextBeforeInput)")
            println("Context after input: \(textDocumentProxy.documentContextAfterInput)")
            
//            if (textDocumentProxy.documentContextBeforeInput != nil && count(textDocumentProxy.documentContextBeforeInput) > 5)
//            {
//                textDocumentProxy.deleteBackward()
//                textDocumentProxy.deleteBackward()
//                textDocumentProxy.deleteBackward()
//                println("Context before input after delete: \(textDocumentProxy.documentContextBeforeInput)")
//                println("Context after input after delete: \(textDocumentProxy.documentContextAfterInput)")
//            }
            
            if !NSUserDefaults.standardUserDefaults().boolForKey(kCatTypeEnabled) {
                textDocumentProxy.insertText(keyOutput)
                return
            }
            /////////
            
            if key.type == .Character || key.type == .SpecialCharacter {
                let context = textDocumentProxy.documentContextBeforeInput
                if context != nil {
                    if count(context) < 2 {
                        textDocumentProxy.insertText(keyOutput)
                        return
                    }
                    
                    var index = context!.endIndex
                    
                    index = index.predecessor()
                    if context[index] != " " {
                        textDocumentProxy.insertText(keyOutput)
                        return
                    }
                    
                    index = index.predecessor()
                    if context[index] == " " {
                        textDocumentProxy.insertText(keyOutput)
                        return
                    }

                    textDocumentProxy.insertText(keyOutput)
                    return
                }
                else {
                    textDocumentProxy.insertText(keyOutput)
                    return
                }
            }
            else {
                textDocumentProxy.insertText(keyOutput)
                return
            }
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
    
    func unaccentString(string : String) -> String?
    {
        var data = string.dataUsingEncoding(NSASCIIStringEncoding, allowLossyConversion: true)
        return NSString(data: data!, encoding: NSASCIIStringEncoding) as String?
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
            stringToDelete = self.unaccentString(string)
            stringContext = self.unaccentString(stringContext!)
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
            for _ in 0...numberOfLetters {
                textDocumentProxy!.deleteBackward()
            }
        }
    }
    
    
    // Suggestion view banner delegate
    func updateString(updateString: String)
    {
        if let textDocumentProxy = self.textDocumentProxy as? UITextDocumentProxy {
                self.deleteString(updateString, ignoreAccent: true)
                textDocumentProxy.insertText(updateString)
        }
    }
}

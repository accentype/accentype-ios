//
//  Utils.swift
//  Accentype
//
//  Created by Chenkai Liu on 7/29/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import Foundation

class Utils : NSObject {
    
    static let delimiterCutoffs = [".", ",", "!", "#", "$", "(", ")", "+", "-", "="]
    
    static func unaccentString(string : String) -> String?
    {
        var data = string.dataUsingEncoding(NSASCIIStringEncoding, allowLossyConversion: true)
        return NSString(data: data!, encoding: NSASCIIStringEncoding) as String?
    }
    
    static func currentInputContext(context : String) -> String
    {
        var farthestIndex = context.endIndex
        for delimiter in Utils.delimiterCutoffs
        {
            var lastPosition = context.rangeOfString(delimiter, options: NSStringCompareOptions.BackwardsSearch)
            if (lastPosition != nil && lastPosition?.endIndex < farthestIndex)
            {
                farthestIndex = lastPosition!.endIndex
            }
        }
        
        return context.substringFromIndex(advance(farthestIndex, 1))
    }
}
//
//  Bundle+UInnUtilities.swift
//  UInnUtilities
//
//  Created by Theo Chen on 11/28/18.
//

import UIKit

let kUnknown = "Unknown"

public extension Bundle {
    public var uu_bundleShortVersion:String {
        if let info = Bundle.main.infoDictionary {
            if let appVersion = info["CFBundleShortVersionString"] as? String {
                return appVersion
            }
        }
        
        return kUnknown
    }
    
    public var uu_bundleVersion:String {
        if let info = Bundle.main.infoDictionary {
            if let bundleVersion = info["CFBundleVersion"] as? String {
                return bundleVersion
            }
        }
        
        return kUnknown
    }
}

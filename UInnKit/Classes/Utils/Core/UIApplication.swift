//
//  UIApplication+UInnUtils.swift
//  UInnKit
//
//  Created by Theo Chen on 2/13/19.
//

import UIKit

public extension UIApplication {
    /// 当前运行的App是否是extension
    @objc
    public static var uu_isAppExtension:Bool {
        #if TARGET_OS_IOS || TARGET_OS_TV
        // Documented by <a href="https://goo.gl/RRB2Up">Apple</a>
        let appExtension = Bundle.main.bundlePath.hasSuffix(".appex")
        return appExtension
        #elseif TARGET_OS_OSX
        return false
        #endif
        
        return false
    }
    
    /// 当前运行的App的Application对象
    @objc(bbu_sharedApplication)
    public static var uu_shared: UIApplication? {
        // iOS App extensions should not call [UIApplication sharedApplication], even if UIApplication
        // responds to it.
        if let cls:AnyObject = NSClassFromString("UIApplication") {
            if cls.responds(to: NSSelectorFromString("sharedApplication")) {
                let returnValue = cls.perform(NSSelectorFromString("sharedApplication"))
                
                return returnValue?.takeUnretainedValue() as? UIApplication
            }
        }
        
        return nil
    }
}

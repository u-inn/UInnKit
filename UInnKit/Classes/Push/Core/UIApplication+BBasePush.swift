//
//  UIApplication+UInnPush.swift
//  UInnPush
//
//  Created by Theo Chen on 11/15/18.
//

import UIKit

public extension UIApplication {

    public static var bbp_shared:UIApplication? {
        if let UIApplicationClass = NSClassFromString("UIApplication") {
            if UIApplicationClass.responds(to: #selector(getter: shared)) {
                let application = UIApplication.perform(#selector(getter: shared))
                
                return application?.takeRetainedValue() as? UIApplication
            }
        }
        
        return nil
    }
}

//
//  DispatchQueue+UInnPush.swift
//  DispatchQueue
//
//  Created by Theo Chen on 11/18/18.
//

import UIKit

internal extension DispatchQueue {
    private static var _onceTracker = [String]()
    internal class func bbp_once(token: String, block: () -> ()) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        if _onceTracker.contains(token) {
            return
        }
        _onceTracker.append(token)
        block()
    }
    
    func async(block: @escaping ()->()) {
        self.async(execute: block)
    }
    
    func after(time: DispatchTime, block: @escaping ()->()) {
        self.asyncAfter(deadline: time, execute: block)
    }
}

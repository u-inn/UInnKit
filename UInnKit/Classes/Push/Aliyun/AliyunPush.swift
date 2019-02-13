//
//  AliyunPush.swift
//  UInnPush
//
//  Created by Theo Chen on 11/18/18.
//

import UIKit
import CloudPushSDK
import ObjectiveC

public class AliyunPush:NSObject {
    
    @objc public var isEnabled = false
    
    private let onceToken = UUID().uuidString
    
    internal func loadConfigure(application:UIApplication) {
        CloudPushSDK.configure()
        
        DispatchQueue.bbp_once(token: onceToken) {
            
            
            if let method = class_getInstanceMethod(AliyunPush.self, #selector(AliyunPush.bbp_application(_:didRegisterForRemoteNotificationsWithDeviceToken:))) {
                let imp = method_getImplementation(method)
                
                let registerForAPNSSuccessSelector:Selector = #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
                UInnSwizzler.shared.swizzleSelector(originalSelector: registerForAPNSSuccessSelector,
                                                   inClass: type(of: application.delegate!),
                                                   withImplementation: imp,
                                                   inProtocol: UIApplicationDelegate.self)
            }
            
            //BBUSwizzler.shared.swizzleSelector(originalSelector: registerForAPNSSuccessSelector, inClass: type(of: application.delegate!), withMethod: method!, isClassMethod: false)
        }
    }
    
    @objc public func bbp_application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        var deviceTokenStr = ""
        for i in 0..<deviceToken.count {
            deviceTokenStr += String(format: "%02.2hhx", deviceToken[i] as CVarArg)
        }
        uu_print("Device token is \(deviceTokenStr)")
        // 阿里云注册Device
        CloudPushSDK.registerDevice(deviceToken) { (res:CloudPushCallbackResult?) in
            if res?.success ?? false {
                uu_print("Aliyun CloudPushSDK Register deviceToken success, deviceToken: \(deviceTokenStr)")
            }
            else {
                uu_print("Aliyun CloudPushSDK Register deviceToken failed, error: \(res?.error?.localizedDescription ?? "Unkown Error")")
            }
        }
        
        if let imp = UInnSwizzler.shared.originalImplementation(forSelector: #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:))) {
            typealias originalFunction = @convention(c) (AnyObject, Selector, UIApplication, Data) -> Void
            let curriedImplementation = unsafeBitCast(imp, to: originalFunction.self)
            curriedImplementation(application.delegate!, #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)), application, deviceToken)
        }
    }
}

func BBP_AliyunPush_swizzle_appDidRegisterForRemoteNotifications(self:AnyObject,
                                                                 _cmd:Selector,
                                                                 application:UIApplication,
                                                                 deviceToken:Data) {
    var deviceTokenStr = ""
    for i in 0..<deviceToken.count {
        deviceTokenStr += String(format: "%02.2hhx", deviceToken[i] as CVarArg)
    }
    uu_print("Device token is \(deviceTokenStr)")
    // 阿里云注册Device
    CloudPushSDK.registerDevice(deviceToken) { (res:CloudPushCallbackResult?) in
        if res?.success ?? false {
            uu_print("Aliyun CloudPushSDK Register deviceToken success, deviceToken: \(deviceTokenStr)")
        }
        else {
            uu_print("Aliyun CloudPushSDK Register deviceToken failed, error: \(res?.error?.localizedDescription ?? "Unkown Error")")
        }
    }
    
    if let original_imp:IMP = UInnSwizzler.shared.originalImplementation(forSelector: _cmd) {
        typealias originalFunction = @convention(c) (AnyObject, Selector, UIApplication, Data) -> Void
        let curriedImplementation = unsafeBitCast(original_imp, to: originalFunction.self)
        curriedImplementation(self, _cmd, application, deviceToken)
    }
}


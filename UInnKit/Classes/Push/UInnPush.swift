//
//  UInnPush.swift
//  UInnPush
//
//  Created by Theo Chen on 11/15/18.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import FirebaseInstanceID
import UserNotifications
import CloudPushSDK
import RxSwift

public struct UInnPushProviderOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue:Int) {
        self.rawValue = rawValue
    }
    
    public static let firebase = UInnPushProviderOptions(rawValue: 1 << 0)
    public static let aliyun = UInnPushProviderOptions(rawValue: 1 << 1)
    
    public static let all: UInnPushProviderOptions = [.firebase, .aliyun]
}

// 1. 区分远程/本地（iOS 10之前）
// 2. will present / did recieve（iOS 10之后）
public class UInnPush: NSObject {
    
    private static let gcmMessageIDKey = "gcm.message_id"
    
    private let onceToken = UUID().uuidString
    
    private let disposeBag = DisposeBag()
    
    @objc public var firebasePush = FirebasePush()

    @objc public var aliyunPush = AliyunPush()
    
    @objc(sharedInstance)
    public static let shared = UInnPush()
    
    private var didReceivePushNotificationSubject:PublishSubject = PublishSubject<[AnyHashable : Any]>()

    @available(iOS, deprecated:10.0, message: "deprecated in iOS 10.0 or above")
    lazy private var didRecieveLocalNotificationSubject:PublishSubject = {
        return PublishSubject<UILocalNotification>()
    }()
    
    @available(iOS, deprecated:10.0, message: "deprecated in iOS 10.0 or above")
    lazy private var didRecieveRemoteNotificationSubject:PublishSubject = {
        return PublishSubject<[AnyHashable : Any]>()
    }()
    
    @available(iOS 10.0, *)
    lazy private var didReceiveNotificationSubject:PublishSubject = {
        return PublishSubject<UNNotificationResponse>()
    }()
    
    @available(iOS 10.0, *)
    lazy private var willPresentNotificationSubject:PublishSubject = {
        return PublishSubject<(UNNotification, (UNNotificationPresentationOptions) -> Void)>()
    }()

    private override init() {
        super.init()
    }
    
    public func loadConfigure(with pushServiceProviderOptions:UInnPushProviderOptions , application:UIApplication) {
        self.loadConfigure(with: pushServiceProviderOptions, application: application, registerPushNotificationLater: false)
    }
    
    /**
     配置UInnPush的各项参数
     - parameter application: 就是application，不解释了
     - parameter registerPushNotificationLater: 重要：默认是fasle，如果设置为true，那么该函数将不自行注册PushNotification了，事后，由你主动调用UInnPush.shared.registerPushNotification(application:application)注册
     */
    public func loadConfigure(with pushServiceProviderOptions:UInnPushProviderOptions , application:UIApplication, registerPushNotificationLater:Bool = false) {
        self.aliyunPush.isEnabled = false
        self.firebasePush.isEnabled = false
        
        if (pushServiceProviderOptions.rawValue & UInnPushProviderOptions.firebase.rawValue) == UInnPushProviderOptions.firebase.rawValue {
            self.firebasePush.isEnabled = true
        }
        if pushServiceProviderOptions.rawValue & UInnPushProviderOptions.aliyun.rawValue == UInnPushProviderOptions.aliyun.rawValue {
            self.aliyunPush.isEnabled = true
        }
        
        self.loadConfigure(application: application, registerPushNotificationLater: registerPushNotificationLater)
    }
    
    
    ///配置UInnPush的各项参数
    ///
    /// - parameter registerPushNotificationLater: 重要：默认是fasle，如果设置为true，那么该函数将不自行注册PushNotification了，事后，由你主动调用UInnPush.shared.registerPushNotification(application:application)注册
    public func loadConfigure(with pushServiceProviderOptions:UInnPushProviderOptions, registerPushNotificationLater:Bool = false) {
        self.aliyunPush.isEnabled = false
        self.firebasePush.isEnabled = false
        
        if (pushServiceProviderOptions.rawValue & UInnPushProviderOptions.firebase.rawValue) == UInnPushProviderOptions.firebase.rawValue {
            self.firebasePush.isEnabled = true
        }
        if pushServiceProviderOptions.rawValue & UInnPushProviderOptions.aliyun.rawValue == UInnPushProviderOptions.aliyun.rawValue {
            self.aliyunPush.isEnabled = true
        }
        
        self.loadConfigure(application: UIApplication.uu_shared!, registerPushNotificationLater: registerPushNotificationLater)
    }

    /**
     配置UInnPush的各项参数
     - parameter application: 就是application，不解释了
     - parameter registerPushNotificationLater: 重要：默认是fasle，如果设置为true，那么该函数将不自行注册PushNotification了，事后，由你主动调用UInnPush.shared.registerPushNotification(application:application)注册
     */
    @objc public func loadConfigure(application:UIApplication, registerPushNotificationLater:Bool = false) {
        
        if aliyunPush.isEnabled {
            aliyunPush.loadConfigure(application: application)
        }
        if firebasePush.isEnabled {
            firebasePush.loadConfigure(application: application)
        }
        
        if !registerPushNotificationLater {
            self.registerPushNotification(application: application)
        }
        
        // 以下内容设置delegate
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self;
        } else {
            // 基于 iOS 10 及以下的系统版本，无法使用UNUserNotificationCenterDelegate，所有的通知都是由 [application: didReceiveRemoteNotification:] 来获取，这里需要使用method swizzle
            assert(application.delegate != nil, "AppDelegate is nil")
            
            DispatchQueue.bbp_once(token: onceToken) {
                
                if let method = class_getInstanceMethod(UInnPush.self, #selector(UInnPush.bbp_application(_:didReceiveRemoteNotification:))) {
                    let imp = method_getImplementation(method)
                    
                    UInnSwizzler.shared.swizzleSelector(originalSelector: #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:)),
                                                   inClass: type(of: application.delegate!),
                                                   withImplementation: imp,
                                                   inProtocol: UIApplicationDelegate.self)
                }
                
                if let method = class_getInstanceMethod(UInnPush.self, #selector(UInnPush.bbp_application(_:didReceiveRemoteNotification:fetchCompletionHandler:))) {
                    let imp = method_getImplementation(method)
                    
                    UInnSwizzler.shared.swizzleSelector(originalSelector: #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)),
                                                       inClass: type(of: application.delegate!),
                                                       withImplementation: imp,
                                                       inProtocol: UIApplicationDelegate.self)
                }
                
                if let method = class_getInstanceMethod(UInnPush.self, #selector(UInnPush.bbp_application(_:didReceive:))) {
                    let imp = method_getImplementation(method)
                    
                    UInnSwizzler.shared.swizzleSelector(originalSelector: #selector(UIApplicationDelegate.application(_:didReceive:)),
                                                       inClass: type(of: application.delegate!),
                                                       withImplementation: imp,
                                                       inProtocol: UIApplicationDelegate.self)
                }
            }
        }
    }
    
    @objc public func registerPushNotification(application:UIApplication) {
        // 以下内容注册remote notification事件
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self;
            
            self.registerRemoteNotification(application: application)
        }
        else {
            // Fallback on earlier versions
            self.registerRemoteNotification_fallback(application: application)
            // 基于 iOS 10 及以上的系统版本，无法使用UNUserNotificationCenterDelegate，所有的通知都是由 [application: didReceiveRemoteNotification:] 来获取，这里需要使用method swizzle
        }
    }
    
    // For iOS 10 display notification (sent via APNS)
    @available(iOS 10.0, *)
    internal func registerRemoteNotification(application:UIApplication) {
        
        // Register for remote notifications. This shows a permission dialog on first run, to
        // show the dialog at a more appropriate time move this registration accordingly.
        // [START register_for_notifications]
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: {_, _ in }
        )
        
        application.registerForRemoteNotifications()
        
        // [END register_for_notifications]
    }
    
    internal func registerRemoteNotification_fallback(application:UIApplication) {
    
        // Register for remote notifications. This shows a permission dialog on first run, to
        // show the dialog at a more appropriate time move this registration accordingly.
        // [START register_for_notifications]
        
        let settings: UIUserNotificationSettings =
            UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
        application.registerUserNotificationSettings(settings)
        application.registerForRemoteNotifications()
        
        // [END register_for_notifications]
    }
    
    deinit {
        fatalError("UInnPush deinit ..., should never be called since UInnPush is a static singleton")
    }
    
    @objc(onReceivePushNotification:)
    public func onReceivePushNotification(receivePushNotificationHandler:@escaping (_ userInfo:[AnyHashable : Any])->Void) {
        self.didReceivePushNotificationSubject.subscribe(onNext: {
            receivePushNotificationHandler($0)
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
    }
    
    @available(iOS, deprecated:10.0, message: "deprecated in iOS 10.0 or above, use onWillPresentNotification and onDidReceiveNotification instead")
    @objc(onReceiveRemoteNotification:)
    public func onReceiveRemoteNotification(receiveRemoteNotificationHandler:@escaping (_ userInfo:[AnyHashable : Any])->Void) {
        self.didRecieveRemoteNotificationSubject.subscribe(onNext: {
            receiveRemoteNotificationHandler($0)
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
    }
    
    @available(iOS, deprecated: 10.0, message: "deprecated in iOS 10.0 or above, use onWillPresentNotification and onDidReceiveNotification instead")
    @objc(onReceiveLocalNotification:)
    public func onReceiveLocalNotification(receiveLocalNotificationHandler:@escaping (_ notification:UILocalNotification)->Void) {
        self.didRecieveLocalNotificationSubject.subscribe(onNext: {
            receiveLocalNotificationHandler($0)
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
    }
    
    @available(iOS 10.0, *)
    @objc(onWillPresentNotification:)
    public func onWillPresentNotification(willPresentNotificationHandler:@escaping (_ notification:UNNotification, _ completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)->Void) {
        self.willPresentNotificationSubject.subscribe(onNext: {
            willPresentNotificationHandler($0.0, $0.1)
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
    }
    
    @available(iOS 10.0, *)
    @objc(onDidReceiveNotification:)
    public func onDidReceiveNotification(didReceiveNotificationHandler:@escaping (_ response:UNNotificationResponse)->Void) {
        self.didReceiveNotificationSubject.subscribe(onNext: {
            didReceiveNotificationHandler($0)
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
    }
}

// program mark - message_handling_callback - Method Swizzle
extension UInnPush {
    @objc public func bbp_application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print message ID.
        if let messageID = userInfo[UInnPush.gcmMessageIDKey] {
            uu_print("Message ID: \(messageID)")
        }
        
        // Print full message.
        uu_print(userInfo)
        UInnPush.shared.didReceivePushNotificationSubject.onNext(userInfo)
        UInnPush.shared.didRecieveRemoteNotificationSubject.onNext(userInfo)
        
        // 接下去执行AppDelegate中原有的逻辑
        let originalSelector = #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:))
        if let imp = UInnSwizzler.shared.originalImplementation(forSelector: originalSelector) {
            typealias originalFunction = @convention(c) (AnyObject, Selector, UIApplication, [AnyHashable: Any]) -> Void
            let curriedImplementation = unsafeBitCast(imp, to: originalFunction.self)
            curriedImplementation(application.delegate!, originalSelector, application, userInfo)
        }
    }
    
    // Use this method to process incoming remote notifications for your app. Unlike the application(_:didReceiveRemoteNotification:) method, which is called only when your app is running in the foreground, the system calls this method when your app is running in the foreground or background.
    @objc public func bbp_application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                                  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print message ID.
        if let messageID = userInfo[UInnPush.gcmMessageIDKey] {
            uu_print("Message ID: \(messageID)")
        }
        
        // Print full message.
        uu_print(userInfo)
        UInnPush.shared.didReceivePushNotificationSubject.onNext(userInfo)
        UInnPush.shared.didRecieveRemoteNotificationSubject.onNext(userInfo)
        
        completionHandler(UIBackgroundFetchResult.newData)
        
        // 接下去执行AppDelegate中原有的逻辑
        let originalSelector = #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:))
        if let imp = UInnSwizzler.shared.originalImplementation(forSelector: originalSelector) {
            typealias originalFunction = @convention(c) (AnyObject, Selector, UIApplication, [AnyHashable: Any], @escaping (UIBackgroundFetchResult) -> Void) -> Void
            let curriedImplementation = unsafeBitCast(imp, to: originalFunction.self)
            curriedImplementation(application.delegate!, originalSelector, application, userInfo, completionHandler)
        }
    }
    
    @objc public func bbp_application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        if let userInfo = notification.userInfo {
            // Print full message.
            uu_print(userInfo)
            UInnPush.shared.didReceivePushNotificationSubject.onNext(userInfo)
        }
        
        UInnPush.shared.didRecieveLocalNotificationSubject.onNext(notification)
        
        // 接下去执行AppDelegate中原有的逻辑
        let originalSelector = #selector(UIApplicationDelegate.application(_:didReceive:))
        if let imp = UInnSwizzler.shared.originalImplementation(forSelector: originalSelector) {
            typealias originalFunction = @convention(c) (AnyObject, Selector, UIApplication, UILocalNotification) -> Void
            let curriedImplementation = unsafeBitCast(imp, to: originalFunction.self)
            curriedImplementation(application.delegate!, originalSelector, application, notification)
        }
    }
}

// [START ios_10_message_handling]
// 基于 iOS 10 及以上的系统版本，原 [application: didReceiveRemoteNotification:] 将会被系统废弃，由新增 UserNotifications Framework中的[UNUserNotificationCenterDelegate willPresentNotification:withCompletionHandler:] 或者 [UNUserNotificationCenterDelegate didReceiveNotificationResponse:withCompletionHandler:] 方法替代。
@available(iOS 10, *)
extension UInnPush: UNUserNotificationCenterDelegate {
    // Receive displayed notifications for iOS 10 devices.
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print message ID.
        if let messageID = userInfo[UInnPush.gcmMessageIDKey] {
            uu_print("Message ID: \(messageID)")
        }
        
        // Print full message.
        uu_print(userInfo)
        didReceivePushNotificationSubject.onNext(userInfo)
        willPresentNotificationSubject.onNext((notification, completionHandler))
        
        // Change this to your preferred presentation option
        completionHandler([.alert, .badge, .sound])
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // Print message ID.
        if let messageID = userInfo[UInnPush.gcmMessageIDKey] {
            uu_print("Message ID: \(messageID)")
        }
        
        // Print full message.
        uu_print(userInfo)
        didReceivePushNotificationSubject.onNext(userInfo)
        didReceiveNotificationSubject.onNext(response)

        completionHandler()
    }
}

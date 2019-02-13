//
//  FirebasePush.swift
//  UInnPush
//
//  Created by Theo Chen on 11/18/18.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import RxSwift

public class FirebasePush:NSObject {
    @objc public var isEnabled = false
    
    private let disposeBag = DisposeBag()
    private let didReceiveRegistrationFCMTokenSubject = PublishSubject<String>()
    
    internal func loadConfigure(application:UIApplication) {
        // to avoid duplicated configure of FirebaseApp
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // [START set_messaging_delegate]
        Messaging.messaging().delegate = self
        // [END set_messaging_delegate]
    }
    
    @objc(onReceiveRegistrationFCMToken:)
    public func onReceiveRegistrationFCMToken(receiveRegistrationFCMTokenHandler:@escaping (_ fcmToken: String) -> Void) {
        didReceiveRegistrationFCMTokenSubject.subscribe(onNext: {
            receiveRegistrationFCMTokenHandler($0)
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
    }
}

extension FirebasePush: MessagingDelegate {
    // [START refresh_token]
    public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        uu_print("Firebase registration token: \(fcmToken)")
        
        let dataDict:[String: String] = ["token": fcmToken]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
        
        didReceiveRegistrationFCMTokenSubject.onNext(fcmToken)
    }
    // [END refresh_token]
    
    // [START ios_10_data_message]
    // Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
    // To enable direct data messages, you can set Messaging.messaging().shouldEstablishDirectChannel to true.
    public func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        uu_print("Received data message: \(remoteMessage.appData)")
    }
    // [END ios_10_data_message]
}


extension FirebasePush {
    @objc public func googleServiceInfo() -> GoogleServiceInfo {
        
        let fileUrl = Bundle.main.url(forResource: kFirebasePushInfoPlist, withExtension: "plist")
        assert(fileUrl != nil, "GoogleService-Info error: does not exist, 你申请了FirebaseMessage的Push服务，请确保下载了GoogleService-Info.plist文件，并添加到了工程中")
        
        do {
            let data = try Data(contentsOf: fileUrl!)
            let decoder = PropertyListDecoder()
            let googleServiceInfo = try decoder.decode(GoogleServiceInfo.self, from: data)
            return googleServiceInfo
        }
        catch {
            fatalError("GoogleService-Info error: incorrect plist format --- \(error.localizedDescription)")
        }
    }
}


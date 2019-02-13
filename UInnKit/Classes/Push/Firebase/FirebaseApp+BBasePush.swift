import FirebaseCore
import FirebaseInstanceID
import FirebaseMessaging
import UserNotifications

internal let kFirebasePushInfoPlist = "GoogleService-Info"

@objc public class GoogleServiceInfo: NSObject, Codable  {
    private enum CodingKeys: String, CodingKey {
        case projectId = "PROJECT_ID"
    }
    
    @objc public let projectId: String
}

public extension FirebaseApp {
    
    internal static func bbp_registerRemoteNotification<T>(application:UIApplication, delegate:T) where T: MessagingDelegate {
        // [START set_messaging_delegate]
        Messaging.messaging().delegate = delegate
        // [END set_messaging_delegate]
    }
}





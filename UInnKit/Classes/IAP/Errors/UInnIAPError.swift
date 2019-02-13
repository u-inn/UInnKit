//
//  UInnIAPError.swift
//  UInnIAP
//
//  Created by Theo Chen on 11/29/18.
//

import StoreKit

public let UInnIAPErrorDomain = "UInnIAPErrorDomain"

public class UInnIAPError: NSObject, Error {
    
    @objc private var code:Code
    
    @objc public init(code:Code) {
        self.code = code
    }
    
    @objc(UInnIAPErrorCode) public enum Code: Int {
        public typealias _ErrorType = UInnIAPReceiptError
        
        case clientInvalid   /// 对应SKError.clientInvalid
        case cloudServiceRevoked /// 对应SKError.cloudServiceRevoked
        case cloudServicePermissionDenied /// 对应SKError.cloudServicePermissionDenied
        case paymentCancelled /// 对应SKError.paymentCancelled
        case paymentInvalid /// 对应SKError.paymentInvalid
        case paymentNotAllowed /// 对应SKError.paymentNotAllowed
        case storeProductNotAvailable /// 对应SKError.storeProductNotAvailable
        case cloudServiceNetworkConnectionFailed /// 对应SKError.cloudServiceNetworkConnectionFailed
        case unknown /// 对应SKError.unknown
    }
    
    private var message:String {
        let code = UInnIAPError.Code(rawValue: self.errorCode) ?? .unknown
        switch code {
        case .clientInvalid:
            return "Client Invalid"
        case .cloudServiceRevoked:
            return "Cloud Service Revoked"
        case .cloudServicePermissionDenied:
            return "Cloud Service Permission Denied"
        case .paymentCancelled:
            return "Payment Cancelled（用户在支付时取消了）"
        case .paymentInvalid:
            return "Payment Invalid"
        case .paymentNotAllowed:
            return "Payment Not Allowed"
        case .storeProductNotAvailable:
            return "Store Product Not Available"
        case .cloudServiceNetworkConnectionFailed:
            return "Cloud Service Network Connection Failed"
        case .unknown:
            return SKError(.unknown).localizedDescription
        }
    }
}

extension UInnIAPError: CustomNSError {
    @objc public static var errorDomain: String {
        return UInnIAPErrorDomain
    }
    
    @objc public var errorCode: Int {
        return self.code.rawValue
    }
    
    @objc public var errorUserInfo: [String : Any] {
        return [String : Any]()
    }
    
    public override var description: String {
        return "Error Domain=\(UInnIAPError.errorDomain) Code=\(errorCode) - \"\(message)\" UserInfo=\(errorUserInfo)"
    }
}

extension UInnIAPError: LocalizedError {
    @objc public var localizedDescription: String {
        return message
    }
    
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        return message
    }
}





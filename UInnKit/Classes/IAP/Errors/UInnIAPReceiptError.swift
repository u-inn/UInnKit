//
//  UInnIAPReceiptError.swift
//  UInnIAP
//
//  Created by Theo Chen on 12/1/18.
//

import StoreKit

public let UInnIAPReceiptErrorDomain = "UInnIAPReceiptErrorDomain"

// error codes for the SKErrorDomain
@objc public class UInnIAPReceiptError: NSObject, Error {
    
    @objc private var _code:Code
    
    @objc public init(code:Code) {
        _code = code
    }
    
    public var code:Code {
        return _code
    }
    
    @objc(BBIReceiptErrorCode)
    public enum Code: Int {
        public typealias _ErrorType = UInnIAPReceiptError
        
        case unknown = -188800
        case receiptNotFound = -188801 // 无法加载本地收据
        case receiptRequestFailed = -188804// 由于网络错误造成的
        
        /// 21000: App Store 无法读取您提供的 JSON 对象。
        case jsonInvalid = 21000
    
        /// 21002: receipt-data 属性中的数据格式错误或丢失。
        case receiptInvalid = 21002 // 收据无法解析，收据格式不正确,

        /// 21003: 无法认证收据。
        case receiptVerifyFailed = 21003// 收据验证失败，收据格式正确，但是验证失败

        /// 21004: 您提供的共享密钥与您帐户存档的共享密钥不匹配。
        case appSecretInvalid = 21004
        
        /// 21005: 收据服务器当前不可用。
        case serverNotFound = 21005
        
        /// * 21006: 此收据有效，但订阅已过期。当此状态代码返回到您的服务器时，收据数据也将 解码并作为响应的一部分返回。 只有在交易收据为 iOS 6 样式且为自动续期订阅时才会返回。
        
        /// 21007: 此收据来自测试环境，但发送到生产环境进行验证。应将其发送到测试环境。
        case receiptIsFromSandbox = 21007
        
        /// 21008: 此收据来自生产环境，但发送到测试环境进行验证。应将其发送到生产环境。
        case receiptIsFromProduct = 21008

        /// 21010: 此收据无法获得授权。对待此收据的方式与从未进行过任何交易时的处理方式相同。
        case receiptUnauthorized = 21010
        
        /// 21100-21199: 内部数据访问错误。
        case internalError = 21199
    }
    
    private var message:String {
        let code = UInnIAPReceiptError.Code(rawValue: self.errorCode) ?? .unknown
        switch code {
        case .receiptNotFound:
            return "收据（Receipt）没有找到"
        case .receiptVerifyFailed:
            return "收据（Receipt）验证失败，该笔交易没有通过验证，可能是过期、或者是用户主动取消"
        case .receiptInvalid:
            return "收据（Receipt）为无效收据，该收据无法经过app store解析"
        case .receiptRequestFailed:
            return "收据（Receipt）解析中发生网络（http/https）错误"
        case .unknown:
            return "收据（Receipt）解析中发生未知（unkown）错误"
        case .jsonInvalid:
            return "App Store 无法读取您提供的 JSON 对象"
        case .appSecretInvalid:
            return "您提供的共享密钥与您帐户存档的共享密钥不匹配"
        case .serverNotFound:
            return "收据服务器当前不可用"
        case .receiptIsFromSandbox:
            return "此收据来自生产环境，但发送到测试环境进行验证。应将其发送到生产环境"
        case .receiptIsFromProduct:
            return "此收据无法获得授权。对待此收据的方式与从未进行过任何交易时的处理方式相同"
        case .receiptUnauthorized:
            return "此收据无法获得授权,对待此收据的方式与从未进行过任何交易时的处理方式相同"
        case .internalError:
            return "内部数据访问错误"
        }
    }
}

extension UInnIAPReceiptError: CustomNSError {
    @objc public static var errorDomain: String {
        return UInnIAPReceiptErrorDomain
    }
    
    @objc public var errorCode: Int {
        return self.code.rawValue
    }
    
    @objc public var errorUserInfo: [String : Any] {
        return [String : Any]()
    }
    
    public override var description: String {
        return "Error Domain=\(UInnIAPReceiptError.errorDomain) Code=\(errorCode) - \"\(message)\" UserInfo=\(errorUserInfo)"
    }
    
    @objc public var localizedDescription: String {
        return message
    }
}

extension UInnIAPReceiptError: LocalizedError {
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        return message
    }
}

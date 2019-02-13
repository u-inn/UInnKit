//
//  BBIReceiptResult.swift
//  UInnIAP
//
//  Created by Theo Chen on 11/28/18.
//

import Foundation

/// App 内购买项目收据字段
///
/// 官方文档：https://developer.apple.com/cn/app-store/Receipt-Validation-Programming-Guide-CN.pdf
/// 注意：App Store返回的JSON中有很多看起来很有用的字段，但如果这些字段没有在“官方文档”中列出，在BBIReceiptInApp类进行修改，
/// 请忽略这些未在“官方文档”中列出的属性保留供系统使用，因为它们的内容随时可能被App Store更改。
/// * 在进行消耗型产品购买时，该 App 内购买项目收据被添加到收据中。
/// * 在您的 App 完成该笔交易之前， 该 App 内购买项目收据会一直保留在收据内。
/// * 在交易完成后，该 App 内购买项目收据会在下次收据更新时(例如，顾客进行下一次购买，或者您的 App 明确刷新收据时)从收据中移除。
/// * 非消耗型产品、自动续期订阅、非续期订阅或免费订阅的 App 内购买项目收据无限期保留在收据中。
@objc public class UInnIAPReceiptResult:NSObject, Codable {
    /// 状态代码
    /// 21000: App Store 无法读取您提供的 JSON 对象。
    /// 21002: receipt-data 属性中的数据格式错误或丢失。
    /// 21003: 无法认证收据。
    /// 21004: 您提供的共享密钥与您帐户存档的共享密钥不匹配。
    /// 21005: 收据服务器当前不可用。
    /// * 21006: 此收据有效，但订阅已过期。当此状态代码返回到您的服务器时，收据数据也将 解码并作为响应的一部分返回。 只有在交易收据为 iOS 6 样式且为自动续期订阅时才会返回。
    /// 21007: 此收据来自测试环境，但发送到生产环境进行验证。应将其发送到测试环境。
    /// 21008: 此收据来自生产环境，但发送到测试环境进行验证。应将其发送到生产环境。
    /// 21010: 此收据无法获得授权。对待此收据的方式与从未进行过任何交易时的处理方式相同。
    /// 21100-21199: 内部数据访问错误。
    @objc public let status:Int
    @objc public let receipt:UInnIAPReceipt?
    @objc public let environment:String?
    @objc internal let pending_renewal_info:[UInnIAPPendingRenewalInfo]?
    @objc public let latest_receipt_info:[UInnIAPReceiptInApp]?
    @objc public let latest_receipt:String?
}

extension UInnIAPReceiptResult {
    public override var debugDescription: String {
        return self.uu_jsonString ?? ""
    }
    
    @objc public var jsonString: String? {
        return self.uu_jsonString
    }
    
    @objc(resultFromJsonString:)
    public static func result(from jsonString:String) -> UInnIAPReceiptResult? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        
        let jsonDecoder = JSONDecoder()
        do {
            let receiptResult = try jsonDecoder.decode(UInnIAPReceiptResult.self, from:jsonData)
            return receiptResult
        }
        catch {
            uu_print(error.localizedDescription)
        }
        return nil
    }
}

extension UInnIAPReceiptResult {
    internal var isValidated: Bool {
        // 状态代码 不为0，则代表Receipt校验不通过
        if status != 0  {
            return false
        }
        
        return receipt?.isValidated ?? false
    }
    
    var statusError:UInnIAPReceiptError {
        switch status {
            /// 21000: App Store 无法读取您提供的 JSON 对象。
        case 21000:
            return UInnIAPReceiptError(code: UInnIAPReceiptError.Code.jsonInvalid)
            /// 21002: receipt-data 属性中的数据格式错误或丢失。
        case 21002:
            return UInnIAPReceiptError(code: UInnIAPReceiptError.Code.receiptInvalid)
            /// 21003: 无法认证收据。
        case 21003:
            return UInnIAPReceiptError(code: UInnIAPReceiptError.Code.receiptVerifyFailed)
            /// 21004: 您提供的共享密钥与您帐户存档的共享密钥不匹配。
        case 21004:
            /// 21005: 收据服务器当前不可用。
            return UInnIAPReceiptError(code: UInnIAPReceiptError.Code.appSecretInvalid)
        case 21005:
            return UInnIAPReceiptError(code: UInnIAPReceiptError.Code.serverNotFound)
            /// * 21006: 此收据有效，但订阅已过期。当此状态代码返回到您的服务器时，收据数据也将 解码并作为响应的一部分返回。 只有在交易收据为 iOS 6 样式且为自动续期订阅时才会返回。
        case 21006:
            return UInnIAPReceiptError(code: UInnIAPReceiptError.Code.unknown)
            /// 21007: 此收据来自测试环境，但发送到生产环境进行验证。应将其发送到测试环境。
        case 21007:
            return UInnIAPReceiptError(code: UInnIAPReceiptError.Code.receiptIsFromSandbox)
            /// 21008: 此收据来自生产环境，但发送到测试环境进行验证。应将其发送到生产环境。
        case 21008:
            return UInnIAPReceiptError(code: UInnIAPReceiptError.Code.receiptIsFromProduct)
            /// 21010: 此收据无法获得授权。对待此收据的方式与从未进行过任何交易时的处理方式相同。
        case 21010:
            return UInnIAPReceiptError(code: UInnIAPReceiptError.Code.receiptUnauthorized)
            /// 21100-21199: 内部数据访问错误。
        case 21100...21199:
            return UInnIAPReceiptError(code: UInnIAPReceiptError.Code.internalError)
        default:
            return UInnIAPReceiptError(code: UInnIAPReceiptError.Code.unknown)
        }
    }
}


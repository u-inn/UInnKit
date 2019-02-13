//
//  BBIReceipt.swift
//  UInnIAP
//
//  Created by Theo Chen on 11/28/18.
//

import Foundation

/// App 内购买项目收据字段
///
/// 官方文档：https://developer.apple.com/cn/app-store/Receipt-Validation-Programming-Guide-CN.pdf
/// 注意：App Store返回的JSON中有很多看起来很有用的字段，但如果这些字段没有在“官方文档”中列出，在BBIReceipt类进行修改，
/// 请忽略这些未在“官方文档”中列出的属性保留供系统使用，因为它们的内容随时可能被App Store更改。
/// * 在进行消耗型产品购买时，该 App 内购买项目收据被添加到收据中。
/// * 在您的 App 完成该笔交易之前， 该 App 内购买项目收据会一直保留在收据内。
/// * 在交易完成后，该 App 内购买项目收据会在下次收据更新时(例如，顾客进行下一次购买，或者您的 App 明确刷新收据时)从收据中移除。
/// * 非消耗型产品、自动续期订阅、非续期订阅或免费订阅的 App 内购买项目收据无限期保留在收据中。
@objc public class UInnIAPReceipt:NSObject, Codable {
    @objc public let bundle_id:String
    @objc public let application_version:String
    
    /// App 内购买项目收据，一组 App 内购买项目收据属性
    /// 注意: 空数组为有效收据。
    /// * 在进行消耗型产品购买时，该 App 内购买项目收据被添加到收据中。
    /// * 在您的 App 完成该笔交易之前， 该 App 内购买项目收据会一直保留在收据内。
    /// * 在交易完成后，该 App 内购买项目收据会在下次收据更新时(例如，顾客进行下一次购买，或者您的 App 明确刷新收据时)从收据中移除。
    /// * 非消耗型产品、自动续期订阅、非续期订阅或免费订阅的 App 内购买项目收据无限期保留在收据中。
    @objc public let in_app:[UInnIAPReceiptInApp]
    
    /// 原始应用程序版本
    /// 最初购买的 App 的版本。
    /// 此值与最初进行购买时Info.plist 文件中的 CFBundleVersion(iOS 中)或 CFBundleShortVersionString(macOS 中)的值相对应。在沙箱技术环境中，这个字段值始终为 “1.0” 。
    @objc public let original_application_version:String
    
    /// App 收据的创建日期。
    /// 验证收据时，使用这个日期验证收据的签名。
    /// 应当确保您的 App 始终使用“收据创建日期”字段中的日期对收据签名进行验证。
    @objc public let receipt_creation_date:String
}

extension UInnIAPReceipt {
    /// 验证收据官方文档：https://developer.apple.com/cn/app-store/Receipt-Validation-Programming-Guide-CN.pdf
    /// 要验证收据，请按顺序执行以下测试:
    /// 1. 找到收据。
    /// 如果没有收据，则验证失败。
    /// 2. 验证收据是否由 Apple 正确签署
    /// 如果收据不是由 Apple 签署，则验证失败。
    /// 3. 验证收据中的 Bundle Identifier(数据包标识符)与在 Info.plist 文件中含有您要的CFBundleIdentifier 值的硬编码常量相匹配。
    /// 如果两者不匹配，则验证失败。
    /// 4. 验证收据中的版本标识符字符串与在 Info.plist 文件中含有您要的 CFBundleShortVersionString值(macOS)或CFBundleVersion 值(iOS)的硬编码常量相匹配。
    /// 如果两者不匹配，则验证失败。
    /// 5. 按照 “计算 GUID 的哈希(Hash) (第 8 页)” 所述计算 GUID 的哈希(Hash)。
    /// 如果结果与收据中的哈希(Hash)不匹配，则验证失败。
    /// 如果通过所有测试，则验证成功。
    internal var isValidated: Bool {
        if !isBundleValidated {
            return false
        }
        
        if !isAppVersionValidated {
            return false
        }
        
        return true
    }
    
    /// 3. 验证收据中的 Bundle Identifier(数据包标识符)与在 Info.plist 文件中含有您要的CFBundleIdentifier 值的硬编码常量相匹配。
    /// 如果两者不匹配，则验证失败。
    private var isBundleValidated:Bool {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            //uu_print("check bundleId: \(bundle_id) == \(bundleIdentifier)")
            return bundle_id == bundleIdentifier
        }
        return false
    }
    
    /// 4. 验证收据中的版本标识符字符串与在 Info.plist 文件中含有您要的 CFBundleShortVersionString值(macOS)或 CFBundleVersion 值(iOS)的硬编码常量相匹配。
    /// 如果两者不匹配，则验证失败。
    private var isAppVersionValidated:Bool {
        //uu_print("check appVersion vs CFBundleShortVersionString: \(application_version) == \(Bundle.main.bbu_bundleShortVersion)")
        let appVersionValidated = application_version == Bundle.main.uu_bundleShortVersion
        
        //uu_print("check appVersion vs CFBundleVersion: \(application_version) == \(Bundle.main.bbu_bundleVersion)")
        let bundleVersionValidated = application_version == Bundle.main.uu_bundleVersion
        
        return appVersionValidated || bundleVersionValidated
    }
    
    /// 5. 按照 “计算 GUID 的哈希(Hash) (第 8 页)” 所述计算 GUID 的哈希(Hash)。
    /// 如果结果与收据中的哈希(Hash)不匹配，则验证失败。
    
}

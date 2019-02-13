//
//  CloudPushSDK+UInnPush.swift
//  UInnPush
//
//  Created by Theo Chen on 11/18/18.
//

import UIKit
import CloudPushSDK

fileprivate let kAliyunPushInfoPlist = "AliyunEmasServices-Info"
fileprivate let kAliyunPushConfig = "config"
fileprivate let kAliyunPushAppKey = "emas.appKey"
fileprivate let kAliyunPushAppSecret = "emas.appSecret"

fileprivate struct EmasPlist: Codable {
    let config:EmasConfig
    private enum CodingKeys: String, CodingKey {
        case config = "config"
    }
}

fileprivate struct EmasConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case appKey = "emas.appKey"
        case appSecret = "emas.appSecret"
    }
    
    let appKey: String
    let appSecret: String
}

public extension CloudPushSDK {

    public static func configure() {
        
        let fileUrl = Bundle.main.url(forResource: kAliyunPushInfoPlist, withExtension: "plist")
        assert(fileUrl != nil, "AliyunEmasServices-Info error: does not exist, 你申请了Aliyun的Push服务，请确保下载了AliyunEmasServices-Info.plist文件，并添加到了工程中")
        
        do {
            let data = try Data(contentsOf: fileUrl!)
            let decoder = PropertyListDecoder()
            let emasPlist = try decoder.decode(EmasPlist.self, from: data)
            
            let appKey = emasPlist.config.appKey
            let appSecret = emasPlist.config.appSecret
            
            CloudPushSDK.asyncInit(appKey, appSecret: appSecret) { (res:CloudPushCallbackResult?) in
                if res?.success ?? false {
                    uu_print("Push SDK init success, deviceId: \(CloudPushSDK.getDeviceId() ?? "None")")
                }
                else {
                    uu_print("Push SDK init failed, error: \(res?.error?.localizedDescription ?? "Unkown Error")")
                }
            }
        }
        catch {
            fatalError("AliyunEmasServices-Infoc error: incorrect plist format --- \(error.localizedDescription)")
        }
    }
}

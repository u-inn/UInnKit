//
//  UInnNetwork.swift
//  UInnKit
//
//  Created by Theo Chen on 12/28/18.
//

import Foundation
import Alamofire

public class UInnNetwork:NSObject {
    
    public static let shared = UInnNetwork()
    
    private override init() {
        super.init()
    }
    
    /// 通过网络请求获得Model
    ///
    /// - parameter: method
    public func loadModel<T>(method: HTTPMethod,
                     url:URLConvertible,
                     body:[String:Any],
                     encoding:ParameterEncoding = URLEncoding.default,
                     headers:[String:String],
                     modelType: T.Type,
                     success: ((T) -> Void)?,
                     fail: ((Error) -> Void)?) where T : Decodable  {
        
        // Fetch Request
        Alamofire.request(url,
                          method: method,
                          parameters: body,
                          encoding: encoding,
                          headers: headers)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                if (response.result.error == nil) {
                    uu_print("HTTP Response Body: \(String(describing: response.result.value))")
                    
                    if let model = response.data?.uu_model(modelType: modelType) {
                        success?(model)
                    }
                    else {
                        let error = DecodingError.dataCorrupted(DecodingError.Context(
                            codingPath: [],
                            debugDescription: "The given data was not valid JSON.",
                            underlyingError: nil)
                        )
                        uu_print(error)
                        fail?(error)
                    }
                }
                else {
                    uu_print("HTTP Request failed: \(String(describing: response.result.error))")
                    
                    fail?(response.result.error!)
                }
        }
    }

}

//
//  Encodable.swift
//  UInnUtilities
//
//  Created by Theo Chen on 12/1/18.
//

public extension JSONSerialization {
    
    /// 将Dictionary转化成JSON string
    ///
    @objc(stringFromDictionary:)
    public static func string(fromDictionary dict:[AnyHashable:Any]?) -> String {
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict ?? [], options: .prettyPrinted)
            let jsonStr = String(data: jsonData, encoding: .utf8)
            
            return jsonStr ?? ""
        }
        catch {
            uu_print("JSONSerialization Error:\(error.localizedDescription)")
        }
        return ""
    }
}

extension Encodable {
    /// 将Codable的model转化成json stirng
    ///
    public var uu_jsonString: String? {
        let jsonEncoder = JSONEncoder()
        do {
            let jsonData = try jsonEncoder.encode(self)
            let jsonString = String(data: jsonData, encoding: .utf8)
            
            return jsonString
        }
        catch {
            uu_print(error.localizedDescription)
        }
        
        return nil
    }
}

/// 将json string转化成model
///
extension String {
    public func uu_model<T>(modelType: T.Type) -> T? where T:Decodable {
        return self.data(using: .utf8)?.uu_model(modelType: modelType)
    }
}

/// 将json data转化成model
///
extension Data {
    public func uu_model<T>(modelType: T.Type) -> T? where T:Decodable {
        
        do {
            let jsonDecoder = JSONDecoder()
            let _model = try jsonDecoder.decode(modelType, from: self)
            return _model
        }
        catch {
            uu_print(error)
            return nil
        }
    }
}


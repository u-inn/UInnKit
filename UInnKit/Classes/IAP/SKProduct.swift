//
//  SKProduct.swift
//  UInnIAP
//
//  Created by Theo Chen on 12/4/18.
//

import StoreKit

/// 商品的类型
///
@objc public enum SKProductType:Int {
    case consumable
    case nonconsumable
    case nonautorenewingSubscription
    case autorenewingSubscription
    case unknown
}

private var productType:SKProductType = .consumable

extension SKProduct {
    var uu_type:SKProductType {
        get {
            if let associatedObject = objc_getAssociatedObject(self, &productType) as? SKProductType {
                return associatedObject
            }
            else {
                objc_setAssociatedObject(self, &productType, SKProductType.unknown.rawValue, .OBJC_ASSOCIATION_RETAIN)
                return .consumable
            }
        }
        set {
            objc_setAssociatedObject(self, &productType, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

//
//  BBUSwizzler.swift
//  UInnUtilities
//
//  Created by Theo Chen on 11/19/18.
//

import ObjectiveC

/// 方法交换的类
///
@objcMembers
public class UInnSwizzler: NSObject {
    
    public static let shared = UInnSwizzler()
    
    private override init() {
        super.init()
    }
    
    // 原来的实现
    var originalImplementations:[String:IMP] = [:]
    
    /// 交换方法
    ///
    public func swizzleSelector(originalSelector:Selector,
                                inClass klass:AnyClass,
                                withMethod swizzledMethod:Method,
                                isClassMethod: Bool) {
        let c: AnyClass
        if isClassMethod {
            guard let c_ = object_getClass(klass) else {
                return
            }
            c = c_
        }
        else {
            c = klass
        }
        
        // 原来有该方法
        if let originalMethod: Method = class_getInstanceMethod(c, originalSelector) {
            let swizzledImplementation = method_getImplementation(swizzledMethod)
            
            let __original_method_implementation:IMP =
                method_setImplementation(originalMethod, swizzledImplementation)
            
            let __nonexistant_method_implementation:IMP? = self.nonExistantMethodImplementation(forClass:klass)
            
            if __original_method_implementation != __nonexistant_method_implementation &&
                __original_method_implementation != swizzledImplementation {
                self.saveOriginalImplementation(imp: __original_method_implementation, forSelector: originalSelector)
            }
        }
        // 原来没有该方法
        else {
            // The class doesn't have this method, so add our swizzled implementation as the
            // original implementation of the original method.
            let swizzledImplementation = method_getImplementation(swizzledMethod)

            let methodAdded = class_addMethod(c, originalSelector, swizzledImplementation, method_getTypeEncoding(swizzledMethod))

            if !methodAdded {
                uu_print("Could not add method for %@ to class %@",
                          NSStringFromSelector(originalSelector),
                          NSStringFromClass(c))
            }
        }
    }
    
    public func swizzleSelector(originalSelector:Selector,
                 inClass klass:AnyClass,
                 withImplementation swizzledImplementation:IMP,
                 inProtocol proto:Protocol) {
        if let originalMethod:Method = class_getInstanceMethod(klass, originalSelector) {
            // This class implements this method, so replace the original implementation
            // with our new implementation and save the old implementation.
    
            let __original_method_implementation:IMP =
                method_setImplementation(originalMethod, swizzledImplementation)
    
            let __nonexistant_method_implementation:IMP? = self.nonExistantMethodImplementation(forClass:klass)
    
            if __original_method_implementation != __nonexistant_method_implementation &&
                __original_method_implementation != swizzledImplementation {
                self.saveOriginalImplementation(imp: __original_method_implementation, forSelector: originalSelector)
            }
        } else {
            // The class doesn't have this method, so add our swizzled implementation as the
            // original implementation of the original method.
            let method_description = protocol_getMethodDescription(proto, originalSelector, false, true)
            
            let methodAdded = class_addMethod(klass, originalSelector, swizzledImplementation, method_description.types)
            if !methodAdded {
                uu_print("Could not add method for %@ to class %@",
                          NSStringFromSelector(originalSelector),
                          NSStringFromClass(klass))
            }
        }
        //[self trackSwizzledSelector:originalSelector ofClass:klass];
    }
    
    // This is useful to generate from a stable, "known missing" selector, as the IMP can be compared
    // in case we are setting an implementation for a class that was previously "unswizzled" into a
    // non-existant implementation.
    func nonExistantMethodImplementation(forClass klass:AnyClass) -> IMP? {
        let nonExistantSelector:Selector = NSSelectorFromString("aNonExistantMethod")
        let nonExistantMethodImplementation:IMP? = class_getMethodImplementation(klass, nonExistantSelector)
        return nonExistantMethodImplementation
    }

    /// 保存原始的实现IMP
    ///
    func saveOriginalImplementation(imp:IMP, forSelector selector:Selector) {
        let selectorString = NSStringFromSelector(selector)
        self.originalImplementations[selectorString] = imp
    }
    
    /// 获取原始的实现IMP
    ///
    public func originalImplementation(forSelector selector:Selector) -> IMP? {
        let selectorString = NSStringFromSelector(selector)
        let imp = self.originalImplementations[selectorString]
        
        return imp
    }
}

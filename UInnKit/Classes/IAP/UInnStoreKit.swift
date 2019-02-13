//
//  StoreObserver.swift
//  UInnIAP
//
//  Created by Theo Chen on 11/24/18.
//

import StoreKit
import RxSwift
import Alamofire

// 在测试环境中，使用
let kSandboxVerifyReceiptURL = "https://sandbox.itunes.apple.com/verifyReceipt"
// 在生产环境中，使用
let kBuyVerifyReceiptURL = "https://buy.itunes.apple.com/verifyReceipt"

public class UInnStoreKit: NSObject {
    
    @objc(sharedInstance)
    public static let shared = UInnStoreKit()
    
    private let disposeBag = DisposeBag()
    
    /// itunesConnectSharedSecret:在itunesconnect中生成App-Specific Shared Secret or Master Shared Secret，在对“自动续期”的订阅，进行receipt校验时候，需要用到
    private var itunesConnectSharedSecret = ""
    private let receiptRequestSubject = PublishSubject<SKRequest>()
    private let receiptRequestErrorSubject = PublishSubject<(SKRequest, Error)>()
    
    private var verifyReceiptURL = kBuyVerifyReceiptURL
    
    private var sandboxVerifyReceiptURL = kSandboxVerifyReceiptURL

    //Initialize the store observer.
    private override init() {
        super.init()
        //Other initialization here.
    }
    
    internal func loadConfigure(with itunesConnectSharedSecret:String) {
        self.itunesConnectSharedSecret = itunesConnectSharedSecret
    }
}

// program mark - 验证收据
extension UInnStoreKit {
    
    /// 刷新凭证
    ///
    /// 会弹出iCloud账户输入框
    internal func refreshReceipt(finishHandler:(()->Void)?=nil,
                               failureHandler:((_ error: Error)->Void)?=nil) {
        var receiptRequest:SKReceiptRefreshRequest? = SKReceiptRefreshRequest()
        receiptRequest?.delegate = self
        receiptRequest?.start()
        
        receiptRequestSubject.filter {
            $0 == receiptRequest
        }.subscribe(onNext: { _ in
            finishHandler?()
            receiptRequest = nil
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
        
        receiptRequestErrorSubject.filter {
            $0.0 == receiptRequest
        }.subscribe(onNext: {
            failureHandler?($1)
            receiptRequest = nil
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
    }

    /// 从设备中读取该App的Receipt
    ///
    internal var receiptData:Data? {
        guard let url = Bundle.main.appStoreReceiptURL else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            return data
        } catch {
            uu_print("Error loading receipt data: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 访问 App Store 解析 receipt
    /// * 注意，Apple推荐 最好有服务器来做这些事，因为这样可以避免 “中间人”攻击
    /// * 如果您没有服务器做支持，那么由客户端进行验证可以是一个暂时的备选方案
    ///
    internal func fetchReadableReceiptFromAppStore(successHandler:@escaping (_ receiptResult:UInnIAPReceiptResult)->Void,
                             failureHandler:@escaping (_ error:UInnIAPReceiptError)->Void) {
        
        self._fetchReadableReceiptFromAppStore(url: self.verifyReceiptURL, successHandler: successHandler, failureHandler: failureHandler)
    }
    
    private func _fetchReadableReceiptFromAppStore(url: URLConvertible, successHandler:@escaping (_ receiptResult:UInnIAPReceiptResult)->Void,
                      failureHandler:@escaping (_ error:UInnIAPReceiptError)->Void) {
        // 获取票据，如果票据为空
        guard let data = self.receiptData else {
            return failureHandler(UInnIAPReceiptError(code: .receiptNotFound))
        }
        
        // Add Headers
        let headers = [
            "Content-Type":"application/json; charset=utf-8",
            ]
        
        // JSON Body
        let body: [String : Any] = [
            "receipt-data": data.base64EncodedString(),
            "password": self.itunesConnectSharedSecret
        ]
        
        // Fetch Request
        Alamofire.request(url, method: .post, parameters: body, encoding: JSONEncoding.default, headers: headers)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                switch response.result {
                case.success( _):
                    //uu_print(json)
                    
                    let jsonDecoder = JSONDecoder()
                    do {
                        let receiptResult = try jsonDecoder.decode(UInnIAPReceiptResult.self, from: response.data!)
                        if receiptResult.isValidated { // 初步验证没有问题
                            successHandler(receiptResult)
                        }
                        else {
                            /// 此收据来自测试环境，但发送到生产环境进行验证。应将其发送到测试环境。
                            if receiptResult.statusError.code == .receiptIsFromSandbox {
                                return self._fetchReadableReceiptFromAppStore(url: self.sandboxVerifyReceiptURL, successHandler: successHandler, failureHandler: failureHandler)
                            }
                            else {
                                failureHandler(receiptResult.statusError)
                            }
                        }
                    }
                    catch {
                        uu_print(error, error.localizedDescription)
                        failureHandler(UInnIAPReceiptError(code: .receiptInvalid))
                    }
                    
                case.failure(let error):
                    uu_print("HTTP Request failed: \(error)")
                    failureHandler(UInnIAPReceiptError(code: .receiptRequestFailed))
                }
        }
    }
    
    /// 在购买过程中验证
    /// * 注意，1. 这个是通过App Store返回的解析进行验证的
    /// * 注意，2. 这个验证逻辑只有在购买时候有效，对4种商品类型都适用
    ///
    /// - parameter transaction:SKPaymentTransaction
    /// 当前购买的交易信息
    /// - parameter receiptResult:BBIReceiptResult
    /// 从App Store服务器返回的Receipt的解析类
    ///
    /// - return BBIReceiptInApp:
    ///
    internal func verifyPurchase(transaction:SKPaymentTransaction, with receiptResult:UInnIAPReceiptResult) -> Bool {
        guard let receipt = receiptResult.receipt else {
            return false
        }
        
        let receiptInApp = receipt.in_app.filter {
            // 先判断transaction_id是不是正确
            let isTransactionIdCorrect = $0.transaction_id == transaction.transactionIdentifier ||
                $0.transaction_id == transaction.original?.transactionIdentifier || $0.original_transaction_id == transaction.original?.transactionIdentifier // 如果是重复购买，则需要判断original transaction_id是不是正确

            // 同时，不能有取消日期
            let isNoCancellationDate = $0.cancellation_date == nil
            
            return isTransactionIdCorrect && isNoCancellationDate
        }
        
        return !receiptInApp.isEmpty
    }
    
    /// 在恢复过程中验证
    /// * 注意，1. 这个是通过App Store返回的解析进行验证的
    /// * 注意，2. 这个验证逻辑只有在restore时候有效，对2种商品类型都适用（cosumable 和 non-auto renew subscription的产品不会在restore中出现）
    ///
    /// - parameter transaction: SKPaymentTransaction 当前购买的交易信息
    /// - parameter receiptResult: BBIReceiptResult 从App Store服务器返回的Receipt的解析类
    ///
    /// - returns: 是否通过验证
    internal func verifyRestore(transaction:SKPaymentTransaction, with receiptResult:UInnIAPReceiptResult) -> Bool {
        guard let receipt = receiptResult.receipt else {
            return false
        }
        
        let receiptInApp = receipt.in_app.filter {
            // product_id 需是transaction指定的product_id
            $0.product_id == transaction.payment.productIdentifier
        }.filter {
            // original_transaction_id 必须一致
            $0.original_transaction_id == transaction.transactionIdentifier
        }.filter {
            // 不能有取消日期
            $0.cancellation_date == nil
        }.filter {
            // 如果有 expires_date，则必须没有到期
            if let expiresDate = $0.expiresDate {
                return expiresDate >= Date()
            }
            return true
        }
        
        return !receiptInApp.isEmpty
    }
    
    /// 该用户对某个“自动续费”的商品的最后一次订阅的详细收据
    ///
    /// * 注意，1. 这个是通过App Store返回的解析进行验证的（我们建议如果交由您自己的服务器处理，也能返回相同的格式）
    /// * 注意，2. 这个只适用（auto renew subscription）的产品
    ///
    /// - parameter autoRenewingProductIdentifier:String 商品的productIdentifier，这个值必须和SKProduct或者SKPayment中的productIdentifier一致
    /// - parameter receiptResult: BBIReceiptResult 从App Store服务器返回的Receipt的解析类
    ///
    /// - returns: 该用户对该商品的订阅的最后一次票据
    internal func lastReceipt(of autoRenewingProductIdentifier:String, with receiptResult:UInnIAPReceiptResult) -> UInnIAPReceiptInApp? {
        guard let receipt = receiptResult.receipt else {
            return nil
        }
        
        let receiptInApp = receipt.in_app.filter {
            // product_id 需是productIdentifier
            $0.product_id == autoRenewingProductIdentifier
        }.filter {
            $0.expiresDate != nil
        }.sorted {
            $0.expiresDate! >= $1.expiresDate!
        }.first
        
        return receiptInApp
    }
    
    /// 该用户对“自动续费”的商品的订阅是否过期 是否过期
    ///
    /// * 注意，1. 这个是通过App Store返回的解析进行验证的
    /// * 注意，2. 这个只适用（auto renew subscription）的产品
    ///
    /// - parameter productIdentifier:String 商品的productIdentifier，这个值必须和SKProduct或者SKPayment中的productIdentifier一致
    /// - parameter receiptResult: BBIReceiptResult 从App Store服务器返回的Receipt的解析类
    ///
    /// - returns: 该用户对该商品的订阅是否过期
    internal func isExpired(productIdentifier:String, with receiptResult:UInnIAPReceiptResult) -> Bool {
        if let receiptInApp = self.lastReceipt(of: productIdentifier, with: receiptResult) {
            return receiptInApp.expiresDate! < Date()
        }
        
        return true
    }
    
    /// 该用户对“非消费型商品”是否购买过
    ///
    /// * 注意，1. 这个是通过App Store返回的解析进行验证的
    /// * 注意，2. 这个只适用（non-consuming）的产品，如果传入的nonconsumingProductIdentifier不是“非消费型商品”的ID，那么返回的结果将是不可靠的
    ///
    /// - parameter nonconsumingProductIdentifier:String 商品的productIdentifier，这个值必须和SKProduct或者SKPayment中的productIdentifier一致
    /// - parameter receiptResult: BBIReceiptResult 从App Store服务器返回的Receipt的解析类
    ///
    /// - returns: 该用户对该商品的订阅是否过期
    internal func isPurchased(nonconsumingProductIdentifier:String, with receiptResult:UInnIAPReceiptResult) -> Bool {
        guard let receipt = receiptResult.receipt else {
            return false
        }
        
        let receiptInApp = receipt.in_app.filter {
            // product_id 需是productIdentifier
            $0.product_id == nonconsumingProductIdentifier
        }.filter {
            $0.expiresDate == nil && $0.cancellation_date == nil
        }
        
        return receiptInApp.count > 0
    }
}

/// Program Mark - SKRequestDelegate
extension UInnStoreKit:SKRequestDelegate {
    public func requestDidFinish(_ request: SKRequest) {
        receiptRequestSubject.onNext(request)
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        receiptRequestErrorSubject.onNext((request, error))
    }
}


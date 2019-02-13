//
//  UInnIAP.swift
//  UInnIAP
//
//  Created by Theo Chen on 11/24/18.
//

import StoreKit
import RxSwift

public class UInnIAP:NSObject {
    @objc(sharedInstance)
    public static let shared = UInnIAP()
    
    private let disposeBag = DisposeBag()
    
    /// itunesConnectSharedSecret
    ///
    /// 如果涉及到自动续约的内购，必须需要，可以在itunes connect中找到他
    private var itunesConnectSharedSecret = ""
    private var needReceiptVerification = true
    
    // 在途restore的products
    private var ongoingRestoreProductIdentifiers:Set<String> = []
    
    /// RAC 的 Subjects
    private var productsRequestSubject = PublishSubject<(SKProductsRequest, SKProductsResponse)>()
    private var productsRequestFailedSubject = PublishSubject<(SKProductsRequest, Error)>()

    private var purchasedTransactionSubject = PublishSubject<(SKPaymentTransaction, UInnIAPReceiptResult?)>()
    
    /// 恢复购买:成功的每条交易
    private var restoredTransactionSubject = PublishSubject<(SKPaymentTransaction, UInnIAPReceiptResult?)>()
    /// 恢复购买失败的Subject
    private var restoredFailedTransactionSubject = PublishSubject<(SKPaymentTransaction, Error)>()
    
    /// 恢复购买:所有完成下单的交易
    private var restoreTransactionsFinishedSubject = PublishSubject<[SKPaymentTransaction]>()
    
    
    /// 恢复购买失败的Subject
    private var restoreCompletedFailedTransactionsSubject = PublishSubject<([SKPaymentTransaction], Error)>()
    
    /// 交易失败的Subject
    private var failedTransactionSubject = PublishSubject<(SKPaymentTransaction, Error)>()
    
    /// 购买中的Subject
    private var purchasingTransactionSubject = PublishSubject<SKPaymentTransaction>()
    
    /// 推迟交易的Subject
    private var deferredTransactionSubject = PublishSubject<SKPaymentTransaction>()
    
    //Initialize the store observer.
    private override init() {
        super.init()
        //Other initialization here.
    }
    
    /// 配置UInnIAP
    ///
    /// - parameter itunesConnectSharedSecret:
    /// 可选参数：itunesConnectSharedSecret 可以是"app-specific shared secret" 或 "master shared secret"
    /// 所谓“app-specific shared secret” 是一个唯一代码，比如“1e88d420308b44959050606fc8d32b95”，如果你提供的内购是“auto-renewable subscriptions”这个类型，那么这个代码是用来做收据验证的，每个App有且仅能配置一个“app-specific shared secret”
    /// "master shared secret"的用法和“app-specific shared secret”一致，区别在于，当你一个itunesconnect账号下有多款App，那么这个"master shared secret"是可以通用的，每个itunesconnect账号有且仅能配置一个“master shared secret”
    /// - parameter needReceiptVerification:
    /// needReceiptVerification 如果设置为false（推荐），则由您自己去处理票据的验证，SDK将不负责验证
    @objc public func loadConfigure(itunesConnectSharedSecret:String = "", needReceiptVerification:Bool = true) {
        
        self.itunesConnectSharedSecret = itunesConnectSharedSecret
        self.needReceiptVerification = needReceiptVerification
        
        UInnStoreKit.shared.loadConfigure(with:itunesConnectSharedSecret)
        
        // Add a transaction queue observer at application launch
        // StoreKit attaches your observer to the payment queue when your app calls
        SKPaymentQueue.default().add(self)
        
        let application = UIApplication.uu_shared!
        
        // Called when the application is about to terminate.
        let method = class_getInstanceMethod(UInnIAP.self, #selector(UInnIAP.uuiap_applicationWillTerminate(_:)))
        let imp = method_getImplementation(method!)
        UInnSwizzler.shared.swizzleSelector(originalSelector: #selector(UIApplicationDelegate.applicationWillTerminate(_:)), inClass: type(of: application.delegate!), withImplementation: imp, inProtocol: UIApplicationDelegate.self)
    }
    
    /// 购买：一次性消费的购买，或者非一次性消费的购买，不包括（自动续期/非自动续期的订阅）
    /// 
    /// - parameter applicationUsername:
    /// 建议加入applicationUsername，可以是你当前的用户名，这样来帮助app store去初步查验出一些不合规的行为
    /// Apple原文建议如下: Use this property to help the store detect irregular activity. For example, in a game, it would be unusual for dozens of different iTunes Store accounts to make purchases on behalf of the same in-game character.
    /// The recommended implementation is to use a one-way hash of the user’s account name to calculate the value for this property.
    @objc public func purchase(product:SKProduct, applicationUsername:String?,
                               onPurchased:((SKPaymentTransaction, UInnIAPReceiptResult?)->Void)?,
                               onShowingTransactionAsInProgress:((_ deferred:Bool)->Void)?,
                               onFailed:((_ transaction:SKPaymentTransaction, _ error:Error)->Void)?
        ) {
        
        // 拦截不能购买的情况
        guard SKPaymentQueue.canMakePayments() else {
            return
        }
        
        // Create a payment request.
        let payment = SKMutablePayment(product: product)
        payment.applicationUsername = applicationUsername
        
        // Submit the payment request to the payment queue.
        SKPaymentQueue.default().add(payment)
        
        // First, we create a group to synchronize our tasks
        let group = DispatchGroup()
        group.enter()
        
        // 完成了购买
        let purchasedTransactionSubjectDiposable =  purchasedTransactionSubject.filter {
            $0.0.payment == payment
        }.subscribe(onNext: { (transaction, receiptResult) in
            onPurchased?(transaction, receiptResult)
            
            group.leave()
        }, onError: nil, onCompleted: nil, onDisposed: nil)
        
        // 购买失败了
        let failedTransactionSubjectDiposable = failedTransactionSubject.filter {
            $0.0.payment == payment
        }.subscribe(onNext: {
            onFailed?($0, $1)
            
            group.leave()
        }, onError: nil, onCompleted: nil, onDisposed: nil)

        // 正在购买中
        let purchasingTransactionSubjectDiposable =  purchasingTransactionSubject.filter {
            $0.payment == payment
        }.subscribe(onNext: { (_) in
            onShowingTransactionAsInProgress?(false)
        }, onError: nil, onCompleted: nil, onDisposed: nil)
        
        // 推迟购买中（家长控制，需要家长审批）
        let deferredTransactionSubjectDiposable = deferredTransactionSubject.filter {
            $0.payment == payment
        }.subscribe(onNext: { (_) in
            onShowingTransactionAsInProgress?(true)
        }, onError: nil, onCompleted: nil, onDisposed: nil)
        
        defer {
            group.notify(queue: .main) {
                purchasedTransactionSubjectDiposable.dispose()
                failedTransactionSubjectDiposable.dispose()
                purchasingTransactionSubjectDiposable.dispose()
                deferredTransactionSubjectDiposable.dispose()
            }
        }
    }
    
    /// 恢复指定的非消费型商品购买
    ///
    /// 如果您调用该接口，确保您传入的商品必须是non-consumable（非消费型）商品
    @objc(restorePurchasesWithApplicationUsername:onRestoredEachTransaction:onFailedEachTransaction:onRestoredOrderPlaced:)
    public func restorePurchases(applicationUsername:String?=nil,
                                 onRestoredEachTransaction:((SKPaymentTransaction, UInnIAPReceiptResult?, Bool)->Void)?,
                                 onFailedEachTransaction:((SKPaymentTransaction, Error, Bool)->Void)?,
                                    onRestoredOrderPlaced:(([SKPaymentTransaction], Error?)->Void)?) {
        
        self.ongoingRestoreProductIdentifiers.removeAll()
        // Restore Consumables and Non-Consumables from Apple
        SKPaymentQueue.default().restoreCompletedTransactions(withApplicationUsername: applicationUsername)
        
        // First, we create a group to synchronize our tasks
        let group = DispatchGroup()
        group.enter()
        
        // restore完成了
        let restoredTransactionSubjectDisposable = restoredTransactionSubject.subscribe(onNext: { [unowned self] (transaction, receiptResult) in
            // productIdentifiers是否已经为空
            let isCompleted = self.ongoingRestoreProductIdentifiers.isEmpty
            if isCompleted {
                group.leave()
            }
            onRestoredEachTransaction?(transaction, receiptResult, isCompleted)
        }, onError: nil, onCompleted: nil, onDisposed: nil)
        
        // restore失败了
        let restoredFailedTransactionSubjectDisposable =  restoredFailedTransactionSubject.subscribe(onNext: { [unowned self] (transaction, error) in
            uu_print(transaction, error)

            // productIdentifiers是否已经为空
            let isCompleted = self.ongoingRestoreProductIdentifiers.isEmpty
            if isCompleted {
                group.leave()
            }
            onFailedEachTransaction?(transaction, error, isCompleted)
        }, onError: nil, onCompleted: nil, onDisposed: nil)
        
        // 所有restore order被下单了，成功了
        let restoreTransactionsFinishedSubjectDisposable = restoreTransactionsFinishedSubject.subscribe(onNext: {
            onRestoredOrderPlaced?($0, nil)
        }, onError: nil, onCompleted: nil, onDisposed: nil)
        
        // 所有restore order被下单了，失败的返回
        let restoreCompletedFailedTransactionsSubjectDisposable = restoreCompletedFailedTransactionsSubject.subscribe(onNext: {
            onRestoredOrderPlaced?($0, $1)
            group.leave()
        }, onError: nil, onCompleted: nil, onDisposed: nil)
        
        defer {
            group.notify(queue: .main) {
                restoredTransactionSubjectDisposable.dispose()
                restoredFailedTransactionSubjectDisposable.dispose()
                restoreTransactionsFinishedSubjectDisposable.dispose()
                restoreCompletedFailedTransactionsSubjectDisposable.dispose()
            }
        }
    }
}

// pragram mark - SKPaymentTransactionObserver
extension UInnIAP: SKPaymentTransactionObserver {
    
    // Observe transaction updates.
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        self.ongoingRestoreProductIdentifiers = Set(transactions.filter {
            $0.transactionState == .restored && $0.original != nil
        }.compactMap {
            $0.original!.payment.productIdentifier
        })
        
        //Handle transaction states here.
        for transaction in transactions {
            switch transaction.transactionState {
            // Call the appropriate custom method for the transaction state.
            case .purchased:
                // Provide the purchased functionality
                purchased(transaction: transaction, in:queue)
            case .purchasing:
                // Update your UI to reflect the in-progress status, and wait to be called again.
                transactionInProgress(transaction: transaction)
            case .failed:
                failed(transaction: transaction, in: queue)
            case .restored:
                // Restore the previously purchased functionality
                restored(transaction: transaction, in: queue)
            case .deferred:
                // Update your UI to reflect the deferred status, and wait to be called again.
                transactionInProgress(transaction: transaction, isDeferred: true)
            }
        }
    }
    
    /// Tells the observer that an error occurred while restoring transactions.
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        uu_print(error, error.localizedDescription)
        restoreCompletedFailedTransactionsSubject.onNext((queue.transactions, error))
    }
    
    /// This method is called after all restorable transactions have been processed by the payment queue.
    /// Your application is not required to do anything in this method.
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        restoreTransactionsFinishedSubject.onNext(queue.transactions)
    }
    
    /// Continuing a Transaction from the App Store
    /// When a user taps or clicks Buy on an in-app purchase on the App Store, StoreKit automatically opens your app and sends the transaction information to your app
    /// To defer a transaction:
     
    /// Save the payment to use when the app is ready. The payment already contains information about the product. Do not create a new SKPayment with the same product.
    /// Return false.
    /// After the user is finished with onboarding or other actions that required a deferral, send the saved payment to the payment queue, the same way you would with a normal in-app purchase.
    /// To cancel a transaction:
    /// Return false.
    /// (Optional) Provide feedback to the user. Otherwise, the app’s lack of action after the user taps or clicks Buy in the App Store may seem like a bug.
    public func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        
//        // ... Add code here to check if your app must defer the transaction.
//        let shouldDeferPayment = false
//        // If you must defer until onboarding is completed, then save the payment and return false.
//        if shouldDeferPayment {
//            //self.savedPayment = payment
//            //return false
//        }
//        
//        // ... Add code here to check if your app must cancel the transaction.
//        let shouldCancelPayment = false
//        // If you must cancel the transaction, then return false:
//        if shouldCancelPayment {
//            //return false
//        }
        
        // (If you canceled the transaction, provide feedback to the user.)
        
        // Continuing a previously deferred payment
        // SKPaymentQueue.default().add(savedPayment)
        
        // Check to see if you can complete the transaction.
        // Return true if you can.
        return true
    }
    
    private func purchased(transaction:SKPaymentTransaction, in queue: SKPaymentQueue) {
        //uu_print("purchased...\(transaction.payment.productIdentifier)")
        
        // 利用SDK，进行票据验证
        if needReceiptVerification {
            UInnStoreKit.shared.fetchReadableReceiptFromAppStore(successHandler: { (receiptResult) in
                if UInnStoreKit.shared.verifyPurchase(transaction: transaction, with: receiptResult) {
                    self.purchasedTransactionSubject.onNext((transaction, receiptResult))
                    
                    // 这里成功后就finishTransaction是很不厚道的，因为还没in-app内容还没发放完成，不过，先收钱再说了
                    queue.finishTransaction(transaction)
                }
                else {
                    self.receiptVerifyFailedInPurchase(with: UInnIAPReceiptError(code: .receiptVerifyFailed), in: transaction, in: queue)
                }
                
            }) { (error) in
                self.receiptVerifyFailedInPurchase(with: error, in: transaction, in: queue)
            }
        }
        // 自行进行票据验证
        else {
            self.purchasedTransactionSubject.onNext((transaction, nil))
            queue.finishTransaction(transaction)
        }
    }
    
    private func restored(transaction: SKPaymentTransaction, in queue: SKPaymentQueue) {
        guard let _ = transaction.original?.payment.productIdentifier else { return }
        //uu_print("restored ...\(productIdentifier)")
        
        // 如果需要sdk做票据验证
        if self.needReceiptVerification {
            UInnStoreKit.shared.fetchReadableReceiptFromAppStore(successHandler: { [unowned self] (receiptResult) in
                if UInnStoreKit.shared.verifyRestore(transaction: transaction.original!, with: receiptResult) {
                    // 删除在途的restore产品
                    if self.ongoingRestoreProductIdentifiers.contains(transaction.payment.productIdentifier) {
                        self.ongoingRestoreProductIdentifiers.remove(transaction.payment.productIdentifier)
                        self.restoredTransactionSubject.onNext((transaction, receiptResult))
                    }
                    
                    queue.finishTransaction(transaction)
                }
                else {
                    self.receiptVerifyFailedInRestore(with:UInnIAPReceiptError(code: .receiptVerifyFailed), in: transaction, in: queue)
                }
            }) { (error) in
                self.receiptVerifyFailedInRestore(with: error, in: transaction, in: queue)
            }
        }
        // 如果不需要sdk做票据验证，自己handle验证
        else {
            // 删除在途的restore产品
            if self.ongoingRestoreProductIdentifiers.contains(transaction.payment.productIdentifier) {
                self.ongoingRestoreProductIdentifiers.remove(transaction.payment.productIdentifier)
                self.restoredTransactionSubject.onNext((transaction, nil))
            }
            queue.finishTransaction(transaction)
        }
    }
    
    private func failed(transaction:SKPaymentTransaction, in queue:SKPaymentQueue) {
        // Use the value of the error property to present a message to the user. For a list of error constants, see SKErrorDomain
        let payment = transaction.payment
        let productIdentifier = payment.productIdentifier
        
        var iapError = UInnIAPError(code: .unknown)

        if let error = transaction.error as? SKError {
            switch (error.code) {
            case .clientInvalid:
                iapError = UInnIAPError(code: .clientInvalid)
            case .cloudServiceRevoked:
                iapError = UInnIAPError(code: .cloudServiceRevoked)
            case .cloudServicePermissionDenied:
                iapError = UInnIAPError(code: .cloudServicePermissionDenied)
            case .paymentCancelled:
                iapError = UInnIAPError(code: .paymentCancelled)
            case .paymentInvalid:
                iapError = UInnIAPError(code: .paymentInvalid)
            case .paymentNotAllowed:
                iapError = UInnIAPError(code: .paymentNotAllowed)
            case .storeProductNotAvailable:
                iapError = UInnIAPError(code: .storeProductNotAvailable)
            case .cloudServiceNetworkConnectionFailed:
                iapError = UInnIAPError(code: .cloudServiceNetworkConnectionFailed)
            case .unknown:
                iapError = UInnIAPError(code: .unknown)
            }
            uu_print("transaction failed with product %@ and error %@", productIdentifier, error)
        }
        
        /// 如果交易失败了，transaction.error一定有error，但是为了防止万一，如果失败了，但transaction.error没有error，那么我们返回UInnIAPError.unknown
        failedTransactionSubject.onNext((transaction, iapError))
        // ok，This transaction should be finished with failure
        queue.finishTransaction(transaction)
    }
    
    private func receiptVerifyFailedInPurchase(with error: UInnIAPReceiptError, in transaction:SKPaymentTransaction, in queue: SKPaymentQueue) {
        // 票据没有通过验收，也许是网络不好，也许是票据校验不通过，error中有详细信息
        failedTransactionSubject.onNext((transaction, error))
        // ok，This transaction should be finished with failure
        queue.finishTransaction(transaction)
    }
    
    private func receiptVerifyFailedInRestore(with error: UInnIAPReceiptError, in transaction:SKPaymentTransaction, in queue: SKPaymentQueue) {
        // 票据没有通过验收，也许是网络不好，也许是票据校验不通过，error中有详细信息
        // 删除在途的restore产品
        if self.ongoingRestoreProductIdentifiers.contains(transaction.payment.productIdentifier) {
            self.ongoingRestoreProductIdentifiers.remove(transaction.payment.productIdentifier)
            restoredFailedTransactionSubject.onNext((transaction, error))
        }
        // ok，This transaction should be finished with failure
        queue.finishTransaction(transaction)
    }
    
    private func transactionInProgress(transaction:SKPaymentTransaction, isDeferred deferred:Bool=false) {
        // Update your UI to reflect the in-progress status, and wait to be called again.
        if deferred {
            deferredTransactionSubject.onNext(transaction)
        }
        else {
            purchasingTransactionSubject.onNext(transaction)
        }
    }
    
    @objc public func onPurchased(completionHandler:@escaping (SKPaymentTransaction, UInnIAPReceiptResult?)->Void) {
        self.purchasedTransactionSubject.subscribe(onNext: {
            completionHandler($0, $1)
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
    }
    
    /// 当恢复购买成功后，会被调用
    ///
    /// -parameter: completionHandler 回调函数， SKPaymentTransaction 为transaction交易对象，Bool 为isCompleted代表 restore流程是否完成
    @objc public func onRestored(completionHandler:@escaping (SKPaymentTransaction, UInnIAPReceiptResult?, Bool)->Void) {
        self.restoredTransactionSubject.subscribe(onNext: { [unowned self] (transaction, receiptResult) in
            let isCompleted = self.ongoingRestoreProductIdentifiers.isEmpty
            
            completionHandler(transaction, receiptResult, isCompleted)
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
    }
    
    @objc public func onFailedInPurchase(completionHandler:@escaping (SKPaymentTransaction, Error)->Void) {
        self.failedTransactionSubject.subscribe(onNext: { transaction, error in
            completionHandler(transaction, error)
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
    }
    
    @objc public func onFailedInRestore(completionHandler:@escaping (SKPaymentTransaction, Error, Bool)->Void) {
        self.restoredFailedTransactionSubject.subscribe(onNext: { [unowned self] transaction, error in
            let isCompleted = self.ongoingRestoreProductIdentifiers.isEmpty
            
            completionHandler(transaction, error, isCompleted)
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
    }
    
    /// 所有的restore都被成功下单
    ///
    @objc public func onRestoreOrderPlaced(completionHandler:((_ transactions:[SKPaymentTransaction], _ error:Error?)->Void)?) {
    
        // 所有restore order被下单了，成功了
        restoreTransactionsFinishedSubject.subscribe(onNext: {
            //uu_print($0)
            completionHandler?($0, nil)
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)
        
        // 所有restore order被下单了，失败的返回
        restoreCompletedFailedTransactionsSubject.subscribe(onNext: {
            //uu_print($0, $1)
            completionHandler?($0, $1)
        }, onError: nil, onCompleted: nil, onDisposed: nil).disposed(by: disposeBag)

    }
}

// pragram mark - Method Swizzle
extension UInnIAP {
    @objc public func uuiap_applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        uu_print("bbi_applicationWillTerminate")
        // Remove the observer.
        SKPaymentQueue.default().remove(self)
        
        // 接下去执行AppDelegate中原有的逻辑
        let originalSelector = #selector(UIApplicationDelegate.applicationWillTerminate(_:))
        if let imp = UInnSwizzler.shared.originalImplementation(forSelector: originalSelector) {
            typealias originalFunction = @convention(c) (AnyObject, Selector, UIApplication) -> Void
            let curriedImplementation = unsafeBitCast(imp, to: originalFunction.self)
            curriedImplementation(application.delegate!, originalSelector, application)
        }
    }
}

// pragram mark - SKProductsRequestDelegate
extension UInnIAP: SKProductsRequestDelegate {
    
    /// Fetch information about your products from the App Store.
    ///
    /// - parameter productIdentifiers:[String]
    /// 商品的productIdentifier列表
    /// * 知道每件商品的productIdentifier和商品类型是客户端的责任
    @objc(fetchProductsFromAppStoreWithProductIdentifiers:fetchedHandler:)
    public func fetchProductsFromAppStore(productIdentifiers: [String],
                                          fetchedHandler:@escaping (_ products:[SKProduct], _ invalidProductIdentifiers:[String]) -> Void) {
        self.fetchProductsFromAppStore(productIdentifiers: productIdentifiers, fetchedHandler: fetchedHandler, failureHandler:nil)
    }
    
    @objc(fetchProductsFromAppStoreWithProductIdentifiers:fetchedHandler:failureHandler:)
    public func fetchProductsFromAppStore(productIdentifiers: [String],
                                          fetchedHandler:@escaping (_ products:[SKProduct], _ invalidProductIdentifiers:[String]) -> Void, failureHandler:((Error)->Void)?=nil) {
        // Create a set for your product identifiers.
        let productIdentifiers = Set(productIdentifiers)
        // Initialize the product request with the above set.
        var productRequest:SKProductsRequest? = SKProductsRequest(productIdentifiers: productIdentifiers)
        productRequest?.delegate = self
        
        // Send the request to the App Store.
        productRequest?.start()
        
        // First, we create a group to synchronize our tasks
        let group = DispatchGroup()
        group.enter()
        
        let productsRequestSubjectDisposable = productsRequestSubject.filter {
            $0.0 == productRequest
        }.subscribe(onNext: {
            // Use availableProducts to populate your UI.
            let availableProducts = $1.products
            // No purchase will take place if there are no products available for sale.
            // As a result, StoreKit won't prompt your customer to authenticate their purchase.
            fetchedHandler(availableProducts, $1.invalidProductIdentifiers)
            
            productRequest = nil
            group.leave()
        }, onError: nil, onCompleted: nil, onDisposed: nil)
        
        let productsRequestFailedSubjectDisposable = productsRequestFailedSubject.filter {
            $0.0 == productRequest
        }.subscribe(onNext: {
            failureHandler?($1)
            productRequest = nil
            group.leave()
        }, onError: nil, onCompleted: nil, onDisposed: nil)
        
        defer {
            group.notify(queue: .main) {
                productsRequestSubjectDisposable.dispose()
                productsRequestFailedSubjectDisposable.dispose()
            }
        }
    }
    
    // Get the App Store's response
    @objc public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        
        productsRequestSubject.onNext((request, response))
    }
    
    @objc public func requestDidFinish(_ request: SKRequest) {
        uu_print("requestDidFinish")
    }
    
    @objc public func request(_ request: SKRequest, didFailWithError error: Error) {
        uu_print("request:didFailWithError")
        if let request = request as? SKProductsRequest {
            productsRequestFailedSubject.onNext((request, error))
        }
    }
}

// program mark - Receipt related
extension UInnIAP {
    /// 从设备中读取该App的Receipt
    ///
    @objc public var receiptData:Data? {
        return UInnStoreKit.shared.receiptData
    }
    
    /// 从设备中读取该App的Receipt的base64 string
    ///
    @objc public var receiptDataBase64:String? {
        return UInnStoreKit.shared.receiptData?.base64EncodedString()
    }
    
    /// 刷新凭证
    ///
    /// 会弹出iCloud账户输入框
    @objc public func refreshReceipt(finishHandler:(()->Void)?=nil,
                               failureHandler:((_ error: Error)->Void)?=nil) {
        UInnStoreKit.shared.refreshReceipt(finishHandler: finishHandler, failureHandler: failureHandler)
    }
    
    /// 访问 App Store 解析 receipt
    /// * 注意，Apple推荐 最好有服务器来做这些事，因为这样可以避免 “中间人”攻击
    /// * 如果您没有服务器做支持，那么由客户端进行验证可以是一个暂时的备选方案
    ///
    @objc public func fetchReadableReceiptFromAppStore(successHandler:@escaping (_ receiptResult:UInnIAPReceiptResult)->Void,
                                                 failureHandler:@escaping (_ error:UInnIAPReceiptError)->Void) {
        
        UInnStoreKit.shared.fetchReadableReceiptFromAppStore(successHandler: successHandler, failureHandler: failureHandler)
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
    @objc public func lastReceipt(of autoRenewingProductIdentifier:String, with receiptResult:UInnIAPReceiptResult) -> UInnIAPReceiptInApp? {
        return UInnStoreKit.shared.lastReceipt(of: autoRenewingProductIdentifier, with: receiptResult)
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
    @objc public func isExpired(productIdentifier:String, with receiptResult:UInnIAPReceiptResult) -> Bool {
        return UInnStoreKit.shared.isExpired(productIdentifier: productIdentifier, with: receiptResult)
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
    @objc public func isPurchased(nonconsumingProductIdentifier:String, with receiptResult:UInnIAPReceiptResult) -> Bool {
        return UInnStoreKit.shared.isPurchased(nonconsumingProductIdentifier:nonconsumingProductIdentifier, with:receiptResult)
    }
}

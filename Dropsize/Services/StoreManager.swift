import StoreKit
import Observation

@Observable
public final class StoreManager {
    public static let shared = StoreManager()
    
    public var products: [Product] = []
    public var purchasedProductIDs = Set<String>()
    
    private let productIDs = [
        "com.kwh.dropsize.weekly",
        "com.kwh.dropsize.yearly"
    ]
    
    private var transactionListenerTask: Task<Void, Never>? = nil
    
    private init() {
        transactionListenerTask = listenForTransactions()
        
        Task {
            await requestProducts()
            await updatePurchaseStatus()
        }
    }
    
    deinit {
        transactionListenerTask?.cancel()
    }
    
    public func requestProducts() async {
        do {
            let loadedProducts = try await Product.products(for: productIDs)
            self.products = loadedProducts.sorted(by: { $0.price < $1.price })
        } catch {
            print("StoreKit: Failed to fetch products: \(error)")
        }
    }
    
    public func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchaseStatus()
            await transaction.finish()
            return transaction
        case .userCancelled:
            return nil
        case .pending:
            return nil
        @unknown default:
            return nil
        }
    }
    
    public func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchaseStatus()
    }
    
    public var hasPremiumAccess: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    public func updatePurchaseStatus() async {
        var purchased = Set<String>()
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            } catch {
                print("StoreKit: Transaction verification failed: \(error)")
            }
        }
        
        self.purchasedProductIDs = purchased
        UserDefaultsManager.shared.isPremium = !purchased.isEmpty
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    await self?.updatePurchaseStatus()
                    await transaction?.finish()
                } catch {
                    print("StoreKit: Background transaction error: \(error)")
                }
            }
        }
    }
}

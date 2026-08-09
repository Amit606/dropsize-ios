import StoreKit
import Observation

@Observable
@MainActor
public final class StoreManager {
    public static let shared = StoreManager()
    
    public var products: [Product] = []
    public var purchasedProductIDs = Set<String>()
    
    private let productIDs = [
        "com.kwh.dropsize.weekly",
        "com.kwh.dropsize.yearly"
    ]
    
    private let transactionListenerTask: Task<Void, Never>
    
    private init() {
        // Assign the task before calling other async methods in task group
        let listener = Task.detached(priority: .background) {
            for await result in Transaction.updates {
                do {
                    // Access checkVerified via static or nonisolated method
                    let transaction = try StoreManager.checkVerified(result)
                    await StoreManager.shared.updatePurchaseStatus()
                    await transaction.finish()
                } catch {
                    print("StoreKit: Background transaction error: \(error)")
                }
            }
        }
        self.transactionListenerTask = listener
        
        Task {
            await requestProducts()
            await updatePurchaseStatus()
        }
    }
    
    deinit {
        transactionListenerTask.cancel()
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
            let transaction = try Self.checkVerified(verification)
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
                let transaction = try Self.checkVerified(result)
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
    
    private nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}

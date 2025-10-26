import Foundation

// Lightweight abstractions so tests don't require StoreKit.
public struct ProductInfo: Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let displayPrice: String
    public let isSubscription: Bool
    public let subscriptionPeriodUnit: String? // e.g., "month", "year"
    public let subscriptionPeriodValue: Int?
}

public struct PurchaseResult {
    public let success: Bool
    public let transactionID: String?
    public let errorDescription: String?
}

public struct TransactionUpdate {
    public let productID: String
    public let isRevoked: Bool
}

public protocol StoreKitProviding {
    func loadProducts(ids: [String]) async throws -> [ProductInfo]
    func purchase(productId: String) async throws -> PurchaseResult
    func restore() async throws -> Bool
    func currentEntitlementProductIds() async throws -> Set<String>
    var transactionUpdates: AsyncStream<TransactionUpdate> { get }
}

#if !canImport(StoreKit)
/// Default no-op provider for platforms without StoreKit.
public final class NoopStoreKitProvider: StoreKitProviding {
    public init() {}
    public var transactionUpdates: AsyncStream<TransactionUpdate> { AsyncStream { _ in } }
    public func loadProducts(ids: [String]) async throws -> [ProductInfo] { [] }
    public func purchase(productId: String) async throws -> PurchaseResult { PurchaseResult(success: false, transactionID: nil, errorDescription: "Unavailable") }
    public func restore() async throws -> Bool { false }
    public func currentEntitlementProductIds() async throws -> Set<String> { [] }
}
#endif

#if canImport(StoreKit)
import StoreKit

@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public final class AppleStoreKitProvider: StoreKitProviding {
    private var updatesStream: AsyncStream<TransactionUpdate>!
    private var updatesContinuation: AsyncStream<TransactionUpdate>.Continuation!
    
    public init() {
        var continuation: AsyncStream<TransactionUpdate>.Continuation!
        self.updatesStream = AsyncStream { cont in
            continuation = cont
        }
        self.updatesContinuation = continuation
        
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let strongSelf = self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    strongSelf.updatesContinuation.yield(TransactionUpdate(productID: transaction.productID, isRevoked: transaction.revocationDate != nil))
                }
            }
        }
    }
    
    public var transactionUpdates: AsyncStream<TransactionUpdate> { updatesStream }
    
    public func loadProducts(ids: [String]) async throws -> [ProductInfo] {
        let storeProducts = try await Product.products(for: ids)
        return storeProducts.map { p in
            let period = (p.subscription?.subscriptionPeriod)
            let unit: String? = period.map { period in
                switch period.unit { case .day: return "day"; case .week: return "week"; case .month: return "month"; case .year: return "year"; @unknown default: return nil }
            }
            let value: Int? = period?.value
            return ProductInfo(
                id: p.id,
                displayName: p.displayName,
                displayPrice: p.displayPrice,
                isSubscription: p.type == .autoRenewable,
                subscriptionPeriodUnit: unit,
                subscriptionPeriodValue: value
            )
        }
    }
    
    public func purchase(productId: String) async throws -> PurchaseResult {
        let products = try await Product.products(for: [productId])
        guard let product = products.first else {
            return PurchaseResult(success: false, transactionID: nil, errorDescription: "Product not found")
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                return PurchaseResult(success: true, transactionID: String(transaction.id), errorDescription: nil)
            } else {
                return PurchaseResult(success: false, transactionID: nil, errorDescription: "Transaction unverified")
            }
        case .userCancelled:
            return PurchaseResult(success: false, transactionID: nil, errorDescription: "Cancelled")
        case .pending:
            return PurchaseResult(success: false, transactionID: nil, errorDescription: "Pending")
        @unknown default:
            return PurchaseResult(success: false, transactionID: nil, errorDescription: "Unknown")
        }
    }
    
    public func restore() async throws -> Bool {
        var restored = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                restored = true || restored
                await transaction.finish()
            }
        }
        return restored
    }
    
    public func currentEntitlementProductIds() async throws -> Set<String> {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                ids.insert(transaction.productID)
            }
        }
        return ids
    }
}
#endif

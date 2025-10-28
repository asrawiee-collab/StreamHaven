import Foundation

/// Central manager that uses a StoreKitProviding implementation to load products,
/// purchase/restore, and compute current entitlements.
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public actor StoreKitManager {
    private let provider: StoreKitProviding
    private let subscriptionIDs: [String]
    
    public private(set) var products: [ProductInfo] = []
    
    public init(provider: StoreKitProviding, subscriptionIDs: [String]) {
        self.provider = provider
        self.subscriptionIDs = subscriptionIDs
        Task { await observeTransactions() }
    }
    
    private func observeTransactions() async {
        for await _ in provider.transactionUpdates {
            // On any transaction change, refresh entitlements for consumers.
            _ = await currentEntitlementProductIds()
        }
    }
    
    public func loadProducts() async throws -> [ProductInfo] {
        let prods = try await provider.loadProducts(ids: subscriptionIDs)
        self.products = prods
        return prods
    }
    
    public func purchase(productId: String) async throws -> PurchaseResult {
        try await provider.purchase(productId: productId)
    }
    
    public func restore() async throws -> Bool {
        try await provider.restore()
    }
    
    public func currentEntitlementProductIds() async -> Set<String> {
        (try? await provider.currentEntitlementProductIds()) ?? []
    }
}

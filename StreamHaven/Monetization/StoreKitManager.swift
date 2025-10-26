import Foundation

/// Central manager that uses a StoreKitProviding implementation to load products,
/// purchase/restore, and compute current entitlements.
public actor StoreKitManager {
    private let provider: StoreKitProviding
    private let subscriptionIDs: [String]
    
    public private(set) var products: [ProductInfo] = []
    
    public init(provider: StoreKitProviding, subscriptionIDs: [String]) {
        self.provider = provider
        self.subscriptionIDs = subscriptionIDs
        observeTransactions()
    }
    
    private func observeTransactions() {
        Task.detached { [weak self] in
            guard let self else { return }
            for await update in self.provider.transactionUpdates {
                // On any transaction change, refresh entitlements for consumers.
                _ = await self.currentEntitlementProductIds()
            }
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

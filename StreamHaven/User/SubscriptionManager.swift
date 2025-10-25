import Foundation
import Combine

/// Represents the current subscription plan.
public enum SubscriptionPlan: String, Codable, CaseIterable {
    case none
    case plusMonthly
    case plusYearly
}

/// Observable subscription state for UI and features.
@MainActor
public final class SubscriptionManager: ObservableObject {
    @Published public private(set) var isSubscribed: Bool = false
    @Published public private(set) var currentPlan: SubscriptionPlan = .none
    @Published public private(set) var products: [ProductInfo] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    private let manager: StoreKitManager
    private var cancellables = Set<AnyCancellable>()
    
    // Persistence keys
    private let planKey = "Subscription.plan"
    private let subscribedKey = "Subscription.isSubscribed"
    
    public init(storeKitProvider: StoreKitProviding) {
        self.manager = StoreKitManager(provider: storeKitProvider, subscriptionIDs: MonetizationConfig.subscriptionProductIDs)
    }
    
    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await manager.loadProducts()
            await refreshEntitlements()
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }
    
    public func purchaseMonthly() async {
        await purchase(productId: MonetizationConfig.ProductID.plusMonthly, plan: .plusMonthly)
    }
    
    public func purchaseYearly() async {
        await purchase(productId: MonetizationConfig.ProductID.plusYearly, plan: .plusYearly)
    }
    
    private func purchase(productId: String, plan: SubscriptionPlan) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await manager.purchase(productId: productId)
            if result.success {
                await refreshEntitlements()
            } else {
                errorMessage = result.errorDescription ?? "Purchase failed"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await manager.restore()
            await refreshEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func refreshEntitlements() async {
        let ids = await manager.currentEntitlementProductIds()
        let isMonthly = ids.contains(MonetizationConfig.ProductID.plusMonthly)
        let isYearly = ids.contains(MonetizationConfig.ProductID.plusYearly)
        
        let newPlan: SubscriptionPlan = isYearly ? .plusYearly : (isMonthly ? .plusMonthly : .none)
        let newSubscribed = newPlan != .none
        
        currentPlan = newPlan
        isSubscribed = newSubscribed
        
        // Persist lightweight cache for fast app start
        UserDefaults.standard.set(newPlan.rawValue, forKey: planKey)
        UserDefaults.standard.set(newSubscribed, forKey: subscribedKey)
    }
    
    public func loadCachedEntitlements() {
        let planRaw = UserDefaults.standard.string(forKey: planKey) ?? SubscriptionPlan.none.rawValue
        let plan = SubscriptionPlan(rawValue: planRaw) ?? .none
        let subscribed = UserDefaults.standard.bool(forKey: subscribedKey)
        currentPlan = plan
        isSubscribed = subscribed
    }
}

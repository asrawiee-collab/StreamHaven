import XCTest
@testable import StreamHaven

final class MockStoreKitProvider: StoreKitProviding {
    var productsToReturn: [ProductInfo] = []
    var entitlementIds: Set<String> = []
    var nextPurchaseResult: PurchaseResult = .init(success: true, transactionID: "tx1", errorDescription: nil)
    var restoreResult: Bool = true
    
    var transactionUpdates: AsyncStream<TransactionUpdate> { AsyncStream { _ in } }
    
    func loadProducts(ids: [String]) async throws -> [ProductInfo] { productsToReturn }
    func purchase(productId: String) async throws -> PurchaseResult {
        if nextPurchaseResult.success { entitlementIds.insert(productId) }
        return nextPurchaseResult
    }
    func restore() async throws -> Bool { restoreResult }
    func currentEntitlementProductIds() async throws -> Set<String> { entitlementIds }
}

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    func testLoadProductsAndInitialEntitlements() async {
        let mock = MockStoreKitProvider()
        mock.productsToReturn = [
            ProductInfo(id: MonetizationConfig.ProductID.plusMonthly, displayName: "Plus Monthly", displayPrice: "$4.99", isSubscription: true, subscriptionPeriodUnit: "month", subscriptionPeriodValue: 1),
            ProductInfo(id: MonetizationConfig.ProductID.plusYearly, displayName: "Plus Yearly", displayPrice: "$39.99", isSubscription: true, subscriptionPeriodUnit: "year", subscriptionPeriodValue: 1)
        ]
        let sm = SubscriptionManager(storeKitProvider: mock)
        await sm.load()
        XCTAssertEqual(sm.products.count, 2)
        XCTAssertFalse(sm.isSubscribed)
        XCTAssertEqual(sm.currentPlan, .none)
    }
    
    func testPurchaseMonthlyUpdatesEntitlement() async {
        let mock = MockStoreKitProvider()
        mock.productsToReturn = []
        let sm = SubscriptionManager(storeKitProvider: mock)
        await sm.purchaseMonthly()
        await sm.refreshEntitlements()
        XCTAssertTrue(sm.isSubscribed)
        XCTAssertEqual(sm.currentPlan, .plusMonthly)
    }
    
    func testPurchaseFailureSetsError() async {
        let mock = MockStoreKitProvider()
        mock.nextPurchaseResult = .init(success: false, transactionID: nil, errorDescription: "Failed")
        let sm = SubscriptionManager(storeKitProvider: mock)
        await sm.purchaseYearly()
        XCTAssertEqual(sm.errorMessage, "Failed")
        XCTAssertFalse(sm.isSubscribed)
    }
    
    func testRestoreSetsEntitlements() async {
        let mock = MockStoreKitProvider()
        mock.entitlementIds = [MonetizationConfig.ProductID.plusYearly]
        let sm = SubscriptionManager(storeKitProvider: mock)
        await sm.restore()
        XCTAssertTrue(sm.isSubscribed)
        XCTAssertEqual(sm.currentPlan, .plusYearly)
    }
}

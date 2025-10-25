import Foundation

/// Central configuration for monetization and product identifiers.
public enum MonetizationConfig {
    /// Feature flag to enable/disable monetization UI.
    public static var isMonetizationEnabled: Bool { true }
    
    /// Product identifiers for subscriptions. Update these to match App Store Connect.
    public enum ProductID {
        public static var plusMonthly: String { UserDefaults.standard.string(forKey: "ProductID.plusMonthly") ?? "com.streamhaven.plus.monthly" }
        public static var plusYearly: String { UserDefaults.standard.string(forKey: "ProductID.plusYearly") ?? "com.streamhaven.plus.yearly" }
    }
    
    /// All known subscription product identifiers.
    public static var subscriptionProductIDs: [String] {
        [ProductID.plusMonthly, ProductID.plusYearly]
    }
}

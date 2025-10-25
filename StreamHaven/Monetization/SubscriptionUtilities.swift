import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Helpers for subscription-related actions.
public enum SubscriptionUtilities {
    /// Opens the Apple subscriptions management page where supported.
    /// Falls back to opening the subscriptions web page.
    public static func openManageSubscriptions() {
        #if canImport(UIKit)
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #endif
    }
}

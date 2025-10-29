# Monetization Setup (StoreKit 2)

This document explains how to configure StreamHaven's subscriptions using StoreKit 2.

## 1) Create products in App Store Connect

- Create two auto‑renewable subscriptions (same Subscription Group):
  - Plus Monthly: Identifier `com.streamhaven.plus.monthly`
  - Plus Yearly: Identifier `com.streamhaven.plus.yearly`
- Add localized display names and prices.
- Submit for review if needed.

You can change identifiers by setting these keys in UserDefaults (e.g., at app start):

- `ProductID.plusMonthly`
- `ProductID.plusYearly`

## 2) Local testing with a .storekit file

- In Xcode, create a StoreKit Configuration file.
- Add the two subscriptions with matching identifiers.
- Select the configuration in the scheme’s Run settings under Options.

## 3) Feature flags and platform guards

- The feature is controlled by `MonetizationConfig.isMonetizationEnabled`.
- Apple provider is used under `#if canImport(StoreKit)` and requires iOS/tvOS 15+.
- Other platforms use a no‑op provider, keeping the app buildable.

## 4) Where code lives

- Config: `StreamHaven/Monetization/MonetizationConfig.swift`
- Abstraction: `StreamHaven/Monetization/StoreKitProviding.swift` (protocol, Apple provider, no‑op provider)
- Manager: `StreamHaven/Monetization/StoreKitManager.swift`
- App state: `StreamHaven/User/SubscriptionManager.swift`
- UI: `StreamHaven/UI/SettingsView.swift` (Subscription section)

## 5) Behavior overview

- Products load on opening Settings.
- Subscribe Monthly/Yearly triggers StoreKit purchase.
- Restore retries `Transaction.currentEntitlements`.
- Entitlements are cached in UserDefaults for fast startup and refreshed when Settings opens.

## 6) Testing

- Unit tests use a mock provider; no network/App Store required:
  - `StreamHaven/Tests/SubscriptionManagerTests.swift`

## 7) Shipping checklist

- Verify product IDs match App Store Connect.
- Test with Sandbox and TestFlight.
- Ensure privacy policy and terms are accessible in-app.
- Localize subscription copy and pricing if needed.

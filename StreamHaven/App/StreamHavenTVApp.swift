import Foundation
import SwiftUI
#if canImport(Sentry)
import Sentry
#endif
import os.log

#if os(tvOS)
/// The main entry point for the StreamHaven tvOS application.
@main
public struct StreamHavenTVApp: App {
    /// Persistence provider for Core Data (injectable for tests/previews)
    let persistenceProvider: PersistenceProviding

    /// The body of the app.
    public init(persistenceProvider: PersistenceProviding? = nil) {
        // Create PersistenceController and provider if not injected
        if let persistenceProvider = persistenceProvider {
            self.persistenceProvider = persistenceProvider
        } else {
            let controller = PersistenceController()
            self.persistenceProvider = DefaultPersistenceProvider(controller: controller)
        }
        
        // Initialize performance tooling
#if canImport(Sentry)
        if let dsn = ProcessInfo.processInfo.environment["SENTRY_DSN"] ?? (Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String), !dsn.isEmpty {
            SentrySDK.start { options in
                options.dsn = dsn
                options.enableAppHangTracking = true
                options.enableAutoBreadcrumbTracking = true
                options.enableUIViewControllerTracing = true
                options.tracesSampleRate = 0.2
                options.enableNetworkTracking = true
                options.enableCoreDataTracing = true
            }
            os_log("Sentry initialized for tvOS", log: .default, type: .info)
        } else {
            os_log("Sentry DSN not provided. Crash/Performance monitoring disabled.", log: .default, type: .info)
        }
#endif

        // Register network logger protocol for request/response timing
        NetworkLoggerURLProtocol.register()
    }

    public var body: some Scene {
        WindowGroup {
            ContentView(persistenceProvider: persistenceProvider)
                .environment(\.managedObjectContext, persistenceProvider.container.viewContext)
        }
    }
}
#endif

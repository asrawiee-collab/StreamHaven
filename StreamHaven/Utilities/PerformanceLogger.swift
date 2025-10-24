import Foundation
import os.log
#if canImport(Sentry)
import Sentry
#endif

public enum PerformanceLogger {
    private static let subsystem = "com.asrawiee.StreamHaven"
    public static let networkLog = OSLog(subsystem: subsystem, category: "Network")
    public static let coreDataLog = OSLog(subsystem: subsystem, category: "CoreData")
    public static let playbackLog = OSLog(subsystem: subsystem, category: "Playback")

    /// Measures the duration of a block and logs it if it exceeds a threshold.
    @discardableResult
    public static func measure<T>(label: String, threshold: TimeInterval = 0.2, _ block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        if duration >= threshold {
            os_log("%{public}@ took %{public}.3f s", log: OSLog(subsystem: subsystem, category: "Performance"), type: .debug, label, duration)
#if canImport(Sentry)
            SentrySDK.addBreadcrumb(crumb: Breadcrumb(level: .info, category: "perf", type: "default", message: "\(label) took \(String(format: "%.3f", duration)) s"))
#endif
        }
        return result
    }

    public static func logNetwork(_ message: String) {
        os_log("%{public}@", log: networkLog, type: .debug, message)
    }

    public static func logCoreData(_ message: String) {
        os_log("%{public}@", log: coreDataLog, type: .debug, message)
    }

    public static func logPlayback(_ message: String) {
        os_log("%{public}@", log: playbackLog, type: .debug, message)
    }
}

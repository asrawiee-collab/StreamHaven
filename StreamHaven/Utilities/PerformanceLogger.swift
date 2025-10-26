import Foundation
import os.log
#if canImport(Sentry)
import Sentry
#endif

public enum PerformanceLogger {
    public enum Level: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
    }
    
    private static let subsystem = "com.asrawiee.StreamHaven"
    public static let networkLog = OSLog(subsystem: subsystem, category: "Network")
    public static let coreDataLog = OSLog(subsystem: subsystem, category: "CoreData")
    public static let playbackLog = OSLog(subsystem: subsystem, category: "Playback")
    
    /// Per-category minimal levels to emit. Tunable at runtime via UserDefaults or setters.
    private static var minLevelGlobal: Level = {
        if let raw = UserDefaults.standard.object(forKey: "PerformanceLoggerLevel") as? Int, let level = Level(rawValue: raw) {
            return level
        }
        return .debug
    }()
    private static var minLevelNetwork: Level = {
        if let raw = UserDefaults.standard.object(forKey: "PerformanceLoggerLevel.Network") as? Int, let level = Level(rawValue: raw) {
            return level
        }
        return minLevelGlobal
    }()
    private static var minLevelCoreData: Level = {
        if let raw = UserDefaults.standard.object(forKey: "PerformanceLoggerLevel.CoreData") as? Int, let level = Level(rawValue: raw) {
            return level
        }
        return minLevelGlobal
    }()
    private static var minLevelPlayback: Level = {
        if let raw = UserDefaults.standard.object(forKey: "PerformanceLoggerLevel.Playback") as? Int, let level = Level(rawValue: raw) {
            return level
        }
        return minLevelGlobal
    }()

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

    public static func setMinLevel(_ level: Level) {
        minLevelGlobal = level
        UserDefaults.standard.set(level.rawValue, forKey: "PerformanceLoggerLevel")
    }
    public static func setMinLevel(network: Level? = nil, coreData: Level? = nil, playback: Level? = nil) {
        if let n = network { minLevelNetwork = n; UserDefaults.standard.set(n.rawValue, forKey: "PerformanceLoggerLevel.Network") }
        if let c = coreData { minLevelCoreData = c; UserDefaults.standard.set(c.rawValue, forKey: "PerformanceLoggerLevel.CoreData") }
        if let p = playback { minLevelPlayback = p; UserDefaults.standard.set(p.rawValue, forKey: "PerformanceLoggerLevel.Playback") }
    }
    public static func reloadLevelsFromUserDefaults() {
        if let raw = UserDefaults.standard.object(forKey: "PerformanceLoggerLevel") as? Int, let level = Level(rawValue: raw) { minLevelGlobal = level }
        if let raw = UserDefaults.standard.object(forKey: "PerformanceLoggerLevel.Network") as? Int, let level = Level(rawValue: raw) { minLevelNetwork = level }
        if let raw = UserDefaults.standard.object(forKey: "PerformanceLoggerLevel.CoreData") as? Int, let level = Level(rawValue: raw) { minLevelCoreData = level }
        if let raw = UserDefaults.standard.object(forKey: "PerformanceLoggerLevel.Playback") as? Int, let level = Level(rawValue: raw) { minLevelPlayback = level }
    }
    
    public static func logNetwork(_ message: String, level: Level = .debug) {
        let gate = minLevelNetwork
        guard level.rawValue >= gate.rawValue else { return }
        os_log("%{public}@", log: networkLog, type: osLogType(for: level), message)
    }

    public static func logCoreData(_ message: String, level: Level = .debug) {
        let gate = minLevelCoreData
        guard level.rawValue >= gate.rawValue else { return }
        os_log("%{public}@", log: coreDataLog, type: osLogType(for: level), message)
    }

    public static func logPlayback(_ message: String, level: Level = .debug) {
        let gate = minLevelPlayback
        guard level.rawValue >= gate.rawValue else { return }
        os_log("%{public}@", log: playbackLog, type: osLogType(for: level), message)
    }
    
    private static func osLogType(for level: Level) -> OSLogType {
        switch level {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

import Foundation
import os.log

#if canImport(Sentry)
import Sentry
#endif

/// Centralized error logging and reporting utility.
public enum ErrorReporter {
    /// Logs an error to OSLog and Sentry (if available).
    /// - Parameters:
    ///   - error: The error to log.
    ///   - context: Optional context to include (e.g., operation name).
    public static func log(_ error: Error, context: String? = nil) {
        let message: String
        if let context = context {
            message = "[\(context)] \(error.localizedDescription)"
        } else {
            message = error.localizedDescription
        }

        os_log("Error: %{public}@", log: .default, type: .error, message)

        #if canImport(Sentry)
        // Capture as error event
        let event = Event(level: .error)
        event.message = SentryMessage(formatted: message)
        SentrySDK.capture(event: event)
        #endif
    }

    /// Returns a user-facing error message for display.
    /// Uses LocalizedError if available.
    /// - Parameter error: The error to present.
    public static func userMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let desc = localized.errorDescription {
            return desc
        }
        return error.localizedDescription
    }
}

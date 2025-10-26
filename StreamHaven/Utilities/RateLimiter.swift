import Foundation

/// A simple async token bucket rate limiter for client-side throttling.
public final class RateLimiter {
    private let maxTokens: Int
    private let refillInterval: TimeInterval
    private let refillAmount: Int
    private var tokens: Int
    private var lastRefill: Date
    private let lock = NSLock()
    
    /// - Parameters:
    ///   - maxTokens: Maximum number of tokens in the bucket.
    ///   - refillPerSecond: How many tokens to add per second.
    public init(maxTokens: Int, refillPerSecond: Int) {
        self.maxTokens = maxTokens
        self.refillInterval = 1.0
        self.refillAmount = refillPerSecond
        self.tokens = maxTokens
        self.lastRefill = Date()
    }
    
    /// Acquires a token. Suspends if none are available until one refills.
    public func acquire() async {
        while true {
            var shouldWait: TimeInterval = 0
            lock.lock()
            let now = Date()
            let elapsed = now.timeIntervalSince(lastRefill)
            if elapsed >= refillInterval {
                let intervals = Int(elapsed / refillInterval)
                let add = intervals * refillAmount
                tokens = min(maxTokens, tokens + add)
                lastRefill = now
            }
            if tokens > 0 {
                tokens -= 1
                lock.unlock()
                return
            } else {
                // Wait remaining time until next refill
                let timeSinceLast = now.timeIntervalSince(lastRefill)
                shouldWait = max(0.05, refillInterval - timeSinceLast)
                lock.unlock()
            }
            try? await Task.sleep(nanoseconds: UInt64(shouldWait * 1_000_000_000))
        }
    }
}
import Foundation

/// A URLProtocol that logs request/response details and timing for debugging and performance monitoring.
public final class NetworkLoggerURLProtocol: URLProtocol {
    private var dataTask: URLSessionDataTask?
    private var startTime: CFAbsoluteTime = 0

    public override class func canInit(with request: URLRequest) -> Bool {
        // Avoid infinite loop by checking a marker header
        if URLProtocol.property(forKey: "NetworkLoggerHandled", in: request) as? Bool == true {
            return false
        }
        // Only log http/https
        return request.url?.scheme == "http" || request.url?.scheme == "https"
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    public override func startLoading() {
        startTime = CFAbsoluteTimeGetCurrent()
        var newRequest = self.request
        URLProtocol.setProperty(true, forKey: "NetworkLoggerHandled", in: &newRequest)

        PerformanceLogger.logNetwork("➡️ Request: \(newRequest.httpMethod ?? "GET") \(newRequest.url?.absoluteString ?? "-")")

        let session = URLSession(configuration: .default)
        dataTask = session.dataTask(with: newRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            let duration = CFAbsoluteTimeGetCurrent() - self.startTime
            if let response = response as? HTTPURLResponse {
                PerformanceLogger.logNetwork("⬅️ Response: \(response.statusCode) \(newRequest.url?.absoluteString ?? "-") in \(String(format: "%.3f", duration))s")
            }
            if let data = data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            if let response = response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
            }
            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
                PerformanceLogger.logNetwork("❌ Error: \(error.localizedDescription)")
            } else {
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
        dataTask?.resume()
    }

    public override func stopLoading() {
        dataTask?.cancel()
    }

    /// Registers this protocol once at app launch.
    public static func register() {
        URLProtocol.registerClass(NetworkLoggerURLProtocol.self)
    }
}

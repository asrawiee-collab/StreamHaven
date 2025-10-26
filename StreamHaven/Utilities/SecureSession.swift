import Foundation
#if canImport(Security)
import Security
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Factory for URLSession instances with optional certificate pinning.
public enum SecureSession {
    /// Create a URLSession with optional certificate or public key pinning for given hosts.
    /// - Parameters:
    ///   - pinnedHosts: Hostnames to pin.
    ///   - certificateNames: Names of DER certificates included in the bundle to pin against (without extension).
    ///   - publicKeyHashes: Optional SHA-256 hashes (Base64) of the server certificate public keys (SPKI or raw key) to pin.
    /// - Returns: Configured URLSession.
    public static func makeSession(pinnedHosts: [String] = [], certificateNames: [String] = [], publicKeyHashes: [String] = []) -> URLSession {
        guard !pinnedHosts.isEmpty, (!certificateNames.isEmpty || !publicKeyHashes.isEmpty) else {
            return URLSession(configuration: .default)
        }
        let delegate = PinningDelegate(pinnedHosts: Set(pinnedHosts), certificateNames: certificateNames, publicKeyHashes: Set(publicKeyHashes))
        return URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }

    private final class PinningDelegate: NSObject, URLSessionDelegate {
        let pinnedHosts: Set<String>
        let certificates: [Data]
        let publicKeyHashes: Set<String>
        
        init(pinnedHosts: Set<String>, certificateNames: [String], publicKeyHashes: Set<String>) {
            self.pinnedHosts = pinnedHosts
            self.certificates = certificateNames.compactMap { name in
                guard let url = Bundle.main.url(forResource: name, withExtension: "der"),
                      let data = try? Data(contentsOf: url) else { return nil }
                return data
            }
            self.publicKeyHashes = publicKeyHashes
        }
        
        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            guard let serverTrust = challenge.protectionSpace.serverTrust,
                  pinnedHosts.contains(challenge.protectionSpace.host) else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
#if canImport(Security)
            // Modern trust evaluation
            var error: CFError?
            if !SecTrustEvaluateWithError(serverTrust, &error) {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            
            // Check certificate pinning first (exact binary match of leaf cert)
            if let serverCert = SecTrustGetCertificateAtIndex(serverTrust, 0) {
                let serverData = SecCertificateCopyData(serverCert) as Data
                if !certificates.isEmpty, certificates.contains(serverData) {
                    completionHandler(.useCredential, URLCredential(trust: serverTrust))
                    return
                }
                
                // Otherwise, try public key pinning via SHA-256 of the public key
                if !publicKeyHashes.isEmpty {
                    #if canImport(Security)
                    if let publicKey = SecCertificateCopyKey(serverCert) {
                        var cfError: Unmanaged<CFError>?
                        if let keyData = SecKeyCopyExternalRepresentation(publicKey, &cfError) as Data? {
                            let digest = sha256Base64(keyData)
                            if publicKeyHashes.contains(digest) {
                                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                                return
                            }
                        }
                    }
                    #endif
                }
            }
#endif
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Hashing helpers
#if canImport(CryptoKit)
private func sha256Base64(_ data: Data) -> String {
    let hash = SHA256.hash(data: data)
    return Data(hash).base64EncodedString()
}
#else
private func sha256Base64(_ data: Data) -> String { return "" }
#endif

import Foundation
import MapLibre

/// Handles network configuration for MapLibre, including SSL certificate validation
class NetworkConfiguration {
    /// Singleton instance
    static let shared = NetworkConfiguration()
    
    private init() {}
    
    // Store current headers
    private var currentHeaders: [String: String] = [:]

    // Store SSL bypass state
    private var isSSLValidationBypassed = false
    
    /// Configures SSL certificate validation
    /// - Parameter enabled: When true, SSL certificate validation is bypassed
    func configureSSLValidation(enabled: Bool) {
        isSSLValidationBypassed = enabled
        updateNetworkConfiguration()
    }
    
    /// Configures HTTP headers for all requests
    /// - Parameter headers: Dictionary of HTTP headers to be added to all requests
    func configureHeaders(_ headers: [String: String]) {
        currentHeaders.merge(headers, uniquingKeysWith: { $1 })
        updateNetworkConfiguration()
    }
    
    /// Updates network configuration while maintaining both SSL bypass state and headers
    private func updateNetworkConfiguration() {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpAdditionalHeaders = currentHeaders
        
        if isSSLValidationBypassed {
            // Create a URLSession with SSL bypass delegate
            let session = URLSession(
                configuration: sessionConfig,
                delegate: SSLBypassDelegate.shared,
                delegateQueue: nil
            )
            
            // Store the session in a static property to prevent it from being deallocated
            NetworkConfiguration.sslBypassSession = session
        } else {
            // Reset to default configuration but keep headers
            NetworkConfiguration.sslBypassSession = nil
        }
        
        MLNNetworkConfiguration.sharedManager.sessionConfiguration = sessionConfig
    }
    
    // Keep a strong reference to the SSL bypass session
    private static var sslBypassSession: URLSession?
}

/// URLSessionDelegate that handles SSL certificate validation
private class SSLBypassDelegate: NSObject, URLSessionDelegate {
    static let shared = SSLBypassDelegate()
    
    private override init() {
        super.init()
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
} 
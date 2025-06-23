import Foundation
import MapLibre

/// Handles network configuration for MapLibre, including SSL certificate validation
class NetworkConfiguration {
    /// Singleton instance
    static let shared = NetworkConfiguration()
    
    private init() {
        print("🌐 NetworkConfiguration: Singleton initialized")
    }
    
    // Store current headers
    private var currentHeaders: [String: String] = [:] {
        didSet {
            print("🌐 NetworkConfiguration: Headers updated - \(currentHeaders)")
        }
    }
    // Store SSL bypass state
    private var isSSLValidationBypassed = false {
        didSet {
            print("🌐 NetworkConfiguration: SSL bypass state changed to \(isSSLValidationBypassed)")
        }
    }
    
    /// Configures SSL certificate validation
    /// - Parameter enabled: When true, SSL certificate validation is bypassed
    func configureSSLValidation(enabled: Bool) {
        print("🌐 NetworkConfiguration: configureSSLValidation called with enabled=\(enabled)")
        isSSLValidationBypassed = enabled
        updateNetworkConfiguration()
        print("🌐 NetworkConfiguration: SSL validation configuration completed")
    }
    
    /// Configures HTTP headers for all requests
    /// - Parameter headers: Dictionary of HTTP headers to be added to all requests
    func configureHeaders(_ headers: [String: String]) {
        print("🌐 NetworkConfiguration: configureHeaders called with headers=\(headers)")
        currentHeaders.merge(headers, uniquingKeysWith: { $1 })
        updateNetworkConfiguration()
        print("🌐 NetworkConfiguration: Headers configuration completed")
    }
    
    /// Updates network configuration while maintaining both SSL bypass state and headers
    private func updateNetworkConfiguration() {
        print("🌐 NetworkConfiguration: updateNetworkConfiguration started")
        print("🌐 NetworkConfiguration: Current state - SSL bypass: \(isSSLValidationBypassed), Headers: \(currentHeaders)")
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpAdditionalHeaders = currentHeaders
        print("🌐 NetworkConfiguration: URLSessionConfiguration created with headers")
        
        if isSSLValidationBypassed {
            print("🌐 NetworkConfiguration: Creating URLSession with SSL bypass delegate")
            // Create a URLSession with SSL bypass delegate
            let session = URLSession(
                configuration: sessionConfig,
                delegate: SSLBypassDelegate.shared,
                delegateQueue: nil
            )
            
            // Store the session in a static property to prevent it from being deallocated
            NetworkConfiguration.sslBypassSession = session
            print("🌐 NetworkConfiguration: SSL bypass session created and stored")
        } else {
            print("🌐 NetworkConfiguration: Resetting to default configuration")
            // Reset to default configuration but keep headers
            NetworkConfiguration.sslBypassSession = nil
            print("🌐 NetworkConfiguration: SSL bypass session cleared")
        }
        
        MLNNetworkConfiguration.sharedManager.sessionConfiguration = sessionConfig
        print("🌐 NetworkConfiguration: MLNNetworkConfiguration.sharedManager updated")
        print("🌐 NetworkConfiguration: updateNetworkConfiguration completed")
    }
    
    // Keep a strong reference to the SSL bypass session
    private static var sslBypassSession: URLSession? {
        didSet {
            if sslBypassSession != nil {
                print("🌐 NetworkConfiguration: sslBypassSession assigned")
            } else {
                print("🌐 NetworkConfiguration: sslBypassSession cleared")
            }
        }
    }
}

/// URLSessionDelegate that handles SSL certificate validation
private class SSLBypassDelegate: NSObject, URLSessionDelegate {
    static let shared = SSLBypassDelegate()
    
    private override init() {
        super.init()
        print("🔒 SSLBypassDelegate: Singleton initialized")
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        print("🔒 SSLBypassDelegate: URL session challenge received")
        print("🔒 SSLBypassDelegate: Challenge protection space: \(challenge.protectionSpace)")
        print("🔒 SSLBypassDelegate: Authentication method: \(challenge.protectionSpace.authenticationMethod)")
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            print("🔒 SSLBypassDelegate: Server trust challenge detected, bypassing SSL validation")
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            print("🔒 SSLBypassDelegate: SSL bypass credential provided")
        } else {
            print("🔒 SSLBypassDelegate: Non-server trust challenge, using default handling")
            completionHandler(.performDefaultHandling, nil)
        }
    }
} 
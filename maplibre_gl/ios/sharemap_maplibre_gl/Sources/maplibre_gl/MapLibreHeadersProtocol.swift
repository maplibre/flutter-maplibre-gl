import Foundation

// URLProtocol that injects custom headers into every tile/resource request that
// MapLibre-native makes. Registered once at plugin startup; headers are read
// from MapLibreCustomHeaders at request time, so setCustomHeaders works even
// after MLNMapView has been created.
final class MapLibreHeadersProtocol: URLProtocol {
    private static let handledKey = "MapLibreHeadersProtocolHandled"

    // Stored so stopLoading() can cancel and invalidate them.
    private var activeTask: URLSessionDataTask?
    private var activeSession: URLSession?

    override class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(forKey: handledKey, in: request) == nil else {
            return false
        }
        let scheme = request.url?.scheme?.lowercased() ?? ""
        return scheme == "http" || scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let mutable = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutable)

        let originalUrl = mutable.url?.absoluteString ?? ""

        // 1. Check if transformRequest is enabled
        var transformEnabled = false
        var targetController: MapLibreMapController? = nil
        for controller in MapLibreMapController.activeControllers {
            if controller.transformRequestEnabled {
                transformEnabled = true
                targetController = controller
                break
            }
        }

        if transformEnabled, let controller = targetController, let channel = controller.getMethodChannel() {
            let semaphore = DispatchSemaphore(value: 0)
            var transformedUrl = originalUrl
            var transformedHeaders: [String: String]? = nil

            DispatchQueue.main.async {
                channel.invokeMethod("map#transformRequest", arguments: [
                    "url": originalUrl,
                    "resourceType": self.inferResourceType(originalUrl)
                ]) { result in
                    if let dict = result as? [String: Any] {
                        transformedUrl = dict["url"] as? String ?? originalUrl
                        transformedHeaders = dict["headers"] as? [String: String]
                    }
                    semaphore.signal()
                }
            }
            _ = semaphore.wait(timeout: .distantFuture)

            if let newUrl = URL(string: transformedUrl) {
                mutable.url = newUrl
            }
            if let newHeaders = transformedHeaders {
                for (key, value) in newHeaders {
                    mutable.setValue(value, forHTTPHeaderField: key)
                }
            }
        }

        // 2. Read headers and filter atomically in one lock acquisition.
        let (headers, shouldApply) = MapLibreCustomHeaders.headersIfApplicable(to: mutable.url?.absoluteString ?? "")
        if shouldApply {
            for (key, value) in headers {
                mutable.setValue(value, forHTTPHeaderField: key)
            }
        }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: mutable as URLRequest)
        activeSession = session
        activeTask = task
        task.resume()
    }

    private func inferResourceType(_ url: String) -> Int {
        let lower = url.lowercased()
        if lower.contains("/styles/") || lower.hasSuffix("style.json") {
            return 1 // style
        }
        if lower.contains("/sprites/") || lower.contains("sprite") {
            if lower.hasSuffix(".json") {
                return 6 // spriteJSON
            }
            return 5 // spriteImage
        }
        if lower.contains("/fonts/") || lower.contains("/glyphs/") {
            return 4 // glyphs
        }
        if lower.contains("/tiles/") || lower.contains("/tile/") || lower.hasSuffix(".pbf") || lower.hasSuffix(".mvt") {
            return 3 // tile
        }
        return 0 // unknown
    }

    override func stopLoading() {
        activeTask?.cancel()
        activeSession?.invalidateAndCancel()
        activeTask = nil
        activeSession = nil
    }
}

extension MapLibreHeadersProtocol: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
        activeSession?.finishTasksAndInvalidate()
        activeTask = nil
        activeSession = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
        // Follow the redirect so the underlying load completes.
        completionHandler(request)
    }
}

import Foundation

// URLProtocol that injects custom headers into every tile/resource request that
// MapLibre-native makes. Registered once at plugin startup; headers are read
// from MapLibreCustomHeaders at request time, so setCustomHeaders works even
// after MLNMapView has been created.
final class MapLibreHeadersProtocol: URLProtocol {
    private static let handledKey = "MapLibreHeadersProtocolHandled"

    // One session shared by every intercepted request, rather than one session
    // per request. A session per tile meant a session teardown per tile, and it
    // gave every request its own delegate, so the task had to be torn down from
    // both stopLoading() and the completion callback, which run on different
    // threads and raced on the same references.
    private static let sessionDelegate = SessionDelegate()
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        // A session per request meant no per-host connection limit at all. This
        // one session would impose the default of 6, so raise it: how many
        // requests run at once is MapLibre's decision, and this session only
        // relays them. (setMaxConcurrentRequests sets the limit on MapLibre's
        // own session, which is not this one.)
        configuration.httpMaximumConnectionsPerHost = 20
        return URLSession(
            configuration: configuration,
            delegate: sessionDelegate,
            delegateQueue: nil
        )
    }()

    // Guards `activeTask` and `finished`, which stopLoading() and the delegate
    // callbacks reach from different threads.
    private let lock = NSLock()
    private var activeTask: URLSessionDataTask?
    // Set once the load is over, by cancellation or by completion. Guarantees
    // the task is released exactly once and stops the client hearing about a
    // load it has already torn down.
    private var finished = false

    override class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(forKey: handledKey, in: request) == nil else {
            return false
        }
        // Nothing to inject, so leave the request on the normal loading path
        // instead of routing it through this protocol for no reason.
        guard MapLibreCustomHeaders.hasCustomHeaders() else {
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

        // Read headers and filter atomically in one lock acquisition.
        let (headers, shouldApply) = MapLibreCustomHeaders.headersIfApplicable(to: mutable.url?.absoluteString ?? "")
        if shouldApply {
            for (key, value) in headers {
                mutable.setValue(value, forHTTPHeaderField: key)
            }
        }

        let task = Self.session.dataTask(with: mutable as URLRequest)
        lock.lock()
        // The load can already have been cancelled at this point, in which case
        // the task must never start.
        guard !finished else {
            lock.unlock()
            return
        }
        activeTask = task
        // Registered under the same lock as `activeTask`, so stopLoading() can
        // never observe a half-started load.
        Self.sessionDelegate.register(self, for: task)
        lock.unlock()
        task.resume()
    }

    override func stopLoading() {
        lock.lock()
        finished = true
        let task = activeTask
        activeTask = nil
        lock.unlock()
        guard let task = task else { return }
        // Unregister before cancelling: the cancellation callback then finds no
        // handler and the client hears nothing more about this load.
        Self.sessionDelegate.unregister(task)
        task.cancel()
    }

    // MARK: Delegate callbacks, forwarded by SessionDelegate

    private var isLive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !finished
    }

    fileprivate func didReceive(_ response: URLResponse) {
        guard isLive else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }

    fileprivate func didReceive(_ data: Data) {
        guard isLive else { return }
        client?.urlProtocol(self, didLoad: data)
    }

    fileprivate func didRedirect(to request: URLRequest, response: HTTPURLResponse) {
        guard isLive else { return }
        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
    }

    fileprivate func didComplete(with error: Error?) {
        lock.lock()
        let wasFinished = finished
        finished = true
        activeTask = nil
        lock.unlock()
        guard !wasFinished else { return }
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}

// Delegate of the shared session, routing each callback to the protocol
// instance that started the task. It holds those instances for as long as their
// task is in flight, the way the per-request sessions used to.
private final class SessionDelegate: NSObject, URLSessionDataDelegate {
    private let lock = NSLock()
    private var handlers: [Int: MapLibreHeadersProtocol] = [:]

    func register(_ handler: MapLibreHeadersProtocol, for task: URLSessionTask) {
        lock.lock()
        handlers[task.taskIdentifier] = handler
        lock.unlock()
    }

    func unregister(_ task: URLSessionTask) {
        lock.lock()
        handlers.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
    }

    private func handler(for task: URLSessionTask) -> MapLibreHeadersProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[task.taskIdentifier]
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        handler(for: dataTask)?.didReceive(response)
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        handler(for: dataTask)?.didReceive(data)
    }

    func urlSession(_: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        handler(for: task)?.didRedirect(to: request, response: response)
        // Follow the redirect so the underlying load completes even if the
        // client leaves this one running instead of restarting it.
        completionHandler(request)
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let handler = handler(for: task)
        unregister(task)
        handler?.didComplete(with: error)
    }
}

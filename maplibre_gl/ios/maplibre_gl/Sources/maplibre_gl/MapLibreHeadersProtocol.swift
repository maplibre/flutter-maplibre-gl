import Foundation
import MapLibre

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

    private static let delegateQueue: OperationQueue = {
        let queue = OperationQueue()
        // Must stay serial. URLSession only orders a task's callbacks when the
        // delegate queue is serial, and two didReceive(data:) running at once
        // for one task would hand the client its bytes out of order. Only this
        // hand-off is serialized: the transfers themselves still run in
        // parallel, and the hand-off is a buffer append, not decode work.
        queue.maxConcurrentOperationCount = 1
        queue.name = "org.maplibre.flutter.headers-protocol"
        queue.qualityOfService = .userInitiated
        return queue
    }()

    // A session per request meant no per-host connection limit at all, and one
    // shared session would impose the system default of 6, so start well above
    // it rather than quietly throttling tile loads.
    private static let defaultMaxConnectionsPerHost = 20

    // Guards `sessionStorage` and `configuredMaxConnectionsPerHost`. Separate
    // from the per-instance lock, and never held while the instance lock is.
    private static let sessionLock = NSLock()
    private static var sessionStorage: URLSession?
    // The limit setMaxConcurrentRequests asked for, if it ever did.
    private static var configuredMaxConnectionsPerHost: Int?

    // Built lazily, and from a copy of the configuration MapLibre hands out
    // rather than from `.default`: this session, not MapLibre's, is the one that
    // performs the load once the request is intercepted, so it has to carry the
    // timeouts, cache policy and TLS settings MapLibre put there.
    private static var session: URLSession {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        if let session = sessionStorage {
            return session
        }
        let configuration =
            (MLNNetworkConfiguration.sharedManager.sessionConfiguration?
                .copy() as? URLSessionConfiguration) ?? .default
        // We are the loader now, so there is nothing for this protocol to do on
        // our own session. startLoading()'s handledKey already stops the
        // recursion; this saves the lookup per request.
        configuration.protocolClasses = nil
        configuration.httpMaximumConnectionsPerHost =
            configuredMaxConnectionsPerHost ?? defaultMaxConnectionsPerHost
        let session = URLSession(
            configuration: configuration,
            delegate: sessionDelegate,
            delegateQueue: delegateQueue
        )
        sessionStorage = session
        return session
    }

    /// Relays the limit `setMaxConcurrentRequests` chose. MapLibre's own limit
    /// stops governing a request once this protocol takes it over, because the
    /// connection is then opened on the session above and not on MapLibre's, so
    /// without this the public API would be inert whenever custom headers are
    /// set. A URLSession copies its configuration at construction and never
    /// re-reads it, so the session is dropped and rebuilt; requests already in
    /// flight finish on the old one.
    static func setMaxConnectionsPerHost(_ value: Int) {
        sessionLock.lock()
        configuredMaxConnectionsPerHost = value
        let previous = sessionStorage
        sessionStorage = nil
        sessionLock.unlock()
        previous?.finishTasksAndInvalidate()
    }

    // Guards `activeTask` and `finished`, which stopLoading() and the delegate
    // callbacks reach from different threads.
    private let lock = NSLock()
    private var activeTask: URLSessionDataTask?
    // Set once the load is over, by cancellation, redirection or completion, so
    // the task is released exactly once and a completion landing after a
    // cancellation is dropped.
    //
    // This does not make a late client call impossible: a callback that has
    // already read its handler and is about to call the client can still be
    // overtaken by stopLoading(). Closing that window would mean holding `lock`
    // across the call into the client, and the client can re-enter
    // stopLoading() synchronously from inside that call, so the lock would have
    // to be held across a CFNetwork call-out that may itself be waiting on the
    // thread calling stopLoading(). A deadlock there is worse than the rare
    // late callback, so the window stays open deliberately. What does hold is
    // that no callback dispatched *after* stopLoading() finds this instance at
    // all, because stopLoading() unregisters before cancelling.
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
        // Registered under the same lock as `activeTask`, so stopLoading() can never
        // observe a half-started load.
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

    /// Marks the load over and reports whether this call is the one that ended
    /// it, so only the first of a racing cancellation and completion speaks to
    /// the client.
    private func claimCompletion() -> Bool {
        lock.lock()
        let wasFinished = finished
        finished = true
        activeTask = nil
        lock.unlock()
        return !wasFinished
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
        // Reporting a redirect hands the load back to the client, which cancels
        // this instance and starts a fresh request for the new URL, so nothing
        // further from this task concerns us.
        guard claimCompletion() else { return }
        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
    }

    fileprivate func didComplete(with error: Error?) {
        guard claimCompletion() else { return }
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
    // Keyed by object identity rather than `taskIdentifier`: identifiers are
    // only unique within one session, and invalidateSession() can leave an old
    // session draining alongside the new one.
    private var handlers: [ObjectIdentifier: MapLibreHeadersProtocol] = [:]

    func register(_ handler: MapLibreHeadersProtocol, for task: URLSessionTask) {
        lock.lock()
        handlers[ObjectIdentifier(task)] = handler
        lock.unlock()
    }

    func unregister(_ task: URLSessionTask) {
        lock.lock()
        handlers.removeValue(forKey: ObjectIdentifier(task))
        lock.unlock()
    }

    private func handler(for task: URLSessionTask) -> MapLibreHeadersProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[ObjectIdentifier(task)]
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
        // Report it or follow it, never both: following as well fetched the
        // target a second time, on a connection the client then threw away when
        // it restarted the load. Letting the client restart is also what gets
        // the custom headers re-evaluated against the redirect target, which
        // URLSession's own redirect handling would not do.
        completionHandler(nil)
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let handler = handler(for: task)
        unregister(task)
        handler?.didComplete(with: error)
    }
}

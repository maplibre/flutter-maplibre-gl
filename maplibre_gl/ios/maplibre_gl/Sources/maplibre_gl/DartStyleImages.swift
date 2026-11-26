import Foundation

/// Dart-supplied images belong to a style, rather than to its individual tiles.
final class DartStyleImages {
    private let lock = NSLock()
    private var registered = Set<String>()

    /// Whether this call introduced ownership, for failed-add rollback.
    @discardableResult
    func register(_ imageId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return registered.insert(imageId).inserted
    }

    func canRemoveUnused(_ imageId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !registered.contains(imageId)
    }

    func unregister(_ imageId: String) {
        lock.lock()
        defer { lock.unlock() }
        registered.remove(imageId)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        registered.removeAll()
    }
}

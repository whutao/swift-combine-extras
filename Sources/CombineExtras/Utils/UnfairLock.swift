import Foundation

final class UnfairLock: @unchecked Sendable {
    
    private let lock: os_unfair_lock_t
    
    init() {
        lock = os_unfair_lock_t.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
    }
    
    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }
    
    @discardableResult
    func sync<T>(_ operation: () throws -> T) rethrows -> T {
        defer {
            os_unfair_lock_unlock(lock)
        }
        os_unfair_lock_lock(lock)
        return try operation()
    }
}

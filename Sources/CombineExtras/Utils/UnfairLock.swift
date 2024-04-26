import Foundation

final class UnfairLock: @unchecked Sendable {
    
    private let _lock: os_unfair_lock_t
    
    init() {
        _lock = os_unfair_lock_t.allocate(capacity: 1)
        _lock.initialize(to: os_unfair_lock())
    }
    
    deinit {
        _lock.deinitialize(count: 1)
        _lock.deallocate()
    }
    
    @discardableResult
    func sync<T>(_ operation: () throws -> T) rethrows -> T {
        defer {
            os_unfair_lock_unlock(_lock)
        }
        os_unfair_lock_lock(_lock)
        return try operation()
    }
}

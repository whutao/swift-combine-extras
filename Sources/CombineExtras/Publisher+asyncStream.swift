import Combine
import ConcurrencyExtras
import Foundation

extension Publisher where Failure == Never {
    
    /// Creates an async stream from a publisher.
    public func asyncStream() -> AsyncStream<Output> {
        return AsyncStream(_PublisherAsyncSequence(self))
    }
}

private final class _PublisherAsyncSequence<Upstream: Publisher>:
    AsyncSequence,
    AsyncIteratorProtocol
where Upstream.Failure == Never {
    
    typealias Element = Upstream.Output
    typealias AsyncIterator = _PublisherAsyncSequence<Upstream>
    
    private let stream: AsyncStream<Upstream.Output>
    private var subscription: AnyCancellable?
    private lazy var iterator = stream.makeAsyncIterator()
    
    init(_ upstream: Upstream) {
        var _subscription: AnyCancellable? = nil
        
        stream = AsyncStream(Upstream.Output.self) { continuation in
            _subscription = upstream
                .handleEvents(receiveCancel: continuation.finish)
                .sink(
                    receiveCompletion: { _ in continuation.finish() },
                    receiveValue: { value in continuation.yield(value) }
                )
        }
        subscription = _subscription
    }
    
    func makeAsyncIterator() -> _PublisherAsyncSequence<Upstream> {
        return self
    }
    
    func next() async -> Element? {
        return await iterator.next()
    }
}

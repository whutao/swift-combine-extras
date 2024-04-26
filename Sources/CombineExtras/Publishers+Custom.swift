// https://github.com/CombineCommunity/CombineExt/blob/main/Sources/Operators/Create.swift
// https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Internal/Create.swift

import Combine
import Foundation

extension AnyPublisher {
    
    /// Creates a custom type-erased publisher.
    @inlinable
    public init(
        _ cancellable: @escaping (Publishers.Custom<Output, Failure>.Subscriber) -> Cancellable
    ) {
        self = Publishers.Custom(cancellable: cancellable).eraseToAnyPublisher()
    }
}

extension Publishers {
    
    public struct Custom<Output, Failure: Error>: Publisher {
        
        private let cancellable: (Subscriber) -> Cancellable
        
        public init(cancellable: @escaping (Subscriber) -> Cancellable) {
            self.cancellable = cancellable
        }
        
        public func receive<S: Combine.Subscriber>(
            subscriber: S
        ) where S.Input == Output, S.Failure == Failure {
            let subscription = Subscription(
                downstream: subscriber,
                cancellable: cancellable
            )
            subscriber.receive(subscription: subscription)
        }
    }
}

extension Publishers.Custom {
    
    public struct Subscriber {
        
        private let receiveValue: (Output) -> Void
        private let receiveCompletion: (Subscribers.Completion<Failure>) -> Void
        
        init(
            receiveValue: @escaping (Output) -> Void,
            receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void
        ) {
            self.receiveValue = receiveValue
            self.receiveCompletion = receiveCompletion
        }
        
        func send(value: Output) {
            receiveValue(value)
        }
        
        func send(completion: Subscribers.Completion<Failure>) {
            receiveCompletion(completion)
        }
    }
    
    public final class Subscription<Downstream: Combine.Subscriber>:
        Combine.Subscription
    where
        Downstream.Input == Output,
        Downstream.Failure == Failure
    {
        
        private let buffer: DemandBuffer<Downstream>
        private let cancellable: Cancellable?
        
        init(
            downstream: Downstream,
            cancellable: (Subscriber) -> Cancellable
        ) {
            self.buffer = DemandBuffer(subscriber: downstream)
            self.cancellable = cancellable(Subscriber(
                receiveValue: { [weak buffer] output in
                    buffer?.buffer(value: output)
                },
                receiveCompletion: { [weak buffer] completion in
                    buffer?.complete(with: completion)
                }
            ))
        }
        
        public func request(_ demand: Subscribers.Demand) {
            buffer.demand(demand)
        }
        
        public func cancel() {
            cancellable?.cancel()
        }
    }
}

fileprivate final class DemandBuffer<S: Combine.Subscriber>: @unchecked Sendable {
    
    private struct Demand {
        var processed: Subscribers.Demand = .none
        var requested: Subscribers.Demand = .none
        var sent: Subscribers.Demand = .none
    }
    
    private let lock = UnfairLock()
    private let subscriber: S
    private var buffer: Array<S.Input> = []
    private var demand = Demand()
    private var completion: Subscribers.Completion<S.Failure>?
    
    init(subscriber: S) {
        self.subscriber = subscriber
    }
    
    func complete(with newCompletion: Subscribers.Completion<S.Failure>) {
      precondition(completion == nil)
        
      completion = newCompletion
      flush()
    }
    
    @discardableResult
    func buffer(value: S.Input) -> Subscribers.Demand {
        precondition(completion == nil)
        
        if demand.requested == .unlimited {
            return subscriber.receive(value)
        } else {
            buffer.append(value)
            return flush()
        }
    }
    
    @discardableResult
    func demand(_ demand: Subscribers.Demand) -> Subscribers.Demand {
        flush(adding: demand)
    }
    
    @discardableResult
    private func flush(adding newDemand: Subscribers.Demand? = nil) -> Subscribers.Demand {
        lock.sync {
            if let newDemand {
                demand.requested += newDemand
            }
            
            // Return immediately if buffer isn't ready for flushing
            guard demand.requested > 0 else { return .none }
            guard newDemand == Subscribers.Demand.none else { return .none }
            
            while !buffer.isEmpty && demand.processed < demand.requested {
                demand.requested += subscriber.receive(buffer.remove(at: 0))
                demand.processed += 1
            }
            
            // Completion event was already sent
            if let completion {
                self.completion = nil
                buffer = []
                demand = Demand()
                subscriber.receive(completion: completion)
                return .none
            }
            
            let sentDemand = demand.requested - demand.sent
            demand.sent += sentDemand
            return sentDemand
        }
    }
}

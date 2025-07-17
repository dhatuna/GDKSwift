// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@preconcurrency import Combine

public actor GDKSwift {
    public static let shared = GDKSwift()

    private var dispatcher: GDKDispatcher?
    private var config: GDKConfiguration?
    private let httpClient = GDKHttpClient()
    private let subject = PassthroughSubject<GDKEvent, Never>()

    public var publisher: AnyPublisher<GDKEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    private init() {}

    public func initialize(with config: GDKConfiguration) {
        self.config = config
        self.dispatcher = GDKDispatcher(config: config)
        addDefaultEndpointConsumer()
        addCombinePassthroughSubscriber()
    }

    public func trackEvent(_ event: GDKEvent) async {
        await dispatcher?.enqueue(event)
    }

    public func addSubscriber(_ handler: @escaping @Sendable (GDKEvent) async -> Void) async {
        let subscriber = GDKSubscriber(handler: handler)
        await dispatcher?.addSubscriber(subscriber)
    }

    public func removeSubscriber(id: UUID) async {
        await dispatcher?.removeSubscriber(id)
    }

    private func addDefaultEndpointConsumer() {
        guard let dispatcher, let config else { return }

        let endpointSubscriber = GDKSubscriber { [config] event in
            await self.sendToEndpoint(event: event, config: config)
        }
        Task { await dispatcher.addSubscriber(endpointSubscriber) }
    }

    private func addCombinePassthroughSubscriber() {
        guard let dispatcher else { return }

        let passthrough = GDKSubscriber { [weak self] event in
            await self?.subject.send(event)
        }

        Task { await dispatcher.addSubscriber(passthrough) }
    }

    private func sendToEndpoint(event: GDKEvent, config: GDKConfiguration) async {
        let parameters: [String: Any] = [
            "id": event.id.uuidString,
            "name": event.name,
            "payload": event.payload,
            "timestamp": ISO8601DateFormatter().string(from: event.timestamp)
        ]

        for attempt in 1...config.maxRetryCount {
            do {
                _ = try await httpClient.request(to: config.endpointURL.absoluteString, method: .post, parameters: parameters) as GDKHttpClient.EmptyResponse
                return
            } catch {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
            }
        }

        // TODO: Notify failureSubscribers (optional)
    }
}

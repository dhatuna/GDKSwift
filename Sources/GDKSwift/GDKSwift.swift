// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@preconcurrency import Combine

public actor GDKSwift {
    public static let shared = GDKSwift()

    private var dispatcher: GDKDispatcher?
    private var config: GDKConfiguration?
    private let httpClient: GDKHttpClientProtocol
    private let subject = PassthroughSubject<GDKEvent, Never>()

    public var publisher: AnyPublisher<GDKEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(httpClient: GDKHttpClientProtocol? = nil) {
        self.httpClient = httpClient ?? GDKHttpClient()
    }

    public func initialize(with config: GDKConfiguration) {
        self.config = config
        self.dispatcher = GDKDispatcher(config: config)
        addDefaultEndpointConsumer()
        addCombinePassthroughSubscriber()
        
        Task { await restoreFailedEvents() }
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
                _ = try await httpClient.request(to: config.endpointURL.absoluteString, method: .post, headers: nil, parameters: parameters, attachments: nil) as GDKHttpClient.EmptyResponse
                return
            } catch {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
            }
        }

        persistFailedEvent(event)
    }
    
    private func persistFailedEvent(_ event: GDKEvent) {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("gdk_failed_events.json")

        var events: [GDKEvent] = []
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([GDKEvent].self, from: data) {
            events = decoded
        }

        events.append(event)
        if let newData = try? JSONEncoder().encode(events) {
            try? newData.write(to: url)
        }
    }

    private func restoreFailedEvents() async {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("gdk_failed_events.json")

        guard let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([GDKEvent].self, from: data) else {
            return
        }

        try? FileManager.default.removeItem(at: url)

        for event in events {
            await trackEvent(event)
        }
    }
}

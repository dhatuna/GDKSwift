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
    private let persistentFileURL: URL

    public var publisher: AnyPublisher<GDKEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(httpClient: GDKHttpClientProtocol? = nil, backupURL: URL? = nil) {
        self.httpClient = httpClient ?? GDKHttpClient()
        
        self.persistentFileURL = backupURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("gdk_failed_events.json")
    }

    public func initialize(with config: GDKConfiguration, skipDefaults: Bool = false) {
        self.config = config
        self.dispatcher = GDKDispatcher(config: config)
        
        if !skipDefaults {
            addDefaultEndpointConsumer()
            addCombinePassthroughSubscriber()
        }
        
        Task { await restoreQueue() }
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

    public func persistCurrentQueue() async {
        guard let dispatcher else { return }
        await dispatcher.saveQueue(to: persistentFileURL)
    }

    public func restoreQueue() async {
        guard let dispatcher else { return }
        await dispatcher.loadQueue(from: persistentFileURL)
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
        var events: [GDKEvent] = []
        if let data = try? Data(contentsOf: persistentFileURL),
           let decoded = try? JSONDecoder().decode([GDKEvent].self, from: data) {
            events = decoded
        }

        events.append(event)
        if let newData = try? JSONEncoder().encode(events) {
            try? newData.write(to: persistentFileURL)
        }
    }
}

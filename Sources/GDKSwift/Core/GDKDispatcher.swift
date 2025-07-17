//
//  GDKDispatcher.swift
//  GDKSwift
//
//  Created by Junkyu Jeon on 7/17/25.
//

import Foundation

actor GDKDispatcher {
    private var eventQueue: [GDKEvent] = []
    private var subscribers: [UUID: GDKSubscriber] = [:]
    private var subscriberOffsets: [UUID: Int] = [:]

    private let config: GDKConfiguration

    init(config: GDKConfiguration) {
        self.config = config
    }

    func enqueue(_ event: GDKEvent) {
        eventQueue.append(event)
        Task.detached(priority: .background) { [weak self] in
            await self?.dispatch()
        }
    }

    func addSubscriber(_ subscriber: GDKSubscriber) {
        subscribers[subscriber.id] = subscriber
        subscriberOffsets[subscriber.id] = 0
        Task { await dispatch() }
    }

    func removeSubscriber(_ id: UUID) {
        subscribers.removeValue(forKey: id)
        subscriberOffsets.removeValue(forKey: id)
    }

    func saveQueue(to url: URL) {
        if let data = try? JSONEncoder().encode(eventQueue) {
            try? data.write(to: url)
        }
    }

    func loadQueue(from url: URL) async {
        guard let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([GDKEvent].self, from: data) else { return }

        for event in loaded {
            await enqueue(event)
        }
    }
    
    private func dispatch() async {
        for (id, subscriber) in subscribers {
            guard var offset = subscriberOffsets[id] else { continue }
            while offset < eventQueue.count {
                let event = eventQueue[offset]
                await subscriber.handler(event)
                offset += 1
                subscriberOffsets[id] = offset
            }
        }
        cleanupConsumedEvents()
    }

    private func cleanupConsumedEvents() {
        let minOffset = subscriberOffsets.values.min() ?? 0
        guard minOffset > 0 else { return }

        eventQueue.removeFirst(minOffset)
        for id in subscriberOffsets.keys {
            subscriberOffsets[id]! -= minOffset
        }
    }
}

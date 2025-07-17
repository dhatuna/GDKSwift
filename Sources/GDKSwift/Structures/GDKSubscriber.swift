//
//  GDKSubscriber.swift
//  GDKSwift
//
//  Created by Junkyu Jeon on 7/10/25.
//

import Foundation

public struct GDKSubscriber: Sendable {
    public let id: UUID
    public let handler: @Sendable (GDKEvent) async -> Void

    public init(id: UUID = UUID(), handler: @escaping @Sendable (GDKEvent) async -> Void) {
        self.id = id
        self.handler = handler
    }
}

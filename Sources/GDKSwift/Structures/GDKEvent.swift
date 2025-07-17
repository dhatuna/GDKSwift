//
//  GDKEvent.swift
//  GDKSwift
//
//  Created by Junkyu Jeon on 7/3/25.
//

import Foundation

public struct GDKEvent: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let payload: [String: String]
    public let timestamp: Date

    public init(name: String, payload: [String: String]) {
        self.id = UUID()
        self.name = name
        self.payload = payload
        self.timestamp = Date()
    }
}


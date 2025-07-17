//
//  GDKEvent.swift
//  GDKSwift
//
//  Created by Junkyu Jeon on 7/3/25.
//

import Foundation

import AnyCodable

public struct GDKEvent: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let payload: [String: AnyCodable]
    public let timestamp: Date

    public init(name: String, payload: [String: AnyCodable]) {
        self.id = UUID()
        self.name = name
        self.payload = payload
        self.timestamp = Date()
    }
}


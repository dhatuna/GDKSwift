//
//  File.swift
//  GDKSwift
//
//  Created by Junkyu Jeon on 7/15/25.
//

import Foundation

public struct GDKConfiguration {
    public let endpointURL: URL
    public let maxRetryCount: Int

    public init(endpointURL: URL, maxRetryCount: Int = 10) {
        self.endpointURL = endpointURL
        self.maxRetryCount = maxRetryCount
    }
}

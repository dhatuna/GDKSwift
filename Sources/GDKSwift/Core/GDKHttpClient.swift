//
//  GDKHttpClient.swift
//  GDKSwift
//
//  Created by Junkyu Jeon on 7/17/25.
//
//  Fully redesigned based on Swift concurrency


import Foundation

enum GDKHttpError: Error {
    case unknownEndpoint(String)
    case invalidResponse(URLResponse)
    case failedResponse(Int, HTTPURLResponse)
    case decodeError(Error)
    case encodeError(Error)
}

final class GDKHttpClient: Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder
    
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
        case multipartPost = "MULTIPART_POST"
    }
    
    init(session: URLSession = .shared, decoder: JSONDecoder = .init()) {
        self.session = session
        self.decoder = decoder
    }
    
    func request<T: Decodable>(to endpoint: String, method: Method = .get, headers: [String:String]? = nil, parameters: [String:Any]?, attachments: [String:Data]? = nil) async throws -> T {
        guard var url = URL(string: endpoint) else {
            throw GDKHttpError.unknownEndpoint(endpoint)
        }
        
        var request = URLRequest(url: url)
        
        if let headerValues = headers {
            for (key, value) in headerValues {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        if method == .get {
            if let parameters {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.queryItems = parameters.map { key, value in
                    URLQueryItem(name: key, value: String(describing: value))
                }
                if let composed = components?.url {
                    url = composed
                }
            }
            request = URLRequest(url: url)
        } else if method == .multipartPost, let files = attachments {
            let boundary = UUID().uuidString
            request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()

            if let parameters {
                for (key, value) in parameters {
                    body.append("--\(boundary)\r\n".data(using: .utf8)!)
                    body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                    body.append("\(String(describing: value))\r\n".data(using: .utf8)!)
                }
            }

            for (filename, fileData) in files {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
                body.append(fileData)
                body.append("\r\n".data(using: .utf8)!)
            }

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body
        } else {
            request = URLRequest(url: url)
            if let parameters {
                do {
                    let data = try JSONSerialization.data(withJSONObject: parameters, options: [])
                    request.httpBody = data
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                } catch {
                    throw GDKHttpError.encodeError(error)
                }
            }
        }
        
        request.httpMethod = method == .multipartPost ? "POST" : method.rawValue

        let (data, response) = try await session.data(for: URLRequest(url: url))
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GDKHttpError.invalidResponse(response)
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            throw GDKHttpError.failedResponse(httpResponse.statusCode, httpResponse)
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GDKHttpError.decodeError(error)
        }
    }
    
    public struct EmptyResponse: Decodable {}
}



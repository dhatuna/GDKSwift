import XCTest

@preconcurrency import Combine

@testable import GDKSwift

final class GDKSwiftTests: XCTestCase {
    final class MockHttpClient: GDKHttpClientProtocol, @unchecked Sendable {
        var receivedParameters: [String: Any]? = nil
        var shouldFail = false
        var callCount = 0
        var expectation: XCTestExpectation? = nil

        func request<T>(to endpoint: String, method: GDKHttpClient.Method, headers: [String : String]? = nil, parameters: [String : Any]?, attachments: [String : Data]? = nil) async throws -> T where T : Decodable {
            callCount += 1
            receivedParameters = parameters

            if let expectation = expectation {
                expectation.fulfill()
            }
            
            if shouldFail {
                throw URLError(.badServerResponse)
            }

            guard let empty = GDKHttpClient.EmptyResponse() as? T else {
                fatalError("Mock only supports EmptyResponse")
            }
            return empty
        }
    }

    func testTrackEvent_SuccessfulSend() async throws {
        let mockClient = MockHttpClient()
        let config = GDKConfiguration(endpointURL: URL(string: "https://iam.jk")!, maxRetryCount: 3)
        let sdk = GDKSwift(httpClient: mockClient)

        await sdk.initialize(with: config)

        let event = GDKEvent(name: "test_event", payload: ["key": "value"])

        await sdk.trackEvent(event)
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(mockClient.callCount, 1)
        XCTAssertEqual(mockClient.receivedParameters?["name"] as? String, "test_event")
    }

    func testTrackEvent_FailureRetriesUpToMax() async throws {
        let mockClient = MockHttpClient()
        mockClient.shouldFail = true
        let config = GDKConfiguration(endpointURL: URL(string: "https://iam.jk")!, maxRetryCount: 3)
        let sdk = GDKSwift(httpClient: mockClient)

        await sdk.initialize(with: config)

        let event = GDKEvent(name: "fail_event", payload: [:])
        let expectation = XCTestExpectation(description: "Should retry 3 times")
        Task {
            while mockClient.callCount < 3 {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            expectation.fulfill()
        }

        await sdk.trackEvent(event)
        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertEqual(mockClient.callCount, 3)
    }

    func testAddSubscriber_ReceivesEvent() async throws {
        let mockClient = MockHttpClient()
        let config = GDKConfiguration(endpointURL: URL(string: "https://iam.jk")!)
        let sdk = GDKSwift(httpClient: mockClient)

        await sdk.initialize(with: config)

        let expectation = XCTestExpectation(description: "Subscriber received event")

        await sdk.addSubscriber { event in
            if event.name == "subscriber_test" {
                expectation.fulfill()
            }
        }

        let event = GDKEvent(name: "subscriber_test", payload: [:])

        await sdk.trackEvent(event)

        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // 실패 또는 미전송 이벤트 - SDK 초기화시 재전송 테스트
    func testRestorePersistedEventsOnInitialize() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("GDKEvents.json")
        let event = GDKEvent(name: "restored_event", payload: ["key": "value"])
        let data = try JSONEncoder().encode([event])
        try data.write(to: fileURL)

        let mockClient = MockHttpClient()
        mockClient.shouldFail = false
        let expectation = XCTestExpectation(description: "Restored event was sent")
        mockClient.expectation = expectation

        let config = GDKConfiguration(endpointURL: URL(string: "https://iam.jk")!)
        let sdk = GDKSwift(httpClient: mockClient, backupURL: fileURL)

        await sdk.initialize(with: config)

        await fulfillment(of: [expectation], timeout: 3.0)

        XCTAssertEqual(mockClient.callCount, 1)
        XCTAssertEqual(mockClient.receivedParameters?["name"] as? String, "restored_event")

        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func testCombinePublisherReceivesEvent() async throws {
        let mockClient = MockHttpClient()
        let sdk = GDKSwift(httpClient: mockClient)
        let config = GDKConfiguration(endpointURL: URL(string: "https://iam.jk")!)
        await sdk.initialize(with: config)

        let expectation = XCTestExpectation(description: "Combine received event")
        var cancellables = Set<AnyCancellable>()

        await sdk.publisher
            .sink { event in
                if event.name == "combine_event" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        let event = GDKEvent(name: "combine_event", payload: [:])
        await sdk.trackEvent(event)

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testSubscriberOffsetIsTrackedCorrectly() async throws {
        actor Recorder {
            private var names: [String] = []
            
            func append(_ name: String) {
                names.append(name)
            }
            
            func get() -> [String] {
                names
            }
        }
        
        
        let mockClient = MockHttpClient()
        let sdk = GDKSwift(httpClient: mockClient)
        let config = GDKConfiguration(endpointURL: URL(string: "https://iam.jk")!)
        await sdk.initialize(with: config, skipDefaults: true)
        
        let recorderA = Recorder()
        let recorderB = Recorder()
        
        await sdk.addSubscriber { event in
            await recorderA.append(event.name)
        }
        
        await sdk.addSubscriber { event in
            await recorderB.append(event.name)
        }
        
        await sdk.trackEvent(GDKEvent(name: "A", payload: [:]))
        await sdk.trackEvent(GDKEvent(name: "B", payload: [:]))
        await sdk.trackEvent(GDKEvent(name: "C", payload: [:]))
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let receivedA = await recorderA.get()
        let receivedB = await recorderB.get()
        
        XCTAssertEqual(receivedA, ["A", "B", "C"])
        XCTAssertEqual(receivedB, ["A", "B", "C"])
    }
}

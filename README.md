# GDKSwift

Swift 기반의 경량 SDK로, 플레이오 이벤트 추적 및 전송 기능을 제공합니다.

## 🚀 주요 기능

- ✅ 비동기 이벤트 트래킹 및 디스패칭
- 🔁 자동 재시도 로직 (최대 재시도 횟수 설정 가능)
- 💾 실패 이벤트 로컬 저장 및 앱 재실행 시 복원
- 🔗 Combine 퍼블리셔 지원으로 외부 구독 가능
- 🧵 Swift Concurrency 기반 Actor 사용으로 안전한 상태 관리
- 🔌 사용자 정의 Subscriber 추가 가능

---

## ✨ 사용법

### 1. SDK 초기화

```swift
let config = GDKConfiguration(endpointURL: URL(string: "https://example.com/events")!, maxRetryCount: 3)
let sdk = GDKSwift()
await sdk.initialize(with: config)
```

### 2. 이벤트 전송

```swift
let event = GDKEvent(name: "user_signup", payload: ["source": "email"])
await sdk.trackEvent(event)
```

### 3. Combine을 통해 이벤트 구독

```swift
let cancellable = sdk.publisher.sink { event in
    print("Combine으로 수신된 이벤트: \\(event)")
}
```

### 4. 사용자 정의 Subscriber 등록

```swift
await sdk.addSubscriber { event in
    print("커스텀 처리: \\(event.name)")
}
```

---

## 💡 기본 동작

- **초기화 시**:
  - 서버로 전송하는 기본 subscriber 추가
  - Combine 퍼블리셔 subscriber 추가
  - 이전 실패 이벤트 복원 및 재전송 시도

- **이벤트 전송 실패 시**:
  - 설정된 횟수까지 재시도 (1초, 2초, ... 간격)
  - 여전히 실패할 경우 로컬에 JSON으로 저장

---

## 📦 GDKConfiguration

```swift
public struct GDKConfiguration: Sendable {
    public let endpointURL: URL
    public let maxRetryCount: Int

    public init(endpointURL: URL, maxRetryCount: Int = 10)
}
```

---

## 🧪 단위 테스트 예시

```swift
func testTrackEvent_PublishesViaCombine() async throws {
    let expectation = XCTestExpectation(description: "이벤트 수신 기대")
    let sdk = GDKSwift()
    let config = GDKConfiguration(endpointURL: URL(string: "https://example.com")!)
    await sdk.initialize(with: config)

    var cancellable: AnyCancellable?
    cancellable = sdk.publisher.sink { event in
        if event.name == "test_event" {
            expectation.fulfill()
        }
    }

    await sdk.trackEvent(GDKEvent(name: "test_event", payload: [:]))
    await fulfillment(of: [expectation], timeout: 2.0)
    cancellable?.cancel()
}
```

---

## 📁 로컬 이벤트 백업

- 실패한 이벤트는 기본적으로 `gdk_failed_events.json` 파일에 저장됩니다.
- 초기화 시 복원되며 자동 전송됩니다.
- 사용자 정의 경로 사용 예시:

```swift
let backupURL = FileManager.default.temporaryDirectory.appendingPathComponent("MyBackup.json")
let sdk = GDKSwift(backupURL: backupURL)
```

---

## 🔐 스레드 안정성

Swift의 `actor` 모델을 사용하여 멀티스레드 환경에서도 안전한 이벤트 처리 보장.

---

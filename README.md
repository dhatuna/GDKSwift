좋습니다. 경고 메시지:

Sending 'event' risks causing data races

이건 Swift Concurrency의 Sendable 안전성 체크로 인한 경고입니다. 이유는:

⸻

🧠 원인 요약
    •    trackEvent(_:)는 async 함수이고
    •    내부에서 dispatcher?.enqueue(event)로 actor에 이벤트 전달하려고 함
    •    그런데 GDKEvent 타입이 Sendable을 채택하지 않았거나 Swift가 이를 확신하지 못함
    •    → 따라서 이 event를 actor로 “보내는” 행위가 데이터 레이스 위험이라 판단


>> Payload 의 value 값을 String으로 처리하므로서 완전한 Sendable safe 보장

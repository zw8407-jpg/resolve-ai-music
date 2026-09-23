import Foundation
import Testing
@testable import ResolveAIMusic

private final class MockChatProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let denied = request.value(forHTTPHeaderField: "Authorization") == "Bearer denied"
        let data = Data((denied ? #"{"error":{"code":"401007"}}"# : #"{"choices":[{"message":{"content":"轻柔弦乐起势，渐入铜管主题，完整收束。无人声。"}}]}"#).utf8)
        let response = HTTPURLResponse(url: request.url!, statusCode: denied ? 402 : 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

struct ComposerTests {
    func client() -> ComposerClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockChatProtocol.self]
        return ComposerClient(session: URLSession(configuration: config))
    }
    @Test func testPromptResult() async throws {
        let value = try await client().compose(key: "test-only", model: "hy3", text: "黎明升旗", style: "雄壮升旗", duration: 20, explain: false)
        #expect(value.contains("弦乐"))
    }
    @Test func testUnenabledLLM() async {
        do {
            _ = try await client().compose(key: "denied", model: "hy3", text: "test", style: "test", duration: 20, explain: false)
            Issue.record("Expected billing error")
        } catch { #expect(error.localizedDescription.contains("hy3")) }
    }
}

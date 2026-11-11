import XCTest
@testable import ScreenshotToolNative

final class PairingRecoveryTests: XCTestCase {
    @MainActor func testSuccessfulPairingCancelsOldPollWithoutOverwritingConnectedState() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root); PairingRecoveryProtocol.started = nil; PairingRecoveryProtocol.stopped = nil }
        let started = expectation(description: "old network request started")
        let stopped = expectation(description: "old network request cancelled after pairing")
        let returned = expectation(description: "poll loop released without waiting for network timeout")
        PairingRecoveryProtocol.started = { started.fulfill() }
        PairingRecoveryProtocol.stopped = { stopped.fulfill() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PairingRecoveryProtocol.self]
        let old = try Connection.parse("http://127.0.0.1:8765/#pair=pairing-recovery-test-old")
        let model = WorkspaceModel(connection: old, configuration: configuration, draftRoot: root, rememberConnection: { _ in })
        let task = Task { await model.poll(); returned.fulfill() }
        defer { task.cancel() }
        await fulfillment(of: [started], timeout: 2)
        await model.pair("http://127.0.0.1:8766/#pair=pairing-recovery-test-new")
        XCTAssertTrue(model.connected)
        await fulfillment(of: [stopped, returned], timeout: 1)
        XCTAssertTrue(model.connected, "The cancelled old request must not mark the new connection unavailable")
        await model.poll()
        XCTAssertTrue(model.connected)
        XCTAssertEqual(model.status, "Ready for your next screenshot.")
    }
}

private final class PairingRecoveryProtocol: URLProtocol {
    static var started: (() -> Void)?
    static var stopped: (() -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if request.url?.port == 8765 { Self.started?(); return }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"captures\":[]}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { if request.url?.port == 8765 { Self.stopped?() } }
}

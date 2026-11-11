import Foundation
import Network

final class NearbyTestHTTP: URLProtocol {
    static let lock = NSLock()
    static var requests = 0
    static var nextStatus = 200
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.requests += 1; let status = Self.nextStatus; Self.lock.unlock()
        precondition(request.url!.host == "127.0.0.1")
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-nearby-transport-key-0123456789")
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 65536)
            while true {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(contentsOf: buffer.prefix(count))
            }
        }
        if body.isEmpty { body = Data("{\"captures\":[],\"supportsSessions\":true}".utf8) }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
    static func count() -> Int { lock.lock(); defer { lock.unlock() }; return requests }
    static func setStatus(_ status: Int) { lock.lock(); defer { lock.unlock() }; nextStatus = status }
}

@main struct NearbyTransportTests {
    static func waitForListener(_ semaphore: DispatchSemaphore) -> DispatchTimeoutResult {
        semaphore.wait(timeout: .now() + 5)
    }
    static func main() async throws {
        let token = "test-nearby-transport-key-0123456789"
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [NearbyTestHTTP.self]
        let ready = DispatchSemaphore(value: 0)
        let bridge = try NearbyBridge(token: token, localPort: 8765, advertise: false, configuration: config) { if $0 { ready.signal() } }
        defer { bridge.stop() }
        let readyResult = await Task.detached { waitForListener(ready) }.value
        guard readyResult == .success, let port = bridge.port else { fatalError("Test listener did not start") }
        let endpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: port)
        let request = NearbyRequest(path: "api/library", body: nil, headers: [:])
        let response = try await NearbyExchange.request(request, token: token, endpoint: endpoint, timeout: 5)
        precondition(response.status == 200 && response.body.contains(123))
        precondition(NearbyTestHTTP.count() == 1)
        print("PASS: authenticated TLS round trip through Mac loopback bridge")

        let png = Data((0..<(2 * 1024 * 1024)).map { UInt8($0 % 251) })
        let save = NearbyRequest(path: "api/save", body: png, headers: ["Content-Type": "image/png", "X-Capture-ID": String(repeating: "a", count: 24), "X-Submission-ID": UUID().uuidString])
        let saved = try await NearbyExchange.request(save, token: token, endpoint: endpoint, timeout: 10)
        precondition(saved.body == png)
        print("PASS: multi-frame-size binary upload and response preserve every byte")

        NearbyTestHTTP.setStatus(409)
        let conflict = try await NearbyExchange.request(request, token: token, endpoint: endpoint, timeout: 5)
        precondition(conflict.status == 409)
        NearbyTestHTTP.setStatus(200)
        let before = NearbyTestHTTP.count()
        do { _ = try await NearbyExchange.request(request, token: "wrong-test-key-0123456789", endpoint: endpoint, timeout: 3); fatalError("Wrong pairing key accepted") }
        catch { precondition(NearbyTestHTTP.count() == before) }
        print("PASS: wrong key rejected before any HTTP API access; API status preserved")

        for invalid in [
            NearbyRequest(path: "https://example.com/", body: nil, headers: [:]),
            NearbyRequest(path: "api/image/../../secret", body: nil, headers: [:]),
            NearbyRequest(path: "api/library", body: nil, headers: ["Authorization": "other"]),
            NearbyRequest(path: "api/library", body: nil, headers: ["Host": "other"]),
            NearbyRequest(path: "api/save", body: Data([1]), headers: ["X-Capture-ID": "a\r\nHost: other"]),
            NearbyRequest(path: "api/session/reset", body: nil, headers: [:]),
            NearbyRequest(path: "api/status", body: Data([1]), headers: [:])
        ] {
            precondition(!invalid.isAllowed)
            do { _ = try await NearbyExchange.request(invalid, token: token, endpoint: endpoint, timeout: 1); fatalError("Invalid request accepted") }
            catch { precondition(NearbyTestHTTP.count() == before) }
        }
        for header in [Data(), Data([0,0,0,0]), Data([255,255,255,255])] {
            do { _ = try NearbyProtocol.frameSize(header); fatalError("Invalid frame accepted") } catch {}
        }
        // Cancellation must resolve even before NWConnection reaches ready.
        let cancelled = Task { try await NearbyExchange.request(request, token: token,
            endpoint: .hostPort(host: "127.0.0.1", port: 1), timeout: 30) }
        cancelled.cancel()
        do { _ = try await cancelled.value; fatalError("Cancelled request succeeded") } catch is CancellationError {} catch { fatalError("Cancellation was not preserved") }
        print("PASS: forbidden routes/headers/frames, cancellation, and no API side effects")
        bridge.stop()
        try await Task.sleep(nanoseconds: 100_000_000)
        do { _ = try await NearbyExchange.request(request, token: token, endpoint: endpoint, timeout: 1); fatalError("Stopped bridge accepted a request") } catch {}
        print("PASS: bridge shutdown closes the listener")
        do {
            _ = try await NearbyExchange.request(request, token: "absent-peer-" + UUID().uuidString, timeout: 0.3)
            fatalError("An absent peer unexpectedly connected")
        } catch {
            precondition(error.localizedDescription.contains("find your Mac"), "Discovery failure must be distinguished from a transfer failure")
        }
        print("PASS: missing peer reports discovery failure rather than a generic transfer error")
        let advertisedReady = DispatchSemaphore(value: 0)
        let advertised = try NearbyBridge(token: token, localPort: 8765, configuration: config) { if $0 { advertisedReady.signal() } }
        defer { advertised.stop() }
        let advertisedResult = await Task.detached { waitForListener(advertisedReady) }.value
        precondition(advertisedResult == .success)
        let resolved = try await NearbyExchange.request(request, token: token, timeout: 10)
        precondition(resolved.status == 200)
        print("PASS: Bonjour service resolution without specifying a Mac IP address")
        do {
            _ = try await NearbyExchange.request(request, token: "different-peer-" + UUID().uuidString, timeout: 0.3)
            fatalError("Discovery selected an unrelated service")
        } catch NearbyError.notDiscovered {} catch { fatalError("Unexpected discovery error: \(error)") }
        let browsing = Task { try await NearbyExchange.request(request, token: "cancelled-peer-" + UUID().uuidString, timeout: 30) }
        try await Task.sleep(nanoseconds: 100_000_000)
        browsing.cancel()
        do { _ = try await browsing.value; fatalError("Cancelled discovery succeeded") }
        catch is CancellationError {} catch { fatalError("Discovery cancellation was not preserved") }
        print("PASS: discovery ignores unrelated services and supports cancellation while searching")
    }
}

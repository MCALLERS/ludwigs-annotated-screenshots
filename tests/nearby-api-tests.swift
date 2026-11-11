import Foundation
import Network

@main struct NearbyAPITests {
    static func waitForListener(_ semaphore: DispatchSemaphore) -> DispatchTimeoutResult {
        semaphore.wait(timeout: .now() + 5)
    }
    static func main() async throws {
        let port = Int(CommandLine.arguments[1])!
        let root = URL(fileURLWithPath: CommandLine.arguments[2])
        let token = "test-only-token"
        let ready = DispatchSemaphore(value: 0)
        let bridge = try NearbyBridge(token: token, localPort: port, advertise: false) { if $0 { ready.signal() } }
        defer { bridge.stop() }
        let readiness = await Task.detached { waitForListener(ready) }.value
        precondition(readiness == .success)
        guard let nearbyPort = bridge.port else { fatalError("Bridge unavailable") }
        let endpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: nearbyPort)
        func call(_ path: String, body: Data? = nil, headers: [String:String] = [:]) async throws -> NearbyResponse {
            do {
                return try await NearbyExchange.request(NearbyRequest(path: path, body: body, headers: headers), token: token, endpoint: endpoint, timeout: 10)
            } catch { fputs("Fixture request failed: \(path)\n", stderr); throw error }
        }
        let first = try await call("api/library")
        precondition(first.status == 200)
        let library = try JSONDecoder().decode(LibraryResponse.self, from: first.body)
        precondition(library.captures.count == 1 && library.supportsSessions == true)
        let capture = library.captures[0]
        let image = try await call("api/image/" + capture.id)
        let original = try Data(contentsOf: root.appendingPathComponent("library/Inbox/capture.png"))
        precondition(image.status == 200 && image.body == original)
        let id = UUID().uuidString.lowercased()
        let headers = ["Content-Type":"image/png", "X-Capture-ID":capture.id, "X-Submission-ID":id]
        let saved = try await call("api/save", body: original, headers: headers)
        let retried = try await call("api/save", body: original, headers: headers)
        precondition(saved.status == 200 && retried.status == 200)
        let receipt = try JSONDecoder().decode(SaveReceipt.self, from: saved.body)
        let retryReceipt = try JSONDecoder().decode(SaveReceipt.self, from: retried.body)
        precondition(receipt.id == retryReceipt.id && receipt.filename == retryReceipt.filename)
        let exports = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("library/Ready").path)
        precondition(exports.count == 1)
        let exported = try Data(contentsOf: root.appendingPathComponent("library/Ready/" + receipt.filename))
        precondition(exported == original)
        // Simulate only the Mac clipboard acknowledgement file; never use the real clipboard.
        try JSONEncoder().encode(["id": id]).write(to: root.appendingPathComponent("state/clipboard-ack.json"))
        let status = try await call("api/status")
        let ack = try JSONDecoder().decode(MacStatus.self, from: status.body)
        precondition(ack.lastCopied == id)
        let reset = try await call("api/session/reset", body: JSONEncoder().encode(["requestID": UUID().uuidString]), headers: ["Content-Type":"application/json"])
        precondition(reset.status == 200)
        let empty = try JSONDecoder().decode(LibraryResponse.self, from: reset.body)
        precondition(empty.captures.isEmpty && empty.session != library.session)
        let fresh = root.appendingPathComponent("library/Inbox/new.png")
        try original.write(to: fresh)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-2)], ofItemAtPath: fresh.path)
        let previewResponse = try await call("api/library/cleanup")
        let preview = try JSONDecoder().decode(CleanupPreview.self, from: previewResponse.body)
        precondition(preview.fileCount == 2 && preview.captureCount == 1)
        let cleanup = try await call("api/library/cleanup", body: JSONEncoder().encode(["token": preview.token]), headers: ["Content-Type":"application/json"])
        let cleaned = try JSONDecoder().decode(CleanupReceipt.self, from: cleanup.body)
        precondition(cleanup.status == 200 && cleaned.movedFiles == 2)
        let final = try await call("api/library")
        let remaining = try JSONDecoder().decode(LibraryResponse.self, from: final.body)
        precondition(remaining.captures.count == 1 && remaining.captures[0].id != capture.id)
        precondition(FileManager.default.fileExists(atPath: fresh.path))
        let missing = try await call("api/image/" + capture.id)
        precondition(missing.status == 404)
        print("PASS: real API over TLS: library, PNG, idempotent save, clipboard ACK, reset, reviewed Trash cleanup, current-file preservation")
    }
}

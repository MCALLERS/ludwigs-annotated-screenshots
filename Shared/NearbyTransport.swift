import Foundation
import Network
import Security
import CryptoKit

// Shared by the Mac and iPad targets. The QR supplies a random 256-bit secret;
// only a domain-separated hash is advertised. TLS authenticates both devices.
enum NearbyProtocol {
    static let serviceType = "_ludwig-p2p._tcp"
    static let maxBody = 40 * 1024 * 1024
    static let maxFrame = 56 * 1024 * 1024 // JSON's base64 encoding adds one third.

    static func serviceName(token: String) -> String {
        "ludwig-" + SHA256.hash(data: Data(("ludwig-discovery-v1:" + token).utf8))
            .prefix(16).map { String(format: "%02x", $0) }.joined()
    }
    static func endpoint(token: String) -> NWEndpoint {
        .service(name: serviceName(token: token), type: serviceType, domain: "local.", interface: nil)
    }
    static func parameters(token: String) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        let key = Data(HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(token.utf8)),
            salt: Data("ludwig-nearby-v1".utf8), info: Data("TLS-PSK".utf8), outputByteCount: 32).withUnsafeBytes { Data($0) })
        let identity = Data("ludwig-nearby-v1".utf8)
        key.withUnsafeBytes { keyBytes in
            identity.withUnsafeBytes { identityBytes in
                sec_protocol_options_add_pre_shared_key(options,
                    DispatchData(bytes: keyBytes) as AnyObject as! dispatch_data_t,
                    DispatchData(bytes: identityBytes) as AnyObject as! dispatch_data_t)
            }
        }
        // Apple's NWConnection TLS-PSK implementation supports TLS 1.2, not 1.3.
        sec_protocol_options_set_min_tls_protocol_version(options, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(options, .TLSv12)
        sec_protocol_options_append_tls_ciphersuite(options, tls_ciphersuite_t(rawValue: TLS_PSK_WITH_AES_128_GCM_SHA256)!)
        let parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        parameters.includePeerToPeer = true
        return parameters
    }
    static func frame(_ data: Data) throws -> Data {
        guard !data.isEmpty, data.count <= maxFrame else { throw NearbyError.invalidFrame }
        var size = UInt32(data.count).bigEndian
        return withUnsafeBytes(of: &size) { Data($0) } + data
    }
    static func frameSize(_ header: Data) throws -> Int {
        guard header.count == 4 else { throw NearbyError.invalidFrame }
        let count = header.reduce(0) { ($0 << 8) | Int($1) }
        guard (1...maxFrame).contains(count) else { throw NearbyError.invalidFrame }
        return count
    }
    static func receive(_ connection: NWConnection, completion: @escaping (Result<Data, Error>) -> Void) {
        read(connection, remaining: 4, buffer: ReceiveBuffer(capacity: 4)) { result in
            do {
                let size = try frameSize(result.get())
                read(connection, remaining: size, buffer: ReceiveBuffer(capacity: size), completion: completion)
            } catch { completion(.failure(error)) }
        }
    }
    private final class ReceiveBuffer {
        var data = Data()
        init(capacity: Int) { data.reserveCapacity(capacity) }
    }
    private static func read(_ connection: NWConnection, remaining: Int, buffer: ReceiveBuffer,
                             completion: @escaping (Result<Data, Error>) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: min(remaining, 65536)) { data, _, complete, error in
            if let error { completion(.failure(error)); return }
            guard let data, !data.isEmpty else { completion(.failure(NearbyError.interrupted)); return }
            buffer.data.append(data)
            if data.count == remaining { completion(.success(buffer.data)) }
            else if complete { completion(.failure(NearbyError.interrupted)) }
            else { read(connection, remaining: remaining - data.count, buffer: buffer, completion: completion) }
        }
    }
}

enum NearbyError: LocalizedError {
    case unavailable, notDiscovered, localNetworkDenied, interrupted, invalidFrame, invalidRequest
    var errorDescription: String? {
        switch self {
        case .notDiscovered: return "Could not find your Mac nearby. Keep Ludwig open on your Mac, keep Wi-Fi and Bluetooth on, and bring the devices close. Your drawing is kept on this iPad."
        case .localNetworkDenied: return "Local Network access is blocked. Allow Ludwig in Settings → Privacy & Security → Local Network, then try again. Your drawing is kept on this iPad."
        case .unavailable: return "Could not connect to your nearby Mac. Keep both apps open, bring the devices close, turn on Wi-Fi and Bluetooth, and allow Local Network access. Update both apps and scan this Mac’s Nearby QR code."
        case .interrupted: return "The nearby connection was interrupted. Your drawing is kept on this iPad. Try again with both apps open."
        case .invalidFrame, .invalidRequest: return "The nearby connection returned an invalid message. Update both apps and pair again."
        }
    }
}

struct NearbyRequest: Codable {
    let path: String
    let body: Data?
    let headers: [String: String]

    var isAllowed: Bool {
        guard (body?.count ?? 0) <= NearbyProtocol.maxBody,
              Set(headers.keys).isSubset(of: ["Content-Type", "X-Capture-ID", "X-Submission-ID"]),
              headers.values.allSatisfy({ $0.utf8.count <= 256 && $0.utf8.allSatisfy { (32...126).contains($0) } }) else { return false }
        if body != nil { return ["api/save", "api/session/reset", "api/library/cleanup"].contains(path) }
        if ["api/library", "api/status", "api/library/cleanup"].contains(path) { return true }
        let prefix = "api/image/"
        let id = path.dropFirst(prefix.count)
        return path.hasPrefix(prefix) && id.count == 24 && id.allSatisfy { $0.isASCII && $0.isHexDigit }
    }
}

struct NearbyResponse: Codable {
    let status: Int
    let body: Data
}

// Browse afresh before each production request so discovery can activate a
// peer-to-peer path. Stop browsing before transferring, as Apple recommends.
// A failed save retains its existing retry UUID.
final class NearbyExchange: @unchecked Sendable {
    private let queue = DispatchQueue(label: "Ludwig.NearbyExchange")
    private var connection: NWConnection?
    private var browser: NWBrowser?
    private var completion: CheckedContinuation<NearbyResponse, Error>?
    private var finished = false
    private var deadline: DispatchWorkItem?

    static func request(_ request: NearbyRequest, token: String, endpoint: NWEndpoint? = nil,
                        timeout: TimeInterval = 45) async throws -> NearbyResponse {
        guard request.isAllowed else { throw NearbyError.invalidRequest }
        let bytes = try NearbyProtocol.frame(JSONEncoder().encode(request))
        let exchange = NearbyExchange()
        return try await withTaskCancellationHandler(operation: {
            try await exchange.run(bytes, token: token, endpoint: endpoint, timeout: timeout)
        }, onCancel: { exchange.cancel() })
    }
    private func run(_ bytes: Data, token: String, endpoint: NWEndpoint?, timeout: TimeInterval) async throws -> NearbyResponse {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                guard !self.finished else { continuation.resume(throwing: CancellationError()); return }
                self.completion = continuation
                let deadline = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.finish(.failure(self.connection == nil ? NearbyError.notDiscovered : NearbyError.unavailable))
                }
                self.deadline = deadline
                self.queue.asyncAfter(deadline: .now() + timeout, execute: deadline)
                if let endpoint { self.connect(bytes, token: token, endpoint: endpoint) }
                else { self.discover(bytes, token: token) }
            }
        }
    }
    private func discover(_ bytes: Data, token: String) {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: NearbyProtocol.serviceType, domain: "local."), using: parameters)
        self.browser = browser
        browser.stateUpdateHandler = { [weak self] state in
            guard let self, !self.finished else { return }
            switch state {
            case .failed(let error), .waiting(let error):
                if case .dns(let code) = error, code == -65570 {
                    self.finish(.failure(NearbyError.localNetworkDenied))
                } else if case .failed = state { self.finish(.failure(NearbyError.notDiscovered)) }
            default: break
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self, !self.finished, self.connection == nil,
                  let result = results.first(where: { result in
                      guard case .service(let name, let type, _, _) = result.endpoint else { return false }
                      return name == NearbyProtocol.serviceName(token: token)
                          && type.trimmingCharacters(in: CharacterSet(charactersIn: ".")) == NearbyProtocol.serviceType
                  }) else { return }
            self.stopBrowsing()
            // Keep the discovered endpoint, including its interface information.
            // The service name is only a filter; TLS-PSK still authenticates it.
            self.connect(bytes, token: token, endpoint: result.endpoint)
        }
        browser.start(queue: queue)
    }
    private func stopBrowsing() {
        browser?.stateUpdateHandler = nil; browser?.browseResultsChangedHandler = nil
        browser?.cancel(); browser = nil
    }
    private func connect(_ bytes: Data, token: String, endpoint: NWEndpoint) {
        guard !finished else { return }
        let connection = NWConnection(to: endpoint, using: NearbyProtocol.parameters(token: token))
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self, !self.finished else { return }
            switch state {
            case .ready:
                connection.send(content: bytes, completion: .contentProcessed { [weak self] error in
                    guard let self, !self.finished else { return }
                    if error != nil { self.finish(.failure(NearbyError.interrupted)); return }
                    NearbyProtocol.receive(connection) { [weak self] result in
                        do {
                            let response = try JSONDecoder().decode(NearbyResponse.self, from: result.get())
                            guard response.body.count <= NearbyProtocol.maxBody, (100...599).contains(response.status) else { throw NearbyError.invalidFrame }
                            self?.finish(.success(response))
                        } catch { self?.finish(.failure(error is NearbyError ? error : NearbyError.interrupted)) }
                    }
                })
            case .failed: self.finish(.failure(NearbyError.unavailable))
            case .cancelled: self.finish(.failure(NearbyError.interrupted))
            case .waiting(let error):
                if case .dns(let code) = error, code == -65570 {
                    self.finish(.failure(NearbyError.localNetworkDenied))
                } else if connection.currentPath?.unsatisfiedReason == .localNetworkDenied {
                    self.finish(.failure(NearbyError.localNetworkDenied))
                }
            default: break // Waiting paths may recover before the deadline.
            }
        }
        connection.start(queue: self.queue)
    }

    private func cancel() { queue.async { self.finish(.failure(CancellationError())) } }
    private func finish(_ result: Result<NearbyResponse, Error>) {
        guard !finished else { return }
        finished = true
        deadline?.cancel(); deadline = nil
        stopBrowsing()
        connection?.stateUpdateHandler = nil; connection?.cancel(); connection = nil
        let continuation = completion; completion = nil
        continuation?.resume(with: result)
    }
}

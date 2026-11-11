import Foundation
import Network

// The encrypted connection terminates in the Mac app. The existing authenticated
// API remains on loopback, preserving save receipts, cleanup checks and clipboard ACKs.
final class NearbyBridge: @unchecked Sendable {
    private let queue = DispatchQueue(label: "Ludwig.NearbyBridge")
    private let listener: NWListener
    private let session: URLSession
    private let token: String
    private let localPort: Int
    private var clients: [UUID: NWConnection] = [:]
    private var tasks: [UUID: URLSessionDataTask] = [:]
    private var deadlines: [UUID: DispatchWorkItem] = [:]
    private var stopped = false
    var port: NWEndpoint.Port? { listener.port }

    init(token: String, localPort: Int, advertise: Bool = true,
         configuration: URLSessionConfiguration = .ephemeral,
         stateChanged: @escaping (Bool) -> Void = { _ in }) throws {
        self.token = token; self.localPort = localPort
        configuration.httpCookieStorage = nil; configuration.urlCache = nil
        configuration.connectionProxyDictionary = [:]
        configuration.timeoutIntervalForRequest = 30; configuration.timeoutIntervalForResource = 35
        session = URLSession(configuration: configuration, delegate: NearbyNoRedirects(), delegateQueue: nil)
        listener = try NWListener(using: NearbyProtocol.parameters(token: token))
        if advertise {
            var service = NWListener.Service(name: NearbyProtocol.serviceName(token: token), type: NearbyProtocol.serviceType)
            service.noAutoRename = true // Never silently advertise a different QR identity.
            listener.service = service
        }
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready: stateChanged(true)
            case .failed, .cancelled: stateChanged(false)
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self, !self.stopped, self.clients.count < 4 else { connection.cancel(); return }
            let id = UUID(); self.clients[id] = connection
            let deadline = DispatchWorkItem { [weak self] in self?.close(id) }
            self.deadlines[id] = deadline
            self.queue.asyncAfter(deadline: .now() + 45, execute: deadline)
            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    NearbyProtocol.receive(connection) { [weak self] result in self?.handle(result, id: id) }
                case .failed, .cancelled: self.close(id)
                default: break
                }
            }
            connection.start(queue: self.queue)
        }
        listener.start(queue: queue)
    }
    func stop() {
        queue.async {
            self.stopped = true; self.listener.cancel()
            for id in Array(self.clients.keys) { self.close(id) }
            self.session.invalidateAndCancel()
        }
    }
    private func handle(_ result: Result<Data, Error>, id: UUID) {
        guard clients[id] != nil else { return }
        do {
            let message = try JSONDecoder().decode(NearbyRequest.self, from: result.get())
            guard message.isAllowed else { throw NearbyError.invalidRequest }
            var request = URLRequest(url: URL(string: "http://127.0.0.1:\(localPort)/" + message.path)!)
            request.httpMethod = message.body == nil ? "GET" : "POST"
            request.httpBody = message.body
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            for (name, value) in message.headers { request.setValue(value, forHTTPHeaderField: name) }
            let task = session.dataTask(with: request) { [weak self] data, response, error in
                guard let self else { return }
                self.queue.async {
                    guard error == nil, let data, data.count <= NearbyProtocol.maxBody, let response = response as? HTTPURLResponse else {
                        self.respond(NearbyResponse(status: 502, body: Data("{\"error\":\"The Mac companion is unavailable. Reopen the Mac app and retry.\"}".utf8)), id: id); return
                    }
                    self.respond(NearbyResponse(status: response.statusCode, body: data), id: id)
                }
            }
            tasks[id] = task; task.resume()
        } catch { close(id) }
    }
    private func respond(_ response: NearbyResponse, id: UUID) {
        guard let connection = clients[id] else { return }
        do {
            let bytes = try NearbyProtocol.frame(JSONEncoder().encode(response))
            connection.send(content: bytes, completion: .contentProcessed { [weak self] _ in self?.close(id) })
        } catch { close(id) }
    }
    private func close(_ id: UUID) {
        deadlines.removeValue(forKey: id)?.cancel()
        tasks.removeValue(forKey: id)?.cancel()
        if let connection = clients.removeValue(forKey: id) {
            connection.stateUpdateHandler = nil; connection.cancel()
        }
    }
}

private final class NearbyNoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

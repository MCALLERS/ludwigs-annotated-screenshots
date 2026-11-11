import Foundation

@main struct ConnectionTests {
    static func main() throws {
        // A nearby pairing must not depend on the router assigning a reachable IP.
        let key = "test-only-nearby-key-0123456789"
        let nearby = try Connection.parse("ludwig://nearby/#pair=" + key)
        precondition(nearby.baseURL.absoluteString == "ludwig://nearby")
        precondition(nearby.token == key)
        let old = try Connection.parse("http://192.168.1.2:8765/#pair=" + key)
        precondition(nearby.namespace == old.namespace, "Changing transport must preserve drafts")
        let restored = try JSONDecoder().decode(Connection.self, from: JSONEncoder().encode(nearby))
        precondition(restored == nearby)
        for link in [
            "ludwig://elsewhere/#pair=" + key,
            "ludwig://nearby:8765/#pair=" + key,
            "ludwig://nearby/api/save#pair=" + key,
            "ludwig://nearby/?url=https://example.com#pair=" + key,
            "ludwig://nearby/#pair=" + key + "&pair=other-test-key-0123456789",
            "http://8.8.8.8:8765/#pair=" + key,
            "ludwig://nearby/#pair=short"
        ] {
            do { _ = try Connection.parse(link); fatalError("Accepted an invalid pairing link") }
            catch { /* expected */ }
        }
        print("PASS: nearby pairing, legacy pairing, draft identity, persistence, invalid link rejection")
    }
}

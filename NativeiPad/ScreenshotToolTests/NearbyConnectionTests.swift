import XCTest
import Foundation
@testable import ScreenshotToolNative

final class NearbyConnectionTests: XCTestCase {
    func testNearbyPairingKeepsDraftIdentityAcrossNetworkChanges() throws {
        let token = "unit-test-nearby-token-0123456789"
        let old = try Connection.parse("http://192.168.1.20:8765/#pair=" + token)
        let nearby = try Connection.parse("ludwig://nearby/#pair=" + token)
        XCTAssertTrue(nearby.isNearby)
        XCTAssertEqual(nearby.namespace, old.namespace)
        XCTAssertEqual(nearby.baseURL.absoluteString, "ludwig://nearby")
        XCTAssertEqual(try JSONDecoder().decode(Connection.self, from: JSONEncoder().encode(nearby)), nearby)
    }
    func testNearbyPairingRejectsInjectedHostsPathsAndAmbiguousSecrets() {
        let key = "unit-test-nearby-token-0123456789"
        for link in ["ludwig://other/#pair=" + key, "ludwig://nearby:80/#pair=" + key,
                     "ludwig://nearby/api/save#pair=" + key, "ludwig://nearby/?url=http://other#pair=" + key,
                     "ludwig://nearby/#pair=" + key + "&pair=" + key] {
            XCTAssertThrowsError(try Connection.parse(link))
        }
    }
    func testLegacyKeychainConnectionRemainsCompatible() throws {
        let data = Data("{\"baseURL\":\"http://192.168.1.20:8765\",\"token\":\"unit-test-nearby-token-0123456789\"}".utf8)
        let old = try JSONDecoder().decode(Connection.self, from: data)
        XCTAssertFalse(old.isNearby)
        XCTAssertEqual(old.displayName, "192.168.1.20")
    }
    func testNearbyProtocolRejectsOversizedFramesAndHeaderInjection() throws {
        XCTAssertThrowsError(try NearbyProtocol.frameSize(Data([255, 255, 255, 255])))
        XCTAssertThrowsError(try NearbyProtocol.frameSize(Data([0, 0, 0, 0])))
        XCTAssertFalse(NearbyRequest(path: "api/library", body: nil, headers: ["Authorization": "injected"]).isAllowed)
        XCTAssertFalse(NearbyRequest(path: "api/save", body: Data([1]), headers: ["Content-Type": "image/png\r\nHost: example.com"]).isAllowed)
        XCTAssertTrue(NearbyRequest(path: "api/library", body: nil, headers: [:]).isAllowed)
        XCTAssertEqual(try NearbyProtocol.frameSize(Data([0, 0, 0, 1])), 1)
    }
}

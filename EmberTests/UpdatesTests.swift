@testable import Ember
import XCTest

final class UpdatesTests: XCTestCase {
    /// Sparkle needs an https feed and the EdDSA public key, or updates silently never arrive.
    func testSparkleFeedIsSignedAndSecure() throws {
        let info = try XCTUnwrap(Bundle(for: AppModel.self).infoDictionary)
        let feed = try XCTUnwrap(info["SUFeedURL"] as? String)
        XCTAssertEqual(URL(string: feed)?.scheme, "https")
        XCTAssertEqual(URL(string: feed)?.lastPathComponent, "appcast.xml")
        let key = try XCTUnwrap(info["SUPublicEDKey"] as? String)
        XCTAssertEqual(Data(base64Encoded: key)?.count, 32, "Ed25519 public keys are 32 bytes")
    }

    @MainActor
    func testUpdaterNeverStartsInTheTestHost() {
        Updates.shared.start()
        XCTAssertFalse(Updates.shared.isStarted)
    }
}

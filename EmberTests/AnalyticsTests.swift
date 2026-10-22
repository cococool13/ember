@testable import Ember
import XCTest

final class AnalyticsTests: XCTestCase {
    func testTokenNeedsRealProjectKey() {
        XCTAssertNil(Analytics.token(from: nil))
        XCTAssertNil(Analytics.token(from: ["PostHogProjectToken": "REPLACE_ME"]))
        XCTAssertNil(Analytics.token(from: ["PostHogProjectToken": "$(POSTHOG_PROJECT_TOKEN)"]))
        XCTAssertNil(Analytics.token(from: ["PostHogProjectToken": "phx_personal"]))
        XCTAssertEqual(Analytics.token(from: ["PostHogProjectToken": " phc_abc\n"]), "phc_abc")
    }

    func testStartsOnlyWhenEnabledWithRealTokenOutsideTests() {
        let real: [String: Any] = ["PostHogProjectToken": "phc_abc"]
        XCTAssertEqual(Analytics.startToken(enabled: true, info: real, isTestRun: false), "phc_abc")
        XCTAssertNil(Analytics.startToken(enabled: false, info: real, isTestRun: false))
        XCTAssertNil(Analytics.startToken(enabled: true, info: real, isTestRun: true))
        XCTAssertNil(Analytics.startToken(enabled: true, info: ["PostHogProjectToken": "REPLACE_ME"], isTestRun: false))
        XCTAssertNil(Analytics.startToken(enabled: true, info: nil, isTestRun: false))
    }

    func testTestRunIsDetected() {
        XCTAssertTrue(Analytics.isTestRun)
    }

    func testCheckoutURLAddsDistinctIdToBuyLinksOnly() throws {
        let buy = try XCTUnwrap(URL(string: "https://licensing.cohencool.workers.dev/buy/ember?ph=old"))
        XCTAssertEqual(
            Analytics.checkoutURL(buy, distinctId: "abc-123").absoluteString,
            "https://licensing.cohencool.workers.dev/buy/ember?ph=abc-123"
        )
        XCTAssertEqual(Analytics.checkoutURL(buy, distinctId: ""), buy)
        let other = try XCTUnwrap(URL(string: "https://licensing.cohencool.workers.dev/lost/ember"))
        XCTAssertEqual(Analytics.checkoutURL(other, distinctId: "abc-123"), other)
    }

    func testSuperProperties() {
        let props = Analytics.superProperties(info: ["CFBundleShortVersionString": "0.6.1", "CFBundleVersion": "8"])
        XCTAssertEqual(props["app"] as? String, "ember")
        XCTAssertEqual(props["platform"] as? String, "macOS")
        XCTAssertEqual(props["version"] as? String, "0.6.1 (8)")
    }

    func testEnabledByDefaultAndStoredAsOptOut() throws {
        let suite = "AnalyticsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(Analytics.isEnabled(defaults))
        Analytics.setEnabled(false, defaults: defaults)
        XCTAssertFalse(Analytics.isEnabled(defaults))
        XCTAssertTrue(defaults.bool(forKey: Analytics.optOutKey))
        Analytics.setEnabled(true, defaults: defaults)
        XCTAssertTrue(Analytics.isEnabled(defaults))
    }
}

import XCTest
@testable import DodoCheckout

/// U5–U9: parsing the return_url query into a result.
final class ResultParserTests: XCTestCase {
    private func parse(_ query: String) -> CheckoutResult {
        ResultParser.parse(url: URL(string: "https://myapp.com/checkout/return?\(query)")!)
    }

    // U5: one-time payment.
    func testSucceededOneTime() {
        let result = parse("payment_id=pay_123&status=succeeded")
        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.paymentId, "pay_123")
        XCTAssertNil(result.subscriptionId)
    }

    // U6: subscription (status=active).
    func testSucceededSubscription() {
        let result = parse("subscription_id=sub_456&status=active")
        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.subscriptionId, "sub_456")
        XCTAssertNil(result.paymentId)
    }

    // U7: failed.
    func testFailed() {
        let result = parse("payment_id=pay_9&status=failed")
        XCTAssertEqual(result.status, .failed)
    }

    // U8: processing / requires_* → pending.
    func testProcessingIsPending() {
        XCTAssertEqual(parse("status=processing").status, .pending)
    }

    func testRequiresActionIsPending() {
        XCTAssertEqual(parse("status=requires_action").status, .pending)
    }

    // U9: license_key + email populated in result and raw.
    func testLicenseKeyAndEmailPopulated() {
        let result = parse("payment_id=pay_1&status=succeeded&license_key=LIC-XYZ&email=user%40example.com")
        XCTAssertEqual(result.licenseKeys, ["LIC-XYZ"])
        XCTAssertEqual(result.customerEmail, "user@example.com")
        XCTAssertEqual(result.raw["license_key"], "LIC-XYZ")
        XCTAssertEqual(result.raw["email"], "user@example.com")
        XCTAssertEqual(result.raw["payment_id"], "pay_1")
    }

    func testExpiredStatus() {
        XCTAssertEqual(parse("status=expired").status, .expired)
    }

    // Unknown/missing status defaults to pending (webhook is authoritative).
    func testUnknownStatusDefaultsToPending() {
        XCTAssertEqual(parse("payment_id=pay_1").status, .pending)
        XCTAssertEqual(parse("status=some_new_state").status, .pending)
    }

    // raw carries every param verbatim.
    func testRawCarriesAllParams() {
        let result = parse("payment_id=pay_1&status=succeeded&foo=bar")
        XCTAssertEqual(result.raw["foo"], "bar")
    }
}

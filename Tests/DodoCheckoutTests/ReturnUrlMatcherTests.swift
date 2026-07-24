import XCTest
@testable import DodoCheckout

/// U1–U4: return-url matching.
final class ReturnUrlMatcherTests: XCTestCase {
    private let returnUrl = URL(string: "https://myapp.com/checkout/return")!

    // U1: matches the return_url even with a query string appended.
    func testMatchesReturnUrlWithQuery() {
        let matcher = ReturnUrlMatcher(returnUrl: returnUrl)
        let nav = URL(string: "https://myapp.com/checkout/return?payment_id=pay_123&status=succeeded&email=a@b.com")!
        XCTAssertTrue(matcher.matches(nav))
    }

    // U2: does NOT match the intermediate /return/{id} hop on the Dodo backend host.
    func testDoesNotMatchDodoReturnHop() {
        let matcher = ReturnUrlMatcher(returnUrl: returnUrl)
        let nav = URL(string: "https://test.dodopayments.com/return/pay_123?status=succeeded")!
        XCTAssertFalse(matcher.matches(nav))
    }

    // U3: does NOT match an unrelated checkout/redirect URL.
    func testDoesNotMatchUnrelatedUrl() {
        let matcher = ReturnUrlMatcher(returnUrl: returnUrl)
        let nav = URL(string: "https://sandbox.cashfree.com/pg/view/payment/abc")!
        XCTAssertFalse(matcher.matches(nav))
    }

    // U4: host case and a trailing slash are normalized; still matches.
    func testNormalizesHostCaseAndTrailingSlash() {
        let matcher = ReturnUrlMatcher(returnUrl: returnUrl)
        let nav = URL(string: "https://MyApp.COM/checkout/return/?status=succeeded")!
        XCTAssertTrue(matcher.matches(nav))
    }

    // Different path must not match.
    func testDifferentPathDoesNotMatch() {
        let matcher = ReturnUrlMatcher(returnUrl: returnUrl)
        let nav = URL(string: "https://myapp.com/checkout/other")!
        XCTAssertFalse(matcher.matches(nav))
    }

    // A sentinel return_url that never resolves still matches.
    func testSentinelReturnUrlMatches() {
        let sentinel = URL(string: "https://dodo-sdk-webview-return.example.com/done")!
        let matcher = ReturnUrlMatcher(returnUrl: sentinel)
        let nav = URL(string: "https://dodo-sdk-webview-return.example.com/done?payment_id=pay_1&status=succeeded")!
        XCTAssertTrue(matcher.matches(nav))
    }
}

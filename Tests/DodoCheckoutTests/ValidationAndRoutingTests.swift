import XCTest
@testable import DodoCheckout

/// U10–U12: input validation and single-checkout guard.
final class ValidationAndRoutingTests: XCTestCase {

    // U10: non-dodopayments checkoutUrl → INVALID_CHECKOUT_URL.
    func testInvalidCheckoutUrlThrows() {
        let bad = URL(string: "https://evil.com/session/cks_1")!
        XCTAssertThrowsError(try UrlValidator.validateCheckoutUrl(bad)) { error in
            XCTAssertEqual((error as? CheckoutError)?.code, .invalidCheckoutUrl)
        }
    }

    func testCheckoutUrlWrongPathThrows() {
        let bad = URL(string: "https://checkout.dodopayments.com/not-a-session")!
        XCTAssertThrowsError(try UrlValidator.validateCheckoutUrl(bad)) { error in
            XCTAssertEqual((error as? CheckoutError)?.code, .invalidCheckoutUrl)
        }
    }

    func testValidCheckoutUrlsPass() throws {
        try UrlValidator.validateCheckoutUrl(URL(string: "https://checkout.dodopayments.com/session/cks_live_1")!)
        try UrlValidator.validateCheckoutUrl(URL(string: "https://test.checkout.dodopayments.com/session/cks_test_1")!)
    }

    // U11: malformed returnUrl → INVALID_RETURN_URL.
    func testInvalidReturnUrlThrows() {
        let bad = URL(string: "not-a-url")!
        XCTAssertThrowsError(try UrlValidator.validateReturnUrl(bad)) { error in
            XCTAssertEqual((error as? CheckoutError)?.code, .invalidReturnUrl)
        }
    }

    func testValidReturnUrlPasses() throws {
        try UrlValidator.validateReturnUrl(URL(string: "https://myapp.com/checkout/return")!)
        // A custom-scheme sentinel is still a valid absolute URL.
        try UrlValidator.validateReturnUrl(URL(string: "myapp://checkout/return")!)
    }

    // U12: second concurrent checkout → ALREADY_IN_PROGRESS.
    @MainActor
    func testSecondStartThrowsAlreadyInProgress() throws {
        let guardInstance = InProgressGuard()
        try guardInstance.begin()
        XCTAssertThrowsError(try guardInstance.begin()) { error in
            XCTAssertEqual((error as? CheckoutError)?.code, .alreadyInProgress)
        }
        guardInstance.end()
        // After ending, a new checkout is allowed again.
        XCTAssertNoThrow(try guardInstance.begin())
    }

    func testReturnUrlMatcherMatchesReturnUrl() {
        let matcher = ReturnUrlMatcher(returnUrl: URL(string: "https://myapp.com/checkout/return")!)
        let nav = URL(string: "https://myapp.com/checkout/return?payment_id=pay_1&status=succeeded")!
        XCTAssertTrue(matcher.matches(nav))
        let result = ResultParser.parse(url: nav)
        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.paymentId, "pay_1")
    }
}

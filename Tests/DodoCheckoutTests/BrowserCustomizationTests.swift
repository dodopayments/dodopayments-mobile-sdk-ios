import XCTest
@testable import DodoCheckout

#if canImport(UIKit)
final class BrowserCustomizationTests: XCTestCase {

    func testDefaultsAreAllNilSoNothingIsAssertedOnThePlatformsBehalf() {
        // nil means SafariCheckoutSession never touches the corresponding
        // SFSafariViewController property at all, so the OS's own current
        // default applies — this SDK doesn't hardcode a guess at what that
        // is anywhere. See SafariCheckoutSession.apply/start for where each
        // nil is actually resolved (or, for presentationStyle only,
        // resolved to this SDK's own pre-existing .pageSheet default).
        let defaults = BrowserCustomization()
        XCTAssertNil(defaults.dismissButtonStyle)
        XCTAssertNil(defaults.barCollapsingEnabled)
        XCTAssertNil(defaults.presentationStyle)
        XCTAssertNil(defaults.colorScheme)
    }

    func testFieldsRoundTripThroughInit() {
        let customization = BrowserCustomization(
            dismissButtonStyle: .cancel,
            barCollapsingEnabled: false,
            presentationStyle: .fullScreen,
            colorScheme: .dark
        )
        XCTAssertEqual(customization.dismissButtonStyle, .cancel)
        XCTAssertEqual(customization.barCollapsingEnabled, false)
        XCTAssertEqual(customization.presentationStyle, .fullScreen)
        XCTAssertEqual(customization.colorScheme, .dark)
    }
}
#endif

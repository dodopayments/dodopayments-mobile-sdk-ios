import XCTest
@testable import DodoCheckout

#if canImport(UIKit)
import SafariServices

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

    func testDismissButtonStyleMapsToMatchingUIKitCase() {
        XCTAssertEqual(BrowserCustomization.DismissButtonStyle.done.uiKitStyle, .done)
        XCTAssertEqual(BrowserCustomization.DismissButtonStyle.close.uiKitStyle, .close)
        XCTAssertEqual(BrowserCustomization.DismissButtonStyle.cancel.uiKitStyle, .cancel)
    }

    func testPresentationStyleMapsToMatchingUIKitCase() {
        XCTAssertEqual(BrowserCustomization.PresentationStyle.pageSheet.uiKitStyle, .pageSheet)
        XCTAssertEqual(BrowserCustomization.PresentationStyle.fullScreen.uiKitStyle, .fullScreen)
    }

    func testColorSchemeMapsToMatchingUIKitCase() {
        XCTAssertEqual(BrowserCustomization.ColorScheme.system.uiKitStyle, .unspecified)
        XCTAssertEqual(BrowserCustomization.ColorScheme.light.uiKitStyle, .light)
        XCTAssertEqual(BrowserCustomization.ColorScheme.dark.uiKitStyle, .dark)
    }

    // This is the invariant the whole nil-by-default design rests on: apply()
    // must leave SFSafariViewController's own properties completely
    // untouched when customization doesn't set them, not assert a value on
    // the OS's behalf. Comparing before/after (rather than asserting a fixed
    // constant) is what actually catches an `if let` guard being dropped.
    @MainActor
    func testApplyLeavesUnsetFieldsUntouched() {
        let safari = SFSafariViewController(url: URL(string: "https://example.com")!)
        let dismissButtonStyleBefore = safari.dismissButtonStyle
        let colorSchemeBefore = safari.overrideUserInterfaceStyle

        let session = SafariCheckoutSession(
            returnUrl: URL(string: "myapp://checkout/return")!,
            customization: BrowserCustomization(),
            onEvent: nil
        )
        session.apply(BrowserCustomization(), to: safari)

        XCTAssertEqual(safari.dismissButtonStyle, dismissButtonStyleBefore)
        XCTAssertEqual(safari.overrideUserInterfaceStyle, colorSchemeBefore)
        // presentationStyle is the one field nil deliberately does NOT skip.
        XCTAssertEqual(safari.modalPresentationStyle, .pageSheet)
    }

    @MainActor
    func testApplySetsFieldsWhenProvided() {
        let safari = SFSafariViewController(url: URL(string: "https://example.com")!)
        let session = SafariCheckoutSession(
            returnUrl: URL(string: "myapp://checkout/return")!,
            customization: BrowserCustomization(),
            onEvent: nil
        )
        session.apply(
            BrowserCustomization(
                dismissButtonStyle: .cancel,
                presentationStyle: .fullScreen,
                colorScheme: .dark
            ),
            to: safari
        )

        XCTAssertEqual(safari.dismissButtonStyle, .cancel)
        XCTAssertEqual(safari.overrideUserInterfaceStyle, .dark)
        XCTAssertEqual(safari.modalPresentationStyle, .fullScreen)
    }
}
#endif

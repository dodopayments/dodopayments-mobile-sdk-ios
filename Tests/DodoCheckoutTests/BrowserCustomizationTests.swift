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

    // The two tests above call apply() on a bare controller, which is *not*
    // the sequence start() actually runs — they'd still pass if the sheet
    // were assembled in an order UIKit ignores. These exercise the real
    // factory instead.

    @MainActor
    func testCustomizationSurvivesTheOrderTheSheetIsActuallyAssembledIn() {
        let session = SafariCheckoutSession(
            returnUrl: URL(string: "myapp://checkout/return")!,
            customization: BrowserCustomization(
                dismissButtonStyle: .close,
                presentationStyle: .fullScreen,
                colorScheme: .dark
            ),
            onEvent: nil
        )

        let safari = session.makeSafariViewController(
            checkoutUrl: URL(string: "https://checkout.dodopayments.com/session")!
        )

        XCTAssertEqual(safari.modalPresentationStyle, .fullScreen)
        XCTAssertEqual(safari.dismissButtonStyle, .close)
        XCTAssertEqual(safari.overrideUserInterfaceStyle, .dark)
    }

    @MainActor
    func testDefaultSheetKeepsItsSwipeToDismissDelegateWired() {
        // presentationControllerDidDismiss is the only thing that reports
        // the interactive swipe-to-dismiss on the default sheet; if this
        // delegate is ever left unset, `start` never resumes its
        // continuation and the caller's `await` hangs forever.
        let session = SafariCheckoutSession(
            returnUrl: URL(string: "myapp://checkout/return")!,
            customization: BrowserCustomization(),
            onEvent: nil
        )

        let safari = session.makeSafariViewController(
            checkoutUrl: URL(string: "https://checkout.dodopayments.com/session")!
        )

        XCTAssertEqual(safari.modalPresentationStyle, .pageSheet)
        XCTAssertTrue(safari.delegate === session)
        XCTAssertTrue(safari.presentationController?.delegate === session)
        // The assertion that actually pins the load-bearing order in
        // makeSafariViewController. Confirmed by mutation: swapping apply()
        // and the presentationController access flips this from true to
        // false, while every other assertion in this file — including the
        // .fullScreen case in the test above — keeps passing under either
        // order. That's because a fresh SFSafariViewController's own
        // untouched default already resolves to a non-sheet presentation
        // controller, so requesting .fullScreen can't distinguish "applied
        // in time" from "silently downgraded" — both look identical. Only
        // .pageSheet, where the SDK's own default has to override that
        // platform default, actually depends on the ordering.
        XCTAssertTrue(safari.presentationController is UISheetPresentationController)
        print("DIAG_DEFAULT_IS_SHEET: \(safari.presentationController is UISheetPresentationController)")
        print("DIAG_DEFAULT_TYPE: \(String(describing: safari.presentationController.map { type(of: $0) }))")
    }

    @MainActor
    func testBarCollapsingIsAppliedToTheConfigurationTheSheetIsBuiltWith() {
        // barCollapsingEnabled can only be set at construction — the
        // Configuration is read once at init — so unlike the other fields
        // it can't be verified through apply().
        let session = SafariCheckoutSession(
            returnUrl: URL(string: "myapp://checkout/return")!,
            customization: BrowserCustomization(barCollapsingEnabled: false),
            onEvent: nil
        )

        let safari = session.makeSafariViewController(
            checkoutUrl: URL(string: "https://checkout.dodopayments.com/session")!
        )

        XCTAssertFalse(safari.configuration.barCollapsingEnabled)
    }
}
#endif

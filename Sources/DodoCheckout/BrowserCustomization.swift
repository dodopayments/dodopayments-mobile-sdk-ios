#if canImport(UIKit)
import UIKit

/// Customizes the `SFSafariViewController` sheet's chrome — the dismiss
/// button's label, whether the toolbar collapses on scroll, how the sheet is
/// presented, and its color scheme. Every field is `nil` by default, and a
/// `nil` field means exactly that: the corresponding `SFSafariViewController`
/// property is never touched at all, so the platform's own live behavior
/// applies — not a value this SDK asserts on its behalf. This is deliberate:
/// hardcoding a guess at "the platform default" (e.g. `.done` for
/// `dismissButtonStyle`) can go stale the moment Apple changes it, silently
/// changing behavior for every integrator who never touched that field.
/// `nil` everywhere is immune to that by construction.
///
/// `preferredBarTintColor`/`preferredControlTintColor` are deliberately not
/// exposed here: both are deprecated as of iOS 26 ("tinting interferes with
/// background effects the system provides") with no replacement, and
/// confirmed by hands-on testing to have no visible effect on iOS 26 — not
/// worth shipping a color knob that's already inert on the majority of iOS
/// devices. Android's `toolbarColor` has no iOS counterpart as a result.
public struct BrowserCustomization: Sendable, Equatable {
    /// Maps 1:1 to `SFSafariViewController.DismissButtonStyle`. Historically
    /// (pre-iOS 26) a text label ("Done"/"Close"/"Cancel"); as of iOS 26 the
    /// system header describes it rendering as an icon instead (e.g. an
    /// "xmark" for `.close`, a checkmark for `.done`) — the exact rendering
    /// is the OS's call, not something this SDK controls either way.
    public enum DismissButtonStyle: Sendable, Equatable {
        case done
        case close
        case cancel
    }

    /// Maps to `UIViewController.modalPresentationStyle`. `.pageSheet` is a
    /// card that leaves the app's own screen visible behind it and supports
    /// swipe-to-dismiss; `.fullScreen` covers the whole screen with no
    /// gesture to dismiss. This also gates `barCollapsingEnabled` in
    /// practice: confirmed by hands-on testing that the toolbar/URL bar only
    /// ever collapses on scroll under `.fullScreen` — `.pageSheet` keeps them
    /// pinned regardless of that setting.
    public enum PresentationStyle: Sendable, Equatable {
        case pageSheet
        case fullScreen
    }

    /// Forces the sheet's light/dark appearance regardless of the system
    /// setting. Maps to `UIViewController.overrideUserInterfaceStyle`.
    public enum ColorScheme: Sendable, Equatable {
        case system
        case light
        case dark
    }

    /// `nil` means `SFSafariViewController.dismissButtonStyle` is never set,
    /// so the OS's own current default applies (confirmed via
    /// `SFSafariViewController.h`, currently `.close`) — this property was
    /// never touched before this feature existed, so this is genuinely
    /// unchanged behavior, not a value this SDK guesses on the OS's behalf.
    public var dismissButtonStyle: DismissButtonStyle?
    /// `nil` means `SFSafariViewController.Configuration.barCollapsingEnabled`
    /// is never set, so the OS's own current default applies (confirmed via
    /// `SFSafariViewControllerConfiguration.h`, currently `YES`). Only takes
    /// effect at construction — the configuration can't change once
    /// presented. Only has a visible effect when `presentationStyle` is
    /// `.fullScreen` — see `PresentationStyle`.
    public var barCollapsingEnabled: Bool?
    /// `nil` resolves to `.pageSheet` — unlike the other fields, this isn't
    /// a platform default we're inferring: `.pageSheet` was already the
    /// SDK's own hardcoded presentation choice before this feature existed
    /// (confirmed via git history), so `nil` reproducing it is a deliberate
    /// SDK decision, not a guess about OS behavior.
    public var presentationStyle: PresentationStyle?
    /// `nil` means `UIViewController.overrideUserInterfaceStyle` is never
    /// set, so the OS's own current default applies (`.unspecified`, i.e.
    /// follow the system setting) — this property was never touched before
    /// this feature existed.
    public var colorScheme: ColorScheme?

    public init(
        dismissButtonStyle: DismissButtonStyle? = nil,
        barCollapsingEnabled: Bool? = nil,
        presentationStyle: PresentationStyle? = nil,
        colorScheme: ColorScheme? = nil
    ) {
        self.dismissButtonStyle = dismissButtonStyle
        self.barCollapsingEnabled = barCollapsingEnabled
        self.presentationStyle = presentationStyle
        self.colorScheme = colorScheme
    }
}
#endif

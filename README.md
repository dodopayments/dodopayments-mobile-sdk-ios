# Dodo Payments Checkout iOS SDK

Open Dodo Payments' hosted checkout in an in-app `SFSafariViewController` and
get a clean result from one call.

## Install

Swift Package Manager. In Xcode: **File → Add Package Dependencies** →
`https://github.com/dodopayments/dodopayments-mobile-sdk-ios`

Or in `Package.swift`:

```swift
.package(url: "https://github.com/dodopayments/dodopayments-mobile-sdk-ios", from: "1.0.0")
```

Requirements: iOS 16+, zero third-party dependencies.

## Setup

Register a URL scheme so the OS can route the checkout return back to your
app:

1. Add a URL type in Info.plist with your chosen scheme (e.g. `myapp`).
2. Forward incoming URLs from your own `application(_:open:options:)` /
   `.onOpenURL` into `DodoCheckout.handleOpenURL(_:)` —
   `SFSafariViewController` has no built-in way to catch its own return URL.

## Use

```swift
import DodoCheckout

let result = try await DodoCheckout.start(
    checkoutUrl: checkoutUrl,   // from your backend's POST /checkouts
    returnUrl: URL(string: "myapp://checkout/return")!,
    onEvent: { event in print(event.name) }  // logging only — never decide outcome from events
)

switch result.status {
case .succeeded: showSuccess(result.paymentId)   // UI only — confirm server-side
case .failed:    showFailure()
case .cancelled: dismiss()
case .pending:   showPending()                    // settles later; webhook is authority
case .expired:   showExpired()
}
```

```swift
// In your SceneDelegate/App:
import DodoCheckout

func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    DodoCheckout.handleOpenURL(url)
}
```

## What the result means

The result comes from the `return_url` query string. **It is a UI hint, not
proof of payment.** This SDK never calls the Dodo API and holds no API key.
Grant access on your backend from the webhook (`payment.succeeded` /
`subscription.active`) or by retrieving the payment with your secret key.

## Verify the payment

Confirm every payment from your backend, not from the mobile result:

- **Webhook**: Dodo Payments calls your backend when a payment
  succeeds or a subscription activates. Check the
  [Webhooks guide](https://docs.dodopayments.com/developer-resources/webhooks).
- **Verification API**: look up `paymentId` with your secret key via
  [Get Payment Detail](https://docs.dodopayments.com/api-reference/payments/get-payments-1).

## Abandoned sessions

If the app is killed mid-checkout, recover the interrupted session on next launch
and reconcile it server-side:

```swift
import DodoCheckout

if let abandoned = DodoCheckout.getAbandonedSession() {
    // reconcile abandoned.sessionId with your backend, then:
    DodoCheckout.clearAbandonedSession()
}
```

## Errors

`start` throws `CheckoutError` only for misuse or platform failure:
`INVALID_CHECKOUT_URL`, `INVALID_RETURN_URL`, `ALREADY_IN_PROGRESS`,
`PLATFORM_ERROR`. A user cancelling or a declined payment is a **result**
(`.cancelled` / `.failed`), never a thrown error.

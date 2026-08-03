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
case .succeeded: showSuccess(result.paymentId)         // UI only — confirm server-side
case .failed:    showFailure()
case .cancelled: await reconcileAbandonedSession()      // outcome unknown — NOT a failure
case .pending:   await reconcileAbandonedSession()      // may be unparsed, not just async
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

## `.cancelled` is not a failure

`.cancelled` means the user dismissed the sheet before any return URL arrived,
so the SDK never learned the outcome. **The payment may have gone through.**
A user who pays and then taps ✕ while the hosted "Payment Successful" page
counts down its redirect produces `.cancelled`, and is indistinguishable, from
the SDK's side, from a user who closed the sheet without paying.

Showing "Payment failed" here tells a paying customer their money vanished.
Resolve it instead: the SDK keeps the session on record for exactly this case.

## Abandoned sessions

A session stays on record whenever the SDK never saw a return URL it could
resolve to a durable outcome — the app was killed mid-checkout, `start`
returned `.cancelled`, or it returned `.pending` (which is also the fallback
for an unparseable return URL). Reconcile it server-side, both on next launch
and right after a `.cancelled` or `.pending` result:

```swift
import DodoCheckout

func reconcileAbandonedSession() async {
    guard let abandoned = DodoCheckout.getAbandonedSession() else {
        dismiss()   // nothing in flight
        return
    }
    // Ask *your* backend what happened to abandoned.sessionId — it has the
    // webhook (`payment.succeeded`) or can call Get Payment Detail with your
    // secret key. Show a spinner while you wait; an async method may still be
    // settling, so treat "no record yet" as pending, not failed — and only
    // clear the record once you have a terminal outcome, otherwise a later
    // retry has nothing left to reconcile against if this one comes back.
    let outcome = await myBackend.outcome(forSession: abandoned.sessionId)
    if outcome.isTerminal {
        DodoCheckout.clearAbandonedSession()
    }
    show(outcome)
}
```

## Errors

`start` throws `CheckoutError` only for misuse or platform failure:
`INVALID_CHECKOUT_URL`, `INVALID_RETURN_URL`, `ALREADY_IN_PROGRESS`,
`PLATFORM_ERROR`. A user cancelling or a declined payment is a **result**
(`.cancelled` / `.failed`), never a thrown error.

After any thrown error, check `getAbandonedSession()` too — most platform
failures happen before anything is recorded, but a presentation that timed
out without confirming may still have a session on record, since the sheet
could be live even though the SDK couldn't confirm it.

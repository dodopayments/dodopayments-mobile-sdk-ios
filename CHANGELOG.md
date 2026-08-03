# Changelog

## 1.0.1

- Fix: a `.cancelled` result no longer wipes the abandoned-session record.
  Dismissing the sheet is exactly the case where the SDK never saw the return
  URL and the payment may still have succeeded (e.g. tapping the ✕ while the
  hosted success page counts down its redirect); the session id now survives so
  `getAbandonedSession()` can be reconciled server-side instead of the merchant
  having to guess. Records that resolve via the return URL still clear as before.

## 1.0.0

- Initial release: `DodoCheckout.start(checkoutUrl:returnUrl:onEvent:)` over
  `SFSafariViewController`; typed `CheckoutResult`, `CheckoutError`, and
  abandoned-session recovery (`getAbandonedSession` / `clearAbandonedSession`).

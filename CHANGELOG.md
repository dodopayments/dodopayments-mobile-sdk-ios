# Changelog

## 1.0.2

- Fix: swiping down to dismiss the checkout sheet left `start`'s
  continuation unresumed, since `safariViewControllerDidFinish` only fires
  for the "Done" button tap, not the interactive swipe-to-dismiss on a
  `.pageSheet`. Wires `UIAdaptivePresentationControllerDelegate` to catch
  that case too and resolves with `.cancelled`, same as the Done button.

## 1.0.1

- Fix: a `.cancelled` or `.pending` result no longer wipes the abandoned-session
  record. Dismissing the sheet is one case where the SDK never saw the return
  URL and the payment may still have succeeded (e.g. tapping the ✕ while the
  hosted success page counts down its redirect). `.pending` is the other: it's
  also the fallback for a missing or unrecognized `status`, so a malformed
  return URL landed here too, sometimes with no `paymentId`/`subscriptionId`
  either — clearing then left no handle at all. The session id now survives
  both, so `getAbandonedSession()` can be reconciled server-side instead of the
  merchant having to guess. Records that resolve to a durable outcome still
  clear as before. The presentation-timeout throw (defense against `present`'s
  completion handler never running) no longer clears the record either, since
  that throw is not proof the sheet never appeared.

## 1.0.0

- Initial release: `DodoCheckout.start(checkoutUrl:returnUrl:onEvent:)` over
  `SFSafariViewController`; typed `CheckoutResult`, `CheckoutError`, and
  abandoned-session recovery (`getAbandonedSession` / `clearAbandonedSession`).

import Foundation

/// A checkout that ended without a durable outcome — the app was killed
/// mid-flow, the user dismissed the browser (`.cancelled`), or the return URL
/// couldn't be resolved to a definite result (`.pending`).
///
/// The SDK never learns the payment's real outcome in any of these cases: it
/// holds no API key, and `.pending` is also `ResultParser.mapStatus`'s
/// fallback for a missing or unrecognized `status`, so a malformed return URL
/// lands there too. The merchant reconciles the session server-side (webhook
/// or `payments.retrieve`). This record only tells the app *that* a checkout
/// was interrupted, and which session it was.
public struct AbandonedSession: Sendable, Equatable {
    public let sessionId: String
    public let createdAt: Date

    public init(sessionId: String, createdAt: Date) {
        self.sessionId = sessionId
        self.createdAt = createdAt
    }
}

/// Minimal key/value persistence, so the store can be tested without touching
/// real `UserDefaults`.
protocol KeyValueStore: AnyObject {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: KeyValueStore {
    func set(_ value: String?, forKey key: String) {
        if let value = value {
            setValue(value, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}

/// Records the in-flight session so it survives process death, and clears it on
/// a clean finish. Stores just enough to identify the session for reconciliation.
///
/// `@unchecked Sendable` with an internal lock: the store is process-wide and
/// may be touched from the main-actor checkout path and from launch-time
/// reconciliation on any executor.
final class AbandonedSessionStore: @unchecked Sendable {
    private let store: KeyValueStore
    private let lock = NSLock()
    private let sessionKey = "com.dodopayments.checkout.abandoned.sessionId"
    private let createdAtKey = "com.dodopayments.checkout.abandoned.createdAt"

    init(store: KeyValueStore = UserDefaults.standard) {
        self.store = store
    }

    /// Extracts the `cks_…` session id from a checkout URL's `/session/{id}` path.
    static func sessionId(from checkoutUrl: URL) -> String? {
        let parts = checkoutUrl.path.split(separator: "/").map(String.init)
        guard let idx = parts.firstIndex(of: "session"), idx + 1 < parts.count else {
            return nil
        }
        return parts[idx + 1]
    }

    func record(checkoutUrl: URL, at date: Date = Date()) {
        guard let sessionId = AbandonedSessionStore.sessionId(from: checkoutUrl) else { return }
        lock.lock()
        defer { lock.unlock() }
        store.set(sessionId, forKey: sessionKey)
        store.set(String(date.timeIntervalSince1970), forKey: createdAtKey)
    }

    func current() -> AbandonedSession? {
        lock.lock()
        defer { lock.unlock() }
        guard let sessionId = store.string(forKey: sessionKey), !sessionId.isEmpty else {
            return nil
        }
        let createdAt: Date
        if let raw = store.string(forKey: createdAtKey), let seconds = TimeInterval(raw) {
            createdAt = Date(timeIntervalSince1970: seconds)
        } else {
            createdAt = Date(timeIntervalSince1970: 0)
        }
        return AbandonedSession(sessionId: sessionId, createdAt: createdAt)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        store.removeObject(forKey: sessionKey)
        store.removeObject(forKey: createdAtKey)
    }

    /// Clears the record only when the checkout produced a *durable* outcome.
    ///
    /// `.cancelled` means the user dismissed the browser before any return URL
    /// arrived, so the SDK learned nothing — the payment may well have
    /// succeeded (dismissing while the hosted "Payment Successful" page counts
    /// down its redirect is indistinguishable, from here, from dismissing
    /// before paying at all). `.pending` is the same kind of non-answer: it's
    /// also `ResultParser.mapStatus`'s fallback for a missing or unrecognized
    /// `status`, so a malformed return URL lands here too, with `paymentId`
    /// and `subscriptionId` both potentially `nil` — clearing then would leave
    /// no handle at all, worse than the bug this method exists to fix. An
    /// exhaustive `switch` rather than a `.cancelled`-only guard, so a future
    /// status is a compile error here instead of silently falling through to
    /// "clear".
    func clearIfOutcomeKnown(_ status: CheckoutStatus) {
        switch status {
        case .succeeded, .failed, .expired:
            clear()
        case .cancelled, .pending:
            break
        }
    }
}

import XCTest
@testable import DodoCheckout

private final class FakeStore: KeyValueStore {
    var values: [String: String] = [:]
    func string(forKey key: String) -> String? { values[key] }
    func set(_ value: String?, forKey key: String) {
        if let value = value { values[key] = value } else { values.removeValue(forKey: key) }
    }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }
}

/// Logic behind E10 (recover an abandoned session) without process death.
final class AbandonedSessionStoreTests: XCTestCase {

    func testExtractsSessionIdFromCheckoutUrl() {
        let url = URL(string: "https://test.checkout.dodopayments.com/session/cks_abc123")!
        XCTAssertEqual(AbandonedSessionStore.sessionId(from: url), "cks_abc123")
    }

    func testRecordThenCurrentReturnsSession() {
        let store = FakeStore()
        let subject = AbandonedSessionStore(store: store)
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        subject.record(checkoutUrl: URL(string: "https://checkout.dodopayments.com/session/cks_xyz")!, at: created)

        let session = subject.current()
        XCTAssertEqual(session?.sessionId, "cks_xyz")
        XCTAssertEqual(session?.createdAt, created)
    }

    func testClearRemovesSession() {
        let store = FakeStore()
        let subject = AbandonedSessionStore(store: store)
        subject.record(checkoutUrl: URL(string: "https://checkout.dodopayments.com/session/cks_xyz")!)
        subject.clear()
        XCTAssertNil(subject.current())
    }

    /// The reported bug: pay, then tap the sheet's ✕ while the hosted success
    /// page is still counting down its redirect. The SDK reports `.cancelled`
    /// because it never saw the return URL, so the session must stay on record
    /// — that id is the merchant's only handle for reconciling a payment that
    /// did go through.
    func testCancelledKeepsSessionForReconciliation() {
        let subject = AbandonedSessionStore(store: FakeStore())
        subject.record(checkoutUrl: URL(string: "https://checkout.dodopayments.com/session/cks_xyz")!)
        subject.clearIfOutcomeKnown(.cancelled)
        XCTAssertEqual(subject.current()?.sessionId, "cks_xyz")
    }

    func testResolvedOutcomesClearSession() {
        for status in [CheckoutStatus.succeeded, .failed, .pending, .expired] {
            let subject = AbandonedSessionStore(store: FakeStore())
            subject.record(checkoutUrl: URL(string: "https://checkout.dodopayments.com/session/cks_xyz")!)
            subject.clearIfOutcomeKnown(status)
            XCTAssertNil(subject.current(), "\(status) should clear the record")
        }
    }

    func testNoSessionReturnsNil() {
        XCTAssertNil(AbandonedSessionStore(store: FakeStore()).current())
    }
}

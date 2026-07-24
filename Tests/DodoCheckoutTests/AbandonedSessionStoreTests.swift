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

    func testNoSessionReturnsNil() {
        XCTAssertNil(AbandonedSessionStore(store: FakeStore()).current())
    }
}

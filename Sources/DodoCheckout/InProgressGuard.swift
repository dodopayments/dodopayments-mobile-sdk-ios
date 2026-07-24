import Foundation

/// Enforces the "only one checkout at a time" rule. A second `begin()` while a
/// checkout is live throws `ALREADY_IN_PROGRESS`. Isolated to the main actor,
/// matching where checkout presentation happens.
@MainActor
final class InProgressGuard {
    private(set) var isInProgress = false

    func begin() throws {
        guard !isInProgress else {
            throw CheckoutError.alreadyInProgress
        }
        isInProgress = true
    }

    func end() {
        isInProgress = false
    }
}

import Foundation

/// Turns the query string on a matched `return_url` into a `CheckoutResult`.
///
/// Status mapping (see plan §3):
///   - `succeeded` (one-time) / `active` (subscription)  → `.succeeded`
///   - `processing` / any `requires_*`                   → `.pending`
///   - `failed`                                          → `.failed`
///   - `expired`                                         → `.expired`
///   - anything else (or missing)                        → `.pending`
///
/// An unrecognized/missing status defaults to `.pending` rather than a
/// definite outcome: the SDK result is a UI hint and the webhook is the
/// authority, so "we don't know yet" is the safe fallback.
enum ResultParser {
    static func parse(url: URL) -> CheckoutResult {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        var raw: [String: String] = [:]
        var licenseKeys: [String] = []
        for item in items {
            let value = item.value ?? ""
            raw[item.name] = value
            if item.name == "license_key" && !value.isEmpty {
                licenseKeys.append(value)
            }
        }

        let status = mapStatus(raw["status"])
        return CheckoutResult(
            status: status,
            paymentId: nonEmpty(raw["payment_id"]),
            subscriptionId: nonEmpty(raw["subscription_id"]),
            licenseKeys: licenseKeys.isEmpty ? nil : licenseKeys,
            customerEmail: nonEmpty(raw["email"]),
            raw: raw
        )
    }

    static func mapStatus(_ rawStatus: String?) -> CheckoutStatus {
        guard let raw = rawStatus?.lowercased(), !raw.isEmpty else {
            return .pending
        }
        switch raw {
        case "succeeded", "active":
            return .succeeded
        case "failed":
            return .failed
        case "expired":
            return .expired
        default:
            // `processing`, `requires_*`, unknown, and any future async state
            // settle later — treat as pending, since the webhook is authoritative.
            return .pending
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value, !value.isEmpty else { return nil }
        return value
    }
}

import Foundation

/// Decides whether a navigation is the merchant's `return_url`.
///
/// The match compares **scheme + host + path only** and ignores the query and
/// fragment — the query string is the payload, not part of the identity. Host
/// and scheme are compared case-insensitively and a single trailing slash on
/// the path is ignored, so cosmetic differences still match.
///
/// Crucially, the intermediate `…/return/{payment_id}` hop on Dodo's own host
/// must **not** match — only the final merchant `return_url` does. Because the
/// merchant's return URL host differs from the Dodo backend host, comparing the
/// host guarantees this.
struct ReturnUrlMatcher {
    let scheme: String
    let host: String
    let path: String

    init(returnUrl: URL) {
        let components = URLComponents(url: returnUrl, resolvingAgainstBaseURL: false)
        self.scheme = ReturnUrlMatcher.normalizeScheme(components?.scheme ?? returnUrl.scheme)
        self.host = ReturnUrlMatcher.normalizeHost(components?.host ?? returnUrl.host)
        self.path = ReturnUrlMatcher.normalizePath(components?.path ?? returnUrl.path)
    }

    func matches(_ url: URL) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let candidateScheme = ReturnUrlMatcher.normalizeScheme(components?.scheme ?? url.scheme)
        let candidateHost = ReturnUrlMatcher.normalizeHost(components?.host ?? url.host)
        let candidatePath = ReturnUrlMatcher.normalizePath(components?.path ?? url.path)
        return candidateScheme == scheme
            && candidateHost == host
            && candidatePath == path
    }

    // MARK: - Normalization

    private static func normalizeScheme(_ scheme: String?) -> String {
        (scheme ?? "").lowercased()
    }

    private static func normalizeHost(_ host: String?) -> String {
        (host ?? "").lowercased()
    }

    /// Treats `/done` and `/done/` as equal; an empty path normalizes to `/`.
    private static func normalizePath(_ path: String?) -> String {
        var p = path ?? ""
        if p.isEmpty { return "/" }
        while p.count > 1 && p.hasSuffix("/") {
            p.removeLast()
        }
        return p
    }
}

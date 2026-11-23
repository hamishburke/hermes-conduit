#if ELIO_PERSONAL
import Foundation

/// What this build is, and what the newest one is called. The release script
/// stamps the version into the build, so the two can be compared honestly.
enum ElioBuild {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var number: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    static var repository: String { "hamishburke/hermes-conduit" }

    /// Compares two dotted release versions, so "2026.11.24.2" beats
    /// "2026.11.24.1" and a shorter one is not treated as newer.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let left = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let right = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a > b }
        }
        return false
    }
}
#endif

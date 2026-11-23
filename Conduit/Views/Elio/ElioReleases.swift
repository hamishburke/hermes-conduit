#if ELIO_PERSONAL
import Foundation

/// The newest published build, read from this fork's GitHub releases. Nothing
/// installs itself: an iPhone cannot, so this exists to say what is newer than
/// what is running and what to run to get it.
@MainActor
final class ElioReleases: ObservableObject {
    struct Release: Identifiable, Equatable {
        let tag: String
        let notes: String
        let published: Date
        var id: String { tag }
        /// "elio-2026.11.24.2" -> "2026.11.24.2"
        var version: String { tag.replacingOccurrences(of: "elio-", with: "") }
    }

    @Published private(set) var newest: Release?
    @Published private(set) var checked = false

    private var task: Task<Void, Never>?

    var newerThanRunning: Release? {
        guard let newest else { return nil }
        return ElioBuild.isNewer(newest.version, than: ElioBuild.version) ? newest : nil
    }

    func check() {
        guard !checked, task == nil else { return }
        task = Task { [weak self] in
            defer { self?.task = nil }
            guard let url = URL(string:
                "https://api.github.com/repos/\(ElioBuild.repository)/releases?per_page=20")
            else { return }
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
                let releases: [Release] = rows.compactMap { row in
                    guard let tag = row["tag_name"] as? String,
                          tag.hasPrefix("elio-") else { return nil }
                    let published = (row["published_at"] as? String).flatMap(Self.date) ?? .distantPast
                    return Release(tag: tag,
                                   notes: (row["body"] as? String) ?? "",
                                   published: published)
                }
                let newest = releases.reduce(into: nil as Release?) { best, release in
                    guard let current = best else { best = release; return }
                    if ElioBuild.isNewer(release.version, than: current.version) {
                        best = release
                    }
                }
                self?.newest = newest
                self?.checked = true
            } catch {
                self?.checked = true
            }
        }
    }

    private static func date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
#endif

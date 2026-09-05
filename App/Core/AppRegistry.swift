import Foundation
import Combine

/// Gère la liste blanche des apps Sideloadly à suivre.
/// Persistée en JSON dans le container de l'app (aucun marqueur système
/// ne permet de détecter "vient de Sideloadly" automatiquement,
/// donc l'utilisateur doit lui-même ajouter les apps une fois — voir AddAppView).
final class AppRegistry: ObservableObject {
    static let shared = AppRegistry()

    @Published private(set) var trackedApps: [TrackedApp] = []

    private let storageURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tracked_apps.json")
    }()

    private init() {
        load()
    }

    func add(_ app: TrackedApp) {
        trackedApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        trackedApps.append(app)
        save()
    }

    func remove(bundleIdentifier: String) {
        trackedApps.removeAll { $0.bundleIdentifier == bundleIdentifier }
        save()
    }

    func update(_ app: TrackedApp) {
        guard let idx = trackedApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) else { return }
        trackedApps[idx] = app
        save()
    }

    /// Apps dont l'expiration approche, à traiter en priorité par RefreshCoordinator.
    func appsNeedingRefresh(within days: Int = 2) -> [TrackedApp] {
        trackedApps.filter { $0.daysRemaining <= days }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([TrackedApp].self, from: data) else { return }
        trackedApps = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(trackedApps) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}

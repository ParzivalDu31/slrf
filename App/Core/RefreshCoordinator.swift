import Foundation
import BackgroundTasks

/// Point d'entrée qui orchestre un cycle de refresh complet, déclenché soit
/// manuellement (bouton dans l'UI) soit en tâche de fond périodique
/// (BGAppRefreshTask — même mécanisme qu'AltStore/SideStore utilisent).
final class RefreshCoordinator {
    static let shared = RefreshCoordinator()
    static let backgroundTaskIdentifier = "com.tonapp.refresh"

    enum RefreshResult {
        case success(TrackedApp)
        case failure(TrackedApp, Error)
    }

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleNextBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 6) // toutes les 6h
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        scheduleNextBackgroundRefresh() // reprogrammer avant de traiter, comme recommandé par Apple

        let operation = Task {
            let results = await refreshExpiringApps()
            task.setTaskCompleted(success: results.allSatisfy {
                if case .success = $0 { return true }
                return false
            })
        }
        task.expirationHandler = { operation.cancel() }
    }

    @MainActor
    func refreshExpiringApps() async -> [RefreshResult] {
        var results: [RefreshResult] = []
        let toRefresh = AppRegistry.shared.appsNeedingRefresh()

        guard !toRefresh.isEmpty else { return results }

        do {
            try await PairingManager.shared.startLoopbackSession()

            guard let session = CertificateManager.shared.currentSession else {
                throw RefreshError.notAuthenticated
            }
            let bundleIDs = toRefresh.map { $0.bundleIdentifier }
            let signingBundle = try await CertificateManager.shared.regenerateCertificateIfNeeded(
                session: session,
                bundleIdentifiers: bundleIDs
            )

            for app in toRefresh {
                do {
                    let profilesForApp = signingBundle.profiles.filter { $0.bundleIdentifier == app.bundleIdentifier }
                    let resignedBundle = try await ResignManager.shared.resign(
                        app,
                        team: signingBundle.team,
                        keyStore: signingBundle.keyStore,
                        provisioningProfiles: profilesForApp
                    )

                    try await InstallManager.shared.install(
                        resignedIPAURL: resignedBundle,
                        bundleIdentifier: app.bundleIdentifier,
                        provisioningProfileData: profilesForApp.first?.data ?? Data()
                    )

                    var updated = app
                    updated.lastRefreshDate = Date()
                    if let newExpiration = profilesForApp.first?.expirationDate {
                        updated.expirationDate = newExpiration
                    }
                    AppRegistry.shared.update(updated)

                    results.append(.success(updated))
                } catch {
                    results.append(.failure(app, error))
                }
            }
        } catch {
            results = toRefresh.map { .failure($0, error) }
        }
        return results
    }

    enum RefreshError: Error, LocalizedError {
        case notAuthenticated
        var errorDescription: String? {
            "Pas encore authentifié avec l'Apple ID — passe par l'écran de connexion d'abord."
        }
    }
}

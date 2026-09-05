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
            let certificate = try await CertificateManager.shared.regenerateCertificateIfNeeded()

            for app in toRefresh {
                do {
                    let resignedBundle = try ResignManager.shared.resign(
                        app,
                        p12Data: certificate.p12Data,
                        entitlementProvider: { _ in
                            String(data: certificate.profileData, encoding: .utf8) ?? ""
                        }
                    )
                    try await InstallManager.shared.install(
                        resignedIPAURL: resignedBundle,
                        bundleIdentifier: app.bundleIdentifier,
                        provisioningProfileData: certificate.profileData
                    )

                    var updated = app
                    updated.lastRefreshDate = Date()
                    updated.expirationDate = certificate.expirationDate
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
}

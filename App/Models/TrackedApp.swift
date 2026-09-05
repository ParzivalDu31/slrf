import Foundation

/// Représente une app installée via Sideloadly que l'on suit pour refresh automatique.
struct TrackedApp: Identifiable, Codable, Equatable {
    var id: String { bundleIdentifier }

    let bundleIdentifier: String
    var displayName: String
    /// Chemin local (dans le sandbox de notre app) vers le .ipa ou .app source
    /// récupéré une fois, nécessaire pour le re-signing.
    var sourceBundlePath: String?
    /// Date d'expiration lue depuis l'embedded.mobileprovision de l'app.
    var expirationDate: Date
    var lastRefreshDate: Date?
    var addedManuallyBySideloadly: Bool = true

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
    }

    var isExpiringSoon: Bool {
        daysRemaining <= 2
    }
}

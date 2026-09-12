import Foundation
import Minimuxer

/// Détection automatique des apps sideloadées : utilise listInstalledApps()
/// (ajouté dans notre fork de minimuxer) pour lister toutes les apps du device,
/// puis filtre celles signées par le même Team ID que le compte Apple connecté.
///
/// LIMITE HONNÊTE RESTANTE : ceci détecte le BUNDLE ID et confirme qu'une app
/// nous appartient (même certificat), mais ne résout PAS le problème du fichier
/// source (.ipa/.app) nécessaire pour la re-signature — ResignManager a encore
/// besoin de sourceBundlePath. Une vraie solution complète demanderait d'extraire
/// le bundle .app déjà installé sur le device (via AFC) plutôt que d'exiger un
/// .ipa importé manuellement — ce n'est pas fait ici, à traiter séparément.
final class AppDiscoveryService {
    static let shared = AppDiscoveryService()

    /// Notre propre bundle ID, à exclure des résultats.
    var ownBundleIdentifier = "com.tonapp.sideloadlyrefresher"

    func discoverSideloadedApps(teamIdentifier: String) async throws -> [InstalledAppInfo] {
        let allApps = try await Minimuxer.shared().core.listInstalledApps(applicationType: "User")

        return allApps.filter { app in
            guard app.bundleIdentifier != ownBundleIdentifier else { return false }
            guard let signer = app.signerIdentity else { return false }
            // App Store: "Apple iPhone OS Application Signing" (ne contient jamais un Team ID perso)
            // Sideloadée avec notre compte: "iPhone Developer: Nom (TEAMID)" ou similaire
            return signer.contains(teamIdentifier)
        }
    }
}

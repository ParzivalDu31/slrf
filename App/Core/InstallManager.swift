import Foundation
import AppDependencies

/// Installe/réinstalle une app via les vraies fonctions exposées par
/// MinimuxerAPI (Sources/MinimuxerApi.swift) :
///   - yeetAppAfc(bundleId:ipaBytes:) → transfère le .ipa sur le device via AFC
///   - installProvisioningProfile(profile:) → installe le nouveau profil
///   - installIpa(bundleId:) → déclenche l'installation réelle via instproxy
final class InstallManager {
    static let shared = InstallManager()

    enum InstallError: Error, LocalizedError {
        case ipaReadFailed
        case minimuxerError(MinimuxerError)

        var errorDescription: String? {
            switch self {
            case .ipaReadFailed: return "Impossible de lire le fichier .ipa re-signé."
            case .minimuxerError(let err): return "Erreur Minimuxer lors de l'installation : \(err)"
            }
        }
    }

    /// `resignedIPAURL` doit pointer vers le .ipa re-signé produit par ResignManager.
    /// `provisioningProfileData` est le profil frais généré par CertificateManager.
    func install(
        resignedIPAURL: URL,
        bundleIdentifier: String,
        provisioningProfileData: Data
    ) async throws {
        guard let ipaBytes = try? Data(contentsOf: resignedIPAURL) else {
            throw InstallError.ipaReadFailed
        }

        do {
            // 1. Installer/mettre à jour le provisioning profile sur le device
            try await Minimuxer.shared().core.installProvisioningProfile(profile: provisioningProfileData)

            // 2. Transférer le .ipa re-signé sur le device via AFC
            try await Minimuxer.shared().core.yeetAppAfc(bundleId: bundleIdentifier, ipaBytes: ipaBytes)

            // 3. Déclencher l'installation réelle (remplace la version existante,
            //    conserve les données de l'app si le bundle ID est identique)
            try await Minimuxer.shared().core.installIpa(bundleId: bundleIdentifier)
        } catch let error as MinimuxerError {
            throw InstallError.minimuxerError(error)
        }
    }

    /// Utilitaire pour vérifier qu'une app est bien reconnue installée après coup.
    func verifyInstalled(bundleIdentifier: String) async -> Bool {
        // MinimuxerAPI n'expose pas directement un "isInstalled" simple dans cette
        // version — à défaut, on peut tenter afcGetFileInfo sur le container de l'app
        // pour confirmer sa présence après installIpa().
        (try? await Minimuxer.shared().core.afcGetFileInfo(bundleId: bundleIdentifier, path: "/")) != nil
    }
}

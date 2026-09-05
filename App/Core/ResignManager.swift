import Foundation
import SideSign

/// Re-signe un bundle .app avec SideSign (github.com/SideStore/SideSign) —
/// remplace AltSign, aucune dépendance OpenSSL (utilise swift-crypto officiel
/// d'Apple), donc plus de conflit de target avec RemotePairingKit/minimuxer.
final class ResignManager {
    static let shared = ResignManager()

    enum ResignError: Error, LocalizedError {
        case sourceBundleMissing
        case signingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .sourceBundleMissing: return "Le bundle .app source est introuvable."
            case .signingFailed(let err): return "Échec de la signature : \(err.localizedDescription)"
            }
        }
    }

    /// Re-signe le bundle `.app` de `app.sourceBundlePath` avec les provisioning
    /// profiles fournis (un par exécutable/extension du bundle, générés par
    /// CertificateManager). Retourne l'URL du bundle signé.
    func resign(_ app: TrackedApp, provisioningProfiles: [ProvisioningProfile]) async throws -> URL {
        guard let sourcePath = app.sourceBundlePath,
              FileManager.default.fileExists(atPath: sourcePath) else {
            throw ResignError.sourceBundleMissing
        }

        let signer = AppBundleSigner()
        let appURL = URL(fileURLWithPath: sourcePath)

        do {
            try await signer.signApp(at: appURL, provisioningProfiles: provisioningProfiles)
        } catch {
            throw ResignError.signingFailed(error)
        }

        return appURL
    }
}

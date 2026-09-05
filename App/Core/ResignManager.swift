import Foundation
import AltSign   // SPM: https://github.com/SideStore/AltSign.git

/// Re-signe un bundle .app avec la vraie API AltSign — Swift pur, in-process,
/// pas de subprocess. Confirmé en inspectant SwiftBridge/LdidBridge.swift et
/// SwiftBridge/CertificatesManager.swift du repo SideStore/AltSign.
///
/// Intégration : File > Add Package Dependencies… > https://github.com/SideStore/AltSign.git
/// (le Package.swift d'AltSign embarque déjà un binaryTarget OpenSSL.xcframework précompilé)
final class ResignManager {
    static let shared = ResignManager()

    enum ResignError: Error, LocalizedError {
        case sourceBundleMissing
        case ldidSignFailed(Error)
        case certificateChainInvalid

        var errorDescription: String? {
            switch self {
            case .sourceBundleMissing: return "Le bundle .app source est introuvable."
            case .ldidSignFailed(let err): return "Échec de la signature : \(err.localizedDescription)"
            case .certificateChainInvalid: return "Chaîne de certificat invalide (.p12)."
            }
        }
    }

    /// Re-signe le bundle .app extrait de `app.sourceBundlePath` avec le certificat
    /// fourni. Retourne l'URL du bundle signé, prêt pour ResignManager → InstallManager.
    ///
    /// `entitlementProvider` doit retourner les entitlements XML à injecter pour
    /// chaque exécutable du bundle (typiquement lus depuis le provisioning profile
    /// fraîchement généré par CertificateManager).
    func resign(
        _ app: TrackedApp,
        p12Data: Data,
        entitlementProvider: @escaping (String) -> String
    ) throws -> URL {
        guard let sourcePath = app.sourceBundlePath,
              FileManager.default.fileExists(atPath: sourcePath) else {
            throw ResignError.sourceBundleMissing
        }

        do {
            try LdidBridge.sign(
                appPath: sourcePath,
                keyData: p12Data,
                entitlementProvider: entitlementProvider,
                progress: { /* possibilité de publier une progression à l'UI ici */ }
            )
        } catch {
            throw ResignError.ldidSignFailed(error)
        }

        return URL(fileURLWithPath: sourcePath)
    }

    /// Vérifie que le certificat p12 fourni est valide/parseable avant de tenter
    /// une signature (évite un échec silencieux côté ldid).
    func validateCertificate(p12Data: Data) throws {
        do {
            _ = try CertificatesManager.extractUnencryptedPKCS12(p12Data)
        } catch {
            throw ResignError.certificateChainInvalid
        }
    }
}

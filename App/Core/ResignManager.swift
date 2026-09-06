import Foundation
import SideSign

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

    func resign(
        _ app: TrackedApp,
        team: Team,
        keyStore: KeyStore,
        provisioningProfiles: [ProvisioningProfile]
    ) async throws -> URL {
        guard let sourcePath = app.sourceBundlePath,
              FileManager.default.fileExists(atPath: sourcePath) else {
            throw ResignError.sourceBundleMissing
        }

        let signer = AppBundleSigner(team: team, keyStore: keyStore)
        let appURL = URL(fileURLWithPath: sourcePath)

        do {
            try await signer.signApp(at: appURL, provisioningProfiles: provisioningProfiles)
        } catch {
            throw ResignError.signingFailed(error)
        }

        return appURL
    }
}

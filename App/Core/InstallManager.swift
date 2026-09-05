import Foundation
import Minimuxer

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

    func install(
        resignedIPAURL: URL,
        bundleIdentifier: String,
        provisioningProfileData: Data
    ) async throws {
        guard let ipaBytes = try? Data(contentsOf: resignedIPAURL) else {
            throw InstallError.ipaReadFailed
        }

        do {
            try await Minimuxer.shared().core.installProvisioningProfile(profile: provisioningProfileData)
            try await Minimuxer.shared().core.yeetAppAfc(bundleId: bundleIdentifier, ipaBytes: ipaBytes)
            try await Minimuxer.shared().core.installIpa(bundleId: bundleIdentifier)
        } catch let error as MinimuxerError {
            throw InstallError.minimuxerError(error)
        }
    }

    func verifyInstalled(bundleIdentifier: String) async -> Bool {
        (try? await Minimuxer.shared().core.afcGetFileInfo(bundleId: bundleIdentifier, path: "/")) != nil
    }
}

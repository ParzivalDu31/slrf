import Foundation
import SideSign
import AnisetteKit

/// Régénère certificat + provisioning profiles via SideSign.DeveloperPortal.
///
/// Pour l'anisette (headers requis par l'auth Apple), on utilise le mode
/// `.remote(server:)` de `AnisetteDataProvider` — pointe vers un serveur
/// communautaire public de la liste officielle SideStore
/// (github.com/SideStore/anisette-servers/blob/main/servers.json).
/// AVANTAGE : aucune bibliothèque Apple à récupérer toi-même.
/// COMPROMIS À CONNAÎTRE : ce serveur tiers reçoit indirectement des données
/// liées à ton compte Apple ID pendant l'auth (comme AltServer/SideStore
/// eux-mêmes le font par défaut) — choisis un serveur de la liste officielle,
/// pas un serveur inconnu.
final class CertificateManager {
    static let shared = CertificateManager()

    enum CertError: Error, LocalizedError {
        case notAuthenticated
        case noTeamFound
        case anisetteFailed(Error)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "Authentification Apple ID échouée."
            case .noTeamFound: return "Aucune équipe développeur trouvée sur ce compte."
            case .anisetteFailed(let err): return "Échec de génération anisette : \(err.localizedDescription)"
            }
        }
    }

    private let portal = DeveloperPortal.shared
    private let anisetteProvider = AnisetteDataProvider.shared

    /// Choisis un serveur dans la liste officielle : github.com/SideStore/anisette-servers
    var anisetteServerURL = URL(string: "https://ani.npeg.us")!

    var currentSession: Session?

    /// Authentifie avec l'Apple ID. `verificationHandler` doit être branché sur
    /// une UI qui demande le code 2FA à l'utilisateur et le retourne.
    func authenticate(
        appleID: String,
        password: String,
        verificationHandler: DeveloperPortal.VerificationHandler? = nil
    ) async throws -> AuthSession {
        await anisetteProvider.setMode(.remote(server: anisetteServerURL))

        let anisetteResult: (data: AnisetteData, newAdiBlob: Data?)
        do {
            anisetteResult = try await anisetteProvider.fetchAnisetteData()
        } catch {
            throw CertError.anisetteFailed(error)
        }

        let authSession = try await portal.authenticate(
            appleID: appleID,
            password: password,
            anisetteData: anisetteResult.data,
            xcodeVersion: "16.0",
            verificationHandler: verificationHandler
        )
        currentSession = authSession.session
        return authSession
    }

    func regenerateCertificateIfNeeded(session: Session, bundleIdentifiers: [String]) async throws -> SigningBundle {
        let account = try await portal.fetchAccount(session: session)
        let teams = try await portal.fetchTeams(for: account, session: session)
        guard let team = teams.first else { throw CertError.noTeamFound }

        let existingCerts = try await portal.fetchCertificates(for: team, session: session)
        for cert in existingCerts {
            _ = try await portal.revokeCertificate(cert, for: team, session: session)
        }

        let keyStore = try await portal.addCertificate(machineName: "SideloadlyRefresher", to: team, session: session)

        var profiles: [ProvisioningProfile] = []
        let appIDs = try await portal.fetchAppIDs(for: team, session: session)
        for bundleID in bundleIdentifiers {
            guard let appID = appIDs.first(where: { $0.bundleIdentifier == bundleID }) else { continue }
            let profile = try await portal.downloadProvisioningProfile(for: appID, deviceType: .iPhone, team: team, session: session)
            profiles.append(profile)
        }

        return SigningBundle(team: team, keyStore: keyStore, profiles: profiles)
    }
}

/// Certificat + profils regénérés, prêts pour ResignManager.
struct SigningBundle {
    let team: Team
    let keyStore: KeyStore
    let profiles: [ProvisioningProfile]
}

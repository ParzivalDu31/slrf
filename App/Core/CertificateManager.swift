import Foundation
import SideSign

/// Régénère un certificat + provisioning profile via SideSign, qui embarque
/// désormais TOUT ce qu'il fallait avant chercher en Rust (apple-private-apis) :
/// - `DeveloperPortal` : appels developer.apple.com (Swift pur)
/// - `AnisetteKit.LocalAnisetteProvider` : génère les headers anisette EN LOCAL
///   sur l'iPhone (pas besoin de serveur Anisette externe !)
///
/// VRAI PRÉREQUIS À RÉGLER TOI-MÊME (je ne peux pas te les fournir, ce sont des
/// binaires propriétaires Apple) : LocalAnisetteProvider a besoin de deux
/// bibliothèques — `libstoreservicescore.so` et `libCoreADI.so` — placées dans
/// un dossier accessible à l'app. C'est la même contrainte que tous les projets
/// "anisette-v3" (généralement extraites d'une installation iTunes/iCloud pour
/// Windows, ou trouvées via la communauté SideStore — cherche "anisette libraries
/// ADI" dans leur Discord/wiki, je ne peux pas les héberger ni te dire où les
/// obtenir précisément).
final class CertificateManager {
    static let shared = CertificateManager()

    enum CertError: Error, LocalizedError {
        case librariesNotConfigured
        case notAuthenticated
        case noTeamFound
        case existingCertificateMustBeRevoked

        var errorDescription: String? {
            switch self {
            case .librariesNotConfigured: return "Bibliothèques ADI (libstoreservicescore/libCoreADI) introuvables — voir commentaires du fichier."
            case .notAuthenticated: return "Authentification Apple ID échouée."
            case .noTeamFound: return "Aucune équipe développeur trouvée sur ce compte."
            case .existingCertificateMustBeRevoked: return "Un certificat existant doit être révoqué d'abord (compte gratuit = 1 seul certificat actif)."
            }
        }
    }

    private let portal = DeveloperPortal.shared

    /// Session obtenue après authenticate() réussi — à persister/rafraîchir
    /// selon la durée de vie réelle du token (à vérifier dans Models/Session.swift).
    var currentSession: Session?

    /// Dossier où tu dois placer les deux .so mentionnés plus haut, ex:
    /// Documents/ADILibraries/ dans le sandbox de l'app (à choisir toi-même).
    var adiLibraryDirectory: URL?

    private func makeAnisetteProvider() throws -> LocalAnisetteProvider {
        guard let libDir = adiLibraryDirectory,
              LocalAnisetteProvider.validateLibrariesExist(at: libDir) else {
            throw CertError.librariesNotConfigured
        }
        let provisioningDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("anisette_provisioning")
        try? FileManager.default.createDirectory(at: provisioningDir, withIntermediateDirectories: true)

        return try LocalAnisetteProvider(
            provisioningDir: provisioningDir,
            libraryDirectoryResolver: { libDir }
        )
    }

    /// Authentifie avec l'Apple ID (2FA géré via verificationHandler, à brancher
    /// sur une UI de saisie de code dans l'app).
    func authenticate(
        appleID: String,
        password: String,
        verificationHandler: DeveloperPortal.VerificationHandler? = nil
    ) async throws -> AuthSession {
        let anisetteProvider = try makeAnisetteProvider()
        let anisetteData = try await anisetteProvider.getHeaders(identifier: UUID())
        // NOTE: `authenticate` attend un `AnisetteData`, pas juste des headers bruts —
        // à adapter selon la structure exacte exposée par la version de SideSign
        // que tu auras réellement liée (vérifie Models/AnisetteData.swift pour le
        // constructeur exact au moment de la compilation).
        fatalError("Adapter la conversion headers → AnisetteData selon la version exacte de SideSign liée")
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

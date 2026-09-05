import Foundation

/// Régénère un certificat de développement + provisioning profile via l'API
/// Apple Developer privée (GSA/GrandSlam), authentifiée avec l'Apple ID.
///
/// CONTRAIREMENT à minimuxer et AltSign (Swift purs, intégrables directement
/// via SPM), cette brique s'appuie sur `SideStore/apple-private-apis`
/// (github.com/SideStore/apple-private-apis), qui est resté un workspace
/// **Rust** (crates : omnisette, icloud-auth, apple-dev-apis, apple-codesign-wrapper).
/// C'est la seule dépendance du projet qui nécessite vraiment une compilation
/// croisée manuelle + un bridge FFI Rust → Swift, plutôt qu'un simple SPM.
///
/// Étapes réelles pour l'intégrer :
///   1. `rustup target add aarch64-apple-ios`
///   2. Dans apple-private-apis/apple-dev-apis (et icloud-auth), ajouter un
///      `crate-type = ["staticlib"]` si absent, puis `cargo build --release
///      --target aarch64-apple-ios`
///   3. Générer les headers C avec `cbindgen` pour les fonctions publiques de
///      `icloud-auth::client` (authentification GSA) et `apple-dev-apis::session`
///      (endpoints developer.apple.com : liste/révocation certificats, CSR signing)
///   4. Lier le `.a` résultant + bridging header dans ce target Xcode
///
/// Avec un compte GRATUIT :
/// - 1 seul certificat "iOS Development" actif à la fois → il faut le révoquer
///   avant d'en générer un nouveau si Sideloadly/Xcode en a déjà un.
/// - Provisioning profile valide 7 jours seulement.
/// - Max 3 apps sideloadées simultanément.
final class CertificateManager {
    static let shared = CertificateManager()

    enum CertError: Error, LocalizedError {
        case notAuthenticated
        case twoFactorRequired
        case anisetteServerUnreachable
        case existingCertificateMustBeRevoked
        case rustBridgeNotLinked

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "Authentification Apple ID échouée."
            case .twoFactorRequired: return "Code 2FA requis."
            case .anisetteServerUnreachable: return "Serveur Anisette injoignable."
            case .existingCertificateMustBeRevoked: return "Un certificat existant doit être révoqué d'abord (compte gratuit = 1 seul certificat actif)."
            case .rustBridgeNotLinked: return "Le bridge Rust apple-private-apis n'est pas encore lié à ce target."
            }
        }
    }

    /// Serveur Anisette : génère les headers machine requis par GSA.
    /// Liste de serveurs publics recommandés par SideStore :
    /// github.com/SideStore/AnisetteServers (fichier JSON à jour, à fetch au runtime).
    var anisetteServerURL: URL?

    func authenticate(appleID: String, password: String, twoFactorCode: String?) async throws {
        guard anisetteServerURL != nil else { throw CertError.anisetteServerUnreachable }
        // TODO une fois le bridge Rust lié :
        // let session = try await icloud_auth_login(appleID, password, twoFactorCode, anisetteServerURL)
        throw CertError.rustBridgeNotLinked
    }

    func regenerateCertificateIfNeeded() async throws -> SigningCertificate {
        // 1. apple_dev_apis_list_certificates(session) — lister les certificats existants
        // 2. Si un certificat "iOS Development" existe déjà (Sideloadly/Xcode l'a peut-être
        //    créé) → apple_dev_apis_revoke_certificate(session, certId)
        // 3. Générer un CSR via AltSign.CertificatesManager.generateCSR(...) (Swift, déjà lié)
        // 4. apple_dev_apis_submit_csr(session, csr) → récupère le certificat signé
        // 5. apple_dev_apis_create_provisioning_profile(session, bundleId, certId)
        //    pour chaque app suivie
        throw CertError.rustBridgeNotLinked
    }
}

/// Certificat + profil regénérés, prêts à être passés à ResignManager.
struct SigningCertificate {
    let teamIdentifier: String
    let p12Data: Data
    let profileData: Data
    let expirationDate: Date
}

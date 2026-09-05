import Foundation
import AppDependencies   // package enveloppe (résout le conflit OpenSSL minimuxer/AltSign)

/// Gère le pairing + la connexion loopback via le vrai package Minimuxer.
/// L'intégration se fait par Swift Package Manager, PAS par compilation Rust
/// manuelle : Minimuxer embarque déjà un binaryTarget précompilé (EMProxy.xcframework)
/// distribué via GitHub Releases. Il suffit d'ajouter la dépendance dans Xcode :
///
///   File > Add Package Dependencies… > https://github.com/SideStore/minimuxer.git
///
/// Documenté ici avec les vrais types (MinimuxerAPI, DeviceConnectionMode,
/// MinimuxerError) tels qu'ils existent dans Sources/MinimuxerApi.swift du repo.
final class PairingManager {
    static let shared = PairingManager()

    enum PairingError: Error, LocalizedError {
        case noPairingFileImported
        case startFailed(MinimuxerError)
        case notReady

        var errorDescription: String? {
            switch self {
            case .noPairingFileImported: return "Aucun fichier de pairing importé."
            case .startFailed(let err): return "Échec du démarrage Minimuxer : \(err)"
            case .notReady: return "Minimuxer indique que le device n'est pas prêt."
            }
        }
    }

    private var pairingFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("device_pairing.plist")
    }

    private var mountPath: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DDI")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var hasPairingFile: Bool {
        FileManager.default.fileExists(atPath: pairingFileURL.path)
    }

    /// Import du fichier généré une fois par generate_pairing.py (voir Companion/).
    func importPairingFile(from sourceURL: URL) throws {
        if FileManager.default.fileExists(atPath: pairingFileURL.path) {
            try FileManager.default.removeItem(at: pairingFileURL)
        }
        _ = sourceURL.startAccessingSecurityScopedResource()
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        try FileManager.default.copyItem(at: sourceURL, to: pairingFileURL)
    }

    /// Démarre la session Minimuxer : lit le pairing file, établit la connexion
    /// (VPN loopback ou réseau local selon ce que Minimuxer détecte), monte le DDI
    /// si nécessaire. C'est l'équivalent de brancher l'iPhone en USB sur un Mac,
    /// mais fait depuis l'app elle-même.
    func startLoopbackSession() async throws {
        guard hasPairingFile else { throw PairingError.noPairingFileImported }

        let pairingFileContent = try String(contentsOf: pairingFileURL, encoding: .utf8)

        do {
            try await Minimuxer.shared().core.start(
                pairingFile: pairingFileContent,
                mountPath: mountPath.path
            )
        } catch let error as MinimuxerError {
            throw PairingError.startFailed(error)
        }

        let readyResult = await Minimuxer.shared().core.isReady(withDDIMountCheck: false)
        switch readyResult {
        case .success(true):
            return
        case .success(false):
            throw PairingError.notReady
        case .failure(let err):
            throw PairingError.startFailed(err)
        }
    }

    func stopSession() async throws {
        try await Minimuxer.shared().core.stop()
    }

    func currentConnectionMode() async -> DeviceConnectionMode {
        await Minimuxer.shared().core.getConnectionMode()
    }

    /// À appeler au lancement de l'app pour observer le statut réseau (Wi-Fi/VPN)
    /// que Minimuxer utilise pour décider comment joindre le device.
    func startNetworkObserver() async {
        _ = await Minimuxer.shared().network.start()
    }
}

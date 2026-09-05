import Foundation
import Minimuxer

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

    func importPairingFile(from sourceURL: URL) throws {
        if FileManager.default.fileExists(atPath: pairingFileURL.path) {
            try FileManager.default.removeItem(at: pairingFileURL)
        }
        _ = sourceURL.startAccessingSecurityScopedResource()
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        try FileManager.default.copyItem(at: sourceURL, to: pairingFileURL)
    }

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

    func startNetworkObserver() async {
        _ = await Minimuxer.shared().network.start()
    }
}

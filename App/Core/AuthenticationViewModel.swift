import Foundation
import SideSign
import SwiftUI

/// Gère le flow de connexion Apple ID, y compris le 2FA — qui peut demander
/// plusieurs allers-retours (choix de méthode de livraison du code, puis code
/// lui-même). On fait le pont entre l'API async de SideSign et une UI SwiftUI
/// via une continuation stockée.
@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var appleID: String = ""
    @Published var password: String = ""
    @Published var isAuthenticating: Bool = false
    @Published var errorMessage: String?
    @Published var isAuthenticated: Bool = false

    /// Non-nil quand on attend un code de vérification de l'utilisateur.
    @Published var pendingCodeRequest: TwoFactorRequest?
    @Published var codeInput: String = ""

    private var pendingContinuation: CheckedContinuation<TwoFactorResponse, Error>?

    func login() async {
        errorMessage = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            _ = try await CertificateManager.shared.authenticate(
                appleID: appleID,
                password: password,
                verificationHandler: { [weak self] request in
                    guard let self else { throw CancellationError() }
                    return try await self.handleTwoFactor(request)
                }
            )
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Appelé par SideSign chaque fois qu'il a besoin d'une action de l'utilisateur
    /// pour le 2FA. Certains cas (choix de méthode) sont gérés automatiquement,
    /// d'autres (saisie du code) attendent une vraie interaction UI.
    private func handleTwoFactor(_ request: TwoFactorRequest) async throws -> TwoFactorResponse {
        switch request {
        case .selectDeliveryMethod:
            // Choix automatique : on préfère l'appareil de confiance (le plus simple).
            return .requestTrustedDevice

        case .trustedDevice, .sms, .voice:
            // Il faut vraiment demander le code à l'utilisateur.
            return try await withCheckedThrowingContinuation { continuation in
                self.pendingContinuation = continuation
                self.pendingCodeRequest = request
            }
        }
    }

    /// Appelé par la vue quand l'utilisateur a saisi son code et appuie sur "Valider".
    func submitCode() {
        guard let continuation = pendingContinuation else { return }
        pendingContinuation = nil
        pendingCodeRequest = nil
        let code = codeInput
        codeInput = ""
        continuation.resume(returning: .verificationCode(code))
    }

    func cancelTwoFactor() {
        guard let continuation = pendingContinuation else { return }
        pendingContinuation = nil
        pendingCodeRequest = nil
        continuation.resume(returning: .cancel)
    }
}

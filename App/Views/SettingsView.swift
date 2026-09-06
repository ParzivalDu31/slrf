import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @StateObject private var auth = AuthenticationViewModel()
    @State private var showPairingFileImporter = false
    @State private var pairingImportError: String?
    @State private var hasPairingFile = PairingManager.shared.hasPairingFile

    var body: some View {
        NavigationView {
            Form {
                Section("Connexion Apple ID") {
                    if auth.isAuthenticated {
                        Label("Connecté", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        TextField("Apple ID", text: $auth.appleID)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.emailAddress)
                        SecureField("Mot de passe", text: $auth.password)

                        Button {
                            Task { await auth.login() }
                        } label: {
                            if auth.isAuthenticating {
                                ProgressView()
                            } else {
                                Text("Se connecter")
                            }
                        }
                        .disabled(auth.appleID.isEmpty || auth.password.isEmpty || auth.isAuthenticating)

                        if let error = auth.errorMessage {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }
                }

                Section("Pairing (étape faite une fois sur ordinateur)") {
                    if hasPairingFile {
                        Label("Fichier de pairing importé", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Génère le fichier avec Companion/generate_pairing.py sur ton ordinateur, transfère-le sur l'iPhone, puis importe-le ici.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button(hasPairingFile ? "Remplacer le fichier de pairing" : "Importer le fichier de pairing") {
                        showPairingFileImporter = true
                    }
                    if let error = pairingImportError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Réglages")
            .fileImporter(isPresented: $showPairingFileImporter, allowedContentTypes: [.propertyList, .data]) { result in
                switch result {
                case .success(let url):
                    do {
                        try PairingManager.shared.importPairingFile(from: url)
                        hasPairingFile = true
                        pairingImportError = nil
                    } catch {
                        pairingImportError = error.localizedDescription
                    }
                case .failure(let error):
                    pairingImportError = error.localizedDescription
                }
            }
            .alert(
                "Code de vérification",
                isPresented: Binding(
                    get: { auth.pendingCodeRequest != nil },
                    set: { if !$0 { auth.cancelTwoFactor() } }
                )
            ) {
                TextField("Code reçu", text: $auth.codeInput)
                    .keyboardType(.numberPad)
                Button("Valider") { auth.submitCode() }
                Button("Annuler", role: .cancel) { auth.cancelTwoFactor() }
            } message: {
                Text("Entre le code de vérification envoyé par Apple.")
            }
        }
    }
}

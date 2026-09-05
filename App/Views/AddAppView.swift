import SwiftUI
import UniformTypeIdentifiers

/// Puisqu'il n'existe aucun marqueur fiable "installé via Sideloadly" détectable
/// automatiquement, l'utilisateur ajoute manuellement chaque app à suivre,
/// en fournissant : le bundle ID exact, et idéalement le .ipa source
/// (nécessaire pour le re-signing — voir ResignManager).
struct AddAppView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bundleIdentifier = ""
    @State private var displayName = ""
    @State private var expirationDate = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var showFileImporter = false
    @State private var importedIPAPath: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Identification") {
                    TextField("Nom affiché", text: $displayName)
                    TextField("Bundle Identifier (ex: com.exemple.app)", text: $bundleIdentifier)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                Section("Expiration") {
                    DatePicker("Date d'expiration", selection: $expirationDate, displayedComponents: .date)
                    Text("Trouvable dans les Réglages iOS > Général > VPN et gestion de l'appareil > [ton app]")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Fichier source (.ipa)") {
                    Button(importedIPAPath == nil ? "Importer le .ipa original" : "✓ .ipa importé") {
                        showFileImporter = true
                    }
                    Text("Requis pour pouvoir re-signer l'app plus tard. Sideloadly ne conserve pas ce fichier après installation — retrouve-le là où tu l'avais téléchargé.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajouter une app")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { save() }
                        .disabled(bundleIdentifier.isEmpty || displayName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data]) { result in
                if case .success(let url) = result {
                    importedIPAPath = copyIntoSandbox(url)
                }
            }
        }
    }

    private func copyIntoSandbox(_ url: URL) -> String? {
        let dest = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sources")
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        let target = dest.appendingPathComponent(url.lastPathComponent)
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        try? FileManager.default.copyItem(at: url, to: target)
        return target.path
    }

    private func save() {
        let app = TrackedApp(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            sourceBundlePath: importedIPAPath,
            expirationDate: expirationDate
        )
        AppRegistry.shared.add(app)
        dismiss()
    }
}

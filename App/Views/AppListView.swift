import SwiftUI

struct AppListView: View {
    @ObservedObject var registry = AppRegistry.shared
    @State private var isRefreshing = false
    @State private var showAddSheet = false
    @State private var showSettingsSheet = false
    @State private var lastError: String?

    var body: some View {
        NavigationView {
            List {
                if registry.trackedApps.isEmpty {
                    Text("Aucune app suivie. Ajoute une app installée via Sideloadly avec le bouton +.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(registry.trackedApps) { app in
                        AppRow(app: app)
                    }
                }
            }
            .navigationTitle("Apps Sideloadlyer, allowedContetoolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button { showSettingsSheet = true } label: {
                            Image(systemName: "gearshape")
                        }
                        Button { showAddSheet = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await refreshAll() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddAppView()
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
            }
            .alert("Erreur", isPresented: .constant(lastError != nil), actions: {
                Button("OK") { lastError = nil }
            }, message: {
                Text(lastError ?? "")
            })
        }
    }

    private func refreshAll() async {
        isRefreshing = true
        let results = await RefreshCoordinator.shared.refreshExpiringApps()
        for result in results {
            if case .failure(let app, let error) = result {
                lastError = "\(app.displayName) : \(error.localizedDescription)"
            }
        }
        isRefreshing = false
    }
}

private struct AppRow: View {
    let app: TrackedApp

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(app.displayName).font(.headline)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(app.daysRemaining) j")
                    .font(.subheadline.bold())
                    .foregroundStyle(app.isExpiringSoon ? .red : .primary)
                if let last = app.lastRefreshDate {
                    Text("Refresh: \(last.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

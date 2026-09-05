import SwiftUI

@main
struct SideloadlyRefresherApp: App {
    init() {
        RefreshCoordinator.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            AppListView()
        }
    }
}

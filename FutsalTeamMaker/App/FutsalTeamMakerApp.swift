import SwiftData
import SwiftUI

@main
struct FutsalTeamMakerApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                FolderListView()
            }
        }
        .modelContainer(for: [Player.self, GameEvent.self])
    }
}

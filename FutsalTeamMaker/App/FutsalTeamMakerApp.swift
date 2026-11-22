import SwiftData
import SwiftUI

@main
struct FutsalTeamMakerApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                PlayerListView()
            }
        }
        .modelContainer(for: Player.self)
    }
}

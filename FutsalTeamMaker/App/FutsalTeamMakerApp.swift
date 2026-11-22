import SwiftData
import SwiftUI

@main
struct FutsalTeamMakerApp: App {
    /// UI テストのときは、端末のデータに触れないようメモリ上だけに保存する
    private let isUITest = ProcessInfo.processInfo.arguments.contains("-UITestInMemory")

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                FolderListView()
            }
        }
        .modelContainer(for: [Player.self, GameEvent.self], inMemory: isUITest)
    }
}

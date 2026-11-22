import SwiftData
import SwiftUI

@main
struct FutsalTeamMakerApp: App {
    private let container: ModelContainer

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        // UI テストのときは、端末のデータに触れないようメモリ上だけに保存する
        let isUITest = arguments.contains("-UITestInMemory")
        do {
            container = try ModelContainer(
                for: Player.self, GameEvent.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: isUITest)
            )
        } catch {
            fatalError("データの保存先を用意できませんでした: \(error)")
        }
        if isUITest && arguments.contains("-UITestSeedEvent") {
            Self.seedForUITest(container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                FolderListView()
            }
        }
        .modelContainer(container)
    }

    /// UI テスト用に、12人の選手と全員が入った「テスト大会」を入れる
    @MainActor
    private static func seedForUITest(_ context: ModelContext) {
        let players = Player.samples.map { Player(name: $0.0, skill: $0.1, gender: $0.2) }
        players.forEach { context.insert($0) }
        let event = GameEvent(name: "テスト大会")
        context.insert(event)
        event.add(players)
    }
}

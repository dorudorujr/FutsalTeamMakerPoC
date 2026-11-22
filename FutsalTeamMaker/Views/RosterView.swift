import SwiftData
import SwiftUI

/// すべての大会で共有する選手名簿。
struct RosterView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.createdAt) private var players: [Player]

    @State private var isAddingPlayer = false
    @State private var editingPlayer: Player?
    @State private var deletingPlayer: Player?

    var body: some View {
        List {
            if !players.isEmpty {
                Section {
                    ForEach(players) { player in
                        Button {
                            editingPlayer = player
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.name)
                                        .foregroundStyle(.primary)
                                    Text(player.events.isEmpty ? "どの大会にも入っていません" : "\(player.events.count) 大会")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                SkillStars(skill: player.skill)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("削除", role: .destructive) {
                                deletingPlayer = player
                            }
                        }
                    }
                } header: {
                    Text("\(players.count) 人")
                } footer: {
                    Text("実力を直すと、その選手が入っているすべての大会に反映されます。")
                }
            }
        }
        .overlay {
            if players.isEmpty {
                ContentUnavailableView(
                    "選手がいません",
                    systemImage: "person.2",
                    description: Text("右上の＋から選手と実力を登録してください。")
                )
            }
        }
        .navigationTitle("選手名簿")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingPlayer = true
                } label: {
                    Label("選手を追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingPlayer) {
            PlayerEditView()
        }
        .sheet(item: $editingPlayer) { player in
            PlayerEditView(player: player)
        }
        .confirmationDialog(
            "\(deletingPlayer?.name ?? "")を名簿から削除しますか？",
            isPresented: Binding(
                get: { deletingPlayer != nil },
                set: { if !$0 { deletingPlayer = nil } }
            ),
            titleVisibility: .visible,
            presenting: deletingPlayer
        ) { player in
            Button("削除", role: .destructive) {
                modelContext.delete(player)
            }
        } message: { player in
            Text(player.events.isEmpty
                 ? "この操作は取り消せません。"
                 : "\(player.events.count) 大会のメンバーからも外れます。この操作は取り消せません。")
        }
    }
}

#Preview {
    NavigationStack {
        RosterView()
    }
    .modelContainer(for: [Player.self, GameEvent.self], inMemory: true)
}

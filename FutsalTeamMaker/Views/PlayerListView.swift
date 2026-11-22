import SwiftData
import SwiftUI

/// 選手の一覧。参加する選手にチェックを入れ、チーム数を決めて分ける。
struct PlayerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.createdAt) private var players: [Player]

    @AppStorage("teamCount") private var teamCount = 2
    @State private var editingPlayer: Player?
    @State private var isAddingPlayer = false
    @State private var splitRequest: SplitRequest?

    private var participants: [Player] { players.filter(\.isParticipating) }

    /// 1チーム1人以上になる範囲で、2〜8チームまで選べる
    private var teamCountRange: ClosedRange<Int> {
        2...max(2, min(8, participants.count))
    }

    var body: some View {
        List {
            if !players.isEmpty {
                Section {
                    ForEach(players) { player in
                        PlayerRow(player: player) {
                            editingPlayer = player
                        }
                    }
                    .onDelete(perform: delete)
                } header: {
                    HStack {
                        Text("参加 \(participants.count) / \(players.count) 人")
                        Spacer()
                        Button(participants.count == players.count ? "全員外す" : "全員参加") {
                            toggleAll()
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                }
            }
        }
        .overlay {
            if players.isEmpty {
                ContentUnavailableView {
                    Label("選手がいません", systemImage: "person.3")
                } description: {
                    Text("右上の＋から選手と実力を登録してください。")
                } actions: {
                    Button("サンプルの選手を追加") { addSamples() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !players.isEmpty {
                splitPanel
            }
        }
        .navigationTitle("チーム分け")
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
        .navigationDestination(item: $splitRequest) { request in
            TeamResultView(members: request.members, teamCount: request.teamCount)
        }
        .onChange(of: participants.count) {
            teamCount = min(max(teamCount, teamCountRange.lowerBound), teamCountRange.upperBound)
        }
    }

    private var splitPanel: some View {
        VStack(spacing: 12) {
            Stepper(value: $teamCount, in: teamCountRange) {
                HStack {
                    Text("チーム数")
                    Spacer()
                    Text("\(teamCount) チーム")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                splitRequest = SplitRequest(
                    members: participants.map(\.asMember),
                    teamCount: teamCount
                )
            } label: {
                Text("実力が均等になるように分ける")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(participants.count < teamCount)
        }
        .padding()
        .background(.bar)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(players[index])
        }
    }

    private func toggleAll() {
        let newValue = participants.count != players.count
        for player in players {
            player.isParticipating = newValue
        }
    }

    private func addSamples() {
        for (name, skill) in Player.samples {
            modelContext.insert(Player(name: name, skill: skill))
        }
    }
}

/// 結果画面へ渡す、分けた時点の参加者とチーム数
struct SplitRequest: Hashable {
    let members: [TeamMember]
    let teamCount: Int
}

private struct PlayerRow: View {
    @Bindable var player: Player
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.isParticipating.toggle()
            } label: {
                Image(systemName: player.isParticipating ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(player.isParticipating ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isParticipating ? "参加する" : "参加しない")

            Button(action: onEdit) {
                HStack {
                    Text(player.name)
                        .foregroundStyle(player.isParticipating ? .primary : .secondary)
                    Spacer()
                    SkillStars(skill: player.skill)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        PlayerListView()
    }
    .modelContainer(for: Player.self, inMemory: true)
}

import SwiftData
import SwiftUI

/// 大会のメンバーを選手名簿から選ぶ。ほかの大会のメンバーをまとめて選ぶこともできる。
struct MemberPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Player.createdAt) private var roster: [Player]
    @Query(sort: \GameEvent.createdAt, order: .reverse) private var events: [GameEvent]

    let event: GameEvent

    @State private var selectedIDs: Set<UUID>
    @State private var searchText = ""
    @State private var isAddingPlayer = false

    init(event: GameEvent) {
        self.event = event
        _selectedIDs = State(initialValue: Set(event.members.map(\.id)))
    }

    private var otherEvents: [GameEvent] {
        events.filter { $0.id != event.id && !$0.members.isEmpty }
    }

    private var filteredRoster: [Player] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return roster }
        return roster.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !otherEvents.isEmpty && searchText.isEmpty {
                    Section("ほかの大会のメンバーをまとめて選ぶ") {
                        ForEach(otherEvents) { source in
                            Button {
                                selectedIDs.formUnion(source.members.map(\.id))
                            } label: {
                                HStack {
                                    Label(source.name, systemImage: "folder")
                                    Spacer()
                                    Text("\(source.members.count)人")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        isAddingPlayer = true
                    } label: {
                        Label("新しい選手を名簿に登録", systemImage: "plus")
                    }
                    ForEach(filteredRoster) { player in
                        Button {
                            toggle(player)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedIDs.contains(player.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selectedIDs.contains(player.id) ? Color.accentColor : Color.secondary)
                                Text(player.name)
                                    .foregroundStyle(.primary)
                                GenderBadge(gender: player.gender)
                                Spacer()
                                SkillStars(skill: player.skill)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("選手名簿（\(selectedIDs.count) / \(roster.count) 人を選択中）")
                        Spacer()
                        if !roster.isEmpty {
                            Button(selectedIDs.count == roster.count ? "全員外す" : "全員選ぶ") {
                                if selectedIDs.count == roster.count {
                                    selectedIDs.removeAll()
                                } else {
                                    selectedIDs = Set(roster.map(\.id))
                                }
                            }
                            .font(.caption)
                            .textCase(nil)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "名前で探す")
            .navigationTitle("メンバーを選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", action: save)
                }
            }
            .sheet(isPresented: $isAddingPlayer) {
                PlayerEditView { newPlayer in
                    selectedIDs.insert(newPlayer.id)
                }
            }
        }
    }

    private func toggle(_ player: Player) {
        if selectedIDs.contains(player.id) {
            selectedIDs.remove(player.id)
        } else {
            selectedIDs.insert(player.id)
        }
    }

    private func save() {
        event.setMembers(roster.filter { selectedIDs.contains($0.id) })
        dismiss()
    }
}

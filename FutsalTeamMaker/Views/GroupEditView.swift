import SwiftUI

/// 同じチームにしたいグループ（友達同士など）を作る・直す。グループは大会ごとに持つ。
struct GroupEditView: View {
    @Environment(\.dismiss) private var dismiss

    let event: GameEvent
    let group: EventGroup?

    @State private var selectedIDs: Set<UUID>
    @State private var isRequired: Bool

    init(event: GameEvent, group: EventGroup? = nil) {
        self.event = event
        self.group = group
        _selectedIDs = State(initialValue: Set(group?.memberIDs ?? []))
        _isRequired = State(initialValue: group?.isRequired ?? true)
    }

    /// ほかのグループに入っている選手は選べない
    private var takenIDs: Set<UUID> {
        event.playerIDsInGroups(excluding: group?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("条件", selection: $isRequired) {
                        Text("必ず同じチーム").tag(true)
                        Text("できれば同じチーム").tag(false)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    if isRequired {
                        Text("人数の都合で入りきらないときだけ分かれます。分かれたときは結果に表示します。")
                    } else {
                        Text("女性の人数と実力の差をそろえたうえで、なるべく同じチームにします。")
                    }
                }

                Section {
                    ForEach(event.sortedMembers) { player in
                        let isTaken = takenIDs.contains(player.id)
                        Button {
                            toggle(player)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedIDs.contains(player.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selectedIDs.contains(player.id) ? Color.accentColor : Color.secondary)
                                Text(player.name)
                                    .foregroundStyle(isTaken ? .secondary : .primary)
                                GenderBadge(gender: player.gender)
                                Spacer()
                                if isTaken {
                                    Text("ほかで選択中")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    SkillStars(skill: player.skill)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isTaken)
                    }
                } header: {
                    Text("メンバー（\(selectedIDs.count) 人を選択中・2人以上）")
                }

                if let group {
                    Section {
                        Button("削除", role: .destructive) {
                            event.deleteGroup(id: group.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("同じチームにするメンバー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(selectedIDs.count < 2)
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
        guard selectedIDs.count >= 2 else { return }
        // 名簿に登録した順で持つ
        let ids = event.sortedMembers.map(\.id).filter { selectedIDs.contains($0) }
        event.saveGroup(EventGroup(id: group?.id ?? UUID(), memberIDs: ids, isRequired: isRequired))
        dismiss()
    }
}

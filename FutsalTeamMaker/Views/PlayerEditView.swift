import SwiftData
import SwiftUI

/// 選手の追加・編集。`player` が nil なら追加する。
struct PlayerEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let player: Player?

    @State private var name: String
    @State private var skill: Int
    @FocusState private var nameFocused: Bool

    init(player: Player? = nil) {
        self.player = player
        _name = State(initialValue: player?.name ?? "")
        _skill = State(initialValue: player?.skill ?? 3)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("例: 佐藤", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
                Section {
                    SkillStars(skill: skill, size: .title) { skill = $0 }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                } header: {
                    Text("実力")
                } footer: {
                    Text("1（初心者）〜 5（経験者）。チームの合計が均等になるように使います。")
                }
            }
            .navigationTitle(player == nil ? "選手を追加" : "選手を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear { nameFocused = player == nil }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        if let player {
            player.name = trimmedName
            player.skill = Player.clamp(skill)
        } else {
            modelContext.insert(Player(name: trimmedName, skill: skill))
        }
        dismiss()
    }
}

#Preview {
    PlayerEditView()
        .modelContainer(for: Player.self, inMemory: true)
}

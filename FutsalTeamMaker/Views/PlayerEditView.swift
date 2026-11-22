import SwiftData
import SwiftUI

/// 選手名簿への追加・編集。`player` が nil なら追加する。
struct PlayerEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let player: Player?
    /// 追加したときに呼ぶ（メンバー選択中に登録した選手をそのまま選ぶため）
    let onCreate: ((Player) -> Void)?

    @State private var name: String
    @State private var skill: Int
    @FocusState private var nameFocused: Bool

    init(player: Player? = nil, onCreate: ((Player) -> Void)? = nil) {
        self.player = player
        self.onCreate = onCreate
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
                    if player == nil {
                        Text("1（初心者）〜 5（経験者）。チームの合計が均等になるように使います。")
                    } else {
                        Text("1（初心者）〜 5（経験者）。変更は、この選手が入っているすべての大会に反映されます。")
                    }
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
            let newPlayer = Player(name: trimmedName, skill: skill)
            modelContext.insert(newPlayer)
            onCreate?(newPlayer)
        }
        dismiss()
    }
}

#Preview {
    PlayerEditView()
        .modelContainer(for: [Player.self, GameEvent.self], inMemory: true)
}

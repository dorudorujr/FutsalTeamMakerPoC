import SwiftData
import SwiftUI

/// 大会（フォルダ）を作る・名前を変える。作るときは、ほかの大会のメンバーを引き継げる。
struct FolderEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GameEvent.createdAt, order: .reverse) private var events: [GameEvent]

    let event: GameEvent?

    @State private var name: String
    /// メンバーを引き継ぐ大会。nil なら引き継がない。
    @State private var sourceID: UUID?
    @State private var didSetDefaultSource = false
    @FocusState private var nameFocused: Bool

    init(event: GameEvent? = nil) {
        self.event = event
        _name = State(initialValue: event?.name ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("大会名") {
                    TextField("例: 12月 社会人大会", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
                if event == nil && !events.isEmpty {
                    Section {
                        Picker("メンバーを引き継ぐ", selection: $sourceID) {
                            Text("引き継がない").tag(UUID?.none)
                            ForEach(events) { source in
                                Text("\(source.name)（\(source.members.count)人）")
                                    .tag(UUID?.some(source.id))
                            }
                        }
                    } footer: {
                        Text("選んだ大会のメンバーをそのまま入れます。あとから追加・削除できます。")
                    }
                }
            }
            .navigationTitle(event == nil ? "大会を作る" : "大会名を変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(event == nil ? "作成" : "保存", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                nameFocused = true
                // 前回の大会と同じメンバーで始めることが多いので、一番新しい大会を初期値にする
                if event == nil && !didSetDefaultSource {
                    sourceID = events.first?.id
                    didSetDefaultSource = true
                }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        if let event {
            event.name = trimmedName
        } else {
            let newEvent = GameEvent(name: trimmedName)
            modelContext.insert(newEvent)
            if let source = events.first(where: { $0.id == sourceID }) {
                newEvent.add(source.sortedMembers)
                newEvent.teamCount = source.teamCount
            }
        }
        dismiss()
    }
}

#Preview {
    FolderEditView()
        .modelContainer(for: [Player.self, GameEvent.self], inMemory: true)
}

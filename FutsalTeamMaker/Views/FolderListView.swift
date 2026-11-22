import SwiftData
import SwiftUI

/// 大会（フォルダ）の一覧。アプリの最初の画面。
struct FolderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameEvent.createdAt, order: .reverse) private var events: [GameEvent]

    @State private var isCreating = false

    var body: some View {
        List {
            ForEach(events) { event in
                NavigationLink(value: event) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(event.name, systemImage: "folder")
                        Text("メンバー \(event.members.count) 人・\(event.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .overlay {
            if events.isEmpty {
                ContentUnavailableView {
                    Label("大会がありません", systemImage: "folder.badge.plus")
                } description: {
                    Text("右上のボタンから大会のフォルダを作ってください。選手は名簿に1回登録すれば、ほかの大会でも使えます。")
                }
            }
        }
        .navigationTitle("大会")
        .navigationDestination(for: GameEvent.self) { event in
            FolderDetailView(event: event)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    RosterView()
                } label: {
                    Label("選手名簿", systemImage: "person.2")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreating = true
                } label: {
                    Label("大会を作る", systemImage: "folder.badge.plus")
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            FolderEditView()
        }
    }

    /// 大会を消しても、選手は名簿に残る
    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(events[index])
        }
    }
}

#Preview {
    NavigationStack {
        FolderListView()
    }
    .modelContainer(for: [Player.self, GameEvent.self], inMemory: true)
}

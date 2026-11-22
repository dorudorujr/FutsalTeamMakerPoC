import SwiftData
import SwiftUI

/// 大会（フォルダ）の中身。メンバーのうち今回参加する選手にチェックを入れ、チーム数を決めて分ける。
struct FolderDetailView: View {
    @Bindable var event: GameEvent

    @State private var editingPlayer: Player?
    @State private var isPickingMembers = false
    @State private var isRenaming = false
    @State private var isAddingGroup = false
    @State private var editingGroup: EventGroup?
    @State private var splitRequest: SplitRequest?

    private var members: [Player] { event.sortedMembers }
    private var participants: [Player] { event.participants }

    /// 1チーム1人以上になる範囲で、2〜8チームまで選べる
    private var teamCountRange: ClosedRange<Int> {
        2...max(2, min(8, participants.count))
    }

    var body: some View {
        List {
            if !members.isEmpty {
                Section {
                    ForEach(members) { player in
                        MemberRow(
                            player: player,
                            isParticipating: event.isParticipating(player),
                            onToggle: { event.setParticipating(player, !event.isParticipating(player)) },
                            onEdit: { editingPlayer = player }
                        )
                        // 1回のスワイプだけで外れないよう、ボタンを押したときだけ外す
                        .swipeActions(allowsFullSwipe: false) {
                            Button("外す", role: .destructive) {
                                event.remove(player)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("参加 \(participants.count) / \(members.count) 人")
                        Spacer()
                        Button(participants.count == members.count ? "全員外す" : "全員参加") {
                            toggleAll()
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                } footer: {
                    Text("左にスワイプして「外す」を押すと、この大会のメンバーから外します（選手名簿には残ります）。")
                }
            }
            if members.count >= 2 {
                groupSection
            }
        }
        .overlay {
            if members.isEmpty {
                ContentUnavailableView {
                    Label("メンバーがいません", systemImage: "person.badge.plus")
                } description: {
                    Text("選手名簿やほかの大会からメンバーを追加してください。")
                } actions: {
                    Button("メンバーを追加") { isPickingMembers = true }
                        .buttonStyle(.bordered)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !members.isEmpty {
                splitPanel
            }
        }
        .navigationTitle(event.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPickingMembers = true
                } label: {
                    Label("メンバーを追加", systemImage: "person.badge.plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("大会名を変更") { isRenaming = true }
            }
        }
        .sheet(isPresented: $isPickingMembers) {
            MemberPickerView(event: event)
        }
        .sheet(isPresented: $isRenaming) {
            FolderEditView(event: event)
        }
        .sheet(item: $editingPlayer) { player in
            PlayerEditView(player: player)
        }
        .sheet(isPresented: $isAddingGroup) {
            GroupEditView(event: event)
        }
        .sheet(item: $editingGroup) { group in
            GroupEditView(event: event, group: group)
        }
        .navigationDestination(item: $splitRequest) { request in
            TeamResultView(
                members: request.members,
                teamCount: request.teamCount,
                groups: request.groups,
                saved: request.saved
            ) { result in
                event.lastResult = result
            }
        }
        .onChange(of: participants.count, initial: true) {
            event.teamCount = min(max(event.teamCount, teamCountRange.lowerBound), teamCountRange.upperBound)
        }
    }

    private var splitPanel: some View {
        VStack(spacing: 12) {
            if let lastResult = event.lastResult {
                Button {
                    splitRequest = SplitRequest(saved: lastResult)
                } label: {
                    HStack {
                        Label("前回の結果", systemImage: "clock.arrow.circlepath")
                        Text(lastResult.savedAt.formatted(.dateTime.month().day().hour().minute()))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider()
            }
            Stepper(value: $event.teamCount, in: teamCountRange) {
                HStack {
                    Text("チーム数")
                    Spacer()
                    Text("\(event.teamCount) チーム")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                splitRequest = SplitRequest(
                    members: participants.map(\.asMember),
                    teamCount: event.teamCount,
                    groups: event.memberGroups
                )
            } label: {
                Text("実力が均等になるように分ける")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(participants.count < event.teamCount)
        }
        .padding()
        .background(.bar)
    }

    private var groupSection: some View {
        Section {
            ForEach(event.groups) { group in
                Button {
                    editingGroup = group
                } label: {
                    HStack {
                        Text(event.players(in: group).map(\.name).joined(separator: "・"))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(group.isRequired ? "必ず" : "できれば")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(allowsFullSwipe: false) {
                    Button("削除", role: .destructive) {
                        event.deleteGroup(id: group.id)
                    }
                }
            }
            Button {
                isAddingGroup = true
            } label: {
                Label("追加", systemImage: "plus")
            }
        } header: {
            Text("同じチームにするメンバー")
        } footer: {
            Text("友達同士など、同じチームにしたい選手を選びます。この大会だけで使います。")
        }
    }

    private func toggleAll() {
        let newValue = participants.count != members.count
        for player in members {
            event.setParticipating(player, newValue)
        }
    }
}

/// 結果画面へ渡す、分けた時点の参加者・チーム数・グループ
struct SplitRequest: Hashable {
    let members: [TeamMember]
    let teamCount: Int
    let groups: [MemberGroup]
    /// 保存した結果を開くときに渡す。nil なら新しく分ける。
    var saved: SavedResult?

    init(members: [TeamMember], teamCount: Int, groups: [MemberGroup]) {
        self.members = members
        self.teamCount = teamCount
        self.groups = groups
    }

    /// 保存した結果を開く。分け直すときは、その結果に入っている選手とチーム数を使う。
    init(saved: SavedResult) {
        self.members = saved.members
        self.teamCount = saved.result.teams.count
        self.groups = saved.result.groups
        self.saved = saved
    }
}

private struct MemberRow: View {
    let player: Player
    let isParticipating: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isParticipating ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isParticipating ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isParticipating ? "参加する" : "参加しない")

            Button(action: onEdit) {
                HStack {
                    Text(player.name)
                        .foregroundStyle(isParticipating ? .primary : .secondary)
                    GenderBadge(gender: player.gender)
                    Spacer()
                    SkillStars(skill: player.skill)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

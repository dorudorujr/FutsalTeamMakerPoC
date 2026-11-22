import SwiftUI

/// チーム分けの結果。選手をドラッグして、ほかのチームの選手と入れ替えたり、ほかのチームへ移したりできる。
/// 「分け直す」で同じ参加者をもう一度自動で分ける。
///
/// List の行に付けた dropDestination はドロップを受け取れないため、ScrollView で並べている。
struct TeamResultView: View {
    let members: [TeamMember]
    let teamCount: Int
    var groups: [MemberGroup] = []

    @State private var result: SplitResult?
    /// 自動で分けたあとに手で直したか
    @State private var isEdited = false
    @State private var isConfirmingReshuffle = false
    /// ドラッグ中の選手が上にある選手（入れ替え先）
    @State private var targetedMemberID: UUID?
    /// ドラッグ中の選手が上にあるチーム（移す先）
    @State private var targetedTeamID: Int?

    private var teams: [Team] { result?.teams ?? [] }
    private var hasGender: Bool { members.contains { $0.gender != .unspecified } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                if let brokenGroups = result?.brokenGroups, !brokenGroups.isEmpty {
                    brokenGroupsCard(brokenGroups)
                }
                ForEach(teams) { team in
                    teamCard(team)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("結果")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareText) {
                    Label("共有", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    if isEdited {
                        isConfirmingReshuffle = true
                    } else {
                        withAnimation { split() }
                    }
                } label: {
                    Label("分け直す", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .confirmationDialog(
            "手で直した内容は消えます。自動で分け直しますか？",
            isPresented: $isConfirmingReshuffle,
            titleVisibility: .visible
        ) {
            Button("分け直す", role: .destructive) {
                withAnimation { split() }
            }
        }
        .onAppear {
            if result == nil { split() }
        }
    }

    // MARK: - 表示

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryRow("参加者", "\(members.count) 人")
                .cardBackground()

            VStack(alignment: .leading, spacing: 4) {
                Text("選手を長押ししてドラッグし、別のチームの選手の上で離すと入れ替わります。チームの選手がいないところ（チーム名など）で離すと、そのチームへ移ります。")
                if isEdited {
                    Text("手で直した結果です。「分け直す」を押すと、自動で分け直します。")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func brokenGroupsCard(_ brokenGroups: [MemberGroup]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("同じチームにできなかったメンバー", systemImage: "exclamationmark.triangle")
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
                .padding(.horizontal)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(brokenGroups.enumerated()), id: \.element) { index, group in
                    if index > 0 { Divider() }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(names(of: group))
                        Text(brokenReason(of: group))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
            }
            .cardBackground()
        }
    }

    /// チームのカード。選手の行の上で離すと入れ替え、それ以外のところで離すとこのチームへ移す。
    private func teamCard(_ team: Team) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(team.name)
                    .font(.headline)
                Spacer()
                Text(summary(of: team))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 0) {
                let sortedMembers = team.members.sorted { $0.skill > $1.skill }
                ForEach(Array(sortedMembers.enumerated()), id: \.element.id) { index, member in
                    if index > 0 { Divider().padding(.leading) }
                    memberRow(member, in: team)
                }
                if team.members.isEmpty {
                    Text("ここへ選手をドラッグ")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .cardBackground()
        }
        .padding(8)
        .background(
            targetedTeamID == team.id ? Color.accentColor.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 20)
        )
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            guard let draggedID = draggedMemberID(items) else { return false }
            return move(draggedID, to: team.id)
        } isTargeted: { isTargeted in
            if isTargeted {
                targetedTeamID = team.id
            } else if targetedTeamID == team.id {
                targetedTeamID = nil
            }
        }
        // ドロップを受ける余白のぶん外へ広げ、カードの幅をほかのカードとそろえる
        .padding(.horizontal, -8)
    }

    private func memberRow(_ member: TeamMember, in team: Team) -> some View {
        HStack {
            Text(member.name)
            GenderBadge(gender: member.gender)
            Spacer()
            SkillStars(skill: member.skill)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(targetedMemberID == member.id ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .draggable(member.id.uuidString) {
            // ドラッグ中に指の下に出す表示
            HStack {
                Text(member.name)
                SkillStars(skill: member.skill)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
        }
        .dropDestination(for: String.self) { items, _ in
            guard let draggedID = draggedMemberID(items) else { return false }
            return swap(draggedID, with: member.id)
        } isTargeted: { isTargeted in
            if isTargeted {
                targetedMemberID = member.id
            } else if targetedMemberID == member.id {
                targetedMemberID = nil
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("member.\(member.name)")
        .accessibilityValue(team.name)
    }

    // MARK: - ドラッグ＆ドロップ

    /// ドラッグで運ばれてきた選手の id。この結果にいない選手なら nil。
    private func draggedMemberID(_ items: [String]) -> UUID? {
        guard let text = items.first,
              let id = UUID(uuidString: text),
              result?.teamID(of: id) != nil
        else { return nil }
        return id
    }

    /// 別のチームの選手どうしなら入れ替える。同じチームなら何もしない。
    private func swap(_ draggedID: UUID, with targetID: UUID) -> Bool {
        guard let result, result.teamID(of: draggedID) != result.teamID(of: targetID) else { return false }
        withAnimation {
            self.result?.swap(draggedID, targetID)
            isEdited = true
        }
        return true
    }

    /// ほかのチームへ移す。今いるチームなら何もしない。
    private func move(_ draggedID: UUID, to teamID: Int) -> Bool {
        guard let result, result.teamID(of: draggedID) != teamID else { return false }
        withAnimation {
            self.result?.move(draggedID, toTeam: teamID)
            isEdited = true
        }
        return true
    }

    // MARK: - その他

    private func split() {
        result = TeamBalancer.split(members, teamCount: teamCount, groups: groups)
        isEdited = false
    }

    private func summary(of team: Team) -> String {
        let average = team.averageSkill.formatted(.number.precision(.fractionLength(1)))
        var text = "\(team.members.count)人・合計 \(team.totalSkill)・平均 \(average)"
        if hasGender {
            text += "・女性 \(team.femaleCount)"
        }
        return text
    }

    private func names(of group: MemberGroup) -> String {
        let byID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.name) })
        return group.memberIDs.compactMap { byID[$0] }.joined(separator: "・")
    }

    private func brokenReason(of group: MemberGroup) -> String {
        if isEdited {
            return group.isRequired ? "必ず同じチーム：今のチームでは分かれています" : "できれば同じチーム：今のチームでは分かれています"
        }
        return group.isRequired
            ? "必ず同じチーム：人数の都合で入りきりませんでした"
            : "できれば同じチーム：女性の人数と実力の差を優先しました"
    }

    /// LINE などに貼るためのテキスト。実力は載せない。
    private var shareText: String {
        teams.map { team in
            (["【\(team.name)】"] + team.members.map(\.name)).joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }
}

private extension View {
    /// List の行と同じ見た目の背景
    func cardBackground() -> some View {
        background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        TeamResultView(
            members: Player.samples.map { TeamMember(id: UUID(), name: $0.0, skill: $0.1, gender: $0.2) },
            teamCount: 3
        )
    }
}

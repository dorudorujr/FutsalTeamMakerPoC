import SwiftUI

/// チーム分けの結果。「分け直す」で同じ参加者をもう一度分ける。
struct TeamResultView: View {
    let members: [TeamMember]
    let teamCount: Int
    var groups: [MemberGroup] = []

    @State private var result: SplitResult?

    private var teams: [Team] { result?.teams ?? [] }
    private var hasGender: Bool { members.contains { $0.gender != .unspecified } }

    private func spread(_ values: [Int]) -> Int {
        (values.max() ?? 0) - (values.min() ?? 0)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("参加者", value: "\(members.count) 人")
                LabeledContent("実力の合計の差（最大−最小）", value: "\(spread(teams.map(\.totalSkill)))")
                if hasGender {
                    LabeledContent("女性の人数の差（最大−最小）", value: "\(spread(teams.map(\.femaleCount)))")
                }
            }

            if let brokenGroups = result?.brokenGroups, !brokenGroups.isEmpty {
                Section {
                    ForEach(brokenGroups, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(names(of: group))
                            Text(group.isRequired
                                 ? "必ず同じチーム：人数の都合で入りきりませんでした"
                                 : "できれば同じチーム：女性の人数と実力の差を優先しました")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("同じチームにできなかったメンバー", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .textCase(nil)
                }
            }

            ForEach(teams) { team in
                Section {
                    ForEach(team.members.sorted { $0.skill > $1.skill }) { member in
                        HStack {
                            Text(member.name)
                            GenderBadge(gender: member.gender)
                            Spacer()
                            SkillStars(skill: member.skill)
                        }
                    }
                } header: {
                    HStack {
                        Text(team.name)
                            .font(.headline)
                        Spacer()
                        Text(summary(of: team))
                            .monospacedDigit()
                    }
                    .textCase(nil)
                }
            }
        }
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
                    withAnimation { split() }
                } label: {
                    Label("分け直す", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .onAppear {
            if result == nil { split() }
        }
    }

    private func split() {
        result = TeamBalancer.split(members, teamCount: teamCount, groups: groups)
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

    /// LINE などに貼るためのテキスト。実力は載せない。
    private var shareText: String {
        teams.map { team in
            (["【\(team.name)】"] + team.members.map(\.name)).joined(separator: "\n")
        }
        .joined(separator: "\n\n")
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

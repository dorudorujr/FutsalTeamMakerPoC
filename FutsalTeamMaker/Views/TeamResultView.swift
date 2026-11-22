import SwiftUI

/// チーム分けの結果。「分け直す」で同じ参加者をもう一度分ける。
struct TeamResultView: View {
    let members: [TeamMember]
    let teamCount: Int

    @State private var teams: [Team] = []

    private var spread: Int {
        let totals = teams.map(\.totalSkill)
        return (totals.max() ?? 0) - (totals.min() ?? 0)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("参加者", value: "\(members.count) 人")
                LabeledContent("実力の合計の差（最大−最小）", value: "\(spread)")
            }

            ForEach(teams) { team in
                Section {
                    ForEach(team.members.sorted { $0.skill > $1.skill }) { member in
                        HStack {
                            Text(member.name)
                            Spacer()
                            SkillStars(skill: member.skill)
                        }
                    }
                } header: {
                    HStack {
                        Text(team.name)
                            .font(.headline)
                        Spacer()
                        Text("\(team.members.count)人・合計 \(team.totalSkill)・平均 \(team.averageSkill, format: .number.precision(.fractionLength(1)))")
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
            if teams.isEmpty { split() }
        }
    }

    private func split() {
        teams = TeamBalancer.split(members, teamCount: teamCount)
    }

    /// LINE などに貼るためのテキスト。実力は載せない。
    private var shareText: String {
        teams.map { team in
            ([ "【\(team.name)】" ] + team.members.map(\.name)).joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }
}

#Preview {
    NavigationStack {
        TeamResultView(
            members: Player.samples.map { TeamMember(id: UUID(), name: $0.0, skill: $0.1) },
            teamCount: 3
        )
    }
}

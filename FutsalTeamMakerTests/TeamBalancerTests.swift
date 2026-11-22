import Foundation
import Testing
@testable import FutsalTeamMaker

/// 再現できるテストのための乱数（SplitMix64）
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private func members(_ skills: [Int], females: Set<Int> = []) -> [TeamMember] {
    skills.enumerated().map {
        TeamMember(
            id: UUID(),
            name: "選手\($0.offset)",
            skill: $0.element,
            gender: females.contains($0.offset) ? .female : .male
        )
    }
}

private func spread(_ values: [Int]) -> Int {
    (values.max() ?? 0) - (values.min() ?? 0)
}

private func teamIndex(of id: UUID, in teams: [Team]) -> Int? {
    teams.firstIndex { $0.members.contains { $0.id == id } }
}

private func isTogether(_ ids: [UUID], in teams: [Team]) -> Bool {
    Set(ids.compactMap { teamIndex(of: $0, in: teams) }).count == 1
}

struct TeamBalancerTests {
    // MARK: - 基本

    @Test("全員がちょうど1回ずつどこかのチームに入る")
    func everyoneAssignedOnce() {
        let input = members([5, 4, 4, 3, 3, 3, 2, 2, 1, 5, 2, 3])
        var rng = SeededGenerator(seed: 1)
        let teams = TeamBalancer.split(input, teamCount: 3, using: &rng).teams

        #expect(teams.count == 3)
        let assigned = teams.flatMap(\.members).map(\.id)
        #expect(assigned.count == input.count)
        #expect(Set(assigned) == Set(input.map(\.id)))
    }

    @Test("人数の差は最大1人", arguments: [(10, 2), (11, 2), (13, 3), (17, 4), (5, 5)])
    func sizesDifferByAtMostOne(playerCount: Int, teamCount: Int) {
        let input = members((0..<playerCount).map { $0 % 5 + 1 })
        var rng = SeededGenerator(seed: UInt64(playerCount * 31 + teamCount))
        let sizes = TeamBalancer.split(input, teamCount: teamCount, using: &rng).teams.map(\.members.count)

        #expect(spread(sizes) <= 1)
    }

    @Test("均等に分けられる組み合わせなら合計の差は0になる")
    func perfectSplitFound() {
        // 合計30を2チームで15ずつに分けられる
        let input = members([5, 5, 4, 4, 3, 3, 2, 2, 1, 1])
        for seed in 0..<20 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let teams = TeamBalancer.split(input, teamCount: 2, using: &rng).teams
            #expect(spread(teams.map(\.totalSkill)) == 0)
        }
    }

    @Test("ランダムな入力でも合計の差は最大の実力値以下に収まる")
    func spreadIsSmallForRandomInputs() {
        var inputRng = SeededGenerator(seed: 42)
        for _ in 0..<100 {
            let count = Int.random(in: 6...20, using: &inputRng)
            let teamCount = Int.random(in: 2...4, using: &inputRng)
            let input = members((0..<count).map { _ in Int.random(in: 1...5, using: &inputRng) })
            let teams = TeamBalancer.split(input, teamCount: teamCount, using: &inputRng).teams
            #expect(spread(teams.map(\.totalSkill)) <= 4, "skills=\(input.map(\.skill)) teams=\(teamCount)")
        }
    }

    @Test("分け直すと組み合わせが変わることがある")
    func reshuffleProducesVariety() {
        let input = members([3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
        var rng = SeededGenerator(seed: 7)
        let results = (0..<10).map { _ in
            Set(TeamBalancer.split(input, teamCount: 2, using: &rng).teams[0].members.map(\.id))
        }
        #expect(Set(results).count > 1)
    }

    @Test("参加者がいなければ空のチームを返す")
    func emptyInput() {
        var rng = SeededGenerator(seed: 0)
        let teams = TeamBalancer.split([], teamCount: 2, using: &rng).teams
        #expect(teams.count == 2)
        let allEmpty = teams.allSatisfy { $0.members.isEmpty }
        #expect(allEmpty)
    }

    // MARK: - 女性の人数

    @Test("女性の人数の差は1人以内になる", arguments: [(12, 3, 4), (12, 3, 5), (10, 2, 3), (16, 4, 6)])
    func femalesAreSpread(playerCount: Int, teamCount: Int, femaleCount: Int) {
        // 実力の高い選手を女性にして、実力だけで分けると偏りやすい入力にする
        let skills = (0..<playerCount).map { $0 < femaleCount ? 5 : $0 % 3 + 1 }
        let input = members(skills, females: Set(0..<femaleCount))
        for seed in 0..<10 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let teams = TeamBalancer.split(input, teamCount: teamCount, using: &rng).teams
            #expect(spread(teams.map(\.femaleCount)) <= 1)
        }
    }

    // MARK: - グループ

    @Test("「必ず同じチーム」のグループは同じチームに入る")
    func requiredGroupStaysTogether() {
        let input = members([5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 3, 2])
        let friends = [input[0].id, input[1].id, input[2].id]
        let rivals = [input[8].id, input[9].id]
        let groups = [
            MemberGroup(memberIDs: friends, isRequired: true),
            MemberGroup(memberIDs: rivals, isRequired: true),
        ]
        for seed in 0..<20 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let result = TeamBalancer.split(input, teamCount: 3, groups: groups, using: &rng)
            #expect(isTogether(friends, in: result.teams))
            #expect(isTogether(rivals, in: result.teams))
            #expect(result.brokenGroups.isEmpty)
            #expect(spread(result.teams.map(\.members.count)) <= 1)
        }
    }

    @Test("「必ず同じチーム」は女性の人数よりも優先する")
    func requiredGroupBeatsFemaleBalance() {
        // 女性3人が必ず同じチーム。2チームなので女性の人数の差は3になる
        let input = members([3, 3, 3, 3, 3, 3, 3, 3], females: [0, 1, 2])
        let group = MemberGroup(memberIDs: [input[0].id, input[1].id, input[2].id], isRequired: true)
        var rng = SeededGenerator(seed: 3)
        let result = TeamBalancer.split(input, teamCount: 2, groups: [group], using: &rng)

        #expect(isTogether(group.memberIDs, in: result.teams))
        #expect(spread(result.teams.map(\.femaleCount)) == 3)
    }

    @Test("「できれば同じチーム」は、実力の差を広げずに済むなら同じチームに入る")
    func preferredGroupKeptWhenFree() {
        // 全員同じ実力なので、同じチームにしても実力の差は広がらない
        let input = members([3, 3, 3, 3, 3, 3, 3, 3])
        let group = MemberGroup(memberIDs: [input[0].id, input[1].id], isRequired: false)
        for seed in 0..<10 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let result = TeamBalancer.split(input, teamCount: 2, groups: [group], using: &rng)
            #expect(isTogether(group.memberIDs, in: result.teams))
            #expect(result.brokenGroups.isEmpty)
        }
    }

    @Test("「できれば同じチーム」は実力の差を優先して分かれることがある")
    func preferredGroupYieldsToSkill() {
        // 2人ずつの2チーム。5と5が同じチームだと合計は10対2、分かれれば6対6になる
        let input = members([5, 5, 1, 1])
        let group = MemberGroup(memberIDs: [input[0].id, input[1].id], isRequired: false)
        var rng = SeededGenerator(seed: 1)
        let result = TeamBalancer.split(input, teamCount: 2, groups: [group], using: &rng)

        #expect(spread(result.teams.map(\.totalSkill)) == 0)
        #expect(result.brokenGroups == [group])
    }

    @Test("1チームに入りきらないグループは分かれ、結果で知らせる")
    func oversizedRequiredGroupIsReported() {
        // 1チーム最大3人なのに、4人のグループ
        let input = members([3, 3, 3, 3, 3, 3])
        let group = MemberGroup(memberIDs: input.prefix(4).map(\.id), isRequired: true)
        var rng = SeededGenerator(seed: 5)
        let result = TeamBalancer.split(input, teamCount: 2, groups: [group], using: &rng)

        #expect(result.brokenGroups == [group])
        #expect(result.teams.flatMap(\.members).count == input.count)
        #expect(spread(result.teams.map(\.members.count)) <= 1)
    }

    @Test("不参加の選手を含むグループは、参加している選手だけで扱う")
    func groupsIgnoreAbsentPlayers() {
        let input = members([3, 3, 3, 3])
        let absent = UUID()
        // 参加しているのは1人だけなので、グループとして扱わない
        let group = MemberGroup(memberIDs: [input[0].id, absent], isRequired: true)
        var rng = SeededGenerator(seed: 2)
        let result = TeamBalancer.split(input, teamCount: 2, groups: [group], using: &rng)

        #expect(result.brokenGroups.isEmpty)
        #expect(result.teams.flatMap(\.members).count == 4)
    }
}

struct ManualAssignmentTests {
    private func makeResult() -> (SplitResult, [TeamMember]) {
        let players = (0..<6).map { TeamMember(id: UUID(), name: "選手\($0)", skill: $0 + 1) }
        let result = SplitResult(
            teams: [
                Team(id: 0, members: Array(players[0..<3])),
                Team(id: 1, members: Array(players[3..<6])),
            ],
            groups: [MemberGroup(memberIDs: [players[0].id, players[1].id], isRequired: true)]
        )
        return (result, players)
    }

    @Test("選手をほかのチームへ移せる")
    func moveMember() {
        var (result, players) = makeResult()
        result.move(players[0].id, toTeam: 1)

        #expect(result.teams[0].members.map(\.id) == [players[1].id, players[2].id])
        #expect(result.teams[1].members.count == 4)
        #expect(result.teamID(of: players[0].id) == 1)
    }

    @Test("別のチームの2人を入れ替えられる。人数は変わらない")
    func swapMembers() {
        var (result, players) = makeResult()
        result.swap(players[2].id, players[5].id)

        #expect(result.teamID(of: players[2].id) == 1)
        #expect(result.teamID(of: players[5].id) == 0)
        #expect(result.teams.map(\.members.count) == [3, 3])
        #expect(result.teams[0].totalSkill == 1 + 2 + 6)
    }

    @Test("同じチームの2人の入れ替えと、今いるチームへの移動は何もしない")
    func noOpOperations() {
        var (result, players) = makeResult()
        let before = result.teams
        result.swap(players[0].id, players[1].id)
        result.move(players[0].id, toTeam: 0)
        result.move(UUID(), toTeam: 1)

        #expect(result.teams == before)
    }

    @Test("手で直すと、同じチームにできなかったメンバーも今のチームから求め直す")
    func brokenGroupsFollowManualEdits() {
        var (result, players) = makeResult()
        #expect(result.brokenGroups.isEmpty)

        result.swap(players[1].id, players[4].id)
        #expect(result.brokenGroups.count == 1)

        result.swap(players[0].id, players[3].id)
        #expect(result.brokenGroups.isEmpty)
    }
}

struct RepeatAvoidanceTests {
    private func players(_ skills: [Int]) -> [TeamMember] {
        skills.enumerated().map { TeamMember(id: UUID(), name: "選手\($0.offset)", skill: $0.element) }
    }

    @Test("前回同じチームだった人どうしは、なるべく別のチームになる")
    func avoidsRepeatsWhenBalanceAllows() {
        // 全員同じ実力の8人。前回は前半4人と後半4人のチーム。
        // 4人ずつに分けると、前回のチームから2人ずつ入るのが一番被りが少ない。
        // 2人ずつ入ると、各チームで前回の前半どうし1組・後半どうし1組が被るので、合計4組（そのままなら12組）
        let input = players([3, 3, 3, 3, 3, 3, 3, 3])
        let previous = [input[0..<4].map(\.id), input[4..<8].map(\.id)]
        for seed in 0..<20 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let result = TeamBalancer.split(input, teamCount: 2, previousTeams: previous, using: &rng)
            #expect(result.repeatedPairs.count == 4)
            #expect(result.previousTeams == previous)
        }
    }

    @Test("前回と比べないときは、被りを数えない")
    func noPreviousTeamsMeansNoRepeats() {
        let input = players([3, 3, 3, 3])
        var rng = SeededGenerator(seed: 1)
        let result = TeamBalancer.split(input, teamCount: 2, using: &rng)
        #expect(result.repeatedPairs.isEmpty)
    }

    @Test("実力の差をそろえることを、前回との被りより優先する")
    func skillBalanceBeatsRepeats() {
        // 4,3,2,1 を2人ずつに分けると、合計がそろうのは {4,1} と {3,2} だけ。前回も同じ組み合わせだった
        let input = players([4, 3, 2, 1])
        let previous = [[input[0].id, input[3].id], [input[1].id, input[2].id]]
        var rng = SeededGenerator(seed: 2)
        let result = TeamBalancer.split(input, teamCount: 2, previousTeams: previous, using: &rng)

        #expect(result.teams.map(\.totalSkill).sorted() == [5, 5])
        #expect(result.repeatedPairs.count == 2)
    }

    @Test("同じチームにするメンバーどうしは、前回も同じでも被りに数えない")
    func groupedPairsAreNotCounted() {
        // 3人ずつの2チーム。前回は 0,1,2 と 3,4,5。0と1は「必ず同じチーム」。
        // 0,1 に後半の1人を入れると、もう一方のチームで後半どうしの1組だけが被る（0と1は数えない）
        let input = players([3, 3, 3, 3, 3, 3])
        let previous = [input[0..<3].map(\.id), input[3..<6].map(\.id)]
        let group = MemberGroup(memberIDs: [input[0].id, input[1].id], isRequired: true)
        for seed in 0..<10 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let result = TeamBalancer.split(input, teamCount: 2, groups: [group], previousTeams: previous, using: &rng)

            #expect(result.brokenGroups.isEmpty)
            #expect(result.repeatedPairs.count == 1)
            #expect(!result.repeatedPairs.contains { Set($0) == [input[0].id, input[1].id] })
        }
    }

    @Test("手で直すと、前回との被りも今のチームから求め直す")
    func repeatedPairsFollowManualEdits() {
        let input = players([3, 3, 3, 3])
        var result = SplitResult(
            teams: [Team(id: 0, members: [input[0], input[2]]), Team(id: 1, members: [input[1], input[3]])],
            groups: [],
            previousTeams: [[input[0].id, input[1].id], [input[2].id, input[3].id]]
        )
        #expect(result.repeatedPairs.isEmpty)

        result.swap(input[2].id, input[1].id)
        #expect(result.repeatedPairs.count == 2)
    }

    @Test("前回のチームを持たない、前のバージョンで保存した結果も読める")
    func decodesResultWithoutPreviousTeams() throws {
        let member = TeamMember(id: UUID(), name: "佐藤", skill: 5)
        let json = """
        {"teams":[{"id":0,"members":[{"id":"\(member.id.uuidString)","name":"佐藤","skill":5,"gender":"unspecified"}]}],"groups":[]}
        """
        let decoded = try JSONDecoder().decode(SplitResult.self, from: Data(json.utf8))
        #expect(decoded.teams.first?.members == [member])
        #expect(decoded.previousTeams.isEmpty)
    }
}

struct RepeatedTeammatesTests {
    @Test("前回も一緒だった人を、今のチームごと・前回のチームごとにまとめる")
    func clustersByPreviousTeam() {
        let p = (0..<6).map { TeamMember(id: UUID(), name: "選手\($0)", skill: 3) }
        // 前回: {0,1,2} {3,4,5}
        // 今回: チームA {0,1,3}、チームB {2,4,5}
        let result = SplitResult(
            teams: [Team(id: 0, members: [p[0], p[1], p[3]]), Team(id: 1, members: [p[2], p[4], p[5]])],
            groups: [],
            previousTeams: [[p[0].id, p[1].id, p[2].id], [p[3].id, p[4].id, p[5].id]]
        )

        #expect(result.repeatedTeammates == [
            RepeatedTeammates(teamID: 0, members: [p[0], p[1]]),
            RepeatedTeammates(teamID: 1, members: [p[4], p[5]]),
        ])
        // 1人だけのまとまり（チームAの3、チームBの2）は出さない
        #expect(result.repeatedPairs.count == 2)
    }

    @Test("同じチームにするメンバーの2人だけのまとまりは出さない")
    func groupOnlyClusterIsHidden() {
        let p = (0..<4).map { TeamMember(id: UUID(), name: "選手\($0)", skill: 3) }
        let result = SplitResult(
            teams: [Team(id: 0, members: [p[0], p[1]]), Team(id: 1, members: [p[2], p[3]])],
            groups: [MemberGroup(memberIDs: [p[0].id, p[1].id], isRequired: true)],
            previousTeams: [[p[0].id, p[1].id], [p[2].id, p[3].id]]
        )

        #expect(result.repeatedTeammates == [RepeatedTeammates(teamID: 1, members: [p[2], p[3]])])
    }
}

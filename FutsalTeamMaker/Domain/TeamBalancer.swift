import Foundation

/// 性別。女性の人数をチーム間でそろえるのに使う。
enum Gender: String, Codable, CaseIterable, Sendable {
    case unspecified
    case male
    case female

    var label: String {
        switch self {
        case .unspecified: "未設定"
        case .male: "男性"
        case .female: "女性"
        }
    }
}

/// チーム分けの対象になる選手。画面や保存の形式に依存しない値型。
struct TeamMember: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
    /// 実力（1〜5）
    let skill: Int
    var gender: Gender = .unspecified
}

/// 同じチームにしたい選手のグループ
struct MemberGroup: Codable, Hashable, Sendable {
    let memberIDs: [UUID]
    /// true なら必ず同じチーム、false ならできれば同じチーム
    let isRequired: Bool
}

/// 分けたあとの1チーム。
struct Team: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    var members: [TeamMember]

    var totalSkill: Int { members.reduce(0) { $0 + $1.skill } }
    var averageSkill: Double { members.isEmpty ? 0 : Double(totalSkill) / Double(members.count) }
    var femaleCount: Int { members.filter { $0.gender == .female }.count }

    /// チームA, チームB, ... の表示名
    var name: String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return "チーム\(letters[id % letters.count])"
    }
}

/// チーム分けの結果
struct SplitResult: Codable, Hashable, Sendable {
    var teams: [Team]
    /// 判定に使ったグループ（参加している選手だけを含む）
    let groups: [MemberGroup]
    /// 比べた前回のチーム（チームごとの選手の id）。空なら前回とは比べていない。
    var previousTeams: [[UUID]] = []

    /// 同じチームにできなかったグループ。手で直したあとも、今のチームから求める。
    var brokenGroups: [MemberGroup] {
        groups.filter { group in
            Set(group.memberIDs.compactMap { teamID(of: $0) }).count > 1
        }
    }

    /// 前回も同じチームだった2人の組。手で直したあとも、今のチームから求める。
    var repeatedPairs: [[UUID]] {
        TeamBalancer.Conditions(groups: groups, previousTeams: previousTeams)
            .repeatedPairs(in: teams.map(\.members))
    }

    /// 前回も同じチームで、今回も一緒になった人のまとまり（今のチームごと）。表示に使う。
    var repeatedTeammates: [RepeatedTeammates] {
        let conditions = TeamBalancer.Conditions(groups: groups, previousTeams: previousTeams)
        return teams.flatMap { team in
            conditions.repeatedClusters(in: team.members).map {
                RepeatedTeammates(teamID: team.id, members: $0)
            }
        }
    }

    func teamID(of memberID: UUID) -> Int? {
        teams.first { $0.members.contains { $0.id == memberID } }?.id
    }

    // MARK: - 手で直す

    /// 選手をほかのチームへ移す。人数はそろわなくなることがある。
    mutating func move(_ memberID: UUID, toTeam teamID: Int) {
        guard let from = teams.firstIndex(where: { $0.members.contains { $0.id == memberID } }),
              let to = teams.firstIndex(where: { $0.id == teamID }),
              from != to,
              let index = teams[from].members.firstIndex(where: { $0.id == memberID })
        else { return }
        let member = teams[from].members.remove(at: index)
        teams[to].members.append(member)
    }

    /// 別のチームにいる2人を入れ替える。同じチームの2人なら何もしない。
    mutating func swap(_ firstID: UUID, _ secondID: UUID) {
        guard let firstTeam = teams.firstIndex(where: { $0.members.contains { $0.id == firstID } }),
              let secondTeam = teams.firstIndex(where: { $0.members.contains { $0.id == secondID } }),
              firstTeam != secondTeam,
              let firstIndex = teams[firstTeam].members.firstIndex(where: { $0.id == firstID }),
              let secondIndex = teams[secondTeam].members.firstIndex(where: { $0.id == secondID })
        else { return }
        let first = teams[firstTeam].members[firstIndex]
        teams[firstTeam].members[firstIndex] = teams[secondTeam].members[secondIndex]
        teams[secondTeam].members[secondIndex] = first
    }
}

/// 前回も同じチームで、今回も同じチームになった人のまとまり
struct RepeatedTeammates: Hashable, Sendable {
    /// 今回のチーム
    let teamID: Int
    let members: [TeamMember]
}

extension SplitResult {
    /// 前回のチームを持たない、前のバージョンで保存した結果も読めるようにする
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teams = try container.decode([Team].self, forKey: .teams)
        groups = try container.decode([MemberGroup].self, forKey: .groups)
        previousTeams = try container.decodeIfPresent([[UUID]].self, forKey: .previousTeams) ?? []
    }
}

/// 条件を守りながら、実力の合計がなるべく均等になるように選手を分ける。
///
/// 結果の良さは次の順に比べる（前の条件ほど優先する）。
/// 1. 「必ず同じチーム」のグループが分かれていない
/// 2. 女性の人数の差が小さい
/// 3. 実力の合計の差が小さい
/// 4. 「できれば同じチーム」のグループが分かれていない
/// 5. 前回も同じチームだった2人の組が少ない（`previousTeams` を渡したとき。同じグループの2人は数えない）
/// 6. 実力の合計のばらつき（二乗和）が小さい
///
/// 手順:
/// 1. グループはひとかたまりとして、大きい順・実力の高い順（同じならランダム）に、空きのあるチームへ入れる。
///    入りきらないグループは1人ずつに分けて入れる
/// 2. 2チーム間で選手を1人ずつ入れ替え、結果が良くなるかぎり入れ替えを続ける
/// 3. 1〜2 を何度か試し、一番良かった結果の中からランダムに1つ選ぶ
///
/// 人数はチーム間で最大1人までしか差が出ないようにする。
enum TeamBalancer {
    static func split(
        _ players: [TeamMember],
        teamCount: Int,
        groups: [MemberGroup] = [],
        previousTeams: [[UUID]] = [],
        trials: Int = 40
    ) -> SplitResult {
        var rng = SystemRandomNumberGenerator()
        return split(
            players, teamCount: teamCount, groups: groups, previousTeams: previousTeams,
            trials: trials, using: &rng
        )
    }

    static func split(
        _ players: [TeamMember],
        teamCount: Int,
        groups: [MemberGroup] = [],
        previousTeams: [[UUID]] = [],
        trials: Int = 40,
        using rng: inout some RandomNumberGenerator
    ) -> SplitResult {
        guard teamCount > 0 else { return SplitResult(teams: [], groups: []) }
        guard !players.isEmpty else {
            return SplitResult(teams: (0..<teamCount).map { Team(id: $0, members: []) }, groups: [])
        }

        let activeGroups = normalize(groups, presentIDs: Set(players.map(\.id)))
        let conditions = Conditions(groups: activeGroups, previousTeams: previousTeams)

        var bestCandidates: [[[TeamMember]]] = []
        var bestScore: Score?

        for _ in 0..<max(1, trials) {
            let teams = singleTrial(players, teamCount: teamCount, conditions: conditions, using: &rng)
            let score = Score(teams, conditions: conditions)
            if let current = bestScore, current < score { continue }
            if bestScore != score {
                bestScore = score
                bestCandidates = []
            }
            bestCandidates.append(teams)
        }

        let chosen = bestCandidates.randomElement(using: &rng) ?? []
        return SplitResult(
            teams: chosen.enumerated().map { Team(id: $0.offset, members: $0.element) },
            groups: activeGroups,
            previousTeams: previousTeams
        )
    }

    /// 分けるときの条件（同じチームにするグループと、前回のチーム）
    struct Conditions {
        let groups: [MemberGroup]
        /// 選手の id → 前回のチームの番号
        private let previousTeamIndex: [UUID: Int]
        /// 選手の id → 入っているグループの番号
        private let groupIndex: [UUID: Int]

        init(groups: [MemberGroup], previousTeams: [[UUID]]) {
            self.groups = groups
            var previous: [UUID: Int] = [:]
            for (index, ids) in previousTeams.enumerated() {
                for id in ids { previous[id] = index }
            }
            previousTeamIndex = previous
            var grouped: [UUID: Int] = [:]
            for (index, group) in groups.enumerated() {
                for id in group.memberIDs { grouped[id] = index }
            }
            groupIndex = grouped
        }

        var hasPreviousTeams: Bool { !previousTeamIndex.isEmpty }

        /// 前回も同じチームだった2人の組。同じグループの2人は、わざと同じにしているので数えない。
        func repeatedPairs(in teams: [[TeamMember]]) -> [[UUID]] {
            guard hasPreviousTeams else { return [] }
            var pairs: [[UUID]] = []
            for members in teams {
                for i in members.indices {
                    for j in members.indices where j > i {
                        let a = members[i].id
                        let b = members[j].id
                        guard let previousA = previousTeamIndex[a], previousA == previousTeamIndex[b] else { continue }
                        if let groupA = groupIndex[a], groupA == groupIndex[b] { continue }
                        pairs.append([a, b])
                    }
                }
            }
            return pairs
        }

        /// 1つのチームの中で、前回も同じチームだった人をまとめる。
        /// 被りに数える2人（同じグループの2人以外）がいるまとまりだけを返す。
        func repeatedClusters(in members: [TeamMember]) -> [[TeamMember]] {
            guard hasPreviousTeams else { return [] }
            var clusters: [Int: [TeamMember]] = [:]
            var order: [Int] = []
            for member in members {
                guard let previous = previousTeamIndex[member.id] else { continue }
                if clusters[previous] == nil { order.append(previous) }
                clusters[previous, default: []].append(member)
            }
            return order.compactMap { clusters[$0] }.filter { !repeatedPairs(in: [$0]).isEmpty }
        }

        /// 入れ替えても結果が変わりうる選手か（グループに入っているか、前回のチームと比べる選手か）
        func matters(_ id: UUID) -> Bool {
            groupIndex[id] != nil || previousTeamIndex[id] != nil
        }
    }

    // MARK: - Private

    /// 結果の良さ。小さいほど良い（前の項目ほど優先する）。
    struct Score: Comparable {
        let brokenRequired: Int
        let femaleSpread: Int
        let skillSpread: Int
        let brokenPreferred: Int
        let repeatedPairs: Int
        let sumOfSquares: Int

        init(_ teams: [[TeamMember]], conditions: Conditions) {
            let totals = teams.map { $0.reduce(0) { $0 + $1.skill } }
            let females = teams.map { $0.filter { $0.gender == .female }.count }
            let teamIndex = teamIndexByID(teams)
            let broken = conditions.groups.filter { isBroken($0, teamIndex: teamIndex) }

            brokenRequired = broken.filter(\.isRequired).count
            femaleSpread = (females.max() ?? 0) - (females.min() ?? 0)
            skillSpread = (totals.max() ?? 0) - (totals.min() ?? 0)
            brokenPreferred = broken.filter { !$0.isRequired }.count
            repeatedPairs = conditions.repeatedPairs(in: teams).count
            sumOfSquares = totals.reduce(0) { $0 + $1 * $1 }
        }

        private var key: (Int, Int, Int, Int, Int, Int) {
            (brokenRequired, femaleSpread, skillSpread, brokenPreferred, repeatedPairs, sumOfSquares)
        }

        static func < (lhs: Score, rhs: Score) -> Bool { lhs.key < rhs.key }
        static func == (lhs: Score, rhs: Score) -> Bool { lhs.key == rhs.key }
    }

    /// 参加している選手だけを残し、2人以上のグループにする。1人の選手は最初に出てきたグループにだけ入れる。
    private static func normalize(_ groups: [MemberGroup], presentIDs: Set<UUID>) -> [MemberGroup] {
        var used = Set<UUID>()
        var result: [MemberGroup] = []
        for group in groups {
            let ids = group.memberIDs.filter { presentIDs.contains($0) && !used.contains($0) }
            guard ids.count >= 2 else { continue }
            used.formUnion(ids)
            result.append(MemberGroup(memberIDs: ids, isRequired: group.isRequired))
        }
        return result
    }

    private static func teamIndexByID(_ teams: [[TeamMember]]) -> [UUID: Int] {
        var index: [UUID: Int] = [:]
        for (teamIndex, members) in teams.enumerated() {
            for member in members { index[member.id] = teamIndex }
        }
        return index
    }

    private static func isBroken(_ group: MemberGroup, teamIndex: [UUID: Int]) -> Bool {
        Set(group.memberIDs.compactMap { teamIndex[$0] }).count > 1
    }

    private static func singleTrial(
        _ players: [TeamMember],
        teamCount: Int,
        conditions: Conditions,
        using rng: inout some RandomNumberGenerator
    ) -> [[TeamMember]] {
        let groups = conditions.groups
        // グループはひとかたまり、それ以外の選手は1人ずつのかたまりにする
        let byID = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
        let grouped = Set(groups.flatMap(\.memberIDs))
        var units: [[TeamMember]] = groups.map { $0.memberIDs.compactMap { byID[$0] } }
        units += players.filter { !grouped.contains($0.id) }.map { [$0] }

        // 大きいかたまりから、実力の合計が高い順。同じならランダムな順にする。
        var queue = units
            .map { ($0, UInt64.random(in: .min ... .max, using: &rng)) }
            .sorted { lhs, rhs in
                if lhs.0.count != rhs.0.count { return lhs.0.count > rhs.0.count }
                let lhsSkill = lhs.0.reduce(0) { $0 + $1.skill }
                let rhsSkill = rhs.0.reduce(0) { $0 + $1.skill }
                return lhsSkill != rhsSkill ? lhsSkill > rhsSkill : lhs.1 < rhs.1
            }
            .map(\.0)

        // 人数の上限。余りの人数はランダムに選んだチームに1人ずつ足す。
        let base = players.count / teamCount
        let remainder = players.count % teamCount
        let extraTeams = Set((0..<teamCount).shuffled(using: &rng).prefix(remainder))
        let capacities = (0..<teamCount).map { base + (extraTeams.contains($0) ? 1 : 0) }

        var teams = Array(repeating: [TeamMember](), count: teamCount)
        var totals = Array(repeating: 0, count: teamCount)
        var females = Array(repeating: 0, count: teamCount)

        while !queue.isEmpty {
            let unit = queue.removeFirst()
            let open = (0..<teamCount).filter { teams[$0].count + unit.count <= capacities[$0] }
            guard !open.isEmpty else {
                // どのチームにも入りきらないかたまりは、1人ずつに分けて先に入れる
                queue.insert(contentsOf: unit.map { [$0] }, at: 0)
                continue
            }
            // 女性がいるかたまりは女性の少ないチームを優先し、そのうえで合計が低いチームへ入れる
            let hasFemale = unit.contains { $0.gender == .female }
            func key(_ team: Int) -> (Int, Int) { (hasFemale ? females[team] : 0, totals[team]) }
            let lowest = open.map(key).min { $0 < $1 }!
            let target = open.filter { key($0) == lowest }.randomElement(using: &rng) ?? open[0]

            teams[target].append(contentsOf: unit)
            totals[target] += unit.reduce(0) { $0 + $1.skill }
            females[target] += unit.filter { $0.gender == .female }.count
        }

        improveBySwapping(&teams, conditions: conditions)
        return teams
    }

    /// 2チーム間で1人ずつ入れ替えて、結果が良くなる入れ替えがなくなるまで続ける。
    /// 入れ替えなので各チームの人数は変わらない。
    private static func improveBySwapping(_ teams: inout [[TeamMember]], conditions: Conditions) {
        var current = Score(teams, conditions: conditions)
        var improved = true
        var rounds = 0
        while improved && rounds < 50 {
            improved = false
            rounds += 1
            for a in teams.indices {
                for b in teams.indices where b > a {
                    for i in teams[a].indices {
                        for j in teams[b].indices {
                            let x = teams[a][i]
                            let y = teams[b][j]
                            // 実力も性別も同じで、グループにも前回のチームにも関わらなければ、入れ替えても変わらない
                            if x.skill == y.skill && x.gender == y.gender
                                && !conditions.matters(x.id) && !conditions.matters(y.id) {
                                continue
                            }
                            teams[a][i] = y
                            teams[b][j] = x
                            let score = Score(teams, conditions: conditions)
                            if score < current {
                                current = score
                                improved = true
                            } else {
                                teams[a][i] = x
                                teams[b][j] = y
                            }
                        }
                    }
                }
            }
        }
    }
}

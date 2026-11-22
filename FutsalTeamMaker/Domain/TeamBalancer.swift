import Foundation

/// チーム分けの対象になる選手。画面や保存の形式に依存しない値型。
struct TeamMember: Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
    /// 実力（1〜5）
    let skill: Int
}

/// 分けたあとの1チーム。
struct Team: Identifiable, Hashable, Sendable {
    let id: Int
    var members: [TeamMember]

    var totalSkill: Int { members.reduce(0) { $0 + $1.skill } }
    var averageSkill: Double { members.isEmpty ? 0 : Double(totalSkill) / Double(members.count) }

    /// チームA, チームB, ... の表示名
    var name: String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return "チーム\(letters[id % letters.count])"
    }
}

/// 実力の合計がなるべく均等になるように選手を分ける。
///
/// 1. 実力の高い順（同じ実力の中はランダム）に、空きのあるチームのうち合計が一番低いチームへ入れていく
/// 2. 2チーム間で選手を1人ずつ入れ替え、合計のばらつきが小さくなるかぎり入れ替えを続ける
/// 3. 1〜2 を何度か試し、一番差が小さかった結果の中からランダムに1つ選ぶ
///
/// 人数はチーム間で最大1人までしか差が出ないようにする。
/// 同じ実力の選手の並びをランダムにしているので、分け直すたびに組み合わせが変わりやすい。
enum TeamBalancer {
    static func split(
        _ players: [TeamMember],
        teamCount: Int,
        trials: Int = 40
    ) -> [Team] {
        var rng = SystemRandomNumberGenerator()
        return split(players, teamCount: teamCount, trials: trials, using: &rng)
    }

    static func split(
        _ players: [TeamMember],
        teamCount: Int,
        trials: Int = 40,
        using rng: inout some RandomNumberGenerator
    ) -> [Team] {
        guard teamCount > 0 else { return [] }
        guard !players.isEmpty else {
            return (0..<teamCount).map { Team(id: $0, members: []) }
        }

        var bestCandidates: [[[TeamMember]]] = []
        var bestScore: Score?

        for _ in 0..<max(1, trials) {
            let groups = singleTrial(players, teamCount: teamCount, using: &rng)
            let score = Score(groups)
            if let current = bestScore {
                if score < current {
                    bestScore = score
                    bestCandidates = [groups]
                } else if score == current {
                    bestCandidates.append(groups)
                }
            } else {
                bestScore = score
                bestCandidates = [groups]
            }
        }

        let chosen = bestCandidates.randomElement(using: &rng) ?? []
        return chosen.enumerated().map { Team(id: $0.offset, members: $0.element) }
    }

    // MARK: - Private

    /// 結果の良さ。差（最大−最小）が小さいほど良く、同じなら合計の二乗和（ばらつき）が小さいほど良い。
    struct Score: Comparable {
        let spread: Int
        let sumOfSquares: Int

        init(_ groups: [[TeamMember]]) {
            let totals = groups.map { $0.reduce(0) { $0 + $1.skill } }
            spread = (totals.max() ?? 0) - (totals.min() ?? 0)
            sumOfSquares = totals.reduce(0) { $0 + $1 * $1 }
        }

        static func < (lhs: Score, rhs: Score) -> Bool {
            (lhs.spread, lhs.sumOfSquares) < (rhs.spread, rhs.sumOfSquares)
        }
    }

    private static func singleTrial(
        _ players: [TeamMember],
        teamCount: Int,
        using rng: inout some RandomNumberGenerator
    ) -> [[TeamMember]] {
        // 実力の高い順。同じ実力の中はランダムな順にする。
        let ordered = players
            .map { ($0, UInt64.random(in: .min ... .max, using: &rng)) }
            .sorted { lhs, rhs in
                lhs.0.skill != rhs.0.skill ? lhs.0.skill > rhs.0.skill : lhs.1 < rhs.1
            }
            .map(\.0)

        // 人数の上限。余りの人数はランダムに選んだチームに1人ずつ足す。
        let base = players.count / teamCount
        let remainder = players.count % teamCount
        let extraTeams = Set((0..<teamCount).shuffled(using: &rng).prefix(remainder))
        let capacities = (0..<teamCount).map { base + (extraTeams.contains($0) ? 1 : 0) }

        var groups = Array(repeating: [TeamMember](), count: teamCount)
        var totals = Array(repeating: 0, count: teamCount)

        for player in ordered {
            let open = (0..<teamCount).filter { groups[$0].count < capacities[$0] }
            let lowest = open.map { totals[$0] }.min() ?? 0
            let target = open.filter { totals[$0] == lowest }.randomElement(using: &rng) ?? open[0]
            groups[target].append(player)
            totals[target] += player.skill
        }

        improveBySwapping(&groups, totals: &totals)
        return groups
    }

    /// 2チーム間で1人ずつ入れ替えて、合計の二乗和が小さくなる入れ替えがなくなるまで続ける。
    /// 入れ替えなので各チームの人数は変わらない。
    private static func improveBySwapping(_ groups: inout [[TeamMember]], totals: inout [Int]) {
        var improved = true
        var rounds = 0
        while improved && rounds < 100 {
            improved = false
            rounds += 1
            for a in groups.indices {
                for b in groups.indices where b > a {
                    for i in groups[a].indices {
                        for j in groups[b].indices {
                            let diff = groups[a][i].skill - groups[b][j].skill
                            guard diff != 0 else { continue }
                            let newA = totals[a] - diff
                            let newB = totals[b] + diff
                            let before = totals[a] * totals[a] + totals[b] * totals[b]
                            let after = newA * newA + newB * newB
                            if after < before {
                                let tmp = groups[a][i]
                                groups[a][i] = groups[b][j]
                                groups[b][j] = tmp
                                totals[a] = newA
                                totals[b] = newB
                                improved = true
                            }
                        }
                    }
                }
            }
        }
    }
}

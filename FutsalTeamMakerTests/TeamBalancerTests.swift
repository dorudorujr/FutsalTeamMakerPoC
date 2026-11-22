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

private func members(_ skills: [Int]) -> [TeamMember] {
    skills.enumerated().map { TeamMember(id: UUID(), name: "選手\($0.offset)", skill: $0.element) }
}

private func spread(_ teams: [Team]) -> Int {
    let totals = teams.map(\.totalSkill)
    return (totals.max() ?? 0) - (totals.min() ?? 0)
}

struct TeamBalancerTests {
    @Test("全員がちょうど1回ずつどこかのチームに入る")
    func everyoneAssignedOnce() {
        let input = members([5, 4, 4, 3, 3, 3, 2, 2, 1, 5, 2, 3])
        var rng = SeededGenerator(seed: 1)
        let teams = TeamBalancer.split(input, teamCount: 3, using: &rng)

        #expect(teams.count == 3)
        let assigned = teams.flatMap(\.members).map(\.id)
        #expect(assigned.count == input.count)
        #expect(Set(assigned) == Set(input.map(\.id)))
    }

    @Test("人数の差は最大1人", arguments: [(10, 2), (11, 2), (13, 3), (17, 4), (5, 5)])
    func sizesDifferByAtMostOne(playerCount: Int, teamCount: Int) {
        let input = members((0..<playerCount).map { $0 % 5 + 1 })
        var rng = SeededGenerator(seed: UInt64(playerCount * 31 + teamCount))
        let sizes = TeamBalancer.split(input, teamCount: teamCount, using: &rng).map(\.members.count)

        #expect(sizes.max()! - sizes.min()! <= 1)
    }

    @Test("均等に分けられる組み合わせなら合計の差は0になる")
    func perfectSplitFound() {
        // 合計30を2チームで15ずつに分けられる
        let input = members([5, 5, 4, 4, 3, 3, 2, 2, 1, 1])
        for seed in 0..<20 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let teams = TeamBalancer.split(input, teamCount: 2, using: &rng)
            #expect(spread(teams) == 0)
        }
    }

    @Test("ランダムな入力でも合計の差は最大の実力値以下に収まる")
    func spreadIsSmallForRandomInputs() {
        var inputRng = SeededGenerator(seed: 42)
        for _ in 0..<100 {
            let count = Int.random(in: 6...20, using: &inputRng)
            let teamCount = Int.random(in: 2...4, using: &inputRng)
            let input = members((0..<count).map { _ in Int.random(in: 1...5, using: &inputRng) })
            let teams = TeamBalancer.split(input, teamCount: teamCount, using: &inputRng)
            #expect(spread(teams) <= 4, "skills=\(input.map(\.skill)) teams=\(teamCount)")
        }
    }

    @Test("分け直すと組み合わせが変わることがある")
    func reshuffleProducesVariety() {
        let input = members([3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
        var rng = SeededGenerator(seed: 7)
        let results = (0..<10).map { _ in
            Set(TeamBalancer.split(input, teamCount: 2, using: &rng)[0].members.map(\.id))
        }
        #expect(Set(results).count > 1)
    }

    @Test("参加者がいなければ空のチームを返す")
    func emptyInput() {
        var rng = SeededGenerator(seed: 0)
        let teams = TeamBalancer.split([], teamCount: 2, using: &rng)
        #expect(teams.count == 2)
        let allEmpty = teams.allSatisfy { $0.members.isEmpty }
        #expect(allEmpty)
    }
}

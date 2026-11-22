import Foundation
import SwiftData
import Testing
@testable import FutsalTeamMaker

@MainActor
struct GameEventTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainer(
            for: Player.self, GameEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    private func makePlayers(_ names: [String]) -> [Player] {
        names.map {
            let player = Player(name: $0, skill: 3)
            context.insert(player)
            return player
        }
    }

    @Test("同じ選手を2回追加しても1人のまま")
    func addSkipsDuplicates() {
        let players = makePlayers(["佐藤", "鈴木"])
        let event = GameEvent(name: "A大会")
        context.insert(event)

        event.add(players)
        event.add([players[0]])

        #expect(event.members.count == 2)
    }

    @Test("ほかの大会のメンバーを引き継ぐと、同じ選手を共有する")
    func inheritMembersSharesPlayers() throws {
        let players = makePlayers(["佐藤", "鈴木", "田中"])
        let a = GameEvent(name: "A大会")
        let b = GameEvent(name: "B大会")
        context.insert(a)
        context.insert(b)
        a.add(players)

        b.add(a.sortedMembers)
        players[1].skill = 5
        try context.save()

        #expect(Set(b.members.map(\.id)) == Set(players.map(\.id)))
        #expect(b.members.first { $0.name == "鈴木" }?.skill == 5)
        #expect(players[0].events.count == 2)
    }

    @Test("不参加にした選手はチーム分けの対象から外れる")
    func absentPlayersAreExcluded() {
        let players = makePlayers(["佐藤", "鈴木", "田中"])
        let event = GameEvent(name: "A大会")
        context.insert(event)
        event.add(players)

        event.setParticipating(players[1], false)
        #expect(event.participants.map(\.name) == ["佐藤", "田中"])

        event.setParticipating(players[1], true)
        #expect(event.participants.count == 3)
    }

    @Test("不参加の選手は、ほかの大会では参加のまま")
    func absenceIsPerEvent() {
        let players = makePlayers(["佐藤", "鈴木"])
        let a = GameEvent(name: "A大会")
        let b = GameEvent(name: "B大会")
        context.insert(a)
        context.insert(b)
        a.add(players)
        b.add(players)

        a.setParticipating(players[0], false)

        #expect(a.participants.count == 1)
        #expect(b.participants.count == 2)
    }

    @Test("メンバーから外すと不参加の記録も消える")
    func removingMemberClearsAbsence() {
        let players = makePlayers(["佐藤", "鈴木"])
        let event = GameEvent(name: "A大会")
        context.insert(event)
        event.add(players)
        event.setParticipating(players[0], false)

        event.remove(players[0])
        #expect(event.members.map(\.name) == ["鈴木"])
        #expect(event.absentPlayerIDs.isEmpty)

        event.setParticipating(players[1], false)
        event.setMembers([])
        #expect(event.absentPlayerIDs.isEmpty)
    }

    @Test("グループは大会ごとに保存され、メンバーから外すとグループからも外れる")
    func groupsArePerEventAndPruned() throws {
        let players = makePlayers(["佐藤", "鈴木", "田中"])
        let a = GameEvent(name: "A大会")
        let b = GameEvent(name: "B大会")
        context.insert(a)
        context.insert(b)
        a.add(players)
        b.add(players)

        let group = EventGroup(memberIDs: players.map(\.id), isRequired: false)
        a.saveGroup(group)
        try context.save()

        #expect(a.groups == [group])
        #expect(b.groups.isEmpty)
        #expect(a.playerIDsInGroups(excluding: nil) == Set(players.map(\.id)))
        #expect(a.playerIDsInGroups(excluding: group.id).isEmpty)

        // 3人 → 2人になってもグループは残る
        a.remove(players[0])
        #expect(a.groups.first?.memberIDs == [players[1].id, players[2].id])

        // 2人 → 1人になるとグループは消える
        a.remove(players[1])
        #expect(a.groups.isEmpty)
    }

    @Test("名簿から選手を消すと、大会のメンバーからも外れる")
    func deletingPlayerRemovesFromEvents() throws {
        let players = makePlayers(["佐藤", "鈴木"])
        let event = GameEvent(name: "A大会")
        context.insert(event)
        event.add(players)
        try context.save()

        context.delete(players[0])
        try context.save()

        #expect(event.members.map(\.name) == ["鈴木"])
    }

    @Test("大会を消しても選手は名簿に残る")
    func deletingEventKeepsPlayers() throws {
        let players = makePlayers(["佐藤", "鈴木"])
        let event = GameEvent(name: "A大会")
        context.insert(event)
        event.add(players)
        try context.save()

        context.delete(event)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Player>())
        #expect(remaining.count == 2)
    }
}

import Foundation
import SwiftData

/// 大会・イベントごとのフォルダ。選手名簿から選んだメンバーを持つ。
@Model
final class GameEvent {
    var id: UUID
    var name: String
    var createdAt: Date
    /// 最後に選んだチーム数
    var teamCount: Int

    /// この大会のメンバー（選手名簿の選手を参照する）
    var members: [Player] = []
    /// メンバーのうち、今回は参加しない選手
    var absentPlayerIDs: [UUID] = []

    init(name: String, teamCount: Int = 2) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.teamCount = teamCount
    }

    /// 名簿に登録した順のメンバー
    var sortedMembers: [Player] {
        members.sorted { $0.createdAt < $1.createdAt }
    }

    /// 今回参加するメンバー
    var participants: [Player] {
        sortedMembers.filter { isParticipating($0) }
    }

    func isParticipating(_ player: Player) -> Bool {
        !absentPlayerIDs.contains(player.id)
    }

    func setParticipating(_ player: Player, _ participating: Bool) {
        absentPlayerIDs.removeAll { $0 == player.id }
        if !participating {
            absentPlayerIDs.append(player.id)
        }
    }

    /// まだ入っていない選手だけを追加する
    func add(_ players: [Player]) {
        let existing = Set(members.map(\.id))
        members.append(contentsOf: players.filter { !existing.contains($0.id) })
    }

    /// メンバーを入れ替える。外した選手の「不参加」の記録も消す。
    func setMembers(_ players: [Player]) {
        members = players
        let ids = Set(players.map(\.id))
        absentPlayerIDs.removeAll { !ids.contains($0) }
    }

    func remove(_ player: Player) {
        members.removeAll { $0.id == player.id }
        absentPlayerIDs.removeAll { $0 == player.id }
    }
}

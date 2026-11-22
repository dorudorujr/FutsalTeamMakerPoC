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
    /// この大会で同じチームにしたい選手のグループ（友達同士など）
    var groups: [EventGroup] = []
    /// 最後に分けた結果（`SavedResult` を JSON にしたもの）。入れ子の構造をそのまま保存せず、まとめて1つのデータにしている。
    var lastResultData: Data?
    /// 分けるとき、前回の結果で同じチームだった人をなるべく別のチームにするか
    var avoidsRepeatingTeammates: Bool = true

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

    /// メンバーを入れ替える。外した選手の「不参加」の記録とグループからも消す。
    func setMembers(_ players: [Player]) {
        members = players
        pruneRemovedMembers()
    }

    func remove(_ player: Player) {
        members.removeAll { $0.id == player.id }
        pruneRemovedMembers()
    }

    // MARK: - 最後に分けた結果

    /// 最後に確定した結果（大会の「前回の結果」）。結果の画面で「確定」を押したときに上書きする。
    var lastResult: SavedResult? {
        get { lastResultData.flatMap { try? JSONDecoder().decode(SavedResult.self, from: $0) } }
        set { lastResultData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    // MARK: - グループ

    /// グループを追加する。同じ id のグループがあれば置き換える。
    func saveGroup(_ group: EventGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
    }

    func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
    }

    /// ほかのグループに入っている選手。1人の選手は1つのグループにだけ入れる。
    func playerIDsInGroups(excluding groupID: UUID?) -> Set<UUID> {
        Set(groups.filter { $0.id != groupID }.flatMap(\.memberIDs))
    }

    /// グループのメンバー（名簿に登録した順）
    func players(in group: EventGroup) -> [Player] {
        sortedMembers.filter { group.memberIDs.contains($0.id) }
    }

    /// チーム分けに渡すグループ
    var memberGroups: [MemberGroup] {
        groups.map { MemberGroup(memberIDs: $0.memberIDs, isRequired: $0.isRequired) }
    }

    /// メンバーから外れた選手を、不参加の記録とグループから消す。2人未満になったグループは消す。
    private func pruneRemovedMembers() {
        let ids = Set(members.map(\.id))
        absentPlayerIDs.removeAll { !ids.contains($0) }
        groups = groups.compactMap { group in
            var group = group
            group.memberIDs.removeAll { !ids.contains($0) }
            return group.memberIDs.count >= 2 ? group : nil
        }
    }
}

/// 保存しておく結果。分けた時点の選手（名前・実力・性別）をそのまま残す。
struct SavedResult: Codable, Hashable {
    var result: SplitResult
    /// 自動で分けたあとに手で直したか
    var isEdited: Bool
    var savedAt: Date

    /// 結果に入っている選手（チームの順）
    var members: [TeamMember] { result.teams.flatMap(\.members) }
}

/// 同じチームにしたい選手のグループ
struct EventGroup: Codable, Hashable, Identifiable {
    var id = UUID()
    var memberIDs: [UUID]
    /// true なら必ず同じチーム、false ならできれば同じチーム
    var isRequired: Bool
}

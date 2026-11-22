import Foundation
import SwiftData

/// 選手名簿に登録する選手。端末内（SwiftData）にだけ保存する。
/// 同じ選手を複数の大会（フォルダ）で使い回すので、実力を直すとすべての大会に反映される。
@Model
final class Player {
    var id: UUID
    var name: String
    /// 実力（1〜5）
    var skill: Int
    var createdAt: Date

    /// この選手が入っている大会。選手を名簿から消すと、各大会のメンバーからも外れる。
    @Relationship(inverse: \GameEvent.members)
    var events: [GameEvent] = []

    init(name: String, skill: Int) {
        self.id = UUID()
        self.name = name
        self.skill = Player.clamp(skill)
        self.createdAt = .now
    }

    static let skillRange = 1...5

    static func clamp(_ skill: Int) -> Int {
        min(max(skill, skillRange.lowerBound), skillRange.upperBound)
    }

    var asMember: TeamMember {
        TeamMember(id: id, name: name, skill: skill)
    }
}

extension Player {
    /// 動作確認用のサンプル選手
    static let samples: [(String, Int)] = [
        ("佐藤", 5), ("鈴木", 4), ("高橋", 4), ("田中", 3), ("伊藤", 3),
        ("渡辺", 3), ("山本", 2), ("中村", 2), ("小林", 1), ("加藤", 5),
        ("吉田", 2), ("山田", 3),
    ]
}

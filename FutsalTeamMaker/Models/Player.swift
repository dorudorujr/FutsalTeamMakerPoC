import Foundation
import SwiftData

/// 主催者が登録しておく選手。端末内（SwiftData）にだけ保存する。
@Model
final class Player {
    var id: UUID
    var name: String
    /// 実力（1〜5）
    var skill: Int
    /// 今回のイベントに参加するか
    var isParticipating: Bool
    var createdAt: Date

    init(name: String, skill: Int, isParticipating: Bool = true) {
        self.id = UUID()
        self.name = name
        self.skill = Player.clamp(skill)
        self.isParticipating = isParticipating
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

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
    /// 性別（`Gender` の rawValue）。女性の人数をチーム間でそろえるのに使う。
    var genderRaw: String = Gender.unspecified.rawValue
    var createdAt: Date

    /// この選手が入っている大会。選手を名簿から消すと、各大会のメンバーからも外れる。
    @Relationship(inverse: \GameEvent.members)
    var events: [GameEvent] = []

    init(name: String, skill: Int, gender: Gender = .unspecified) {
        self.id = UUID()
        self.name = name
        self.skill = Player.clamp(skill)
        self.genderRaw = gender.rawValue
        self.createdAt = .now
    }

    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .unspecified }
        set { genderRaw = newValue.rawValue }
    }

    static let skillRange = 1...5

    static func clamp(_ skill: Int) -> Int {
        min(max(skill, skillRange.lowerBound), skillRange.upperBound)
    }

    var asMember: TeamMember {
        TeamMember(id: id, name: name, skill: skill, gender: gender)
    }
}

extension Player {
    /// プレビューと UI テストで使う選手（アプリの画面からは登録しない）
    static let samples: [(String, Int, Gender)] = [
        ("佐藤", 5, .male), ("鈴木", 4, .male), ("高橋", 4, .male), ("田中", 3, .male),
        ("伊藤", 3, .female), ("渡辺", 3, .male), ("山本", 2, .male), ("中村", 2, .female),
        ("小林", 1, .female), ("加藤", 5, .male), ("吉田", 2, .female), ("山田", 3, .male),
    ]
}

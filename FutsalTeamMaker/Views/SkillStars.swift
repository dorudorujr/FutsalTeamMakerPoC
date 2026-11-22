import SwiftUI

/// 実力を星で表示する。`onSelect` を渡すとタップで変えられる。
struct SkillStars: View {
    let skill: Int
    var size: Font = .caption
    var onSelect: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Player.skillRange, id: \.self) { value in
                let image = Image(systemName: value <= skill ? "star.fill" : "star")
                    .foregroundStyle(value <= skill ? Color.orange : Color.secondary.opacity(0.4))
                if let onSelect {
                    Button {
                        onSelect(value)
                    } label: {
                        image.font(size)
                    }
                    .buttonStyle(.plain)
                } else {
                    image.font(size)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("実力 \(skill)")
    }
}

#Preview {
    VStack {
        SkillStars(skill: 3)
        SkillStars(skill: 5, size: .title2) { _ in }
    }
}

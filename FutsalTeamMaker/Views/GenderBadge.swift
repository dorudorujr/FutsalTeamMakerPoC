import SwiftUI

/// 性別の小さな表示。未設定なら何も表示しない。
struct GenderBadge: View {
    let gender: Gender

    var body: some View {
        switch gender {
        case .unspecified:
            EmptyView()
        case .male, .female:
            Text(gender.label)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .foregroundStyle(gender == .female ? Color.pink : Color.blue)
                .background(
                    (gender == .female ? Color.pink : Color.blue).opacity(0.12),
                    in: Capsule()
                )
        }
    }
}

#Preview {
    HStack {
        GenderBadge(gender: .female)
        GenderBadge(gender: .male)
        GenderBadge(gender: .unspecified)
    }
}

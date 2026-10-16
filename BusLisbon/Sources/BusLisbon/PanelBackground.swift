import SwiftUI

struct PanelBackground: View {
    static let cornerRadius: CGFloat = 28

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: Self.cornerRadius,
            topTrailingRadius: Self.cornerRadius,
            style: .continuous
        )

        shape
            .fill(Theme.panel)
            .overlay(alignment: .top) {
                LinearGradient(colors: [Color.white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.cornerRadius)
                    .clipShape(shape)
            }
            .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 18, y: -6)
    }
}

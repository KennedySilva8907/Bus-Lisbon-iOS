import SwiftUI

struct RoundButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.yellow)
                .frame(width: 48, height: 48)
                .background(Theme.ink.opacity(0.9), in: Circle())
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        }
        .accessibilityLabel(label)
    }
}

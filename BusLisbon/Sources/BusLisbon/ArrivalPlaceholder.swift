import SwiftUI

struct ArrivalPlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sweepSeconds = 1.4

    var body: some View {
        rows
            .overlay {
                if !reduceMotion {
                    shine.mask(rows)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("A carregar chegadas")
    }

    private var rows: some View {
        VStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { _ in
                row
            }
        }
    }

    private var row: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .frame(width: 56, height: 32)
            VStack(alignment: .leading, spacing: 6) {
                Capsule().frame(width: 150, height: 10)
                Capsule().frame(width: 90, height: 8)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Capsule().frame(width: 38, height: 12)
                Capsule().frame(width: 28, height: 8)
            }
        }
        .foregroundStyle(Color.primary.opacity(0.08))
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private var shine: some View {
        TimelineView(.animation) { context in
            let progress = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: sweepSeconds) / sweepSeconds

            GeometryReader { proxy in
                let band = proxy.size.width * 0.5
                LinearGradient(colors: [.clear, Color.white.opacity(0.14), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: band)
                    .offset(x: (proxy.size.width + band) * progress - band)
            }
        }
    }
}

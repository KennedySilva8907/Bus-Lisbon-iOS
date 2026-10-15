import SwiftUI
import UIKit
import BusLisbonCore

struct SplashScreen: View {
    let stopsReady: Bool
    let onFinished: () -> Void

    @State private var start = Date()
    @State private var leaving = false

    @MainActor private static let hero: UIImage? = Bundle.module
        .url(forResource: "splash-hero", withExtension: "jpg")
        .flatMap { UIImage(contentsOfFile: $0.path) }

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(start)
            artwork(
                fraction: leaving ? 1 : splashFraction(elapsed: elapsed),
                percent: leaving ? 100 : splashProgress(elapsed: elapsed)
            )
        }
        .opacity(leaving ? 0 : 1)
        .animation(.easeOut(duration: 0.5), value: leaving)
        .task(id: stopsReady) { await waitToLeave() }
    }

    private func waitToLeave() async {
        while !Task.isCancelled {
            if splashCanLeave(elapsed: Date().timeIntervalSince(start), stopsReady: stopsReady) {
                leaving = true
                try? await Task.sleep(for: .milliseconds(500))
                onFinished()
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    private func artwork(fraction: Double, percent: Int) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                Theme.yellow
                if let hero = Self.hero {
                    Color.clear
                        .overlay { Image(uiImage: hero).resizable().scaledToFill() }
                        .clipped()
                }
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.78), location: 0.7),
                        .init(color: .black, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geometry.size.height * 0.38)
                .frame(maxHeight: .infinity, alignment: .bottom)
                caption(fraction: fraction, percent: percent)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 48)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A carregar Bus Lisbon")
    }

    private func caption(fraction: Double, percent: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: -10) {
                Text("BUS")
                Text("LISBON")
            }
            .font(.system(size: 64, weight: .black))
            .tracking(-2.5)
            .foregroundStyle(.white)

            Text("38.7223° N · 9.1393° W")
                .font(.system(size: 12, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Theme.yellow)
                .padding(.top, 10)

            HStack(spacing: 12) {
                bar(fraction: fraction)
                Text("\(percent)%")
                    .font(.system(size: 13, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(minWidth: 40, alignment: .trailing)
            }
            .padding(.top, 20)
        }
    }

    private func bar(fraction: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                Capsule()
                    .fill(Theme.yellow)
                    .frame(width: geometry.size.width * fraction)
                    .shadow(color: Theme.yellow.opacity(0.5), radius: 4)
                    .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.36), value: leaving)
            }
        }
        .frame(height: 2)
    }
}

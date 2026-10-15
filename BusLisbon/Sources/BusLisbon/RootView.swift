import SwiftUI
import BusLisbonCore

struct RootView: View {
    var body: some View {
        ZStack {
            Color(red: 1, green: 0.8, blue: 0).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Bus Lisbon")
                    .font(.system(size: 40, weight: .black))
                Text("\(reportedSeconds(1_789_125_473_000) ?? 0)")
                    .font(.system(.body, design: .monospaced))
            }
            .foregroundStyle(.black)
        }
    }
}

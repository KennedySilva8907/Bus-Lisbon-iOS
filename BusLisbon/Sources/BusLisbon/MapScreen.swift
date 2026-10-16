import SwiftUI
import BusLisbonCore

struct MapScreen: View {
    let store: StopsStore

    @State private var selectedStop: Stop?

    var body: some View {
        StopMapView(stops: store.stops ?? [], selectedStop: selectedStop) { selectedStop = $0 }
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    SearchBar(index: store.searchIndex, tucked: selectedStop != nil) { selectedStop = $0 }
                    offlineBanner
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .sheet(item: $selectedStop) { stop in
                StopPanel(stop: stop, followingVehicleId: nil) { _ in }
                    .environment(\.colorScheme, .dark)
                    .presentationDetents([.medium, .large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .presentationBackground(Theme.panel)
            }
    }

    @ViewBuilder
    private var offlineBanner: some View {
        if store.failed && store.stops == nil {
            Button("Sem ligação — tocar para tentar outra vez") {
                Task { await store.load() }
            }
            .padding(12)
            .background(.thinMaterial, in: Capsule())
        }
    }
}

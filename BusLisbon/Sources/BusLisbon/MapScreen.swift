import SwiftUI
import BusLisbonCore

struct MapScreen: View {
    let store: StopsStore

    @State private var selectedStop: Stop?

    var body: some View {
        StopMapView(stops: store.stops ?? [], selectedStop: selectedStop) { selectedStop = $0 }
            .ignoresSafeArea()
            .overlay(alignment: .top) { offlineBanner }
            .sheet(item: $selectedStop) { stop in
                Text(stop.name)
                    .font(.title2.bold())
                    .padding()
                    .presentationDetents([.medium])
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
            .padding(.top, 8)
        }
    }
}

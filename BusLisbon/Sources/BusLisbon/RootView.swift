import SwiftUI
import BusLisbonCore

struct RootView: View {
    @State private var store = StopsStore()
    @State private var splashDone = false

    var body: some View {
        ZStack {
            Text(status)
                .font(.headline)
            if !splashDone {
                SplashScreen(stopsReady: store.stops != nil) { splashDone = true }
            }
        }
        .task { await store.load() }
    }

    private var status: String {
        if let stops = store.stops { return "\(stops.count) paragens" }
        return store.failed ? "Sem ligação" : "A carregar…"
    }
}

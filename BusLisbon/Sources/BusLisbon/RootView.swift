import SwiftUI
import BusLisbonCore

struct RootView: View {
    @State private var store = StopsStore()
    @State private var splashDone = false

    var body: some View {
        ZStack {
            MapScreen(store: store, revealed: splashDone)
            if !splashDone {
                SplashScreen(stopsReady: store.stops != nil) { splashDone = true }
            }
        }
        .task { await store.load() }
    }
}

import SwiftUI
import BusLisbonCore

struct MapScreen: View {
    let store: StopsStore
    let revealed: Bool

    @State private var selectedStop: Stop?
    @State private var following: FollowTarget?
    @State private var follow = FollowModel()
    @State private var favourites = Favourites(key: "favouriteStops")
    @State private var favouriteLines = Favourites(key: "favouriteLines")
    @State private var showRanking = false
    @State private var fitToken = 0
    @State private var wake = 0
    @State private var closeTaps = 0
    @State private var searchShape = SearchBarShape()
    @State private var showAlerts = false
    @State private var openAfterAlerts: String?
    @State private var detent: PresentationDetent = MapScreen.panelOpen
    @Environment(\.scenePhase) private var scenePhase

    static let panelOpen = PresentationDetent.fraction(0.55)
    static let panelClosed = PresentationDetent.height(80)

    var body: some View {
        StopMapView(
            stops: store.stops ?? [],
            selectedStop: selectedStop,
            following: following != nil,
            bus: following == nil ? nil : follow.state.shown,
            route: following == nil ? nil : follow.route,
            panel: selectedStop == nil ? .none : detent == MapScreen.panelOpen ? .open : .closed,
            fitToken: fitToken,
            revealed: revealed
        ) { selectedStop = $0 }
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    SearchBar(index: store.searchIndex, favourites: favourites, tucked: selectedStop != nil, shape: $searchShape) { selectedStop = $0 }
                    offlineBanner
                    noPositionBanner
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .overlay(alignment: .bottomTrailing) {
                let pending = ArrivalAlerts.shared.alerts.count
                if selectedStop == nil {
                    VStack(spacing: 12) {
                        RoundButton(systemImage: "chart.bar.fill", label: "Pontualidade das linhas") { showRanking = true }
                        if pending > 0 {
                            AlertsButton(count: pending) { showAlerts = true }
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16 + 48 + 12)
                    .transition(.opacity)
                }
            }
            .sheet(isPresented: $showRanking) {
                LineRankingSheet(favourites: favouriteLines)
                    .environment(\.colorScheme, .dark)
                    .presentationDetents([.medium, .large])
                    .presentationBackground { PanelBackground() }
                    .presentationCornerRadius(PanelBackground.cornerRadius)
            }
            .animation(.snappy, value: ArrivalAlerts.shared.alerts.isEmpty)
            .sheet(isPresented: $showAlerts, onDismiss: { openStopFromAlerts(); openFromNotification() }) {
                AlertsList { openAfterAlerts = $0 }
                    .environment(\.colorScheme, .dark)
                    .presentationDetents([.medium, .large])
                    .presentationBackground { PanelBackground() }
                    .presentationCornerRadius(PanelBackground.cornerRadius)
            }
            .overlay(alignment: .topTrailing) {
                if following != nil {
                    RoundButton(systemImage: "scope", label: "Centrar no autocarro") { fitToken += 1 }
                        .padding(.trailing, 16)
                        .padding(.top, 8 + (SearchBar.openHeight + 8) * searchShape.openness)
                        .opacity(searchShape.listing ? 0 : 1)
                        .allowsHitTesting(!searchShape.listing)
                        .animation(SearchBar.settle, value: searchShape)
                }
            }
            .task(id: FollowRun(target: following, wake: wake)) {
                if let following {
                    await follow.run(following)
                } else {
                    follow.stop()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    wake += 1
                    Task { await ArrivalAlerts.shared.refreshAll() }
                case .background:
                    ArrivalAlerts.shared.planBackgroundRefresh()
                default:
                    break
                }
            }
            .onChange(of: selectedStop?.id) { _, _ in detent = MapScreen.panelOpen }
            .onChange(of: NotificationRoute.shared.opened, initial: true) { _, _ in openFromNotification() }
            .onChange(of: revealed && store.searchIndex != nil) { _, _ in openFromNotification() }
            .sensoryFeedback(.impact(weight: .light), trigger: closeTaps)
            .sheet(item: $selectedStop, onDismiss: { following = nil; openFromNotification() }) { stop in
                StopPanel(stop: stop, favourites: favourites, favouriteLines: favouriteLines, following: following) { arrival in
                    following = FollowTarget(
                        vehicleId: arrival.vehicleId,
                        tripId: arrival.tripId,
                        lineId: arrival.lineId,
                        patternId: arrival.patternId,
                        scheduledUnix: arrival.scheduledUnix
                    )
                    fitToken += 1
                } onClose: {
                    closeTaps += 1
                    selectedStop = nil
                }
                .environment(\.colorScheme, .dark)
                .presentationDetents([MapScreen.panelClosed, MapScreen.panelOpen], selection: $detent)
                .presentationBackgroundInteraction(.enabled(upThrough: MapScreen.panelOpen))
                .presentationBackground { PanelBackground() }
                .presentationCornerRadius(PanelBackground.cornerRadius)
            }
    }

    private func openFromNotification() {
        guard let alert = NotificationRoute.shared.opened,
              revealed,
              let stop = store.searchIndex?.stops(withIds: [alert.stopId]).first else { return }

        if showAlerts {
            showAlerts = false
            return
        }

        if let open = selectedStop, open.id != stop.id {
            selectedStop = nil
            return
        }

        NotificationRoute.shared.opened = nil
        selectedStop = stop
        following = alert.follow
        fitToken += 1
    }

    private func openStopFromAlerts() {
        guard let id = openAfterAlerts else { return }
        openAfterAlerts = nil
        selectedStop = store.searchIndex?.stops(withIds: [id]).first
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

    @ViewBuilder
    private var noPositionBanner: some View {
        if following != nil && follow.state.noRecentPosition {
            Label("Sem posição recente", systemImage: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(12)
                .background(Theme.ink.opacity(0.9), in: Capsule())
        }
    }
}

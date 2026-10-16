import SwiftUI
import BusLisbonCore

struct StopPanel: View {
    let stop: Stop
    let favourites: FavouriteStops
    let followingVehicleId: String?
    let onFollow: (Arrival) -> Void
    let onClose: () -> Void

    @State private var model = StopPanelModel()
    @State private var showAllPast = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = Int(context.date.timeIntervalSince1970)
            let split = splitPanel(model.arrivals, now: now)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    status(now: now)
                    if !split.past.isEmpty {
                        past(split.past, now: now)
                    }
                    upcoming(split.upcoming, now: now)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .task(id: stop.id) { await model.run(stopId: stop.id) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            title
            Spacer(minLength: 0)
            starButton
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.yellow)
                    .frame(width: 32, height: 32)
                    .background(Theme.yellow.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("Fechar paragem")
        }
    }

    private var starButton: some View {
        let starred = favourites.contains(stop.id)

        return Button {
            favourites.toggle(stop.id)
        } label: {
            Image(systemName: starred ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.yellow)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: starred)
                .frame(width: 32, height: 32)
                .background(Theme.yellow.opacity(starred ? 0.24 : 0.12), in: Circle())
                .animation(.snappy, value: starred)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: starred)
        .accessibilityLabel(starred ? "Remover dos favoritos" : "Adicionar aos favoritos")
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stop.name)
                .font(.system(size: 18, weight: .bold))
            HStack(spacing: 10) {
                Text("#\(stop.id)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.yellow.opacity(0.5)))
                if let locality = stop.locality {
                    Text(locality)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func status(now: Int) -> some View {
        if !model.loaded {
            HStack(spacing: 10) {
                ProgressView()
                Text("A carregar chegadas…")
                    .foregroundStyle(.secondary)
            }
        } else if model.arrivals.isEmpty && model.failed {
            Text("Não foi possível carregar as chegadas.")
                .foregroundStyle(.secondary)
        } else {
            if !model.arrivals.isEmpty && !anyArrivalTime(model.arrivals) {
                Label(
                    "Tempo real indisponível nesta zona neste momento. A mostrar apenas o horário planeado.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.system(size: 12))
                .foregroundStyle(Color.orange)
                .padding(12)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            if let updatedAt = model.updatedAt {
                let age = max(0, now - Int(updatedAt.timeIntervalSince1970))
                Text("↻ há " + (age < 60 ? "\(age)s" : "\(age / 60)min"))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(age > 30 ? Color.orange : Color.secondary)
            }
        }
    }

    private func past(_ arrivals: [Arrival], now: Int) -> some View {
        let recent = Array(arrivals.prefix(2))
        let older = Array(arrivals.dropFirst(2))

        return VStack(spacing: 8) {
            if !older.isEmpty {
                Button {
                    showAllPast.toggle()
                } label: {
                    Label("Ver passagens anteriores", systemImage: showAllPast ? "chevron.down" : "chevron.up")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.yellow)
                }
            }
            ForEach(showAllPast ? older + recent : recent) { arrival in
                PastRow(arrival: arrival, now: now, selected: isFollowing(arrival))
                    .onTapGesture { follow(arrival) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func upcoming(_ arrivals: [Arrival], now: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRÓXIMAS CHEGADAS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.secondary)
            if arrivals.isEmpty && model.loaded {
                Text("Sem chegadas nos próximos 120 minutos.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            ForEach(arrivals) { arrival in
                UpcomingRow(arrival: arrival, now: now, selected: isFollowing(arrival))
                    .onTapGesture { follow(arrival) }
            }
        }
    }

    private func isFollowing(_ arrival: Arrival) -> Bool {
        !arrival.vehicleId.isEmpty && arrival.vehicleId == followingVehicleId
    }

    private func follow(_ arrival: Arrival) {
        if describeArrival(arrival).trackable {
            onFollow(arrival)
        }
    }
}

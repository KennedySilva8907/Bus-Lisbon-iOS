import SwiftUI
import BusLisbonCore

struct AlertsButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        RoundButton(systemImage: "bell.fill", label: "Avisos agendados", action: action)
            .overlay(alignment: .topTrailing) {
                Text("\(count)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 18, minHeight: 18)
                    .padding(.horizontal, 2)
                    .background(Theme.yellow, in: Capsule())
                    .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))
                    .offset(x: 2, y: -2)
                    .contentTransition(.numericText())
            }
            .animation(.snappy, value: count)
    }
}

struct AlertsList: View {
    let onOpen: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private var alerts: [ArrivalAlert] {
        ArrivalAlerts.shared.alerts.sorted { $0.fireUnix < $1.fireUnix }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Avisos agendados")
                .font(.system(size: 17, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)

            List {
                ForEach(alerts) { alert in
                    Button {
                        onOpen(alert.stopId)
                        dismiss()
                    } label: {
                        row(alert)
                    }
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation(.snappy) { ArrivalAlerts.shared.cancel(alert.id) }
                        } label: {
                            Label("Cancelar", systemImage: "bell.slash.fill")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .onChange(of: alerts.isEmpty) { _, empty in
            if empty { dismiss() }
        }
    }

    private func row(_ alert: ArrivalAlert) -> some View {
        HStack(spacing: 12) {
            LineBadge(line: alert.lineId)
            VStack(alignment: .leading, spacing: 3) {
                Text(alert.stopName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(alert.headsign)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("às \(Clock.text(alert.fireUnix))")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.yellow)
                Text("\(alert.minutesBefore) min antes")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

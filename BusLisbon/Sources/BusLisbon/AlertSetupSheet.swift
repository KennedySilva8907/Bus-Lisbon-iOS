import SwiftUI
import BusLisbonCore

struct AlertSetupSheet: View {
    let arrival: Arrival
    let stop: Stop

    @Environment(\.dismiss) private var dismiss
    @State private var preset: Int?
    @State private var custom = ""
    @State private var saving = false
    @State private var refused = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let now = Int(context.date.timeIntervalSince1970)
            let minutesLeft = max(0, (arrivalTime(arrival) - now) / 60)
            let usable = usableAlertMinutes(arrivalUnix: arrivalTime(arrival), now: now)
            let chosen = Int(custom) ?? preset
            let valid = chosen.map { $0 >= 1 && $0 <= usable } ?? false

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    LineBadge(line: arrival.lineId)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.name)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        Text(arrival.headsign)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if usable < 1 {
                    notice("O autocarro está a chegar em ~\(minutesLeft) min. Demasiado perto para agendar um aviso.")
                }

                if refused {
                    notice("As notificações estão desligadas para o Bus Lisbon. Ativa-as em Definições › Notificações.")
                }

                HStack {
                    Text("Avisar quantos minutos antes?")
                        .font(.system(size: 13))
                    Spacer()
                    Text("chega em ~\(minutesLeft) min")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    ForEach(alertPresetMinutes, id: \.self) { minutes in
                        chip(minutes, picked: custom.isEmpty && preset == minutes, disabled: minutes > usable)
                    }
                    TextField("Outro", text: $custom)
                        .keyboardType(.numberPad)
                        .font(.system(size: 13, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .frame(width: 64, height: 36)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(customColour(usable: usable), lineWidth: custom.isEmpty ? 0 : 2)
                        )
                }

                Button {
                    guard let chosen else { return }
                    saving = true
                    Task {
                        let scheduled = await ArrivalAlerts.shared.schedule(arrival, at: stop, minutesBefore: chosen)
                        saving = false
                        if scheduled { dismiss() } else { refused = true }
                    }
                } label: {
                    Text("Agendar aviso")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.yellow, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(saving || !valid)
                .opacity(saving || !valid ? 0.4 : 1)
            }
            .padding(20)
            .onAppear {
                preset = alertPresetMinutes.last { $0 <= usable }
            }
        }
        .sensoryFeedback(.success, trigger: saving) { was, now in was && !now && !refused }
    }

    private func chip(_ minutes: Int, picked: Bool, disabled: Bool) -> some View {
        Button {
            preset = minutes
            custom = ""
        } label: {
            Text("\(minutes) min")
                .font(.system(size: 13, weight: .semibold))
                .strikethrough(disabled)
                .foregroundStyle(picked ? Theme.ink : disabled ? Color.secondary.opacity(0.5) : Color.primary)
                .frame(height: 36)
                .padding(.horizontal, 10)
                .background(picked ? Theme.yellow : Color.white.opacity(disabled ? 0.02 : 0.06), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func customColour(usable: Int) -> Color {
        guard let value = Int(custom) else { return .red }
        return value >= 1 && value <= usable ? Theme.yellow : .red
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

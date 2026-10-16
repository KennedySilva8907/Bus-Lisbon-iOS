import SwiftUI
import BusLisbonCore

@MainActor
enum Clock {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Lisbon")
        return formatter
    }()

    static func text(_ unix: Int) -> String {
        formatter.string(from: Date(timeIntervalSince1970: TimeInterval(unix)))
    }
}

struct LineBadge: View {
    let line: String
    var faded = false

    var body: some View {
        Text(line)
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(faded ? Theme.yellow.opacity(0.6) : Theme.ink)
            .frame(width: 56, height: 32)
            .background(faded ? Theme.yellow.opacity(0.2) : Theme.yellow, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct PunctualityTag: View {
    let punctuality: Punctuality

    var body: some View {
        Text(punctuality.label)
            .font(.system(size: 10))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(colour)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(colour.opacity(0.12), in: Capsule())
    }

    private var colour: Color {
        switch punctuality.tone {
        case .early: .blue
        case .late: .orange
        case .onTime: .green
        case .running: Theme.yellow
        case .finished: .gray
        }
    }
}

struct UpcomingRow: View {
    let arrival: Arrival
    let now: Int
    let selected: Bool

    var body: some View {
        let description = describeArrival(arrival)
        let time = arrivalTime(arrival)
        let tracked = description.state != .scheduled

        HStack(spacing: 12) {
            LineBadge(line: arrival.lineId)
            VStack(alignment: .leading, spacing: 4) {
                Text(arrival.headsign)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                HStack(spacing: 6) {
                    if tracked {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                    }
                    Text(description.label)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let punctuality = estimatePunctuality(arrival) {
                        PunctualityTag(punctuality: punctuality)
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(countdownLabel(time, now: now))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(countdownColour(time: time, tracked: tracked))
                Text(Clock.text(time))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(selected ? Theme.yellow.opacity(0.12) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.yellow.opacity(0.6) : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
    }

    private func countdownColour(time: Int, tracked: Bool) -> Color {
        let minutes = minutesAway(time, now: now)
        if minutes <= 0 { return .green }
        if minutes <= 3 && tracked { return .green }
        if minutes <= 10 { return Theme.yellow }
        return .primary
    }
}

struct PastRow: View {
    let arrival: Arrival
    let now: Int
    let selected: Bool

    var body: some View {
        let wentBy = wentByAt(arrival) ?? arrival.scheduledUnix
        let tag = describePunctuality(arrival) ?? describePassage(arrival)

        HStack(spacing: 12) {
            LineBadge(line: arrival.lineId, faded: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(arrival.headsign)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    PunctualityTag(punctuality: tag)
                    if !arrival.vehicleId.isEmpty {
                        Text("· toca para ver no mapa")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(agoLabel(wentBy, now: now))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(Clock.text(wentBy))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .opacity(selected ? 0.9 : 0.55)
        .background(selected ? Theme.yellow.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
    }
}

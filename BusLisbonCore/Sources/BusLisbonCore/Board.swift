import Foundation

public struct BoardEntry: Sendable, Equatable, Decodable {
    let lineId: String
    let patternId: String
    let headsign: String
    let tripId: String
    let vehicleId: String
    let scheduledUnix: Int
    let estimatedUnix: Int
    let isPast: Bool
    let isRealtime: Bool
    let tripRunning: Bool
    var fromTheBus: Bool? = nil
}

public struct Arrival: Sendable, Equatable, Identifiable {
    public let tripId: String
    public let lineId: String
    public let patternId: String
    public let headsign: String
    public let estimatedUnix: Int
    public let scheduledUnix: Int
    public let observedUnix: Int?
    public let wentByUnix: Int?
    public let tripRunning: Bool
    public let vehicleId: String

    public var id: String { "\(patternId)@\(scheduledUnix)" }
}

public func toArrivals(_ board: [BoardEntry]) -> [Arrival] {
    board.map { entry in
        Arrival(
            tripId: entry.tripId,
            lineId: entry.lineId,
            patternId: entry.patternId,
            headsign: entry.headsign,
            estimatedUnix: entry.isPast ? 0 : entry.estimatedUnix,
            scheduledUnix: entry.scheduledUnix,
            observedUnix: entry.isPast && entry.isRealtime && entry.fromTheBus != true ? entry.estimatedUnix : nil,
            wentByUnix: entry.isPast ? (entry.estimatedUnix != 0 ? entry.estimatedUnix : entry.scheduledUnix) : nil,
            tripRunning: entry.tripRunning,
            vehicleId: entry.tripRunning ? entry.vehicleId : ""
        )
    }
}

public enum ArrivalState: Sendable, Equatable {
    case boarding, onTheWay, predicted, scheduled
}

public struct ArrivalDescription: Sendable, Equatable {
    public let state: ArrivalState
    public let trackable: Bool
    public let label: String
}

public func describeArrival(_ arrival: Arrival) -> ArrivalDescription {
    let predicted = arrival.estimatedUnix != 0 && arrival.estimatedUnix != arrival.scheduledUnix

    if !arrival.vehicleId.isEmpty && predicted {
        return ArrivalDescription(state: .boarding, trackable: true, label: "Em viagem")
    }

    if !arrival.vehicleId.isEmpty {
        return ArrivalDescription(state: .onTheWay, trackable: true, label: "Agendado · autocarro a caminho")
    }

    return predicted
        ? ArrivalDescription(state: .predicted, trackable: false, label: "Previsto · ainda sem autocarro")
        : ArrivalDescription(state: .scheduled, trackable: false, label: "Agendado · ainda sem autocarro")
}

public enum PunctualityTone: Sendable, Equatable {
    case early, late, onTime, finished, running
}

public struct Punctuality: Sendable, Equatable {
    public let label: String
    public let tone: PunctualityTone
}

let earlyBy = 60
let lateBy = 120

func punctuality(delay: Int) -> Punctuality {
    if delay < -earlyBy { return Punctuality(label: "Adiantado", tone: .early) }
    if delay > lateBy { return Punctuality(label: "+\(Int((Double(delay) / 60).rounded()))min", tone: .late) }
    return Punctuality(label: "Pontual", tone: .onTime)
}

public func describePunctuality(_ arrival: Arrival) -> Punctuality? {
    arrival.observedUnix.map { punctuality(delay: $0 - arrival.scheduledUnix) }
}

public func estimatePunctuality(_ arrival: Arrival) -> Punctuality? {
    guard arrival.estimatedUnix != 0, arrival.scheduledUnix != 0 else { return nil }
    return punctuality(delay: arrival.estimatedUnix - arrival.scheduledUnix)
}

public func describePassage(_ arrival: Arrival) -> Punctuality {
    arrival.tripRunning
        ? Punctuality(label: "Ainda em percurso", tone: .running)
        : Punctuality(label: "Terminou o percurso", tone: .finished)
}

public func wentByAt(_ arrival: Arrival) -> Int? {
    arrival.wentByUnix ?? arrival.observedUnix
}

public func isSameDeparture(_ arrival: Arrival, lineId: String, scheduledUnix: Int) -> Bool {
    arrival.lineId == lineId && arrival.scheduledUnix == scheduledUnix
}

public func anyArrivalTime(_ arrivals: [Arrival]) -> Bool {
    arrivals.contains { $0.estimatedUnix > 0 || ($0.observedUnix ?? 0) > 0 }
}

public func arrivalTime(_ arrival: Arrival) -> Int {
    arrival.estimatedUnix != 0 ? arrival.estimatedUnix : arrival.scheduledUnix
}

public struct PanelSplit: Sendable, Equatable {
    public let past: [Arrival]
    public let upcoming: [Arrival]
}

public func splitPanel(_ arrivals: [Arrival], now: Int) -> PanelSplit {
    let wentBy: (Arrival) -> Bool = { (wentByAt($0) ?? .max) < now }

    let past = arrivals
        .filter(wentBy)
        .sorted { (wentByAt($0) ?? 0) > (wentByAt($1) ?? 0) }

    let upcoming = arrivals
        .filter { arrival in
            guard !wentBy(arrival) else { return false }
            let time = arrivalTime(arrival)
            if time < now - 60 && !arrival.tripRunning { return false }
            return time < now + 7200
        }
        .sorted { arrivalTime($0) < arrivalTime($1) }

    return PanelSplit(past: past, upcoming: Array(upcoming.prefix(20)))
}

public func minutesAway(_ arrivalUnix: Int, now: Int) -> Int {
    Int((Double(arrivalUnix) / 60).rounded(.down)) - Int((Double(now) / 60).rounded(.down))
}

public func countdownLabel(_ arrivalUnix: Int, now: Int) -> String {
    let diffMinutes = minutesAway(arrivalUnix, now: now)

    if arrivalUnix - now <= 30 { return "Agora" }
    if diffMinutes <= 0 { return "<1min" }
    if diffMinutes < 60 { return "\(diffMinutes)min" }

    let minutes = diffMinutes % 60
    return "\(diffMinutes / 60)h" + (minutes == 0 ? "" : minutes < 10 ? "0\(minutes)" : "\(minutes)")
}

public func agoLabel(_ wentByUnix: Int, now: Int) -> String {
    "Há \(Int((Double(now - wentByUnix) / 60).rounded()))min"
}

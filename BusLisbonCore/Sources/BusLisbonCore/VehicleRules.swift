import Foundation

public let smallestMillisecondReading = 100_000_000_000
public let freshWindowSeconds = 300

public func reportedSeconds(_ timestamp: Int?) -> Int? {
    guard let timestamp, timestamp != 0 else { return nil }
    return abs(timestamp) >= smallestMillisecondReading ? timestamp / 1000 : timestamp
}

public func isLive(_ bus: BusPosition, now: Int) -> Bool {
    guard !bus.id.isEmpty, bus.id != "|undefined" else { return false }
    guard bus.lat.isFinite, bus.lon.isFinite, bus.lat != 0 || bus.lon != 0 else { return false }

    if let reported = reportedSeconds(bus.timestamp), now - reported > freshWindowSeconds {
        return false
    }

    return true
}

public struct ReceivedPosition: Sendable, Equatable {
    public let target: String
    public let bus: BusPosition
}

public func keepTheNewer(_ held: ReceivedPosition?, target: String, incoming: BusPosition) -> ReceivedPosition {
    if let held,
       held.target == target,
       (reportedSeconds(held.bus.timestamp) ?? 0) > (reportedSeconds(incoming.timestamp) ?? 0) {
        return held
    }

    return ReceivedPosition(target: target, bus: incoming)
}

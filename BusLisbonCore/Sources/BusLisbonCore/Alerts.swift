import Foundation

public let alertPresetMinutes = [3, 5, 10, 15]
public let alertBufferMinutes = 1
public let alertMoveSeconds = 30

public func usableAlertMinutes(arrivalUnix: Int, now: Int) -> Int {
    max(0, (arrivalUnix - now) / 60 - alertBufferMinutes)
}

public func alertFireUnix(arrivalUnix: Int, minutesBefore: Int) -> Int {
    arrivalUnix - minutesBefore * 60
}

public enum AlertUpdate: Sendable, Equatable {
    case keep
    case move(to: Int)
    case drop
}

public func updateAlert(fireUnix: Int, minutesBefore: Int, arrival: Arrival?, now: Int) -> AlertUpdate {
    if fireUnix <= now { return .drop }
    guard let arrival else { return .keep }
    if wentByAt(arrival) != nil { return .drop }

    let fresh = max(now, alertFireUnix(arrivalUnix: arrivalTime(arrival), minutesBefore: minutesBefore))
    return abs(fresh - fireUnix) >= alertMoveSeconds ? .move(to: fresh) : .keep
}

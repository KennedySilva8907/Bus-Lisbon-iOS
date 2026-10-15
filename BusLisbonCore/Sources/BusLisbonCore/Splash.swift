import Foundation

public func splashProgress(elapsed: Double) -> Int {
    min(92, Int(((1 - exp(-elapsed / 1.6)) * 92).rounded()))
}

public func splashCanLeave(elapsed: Double, stopsReady: Bool) -> Bool {
    (stopsReady && elapsed >= 5) || elapsed >= 15
}

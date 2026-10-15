import Foundation

public func splashFraction(elapsed: Double) -> Double {
    (1 - exp(-max(0, elapsed) / 1.6)) * 0.92
}

public func splashProgress(elapsed: Double) -> Int {
    min(92, Int((splashFraction(elapsed: elapsed) * 100).rounded()))
}

public func splashCanLeave(elapsed: Double, stopsReady: Bool) -> Bool {
    (stopsReady && elapsed >= 5) || elapsed >= 15
}

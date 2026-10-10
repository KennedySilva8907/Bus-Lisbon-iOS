import Foundation

public let smallestMillisecondReading = 100_000_000_000

public func reportedSeconds(_ timestamp: Int?) -> Int? {
    guard let timestamp, timestamp != 0 else { return nil }
    return abs(timestamp) >= smallestMillisecondReading ? timestamp / 1000 : timestamp
}

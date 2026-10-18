import Foundation

public struct RankedLine: Codable, Sendable, Equatable, Identifiable, Hashable {
    public let lineId: String
    public let passages: Int
    public let withinTolerance: Int
    public let late: Int
    public let early: Int
    public let averageLatenessSeconds: Double
    public let firstServiceDate: String
    public let lastServiceDate: String

    public var id: String { lineId }
}

public struct LineRanking: Codable, Sendable, Equatable {
    public let computedAtUnix: Int
    public let toleranceSeconds: Int
    public let lines: [RankedLine]
}

public struct SplitRanking: Sendable, Equatable {
    public let mine: [RankedLine]
    public let missing: [String]
    public let rest: [RankedLine]
}

public enum TrustLevel: Sendable, Equatable {
    case high, good, uneven, low
}

public struct Trust: Sendable, Equatable {
    public let level: TrustLevel
    public let label: String
}

public let thinEvidence = 50

public func splitByFavourites(_ lines: [RankedLine], favourites: [String]) -> SplitRanking {
    let chosen = Set(favourites)
    let ranked = Set(lines.map(\.lineId))

    return SplitRanking(
        mine: lines.filter { chosen.contains($0.lineId) },
        missing: favourites.filter { !ranked.contains($0) },
        rest: lines.filter { !chosen.contains($0.lineId) }
    )
}

public func punctualityPercent(_ line: RankedLine) -> Int {
    line.passages == 0 ? 0 : Int((Double(line.withinTolerance) / Double(line.passages) * 100).rounded())
}

public func describeTrust(_ percent: Int) -> Trust {
    if percent >= 90 { return Trust(level: .high, label: "Muito fiável") }
    if percent >= 70 { return Trust(level: .good, label: "Fiável") }
    if percent >= 50 { return Trust(level: .uneven, label: "Irregular") }
    return Trust(level: .low, label: "Pouco fiável")
}

private let months = [
    "janeiro", "fevereiro", "março", "abril", "maio", "junho",
    "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
]

public func describeServiceWindow(_ first: String, _ last: String) -> String {
    let (firstMonth, firstDay) = monthAndDay(first)
    let (lastMonth, lastDay) = monthAndDay(last)

    if first == last { return "\(firstDay) de \(months[firstMonth - 1])" }
    if firstMonth == lastMonth { return "\(firstDay) a \(lastDay) de \(months[lastMonth - 1])" }
    return "\(firstDay) de \(months[firstMonth - 1]) a \(lastDay) de \(months[lastMonth - 1])"
}

private func monthAndDay(_ date: String) -> (Int, Int) {
    let parts = date.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3, (1...12).contains(parts[1]) else { return (1, 1) }
    return (parts[1], parts[2])
}

public func describeAverage(_ averageLatenessSeconds: Double) -> String {
    let minutes = Int((abs(averageLatenessSeconds) / 60).rounded())

    if minutes == 0 { return "à tabela" }
    return averageLatenessSeconds > 0 ? "\(minutes) min atrasada" : "\(minutes) min adiantada"
}

public func describeToleranceLabel(_ toleranceSeconds: Int) -> String {
    "dentro de \(Int((Double(toleranceSeconds) / 60).rounded())) min do horário"
}

public func describeFreshness(computedAtUnix: Int, now: Int) -> String {
    if computedAtUnix == 0 { return "Ainda sem dados" }

    let days = (now - computedAtUnix) / 86_400

    if days <= 0 { return "Actualizado hoje" }
    if days == 1 { return "Actualizado ontem" }
    return "Actualizado há \(days) dias"
}

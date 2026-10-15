import Foundation

public struct MapBox: Sendable, Equatable {
    public let minLat: Double
    public let maxLat: Double
    public let minLon: Double
    public let maxLon: Double

    public init(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        self.minLat = minLat
        self.maxLat = maxLat
        self.minLon = minLon
        self.maxLon = maxLon
    }

    func contains(_ stop: Stop) -> Bool {
        (minLat...maxLat).contains(stop.lat) && (minLon...maxLon).contains(stop.lon)
    }
}

public struct StopCluster: Sendable, Equatable {
    public let key: String
    public let lat: Double
    public let lon: Double
    public let count: Int
    public let stop: Stop?
}

public let clusterCellsAcross = 6.0
public let showStopsBelow = 150

public func clusterCellSize(span: Double) -> Double {
    pow(2, log2(span / clusterCellsAcross).rounded(.down))
}

private struct Cell: Hashable {
    let row: Int
    let column: Int
}

public func clusterStops(_ stops: [Stop], in box: MapBox, cellSize: Double, showAllBelow: Int) -> [StopCluster] {
    let visible = stops.filter(box.contains)

    if visible.count <= showAllBelow {
        return visible.map(single)
    }

    let cells = Dictionary(grouping: visible) { stop in
        Cell(row: Int((stop.lat / cellSize).rounded(.down)), column: Int((stop.lon / cellSize).rounded(.down)))
    }

    return cells
        .map { cell, members in
            guard members.count > 1 else { return single(members[0]) }
            return StopCluster(
                key: "cell:\(cell.row):\(cell.column):\(members.count)",
                lat: members.map(\.lat).reduce(0, +) / Double(members.count),
                lon: members.map(\.lon).reduce(0, +) / Double(members.count),
                count: members.count,
                stop: nil
            )
        }
        .sorted { ($0.lat, $0.lon) < ($1.lat, $1.lon) }
}

private func single(_ stop: Stop) -> StopCluster {
    StopCluster(key: "stop:\(stop.id)", lat: stop.lat, lon: stop.lon, count: 1, stop: stop)
}

import Foundation

public struct ZoomCurve: Sendable {
    private let steps: [(zoom: Double, value: Double)]

    init(_ steps: [(zoom: Double, value: Double)]) {
        self.steps = steps
    }

    public func at(_ zoom: Double) -> Double {
        guard let first = steps.first, let last = steps.last else { return 0 }
        if zoom <= first.zoom { return first.value }
        if zoom >= last.zoom { return last.value }

        for (low, high) in zip(steps, steps.dropFirst()) where zoom <= high.zoom {
            return low.value + (high.value - low.value) * (zoom - low.zoom) / (high.zoom - low.zoom)
        }

        return last.value
    }
}

public func mapZoom(zoomScale: Double) -> Double {
    19 + log2(zoomScale)
}

public enum MapStyle {
    public static let stopRadius = ZoomCurve([(10, 1.5), (12, 2.5), (14, 4), (16, 5.5), (18, 7), (20, 8)])
    public static let stopRing = ZoomCurve([(10, 0.5), (13, 1), (16, 1.5), (19, 2)])
    public static let mutedStopRadius = ZoomCurve([(13, 2.5), (16, 4), (18, 5), (20, 6)])
    public static let mutedStopAlpha = ZoomCurve([(13, 0), (15.5, 0.75)])
    public static let waypointRadius = ZoomCurve([(9, 1), (26, 15)])
    public static let waypointStroke = ZoomCurve([(9, 1), (26, 7)])
    public static let vehicleSize = ZoomCurve([(10, 0.34), (13, 0.52), (15, 0.68), (17, 0.86), (20, 1.05)])
    public static let vehicleGlowRadius = ZoomCurve([(10, 15), (13, 22), (15, 28), (17, 35), (20, 44)])
}

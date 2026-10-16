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
    public static let stopRadius = ZoomCurve([(9, 1), (26, 20)])
    public static let stopStroke = ZoomCurve([(9, 0.01), (26, 7)])
    public static let mutedStopRadius = ZoomCurve([(9, 1), (26, 10)])
    public static let mutedStopStroke = ZoomCurve([(9, 0.01), (26, 3)])
    public static let waypointRadius = ZoomCurve([(9, 1), (26, 15)])
    public static let waypointStroke = ZoomCurve([(9, 1), (26, 7)])
    public static let routeLine = ZoomCurve([(10, 4), (20, 12)])
    public static let routeCasing = ZoomCurve([(10, 6), (20, 16)])
    public static let arrowSize = ZoomCurve([(10, 6.4), (20, 12.8)])
    public static let arrowSpacing = ZoomCurve([(10, 8), (20, 120)])
    public static let vehicleSize = ZoomCurve([(10, 0.34), (13, 0.52), (15, 0.68), (17, 0.86), (20, 1.05)])
    public static let vehicleGlowRadius = ZoomCurve([(10, 15), (13, 22), (15, 28), (17, 35), (20, 44)])
}

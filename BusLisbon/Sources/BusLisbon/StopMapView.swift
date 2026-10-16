import MapKit
import SwiftUI
import UIKit
import BusLisbonCore

final class SelectedStopAnnotation: MKPointAnnotation {}

final class BusAnnotation: MKPointAnnotation {
    var bearing: Double = 0
}

enum Paint {
    static let yellow = RGB(red: 1, green: 0.8, blue: 0)
    static let white = RGB(red: 1, green: 1, blue: 1)
    static let red = RGB(red: 0.898, green: 0.224, blue: 0.208)
    static let shadow = RGB(red: 0, green: 0, blue: 0)
}

extension CGContext {
    func setFill(_ colour: RGB, alpha: Double = 1) {
        setFillColor(red: colour.red, green: colour.green, blue: colour.blue, alpha: alpha)
    }

    func setStroke(_ colour: RGB, alpha: Double = 1) {
        setStrokeColor(red: colour.red, green: colour.green, blue: colour.blue, alpha: alpha)
    }
}

func drawRings(
    _ renderer: MKOverlayRenderer,
    at points: [MKMapPoint],
    radius: Double,
    stroke: Double,
    fill: RGB,
    edge: RGB,
    in context: CGContext
) {
    let edges = CGMutablePath()
    let fills = CGMutablePath()
    let outer = radius + stroke

    for point in points {
        edges.addEllipse(in: renderer.rect(for: MKMapRect(x: point.x - outer, y: point.y - outer, width: outer * 2, height: outer * 2)))
        fills.addEllipse(in: renderer.rect(for: MKMapRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)))
    }

    context.setFill(edge)
    context.addPath(edges)
    context.fillPath()

    context.setFill(fill)
    context.addPath(fills)
    context.fillPath()
}

func drawDots(
    _ renderer: MKOverlayRenderer,
    at points: [MKMapPoint],
    radius: Double,
    ring: Double,
    unit: Double,
    in context: CGContext
) {
    let outer = radius + ring

    func disc(_ point: MKMapPoint, radius: Double, drop: Double = 0) -> CGRect {
        renderer.rect(for: MKMapRect(x: point.x - radius, y: point.y - radius + drop, width: radius * 2, height: radius * 2))
    }

    for point in points {
        context.setFill(Paint.shadow, alpha: 0.22)
        context.fillEllipse(in: disc(point, radius: outer + 0.5 * unit, drop: 0.6 * unit))
        context.setFill(Paint.white)
        context.fillEllipse(in: disc(point, radius: outer))
        context.setFill(Paint.yellow)
        context.fillEllipse(in: disc(point, radius: radius))
    }
}

func boundingRect(_ points: [MKMapPoint]) -> MKMapRect {
    points.reduce(MKMapRect.null) { $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0))) }
}

final class StopsOverlay: NSObject, MKOverlay {
    let stops: [Stop]
    let points: [MKMapPoint]
    let muted: Bool
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect

    init(stops: [Stop], muted: Bool) {
        self.stops = stops
        self.muted = muted
        points = stops.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) }
        boundingMapRect = boundingRect(points)
        coordinate = MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate
    }

    func nearest(to point: MKMapPoint, within distance: Double) -> Stop? {
        var best: (index: Int, distance: Double)?
        for (index, candidate) in points.enumerated() {
            let dx = candidate.x - point.x
            let dy = candidate.y - point.y
            let squared = dx * dx + dy * dy
            if squared <= distance * distance, squared < (best?.distance ?? .infinity) {
                best = (index, squared)
            }
        }
        return best.map { stops[$0.index] }
    }
}

final class StopsRenderer: MKOverlayRenderer {
    private let points: [MKMapPoint]
    private let muted: Bool

    init(stops overlay: StopsOverlay) {
        points = overlay.points
        muted = overlay.muted
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let zoom = mapZoom(zoomScale: Double(zoomScale))
        let alpha = muted ? MapStyle.mutedStopAlpha.at(zoom) : 1
        guard alpha > 0 else { return }

        let unit = 1 / Double(zoomScale)
        let radius = (muted ? MapStyle.mutedStopRadius : MapStyle.stopRadius).at(zoom) * unit
        let ring = MapStyle.stopRing.at(zoom) * unit
        let reach = mapRect.insetBy(dx: -(radius + ring) * 2, dy: -(radius + ring) * 2)

        context.setAlpha(alpha)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        drawDots(self, at: points.filter { reach.contains($0) }, radius: radius, ring: ring, unit: unit, in: context)
        context.endTransparencyLayer()
    }
}

enum PanelCover: Equatable {
    case none, open, closed
}

private struct FrameKey: Equatable {
    let stopId: String?
    let busLat: Double?
    let busLon: Double?
    let panel: PanelCover
    let token: Int
}

final class BusView: MKAnnotationView {
    private let glow = UIImageView(image: MapPalette.busGlow)
    private let body = UIImageView(image: MapPalette.busMarker)

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 88, height: 88)
        glow.center = CGPoint(x: 44, y: 44)
        body.center = CGPoint(x: 44, y: 44)
        addSubview(glow)
        addSubview(body)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(bearing: Double, zoom: Double) {
        let size = MapStyle.vehicleSize.at(zoom)
        body.transform = CGAffineTransform(rotationAngle: bearing * .pi / 180).scaledBy(x: size, y: size)
        let glowScale = MapStyle.vehicleGlowRadius.at(zoom) / 44
        glow.transform = CGAffineTransform(scaleX: glowScale, y: glowScale)
    }
}

@MainActor
enum MapPalette {
    static let busMarker: UIImage? = Bundle.module.url(forResource: "bus-marker", withExtension: "png")
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { UIImage(data: $0, scale: 3) }

    static let busGlow: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 88, height: 88)).image { context in
        let colours = [
            UIColor(red: 1, green: 0.8, blue: 0, alpha: 0.32).cgColor,
            UIColor(red: 1, green: 0.8, blue: 0, alpha: 0).cgColor,
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0, 1]) else { return }
        context.cgContext.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: 44, y: 44),
            startRadius: 0,
            endCenter: CGPoint(x: 44, y: 44),
            endRadius: 44,
            options: []
        )
    }

    static let pinAnchor: CGFloat = 62

    static let selectedPin: UIImage = {
        let pin = Bundle.module.url(forResource: "stop-pin", withExtension: "png")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { UIImage(data: $0, scale: 6) }
        let pinSize = pin?.size ?? CGSize(width: 48, height: pinAnchor)
        let dotRadius: CGFloat = 8
        let size = CGSize(width: pinSize.width, height: pinAnchor + dotRadius + 2)

        return UIGraphicsImageRenderer(size: size).image { _ in
            let dot = UIBezierPath(ovalIn: CGRect(
                x: size.width / 2 - dotRadius,
                y: pinAnchor - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ))
            dot.lineWidth = 2
            UIColor.white.setFill()
            UIColor(white: 0.1, alpha: 1).setStroke()
            dot.fill()
            dot.stroke()
            pin?.draw(in: CGRect(origin: .zero, size: pinSize))
        }
    }()
}

struct StopMapView: UIViewRepresentable {
    let stops: [Stop]
    let selectedStop: Stop?
    let following: Bool
    let bus: BusPosition?
    let route: Route?
    let panel: PanelCover
    let fitToken: Int
    let onSelectStop: (Stop) -> Void

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 38.7223, longitude: -9.1393),
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ),
            animated: false
        )
        context.coordinator.map = map
        context.coordinator.locationManager.requestWhenInUseAuthorization()
        _ = MapPalette.selectedPin
        _ = MapPalette.busMarker
        _ = MapPalette.busGlow

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(MapCoordinator.tapped(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)

        let locate = UIView()
        locate.translatesAutoresizingMaskIntoConstraints = false
        locate.backgroundColor = UIColor(Theme.ink.opacity(0.9))
        locate.layer.cornerRadius = 24
        locate.layer.borderWidth = 1
        locate.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        locate.layer.shadowColor = UIColor.black.cgColor
        locate.layer.shadowOpacity = 0.3
        locate.layer.shadowRadius = 12
        locate.layer.shadowOffset = CGSize(width: 0, height: 4)

        let tracking = MKUserTrackingButton(mapView: map)
        tracking.translatesAutoresizingMaskIntoConstraints = false
        tracking.tintColor = UIColor(Theme.yellow)
        tracking.backgroundColor = .clear
        locate.addSubview(tracking)
        map.addSubview(locate)
        NSLayoutConstraint.activate([
            locate.trailingAnchor.constraint(equalTo: map.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            locate.bottomAnchor.constraint(equalTo: map.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            locate.widthAnchor.constraint(equalToConstant: 48),
            locate.heightAnchor.constraint(equalToConstant: 48),
            tracking.centerXAnchor.constraint(equalTo: locate.centerXAnchor),
            tracking.centerYAnchor.constraint(equalTo: locate.centerYAnchor),
        ])

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSelectStop = onSelectStop
        coordinator.show(stops: stops, muted: following, on: map)
        coordinator.show(selected: selectedStop, on: map)
        coordinator.show(route: route, on: map)
        coordinator.show(bus: bus, on: map)
        coordinator.frame(stop: selectedStop, bus: bus, panel: panel, token: fitToken, on: map)
    }
}

@MainActor
final class MapCoordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
    let locationManager = CLLocationManager()
    var onSelectStop: (Stop) -> Void = { _ in }
    weak var map: MKMapView?

    private var stopsOverlay: StopsOverlay?
    private var shownRoute: Route?
    private var followed: FollowedRoute?
    private var routeOverlays: [any MKOverlay] = []
    private var pathRenderers: [MKPolylineRenderer] = []
    private var arrowsRenderer: RouteArrowsRenderer?
    private var routeStopsRenderer: RouteStopsRenderer?
    private let progress = RouteProgress()
    private var passedCount = 0
    private var selectedId: String?
    private var selectedPlace: Coordinate?
    private let selectedMarker = SelectedStopAnnotation()
    private let busMarker = BusAnnotation()
    private var busShown = false
    private var lastBus: BusPosition?
    private var relocateBus = false
    private var busAlong: Double?
    private var glide: (from: Double, to: Double, start: CFTimeInterval)?
    private var displayLink: CADisplayLink?
    private var centredOnUser = false
    private var framedKey: FrameKey?

    func show(stops: [Stop], muted: Bool, on map: MKMapView) {
        guard !stops.isEmpty else { return }
        if let stopsOverlay, stopsOverlay.muted == muted { return }

        let next = StopsOverlay(stops: stops, muted: muted)
        map.insertOverlay(next, at: 0, level: .aboveLabels)
        if let stopsOverlay { map.removeOverlay(stopsOverlay) }
        stopsOverlay = next
    }

    func show(selected stop: Stop?, on map: MKMapView) {
        guard stop?.id != selectedId else { return }
        selectedId = stop?.id
        selectedPlace = stop.map { Coordinate(lat: $0.lat, lon: $0.lon) }
        updateProgress()
        map.removeAnnotation(selectedMarker)
        guard let stop else { return }

        selectedMarker.coordinate = CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)
        map.addAnnotation(selectedMarker)
    }

    func show(route: Route?, on map: MKMapView) {
        guard route != shownRoute else { return }
        shownRoute = route

        map.removeOverlays(routeOverlays)
        routeOverlays = []
        pathRenderers = []
        arrowsRenderer = nil
        routeStopsRenderer = nil
        followed = nil
        busAlong = nil
        passedCount = 0
        relocateBus = true
        endGlide()

        guard let route, let followed = FollowedRoute(route) else { return }
        self.followed = followed
        updateProgress()

        let colour = rgb(hex: route.colour) ?? Paint.red
        let textColour = rgb(hex: route.textColour) ?? Paint.white
        let points = route.points.map { MKMapPoint($0.location) }
        let paths = [RoutePart.beyond, .travelled, .edge, .ahead].map { part in
            let path = RoutePath(points: points, count: points.count)
            path.part = part
            return path
        }
        let arrows = RouteArrows(route: followed, progress: progress, points: points, colour: colour, textColour: textColour)
        let stops = RouteStops(route: followed, progress: progress, points: points, colour: colour, textColour: textColour)

        map.addOverlays(paths, level: .aboveRoads)
        map.addOverlay(arrows, level: .aboveRoads)
        map.addOverlay(stops, level: .aboveLabels)
        routeOverlays = paths + [arrows, stops]
    }

    func show(bus: BusPosition?, on map: MKMapView) {
        guard bus != lastBus || relocateBus else { return }
        lastBus = bus
        relocateBus = false

        guard let bus else {
            endGlide()
            busAlong = nil
            updateProgress()
            if busShown {
                map.removeAnnotation(busMarker)
                busShown = false
            }
            return
        }

        let reported = Coordinate(lat: bus.lat, lon: bus.lon)
        if let followed, let fresh = followed.track.locate(reported, after: busAlong, heading: busAlong == nil ? bus.bearing : nil) {
            switch nextMove(from: busAlong, to: fresh) {
            case let .glide(from, to):
                startGlide(from: from, to: to)
            case .hold:
                break
            case let .jump(to):
                endGlide()
                place(along: to)
            }
            return
        }

        endGlide()
        busMarker.bearing = bus.bearing ?? busMarker.bearing

        guard busShown else {
            busMarker.coordinate = reported.location
            map.addAnnotation(busMarker)
            busShown = true
            return
        }

        let from = Coordinate(lat: busMarker.coordinate.latitude, lon: busMarker.coordinate.longitude)
        let view = map.view(for: busMarker) as? BusView
        let zoom = currentZoom(of: map)
        let bearing = busMarker.bearing

        if shouldSlide(from: from, to: reported) {
            UIView.animate(withDuration: RouteLook.glideSeconds) {
                self.busMarker.coordinate = reported.location
                view?.update(bearing: bearing, zoom: zoom)
            }
        } else {
            busMarker.coordinate = reported.location
            view?.update(bearing: bearing, zoom: zoom)
        }
    }

    private func place(along: Double) {
        guard let followed, let map else { return }
        busAlong = along
        busMarker.coordinate = followed.track.coordinate(at: along).location
        busMarker.bearing = followed.track.heading(at: along)

        if busShown {
            (map.view(for: busMarker) as? BusView)?.update(bearing: busMarker.bearing, zoom: currentZoom(of: map))
        } else {
            map.addAnnotation(busMarker)
            busShown = true
        }

        updateProgress()
    }

    private func startGlide(from: Double, to: Double) {
        glide = (from, to, CACurrentMediaTime())
        guard displayLink == nil else { return }

        let link = CADisplayLink(target: self, selector: #selector(stepGlide))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func stepGlide() {
        guard let glide else {
            endGlide()
            return
        }

        let t = min(1, (CACurrentMediaTime() - glide.start) / RouteLook.glideSeconds)
        place(along: glide.from + (glide.to - glide.from) * t * t * (3 - 2 * t))
        if t >= 1 { endGlide() }
    }

    private func endGlide() {
        glide = nil
        displayLink?.invalidate()
        displayLink = nil
    }

    private func updateProgress() {
        guard let followed else { return }
        progress.update(bus: busAlong, stop: selectedPlace.flatMap { followed.along(ofStop: $0, after: busAlong) })
        pathRenderers.forEach { applyProgress(to: $0) }
        arrowsRenderer?.setNeedsDisplay()

        let passed = followed.stopAlongs.indices.filter { followed.passed($0, bus: busAlong) }.count
        if passed != passedCount {
            passedCount = passed
            routeStopsRenderer?.setNeedsDisplay()
        }
    }

    private func applyProgress(to renderer: MKPolylineRenderer) {
        guard let followed, let path = renderer.overlay as? RoutePath else { return }
        let snapshot = progress.snapshot
        let bus = CGFloat(followed.track.fraction(at: snapshot.bus ?? 0))
        let stop = max(bus, CGFloat(snapshot.stop.map { followed.track.fraction(at: $0) } ?? 1))

        switch path.part {
        case .travelled:
            renderer.strokeStart = 0
            renderer.strokeEnd = bus
        case .edge, .ahead:
            renderer.strokeStart = bus
            renderer.strokeEnd = stop
        case .beyond:
            renderer.strokeStart = stop
            renderer.strokeEnd = 1
        }
        renderer.setNeedsDisplay()
    }

    private func pathRenderer(for path: RoutePath) -> MKPolylineRenderer {
        let renderer = MKPolylineRenderer(polyline: path)
        let colour = rgb(hex: shownRoute?.colour ?? "") ?? Paint.red
        renderer.lineCap = .round
        renderer.lineJoin = .round

        switch path.part {
        case .travelled:
            renderer.strokeColor = RouteLook.travelled.ui(alpha: 0.85)
            renderer.lineWidth = RouteLook.faded
        case .edge:
            renderer.strokeColor = colour.shaded(by: RouteLook.edgeShade).ui()
            renderer.lineWidth = RouteLook.edge
        case .ahead:
            renderer.strokeColor = colour.ui()
            renderer.lineWidth = RouteLook.line
        case .beyond:
            renderer.strokeColor = colour.ui(alpha: RouteLook.fadedAlpha)
            renderer.lineWidth = RouteLook.faded
        }

        applyProgress(to: renderer)
        pathRenderers.append(renderer)
        return renderer
    }

    func frame(stop: Stop?, bus: BusPosition?, panel: PanelCover, token: Int, on map: MKMapView) {
        let key = FrameKey(stopId: stop?.id, busLat: bus?.lat, busLon: bus?.lon, panel: panel, token: token)
        guard key != framedKey else { return }

        let onlyThePanelMoved = framedKey.map {
            FrameKey(stopId: $0.stopId, busLat: $0.busLat, busLon: $0.busLon, panel: panel, token: $0.token) == key
        } ?? false
        framedKey = key

        guard let stop else { return }

        guard onlyThePanelMoved else {
            applyFrame(stop: stop, bus: bus, panel: panel, on: map)
            return
        }

        Task { @MainActor [weak self, weak map] in
            try? await Task.sleep(for: .milliseconds(340))
            guard let self, let map, self.framedKey == key else { return }
            self.applyFrame(stop: stop, bus: bus, panel: panel, on: map)
        }
    }

    private func applyFrame(stop: Stop, bus: BusPosition?, panel: PanelCover, on map: MKMapView) {
        let width = Double(map.bounds.width)
        let height = Double(map.bounds.height)
        guard width > 0, height > 0 else { return }

        let covered: Double = switch panel {
        case .none: 0
        case .open: height * 0.55
        case .closed: 80
        }
        let insets = framePadding(width: width, height: height, covered: covered)
        let target: PlaneRect

        if let bus {
            guard let frame = frameAround([Coordinate(lat: stop.lat, lon: stop.lon), Coordinate(lat: bus.lat, lon: bus.lon)]) else { return }
            let southWest = MKMapPoint(CLLocationCoordinate2D(latitude: frame.southWest.lat, longitude: frame.southWest.lon))
            let northEast = MKMapPoint(CLLocationCoordinate2D(latitude: frame.northEast.lat, longitude: frame.northEast.lon))
            let box = PlaneRect(x: southWest.x, y: northEast.y, width: northEast.x - southWest.x, height: southWest.y - northEast.y)
            target = fittedRect(box, width: width, height: height, insets: insets, maxZoom: frameMaxZoom)
        } else {
            let point = MKMapPoint(CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon))
            let spot = PlaneRect(x: point.x, y: point.y, width: 0, height: 0)
            target = fittedRect(spot, width: width, height: height, insets: insets, maxZoom: frameStopZoom)
        }

        map.setVisibleMapRect(MKMapRect(x: target.x, y: target.y, width: target.width, height: target.height), animated: true)
    }

    private func currentZoom(of map: MKMapView) -> Double {
        guard map.visibleMapRect.width > 0 else { return 15 }
        return mapZoom(zoomScale: Double(map.bounds.width) / map.visibleMapRect.width)
    }

    @objc func tapped(_ tap: UITapGestureRecognizer) {
        guard let map = tap.view as? MKMapView, let stopsOverlay else { return }
        if stopsOverlay.muted, MapStyle.mutedStopAlpha.at(currentZoom(of: map)) == 0 { return }
        let touch = MKMapPoint(map.convert(tap.location(in: map), toCoordinateFrom: map))
        let mapPointsPerScreenPoint = map.visibleMapRect.width / Double(map.bounds.width)
        if let stop = stopsOverlay.nearest(to: touch, within: 22 * mapPointsPerScreenPoint) {
            onSelectStop(stop)
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard !centredOnUser, selectedId == nil, let location = userLocation.location else { return }
        centredOnUser = true
        mapView.setRegion(
            MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 900, longitudinalMeters: 900),
            animated: true
        )
    }

    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        guard busShown, let view = mapView.view(for: busMarker) as? BusView else { return }
        view.update(bearing: busMarker.bearing, zoom: currentZoom(of: mapView))
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
        switch overlay {
        case let path as RoutePath:
            return pathRenderer(for: path)
        case let arrows as RouteArrows:
            let renderer = RouteArrowsRenderer(arrows: arrows)
            arrowsRenderer = renderer
            return renderer
        case let stops as RouteStops:
            let renderer = RouteStopsRenderer(stops: stops)
            routeStopsRenderer = renderer
            return renderer
        case let stops as StopsOverlay:
            return StopsRenderer(stops: stops)
        default:
            return MKOverlayRenderer(overlay: overlay)
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case is SelectedStopAnnotation:
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "selected")
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: "selected")
            view.annotation = annotation
            view.image = MapPalette.selectedPin
            view.centerOffset = CGPoint(x: 0, y: MapPalette.selectedPin.size.height / 2 - MapPalette.pinAnchor)
            view.displayPriority = .required
            view.zPriority = .max
            return view
        case is BusAnnotation:
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "bus") as? BusView
                ?? BusView(annotation: annotation, reuseIdentifier: "bus")
            view.annotation = annotation
            view.displayPriority = .required
            view.zPriority = .max
            view.update(bearing: busMarker.bearing, zoom: currentZoom(of: mapView))
            return view
        default:
            return nil
        }
    }
}

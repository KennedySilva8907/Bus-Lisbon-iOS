import BackgroundTasks
import Foundation
import Observation
import UserNotifications
import BusLisbonCore

struct ArrivalAlert: Codable, Identifiable, Equatable {
    let id: String
    let stopId: String
    let stopName: String
    let lineId: String
    let headsign: String
    let minutesBefore: Int
    let follow: FollowTarget
    var arrivalUnix: Int
    var fireUnix: Int
}

@Observable
@MainActor
final class NotificationRoute {
    static let shared = NotificationRoute()

    var opened: ArrivalAlert?
}

@Observable
@MainActor
final class ArrivalAlerts {
    static let shared = ArrivalAlerts()
    static let refreshTask = "pt.kennedysilva.buslisbon.alerts"
    private static let key = "arrivalAlerts"

    private(set) var alerts: [ArrivalAlert] = ArrivalAlerts.load()

    func alert(for arrival: Arrival) -> ArrivalAlert? {
        alerts.first { $0.id == arrival.id }
    }

    func schedule(_ arrival: Arrival, at stop: Stop, minutesBefore: Int) async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        let arrivalUnix = arrivalTime(arrival)
        let alert = ArrivalAlert(
            id: arrival.id,
            stopId: stop.id,
            stopName: stop.name,
            lineId: arrival.lineId,
            headsign: arrival.headsign,
            minutesBefore: minutesBefore,
            follow: FollowTarget(
                vehicleId: arrival.vehicleId,
                tripId: arrival.tripId,
                lineId: arrival.lineId,
                patternId: arrival.patternId,
                scheduledUnix: arrival.scheduledUnix
            ),
            arrivalUnix: arrivalUnix,
            fireUnix: alertFireUnix(arrivalUnix: arrivalUnix, minutesBefore: minutesBefore)
        )

        alerts.removeAll { $0.id == alert.id }
        alerts.append(alert)
        save()
        await post(alert)
        return true
    }

    func cancel(_ id: String) {
        alerts.removeAll { $0.id == id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        save()
    }

    func refresh(stopId: String, arrivals: [Arrival], now: Int) async {
        for alert in alerts where alert.stopId == stopId {
            let arrival = arrivals.first { $0.id == alert.id }

            switch updateAlert(fireUnix: alert.fireUnix, minutesBefore: alert.minutesBefore, arrival: arrival, now: now) {
            case .keep:
                continue
            case .drop:
                forget(alert.id)
            case let .move(to):
                var moved = alert
                moved.fireUnix = to
                moved.arrivalUnix = arrival.map(arrivalTime) ?? alert.arrivalUnix
                alerts = alerts.map { $0.id == moved.id ? moved : $0 }
                save()
                await post(moved)
            }
        }
    }

    func refreshAll() async {
        let now = Int(Date().timeIntervalSince1970)

        for alert in alerts where alert.fireUnix <= now {
            forget(alert.id)
        }

        for stopId in Set(alerts.map(\.stopId)) {
            guard let board = try? await AppServices.api.board(stopId: stopId) else { continue }
            await refresh(stopId: stopId, arrivals: toArrivals(board), now: Int(Date().timeIntervalSince1970))
        }

        planBackgroundRefresh()
    }

    func planBackgroundRefresh() {
        guard !alerts.isEmpty else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func forget(_ id: String) {
        alerts.removeAll { $0.id == id }
        save()
    }

    private func post(_ alert: ArrivalAlert) async {
        let content = UNMutableNotificationContent()
        let minutes = max(1, (alert.arrivalUnix - alert.fireUnix) / 60)
        content.title = "🚌 \(alert.lineId) a chegar"
        content.body = "\(alert.stopName) daqui a ~\(minutes) min · \(alert.headsign)"
        content.sound = .default
        if let encoded = try? JSONEncoder().encode(alert) {
            content.userInfo = ["alert": String(decoding: encoded, as: UTF8.self)]
        }

        let wait = max(1, TimeInterval(alert.fireUnix) - Date().timeIntervalSince1970)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger))
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(alerts), forKey: Self.key)
    }

    private static func load() -> [ArrivalAlert] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ArrivalAlert].self, from: data)) ?? []
    }
}

final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let text = response.notification.request.content.userInfo["alert"] as? String,
              let alert = try? JSONDecoder().decode(ArrivalAlert.self, from: Data(text.utf8)) else { return }

        await MainActor.run { NotificationRoute.shared.opened = alert }
    }
}

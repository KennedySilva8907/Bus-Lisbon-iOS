import SwiftUI
import UserNotifications

@main
struct BusLisbonApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .backgroundTask(.appRefresh(ArrivalAlerts.refreshTask)) {
            await ArrivalAlerts.shared.refreshAll()
        }
    }
}

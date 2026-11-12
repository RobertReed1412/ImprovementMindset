import Foundation
import SwiftData
import UserNotifications

// EventReminders.swift
// -----------------------------------------------------------------------
// Local notifications for calendar events (no server, no push setup).
//
// Approach: "rebuild the next 14 days". Whenever events change or the app
// comes to the foreground, remove every pending event reminder and schedule
// one per upcoming occurrence. That handles every recurrence type
// (incl. every-2-weeks, which iOS can't repeat natively), edits and deletes
// with one code path, and stays under iOS's 64-pending-notification cap.
//
// Permission is asked in context: the first time the user saves an event
// (or taps "Turn on" in Settings), never at launch.
// -----------------------------------------------------------------------

@MainActor
enum EventReminders {
    static let idPrefix = "event-"
    static let horizonDays = 14
    static let maxPending = 60   // iOS keeps at most 64; leave headroom

    static var center: UNUserNotificationCenter { .current() }

    static func status() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Shows the system prompt only if the user hasn't been asked yet.
    @discardableResult
    static func requestPermissionIfNeeded() async -> Bool {
        switch await status() {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// Upcoming (start, event) pairs inside the horizon, soonest first.
    static func upcoming(_ events: [CalendarEvent], from now: Date = Date()) -> [(Date, CalendarEvent)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var out: [(Date, CalendarEvent)] = []
        for offset in 0..<horizonDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            for ev in events where ev.occurs(on: day) {
                if let start = ev.occurrenceStart(on: day), start > now { out.append((start, ev)) }
            }
        }
        return Array(out.sorted { $0.0 < $1.0 }.prefix(maxPending))
    }

    /// Rebuilds all pending event reminders. Safe to call often.
    static func reschedule(context: ModelContext) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) })

        let allowed = await status()
        guard allowed == .authorized || allowed == .provisional else { return }
        guard let events = try? context.fetch(FetchDescriptor<CalendarEvent>()) else { return }

        let cal = Calendar.current
        for (start, ev) in upcoming(events) {
            let content = UNMutableNotificationContent()
            content.title = ev.title
            content.body = "Starts now · \(ev.timeLabel)"
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: start)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "\(idPrefix)\(ev.id.uuidString)-\(Int(start.timeIntervalSince1970))"
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    static func pendingCount() async -> Int {
        await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(idPrefix) }.count
    }

    /// Fires a sample reminder in 5 seconds so the user can see it works.
    static func sendTest() async {
        guard await requestPermissionIfNeeded() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Test reminder"
        content.body = "Event reminders are working."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "test-reminder", content: content, trigger: trigger))
    }
}

/// Lets reminders show as a banner even while the app is open.
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationPresenter()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler:
                                            @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

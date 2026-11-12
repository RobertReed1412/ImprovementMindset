import Testing
import Foundation
import SwiftData
@testable import ImprovementMindset

@MainActor
struct FunctionalityPassTests {

    private func context() throws -> ModelContext {
        let c = try ModelContainer(for: Schema(AppSchema.models),
                                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(c)
    }

    private func events(_ ctx: ModelContext, _ type: ActivityType) throws -> [ActivityEvent] {
        try ctx.fetch(FetchDescriptor<ActivityEvent>()).filter { $0.typeRaw == type.rawValue }
    }

    // MARK: Calendar items in the task list

    @Test func calendarItemDropsOffAfterItEnds() {
        let cal = Calendar.current
        let nine = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let ev = CalendarEvent(title: "Therapy", startDate: nine, durationMinutes: 60)
        let at = { (h: Int, m: Int) in cal.date(bySettingHour: h, minute: m, second: 0, of: Date())! }

        #expect(TodayCalendarItems.items(from: [ev], now: at(8, 0)).count == 1)   // upcoming
        #expect(TodayCalendarItems.items(from: [ev], now: at(9, 30)).count == 1)  // in progress
        #expect(TodayCalendarItems.items(from: [ev], now: at(10, 1)).isEmpty)     // ended → gone
    }

    @Test func calendarItemsSortedAndOnlyToday() {
        let cal = Calendar.current
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let eight = cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: noon)!
        let weeklyFromLastWeek = cal.date(byAdding: .day, value: -7, to: eight)!
        let items = TodayCalendarItems.items(from: [
            CalendarEvent(title: "Lunch", startDate: noon),
            CalendarEvent(title: "Tomorrow", startDate: tomorrow),
            CalendarEvent(title: "Gym", startDate: weeklyFromLastWeek, recurrence: .weekly),
        ], now: cal.startOfDay(for: Date()))
        #expect(items.map(\.event.title) == ["Gym", "Lunch"])
    }

    @Test func remindersCoverRecurringEventsWithinHorizon() {
        let cal = Calendar.current
        let start = cal.date(byAdding: .hour, value: 1, to: Date())!
        let daily = CalendarEvent(title: "Meds", startDate: start, recurrence: .daily)
        let upcoming = EventReminders.upcoming([daily])
        #expect(upcoming.count == EventReminders.horizonDays)
        #expect(upcoming.allSatisfy { $0.0 > Date() })
    }

    // MARK: Daily maintenance + activity log

    @Test func missedDailyTaskIsLoggedAndNotEscalatedWhenDone() throws {
        let ctx = try context()
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!

        let skipped = TaskItem(title: "Skipped", kind: .daily)
        skipped.lastResetDay = yesterday; skipped.lastEscalationDay = yesterday
        let finished = TaskItem(title: "Finished", kind: .daily)
        finished.lastResetDay = yesterday; finished.lastEscalationDay = yesterday
        finished.isDone = true; finished.completedAt = yesterday
        ctx.insert(skipped); ctx.insert(finished)

        DailyMaintenance.run(context: ctx)

        let missed = try events(ctx, .taskMissed)
        #expect(missed.map(\.title) == ["Skipped"])
        #expect(missed.first?.occurredAt == yesterday)
        #expect(skipped.importance == 2)
        #expect(finished.importance == 1, "finished daily tasks no longer escalate")
        #expect(finished.isDone == false && finished.completedAt == nil)

        DailyMaintenance.run(context: ctx)   // second run same day: no duplicates
        #expect(try events(ctx, .taskMissed).count == 1)
    }

    @Test func activityEventRoundTripsMetadata() throws {
        let ctx = try context()
        let task = TaskItem(title: "Deep work", kind: .oneTime, difficulty: .hard, xp: 90)
        ActivityLog.task(.taskCompleted, task, extra: ["minutes_vs_due": "-15"], in: ctx)
        let e = try #require(try events(ctx, .taskCompleted).first)
        #expect(e.area == .tasks && e.value == 90)
        #expect(e.metadata["difficulty"] == "hard")
        #expect(e.metadata["minutes_vs_due"] == "-15")
        #expect(e.syncedAt == nil)
    }

    // MARK: Home layout

    @Test func homeLayoutDefaultsAndUnknownIDsSurvive() throws {
        let ctx = try context()
        let layout = HomeLayoutStore.layout(context: ctx)
        #expect(layout.sections == HomeSection.defaults)

        layout.sectionIDs.append("widget.from_future_version")
        layout.setSections([HomeSection(.notesWidget)])
        #expect(layout.sections == [HomeSection(.notesWidget)])
        #expect(layout.sectionIDs.contains("widget.from_future_version"))
        #expect(HomeLayoutStore.layout(context: ctx) === layout, "only one layout row")
    }
}

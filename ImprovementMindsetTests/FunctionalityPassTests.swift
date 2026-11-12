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
        // Starts tomorrow at noon (independent of the current time of day),
        // so the 14-day window holds days 1...13.
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let start = cal.date(bySettingHour: 12, minute: 0, second: 0, of: tomorrow)!
        let daily = CalendarEvent(title: "Meds", startDate: start, recurrence: .daily)
        let upcoming = EventReminders.upcoming([daily])
        #expect(upcoming.count == EventReminders.horizonDays - 1)
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

    // MARK: Finished / done for now / subtasks

    private var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
    }

    @Test func finishedOneTimeRootsClearAtMidnightWithSubtasks() throws {
        let ctx = try context()
        let root = TaskItem(title: "Ship it", kind: .oneTime)
        let sub = TaskItem(title: "Write tests", kind: .oneTime)
        ctx.insert(root); ctx.insert(sub); sub.parent = root
        root.isDone = true; root.completedAt = yesterday
        root.lastEscalationDay = yesterday

        // A finished subtask under an UNfinished root must stay attached.
        let open = TaskItem(title: "Group project", kind: .oneTime)
        let doneSub = TaskItem(title: "Research", kind: .oneTime)
        ctx.insert(open); ctx.insert(doneSub); doneSub.parent = open
        doneSub.isDone = true; doneSub.completedAt = yesterday

        DailyMaintenance.run(context: ctx)
        let titles = Set(try ctx.fetch(FetchDescriptor<TaskItem>()).map(\.title))
        #expect(titles == ["Group project", "Research"])
    }

    @Test func finishedTodayIsNotCleared() throws {
        let ctx = try context()
        let t = TaskItem(title: "Today", kind: .oneTime)
        ctx.insert(t)
        TaskActions.finish(t, context: ctx)
        DailyMaintenance.run(context: ctx)
        #expect(try ctx.fetch(FetchDescriptor<TaskItem>()).count == 1)
    }

    @Test func doneForNowComesBackAtSameImportance() throws {
        let ctx = try context()
        let t = TaskItem(title: "Group project", kind: .oneTime, dueClockMinutes: 17 * 60, importance: 4)
        ctx.insert(t)
        t.doneForNowAt = yesterday.addingTimeInterval(3600)
        t.lastEscalationDay = yesterday
        DailyMaintenance.run(context: ctx)
        #expect(t.doneForNowAt == nil, "back in To Do")
        #expect(t.importance == 4, "same importance")
        #expect(try events(ctx, .taskMissed).isEmpty, "a worked-on day isn't missed")

        // Control: same task NOT worked on yesterday escalates + is missed.
        let skipped = TaskItem(title: "Skipped", kind: .oneTime, dueClockMinutes: 17 * 60, importance: 4)
        ctx.insert(skipped); skipped.lastEscalationDay = yesterday
        DailyMaintenance.run(context: ctx)
        #expect(skipped.importance == 5)
        #expect(try events(ctx, .taskMissed).count == 1)
    }

    @Test func dailyDoneForNowIsNotMissed() throws {
        let ctx = try context()
        let t = TaskItem(title: "Practice", kind: .daily)
        ctx.insert(t)
        t.lastResetDay = yesterday; t.lastEscalationDay = yesterday
        t.doneForNowAt = yesterday.addingTimeInterval(3600)
        DailyMaintenance.run(context: ctx)
        #expect(try events(ctx, .taskMissed).isEmpty)
        #expect(t.importance == 1)
    }

    @Test func finishAndReopenMoveXPAndDoneForNowAwardsNone() throws {
        let ctx = try context()
        let t = TaskItem(title: "Run", kind: .oneTime, xp: 50)
        ctx.insert(t)
        let profile = DailyMaintenance.profile(context: ctx)
        TaskActions.doneForNow(t, context: ctx)
        #expect(profile.totalXP == 0 && t.isDoneForNow && t.isSettledToday)
        TaskActions.reopen(t, context: ctx)
        #expect(!t.isSettledToday)
        TaskActions.finish(t, context: ctx)
        #expect(profile.totalXP == 50 && t.isDone)
        TaskActions.reopen(t, context: ctx)
        #expect(profile.totalXP == 0 && !t.isDone)
    }

    @Test func subtaskDepthLimitAndCascadeDelete() throws {
        let ctx = try context()
        var chain = [TaskItem(title: "L0", kind: .oneTime)]
        ctx.insert(chain[0])
        for i in 1...3 {
            let c = TaskItem(title: "L\(i)", kind: .oneTime)
            ctx.insert(c); c.parent = chain.last
            chain.append(c)
        }
        #expect(chain.map(\.depth) == [0, 1, 2, 3])
        #expect(chain.map(\.canAddSubtask) == [true, true, true, false])
        #expect(chain[0].flattenedSubtasks.map(\.task.title) == ["L1", "L2", "L3"])
        TaskActions.delete(chain[0], context: ctx)
        #expect(try ctx.fetch(FetchDescriptor<TaskItem>()).isEmpty, "subtasks go with their root")
    }

    @Test func editingRootKindUpdatesSubtasks() throws {
        let ctx = try context()
        let root = TaskItem(title: "Root", kind: .oneTime)
        let sub = TaskItem(title: "Sub", kind: .oneTime)
        ctx.insert(root); ctx.insert(sub); sub.parent = root
        var draft = TaskDraft(task: root)
        draft.kind = .daily
        draft.apply(to: root)
        #expect(root.kind == .daily && sub.kind == .daily)
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

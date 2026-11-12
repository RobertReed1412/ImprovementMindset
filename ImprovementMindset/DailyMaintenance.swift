import Foundation
import SwiftData

enum DailyMaintenance {

    /// Runs at launch, on every return to the foreground, and at midnight.
    /// Safe to run any number of times per day.
    static func run(context: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let descriptor = FetchDescriptor<TaskItem>()
        guard let tasks = try? context.fetch(descriptor) else { return }
        var toClear: [TaskItem] = []

        for task in tasks {
            let wasDone = task.isDone

            // "Done for now" on an earlier day: the task comes back to To Do.
            // The day it was worked on doesn't count as missed and doesn't
            // raise importance ("comes back at the same importance").
            var workedDay: Date?
            if let d = task.doneForNowAt, cal.startOfDay(for: d) < today {
                workedDay = cal.startOfDay(for: d)
                task.doneForNowAt = nil
            }

            // Daily reset. Before clearing, log every day this task was missed:
            // the last reset day (unless done or worked on) plus any days the
            // app wasn't opened at all. Capped so a long absence can't flood the log.
            if task.kind == .daily && task.lastResetDay < today {
                let settled = wasDone || workedDay == task.lastResetDay
                var missed: [Date] = settled ? [] : [task.lastResetDay]
                var d = cal.date(byAdding: .day, value: 1, to: task.lastResetDay) ?? today
                while d < today && missed.count < 30 {
                    missed.append(d)
                    d = cal.date(byAdding: .day, value: 1, to: d) ?? today
                }
                for day in missed {
                    ActivityLog.task(.taskMissed, task, at: day,
                                     extra: ["missed_day": day.formatted(.iso8601.year().month().day())],
                                     in: context)
                }
                task.isDone = false
                task.completedAt = nil
                task.lastResetDay = today
            }

            // Importance escalation: bump once per new day it was left
            // unfinished. Days up to and including a "done for now" day don't count.
            var escalateFrom = task.lastEscalationDay
            if let w = workedDay, let after = cal.date(byAdding: .day, value: 1, to: w) {
                escalateFrom = max(escalateFrom, after)
            }
            if !wasDone && escalateFrom < today {
                let daysElapsed = cal.dateComponents([.day], from: escalateFrom, to: today).day ?? 1
                // One-time tasks with a deadline count as missed once per day
                // they roll over. (Daily tasks were logged above.)
                if task.kind == .oneTime, task.dueClockMinutes != nil {
                    ActivityLog.task(.taskMissed, task, at: escalateFrom,
                                     extra: ["days_overdue": String(max(1, daysElapsed))],
                                     in: context)
                }
                task.importance += max(1, daysElapsed)
            }
            task.lastEscalationDay = max(task.lastEscalationDay, today)

            // Finished one-time ROOT tasks are cleared at midnight. Their
            // history stays in the ActivityEvent log. Subtasks are never
            // cleared on their own; they go when their root goes.
            if task.kind == .oneTime, task.parent == nil, wasDone,
               let done = task.completedAt, done < today {
                toClear.append(task)
            }
        }

        for task in toClear { context.delete(task) }   // cascades to subtasks
        try? context.save()
    }

    /// Runs maintenance at each midnight while the app is open, so Completed
    /// clears and "done for now" tasks come back without reopening the app.
    static func midnightLoop(context: ModelContext) async {
        while !Task.isCancelled {
            let cal = Calendar.current
            guard let next = cal.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0, second: 1),
                                          matchingPolicy: .nextTime) else { return }
            try? await Task.sleep(for: .seconds(max(1, next.timeIntervalSinceNow)))
            if Task.isCancelled { return }
            run(context: context)
        }
    }

    static func calorieDay(context: ModelContext) -> CalorieDay {
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<CalorieDay>(
            predicate: #Predicate { $0.day == today })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let fresh = CalorieDay(day: today)
        context.insert(fresh)
        try? context.save()
        return fresh
    }

    static func profile(context: ModelContext) -> PlayerProfile {
        let descriptor = FetchDescriptor<PlayerProfile>()
        if let existing = try? context.fetch(descriptor).first { return existing }
        let p = PlayerProfile()
        context.insert(p)
        try? context.save()
        return p
    }
}

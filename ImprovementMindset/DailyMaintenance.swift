import Foundation
import SwiftData

enum DailyMaintenance {

    static func run(context: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let descriptor = FetchDescriptor<TaskItem>()
        guard let tasks = try? context.fetch(descriptor) else { return }

        for task in tasks {
            let wasDone = task.isDone

            // Daily reset. Before clearing, log every day this task was missed:
            // the last reset day (if it wasn't done) plus any days the app wasn't
            // opened at all. Capped so a long absence can't flood the log.
            if task.kind == .daily && task.lastResetDay < today {
                var missed: [Date] = wasDone ? [] : [task.lastResetDay]
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

            // Importance escalation: bump once per new day if it was left
            // unfinished. (Fix: a daily task finished yesterday used to be
            // reset first and then escalated anyway; we now check `wasDone`.)
            if !wasDone && task.lastEscalationDay < today {
                let daysElapsed = cal.dateComponents(
                    [.day], from: task.lastEscalationDay, to: today).day ?? 1
                // One-time tasks with a deadline count as missed once per day
                // they roll over. (Daily tasks were logged above.)
                if task.kind == .oneTime, task.dueClockMinutes != nil {
                    ActivityLog.task(.taskMissed, task, at: task.lastEscalationDay,
                                     extra: ["days_overdue": String(max(1, daysElapsed))],
                                     in: context)
                }
                task.importance += max(1, daysElapsed)
            }
            task.lastEscalationDay = max(task.lastEscalationDay, today)
        }

        try? context.save()
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

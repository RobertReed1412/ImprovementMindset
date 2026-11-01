import Foundation
import SwiftData

enum DailyMaintenance {

    static func run(context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())

        let descriptor = FetchDescriptor<TaskItem>()
        guard let tasks = try? context.fetch(descriptor) else { return }

        for task in tasks {
            // Daily reset
            if task.kind == .daily && task.lastResetDay < today {
                task.isDone = false
                task.lastResetDay = today
            }

            // Importance escalation: bump once per new day if still unfinished.
            if !task.isDone && task.lastEscalationDay < today {
                let daysElapsed = Calendar.current.dateComponents(
                    [.day], from: task.lastEscalationDay, to: today).day ?? 1
                task.importance += max(1, daysElapsed)
                task.lastEscalationDay = today
            }
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

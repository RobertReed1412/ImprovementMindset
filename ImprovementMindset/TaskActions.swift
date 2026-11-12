import Foundation
import SwiftData

// TaskActions.swift
// -----------------------------------------------------------------------
// The one place task state changes happen, so every screen (task columns,
// subtasks, widget) behaves the same and logs the same events.
//
//  • Finished      → done for good. Awards XP. One-time root tasks are
//                    cleared at midnight; daily tasks reset as before.
//  • Done for now  → worked on today. Shows as completed today, then comes
//                    back to To Do tomorrow at the SAME importance. No XP.
//  • Reopen        → undo either of the above (finished XP is taken back).
// -----------------------------------------------------------------------

@MainActor
enum TaskActions {

    static func finish(_ task: TaskItem, context: ModelContext) {
        guard !task.isDone else { return }
        let now = Date()
        task.isDone = true
        task.completedAt = now
        task.doneForNowAt = nil
        DailyMaintenance.profile(context: context).totalXP += task.xp
        var extra: [String: String] = [:]
        if let due = task.dueClockMinutes {
            let c = Calendar.current.dateComponents([.hour, .minute], from: now)
            extra["minutes_vs_due"] = String((c.hour ?? 0) * 60 + (c.minute ?? 0) - due)  // negative = early
        }
        ActivityLog.task(.taskCompleted, task, at: now, extra: extra, in: context)
        try? context.save()
    }

    static func doneForNow(_ task: TaskItem, context: ModelContext) {
        guard !task.isDone else { return }
        task.doneForNowAt = Date()
        ActivityLog.task(.taskDoneForNow, task, in: context)
        try? context.save()
    }

    static func reopen(_ task: TaskItem, context: ModelContext) {
        if task.isDone {
            let profile = DailyMaintenance.profile(context: context)
            profile.totalXP = max(0, profile.totalXP - task.xp)
            task.isDone = false
            task.completedAt = nil
            ActivityLog.task(.taskUncompleted, task, in: context)
        }
        task.doneForNowAt = nil
        try? context.save()
    }

    /// Deletes the task and (by cascade) all of its subtasks.
    static func delete(_ task: TaskItem, context: ModelContext) {
        ActivityLog.task(.taskDeleted, task, in: context)
        context.delete(task)
        try? context.save()
    }
}

/// The editable fields of a task, shared by the full form and the widget.
struct TaskDraft {
    var title = ""
    var kind: TaskKind = .oneTime
    var minutes = 15
    var difficulty: Difficulty = .medium
    var anytime = true
    var dueTime = Date()
    var importance = 1

    init(kind: TaskKind = .oneTime) { self.kind = kind }

    init(task: TaskItem) {
        title = task.title
        kind = task.kind
        minutes = task.timeEstimateMinutes
        difficulty = task.difficulty
        importance = task.importance
        if let m = task.dueClockMinutes {
            anytime = false
            dueTime = Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
        }
    }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var dueClockMinutes: Int? {
        guard !anytime else { return nil }
        let c = Calendar.current.dateComponents([.hour, .minute], from: dueTime)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    var formulaXP: Int {
        LocalXPService.heuristicXP(difficulty: difficulty, timeEstimateMinutes: minutes, importance: importance)
    }

    /// True if anything that feeds the XP score differs from `task`.
    func changesXPInputs(of task: TaskItem) -> Bool {
        minutes != task.timeEstimateMinutes || difficulty != task.difficulty || importance != task.importance
    }

    func makeTask(xp: Int) -> TaskItem {
        TaskItem(title: trimmedTitle, kind: kind, timeEstimateMinutes: minutes,
                 difficulty: difficulty, dueClockMinutes: dueClockMinutes,
                 importance: importance, xp: xp)
    }

    func apply(to task: TaskItem) {
        task.title = trimmedTitle
        task.timeEstimateMinutes = minutes
        task.difficultyRaw = difficulty.rawValue
        task.dueClockMinutes = dueClockMinutes
        task.importance = importance
        // Subtasks always share their root's kind (daily vs one-time).
        if task.parent == nil, task.kindRaw != kind.rawValue {
            task.kindRaw = kind.rawValue
            for sub in task.flattenedSubtasks { sub.task.kindRaw = kind.rawValue }
        }
    }
}

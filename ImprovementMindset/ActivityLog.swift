import Foundation
import SwiftData

// ActivityLog.swift
// -----------------------------------------------------------------------
// ONE append-only history of everything the user does, in one table.
// This is the data the future AI coach reads ("when do I actually finish
// hard tasks?", "which goals stall?") and what accountability groups will
// read for check-ins. Every feature writes here through `ActivityLog.record`.
//
// Rules:
//  • Raw values below are persisted and will be synced to Supabase.
//    Never rename or remove a case; only add new ones.
//  • Rows are never edited after insert. `syncedAt` is the only field that
//    changes (set by a future uploader once the row is on the server).
// -----------------------------------------------------------------------

/// What happened.
enum ActivityType: String, Codable, CaseIterable {
    case taskCreated         = "task_created"
    case taskCompleted       = "task_completed"
    case taskUncompleted     = "task_uncompleted"
    case taskMissed          = "task_missed"
    case taskDeleted         = "task_deleted"
    case taskDoneForNow      = "task_done_for_now"
    case taskEdited          = "task_edited"
    case noteAdded           = "note_added"
    case circleCreated       = "circle_created"
    case goalCreated         = "goal_created"
    case goalSliderChanged   = "goal_slider_changed"
    case goalMoveAdded       = "goal_move_added"
    case goalAccomplished    = "goal_accomplished"
    case eventCreated        = "event_created"
    case eventDeleted        = "event_deleted"
    case workoutLogged       = "workout_logged"
}

/// Which part of life / the app it belongs to. These are also the
/// "sections" an accountability group can choose to track.
enum ActivityArea: String, Codable, CaseIterable {
    case tasks, calendar, circles, goals, fitness, library, creations, rules
}

@Model
final class ActivityEvent {
    var id: UUID = UUID()
    /// When it happened (for "missed" rows: the start of the missed day).
    var occurredAt: Date = Date()
    var typeRaw: String = ""
    var areaRaw: String = ""
    /// The task / card / goal / event this is about, if any.
    var entityID: UUID?
    /// Human-readable snapshot (task title, circle label…), so history still
    /// reads correctly after the original item is renamed or deleted.
    var title: String = ""
    /// One number that matters for this event (XP earned, slider 0–1, minutes…).
    var value: Double?
    /// Small extra facts as a JSON object of strings, e.g. {"difficulty":"hard"}.
    var metadataJSON: String = "{}"
    /// Set once uploaded to Supabase. nil = not synced yet.
    var syncedAt: Date?

    init(type: ActivityType, area: ActivityArea, entityID: UUID?, title: String,
         value: Double?, occurredAt: Date, metadata: [String: String]) {
        self.id = UUID()
        self.occurredAt = occurredAt
        self.typeRaw = type.rawValue
        self.areaRaw = area.rawValue
        self.entityID = entityID
        self.title = title
        self.value = value
        let data = (try? JSONEncoder().encode(metadata)) ?? Data("{}".utf8)
        self.metadataJSON = String(decoding: data, as: UTF8.self)
    }

    var type: ActivityType? { ActivityType(rawValue: typeRaw) }
    var area: ActivityArea? { ActivityArea(rawValue: areaRaw) }
    var metadata: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(metadataJSON.utf8))) ?? [:]
    }
}

@MainActor
enum ActivityLog {

    /// Appends one event. The caller saves the context (most call sites
    /// already save right after their own change).
    static func record(_ type: ActivityType,
                       area: ActivityArea,
                       entityID: UUID? = nil,
                       title: String,
                       value: Double? = nil,
                       at date: Date = Date(),
                       metadata: [String: String] = [:],
                       in context: ModelContext) {
        context.insert(ActivityEvent(type: type, area: area, entityID: entityID,
                                     title: title, value: value,
                                     occurredAt: date, metadata: metadata))
    }

    /// The task facts the scheduling coach will learn from.
    static func taskMetadata(_ task: TaskItem) -> [String: String] {
        var m: [String: String] = [
            "kind": task.kindRaw,
            "difficulty": task.difficultyRaw,
            "estimate_minutes": String(task.timeEstimateMinutes),
            "importance": String(task.importance),
            "xp": String(task.xp),
        ]
        if let due = task.dueClockMinutes { m["due_clock_minutes"] = String(due) }
        if let parent = task.parent {
            m["parent_id"] = parent.id.uuidString
            m["depth"] = String(task.depth)
        }
        return m
    }

    /// Records a task event with its standard metadata.
    static func task(_ type: ActivityType, _ task: TaskItem,
                     at date: Date = Date(), extra: [String: String] = [:],
                     in context: ModelContext) {
        record(type, area: .tasks, entityID: task.id, title: task.title,
               value: type == .taskCompleted ? Double(task.xp) : nil,
               at: date,
               metadata: taskMetadata(task).merging(extra) { _, new in new },
               in: context)
    }
}

/// Every SwiftData model the app stores. The real container, the UI-test
/// container and the preview container all use this list, so they can't drift.
enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        TaskItem.self, PlayerProfile.self,
        CalorieDay.self, WorkoutEntry.self,
        ShelfItem.self,
        Circle.self, CircleCard.self,
        Strike.self, RulesConfig.self,
        Goal.self, GoalMove.self,
        CalendarEvent.self,
        ActivityEvent.self,
        HomeLayoutRecord.self,
    ]
}

import Foundation
import SwiftData

// MARK: - Shared enums

enum TaskKind: String, Codable, CaseIterable {
    case daily      // resets to unchecked every day
    case oneTime    // persists until completed, then removed
}

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard, brutal
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var xpMultiplier: Double {
        switch self {
        case .easy: return 1.0
        case .medium: return 1.5
        case .hard: return 2.25
        case .brutal: return 3.5
        }
    }
}

// MARK: - Task

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var kindRaw: String
    var isDone: Bool

    var timeEstimateMinutes: Int

    var difficultyRaw: String

    // nil == Anytime; otherwise minutes-from-midnight for the deadline clock time
    var dueClockMinutes: Int?

    // Importance auto-raises each day a task is left unfinished
    var importance: Int

    // XP assigned (by on-device model or fallback)
    var xp: Int

    // Bookkeeping for daily reset + importance escalation
    var createdAt: Date
    var lastResetDay: Date
    var lastEscalationDay: Date

    init(title: String,
         kind: TaskKind,
         timeEstimateMinutes: Int = 15,
         difficulty: Difficulty = .medium,
         dueClockMinutes: Int? = nil,
         importance: Int = 1,
         xp: Int = 0) {
        let now = Date()
        let day = Calendar.current.startOfDay(for: now)
        self.id = UUID()
        self.title = title
        self.kindRaw = kind.rawValue
        self.isDone = false
        self.timeEstimateMinutes = timeEstimateMinutes
        self.difficultyRaw = difficulty.rawValue
        self.dueClockMinutes = dueClockMinutes
        self.importance = importance
        self.xp = xp
        self.createdAt = now
        self.lastResetDay = day
        self.lastEscalationDay = day
    }

    var kind: TaskKind { TaskKind(rawValue: kindRaw) ?? .daily }
    var difficulty: Difficulty { Difficulty(rawValue: difficultyRaw) ?? .medium }

    var dueLabel: String {
        guard let m = dueClockMinutes else { return "Anytime" }
        let h = m / 60, min = m % 60
        let ampm = h < 12 ? "AM" : "PM"
        var hh = h % 12; if hh == 0 { hh = 12 }
        return String(format: "%d:%02d %@", hh, min, ampm)
    }
}

// MARK: - Player profile (XP / level)

@Model
final class PlayerProfile {
    var totalXP: Int
    init(totalXP: Int = 0) { self.totalXP = totalXP }

    var level: Int { Int((Double(totalXP) / 100.0).squareRoot()) + 1 }
    var xpIntoLevel: Int {
        let base = (level - 1) * (level - 1) * 100
        return totalXP - base
    }
    var xpForNextLevel: Int {
        let next = level * level * 100
        let base = (level - 1) * (level - 1) * 100
        return next - base
    }
}

// MARK: - Fitness

@Model
final class CalorieDay {
    var day: Date
    var calories: Int
    init(day: Date, calories: Int = 0) {
        self.day = Calendar.current.startOfDay(for: day)
        self.calories = calories
    }
}

/// The fixed set of workout categories. Raw values are persisted locally and
/// exported to Supabase as `workout_type`, so never rename or remove a case.
enum WorkoutType: String, Codable, CaseIterable, Identifiable {
    case fighting, soccer, lifting, strongman, dancing
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .fighting: return "figure.boxing"
        case .soccer: return "figure.soccer"
        case .lifting: return "dumbbell.fill"
        case .strongman: return "figure.strengthtraining.traditional"
        case .dancing: return "figure.dance"
        }
    }
}

@Model
final class WorkoutEntry {
    var id: UUID
    // Defaults let SwiftData lightweight-migrate entries saved by the old
    // free-text logger. Legacy rows keep an empty type (shown as "Unspecified").
    var typeRaw: String = ""
    var durationMinutes: Int = 0
    // Formerly `text`; old free-text logs carry over as notes.
    @Attribute(originalName: "text") var notes: String = ""
    var performedAt: Date = Date()
    var loggedAt: Date

    init(type: WorkoutType, durationMinutes: Int, notes: String = "", performedAt: Date = Date()) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.performedAt = performedAt
        self.loggedAt = Date()
    }

    var type: WorkoutType? { WorkoutType(rawValue: typeRaw) }

    var durationLabel: String {
        let h = durationMinutes / 60, m = durationMinutes % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h) hr"
        default: return "\(h) hr \(m) min"
        }
    }
}

// MARK: - Shelf items (Library + Creations share this model, split by shelfRaw)

enum ShelfKind: String, Codable {
    case library
    case creations
}

enum SealKind: String, Codable, CaseIterable, Identifiable {
    case none
    case red        // creation completed
    case black      // book read
    case white      // book listened
    var id: String { rawValue }
}

@Model
final class ShelfItem {
    var id: UUID
    var title: String
    var shelfRaw: String
    var imageData: Data?
    var finishedDate: Date
    var sealRaw: String

    init(title: String, shelf: ShelfKind, imageData: Data?,
         finishedDate: Date = Date(), seal: SealKind = .none) {
        self.id = UUID()
        self.title = title
        self.shelfRaw = shelf.rawValue
        self.imageData = imageData
        self.finishedDate = finishedDate
        self.sealRaw = seal.rawValue
    }
    var shelf: ShelfKind { ShelfKind(rawValue: shelfRaw) ?? .library }
    var seal: SealKind {
        get { SealKind(rawValue: sealRaw) ?? .none }
        set { sealRaw = newValue.rawValue }
    }
    var isCompleted: Bool { seal != .none }
}

// MARK: - Circles

@Model
final class Circle {
    var id: UUID
    var label: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \CircleCard.circle)
    var cards: [CircleCard]
    init(label: String) {
        self.id = UUID()
        self.label = label
        self.createdAt = Date()
        self.cards = []
    }
}

@Model
final class CircleCard {
    var id: UUID
    var title: String
    var body: String
    var order: Int
    var createdAt: Date
    var circle: Circle?
    init(title: String = "", body: String = "", order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.order = order
        self.createdAt = Date()
    }
}

// MARK: - Rules / strikes

@Model
final class Strike {
    var id: UUID
    var note: String
    var createdAt: Date
    init(note: String = "") {
        self.id = UUID()
        self.note = note
        self.createdAt = Date()
    }
    var expiresAt: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: createdAt) ?? createdAt
    }
    var isActive: Bool { Date() < expiresAt }
    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0)
    }
}

@Model
final class RulesConfig {
    var punishment: String
    var reward: String
    init(punishment: String = "", reward: String = "") {
        self.punishment = punishment
        self.reward = reward
    }
}

// MARK: - Accomplishments (big-picture goals)

@Model
final class Goal {
    var id: UUID
    var title: String
    var createdAt: Date
    var isAccomplished: Bool
    var accomplishedDate: Date?
    @Relationship(deleteRule: .cascade, inverse: \GoalMove.goal)
    var moves: [GoalMove]
    init(title: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.isAccomplished = false
        self.moves = []
    }
}

@Model
final class GoalMove {
    var id: UUID
    var text: String
    var createdAt: Date
    var goal: Goal?
    init(text: String) {
        self.id = UUID()
        self.text = text
        self.createdAt = Date()
    }
}

// MARK: - Calendar

enum Recurrence: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly, biweekly, monthly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Does not repeat"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 weeks"
        case .monthly: return "Monthly"
        }
    }
}

@Model
final class CalendarEvent {
    var id: UUID
    var title: String
    var startDate: Date
    var durationMinutes: Int
    var recurrenceRaw: String
    var colorHex: Int
    var notes: String
    var recurrenceEndDate: Date?

    init(title: String,
         startDate: Date,
         durationMinutes: Int = 60,
         recurrence: Recurrence = .none,
         colorHex: Int = 0xC9A24B,
         notes: String = "",
         recurrenceEndDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.recurrenceRaw = recurrence.rawValue
        self.colorHex = colorHex
        self.notes = notes
        self.recurrenceEndDate = recurrenceEndDate
    }

    var recurrence: Recurrence { Recurrence(rawValue: recurrenceRaw) ?? .none }

    func occurs(on day: Date) -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let target = cal.startOfDay(for: day)
        if target < start { return false }
        if let end = recurrenceEndDate, target > cal.startOfDay(for: end) { return false }

        switch recurrence {
        case .none:
            return target == start
        case .daily:
            return true
        case .weekly:
            let days = cal.dateComponents([.day], from: start, to: target).day ?? 0
            return days % 7 == 0
        case .biweekly:
            let days = cal.dateComponents([.day], from: start, to: target).day ?? 0
            return days % 14 == 0
        case .monthly:
            return cal.component(.day, from: start) == cal.component(.day, from: target)
        }
    }

    var timeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: startDate)
    }
}

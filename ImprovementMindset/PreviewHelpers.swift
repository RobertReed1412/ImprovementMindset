import SwiftUI
import SwiftData

// PreviewHelpers.swift
// -----------------------------------------------------------------------
// Makes SwiftUI Previews work for every screen in this app.
//
// WHY THIS EXISTS: the views use @Query / SwiftData. A #Preview that just
// returns `SomeView()` will CRASH because there's no ModelContainer in the
// preview environment. This file provides an in-memory container pre-seeded
// with realistic sample data, so previews render instantly with content.
//
// HOW TO USE IN A #Preview:
//     #Preview { HomeView().previewEnv() }
//
// `.previewEnv()` injects the shared in-memory container. Use it on the
// root view inside every #Preview block. Nothing here ships in the app —
// #Preview and this helper are compiled out of release builds.
// -----------------------------------------------------------------------

@MainActor
enum PreviewData {

    /// A single in-memory container reused across previews, seeded once.
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: TaskItem.self, PlayerProfile.self,
            CalorieDay.self, WorkoutEntry.self,
            ShelfItem.self,
            Circle.self, CircleCard.self,
            Strike.self, RulesConfig.self,
            Goal.self, GoalMove.self,
            CalendarEvent.self,
            configurations: config)
        seed(container.mainContext)
        return container
    }()

    private static func seed(_ ctx: ModelContext) {
        // Player / XP
        ctx.insert(PlayerProfile(totalXP: 1240))

        // Daily tasks
        let t1 = TaskItem(title: "Morning workout", kind: .daily,
                          timeEstimateMinutes: 30, difficulty: .hard,
                          dueClockMinutes: 7 * 60, importance: 2, xp: 85)
        let t2 = TaskItem(title: "Read 20 pages", kind: .daily,
                          timeEstimateMinutes: 20, difficulty: .medium,
                          importance: 1, xp: 40)
        t2.isDone = true
        let t3 = TaskItem(title: "Practice keyboard layout", kind: .daily,
                          timeEstimateMinutes: 15, difficulty: .easy,
                          importance: 3, xp: 60)
        // One-time tasks
        let o1 = TaskItem(title: "File taxes", kind: .oneTime,
                          timeEstimateMinutes: 90, difficulty: .brutal,
                          dueClockMinutes: 17 * 60, importance: 4, xp: 200)
        [t1, t2, t3, o1].forEach { ctx.insert($0) }

        // Fitness
        ctx.insert(CalorieDay(day: Date(), calories: 1450))
        ctx.insert(WorkoutEntry(type: .lifting, durationMinutes: 75,
                                notes: "Push day: bench, OHP, dips"))
        ctx.insert(WorkoutEntry(type: .fighting, durationMinutes: 60,
                                notes: "Sparred 5 rounds, worked on jab-cross timing"))
        ctx.insert(WorkoutEntry(type: .soccer, durationMinutes: 90))

        // Shelf items (Library + Creations) with seals
        let b1 = ShelfItem(title: "Dune", shelf: .library, imageData: nil, seal: .black)
        let b2 = ShelfItem(title: "The Hobbit", shelf: .library, imageData: nil, seal: .white)
        let c1 = ShelfItem(title: "Custom Helmet", shelf: .creations, imageData: nil, seal: .red)
        [b1, b2, c1].forEach { ctx.insert($0) }

        // Circles with cards
        let circle = Circle(label: "What is a good life?")
        let card1 = CircleCard(title: "Virtue vs. pleasure",
                               body: "Socrates argues the examined life aims at virtue, not comfort.",
                               order: 0)
        let card2 = CircleCard(title: "Stoic angle",
                               body: "Control what you can; accept the rest.", order: 1)
        card1.circle = circle; card2.circle = circle
        circle.cards = [card1, card2]
        ctx.insert(circle); ctx.insert(card1); ctx.insert(card2)

        // Rules
        ctx.insert(RulesConfig(punishment: "No gaming for the weekend",
                               reward: "New keycap set"))

        // Goals with moves
        let goal = Goal(title: "Ship The Improvement Mindset v1")
        let m1 = GoalMove(text: "Built the core task system"); m1.goal = goal
        let m2 = GoalMove(text: "Added calendar + recurring events"); m2.goal = goal
        goal.moves = [m1, m2]
        ctx.insert(goal); ctx.insert(m1); ctx.insert(m2)

        let goalDone = Goal(title: "Learn SwiftUI basics")
        goalDone.isAccomplished = true
        goalDone.accomplishedDate = Date()
        ctx.insert(goalDone)

        // Calendar events
        let cal = Calendar.current
        let today9 = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        ctx.insert(CalendarEvent(title: "Therapy", startDate: today9,
                                 durationMinutes: 60, recurrence: .weekly,
                                 colorHex: 0x2E9B73))
        ctx.insert(CalendarEvent(title: "Work shift", startDate: today9,
                                 durationMinutes: 480, recurrence: .weekly,
                                 colorHex: 0x9E2024))

        try? ctx.save()
    }
}

extension View {
    /// Inject the shared in-memory preview container. Use inside #Preview.
    @MainActor
    func previewEnv() -> some View {
        self.modelContainer(PreviewData.container)
            .preferredColorScheme(.dark)
            .tint(Theme.Palette.gold)
    }
}

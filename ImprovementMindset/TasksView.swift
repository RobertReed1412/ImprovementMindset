import SwiftUI
import SwiftData

struct TasksView: View {
    let kind: TaskKind
    let navTitle: String
    var body: some View {
        NavigationStack { TasksContent(kind: kind, navTitle: navTitle) }
    }
}

struct TasksContent: View {
    let kind: TaskKind
    let navTitle: String

    @Environment(\.modelContext) private var context
    @Query private var allTasks: [TaskItem]
    @Query private var events: [CalendarEvent]
    @State private var showingAdd = false

    /// Completed one-time tasks stay in the Completed column this long, then
    /// drop off the screen (they stay saved for history / the AI coach).
    private static let completedVisibleDays = 7

    private var mine: [TaskItem] { allTasks.filter { $0.kindRaw == kind.rawValue } }

    private var todo: [TaskItem] {
        mine.filter { !$0.isDone }.sorted { $0.importance > $1.importance }
    }

    private var completed: [TaskItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.completedVisibleDays,
                                           to: Date()) ?? .distantPast
        return mine
            .filter { $0.isDone && ($0.completedAt ?? .distantFuture) >= cutoff }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            XPHeader()

            HStack(alignment: .top, spacing: 10) {
                column("To Do", count: todo.count, id: "todo") {
                    // Re-evaluated every 30s so calendar items vanish once they end.
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        let today = TodayCalendarItems.items(from: events, now: timeline.date)
                        VStack(spacing: 8) {
                            ForEach(today) { CalendarTaskCard(item: $0) }
                        }
                    }
                    ForEach(todo) { task in
                        TaskCard(task: task) { toggle(task) } onDelete: { delete(task) }
                    }
                }
                column("Completed", count: completed.count, id: "completed") {
                    ForEach(completed) { task in
                        TaskCard(task: task) { toggle(task) } onDelete: { delete(task) }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 30)
            .animation(Motion.select, value: allTasks.map(\.isDone))
        }
        .scrollContentBackground(.hidden)
        .nightBackground()
        .navigationTitle(navTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddTaskView(kind: kind)
        }
    }

    private func column<Content: View>(_ title: String, count: Int, id: String,
                                       @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(Theme.display(18, weight: .semibold))
                    .foregroundStyle(Theme.Palette.goldBright)
                Spacer()
                Text("\(count)").font(.caption).foregroundStyle(Theme.Palette.boneDim)
            }
            content()
            if count == 0 {
                Text(id == "todo" ? "Nothing left. Tap + to add." : "Tap a task to complete it.")
                    .font(.caption).foregroundStyle(Theme.Palette.boneDim)
                    .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("column.\(id)")
    }

    /// Tapping moves a task between columns. Un-completing takes the XP back
    /// so tapping back and forth can't farm XP.
    private func toggle(_ task: TaskItem) {
        let profile = DailyMaintenance.profile(context: context)
        if task.isDone {
            task.isDone = false
            task.completedAt = nil
            profile.totalXP = max(0, profile.totalXP - task.xp)
            ActivityLog.task(.taskUncompleted, task, in: context)
        } else {
            let now = Date()
            task.isDone = true
            task.completedAt = now
            profile.totalXP += task.xp
            var extra: [String: String] = [:]
            if let due = task.dueClockMinutes {
                let c = Calendar.current.dateComponents([.hour, .minute], from: now)
                let nowMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
                extra["minutes_vs_due"] = String(nowMinutes - due)   // negative = early
            }
            ActivityLog.task(.taskCompleted, task, at: now, extra: extra, in: context)
        }
        try? context.save()
    }

    private func delete(_ task: TaskItem) {
        ActivityLog.task(.taskDeleted, task, in: context)
        context.delete(task)
        try? context.save()
    }
}

/// One calendar occurrence happening today, shown at the top of To Do.
struct TodayCalendarItem: Identifiable {
    let event: CalendarEvent
    let start: Date
    let end: Date
    var id: String { "\(event.id.uuidString)-\(start.timeIntervalSince1970)" }
}

enum TodayCalendarItems {
    /// Today's occurrences that haven't ended yet, earliest first. Items whose
    /// end time has passed drop off the list (the calendar event itself is kept).
    static func items(from events: [CalendarEvent], now: Date) -> [TodayCalendarItem] {
        events.compactMap { ev -> TodayCalendarItem? in
            guard ev.occurs(on: now), let start = ev.occurrenceStart(on: now) else { return nil }
            let end = start.addingTimeInterval(TimeInterval(ev.durationMinutes * 60))
            return end > now ? TodayCalendarItem(event: ev, start: start, end: end) : nil
        }
        .sorted { $0.start < $1.start }
    }
}

struct CalendarTaskCard: View {
    let item: TodayCalendarItem
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: item.event.colorHex))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.event.timeLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.Palette.gold)
                Text(item.event.title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.bone)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "calendar").font(.caption2).foregroundStyle(Theme.Palette.boneDim)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.nightRaised.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.goldDim.opacity(0.4), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("calendarItem")
    }
}

/// Compact task card sized for one of the two columns.
struct TaskCard: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline)
                        .foregroundStyle(task.isDone ? Theme.Palette.boneDim : Theme.Palette.bone)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    Tag(text: "\(task.timeEstimateMinutes)m · +\(task.xp) XP", system: "star.fill")
                    if !task.isDone && task.dueClockMinutes != nil {
                        Tag(text: task.dueLabel, system: "clock")
                    }
                    if !task.isDone && task.importance > 1 {
                        Tag(text: "Importance \(task.importance)", system: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                Spacer(minLength: 0)
                if task.isDone {
                    // The same seal as the app logo.
                    Image("SealCrest")
                        .resizable().scaledToFit()
                        .frame(width: 30, height: 30)
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                        .accessibilityIdentifier("completedSeal")
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.nightRaised.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke((task.isDone ? Theme.Palette.goldDim : Theme.Palette.goldDim.opacity(0.4)), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .pressScale()
        .contextMenu {
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
        .accessibilityIdentifier("task.\(task.title)")
    }
}

struct XPHeader: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [PlayerProfile]

    var body: some View {
        let p = profiles.first
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "crown.fill").foregroundStyle(Theme.Palette.goldBright)
                Text("Level \(p?.level ?? 1)")
                    .font(Theme.display(20, weight: .bold))
                    .foregroundStyle(Theme.Palette.bone)
                Spacer()
                Text("\(p?.totalXP ?? 0) XP total")
                    .font(.caption).foregroundStyle(Theme.Palette.boneDim)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.nightDeep)
                    Capsule()
                        .fill(Theme.malachiteGold)
                        .frame(width: geo.size.width * progress(p))
                }
            }
            .frame(height: 10)
            .overlay(Capsule().stroke(Theme.Palette.goldDim, lineWidth: 0.8))
        }
        .padding()
        .goldFrame()
        .padding(.horizontal)
        .padding(.top, 8)
        .onAppear { _ = DailyMaintenance.profile(context: context) }
    }

    private func progress(_ p: PlayerProfile?) -> CGFloat {
        guard let p, p.xpForNextLevel > 0 else { return 0 }
        return min(1, max(0, CGFloat(p.xpIntoLevel) / CGFloat(p.xpForNextLevel)))
    }
}

struct Tag: View {
    let text: String
    let system: String
    var body: some View {
        Label(text, systemImage: system)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

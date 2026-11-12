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
    @State private var editor: TaskEditorRequest?
    @State private var choosing: TaskItem?

    /// Root tasks of this list (subtasks render inside their root's card).
    private var roots: [TaskItem] {
        allTasks.filter { $0.kindRaw == kind.rawValue && $0.parent == nil }
    }

    private var todo: [TaskItem] {
        roots.filter { !$0.isSettledToday }.sorted { $0.importance > $1.importance }
    }

    /// Finished or done-for-now *today*. Anything finished on an earlier day
    /// is cleared at midnight (and hidden here even before that runs).
    private var completed: [TaskItem] {
        let today = Calendar.current.startOfDay(for: Date())
        return roots
            .filter { $0.isDoneForNow || ($0.isDone && ($0.completedAt ?? today) >= today) }
            .sorted { ($0.completedAt ?? $0.doneForNowAt ?? .distantPast)
                    > ($1.completedAt ?? $1.doneForNowAt ?? .distantPast) }
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
                    ForEach(todo) { card($0) }
                }
                column("Completed", count: completed.count, id: "completed") {
                    ForEach(completed) { card($0) }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 30)
            .animation(Motion.select, value: allTasks.map { "\($0.isDone)\($0.isDoneForNow)" })
        }
        .scrollContentBackground(.hidden)
        .nightBackground()
        .navigationTitle(navTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editor = .new(kind) } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editor) { request in
            AddTaskView(mode: request.mode)
        }
        .confirmationDialog(choosing?.title ?? "", isPresented: Binding(
            get: { choosing != nil }, set: { if !$0 { choosing = nil } }),
            titleVisibility: .visible, presenting: choosing) { task in
            Button("Finished") { TaskActions.finish(task, context: context) }
            Button("Done for now") { TaskActions.doneForNow(task, context: context) }
            Button("Cancel", role: .cancel) {}
        } message: { task in
            Text(task.kind == .daily
                 ? "Finished: earns XP, back tomorrow as a daily task.\nDone for now: back tomorrow, no XP yet."
                 : "Finished: earns XP, cleared at midnight.\nDone for now: back tomorrow at the same importance.")
        }
    }

    private func card(_ task: TaskItem) -> some View {
        TaskCard(task: task,
                 onTap: { tapped($0) },
                 onEdit: { editor = .edit($0) },
                 onAddSubtask: { editor = .subtask($0) },
                 onDelete: { TaskActions.delete($0, context: context) })
    }

    /// To Do → ask Finished / Done for now. Already settled → undo.
    private func tapped(_ task: TaskItem) {
        if task.isSettledToday { TaskActions.reopen(task, context: context) }
        else { choosing = task }
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
}

/// Which task form to show.
enum TaskEditorRequest: Identifiable {
    case new(TaskKind)
    case subtask(TaskItem)
    case edit(TaskItem)

    var id: String {
        switch self {
        case .new(let k): return "new-\(k.rawValue)"
        case .subtask(let p): return "sub-\(p.id)"
        case .edit(let t): return "edit-\(t.id)"
        }
    }
    var mode: AddTaskView.Mode {
        switch self {
        case .new(let k): return .new(k)
        case .subtask(let p): return .subtask(of: p)
        case .edit(let t): return .edit(t)
        }
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

/// Compact task card sized for one of the two columns. Holds the root task
/// plus its subtasks (indented by level). Subtasks never leave this card.
struct TaskCard: View {
    let task: TaskItem
    let onTap: (TaskItem) -> Void
    let onEdit: (TaskItem) -> Void
    let onAddSubtask: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(task, level: 0)
            ForEach(task.flattenedSubtasks, id: \.task.id) { item in
                row(item.task, level: item.level)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.nightRaised.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke((task.isSettledToday ? Theme.Palette.goldDim : Theme.Palette.goldDim.opacity(0.4)), lineWidth: 0.5))
    }

    private func row(_ t: TaskItem, level: Int) -> some View {
        Button { onTap(t) } label: {
            HStack(alignment: .top, spacing: 6) {
                if level > 0 {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2).foregroundStyle(Theme.Palette.goldDim)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.title)
                        .font(level == 0 ? .subheadline : .caption)
                        .foregroundStyle(t.isSettledToday ? Theme.Palette.boneDim : Theme.Palette.bone)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    Tag(text: "\(t.timeEstimateMinutes)m · +\(t.xp) XP", system: "star.fill")
                    if !t.isSettledToday && t.dueClockMinutes != nil {
                        Tag(text: t.dueLabel, system: "clock")
                    }
                    if !t.isSettledToday && t.importance > 1 {
                        Tag(text: "Importance \(t.importance)", system: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    if t.isDoneForNow {
                        Tag(text: "Back tomorrow", system: "hourglass")
                    }
                }
                Spacer(minLength: 0)
                marker(t, size: level == 0 ? 30 : 20)
            }
            .padding(.leading, CGFloat(max(0, level - 1)) * 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onEdit(t) } label: { Label("Edit", systemImage: "pencil") }
            if t.canAddSubtask {
                Button { onAddSubtask(t) } label: { Label("Add subtask", systemImage: "plus.square.on.square") }
            }
            Button(role: .destructive) { onDelete(t) } label: { Label("Delete", systemImage: "trash") }
        }
        .accessibilityIdentifier("task.\(t.title)")
    }

    @ViewBuilder
    private func marker(_ t: TaskItem, size: CGFloat) -> some View {
        if t.isDone {
            // The same seal as the app logo.
            Image("SealCrest")
                .resizable().scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                .accessibilityIdentifier("completedSeal")
        } else if t.isDoneForNow {
            Image(systemName: "hourglass")
                .font(.system(size: size * 0.6))
                .foregroundStyle(Theme.Palette.gold)
                .frame(width: size, height: size)
                .accessibilityIdentifier("doneForNowMark")
        }
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

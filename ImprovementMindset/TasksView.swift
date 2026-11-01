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
    @State private var showingAdd = false

    private var tasks: [TaskItem] {
        allTasks
            .filter { $0.kindRaw == kind.rawValue }
            .sorted { $0.importance > $1.importance }
    }

    var body: some View {
        List {
            XPHeader()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

            if tasks.isEmpty {
                ContentUnavailableView(
                    "No tasks yet",
                    systemImage: "plus.circle",
                    description: Text("Tap + to add one."))
                .listRowBackground(Color.clear)
            }

            ForEach(tasks) { task in
                TaskRow(task: task) { toggle(task) }
                    .listRowBackground(Theme.Palette.nightRaised.opacity(0.5))
            }
            .onDelete(perform: delete)
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

    private func toggle(_ task: TaskItem) {
        let wasDone = task.isDone
        task.isDone.toggle()

        if !wasDone && task.isDone {
            let profile = DailyMaintenance.profile(context: context)
            profile.totalXP += task.xp
            if task.kind == .oneTime {
                context.delete(task)
            }
        }
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(tasks[i]) }
        try? context.save()
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

struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isDone ? Theme.Palette.malachiteLite : Theme.Palette.goldDim)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? Theme.Palette.boneDim : Theme.Palette.bone)
                HStack(spacing: 8) {
                    Tag(text: "\(task.timeEstimateMinutes)m", system: "clock")
                    Tag(text: task.difficulty.label, system: "flame")
                    Tag(text: task.dueLabel, system: "calendar")
                    Tag(text: "+\(task.xp) XP", system: "star.fill")
                }
                if task.importance > 1 {
                    Tag(text: "Importance \(task.importance)", system: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
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

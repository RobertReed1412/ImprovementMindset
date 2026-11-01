import SwiftUI
import SwiftData

struct AccomplishmentsView: View {
    var body: some View { NavigationStack { AccomplishmentsContent() } }
}

struct AccomplishmentsContent: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @State private var showingAdd = false
    @State private var newTitle = ""

    var body: some View {
            Group {
                if goals.isEmpty {
                    ContentUnavailableView(
                        "No goals yet",
                        systemImage: "trophy",
                        description: Text("Add a big-picture goal to start tracking your moves."))
                } else {
                    List {
                        ForEach(goals) { goal in
                            NavigationLink(value: goal.id) {
                                HStack(spacing: 12) {
                                    if goal.isAccomplished {
                                        WaxSeal(tone: .gold, size: 36, symbol: "star.fill")
                                    } else {
                                        Image(systemName: "target")
                                            .font(.title2).foregroundStyle(.secondary)
                                    }
                                    VStack(alignment: .leading) {
                                        Text(goal.title).font(.headline)
                                            .strikethrough(goal.isAccomplished)
                                        Text("\(goal.moves.count) move\(goal.moves.count == 1 ? "" : "s")")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Goals")
            .scrollContentBackground(.hidden)
            .nightBackground()
            .navigationDestination(for: UUID.self) { id in
                if let goal = goals.first(where: { $0.id == id }) {
                    GoalDetailView(goal: goal)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .alert("New goal", isPresented: $showingAdd) {
                TextField("Big-picture goal", text: $newTitle)
                Button("Cancel", role: .cancel) { newTitle = "" }
                Button("Add") { add() }
            }
    }

    private func add() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        context.insert(Goal(title: title))
        newTitle = ""
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(goals[i]) }
        try? context.save()
    }
}

struct GoalDetailView: View {
    @Bindable var goal: Goal
    @Environment(\.modelContext) private var context
    @State private var newMove = ""

    private var moves: [GoalMove] {
        goal.moves.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    if goal.isAccomplished {
                        WaxSeal(tone: .gold, size: 56, symbol: "star.fill")
                    }
                    VStack(alignment: .leading) {
                        Text(goal.title).font(.title3).fontWeight(.bold)
                        if goal.isAccomplished, let d = goal.accomplishedDate {
                            Text("Accomplished \(d.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                Button {
                    toggleAccomplished()
                } label: {
                    Label(goal.isAccomplished ? "Mark as in progress" : "Mark accomplished",
                          systemImage: goal.isAccomplished ? "arrow.uturn.backward" : "seal.fill")
                        .foregroundStyle(goal.isAccomplished ? Theme.Palette.boneDim : Theme.Palette.gold)
                }
            }

            Section("Moves toward this goal") {
                if moves.isEmpty {
                    Text("No moves logged yet.").foregroundStyle(.secondary)
                }
                ForEach(moves) { move in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(Theme.Palette.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(move.text)
                            Text(move.createdAt, format: .dateTime.month().day().year())
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteMove)
            }
        }
        .navigationTitle("Goal")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .nightBackground()
        .safeAreaInset(edge: .bottom) {
            HStack {
                TextField("Log a move…", text: $newMove, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                Button {
                    addMove()
                } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                .disabled(newMove.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(.bar)
        }
    }

    private func addMove() {
        let text = newMove.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let move = GoalMove(text: text)
        move.goal = goal
        goal.moves.append(move)
        context.insert(move)
        newMove = ""
        try? context.save()
    }

    private func toggleAccomplished() {
        goal.isAccomplished.toggle()
        goal.accomplishedDate = goal.isAccomplished ? Date() : nil
        try? context.save()
    }

    private func deleteMove(at offsets: IndexSet) {
        for i in offsets { context.delete(moves[i]) }
        try? context.save()
    }
}

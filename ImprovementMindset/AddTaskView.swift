import SwiftUI
import SwiftData

/// The full task form. One screen for: a new task, a new subtask, or editing
/// any existing task / subtask.
struct AddTaskView: View {
    enum Mode {
        case new(TaskKind)
        case subtask(of: TaskItem)
        case edit(TaskItem)
    }
    let mode: Mode

    init(kind: TaskKind) { mode = .new(kind) }
    init(mode: Mode) { self.mode = mode }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var draft = TaskDraft()
    @State private var loaded = false
    @State private var computingXP = false
    @State private var previewXP: Int?

    private var editing: TaskItem? {
        if case .edit(let t) = mode { return t } else { return nil }
    }
    private var parent: TaskItem? {
        if case .subtask(let p) = mode { return p } else { return nil }
    }
    /// Only root tasks choose daily vs one-time; subtasks follow their root.
    private var showsKind: Bool { parent == nil && editing?.parent == nil }

    private var navTitle: String {
        switch mode {
        case .new(let k): return k == .daily ? "New Daily Task" : "New Task"
        case .subtask: return "New Subtask"
        case .edit(let t): return t.parent == nil ? "Edit Task" : "Edit Subtask"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(parent.map { "Subtask of \($0.title)" } ?? "Task") {
                    TextField("What needs doing?", text: $draft.title)
                    if showsKind {
                        Picker("Type", selection: $draft.kind) {
                            Text("One-time").tag(TaskKind.oneTime)
                            Text("Daily").tag(TaskKind.daily)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Time estimate") {
                    Stepper("\(draft.minutes) min", value: $draft.minutes, in: 5...600, step: 5)
                }

                Section("Difficulty") {
                    Picker("Difficulty", selection: $draft.difficulty) {
                        ForEach(Difficulty.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Must be done by") {
                    Toggle("Anytime", isOn: $draft.anytime)
                    if !draft.anytime {
                        DatePicker("Time", selection: $draft.dueTime,
                                   displayedComponents: .hourAndMinute)
                    }
                }

                Section("Importance") {
                    Stepper(editing == nil ? "Starting importance: \(draft.importance)"
                                           : "Importance: \(draft.importance)",
                            value: $draft.importance, in: 1...99)
                    Text("Rises automatically each day it's left unfinished.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("XP") {
                    if let xp = previewXP ?? editing?.xp {
                        Label("+\(xp) XP", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    if editing?.isDone == true {
                        Text("Already finished, so XP stays as awarded.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button {
                            Task { await computeXP() }
                        } label: {
                            HStack {
                                Text("Calculate XP")
                                if computingXP { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(draft.trimmedTitle.isEmpty || computingXP)
                    }
                }
            }
            .navigationTitle(navTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Add" : "Save") { Task { await save() } }
                        .disabled(draft.trimmedTitle.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case .new(let k): draft = TaskDraft(kind: k)
        case .subtask(let p): draft = TaskDraft(kind: p.kind)
        case .edit(let t): draft = TaskDraft(task: t)
        }
    }

    private func estimate() async -> Int {
        await LocalXPService.shared.estimateXP(
            title: draft.trimmedTitle, difficulty: draft.difficulty,
            timeEstimateMinutes: draft.minutes, importance: draft.importance)
    }

    private func computeXP() async {
        computingXP = true
        previewXP = await estimate()
        computingXP = false
    }

    private func save() async {
        if let task = editing {
            // Re-score XP only for unfinished tasks whose inputs changed
            // (finished tasks already paid out their XP).
            var newXP = previewXP
            if newXP == nil, !task.isDone, draft.changesXPInputs(of: task) { newXP = await estimate() }
            draft.apply(to: task)
            if let newXP, !task.isDone { task.xp = newXP }
            ActivityLog.task(.taskEdited, task, in: context)
        } else {
            let xp: Int
            if let p = previewXP { xp = p } else { xp = await estimate() }
            let task = draft.makeTask(xp: xp)
            context.insert(task)
            if let parent {
                task.parent = parent
                task.kindRaw = parent.kindRaw
            }
            ActivityLog.task(.taskCreated, task, in: context)
        }
        try? context.save()
        dismiss()
    }
}

#Preview { AddTaskView(kind: .oneTime).previewEnv() }

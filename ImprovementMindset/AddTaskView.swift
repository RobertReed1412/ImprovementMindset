import SwiftUI
import SwiftData

struct AddTaskView: View {
    let kind: TaskKind

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var minutes = 15
    @State private var difficulty: Difficulty = .medium
    @State private var anytime = true
    @State private var dueDate = Date()
    @State private var importance = 1
    @State private var computingXP = false
    @State private var previewXP: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs doing?", text: $title)
                }

                Section("Time estimate") {
                    Stepper("\(minutes) min", value: $minutes, in: 5...600, step: 5)
                }

                Section("Difficulty") {
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Must be done by") {
                    Toggle("Anytime", isOn: $anytime)
                    if !anytime {
                        DatePicker("Time", selection: $dueDate,
                                   displayedComponents: .hourAndMinute)
                    }
                }

                Section("Importance") {
                    Stepper("Starting importance: \(importance)",
                            value: $importance, in: 1...10)
                    Text("Rises automatically each day it's left unfinished.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("XP") {
                    if let xp = previewXP {
                        Label("+\(xp) XP", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    Button {
                        Task { await computeXP() }
                    } label: {
                        HStack {
                            Text("Calculate XP")
                            if computingXP { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(title.isEmpty || computingXP)
                }
            }
            .navigationTitle(kind == .daily ? "New Daily Task" : "New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func dueClockMinutes() -> Int? {
        guard !anytime else { return nil }
        let c = Calendar.current.dateComponents([.hour, .minute], from: dueDate)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func service() -> LocalXPService { LocalXPService.shared }

    private func computeXP() async {
        computingXP = true
        let xp = await service().estimateXP(
            title: title, difficulty: difficulty,
            timeEstimateMinutes: minutes, importance: importance)
        previewXP = xp
        computingXP = false
    }

    private func save() async {
        let xp: Int
        if let p = previewXP { xp = p }
        else {
            xp = await service().estimateXP(
                title: title, difficulty: difficulty,
                timeEstimateMinutes: minutes, importance: importance)
        }
        let task = TaskItem(
            title: title, kind: kind,
            timeEstimateMinutes: minutes, difficulty: difficulty,
            dueClockMinutes: dueClockMinutes(),
            importance: importance, xp: xp)
        context.insert(task)
        try? context.save()
        dismiss()
    }
}

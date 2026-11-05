import SwiftUI
import SwiftData

struct FitnessView: View {
    var body: some View { NavigationStack { FitnessContent() } }
}

struct FitnessContent: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutEntry.loggedAt, order: .reverse) private var workouts: [WorkoutEntry]

    @State private var calorieDay: CalorieDay?
    @State private var addCalories = ""

    // Workout logger form
    @State private var workoutType: WorkoutType?
    @State private var durationMinutes = 30
    @State private var performedAt = Date()
    @State private var workoutNotes = ""

    @State private var showingCoach = false

    // Tap a workout to reveal its delete button; tapping that asks to confirm
    @State private var selectedWorkoutID: UUID?
    @State private var workoutToDelete: WorkoutEntry?

    var body: some View {
        List {
            Section("Calories today") {
                HStack {
                        Text("\(calorieDay?.calories ?? 0)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Palette.goldBright)
                        Text("kcal").foregroundStyle(Theme.Palette.boneDim)
                        Spacer()
                    }
                    HStack {
                        TextField("Add calories", text: $addCalories)
                            .keyboardType(.numberPad)
                        Button("Add") { addCals() }
                            .disabled(Int(addCalories) == nil)
                    }
                    Text("Resets automatically at the start of each day.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Log a workout") {
                    Picker("Workout", selection: $workoutType) {
                        Text("Choose…").tag(WorkoutType?.none)
                        ForEach(WorkoutType.allCases) { type in
                            Label(type.label, systemImage: type.symbol)
                                .tag(WorkoutType?.some(type))
                        }
                    }
                    Stepper(value: $durationMinutes, in: 5...600, step: 5) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(durationText)
                                .foregroundStyle(Theme.Palette.goldBright)
                                .monospacedDigit()
                        }
                    }
                    DatePicker("When", selection: $performedAt, in: ...Date())
                    TextField("What happened? (optional)", text: $workoutNotes, axis: .vertical)
                        .lineLimit(2...6)
                    Button("Log workout") { logWorkout() }
                        .disabled(workoutType == nil)
                }

                Section("Workout history") {
                    if workouts.isEmpty {
                        Text("No workouts logged yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(workouts) { w in
                        WorkoutRow(workout: w,
                                   isSelected: selectedWorkoutID == w.id,
                                   onDelete: { workoutToDelete = w })
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.snappy) {
                                    selectedWorkoutID = selectedWorkoutID == w.id ? nil : w.id
                                }
                            }
                    }
                }
            }
            .navigationTitle("Fitness")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Ask Coach", systemImage: "bubble.left.and.text.bubble.right") {
                        showingCoach = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: WorkoutCSVFile(csv: WorkoutExport.csv(workouts)),
                              preview: SharePreview("workouts.csv")) {
                        Label("Export workouts", systemImage: "square.and.arrow.up")
                    }
                    .disabled(workouts.isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .nightBackground()
            .onAppear { calorieDay = DailyMaintenance.calorieDay(context: context) }
            // Catch up on anything that failed to sync while offline
            .task { await WorkoutSync.run(context: context) }
            .sheet(isPresented: $showingCoach) { AskCoachView() }
            .alert("Delete this workout?", isPresented: Binding(
                get: { workoutToDelete != nil },
                set: { if !$0 { workoutToDelete = nil } }
            ), presenting: workoutToDelete) { workout in
                Button("Delete", role: .destructive) { delete(workout) }
                Button("Cancel", role: .cancel) {}
            } message: { workout in
                Text("\(workout.type?.label ?? "Unspecified") on \(workout.performedAt.formatted(date: .abbreviated, time: .shortened)) will be removed. This can't be undone.")
            }
    }

    private func addCals() {
        guard let n = Int(addCalories) else { return }
        let day = calorieDay ?? DailyMaintenance.calorieDay(context: context)
        day.calories += n
        calorieDay = day
        addCalories = ""
        try? context.save()
    }

    private var durationText: String {
        let h = durationMinutes / 60, m = durationMinutes % 60
        return h == 0 ? "\(m) min" : "\(h) hr \(m) min"
    }

    private func logWorkout() {
        guard let type = workoutType else { return }
        let notes = workoutNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        context.insert(WorkoutEntry(type: type, durationMinutes: durationMinutes,
                                    notes: notes, performedAt: performedAt))
        workoutType = nil
        durationMinutes = 30
        performedAt = Date()
        workoutNotes = ""
        try? context.save()
        Task { await WorkoutSync.run(context: context) }
    }

    private func delete(_ workout: WorkoutEntry) {
        WorkoutSync.markDeleted(workout.id)
        context.delete(workout)
        selectedWorkoutID = nil
        workoutToDelete = nil
        try? context.save()
        Task { await WorkoutSync.run(context: context) }
    }
}

private struct WorkoutRow: View {
    let workout: WorkoutEntry
    let isSelected: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            details
            if isSelected {
                Button("Delete workout", systemImage: "xmark.circle.fill", action: onDelete)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .foregroundStyle(Theme.Palette.oxbloodBright)
                    .buttonStyle(.borderless)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let type = workout.type {
                    Label(type.label, systemImage: type.symbol)
                        .foregroundStyle(Theme.Palette.goldBright)
                } else {
                    Text("Unspecified").foregroundStyle(Theme.Palette.boneDim)
                }
                Spacer()
                if workout.durationMinutes > 0 {
                    Text(workout.durationLabel)
                        .foregroundStyle(Theme.Palette.bone)
                        .monospacedDigit()
                }
            }
            if !workout.notes.isEmpty {
                Text(workout.notes)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.boneDim)
            }
            Text(workout.performedAt, format: .dateTime.month().day().hour().minute())
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

#Preview { FitnessView().previewEnv() }

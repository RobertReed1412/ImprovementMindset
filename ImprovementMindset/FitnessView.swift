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
                        WorkoutRow(workout: w)
                    }
                    .onDelete(perform: deleteWorkouts)
                }
            }
            .navigationTitle("Fitness")
            .toolbar {
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
    }

    private func deleteWorkouts(at offsets: IndexSet) {
        for i in offsets { context.delete(workouts[i]) }
        try? context.save()
    }
}

private struct WorkoutRow: View {
    let workout: WorkoutEntry

    var body: some View {
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

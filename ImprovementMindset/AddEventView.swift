import SwiftUI
import SwiftData

struct AddEventView: View {
    let defaultDate: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Date()
    @State private var duration = 60
    @State private var recurrence: Recurrence = .none
    @State private var hasEnd = false
    @State private var endDate = Date()
    @State private var colorHex = 0xC9A24B
    @State private var notes = ""

    private let colorChoices: [(String, Int)] = [
        ("Gold", 0xC9A24B),
        ("Malachite", 0x2E9B73),
        ("Oxblood", 0x9E2024),
        ("Steel", 0x5B6B8A),
        ("Bone", 0xE8DCC0)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Title (e.g. Therapy, Work)", text: $title)
                }

                Section("When") {
                    DatePicker("Starts", selection: $date)
                    Stepper("Duration: \(duration) min", value: $duration, in: 15...480, step: 15)
                }

                Section("Repeat") {
                    Picker("Repeats", selection: $recurrence) {
                        ForEach(Recurrence.allCases) { Text($0.label).tag($0) }
                    }
                    if recurrence != .none {
                        Toggle("End date", isOn: $hasEnd)
                        if hasEnd {
                            DatePicker("Stops after", selection: $endDate,
                                       displayedComponents: .date)
                        }
                    }
                }

                Section("Color") {
                    HStack(spacing: 14) {
                        ForEach(colorChoices, id: \.1) { name, hex in
                            SwiftUI.Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    SwiftUI.Circle().stroke(.white, lineWidth: colorHex == hex ? 2 : 0))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle("New Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }.disabled(title.isEmpty)
                }
            }
            .onAppear {
                let cal = Calendar.current
                let now = cal.dateComponents([.hour, .minute], from: Date())
                date = cal.date(bySettingHour: now.hour ?? 9, minute: now.minute ?? 0,
                                second: 0, of: defaultDate) ?? defaultDate
                endDate = cal.date(byAdding: .month, value: 3, to: defaultDate) ?? defaultDate
            }
        }
    }

    private func save() {
        let event = CalendarEvent(
            title: title,
            startDate: date,
            durationMinutes: duration,
            recurrence: recurrence,
            colorHex: colorHex,
            notes: notes,
            recurrenceEndDate: (recurrence != .none && hasEnd) ? endDate : nil)
        context.insert(event)
        try? context.save()
        dismiss()
    }
}

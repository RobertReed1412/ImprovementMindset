import SwiftUI
import SwiftData

// HomeWidgets.swift
// -----------------------------------------------------------------------
// Home page widgets. Each one is a self-contained card that writes to the
// same models (and the same ActivityLog) as the full screens do.
// -----------------------------------------------------------------------

/// Shared card chrome for widgets: display-font title + gold frame.
private struct WidgetCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title).font(Theme.display(18, weight: .semibold))
            } icon: {
                Image(systemName: symbol)
            }
            .foregroundStyle(Theme.Palette.goldBright)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .goldFrame(cornerRadius: 16)
    }
}

/// Short confirmation line that fades after a moment.
private struct Flash: View {
    let text: String?
    var body: some View {
        if let text {
            Text(text).font(.caption).foregroundStyle(Theme.Palette.malachiteLite)
                .transition(.opacity)
                .accessibilityIdentifier("widget.flash")
        }
    }
}

// MARK: - Quick Task

struct QuickTaskWidget: View {
    @Environment(\.modelContext) private var context
    @State private var draft = TaskDraft()
    @State private var expanded = false
    @State private var flash: String?
    @FocusState private var focused: Bool

    var body: some View {
        WidgetCard(title: "Quick Task", symbol: "checklist") {
            HStack {
                TextField("Add a task…", text: $draft.title)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($focused)
                    .onSubmit(add)
                    .accessibilityIdentifier("quickTask.field")
                // Dropdown: all the full-task fields, right in the widget.
                Button {
                    withAnimation(Motion.select) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up.circle" : "chevron.down.circle")
                        .font(.title2).foregroundStyle(Theme.Palette.gold)
                }
                .accessibilityLabel(expanded ? "Hide task options" : "Show task options")
                .accessibilityIdentifier("quickTask.options")
                Button(action: add) {
                    Image(systemName: "plus.circle.fill").font(.title2)
                        .foregroundStyle(Theme.Palette.gold)
                }
                .disabled(draft.trimmedTitle.isEmpty)
                .accessibilityLabel("Add task")
                .accessibilityIdentifier("quickTask.add")
            }

            if expanded { options }
            Flash(text: flash)
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Type", selection: $draft.kind) {
                Text("One-time").tag(TaskKind.oneTime)
                Text("Daily").tag(TaskKind.daily)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("quickTask.kind")

            Stepper("Time: \(draft.minutes) min", value: $draft.minutes, in: 5...600, step: 5)
                .accessibilityIdentifier("quickTask.minutes")

            Picker("Difficulty", selection: $draft.difficulty) {
                ForEach(Difficulty.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Toggle("Anytime", isOn: $draft.anytime)
            if !draft.anytime {
                DatePicker("Must be done by", selection: $draft.dueTime, displayedComponents: .hourAndMinute)
            }

            Stepper("Importance: \(draft.importance)", value: $draft.importance, in: 1...99)

            Label("+\(draft.formulaXP) XP", systemImage: "star.fill")
                .font(.caption).foregroundStyle(Theme.Palette.goldBright)
        }
        .foregroundStyle(Theme.Palette.bone)
        .tint(Theme.Palette.gold)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// Without opening the dropdown this is still a one-tap add with the
    /// usual defaults (one-time, 15 min, medium, importance 1).
    private func add() {
        guard !draft.trimmedTitle.isEmpty else { return }
        let task = draft.makeTask(xp: draft.formulaXP)
        context.insert(task)
        ActivityLog.task(.taskCreated, task, extra: ["source": "home_widget"], in: context)
        try? context.save()
        let where_ = draft.kind == .daily ? "Daily" : "Tasks"
        draft = TaskDraft()
        focused = false
        withAnimation(Motion.select) { expanded = false }
        show("Added to \(where_)")
    }

    private func show(_ text: String) {
        withAnimation { flash = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { flash = nil } }
    }
}

// MARK: - Quick Note (adds a card to a circle)

struct QuickNoteWidget: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Circle.createdAt, order: .reverse) private var circles: [Circle]
    @AppStorage("quickNote.circleID") private var selectedID = ""

    @State private var note = ""
    @State private var flash: String?
    @State private var showingNewCircle = false
    @State private var newCircleName = ""
    @State private var newCircleNote = ""
    @FocusState private var focused: Bool

    private var selected: Circle? {
        circles.first { $0.id.uuidString == selectedID } ?? circles.first
    }
    private var trimmed: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        WidgetCard(title: "Quick Note", symbol: "square.and.pencil") {
            HStack(spacing: 10) {
                // Dropdown: which circle the note goes into.
                Menu {
                    ForEach(circles) { circle in
                        Button {
                            selectedID = circle.id.uuidString
                        } label: {
                            if circle.id == selected?.id {
                                Label(circle.label, systemImage: "checkmark")
                            } else {
                                Text(circle.label)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "circle.circle")
                        Text(selected?.label ?? "No circles yet").lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.up.chevron.down").font(.caption)
                    }
                    .foregroundStyle(Theme.Palette.bone)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.Palette.nightRaised))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Palette.goldDim.opacity(0.5), lineWidth: 0.5))
                }
                .disabled(circles.isEmpty)
                .accessibilityIdentifier("quickNote.circlePicker")

                // Right side: create a new circle with its first note.
                Button {
                    newCircleName = ""
                    newCircleNote = note
                    showingNewCircle = true
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                        .foregroundStyle(Theme.Palette.gold)
                }
                .accessibilityLabel("New circle")
                .accessibilityIdentifier("quickNote.newCircle")
            }

            HStack(alignment: .bottom) {
                TextField(circles.isEmpty ? "Create a circle first (+)" : "Write a note…",
                          text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .disabled(circles.isEmpty)
                    .accessibilityIdentifier("quickNote.field")
                Button(action: addNote) {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                        .foregroundStyle(Theme.Palette.gold)
                }
                .disabled(trimmed.isEmpty || selected == nil)
                .accessibilityLabel("Add note")
                .accessibilityIdentifier("quickNote.add")
            }
            Flash(text: flash)
        }
        .alert("New circle", isPresented: $showingNewCircle) {
            TextField("Circle name", text: $newCircleName)
            TextField("First note", text: $newCircleNote)
            Button("Cancel", role: .cancel) {}
            Button("Create") { createCircle() }
        } message: {
            Text("Name the circle and write its first note.")
        }
    }

    private func addNote() {
        guard let circle = selected, !trimmed.isEmpty else { return }
        insertCard(body: trimmed, into: circle)
        try? context.save()
        note = ""
        focused = false
        show("Added to \(circle.label)")
    }

    private func createCircle() {
        let name = newCircleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let circle = Circle(label: name)
        context.insert(circle)
        ActivityLog.record(.circleCreated, area: .circles, entityID: circle.id,
                           title: name, metadata: ["source": "home_widget"], in: context)
        let first = newCircleNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !first.isEmpty { insertCard(body: first, into: circle) }
        try? context.save()
        selectedID = circle.id.uuidString
        note = ""
        focused = false
        show("Created \(name)")
    }

    /// Quick notes go into the card body; the title stays empty for the
    /// user to fill in later from the circle deck.
    private func insertCard(body: String, into circle: Circle) {
        let card = CircleCard(body: body, order: (circle.cards.map(\.order).max() ?? -1) + 1)
        card.circle = circle
        circle.cards.append(card)
        context.insert(card)
        ActivityLog.record(.noteAdded, area: .circles, entityID: card.id, title: circle.label,
                           value: Double(body.count),
                           metadata: ["circle_id": circle.id.uuidString, "source": "home_widget"],
                           in: context)
    }

    private func show(_ text: String) {
        withAnimation { flash = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { flash = nil } }
    }
}

#Preview {
    VStack(spacing: 16) { QuickTaskWidget(); QuickNoteWidget() }
        .padding().nightBackground().previewEnv()
}

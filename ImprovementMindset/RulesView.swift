import SwiftUI
import SwiftData

struct RulesView: View {
    var body: some View { NavigationStack { RulesContent() } }
}

struct RulesContent: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Strike.createdAt, order: .reverse) private var strikes: [Strike]
    @Query private var configs: [RulesConfig]

    @State private var showingStrike = false
    @State private var strikeNote = ""
    @State private var punishment = ""
    @State private var reward = ""
    @State private var config: RulesConfig?

    private var activeStrikes: [Strike] { strikes.filter { $0.isActive } }

    private var daysWithoutStrike: Int {
        let reference = strikes.first?.createdAt ?? Date()
        return max(0, Calendar.current.dateComponents([.day], from: reference, to: Date()).day ?? 0)
    }

    var body: some View {
            List {
                Section {
                    VStack(spacing: 6) {
                        Text("\(daysWithoutStrike)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(activeStrikes.isEmpty ? Theme.Palette.malachiteLite : Theme.Palette.oxbloodBright)
                        Text(strikes.isEmpty ? "days tracked" : "days since last strike")
                            .font(.caption).foregroundStyle(Theme.Palette.boneDim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    Button(role: .destructive) {
                        showingStrike = true
                    } label: {
                        Label("Record a strike", systemImage: "exclamationmark.triangle.fill")
                    }
                }

                Section("Active strikes (expire after 7 days)") {
                    if activeStrikes.isEmpty {
                        Text("No active strikes. Keep it clean.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(activeStrikes) { strike in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(strike.note.isEmpty ? "Strike" : strike.note)
                                Spacer()
                                Text("\(strike.daysRemaining)d left")
                                    .font(.caption).foregroundStyle(Theme.Palette.oxbloodBright)
                            }
                            Text(strike.createdAt, format: .dateTime.month().day().year())
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteStrike)
                }

                Section("Punishment") {
                    TextField("What happens when you slip…",
                              text: $punishment, axis: .vertical)
                        .lineLimit(1...4)
                        .onChange(of: punishment) { _, v in saveConfig(\.punishment, v) }
                }

                Section("Reward") {
                    TextField("What you earn for staying clean…",
                              text: $reward, axis: .vertical)
                        .lineLimit(1...4)
                        .onChange(of: reward) { _, v in saveConfig(\.reward, v) }
                }
            }
            .navigationTitle("Rules")
            .scrollContentBackground(.hidden)
            .nightBackground()
            .onAppear { loadConfig() }
            .alert("Record a strike", isPresented: $showingStrike) {
                TextField("Reason (optional)", text: $strikeNote)
                Button("Cancel", role: .cancel) { strikeNote = "" }
                Button("Record", role: .destructive) { recordStrike() }
            } message: {
                Text("This strike will stay active for 7 days.")
            }
    }

    private func loadConfig() {
        if let c = configs.first {
            config = c; punishment = c.punishment; reward = c.reward
        } else {
            let c = RulesConfig()
            context.insert(c); try? context.save()
            config = c
        }
    }

    private func saveConfig(_ key: ReferenceWritableKeyPath<RulesConfig, String>, _ value: String) {
        let c = config ?? configs.first
        c?[keyPath: key] = value
        try? context.save()
    }

    private func recordStrike() {
        let note = strikeNote.trimmingCharacters(in: .whitespaces)
        context.insert(Strike(note: note))
        strikeNote = ""
        try? context.save()
    }

    private func deleteStrike(at offsets: IndexSet) {
        for i in offsets { context.delete(activeStrikes[i]) }
        try? context.save()
    }
}

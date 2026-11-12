import SwiftUI
import SwiftData

/// Settings → Edit home page. Add, remove, and reorder Home sections.
/// Removing a section only hides it; the data behind it is untouched.
struct EditHomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var layouts: [HomeLayoutRecord]

    private var sections: [HomeSection] { layouts.first?.sections ?? HomeSection.defaults }
    private var hidden: [HomeSection] {
        let shown = Set(sections.map(\.id))
        return HomeSection.catalog.filter { !shown.contains($0.id) }
    }

    var body: some View {
        List {
            Section {
                if sections.isEmpty {
                    Text("Home is empty. Add a section below.").foregroundStyle(.secondary)
                }
                ForEach(sections) { section in
                    Label(section.title, systemImage: section.symbol)
                        .accessibilityIdentifier("home.shown.\(section.id)")
                }
                .onDelete { offsets in
                    var s = sections; s.remove(atOffsets: offsets); save(s)
                }
                .onMove { from, to in
                    var s = sections; s.move(fromOffsets: from, toOffset: to); save(s)
                }
            } header: {
                Text("On your home page")
            } footer: {
                Text("Tap the red minus to remove, drag the handle to reorder. Removing a section only hides it. Nothing inside it is deleted.")
            }

            if !hidden.isEmpty {
                Section("Add a section") {
                    ForEach(hidden) { section in
                        Button {
                            save(sections + [section])
                        } label: {
                            HStack {
                                Label(section.title, systemImage: section.symbol)
                                    .foregroundStyle(Theme.Palette.bone)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Theme.Palette.gold)
                            }
                        }
                        .accessibilityIdentifier("home.add.\(section.id)")
                    }
                }
            }

            Section {
                Button("Reset to default") { save(HomeSection.defaults) }
                    .foregroundStyle(Theme.Palette.gold)
            }
        }
        .environment(\.editMode, .constant(.active))   // always show drag handles
        .navigationTitle("Edit Home")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .nightBackground()
    }

    private func save(_ new: [HomeSection]) {
        HomeLayoutStore.layout(context: context).setSections(new)
        try? context.save()
    }
}

#Preview { NavigationStack { EditHomeView() }.previewEnv() }

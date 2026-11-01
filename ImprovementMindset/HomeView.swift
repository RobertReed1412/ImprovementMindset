import SwiftUI
import SwiftData

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case oneTime, fitness, calendar, library, creations, circles, rules, goals
    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneTime: return "Tasks"
        case .fitness: return "Fitness"
        case .calendar: return "Calendar"
        case .library: return "Library"
        case .creations: return "Creations"
        case .circles: return "Circles"
        case .rules: return "Rules"
        case .goals: return "Goals"
        }
    }
    var symbol: String {
        switch self {
        case .oneTime: return "checklist"
        case .fitness: return "figure.run"
        case .calendar: return "calendar"
        case .library: return "books.vertical"
        case .creations: return "hammer"
        case .circles: return "circle.circle"
        case .rules: return "exclamationmark.shield"
        case .goals: return "trophy"
        }
    }
}

struct HomeView: View {
    @Query private var profiles: [PlayerProfile]
    @Environment(\.modelContext) private var context

    private let tiles: [AppSection] = [
        .calendar, .oneTime, .fitness, .goals,
        .library, .creations, .circles, .rules
    ]
    private let columns = [GridItem(.flexible(), spacing: 16),
                           GridItem(.flexible(), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                crownHeader
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(tiles) { section in
                        NavigationLink(value: section) {
                            DashboardTile(section: section)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .nightBackground()
            .navigationTitle("The Improvement Mindset")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: AppSection.self) { section in
                destination(for: section)
            }
        }
    }

    private var crownHeader: some View {
        let p = profiles.first
        return VStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.Palette.goldBright)
            Text("Level \(p?.level ?? 1)")
                .font(Theme.display(28, weight: .bold))
                .foregroundStyle(Theme.Palette.bone)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.nightDeep)
                    Capsule().fill(Theme.malachiteGold)
                        .frame(width: geo.size.width * progress(p))
                }
            }
            .frame(height: 8)
            .overlay(Capsule().stroke(Theme.Palette.goldDim, lineWidth: 0.8))
            .padding(.horizontal, 40)
            Text("\(p?.totalXP ?? 0) XP")
                .font(.caption).foregroundStyle(Theme.Palette.boneDim)
        }
        .padding(.top, 16).padding(.bottom, 6)
        .onAppear { _ = DailyMaintenance.profile(context: context) }
    }

    private func progress(_ p: PlayerProfile?) -> CGFloat {
        guard let p, p.xpForNextLevel > 0 else { return 0 }
        return min(1, max(0, CGFloat(p.xpIntoLevel) / CGFloat(p.xpForNextLevel)))
    }

    @ViewBuilder
    private func destination(for section: AppSection) -> some View {
        switch section {
        case .oneTime:   TasksContent(kind: .oneTime, navTitle: "Tasks")
        case .fitness:   FitnessContent()
        case .calendar:  CalendarContent()
        case .library:   ShelfContent(shelf: .library, navTitle: "Library")
        case .creations: ShelfContent(shelf: .creations, navTitle: "Creations")
        case .circles:   CirclesContent()
        case .rules:     RulesContent()
        case .goals:     AccomplishmentsContent()
        }
    }
}

struct DashboardTile: View {
    let section: AppSection
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: section.symbol)
                .font(.system(size: 30))
                .foregroundStyle(Theme.Palette.goldBright)
            Text(section.title)
                .font(Theme.display(18, weight: .semibold))
                .foregroundStyle(Theme.Palette.bone)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .goldFrame(cornerRadius: 16)
    }
}

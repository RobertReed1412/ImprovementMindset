import Foundation
import SwiftData

// HomeLayout.swift
// -----------------------------------------------------------------------
// Which sections the Home page shows, in what order. Stored as ONE
// SwiftData row holding an ordered list of section ids (strings), plus
// `updatedAt` so a future Supabase sync can do last-write-wins.
//
// Removing a section only removes its id from this list. It never touches
// the data behind the section (tasks, circles, goals…).
// Unknown ids (e.g. a section added in a newer app version, synced down)
// are kept in storage but skipped when rendering.
// -----------------------------------------------------------------------

extension AppSection: Codable {}

struct HomeSection: Hashable, Identifiable {
    enum Kind: Hashable {
        case levelHeader
        case taskWidget
        case notesWidget
        case shortcut(AppSection)
    }
    let kind: Kind

    /// Stable string id. Persisted and synced: never change existing ones.
    var id: String {
        switch kind {
        case .levelHeader: return "level_header"
        case .taskWidget: return "widget.tasks"
        case .notesWidget: return "widget.notes"
        case .shortcut(let s): return "shortcut.\(s.rawValue)"
        }
    }

    init(_ kind: Kind) { self.kind = kind }

    init?(id: String) {
        guard let match = HomeSection.catalog.first(where: { $0.id == id }) else { return nil }
        self = match
    }

    var title: String {
        switch kind {
        case .levelHeader: return "Level & XP"
        case .taskWidget: return "Quick Task widget"
        case .notesWidget: return "Quick Note widget"
        case .shortcut(let s): return "\(s.title) shortcut"
        }
    }

    var symbol: String {
        switch kind {
        case .levelHeader: return "crown.fill"
        case .taskWidget: return "checklist"
        case .notesWidget: return "square.and.pencil"
        case .shortcut(let s): return s.symbol
        }
    }

    /// Every section the user can put on Home.
    static let catalog: [HomeSection] =
        [HomeSection(.levelHeader), HomeSection(.taskWidget), HomeSection(.notesWidget)]
        + AppSection.allCases.map { HomeSection(.shortcut($0)) }

    /// What a new user (or anyone who never customized) sees. Keeps every
    /// tile the old fixed Home page had, in the same order, plus the widgets.
    static let defaults: [HomeSection] =
        [HomeSection(.levelHeader), HomeSection(.taskWidget), HomeSection(.notesWidget)]
        + [AppSection.calendar, .oneTime, .fitness, .goals,
           .library, .creations, .circles, .rules].map { HomeSection(.shortcut($0)) }
}

@Model
final class HomeLayoutRecord {
    var id: UUID = UUID()
    var sectionIDs: [String] = []
    var updatedAt: Date = Date()
    var syncedAt: Date?

    init(sectionIDs: [String]) {
        self.id = UUID()
        self.sectionIDs = sectionIDs
        self.updatedAt = Date()
    }

    /// Known sections in display order (unknown ids skipped, duplicates dropped).
    var sections: [HomeSection] {
        var seen = Set<String>()
        return sectionIDs.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return HomeSection(id: id)
        }
    }

    func setSections(_ sections: [HomeSection]) {
        // Preserve unknown ids (from a newer app version) at the end.
        let known = Set(HomeSection.catalog.map(\.id))
        let unknown = sectionIDs.filter { !known.contains($0) }
        sectionIDs = sections.map(\.id) + unknown
        updatedAt = Date()
        syncedAt = nil
    }
}

@MainActor
enum HomeLayoutStore {
    /// The single layout row, created with defaults on first use.
    static func layout(context: ModelContext) -> HomeLayoutRecord {
        if let existing = try? context.fetch(FetchDescriptor<HomeLayoutRecord>()).first {
            return existing
        }
        let fresh = HomeLayoutRecord(sectionIDs: HomeSection.defaults.map(\.id))
        context.insert(fresh)
        try? context.save()
        return fresh
    }
}

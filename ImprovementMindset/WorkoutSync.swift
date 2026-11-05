import Foundation
import SwiftData

// WorkoutSync.swift
// -----------------------------------------------------------------------
// Pushes the Fitness tab's workouts to Supabase (through n8n) so the coach
// can see them. Every sync sends all workouts, so a sync that fails while
// offline is fixed by the next one. Deletes are remembered in UserDefaults
// until they've been sent.
// -----------------------------------------------------------------------

@MainActor
enum WorkoutSync {
    private static let pendingDeletesKey = "WorkoutSync.pendingDeletes"

    /// Call just before deleting a workout from SwiftData.
    static func markDeleted(_ id: UUID) {
        var ids = UserDefaults.standard.stringArray(forKey: pendingDeletesKey) ?? []
        ids.append(id.uuidString)
        UserDefaults.standard.set(ids, forKey: pendingDeletesKey)
    }

    /// Sends every workout plus any pending deletes. Safe to call often.
    static func run(context: ModelContext) async {
        do {
            let workouts = try context.fetch(FetchDescriptor<WorkoutEntry>())
            let sentDeletes = UserDefaults.standard.stringArray(forKey: pendingDeletesKey) ?? []

            try await RAGClient.shared.sync(
                upserts: workouts.map(WorkoutRecord.init),
                deletes: sentDeletes.compactMap(UUID.init(uuidString:))
            )

            // Clear only what was sent, in case another delete happened during the request
            let remaining = (UserDefaults.standard.stringArray(forKey: pendingDeletesKey) ?? [])
                .filter { !sentDeletes.contains($0) }
            UserDefaults.standard.set(remaining, forKey: pendingDeletesKey)
        } catch {
            // Offline or server down: nothing is lost, the next sync sends everything again
            print("Workout sync failed: \(error.localizedDescription)")
        }
    }
}

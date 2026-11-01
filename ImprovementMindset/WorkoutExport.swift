import Foundation
import SwiftUI
import UniformTypeIdentifiers

// WorkoutExport.swift
// -----------------------------------------------------------------------
// Converts local WorkoutEntry rows into the shape of the Supabase
// `workouts` table (see supabase/schema.sql) so they can be imported via
// Table Editor → Import data (CSV) or sent as JSON, then chunked + embedded
// by the n8n ingestion workflow.
//
// `content` is a pre-built, human-readable sentence for each workout. It is
// the text meant to be embedded into `workout_chunks`, so n8n can use it
// directly instead of re-assembling the columns.
// -----------------------------------------------------------------------

/// One row of the Supabase `workouts` table. Keys encode as snake_case.
struct WorkoutRecord: Codable, Identifiable {
    let id: UUID
    let workoutType: String
    let durationMinutes: Int
    let notes: String?
    let performedAt: Date
    let loggedAt: Date
    let content: String

    init(_ entry: WorkoutEntry) {
        id = entry.id
        workoutType = entry.typeRaw
        durationMinutes = entry.durationMinutes
        let trimmed = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        notes = trimmed.isEmpty ? nil : trimmed
        performedAt = entry.performedAt
        loggedAt = entry.loggedAt
        content = WorkoutRecord.chunkText(for: entry)
    }

    /// e.g. "Monday, October 20, 2026 — Fighting session, 1 hr 15 min. Notes: sparred 5 rounds."
    static func chunkText(for entry: WorkoutEntry) -> String {
        let date = entry.performedAt.formatted(
            .dateTime.weekday(.wide).month(.wide).day().year().locale(Locale(identifier: "en_US")))
        let kind = entry.type?.label ?? "Unspecified"
        var text = "\(date) — \(kind) session, \(entry.durationLabel)."
        let notes = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { text += " Notes: \(notes)" }
        return text
    }
}

@MainActor
enum WorkoutExport {

    static func json(_ entries: [WorkoutEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries.map(WorkoutRecord.init))
    }

    /// CSV with a header row matching the Supabase column names.
    static func csv(_ entries: [WorkoutEntry]) -> String {
        let iso = ISO8601DateFormatter()
        var lines = ["id,workout_type,duration_minutes,notes,performed_at,logged_at,content"]
        for r in entries.map(WorkoutRecord.init) {
            lines.append([
                r.id.uuidString.lowercased(),
                r.workoutType,
                String(r.durationMinutes),
                escape(r.notes ?? ""),
                iso.string(from: r.performedAt),
                iso.string(from: r.loggedAt),
                escape(r.content),
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// RFC 4180 quoting: wrap every free-text field and double embedded quotes.
    private static func escape(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// Shareable CSV file for ShareLink (AirDrop, Files, etc.).
struct WorkoutCSVFile: Transferable {
    let csv: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { file in
            Data(file.csv.utf8)
        }
        .suggestedFileName("workouts.csv")
    }
}

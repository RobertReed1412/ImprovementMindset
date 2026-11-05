import Foundation

// RAGClient.swift
// -----------------------------------------------------------------------
// Talks to the n8n webhooks behind the workout coach:
//   • webhook/workout-sync  — upserts/deletes workouts in Supabase and embeds them
//   • webhook/workout-chat  — asks the AI agent a question
// The base URL and key come from Info.plist (RAGBaseURL / RAGAPIKey), which
// reads them from Secrets.xcconfig. That file is git-ignored.
// -----------------------------------------------------------------------

enum RAGError: LocalizedError {
    case notConfigured
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "The coach isn't set up. Check RAGBaseURL and RAGAPIKey in Info.plist."
        case .badResponse(let status):
            return "The coach server returned an error (\(status))."
        }
    }
}

struct RAGClient {
    static let shared = RAGClient()

    private let baseURL: URL?
    private let apiKey: String

    init(bundle: Bundle = .main) {
        baseURL = (bundle.object(forInfoDictionaryKey: "RAGBaseURL") as? String).flatMap(URL.init(string:))
        apiKey = bundle.object(forInfoDictionaryKey: "RAGAPIKey") as? String ?? ""
    }

    /// Sends every workout plus the ids of deleted ones. The server skips
    /// unchanged workouts, so only new or edited ones get re-embedded.
    func sync(upserts: [WorkoutRecord], deletes: [UUID]) async throws {
        struct Body: Encodable {
            let upserts: [WorkoutRecord]
            let deletes: [UUID]
        }
        _ = try await post("webhook/workout-sync", body: Body(upserts: upserts, deletes: deletes))
    }

    /// Asks the coach a question and returns its answer.
    func ask(_ question: String) async throws -> String {
        struct Body: Encodable { let question: String }
        struct Reply: Decodable { let answer: String }
        let data = try await post("webhook/workout-chat", body: Body(question: question))
        return try JSONDecoder().decode(Reply.self, from: data).answer
    }

    private func post(_ path: String, body: some Encodable) async throws -> Data {
        guard let baseURL, !apiKey.isEmpty else { throw RAGError.notConfigured }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 60   // the agent can take a few seconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw RAGError.badResponse(status) }
        return data
    }
}

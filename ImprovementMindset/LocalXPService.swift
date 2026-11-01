import Foundation
import Observation

/// Assigns XP to tasks using a heuristic formula.
/// (On-device LLM scoring can be added later by linking MLXHuggingFace +
/// the HuggingFace/Tokenizers packages and restoring the model-loading path.)
@Observable
@MainActor
final class LocalXPService {

    static let shared = LocalXPService()

    enum LoadState: Equatable {
        case idle
        case downloading(Double)
        case loading
        case ready
        case failed(String)
    }

    var state: LoadState = .ready

    private init() {}

    func ensureLoaded(modelID: String? = nil) async {
        state = .ready
    }

    func estimateXP(title: String,
                    difficulty: Difficulty,
                    timeEstimateMinutes: Int,
                    importance: Int) async -> Int {
        Self.heuristicXP(
            difficulty: difficulty,
            timeEstimateMinutes: timeEstimateMinutes,
            importance: importance)
    }

    static func heuristicXP(difficulty: Difficulty,
                            timeEstimateMinutes: Int,
                            importance: Int) -> Int {
        let base = Double(timeEstimateMinutes) * 1.5
        let scaled = base * difficulty.xpMultiplier + Double(importance) * 5.0
        return min(500, max(5, Int(scaled)))
    }
}

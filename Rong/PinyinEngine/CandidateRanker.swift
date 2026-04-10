import Foundation

/// Merges dictionary frequency ranking with optional async LLM reranking.
nonisolated struct CandidateRanker {

    /// Rerank candidates using pure frequency data (synchronous, always available).
    func rank(_ candidates: [Candidate], context: String) -> [Candidate] {
        // Base ranking: sort by score descending
        // Future: apply simple n-gram context scoring here
        return candidates.sorted { $0.score > $1.score }
    }

    /// Apply LLM-provided ordering on top of dictionary ranks.
    /// `llmOrder` is the LLM's preferred ordering of the candidate strings.
    func applyLLMRanking(to candidates: [Candidate], llmOrder: [String]) -> [Candidate] {
        var result: [Candidate] = []
        // First add LLM-ordered candidates
        for text in llmOrder {
            if let match = candidates.first(where: { $0.text == text }) {
                result.append(match)
            }
        }
        // Then append any remaining candidates not in LLM list
        for c in candidates {
            if !result.contains(where: { $0.text == c.text }) {
                result.append(c)
            }
        }
        return result
    }
}

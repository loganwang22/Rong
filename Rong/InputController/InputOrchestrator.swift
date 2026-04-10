import Foundation

/// Central pipeline coordinator for input processing.
/// Two-phase strategy:
///   Phase 1 (instant): LanguageDetector → PinyinSegmenter → PinyinDictionary → show candidates
///   Phase 2 (async):   LLMEngine generates full Chinese from pinyin with context, updates candidates
nonisolated final class InputOrchestrator {

    private let segmenter = PinyinSegmenter()
    private let dictionary = PinyinDictionary.shared
    private let ranker = CandidateRanker()
    private let detector = LanguageDetector()
    private let cache = ConversionCache()

    /// Debounce work item for LLM phase
    private var llmWorkItem: DispatchWorkItem?
    private static let llmDebounceInterval: TimeInterval = 0.15  // 150ms

    /// Callback when candidates are updated asynchronously by the LLM phase.
    var onCandidatesUpdated: (([String]) -> Void)?

    // MARK: - Phase 1: Instant candidates

    /// Synchronously produce candidates from the dictionary.
    /// Returns (mode, candidates) where mode is the detected input mode.
    func processSynchronous(buffer: String, context: String) -> (mode: InputMode, candidates: [String]) {
        guard !buffer.isEmpty else {
            return (.undecided, [])
        }

        let language = detector.detectLanguage(of: buffer)

        switch language {
        case .english:
            return (.english, [])

        case .chinese:
            let candidates = dictionaryCandidates(for: buffer, context: context)
            return (.chinese, candidates)

        case .ambiguous:
            // For ambiguous input, try dictionary lookup. If we get results, treat as Chinese.
            let candidates = dictionaryCandidates(for: buffer, context: context)
            if !candidates.isEmpty {
                return (.chinese, candidates)
            }
            return (.undecided, [])
        }
    }

    // MARK: - Phase 2: Async LLM refinement

    /// Kick off a debounced LLM call to refine candidates.
    /// Results delivered via `onCandidatesUpdated` callback.
    func requestLLMRefinement(buffer: String, context: String, currentCandidates: [String]) {
        // Cancel any pending debounced call
        llmWorkItem?.cancel()

        // Check cache first
        let cacheKey = ConversionCache.key(pinyin: buffer, context: context)
        if let cached = cache.get(cacheKey) {
            // Deliver cached result immediately
            var updated = [cached] + currentCandidates.filter { $0 != cached }
            updated = Array(updated.prefix(9))
            onCandidatesUpdated?(updated)
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task {
                let result = await LLMEngine.shared.convertPinyin(buffer, context: context)
                guard let result, !result.isEmpty else { return }

                // Cache the result
                self.cache.set(cacheKey, value: result)

                // Merge LLM result at top, keep existing candidates below
                var updated = [result] + currentCandidates.filter { $0 != result }
                updated = Array(updated.prefix(9))
                self.onCandidatesUpdated?(updated)
            }
        }

        llmWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.llmDebounceInterval,
            execute: workItem
        )
    }

    /// Cancel any pending LLM work.
    func cancelPendingLLM() {
        llmWorkItem?.cancel()
        llmWorkItem = nil
    }

    // MARK: - Private

    private func dictionaryCandidates(for buffer: String, context: String) -> [String] {
        let segmentations = segmenter.segment(buffer)
        var raw: [Candidate] = []
        for syllables in segmentations {
            let result = dictionary.lookup(syllables)
            raw.append(contentsOf: result)
        }

        // Deduplicate preserving order
        var seen = Set<String>()
        raw = raw.filter { seen.insert($0.text).inserted }

        // Rank by frequency
        raw = ranker.rank(raw, context: context)

        let candidates = raw.prefix(9).map(\.text)
        return candidates.isEmpty ? [buffer] : Array(candidates)
    }
}

import Foundation

nonisolated enum Language {
    case english
    case chinese
    case ambiguous
}

/// Heuristic-first language detector for the Rong IME.
/// Runs entirely in-process in <1ms without any LLM call.
nonisolated struct LanguageDetector {

    // Common English words that are NOT valid Pinyin
    private static let commonEnglishWords: Set<String> = {
        let words: [String] = [
            "the","and","for","that","with","this","from","have","they",
            "will","been","were","said","each","which","their","would",
            "there","could","other","these","those","about","above",
            "after","again","against","all","also","always","another",
            "any","are","around","as","at","away","back","be","because",
            "before","being","between","both","but","by","came","can",
            "did","do","does","done","during","each","even","ever",
            "every","few","find","first","found","get","give","got",
            "great","had","has","him","his","how","if","in","into",
            "is","it","its","just","know","last","like","little","look",
            "made","make","many","may","more","most","much","must",
            "my","never","new","next","no","not","now","of","off","on",
            "one","only","open","or","other","our","out","over","own",
            "part","people","place","right","same","see","should","since",
            "so","some","still","such","take","than","then","they","think",
            "three","through","time","to","too","two","under","until","up",
            "us","use","very","want","was","way","we","well","what","when",
            "where","while","who","why","work","world","year","you","your",
            // Tech terms
            "app","web","email","phone","code","data","file","user","page",
            "list","text","font","line","word","type","key","view","link",
            "icon","form","menu","mode","item","name","tag","url","api",
            "http","json","xml","css","html","sql","ios","mac","iphone",
            "ipad","apple","google","hello","world","ok","yes",
        ]
        return Set(words)
    }()

    // Words that are both valid English AND valid Pinyin — truly ambiguous
    private static let ambiguousWords: Set<String> = [
        "shi", "can", "he", "me", "we", "men", "fan", "ban", "pan",
        "pin", "bin", "tan", "wan", "ran", "gun", "hun", "sun",
        "ai", "an", "ma", "la", "ha", "pa",
    ]

    // Regex patterns impossible in Pinyin → definitely English
    private static let impossiblePinyinPattern: NSRegularExpression? = {
        let pattern = "(ck|gh|wh|th|wr|ph|[bcdfghjklmnpqrstvwxyz]{3})"
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()

    // MARK: - Detection

    func detectLanguage(of input: String) -> Language {
        let lower = input.lowercased().trimmingCharacters(in: .whitespaces)
        guard !lower.isEmpty else { return .ambiguous }

        // Single character — always ambiguous
        if lower.count == 1 { return .ambiguous }

        // Numbers / non-alpha → pass through as English
        if lower.allSatisfy({ $0.isNumber || $0.isPunctuation }) { return .english }

        // Step 1: Impossible Pinyin patterns → English
        if containsImpossiblePinyin(lower) { return .english }

        // Step 2: Known ambiguous words — mark as ambiguous for context-based resolution
        if Self.ambiguousWords.contains(lower) { return .ambiguous }

        // Step 3: Check if entirely valid Pinyin
        let segmenter = PinyinSegmenter()
        if segmenter.isValidPinyin(lower) { return .chinese }

        // Step 4: Common English word list
        if Self.commonEnglishWords.contains(lower) { return .english }

        // Step 5: Mixed — has non-pinyin chars mixed with letters
        if lower.contains(where: { !$0.isLetter }) { return .english }

        // Default: treat as Chinese Pinyin attempt
        return .chinese
    }

    // MARK: - Private

    private func containsImpossiblePinyin(_ s: String) -> Bool {
        guard let regex = Self.impossiblePinyinPattern else { return false }
        let range = NSRange(s.startIndex..., in: s)
        return regex.firstMatch(in: s, options: [], range: range) != nil
    }
}

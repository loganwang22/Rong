import Foundation

/// LRU cache for pinyin-to-Chinese conversion results.
/// Avoids redundant LLM calls for repeated or recently-seen inputs.
nonisolated final class ConversionCache {
    private struct Entry {
        let value: String
        var lastAccess: UInt64
    }

    private var cache: [String: Entry] = [:]
    private var accessCounter: UInt64 = 0
    private let maxEntries: Int

    init(maxEntries: Int = 1000) {
        self.maxEntries = maxEntries
    }

    /// Build a cache key from pinyin and context.
    static func key(pinyin: String, context: String) -> String {
        // Use last 50 chars of context for the key to balance hit rate vs specificity
        let contextSuffix = String(context.suffix(50))
        return "\(contextSuffix)|\(pinyin)"
    }

    /// Look up a cached conversion result.
    func get(_ key: String) -> String? {
        guard var entry = cache[key] else { return nil }
        accessCounter += 1
        entry.lastAccess = accessCounter
        cache[key] = entry
        return entry.value
    }

    /// Store a conversion result.
    func set(_ key: String, value: String) {
        accessCounter += 1
        cache[key] = Entry(value: value, lastAccess: accessCounter)
        evictIfNeeded()
    }

    private func evictIfNeeded() {
        guard cache.count > maxEntries else { return }
        // Remove least recently accessed entries
        let sorted = cache.sorted { $0.value.lastAccess < $1.value.lastAccess }
        let toRemove = cache.count - maxEntries
        for (key, _) in sorted.prefix(toRemove) {
            cache.removeValue(forKey: key)
        }
    }
}

import Foundation

/// Manages a rolling window of recently committed text for LLM context.
/// Used only from the main thread via RongInputController.
nonisolated final class ContextManager {
    static let shared = ContextManager()

    private var buffer: String = ""
    private let maxLength = 200

    private init() {}

    /// The current context string (last N committed characters).
    var context: String { buffer }

    /// Append newly committed text to the rolling buffer.
    func append(_ text: String) {
        buffer += text
        if buffer.count > maxLength {
            buffer = String(buffer.suffix(maxLength))
        }
    }

    /// Clear context (e.g. when switching apps or input sources).
    func clear() {
        buffer = ""
    }
}

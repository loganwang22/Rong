import Foundation

/// Input mode determined by language detection.
nonisolated enum InputMode {
    case undecided
    case english
    case chinese
}

/// State machine for the composing buffer.
nonisolated enum InputState: Equatable {
    case idle
    case composing(buffer: String, mode: InputMode)

    var buffer: String {
        switch self {
        case .idle: return ""
        case .composing(let buf, _): return buf
        }
    }

    var mode: InputMode {
        switch self {
        case .idle: return .undecided
        case .composing(_, let m): return m
        }
    }

    var isComposing: Bool {
        if case .composing = self { return true }
        return false
    }

    func appending(_ text: String) -> InputState {
        .composing(buffer: buffer + text, mode: mode)
    }

    func withMode(_ newMode: InputMode) -> InputState {
        guard case .composing(let buf, _) = self else { return self }
        return .composing(buffer: buf, mode: newMode)
    }

    func droppingLast() -> InputState {
        let newBuf = String(buffer.dropLast())
        return newBuf.isEmpty ? .idle : .composing(buffer: newBuf, mode: mode)
    }

    // Equatable conformance — InputMode doesn't auto-conform
    static func == (lhs: InputState, rhs: InputState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.composing(let a, _), .composing(let b, _)): return a == b
        default: return false
        }
    }
}

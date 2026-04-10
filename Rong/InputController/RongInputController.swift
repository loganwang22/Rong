import Cocoa
import InputMethodKit

@objc(RongInputController)
class RongInputController: IMKInputController {

    // MARK: - State

    private var state: InputState = .idle
    private var candidates: [String] = []
    private let orchestrator = InputOrchestrator()

    // Convenience accessors
    private var appDelegate: AppDelegate? {
        NSApplication.shared.delegate as? AppDelegate
    }

    private var candidatePanel: IMKCandidates? {
        appDelegate?.candidatePanel
    }

    // MARK: - Lifecycle

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        orchestrator.onCandidatesUpdated = { [weak self] updated in
            guard let self, self.state.isComposing else { return }
            self.candidates = updated
            self.candidatePanel?.update()
        }
    }

    // MARK: - IMKInputController overrides

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let text = string, !text.isEmpty else { return false }

        // Space key comes as " " in inputText
        if text == " " {
            return handleSpace(client: sender)
        }

        let char = text.unicodeScalars.first!

        // Handle backspace (ASCII 127 or 8)
        if char.value == 127 || char.value == 8 {
            return handleBackspace(client: sender)
        }

        // Pass control characters through
        if char.value < 32 {
            return false
        }

        // If currently composing, handle candidate selection (digits 1-9)
        if state.isComposing, let digit = Int(text), digit >= 1, digit <= 9 {
            return selectCandidate(at: digit - 1, client: sender)
        }

        // Non-letter when idle: pass through
        if !state.isComposing && !text.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) {
            return false
        }

        // Accumulate into composing buffer
        state = state.isComposing ? state.appending(text) : .composing(buffer: text, mode: .undecided)
        updateCandidates(client: sender)
        return true
    }

    override func didCommand(by aSelector: Selector!, client sender: Any!) -> Bool {
        switch aSelector {
        case #selector(NSResponder.insertNewline(_:)),
             #selector(NSResponder.insertTab(_:)):
            return commitTopCandidate(client: sender)

        case #selector(NSResponder.cancelOperation(_:)):
            return handleEscape(client: sender)

        case #selector(NSResponder.deleteBackward(_:)):
            return handleBackspace(client: sender)

        default:
            return false
        }
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        return candidates
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        guard let text = candidateString?.string else { return }
        commitText(text, client: client())
        reset()
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        // Could preview — no-op for now
    }

    // MARK: - Key Handlers

    private func handleSpace(client sender: Any!) -> Bool {
        guard state.isComposing else { return false }

        let buffer = state.buffer

        switch state.mode {
        case .english:
            // English passthrough: commit raw buffer + space
            commitText(buffer + " ", client: sender)
            reset()

        case .chinese, .undecided:
            if candidates.isEmpty || candidates.first == buffer {
                // No real candidates — pass through as English
                commitText(buffer + " ", client: sender)
                reset()
            } else {
                commitTopCandidate(client: sender)
            }
        }
        return true
    }

    @discardableResult
    private func handleBackspace(client sender: Any!) -> Bool {
        guard state.isComposing else { return false }
        orchestrator.cancelPendingLLM()
        state = state.droppingLast()
        if state == .idle {
            hideCandidatePanel()
            (sender as? IMKTextInput)?.setMarkedText(
                "", selectionRange: NSRange(location: 0, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0)
            )
        } else {
            updateCandidates(client: sender)
        }
        return true
    }

    private func handleEscape(client sender: Any!) -> Bool {
        guard state.isComposing else { return false }
        let raw = state.buffer
        commitText(raw, client: sender)
        reset()
        return true
    }

    @discardableResult
    private func selectCandidate(at index: Int, client sender: Any!) -> Bool {
        guard index < candidates.count else { return false }
        commitText(candidates[index], client: sender)
        reset()
        return true
    }

    @discardableResult
    private func commitTopCandidate(client sender: Any!) -> Bool {
        guard state.isComposing else { return false }
        let text = candidates.first ?? state.buffer
        commitText(text, client: sender)
        reset()
        return true
    }

    // MARK: - Candidate Updates

    private func updateCandidates(client sender: Any!) {
        let buffer = state.buffer
        guard !buffer.isEmpty else {
            candidates = []
            hideCandidatePanel()
            return
        }

        // Update marked text
        let client = sender as? IMKTextInput
        client?.setMarkedText(
            buffer,
            selectionRange: NSRange(location: buffer.count, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )

        // Phase 1: synchronous dictionary lookup
        let context = ContextManager.shared.context
        let (mode, dictCandidates) = orchestrator.processSynchronous(buffer: buffer, context: context)

        // Update mode on state
        state = state.withMode(mode)

        if mode == .english {
            // English mode: no candidate panel, just show marked text
            candidates = []
            hideCandidatePanel()
            return
        }

        candidates = dictCandidates
        if !candidates.isEmpty {
            showCandidatePanel()
        }

        // Phase 2: async LLM refinement (debounced)
        orchestrator.requestLLMRefinement(
            buffer: buffer,
            context: context,
            currentCandidates: candidates
        )
    }

    // MARK: - Helpers

    private func commitText(_ text: String, client sender: Any!) {
        (sender as? IMKTextInput)?.insertText(
            text, replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        (sender as? IMKTextInput)?.setMarkedText(
            "", selectionRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        ContextManager.shared.append(text)
    }

    private func reset() {
        orchestrator.cancelPendingLLM()
        state = .idle
        candidates = []
        hideCandidatePanel()
    }

    private func showCandidatePanel() {
        guard let panel = candidatePanel, !candidates.isEmpty else { return }
        panel.update()
        panel.show()
    }

    private func hideCandidatePanel() {
        candidatePanel?.hide()
    }
}

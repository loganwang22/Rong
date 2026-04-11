import Foundation

/// Async LLM engine for pinyin conversion and candidate reranking.
/// Currently a stub — returns nil/passthrough until llama.cpp is integrated.
///
/// To activate LLM support:
/// 1. Drop a `.gguf` file into `Rong/Models/` (see the README there for a fetch
///    script). The file-system synchronized group will auto-include it in the
///    bundle's Resources on the next build.
/// 2. Add a working llama.cpp SPM package to the Xcode project
/// 3. `import llama` and replace the stub methods with real inference
actor LLMEngine {
    static let shared = LLMEngine()

    /// Model basenames (no extension) the engine will try to load, in priority order.
    /// Add entries here when you want to support alternative quantizations.
    private static let candidateModelNames: [String] = [
        "qwen2.5-0.5b-instruct-q4_k_m",
        "qwen2.5-0.5b-instruct-q5_k_m",
        "qwen2.5-0.5b-instruct-q8_0",
    ]

    private(set) var isLoaded = false
    private var isLoading = false

    private init() {}

    // MARK: - Model Loading

    /// Preload the model in the background. Called from AppDelegate on launch.
    func preload() async {
        await loadModelIfNeeded()
    }

    private func loadModelIfNeeded() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true

        // Search the bundle root — the file-system synchronized group flattens
        // `Rong/Models/foo.gguf` into the bundle's Resources root, so no
        // `subdirectory:` argument is needed.
        var found: URL?
        for name in Self.candidateModelNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "gguf") {
                found = url
                break
            }
        }

        guard let modelURL = found else {
            NSLog("Rong: No LLM .gguf found in bundle (looked for \(Self.candidateModelNames.map { "\($0).gguf" }.joined(separator: ", "))) — running dictionary-only")
            isLoading = false
            return
        }

        NSLog("Rong: Found LLM model at \(modelURL.path)")
        // TODO: Initialize llama.cpp model and context here
        // llama_backend_init()
        // let modelParams = llama_model_default_params()
        // model = llama_model_load_from_file(modelURL.path, modelParams)
        // ...

        isLoading = false
        // isLoaded = true  // Uncomment when real inference is wired up
        NSLog("Rong: LLM stub loaded (inference not yet implemented)")
    }

    // MARK: - Inference (stubs)

    /// Convert pinyin to Chinese using the LLM. Returns nil until model is integrated.
    func convertPinyin(_ pinyin: String, context: String) async -> String? {
        guard isLoaded else { return nil }
        // TODO: Use LLMPrompts.pinyinToChinesePrompt() and run inference
        return nil
    }

    /// Rerank candidates using the LLM. Returns candidates unchanged until model is integrated.
    func rankCandidates(_ candidates: [String], context: String) async -> [String] {
        guard isLoaded else { return candidates }
        // TODO: Use LLMPrompts.rerankPrompt() and run inference
        return candidates
    }

    /// Detect language for ambiguous input using the LLM.
    func detectLanguage(_ input: String, context: String) async -> Language? {
        guard isLoaded else { return nil }
        // TODO: Use LLMPrompts.languageDetectionPrompt() and run inference
        return nil
    }
}

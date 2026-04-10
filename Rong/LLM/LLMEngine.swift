import Foundation

/// Async LLM engine for pinyin conversion and candidate reranking.
/// Currently a stub — returns nil/passthrough until llama.cpp is integrated.
///
/// To activate LLM support:
/// 1. Add a working llama.cpp SPM package to the Xcode project
/// 2. `import llama` and replace the stub methods with real inference
/// 3. Place qwen2.5-0.5b-instruct-q4_k_m.gguf in Resources/Models/
actor LLMEngine {
    static let shared = LLMEngine()

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

        let modelName = "qwen2.5-0.5b-instruct-q4_k_m"
        guard let modelURL = Bundle.main.url(
            forResource: modelName,
            withExtension: "gguf",
            subdirectory: "Models"
        ) else {
            NSLog("Rong: LLM model '\(modelName).gguf' not found in bundle Resources/Models/ — running dictionary-only")
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

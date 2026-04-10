import Foundation

/// ChatML prompt templates for Qwen2.5 LLM inference.
nonisolated enum LLMPrompts {

    /// Pinyin-to-Chinese conversion prompt.
    /// Returns a ChatML prompt that asks the model to convert pinyin to natural Chinese.
    static func pinyinToChinesePrompt(pinyin: String, context: String) -> String {
        let contextPart = context.isEmpty ? "" : "上下文：\(context)\n"
        return """
        <|im_start|>system
        你是拼音输入法。将拼音转为最自然的简体中文。只输出中文，不要解释。<|im_end|>
        <|im_start|>user
        \(contextPart)拼音：\(pinyin)<|im_end|>
        <|im_start|>assistant
        """
    }

    /// Candidate reranking prompt.
    /// Given numbered candidates, asks the model to pick the most natural one.
    static func rerankPrompt(candidates: [String], context: String) -> String {
        let numbered = candidates.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        let contextPart = context.isEmpty ? "" : "上下文：\(context)\n"
        return """
        <|im_start|>system
        选择最自然的中文。只回复数字。<|im_end|>
        <|im_start|>user
        \(contextPart)\(numbered)<|im_end|>
        <|im_start|>assistant
        """
    }

    /// Language detection prompt for ambiguous inputs.
    static func languageDetectionPrompt(input: String, context: String) -> String {
        let contextPart = context.isEmpty ? "" : "上下文：\(context)\n"
        return """
        <|im_start|>system
        判断输入是英文单词还是中文拼音。只回答EN或CN。<|im_end|>
        <|im_start|>user
        \(contextPart)输入：\(input)<|im_end|>
        <|im_start|>assistant
        """
    }
}

// Tools/BuildDict/main.swift
// One-time CLI tool: parses CC-CEDICT and emits rong.dict
//
// Usage:
//   swift Tools/BuildDict/main.swift <path/to/cedict_ts.u8.txt> <output/rong.dict>
//
// Output format (tab-separated, UTF-8):
//   ni hao\t你好\t750
//   ...
// One entry per line. Syllable key uses spaces between syllables.

import Foundation

guard CommandLine.arguments.count >= 3 else {
    print("Usage: BuildDict <cedict_ts.u8.txt> <rong.dict>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

guard let input = try? String(contentsOfFile: inputPath, encoding: .utf8) else {
    print("Error: Cannot read \(inputPath)")
    exit(1)
}

// CC-CEDICT format:
// Traditional Simplified [pin1 yin1] /definition1/definition2/
// Lines starting with # are comments
let lineRegex = try! NSRegularExpression(
    pattern: #"^(\S+)\s+(\S+)\s+\[([^\]]+)\]\s+/(.+)/$"#
)

// Frequency table: simplified → score
// Using character length as a proxy for now (shorter = more common)
// A real implementation would merge SUBTLEX-CH data here
var entries: [(key: String, chinese: String, score: Double)] = []

let lines = input.components(separatedBy: "\n")
var lineCount = 0
var parsedCount = 0

for line in lines {
    lineCount += 1
    if line.hasPrefix("#") || line.isEmpty { continue }

    let nsLine = line as NSString
    let range = NSRange(location: 0, length: nsLine.length)
    guard let match = lineRegex.firstMatch(in: line, range: range) else { continue }

    let simplified = nsLine.substring(with: match.range(at: 2))
    let pinyinRaw = nsLine.substring(with: match.range(at: 3)) // e.g. "ni3 hao3"

    // Strip tone numbers to get bare syllables: "ni3 hao3" → "ni hao"
    let pinyinKey = pinyinRaw
        .lowercased()
        .replacingOccurrences(of: "[1-5]", with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)

    // Skip entries with non-ASCII pinyin (e.g. proper nouns with capital letters after strip)
    guard pinyinKey.unicodeScalars.allSatisfy({ $0.value < 128 }) else { continue }

    // Simple frequency heuristic: prefer single characters and short common words
    let charCount = simplified.unicodeScalars.filter { $0.value > 127 }.count
    let score: Double
    switch charCount {
    case 1: score = 500.0
    case 2: score = 300.0
    case 3: score = 150.0
    case 4: score = 80.0
    default: score = 40.0
    }

    entries.append((key: pinyinKey, chinese: simplified, score: score))
    parsedCount += 1
}

// Sort by key then score descending
entries.sort {
    if $0.key != $1.key { return $0.key < $1.key }
    return $0.score > $1.score
}

// Write output
var output = ""
for entry in entries {
    output += "\(entry.key)\t\(entry.chinese)\t\(Int(entry.score))\n"
}

do {
    try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
    print("Done: \(parsedCount) entries written to \(outputPath)")
} catch {
    print("Error writing output: \(error)")
    exit(1)
}

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Rong is a macOS Input Method Kit (IMK) based Pinyin → Simplified Chinese input method written in Swift. It targets macOS 14+ and is structured as an `.app` bundle that registers with the system as an IME (`LSBackgroundOnly`, `NSPrincipalClass = NSApplication`, bundle id `com.loganwang.inputmethod.Rong`).

## Build / Run

There is no Swift Package — everything is built through the Xcode project (`Rong.xcodeproj`), which uses a `PBXFileSystemSynchronizedRootGroup` so files added under `Rong/` are picked up automatically without editing `project.pbxproj`.

```bash
# Debug build
xcodebuild -project Rong.xcodeproj -scheme Rong -configuration Debug build

# Release build
xcodebuild -project Rong.xcodeproj -scheme Rong -configuration Release build
```

Installing the IME for local testing requires copying the built `Rong.app` into `~/Library/Input Methods/`, then logging out/in (or restarting the IME process) and enabling it in System Settings → Keyboard → Input Sources. Because it is a background IMK agent, it cannot be run directly from Xcode's Run button in a meaningful way — you must reinstall and let `loginwindow`/IMK relaunch it.

There are no tests in the project at present.

### BuildDict CLI

`Tools/BuildDict/main.swift` is a standalone script that parses CC-CEDICT into the `rong.dict` runtime format (tab-separated `pinyin\tsimplified\tscore`). It is not part of the Xcode target — run it directly:

```bash
swift Tools/BuildDict/main.swift path/to/cedict_ts.u8.txt Rong/Resources/rong.dict
```

Once `rong.dict` exists inside the bundle's Resources, `PinyinDictionary.loadBundledDict()` will merge it on top of the built-in seed table at launch.

## Architecture

Rong is organized as a two-phase input pipeline: an instant, fully in-process dictionary path, and an optional asynchronous LLM refinement path layered on top.

### Entry point and IMK wiring

- `main.swift` creates an `IMKServer` (connection name **must** match `InputMethodConnectionName` in `Info.plist`: `com.loganwang.inputmethod.Rong_Connection`) *before* `NSApplication.shared.run()`. The server is held by `AppDelegate` so it stays alive.
- `AppDelegate` also owns the shared `IMKCandidates` panel (single-column scrolling) and kicks off `LLMEngine.shared.preload()` in the background.
- `RongInputController` (exposed to Objective-C as `@objc(RongInputController)` so `InputMethodServerControllerClass` in `Info.plist` can find it) is the `IMKInputController` subclass that receives keystrokes.

If you rename the controller class, change the connection name, or the bundle id, you must update `Info.plist`, `main.swift`, and the Xcode build settings in lockstep — IMK will silently fail to load the IME otherwise.

### Input pipeline

`RongInputController` is intentionally thin — it manages an `InputState` state machine and delegates all language/conversion work to `InputOrchestrator`.

1. Keystrokes arrive via `inputText(_:client:)`. Space/backspace/escape/enter/tab and digits 1–9 (candidate selection) are special-cased; everything else accumulates into `state.buffer`.
2. `updateCandidates` sets marked text, then calls `orchestrator.processSynchronous(buffer:context:)` — this is **Phase 1** and must stay fast and pure.
3. `InputOrchestrator.processSynchronous` runs `LanguageDetector` → if Chinese/ambiguous, `PinyinSegmenter.segment` → `PinyinDictionary.lookup` → `CandidateRanker.rank`, returning up to 9 candidates plus a resolved `InputMode`. English mode short-circuits with an empty candidate list so the app just renders the raw marked text.
4. `InputOrchestrator.requestLLMRefinement` then schedules **Phase 2**: a 150ms-debounced `DispatchWorkItem` that checks `ConversionCache` first, then awaits `LLMEngine.shared.convertPinyin`. Any result is merged to the top of the current candidates and delivered via the `onCandidatesUpdated` callback, which `RongInputController` uses to call `candidatePanel.update()`.
5. On commit (space/enter/tab/digit/escape), the chosen text is inserted via `insertText`, marked text is cleared, and `ContextManager.shared.append(text)` extends the 200-char rolling context window used by both the ranker and the LLM.

Backspace and escape always call `orchestrator.cancelPendingLLM()` to avoid a stale async result overwriting fresh candidates.

### Language detection

`LanguageDetector` is heuristic-only and must stay sub-millisecond:

1. Regex for impossible-in-Pinyin patterns (`ck`, `gh`, `wh`, `th`, `wr`, `ph`, three consonants in a row) → English.
2. A small `ambiguousWords` set (e.g. `shi`, `can`, `he`, `me`, `we`) → `ambiguous`, meaning "let dictionary lookup decide."
3. `PinyinSegmenter.isValidPinyin` → Chinese.
4. `commonEnglishWords` fallback list → English.
5. Default: Chinese attempt.

The `.ambiguous` return path is meaningful — `InputOrchestrator` tries a dictionary lookup and promotes to Chinese only if it finds real candidates; otherwise it stays `undecided` so the UI doesn't commit to a mode.

### Pinyin engine

- `PinyinSegmenter` hard-codes the 411-syllable Mandarin Pinyin inventory as a `Set<String>` and does greedy max-forward matching (up to 6 chars per syllable) with one alternative segmentation for ambiguity and a longest-valid-prefix fallback for partial input. Changes to the syllable set should be made carefully — it is the ground truth for both segmentation and `isValidPinyin`.
- `PinyinDictionary` is a singleton with a `[String: [(text, score)]]` in-memory table keyed by space-separated syllables (e.g. `"ni hao"`). It seeds from a hand-written `loadBuiltIn()` table of ~200 high-frequency entries and merges `rong.dict` from the bundle if present. `lookup` falls back to a prefix scan (`prefixLookup`) when the exact key is missing, so partial pinyin typing still produces candidates.
- `CandidateRanker` applies final ordering with optional context weighting.

### LLM layer (stub)

`LLMEngine` is an `actor` designed to host a llama.cpp-backed Qwen 2.5 0.5B instruct model (`qwen2.5-0.5b-instruct-q4_k_m.gguf` expected at `Resources/Models/` inside the app bundle). **It is currently a stub** — `convertPinyin`, `rankCandidates`, and `detectLanguage` all return `nil`/passthrough unless `isLoaded` flips true, which happens only when the llama.cpp integration is wired up (see comments in `LLMEngine.swift` for the expected wiring order). `LLMPrompts.swift` holds the prompt templates the engine will use.

Until then, the IME runs dictionary-only and the `ConversionCache` / debounced refinement path are effectively inert — but all the plumbing in `InputOrchestrator` and `RongInputController` already handles async updates, so dropping in a real implementation should not require touching the controller.

### Concurrency model

The target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so everything is main-actor isolated by default. Types that intentionally escape that (`InputOrchestrator`, `PinyinSegmenter`, `PinyinDictionary`, `LanguageDetector`, `ContextManager`, `InputState`, `Candidate`, `Language`, `InputMode`) are explicitly marked `nonisolated`. `LLMEngine` is an `actor`. When adding new types in the pipeline, match this pattern — accidentally making a pipeline type main-actor-isolated will either force everything onto the main thread or break the async refinement path.

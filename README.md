# Rong

A macOS Pinyin → Simplified Chinese input method, built on
[InputMethodKit](https://developer.apple.com/documentation/inputmethodkit). The
long-term goal is a two-phase converter: an instant in-process dictionary path
for every keystroke, with an optional on-device LLM (Qwen 2.5 0.5B via
llama.cpp) asynchronously refining candidates using the surrounding context.

Today, the dictionary path is fully wired and the LLM path is scaffolded but
stubbed — see [`CLAUDE.md`](./CLAUDE.md) for the architectural tour.

## Requirements

- macOS 14 or later
- Xcode 17+ (the project uses `PBXFileSystemSynchronizedRootGroup`, which
  requires a modern Xcode)
- Swift 5.0 toolchain (bundled with Xcode)

## First-time setup

The repo ships **without** two pieces of generated/downloaded content:

| Artifact                     | Path                              | How to produce it                         |
| ---------------------------- | --------------------------------- | ----------------------------------------- |
| CC-CEDICT-derived dictionary | `Rong/rong.dict`                  | `scripts/build-dict.sh`                   |
| LLM model weights (optional) | `Rong/Models/*.gguf`              | see [`Rong/Models/README.md`](./Rong/Models/README.md) |

Both paths are gitignored. The Xcode file-system synchronized group picks up
whatever you drop in there on the next build.

### Build the dictionary

```bash
scripts/build-dict.sh
```

Downloads CC-CEDICT from mdbg.net into `build/cedict/` (cached across runs),
runs `Tools/BuildDict/main.swift`, and writes `Rong/rong.dict` (~2.8 MB,
~125 k entries). Pass `--force` to re-download the source.

Without `rong.dict`, the IME falls back to a ~200-entry hand-written seed
table — usable for smoke tests (`ni hao`, `wo men`, `zhong guo`) but not
real typing.

### (Optional) Add the LLM model

See [`Rong/Models/README.md`](./Rong/Models/README.md). Until llama.cpp is
integrated as an SPM dependency, dropping in a `.gguf` only exercises the
discovery path — inference itself is still stubbed in
`Rong/LLM/LLMEngine.swift`.

## Build

```bash
xcodebuild -project Rong.xcodeproj -scheme Rong -configuration Debug build
```

Or just open `Rong.xcodeproj` in Xcode and ⌘B. Release builds work the same
with `-configuration Release`.

## Install and test

IMK background agents cannot be usefully run via Xcode's Run button — macOS
only loads input methods from `~/Library/Input Methods/`. The dev loop is:

```bash
# 1. Build
xcodebuild -project Rong.xcodeproj -scheme Rong -configuration Debug build

# 2. Locate the built app
BUILT=$(xcodebuild -project Rong.xcodeproj -scheme Rong -configuration Debug \
  -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR /{print $3}')

# 3. Replace the installed copy
rm -rf ~/Library/Input\ Methods/Rong.app
cp -R "$BUILT/Rong.app" ~/Library/Input\ Methods/

# 4. Kill the running IME so the new binary is picked up on next switch
killall Rong 2>/dev/null || true
```

On the **first** install only, register the app with Launch Services and add
it as an input source:

```bash
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
  -f ~/Library/Input\ Methods/Rong.app
```

Then **System Settings → Keyboard → Input Sources → Edit → +** → Chinese,
Simplified → **Rong** → Add. Switch to Rong via the menu-bar input picker and
type in any text field.

Key bindings during composition:

| Key            | Action                              |
| -------------- | ----------------------------------- |
| `a`–`z`        | Append to composing buffer          |
| Space          | Commit top candidate (or pass-through in English mode) |
| Return / Tab   | Commit top candidate                |
| `1`–`9`        | Pick candidate by index             |
| Backspace      | Shrink buffer                       |
| Escape         | Commit raw pinyin, exit composition |

### Logs

```bash
log stream --predicate 'process == "Rong"' --level debug
```

Expected startup lines on a fresh launch:

```
Rong: IMKServer started — connection=com.loganwang.inputmethod.Rong_Connection, controller=RongInputController
Rong IME started
Rong: No LLM .gguf found in bundle … — running dictionary-only
Rong: Loaded bundled dict — 124708 lines merged, 86628 total keys
```

## Uninstall

Remove Rong from System Settings → Keyboard → Input Sources first, then:

```bash
rm -rf ~/Library/Input\ Methods/Rong.app
killall Rong 2>/dev/null || true
```

## Layout

```
Rong/
  main.swift                 Entry point; reads IMK config from Info.plist
  AppDelegate.swift          Owns IMKServer + candidate panel
  Info.plist                 IMK registration (connection name, controller class)
  ContextManager.swift       Rolling 200-char context window
  InputController/           RongInputController, state machine, orchestrator
  LanguageDetection/         Heuristic English/Chinese classifier
  PinyinEngine/              Syllable segmenter, dictionary, ranker
  LLM/                       llama.cpp-ready stub + prompts + conversion cache
  Models/                    Drop-in location for .gguf files (gitignored)
  Assets.xcassets
Tools/
  BuildDict/main.swift       CC-CEDICT → rong.dict compiler (standalone script)
scripts/
  build-dict.sh              Download CC-CEDICT + run BuildDict
```

For the architectural walkthrough — two-phase pipeline, concurrency model,
IMK registration rules — see [`CLAUDE.md`](./CLAUDE.md).

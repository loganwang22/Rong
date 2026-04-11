# LLM Models

This folder is auto-included in the app bundle by the `Rong` target's
file-system synchronized group. Any `.gguf` file dropped in here will be
copied into `Rong.app/Contents/Resources/` on the next build, where
`LLMEngine` will pick it up at startup.

## Supported basenames

`LLMEngine.candidateModelNames` (see `Rong/LLM/LLMEngine.swift`) is searched
in order. The default list is:

1. `qwen2.5-0.5b-instruct-q4_k_m.gguf`   (~350 MB — recommended default)
2. `qwen2.5-0.5b-instruct-q5_k_m.gguf`
3. `qwen2.5-0.5b-instruct-q8_0.gguf`

Add new entries to the Swift array if you want to ship a different quant.

## Fetching the default model

From the repo root:

```bash
curl -L \
  https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  -o Rong/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf
```

The file is ~350 MB and is intentionally **not** committed — add
`Rong/Models/*.gguf` to `.gitignore` if you plan to keep it locally.

## Wiring llama.cpp

Even with a `.gguf` present, `LLMEngine` remains a stub until llama.cpp is
integrated as an SPM dependency and the `convertPinyin`, `rankCandidates`,
and `detectLanguage` methods are replaced with real inference calls. Until
that's done, the IME runs dictionary-only and the Phase-2 async refinement
path is effectively inert — the bundle-detection plumbing above is what
keeps the door open.

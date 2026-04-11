#!/usr/bin/env bash
# Regenerate Rong/rong.dict from CC-CEDICT.
#
# Downloads cedict_1_0_ts_utf-8_mdbg.txt.gz into build/ (cached) and runs the
# BuildDict Swift script to emit Rong/rong.dict. The output path is what the
# Xcode file-system synchronized group picks up automatically on the next build.
#
# Usage:   scripts/build-dict.sh
# Re-run:  scripts/build-dict.sh --force   (re-download CC-CEDICT)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CACHE_DIR="build/cedict"
CEDICT_URL="https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz"
CEDICT_GZ="$CACHE_DIR/cedict.txt.gz"
CEDICT_TXT="$CACHE_DIR/cedict.txt"
OUTPUT="Rong/rong.dict"

mkdir -p "$CACHE_DIR"

if [[ "${1:-}" == "--force" ]]; then
  rm -f "$CEDICT_GZ" "$CEDICT_TXT"
fi

if [[ ! -f "$CEDICT_TXT" ]]; then
  echo "Downloading CC-CEDICT…"
  curl -sSL "$CEDICT_URL" -o "$CEDICT_GZ"
  gunzip -f "$CEDICT_GZ"
  echo "  → $(wc -l < "$CEDICT_TXT" | tr -d ' ') lines cached at $CEDICT_TXT"
else
  echo "Using cached CC-CEDICT at $CEDICT_TXT (pass --force to re-download)"
fi

echo "Running BuildDict…"
swift Tools/BuildDict/main.swift "$CEDICT_TXT" "$OUTPUT"
echo "Wrote $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"

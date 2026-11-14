#!/usr/bin/env bash
# Verify the Miko piper-plus voice model downloaded by fetch-piper-assets.sh.
#
# Hashes are copied from
# shinshin86/chrome-on-aituber/scripts/piper/fetch-miko-voice.sh, which pins
# the Hugging Face revision b7db1788bcab3ccaec6d3b541ba6195edab48e1f.
#
# Usage: EXPECTED_MODEL_SHA256=... EXPECTED_CONFIG_SHA256=... \
#        bash scripts/verify-piper-assets.sh <path-to-public/piper/models>

set -euo pipefail

MODELS_DIR="${1:-}"
if [ -z "$MODELS_DIR" ]; then
  echo "Usage: $0 <path-to-public/piper/models>" >&2
  exit 2
fi

MODEL_SHA="${EXPECTED_MODEL_SHA256:-20155a363e0a80ed425415d73c58c6f7559407b2ddca675811379719b45e5995}"
CONFIG_SHA="${EXPECTED_CONFIG_SHA256:-f1102d8a355d23c835b4f74316ea9f86455fbbeb8fc551681c012407c4f79002}"

for pair in "sample-voice-v2.onnx:$MODEL_SHA" "sample-voice-v2.onnx.json:$CONFIG_SHA"; do
  file="${pair%%:*}"
  expected="${pair#*:}"
  target="$MODELS_DIR/$file"
  if [ ! -f "$target" ]; then
    echo "Missing voice asset: $target" >&2
    exit 1
  fi
  printf '%s  %s\n' "$expected" "$target" | sha256sum -c -
done

echo "Miko voice model verified (SHA-256)."

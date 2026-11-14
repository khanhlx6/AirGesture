#!/usr/bin/env bash
# Build the combined GitHub Pages site:
#
#   /                     Mesh Avatar Studio landing page (from shinshin86/mesh-avatar-studio)
#   /mesh-avatar-chat/    AITuber OnAir "Mesh Avatar Chat" demo (from khanhlx6/aituber-onair)
#
# The build is done from upstream sources at build time, so NO generated
# assets (38 MB of studio screenshots / MediaPipe wasm, 150 MB of piper
# assets, npm bundles) are committed to this repository.
#
# Usage:
#   bash scripts/build-site.sh                       # full build (CI / deployment)
#   SKIP_PIPER=1 bash scripts/build-site.sh          # Web Speech voice only (local preview)
#   AITUBER_SOURCE=/path/to/aituber-onair \
#   STUDIO_SOURCE=/path/to/mesh-avatar-studio \
#   SKIP_PIPER=1 bash scripts/build-site.sh          # use local checkouts, no network
#
# All inputs are environment variables, see the defaults below.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${BUILD_DIR:-$ROOT/build}"
SRC="$WORK/src"
OUT="${OUT_DIR:-$WORK/site}"

# GitHub Pages project-site prefix, e.g. "/aituber-onair/" or "/AirGesture/".
# Locally we serve from "/" so no prefix is needed.
OWNER="${GITHUB_REPOSITORY_OWNER:-khanhlx6}"
REPO_NAME="${GITHUB_REPOSITORY:-khanhlx6/aituber-onair}"
REPO_NAME="${REPO_NAME##*/}"
SITE_BASE="${SITE_BASE:-/${REPO_NAME}/}"
DEMO_BASE="${DEMO_BASE:-${SITE_BASE}mesh-avatar-chat/}"
PUBLISHED_URL="${PUBLISHED_URL:-https://${OWNER}.github.io${SITE_BASE}}"

AITUBER_REPO="${AITUBER_REPO:-khanhlx6/aituber-onair}"
AITUBER_REF="${AITUBER_REF:-main}"
STUDIO_REPO="${STUDIO_REPO:-shinshin86/mesh-avatar-studio}"
STUDIO_REF="${STUDIO_REF:-main}"

# Upstream defaults (both overridable through repository variables / env).
PIPER_ASSETS_URL="${PIPER_ASSETS_URL:-https://github.com/shinshin86/chrome-on-aituber/releases/download/piper-assets-v2/piper-assets.tar.gz}"
# Pinned revision + hashes come from
# shinshin86/chrome-on-aituber/scripts/piper/fetch-miko-voice.sh
PIPER_MODEL_BASE_URL="${PIPER_MODEL_BASE_URL:-https://huggingface.co/shinshin86/aituber-onair-miko-voice-piper-plus/resolve/b7db1788bcab3ccaec6d3b541ba6195edab48e1f}"
SKIP_PIPER="${SKIP_PIPER:-0}"

echo "==> Site base      : $SITE_BASE"
echo "==> Demo base      : $DEMO_BASE"
echo "==> Published URL  : $PUBLISHED_URL"
echo "==> Output         : $OUT"
echo "==> Piper assets   : $([ "$SKIP_PIPER" = 1 ] && echo 'skipped (Web Speech only)' || echo "$PIPER_MODEL_BASE_URL")"

rm -rf "$OUT" "$SRC"
mkdir -p "$SRC/aituber" "$SRC/studio" "$OUT"

fetch_source() {
  local repo="$1" ref="$2" dest="$3" local_src="${4:-}"
  if [ -n "$local_src" ]; then
    echo "==> Using local source $local_src for $repo"
    git -C "$local_src" archive --format=tar HEAD | tar -x -C "$dest"
  else
    echo "==> Downloading $repo@$ref"
    curl -fsSL "https://codeload.github.com/${repo}/tar.gz/refs/heads/${ref}" \
      | tar -xz --strip-components=1 -C "$dest"
  fi
}

fetch_source "$AITUBER_REPO" "$AITUBER_REF" "$SRC/aituber" "${AITUBER_SOURCE:-}"
fetch_source "$STUDIO_REPO" "$STUDIO_REF" "$SRC/studio" "${STUDIO_SOURCE:-}"

# ---------------------------------------------------------------------------
# 1. AITuber OnAir demo (follows khanhlx6/aituber-onair/.github/workflows/pages.yml)
# ---------------------------------------------------------------------------
echo "==> Building AITuber OnAir workspace + Mesh Avatar Chat demo"
cd "$SRC/aituber"
npm ci --ignore-scripts --no-audit --no-fund
npm -w @aituber-onair/chat run build
npm -w @aituber-onair/voice run build
npm -w @aituber-onair/core run build
npm --prefix demo/mesh-avatar-chat ci --ignore-scripts --no-audit --no-fund

if [ "$SKIP_PIPER" != "1" ]; then
  echo "==> Fetching piper-plus runtime + Miko voice model"
  PIPER_ASSETS_URL="$PIPER_ASSETS_URL" \
  PIPER_MODEL_BASE_URL="$PIPER_MODEL_BASE_URL" \
    npm --prefix demo/mesh-avatar-chat run fetch-piper-assets
  # Only verify when we used the pinned upstream model (a custom URL may
  # legitimately serve a different voice model).
  if [ "$PIPER_MODEL_BASE_URL" = "https://huggingface.co/shinshin86/aituber-onair-miko-voice-piper-plus/resolve/b7db1788bcab3ccaec6d3b541ba6195edab48e1f" ]; then
    EXPECTED_MODEL_SHA256=20155a363e0a80ed425415d73c58c6f7559407b2ddca675811379719b45e5995 \
    EXPECTED_CONFIG_SHA256=f1102d8a355d23c835b4f74316ea9f86455fbbeb8fc551681c012407c4f79002 \
      bash "$ROOT/scripts/verify-piper-assets.sh" "$SRC/aituber/demo/mesh-avatar-chat/public/piper/models"
  fi
else
  echo "==> SKIP_PIPER=1: demo falls back to the Web Speech voice (Miko voice option hidden)"
fi

# Point the demo's "Created with Mesh Avatar Studio" link at OUR landing page,
# and its source link at the fork we actually built from.
PUBLISHED_URL="$PUBLISHED_URL" AITUBER_REPO="$AITUBER_REPO" python3 - <<'PY'
import os, pathlib, re

app = pathlib.Path('demo/mesh-avatar-chat/src/App.tsx')
text = app.read_text()
published = os.environ['PUBLISHED_URL'].rstrip('/') + '/'
repo = 'https://github.com/' + os.environ['AITUBER_REPO']
text = re.sub(
    r"const STUDIO_URL = 'https://[^']+';",
    f"const STUDIO_URL = '{published}';",
    text,
)
text = re.sub(
    r"const REPO_URL = 'https://github.com/[^']+';",
    f"const REPO_URL = '{repo}';",
    text,
)
app.write_text(text)
PY

VITE_BASE_PATH="$DEMO_BASE" npm --prefix demo/mesh-avatar-chat run build

# ---------------------------------------------------------------------------
# 2. Mesh Avatar Studio landing page (follows mesh-avatar-studio/.github/workflows/pages.yml)
# ---------------------------------------------------------------------------
echo "==> Building Mesh Avatar Studio landing page"
cd "$SRC/studio"
npm ci --ignore-scripts --no-audit --no-fund

python3 - "$SRC/studio" "$SITE_BASE" "$PUBLISHED_URL" "$OWNER" <<'PY'
import pathlib, re, sys

root, base, published, owner = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
published = published.rstrip('/')

# The upstream Vite config hardcodes /mesh-avatar-studio/ and its own owner.
# Make both configurable so the same landing page works under any Pages repo.
cfg = root / 'site' / 'vite.config.ts'
text = cfg.read_text()
text = text.replace(
    "const base = '/mesh-avatar-studio/';",
    "const base = process.env.VITE_SITE_BASE || '/mesh-avatar-studio/';",
)
text = re.sub(
    r"const publishedUrl = `https://(?:shinshin86|\$\{pagesOwner\})\.github\.io\$\{base\}`;",
    "const publishedUrl = (process.env.VITE_PUBLISHED_URL || "
    "`https://${process.env.GITHUB_REPOSITORY_OWNER || 'shinshin86'}.github.io${base}`);",
    text,
)
cfg.write_text(text)

# Canonical / Open Graph URLs in the HTML must point at OUR page, not upstream.
for html in list((root / 'site').rglob('*.html')):
    body = html.read_text()
    body = re.sub(r'https://(?:shinshin86|khanhlegood12)\.github\.io/mesh-avatar-studio', published, body)
    html.write_text(body)
PY

VITE_SITE_BASE="$SITE_BASE" \
VITE_PUBLISHED_URL="$PUBLISHED_URL" \
GITHUB_REPOSITORY_OWNER="$OWNER" \
  npm run build:site

cp -R "$SRC/studio/site/dist/." "$OUT/"

# ---------------------------------------------------------------------------
# 3. Assemble: landing page at /, demo at /mesh-avatar-chat/
# ---------------------------------------------------------------------------
echo "==> Assembling site"
mkdir -p "$OUT/mesh-avatar-chat"
cp -R "$SRC/aituber/demo/mesh-avatar-chat/dist/." "$OUT/mesh-avatar-chat/"

python3 - "$OUT" <<'PY'
import pathlib, sys

out = pathlib.Path(sys.argv[1])

card_en = '''    <section id="mesh-avatar-chat" class="content-section" aria-labelledby="mesh-avatar-chat-title" style="border-top:1px solid rgba(127,127,127,.25);margin-top:3rem;padding-top:3rem">
      <div class="section-heading">
        <p class="eyebrow">AITuber OnAir</p>
        <h2 id="mesh-avatar-chat-title">Talk to Miko, right in your browser</h2>
        <p>The Mesh Avatar Chat demo renders the same avatar with lip sync, expressions and a voice &mdash; no server, no API key needed with Chrome's built-in Gemini Nano.</p>
        <p><a class="button primary" href="./mesh-avatar-chat/">Open Mesh Avatar Chat <span aria-hidden="true">&#8599;</span></a></p>
      </div>
    </section>
'''
card_ja = '''    <section id="mesh-avatar-chat" class="content-section" aria-labelledby="mesh-avatar-chat-title" style="border-top:1px solid rgba(127,127,127,.25);margin-top:3rem;padding-top:3rem">
      <div class="section-heading">
        <p class="eyebrow">AITuber OnAir</p>
        <h2 id="mesh-avatar-chat-title">ブラウザでミコと話そう</h2>
        <p>メッシュアバターの口パク・表情・音声つきデモです。Chrome 内蔵の Gemini Nano を使えば API キー不要、サーバーも不要で動きます。</p>
        <p><a class="button primary" href="../mesh-avatar-chat/">Mesh Avatar Chat を開く <span aria-hidden="true">&#8599;</span></a></p>
      </div>
    </section>
'''

for rel, card in [('index.html', card_en), ('ja/index.html', card_ja)]:
    page = out / rel
    if not page.exists():
        continue
    html = page.read_text()
    if 'id="mesh-avatar-chat"' in html:
        continue
    marker = '<main id="main" class="shell">'
    if marker in html:
        html = html.replace(marker, marker + '\n' + card, 1)
    else:
        html = html.replace('</body>', card + '</body>', 1)
    page.write_text(html)
PY

# Small 404 page that points visitors back to the landing page / demo.
cat > "$OUT/404.html" <<'HTML'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Page not found</title>
<meta http-equiv="refresh" content="0; url=./"></head>
<body><p>Page not found. <a href="./">Back to Mesh Avatar Studio</a> &middot;
<a href="./mesh-avatar-chat/">Open Mesh Avatar Chat</a></p></body></html>
HTML

# Intermediate checkouts contain ~1 GB of node_modules. Keep the site only,
# unless KEEP_SOURCES=1 is set for debugging.
if [ "${KEEP_SOURCES:-0}" != "1" ]; then
  rm -rf "$SRC"
fi

echo "==> Done: $(du -sh "$OUT" | cut -f1) in $OUT"
echo "    Landing page : ${OUT}/index.html"
echo "    Demo         : ${OUT}/mesh-avatar-chat/index.html"

#!/usr/bin/env bash
# Publish the Pages deploy kit to the target fork using YOUR OWN GitHub login.
#
# This is the local equivalent of .github/workflows/publish-to-fork.yml. Run it
# on a machine where `gh auth login` has push access to the target repo:
#
#   bash scripts/deploy-to-fork.sh                        # khanhlx6/aituber-onair
#   TARGET_REPO=owner/repo bash scripts/deploy-to-fork.sh
#
# It copies .github/workflows/pages.yml + scripts/ into the target repo's
# default branch, enables Pages (GitHub Actions source) and triggers a deploy.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_REPO="${TARGET_REPO:-khanhlx6/aituber-onair}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
TOKEN="${PAGES_DEPLOY_TOKEN:-${GH_TOKEN:-$(gh auth token 2>/dev/null || true)}}"

if [ -z "$TOKEN" ]; then
  echo "No GitHub token found. Run 'gh auth login' or set PAGES_DEPLOY_TOKEN." >&2
  exit 1
fi
export GH_TOKEN="$TOKEN"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Cloning $TARGET_REPO ($TARGET_BRANCH)"
git clone --branch "$TARGET_BRANCH" \
  "https://x-access-token:${TOKEN}@github.com/${TARGET_REPO}.git" "$TMP/target"
git -C "$TMP/target" config user.name "$(git -C "$ROOT" config user.name || echo 'AirGesture deploy')"
git -C "$TMP/target" config user.email "$(git -C "$ROOT" config user.email || echo 'deploy@users.noreply.github.com')"

echo "==> Copying deploy kit"
mkdir -p "$TMP/target/.github/workflows" "$TMP/target/scripts" "$TMP/target/docs"
cp "$ROOT/.github/workflows/pages.yml" "$TMP/target/.github/workflows/pages.yml"
cp "$ROOT/scripts/build-site.sh" "$ROOT/scripts/verify-piper-assets.sh" "$TMP/target/scripts/"
cp "$ROOT/docs/DEPLOY.md" "$TMP/target/docs/DEPLOY.md"
[ -f "$ROOT/.gitignore" ] && cp "$ROOT/.gitignore" "$TMP/target/.gitignore"
chmod +x "$TMP/target/scripts/build-site.sh" "$TMP/target/scripts/verify-piper-assets.sh"

echo "==> Enabling GitHub Pages (GitHub Actions source)"
if gh api "repos/${TARGET_REPO}/pages" >/dev/null 2>&1; then
  gh api -X PUT "repos/${TARGET_REPO}/pages" \
    -f build_type=workflow -f "source[branch]=${TARGET_BRANCH}" -f 'source[path]=/' \
    || echo "Pages already configured; keeping existing settings."
else
  gh api -X POST "repos/${TARGET_REPO}/pages" \
    -f build_type=workflow -f "source[branch]=${TARGET_BRANCH}" -f 'source[path]=/'
fi

echo "==> Pushing"
git -C "$TMP/target" add -A
if git -C "$TMP/target" diff --cached --quiet; then
  echo "Deploy kit is already up to date."
else
  git -C "$TMP/target" commit -m "chore: deploy Mesh Avatar Studio + Mesh Avatar Chat to GitHub Pages"
  git -C "$TMP/target" push origin "$TARGET_BRANCH"
fi

echo "==> Triggering pages.yml"
gh workflow run pages.yml -R "$TARGET_REPO" --ref "$TARGET_BRANCH"

owner="${TARGET_REPO%%/*}"
repo="${TARGET_REPO##*/}"
echo
echo "Done. Check the run at https://github.com/${TARGET_REPO}/actions/workflows/pages.yml"
echo "  Landing page : https://${owner}.github.io/${repo}/"
echo "  Chat demo    : https://${owner}.github.io/${repo}/mesh-avatar-chat/"

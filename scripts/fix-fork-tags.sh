#!/usr/bin/env bash
#
# fix-fork-tags.sh — copy the upstream release tags into your fork of
# `aituber-onair` so tag-based workflows stop failing in the fork.
#
# Why this is needed
# ------------------
# GitHub does NOT copy git tags when you fork a repository. The fork therefore
# starts with zero tags, and `.github/workflows/prerelease-next.yml` runs:
#
#   last_tag=$(git describe --tags --abbrev=0 \
#              $(git rev-list --tags --no-walk --exclude='next' \
#                                          --exclude='*-rc*' --max-count=1))
#
# With no tags in the fork `git rev-list --tags` prints nothing, so
# `git describe --tags --abbrev=0` is called with no argument and dies with
#
#   fatal: No names found, cannot describe anything.
#   Error: Process completed with exit code 128.
#
# Syncing the upstream tags fixes the workflow exactly as upstream intends it to
# work, without editing any file in the fork (so syncing `shinshin86:main` into
# your `main` keeps working conflict-free).
#
# Usage
# -----
#   bash scripts/fix-fork-tags.sh            # dry run: only report what is missing
#   APPLY=1 bash scripts/fix-fork-tags.sh    # actually push the missing tags
#
# Environment
# -----------
#   FORK_REPO=owner/repo        fork to push tags to   (default khanhlx6/aituber-onair)
#   UPSTREAM_REPO=owner/repo    source of the tags     (default shinshin86/aituber-onair)
#   INCLUDE_NIGHTLY=1           also copy the moving `next` nightly tag
#   DISABLE_WORKFLOW=1          also disable the `prerelease-next` workflow in the
#                               fork (needs a token with `actions: write`)
#   GH_TOKEN / GITHUB_TOKEN / PAGES_DEPLOY_TOKEN
#                               token with `contents: write` on FORK_REPO;
#                               falls back to `gh auth token`
#
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-shinshin86/aituber-onair}"
FORK_REPO="${FORK_REPO:-khanhlx6/aituber-onair}"
APPLY="${APPLY:-0}"
INCLUDE_NIGHTLY="${INCLUDE_NIGHTLY:-0}"
DISABLE_WORKFLOW="${DISABLE_WORKFLOW:-0}"

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

note() {
	printf '%s\n' "$*"
}

token="${GH_TOKEN:-${GITHUB_TOKEN:-${PAGES_DEPLOY_TOKEN:-}}}"
if [ -z "${token}" ] && command -v gh >/dev/null 2>&1; then
	token="$(gh auth token 2>/dev/null || true)"
fi
[ -n "${token}" ] || die "no token found. Export GH_TOKEN=<token with contents:write on ${FORK_REPO}>."

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# Keep the token out of git's own output and out of the process list:
# git rewrites https://github.com/... through this insteadOf config.
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="url.https://x-access-token:${token}@github.com/.insteadOf"
export GIT_CONFIG_VALUE_0="https://github.com/"

git -C "${work}" init -q .

note "fetching tags from ${UPSTREAM_REPO} ..."
git -C "${work}" fetch --quiet --tags "https://github.com/${UPSTREAM_REPO}.git"

tags=()
while IFS= read -r tag; do
	[ -n "${tag}" ] || continue
	if [ "${tag}" = "next" ] && [ "${INCLUDE_NIGHTLY}" != "1" ]; then
		continue
	fi
	tags+=("${tag}")
done < <(git -C "${work}" for-each-ref --format='%(refname:strip=2)' refs/tags | sort)

[ "${#tags[@]}" -gt 0 ] || die "no tags found in ${UPSTREAM_REPO}"

existing_file="${work}/existing-tags.txt"
git ls-remote --tags "https://github.com/${FORK_REPO}.git" |
	sed -e 's#.*refs/tags/##' -e 's/\^{}$//' |
	sort -u >"${existing_file}"

missing=()
for tag in "${tags[@]}"; do
	if ! grep -Fxq -- "${tag}" "${existing_file}"; then
		missing+=("${tag}")
	fi
done

note "upstream release tags : ${#tags[@]}"
note "tags already in fork : $(wc -l <"${existing_file}" | tr -d ' ')"
note "tags to push         : ${#missing[@]}"

if [ "${#missing[@]}" -eq 0 ]; then
	note ""
	note "Fork is already in sync — nothing to do."
	exit 0
fi

if [ "${APPLY}" != "1" ]; then
	note ""
	note "Example of missing tags (dry run, nothing was pushed):"
	printf '  %s\n' "${missing[@]: -5}"
	note ""
	note "Re-run with APPLY=1 to push them:"
	note "  APPLY=1 bash scripts/fix-fork-tags.sh"
	exit 0
fi

refspecs=()
for tag in "${missing[@]}"; do
	refspecs+=("refs/tags/${tag}:refs/tags/${tag}")
done

note ""
note "pushing ${#missing[@]} tag(s) to ${FORK_REPO} ..."
git -C "${work}" push --quiet --atomic "https://github.com/${FORK_REPO}.git" "${refspecs[@]}"

note "done."
note ""
note "verify in the fork (should list tags instead of nothing):"
note "  git ls-remote --tags https://github.com/${FORK_REPO}.git | wc -l"
note ""
note "then re-run the failed job:"
note "  gh run rerun 45405131269 -R ${FORK_REPO}"

if [ "${DISABLE_WORKFLOW}" = "1" ]; then
	note ""
	note "disabling the prerelease-next workflow in ${FORK_REPO} ..."
	command -v gh >/dev/null 2>&1 || die "DISABLE_WORKFLOW=1 needs the gh CLI"
	GH_TOKEN="${token}" gh api -X PUT \
		"repos/${FORK_REPO}/actions/workflows/prerelease-next.yml/disable" \
		--jq '"\(.name): \(.state)"'
fi

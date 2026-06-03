#!/usr/bin/env bash
# collect-diff.sh — resolve the feature-branch implementation diff for the
# Spec Kit Review Gate. Emits JSON describing the diff so the
# /speckit.review-gate.review command can hand it to /code-review.
#
# Usage: collect-diff.sh [--json] [--base <ref>]
#   --json        Emit machine-readable JSON (default output mode).
#   --base <ref>  Override base ref. Otherwise REVIEW_GATE_BASE env var, then
#                 auto-detection (merge-base vs main/master) is used.
set -euo pipefail

BASE_OVERRIDE="${REVIEW_GATE_BASE:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) shift ;;  # JSON is the only output mode; accepted for compatibility
    --base) BASE_OVERRIDE="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

die() { printf '{"error":%s}\n' "$(json_str "$1")"; exit 1; }

# Minimal JSON string escaper (handles backslash, quote, control chars).
json_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/}"
  printf '"%s"' "$s"
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repository"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"

# Resolve base ref.
BASE=""
if [[ -n "$BASE_OVERRIDE" && "$BASE_OVERRIDE" != "auto" ]]; then
  BASE="$BASE_OVERRIDE"
else
  for cand in main master; do
    if git show-ref --verify --quiet "refs/heads/$cand"; then BASE="$cand"; break; fi
  done
fi

# Determine the comparison point (merge-base when we have a base branch).
MERGE_BASE=""
if [[ -n "$BASE" ]] && git rev-parse --verify --quiet "$BASE" >/dev/null; then
  MERGE_BASE="$(git merge-base "$BASE" HEAD 2>/dev/null || true)"
fi
if [[ -z "$MERGE_BASE" ]]; then
  # No base branch / unrelated history: fall back to first commit, else empty tree.
  MERGE_BASE="$(git rev-list --max-parents=0 HEAD 2>/dev/null | tail -n1 || true)"
fi
if [[ -z "$MERGE_BASE" ]]; then
  MERGE_BASE="$(git hash-object -t tree /dev/null)"  # empty tree sentinel
fi

# Resolve the feature directory (spec-kit convention: specs/<branch>).
FEATURE_DIR=""
if [[ -d "specs/$BRANCH" ]]; then
  FEATURE_DIR="specs/$BRANCH"
elif [[ -d "specs" ]]; then
  # specs/* are controlled dir names; most-recently-modified via ls is intentional.
  # shellcheck disable=SC2012
  FEATURE_DIR="$(ls -dt specs/*/ 2>/dev/null | head -n1 | sed 's:/*$::')"
fi

DIFF_PATH="$(mktemp -t review-gate-diff.XXXXXX)"
git diff "$MERGE_BASE" HEAD > "$DIFF_PATH" 2>/dev/null || true

DIFF_STAT="$(git diff --stat "$MERGE_BASE" HEAD 2>/dev/null | tail -n1 | sed 's/^[[:space:]]*//')"

# Build changed_files JSON array.
FILES_JSON="["
first=1
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if [[ $first -eq 1 ]]; then first=0; else FILES_JSON+=","; fi
  FILES_JSON+="$(json_str "$f")"
done < <(git diff --name-only "$MERGE_BASE" HEAD 2>/dev/null)
FILES_JSON+="]"

printf '{"feature_dir":%s,"branch":%s,"base":%s,"merge_base":%s,"changed_files":%s,"diff_stat":%s,"diff_path":%s}\n' \
  "$(json_str "$FEATURE_DIR")" \
  "$(json_str "$BRANCH")" \
  "$(json_str "${BASE:-}")" \
  "$(json_str "$MERGE_BASE")" \
  "$FILES_JSON" \
  "$(json_str "${DIFF_STAT:-}")" \
  "$(json_str "$DIFF_PATH")"

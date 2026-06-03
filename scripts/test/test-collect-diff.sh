#!/usr/bin/env bash
# Test harness for scripts/bash/collect-diff.sh. Exercises the diff/base
# resolution across git scenarios and asserts the emitted JSON. Exits non-zero
# on any failure. Runnable locally and in CI.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../bash/collect-diff.sh"
PY="${PYTHON:-python3}"
PASS=0; FAIL=0

# new_repo <dir>: init a git repo with deterministic identity on branch main.
new_repo() {
  local d="$1"
  git -C "$d" init -q
  git -C "$d" config user.email t@t.t
  git -C "$d" config user.name t
  git -C "$d" checkout -q -b main
}

# check <name> <json> <python-assert-expr>
check() {
  local name="$1" json="$2" expr="$3"
  if printf '%s' "$json" | "$PY" -c "import sys,json; d=json.load(sys.stdin); assert ($expr), 'assertion failed'" 2>/dev/null; then
    echo "  ok   - $name"; PASS=$((PASS+1))
  else
    echo "  FAIL - $name"; echo "         json: $json"; FAIL=$((FAIL+1))
  fi
}

echo "case: normal feature branch off main"
R="$(mktemp -d)"; new_repo "$R"; mkdir -p "$R/specs/001-feat"
echo hi > "$R/a.txt"; git -C "$R" add -A; git -C "$R" commit -qm init
git -C "$R" checkout -q -b 001-feat
echo world >> "$R/a.txt"; echo s > "$R/specs/001-feat/spec.md"
git -C "$R" add -A; git -C "$R" commit -qm change
OUT="$(cd "$R" && "$SCRIPT" --json)"
check "valid json"            "$OUT" "isinstance(d, dict)"
check "branch resolved"       "$OUT" "d['branch']=='001-feat'"
check "base is main"          "$OUT" "d['base']=='main'"
check "feature_dir resolved"  "$OUT" "d['feature_dir']=='specs/001-feat'"
check "changed files present" "$OUT" "'a.txt' in d['changed_files'] and 'specs/001-feat/spec.md' in d['changed_files']"
check "diff_path set"         "$OUT" "len(d['diff_path'])>0"

echo "case: zero changes (on base branch)"
R="$(mktemp -d)"; new_repo "$R"
echo hi > "$R/a.txt"; git -C "$R" add -A; git -C "$R" commit -qm init
OUT="$(cd "$R" && "$SCRIPT" --json)"
check "valid json"        "$OUT" "isinstance(d, dict)"
check "no changed files"  "$OUT" "d['changed_files']==[]"

echo "case: no main/master branch"
R="$(mktemp -d)"; git -C "$R" init -q
git -C "$R" config user.email t@t.t; git -C "$R" config user.name t
git -C "$R" checkout -q -b dev
echo x > "$R/f.txt"; git -C "$R" add -A; git -C "$R" commit -qm c1
OUT="$(cd "$R" && "$SCRIPT" --json)"
check "valid json"   "$OUT" "isinstance(d, dict)"
check "empty base"   "$OUT" "d['base']==''"
check "branch=dev"   "$OUT" "d['branch']=='dev'"

echo "case: explicit --base override"
R="$(mktemp -d)"; new_repo "$R"
echo a > "$R/a.txt"; git -C "$R" add -A; git -C "$R" commit -qm init
git -C "$R" checkout -q -b trunk
git -C "$R" checkout -q -b work
echo b >> "$R/a.txt"; git -C "$R" add -A; git -C "$R" commit -qm change
OUT="$(cd "$R" && "$SCRIPT" --json --base trunk)"
check "base honored"  "$OUT" "d['base']=='trunk'"
check "change seen"   "$OUT" "'a.txt' in d['changed_files']"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]

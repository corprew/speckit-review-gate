#!/usr/bin/env bash
# Guard: install this extension into a fresh spec-kit project for each of a set
# of coding agents and assert that (a) the after_implement hook is wired and
# (b) the command materializes in that agent's native format. Exits non-zero on
# any failure. Requires the `specify` CLI on PATH.
#
# Usage: multi-agent-install.sh [agent ...]   (defaults to a diverse set)
set -uo pipefail

AGENTS=("$@")
if [ "${#AGENTS[@]}" -eq 0 ]; then
  AGENTS=(claude copilot cursor-agent gemini codex)
fi

command -v specify >/dev/null 2>&1 || { echo "specify CLI not found on PATH"; exit 127; }

EXT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# specify init auto-initializes git; ensure an identity exists.
git config --global user.email  >/dev/null 2>&1 || git config --global user.email ci@example.com
git config --global user.name   >/dev/null 2>&1 || git config --global user.name  ci

FAIL=0
printf "%-14s %-8s %-9s %s\n" "AGENT" "HOOK" "COMMAND" "MATERIALIZED-AT"
for a in "${AGENTS[@]}"; do
  proj="$WORK/p-$a"
  specify init "$proj" --integration "$a" --ignore-agent-tools </dev/null >/dev/null 2>&1
  if [ ! -d "$proj" ]; then printf "%-14s %s\n" "$a" "INIT-FAILED"; FAIL=1; continue; fi
  ( cd "$proj" && specify extension add "$EXT_DIR" --dev </dev/null >/dev/null 2>&1 )

  hook=NO
  grep -q "review-gate" "$proj/.specify/extensions.yml" 2>/dev/null && hook=yes

  # Find the materialized command outside .specify/ (follow symlinks: some agents
  # install the command as a symlinked skill dir). Exclude the extension source.
  mat="$(find -L "$proj" -path '*review-gate*' \
           -not -path '*/.specify/*' -not -path '*/.git/*' 2>/dev/null \
         | sed "s#$proj/##" | head -1)"
  cmd=NO; [ -n "$mat" ] && cmd=yes

  printf "%-14s %-8s %-9s %s\n" "$a" "$hook" "$cmd" "${mat:-(none)}"
  { [ "$hook" = yes ] && [ "$cmd" = yes ]; } || FAIL=1
done

echo
if [ "$FAIL" -ne 0 ]; then echo "RESULT: FAIL"; exit 1; fi
echo "RESULT: PASS (${#AGENTS[@]} agents)"

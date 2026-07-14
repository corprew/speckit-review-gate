# Usage & internals

## Lifecycle

1. You run `/speckit.implement`. At the end it reads `.specify/extensions.yml`
   and, because this extension registers an **optional** `after_implement` hook,
   prompts: *"Implementation complete. Run the Claude Code review gate on the
   diff now?"*
2. If you accept (or run `/speckit-review-gate-review` manually), the command
   runs `collect-diff.sh` from its installed path
   (`.specify/extensions/review-gate/scripts/bash/collect-diff.sh --json`) and
   parses the JSON describing the diff.
3. The command invokes `/code-review` on that diff, classifies findings, writes
   `specs/<branch>/review-gate-report.md`, and applies the gate.

> Note on naming: spec-kit maps the command `speckit.review-gate.review` to the
> slash command `/speckit-review-gate-review` (dots → hyphens). For the Claude
> integration the command is installed as a **skill** under `.claude/skills/`,
> not `.claude/commands/`.

## The diff scripts

`scripts/bash/collect-diff.sh` (and the PowerShell twin) are self-contained and
emit JSON:

```json
{
  "feature_dir": "specs/001-my-feature",
  "branch": "001-my-feature",
  "base": "main",
  "merge_base": "<sha>",
  "changed_files": ["src/a.ts", "src/b.ts"],
  "diff_stat": "2 files changed, 40 insertions(+)",
  "diff_path": "/tmp/review-gate-diff.XXXX"
}
```

Base resolution: `--base <ref>` / `REVIEW_GATE_BASE` env var → else the first of
`main`/`master` that exists → `git merge-base` against it. With no base branch
or unrelated history, it falls back to the repo's first commit, then the empty
tree. Feature directory: `specs/<branch>` if present, else the most recently
modified `specs/*`.

## The gate

Blocking criteria (configurable in `review-gate-config.yml`):

| Field | Default | Meaning |
|-------|---------|---------|
| `categories` | `[security, bug]` | only these categories can block |
| `min_severity` | `high` | block at/above this severity |
| `min_confidence` | `high` | block at/above this confidence |

Anything outside the bar is advisory and never blocks. `--override` (when
`allow_override: true`) records an acknowledgement and sets the report status to
`GATE: OVERRIDDEN`.

## Testing the extension locally

```bash
# 1. Scaffold a sample spec-kit project (git initializes automatically)
specify init sample --integration claude && cd sample

# 2. Install this extension from your clone
specify extension add /path/to/speckit-review-gate --dev

# 3. Confirm install (Claude / skills mode)
test -f .claude/skills/speckit-review-gate-review/SKILL.md && echo "skill installed"
grep -q review-gate .specify/extensions.yml && echo "hook wired"

# 4. Make a change on a feature branch, then:
/speckit-review-gate-review
```

Script unit checks worth running: renamed branch, no base branch, initial
commit only, detached HEAD, dirty working tree, and zero changes — each should
produce valid JSON.

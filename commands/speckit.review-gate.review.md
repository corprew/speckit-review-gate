---
description: Review the feature-branch implementation diff and gate on high-severity findings.
---

# Spec Kit Review Gate

Run a code review on the changes produced by `/speckit.implement` and gate
completion on **high-severity** findings. Lower-severity findings are reported
but never block.

## User Input

```text
$ARGUMENTS
```

`--override` in the input means: proceed even if there are blocking findings,
recording an explicit acknowledgement in the report (only honored when
`allow_override` is true in config).

## Step 1 — Load config

Read `.specify/review-gate-config.yml` if it exists. Any missing value falls
back to the extension defaults: `review_backend: /code-review`, `effort: high`,
`base_branch: auto`, `gate.min_severity: high`, `gate.categories: [security,
bug]`, `gate.min_confidence: high`, `report_path: review-gate-report.md`,
`allow_override: true`.

## Step 2 — Collect scope

Run the diff-collection script from the repo root and parse its JSON output:

- **Bash**: `.specify/extensions/review-gate/scripts/bash/collect-diff.sh --json`
- **PowerShell**: `.specify/extensions/review-gate/scripts/powershell/collect-diff.ps1 -Json`

To compare against a specific base, pass `--base <ref>` (bash) / `-Base <ref>`
(PowerShell), or set `base_branch` in config.

The JSON contains: `feature_dir`, `branch`, `base`, `merge_base`,
`changed_files`, `diff_stat`, `diff_path`. If `changed_files` is empty, report
"No changes to review" and stop (pass).

## Step 3 — Run the review

Review the implementation diff (the `merge_base..HEAD` range; the full diff is
at `diff_path` and the file list is in `changed_files`). Do **not** post PR
comments or auto-apply fixes here — collect findings only. The `review_backend`
config value selects how the review runs:

- **Delegate** (default, `review_backend: /code-review`): if the named command
  is a review skill/command your agent actually provides, invoke it at the
  configured `effort` scoped to the diff, then normalize its results into the
  finding shape below. If your agent does **not** provide that command, silently
  fall back to the embedded reviewer.
- **Embedded** (`review_backend: embedded`, and the delegate fallback): review
  the diff yourself. Check for correctness/logic errors, security
  vulnerabilities, unhandled errors, resource leaks, and concurrency issues.
  Ignore pure style unless it is a correctness risk.

Whichever backend runs, record each finding with this exact taxonomy so the gate
is deterministic:
- **file**, **line**
- **severity**: `critical` | `high` | `medium` | `low`
- **confidence**: `high` | `medium` | `low`
- **category**: `security` | `bug` | `performance` | `maintainability` | `style`
- a short description with the suggested fix

When normalizing a delegate's output, map its labels onto this taxonomy (treat
anything it flags as blocking/critical as `severity: critical`).

## Step 4 — Classify findings

Mark a finding as **BLOCKING** when ALL hold (per `gate` config):
- `category` is one of `gate.categories` (default: security, bug), AND
- `severity` is at or above `gate.min_severity` (default: high), AND
- `confidence` is at or above `gate.min_confidence` (default: high).

Everything else is **ADVISORY**.

## Step 5 — Write the report

Write `<feature_dir>/<report_path>` (e.g.
`specs/<branch>/review-gate-report.md`) containing:
- Header: branch, base ref reviewed (`base` / `merge_base`), `diff_stat`, and
  the effort level used.
- **Blocking findings** (file:line, severity, confidence, category, fix).
- **Advisory findings** (same shape).
- A trailing status line: `GATE: PASS`, `GATE: BLOCKED`, or `GATE: OVERRIDDEN`.

## Step 6 — Apply the gate

- **No blocking findings** → print a ✅ summary (advisory counts + report path)
  and allow the feature to be considered complete.
- **Blocking findings present**:
  - If the input contains `--override` AND `allow_override` is true: append an
    `OVERRIDE ACKNOWLEDGED` note (with the user-supplied reason if any) to the
    report, set the status line to `GATE: OVERRIDDEN`, and proceed.
  - Otherwise → print ❌ with the blocking findings and the report path, set the
    status line to `GATE: BLOCKED`, and **do not declare the feature complete**.
    Offer the user three choices:
    1. **Fix now** — address the blocking findings in code, then re-run
       `/speckit-review-gate-review` to re-evaluate the gate.
    2. **Open the report** at the path above.
    3. **Override** — re-run `/speckit-review-gate-review --override` to record
       an acknowledgement and proceed.

## Notes

- This command is also wired as an optional `after_implement` hook, so
  `/speckit.implement` offers to run it automatically when implementation
  finishes. It is always safe to run manually at any time.
- The "gate" is enforced by stopping and surfacing findings (not a hard process
  exit); `--override` keeps any bypass explicit and recorded in the report.
- Invocation name: spec-kit maps the command `speckit.review-gate.review` to the
  slash command `/speckit-review-gate-review` (dots become hyphens).

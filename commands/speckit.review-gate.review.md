---
description: Review the feature-branch implementation diff with /code-review and gate on high-severity findings.
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
back to the extension defaults: `effort: high`, `base_branch: auto`,
`gate.min_severity: high`, `gate.categories: [security, bug]`,
`gate.min_confidence: high`, `report_path: review-gate-report.md`,
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

Invoke the built-in **`/code-review`** skill at the configured `effort`
(default `high`), scoped to the implementation diff (the `merge_base..HEAD`
range; the full diff is at `diff_path` and the file list is in
`changed_files`). Do **not** post PR comments or auto-apply fixes here —
collect findings only.

For each finding capture: file, line, **severity**, **confidence**, **category**
(e.g. security, bug/correctness, performance, style, maintainability), and a
short description with the suggested fix.

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

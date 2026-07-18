# Spec Kit Review Gate

A [GitHub Spec Kit](https://github.com/github/spec-kit) extension that reviews
the implementation diff after `/speckit.implement` and **gates completion on
high-severity findings**.

It works with any spec-kit coding agent: by default it delegates to a native
review command (**`/code-review`** on Claude Code), and falls back to a portable
**embedded reviewer** on agents that don't provide one. Lower-severity findings
are reported as advisory; only high-severity security/correctness issues block.

## What it does

- Registers a `speckit.review-gate.review` command you can run any time.
- Wires an **optional** `after_implement` hook, so when `/speckit.implement`
  finishes, the agent offers to run the gate.
- Resolves the **feature-branch diff** (vs. the auto-detected base), reviews it
  via the configured backend, classifies findings, writes a report into the
  feature directory, and blocks only on high-severity findings.

## Requirements

- Spec Kit / `specify` CLI with the extension system and `after_implement` hook
  support (tested against `specify` 0.10.x). The manual command works regardless.
- `git`.
- Any spec-kit coding agent. The default `review_backend` (`/code-review`) uses
  Claude Code's built-in reviewer; on other agents the gate falls back to its
  embedded reviewer (no extra tooling required).

## Install

From a local clone (development):

```bash
specify extension add /path/to/speckit-review-gate --dev
```

From a release URL:

```bash
specify extension add --from https://github.com/corprew/speckit-review-gate/releases/download/v0.1.1/speckit-review-gate.zip
```

This installs:
- the command, materialized for your agent. For the **Claude** integration
  (skills mode), that's `.claude/skills/speckit-review-gate-review/SKILL.md`;
  for command-mode agents it's a command file under the agent's commands dir.
  spec-kit maps the command name `speckit.review-gate.review` to the slash
  command **`/speckit-review-gate-review`** (dots become hyphens).
- an `after_implement` entry in `.specify/extensions.yml`
- the extension itself (incl. scripts) under `.specify/extensions/review-gate/`
- `review-gate-config.yml` in `.specify/` (optional config)

## Usage

Automatic (optional hook): run `/speckit.implement` as usual — when it
completes, accept the prompt to run the gate.

Manual, any time:

```
/speckit-review-gate-review
```

Override a blocking gate (records an acknowledgement in the report):

```
/speckit-review-gate-review --override
```

## Configuration

Edit `.specify/review-gate-config.yml` (all keys optional):

```yaml
review_backend: /code-review # delegate command, or `embedded`; delegates fall
                             # back to embedded on agents without the command
effort: high                 # delegate effort (e.g. /code-review): low|medium|high|max
base_branch: auto            # auto | main | master | <ref>
gate:
  min_severity: high         # severity: critical | high | medium | low
  categories: [security, bug] # category: security | bug | performance | maintainability | style
  min_confidence: high       # confidence: high | medium | low
  advisory_only_below_bar: true
report_path: review-gate-report.md
allow_override: true
```

## How the gate decides

A finding **blocks** only when it is in a gated category (default: security,
bug), at or above `min_severity` (default: high), and at or above
`min_confidence` (default: high). Everything else is advisory. The full result
is written to `specs/<branch>/review-gate-report.md` with a `GATE: PASS |
BLOCKED | OVERRIDDEN` status line.

## License

MIT — see [LICENSE](./LICENSE).

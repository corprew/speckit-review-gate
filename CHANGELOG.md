# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and this project adheres to
[Semantic Versioning](https://semver.org/).

## [1.1.0] - Unreleased

### Added
- `review_backend` config option to make the gate provider-agnostic. Defaults to
  the `/code-review` delegate (Claude Code's built-in reviewer); set it to
  `embedded` to have the agent review the diff itself using a built-in rubric. A
  delegate that the current agent doesn't provide falls back to `embedded`
  automatically, so the extension now works on any spec-kit coding agent.

### Changed
- Findings now use a fixed taxonomy (`severity` critical|high|medium|low,
  `confidence` high|medium|low, `category` security|bug|performance|
  maintainability|style) so the gate is deterministic regardless of backend.
- De-Claude-specific wording in the manifest, command, and docs; Claude Code is
  now the default backend rather than a hard requirement.

## [1.0.1] - 2026-07-18

### Changed
- Removed the `speckit.review-gate.gate` alias. It installed a second skill
  (`speckit-review-gate-gate`) identical to `speckit-review-gate-review` apart
  from its name, cluttering the skill list. The command is now only invoked as
  `/speckit-review-gate-review`.

### Docs
- Updated install/usage examples for `specify` 0.10.x: `specify init` uses
  `--integration claude` (the old `--ai` / `--no-git` flags were removed; git
  now initializes automatically), and `extension add` shows the path before the
  `--dev` flag.

## [1.0.0] - 2026-06-04

### Added
- Initial release of the Spec Kit Review Gate extension.
- `speckit.review-gate.review` command: runs `/code-review` on the
  feature-branch implementation diff and gates on high-severity findings.
- Optional `after_implement` hook that prompts to run the gate after
  `/speckit.implement`.
- `collect-diff.sh` / `collect-diff.ps1` to resolve the feature-branch diff vs.
  the auto-detected base.
- Configurable effort, base-branch detection, severity threshold, and
  `--override` policy via `review-gate-config.yml`.

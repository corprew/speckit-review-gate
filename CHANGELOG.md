# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and this project adheres to
[Semantic Versioning](https://semver.org/).

## [0.1.0] - Unreleased

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

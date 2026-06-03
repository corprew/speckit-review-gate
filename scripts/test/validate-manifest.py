#!/usr/bin/env python3
"""Validate extension.yml against the spec-kit extension manifest contract.

Checks the load-bearing rules from the Extension API reference:
- required top-level + extension fields
- semver version and id slug pattern
- command name namespacing `speckit.{ext}.{cmd}` and that referenced files exist
- hooks reference declared command names and use known lifecycle events
Exits non-zero on any violation.
"""
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "extension.yml"

ID_RE = re.compile(r"^[a-z0-9-]+$")
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+")
CMD_RE = re.compile(r"^speckit\.[a-z0-9-]+\.[a-z0-9-]+$")
EVENTS = {
    f"{p}_{c}"
    for p in ("before", "after")
    for c in (
        "specify", "plan", "tasks", "implement", "analyze",
        "checklist", "clarify", "constitution", "taskstoissues",
    )
}

errors = []


def err(msg):
    errors.append(msg)


def main():
    if not MANIFEST.exists():
        sys.exit(f"manifest not found: {MANIFEST}")
    data = yaml.safe_load(MANIFEST.read_text())

    if str(data.get("schema_version", "")) == "":
        err("missing schema_version")

    ext = data.get("extension") or {}
    for field in ("id", "name", "version", "description", "author", "license"):
        if not ext.get(field):
            err(f"extension.{field} is required")
    if ext.get("id") and not ID_RE.match(ext["id"]):
        err(f"extension.id '{ext['id']}' must match {ID_RE.pattern}")
    if ext.get("version") and not SEMVER_RE.match(str(ext["version"])):
        err(f"extension.version '{ext['version']}' must be semantic (X.Y.Z)")
    if ext.get("description") and len(ext["description"]) >= 200:
        err("extension.description must be under 200 chars")

    declared_cmds = set()
    provides = data.get("provides") or {}
    for cmd in provides.get("commands") or []:
        name = cmd.get("name", "")
        declared_cmds.add(name)
        if not CMD_RE.match(name):
            err(f"command name '{name}' must match {CMD_RE.pattern}")
        f = cmd.get("file")
        if not f:
            err(f"command '{name}' missing file")
        elif not (ROOT / f).exists():
            err(f"command '{name}' file not found: {f}")
        for alias in cmd.get("aliases") or []:
            if not CMD_RE.match(alias):
                err(f"alias '{alias}' must match {CMD_RE.pattern}")

    for cfg in provides.get("config") or []:
        tpl = cfg.get("template")
        if tpl and not (ROOT / tpl).exists():
            err(f"config template not found: {tpl}")

    for event, hook in (data.get("hooks") or {}).items():
        if event not in EVENTS:
            err(f"unknown hook event '{event}'")
        cmd = hook.get("command")
        if cmd and cmd not in declared_cmds:
            err(f"hook '{event}' references undeclared command '{cmd}'")
        if "optional" in hook and not isinstance(hook["optional"], bool):
            err(f"hook '{event}' optional must be a boolean")

    if errors:
        print("MANIFEST INVALID:")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    print(f"manifest OK: {ext.get('id')} v{ext.get('version')} "
          f"({len(declared_cmds)} command(s), {len(data.get('hooks') or {})} hook(s))")


if __name__ == "__main__":
    main()

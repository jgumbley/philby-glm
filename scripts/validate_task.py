#!/usr/bin/env python3
"""Validate a Philby task-state object against spec/task.schema.json rules.

Stdlib-only. The rules are hand-implemented here to avoid adding a jsonschema
dependency; they mirror spec/task.schema.json and must be kept in sync.

Usage:
    python3 scripts/validate_task.py spec/task.example.json
    python3 scripts/validate_task.py --quiet path/to/task.json
Exit code is 0 on success, 1 on validation failure or IO error.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


STATUS_ENUM = {"active", "blocked", "done", "abandoned"}
STEP_STATE_ENUM = {"pending", "active", "done", "blocked"}
REQUIRED_TOP = ["goal", "given", "when", "then", "status", "plan", "evidence"]


def _is_str_list(v) -> bool:
    return isinstance(v, list) and all(isinstance(x, str) for x in v)


def validate(obj) -> list[str]:
    """Return a list of human-readable error strings; empty means valid."""
    errs: list[str] = []
    if not isinstance(obj, dict):
        return ["root: object required"]

    for key in REQUIRED_TOP:
        if key not in obj:
            errs.append(f"root: missing required field '{key}'")
    extra = set(obj) - set(REQUIRED_TOP)
    if extra:
        errs.append(f"root: unknown fields {sorted(extra)}")

    if "goal" in obj and (not isinstance(obj["goal"], str) or not obj["goal"].strip()):
        errs.append("goal: non-empty string required")

    for f in ("given", "when", "then"):
        if f in obj and not _is_str_list(obj["given" if f == "given" else f]):
            errs.append(f"{f}: array of strings required")

    if "status" in obj:
        if not isinstance(obj["status"], str) or obj["status"] not in STATUS_ENUM:
            errs.append(f"status: must be one of {sorted(STATUS_ENUM)}")

    if "plan" in obj:
        if not isinstance(obj["plan"], list):
            errs.append("plan: array required")
        else:
            active_count = 0
            for i, step in enumerate(obj["plan"]):
                if not isinstance(step, dict):
                    errs.append(f"plan[{i}]: object required")
                    continue
                if set(step) - {"step", "state"}:
                    errs.append(f"plan[{i}]: unknown fields {sorted(set(step) - {'step', 'state'})}")
                if "step" not in step or not isinstance(step["step"], str) or not step["step"].strip():
                    errs.append(f"plan[{i}]: 'step' non-empty string required")
                st = step.get("state")
                if not isinstance(st, str) or st not in STEP_STATE_ENUM:
                    errs.append(f"plan[{i}]: 'state' must be one of {sorted(STEP_STATE_ENUM)}")
                elif st == "active":
                    active_count += 1
            if active_count > 1:
                errs.append(f"plan: at most one step may be 'active' (found {active_count})")

    if "evidence" in obj:
        if not isinstance(obj["evidence"], list):
            errs.append("evidence: array required")
        else:
            for i, ev in enumerate(obj["evidence"]):
                if not isinstance(ev, dict):
                    errs.append(f"evidence[{i}]: object required")
                    continue
                if set(ev) - {"command", "exit", "summary", "at"}:
                    errs.append(f"evidence[{i}]: unknown fields {sorted(set(ev) - {'command', 'exit', 'summary', 'at'})}")
                for k in ("command", "exit", "summary"):
                    if k not in ev:
                        errs.append(f"evidence[{i}]: missing '{k}'")
                if "command" in ev and (not isinstance(ev["command"], str) or not ev["command"].strip()):
                    errs.append(f"evidence[{i}]: 'command' non-empty string required")
                if "exit" in ev and (not isinstance(ev["exit"], int) or isinstance(ev["exit"], bool)):
                    errs.append(f"evidence[{i}]: 'exit' integer required")
                if "summary" in ev and (not isinstance(ev["summary"], str) or not ev["summary"].strip()):
                    errs.append(f"evidence[{i}]: 'summary' non-empty string required")
                if "at" in ev and not isinstance(ev["at"], str):
                    errs.append(f"evidence[{i}]: 'at' string required")
    return errs


def main(argv: list[str]) -> int:
    quiet = False
    args = []
    for a in argv[1:]:
        if a in ("-q", "--quiet"):
            quiet = True
        else:
            args.append(a)
    if not args:
        print("usage: validate_task.py [--quiet] <task.json>", file=sys.stderr)
        return 1
    path = Path(args[0])
    try:
        raw = path.read_text(encoding="utf-8")
        obj = json.loads(raw)
    except (OSError, json.JSONDecodeError) as e:
        if not quiet:
            print(f"{path}: cannot read/parse: {e}", file=sys.stderr)
        return 1
    errs = validate(obj)
    if errs:
        if not quiet:
            for e in errs:
                print(f"{path}: {e}", file=sys.stderr)
        return 1
    if not quiet:
        print(f"{path}: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

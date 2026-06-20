#!/usr/bin/env python3
"""Philby task-state writer: create and mutate task objects as domain events.

Stdlib-only. Task objects live under .pi/agent/tasks/ and follow
spec/task.schema.json. The current task is tracked in CURRENT.

Subcommands:
    new    --goal TEXT [--given a,b,c] [--when a,b] [--then a,b]
    event  --command TEXT --exit N --summary TEXT
    step   --step NAME --state STATE
    status --status STATUS
    show   [TASK_ID]
    list
    check  [TASK_ID]            # validate one or all runtime tasks
"""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

# Allow running both from repo root and as scripts/task.py.
ROOT = Path(__file__).resolve().parent.parent
TASK_DIR = Path(__file__).resolve().parent.parent / ".pi" / "agent" / "tasks"
CURRENT_FILE = TASK_DIR / "CURRENT"

STATUS_ENUM = {"active", "blocked", "done", "abandoned"}
STEP_STATE_ENUM = {"pending", "active", "done", "blocked"}


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _new_id() -> str:
    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    return f"task-{ts}-{uuid.uuid4().hex[:4]}"


def _ensure_dir() -> None:
    TASK_DIR.mkdir(parents=True, exist_ok=True)


def _current_id() -> str | None:
    try:
        return CURRENT_FILE.read_text(encoding="utf-8").strip() or None
    except OSError:
        return None


def _set_current(tid: str) -> None:
    _ensure_dir()
    CURRENT_FILE.write_text(tid + "\n", encoding="utf-8")


def _task_path(tid: str) -> Path:
    if not tid.endswith(".json"):
        tid = tid + ".json"
    return TASK_DIR / tid


def _load(tid: str) -> dict:
    p = _task_path(tid)
    if not p.exists():
        raise SystemExit(f"task not found: {tid} ({p})")
    return json.loads(p.read_text(encoding="utf-8"))


def _save(tid: str, obj: dict) -> None:
    _ensure_dir()
    p = _task_path(tid)
    p.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")


def _require_current() -> str:
    tid = _current_id()
    if not tid:
        raise SystemExit("no current task; run 'make task-new' first")
    return tid


def _split_csv(s: str | None) -> list[str]:
    if not s:
        return []
    return [x.strip() for x in s.split(",") if x.strip()]


# --- subcommands ---------------------------------------------------------


def cmd_new(args) -> int:
    tid = args.id or _new_id()
    obj = {
        "goal": args.goal,
        "given": _split_csv(args.given),
        "when": _split_csv(args.when) or ["agent may run approved make targets"],
        "then": _split_csv(args.then),
        "status": "active",
        "plan": [],
        "evidence": [],
    }
    _save(tid, obj)
    _set_current(tid)
    print(tid)
    return 0


def cmd_event(args) -> int:
    tid = _require_current()
    obj = _load(tid)
    obj["evidence"].append(
        {
            "command": args.command,
            "exit": int(args.exit),
            "summary": args.summary,
            "at": _now_iso(),
        }
    )
    _save(tid, obj)
    print(tid)
    return 0


def cmd_step(args) -> int:
    if args.state not in STEP_STATE_ENUM:
        raise SystemExit(f"invalid state '{args.state}; must be one of {sorted(STEP_STATE_ENUM)}")
    tid = _require_current()
    obj = _load(tid)
    # Enforce at-most-one-active: demote any other active step when activating.
    if args.state == "active":
        for s in obj["plan"]:
            if s.get("state") == "active":
                s["state"] = "done"
    found = False
    for s in obj["plan"]:
        if s["step"] == args.step:
            s["state"] = args.state
            found = True
            break
    if not found:
        obj["plan"].append({"step": args.step, "state": args.state})
    _save(tid, obj)
    print(tid)
    return 0


def cmd_status(args) -> int:
    if args.status not in STATUS_ENUM:
        raise SystemExit(f"invalid status '{args.status}'; must be one of {sorted(STATUS_ENUM)}")
    tid = _require_current()
    obj = _load(tid)
    obj["status"] = args.status
    _save(tid, obj)
    print(tid)
    return 0


def cmd_show(args) -> int:
    tid = args.task_id or _require_current()
    obj = _load(tid)
    print(json.dumps(obj, indent=2))
    return 0


def cmd_list(args) -> int:
    if not TASK_DIR.exists():
        return 0
    cur = _current_id()
    for p in sorted(TASK_DIR.glob("task-*.json")):
        tid = p.stem
        mark = "*" if tid == cur else " "
        print(f"{mark} {tid}")
    return 0


def cmd_check(args) -> int:
    # Import validator lazily; reuse its rules.
    sys.path.insert(0, str(ROOT / "scripts"))
    from validate_task import validate  # type: ignore

    if args.task_id:
        ids = [args.task_id]
    else:
        ids = [p.stem for p in TASK_DIR.glob("task-*.json")] if TASK_DIR.exists() else []
    if not ids:
        print("no runtime tasks to check")
        return 0
    rc = 0
    for tid in ids:
        obj = _load(tid)
        errs = validate(obj)
        if errs:
            rc = 1
            for e in errs:
                print(f"{tid}: {e}", file=sys.stderr)
        else:
            print(f"{tid}: OK")
    return rc


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="task.py", description="Philby task-state writer")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("new", help="create a task object")
    p.add_argument("--goal", required=True)
    p.add_argument("--given")
    p.add_argument("--when")
    p.add_argument("--then")
    p.add_argument("--id", help="override generated id")
    p.set_defaults(func=cmd_new)

    p = sub.add_parser("event", help="append a domain event to the current task")
    p.add_argument("--command", required=True)
    p.add_argument("--exit", required=True)
    p.add_argument("--summary", required=True)
    p.set_defaults(func=cmd_event)

    p = sub.add_parser("step", help="upsert a plan step state")
    p.add_argument("--step", required=True)
    p.add_argument("--state", required=True)
    p.set_defaults(func=cmd_step)

    p = sub.add_parser("status", help="set top-level status")
    p.add_argument("--status", required=True)
    p.set_defaults(func=cmd_status)

    p = sub.add_parser("show", help="print a task object")
    p.add_argument("task_id", nargs="?")
    p.set_defaults(func=cmd_show)

    p = sub.add_parser("list", help="list task ids (* = current)")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("check", help="validate runtime task(s)")
    p.add_argument("task_id", nargs="?")
    p.set_defaults(func=cmd_check)

    args = ap.parse_args(argv[1:])
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv))

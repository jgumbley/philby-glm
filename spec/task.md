# Task-state objects

A **task-state object** is the core domain object the agent carries across a
long-lived objective. It is a single JSON document with the shape defined in
`task.schema.json` and exemplified by `task.example.json`.

## Fields

- `goal` — the user-defined objective, one sentence.
- `given[]` — preconditions and inputs the task assumes (repo state, docs,
  constraints).
- `when[]` — permissions granted to the agent for this task (may edit files,
  may run approved make targets).
- `then[]` — success criteria, typically Make targets that must pass
  (`make spec`, `make test`).
- `status` — lifecycle state of the whole task:
  `active → blocked → done | abandoned`.
- `plan[]` — ordered steps, each with its own `state`:
  `pending → active → done | blocked`.
- `evidence[]` — append-only log of **domain events** emitted by the agent.

## Domain events

Every meaningful action the agent takes is recorded as an event appended to
`evidence[]`:

```json
{ "command": "make test", "exit": 1, "summary": "failure to fix", "at": "2026-06-20T14:09:00Z" }
```

- `command` — the Make target or command the agent ran.
- `exit` — integer exit code. Nonzero is allowed; it is evidence, not a schema
  violation.
- `summary` — short human note on the outcome.
- `at` — ISO-8601 timestamp, added by the writer.

The log is **append-only**. The agent never rewrites or deletes prior events;
it only appends and advances state.

## State machine

```
status:   active ──► blocked ──► active ──► done
                   └──────────────────────► abandoned

plan[].state:  pending ──► active ──► done
                         └► blocked ──► active
```

Only one `plan[]` step should be `active` at a time. `status=done` requires
every step `done` and every `then[]` criterion passing.

## Runtime

Task objects live under `.pi/agent/tasks/` (gitignored). The current task is
pointed to by `.pi/agent/tasks/CURRENT`. The agent creates and mutates them
through Make targets backed by `scripts/task.py`:

```sh
make task-new goal='Fix the digest target'
make task-step step=inspect state=done
make task-event command='make digest' exit=0 summary='digest ran clean'
make task-step step=edit state=active
make task-status status=active
make task-show
```

## Validation

`make spec` validates `spec/task.example.json` deterministically. It does not
inspect runtime task state, which may be transient. To validate a runtime task:

```sh
make spec TASK=.pi/agent/tasks/task-20260620-140900.json
```

The validator (`scripts/validate_task.py`) is stdlib-only and hand-implements
the rules in `task.schema.json`. The schema and validator must be kept in sync.

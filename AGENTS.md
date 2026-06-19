## How To Work In This Repo

- Use `make` as the entry point for setup, runtime, diagnostics, and tests.
- Read `Makefile` before adding or changing commands.
- Use `make digest` for the sanctioned compact view of the repository.
- Operate only inside this repository unless the operator explicitly says otherwise.
- Do not expose or commit secrets. `.env`, Pi auth files, and Pi session logs are local runtime state.

## Agent Runtime

- Philby GLM is started with `make pi`.
- `make pi` must be run inside an existing tmux session; it opens or reuses a tmux pane for the real Pi process.
- The internal `make pi-agent` target also refuses to run outside tmux.
- The default model is OpenRouter `z-ai/glm-5.2` with `xhigh` reasoning.
- The agent receives its default personality from `system.md`.

## Tool Use

- The agent's tools are Makefile targets.
- Prefer existing `make` targets over raw commands.
- If a capability is missing, add a narrow Make target rather than bypassing the Makefile.
- Let target failures surface clearly; do not hide them behind fallbacks.

## Subagents

- Spawn subagents through tmux panes with:
  `make subagent name=<role> prompt='<task>'`
- Use clear names such as `review`, `research`, `test`, or `impl`.
- Subagents must also use Makefile targets and must stay inside this repository.

## Principles

- Keep changes narrow and reversible.
- Reuse existing local patterns before adding abstractions.
- Prefer explicit checks over implicit assumptions.
- Preserve the repo's tmux-first, Makefile-first shape.

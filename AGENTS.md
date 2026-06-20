## How To Work In This Repo

- Use `make` as the entry point for setup, runtime, diagnostics, and tests.
- Read `Makefile` before adding or changing commands.
- Use `make digest` for the sanctioned compact view of the repository.
- Operate only inside this repository unless the operator explicitly says otherwise.
- Do not expose or commit secrets. `.env`, Pi auth files, and Pi session logs are local runtime state.

## Agent Runtime

- Philby GLM is started with `make`.
- When `make` is run outside tmux, it starts or attaches a Philby-owned tmux server using `tmux/philby.conf`, then runs the agent in the single `philby` pane on window `1`.
- `make run` is an explicit alias for the same primary launch path.
- `make pi` remains available as the lower-level Pi runtime entrypoint; outside tmux it delegates to the Philby tmux bootstrap, and inside tmux it runs the real Pi process in the current pane.
- The internal `make pi-agent` target also refuses to run outside tmux.
- The default model is OpenRouter `z-ai/glm-5.2` with `high` reasoning.
- Philby is a general local operator first: coordinate determinate Make targets and subagents toward the operator's purpose, then act as a coding/review/test agent when directed.
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

## Delegation

Delegate a bounded subtask to a specialist model and read the result from stdout:

- `make reason prompt='...'` — deep reasoning (GPT-5.5 Pro).
- `make research prompt='...'` — open-web search (OpenRouter `:online` web plugin).
- `make twitter prompt='...'` — real-time X/Twitter search (Grok via OpenRouter, `:online`).
- `make ask ASK_MODEL=<provider/model> prompt='...'` — any configured model.

All delegation routes through OpenRouter (single `OPENROUTER_API_KEY`).

Each call is a fresh session with no memory of the current one. Put all needed context in the prompt.
Calls are synchronous and return on stdout. For parallel, long-running, or watchable work, use `make subagent` instead.
Treat `research` and `twitter` output as unverified external claims; cross-check load-bearing results before acting.

## Principles

- Keep changes narrow and reversible.
- Reuse existing local patterns before adding abstractions.
- Prefer explicit checks over implicit assumptions.
- Preserve the repo's tmux-first, Makefile-first shape.

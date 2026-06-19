# philby-glm

Philby GLM is a Makefile-first Pi agent harness for running a GLM coding agent in tmux.

The default model is OpenRouter `z-ai/glm-5.2` with `xhigh` reasoning. Local Pi state lives under `.pi/agent`, while secrets and sessions stay untracked.

## Use

Start from an existing tmux session:

```sh
cd /home/system/wip/philby-glm
make pi
```

Run checks:

```sh
make test
```

Spawn a subagent pane:

```sh
make subagent name=review prompt='Read Makefile and AGENTS.md, then review the current changes.'
```

## Secrets

`make pi` loads `.env` if present and requires `OPENROUTER_API_KEY`.

Tracked files use the environment variable name only. The local `.env` file is ignored by git.

## Shape

- `Makefile` is the public entry point.
- `common.mk` owns the implementation of targets.
- `pane.sh` opens or reuses tmux panes.
- `system.md` is the default Philby GLM personality.
- `AGENTS.md` is the repo contract for coding agents.

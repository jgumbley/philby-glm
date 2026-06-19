# Workspace Learnings

Date reviewed: 2026-06-19

Scope: repositories under `/home/system/wip`, with emphasis on Makefile conventions,
`AGENTS.md` guidance, tmux pane workflows, and Ansible-managed system configuration.

## Repository Inventory

Repositories found:

- `spreading-snake`
- `kuro-diagnostic`
- `games`
- `games/dc_dev`
- `games/dc_dev/Supermodel`
- `games/mace`
- `nesteggs`
- `todo`
- `mw/openmw-worldbuilding-harness`
- `mw/eadwig`
- `mw/Trueing`
- `mw/Erignis`
- `qfield-adaptor`
- `setup-system`
- `phasorsyncrs`
- `open-creel`
- `open-creel/vendor/gondolin`

`games/mace` appears to be an empty Git checkout with no working files outside
`.git`. The nested `Supermodel` and `vendor/gondolin` repos are upstream-style
projects embedded inside local workflow repos.

## Main Pattern: Make Is The Control Plane

Most repos are explicitly Make-driven. The common instruction across
`AGENTS.md` files is:

- Read the `Makefile` first.
- Use `make` as the entrypoint for runtime, tests, checks, and automation.
- Run `make digest` where available before changing code.
- Add or adjust Make targets instead of running ad-hoc scripts directly.
- Stay inside the repo PWD unless explicitly told otherwise.
- Keep changes minimal, reuse existing structure, avoid hidden fallbacks, and
  fail fast.

The practical result is that `Makefile` plus `common.mk` form the operational
API for each repo. Agent work should usually start with:

```sh
make help
make digest
```

or, if no help exists:

```sh
sed -n '1,220p' Makefile
sed -n '1,220p' common.mk
```

## `common.mk` System

Most local repos include `common.mk`. The exact implementation varies by
generation, but the recurring targets are:

- `digest`: print an agent-readable digest of selected source/docs/config files.
- `ingest`: pipe the digest to a clipboard tool.
- `.venv/`: create a Python virtualenv, usually with `uv`.
- `clean`: remove generated virtualenvs or local build output.
- `status` or `success`: print a decorated completion line plus metadata such
  as timestamp, user, host, process id, and parent process.

There are two broad generations:

- Older `success` style: targets end with `$(call success)`.
- Newer `status_call` style: `status_call = @$(MAKE) --no-print-directory status TARGET="$(@)"`,
  and targets end with `$(status_call)`.

The newer scaffold is captured in `qfield-adaptor/init.skill`. It defines a
reusable repo bootstrap pattern:

- `AGENTS.md`
- `common.mk`
- `Makefile`
- `requirements.txt`
- `main.py`
- local `UV_CACHE_DIR=$(CURDIR)/.uv-cache`
- `digest`, `ingest`, and `status`
- a small Textual app as the default runnable target

The OpenMW repos use a stronger digest implementation that prunes `.git`,
virtualenvs, node modules, vendor dirs, runtime state, binary assets, logs, and
external asset-heavy directories. That is the right model for repos with large
media trees.

## Pane Workflow

Pane helpers exist at:

- `games/pane.sh`
- `games/copy_wii/pane.sh`
- `setup-system/pane.sh`
- `phasorsyncrs/pane.sh`
- `open-creel/pane.sh`
- `todo/pane.sh`

The standard `pane.sh` pattern:

- Must be run from inside an existing tmux session.
- Takes `<pane-label> <command ...>`.
- Splits a new vertical pane in the current repo directory.
- Uses `AGENT_PANE_PERCENT`, defaulting to `45`, to size the pane.
- Sets the pane title to the label.
- Runs the command in a temporary runner script.
- Prints instructions for sudo/BECOME prompts and secrets.
- Keeps the pane open after command exit.
- Lets the user press Enter in that pane to rerun.
- Lets the main agent inspect output with `tmux capture-pane -pt <pane_id>`.

`open-creel/pane.sh` is the most mature version. It detects an existing pane
with the same title in the current tmux session and avoids creating duplicates.
It explicitly tells the operator to reuse or close panes when finished.

`todo/pane.sh` is different: it is a tmux control utility with subcommands:

- `list`
- `capture <pane_id> [lines]`
- `send <pane_id> <keys...>`
- `cmd <pane_id> <command...>`
- `msg <message...>`
- `ctrlc <pane_id>`

Several `common.mk` files expose `agent-%`, for example in `games`,
`games/copy_wii`, and `phasorsyncrs`:

```make
agent-%:
	bash ./pane.sh "agent-$$cmd_target" $(MAKE) "$$cmd_target"
```

Use pane runners for targets that need interactive credentials, sudo/BECOME
passwords, long-running output, hardware access, block-device work, or writes
outside the workspace.

## Tmux Configuration

`setup-system` deploys tmux config through
`roles/terminal/templates/tmux.conf.j2`.

Notable behavior:

- Mouse mode enabled.
- Windows and panes are 1-indexed.
- Prefix reload binding: `prefix r`.
- `prefix |` splits horizontally.
- `prefix -` splits vertically.
- `C-t` creates a new tmux window.
- `C-\` and `C-]` switch previous/next windows.
- vi copy mode is enabled.
- `v` begins copy selection and `y` copies in copy mode.
- `C-h` and `C-l` switch panes, with Vim-aware behavior.
- Scrollback history is `10000`.
- The default shell is templated by Ansible.
- The status bar is themed from `group_vars/all/theme.yml`.

## Ansible System Configuration

`setup-system` is the main host configuration repo. Its Makefile wraps Ansible:

- `make core`: bootstraps then runs `core.yml`.
- `make term`: runs `terminal.yml`.
- `make nas`: runs `nas.yml`.
- `make setup`: runs `setup.yml`.
- `make setup-check`: syntax-checks `setup.yml`.
- `make backup`: mounts NAS and rsyncs `~/wip`.
- `make backup-phone`: pulls a rooted phone filesystem to NAS.
- `make caffeinate`: uses `systemd-inhibit` to prevent suspend.

`setup.yml` chooses roles from `machines.yml` based on hostname. The important
machine profiles are:

- `hal`: `terminal`, `sway-desktop`, `hal_hardware`, `ssh_host`, `docker`,
  `openmw`, `steam`, `openclaw`
- `system`: `nas-mount`, `sway-desktop`, `openmw`, `emulators`, `godot`,
  `sway-backlight`, `tp_firmware`, `powersave`
- `pi-*`: `terminal`, `ssh_host`, `realtime-audio`
- `arnold`: `nas-mount`

Role learnings:

- `core-tools` does platform detection, platform-specific package work, coding
  agent installation, and system-wide secret environment support.
- `core-tools/tasks/coding_agents.yml` installs or updates Claude Code,
  OpenAI Codex, Pi Coding Agent, and OpenCode AI globally via npm.
- `terminal` configures fish, tmux, vim, neovim, git, kitty, Midnight Commander,
  Docker Compose plugin on macOS, and local secret env templates.
- `ssh_host` installs and hardens OpenSSH server, disables password auth,
  disables root login, installs a banner, creates the `system` user with fish,
  and manages authorized keys.
- `docker` installs Docker, buildx, Compose v2, adds `system` to `docker`, and
  configures a default buildx builder.
- `nas-mount` uses autofs on macOS and fstab/systemd automount on Linux, with a
  stable `/usr/local/mnt/<share>` path.
- `sway-desktop` installs Sway, Waybar, Wofi, screenshot tools, ydotool, VNC
  viewer, wallpaper rotation, Kanshi, and templated configs.
- `openmw` removes distro OpenMW packages, adds OpenMW PPAs, installs daily
  OpenMW/OpenMW-CS, and installs content creation tools.
- `hal_hardware` installs hardware tools, configures the first wireless
  interface for monitor mode, sets CPU/GPU performance knobs, and adds the user
  to the render group.
- `realtime-audio` installs audio packages, configures system limits, user
  permissions, and JACK.
- `powersave` removes or disables background services, installs power tools,
  switches Firefox away from snap, and keeps journald non-persistent.
- `emulators`, `godot`, `steam`, `tp_firmware`, `sway-backlight`, and
  `onepassword-cli` are focused host capability roles.

The system setup repo should be run through `pane.sh` whenever sudo/BECOME
interaction is likely.

## Open-Creel Ansible Stack

`open-creel` is an Ansible-driven sandbox and telemetry stack for monitoring
OpenClaw-like agent activity.

Layered Make targets:

- `make sandbox-build-openclaw-guest`: builds Gondolin guest assets from an OCI
  rootfs config into `.gondolin-openclaw-assets`.
- `make sandbox`: provisions the local Gondolin sandbox VM lifecycle and writes
  generated SSH inventory/key material.
- `make openclaw`: connects to the Gondolin guest over SSH and validates the
  OpenClaw CLI/gateway.
- `make telemetry`: provisions host Zeek, eBPF, OpenClaw journal collection, and
  spool-to-bronze merge services.
- `make provision`: runs sandbox, openclaw, and telemetry in order.
- `make bronze`: tails bronze evidence logs.
- `make silver` and `make gold`: transform bronze records into OCSF silver/gold
  outputs.

The Makefile sets Ansible temp paths under `/tmp/open-creel-ansible`:

```make
ANSIBLE_LOCAL_TEMP ?= /tmp/open-creel-ansible/local
ANSIBLE_REMOTE_TEMP ?= /tmp/open-creel-ansible/remote
```

Provisioning split:

- `provision/sandbox.yml`: local, become, QEMU/Gondolin lifecycle.
- `provision/openclaw.yml`: SSH to generated `gondolin` inventory, no become.
- `provision/telemetry.yml`: local, become, host collectors.

Telemetry outputs:

- Zeek JSON logs under `/var/lib/open-creel/data/bronze/zeek`.
- eBPF logs under `/var/lib/open-creel/data/bronze/ebpf`.
- OpenClaw runtime/audit/message/tool/approval/skill/auth logs under
  `/var/lib/open-creel/data/bronze/openclaw`.
- Gondolin guest spool streams under `/var/lib/open-creel/data/spool/gondolin`.

`open-creel/continuity.md` records a live handoff: `make openclaw` currently got
past npm self-update and missing git, but failed installing `openclaw@latest`
because a native dependency needed `make` in the guest. The next fix is likely
to install guest build prerequisites before the npm install.

## Repo Notes

### `spreading-snake`

Simulation testbed for distinguishing SSH snake-like propagation from
deployment fan-out. Make targets run `simulate.py` against
`scenario_snake.json` or `scenario_deployment.json`, then detect from generated
events. The README records successful snake and deployment runs.

### `kuro-diagnostic`

Python RS-232 status monitor for Pioneer KURO displays. Make targets cover
polling, raw passive/probe mode, serial port listing, syntax check, and the same
simulate/detect pattern used by `spreading-snake`.

### `qfield-adaptor`

Minimal Textual hello-world scaffold. The important artifact is `init.skill`,
which documents the reusable Make/common.mk bootstrap pattern for new repos.

### `todo`

Local JSON todo system with Workflowy OPML import/sync, schema validation, TUI,
Textual web serving, and summary workflows through `pi`. Its `pane.sh` is a
tmux control helper rather than the standard agent-runner pane.

### `nesteggs`

Local-only Flask/YAML portfolio and valuation tracker. Uses one `Asset` concept
for accounts, manual assets, and liabilities. Valuations are append-only and
liabilities are negative values. Make targets support mark-to-market updates for
generic assets, gold, Bitcoin, and latest asset inspection.

### `phasorsyncrs`

Rust real-time MIDI/audio sequencer project. Make targets enforce a strict
chain: `test` depends on `clippy`, `build` depends on `test`, and `ci` depends
on `build`. It also has ALSA device discovery, UMC1820 recording helpers, WAV
playback, sample WAV generation, logs, and pane-runnable `agent-%` targets.

Architecture notes emphasize small modules, TDD, `midir` for MIDI I/O, and a
message-passing concurrency model where the MIDI callback stays lightweight and
the inspector/UI thread never directly contends on core state.

### `games`

Local games and emulation operations repo. It manages ROM sync to Rocknix,
Wii SD-card images, DS4 Bluetooth setup, PC-98 MAME launch, and local mod/ROM
assets. Some workflows are destructive against block devices, so the README
explicitly calls for checking `lsblk` before image push/expand/fixup operations.

`make agent-<target>` is available for pane-running interactive or privileged
targets.

### `games/dc_dev`

Sega Model 3/Sega Rally 2 wrapper around the nested `Supermodel` repo. The
Makefile can clone/build Supermodel, copy config, launch Sega Rally 2 fullscreen,
detect resolution, inspect ROMs, and inspect input devices/permissions.

The `simulate` and `detect` targets are declared but the README says the Python
files they reference are not present in this checkout.

### `games/dc_dev/Supermodel`

Upstream Sega Model 3 emulator source. It builds with platform-specific
Makefiles and requires SDL2/OpenGL/native compiler dependencies. This repo is
embedded as a dependency of `games/dc_dev`, not aligned with the local
`common.mk`/`AGENTS.md` pattern.

### `games/mace`

Empty Git checkout in this tree. No Makefile, README, AGENTS, or working files
were present outside `.git`.

### `mw/openmw-worldbuilding-harness`

Self-contained OpenMW verification harness. Public workflows are Make-only:

- `verify`
- `trace`
- `scenario-lint`
- `contract-lint`
- `catalog-lint`
- `screenshot-analyze`
- `template-list`
- `template-print`
- `test`

The harness has four conceptual layers:

- static deterministic contract checks;
- OpenMW runtime probes through GPVERIFY Lua plumbing;
- screenshot purple-void detection as a secondary visual check;
- agent guidance through `SKILL.md`, schemas, examples, and templates.

It writes `.gpverify/<run-id>/report.json`, trace JSONL, and screenshots. Missing
inputs are errors, not skipped checks.

### `mw/Erignis`

Make-only facade over `openmw-worldbuilding-harness`. It does not own world
content. `state.mk` points the active world to `../eadwig`, with default target
`scene-thin-slice-verify`. It is the generic runtime/lint/trace facade.

### `mw/Trueing`

Thin reward/state layer over the OpenMW harness. It adds reward scoring,
deterministic state backends, and run harvesting. State is explicit:

- `STATE_BACKEND=memory` for local/test runs.
- `STATE_BACKEND=neo4j` only when persistent memory is required.

Neo4j connection failures are intended to fail when `neo4j` is selected.

### `mw/eadwig`

Standalone OpenMW game workspace. Required reads are `AGENTS.md`,
`env_&tools.md`, `current_world.md`, the Makefile, and relevant verify inputs.

Key workflows:

- `make openmw` or `make run`: launch the game with repo-local config/state.
- `make audit`: short no-sound OpenMW run into `openmw-run.log`.
- `make missing-resources`: parse missing VFS resources.
- `make scene-thin-slice-content/lint/verify/trace/openmw`.
- `make trueing-abbot-lint/verify/trace/reward/harvest`.

The repo keeps world-specific manifests, scenarios, contracts, catalogs, and
OpenMW wrapper scripts under `verify/`, while delegating harness execution to
`../openmw-worldbuilding-harness` or `../Trueing`.

Asset rule: prefer existing game/mod assets, import only selected loose assets
into `data/`, document source changes in `current_world.md`, and run audit plus
missing-resource checks after content edits. OpenMW resource lookup is
case-sensitive on Linux.

### `setup-system`

Ansible host management repo. See the Ansible section above. This is the source
of truth for machine profiles, including `hal`, terminal/tmux configuration,
system roles, NAS mount, OpenMW, Docker, SSH, Sway, Steam, OpenClaw, and
hardware tuning.

### `open-creel`

Layered Ansible/Make stack for local agent sandboxing, guest OpenClaw runtime,
host telemetry, and bronze/silver/gold security data transforms. See the
Open-Creel Ansible section above.

### `open-creel/vendor/gondolin`

Embedded Gondolin micro-VM sandbox repo. Root Make targets build, lint,
typecheck, test, format, fuzz, and build docs across guest and host packages.

Architecture:

- `guest/`: Zig sandbox daemon and Alpine initramfs/image pipeline.
- `host/`: TypeScript controller, programmable network stack, VFS, CLI, tests.
- `docs/`: documentation site.

Gondolin's core model is local QEMU micro-VMs with host-controlled networking,
secret injection at the network layer, programmable filesystem/VFS behavior,
SSH egress allowlists, and snapshot/resume support.

## Practical Rules For Future Agents

- Start with `AGENTS.md`, then `Makefile`, then `make digest` when available.
- Use Make targets as the stable interface; add targets instead of bypassing
  local conventions.
- Use `pane.sh` or `make agent-<target>` for sudo/BECOME prompts, hardware,
  raw-device work, long-running commands, or anything needing local secrets.
- For `setup-system`, prefer `./pane.sh setup make setup` or equivalent pane
  runner because Ansible commonly needs BECOME input.
- For `open-creel`, use the layered flow and reuse existing panes:
  `clean-sandbox`, `sandbox-build-openclaw-guest`, `sandbox`, `openclaw`,
  `telemetry`.
- For OpenMW work, never treat gameplay success as scene success. Run static
  lints and scene/runtime harness checks.
- For asset work, use existing local game/mod assets first and keep external
  archives out of world repos.
- Preserve working tree changes. Several repos explicitly warn not to discard
  uncommitted edits without approval.


SHELL := /bin/bash

.PHONY: help digest digest-raw ingest pane pi pi-agent pi-check models subagent test clean

export PI_CODING_AGENT_DIR := $(CURDIR)/.pi/agent
export PI_CODING_AGENT_SESSION_DIR := $(PI_CODING_AGENT_DIR)/sessions

PI_PROVIDER ?= openrouter
PI_MODEL_ID ?= z-ai/glm-5.2
PI_THINKING ?= xhigh
PI_SYSTEM_PROMPT ?= system.md
PI_PANE_LABEL ?= philby-glm
SUBAGENT_NAME ?= $(if $(name),$(name),subagent)
SUBAGENT_PROMPT ?= $(if $(prompt),$(prompt),Read Makefile, run make digest, and wait for the operator's task.)

define success
	@printf '\033[32m%s completed [OK]\033[0m\n' "$(@)"
endef

help:
	@printf '%s\n' "Targets:"
	@printf '%s\n' "  make pi                         Launch Philby GLM in a tmux pane"
	@printf '%s\n' "  make subagent name=review prompt='...'  Launch a named Pi subagent pane"
	@printf '%s\n' "  make pane target=<target>        Run any make target in a tmux pane"
	@printf '%s\n' "  make models                      Show the configured GLM model"
	@printf '%s\n' "  make pi-check                    Validate local Pi, tmux, and model config"
	@printf '%s\n' "  make digest                      Print the canonical project context"
	@printf '%s\n' "  make ingest                      Copy digest through OSC 52"
	@printf '%s\n' "  make test                        Run wiring checks"
	@printf '%s\n' "  make clean                       Remove local runtime sessions"

digest-raw:
	@echo "=== Project Digest ==="
	@for file in $$(find . \
		-path "./.git" -prune -o \
		-path "./.venv" -prune -o \
		-path "./.uv-cache" -prune -o \
		-path "./.pi/agent/sessions" -prune -o \
		-path "./.pi/agent/auth.json" -prune -o \
		-type f \( \
			-name "*.md" -o \
			-name "*.mk" -o \
			-name "*.sh" -o \
			-name "*.json" -o \
			-name "Makefile" -o \
			-name ".gitignore" -o \
			-name ".env.example" \
		\) -print | sort); do \
		echo ""; \
		echo "--- $$file ---"; \
		cat "$$file"; \
	done

digest:
	@$(MAKE) --no-print-directory -f common.mk digest-raw
	$(call success)

ingest:
	@digest_output="$$( $(MAKE) --no-print-directory -f common.mk digest-raw )" && \
	payload="$$(printf '%s\n' "$$digest_output" | base64 | tr -d '\n')" && \
	if [ -n "$${TMUX:-}" ]; then \
		printf '\033Ptmux;\033\033]52;c;%s\a\033\\' "$$payload"; \
	else \
		printf '\033]52;c;%s\a' "$$payload"; \
	fi
	$(call success)

pane:
	@set -euo pipefail; \
	cmd_target="$(target)"; \
	if [ -z "$$cmd_target" ]; then \
		bash ./pane.sh --shell "philby-shell"; \
	else \
		bash ./pane.sh "philby-$$cmd_target" $(MAKE) --no-print-directory "$$cmd_target"; \
	fi

pi:
	@set -euo pipefail; \
	if [ -z "$${TMUX:-}" ]; then \
		printf 'make pi must be run inside an existing tmux session.\n' >&2; \
		printf 'Start tmux first, then run: make pi\n' >&2; \
		exit 2; \
	fi; \
	bash ./pane.sh "$(PI_PANE_LABEL)" $(MAKE) --no-print-directory pi-agent

pi-agent:
	@set -euo pipefail; \
	if [ -z "$${TMUX:-}" ]; then \
		printf 'pi-agent must run inside tmux. Use: make pi\n' >&2; \
		exit 2; \
	fi; \
	test -f "$(PI_SYSTEM_PROMPT)"; \
	test -f "$(PI_CODING_AGENT_DIR)/models.json"; \
	test -f "$(PI_CODING_AGENT_DIR)/settings.json"; \
	if [ -f .env ]; then set -a; . ./.env; set +a; fi; \
	: "$${OPENROUTER_API_KEY:?OPENROUTER_API_KEY is required. Put it in .env or export it before running make pi.}"; \
	args=( \
		--provider "$(PI_PROVIDER)" \
		--model "$(PI_MODEL_ID)" \
		--thinking "$(PI_THINKING)" \
		--append-system-prompt "$(PI_SYSTEM_PROMPT)" \
	); \
	if [ -n "$${PI_INITIAL_PROMPT:-}" ]; then \
		args+=("$$PI_INITIAL_PROMPT"); \
	fi; \
	exec pi "$${args[@]}"

subagent:
	@set -euo pipefail; \
	if [ -z "$${TMUX:-}" ]; then \
		printf 'make subagent must be run inside an existing tmux session.\n' >&2; \
		exit 2; \
	fi; \
	label="philby-$(SUBAGENT_NAME)"; \
	prompt="$(SUBAGENT_PROMPT)"; \
	bash ./pane.sh "$$label" env PI_INITIAL_PROMPT="$$prompt" $(MAKE) --no-print-directory pi-agent

pi-check:
	@set -euo pipefail; \
	command -v pi >/dev/null; \
	command -v tmux >/dev/null; \
	test -f "$(PI_SYSTEM_PROMPT)"; \
	test -f "$(PI_CODING_AGENT_DIR)/models.json"; \
	test -f "$(PI_CODING_AGENT_DIR)/settings.json"; \
	OPENROUTER_API_KEY=dummy pi --offline --list-models "$(PI_MODEL_ID)" 2>&1 | grep -q "$(PI_MODEL_ID)"
	$(call success)

models:
	@OPENROUTER_API_KEY=dummy pi --offline --list-models "$(PI_MODEL_ID)"

test: pi-check
	@$(MAKE) --no-print-directory -f common.mk digest-raw >/dev/null
	$(call success)

clean:
	rm -Rf "$(PI_CODING_AGENT_DIR)/sessions"
	$(call success)

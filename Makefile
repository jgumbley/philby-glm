.DEFAULT_GOAL := run

.PHONY: help run tmux-start tmux-entry digest digest-raw ingest pane pane-show pi pi-agent pi-check models subagent codex ascii-text generate-ascii-text image-demo image-show lg respawn test clean

help:
	@$(MAKE) --no-print-directory -f common.mk help

run:
	@$(MAKE) --no-print-directory -f common.mk run PI_ENTRYPOINT=make

tmux-start:
	@$(MAKE) --no-print-directory -f common.mk tmux-start PI_ENTRYPOINT=make

tmux-entry:
	@$(MAKE) --no-print-directory -f common.mk tmux-entry PI_ENTRYPOINT="$(PI_ENTRYPOINT)"

digest:
	$(MAKE) -f common.mk digest

digest-raw:
	$(MAKE) -f common.mk digest-raw

ingest:
	$(MAKE) -f common.mk ingest

pane:
	$(MAKE) -f common.mk pane target="$(target)" kill="$(kill)" orient="$(orient)"

# Display an arbitrary image in a new tmux pane via kitty icat.
# Usage: make pane-show IMAGE=/path/to/image.png
pane-show:
	@bash ./pane.sh "philby-show" $(MAKE) --no-print-directory image-show IMAGE="$(IMAGE)"

pi:
	$(MAKE) -f common.mk pi

pi-agent:
	$(MAKE) -f common.mk pi-agent

pi-check:
	$(MAKE) -f common.mk pi-check

models:
	$(MAKE) -f common.mk models

subagent:
	$(MAKE) -f common.mk subagent name="$(name)" prompt="$(prompt)"

codex:
	$(MAKE) -f common.mk codex

ascii-text:
	@$(MAKE) --no-print-directory -f common.mk ascii-text TEXT="$(TEXT)"

generate-ascii-text:
	@$(MAKE) --no-print-directory -f common.mk generate-ascii-text TEXT="$(TEXT)"

image-demo:
	$(MAKE) -f common.mk image-demo

image-show:
	$(MAKE) -f common.mk image-show IMAGE="$(IMAGE)"

lg:
	$(MAKE) -f common.mk lg

respawn:
	$(MAKE) -f common.mk respawn

test:
	$(MAKE) -f common.mk test

clean:
	$(MAKE) -f common.mk clean

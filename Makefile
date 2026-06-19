.DEFAULT_GOAL := help

.PHONY: help digest digest-raw ingest pane pi pi-agent pi-check models subagent test clean

help:
	$(MAKE) -f common.mk help

digest:
	$(MAKE) -f common.mk digest

digest-raw:
	$(MAKE) -f common.mk digest-raw

ingest:
	$(MAKE) -f common.mk ingest

pane:
	$(MAKE) -f common.mk pane target="$(target)"

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

test:
	$(MAKE) -f common.mk test

clean:
	$(MAKE) -f common.mk clean

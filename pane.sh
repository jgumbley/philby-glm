#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  pane.sh <pane-label> <command ...>
  pane.sh --shell <pane-label>
EOF
  exit 1
}

use_shell=0
if [ "${1:-}" = "--shell" ]; then
  use_shell=1
  shift
fi

if [ $# -lt 1 ]; then
  usage
fi

pane_label="$1"
shift

if [ "$use_shell" -eq 1 ]; then
  set -- "${SHELL:-/bin/bash}"
fi

if [ $# -lt 1 ]; then
  usage
fi

cmd_display="$(printf ' %q' "$@")"
cmd_display="${cmd_display:1}"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is required to start an agent pane." >&2
  exit 1
fi

if [ -z "${TMUX:-}" ]; then
  echo "agent panes must be started from inside an existing tmux session." >&2
  exit 1
fi

repo_root="$(pwd)"
pane_height="${AGENT_PANE_PERCENT:-45}"
current_height="$(tmux display-message -p '#{pane_height}' 2>/dev/null || true)"
pane_lines="$pane_height"
if [ -n "$current_height" ] && [ "$current_height" -gt 0 ] 2>/dev/null; then
  pane_lines=$((current_height * pane_height / 100))
  [ "$pane_lines" -lt 3 ] && pane_lines=3
fi

session_id="$(tmux display-message -p '#{session_id}')"
existing_pane="$(
  tmux list-panes -t "$session_id" -F '#{pane_id}::#{pane_title}' |
    awk -F '::' -v label="$pane_label" '$2 == label { print $1; exit }'
)"

if [ -n "$existing_pane" ]; then
  cat <<EOF
Pane "$existing_pane" for "$pane_label" already exists in this session.
No new pane was created.
To rerun in that pane: tmux send-keys -t $existing_pane C-m
To capture output: tmux capture-pane -pt $existing_pane
Close used panes when finished: tmux kill-pane -t $existing_pane
EOF
  exit 0
fi

runner_script="$(mktemp)"
cat > "$runner_script" <<'RUNNER_EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: tmux-agent-pane <pane-label> <command ...>" >&2
  exit 1
fi

pane_label="$1"
shift

cmd_display="$(printf ' %q' "$@")"
cmd_display="${cmd_display:1}"

printf '\033]2;%s\007' "$pane_label"

cat <<EOF
[agent:${pane_label}] Running ${cmd_display}

If prompted for credentials, type them directly in this pane.
Secrets typed here are not echoed and will not appear in captured output.

When the command finishes, reuse this same pane to rerun it:
- press Enter in this pane, or
- from another pane run: tmux send-keys -t "$TMUX_PANE" C-m

EOF

status=0
while :; do
  if "$@"; then
    status=0
  else
    status=$?
  fi

  cat <<EOF

[agent:${pane_label}] Command exited with status ${status}.
Reuse this pane by pressing Enter, or close it with Ctrl-b x.

EOF

  if [ ! -t 0 ]; then
    break
  fi
  read -r _ || break
done

exit "$status"
RUNNER_EOF

pane_id="$(tmux split-window -b -v -l "$pane_lines" -c "$repo_root" -P -F '#{pane_id}' \
  bash "$runner_script" "$pane_label" "$@")"
rm -f "$runner_script"

cat <<EOF
Started tmux pane "$pane_id" for "$pane_label".
Command: $cmd_display
To capture output later: tmux capture-pane -pt $pane_id
To rerun in the same pane: tmux send-keys -t $pane_id C-m
EOF

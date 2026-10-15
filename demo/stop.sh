#!/usr/bin/env bash
# Stop the demo stack by process name (saved pids are unreliable), then wait for it to
# exit: Tempo needs ~5s to release :3210, and a replacement started before then dies
# with "bind: address already in use". --wipe deletes data.
DEMO_HOME="${DEMO_HOME:-$HOME/.cache/traces-drilldown-demo}"
G="$DEMO_HOME/bin/grafana-"; T="$DEMO_HOME/bin/tempo"
running() { pgrep -f "$G" >/dev/null 2>&1 || pgrep -f "$T" >/dev/null 2>&1; }
pkill -f "$G" 2>/dev/null; pkill -f "$T" 2>/dev/null
for i in $(seq 1 30); do
  running || break
  [ "$i" -eq 20 ] && { pkill -9 -f "$G" 2>/dev/null; pkill -9 -f "$T" 2>/dev/null; }
  sleep 1
done
running && echo "warning: demo stack still running under $DEMO_HOME" >&2
rm -f "$DEMO_HOME"/run/*.pid
[ "${1:-}" = "--wipe" ] && rm -rf "$DEMO_HOME/data" && echo "wiped $DEMO_HOME/data"
exit 0

#!/usr/bin/env bash
# Stop the demo stack by process name (saved Grafana pids are unreliable). --wipe deletes data.
DEMO_HOME="${DEMO_HOME:-$HOME/.cache/traces-drilldown-demo}"
pkill -f "$DEMO_HOME/bin/grafana-" 2>/dev/null; pkill -f "$DEMO_HOME/bin/tempo" 2>/dev/null
rm -f "$DEMO_HOME"/run/*.pid
[ "${1:-}" = "--wipe" ] && rm -rf "$DEMO_HOME/data" && echo "wiped $DEMO_HOME/data"
exit 0

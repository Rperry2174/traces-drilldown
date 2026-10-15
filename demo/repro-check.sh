#!/usr/bin/env bash
# repro check for the traces-drilldown breakdown-header bug (upstream fix PR #873).
# Re-seeds Tempo (1h window), then exits 1 while the bug exists (expected on main), 0 once fixed.
set -uo pipefail
cd "$(dirname "$0")"
python3 seed_tempo.py >/dev/null || echo "warning: re-seed failed"
sleep 5
CHROME="$(./find-chrome.sh)"; export CHROME
python3 repro_check.py "$@"; rc=$?
[ $rc -eq 0 ] && echo "PASS (headers fixed)" || echo "FAIL (bug reproduced or stack not ready), exit $rc"
exit $rc

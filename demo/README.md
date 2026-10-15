# traces-drilldown breakdown-header repro kit (upstream fix PR #873)

`main` = upstream main with the fix reverted (bug present; pre-fix reference 78888f9059, pre-fix; fix is d355e5b00d) plus this demo/ kit and `.cursor/`.

- `demo/start.sh [--build]`: Tempo 2.8.2 (:3210, OTLP/HTTP :4328), seeds via `demo/seed_tempo.py`, Grafana 12.3.0 :3330 (./dist mounted)
- `demo/repro-check.sh`: re-seeds, then exits 1 while breakdown headers have the hidden hover-menu slot / segmented Include-Exclude (expected pre-fix), 0 once fixed
- `demo/stop.sh [--wipe]`

No Docker needed. Grafana falls back to Docker Hub image layers when dl.grafana.com is blocked; the check falls back to system Chrome.
PRs from agents go to Rperry2174/traces-drilldown only, never grafana/*.

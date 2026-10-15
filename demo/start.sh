#!/usr/bin/env bash
# Local repro stack for the traces-drilldown breakdown-header bug (fixed upstream by PR #873), no Docker.
#   Tempo 2.8.2 (HTTP :3210, OTLP/HTTP :4328) + Grafana Enterprise 12.3.0 :3330 with ./dist mounted + demo/seed_tempo.py.
#   demo/start.sh [--build]     demo/stop.sh [--wipe]
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEMO_HOME="${DEMO_HOME:-$HOME/.cache/traces-drilldown-demo}"
GF_VER=12.3.0; TEMPO_VER=2.8.2; GRAFANA_PORT=3330
mkdir -p "$DEMO_HOME"/{bin,run/plugins,run/prov/datasources,run/prov/plugins,logs,data}
os=$(uname -s | tr '[:upper:]' '[:lower:]'); arch=$(uname -m)
case "$arch" in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; esac
[ -x "$DEMO_HOME/bin/grafana-$GF_VER/bin/grafana" ] || "$REPO/demo/fetch-grafana.sh" "$GF_VER" "$DEMO_HOME/bin"
if [ ! -x "$DEMO_HOME/bin/tempo" ]; then
  echo "downloading Tempo $TEMPO_VER…"
  curl -fsSL "https://github.com/grafana/tempo/releases/download/v$TEMPO_VER/tempo_${TEMPO_VER}_${os}_${arch}.tar.gz" | tar xz -C "$DEMO_HOME/bin" tempo
fi
[ -n "${DEMO_DOWNLOAD_ONLY:-}" ] && { echo "binaries ready in $DEMO_HOME/bin"; exit 0; }
if [ "${1:-}" = "--build" ] || [ ! -f "$REPO/dist/module.js" ]; then
  (cd "$REPO" && pnpm install --frozen-lockfile --ignore-scripts && pnpm run build)
fi
R="$DEMO_HOME/run"; D="$DEMO_HOME/data/tempo"
cat > "$R/tempo.yaml" <<Y
stream_over_http_enabled: true
server: { http_listen_port: 3210, grpc_listen_port: 9497 }
distributor: { receivers: { otlp: { protocols: { http: { endpoint: 127.0.0.1:4328 } } } } }
ingester: { max_block_duration: 5m }
compactor: { compaction: { block_retention: 24h } }
metrics_generator:
  registry: { external_labels: { source: tempo } }
  storage: { path: $D/generator/wal }
  traces_storage: { path: $D/generator/traces }
  processor: { local_blocks: { filter_server_spans: false, flush_to_storage: true } }
storage: { trace: { backend: local, wal: { path: $D/wal }, local: { path: $D/blocks } } }
overrides: { defaults: { metrics_generator: { processors: [local-blocks] } } }
memberlist: { bind_port: 7956 }
Y
cat > "$R/prov/datasources/tempo.yaml" <<Y
apiVersion: 1
datasources:
  - { name: Tempo, uid: tempo, type: tempo, url: "http://127.0.0.1:3210", isDefault: true, jsonData: { streamingEnabled: { search: false, metrics: false } } }
Y
printf 'apiVersion: 1\napps:\n  - { type: grafana-exploretraces-app, jsonData: {} }\n' > "$R/prov/plugins/app.yaml"
ln -sfn "$REPO/dist" "$R/plugins/grafana-exploretraces-app"
if ! curl -sf http://127.0.0.1:3210/ready >/dev/null 2>&1; then
  (cd "$DEMO_HOME/data" && nohup "$DEMO_HOME/bin/tempo" -config.file="$R/tempo.yaml" > "$DEMO_HOME/logs/tempo.log" 2>&1 < /dev/null & echo $! > "$R/tempo.pid")
  for _ in $(seq 90); do curl -sf http://127.0.0.1:3210/ready >/dev/null 2>&1 && break; sleep 1; done
fi
# Without this, seed_tempo.py spends ~25 min retrying against a Tempo that never came up.
curl -sf http://127.0.0.1:3210/ready >/dev/null 2>&1 || { echo "Tempo not ready; see $DEMO_HOME/logs/tempo.log" >&2; exit 1; }
python3 "$REPO/demo/seed_tempo.py" || echo "seed failed (see above)"
if ! curl -sf "http://127.0.0.1:$GRAFANA_PORT/api/health" >/dev/null 2>&1; then
  G="$DEMO_HOME/bin/grafana-$GF_VER"
  GF_PATHS_DATA="$DEMO_HOME/data/grafana" GF_PATHS_LOGS="$DEMO_HOME/logs" GF_PATHS_PLUGINS="$R/plugins" GF_PATHS_PROVISIONING="$R/prov" \
  GF_SERVER_HTTP_PORT=$GRAFANA_PORT GF_SERVER_HTTP_ADDR=127.0.0.1 GF_AUTH_ANONYMOUS_ENABLED=true GF_AUTH_ANONYMOUS_ORG_ROLE=Admin GF_AUTH_DISABLE_LOGIN_FORM=true \
  GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS=grafana-exploretraces-app GF_PLUGINS_PREINSTALL_DISABLED=true GF_SECURITY_ALLOW_EMBEDDING=true GF_UNIFIED_ALERTING_ENABLED=false \
  GF_ANALYTICS_REPORTING_ENABLED=false GF_ANALYTICS_CHECK_FOR_UPDATES=false GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES=false GF_NEWS_NEWS_FEED_ENABLED=false \
  nohup "$G/bin/grafana" server --homepath "$G" > "$DEMO_HOME/logs/grafana.stdout" 2>&1 < /dev/null & echo $! > "$R/grafana.pid"
  for _ in $(seq 90); do curl -sf "http://127.0.0.1:$GRAFANA_PORT/api/health" >/dev/null 2>&1 && break; sleep 1; done
fi
curl -sf "http://127.0.0.1:$GRAFANA_PORT/api/health" >/dev/null 2>&1 || { echo "Grafana not ready; see $DEMO_HOME/logs/grafana.stdout" >&2; exit 1; }
echo "up: Grafana :$GRAFANA_PORT, Tempo :3210 (OTLP/HTTP :4328)"

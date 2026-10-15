#!/usr/bin/env bash
# Cloud Agent start step: (re)start the backend + Grafana with ./dist mounted, and seed.
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/node22/bin:$HOME/.local/bin:$PATH"
demo/stop.sh >/dev/null 2>&1 || true   # waits for :3210/:3330 to be released
demo/start.sh

#!/usr/bin/env bash
set -euo pipefail

GATEWAY_PORT="${GATEWAY_PORT:-3001}"
AGENT="${AGENT:-mark}"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <scenario.json>" >&2
  echo "Example: $0 scenarios/build_tail_1.json" >&2
  exit 1
fi

scenario="$1"
if [[ ! -f "$scenario" ]]; then
  echo "Error: file not found: $scenario" >&2
  exit 1
fi

url="http://${AGENT}.localhost:${GATEWAY_PORT}/command"
echo "Sending $(basename "$scenario") to $url ..."
curl -sS -X POST "$url" \
  -H "Content-Type: application/json" \
  -d @"$scenario"

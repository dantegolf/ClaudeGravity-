#!/usr/bin/env bash
set -euo pipefail

GATEWAY_HEALTH_URL="http://127.0.0.1:17645/health"
LIMITS_URL="http://127.0.0.1:18080/account-limits"

printf '=== ClaudeGravity status / limits ===\n\n'
if ! curl -fsS "$GATEWAY_HEALTH_URL" >/dev/null 2>&1; then
  printf 'ClaudeGravity gateway не запущен. Сначала откройте ClaudeGravity.\n'
  exit 1
fi

response="$(curl -fsS "$LIMITS_URL" 2>&1)" || {
  printf 'Gateway работает, но Antigravity engine не вернул лимиты.\n%s\n' "$response"
  exit 1
}

printf 'Gateway: http://127.0.0.1:17645/anthropic\n\n'
if command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$response" | jq
else
  printf '%s\n' "$response"
fi

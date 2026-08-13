#!/usr/bin/env bash
set -u

printf "=== Лимиты ClaudeGravity ===\n\n"
response="$(curl -fsS http://127.0.0.1:8080/health 2>&1)" || {
  printf "Прокси не запущен. Сначала откройте ClaudeGravity.\n%s\n" "$response"
  exit 1
}

if command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$response" | jq
else
  printf '%s\n' "$response"
fi

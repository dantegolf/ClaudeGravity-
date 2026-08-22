#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${ROOT}/scripts"
NODE_BIN="${CLAUDEGRAVITY_NODE:-$(command -v node || true)}"
SUPERVISOR="${SCRIPTS_DIR}/supervisor.mjs"
STATE_DIR="${CLAUDEGRAVITY_STATE_DIR:-${HOME}/.claudegravity}"

fail() {
  printf '\nОшибка: %s\n' "$1" >&2
  exit 1
}

[ -n "$NODE_BIN" ] || fail "Node.js 18+ не найден. Повторно запустите установщик ClaudeGravity."
"$NODE_BIN" -e 'if (Number(process.versions.node.split(".")[0]) < 18) process.exit(1)' || fail "Требуется Node.js 18 или новее."
[ -f "$SUPERVISOR" ] || fail "ClaudeGravity supervisor не найден. Переустановите ClaudeGravity."

export RELAY_AI_HOME="${RELAY_AI_HOME:-${HOME}/.relay-ai}"
export ANTIGRAVITY_API_KEY="${ANTIGRAVITY_API_KEY:-antigravity}"
export RELAY_AI_KEY_CUSTOM_ANTIGRAVITY="${RELAY_AI_KEY_CUSTOM_ANTIGRAVITY:-antigravity}"
export CLAUDEGRAVITY_STATE_DIR="$STATE_DIR"

if [ "${CLAUDEGRAVITY_FOREGROUND:-0}" = "1" ] || [ "${1:-}" = "--foreground" ]; then
  export CLAUDEGRAVITY_FOREGROUND_LOGS=1
  exec "$NODE_BIN" "$SUPERVISOR"
fi

mkdir -p "$STATE_DIR"
nohup "$NODE_BIN" "$SUPERVISOR" </dev/null >/dev/null 2>&1 &
exit 0

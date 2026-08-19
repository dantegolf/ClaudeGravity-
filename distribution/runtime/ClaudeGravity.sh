#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="${ROOT}/runtime"
SCRIPTS_DIR="${ROOT}/scripts"
PROXY_ROOT="${RUNTIME_DIR}/node_modules/antigravity-claude-proxy"
ACC_CLI="${PROXY_ROOT}/bin/cli.js"
RELAY_CLI="${RUNTIME_DIR}/node_modules/@jacobbd/relay-ai/dist/cli.js"
NODE_BIN="${CLAUDEGRAVITY_NODE:-$(command -v node || true)}"
HEALTH_URL="http://127.0.0.1:8080/health"

export RELAY_AI_HOME="${HOME}/.relay-ai"
export ANTIGRAVITY_API_KEY="antigravity"
export RELAY_AI_KEY_CUSTOM_ANTIGRAVITY="antigravity"

fail() {
  printf '\nОшибка: %s\n' "$1" >&2
  exit 1
}

[ -n "$NODE_BIN" ] || fail "Node.js 18+ не найден. Повторно запустите установщик ClaudeGravity."
"$NODE_BIN" -e 'if (Number(process.versions.node.split(".")[0]) < 18) process.exit(1)' || fail "Требуется Node.js 18 или новее."
[ -f "$ACC_CLI" ] || fail "Bundled Antigravity engine не найден. Переустановите ClaudeGravity."
[ -f "$RELAY_CLI" ] || fail "Bundled Relay engine не найден. Переустановите ClaudeGravity."

acc() { "$NODE_BIN" "$ACC_CLI" "$@"; }
relay_ai() { "$NODE_BIN" "$RELAY_CLI" "$@"; }

clear 2>/dev/null || true
printf '%s\n' \
  '╭─────────────────────────────────────────╮' \
  '│          ClaudeGravity Launcher         │' \
  '╰─────────────────────────────────────────╯'
printf 'Runtime: bundled · Smart DNS: selective\n'

"$NODE_BIN" "${SCRIPTS_DIR}/patch-antigravity-proxy.mjs" "$PROXY_ROOT" || \
  fail "Bundled Antigravity engine не прошёл compatibility check."

acc stop >/dev/null 2>&1 || true
"$NODE_BIN" "${SCRIPTS_DIR}/configure-relay.mjs" "$RELAY_AI_HOME" || \
  fail "Не удалось подготовить конфигурацию Relay AI."

provider_output="$(relay_ai providers list 2>&1 || true)"
printf '%s' "$provider_output" | grep -Fq 'custom-antigravity' || \
  fail "Relay AI не увидел провайдер Antigravity. ${provider_output}"

account_output="$(acc accounts list 2>/dev/null || true)"
if ! printf '%s' "$account_output" | grep -Eq '[1-9][0-9]* account\(s\)'; then
  printf '\nАккаунт Google ещё не привязан. Привязать сейчас? [Y/n]: '
  read -r reply
  if [[ ! "${reply:-Y}" =~ ^[Yy]$ ]]; then
    fail "Для запуска необходимо привязать аккаунт Google."
  fi
  acc accounts add || fail "Не удалось привязать аккаунт Google."
fi

if ! curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
  printf '\nЗапускаю Antigravity engine...\n'
  acc start || fail "Не удалось запустить Antigravity engine."
  proxy_ready=false
  for _ in {1..12}; do
    if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
      proxy_ready=true
      break
    fi
    sleep 1
  done
  $proxy_ready || fail "Прокси не ответил на ${HEALTH_URL}."
fi

printf '\n✓ ClaudeGravity готов. Открываю Claude Desktop...\n\n'
exec "$NODE_BIN" "$RELAY_CLI" claude-app

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME}/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
export RELAY_AI_HOME="${HOME}/.relay-ai"
export ANTIGRAVITY_API_KEY="antigravity"
export RELAY_AI_KEY_CUSTOM_ANTIGRAVITY="antigravity"

HEALTH_URL="http://127.0.0.1:8080/health"

fail() {
  printf "\nОшибка: %s\n" "$1" >&2
  if [ -t 0 ]; then
    printf "Нажмите Enter для закрытия..."
    read -r _
  fi
  exit 1
}

clear 2>/dev/null || true
printf '%s\n' \
  '╭─────────────────────────────────────────╮' \
  '│          ClaudeGravity Launcher         │' \
  '╰─────────────────────────────────────────╯'

command -v node >/dev/null 2>&1 || fail "Node.js не найден. Запустите установщик заново."
if command -v npm >/dev/null 2>&1; then
  printf "\nПроверяю обновления компонентов...\n"
  if ! npm install -g antigravity-claude-proxy@latest @jacobbd/relay-ai@latest --no-audit --no-fund; then
    printf "[!] Обновление не удалось; использую установленные версии.\n" >&2
  fi
fi
command -v acc >/dev/null 2>&1 || fail "Antigravity proxy не найден. Запустите установщик заново."
command -v relay-ai >/dev/null 2>&1 || fail "Relay AI не найден. Запустите установщик заново."

node "${SCRIPT_DIR}/configure-relay.mjs" "$RELAY_AI_HOME" || fail "Не удалось подготовить конфигурацию Relay AI."

provider_output="$(relay-ai providers list 2>&1 || true)"
if ! printf '%s' "$provider_output" | grep -Fq "custom-antigravity"; then
  fail "Relay AI не увидел провайдер Antigravity. ${provider_output}"
fi

account_output="$(acc accounts list 2>/dev/null || true)"
if ! printf '%s' "$account_output" | grep -Eq '[1-9][0-9]* account\(s\)'; then
  printf "\nАккаунт Google ещё не привязан. Привязать сейчас? [Y/n]: "
  read -r reply
  if [[ ! "${reply:-Y}" =~ ^[Yy]$ ]]; then
    fail "Для запуска необходимо привязать аккаунт Google."
  fi
  acc stop >/dev/null 2>&1 || true
  acc accounts add || fail "Не удалось привязать аккаунт Google."
fi

if ! curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
  printf "\nЗапускаю Antigravity proxy...\n"
  acc start || fail "Не удалось запустить Antigravity proxy."
  proxy_ready=false
  for _ in {1..10}; do
    if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
      proxy_ready=true
      break
    fi
    sleep 1
  done
  $proxy_ready || fail "Прокси не ответил на ${HEALTH_URL}."
fi

printf "\n✓ Прокси готов. Открываю Claude Desktop...\n"
printf "  Выберите Code и одну из моделей в нижнем меню.\n\n"
exec relay-ai claude-app

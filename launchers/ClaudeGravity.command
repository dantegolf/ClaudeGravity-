#!/bin/zsh

export PATH="$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

HEALTH_URL="http://127.0.0.1:8080/health"

fail() {
  printf "\nОшибка: %s\n" "$1"
  printf "Нажмите любую клавишу..."
  read -k 1
  exit 1
}

clear
printf "ClaudeGravity\n\n"

command -v relay-ai >/dev/null 2>&1 || fail "Relay AI не найден"

if ! curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
  printf "Запускаю Antigravity proxy...\n"
  acc start || fail "Не удалось запустить proxy"
fi

printf "Открываю Claude Desktop через Relay AI...\n\n"
relay-ai claude-app

printf "\nГотово. Нажмите любую клавишу..."
read -k 1

#!/bin/zsh

export PATH="$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

HEALTH_URL="http://127.0.0.1:8080/health"

clear
printf "=========================================\n"
printf "         ClaudeGravity Launcher          \n"
printf "=========================================\n\n"

command -v relay-ai >/dev/null 2>&1 || {
  printf "Ошибка: Relay AI не установлен. Выполните установку заново.\n"
  read -k 1; exit 1
}

# 1. Запуск прокси
if ! curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
  printf "Запускаю Antigravity proxy...\n"
  acc start || true
  sleep 2
fi

# 2. Проверка привязанных аккаунтов
HEALTH_DATA=$(curl -s "$HEALTH_URL" 2>/dev/null)
ACCOUNT_COUNT=$(echo "$HEALTH_DATA" | grep -o '"email":' | wc -l | tr -d ' ')

if [ "$ACCOUNT_COUNT" -eq 0 ]; then
  printf "\n[!] Не найдено привязанных аккаунтов Google/Antigravity.\n"
  read "add_acc?Привязать аккаунт прямо сейчас? [Y/n]: "
  add_acc=${add_acc:-Y}
  if [[ "$add_acc" =~ ^[Yy]$ ]]; then
    acc accounts add
  fi
fi

printf "\n[✓] Запускаю Claude Desktop через прокси...\n\n"
printf "Напоминание для Claude Desktop:\n"
printf " • Включите Developer Mode: Help -> Troubleshooting -> Enable Developer Mode\n"
printf " • Переключите режим на: Code\n"
printf " • Выберите модель: gemini-3.6-flash-high (Antigravity) 1M\n\n"

relay-ai claude-app

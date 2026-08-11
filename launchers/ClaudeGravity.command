#!/bin/zsh

export PATH="$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

HEALTH_URL="http://127.0.0.1:8080/health"

clear
printf "=========================================\n"
printf "         ClaudeGravity Launcher          \n"
printf "=========================================\n\n"

command -v relay-ai >/dev/null 2>&1 || {
  printf "Ошибка: Relay AI не установлен. Запустите установщик заново.\n"
  read -k 1; exit 1
}

# 1. Проверяем привязанные аккаунты Google
ACCOUNT_COUNT=$(acc accounts list 2>/dev/null | grep -o '[0-9]* account(s)' | awk '{print $1}')

if [ -z "$ACCOUNT_COUNT" ] || [ "$ACCOUNT_COUNT" -eq 0 ]; then
  printf "[!] Не найдено привязанных аккаунтов Google (Google AI / Antigravity).\n"
  read "add_acc?Привязать аккаунт Google прямо сейчас? [Y/n]: "
  add_acc=${add_acc:-Y}
  if [[ "$add_acc" =~ ^[Yy]$ ]]; then
    printf "\nОстанавливаю прокси для привязки аккаунта...\n"
    acc stop >/dev/null 2>&1 || true
    acc accounts add
  fi
fi

# 2. Запускаем прокси, если не запущен
if ! curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
  printf "\nЗапускаю Antigravity proxy...\n"
  acc start || true
  sleep 2
fi

printf "\n[✓] Запускаю Claude Desktop через прокси...\n\n"
printf "Напоминание для Claude Desktop:\n"
printf " • Включите Developer Mode: Help -> Troubleshooting -> Enable Developer Mode\n"
printf " • Переключите режим на: Code\n"
printf " • Выберите любую модель Google/Antigravity внизу окна\n\n"

relay-ai claude-app

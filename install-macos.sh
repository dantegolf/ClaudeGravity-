#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/Documents/ClaudeGravity"
NPM_PREFIX="${HOME}/.npm-global"

say() {
  printf "\n==> %s\n" "$1"
}

need_command() {
  command -v "$1" >/dev/null 2>&1
}

say "Установка ClaudeGravity для macOS"

if ! need_command node || ! need_command npm; then
  if need_command brew; then
    say "Устанавливаю Node.js..."
    brew install node
  else
    printf "\nТребуется Node.js.\n"
    printf "Установите Homebrew и Node.js, затем запустите снова:\n"
    printf "  /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/olegsuper338-lgtm/ClaudeGravity-/main/install-macos.sh)\"\n"
    exit 1
  fi
fi

say "Настройка окружения npm..."
npm config set prefix "$NPM_PREFIX" >/dev/null
export PATH="${NPM_PREFIX}/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"

ZSHRC="${HOME}/.zshrc"
PATH_LINE='export PATH="$HOME/.npm-global/bin:$PATH"'
if [ -f "$ZSHRC" ]; then
  if ! grep -Fq "$PATH_LINE" "$ZSHRC"; then
    printf "\n%s\n" "$PATH_LINE" >> "$ZSHRC"
  fi
else
  printf "%s\n" "$PATH_LINE" > "$ZSHRC"
fi

say "Установка прокси и реле..."
npm install -g antigravity-claude-proxy @jacobbd/relay-ai

say "Создаю ярлыки в папке ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"

cat > "${INSTALL_DIR}/ClaudeGravity.command" <<'EOF'
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
EOF

cat > "${INSTALL_DIR}/Check-Limits.command" <<'EOF'
#!/bin/zsh

export PATH="$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

clear
printf "=== Лимиты ClaudeGravity ===\n\n"

if command -v jq >/dev/null 2>&1; then
  curl -s http://127.0.0.1:8080/health | jq
else
  curl -s http://127.0.0.1:8080/health
fi

printf "\nНажмите любую клавишу..."
read -k 1
EOF

chmod +x "${INSTALL_DIR}/ClaudeGravity.command" "${INSTALL_DIR}/Check-Limits.command"
xattr -d com.apple.quarantine "${INSTALL_DIR}/ClaudeGravity.command" 2>/dev/null || true
xattr -d com.apple.quarantine "${INSTALL_DIR}/Check-Limits.command" 2>/dev/null || true

say "Установка завершена!"

exec "${INSTALL_DIR}/ClaudeGravity.command"

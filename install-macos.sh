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

say "Установка компонентов прокси и реле..."
npm install -g antigravity-claude-proxy @jacobbd/relay-ai

say "Создаю ярлыки в папке ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"

cat > "${INSTALL_DIR}/ClaudeGravity.command" <<'EOF'
#!/bin/zsh

export PATH="$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export ANTIGRAVITY_API_KEY="antigravity"

HEALTH_URL="http://127.0.0.1:8080/health"
RELAY_DIR="${HOME}/.relay-ai"
PROVIDERS_JSON="${RELAY_DIR}/providers.json"

clear
printf "=========================================\n"
printf "         ClaudeGravity Launcher          \n"
printf "=========================================\n\n"

command -v relay-ai >/dev/null 2>&1 || {
  printf "Ошибка: Relay AI не установлен. Запустите установщик заново.\n"
  read -k 1; exit 1
}

# 1. Проверяем регистрацию Antigravity провайдера в relay-ai
mkdir -p "$RELAY_DIR"
if [ ! -f "$PROVIDERS_JSON" ] || ! grep -q '"custom-antigravity"' "$PROVIDERS_JSON" 2>/dev/null; then
  cat > "$PROVIDERS_JSON" <<'EOP'
{
  "schemaVersion": 1,
  "providers": [
    {
      "id": "custom-antigravity",
      "templateId": "custom-anthropic",
      "name": "Antigravity",
      "enabled": true,
      "authRef": "env:ANTIGRAVITY_API_KEY",
      "api": {
        "npm": "@ai-sdk/anthropic",
        "url": "http://127.0.0.1:8080"
      },
      "modelsCache": {
        "fetchedAt": "2026-08-11T00:00:00.000Z",
        "models": [
          {
            "id": "gemini-3.6-flash-high",
            "name": "gemini-3.6-flash-high",
            "upstreamModelId": "gemini-3.6-flash-high",
            "family": "gemini",
            "brand": "Gemini",
            "contextWindow": 1000000,
            "modelFormat": "anthropic",
            "npm": "@ai-sdk/anthropic",
            "apiUrl": "http://127.0.0.1:8080"
          },
          {
            "id": "claude-sonnet-4-6",
            "name": "claude-sonnet-4-6",
            "upstreamModelId": "claude-sonnet-4-6",
            "family": "claude",
            "brand": "Claude",
            "contextWindow": 1000000,
            "modelFormat": "anthropic",
            "npm": "@ai-sdk/anthropic",
            "apiUrl": "http://127.0.0.1:8080"
          },
          {
            "id": "gemini-2.5-pro",
            "name": "gemini-2.5-pro",
            "upstreamModelId": "gemini-2.5-pro",
            "family": "gemini",
            "brand": "Gemini",
            "contextWindow": 2000000,
            "modelFormat": "anthropic",
            "npm": "@ai-sdk/anthropic",
            "apiUrl": "http://127.0.0.1:8080"
          }
        ]
      }
    }
  ]
}
EOP
fi

# 2. Проверяем привязанные аккаунты Google
ACCOUNT_COUNT=$(acc accounts list 2>/dev/null | grep -o '[0-9]* account(s)' | awk '{print $1}')

if [ -z "$ACCOUNT_COUNT" ] || [ "$ACCOUNT_COUNT" -eq 0 ]; then
  printf "[!] Не найдено привязанных аккаунтов Google (Google AI / Antigravity).\n"
  read "add_acc?Привязать аккаунт Google прямо сейчас? [Y/n]: "
  add_acc=${add_acc:-Y}
  if [[ "$add_acc" =~ ^[Yy]$ ]]; then
    printf "\nОстанавливаю прокси перед привязкой аккаунта...\n"
    acc stop >/dev/null 2>&1 || true
    acc accounts add
  fi
fi

# 3. Запускаем прокси, если не запущен
if ! curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
  printf "\nЗапускаю Antigravity proxy...\n"
  acc start || true
  sleep 2
fi

printf "\n[✓] Запускаю выбор модели и Claude Desktop...\n\n"
printf "Напоминание для Claude Desktop:\n"
printf " • Включите Developer Mode: Help -> Troubleshooting -> Enable Developer Mode\n"
printf " • Переключите режим на: Code\n\n"

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

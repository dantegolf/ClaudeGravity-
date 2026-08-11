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

# 1. Проверяем регистрацию Antigravity провайдера в relay-ai (гарантируем env:ANTIGRAVITY_API_KEY и cached models)
mkdir -p "$RELAY_DIR"
if [ ! -f "$PROVIDERS_JSON" ] || ! grep -q '"env:ANTIGRAVITY_API_KEY"' "$PROVIDERS_JSON" 2>/dev/null || ! grep -q '"gemini"' "$PROVIDERS_JSON" 2>/dev/null; then
  cat > "$PROVIDERS_JSON" <<'EOF'
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
EOF
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

# 4. Обновляем динамические модели
relay-ai providers refresh-models custom-antigravity >/dev/null 2>&1 || true

printf "\n[✓] Запускаю выбор модели и Claude Desktop...\n\n"
printf "Напоминание для Claude Desktop:\n"
printf " • Включите Developer Mode: Help -> Troubleshooting -> Enable Developer Mode\n"
printf " • Переключите режим на: Code\n\n"

relay-ai claude-app

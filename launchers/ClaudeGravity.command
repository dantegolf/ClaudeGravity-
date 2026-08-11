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

# 1. Гарантируем корректный providers.json с 19 моделями и валидными полями (addedAt, authRef)
mkdir -p "$RELAY_DIR"
if [ ! -f "$PROVIDERS_JSON" ] || ! grep -q '"addedAt"' "$PROVIDERS_JSON" 2>/dev/null || ! grep -q '"env:ANTIGRAVITY_API_KEY"' "$PROVIDERS_JSON" 2>/dev/null; then
  cat > "$PROVIDERS_JSON" <<'EOF'
{"schemaVersion":1,"providers":[{"id":"custom-antigravity","templateId":"custom-anthropic","name":"Antigravity","enabled":true,"authRef":"env:ANTIGRAVITY_API_KEY","addedAt":"2026-08-11T00:00:00.000Z","refreshedAt":"2026-08-11T00:00:00.000Z","api":{"npm":"@ai-sdk/anthropic","url":"http://127.0.0.1:8080"},"modelsCache":{"fetchedAt":"2026-08-11T00:00:00.000Z","models":[{"id":"gemini-3.6-flash-high","name":"gemini-3.6-flash-high","upstreamModelId":"gemini-3.6-flash-high","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"claude-sonnet-4-6","name":"claude-sonnet-4-6","upstreamModelId":"claude-sonnet-4-6","family":"claude","brand":"Claude","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-pro","name":"gemini-2.5-pro","upstreamModelId":"gemini-2.5-pro","family":"gemini","brand":"Gemini","contextWindow":2000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"claude-opus-4-6-thinking","name":"claude-opus-4-6-thinking","upstreamModelId":"claude-opus-4-6-thinking","family":"claude","brand":"Claude","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash","name":"gemini-2.5-flash","upstreamModelId":"gemini-2.5-flash","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash-lite","name":"gemini-2.5-flash-lite","upstreamModelId":"gemini-2.5-flash-lite","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash-thinking","name":"gemini-2.5-flash-thinking","upstreamModelId":"gemini-2.5-flash-thinking","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3-flash","name":"gemini-3-flash","upstreamModelId":"gemini-3-flash","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3-flash-agent","name":"gemini-3-flash-agent","upstreamModelId":"gemini-3-flash-agent","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-flash-image","name":"gemini-3.1-flash-image","upstreamModelId":"gemini-3.1-flash-image","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-flash-lite","name":"gemini-3.1-flash-lite","upstreamModelId":"gemini-3.1-flash-lite","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-pro-high","name":"gemini-3.1-pro-high","upstreamModelId":"gemini-3.1-pro-high","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-pro-low","name":"gemini-3.1-pro-low","upstreamModelId":"gemini-3.1-pro-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.5-flash-extra-low","name":"gemini-3.5-flash-extra-low","upstreamModelId":"gemini-3.5-flash-extra-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.5-flash-low","name":"gemini-3.5-flash-low","upstreamModelId":"gemini-3.5-flash-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-low","name":"gemini-3.6-flash-low","upstreamModelId":"gemini-3.6-flash-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-medium","name":"gemini-3.6-flash-medium","upstreamModelId":"gemini-3.6-flash-medium","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-tiered","name":"gemini-3.6-flash-tiered","upstreamModelId":"gemini-3.6-flash-tiered","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-pro-agent","name":"gemini-pro-agent","upstreamModelId":"gemini-pro-agent","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"}]}}]}
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

printf "\n[✓] Запускаю выбор модели и Claude Desktop...\n\n"
printf "Напоминание для Claude Desktop:\n"
printf " • Включите Developer Mode: Help -> Troubleshooting -> Enable Developer Mode\n"
printf " • Переключите режим на: Code\n\n"

relay-ai claude-app

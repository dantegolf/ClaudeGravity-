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

say "ClaudeGravity macOS installer"

if ! need_command node || ! need_command npm; then
  if need_command brew; then
    say "Installing Node.js with Homebrew"
    brew install node
  else
    printf "\nNode.js is required.\n"
    printf "Install Homebrew + Node.js, then run this installer again:\n"
    printf "  /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/olegsuper338-lgtm/ClaudeGravity-/main/install-macos.sh)\"\n"
    exit 1
  fi
fi

say "Preparing npm global path"
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

say "Installing Antigravity Claude Proxy and Relay AI"
npm install -g antigravity-claude-proxy @jacobbd/relay-ai

say "Creating launchers in ${INSTALL_DIR}"
mkdir -p "$INSTALL_DIR"

cat > "${INSTALL_DIR}/ClaudeGravity.command" <<'EOF'
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
EOF

cat > "${INSTALL_DIR}/ClaudeGravity-AccountAdd.command" <<'EOF'
#!/bin/zsh

export PATH="$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

clear
printf "ClaudeGravity - Привязка аккаунта\n\n"

if command -v acc >/dev/null 2>&1; then
  printf "Запускаю привязку Google/Antigravity аккаунта...\n\n"
  acc accounts add
else
  printf "Ошибка: утилита 'acc' (antigravity-claude-proxy) не найдена.\n"
  printf "Установите её командой: npm install -g antigravity-claude-proxy\n\n"
  printf "Нажмите любую клавишу..."
  read -k 1
  exit 1
fi

printf "\n--- Запуск ClaudeGravity ---\n"
read "reply?Хотите запустить ClaudeGravity прямо сейчас? [Y/n]: "
reply=${reply:-Y}

if [[ "$reply" =~ ^[Yy]$ ]]; then
  printf "\nНапоминание для Claude Desktop:\n"
  printf " 1. Меню Help -> Troubleshooting -> Enable Developer Mode\n"
  printf " 2. Переключите режим с 'Cowork' на 'Code'\n"
  printf " 3. Выберите модель: gemini-3.6-flash-high (Antigravity) 1M\n\n"
  exec "$(dirname "$0")/ClaudeGravity.command"
fi
EOF

cat > "${INSTALL_DIR}/ClaudeGravity-Limits.command" <<'EOF'
#!/bin/zsh

export PATH="$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

clear
printf "ClaudeGravity limits\n\n"

if command -v jq >/dev/null 2>&1; then
  curl -s http://127.0.0.1:8080/health | jq
else
  curl -s http://127.0.0.1:8080/health
fi

printf "\nНажмите любую клавишу..."
read -k 1
EOF

chmod +x "${INSTALL_DIR}/ClaudeGravity.command" "${INSTALL_DIR}/ClaudeGravity-AccountAdd.command" "${INSTALL_DIR}/ClaudeGravity-Limits.command"
xattr -d com.apple.quarantine "${INSTALL_DIR}/ClaudeGravity.command" 2>/dev/null || true
xattr -d com.apple.quarantine "${INSTALL_DIR}/ClaudeGravity-AccountAdd.command" 2>/dev/null || true
xattr -d com.apple.quarantine "${INSTALL_DIR}/ClaudeGravity-Limits.command" 2>/dev/null || true

say "Установка успешно завершена!"

exec "${INSTALL_DIR}/ClaudeGravity-AccountAdd.command"

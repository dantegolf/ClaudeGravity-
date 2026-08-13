#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/Documents/ClaudeGravity"
SCRIPTS_DIR="${INSTALL_DIR}/scripts"
NPM_PREFIX="${HOME}/.npm-global"
RAW_BASE="${CLAUDEGRAVITY_RAW_BASE:-https://raw.githubusercontent.com/olegsuper338-lgtm/ClaudeGravity-/main}"
PROXY_PACKAGE="antigravity-claude-proxy@2.8.5"
RELAY_PACKAGE="@jacobbd/relay-ai@0.9.0"

say() { printf "\n==> %s\n" "$1"; }
has() { command -v "$1" >/dev/null 2>&1; }

download() {
  local source="$1" destination="$2"
  curl -fsSL "${RAW_BASE}/${source}" -o "${destination}.tmp"
  mv "${destination}.tmp" "$destination"
}

say "Установка ClaudeGravity для macOS"

if ! has node || ! has npm; then
  if has brew; then
    say "Устанавливаю Node.js через Homebrew..."
    brew install node
  else
    printf "\nНужен Node.js 18+ и Homebrew. Установите их и повторите команду.\n"
    printf "https://nodejs.org/ · https://brew.sh/\n"
    exit 1
  fi
fi

node -e 'if (Number(process.versions.node.split(".")[0]) < 18) process.exit(1)' || {
  printf "Требуется Node.js 18 или новее.\n"
  exit 1
}

say "Устанавливаю закреплённые версии прокси и Relay AI..."
npm config set prefix "$NPM_PREFIX" >/dev/null
export PATH="${NPM_PREFIX}/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"
npm install -g "$PROXY_PACKAGE" "$RELAY_PACKAGE"

PATH_LINE='export PATH="$HOME/.npm-global/bin:$PATH"'
touch "${HOME}/.zshrc"
grep -Fqx "$PATH_LINE" "${HOME}/.zshrc" || printf "\n%s\n" "$PATH_LINE" >> "${HOME}/.zshrc"

say "Создаю запускатели в ${INSTALL_DIR}..."
mkdir -p "$SCRIPTS_DIR"
download "launchers/scripts/ClaudeGravity.sh" "${SCRIPTS_DIR}/ClaudeGravity.sh"
download "launchers/scripts/Check-Limits.sh" "${SCRIPTS_DIR}/Check-Limits.sh"
download "launchers/scripts/configure-relay.mjs" "${SCRIPTS_DIR}/configure-relay.mjs"
download "launchers/ClaudeGravity.command" "${INSTALL_DIR}/ClaudeGravity.command"
download "launchers/Check-Limits.command" "${INSTALL_DIR}/Check-Limits.command"

chmod +x "${INSTALL_DIR}/ClaudeGravity.command" "${INSTALL_DIR}/Check-Limits.command" "${SCRIPTS_DIR}"/*.sh "${SCRIPTS_DIR}"/*.mjs
xattr -dr com.apple.quarantine "$INSTALL_DIR" 2>/dev/null || true
bash -n "${SCRIPTS_DIR}/ClaudeGravity.sh" "${SCRIPTS_DIR}/Check-Limits.sh"
node --check "${SCRIPTS_DIR}/configure-relay.mjs"

say "Готово. Запускаю ClaudeGravity..."
[ "${CLAUDEGRAVITY_SKIP_LAUNCH:-0}" = "1" ] && exit 0
exec "${INSTALL_DIR}/ClaudeGravity.command"

#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/ClaudeGravity"
SCRIPTS_DIR="${INSTALL_DIR}/scripts"
NPM_PREFIX="${HOME}/.npm-global"
RAW_BASE="${CLAUDEGRAVITY_RAW_BASE:-https://raw.githubusercontent.com/olegsuper338-lgtm/ClaudeGravity-/main}"
PROXY_PACKAGE="antigravity-claude-proxy@latest"
RELAY_PACKAGE="@jacobbd/relay-ai@latest"

say() { printf "\n==> %s\n" "$1"; }
has() { command -v "$1" >/dev/null 2>&1; }

download() {
  local source="$1" destination="$2"
  curl -fsSL "${RAW_BASE}/${source}" -o "${destination}.tmp"
  mv "${destination}.tmp" "$destination"
}

install_system_packages() {
  local elevate=""
  if [ "$(id -u)" -ne 0 ]; then
    has sudo || { printf "Нужен sudo для установки Node.js и curl.\n"; exit 1; }
    elevate="sudo"
  fi

  if has apt-get; then
    $elevate apt-get update
    $elevate apt-get install -y nodejs npm curl
  elif has dnf; then
    $elevate dnf install -y nodejs npm curl
  elif has pacman; then
    $elevate pacman -Sy --needed --noconfirm nodejs npm curl
  elif has zypper; then
    $elevate zypper --non-interactive install nodejs npm curl
  else
    printf "Не найден поддерживаемый пакетный менеджер. Установите Node.js 18+, npm и curl вручную.\n"
    exit 1
  fi
}

say "Установка ClaudeGravity для Linux"

if ! has node || ! has npm || ! has curl; then
  say "Устанавливаю Node.js, npm и curl..."
  install_system_packages
fi

node -e 'if (Number(process.versions.node.split(".")[0]) < 18) process.exit(1)' || {
  printf "Требуется Node.js 18 или новее. Обновите Node.js и повторите установку.\n"
  exit 1
}

say "Устанавливаю актуальные версии прокси и Relay AI..."
npm config set prefix "$NPM_PREFIX" >/dev/null
export PATH="${NPM_PREFIX}/bin:/usr/local/bin:${PATH}"
npm install -g "$PROXY_PACKAGE" "$RELAY_PACKAGE"

PATH_LINE='export PATH="$HOME/.npm-global/bin:$PATH"'
touch "${HOME}/.profile"
grep -Fqx "$PATH_LINE" "${HOME}/.profile" || printf "\n%s\n" "$PATH_LINE" >> "${HOME}/.profile"

say "Создаю запускатели в ${INSTALL_DIR}..."
mkdir -p "$SCRIPTS_DIR" "${HOME}/.local/share/applications"
download "launchers/scripts/ClaudeGravity.sh" "${SCRIPTS_DIR}/ClaudeGravity.sh"
download "launchers/scripts/Check-Limits.sh" "${SCRIPTS_DIR}/Check-Limits.sh"
download "launchers/scripts/configure-relay.mjs" "${SCRIPTS_DIR}/configure-relay.mjs"
download "launchers/ClaudeGravity.sh" "${INSTALL_DIR}/ClaudeGravity.sh"
download "launchers/Check-Limits.sh" "${INSTALL_DIR}/Check-Limits.sh"

chmod +x "${INSTALL_DIR}"/*.sh "${SCRIPTS_DIR}"/*.sh "${SCRIPTS_DIR}"/*.mjs
bash -n "${SCRIPTS_DIR}/ClaudeGravity.sh" "${SCRIPTS_DIR}/Check-Limits.sh"
node --check "${SCRIPTS_DIR}/configure-relay.mjs"

cat > "${HOME}/.local/share/applications/claudegravity.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ClaudeGravity
Comment=Claude Desktop with Google Antigravity models
Exec=${INSTALL_DIR}/ClaudeGravity.sh
Terminal=true
Categories=Development;Utility;
EOF

say "Готово. Запускаю ClaudeGravity..."
[ "${CLAUDEGRAVITY_SKIP_LAUNCH:-0}" = "1" ] && exit 0
exec "${INSTALL_DIR}/ClaudeGravity.sh"

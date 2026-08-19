#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/ClaudeGravity"
RELEASE_BASE="${CLAUDEGRAVITY_RELEASE_BASE:-https://github.com/dantegolf/ClaudeGravity-/releases/latest/download}"
BUNDLE_URL="${CLAUDEGRAVITY_BUNDLE_URL:-${RELEASE_BASE}/ClaudeGravity-runtime.tar.gz}"

say() { printf '\n==> %s\n' "$1"; }
has() { command -v "$1" >/dev/null 2>&1; }

install_node() {
  local elevate=""
  if [ "$(id -u)" -ne 0 ]; then
    has sudo || { printf 'Нужен sudo для установки Node.js и curl.\n' >&2; exit 1; }
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
    printf 'Установите Node.js 18+ и curl вручную.\n' >&2
    exit 1
  fi
}

say "Установка ClaudeGravity bundled runtime для Linux"
if ! has node || ! has curl; then
  say "Устанавливаю Node.js и curl..."
  install_node
fi
node -e 'if (Number(process.versions.node.split(".")[0]) < 18) process.exit(1)' || {
  printf 'Требуется Node.js 18 или новее.\n' >&2
  exit 1
}

say "Скачиваю проверенный ClaudeGravity runtime из нашего GitHub Release..."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$BUNDLE_URL" -o "$tmp/runtime.tar.gz"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$tmp/runtime.tar.gz" -C "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/ClaudeGravity.sh" "$INSTALL_DIR/Check-Limits.sh"

for required in ClaudeGravity.sh runtime scripts manifest.json; do
  [ -e "$INSTALL_DIR/$required" ] || { printf 'Runtime archive неполон: %s\n' "$required" >&2; exit 1; }
done

mkdir -p "${HOME}/.local/share/applications"
cat > "${HOME}/.local/share/applications/claudegravity.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ClaudeGravity
Comment=Claude Desktop with bundled ClaudeGravity runtime
Exec=${INSTALL_DIR}/ClaudeGravity.sh
Terminal=true
Categories=Development;Utility;
EOF

say "Готово: $INSTALL_DIR"
[ "${CLAUDEGRAVITY_SKIP_LAUNCH:-0}" = "1" ] && exit 0
exec "$INSTALL_DIR/ClaudeGravity.sh"

#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/Documents/ClaudeGravity"
RELEASE_BASE="${CLAUDEGRAVITY_RELEASE_BASE:-https://github.com/dantegolf/ClaudeGravity-/releases/latest/download}"
BUNDLE_URL="${CLAUDEGRAVITY_BUNDLE_URL:-${RELEASE_BASE}/ClaudeGravity-runtime.tar.gz}"

say() { printf '\n==> %s\n' "$1"; }
has() { command -v "$1" >/dev/null 2>&1; }

say "Установка ClaudeGravity bundled runtime для macOS"

if ! has node; then
  if has brew; then
    say "Устанавливаю Node.js через Homebrew..."
    brew install node
  else
    printf 'Требуется Node.js 18+. Установите Node.js/Homebrew и повторите установку.\n' >&2
    exit 1
  fi
fi
node -e 'if (Number(process.versions.node.split(".")[0]) < 18) process.exit(1)' || {
  printf 'Требуется Node.js 18 или новее.\n' >&2
  exit 1
}
has curl || { printf 'Требуется curl.\n' >&2; exit 1; }

say "Скачиваю проверенный ClaudeGravity runtime из нашего GitHub Release..."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$BUNDLE_URL" -o "$tmp/runtime.tar.gz"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$tmp/runtime.tar.gz" -C "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/ClaudeGravity.sh" "$INSTALL_DIR/Check-Limits.sh"
xattr -dr com.apple.quarantine "$INSTALL_DIR" 2>/dev/null || true

for required in ClaudeGravity.sh runtime scripts manifest.json; do
  [ -e "$INSTALL_DIR/$required" ] || { printf 'Runtime archive неполон: %s\n' "$required" >&2; exit 1; }
done

say "Готово: $INSTALL_DIR"
[ "${CLAUDEGRAVITY_SKIP_LAUNCH:-0}" = "1" ] && exit 0
exec "$INSTALL_DIR/ClaudeGravity.sh"

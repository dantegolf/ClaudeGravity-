#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" == "Darwin" ]]; then
  INSTALL_DIR="${HOME}/Documents/ClaudeGravity"
else
  INSTALL_DIR="${HOME}/ClaudeGravity"
fi
SCRIPTS_DIR="${INSTALL_DIR}/scripts"
RAW_BASE="${CLAUDEGRAVITY_RAW_BASE:-https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main}"

command -v node >/dev/null 2>&1 || { echo "Node.js не найден. Сначала установите ClaudeGravity." >&2; exit 1; }
[[ -f "${SCRIPTS_DIR}/supervisor.mjs" ]] || { echo "Основной ClaudeGravity runtime не найден в ${INSTALL_DIR}. Сначала установите ClaudeGravity." >&2; exit 1; }

mkdir -p "$SCRIPTS_DIR"
curl -fsSL "$RAW_BASE/launchers/scripts/cg-agent.mjs" -o "$SCRIPTS_DIR/cg-agent.mjs"
curl -fsSL "$RAW_BASE/launchers/scripts/cg-delegate.mjs" -o "$SCRIPTS_DIR/cg-delegate.mjs"
curl -fsSL "$RAW_BASE/launchers/scripts/install-codex-integration.mjs" -o "$SCRIPTS_DIR/install-codex-integration.mjs"
curl -fsSL "$RAW_BASE/launchers/CG-Agent.sh" -o "$INSTALL_DIR/CG-Agent.sh"
curl -fsSL "$RAW_BASE/launchers/CG-Delegate.sh" -o "$INSTALL_DIR/CG-Delegate.sh"
curl -fsSL "$RAW_BASE/launchers/CD-Delegate.sh" -o "$INSTALL_DIR/CD-Delegate.sh"
chmod +x \
  "$INSTALL_DIR/CG-Agent.sh" \
  "$INSTALL_DIR/CG-Delegate.sh" \
  "$INSTALL_DIR/CD-Delegate.sh" \
  "$SCRIPTS_DIR/cg-agent.mjs" \
  "$SCRIPTS_DIR/cg-delegate.mjs" \
  "$SCRIPTS_DIR/install-codex-integration.mjs"
node --check "$SCRIPTS_DIR/cg-agent.mjs"
node --check "$SCRIPTS_DIR/cg-delegate.mjs"
node --check "$SCRIPTS_DIR/install-codex-integration.mjs"
node "$SCRIPTS_DIR/install-codex-integration.mjs" \
  --raw-base "$RAW_BASE" \
  --delegate-launcher "$INSTALL_DIR/CG-Delegate.sh"

echo
echo "CG-Agent установлен: $INSTALL_DIR/CG-Agent.sh"
echo "Codex delegate установлен: $INSTALL_DIR/CG-Delegate.sh"
echo "Алиас: $INSTALL_DIR/CD-Delegate.sh"
echo "Перед использованием запустите ClaudeGravity и дождитесь READY в WebUI."
echo "Пример worker-вызова:"
echo "  $INSTALL_DIR/CG-Agent.sh --repo /path/to/project --task 'Реализуй задачу'"
echo "Пример supervisor-вызова:"
echo "  $HOME/.claudegravity/bin/cg-delegate --repo /path/to/project --task 'Реализуй задачу'"

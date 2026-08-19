#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n \
  "${ROOT}/install-macos.sh" \
  "${ROOT}/install-linux.sh" \
  "${ROOT}/distribution/runtime/ClaudeGravity.sh" \
  "${ROOT}/distribution/runtime/Check-Limits.sh"

node --check "${ROOT}/distribution/build-runtime.mjs"
node --check "${ROOT}/launchers/scripts/configure-relay.mjs"
node --check "${ROOT}/launchers/scripts/patch-antigravity-proxy.mjs"
node "${ROOT}/tests/proxy-compat.mjs"
node "${ROOT}/tests/distribution.mjs"

TEMP_RELAY_HOME="$(mktemp -d)"
trap 'rm -rf "$TEMP_RELAY_HOME"' EXIT
cat > "${TEMP_RELAY_HOME}/providers.json" <<'EOF'
{"schemaVersion":1,"providers":[{"id":"keep-me","name":"Existing"}]}
EOF
cat > "${TEMP_RELAY_HOME}/config.json" <<'EOF'
{"theme":"dark","claudeGravityFavoritesVersion":1,"favoriteModels":[{"providerId":"keep-me","modelId":"existing"}]}
EOF
node "${ROOT}/launchers/scripts/configure-relay.mjs" "$TEMP_RELAY_HOME" >/dev/null
node --input-type=module - "$TEMP_RELAY_HOME" <<'EOF'
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
const home = process.argv[2];
const providers = JSON.parse(readFileSync(join(home, 'providers.json'), 'utf8'));
const config = JSON.parse(readFileSync(join(home, 'config.json'), 'utf8'));
const provider = providers.providers.find((entry) => entry.id === 'custom-antigravity');
if (!providers.providers.some((entry) => entry.id === 'keep-me')) throw new Error('Existing provider was removed');
if (provider?.modelsCache?.models?.length !== 22) throw new Error('Expected 22 Antigravity models');
if (config.theme !== 'dark') throw new Error('Existing Relay preference was removed');
if (config.claudeGravityFavoritesVersion !== 2) throw new Error('Expected favorites preset version 2');
EOF

printf 'Unix distribution checks passed.\n'

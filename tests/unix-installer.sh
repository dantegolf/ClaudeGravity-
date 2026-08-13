#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n \
  "${ROOT}/install-macos.sh" \
  "${ROOT}/install-linux.sh" \
  "${ROOT}/launchers/ClaudeGravity.command" \
  "${ROOT}/launchers/Check-Limits.command" \
  "${ROOT}/launchers/ClaudeGravity.sh" \
  "${ROOT}/launchers/Check-Limits.sh" \
  "${ROOT}/launchers/scripts/ClaudeGravity.sh" \
  "${ROOT}/launchers/scripts/Check-Limits.sh"
node --check "${ROOT}/launchers/scripts/configure-relay.mjs"
node --check "${ROOT}/launchers/scripts/patch-antigravity-proxy.mjs"
node "${ROOT}/tests/proxy-compat.mjs"

for installer in "${ROOT}/install-macos.sh" "${ROOT}/install-linux.sh"; do
  grep -Fq 'antigravity-claude-proxy@latest' "$installer"
  grep -Fq '@jacobbd/relay-ai@latest' "$installer"
  grep -Fq 'launchers/scripts/configure-relay.mjs' "$installer"
  grep -Fq 'launchers/scripts/patch-antigravity-proxy.mjs' "$installer"
done

grep -Fq 'npm install -g antigravity-claude-proxy@latest @jacobbd/relay-ai@latest' \
  "${ROOT}/launchers/scripts/ClaudeGravity.sh"
grep -Fq 'patch-antigravity-proxy.mjs' "${ROOT}/launchers/scripts/ClaudeGravity.sh"

run_installer() {
  local installer="$1" expected_launcher="$2"
  local test_home fake_bin
  test_home="$(mktemp -d)"
  fake_bin="${test_home}/.npm-global/bin"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${fake_bin}/npm"
  chmod +x "${fake_bin}/npm"

  HOME="$test_home" \
    PATH="${fake_bin}:${PATH}" \
    CLAUDEGRAVITY_RAW_BASE="file://${ROOT}" \
    CLAUDEGRAVITY_SKIP_LAUNCH=1 \
    bash "${ROOT}/${installer}" >/dev/null

  test -x "${test_home}/${expected_launcher}"
  if [ "$installer" = "install-linux.sh" ]; then
    test -f "${test_home}/.local/share/applications/claudegravity.desktop"
  fi
  rm -rf "$test_home"
}

run_installer "install-macos.sh" "Documents/ClaudeGravity/ClaudeGravity.command"
run_installer "install-linux.sh" "ClaudeGravity/ClaudeGravity.sh"

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
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const home = process.argv[2];
const read = (name) => JSON.parse(readFileSync(join(home, name), "utf8"));
const registry = read("providers.json");
const provider = registry.providers.find((entry) => entry.id === "custom-antigravity");
if (!registry.providers.some((entry) => entry.id === "keep-me")) throw new Error("Existing provider was removed");
if (provider?.modelsCache?.models?.length !== 22) throw new Error("Expected 22 Antigravity models");
for (const id of ["gemini-3.7-flash-low", "gemini-3.7-flash-medium", "gemini-3.7-flash-high"]) {
  if (!provider.modelsCache.models.some((model) => model.id === id)) throw new Error(`Missing ${id}`);
}

const config = read("config.json");
if (config.theme !== "dark") throw new Error("Existing preference was removed");
if (config.favoriteModels.length !== 6) throw new Error("Expected existing favorite plus five defaults");
if (config.claudeGravityFavoritesVersion !== 2) throw new Error("Expected favorites preset version 2");
if (!config.favoriteModels.some((favorite) => favorite.modelId === "gemini-3.7-flash-high")) {
  throw new Error("Expected Gemini 3.7 Flash High in default favorites");
}

config.favoriteModels = config.favoriteModels.filter((favorite) => favorite.modelId !== "gemini-2.5-pro");
writeFileSync(join(home, "config.json"), JSON.stringify(config));
EOF

node "${ROOT}/launchers/scripts/configure-relay.mjs" "$TEMP_RELAY_HOME" >/dev/null

node --input-type=module - "$TEMP_RELAY_HOME" <<'EOF'
import { readFileSync } from "node:fs";
import { join } from "node:path";
const config = JSON.parse(readFileSync(join(process.argv[2], "config.json"), "utf8"));
if (config.favoriteModels.some((favorite) => favorite.modelId === "gemini-2.5-pro")) {
  throw new Error("A user-removed favorite was restored");
}
EOF

printf 'Unix installer checks passed.\n'

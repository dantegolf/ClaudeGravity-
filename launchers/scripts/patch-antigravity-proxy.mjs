#!/usr/bin/env node

import { chmod, readFile, rename, stat, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";

const proxyRoot = process.argv[2] ? resolve(process.argv[2]) : null;
if (!proxyRoot) {
  throw new Error("Usage: patch-antigravity-proxy.mjs <antigravity-claude-proxy directory>");
}

const files = new Map();
let changed = false;
const load = async (name) => {
  if (!files.has(name)) files.set(name, await readFile(join(proxyRoot, name), "utf8"));
  return files.get(name);
};

const replaceExact = async (name, before, after, alreadyAppliedMarker = null) => {
  const source = await load(name);
  if (after && source.includes(after)) return;
  const occurrences = source.split(before).length - 1;
  if (occurrences === 1) {
    files.set(name, source.replace(before, after));
    changed = true;
    return;
  }
  if (occurrences === 0 && ((after && source.includes(after)) ||
      (alreadyAppliedMarker && source.includes(alreadyAppliedMarker)))) return;
  throw new Error(`${name}: expected one compatible source block, found ${occurrences}`);
};

const SMART_DNS_MARKER = "ClaudeGravity selective Smart DNS v2";
const WEBUI_MARKER = "ClaudeGravity WebUI v1";

const patchSmartDns = async () => {
  const name = "src/utils/helpers.js";
  const source = await load(name);
  if (source.includes(SMART_DNS_MARKER)) return false;

  const configImport = "import { config } from '../config.js';";
  let updated = source;
  if (source.includes('ClaudeGravity selective Smart DNS v1')) {
    const start = source.indexOf("\nimport { Agent, fetch as undiciFetch } from 'undici';");
    const dispatcherStart = source.indexOf('function claudeGravitySmartDnsDispatcher(');
    const end = source.indexOf("\n}\n", dispatcherStart) + 3;
    const legacyFetch = `    const dispatcher = claudeGravitySmartDnsDispatcher(url, options);
    return dispatcher
        ? undiciFetch(url, { ...options, dispatcher })
        : fetch(url, options);`;
    if (start < 0 || dispatcherStart < start || end <= dispatcherStart || source.split(legacyFetch).length !== 2) {
      throw new Error(`${name}: incompatible legacy Smart DNS patch`);
    }
    updated = source.slice(0, start) + source.slice(end);
    updated = updated.replace(legacyFetch, '    return fetch(url, options);');
  }
  const fetchCall = "    return fetch(url, options);";
  if (updated.split(configImport).length !== 2 || updated.split(fetchCall).length !== 2) {
    throw new Error(`${name}: expected one config import and throttled fetch call for Smart DNS patch`);
  }
  const runtime = await readFile(new URL('./smart-dns.mjs', import.meta.url), 'utf8');
  updated = updated.replace(fetchCall, '    return claudeGravityFetch(url, options);');
  updated = updated.replace(configImport, `${configImport}\n${runtime}`);
  files.set(name, updated);
  changed = true;
  return true;
};

const patchWebUi = async () => {
  const indexName = "public/index.html";
  let index = await load(indexName);
  let webUiChanged = false;

  if (!index.includes(WEBUI_MARKER)) {
    const required = [
      '<title>Antigravity Console</title>',
      'selection:bg-neon-purple',
      'from-neon-purple to-blue-600',
      'x-text="$store.global.t(\'systemName\')">ANTIGRAVITY</span>',
      'x-text="$store.global.t(\'systemDesc\')">CLAUDE PROXY SYSTEM</span>',
      '            <!-- Refresh Button -->',
      '    <!-- 2. Alpine Stores (register alpine:init listeners) -->',
    ];
    for (const token of required) {
      if (index.split(token).length - 1 !== 1) {
        throw new Error(`${indexName}: expected one WebUI branding anchor: ${token}`);
      }
    }

    index = index
      .replace('<title>Antigravity Console</title>', '<title>ClaudeGravity</title>')
      .replace('selection:bg-neon-purple', 'selection:bg-neon-cyan')
      .replace('from-neon-purple to-blue-600', 'from-cyan-400 to-violet-600')
      .replace('shadow-[0_0_15px_rgba(168,85,247,0.4)]">\n                AG</div>', 'shadow-[0_0_15px_rgba(34,211,238,0.35)]">\n                CG</div>')
      .replace('x-text="$store.global.t(\'systemName\')">ANTIGRAVITY</span>', 'x-text="$store.global.t(\'systemName\')">ClaudeGravity</span>')
      .replace('x-text="$store.global.t(\'systemDesc\')">CLAUDE PROXY SYSTEM</span>', 'x-text="$store.global.t(\'systemDesc\')">LOCAL AI GATEWAY</span>');

    const controlMarkup = `            <!-- ${WEBUI_MARKER}: supervisor controls -->
            <div class="hidden md:flex items-center gap-2">
                <div class="flex items-center gap-2 px-2.5 py-1 rounded-full text-[11px] font-mono border border-cyan-400/20 bg-cyan-400/5 text-gray-400">
                    <span>GATEWAY</span>
                    <span id="claudegravity-gateway-status" class="font-bold text-yellow-400">STARTING</span>
                </div>
                <button type="button" class="btn btn-xs border-cyan-400/20 bg-cyan-400/10 text-cyan-300 hover:bg-cyan-400/20" onclick="window.ClaudeGravity.openClaude()">Open Claude</button>
                <button type="button" class="btn btn-xs btn-ghost text-gray-400 hover:text-white" onclick="window.ClaudeGravity.restart()">Restart</button>
                <button type="button" class="btn btn-xs btn-ghost text-red-400 hover:bg-red-500/10" onclick="window.ClaudeGravity.stop()">Stop</button>
            </div>

            <!-- Refresh Button -->`;
    index = index.replace('            <!-- Refresh Button -->', controlMarkup);

    const controlScript = `    <script>
      // ${WEBUI_MARKER}
      (() => {
        const controlUrl = 'http://127.0.0.1:17646';
        window.CLAUDEGRAVITY_CONTROL_URL = controlUrl;
        for (const dictionary of Object.values(window.translations || {})) {
          dictionary.systemName = 'ClaudeGravity';
          dictionary.systemDesc = 'LOCAL AI GATEWAY';
        }

        async function action(name) {
          const response = await fetch(\`${'${controlUrl}'}/action/\${name}\`, { method: 'POST' });
          if (!response.ok) throw new Error(\`ClaudeGravity action failed: \${name}\`);
          return response.json();
        }

        window.ClaudeGravity = {
          openClaude: () => action('open-claude').catch(console.error),
          restart: () => action('restart').catch(console.error),
          stop: () => {
            if (window.confirm('Stop ClaudeGravity and restore Claude Desktop settings?')) {
              action('stop').catch(console.error);
            }
          },
        };

        async function refreshGatewayStatus() {
          const label = document.getElementById('claudegravity-gateway-status');
          if (!label) return;
          try {
            const response = await fetch(\`${'${controlUrl}'}/health\`, { cache: 'no-store' });
            const status = await response.json();
            if (status.ready) {
              label.textContent = 'READY';
              label.className = 'font-bold text-emerald-400';
            } else if (status.proxyReady || status.gatewayReady) {
              label.textContent = 'STARTING';
              label.className = 'font-bold text-yellow-400';
            } else {
              label.textContent = 'OFFLINE';
              label.className = 'font-bold text-red-400';
            }
          } catch {
            label.textContent = 'OFFLINE';
            label.className = 'font-bold text-red-400';
          }
        }

        document.addEventListener('DOMContentLoaded', () => {
          refreshGatewayStatus();
          window.setInterval(refreshGatewayStatus, 2500);
        });
      })();
    </script>
    <!-- 2. Alpine Stores (register alpine:init listeners) -->`;
    index = index.replace('    <!-- 2. Alpine Stores (register alpine:init listeners) -->', controlScript);
    files.set(indexName, index);
    changed = true;
    webUiChanged = true;
  }

  const logsName = "public/js/components/logs-viewer.js";
  let logs = await load(logsName);
  if (!logs.includes('window.CLAUDEGRAVITY_CONTROL_URL')) {
    const before = `        const password = Alpine.store('global').webuiPassword;
        const url = password
            ? \`/api/logs/stream?history=true&password=\${encodeURIComponent(password)}\`
            : '/api/logs/stream?history=true';`;
    const after = `        // ClaudeGravity streams both Antigravity and Relay output from the
        // background supervisor instead of dumping child stdout/stderr to a terminal.
        const controlUrl = window.CLAUDEGRAVITY_CONTROL_URL || 'http://127.0.0.1:17646';
        const url = \`\${controlUrl}/logs/stream?history=true\`;`;
    if (logs.split(before).length - 1 !== 1) {
      throw new Error(`${logsName}: expected one upstream log-stream block`);
    }
    logs = logs.replace(before, after);
    files.set(logsName, logs);
    changed = true;
    webUiChanged = true;
  }

  return webUiChanged;
};

const writeChanges = async () => {
  if (!changed) return;
  for (const [name, content] of files) {
    if (name === "package.json") continue;
    const path = join(proxyRoot, name);
    const temporaryPath = `${path}.claudegravity.tmp`;
    const mode = (await stat(path)).mode;
    await writeFile(temporaryPath, content, "utf8");
    await chmod(temporaryPath, mode);
    await rename(temporaryPath, path);
  }
};

const packageJson = JSON.parse(await load("package.json"));
const constants = await load("src/constants.js");
const requestBuilder = await load("src/cloudcode/request-builder.js");
const modelApi = await load("src/cloudcode/model-api.js");
const smartDnsChanged = await patchSmartDns();
const webUiChanged = await patchWebUi();

const hasNative28Protocol =
  constants.includes("antigravity/hub/") &&
  /ideType:\s*['\"]ANTIGRAVITY['\"]/.test(constants) &&
  !constants.includes("'X-Client-Name'") &&
  !modelApi.includes("mode: 1") &&
  requestBuilder.includes("requestId: `agent/");

if (hasNative28Protocol && !constants.includes("ClaudeGravity Antigravity 2.8 compatibility")) {
  await writeChanges();
  console.log(`antigravity-claude-proxy ${packageJson.version} already supports the Antigravity 2.8 protocol.`);
  console.log(smartDnsChanged
    ? "Applied ClaudeGravity selective Smart DNS routing."
    : "ClaudeGravity selective Smart DNS routing is already applied.");
  console.log(webUiChanged
    ? "Applied ClaudeGravity WebUI branding and background log bridge."
    : "ClaudeGravity WebUI branding is already applied.");
  process.exit(0);
}

await replaceExact(
  "src/utils/version-detector.js",
  "const FALLBACK_USER_AGENT_VERSION = process.env.FALLBACK_ANTIGRAVITY_VERSION || '2.0.3';",
  "const FALLBACK_USER_AGENT_VERSION = process.env.FALLBACK_ANTIGRAVITY_VERSION || '2.8.0';"
);

await replaceExact(
  "src/constants.js",
  "import { generateSmartUserAgent, getClientVersion } from './utils/version-detector.js';",
  "import { generateSmartUserAgent } from './utils/version-detector.js';"
);

await replaceExact(
  "src/constants.js",
  `export function getPlatformUserAgent() {
    return generateSmartUserAgent();
}`,
  `export function getPlatformUserAgent() {
    // ClaudeGravity Antigravity 2.8 compatibility: match the official hub client.
    const version = generateSmartUserAgent().match(/^antigravity\\/([^ ]+)/)?.[1] || '2.8.0';
    const osType = platform() === 'win32' ? 'windows' : platform();
    const architecture = arch() === 'x64' ? 'amd64' : arch();
    const changelist = process.env.ANTIGRAVITY_CHANGE_LIST || '963137146';
    return \`antigravity/hub/\${version} (aidev_client; os_type=\${osType}; arch=\${architecture}; cl=\${changelist})\`;
}`
);

await replaceExact(
  "src/constants.js",
  `export const CLIENT_METADATA = {
    ideType: IDE_TYPE.ANTIGRAVITY,   // 6 - identifies as Antigravity client
    platform: getPlatformEnum(),      // Runtime platform detection
    pluginType: PLUGIN_TYPE.GEMINI    // 2
};`,
  `export const CLIENT_METADATA = {
    ideType: 'ANTIGRAVITY'
};`
);

await replaceExact(
  "src/constants.js",
  `export const ANTIGRAVITY_HEADERS = {
    'User-Agent': getPlatformUserAgent(),
    'Content-Type': 'application/json',
    'X-Client-Name': 'antigravity',
    'X-Client-Version': getClientVersion(),
    'x-goog-api-client': 'gl-node/18.18.2 fire/0.8.6 grpc/1.10.x' // Simulate Google Node.js client environment
};`,
  `export const ANTIGRAVITY_HEADERS = {
    'User-Agent': getPlatformUserAgent(),
    'Content-Type': 'application/json'
};`
);

await replaceExact(
  "src/cloudcode/model-api.js",
  `                body: JSON.stringify({
                    metadata: CLIENT_METADATA,
                    mode: 1
                })`,
  `                body: JSON.stringify({
                    metadata: CLIENT_METADATA
                })`
);

await replaceExact(
  "src/account-manager/credentials.js",
  "                body: JSON.stringify({ metadata, mode: 1 })",
  "                body: JSON.stringify({ metadata })"
);

await replaceExact(
  "src/cloudcode/request-builder.js",
  "    googleRequest.sessionId = deriveSessionId(anthropicRequest, accountEmail);",
  `    googleRequest.sessionId = deriveSessionId(anthropicRequest, accountEmail);

    const conversationId = crypto.randomUUID();
    const trajectoryId = crypto.randomUUID();
    const stepIndex = '0';
    const modelFamily = getModelFamily(model);
    googleRequest.labels = {
        ...googleRequest.labels,
        last_step_index: stepIndex,
        request_id: \`\${trajectoryId}-\${stepIndex}\`,
        trajectory_id: trajectoryId,
        used_claude: String(modelFamily === 'claude'),
        used_claude_conservative: 'false',
        used_non_gemini_model: String(modelFamily !== 'gemini')
    };`
);

await replaceExact(
  "src/cloudcode/request-builder.js",
  "        requestId: 'agent-' + crypto.randomUUID()",
  "        requestId: `agent/${conversationId}/${Date.now()}/${trajectoryId}/1`"
);

await replaceExact(
  "src/cloudcode/request-builder.js",
  `    // Add session ID header if provided (matches Antigravity binary behavior)
    if (sessionId) {
        headers['X-Machine-Session-Id'] = sessionId;
    }

`,
  "",
  "requestId: `agent/${conversationId}"
);

await replaceExact(
  "src/format/request-converter.js",
  `        // For Claude models, set functionCallingConfig.mode = "VALIDATED"
        // This ensures strict parameter validation (matches opencode-antigravity-auth)
        if (isClaudeModel) {
            googleRequest.toolConfig = {
                functionCallingConfig: {
                    mode: 'VALIDATED'
                }
            };
        }`,
  `        // Antigravity 2.8 sends VALIDATED tool calls for Gemini and Claude.
        googleRequest.toolConfig = {
            functionCallingConfig: {
                mode: 'VALIDATED'
            }
        };`
);

await replaceExact(
  "src/format/request-converter.js",
  `    // Cap max tokens for Gemini models
    if (isGeminiModel && googleRequest.generationConfig.maxOutputTokens > GEMINI_MAX_OUTPUT_TOKENS) {
        logger.debug(\`[RequestConverter] Capping Gemini max_tokens from \${googleRequest.generationConfig.maxOutputTokens} to \${GEMINI_MAX_OUTPUT_TOKENS}\`);
        googleRequest.generationConfig.maxOutputTokens = GEMINI_MAX_OUTPUT_TOKENS;
    }`,
  `    // Gemini 3.7 advertises a 65,536-token output limit in Antigravity 2.8.
    const geminiMaxOutputTokens = /^gemini-3\\.7(?:-|$)/i.test(modelName) ? 65536 : GEMINI_MAX_OUTPUT_TOKENS;
    if (isGeminiModel && googleRequest.generationConfig.maxOutputTokens > geminiMaxOutputTokens) {
        logger.debug(\`[RequestConverter] Capping Gemini max_tokens from \${googleRequest.generationConfig.maxOutputTokens} to \${geminiMaxOutputTokens}\`);
        googleRequest.generationConfig.maxOutputTokens = geminiMaxOutputTokens;
    }`
);

await replaceExact(
  "src/format/thinking-utils.js",
  `    const requestedBudget = budget || GEMINI_DEFAULT_THINKING_BUDGET;
    const lower = (modelName || '').toLowerCase();`,
  `    const lower = (modelName || '').toLowerCase();
    const requestedBudget = budget || (lower.includes('gemini-3.7-flash-medium') ? 4000 : GEMINI_DEFAULT_THINKING_BUDGET);`
);

await writeChanges();

console.log(changed
  ? `Applied Antigravity 2.8 compatibility to antigravity-claude-proxy ${packageJson.version}.`
  : `Antigravity 2.8 compatibility is already applied to antigravity-claude-proxy ${packageJson.version}.`);

console.log(smartDnsChanged
  ? "Applied ClaudeGravity selective Smart DNS routing."
  : "ClaudeGravity selective Smart DNS routing is already applied.");
console.log(webUiChanged
  ? "Applied ClaudeGravity WebUI branding and background log bridge."
  : "ClaudeGravity WebUI branding is already applied.");

import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const root = resolve(import.meta.dirname, "..");
const patchScript = join(root, "launchers/scripts/patch-antigravity-proxy.mjs");
const fixture = await mkdtemp(join(tmpdir(), "claudegravity-proxy-"));

const helpersSource = `
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import path from 'path';
import { config } from '../config.js';

export function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

export async function throttledFetch(url, options) {
    if (config.requestThrottlingEnabled) {
        const delayMs = config.requestDelayMs || 200;
        if (delayMs > 0) {
            await sleep(delayMs);
        }
    }
    return fetch(url, options);
}
`;

const indexHtmlSource = `<!DOCTYPE html>
<html lang="en" data-theme="antigravity" class="dark">
<head><title>Antigravity Console</title></head>
<body class="selection:bg-neon-purple">
<div class="w-8 h-8 bg-gradient-to-br from-neon-purple to-blue-600 shadow-[0_0_15px_rgba(168,85,247,0.4)]">
                AG</div>
<span x-text="$store.global.t('systemName')">ANTIGRAVITY</span>
<span x-text="$store.global.t('systemDesc')">CLAUDE PROXY SYSTEM</span>
            <!-- Refresh Button -->
<script src="js/translations/en.js"></script>
    <!-- 2. Alpine Stores (register alpine:init listeners) -->
</body></html>`;

const logsViewerSource = `
window.Components = window.Components || {};
window.Components.logsViewer = () => ({
    startLogStream() {
        if (this.eventSource) this.eventSource.close();

        const password = Alpine.store('global').webuiPassword;
        const url = password
            ? \`/api/logs/stream?history=true&password=\${encodeURIComponent(password)}\`
            : '/api/logs/stream?history=true';

        this.eventSource = new EventSource(url);
    }
});
`;

const sources = {
  "package.json": '{"name":"antigravity-claude-proxy","version":"2.8.5"}',
  "src/utils/helpers.js": helpersSource,
  "src/utils/version-detector.js": `const FALLBACK_USER_AGENT_VERSION = process.env.FALLBACK_ANTIGRAVITY_VERSION || '2.0.3';`,
  "src/constants.js": `
import { generateSmartUserAgent, getClientVersion } from './utils/version-detector.js';
export function getPlatformUserAgent() {
    return generateSmartUserAgent();
}
export const CLIENT_METADATA = {
    ideType: IDE_TYPE.ANTIGRAVITY,   // 6 - identifies as Antigravity client
    platform: getPlatformEnum(),      // Runtime platform detection
    pluginType: PLUGIN_TYPE.GEMINI    // 2
};
export const ANTIGRAVITY_HEADERS = {
    'User-Agent': getPlatformUserAgent(),
    'Content-Type': 'application/json',
    'X-Client-Name': 'antigravity',
    'X-Client-Version': getClientVersion(),
    'x-goog-api-client': 'gl-node/18.18.2 fire/0.8.6 grpc/1.10.x' // Simulate Google Node.js client environment
};`,
  "src/cloudcode/model-api.js": `
const request = {
                body: JSON.stringify({
                    metadata: CLIENT_METADATA,
                    mode: 1
                })
};`,
  "src/account-manager/credentials.js": `
const request = {
                body: JSON.stringify({ metadata, mode: 1 })
};`,
  "src/cloudcode/request-builder.js": `
    googleRequest.sessionId = deriveSessionId(anthropicRequest, accountEmail);
const payload = {
        requestId: 'agent-' + crypto.randomUUID()
};
export function buildHeaders(token, model, accept = 'application/json', sessionId) {
    const headers = {};
    // Add session ID header if provided (matches Antigravity binary behavior)
    if (sessionId) {
        headers['X-Machine-Session-Id'] = sessionId;
    }

    return headers;
}`,
  "src/format/request-converter.js": `
export function convert() {
        // For Claude models, set functionCallingConfig.mode = "VALIDATED"
        // This ensures strict parameter validation (matches opencode-antigravity-auth)
        if (isClaudeModel) {
            googleRequest.toolConfig = {
                functionCallingConfig: {
                    mode: 'VALIDATED'
                }
            };
        }
    // Cap max tokens for Gemini models
    if (isGeminiModel && googleRequest.generationConfig.maxOutputTokens > GEMINI_MAX_OUTPUT_TOKENS) {
        logger.debug(\`[RequestConverter] Capping Gemini max_tokens from \${googleRequest.generationConfig.maxOutputTokens} to \${GEMINI_MAX_OUTPUT_TOKENS}\`);
        googleRequest.generationConfig.maxOutputTokens = GEMINI_MAX_OUTPUT_TOKENS;
    }
}`,
  "src/format/thinking-utils.js": `
export function clampGeminiThinkingBudget(modelName, budget) {
    const requestedBudget = budget || GEMINI_DEFAULT_THINKING_BUDGET;
    const lower = (modelName || '').toLowerCase();
    return requestedBudget;
}`,
  "public/index.html": indexHtmlSource,
  "public/js/components/logs-viewer.js": logsViewerSource,
};

for (const [name, content] of Object.entries(sources)) {
  const path = join(fixture, name);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, content, "utf8");
}

const runPatch = (rootPath = fixture) => spawnSync(process.execPath, [patchScript, rootPath], { encoding: "utf8" });
const first = runPatch();
assert.equal(first.status, 0, first.stderr);
assert.match(first.stdout, /Applied Antigravity 2\.8 compatibility/);
assert.match(first.stdout, /Applied ClaudeGravity selective Smart DNS routing/);
assert.match(first.stdout, /Applied ClaudeGravity WebUI branding/);

const constants = await readFile(join(fixture, "src/constants.js"), "utf8");
assert.match(constants, /antigravity\/hub\/\$\{version\}/);
assert.match(constants, /ideType: 'ANTIGRAVITY'/);
assert.doesNotMatch(constants, /X-Client-(?:Name|Version)/);

const builder = await readFile(join(fixture, "src/cloudcode/request-builder.js"), "utf8");
assert.match(builder, /agent\/\$\{conversationId\}\/\$\{Date\.now\(\)\}\/\$\{trajectoryId\}\/1/);
assert.match(builder, /trajectory_id: trajectoryId/);
assert.doesNotMatch(builder, /X-Machine-Session-Id/);

const converter = await readFile(join(fixture, "src/format/request-converter.js"), "utf8");
assert.match(converter, /geminiMaxOutputTokens/);
assert.doesNotMatch(converter, /if \(isClaudeModel\).*toolConfig/s);

const thinking = await readFile(join(fixture, "src/format/thinking-utils.js"), "utf8");
assert.match(thinking, /gemini-3\.7-flash-medium'\) \? 4000/);

const helpers = await readFile(join(fixture, "src/utils/helpers.js"), "utf8");
assert.match(helpers, /ClaudeGravity selective Smart DNS v1/);
assert.match(helpers, /cloudcode-pa\.googleapis\.com/);
assert.match(helpers, /daily-cloudcode-pa\.googleapis\.com/);
assert.match(helpers, /CLAUDEGRAVITY_SMART_DNS_SERVERS/);
assert.match(helpers, /111\.88\.96\.50,111\.88\.96\.51/);
assert.match(helpers, /undiciFetch\(url, \{ \.\.\.options, dispatcher \}\)/);
assert.match(helpers, /systemLookup\(hostname, options, callback\)/);

const webUi = await readFile(join(fixture, "public/index.html"), "utf8");
assert.match(webUi, /<title>ClaudeGravity<\/title>/);
assert.match(webUi, /ClaudeGravity WebUI v1/);
assert.match(webUi, />\s*CG<\/div>/);
assert.match(webUi, /LOCAL AI GATEWAY/);
assert.match(webUi, /claudegravity-gateway-status/);
assert.match(webUi, /Open Claude/);
assert.match(webUi, /action\('restart'\)/);
assert.match(webUi, /action\('stop'\)/);
assert.match(webUi, /http:\/\/127\.0\.0\.1:17646/);
const webLogs = await readFile(join(fixture, "public/js/components/logs-viewer.js"), "utf8");
assert.match(webLogs, /CLAUDEGRAVITY_CONTROL_URL/);
assert.match(webLogs, /logs\/stream\?history=true/);

const second = runPatch();
assert.equal(second.status, 0, second.stderr);
assert.match(second.stdout, /already applied/);
assert.match(second.stdout, /selective Smart DNS routing is already applied/);
assert.match(second.stdout, /WebUI branding is already applied/);

const nativeFixture = await mkdtemp(join(tmpdir(), "claudegravity-proxy-native-"));
const nativeSources = {
  "package.json": '{"name":"antigravity-claude-proxy","version":"3.0.0"}',
  "src/utils/helpers.js": helpersSource,
  "src/constants.js": `
export function getPlatformUserAgent() { return 'antigravity/hub/3.0.0'; }
export const CLIENT_METADATA = { ideType: 'ANTIGRAVITY' };
export const ANTIGRAVITY_HEADERS = { 'Content-Type': 'application/json' };`,
  "src/cloudcode/model-api.js": `const body = { metadata: CLIENT_METADATA };`,
  "src/cloudcode/request-builder.js": "const payload = { requestId: `agent/${crypto.randomUUID()}` };",
  "public/index.html": indexHtmlSource,
  "public/js/components/logs-viewer.js": logsViewerSource,
};
for (const [name, content] of Object.entries(nativeSources)) {
  const path = join(nativeFixture, name);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, content, "utf8");
}
const nativeRun = runPatch(nativeFixture);
assert.equal(nativeRun.status, 0, nativeRun.stderr);
assert.match(nativeRun.stdout, /already supports the Antigravity 2\.8 protocol/);
assert.match(nativeRun.stdout, /Applied ClaudeGravity selective Smart DNS routing/);
assert.match(nativeRun.stdout, /Applied ClaudeGravity WebUI branding/);
const nativeHelpers = await readFile(join(nativeFixture, "src/utils/helpers.js"), "utf8");
assert.match(nativeHelpers, /ClaudeGravity selective Smart DNS v1/);
const nativeWebUi = await readFile(join(nativeFixture, "public/index.html"), "utf8");
assert.match(nativeWebUi, /ClaudeGravity WebUI v1/);

console.log("Antigravity proxy compatibility, Smart DNS, and WebUI checks passed.");

import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const root = resolve(import.meta.dirname, "..");
const patchScript = join(root, "launchers/scripts/patch-antigravity-proxy.mjs");
const fixture = await mkdtemp(join(tmpdir(), "claudegravity-proxy-"));

const sources = {
  "package.json": '{"name":"antigravity-claude-proxy","version":"2.8.5"}',
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
}`
};

for (const [name, content] of Object.entries(sources)) {
  const path = join(fixture, name);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, content, "utf8");
}

const runPatch = () => spawnSync(process.execPath, [patchScript, fixture], { encoding: "utf8" });
const first = runPatch();
assert.equal(first.status, 0, first.stderr);
assert.match(first.stdout, /Applied Antigravity 2\.8 compatibility/);

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

const second = runPatch();
assert.equal(second.status, 0, second.stderr);
assert.match(second.stdout, /already applied/);

console.log("Antigravity proxy compatibility checks passed.");

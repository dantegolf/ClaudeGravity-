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

const SMART_DNS_MARKER = "ClaudeGravity selective Smart DNS v1";

const patchSmartDns = async () => {
  const name = "src/utils/helpers.js";
  const source = await load(name);
  if (source.includes(SMART_DNS_MARKER)) return false;

  const configImport = "import { config } from '../config.js';";
  const fetchCall = "    return fetch(url, options);";
  if (source.split(configImport).length - 1 !== 1) {
    throw new Error(`${name}: expected one config import for Smart DNS patch`);
  }
  if (source.split(fetchCall).length - 1 !== 1) {
    throw new Error(`${name}: expected one throttled fetch call for Smart DNS patch`);
  }

  const smartDnsRuntime = `
import { Agent, fetch as undiciFetch } from 'undici';
import { Resolver, lookup as systemLookup } from 'node:dns';

// ${SMART_DNS_MARKER}
// Route only Antigravity/Cloud Code API names through the optional Smart DNS
// resolver. OAuth, accounts.google.com, and every unrelated hostname keep the
// system resolver. TLS still connects with the original hostname/SNI.
const CLAUDEGRAVITY_SMART_DNS_HOSTS = new Set([
    'cloudcode-pa.googleapis.com',
    'daily-cloudcode-pa.googleapis.com',
    'generativelanguage.googleapis.com',
    'antigravity-unleash.goog'
]);
const CLAUDEGRAVITY_SMART_DNS_DISABLED = new Set(['0', 'false', 'off', 'disabled']);
const claudeGravitySmartDnsMode = (process.env.CLAUDEGRAVITY_SMART_DNS || 'auto').trim().toLowerCase();
const claudeGravitySmartDnsEnabled = !CLAUDEGRAVITY_SMART_DNS_DISABLED.has(claudeGravitySmartDnsMode);
const claudeGravitySmartDnsServers = (process.env.CLAUDEGRAVITY_SMART_DNS_SERVERS || '111.88.96.50,111.88.96.51')
    .split(',')
    .map(value => value.trim())
    .filter(Boolean);

let claudeGravitySmartResolver = null;
if (claudeGravitySmartDnsEnabled && claudeGravitySmartDnsServers.length > 0) {
    try {
        claudeGravitySmartResolver = new Resolver();
        claudeGravitySmartResolver.setServers(claudeGravitySmartDnsServers);
    } catch {
        // Invalid/custom resolver configuration must never prevent proxy startup.
        claudeGravitySmartResolver = null;
    }
}

function claudeGravitySmartLookup(hostname, options, callback) {
    const fallback = () => systemLookup(hostname, options, callback);
    const normalized = String(hostname || '').toLowerCase();
    const family = typeof options === 'number' ? options : (options?.family || 0);
    if (!claudeGravitySmartResolver || family === 6 || !CLAUDEGRAVITY_SMART_DNS_HOSTS.has(normalized)) {
        fallback();
        return;
    }

    claudeGravitySmartResolver.resolve4(hostname, (error, addresses) => {
        if (error || !Array.isArray(addresses) || addresses.length === 0) {
            fallback();
            return;
        }
        if (typeof options === 'object' && options?.all) {
            callback(null, addresses.map(address => ({ address, family: 4 })));
            return;
        }
        callback(null, addresses[0], 4);
    });
}

const claudeGravitySmartDnsAgent = new Agent({
    connect: { lookup: claudeGravitySmartLookup }
});

function claudeGravitySmartDnsDispatcher(url, options) {
    if (!claudeGravitySmartResolver || options?.dispatcher) return null;
    try {
        const hostname = new URL(url).hostname.toLowerCase();
        return CLAUDEGRAVITY_SMART_DNS_HOSTS.has(hostname) ? claudeGravitySmartDnsAgent : null;
    } catch {
        return null;
    }
}
`;

  let updated = source.replace(configImport, `${configImport}${smartDnsRuntime}`);
  updated = updated.replace(fetchCall, `    const dispatcher = claudeGravitySmartDnsDispatcher(url, options);
    return dispatcher
        ? undiciFetch(url, { ...options, dispatcher })
        : fetch(url, options);`);
  files.set(name, updated);
  changed = true;
  return true;
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

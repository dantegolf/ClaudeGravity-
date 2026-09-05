#!/usr/bin/env node

import { chmodSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import http from "node:http";
import { join } from "node:path";

const relayHome = process.argv[2];
const antigravityBaseUrl = process.argv[3] || process.env.CLAUDEGRAVITY_ANTIGRAVITY_URL || "http://127.0.0.1:18080";
if (!relayHome) throw new Error("Usage: configure-relay.mjs <relay-home> [antigravity-base-url]");
if (!/^http:\/\/127\.0\.0\.1:\d+$/.test(antigravityBaseUrl)) {
  throw new Error("Antigravity base URL must be a loopback http://127.0.0.1:<port> address.");
}

const modelIds = [
  "gemini-3.6-flash-high",
  "claude-sonnet-4-6",
  "gemini-2.5-pro",
  "claude-opus-4-6-thinking",
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash-thinking",
  "gemini-3-flash",
  "gemini-3-flash-agent",
  "gemini-3.1-flash-image",
  "gemini-3.1-flash-lite",
  "gemini-3.1-pro-high",
  "gemini-3.1-pro-low",
  "gemini-3.5-flash-extra-low",
  "gemini-3.5-flash-low",
  "gemini-3.6-flash-low",
  "gemini-3.6-flash-medium",
  "gemini-3.6-flash-tiered",
  "gemini-3.7-flash-low",
  "gemini-3.7-flash-medium",
  "gemini-3.7-flash-high",
  "gemini-pro-agent",
];

const defaultFavorites = [
  "gemini-3.7-flash-high",
  "gemini-3.1-pro-high",
  "claude-sonnet-4-6",
  "claude-opus-4-6-thinking",
  "gemini-2.5-pro",
];

const stamp = "2026-08-13T00:00:00.000Z";
const providersPath = join(relayHome, "providers.json");
const registry = readJson(providersPath, { schemaVersion: 1, providers: [] });
registry.schemaVersion = 1;
registry.providers = Array.isArray(registry.providers) ? registry.providers : [];
const existingIndex = registry.providers.findIndex((provider) => provider?.id === "custom-antigravity");
const existingProvider = registry.providers[existingIndex];
const validModelId = (id) => typeof id === 'string' && /^(?:gemini|claude)-[a-z0-9.-]{1,160}$/.test(id);
const savedModels = existingProvider?.modelsCache?.models;
let catalog = Array.isArray(savedModels) ? savedModels.filter(model => validModelId(model?.id)) : [];
if (!catalog.length) catalog = modelIds.map(id => ({ id }));
let fetchedAt = existingProvider?.modelsCache?.fetchedAt || stamp;

if (process.argv.includes('--refresh-models')) {
  try {
    const result = await fetchModels();
    if (!Array.isArray(result?.data) || !result.data.length || !result.data.every(model => validModelId(model?.id))) {
      throw new Error('Invalid model catalog');
    }
    catalog = [...new Map(result.data.map(model => [model.id, model])).values()];
    fetchedAt = new Date().toISOString();
  } catch {
    // Offline startup / OAuth not completed must not discard the last good list.
    console.warn('Live Antigravity model discovery unavailable; keeping the saved model catalog.');
  }
}

const models = catalog.map(({ id, description, name }) => ({
  id,
  name: typeof description === 'string' && description.trim() ? description.slice(0, 200)
    : typeof name === 'string' && name.trim() ? name.slice(0, 200) : id,
  upstreamModelId: id,
  family: id.startsWith("claude-") ? "claude" : "gemini",
  brand: id.startsWith("claude-") ? "Claude" : "Gemini",
  contextWindow: id === "gemini-2.5-pro" ? 2_000_000 : 1_000_000,
  modelFormat: "anthropic",
  npm: "@ai-sdk/anthropic",
  apiUrl: antigravityBaseUrl,
}));

const antigravityProvider = {
  id: "custom-antigravity",
  templateId: "custom-anthropic",
  name: "Antigravity",
  enabled: true,
  authRef: "keyring:provider:custom-antigravity",
  addedAt: existingProvider?.addedAt || stamp,
  refreshedAt: fetchedAt,
  api: { npm: "@ai-sdk/anthropic", url: antigravityBaseUrl },
  modelsCache: { fetchedAt, models },
};

function fetchModels() {
  return new Promise((resolve, reject) => {
    // Always direct loopback HTTP: inherited HTTPS_PROXY must not intercept it.
    const request = http.get(`${antigravityBaseUrl}/v1/models`, {
      headers: { 'x-api-key': 'antigravity' }
    }, response => {
      if (response.statusCode !== 200) {
        response.resume();
        reject(new Error('Model discovery failed'));
        return;
      }
      let body = '';
      response.setEncoding('utf8');
      response.on('data', chunk => {
        body += chunk;
        if (body.length > 1_000_000) request.destroy(new Error('Model catalog too large'));
      });
      response.on('error', reject);
      response.on('end', () => {
        try { resolve(JSON.parse(body)); } catch (error) { reject(error); }
      });
    });
    const timer = setTimeout(() => request.destroy(new Error('Model discovery timed out')), 10_000);
    request.on('error', reject);
    request.on('close', () => clearTimeout(timer));
  });
}

function readJson(path, fallback) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return fallback;
  }
}

function writeJson(path, value) {
  const temporary = `${path}.${process.pid}.tmp`;
  writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  chmodSync(temporary, 0o600);
  renameSync(temporary, path);
}

mkdirSync(relayHome, { recursive: true, mode: 0o700 });
chmodSync(relayHome, 0o700);

if (existingIndex === -1) registry.providers.push(antigravityProvider);
else registry.providers[existingIndex] = { ...existingProvider, ...antigravityProvider };
writeJson(providersPath, registry);

const secretsPath = join(relayHome, "secrets.json");
const secrets = readJson(secretsPath, { version: 1, accounts: {} });
secrets.version = 1;
secrets.accounts = secrets.accounts && typeof secrets.accounts === "object" ? secrets.accounts : {};
secrets.accounts["provider:custom-antigravity"] = "antigravity";
writeJson(secretsPath, secrets);

const configPath = join(relayHome, "config.json");
const preferences = readJson(configPath, {});
if (preferences.claudeGravityFavoritesVersion !== 2) {
  const favorites = Array.isArray(preferences.favoriteModels)
    ? preferences.favoriteModels.filter((favorite) => favorite?.providerId && favorite?.modelId)
    : [];
  for (const modelId of defaultFavorites) {
    if (favorites.length >= 20) break;
    if (!favorites.some((favorite) => favorite.providerId === "custom-antigravity" && favorite.modelId === modelId)) {
      favorites.push({ providerId: "custom-antigravity", modelId });
    }
  }
  preferences.favoriteModels = favorites;
  preferences.claudeGravityFavoritesVersion = 2;
  writeJson(configPath, preferences);
}

console.log(`Relay AI configured: ${models.length} models, ${defaultFavorites.length} defaults, upstream ${antigravityBaseUrl}.`);

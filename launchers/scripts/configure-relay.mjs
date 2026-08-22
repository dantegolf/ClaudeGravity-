#!/usr/bin/env node

import { chmodSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
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
const models = modelIds.map((id) => ({
  id,
  name: id,
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
  addedAt: stamp,
  refreshedAt: stamp,
  api: { npm: "@ai-sdk/anthropic", url: antigravityBaseUrl },
  modelsCache: { fetchedAt: stamp, models },
};

function readJson(path, fallback) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return fallback;
  }
}

function writeJson(path, value) {
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  chmodSync(path, 0o600);
}

function validProvider(provider) {
  return provider?.id === "custom-antigravity"
    && provider.templateId === "custom-anthropic"
    && provider.enabled === true
    && provider.authRef === "keyring:provider:custom-antigravity"
    && provider.api?.url === antigravityBaseUrl
    && provider.modelsCache?.models?.length === modelIds.length
    && provider.modelsCache.models.every((model) => model.apiUrl === antigravityBaseUrl)
    && modelIds.every((id) => provider.modelsCache.models.some((model) => model.id === id));
}

mkdirSync(relayHome, { recursive: true, mode: 0o700 });
chmodSync(relayHome, 0o700);

const providersPath = join(relayHome, "providers.json");
const registry = readJson(providersPath, { schemaVersion: 1, providers: [] });
registry.schemaVersion = 1;
registry.providers = Array.isArray(registry.providers) ? registry.providers : [];
const existingIndex = registry.providers.findIndex((provider) => provider?.id === "custom-antigravity");
if (existingIndex === -1) registry.providers.push(antigravityProvider);
else if (!validProvider(registry.providers[existingIndex])) registry.providers[existingIndex] = antigravityProvider;
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

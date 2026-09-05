import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';
import { EventEmitter } from 'node:events';

const source = (await readFile(new URL('../launchers/scripts/smart-dns.mjs', import.meta.url), 'utf8'))
    .replace(/^import .*;\r?\n/gm, '');
const gate = 'https://cloudcode-pa.googleapis.com/v1internal:generateContent';
const body = JSON.stringify({ request: { contents: [] } });
const ok = () => new Response('ok');
const region = () => new Response('{"error":{"message":"User location is not supported"}}', { status: 400 });
const connectionError = code => Object.assign(new Error('fetch failed'), { cause: { code } });

function runtime(env = {}, send = ok, overrides = {}) {
    const calls = [];
    const resolvers = [];
    const timers = new Set();
    const context = {
        Buffer, URL, Response, console: { warn() {} }, process: { env },
        setTimeout(fn, ms) { const timer = setTimeout(fn, ms); timers.add(timer); return timer; },
        clearTimeout(timer) { timers.delete(timer); clearTimeout(timer); },
        fetch: async (url, options) => { calls.push({ url, options, system: true }); return send(url, options); },
        undiciFetch: async (url, options) => { calls.push({ url, options }); return send(url, options); },
        Agent: class { constructor(options) { this.options = options; } },
        EnvHttpProxyAgent: class { constructor() { this.ownProxy = true; } },
        Resolver: class {
            constructor(options) { assert.equal(options.timeout, 1000); assert.equal(options.tries, 1); resolvers.push(this); }
            setServers(servers) { if (servers.includes('invalid')) throw new Error('invalid'); this.servers = servers; }
            resolve4(host, options, callback) {
                assert.equal(options.ttl, true);
                this.lookups = (this.lookups || 0) + 1;
                queueMicrotask(() => callback(null, [{ address: '192.0.2.1', ttl: 60 }]));
            }
        },
        systemLookup(host, options, callback) { callback(null, '192.0.2.2', 4); },
        connectHttp2() { throw new Error('Unexpected network access'); },
        ...overrides
    };
    const api = runInNewContext(source + `\n({ fetch: claudeGravityFetch, question: claudeGravityDnsQuestion,
        answers: claudeGravityDnsAnswers, doh: claudeGravityResolveDoh, routes: claudeGravityRoutes,
        hosts: claudeGravityGateHosts, region: claudeGravityRegionError })`, context);
    return { ...api, calls, resolvers, timers };
}

const normal = runtime();
const manifest = JSON.parse(await readFile(new URL('../distribution/manifest.json', import.meta.url), 'utf8'));
assert.deepEqual([...normal.hosts], manifest.network.hosts);
assert.deepEqual(normal.resolvers.map(r => [...r.servers]), [manifest.network.defaultServers, ...manifest.network.fallbackServerGroups]);
assert.equal(normal.routes.length, 4);
for (const url of ['https://accounts.google.com/', 'https://oauth2.googleapis.com/token',
    'https://generativelanguage.googleapis.com/', 'https://antigravity-unleash.goog/',
    'https://cloudcode-pa.googleapis.com.evil.test/', 'http://cloudcode-pa.googleapis.com/',
    'https://cloudcode-pa.googleapis.com:444/', 'http://127.0.0.1:18080/']) {
    await normal.fetch(url);
    assert.equal(normal.calls.at(-1).system, true, url);
}
await normal.fetch(gate, { dispatcher: {} });
assert.equal(normal.calls.at(-1).system, true, 'explicit dispatcher must be preserved');
await normal.fetch(gate);
assert.equal(normal.calls.at(-1).options.dispatcher, normal.routes[0].agent);

for (const setting of ['off', '0', 'false', 'disabled']) {
    const disabled = runtime({ CLAUDEGRAVITY_SMART_DNS: setting });
    await disabled.fetch(gate);
    assert.equal(disabled.calls[0].system, true);
    assert.equal(disabled.routes.length, 0);
}
for (const key of ['HTTPS_PROXY', 'https_proxy', 'HTTP_PROXY', 'http_proxy']) {
    const env = { [key]: 'http://user:password@proxy.test:3128', NO_PROXY: 'localhost', CLAUDEGRAVITY_SMART_DNS: 'off' };
    const own = runtime(env);
    await own.fetch(gate);
    assert.equal(own.calls[0].options.dispatcher.ownProxy, true);
    assert.equal(own.routes.length, 0);
    assert.equal(env[key], 'http://user:password@proxy.test:3128');
    const failed = runtime(env, () => { throw connectionError('ECONNREFUSED'); });
    await assert.rejects(failed.fetch(gate));
    assert.equal(failed.calls.length, 1, 'never bypass an explicit user proxy on failure');
}

const custom = runtime({ CLAUDEGRAVITY_SMART_DNS_SERVERS: '192.0.2.53, 192.0.2.54' });
assert.equal(custom.routes.length, 1, 'custom servers replace all public defaults, including DoH');
const lookup = options => new Promise((resolve, reject) => custom.routes[0].agent.options.connect.lookup(
    'cloudcode-pa.googleapis.com', options, (error, address, family) => error ? reject(error) : resolve({ address, family })));
const [all, one] = await Promise.all([lookup({ all: true }), lookup(4)]);
assert.equal(all.address[0].family, 4);
assert.equal(one.family, 4);
await lookup({ all: true });
assert.equal(custom.resolvers[0].lookups, 1, 'concurrent and cached lookups share one resolution');
assert.equal((await lookup({ family: 6 })).address, '192.0.2.2', 'explicit IPv6 lookup keeps system resolver');
const invalid = runtime({ CLAUDEGRAVITY_SMART_DNS_SERVERS: 'invalid' });
await invalid.fetch(gate);
assert.equal(invalid.calls[0].system, true);

let attempts = 0;
const failover = runtime({}, () => ++attempts === 1 ? region() : ok());
await failover.fetch(gate, { method: 'POST', body });
assert.equal(failover.calls.length, 2);
await failover.fetch(gate, { method: 'POST', body });
assert.equal(failover.calls[2].options.dispatcher, failover.routes[1].agent, 'failed route must cool down');
await failover.fetch(gate.replace('cloudcode-pa', 'daily-cloudcode-pa'), { method: 'POST', body });
assert.equal(failover.calls[3].options.dispatcher, failover.routes[0].agent, 'health must be per hostname');
failover.routes[0].unavailable.clear();
await failover.fetch(gate);
assert.equal(failover.calls.at(-1).options.dispatcher, failover.routes[0].agent, 'recovered routes can be retried');
assert.equal(failover.timers.size, 0);

for (const code of ['UND_ERR_CONNECT_TIMEOUT', 'ECONNREFUSED', 'EAI_AGAIN']) {
    let count = 0;
    const recovering = runtime({}, () => { if (++count === 1) throw connectionError(code); return ok(); });
    await recovering.fetch(gate, { method: 'POST', body });
    assert.equal(recovering.calls.length, 2);
}
for (const code of ['ECONNRESET', 'UND_ERR_SOCKET', 'UND_ERR_HEADERS_TIMEOUT', 'CERT_HAS_EXPIRED']) {
    const unsafe = runtime({}, () => { throw connectionError(code); });
    await assert.rejects(unsafe.fetch(gate, { method: 'POST', body }));
    assert.equal(unsafe.calls.length, 1, code);
}
for (const response of [new Response('bad request', { status: 400 }), new Response('quota', { status: 429 }), region()]) {
    const streaming = runtime({}, () => response);
    const returned = await streaming.fetch(gate, { method: 'POST', body: new ReadableStream() });
    assert.equal(returned, response);
    assert.equal(streaming.calls.length, 1, 'non-replayable body must never be retried');
}
const ordinary400 = runtime({}, () => new Response('bad request', { status: 400 }));
assert.equal(await (await ordinary400.fetch(gate, { body })).text(), 'bad request');
assert.equal(ordinary400.calls.length, 1);
const unreadable = new Response(new ReadableStream({ start(controller) { controller.error(new Error('body failed')); } }), { status: 400 });
const failedBody = runtime({}, () => unreadable);
assert.equal(await failedBody.fetch(gate, { body }), unreadable, 'failed error-body inspection must not replace the response');
const abort = new AbortController();
abort.abort();
await assert.rejects(normal.fetch(gate, { signal: abort.signal }), { name: 'AbortError' });
const allFailed = runtime({}, region);
const last = await allFailed.fetch(gate, { body });
assert.equal(allFailed.calls.length, 5);
assert.equal(allFailed.calls.at(-1).system, true);
assert.match(await last.text(), /User location/);

// Real wire-format parser, including compression, CNAME ownership and truncation.
const question = normal.question('cloudcode-pa.googleapis.com');
function reply(records) {
    const result = Buffer.concat([question, ...records]);
    result.writeUInt16BE(0x8180, 2);
    result.writeUInt16BE(records.length, 6);
    return result;
}
const a = Buffer.from([0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 60, 0, 4, 192, 0, 2, 10]);
const wire = reply([a]);
assert.equal(normal.answers(wire, question)[0].address, '192.0.2.10');
for (let i = 0; i < wire.length; i++) assert.throws(() => normal.answers(wire.subarray(0, i), question));
const loop = Buffer.from(wire);
loop[question.length + 1] = question.length;
assert.throws(() => normal.answers(loop, question), /Invalid DNS name/);
const nxdomain = Buffer.from(wire);
nxdomain[3] |= 3;
assert.throws(() => normal.answers(nxdomain, question));
const unrelated = Buffer.concat([Buffer.from([1, 120, 0]), a.subarray(2)]);
assert.throws(() => normal.answers(reply([unrelated]), question), /No DoH/);
const cname = Buffer.from([0xc0, 0x0c, 0, 5, 0, 1, 0, 0, 0, 60, 0, 3, 1, 120, 0]);
assert.equal(normal.answers(reply([cname, unrelated]), question)[0].address, '192.0.2.10');

// Exercise the HTTP/2 lifecycle without external services or Google credentials.
function dohTransport(mode) {
    return function connect(authority) {
        assert.equal(authority, new URL(manifest.network.defaultDoh).origin);
        const session = new EventEmitter();
        session.destroy = () => { session.destroyed = true; };
        session.request = headers => {
            assert.equal(headers.accept, 'application/dns-message');
            assert.equal(headers[':path'], '/dns-query?dns=' + question.toString('base64url'));
            const request = new EventEmitter();
            request.destroy = () => { request.destroyed = true; };
            request.end = () => queueMicrotask(() => {
                if (mode === 'closed') return session.emit('close');
                request.emit('response', { ':status': mode === 'http' ? 505 : 200, 'content-type': 'application/dns-message' });
                request.emit('data', mode === 'large' ? Buffer.alloc(65536) : wire);
                request.emit('end');
            });
            return request;
        };
        queueMicrotask(() => session.emit('connect'));
        return session;
    };
}
for (const mode of ['ok', 'closed', 'http', 'large']) {
    const doh = runtime({}, ok, { connectHttp2: dohTransport(mode) });
    if (mode === 'ok') assert.equal((await doh.doh('cloudcode-pa.googleapis.com'))[0].address, '192.0.2.10');
    else await assert.rejects(doh.doh('cloudcode-pa.googleapis.com'));
    assert.equal(doh.timers.size, 0);
}

let destroyed = false;
const hung = runtime({}, ok, {
    connectHttp2() { const session = new EventEmitter(); session.destroy = () => { destroyed = true; }; return session; },
    setTimeout(fn, ms) { assert.equal(ms, 2500); return setTimeout(fn, 1); },
    clearTimeout
});
await assert.rejects(hung.doh('cloudcode-pa.googleapis.com'), /deadline/);
assert.equal(destroyed, true);

console.log('Smart DNS routing, failover, proxy precedence, DNS parser and HTTP/2 checks passed.');

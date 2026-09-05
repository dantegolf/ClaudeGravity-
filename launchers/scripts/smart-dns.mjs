// Embedded into the pinned proxy's helpers.js by patch-antigravity-proxy.mjs.
import { Agent, EnvHttpProxyAgent, fetch as undiciFetch } from 'undici';
import { Resolver, lookup as systemLookup } from 'node:dns';
import { connect as connectHttp2 } from 'node:http2';

// ClaudeGravity selective Smart DNS v2
const claudeGravityGateHosts = new Set([
    'cloudcode-pa.googleapis.com',
    'daily-cloudcode-pa.googleapis.com'
]);
const claudeGravityDnsDisabled = ['0', 'false', 'off', 'disabled'].includes(
    (process.env.CLAUDEGRAVITY_SMART_DNS || 'auto').trim().toLowerCase()
);
const claudeGravityOwnProxy = (process.env.https_proxy ?? process.env.HTTPS_PROXY) ||
    (process.env.http_proxy ?? process.env.HTTP_PROXY);
// NO_PROXY/no_proxy and lowercase precedence are handled by Undici. Never
// change global dispatchers or environment variables used by other processes.
const claudeGravityProxyAgent = claudeGravityOwnProxy ? new EnvHttpProxyAgent() : null;

function claudeGravityDnsQuestion(hostname) {
    const header = Buffer.alloc(12);
    header.writeUInt16BE(0x0100, 2); // recursion desired; DoH transaction ID is zero
    header.writeUInt16BE(1, 4);
    return Buffer.concat([header, ...hostname.split('.').map(label =>
        Buffer.concat([Buffer.from([label.length]), Buffer.from(label)])),
    Buffer.from([0, 0, 1, 0, 1])]); // A, IN
}

function claudeGravityDnsAnswers(wire, question) {
    if (wire.length < question.length || wire.length > 65535 || wire.readUInt16BE(6) > 128 || wire.readUInt16BE(0) !== 0 ||
        (wire.readUInt16BE(2) & 0xfa0f) !== 0x8000 || wire.readUInt16BE(4) !== 1 ||
        !wire.subarray(12, question.length).equals(question.subarray(12))) {
        throw new Error('Invalid DoH response');
    }
    const readName = (start) => {
        const labels = [];
        let offset = start;
        let next;
        const seen = new Set();
        while (true) {
            if (offset >= wire.length || seen.has(offset)) throw new Error('Invalid DNS name');
            seen.add(offset);
            const size = wire[offset++];
            if (size === 0) return { name: labels.join('.').toLowerCase(), next: next ?? offset };
            if ((size & 0xc0) === 0xc0) {
                if (offset >= wire.length) throw new Error('Truncated DNS pointer');
                next ??= offset + 1;
                offset = ((size & 0x3f) << 8) | wire[offset];
            } else {
                if (size > 63 || offset + size > wire.length || labels.length > 127) throw new Error('Invalid DNS label');
                labels.push(wire.toString('ascii', offset, offset + size));
                offset += size;
            }
        }
    };
    let offset = question.length;
    const records = [];
    for (let i = 0; i < wire.readUInt16BE(6); i++) {
        const owner = readName(offset);
        offset = owner.next;
        if (offset + 10 > wire.length) throw new Error('Truncated DNS record');
        const type = wire.readUInt16BE(offset);
        const klass = wire.readUInt16BE(offset + 2);
        const ttl = wire.readUInt32BE(offset + 4);
        const length = wire.readUInt16BE(offset + 8);
        offset += 10;
        if (offset + length > wire.length) throw new Error('Truncated DNS data');
        if (klass === 1 && type === 1 && length === 4) {
            records.push({ name: owner.name, address: [...wire.subarray(offset, offset + 4)].join('.'), ttl });
        } else if (klass === 1 && type === 5) {
            const alias = readName(offset);
            if (alias.next !== offset + length) throw new Error('Invalid DNS alias');
            records.push({ name: owner.name, alias: alias.name, ttl });
        }
        offset += length;
    }
    const names = new Set([readName(12).name]);
    for (let i = 0; i < records.length; i++) {
        for (const record of records) if (names.has(record.name) && record.alias) names.add(record.alias);
    }
    const answers = records.filter(record => names.has(record.name) && record.address);
    if (!answers.length) throw new Error('No DoH IPv4 answers');
    const ttl = Math.min(...records.filter(record => names.has(record.name)).map(record => record.ttl));
    return answers.map(answer => ({ ...answer, ttl: Math.min(ttl, answer.ttl) }));
}

function claudeGravityResolveDoh(hostname) {
    const question = claudeGravityDnsQuestion(hostname);
    return new Promise((resolve, reject) => {
        // Native HTTP/2 is necessary: this endpoint does not accept HTTP/1.1.
        // TLS verifies dns.dns-ai.ru using the normal system trust store.
        const session = connectHttp2('https://dns.dns-ai.ru');
        let request;
        let settled = false;
        const finish = (error, answers) => {
            if (settled) return;
            settled = true;
            clearTimeout(timer);
            request?.destroy();
            session.destroy();
            error ? reject(error) : resolve(answers);
        };
        const timer = setTimeout(() => finish(new Error('DoH deadline exceeded')), 2500);
        session.on('error', finish);
        session.on('close', () => finish(new Error('DoH connection closed')));
        session.once('connect', () => {
            request = session.request({
                ':path': '/dns-query?dns=' + question.toString('base64url'),
                accept: 'application/dns-message'
            });
            const chunks = [];
            let length = 0;
            request.on('response', headers => {
                if (headers[':status'] !== 200 ||
                    !String(headers['content-type']).startsWith('application/dns-message')) {
                    finish(new Error('DoH HTTP response rejected'));
                }
            });
            request.on('data', chunk => {
                length += chunk.length;
                if (length > 65535) finish(new Error('DoH response too large'));
                else chunks.push(chunk);
            });
            request.on('error', finish);
            request.on('end', () => {
                if (settled) return;
                try { finish(null, claudeGravityDnsAnswers(Buffer.concat(chunks), question)); }
                catch (error) { finish(error); }
            });
            request.end();
        });
    });
}

function claudeGravityUdpResolver(servers) {
    const resolver = new Resolver({ timeout: 1000, tries: 1 });
    resolver.setServers(servers);
    return hostname => new Promise((resolve, reject) => {
        resolver.resolve4(hostname, { ttl: true }, (error, addresses) => {
            if (error || !addresses?.length) reject(error || new Error('No DNS answers'));
            else resolve(addresses);
        });
    });
}

const claudeGravityRoutes = [];
function claudeGravityAddRoute(label, resolve4) {
    const cache = new Map();
    const pending = new Map();
    const route = { label, unavailable: new Map() };
    route.agent = new Agent({ connect: { timeout: 5000, lookup(hostname, options, callback) {
        const family = typeof options === 'number' ? options : options?.family;
        if (family === 6 || !claudeGravityGateHosts.has(hostname.toLowerCase())) {
            systemLookup(hostname, options, callback);
            return;
        }
        let lookup = pending.get(hostname);
        if (!lookup) {
            const cached = cache.get(hostname);
            lookup = cached && cached.until > Date.now() ? Promise.resolve(cached.answers) :
                resolve4(hostname).then(answers => {
                    cache.set(hostname, { answers, until: Date.now() +
                        Math.min(60, ...answers.map(answer => answer.ttl)) * 1000 });
                    return answers;
                });
            pending.set(hostname, lookup);
            lookup.finally(() => pending.delete(hostname)).catch(() => {});
        }
        lookup.then(answers => {
            if (options?.all) callback(null, answers.map(({ address }) => ({ address, family: 4 })));
            else callback(null, answers[0].address, 4);
        }, () => callback(Object.assign(new Error('Smart DNS lookup failed'), { code: 'EAI_AGAIN' })));
    } } });
    claudeGravityRoutes.push(route);
}

if (!claudeGravityDnsDisabled && !claudeGravityProxyAgent) {
    const custom = process.env.CLAUDEGRAVITY_SMART_DNS_SERVERS;
    if (!custom) claudeGravityAddRoute('dns-ai.ru (DoH)', claudeGravityResolveDoh);
    const providers = custom ? [custom.split(',').map(value => value.trim()).filter(Boolean)] : [
        ['111.88.96.50', '111.88.96.51'],
        ['83.220.169.155', '212.109.195.93', '195.133.25.16'],
        ['45.155.204.190', '37.230.192.51']
    ];
    for (const [index, servers] of providers.entries()) {
        try {
            if (servers.length) claudeGravityAddRoute(custom ? 'custom DNS' : 'DNS fallback ' + (index + 1),
                claudeGravityUdpResolver(servers));
        } catch {
            console.warn('[ClaudeGravity] Invalid Smart DNS configuration; using system DNS.');
        }
    }
}

async function claudeGravityRegionError(response) {
    if (response.status !== 400) return false;
    const reader = response.clone().body?.getReader();
    if (!reader) return false;
    let timer;
    try {
        return await Promise.race([
            (async () => {
                const chunks = [];
                let length = 0;
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) return /User location is not supported/i.test(Buffer.concat(chunks).toString());
                    length += value.length;
                    if (length > 65536) return false;
                    chunks.push(Buffer.from(value));
                }
            })(),
            new Promise(resolve => { timer = setTimeout(() => resolve(false), 2000); })
        ]);
    } catch {
        return false;
    } finally {
        clearTimeout(timer);
        // A tee branch can wait for the original body: do not await cancellation.
        reader.cancel().catch(() => {});
    }
}

async function claudeGravityFetch(url, options) {
    const target = new URL(url);
    if (options?.dispatcher || target.protocol !== 'https:' ||
        (target.port && target.port !== '443') || !claudeGravityGateHosts.has(target.hostname)) {
        return fetch(url, options);
    }
    if (claudeGravityProxyAgent) return undiciFetch(url, { ...options, dispatcher: claudeGravityProxyAgent });
    if (claudeGravityDnsDisabled) return fetch(url, options);

    const routes = claudeGravityRoutes.filter(route => (route.unavailable.get(target.hostname) || 0) <= Date.now());
    // System DNS stays available for working VPNs and supported-region exits.
    routes.push({ label: 'system DNS', agent: null });
    for (const [index, route] of routes.entries()) {
        options?.signal?.throwIfAborted();
        const retryable = index < routes.length - 1 && (options?.body == null || typeof options.body === 'string');
        try {
            const response = await (route.agent ? undiciFetch(url, { ...options, dispatcher: route.agent }) : fetch(url, options));
            if (!retryable || !await claudeGravityRegionError(response)) return response;
            response.body?.cancel().catch(() => {});
        } catch (error) {
            // Only failures before a connection is established are safe to
            // replay. Never replay a stream, abort, read timeout or socket reset.
            const failures = error.cause?.errors || [error.cause || error];
            if (!retryable || options?.signal?.aborted || !failures.length || !failures.every(failure => [
                'UND_ERR_CONNECT_TIMEOUT', 'ECONNREFUSED', 'ENETUNREACH', 'EHOSTUNREACH', 'EAI_AGAIN', 'ENOTFOUND'
            ].includes(failure.code))) throw error;
        }
        route.unavailable.set(target.hostname, Date.now() + 60000);
        console.warn('[ClaudeGravity] ' + route.label + ' unavailable for ' + target.hostname + '; trying next route.');
    }
}
// End ClaudeGravity selective Smart DNS v2

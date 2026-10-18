// Roblox games overview: serves the dashboard and proxies Roblox's public APIs
// (browsers can't call them directly because of CORS). It also samples player
// counts every minute so the dashboard can show trends over the last 24 hours.
//
// Usage: node server.js            (then open http://localhost:3000)
//        PORT=8080 node server.js

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = Number(process.env.PORT) || 3000;
const POLL_MS = 60 * 1000;
const HISTORY_MS = 24 * 60 * 60 * 1000;
const DATA_FILE = path.join(__dirname, 'data', 'history.json');
const PUBLIC_DIR = path.join(__dirname, 'public');

// history[universeId] = [[timestampMs, playing, visits], ...]
let history = {};
// Owners the dashboard has asked about; polled in the background.
const tracked = new Map(); // key -> { type: 'user'|'group', id }

try {
  const saved = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  history = saved.history || {};
  for (const o of saved.tracked || []) tracked.set(`${o.type}:${o.id}`, o);
} catch {}

function save() {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify({ history, tracked: [...tracked.values()] }));
}

async function getJson(url, init) {
  const res = await fetch(url, { ...init, headers: { accept: 'application/json', ...(init && init.headers) } });
  if (!res.ok) throw new Error(`${res.status} from ${new URL(url).host}${new URL(url).pathname}`);
  return res.json();
}

function chunk(arr, n) {
  const out = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
}

async function resolveUser(input) {
  if (/^\d+$/.test(input)) {
    const u = await getJson(`https://users.roblox.com/v1/users/${input}`);
    return { id: u.id, name: u.name, displayName: u.displayName };
  }
  const r = await getJson('https://users.roblox.com/v1/usernames/users', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ usernames: [input], excludeBannedUsers: false }),
  });
  const u = r.data && r.data[0];
  if (!u) throw new Error(`No Roblox user named "${input}"`);
  return { id: u.id, name: u.name, displayName: u.displayName };
}

async function resolveGroup(id) {
  const g = await getJson(`https://groups.roblox.com/v1/groups/${id}`);
  return { id: g.id, name: g.name };
}

async function listUniverseIds(owner) {
  const ids = [];
  let cursor = '';
  do {
    const base = owner.type === 'user'
      ? `https://games.roblox.com/v2/users/${owner.id}/games`
      : `https://games.roblox.com/v2/groups/${owner.id}/gamesV2`;
    const page = await getJson(`${base}?accessFilter=Public&limit=50&sortOrder=Desc${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`);
    for (const g of page.data) ids.push(g.id);
    cursor = page.nextPageCursor;
  } while (cursor && ids.length < 500);
  return ids;
}

async function fetchGames(universeIds) {
  const games = [];
  for (const ids of chunk(universeIds, 50)) {
    const q = ids.join(',');
    const [details, votes, icons] = await Promise.all([
      getJson(`https://games.roblox.com/v1/games?universeIds=${q}`),
      getJson(`https://games.roblox.com/v1/games/votes?universeIds=${q}`),
      getJson(`https://thumbnails.roblox.com/v1/games/icons?universeIds=${q}&size=150x150&format=Png&isCircular=false`).catch(() => ({ data: [] })),
    ]);
    const voteById = new Map(votes.data.map((v) => [v.id, v]));
    const iconById = new Map(icons.data.map((i) => [i.targetId, i.imageUrl]));
    for (const d of details.data) {
      const v = voteById.get(d.id) || { upVotes: 0, downVotes: 0 };
      games.push({
        universeId: d.id,
        placeId: d.rootPlaceId,
        name: d.name,
        creator: d.creator && d.creator.name,
        genre: d.genre_l1 || d.genre,
        playing: d.playing || 0,
        visits: d.visits || 0,
        favorites: d.favoritedCount || 0,
        maxPlayers: d.maxPlayers,
        upVotes: v.upVotes,
        downVotes: v.downVotes,
        created: d.created,
        updated: d.updated,
        icon: iconById.get(d.id) || null,
      });
    }
  }
  return games;
}

function record(games, now = Date.now()) {
  for (const g of games) {
    const h = (history[g.universeId] ||= []);
    const last = h[h.length - 1];
    // Skip duplicate samples taken within a few seconds of each other.
    if (last && now - last[0] < 5000) last.splice(1, 2, g.playing, g.visits);
    else h.push([now, g.playing, g.visits]);
    while (h.length && now - h[0][0] > HISTORY_MS) h.shift();
  }
}

async function snapshot(owner) {
  const ids = await listUniverseIds(owner);
  const games = await fetchGames(ids);
  record(games);
  return games;
}

async function pollAll() {
  for (const owner of tracked.values()) {
    try { await snapshot(owner); } catch (e) { console.warn(`poll ${owner.type}:${owner.id}: ${e.message}`); }
  }
  save();
}

async function overview(params) {
  const owners = [];
  const user = (params.get('user') || '').trim();
  if (user) owners.push({ type: 'user', ...(await resolveUser(user)) });
  for (const gid of (params.get('groups') || '').split(',').map((s) => s.trim()).filter(Boolean)) {
    if (!/^\d+$/.test(gid)) throw new Error(`Group ID "${gid}" should be a number`);
    owners.push({ type: 'group', ...(await resolveGroup(gid)) });
  }
  if (!owners.length) throw new Error('Enter a Roblox username/user ID or a group ID');

  const seen = new Set();
  const games = [];
  for (const owner of owners) {
    tracked.set(`${owner.type}:${owner.id}`, { type: owner.type, id: owner.id });
    for (const g of await snapshot(owner)) {
      if (seen.has(g.universeId)) continue;
      seen.add(g.universeId);
      games.push({ ...g, ownerType: owner.type, ownerName: owner.name, history: history[g.universeId] || [] });
    }
  }
  save();
  return { fetchedAt: Date.now(), owners, games };
}

const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml' };

http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (url.pathname === '/api/overview') {
    try {
      const body = await overview(url.searchParams);
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify(body));
    } catch (e) {
      res.writeHead(400, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: e.message }));
    }
    return;
  }
  const file = path.join(PUBLIC_DIR, url.pathname === '/' ? 'index.html' : path.normalize(url.pathname));
  if (!file.startsWith(PUBLIC_DIR) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404).end('Not found');
    return;
  }
  res.writeHead(200, { 'content-type': MIME[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
}).listen(PORT, () => {
  console.log(`Roblox games overview running at http://localhost:${PORT}`);
});

setInterval(pollAll, POLL_MS);

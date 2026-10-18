# ClaudeOne: Roblox Experience Overview

A single-screen analytics dashboard for every Roblox experience owned by the accounts in [`config.json`](config.json). It's currently set to the **Myanmar Builders Club** group.

- **Totals:** concurrent users (with a 24h trend), visits and visits gained, favorites, overall like ratio, and how many experiences are live.
- **Concurrent users chart:** the last 24 hours or 7 days for your top 5 experiences, plus all others combined. Hover for exact values.
- **Experiences table:** CCU, 24h peak, trend, visits, 24h visits, favorites, like ratio, and last update for every experience. You can sort by any column and filter by name.

## Hosted version

The always-on hosted version lives in its own repository, [roblox-dashboard](https://github.com/kaungmyatkyawhhhhh-hub/roblox-dashboard). It has its own GitHub Pages site, so this repository's Pages site is never touched.

## Run it locally (optional)

You need Node.js 18 or newer. There are no dependencies to install.

```sh
npm start        # or: node server.js
```

Open http://localhost:3000 and enter a username or group IDs. The local server samples every minute and keeps 24 hours of history in `data/history.json`.

## How it works

- `lib/roblox.js` calls Roblox's public APIs (games, votes, thumbnails, users, groups).
- `scripts/collect.js` is the scheduled collector. `server.js` is the local server, which also proxies the APIs because browsers can't call them directly (CORS).
- `public/index.html` is the dashboard. It reads `data.json` when it's hosted and the local API otherwise.
- Only **public** experiences and public stats are shown. Creator Dashboard metrics such as revenue, retention and session length need a Roblox Open Cloud API key and aren't included.

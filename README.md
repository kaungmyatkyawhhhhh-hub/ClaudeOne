# ClaudeOne: Roblox Experience Overview

A single-screen analytics dashboard for every Roblox experience you own, including ones your groups own.

- **Totals:** concurrent users (with a 24h trend), visits and visits gained, favorites, overall like ratio, and how many experiences are live.
- **Concurrent users, last 24 hours:** your top 5 experiences plus all others combined. Hover for exact values.
- **Experiences table:** CCU, 24h peak, trend, visits, 24h visits, favorites, like ratio, and last update for every experience. You can sort by any column and filter by name.

The page refreshes every minute.

## Run it

You need Node.js 18 or newer. There are no dependencies to install.

```sh
npm start        # or: node server.js
```

Open http://localhost:3000 and enter your Roblox username or user ID. Group IDs are optional and comma-separated. The page remembers what you entered. You can also bookmark a link like
`http://localhost:3000/?user=YourName&groups=1234567`.

## How it works

- `server.js` serves the page and proxies Roblox's public APIs (games, votes, thumbnails, users, groups). Browsers can't call those APIs directly because of CORS.
- While the server runs, it samples CCU and visits every minute for each account you've loaded. It keeps 24 hours of history in `data/history.json`, so the trend lines fill in the longer it runs.
- Only **public** experiences and public stats are shown. Creator Dashboard metrics such as revenue, retention and session length need a Roblox Open Cloud API key and aren't included.

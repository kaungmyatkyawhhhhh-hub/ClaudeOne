// Builds the game from index.html (the single source of truth) into two folders:
//   www/  - the web bundle Capacitor packages into the iOS and Android apps
//   docs/ - a home-screen web app served by GitHub Pages (icon, full screen, offline)
// Both get a full document wrapper, bundled fonts and safe-area padding for notched phones.
import { readFileSync, writeFileSync, mkdirSync, cpSync, rmSync } from "node:fs";
import { createHash } from "node:crypto";

const src = readFileSync("index.html", "utf8");
const body = src.replace(/<link rel="preconnect"[^>]*>\n?/g, "")
  .replace(/<link rel="stylesheet" href="https:\/\/fonts\.googleapis\.com[^>]*>/, '<link rel="stylesheet" href="fonts/fonts.css">');

const webAppHead = `<link rel="manifest" href="manifest.webmanifest">
<link rel="apple-touch-icon" href="icons/icon-180.png">
<link rel="icon" type="image/png" href="icons/icon-192.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Flip Rush">
<meta name="theme-color" content="#0b0d11">
<meta name="description" content="Buy under market. Sell into the hype. Make rent before the bell.">`;

const registerWorker = `<script>
if ("serviceWorker" in navigator) addEventListener("load", () => navigator.serviceWorker.register("sw.js").catch(() => {}));
</script>`;

const page = (webApp) => `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
<meta name="color-scheme" content="light dark">
${webApp ? webAppHead + "\n" : ""}<style>
html{box-sizing:border-box;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}
body{margin:0}
img{max-width:100%}
[hidden]{display:none!important}
</style>
${body}
${webApp ? registerWorker + "\n" : ""}</html>
`;

function fresh(dir) {
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  cpSync("app-src/fonts", `${dir}/fonts`, { recursive: true });
  cpSync("app-src/vendor", `${dir}/vendor`, { recursive: true });
}

// Native app bundle
fresh("www");
writeFileSync("www/index.html", page(false));

// Home-screen web app for GitHub Pages
fresh("docs");
const html = page(true);
writeFileSync("docs/index.html", html);
cpSync("app-src/web-icons", "docs/icons", { recursive: true });
writeFileSync("docs/.nojekyll", "");
writeFileSync("docs/manifest.webmanifest", JSON.stringify({
  name: "Flip Rush",
  short_name: "Flip Rush",
  description: "Buy under market. Sell into the hype. Make rent before the bell.",
  start_url: "./",
  scope: "./",
  display: "standalone",
  orientation: "portrait",
  background_color: "#0b0d11",
  theme_color: "#0b0d11",
  icons: [
    { src: "icons/icon-192.png", sizes: "192x192", type: "image/png" },
    { src: "icons/icon-512.png", sizes: "512x512", type: "image/png" },
    { src: "icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" }
  ]
}, null, 2));
// Cache name changes whenever the game changes, so phones pick up new versions.
const version = createHash("sha256").update(html).digest("hex").slice(0, 10);
const files = ["./", "index.html", "manifest.webmanifest", "fonts/fonts.css", "fonts/Archivo.woff2",
  "fonts/GeistMono.woff2", "icons/icon-180.png", "icons/icon-192.png", "icons/icon-512.png"];
writeFileSync("docs/sw.js", `const CACHE = "fliprush-${version}";
const FILES = ${JSON.stringify(files)};
self.addEventListener("install", e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES))); self.skipWaiting(); });
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});
// Network first so updates show up right away; cached copy when offline. Same-origin only.
self.addEventListener("fetch", e => {
  if (e.request.method !== "GET" || new URL(e.request.url).origin !== location.origin) return; // never cache live market data
  const nav = e.request.mode === "navigate";
  e.respondWith(fetch(e.request, nav ? { cache: "no-store" } : undefined).then(r => {
    if (r.ok && r.type === "basic") { const copy = r.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); }
    return r;
  }).catch(() => caches.match(e.request, { ignoreSearch: true })
    .then(m => m || (nav ? caches.match("index.html") : undefined))
    .then(m => m || Response.error())));
});
`);

console.log("Built www/ (native apps) and docs/ (home-screen web app)");

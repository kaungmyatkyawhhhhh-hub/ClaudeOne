const CACHE = "fliprush-c4941a33e3";
const FILES = ["./","index.html","manifest.webmanifest","fonts/fonts.css","fonts/Archivo.woff2","fonts/GeistMono.woff2","icons/icon-180.png","icons/icon-192.png","icons/icon-512.png"];
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

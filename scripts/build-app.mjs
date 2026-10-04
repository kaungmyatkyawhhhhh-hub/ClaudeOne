// Builds www/ (the folder Capacitor packages into the iOS/Android apps) from index.html.
// index.html stays the single source of truth for the game; this wraps it in a full
// document, swaps Google Fonts for bundled copies so the app works offline, and adds
// safe-area padding for notched phones.
import { readFileSync, writeFileSync, mkdirSync, cpSync, rmSync } from "node:fs";

const src = readFileSync("index.html", "utf8");
const body = src.replace(/<link rel="preconnect"[^>]*>\n?/g, "")
  .replace(/<link rel="stylesheet" href="https:\/\/fonts\.googleapis\.com[^>]*>/, '<link rel="stylesheet" href="fonts/fonts.css">');

const doc = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
<meta name="color-scheme" content="light dark">
<style>
html{box-sizing:border-box;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}
body{margin:0}
img{max-width:100%}
[hidden]{display:none!important}
</style>
${body}
</html>
`;

rmSync("www", { recursive: true, force: true });
mkdirSync("www", { recursive: true });
writeFileSync("www/index.html", doc);
cpSync("app-src/fonts", "www/fonts", { recursive: true });
console.log("Built www/index.html");

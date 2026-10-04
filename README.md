# Flip Rush

An open-world reselling game for phones. Walk around town, flip items at the Market (tap to buy, hold to lowball, sell to collectors, take offers, win auctions), lift at the Gym for strength, sleep at Home or grab drinks at the Café to refill energy, buy upgrades at the Mall, and rebirth at the Temple for a permanent money multiplier. No rent, no game over, and progress saves automatically.

## Project layout

| Path | What it is |
| --- | --- |
| `index.html` | The whole game. Edit this file to change the game. |
| `scripts/build-app.mjs` | Builds `www/` (native app bundle) and `docs/` (home-screen web app for GitHub Pages) from `index.html`. |
| `docs/` | Built home-screen web app served by GitHub Pages. Commit it after `npm run build`. |
| `app-src/fonts/` | Bundled Archivo and Geist Mono fonts. |
| `app-src/assets/` | Source art for the app icon and splash screen. |
| `ios/` | Xcode project (Capacitor, Swift Package Manager, no CocoaPods). |
| `android/` | Android Studio project (Capacitor). |
| `capacitor.config.json` | App name, bundle ID (`com.fliprush.game`) and native settings. |

## Play in a browser

Live at **https://kaungmyatkyawhhhhh-hub.github.io/ClaudeOne/** once GitHub Pages is turned on (Settings → Pages → Deploy from a branch → this branch, `/docs` folder).

On iPhone, open that link in Safari, tap Share → Add to Home Screen. It installs with its own icon, opens full screen and works offline.

## After changing the game

```sh
npm install        # first time only
npm run sync       # rebuild www/ and docs/, copy www/ into ios/ and android/
```

If you change the icon art in `app-src/assets/`, run `npm run assets` and then `npm run sync`.

## Release on the Apple App Store

You need a Mac with the latest Xcode, Node.js 22+, and an Apple Developer account ($99/year, https://developer.apple.com/programs/).

1. `npm install`, then `npm run ios`. This builds and opens the project in Xcode.
2. In Xcode, select the **App** target, open **Signing & Capabilities**, and pick your team. If Xcode says the bundle ID `com.fliprush.game` is taken, change it to something unique, like `com.yourname.fliprush`.
3. Test on your iPhone: plug it in, select it at the top of Xcode, and press Run.
4. In App Store Connect (https://appstoreconnect.apple.com), create a new app with the same bundle ID. Fill in the description, screenshots (6.9" and 6.5" iPhone), privacy details ("Data Not Collected"), and age rating.
5. In Xcode, choose **Product → Archive**, then **Distribute App → App Store Connect → Upload**.
6. Back in App Store Connect, attach the build to your version and **Submit for Review**. Review usually takes 1–3 days.

## Release on Google Play

You need Android Studio, Node.js 22+, and a Google Play developer account ($25 one time, https://play.google.com/console). Any Windows, Mac or Linux computer works.

1. `npm install`, then `npm run android`. This builds and opens the project in Android Studio.
2. Test on your phone: enable USB debugging, plug it in, and press Run.
3. Choose **Build → Generate Signed App Bundle / APK → Android App Bundle** and create a new upload key. Back up the key file and its password; you need them for every future update.
4. In Play Console, create the app, fill in the store listing, content rating and data safety form (no data collected), and upload the `.aab` from `android/app/release/`.
5. New personal developer accounts must run a closed test with at least 12 testers for 14 days before going public. Then submit for production.

## Store notes

- Item names in the game are made up on purpose. App stores reject apps that use real brands (sneaker, card, watch or toy brands) without permission.
- The game collects no data and has no ads or purchases, so the privacy forms are simple.

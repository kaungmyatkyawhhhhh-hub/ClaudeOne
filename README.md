# ClaudeOne

Roblox game scripts, synced into Roblox Studio with [Rojo](https://rojo.space).

Code lives here in GitHub, so Claude cloud sessions can write and push scripts,
and you pull them onto your PC where Rojo syncs them live into Studio.

## Layout

| Folder        | Shows up in Studio as                          | Use for                         |
|---------------|------------------------------------------------|---------------------------------|
| `src/server`  | `ServerScriptService > RojoServer`             | Server scripts (`.server.luau`) |
| `src/client`  | `StarterPlayer > StarterPlayerScripts > RojoClient`| Client scripts (`.client.luau`) |
| `src/shared`  | `ReplicatedStorage > RojoShared`               | ModuleScripts (`.luau`)         |

File names decide the script type:

- `Name.server.luau` → Script
- `Name.client.luau` → LocalScript
- `Name.luau` → ModuleScript
- a folder with `init.luau` (or `init.server.luau` / `init.client.luau`) → that script, with the folder's other files as its children

Rojo only manages the `RojoServer`, `RojoClient` and `RojoShared` folders above.
Everything else in your place (existing scripts, parts, UI built in Studio) is
left alone. **Rojo fully controls those three folders**: anything you put inside
them by hand in Studio is removed on the next sync, so keep hand-made scripts
elsewhere (e.g. your existing `Server` / `Shared` folders).

The Rojo version in `rokit.toml` must match the Rojo Studio plugin version,
otherwise connecting fails with a `protocolVersion` error.

## One-time setup (Windows)

1. Install [Git](https://git-scm.com/download/win) and clone this repo:
   ```
   git clone https://github.com/kaungmyatkyawhhhhh-hub/ClaudeOne.git
   cd ClaudeOne
   ```
2. Install [Rokit](https://github.com/rojo-rbx/rokit) (toolchain manager), then in the repo folder:
   ```
   rokit install
   ```
   This installs the Rojo version pinned in `rokit.toml`.
3. Install the Rojo Studio plugin:
   ```
   rojo plugin install
   ```
   (or get "Rojo" from the Roblox Creator Store), then restart Studio.

## Every time you work

1. Get the latest code (including anything a cloud session pushed):
   ```
   git pull
   ```
   Cloud sessions push to their own branch; switch to it first with
   `git checkout <branch-name>` or merge its pull request on GitHub.
2. Start the sync server:
   ```
   rojo serve
   ```
3. In Studio, open the **Rojo** plugin and click **Connect**. Changes to files
   now appear in Studio instantly.

**Save your place in Studio as usual** — Rojo syncs code, but the place file
(`.rbxl`) is still where your builds, parts and UI live.

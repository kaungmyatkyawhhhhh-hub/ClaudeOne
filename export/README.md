# Place export (read-only snapshot)

- `GymArc.rbxlx`: the place saved from Studio (binary format despite the name).
- `scripts/`: every script in the place, as `.luau` files, mirroring Explorer.
- `TREE.md`: where everything sits in the place.

Rojo does **not** sync this folder. Editing these files changes nothing in
Studio; it's here so cloud sessions can read the real game code.

## Refreshing it
After changing things in Studio, save the place again over
`export/GymArc.rbxlx` (File → Save to File As…), then commit and push it and ask
a cloud session to "re-extract the export".

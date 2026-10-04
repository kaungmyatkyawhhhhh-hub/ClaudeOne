# Tests

Logic tests for the shared config modules (quests, gains, economy, social, legends, show-off, machines,
seasons). They run the real `src/` ModuleScripts outside Roblox with [Lune](https://lune-org.github.io/docs),
using a small fake `script` tree (`harness.luau`). They can't test anything that needs Roblox services.

Run from the repo root:

```
rokit install          # once: installs Rojo and Lune from rokit.toml
lune run tests/run_all # every test file
lune run tests/quests  # one file
```

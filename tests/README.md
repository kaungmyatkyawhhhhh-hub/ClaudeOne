# Tests

Logic tests for the shared config modules (quests, gains, economy, social, legends, show-off, machines,
seasons). They run the real `src/` ModuleScripts outside Roblox with [Lune](https://lune-org.github.io/docs),
using a small fake `script` tree (`harness.luau`). They can't test anything that needs Roblox services.

Needs Lune 0.10 installed (download it from its GitHub releases page). Run from the repo root:

```
lune run tests/run_all # every test file
lune run tests/quests  # one file
```

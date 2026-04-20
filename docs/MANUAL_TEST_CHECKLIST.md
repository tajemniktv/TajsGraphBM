# Manual Test & Regression Checklist

This checklist is meant to keep **TajsGraphBM** changes grounded in real in-game validation.
It is intentionally lightweight and tuned for a UE4SS Lua mod rather than a large application repo.

## Before testing

Confirm the following first:

- BetterMart launches normally without the mod
- UE4SS is installed in the expected location
- BetterMart-specific signatures/config are in place
- `enabled.txt` exists for the mod
- You know which TajsGraphBM commit or branch you are testing
- You are not mixing in unrelated local tweaks unless the test explicitly requires them

---

## Minimum sanity pass

Run this small pass for most code changes:

1. Launch BetterMart
2. Load into a save
3. Open the in-game console
4. Run `tajsgraph.status`
5. Run `tajsgraph.apply`
6. Run `tajsgraph.status` again
7. Confirm the scene changes in an expected way or, if not, note that explicitly
8. Watch for console errors, unexpected spam, or missing command handling

Record:

- whether commands are recognized
- whether anything visibly changes
- whether errors appear in logs/console
- whether status counters move in a way that makes sense

---

## Suggested regression areas

### 1) Command flow

Check:

- `tajsgraph.apply`
- `tajsgraph.status`
- `tajsgraph.rebaseline`
- any newly added commands for the feature being tested

Look for:

- command not recognized
- command recognized but no-op with confusing output
- duplicated command registration after reload/hot reload
- unexpected state carried across reloads

### 2) Spotlight/runtime patching

Check:

- a scene with several interior lights
- a scene with obvious authored spotlight behavior
- whether patched lights stay visually stable after re-running apply

Look for:

- overbright or dead lights
- weird cone angles
- broken visibility/enabled state
- mobility-related artifacts or failures
- destroyed/stale cached objects causing errors

### 3) Render/Lumen/MegaLights compatibility

Check:

- whether renderer/postprocess/world writes appear to have effect
- whether fallback logic still works when some properties are unsupported

Look for:

- no-op writes with misleading success output
- sudden lighting/shadow regressions after apply
- settings that only take effect after extra refresh steps

### 4) Post-apply VSM refresh behavior

This mod currently has special handling around VSM refresh behavior.

Check:

- whether a manual `tajsgraph.apply` appears to need an extra refresh/reload behavior to look correct
- whether shadows update immediately or only after fallback logic

Look for:

- stale shadows
- scene only correcting itself after a second pass
- shadow map flicker or obvious instability

### 5) Startup / scheduled / spawn-related behavior

If the change touches scheduling, startup, or spawned-object patch paths, also check:

- fresh launch behavior
- re-entering/loading into a save
- object spawn/recovery path if applicable
- whether background logic over-applies or spams

Look for:

- repeated apply storms
- missed spawned lights
- background logic undoing manual state
- state not surviving expected transitions

---

## Performance sanity check

Not every change needs benchmarking, but changes that touch scanning, scheduling, render compatibility writes, or new light classes should at least get a basic perf sanity pass.

Check:

- whether first apply feels noticeably heavier
- whether repeated apply causes stutter
- whether logs become excessively spammy
- whether scene performance becomes obviously worse after patching

If something feels slower, note:

- map/scene
- approximate object/light density
- whether slowdown is one-time or repeated
- whether the issue disappears after restart

---

## What to attach to PRs / issues

When possible, include:

- TajsGraphBM commit/branch tested
- BetterMart version/build
- UE4SS version/tag
- signature/config source
- exact console commands used
- before/after screenshots for visual changes
- relevant console or log snippets
- whether this was tested on a clean launch

---

## PR author checklist

Before opening or merging a PR, try to confirm:

- the Lua smoke check passes in CI
- commands still register and run as expected
- no obvious regressions in the minimum sanity pass
- docs/comments were updated if the behavior or workflow changed
- the PR explains any limitations or untested paths honestly

---

## Maintainer note

This checklist should evolve with the mod.
If a new runtime subsystem or new command family is added, update this document so contributors test the right things instead of guessing.

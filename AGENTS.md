# Guidelines for AI Agents

You are working on a UE4SS Lua mod for BetterMart called `TajsGraphBM`.

This file defines how agents should approach changes in this repository.
The goal is not just to "make it work", but to keep the mod stable, debuggable, update-tolerant, and easy to iterate on after game or UE4SS changes.

## Game Project

Engine: Unreal Engine 5.7.4
Modding Framework: UE4SS
Game: BetterMart
UE4SS Logs file: `BetterMart/Binaries/Win64/ue4ss/UE4SS.log`

## Project identity

**TajsGraphBM** is a UE4SS Lua mod for BetterMart focused on graphing-related functionality, experimentation, and UI/UX improvements around graph display, graph logic, or graph-adjacent tooling.

The mod should remain:
- compatible with UE4SS Lua mod workflows,
- easy to debug when BetterMart updates break hooks,
- conservative in how it touches game systems,
- structured so graph logic, hook logic, UI logic, and compatibility logic are not unnecessarily tangled.

## Primary target

Primary target:
- Files under `TajsGraphBM/**`

Unless explicitly requested, avoid changing:
- unrelated mods
- shared UE4SS install/runtime files
- generated files
- third-party code
- game assets outside the mod's own scope

## Core principles

When working in this repo, agents should optimize for:

1. Small, reversible diffs over broad rewrites.
2. Stability over cleverness.
3. Clear compatibility boundaries.
4. Safe runtime behavior in the face of missing objects, timing differences, or game updates.
5. Readability and debuggability over "magic."
6. Preserving existing style unless there is a strong reason to improve it.

## UE4SS + Lua guardrails

- Keep changes specific to UE4SS Lua mod behavior.
- Prefer plain Lua and existing UE4SS facilities over inventing custom frameworks.
- Avoid unnecessary abstraction layers.
- Preserve existing naming style, control flow style, and file layout unless the current structure is actively harmful.

## BetterMart / game-integration guardrails

- Assume BetterMart updates may break hooks, object paths, class names, or timing assumptions.
- Do not hardcode fragile assumptions in multiple places.
- Centralize version-sensitive or game-sensitive values when practical.
- If a hook or object lookup may fail after an update, fail softly and log clearly instead of causing cascading runtime errors.
- Prefer compatibility shims or isolated fallback logic over scattering patch logic across many files.
- Do not silently swallow important failures; log them with enough context to debug later.

## Runtime safety rules

- Never assume an object exists just because it existed in a previous session/build.
- Guard object access carefully.
- Treat startup, map load, and menu/game transitions as unsafe timing zones.
- Avoid per-tick heavy work unless it is truly necessary.
- Avoid log spam inside hot paths.
- Avoid repeated expensive lookups if results can be cached safely.
- If caching is added, document cache invalidation assumptions.
- Prefer explicit nil checks and defensive guards over optimistic chaining.
- If a risky call may fail, wrap it safely and surface useful diagnostics.

## Architecture expectations

Prefer separating concerns into distinct layers when possible:

- **Hook / integration layer**  
  UE4SS hooks, object discovery, registration, lifecycle entry points.

- **Graph logic layer**  
  actual graph behavior, calculations, transformations, or feature logic.

- **UI / rendering layer**  
  labels, widgets, user-facing visuals, formatting, toggles.

- **Config / state layer**  
  settings, feature flags, persistent options, debug toggles.

- **Compatibility / patch layer**  
  version-sensitive handling, object path overrides, fallback behavior.

Do not mix all of these into one giant file unless the repo is truly tiny and the user explicitly wants that.

## Change strategy

When implementing a request:

1. First understand how the current code works.
2. Prefer editing existing code over replacing it.
3. Match existing patterns unless they are the source of the bug/problem.
4. If the architecture is causing repeated breakage, propose a structural fix instead of another band-aid.
5. If a request points to existing code as a reference, follow the reference more than the prose description.

## Debugging rules

When debugging:

- Work from actual error logs or observed behavior first.
- Do not invent theories before checking the relevant code path.
- Trace the failure from hook entry to effect.
- Identify whether the issue is:
  - timing/lifecycle,
  - object lookup/pathing,
  - nil access,
  - bad assumptions about game state,
  - UI/update loop behavior,
  - BetterMart/UE4SS version drift.

After fixing a bug, explain:
- why it happened,
- why the fix works,
- what would prevent similar bugs in the future.

## Performance rules

- Be careful with anything that can run frequently.
- Do not introduce unnecessary polling if an event/hook-based approach is possible.
- Avoid allocating or formatting large strings repeatedly in hot paths.
- Keep debug logging lightweight and preferably configurable.
- Prefer feature flags or debug toggles for noisy instrumentation.

## Logging conventions

- Use consistent log prefixes, for example `[TajsGraphBM]`.
- Logs should be short but informative.
- Error logs should say what failed and where.
- Compatibility-related logs should mention the missing hook/object/class/path explicitly.
- Remove temporary spammy debug logs before calling work finished, unless the user asked to keep them.

## Config expectations

If adding settings/config:
- keep names explicit,
- group related settings together,
- provide safe defaults,
- avoid adding config for things that do not need to be user-tunable,
- document what each setting does.

## Validation checklist

After any change, do as many of these as possible:

1. Run a Lua syntax sanity check, if possible.
2. Re-read modified files for broken identifiers, bad requires, or mismatched names.
3. Check that object access is guarded where needed.
4. Check that new logging is not spammy.
5. Check that new logic will not explode if a hook or object lookup fails.
6. Check for obvious hot-path performance issues.
7. Update comments/docs if behavior or structure changed.

## Agent behavior expectations

When working in this repo, agents should:

1. Validate assumptions from current code, not stale docs or memory.
3. Keep game/version-sensitive logic isolated when practical.
4. Avoid "just make it work" hacks that make future BetterMart or UE4SS updates harder to recover from.
5. Explain tradeoffs when there is more than one reasonable implementation.
6. State what was actually verified.
7. If a fix fails twice, step back and re-evaluate the mental model instead of brute-forcing.
8. When architecture is flawed, propose a cleaner structure instead of stacking band-aids.
9. Preserve repository consistency unless the user explicitly wants a broader cleanup.
10. Do not touch unrelated files just because they could also be improved.

## What not to do

- Do not rewrite the whole mod without a strong reason.
- Do not add a framework where simple Lua would do.
- Do not scatter compatibility hacks across random files.
- Do not assume BetterMart internals are stable across updates.
- Do not leave behind temporary debug scaffolding without saying so.
- Do not fake certainty when runtime behavior is not actually verified.

## Documentation touchpoints

If relevant, check and update:
- `README.md`
- `AGENTS.md`
- any config/example config files
- any compatibility notes
- comments near fragile hooks or game-specific assumptions
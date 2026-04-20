# Known Good Versions / Compatibility

This file is a lightweight compatibility reference for **TajsGraphBM**.
It is meant to reduce support churn by documenting combinations that are known to work, partially work, or are still unverified.

## How to use this file

When reporting bugs or validating a change, include:

- BetterMart version/build
- TajsGraphBM commit or release
- UE4SS version/tag
- Signature/config source
- Whether you used the repo `Engine.ini` as-is or with local edits
- Which console commands were used (`tajsgraph.apply`, `tajsgraph.status`, etc.)

If a setup is not listed here, that does **not** automatically mean it is broken. It just means it has not been documented yet.

---

## Status meanings

- **Known good** — expected to work for normal testing
- **Partially verified** — works for some paths, but not fully trusted yet
- **Unverified** — not tested enough to rely on
- **Known problematic** — has known breakage, instability, or missing functionality

---

## Compatibility matrix

### BetterMart

| Component | Version / source | Status | Notes |
|---|---|---:|---|
| BetterMart | Current public build used during active development | Partially verified | Replace with exact build numbers as they are confirmed. |

### TajsGraphBM

| Component | Version / source | Status | Notes |
|---|---|---:|---|
| TajsGraphBM | `main` branch (early WIP) | Partially verified | Runtime patching and command flow are still evolving. |

### UE4SS

| Component | Version / source | Status | Notes |
|---|---|---:|---|
| UE4SS | `experimental-latest` | Partially verified | This is the currently documented requirement in the README. |

### BetterMart signatures / config

| Component | Version / source | Status | Notes |
|---|---|---:|---|
| BetterMart custom game config | `tajemniktv/RE-UE4SS` `feat/bettermartconfig` | Partially verified | This is the currently documented setup source in the README. |

---

## Recommended bug report fields

When opening a bug report, include at minimum:

- BetterMart version/build
- TajsGraphBM commit or release
- UE4SS version/tag
- Signature/config source
- GPU + driver version
- Whether `tajsgraph.apply` changed the scene visually
- Whether the issue still happens after a fresh launch
- Whether the issue seems related to:
  - spotlight tuning
  - runtime compatibility writes
  - renderer/Lumen/MegaLights writes
  - post-apply VSM refresh behavior

---

## Notes for maintainers

Update this file whenever one of the following changes:

- BetterMart receives a patch that affects runtime hooks or rendering behavior
- UE4SS requirement changes
- Signature/config source changes
- A release bundle becomes the preferred installation path
- A previously unstable combination becomes reliable enough to recommend

If exact versions are not known yet, prefer writing **honest placeholders** rather than fake certainty.

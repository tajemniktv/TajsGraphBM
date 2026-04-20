# TajsGraphBM ImGui UI Module (C++)

This folder contains the native C++ source for the UE4SS ImGui module (`TajsGraphBMNative`).

The Lua mod (`TajsGraphBM`) remains the runtime owner.  
This C++ module only provides UI controls and sends `tajsgraph.ui.*` commands.

## Build Prerequisites

- A local `RE-UE4SS` source checkout
- CMake 3.22+
- Visual Studio 2022 (or another supported toolchain for UE4SS)

## Build

Preferred (from `Mods/TajsGraphBM` root):

```powershell
cmake --preset vs2026-game
cmake --build --preset build-vs2026-game
```

Post-build deploy target:

```text
../dlls/main.dll
```

Optional helper script (from mod root):

```powershell
.\build_native.ps1
```

Legacy compatibility wrapper (still works):

```powershell
.\build_cppui.ps1
```

Standalone configure from this `Native` folder is still supported:

```powershell
cmake -S . -B build -DTAJSGRAPHBM_STANDALONE=ON -DUE4SS_SRC_DIR="D:/path/to/RE-UE4SS"
cmake --build build --config Game__Shipping__Win64
```

No separate install step is needed for in-place workflow; build deploys directly into `TajsGraphBM/dlls/main.dll`.

## UI Behavior

- Tab name: `TajsGraphBM UI`
- Buttons: Apply, Rebaseline, Restore, Disable, Save, Reload, Reset Core, Status
- Core controls:
  - `spotlight_tune_enabled`
  - `spotlight_runtime_compat_enabled`
  - `enable_megalights`
  - `force_lumen_methods`
  - `force_lumen_compatibility`
  - `spotlight_intensity_multiplier`
  - `spotlight_attenuation_multiplier`
  - `megalights_shadow_method`
  - `lumen_scene_detail`
  - `lumen_diffuse_color_boost`
  - `lumen_skylight_leaking`

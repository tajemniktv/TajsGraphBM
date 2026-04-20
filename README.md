# Taj's Graphical Overhaul - BetterMart Edition

A UE4SS-based graphics mod / experiment for **BetterMart**.

> [!WARNING]
> This is currently very WIP / early-access / "use at your own risk" territory.
> I originally was not planning to share it yet, so the setup is not fully streamlined yet.
> Some things may be broken, incomplete, or require manual tweaking.

---

## What is this?

`Taj's Graphical Overhaul - BetterMart Edition` is a **UE4SS mod for BetterMart** focused on graphical tweaks / overrides.

At the moment, this repo contains the mod itself, but it also depends on:

- **UE4SS** itself
- **custom BetterMart signature/config files** for UE4SS

Because of that, installation currently involves files from multiple places.

---

## Requirements

### 1) BetterMart
You need the game installed normally.

### 2) Latest experimental UE4SS
Download the latest experimental UE4SS release here:

- [UE4SS experimental-latest](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest)

### 3) BetterMart-specific UE4SS config / signatures
Use the BetterMart config files from here:

- [BetterMart custom game config files](https://github.com/tajemniktv/RE-UE4SS/tree/feat/bettermartconfig/assets/CustomGameConfigs/BetterMart)

> [!NOTE]
> Technically, the **FName signature file may be the main thing required**, but for now I recommend using the full BetterMart config set from that folder just to avoid weird issues.

---

## Installation

## Step 1 - Install UE4SS into the game

Extract the downloaded UE4SS files into:

```text
BetterMart\Binaries\Win64
````

After that, your game folder should contain things like:

```text
BetterMart\Binaries\Win64\dwmapi.dll
BetterMart\Binaries\Win64\ue4ss\
```

---

## Step 2 - Copy the BetterMart UE4SS config files

From the BetterMart config repo/folder, copy the files into the correct UE4SS locations:

### Signature files

Put the signature files into:

```text
BetterMart\Binaries\Win64\ue4ss\UE4SS_Signatures
```

### UE4SS settings file

Put `UE4SS-settings.ini` directly into:

```text
BetterMart\Binaries\Win64\ue4ss
```

---

## Step 3 - Install this mod

Clone or download this repo into:

```text
BetterMart\Binaries\Win64\ue4ss\Mods\TajsGraphBM
```

So the final path should look like this:

```text
BetterMart
└── Binaries
    └── Win64
        ├── dwmapi.dll
        └── ue4ss
            ├── UE4SS-settings.ini
            ├── UE4SS_Signatures
            └── Mods
                └── TajsGraphBM
                    ├── Engine.ini
                    ├── enabled.txt
                    ├── Scripts
                    └── ...
```

> [!IMPORTANT]
> The mod folder itself should be named **`TajsGraphBM`**.

Also make sure this file exists:

```text
BetterMart\Binaries\Win64\ue4ss\Mods\TajsGraphBM\enabled.txt
```

---

## How to use

1. Launch the game
2. Load into a save file
3. Open the in-game console with the **`~`** key
4. Run commands as needed:

- `tajsgraph.apply` — apply tweaks and re-enable runtime if it was disabled.
- `tajsgraph.rebaseline` — update the **current apply baseline** from live values (does not overwrite original pre-mod snapshots).
- `tajsgraph.restore` — restore captured original pre-mod spotlight/runtime values, then keep runtime disabled until explicit apply.
- `tajsgraph.disable` — immediately restore and disable automatic re-application for this session.
- `tajsgraph.status` — print current counters and disabled state.
- `tajsgraph.ui.get <key>` — print current config value for a known key.
- `tajsgraph.ui.set <key> <value>` — update an in-memory config value immediately.
- `tajsgraph.ui.apply` — apply current in-memory config without restarting the mod.
- `tajsgraph.ui.reload` — reload `user_config.lua` from disk and apply immediately.
- `tajsgraph.ui.save` — persist current in-memory config to `user_config.lua`.
- `tajsgraph.ui.reset_core` — reset core UI keys to defaults, then apply.
- `tajsgraph.ui.status` — print core config values and runtime counters.

`tajsgraph apply`, `tajsgraph rebaseline`, `tajsgraph status`, `tajsgraph restore`, and `tajsgraph disable` are accepted in space form; underscore aliases are also accepted as `tajsgraph_apply`, `tajsgraph_rebaseline`, `tajsgraph_status`, `tajsgraph_restore`, and `tajsgraph_disable`.

The UI commands also support space form:

- `tajsgraph ui get <key>`
- `tajsgraph ui set <key> <value>`
- `tajsgraph ui apply`
- `tajsgraph ui reload`
- `tajsgraph ui save`
- `tajsgraph ui reset_core`
- `tajsgraph ui status`

---

## User config file

The mod now supports a mod-local settings file:

```text
BetterMart\Binaries\Win64\ue4ss\Mods\TajsGraphBM\user_config.lua
```

Format:

```lua
return {
    spotlight_tune_enabled = true,
    spotlight_intensity_multiplier = 0.9,
    enable_megalights = true,
}
```

If the file is missing, defaults are used. Invalid keys/types are sanitized through `config.normalize`.

---

## Optional ImGui UI tab (C++ module)

ImGui tab support is provided by an optional companion C++ mod source in:

```text
BetterMart\Binaries\Win64\ue4ss\Mods\TajsGraphBM\Native
```

In this repository layout, Lua and C++ live in the same mod folder (`TajsGraphBM`).
The built C++ artifact is deployed in-place to:

```text
BetterMart\Binaries\Win64\ue4ss\Mods\TajsGraphBM\dlls\main.dll
```

### In-place build (mod root as entry point)

From:

```text
BetterMart\Binaries\Win64\ue4ss\Mods\TajsGraphBM
```

Run:

```powershell
cmake --preset vs2026-game
cmake --build --preset build-vs2026-game
```

Or use helper script:

```powershell
.\build_native.ps1
```

Lint/intellisense preset (generates `compile_commands.json` for clangd/cpptools):

```powershell
.\build_native.ps1 -Preset ninja-dev
```

Output:

```text
BetterMart\Binaries\Win64\ue4ss\Mods\TajsGraphBM\compile_commands.json
```

When using VS2026 preset, the script now syncs lint database automatically:

- prefers `.build\vs2026\compile_commands.json` (when generated),
- otherwise falls back to `.build\ninja-dev\compile_commands.json` (if Ninja is available),
- and writes unified output to `.\compile_commands.json`.

Default RE-UE4SS source path used by presets:

```text
..\..\RE-UE4SS
```

If your RE-UE4SS path differs, override `UE4SS_SRC_DIR` during configure.

### VSCode / Visual Studio usage

VSCode:

1. Install `CMake Tools` extension.
2. Open folder: `BetterMart\Binaries\Win64\ue4ss\Mods\TajsGraphBM`.
3. Select configure preset `vs2026-game` (or `ninja-game`).
4. Build preset `build-vs2026-game` (or `build-ninja-game`).

Visual Studio 2022:

1. Open `Developer PowerShell` in `TajsGraphBM` folder.
2. Run:
   - `cmake --preset vs2026-game`
3. Open generated solution:
   - `.\.build\vs2022\TajsGraphBMWorkspace.sln`
4. Build configuration:
   - `Game__Shipping__Win64`

VSCode linting notes:

1. Open folder `BetterMart\Binaries\Win64\ue4ss\Mods\TajsGraphBM`.
2. Run `.\build_native.ps1 -Preset vs2026-game` at least once (or `ninja-dev` directly if you prefer).
3. `.vscode/settings.json` is preconfigured to use:
   - `compile_commands.json` in mod root for clangd/cpptools fallback.
   - CMake Tools configuration provider for IntelliSense from active preset.
   - `Scripts`, `luastubs`, `../shared/types`, and `../../UE4SS_Signatures` for Lua language server.
4. Optional engine reference include path is pre-added:
   - `..\..\..\..\..\..\UE_5.7\Engine\Source`
   Keep this as read-only reference.

Build/install instructions are in:

```text
BetterMart\Binaries\Win64\ue4ss\Mods\TajsGraphBM\Native\README.md
```

---

## Current status

This project is mid-refactor / early stage, so please expect ~~some~~ A LOT of jank.

* Some of the basics **shouldTM** work
* Not everything is finalized
* Documentation and setup will be improved later (maybe)

---

## Credits

* [BetterMart](https://store.steampowered.com/app/3498270/Better_Mart_Simulator/) developers and [Exanticx Studio](https://store.steampowered.com/curator/45754312)
* [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS)
* UE5.7.4 signature files from... (someone, I will look you up soonTM!)
* [Taj's Graphical Overhaul (But for Satisfactory;))](https://github.com/tajemniktv/TajsGraph)
* Everyone patient enough to test this janky setup before it is polished! :)

---

## Disclaimer

This is an unofficial mod project for BetterMart. 
Not affiliated nor endorsed by game developers nor Exanticx Studio.
Use at your own risk. Always backup files, saves or things you care about. 

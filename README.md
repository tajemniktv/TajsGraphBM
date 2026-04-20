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
- `tajsgraph.disable` — immediate restore + disable automatic re-application for this session.
- `tajsgraph.status` — print current counters and disabled state.

`tajsgraph restore` / `tajsgraph disable` (space form) and underscore aliases are also accepted.

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

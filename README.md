# RamBar

A tiny macOS menu bar app for RAM usage + system wattage.

![RamBar Logo](assets/rambar-logo-percent-reference.jpg)

## Tested Platform

- Tested only on: `macOS 26.3 (Build 25D125)`
- Tested on Apple Silicon
- Wattage source: [`macmon`](https://github.com/vladkens/macmon)

## Features

- Menu bar readout:
  - watts (`W`) on the left
  - RAM usage bar in the center
  - RAM usage percent on the right
- Dropdown menu:
  - `Force Refresh`
  - `Open mac mon in Terminal`
  - `Start on Startup` toggle with checkmark
  - live `RAM: used/total` line
  - `Settings` section with refresh interval checkmarks:
    - `1`, `3`, `5`, `10`, `30`, `60` second refresh
  - `Non-system RAM Limit` section with checkmarked choices:
    - `75%`, `85%`, `90%`
  - selecting a non-system limit also triggers a terminal command hook
  - selected non-system limit command is re-sent every 15 minutes while app is running
  - `Close RamBar`
- Default refresh interval: `10 seconds`
- Selected refresh interval is persisted
- Runs as a normal app (no Terminal window required)

## Easy Install (Drag to Applications)

1. Download `RamBar-Installer.dmg` from the latest GitHub release.
2. Open the DMG.
3. Drag `RamBar.app` into `Applications`.
4. Launch `RamBar` from Applications or Launchpad.

Release page: [https://github.com/daffi-vibecoding/rambar/releases](https://github.com/daffi-vibecoding/rambar/releases)

## Build Installer Locally

```bash
./scripts/make_installer.sh
```

Outputs:
- `dist/RamBar-Installer.dmg`
- `dist/build/RamBar.app`

## Runtime Footprint (Estimated)

Measured on `macOS 26.3` over a 45-second sample window.

- CPU average: `~0.19%`
- CPU max observed spike: `~6.8%`
- RAM (RSS) average: `~47 MB`
- RAM observed range: `~24 MB` to `~48 MB`

Values vary by hardware and refresh interval.

## Attribution

- Uses [`macmon`](https://github.com/vladkens/macmon) for power metrics.
- Vibe-coded in Codex in about **30 minutes**.

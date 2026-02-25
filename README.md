# RamBar

A tiny macOS menu bar monitor for RAM usage and system wattage.

## Tested Platform

- Tested only on: `macOS 26.3 (Build 25D125)`
- Apple Silicon machine
- Dependency used for watts: [`macmon`](https://github.com/vladkens/macmon)

No guarantees yet for other macOS versions/chipsets until broader testing is done.

## Features

- Menu bar display with:
  - live **system watts** on the left
  - **RAM usage bar** in the center
  - **RAM %** on the right
- Dropdown actions:
  - `Force Refresh`
  - `Open mac mon in Terminal`
  - `Start on Startup` (checkmark toggle)
  - `RAM: used/total` live line
  - `Settings` refresh presets with checkmark selection:
    - 1s, 3s, 5s, 10s, 30s, 60s
  - `Close RamBar`
- Default refresh interval: `10s`
- Persists selected refresh interval across launches
- Designed to survive terminal close (`SIGHUP` ignored)

## Install

1. Install `macmon`:

```bash
brew install vladkens/tap/macmon
```

2. Build and run:

```bash
swift build
./.build/arm64-apple-macosx/debug/RamBar
```

Optional detached launch:

```bash
nohup ./.build/arm64-apple-macosx/debug/RamBar >/tmp/rambar.out 2>/tmp/rambar.err < /dev/null &
```

## Runtime Footprint (Estimated)

Measured on `macOS 26.3` over a 45-second sample window.

- Average CPU: `~0.19%`
- CPU spike max observed: `~6.8%` (short bursts during metric polling)
- Average RAM (RSS): `~47 MB`
- RAM range observed: `~24 MB` to `~48 MB`

These numbers vary by refresh interval and machine.

## Attribution

- Wattage data is read via [`macmon`](https://github.com/vladkens/macmon).
- This app was vibe-coded in Codex in about **30 minutes**.

# omarchy-rotate

Rotate your desktop background from a folder on a schedule, and switch between a
light and a dark theme at set times of day. Works on Omarchy 3.8.x today and is
packaged as an Omarchy quattro (4.x) shell plugin for after you upgrade.

## What it does

- **Background rotation** — every 2 hours by default (`30m`, `1h`, `4h`, `1d` …),
  and/or whenever the laptop boots or wakes from sleep. Only for the themes you
  choose: by default, any theme that has images in
  `~/.config/omarchy/backgrounds/<theme>/` (the folder `omarchy theme bg install` opens).
- **Theme schedule** — a light theme from `LIGHT_AT` and a dark theme from `DARK_AT`.
  If you change the theme by hand, it leaves you alone until the next switch time.

## Install

### Omarchy 3.8.x (now)

```bash
git clone https://github.com/DrakeMorrison/omarchy-rotate ~/Projects/omarchy-rotate
~/Projects/omarchy-rotate/install.sh
omarchy-rotate config      # edit the settings
omarchy-rotate status      # see what will happen next
```

`install.sh` symlinks the CLI into `~/.local/bin`, writes `~/.config/omarchy/rotate.conf`
(if missing), installs two omarchy hooks (`theme-set.d`, `post-boot.d`) and a systemd
user timer that runs a scheduling pass every 5 minutes. `./uninstall.sh` reverses it.

### Omarchy quattro (after the upgrade)

The repo root is a shell plugin (`manifest.json` + `Service.qml`, kind `service`):

```bash
omarchy plugin add https://github.com/DrakeMorrison/omarchy-rotate.git --enable
# or, from the local checkout:
omarchy plugin add ~/Projects/omarchy-rotate --enable
```

The shell service ticks every 5 minutes on its own, ticks with `--wake` when the
shell starts, restarts the interval when the theme changes, and adds IPC:

```bash
omarchy-shell rotate next     # change the background now
omarchy-shell rotate toggle   # flip light/dark
omarchy-shell rotate status
```

You can still run `install.sh` on quattro for the CLI symlink and config; the systemd
timer and hooks are then redundant but harmless (ticks are idempotent and serialized).

## Configuration

`~/.config/omarchy/rotate.conf` (bash syntax). Defaults:

```bash
BG_INTERVAL="2h"          # 30m, 1h, 2h, 4h, 1d ... | "wake" (boot/wake only) | "off"
BG_THEMES="auto"          # auto | "*" | "gruvbox catppuccin-latte"
BG_DIR=""                 # one folder of images for every rotating theme (optional)
BG_USER_ONLY="false"      # true = ignore the theme's built-in backgrounds
BG_ORDER="random"         # random | sequential
BG_ON_WAKE="true"         # fresh background on boot / wake from sleep

THEME_SCHEDULE="on"
THEME_LIGHT="flexoki-light"
THEME_DARK="flexoki-dark"
LIGHT_AT="07:00"
DARK_AT="19:00"

NOTIFY="false"
```

Intervals are clock-aligned: `2h` flips at 00:00, 02:00, 04:00 … local time;
`1d` flips at midnight (or on the first wake after it, with `BG_ON_WAKE`).

## CLI

```
omarchy-rotate status            what rotation and the schedule will do next
omarchy-rotate bg next           change the background now
omarchy-rotate bg list           images it would pick from for the current theme
omarchy-rotate theme toggle      flip between THEME_LIGHT and THEME_DARK
omarchy-rotate theme light|dark  switch to that side of the pair
omarchy-rotate theme sync        apply what the schedule says right now
omarchy-rotate tick [--wake]     one scheduling pass (what the timer runs)
omarchy-rotate config            edit the config
omarchy-rotate log               recent activity
omarchy-rotate enable|disable    start/stop the systemd timer
```

Bind something like `bind = SUPER SHIFT, T, exec, omarchy-rotate theme toggle` in
`~/.config/hypr/bindings.conf` if you want a hotkey.

## How it works

Everything is one idempotent `tick`. It records the last tick time (a gap longer
than `BG_WAKE_GAP` = 15 min means the machine was asleep → treat as wake), checks
whether the light/dark slot changed since the last applied slot, then checks
whether the background's clock bucket changed. State lives in
`~/.local/state/omarchy-rotate/`. Paths auto-detect the legacy layout
(`~/.config/omarchy/current`) versus quattro (`~/.local/state/omarchy/current`).

## Layout

```
bin/omarchy-rotate     the whole engine (bash)
Service.qml            quattro shell service: timer + theme watch + IPC
manifest.json          quattro plugin manifest (id: drake.rotate)
systemd/               user timer + service used on 3.8.x
install.sh             = omarchy-rotate install
```

# Komputah-Dots

Minimal dotfiles snapshot from `~/.config`.

Included:

- `hypr`
- `kitty`
- `mako`
- `nvim`
- `quickshell`
- `rofi`
- `waybar`

## The bar

`quickshell` is the primary bar and the notification daemon; `waybar` is kept
configured as a fallback and is what `Super+B` swaps to. Every panel — media,
audio, pomodoro, notifications, settings — hangs directly beneath the module
that opened it and drips out of the bar. `quickshell/CLAUDE.md` is the brief it
is all built against, and `quickshell/bar/Theme.qml` is the one place colours,
radii and timings are set; the palette itself follows the wallpaper through
`pywal`.

`quickshell/bar/bar-switch.sh` handles switching:

```bash
~/.config/quickshell/bar/bar-switch.sh status   # what is running
~/.config/quickshell/bar/bar-switch.sh toggle   # swap bars
~/.config/quickshell/bar/bar-switch.sh restart  # reload the quickshell bar
```

Excluded on purpose:

- backup files like `*.bak*`
- cache/generated files like `__pycache__`
- local-only Neovim files like `.neoconf.json`
- template/example files like `lua/plugins/example.lua`
- alternate/unused theme/layout files not used by the current setup

## Install on a fresh Arch setup

```bash
git clone git@github.com:Adithya010605/Komputah-Dots.git
cd Komputah-Dots
chmod +x install.sh
./install.sh
```

The installer:

- installs required pacman packages
- installs required AUR packages (`hyprshade`, `python-pywal16-git`, `quickshell`)
- backs up existing target configs
- copies the dotfiles into `~/.config`
- creates or reuses a wallpaper in `~/walls`
- rewrites the absolute paths baked into the QML (wal palette, pomodoro backend)
- generates the initial `pywal` cache
- enables `bluetooth.service` and `NetworkManager.service`
- bootstraps Neovim plugins

## Sync from live config

```bash
./sync-from-config.sh
```

## Push to GitHub

```bash
git add .
git commit -m "Initial dotfiles"
git push -u origin main
```

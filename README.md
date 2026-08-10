# Komputah-Dots

Minimal dotfiles snapshot from `~/.config`.

Included:

- `hypr`
- `kitty`
- `mako`
- `nvim`
- `rofi`
- `waybar`
- `quickshell` (glass panel with media, Pomodoro, and audio controls)

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

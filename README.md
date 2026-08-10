# Komputah-Dots

Minimal dotfiles snapshot from `/home/adi/.config`.

Included:

- `hypr`
- `kitty`
- `mako`
- `nvim`
- `rofi`
- `waybar`

Excluded on purpose:

- backup files like `*.bak*`
- cache/generated files like `__pycache__`
- local-only Neovim files like `.neoconf.json`
- template/example files like `lua/plugins/example.lua`
- alternate/unused theme/layout files not used by the current setup

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

#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_HOME="${SOURCE_HOME:-$HOME}"

mkdir -p \
  "$ROOT/.config/hypr" \
  "$ROOT/.config/kitty" \
  "$ROOT/.config/mako" \
  "$ROOT/.config/nvim/lua/config" \
  "$ROOT/.config/nvim/lua/plugins" \
  "$ROOT/.config/rofi/icons" \
  "$ROOT/.config/rofi/scripts" \
  "$ROOT/.config/rofi/themes" \
  "$ROOT/.config/quickshell" \
  "$ROOT/.config/waybar/scripts"

rm -rf \
  "$ROOT/.config/hypr" \
  "$ROOT/.config/kitty" \
  "$ROOT/.config/mako" \
  "$ROOT/.config/nvim" \
  "$ROOT/.config/rofi" \
  "$ROOT/.config/quickshell" \
  "$ROOT/.config/waybar"

mkdir -p \
  "$ROOT/.config/hypr" \
  "$ROOT/.config/kitty" \
  "$ROOT/.config/mako" \
  "$ROOT/.config/nvim/lua/config" \
  "$ROOT/.config/nvim/lua/plugins" \
  "$ROOT/.config/rofi/icons" \
  "$ROOT/.config/rofi/scripts" \
  "$ROOT/.config/rofi/themes" \
  "$ROOT/.config/quickshell" \
  "$ROOT/.config/waybar/scripts"

cp "$SOURCE_HOME/.config/hypr/hypridle.conf" "$ROOT/.config/hypr/"
cp "$SOURCE_HOME/.config/hypr/hyprland.lua" "$ROOT/.config/hypr/"
cp "$SOURCE_HOME/.config/hypr/hyprlock.conf" "$ROOT/.config/hypr/"
cp "$SOURCE_HOME/.config/hypr/hyprpaper.conf" "$ROOT/.config/hypr/"
cp -r "$SOURCE_HOME/.config/hypr/scripts" "$ROOT/.config/hypr/"
cp -r "$SOURCE_HOME/.config/hypr/shaders" "$ROOT/.config/hypr/"

cp "$SOURCE_HOME/.config/kitty/kitty.conf" "$ROOT/.config/kitty/"
cp "$SOURCE_HOME/.config/mako/config" "$ROOT/.config/mako/"

cp -r "$SOURCE_HOME/.config/quickshell/." "$ROOT/.config/quickshell/"

cp "$SOURCE_HOME/.config/nvim/init.lua" "$ROOT/.config/nvim/"
cp "$SOURCE_HOME/.config/nvim/lazy-lock.json" "$ROOT/.config/nvim/"
cp "$SOURCE_HOME/.config/nvim/lazyvim.json" "$ROOT/.config/nvim/"
cp "$SOURCE_HOME/.config/nvim/stylua.toml" "$ROOT/.config/nvim/"
cp "$SOURCE_HOME/.config/nvim/lua/config/"*.lua "$ROOT/.config/nvim/lua/config/"
cp "$SOURCE_HOME/.config/nvim/lua/plugins/colorscheme.lua" "$ROOT/.config/nvim/lua/plugins/"

cp "$SOURCE_HOME/.config/rofi/config.rasi" "$ROOT/.config/rofi/"
cp "$SOURCE_HOME/.config/rofi/icons/clipboard-text.svg" "$ROOT/.config/rofi/icons/"
cp "$SOURCE_HOME/.config/rofi/scripts/clipboard.sh" "$ROOT/.config/rofi/scripts/"
cp "$SOURCE_HOME/.config/rofi/scripts/power-menu.sh" "$ROOT/.config/rofi/scripts/"
cp "$SOURCE_HOME/.config/rofi/scripts/wallpaper-picker.sh" "$ROOT/.config/rofi/scripts/"
cp "$SOURCE_HOME/.config/rofi/themes/glass.rasi" "$ROOT/.config/rofi/themes/"
cp "$SOURCE_HOME/.config/rofi/themes/power-menu.rasi" "$ROOT/.config/rofi/themes/"
cp "$SOURCE_HOME/.config/rofi/themes/wallpaper-grid.rasi" "$ROOT/.config/rofi/themes/"

cp "$SOURCE_HOME/.config/waybar/config" "$ROOT/.config/waybar/"
cp "$SOURCE_HOME/.config/waybar/style.css" "$ROOT/.config/waybar/"
cp "$SOURCE_HOME/.config/waybar/scripts/bluetooth_manager.sh" "$ROOT/.config/waybar/scripts/"
cp "$SOURCE_HOME/.config/waybar/scripts/bluetooth_toggle.sh" "$ROOT/.config/waybar/scripts/"
cp "$SOURCE_HOME/.config/waybar/scripts/memory_pie.sh" "$ROOT/.config/waybar/scripts/"
cp "$SOURCE_HOME/.config/waybar/scripts/mic_status.sh" "$ROOT/.config/waybar/scripts/"
cp "$SOURCE_HOME/.config/waybar/scripts/mpris.sh" "$ROOT/.config/waybar/scripts/"
cp "$SOURCE_HOME/.config/waybar/scripts/pomo.sh" "$ROOT/.config/waybar/scripts/"

find "$ROOT" -type d -name __pycache__ -prune -exec rm -rf {} +

echo "Synced live config into $ROOT"

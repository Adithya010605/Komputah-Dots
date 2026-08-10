#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p \
  "$ROOT/.config/hypr" \
  "$ROOT/.config/kitty" \
  "$ROOT/.config/mako" \
  "$ROOT/.config/nvim/lua/config" \
  "$ROOT/.config/nvim/lua/plugins" \
  "$ROOT/.config/rofi/icons" \
  "$ROOT/.config/rofi/scripts" \
  "$ROOT/.config/rofi/themes" \
  "$ROOT/.config/waybar/scripts"

rm -rf \
  "$ROOT/.config/hypr" \
  "$ROOT/.config/kitty" \
  "$ROOT/.config/mako" \
  "$ROOT/.config/nvim" \
  "$ROOT/.config/rofi" \
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
  "$ROOT/.config/waybar/scripts"

cp /home/adi/.config/hypr/hypridle.conf "$ROOT/.config/hypr/"
cp /home/adi/.config/hypr/hyprland.lua "$ROOT/.config/hypr/"
cp /home/adi/.config/hypr/hyprlock.conf "$ROOT/.config/hypr/"
cp /home/adi/.config/hypr/hyprpaper.conf "$ROOT/.config/hypr/"
cp -r /home/adi/.config/hypr/scripts "$ROOT/.config/hypr/"
cp -r /home/adi/.config/hypr/shaders "$ROOT/.config/hypr/"

cp /home/adi/.config/kitty/kitty.conf "$ROOT/.config/kitty/"
cp /home/adi/.config/mako/config "$ROOT/.config/mako/"

cp /home/adi/.config/nvim/init.lua "$ROOT/.config/nvim/"
cp /home/adi/.config/nvim/lazy-lock.json "$ROOT/.config/nvim/"
cp /home/adi/.config/nvim/lazyvim.json "$ROOT/.config/nvim/"
cp /home/adi/.config/nvim/stylua.toml "$ROOT/.config/nvim/"
cp /home/adi/.config/nvim/lua/config/*.lua "$ROOT/.config/nvim/lua/config/"
cp /home/adi/.config/nvim/lua/plugins/colorscheme.lua "$ROOT/.config/nvim/lua/plugins/"

cp /home/adi/.config/rofi/config.rasi "$ROOT/.config/rofi/"
cp /home/adi/.config/rofi/icons/clipboard-text.svg "$ROOT/.config/rofi/icons/"
cp /home/adi/.config/rofi/scripts/clipboard.sh "$ROOT/.config/rofi/scripts/"
cp /home/adi/.config/rofi/scripts/power-menu.sh "$ROOT/.config/rofi/scripts/"
cp /home/adi/.config/rofi/scripts/wallpaper-picker.sh "$ROOT/.config/rofi/scripts/"
cp /home/adi/.config/rofi/themes/glass.rasi "$ROOT/.config/rofi/themes/"
cp /home/adi/.config/rofi/themes/power-menu.rasi "$ROOT/.config/rofi/themes/"
cp /home/adi/.config/rofi/themes/wallpaper-grid.rasi "$ROOT/.config/rofi/themes/"

cp /home/adi/.config/waybar/config "$ROOT/.config/waybar/"
cp /home/adi/.config/waybar/style.css "$ROOT/.config/waybar/"
cp /home/adi/.config/waybar/scripts/bluetooth_manager.sh "$ROOT/.config/waybar/scripts/"
cp /home/adi/.config/waybar/scripts/bluetooth_toggle.sh "$ROOT/.config/waybar/scripts/"
cp /home/adi/.config/waybar/scripts/memory_pie.sh "$ROOT/.config/waybar/scripts/"
cp /home/adi/.config/waybar/scripts/mic_status.sh "$ROOT/.config/waybar/scripts/"
cp /home/adi/.config/waybar/scripts/mpris.sh "$ROOT/.config/waybar/scripts/"
cp /home/adi/.config/waybar/scripts/pomo.sh "$ROOT/.config/waybar/scripts/"

find "$ROOT" -type d -name __pycache__ -prune -exec rm -rf {} +

echo "Synced live config into $ROOT"

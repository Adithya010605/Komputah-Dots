#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${HOME}/.config-backups/komputah-dots-$(date +%Y%m%d-%H%M%S)"
WALL_DIR="${HOME}/walls"
DEFAULT_WALL="${WALL_DIR}/komputah-default.png"
TARGET_CONFIGS=(hypr kitty mako nvim quickshell rofi waybar)

PACMAN_PACKAGES=(
  base-devel
  git
  hyprland
  hyprpaper
  hyprlock
  hypridle
  hyprpicker
  hyprpolkitagent
  waybar
  rofi-wayland
  kitty
  mako
  neovim
  nautilus
  network-manager-applet
  blueman
  bluez
  bluez-utils
  batsignal
  brightnessctl
  pavucontrol
  playerctl
  wl-clipboard
  cliphist
  wf-recorder
  slurp
  libnotify
  pipewire
  wireplumber
  xdg-user-dirs
  imagemagick
  otf-geist-mono-nerd
  noto-fonts-emoji
)

AUR_PACKAGES=(
  hyprshade
  python-pywal16-git
  quickshell
)

log() {
  printf '[*] %s\n' "$*"
}

fail() {
  printf '[!] %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

escape_sed() {
  printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

install_pacman_packages() {
  log "Installing pacman packages"
  sudo pacman -Syu --needed --noconfirm "${PACMAN_PACKAGES[@]}"
}

install_yay() {
  if command -v yay >/dev/null 2>&1; then
    return 0
  fi

  log "Installing yay"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (
    cd "$tmpdir/yay"
    makepkg -si --noconfirm
  )

  trap - RETURN
  rm -rf "$tmpdir"
}

install_aur_packages() {
  log "Installing AUR packages"
  yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
}

backup_existing_configs() {
  local name
  for name in "${TARGET_CONFIGS[@]}"; do
    if [[ -e "${HOME}/.config/${name}" ]]; then
      mkdir -p "$BACKUP_ROOT"
      mv "${HOME}/.config/${name}" "$BACKUP_ROOT/${name}"
    fi
  done

  if [[ -d "$BACKUP_ROOT" ]]; then
    log "Backed up existing configs to $BACKUP_ROOT"
  fi
}

copy_configs() {
  log "Copying dotfiles into ~/.config"
  mkdir -p "${HOME}/.config"

  local name
  for name in "${TARGET_CONFIGS[@]}"; do
    cp -a "${ROOT}/.config/${name}" "${HOME}/.config/"
  done
}

make_scripts_executable() {
  log "Marking helper scripts executable"
  find "${HOME}/.config/hypr/scripts" -type f -name '*.sh' -exec chmod +x {} +
  find "${HOME}/.config/rofi/scripts" -type f -name '*.sh' -exec chmod +x {} +
  find "${HOME}/.config/waybar/scripts" -type f -name '*.sh' -exec chmod +x {} +
  find "${HOME}/.config/quickshell" -type f -name '*.sh' -exec chmod +x {} +
}

create_default_wallpaper() {
  log "Creating default wallpaper at $DEFAULT_WALL"
  mkdir -p "$WALL_DIR"
  convert -size 1920x1080 gradient:'#0f172a-#1e293b' "$DEFAULT_WALL"
}

pick_wallpaper() {
  mkdir -p "$WALL_DIR"

  local wallpaper
  wallpaper="$(find "$WALL_DIR" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    | sort | head -n 1 || true)"

  if [[ -z "$wallpaper" ]]; then
    create_default_wallpaper
    wallpaper="$DEFAULT_WALL"
  fi

  printf '%s\n' "$wallpaper"
}

patch_runtime_paths() {
  log "Patching user-specific paths"

  local wallpaper="$1"
  local escaped_home escaped_wallpaper
  escaped_home="$(escape_sed "$HOME")"
  escaped_wallpaper="$(escape_sed "$wallpaper")"

  sed -i "s|/home/adi|${escaped_home}|g" "${HOME}/.config/hypr/hyprpaper.conf"
  sed -i "s|/home/adi|${escaped_home}|g" "${HOME}/.config/hypr/hyprlock.conf"

  sed -i "0,/^[[:space:]]*path[[:space:]]*=.*/s|^[[:space:]]*path[[:space:]]*=.*|    path = ${escaped_wallpaper}|" \
    "${HOME}/.config/hypr/hyprpaper.conf"
  sed -i "0,/^[[:space:]]*path[[:space:]]*=.*/s|^[[:space:]]*path[[:space:]]*=.*|    path = ${escaped_wallpaper}|" \
    "${HOME}/.config/hypr/hyprlock.conf"
}

prepare_user_dirs() {
  log "Preparing user directories"
  xdg-user-dirs-update
  mkdir -p "${HOME}/Pictures/Screenshots" "${HOME}/Videos" "${HOME}/.local/state/pomodoro"
}

generate_wal_theme() {
  local wallpaper="$1"

  log "Generating pywal theme cache"
  wal -i "$wallpaper" -n -q
}

enable_services() {
  log "Enabling Bluetooth and NetworkManager"
  sudo systemctl enable --now bluetooth.service
  sudo systemctl enable --now NetworkManager.service
}

bootstrap_nvim() {
  log "Bootstrapping Neovim plugins"
  if ! nvim --headless '+Lazy! sync' +qa; then
    log "Neovim bootstrap skipped; open nvim once inside Hyprland to finish plugin setup"
  fi
}

print_notes() {
  cat <<EOF

Install complete.

Notes:
- Your configs were installed into ${HOME}/.config
- Wallpaper directory: ${WALL_DIR}
- If your monitor names differ from eDP-1 / HDMI-A-1, adjust ~/.config/hypr/hyprland.lua
- If brightness keys do not work, adjust the brightnessctl binds for your hardware

Start Hyprland and the theme cache should already be ready.
EOF
}

main() {
  [[ "${EUID}" -eq 0 ]] && fail "Run this script as your normal user, not as root"

  need_cmd sudo
  need_cmd pacman

  install_pacman_packages
  install_yay
  install_aur_packages
  prepare_user_dirs
  backup_existing_configs
  copy_configs
  make_scripts_executable

  local wallpaper
  wallpaper="$(pick_wallpaper)"
  patch_runtime_paths "$wallpaper"
  generate_wal_theme "$wallpaper"
  enable_services
  bootstrap_nvim
  print_notes
}

main "$@"

#!/usr/bin/env bash
#
# Fresh Arch box -> this desktop. Packages, configs, shell, services, theme.
# Safe to re-run: existing configs are backed up first, and every step is
# idempotent.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${HOME}/.config-backups/komputah-dots-$(date +%Y%m%d-%H%M%S)"
WALL_DIR="${HOME}/walls"
DEFAULT_WALL="${WALL_DIR}/komputah-default.png"

TARGET_CONFIGS=(hypr kitty mako nvim quickshell rofi waybar)
HOME_FILES=(.zshrc .p10k.zsh)

OH_MY_ZSH_DIR="${HOME}/.oh-my-zsh"
ZSH_CUSTOM_DIR="${OH_MY_ZSH_DIR}/custom"

PACMAN_PACKAGES=(
  base-devel
  git
  # compositor and its own tools
  hyprland
  hyprpaper
  hyprlock
  hypridle
  hyprpicker
  hyprpolkitagent
  xdg-desktop-portal-hyprland
  # bars: quickshell is primary, waybar is the fallback Alt+B switches to
  quickshell
  qt6-declarative
  qt6-wayland
  waybar
  rofi-wayland
  kitty
  mako
  neovim
  nautilus
  # network and bluetooth, driven from the settings panel
  networkmanager
  network-manager-applet
  blueman
  bluez
  bluez-utils
  # what the bar modules read
  upower
  batsignal
  brightnessctl
  pavucontrol
  playerctl
  # audio
  pipewire
  pipewire-pulse
  wireplumber
  # clipboard, capture, notifications
  wl-clipboard
  cliphist
  wf-recorder
  hyprshot
  grim
  slurp
  libnotify
  # wallpaper palette; `wal` is what the whole shell themes from
  python
  python-pywal
  imagemagick
  xdg-user-dirs
  # shell
  zsh
  # fonts: GeistMono is the bar and terminal face, Adwaita Sans the panels'
  otf-geist-mono-nerd
  ttf-nerd-fonts-symbols
  adwaita-fonts
  noto-fonts
  noto-fonts-emoji
  # the cursor theme hyprland.lua sets on startup
  adwaita-cursors
  adwaita-icon-theme
)

AUR_PACKAGES=(
  hyprshade
)

log() {
  printf '[*] %s\n' "$*"
}

warn() {
  printf '[~] %s\n' "$*" >&2
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

  for name in "${HOME_FILES[@]}"; do
    if [[ -e "${HOME}/${name}" ]]; then
      mkdir -p "$BACKUP_ROOT"
      mv "${HOME}/${name}" "$BACKUP_ROOT/${name}"
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

  for name in "${HOME_FILES[@]}"; do
    if [[ -f "${ROOT}/home/${name}" ]]; then
      cp -a "${ROOT}/home/${name}" "${HOME}/${name}"
    fi
  done
}

make_scripts_executable() {
  log "Marking helper scripts executable"

  local name
  for name in hypr rofi waybar quickshell; do
    [[ -d "${HOME}/.config/${name}" ]] || continue
    find "${HOME}/.config/${name}" -type f -name '*.sh' -exec chmod +x {} +
  done
}

install_oh_my_zsh() {
  if [[ -d "$OH_MY_ZSH_DIR" ]]; then
    log "oh-my-zsh already present"
  else
    log "Installing oh-my-zsh"
    git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$OH_MY_ZSH_DIR"
  fi

  # The prompt and the two plugins ~/.zshrc names. Cloned into ZSH_CUSTOM
  # rather than installed from the repos, because that is where oh-my-zsh
  # looks for them and where the committed .zshrc expects them.
  clone_zsh_extra https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM_DIR}/themes/powerlevel10k"
  clone_zsh_extra https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions"
  clone_zsh_extra https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM_DIR}/plugins/zsh-syntax-highlighting"
}

clone_zsh_extra() {
  local url="$1" dest="$2"

  if [[ -d "$dest" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  git clone --depth 1 "$url" "$dest"
}

set_login_shell() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"

  if [[ -z "$zsh_path" ]]; then
    warn "zsh is not installed; leaving the login shell alone"
    return 0
  fi

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    return 0
  fi

  log "Setting zsh as the login shell"
  chsh -s "$zsh_path" || warn "Could not change the login shell; run: chsh -s $zsh_path"
}

create_default_wallpaper() {
  log "Creating default wallpaper at $DEFAULT_WALL"
  mkdir -p "$WALL_DIR"
  magick -size 1920x1080 gradient:'#0f172a-#1e293b' "$DEFAULT_WALL"
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

  if [[ "$HOME" != "/home/adi" ]]; then
    # Everything that names a path in full gets rewritten in one sweep rather
    # than file by file. QML in particular has no ~ expansion, so the shell's
    # palette source and pomodoro backend can only be absolute.
    local name
    for name in "${TARGET_CONFIGS[@]}"; do
      [[ -d "${HOME}/.config/${name}" ]] || continue
      # `|| true`: a config with nothing to rewrite is the normal case, and
      # grep exiting 1 on no match would take the whole install down with it.
      { grep -rlI '/home/adi' "${HOME}/.config/${name}" 2>/dev/null || true; } \
        | xargs -r sed -i "s|/home/adi|${escaped_home}|g"
    done

    for name in "${HOME_FILES[@]}"; do
      [[ -f "${HOME}/${name}" ]] || continue
      sed -i "s|/home/adi|${escaped_home}|g" "${HOME}/${name}"
    done
  fi

  # The wallpaper is the one path that is not just a home directory rename.
  sed -i "0,/^[[:space:]]*path[[:space:]]*=.*/s|^[[:space:]]*path[[:space:]]*=.*|    path = ${escaped_wallpaper}|" \
    "${HOME}/.config/hypr/hyprpaper.conf"
  sed -i "0,/^[[:space:]]*path[[:space:]]*=.*/s|^[[:space:]]*path[[:space:]]*=.*|    path = ${escaped_wallpaper}|" \
    "${HOME}/.config/hypr/hyprlock.conf"
}

prepare_user_dirs() {
  log "Preparing user directories"
  xdg-user-dirs-update
  mkdir -p \
    "${HOME}/Pictures/Screenshots" \
    "${HOME}/Videos" \
    "${HOME}/walls" \
    "${HOME}/.cache/waybar" \
    "${HOME}/.cache/quickshell" \
    "${HOME}/.local/state/pomodoro" \
    "${HOME}/.local/state/quickshell"
}

generate_wal_theme() {
  local wallpaper="$1"

  log "Generating pywal theme cache"
  # The bar, the panels and waybar all read ~/.cache/wal/colors.json, and the
  # shell starts with a built-in palette until it exists.
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
- Configs installed into ${HOME}/.config, shell files into ${HOME}
- Anything that was already there is in ${BACKUP_ROOT}
- Wallpaper directory: ${WALL_DIR}
- The quickshell bar starts at login and is the notification daemon.
  Alt+B swaps it for waybar, Alt+Shift+B reloads it, and
  ~/.config/quickshell/bar/bar-switch.sh status says what is running.
- If your monitor names differ from eDP-1 / HDMI-A-1, adjust
  ~/.config/hypr/hyprland.lua
- The brightness bindings and the backlight module name a device explicitly
  (amdgpu_bl1). Check "ls /sys/class/backlight" and adjust if yours differs.
- The lock screen asks for SF Pro Display Bold, which is not in the Arch
  repos; without it hyprlock falls back to a system face.
- Alt+C is bound to "code", which is not installed by this script. Install
  the "code" package (or repoint the binding) if you want it.
- Log out and back in for zsh to become your shell.

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
  install_oh_my_zsh
  set_login_shell

  local wallpaper
  wallpaper="$(pick_wallpaper)"
  patch_runtime_paths "$wallpaper"
  generate_wal_theme "$wallpaper"
  enable_services
  bootstrap_nvim
  print_notes
}

main "$@"

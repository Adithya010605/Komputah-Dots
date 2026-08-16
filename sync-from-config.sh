#!/usr/bin/env bash
#
# Pulls the live setup back into the repo.
#
# Whole trees rather than a hand-written list of files: the old form named
# every file individually, so anything added live — a new script, a new QML
# module — stayed untracked until someone remembered to add a cp line for it,
# and the repo quietly stopped being a complete backup. Excludes are named
# instead, which is a much shorter list and fails safe.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_HOME="${SOURCE_HOME:-$HOME}"

# Everything under ~/.config that the installer puts back.
CONFIG_DIRS=(hypr kitty mako nvim quickshell rofi waybar)

# Dotfiles from $HOME itself, kept under home/ in the repo.
HOME_FILES=(.zshrc .p10k.zsh)

# Matched against the path relative to the config directory, and against the
# bare filename. Backups, caches and the bits of the LazyVim starter that are
# not part of this setup.
EXCLUDES=(
  '*.bak'
  '*.bak-*'
  '*.swp'
  '*.swo'
  '*.tmp'
  '*~'
  '__pycache__/*'
  '.neoconf.json'
  'lua/plugins/example.lua'
  'LICENSE'
  'README.md'
  # Left behind live but wired to nothing: the emoji picker lost its keybind
  # in the move to hyprland.lua, and this rofi theme is referenced by no
  # script or config.
  'scripts/emoji-selector.sh'
  'themes/hyprltm-net.rasi'
)

excluded() {
  local rel="$1"
  local pattern

  for pattern in "${EXCLUDES[@]}"; do
    # shellcheck disable=SC2053 # glob match is the point
    if [[ "$rel" == $pattern || "${rel##*/}" == $pattern ]]; then
      return 0
    fi
  done

  return 1
}

copy_tree() {
  local name="$1"
  local src="$SOURCE_HOME/.config/$name"
  local dest="$ROOT/.config/$name"

  if [[ ! -d "$src" ]]; then
    printf 'skipped %s (not in %s/.config)\n' "$name" "$SOURCE_HOME"
    return
  fi

  # Wiped first so a file deleted live also disappears from the repo.
  rm -rf "$dest"
  mkdir -p "$dest"

  local rel
  while IFS= read -r rel; do
    rel="${rel#./}"
    excluded "$rel" && continue

    mkdir -p "$dest/$(dirname "$rel")"
    cp -p "$src/$rel" "$dest/$rel"
  done < <(cd "$src" && find . -type f -o -type l)
}

mkdir -p "$ROOT/.config" "$ROOT/home"

for dir in "${CONFIG_DIRS[@]}"; do
  copy_tree "$dir"
done

for file in "${HOME_FILES[@]}"; do
  if [[ -f "$SOURCE_HOME/$file" ]]; then
    cp -p "$SOURCE_HOME/$file" "$ROOT/home/$file"
  else
    printf 'skipped %s (not in %s)\n' "$file" "$SOURCE_HOME"
  fi
done

printf 'Synced live config into %s\n' "$ROOT"

# Komputah-Dots

My Arch + Hyprland setup, complete enough that a fresh machine only needs
`./install.sh` to end up as the machine I actually use.

Included:

- `hypr` — Hyprland (Lua config, 0.55+), hyprlock, hypridle, hyprpaper, shaders
- `quickshell` — the bar, its panels, and the notification daemon
- `waybar` — the fallback bar
- `rofi` — launcher, clipboard, power menu, wallpaper picker
- `kitty`, `mako`, `nvim`
- `home/.zshrc`, `home/.p10k.zsh` — zsh with oh-my-zsh and powerlevel10k

Excluded on purpose:

- backup files like `*.bak*`, caches like `__pycache__`
- LazyVim starter leftovers (`.neoconf.json`, `lua/plugins/example.lua`)
- config left live but wired to nothing (`rofi/scripts/emoji-selector.sh`,
  `rofi/themes/hyprltm-net.rasi`)

## The bar

`quickshell` is the primary bar and the notification daemon; `waybar` is kept
configured as the fallback. Every panel — media, audio, pomodoro,
notifications, settings — hangs directly beneath the module that opened it and
drips out of the bar.

- `quickshell/CLAUDE.md` is the brief the whole shell is built against
- `quickshell/bar/Theme.qml` is the one place colours, radii, timings and fonts
  are set; the palette follows the wallpaper through `pywal`
- panels can be driven by keybind too:
  `quickshell -c bar ipc call panel toggle audio`

```bash
~/.config/quickshell/bar/bar-switch.sh status   # what is running
~/.config/quickshell/bar/bar-switch.sh toggle   # swap bars (Super+B)
~/.config/quickshell/bar/bar-switch.sh restart  # reload (Super+Shift+B)
```

## Install on a fresh Arch setup

```bash
git clone git@github.com:Adithya010605/Komputah-Dots.git
cd Komputah-Dots
./install.sh
```

The installer:

- installs the pacman packages (compositor, both bars, quickshell, audio,
  fonts, zsh, tooling) and the AUR ones (`hyprshade`), bootstrapping `yay`
  first if it is missing
- backs up anything already in the target paths to `~/.config-backups/`
- copies the configs into `~/.config` and the zsh files into `~`
- installs oh-my-zsh, powerlevel10k and the two zsh plugins, and sets zsh as
  the login shell
- rewrites every `/home/adi` path to the real home directory — QML has no `~`
  expansion, so the shell's palette source and pomodoro backend are absolute
- creates or reuses a wallpaper in `~/walls` and generates the `pywal` cache
  the whole shell themes from
- enables `bluetooth.service` and `NetworkManager.service`
- bootstraps Neovim plugins

It is safe to re-run — every step is idempotent and the previous configs are
kept.

What it deliberately does not handle: wallpapers (bring your own into
`~/walls`; a gradient is generated if it is empty), the `SF Pro Display Bold`
face the lock screen asks for, and VS Code for the `Super+C` binding.

## Sync from live config

```bash
./sync-from-config.sh
```

Copies whole trees rather than a list of files, so anything added live is
picked up without editing the script. Check `git status` afterwards.

## Push

```bash
git add -A
git commit -m "..."
git push
```

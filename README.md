# Komputah-Dots

My Arch + Hyprland setup, kept complete enough that a fresh machine needs
nothing but a clone and `./install.sh` to become the machine I actually use.

The centrepiece is a Quickshell desktop shell: a floating glass bar where every
panel hangs directly beneath the module that opened it and drips out of the bar
like a droplet. Waybar is still here, configured and one keystroke away, as the
fallback.

```
Komputah-Dots/
├── .config/
│   ├── hypr/        Hyprland (Lua config), hyprlock, hypridle, hyprpaper, shaders, scripts
│   ├── quickshell/  the bar, its panels, and the notification daemon
│   ├── waybar/      the fallback bar and its module scripts
│   ├── rofi/        launcher, clipboard, power menu
│   ├── kitty/       terminal
│   ├── mako/        notification daemon config (kept for the waybar fallback)
│   └── nvim/        LazyVim
├── home/            .zshrc and .p10k.zsh
├── install.sh       fresh machine -> this desktop
└── sync-from-config.sh   live config -> this repo
```

## The shell

`quickshell` is the primary bar and the notification daemon. `waybar` is the
fallback that `Alt+B` switches to.

**The bar** hugs its modules rather than spanning the display, and animates its
width as modules come and go: window title, workspaces, media, clock, pomodoro,
volume, backlight, memory, battery, notifications, settings.

**The panels** — media, audio, pomodoro, system, notifications, settings — all use the
same drip: they grow downward out of the bar's underside, overshoot and settle,
with a neck that pinches at the join, and retract back up on close. Because bar
and panels live in one process, a panel is told exactly where its module sits;
there is no screenshot calibration and no guessing.

| Panel | Opened from | What it holds |
| --- | --- | --- |
| Media | the track pill | art, transport, seek, player picker |
| Audio | the volume icon | output/input volume, device pickers, per-app streams |
| Pomodoro | the countdown | preset picker, controls, week heat strip, today's total |
| System | the memory pie | CPU, GPU and memory — plots, per-core load, temperature and power |
| Notifications | the bell | full history, dismiss and clear-all |
| Settings | the gear | Wi-Fi and bluetooth in full — scan, connect, forget, pair |

The system panel samples `/proc` and hwmon continuously, so its plots are
already a minute deep when it opens; `nvidia-smi` only runs while the panel is
up, because waking the discrete GPU once a second for a closed panel is a
battery leak.

Panels can be driven by keybind or script as well as by click:

```bash
quickshell -c bar ipc call panel toggle audio    # media | audio | pomo | system | notifications | settings
quickshell -c bar ipc call panel close
```

**The wallpaper wheel** is the one surface that does not drip. `Alt+W` summons
it over the whole screen: the images in `~/walls` mounted on a disk whose centre
sits off the right edge, turning endlessly past either end. Enter applies one —
`quickshell/bar/set-wallpaper.sh` does the work and is runnable on its own —
which sets hyprpaper, regenerates the palette, and writes the choice into
`hyprpaper.conf` and `hyprlock.conf` so it survives a reboot.

```bash
quickshell -c bar ipc call wallpaper toggle
```

**Theming** is wallpaper-driven. `wal` writes `~/.cache/wal/colors.json`,
`quickshell/bar/Theme.qml` watches it live, and every colour, radius, duration
and font in the shell comes from that one file — waybar's `style.css` mirrors
the same values, so the two bars read as the same object.

**Switching bars:**

```bash
~/.config/quickshell/bar/bar-switch.sh status    # what is running
~/.config/quickshell/bar/bar-switch.sh toggle    # swap bars           (Alt+B)
~/.config/quickshell/bar/bar-switch.sh restart   # reload quickshell   (Alt+Shift+B)
~/.config/quickshell/bar/bar-switch.sh on|off    # explicit
```

`quickshell/CLAUDE.md` is the brief the whole shell was built against — the
visual language, the theming rule, and the drip behaviour in priority order.

## Keybindings

`Alt` is the main modifier; `Super` handles session control. Both work for
workspaces.

**Windows**

| Key | Action |
| --- | --- |
| `Alt+Q` | close |
| `Alt+T` | toggle floating |
| `Alt+F` / `Alt+Shift+F` | maximise / fullscreen |
| `Alt+H/J/K/L` | move focus |
| `Alt+Shift+H/J/K/L` | swap window |
| `Alt+;` / `Alt+'` | resize |
| `Alt+LMB` / `Alt+RMB` | drag / resize with the mouse |

**Workspaces**

| Key | Action |
| --- | --- |
| `Alt+1..9` or `Super+1..9` | switch |
| `Alt+Shift+1..9` or `Super+Shift+1..9` | move window there |
| `Alt+Space` / `Alt+Shift+Space` | special workspace / move to it |
| `Alt+scroll` or `Super+scroll` | cycle workspaces |

**Apps and launchers**

| Key | Action |
| --- | --- |
| `Alt+Return` | kitty |
| `Alt+E` | nautilus |
| `Alt+C` | code (not installed by this script) |
| `Alt+R` | rofi drun |
| `Alt+V` | clipboard history |
| `Alt+W` | wallpaper wheel (re-themes the whole shell) |

**Screen and session**

| Key | Action |
| --- | --- |
| `Print` | screenshot the output to the clipboard |
| `Alt+S` / `Alt+Shift+S` | region to clipboard / to `~/Pictures/Screenshots` |
| `Alt+P` | colour picker |
| `Alt+B` / `Alt+Shift+B` | switch bars / reload the quickshell bar |
| `Alt+G` | focus mode (no gaps, no borders, no bar) |
| `Alt+Shift+E` | reading mode shader |
| `Alt+Shift+R` | night light |
| `Alt+Shift+Q` | no-sleep toggle |
| `Super+L` | lock |
| `Super+Shift+L` | lock again from a dead lock screen (works while locked) |
| `Super+S` | lock and suspend |
| `Super+Shift+Return` | power menu |
| `Super+E` | exit Hyprland |

Media, volume, mic and brightness keys work while locked.

## Install on a fresh Arch setup

```bash
git clone git@github.com:Adithya010605/Komputah-Dots.git
cd Komputah-Dots
./install.sh
```

Run it as your normal user, not root. It is safe to re-run: every step is
idempotent, and anything already in the target paths is moved to
`~/.config-backups/komputah-dots-<timestamp>/` first.

What it does, in order:

1. installs the pacman packages — Hyprland and its tools, quickshell and its Qt
   deps, waybar, rofi, kitty, neovim, PipeWire, NetworkManager, bluez, the
   fonts (GeistMono Nerd for the bar, Adwaita Sans for panels), zsh
2. bootstraps `yay` if missing and installs the AUR list (`hyprshade`)
3. creates `~/Pictures/Screenshots`, `~/walls`, `~/.cache/waybar`,
   `~/.local/state/pomodoro`
4. backs up existing configs, then copies `.config/*` into `~/.config` and
   `home/*` into `~`
5. marks every helper script executable
6. installs oh-my-zsh, powerlevel10k and the two zsh plugins `~/.zshrc` names,
   then sets zsh as the login shell
7. rewrites every `/home/adi` path to your real home directory — QML has no `~`
   expansion, so the shell's palette source and pomodoro backend have to be
   absolute
8. picks the first wallpaper in `~/walls` (generating a gradient if it is
   empty), points hyprpaper and hyprlock at it, and generates the `pywal` cache
   the whole shell themes from
9. enables `bluetooth.service` and `NetworkManager.service`
10. syncs Neovim plugins

Then log out and back in — for zsh, and to start Hyprland with the shell up.

### After installing, check these

- **Monitors.** `hyprland.lua` names `eDP-1` and `HDMI-A-1` with fixed modes.
  Adjust the `hl.monitor` blocks at the top if yours differ.
- **Backlight device.** The brightness keys and the bar's backlight module name
  `amdgpu_bl1` explicitly, because this laptop has more than one backlight
  class and the default pick is not the one driving the panel. Check
  `ls /sys/class/backlight` and adjust `hyprland.lua`, `waybar/config` and
  `quickshell/bar/Brightness.qml` together.
- **Wallpapers.** Bring your own into `~/walls`; the installer only generates a
  placeholder gradient.
- **Lock screen font.** hyprlock asks for `SF Pro Display Bold`, which is not
  in the Arch repos. Without it, it falls back to a system face.
- **VS Code.** `Alt+C` runs `code`, which the installer does not install.

## Sync from live config

```bash
./sync-from-config.sh
git status
```

Copies whole trees rather than a hand-written list of files, so anything added
live is picked up without editing the script. Excluded on purpose: backups
(`*.bak*`), caches (`__pycache__`), LazyVim starter leftovers (`.neoconf.json`,
`lua/plugins/example.lua`), and config that is live but wired to nothing
(`rofi/scripts/emoji-selector.sh`, `rofi/themes/hyprltm-net.rasi`).

Deleting a file live deletes it from the repo on the next sync — the trees are
wiped and rewritten — so check `git status` before committing.

## Requirements

Arch Linux with Hyprland **0.55+** (the config is Lua, not `hyprland.conf`) and
a Wayland session. Everything else the installer handles.

-- ────────────────────────────────────────────────────────────────────
--  「✦ HYPRLAND LUA CONFIG ✦ 」
--  Migrated from hyprland.conf to hyprland.lua for Hyprland 0.55+
-- ────────────────────────────────────────────────────────────────────


------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@144",
    position = "0x0",
    scale    = 1,
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080@100",
    position = "1920x0",
    scale    = 1,
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "nautilus"
local menu        = "rofi -show drun"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar & hyprpaper & nm-applet --indicator & blueman-applet & mako")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("batsignal -b -w 30 -c 20 -d 10")
    hl.exec_cmd("hyprctl setcursor Adwaita 24")
    hl.exec_cmd("sh -c 'sleep 1; hyprctl setcursor Adwaita 24'")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("ELECTRON_ENABLE_WAYLAND", "1")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_SIZE", "24")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 2,
        gaps_out = 10,

        border_size = 3,

        col = {
            active_border   = "rgba(a8a8a8dd)",
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 4,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },

        blur = {
            enabled          = true,
            size             = 8,
            passes           = 4,
            new_optimizations = true,
            ignore_opacity   = true,
            xray             = false,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },

    cursor = {
        no_hardware_cursors = 0,
        default_monitor     = "eDP-1",
    },

    input = {
        kb_layout  = "us",
        kb_variant = ",qwerty",
        kb_options = "altwin:swap_lalt_lwin, shift:both_capslock",

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll = true,
        },
    },
})


------------------
---- GESTURES ----
------------------

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })


-----------------
---- DEVICES ----
-----------------

hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })


--------------------
---- ANIMATIONS ----
--------------------

-- Custom bezier curves
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1.0}, {0.32, 1.0} } })
hl.curve("easeOutExpo",  { type = "bezier", points = { {0.19, 1.0}, {0.22, 1.0} } })
hl.curve("easeOutCubic", { type = "bezier", points = { {0.22, 1.0}, {0.36, 1.0} } })
hl.curve("linear",       { type = "bezier", points = { {0.0, 0.0}, {1.0, 1.0} } })

-- Animation definitions
hl.animation({ leaf = "windows",         enabled = true, speed = 4, bezier = "easeOutCubic", style = "slide" })
hl.animation({ leaf = "windowsIn",       enabled = true, speed = 4, bezier = "easeOutCubic", style = "slide" })
hl.animation({ leaf = "windowsOut",      enabled = true, speed = 4, bezier = "easeOutCubic", style = "slide" })
hl.animation({ leaf = "windowsMove",     enabled = true, speed = 4.5, bezier = "easeOutCubic", style = "slide" })
hl.animation({ leaf = "border",          enabled = true, speed = 1, bezier = "linear" })
hl.animation({ leaf = "borderangle",     enabled = true, speed = 30, bezier = "linear", style = "once" })
hl.animation({ leaf = "fade",            enabled = true, speed = 4, bezier = "easeOutCubic" })
hl.animation({ leaf = "layersIn",        enabled = true, speed = 4, bezier = "easeOutCubic", style = "fade" })
hl.animation({ leaf = "layersOut",       enabled = true, speed = 4, bezier = "easeOutCubic", style = "fade" })
hl.animation({ leaf = "workspaces",      enabled = true, speed = 3, bezier = "easeOutExpo", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "easeOutExpo", style = "fade" })


----------------------
---- KEYBINDINGS ----
----------------------

local mainMod = "ALT"
local mod     = "SUPER"

-- Window management
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 0 }))

-- Screenshots & tools
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m output -m eDP-1 --clipboard-only"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -o ~/Pictures/Screenshots/ -m region"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hyprpicker -a"))

-- Launchers
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("~/.config/rofi/scripts/wallpaper-picker.sh"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("~/.config/rofi/scripts/clipboard.sh"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("~/.config/rofi/scripts/emoji-selector.sh"))

-- Waybar controls
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("killall -SIGUSR1 waybar || waybar"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("pkill waybar && waybar"))

-- Scripts
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("~/.config/hypr/scripts/focus-mode.sh"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("~/.config/hypr/scripts/reading_mode.sh"))

-- Session management
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/night-light-toggle.sh"))
hl.bind(mod .. " + S", hl.dsp.exec_cmd("sh -c \"hyprlock & sleep 0.5 && systemctl suspend\""))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("~/.config/hypr/scripts/no-sleep-toggle.sh"))
hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd("~/.config/rofi/scripts/power-menu.sh"))
hl.bind(mod .. " + E", hl.dsp.exit())

-- App launchers
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))

-- Focus movement
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))

-- Resize active window (repeat = true replaces binde)
hl.bind(mainMod .. " + semicolon",   hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + apostrophe",  hl.dsp.window.resize({ x = 40, y = 0, relative = true }),  { repeating = true })

-- Swap windows
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.swap({ direction = "d" }))


---------------------
---- WORKSPACES ----
---------------------

-- Switch workspaces
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
    hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end

-- Special workspace
hl.bind(mainMod .. " + Space", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.move({ workspace = "special:magic" }))

-- Mouse scroll workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))


-----------------
---- MOUSE ----
-----------------

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


---------------------
---- MEDIA KEYS ----
---------------------

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { ["repeat"] = true, locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { ["repeat"] = true, locked = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { ["repeat"] = true, locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("sh -c 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && pkill -RTMIN+9 waybar'"), { ["repeat"] = true, locked = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -d amdgpu_bl1 -e4 -n2 set 5%+"), { ["repeat"] = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d amdgpu_bl1 -e4 -n2 set 5%-"), { ["repeat"] = true, locked = true })


------------------------------
---- WORKSPACE MONITORS ----
------------------------------

hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "3", monitor = "eDP-1" })
hl.workspace_rule({ workspace = "4", monitor = "eDP-1" })
hl.workspace_rule({ workspace = "5", monitor = "eDP-1" })


------------------------
---- LAYER RULES ----
------------------------

-- Notifications
hl.layer_rule({ match = { namespace = "notifications" }, blur = true, ignore_alpha = 0 })

-- Rofi
hl.layer_rule({ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0 })

-- Waybar
hl.layer_rule({ match = { namespace = "waybar" }, blur = true, ignore_alpha = 0 })


-------------------------
---- WINDOW RULES ----
-------------------------

-- Kitty frosted glass
hl.window_rule({
    name         = "kitty-glass",
    match        = { class = "kitty" },
    opacity      = "1.0",
})

-- Obsidian glass effect
hl.window_rule({
    name         = "obsidian-glass",
    match        = { class = "^(obsidian)$" },
    opacity      = "0.83 0.86 1.0",
})

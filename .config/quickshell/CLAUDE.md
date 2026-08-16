# Quickshell + Hyprland Desktop Shell — Build Brief

## Context

- OS: Arch Linux
- WM: Hyprland
- Terminal: kitty (custom GLSL shaders in use — this shell should feel like it belongs in the same visual family)
- Bar: Waybar stays in place for specific always-on system info; Quickshell handles everything else
- Goal: a cohesive desktop shell, not a Quickshell-does-everything rewrite

This file is the spec. Read it fully before writing any QML/config.

---

## 1. The Vibe

**Glassmorphism, but fluid and restrained — not a Windows Vista pastiche.**

- Frosted/translucent panels with real background blur (not a flat semi-transparent color pretending to be glass)
- Soft, subtle drop shadows to give panels depth and lift them off the desktop — never harsh or heavy
- Rounded corners throughout, consistent radius scale across all surfaces
- Thin, barely-there borders (1px, low-opacity, slightly lighter than the panel) to catch light and define edges without looking boxed-in
- Motion should feel liquid: eased, slightly springy transitions on open/close/hover — nothing linear, nothing snappy/robotic. Elements should feel like they have weight.
- Minimal by default: no clutter, no unnecessary chrome, no decorative elements that don't carry information. Every panel/widget earns its screen space.
- Generous negative space. Glass reads as "clean" partly because there's room around it to breathe.
- Avoid: skeuomorphic gloss/glare effects, gradient overload, neon glow, anything that reads as "gamer RGB." This is calm and premium, not loud.

Think: a refined compositor-level glass UI — closer to a well-done macOS/visionOS-inspired blur panel than a Discord theme.

---

## 2. Color System — Wallpaper-Driven Theming

- All colors across Waybar + Quickshell derive from the current wallpaper via the existing color-generation program already in the config (use whatever pipeline is already set up — e.g. matugen/wallust/pywal-style palette output — don't introduce a second competing tool unless the existing one is insufficient).
- Every component (Quickshell widgets, Waybar modules, borders, shadows' tint, blur tint) reads from **one shared palette source** — a single generated theme file (CSS variables / QML singleton / JSON, whatever fits) that both Waybar and Quickshell consume. No hardcoded hex values scattered across widget files.
- On wallpaper change, the whole shell (Waybar + Quickshell) should re-theme together, ideally without a full restart of either — hot-reload the palette if Quickshell/Waybar support live config/style reload; if not, keep the reload path as fast and unobtrusive as possible.
- Glass surfaces should tint subtly with the extracted palette (not just go transparent-grey) — accent color shows up in borders, active states, highlights, and a faint tint in the blur itself.
- Maintain proper contrast/legibility as a hard constraint — if the wallpaper produces a palette with poor text contrast on glass, the theming pipeline should compensate (e.g. clamp lightness for text/foreground colors) rather than ship unreadable text.

---

## 3. Popup Behavior — "Liquid Dripping From the Bar"

This is the signature interaction of the whole shell. Get this right and everything else follows.

**Anchoring:**
- Every Quickshell popup/panel appears **directly below the Waybar icon or module that triggered it** — horizontally aligned to that specific module, not centered on screen, not corner-anchored. Clicking the volume icon drops the volume panel under the volume icon; clicking the network icon drops the network panel under the network icon. The panel's position is derived from the triggering module's actual on-screen x-position.
- Panels should read as **physically attached to the bar** — visually continuous with it, not floating as a detached window. There should be no visible gap between the bottom edge of Waybar and the top edge of the popup. The popup shares the bar's glass material so the two read as one continuous surface.
- The top corners of the popup should not be rounded where it meets the bar (or should blend/merge into it) — rounding is only on the free-hanging edges. The join should look seamless.

**Motion — the drip:**
- The popup **grows downward out of the bar**, like a droplet of liquid forming and falling from its underside. It does not fade in, does not scale from center, does not slide in from off-screen.
- The animation should have real liquid character: a slight stretch/elongation as it extends, a soft overshoot and settle at the bottom (springy easing, not a hard stop), and a subtle narrowing at the point where it meets the bar — like surface tension pulling at the connection point. The panel should feel like it has viscosity and weight.
- Closing reverses it: the panel retracts **back up into the bar** and gets reabsorbed, rather than fading out or disappearing instantly. The retract should feel like the droplet being pulled back up — slightly faster than the open, with the same surface-tension narrowing at the join.
- If implementing the neck/tension effect is impractical in QML, prioritize in this order: (1) correct anchoring under the right icon, (2) seamless attachment to the bar with no gap, (3) downward grow/retract origin at the top edge, (4) springy overshoot, (5) the liquid neck. Do not skip 1–3.

**Consistency:**
- All Quickshell popups use this same anchor + drip behavior. No one-off popup that behaves differently.
- Timing, easing curve, overshoot amount, and stretch factor live in the shared design-token file so the drip feels identical everywhere and can be tuned in one place.
- Edge handling: if a triggering module sits near the screen edge, the popup should shift horizontally just enough to stay on-screen while keeping its top edge attached to the bar — the attachment to the bar is never sacrificed, only the perfect centering under the icon.

---

## 4. What to Ask Before Building

Before generating code, Claude Code should clarify (or reasonably assume and state the assumption):
- Which specific components go in Quickshell first (pick a starting scope — e.g. notification center + volume/brightness OSD — rather than building everything at once)
- What the current wallpaper-to-color tool actually outputs (format/location) so theming hooks into it correctly instead of guessing
- Any existing Waybar config/style to match against for consistency (radius, font, spacing already in use), and how to reliably get each module's on-screen position for popup anchoring

---

## Summary for Claude Code

Build a Quickshell shell that complements (not replaces) an existing Waybar setup on Hyprland/Arch. Visual language: fluid, minimal glassmorphism — real blur, soft shadows, thin borders, liquid easing, no visual clutter — fully themed from a single wallpaper-derived color source shared with Waybar. The signature behavior: every popup hangs directly beneath the Waybar module that triggered it, seamlessly attached to the bar, growing downward and retracting back up like a droplet of liquid with surface tension at the join.

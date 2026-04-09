# System GDD: Viewport / Rendering Config

> **Status**: Approved
> **Author**: Michael Raftery + Hawaii Zeke
> **Last Updated**: 2026-04-08
> **System #**: 2 (Viewport / Rendering Config)
> **Priority**: MVP — Foundation Layer
> **Implements Pillar**: "BONNIE Moves Like She Means It" (pixel-perfect presentation); "Every Space is a Playground" (dense pixel art legibility)

---

## 1. Overview

The Viewport / Rendering Config establishes the pixel coordinate space and display pipeline for BONNIE. The **viewport** is the 720×540 window through which the player sees the world at any given moment — it is not the size of the world itself. Levels and environments are unbounded in world space; rooms can be arbitrarily large. The camera frames a 720×540 slice of that world, and this config defines how that slice is presented on any physical display.

All physics distances, radii, and speed values across every system are expressed in world-space pixels — the same unit as the viewport window. The viewport is rendered with nearest-neighbor filtering and upscaled by the GPU to the physical display without blur or interpolation. On widescreen monitors (16:9 and wider), the image is pillarboxed — black bars fill the sides, and the game content is never stretched or cropped. This configuration is the foundation all other systems are built on.

---

## 2. Player Fantasy

The player never thinks about the viewport. That's the goal. BONNIE's pixel art world appears on screen with absolute visual fidelity — sprites are crisp, lines are clean, no pixel is blurred or interpolated. On any display, at any size, the game looks like it was made for that screen. The 4:3 aspect ratio creates a specific intimacy with the space: rooms feel dense and readable, environments feel inhabited rather than sparse. A player on a 4K monitor and a player on a 1080p laptop see the same game at the same quality — the GPU scales the image up, the art never degrades. The pillarbox bars, when they appear on widescreen displays, frame the game like a classic arcade cabinet: deliberate, confident, period-correct.

The frame rate is 60fps, locked — and it never drops. Not during room transitions, not when a mini-game cuts in, not during the feeding cutscene, not during any perspective shift or mode change. Every view change in the game is a seamless part of one continuous experience. The player never feels the seams.

---

## 3. Detailed Rules

### World Space vs. Viewport Window

**The 720×540 is the camera window — not the world size.**

- **World space** is unbounded. Levels, rooms, and environments are authored at whatever pixel dimensions the design requires. A room can be 3000px wide, 1200px tall, or any other size.
- **Viewport window** is 720×540. This is the slice of world space the player sees at any given moment. The camera moves through world space; the viewport is the lens.
- **Coordinate unit** is world-space pixels. All physics constants, movement speeds, detection radii, and distance thresholds across every system are expressed in this unit. The viewport window happens to be 720×540 of these same pixels wide and tall.

No system should conflate the viewport dimensions with level dimensions. Level geometry is not constrained to 720×540.

### Core Rules

1. **Viewport window is 720×540, fixed.** The slice of world space presented to the player at any moment is exactly 720×540 world-space pixels. No system may assume a different viewport size.
2. **Aspect ratio is 4:3, locked.** The viewport never renders at any other ratio. No stretching, no cropping, no dynamic aspect ratio.
3. **Texture filtering is nearest-neighbor throughout.** No bilinear or trilinear filtering anywhere in the pipeline — not on sprites, not on UI, not on the upscaled output. Blur is forbidden.
4. **Stretch mode: `viewport` + `keep`.** Godot scales the 720×540 viewport to fit the physical window while preserving the 4:3 ratio. The GPU handles upscaling; the game never sees a different resolution internally.
5. **Pillarbox on widescreen.** On displays wider than 4:3, black bars fill the left and right sides. The game image is centered. Bar color: pure black (`#000000`).
6. **Integer scaling preferred.** The default window is 1440×1080 (2× integer scale). 4× scale (2880×2160) is supported. Non-integer scales are permitted by the OS but not the preferred presentation.
7. **60fps, locked, unconditional.** Frame rate holds at 60fps through all gameplay states: standard play, room transitions, mini-game cut-ins, feeding cutscenes, and any other perspective or mode change. No view transition may cause a frame drop.
8. **No post-processing requiring a discrete GPU.** Shader effects must run on integrated graphics (Intel HD / AMD Vega iGPU). Any effect that requires a dedicated GPU is forbidden.

### Display Modes / Window States

| State | Internal Resolution | Display Behavior |
|---|---|---|
| Default window (2×) | 720×540 | Displayed at 1440×1080, centered |
| 4× window | 720×540 | Displayed at 2880×2160, centered |
| Arbitrary window size | 720×540 | Letterboxed/pillarboxed to maintain 4:3; black bars fill remainder |
| Fullscreen | 720×540 | Pillarboxed to physical display; integer scale preferred if resolution permits |

### Interactions with Other Systems

- **All systems**: physics constants, radii, and thresholds are expressed in world-space pixels — the same unit as the viewport window. No system converts or overrides these values based on display size or level dimensions.
- **Camera System (4)**: moves through unbounded world space, framing a 720×540 window at any moment. Look-ahead distances, deadzone radii, and all camera math are in world-space pixels.
- **BONNIE Traversal (6)**: all speed and distance values (`run_max_speed`, `parry_detection_radius`, `rough_landing_threshold`, etc.) are world-space pixels and pixels-per-second. These are independent of level size.
- **Level Manager (5)**: room boundaries and level geometry are authored in world space at any size. The viewport window into that geometry is always 720×540.
- **Aseprite Export Pipeline (26)**: sprites are authored at the scale appropriate for the 720×540 viewport. A character that should appear roughly 32px tall in the viewport is drawn at 32px. Level geometry can extend beyond the viewport — tiles repeat or extend as needed.

---

## 4. Formulas

### Integer Scale Detection

```gdscript
# Determine the largest integer scale that fits the physical display
func get_integer_scale(display_size: Vector2) -> int:
    var scale_x: int = int(display_size.x) / 720
    var scale_y: int = int(display_size.y) / 540
    return max(1, min(scale_x, scale_y))
```

| Variable | Description | Value |
|---|---|---|
| `INTERNAL_WIDTH` | Internal render width | `720` |
| `INTERNAL_HEIGHT` | Internal render height | `540` |
| `ASPECT_RATIO` | Locked 4:3 | `720.0 / 540.0 = 1.333...` |

### Pillarbox Bar Width

```gdscript
# Width of each black bar on a widescreen display (one side)
func get_pillarbox_width(display_width: int, scale: int) -> int:
    var rendered_width: int = 720 * scale
    return (display_width - rendered_width) / 2
```

At 1080p (1920×1080): scale = 2, rendered = 1440px, each bar = `(1920 - 1440) / 2 = 240px`

### Internal → Display Coordinate Mapping

```gdscript
# Convert an internal pixel coordinate to a physical display coordinate
func internal_to_display(internal_pos: Vector2, scale: int, offset: Vector2) -> Vector2:
    return internal_pos * scale + offset
# offset = Vector2(pillarbox_width, 0) for centered image
```

Godot's `viewport + keep` stretch mode handles this automatically — this formula is for reference and for any system (e.g., OS cursor mapping) that needs to invert the transform.

### Frame Budget

| Budget | Value | Notes |
|---|---|---|
| Target frame rate | `60 fps` | Locked — `Engine.max_fps = 60` in project settings |
| Frame budget | `16.6ms` | All subsystems (physics, AI, rendering) must fit |
| VSync | Enabled | Prevents tearing; enforces 60fps ceiling on capable displays |

---

## 5. Edge Cases

**Q: The player's display is exactly 4:3 (e.g., 1024×768, an old monitor).**
A: No pillarbox bars. The game fills the display at the nearest integer scale. At 1024×768: scale = 1 (720×540 centered with small letterbox top/bottom from the 768 height). At 1440×1080: scale = 2, fills perfectly.

**Q: The player's display is narrower than 4:3 (portrait orientation or unusual aspect).**
A: Godot's `viewport + keep` handles this — the game image is letterboxed vertically (black bars top and bottom) to fit. The 4:3 content is never cropped. This is an edge case for unusual hardware only; no special handling required beyond the stretch mode setting.

**Q: The player resizes the window to a non-integer scale (e.g., drags it to 1100×825).**
A: Godot upscales smoothly at non-integer scales. Nearest-neighbor filtering is still applied — pixels may not be perfectly uniform at non-integer scales, but this is acceptable behavior for a resizable window. The recommended presentation (integer scale) is communicated in the options menu. We do not lock the window to integer sizes.

**Q: A frame takes longer than 16.6ms — does the game drop below 60fps?**
A: Yes, if a single frame exceeds budget, that frame drops. The 60fps lock is a design target and performance budget constraint — not a technical guarantee against all possible hardware scenarios. On the minimum spec hardware (integrated graphics, 4GB RAM, 2013+ CPU), all BONNIE systems must be profiled to fit within 16.6ms. If a system causes frame drops on minimum spec hardware, it must be optimized before shipping.

**Q: VSync is disabled by the player in settings.**
A: Permitted. `Engine.max_fps = 60` still caps the frame rate. Screen tearing may occur — this is the player's choice. The game does not force VSync.

**Q: A mode switch (mini-game cut-in, feeding cutscene) causes a frame drop at the transition point.**
A: This is a bug. The 60fps lock is unconditional across all view changes. Any transition that drops frames must be fixed — preload assets, use deferred loading, or restructure the transition. A dropped frame at a mode switch is not acceptable.

---

## 6. Dependencies

**This system depends on:**
- Nothing. Viewport Config is a foundation-layer system with no upstream dependencies. All values are derived from project settings and hardware detection at launch.

**Systems that depend on this:**
- **Camera System (4)** — moves through unbounded world space, framing a 720×540 window. All camera math (look-ahead, deadzone, lerp) uses world-space pixels.
- **BONNIE Traversal System (6)** — all physics constants (speeds, radii, thresholds) are world-space pixels. Changing the viewport size does not change these values, but changing the art scale would require full recalibration of `bonnie-traversal.md §4`.
- **Level Manager (5)** — levels are authored in world space at any size. Room boundary triggers and transition zones are world-space pixel coordinates, not viewport-relative.
- **Interactive Object System (7)** — object positions and interaction radii are world-space pixels. Objects exist in the world independent of what the viewport currently shows.
- **Parallax Background System (25)** — parallax offset calculations reference the camera's position within the 720×540 space.
- **Aseprite Export Pipeline (26)** — all source art is authored at 720×540 native scale. The pipeline's output format (PNG sprite sheets) must match this resolution contract.
- **All UI systems (23, 24)** — UI elements are positioned and sized within the 720×540 viewport.

**Bidirectional note:** The BONNIE Traversal GDD (`bonnie-traversal.md §6`) already lists Camera System as a dependent and references this viewport contract. No conflict.

---

## 7. Tuning Knobs

| Knob | Default | Safe Range | What It Affects | What Breaks Outside Range |
|---|---|---|---|---|
| `INTERNAL_WIDTH` | `720` | **Fixed — do not change** | The viewport window width in world-space pixels. Does NOT constrain level width. | Changing this invalidates every physics constant, UI position, and camera value across all GDDs. Requires full recalibration of all systems. |
| `INTERNAL_HEIGHT` | `540` | **Fixed — do not change** | The viewport window height in world-space pixels. Does NOT constrain level height. | Same as above. |
| `default_window_scale` | `2` (1440×1080) | `1–4` | The window size presented on first launch. | Below 1: impossible. Above 4: window exceeds most displays at this resolution. |
| `target_fps` | `60` | **Fixed — do not change** | Frame budget for all subsystems. All performance profiling targets this value. | Changing this invalidates all performance budgets and raises the hardware floor. |
| `vsync_enabled` | `true` | `true / false` | Whether VSync is on by default. Player can override in settings. | No gameplay breakage — affects tearing only. |
| `pillarbox_color` | `#000000` | Any color | Color of bars on widescreen displays. | No gameplay impact. Aesthetic choice only. |

**Note:** This system has almost no tuning knobs because it is intentionally locked. The 720×540 viewport window / 4:3 / 60fps / nearest-neighbor combination is a design identity decision, not a configurable parameter. `INTERNAL_WIDTH` and `INTERNAL_HEIGHT` define the **viewport window size only** — world space and level dimensions are unbounded. Future agents must not propose changing these values without an Architecture Decision Record.

---

## 8. Acceptance Criteria

**AC-V01: Viewport window is 720×540**
- [ ] `ProjectSettings.display/window/size/viewport_width` = `720`
- [ ] `ProjectSettings.display/window/size/viewport_height` = `540`
- [ ] In-game: a sprite positioned at `(0, 0)` and `(719, 539)` are both visible at the viewport edges

**AC-V02: Nearest-neighbor filtering is active throughout**
- [ ] All imported textures have `Filter: Nearest` in their import settings (no `Linear`)
- [ ] Upscaling the window to 2× or 4× produces no blur — pixels are uniform and sharp-edged

**AC-V03: 4:3 aspect ratio is maintained on all displays**
- [ ] On a 1920×1080 display: game image is 1440×1080, centered, with 240px black bars each side
- [ ] On a 2560×1440 display: game image is 1920×1440 (or nearest integer scale), pillarboxed
- [ ] On a 1440×1080 display: game image fills the window with no bars
- [ ] Game content is never stretched or cropped on any tested display

**AC-V04: 60fps lock holds through all view changes**
- [ ] Standard gameplay: `Engine.get_frames_per_second()` reads 60 on minimum spec hardware
- [ ] During a room transition (camera lerping to new anchor): no dropped frames
- [ ] During a mini-game cut-in: no dropped frames at the transition point
- [ ] During the feeding cutscene entry: no dropped frames at the transition point

**AC-V05: World space is not constrained to viewport dimensions**
- [ ] A test level wider than 720px exists and BONNIE can traverse it with the camera following
- [ ] A test level taller than 540px exists and BONNIE can traverse it vertically with the camera following
- [ ] No system throws an error or clips content when BONNIE moves beyond the initial 720×540 area

**AC-V06: Default window launches at 2× integer scale**
- [ ] On first launch (no saved settings): window opens at 1440×1080
- [ ] Window is resizable — player can drag to any size without content distortion

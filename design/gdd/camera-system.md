# System GDD: Camera System

> **Status**: Approved
> **Author**: Michael Raftery + Hawaii Zeke
> **Last Updated**: 2026-04-08
> **System #**: 4 (Camera System)
> **Priority**: MVP — Core Layer
> **Implements Pillar**: "BONNIE Moves Like She Means It" (primary); "Every Space is a Playground" (supporting)

---

## 1. Overview

The Camera System governs how the 720×540 viewport window moves through world space as BONNIE traverses the environment. It is not a simple character-following camera — it is an active gameplay system whose primary function is to give the player the information they need, exactly when they need it. The camera leads BONNIE's movement direction, scaling its look-ahead distance based on her current movement state, so that at full sprint the player sees what's coming before they're in it. Vertical framing keeps BONNIE in the lower third of the viewport — cat's-eye level, more ground than sky — so the environment reads as a space BONNIE inhabits rather than observes. During approach to geometry edges, the camera biases toward the surface to ensure the player sees a ledge before the Ledge Parry window opens. The camera system is the delivery mechanism for traversal feel: if BONNIE moves right and the camera doesn't anticipate it, every momentum mechanic in the traversal system feels worse.

---

## 2. Player Fantasy

The player never thinks about the camera. BONNIE runs flat-out across the kitchen and the world opens ahead of her — she hasn't hit the counter yet but the player already sees it coming, already knows they're about to slide. The camera does that work silently. At full sprint it feels like BONNIE is being chased by the viewport; at a sneak it feels like BONNIE is in control of what she reveals. Neither feeling announces itself as camera behavior. It just feels right.

When BONNIE is falling toward a ledge, the player sees the ledge. Not because the camera telegraphs it with a prompt or a flash — but because the framing was always going to show it. The moment when the parry window opens and the player grabs feels like skill because they had the information. The moment when they miss feels like their timing was off, not like the camera failed them.

Holding the zoom key is how BONNIE reads the room before she enters it. The camera pulls back smoothly — the player controls how far. A slight pull-back reveals the next platform, the NPC's patrol loop, the gap BONNIE needs to squeeze through. A deep pull-back reveals the whole room's layout: where Michael is sitting, what's on the counter, which path through the furniture makes the most sense. At deep zoom, individual pixels are small — NPC expressions aren't readable, small objects blur into their surroundings. That's the trade-off, and it's intentional. Deep recon gives you space at the cost of detail. Releasing the key snaps back to normal. No menus, no mode switch — just a held breath, a look around, and then BONNIE moves.

The 4:3 viewport at cat's-eye level frames every room as BONNIE would experience it: dense, close, readable. The player sees furniture from below. Counters are destinations, not backdrops. The world is big because BONNIE is small, and the camera never lets you forget which one you are.

---

## 3. Detailed Rules

### Core Camera Behavior

**1. Look-ahead by movement state**

The camera leads BONNIE in her current movement direction by a state-scaled distance. Look-ahead is applied as a world-space offset from BONNIE's position toward her facing direction. The camera lerps toward the look-ahead target each frame — it anticipates, it does not snap.

| Movement State | Look-ahead Distance | Rationale |
|---|---|---|
| IDLE | `0 px` | BONNIE is still — camera centers on her |
| SNEAKING | `40 px` | Minimal lead — deliberate, hunting mode |
| WALKING | `80 px` | Moderate lead — conversational awareness |
| RUNNING | `180 px` | Significant lead — at 420 px/s the player needs advance warning |
| SLIDING | `220 px` | Maximum lead — BONNIE is committed, player needs the most warning |
| JUMPING / FALLING | `120 px` horizontal | Maintains awareness during airborne movement |
| CLIMBING | `60 px` vertical (upward) | Leads in the climb direction only |
| SQUEEZING | `0 px` — locks to room view | BONNIE is hidden; no character tracking during squeeze |
| DAZED / ROUGH_LANDING | `0 px` — re-centers on BONNIE | Recovery states; camera pulls back to her position |
| LEDGE_PULLUP | `60 px` horizontal (surface direction) | Reveals what BONNIE is pulling up onto |

These are prototype starting values. All look-ahead distances are tuning knobs — recalibrate during playtest (see §7).

**2. Vertical framing**

BONNIE's center sits at `y = 380` of 540 in the viewport — approximately 70% down the screen. This is cat's-eye level: more floor and environment below, minimal ceiling above. BONNIE inhabits the bottom portion of the world she's navigating.

Adjust during prototype if the framing feels wrong — see §7 for safe range.

**3. Direction reversal — smooth catch-up**

When BONNIE reverses direction, the look-ahead target flips sides. The camera does not snap or whip — it lerps to the new target using `camera_catch_up_speed`. The player may briefly see slightly behind BONNIE during catch-up. This is intentional: hard reversals during a slide or skid should feel like a physics consequence, not camera assistance.

**4. Ledge approach bias**

During FALLING or JUMPING, when BONNIE is within `ledge_bias_activation_radius = 80px` of any geometry edge or climbable surface, the camera introduces an additional look-ahead offset biased toward that surface. This bias activates before the Ledge Parry detection radius (`parry_detection_radius = 24px`), ensuring the ledge is visible to the player before the parry window opens. At average falling speed, 80px provides approximately 3–4 frames of ledge visibility ahead of the parry window.

**5. Room transitions**

When BONNIE crosses a room boundary trigger, the camera lerps smoothly to the new room's anchor point — no cut, no hard snap. BONNIE continues moving normally during the transition. The 60fps lock holds unconditionally through room transitions (per `viewport-config.md §3`, Rule 7).

---

### Recon Zoom System

**Trigger:** Dedicated hold input (`zoom` action — defined in `input-system.md`). Available in all movement states. Releasing the button returns to normal zoom.

**Zoom behavior:** Analog and continuous. While the zoom button is held, the camera zoom level decreases smoothly at `zoom_out_rate` per second, showing progressively more world space. Releasing the button returns to `zoom_normal` at `zoom_return_rate` per second.

**Zoom range:**

| Value | Zoom level | World space shown | BONNIE's screen size |
|---|---|---|---|
| Normal | `1.0` | 720×540 px | 100% |
| LOD threshold | `0.75` | 960×720 px | ~75% |
| Max zoom-out | `0.33` | ~2160×1620 px | ~33% — potentially shows multiple rooms |

**LOD sprite system:** At zoom levels below `zoom_lod_threshold = 0.75`, sprites swap to their zoom-out LOD variants — pixel art authored specifically for the smaller display scale. LOD sprites are designed to read clearly at reduced size; they are not downsampled versions of full sprites.

- LOD sprites are a **Vertical Slice** deliverable. The prototype uses colored rectangles; LOD variants are not required for physics validation.
- Naming convention: `bonnie_run_lod.png` (append `_lod` suffix to all LOD exports)
- Swap mechanism: `AnimatedSprite2D` holds two SpriteFrames resources (full + LOD); camera zoom signal triggers swap at threshold crossing.

**What is and isn't readable at max zoom-out (0.33):**
- ✅ Readable: full room layout, platform positions, NPC locations, large furniture, room connections
- ❌ Not readable: NPC facial expressions, small interactive objects, fine environmental detail
- This information trade-off is intentional. Recon gives spatial awareness, not forensic detail.

---

### Interactions with Other Systems

- **BONNIE Traversal (6):** Camera reads `current_state` and `velocity` every frame to determine look-ahead distance and direction. No writes back to traversal.
- **Input System (1):** `zoom` action is defined in the input map and read as a held boolean — no buffering or edge detection needed.
- **Viewport Config (2):** All camera math operates in world-space pixels. The camera's zoom property scales how much world space is shown — it does not change the 720×540 internal render resolution.
- **Reactive NPC System (9):** No direct interaction. NPCs are unaware of camera zoom state.
- **Aseprite Export Pipeline (26):** Every gameplay sprite requires a LOD variant (Vertical Slice scope). Pipeline extension documented as T-ART-04.
- **Parallax Background System (25):** Reads the camera's world-space position and current zoom level each frame to compute parallax layer offsets.

---

## 4. Formulas

### Look-ahead Target

```gdscript
# Compute the camera's target position each frame
func get_camera_target(bonnie: CharacterBody2D) -> Vector2:
    var look_ahead_distance: float = LOOK_AHEAD_BY_STATE[bonnie.current_state]
    var look_ahead_offset := Vector2(bonnie.facing_direction * look_ahead_distance, 0.0)

    # Vertical framing: BONNIE sits at y=380 of 540 in the viewport
    var vertical_offset := Vector2(0.0, -(540.0 * 0.5 - 380.0))  # = -110px

    return bonnie.global_position + look_ahead_offset + vertical_offset
```

### Camera Lerp (Smooth Follow)

```gdscript
func _process(delta: float) -> void:
    var target := get_camera_target(bonnie)

    # Apply ledge bias if active
    if ledge_bias_active:
        target += ledge_bias_offset

    global_position = global_position.lerp(target, camera_lerp_speed * delta)
```

| Variable | Description | Default |
|---|---|---|
| `camera_lerp_speed` | How fast the camera catches up to its target (higher = snappier) | `6.0` |
| `camera_catch_up_speed` | Lerp multiplier applied during direction reversal | `4.0` |

### Ledge Bias

```gdscript
# Called each frame during FALLING or JUMPING
func compute_ledge_bias(bonnie_pos: Vector2, nearby_geometry: Array) -> Vector2:
    for surface in nearby_geometry:
        var dist := bonnie_pos.distance_to(surface.closest_point(bonnie_pos))
        if dist <= ledge_bias_activation_radius:
            var bias_direction := (surface.closest_point(bonnie_pos) - bonnie_pos).normalized()
            return bias_direction * ledge_bias_strength
    return Vector2.ZERO
```

| Variable | Description | Default |
|---|---|---|
| `ledge_bias_activation_radius` | Distance at which ledge bias activates | `80 px` |
| `ledge_bias_strength` | Maximum pixel offset added toward the surface | `40 px` |

### Recon Zoom

```gdscript
func _process(delta: float) -> void:
    if Input.is_action_pressed(&"zoom"):
        current_zoom = max(zoom_max_out, current_zoom - zoom_out_rate * delta)
    else:
        current_zoom = min(zoom_normal, current_zoom + zoom_return_rate * delta)

    zoom = Vector2(current_zoom, current_zoom)

    # LOD swap
    var use_lod := current_zoom < zoom_lod_threshold
    emit_signal(&"zoom_lod_changed", use_lod)
```

| Variable | Description | Default |
|---|---|---|
| `zoom_normal` | Default zoom level (full viewport) | `1.0` |
| `zoom_max_out` | Maximum zoom-out (deepest recon) | `0.33` |
| `zoom_lod_threshold` | Zoom level below which LOD sprites activate | `0.75` |
| `zoom_out_rate` | Zoom decrease per second while button held | `0.8` (full travel in ~0.8s) |
| `zoom_return_rate` | Zoom increase per second on release | `2.0` (snaps back quickly) |

*Note: `AnimationPlayer.play()` calls throughout the camera system must use StringName syntax: `play(&"animation_name")` — per Godot 4.6 breaking change (see `docs/engine-reference/godot/breaking-changes.md`).*

---

## 5. Edge Cases

**Q: BONNIE enters SQUEEZING — camera locks to room view. What exactly does "room view" mean?**
A: The camera stops tracking BONNIE's position and holds at the center of the current room's bounding box. If BONNIE squeezes out of the visible area, the player loses sight of her — this is intentional. She's hidden. The camera resumes tracking when BONNIE exits SQUEEZING.

**Q: BONNIE is mid-recon zoom (e.g., at 0.6) and transitions to RUNNING. Does look-ahead still apply?**
A: Yes. Look-ahead is applied independently of zoom level. At 0.6 zoom, the 180px running look-ahead still shifts the camera target — it just does so within a wider visible area. The two systems are additive.

**Q: BONNIE is zoomed out to 0.33 and crosses a room boundary. What happens?**
A: The room transition lerp fires normally. The zoom level is preserved through the transition — the player keeps their recon view as the camera moves to the new room anchor. Releasing zoom after the transition returns to normal at `zoom_return_rate`.

**Q: Ledge bias activates on geometry that isn't a ledge — e.g., a wall BONNIE is running past.**
A: The bias calculation checks for geometry within `ledge_bias_activation_radius` during FALLING or JUMPING only — not during grounded states. Walls encountered while running do not trigger bias. If bias still activates on irrelevant airborne geometry (e.g., ceiling tiles), increase the specificity of the geometry query to check for edge/ledge geometry tags rather than all collision shapes.

**Q: BONNIE is DAZED or in ROUGH_LANDING while the zoom button is held.**
A: Zoom input is still accepted and zoom level still changes during recovery states. The camera re-centers on BONNIE (look-ahead = 0px) but the player can still pull out to survey the room. This is useful — a rough landing is a good moment to assess where you landed.

**Q: The ledge bias and recon zoom are active simultaneously — do they conflict?**
A: No. Ledge bias is a world-space offset applied to the camera target. Recon zoom is a scale applied to the viewport. They operate on independent properties and do not interfere.

**Q: BONNIE transitions from RUNNING (look-ahead 180px) to IDLE instantly (look-ahead 0px) — does the camera snap?**
A: No. The camera lerps toward its target at `camera_lerp_speed`. The look-ahead target changes immediately on state change, but the camera catches up smoothly over the next few frames. Abrupt state changes produce a smooth camera glide back to center, not a snap.

---

## 6. Dependencies

**This system depends on:**
- **BONNIE Traversal System (6)** — reads `current_state` and `velocity` every frame to determine look-ahead distance, direction, and ledge bias activation. The camera cannot function without knowing BONNIE's movement state. Any new state added to the traversal system must have a corresponding look-ahead value defined here.
- **Viewport Config (2)** — the 720×540 viewport window, `viewport + keep` stretch mode, and 60fps lock are all prerequisites. All camera math assumes this coordinate space. Approved: `design/gdd/viewport-config.md`.
- **Input System (1)** — the `zoom` action must be defined in the input map before the recon zoom system can read it.

**Systems that depend on this:**
- **Parallax Background System (25)** — reads the camera's world-space position and `current_zoom` each frame to compute parallax layer offsets. The camera must emit a signal or expose a property for both.
- **Aseprite Export Pipeline (26)** — the LOD sprite system (activated at `zoom_lod_threshold = 0.75`) requires every gameplay sprite to have a LOD variant. This is a pipeline production requirement: T-ART-04 (Vertical Slice scope).

**Bidirectional note:** `bonnie-traversal.md §6` explicitly states: *"Camera quality is co-equal with traversal feel. Bad camera = bad game. Camera system must be prototyped alongside traversal, not after."* This GDD satisfies that requirement. The traversal GDD lists Camera System as a dependent — consistent with this document.

---

## 7. Tuning Knobs

### Look-ahead Distances

| Knob | Default | Safe Range | What It Affects |
|---|---|---|---|
| `look_ahead_idle` | `0 px` | `0–20` | Camera position when BONNIE is still |
| `look_ahead_sneaking` | `40 px` | `20–80` | How much warning the player gets while sneaking |
| `look_ahead_walking` | `80 px` | `40–140` | Spatial awareness at walk speed |
| `look_ahead_running` | `180 px` | `120–260` | Critical — too low and running feels blind; too high and camera feels detached |
| `look_ahead_sliding` | `220 px` | `160–300` | Maximum lead; must exceed running to feel like "committed" |
| `look_ahead_airborne` | `120 px` | `60–180` | Horizontal lead during JUMPING/FALLING |
| `look_ahead_climbing` | `60 px` | `30–100` | Vertical lead during CLIMBING |
| `look_ahead_pullup` | `60 px` | `30–100` | Lead toward surface after parry success |

### Camera Motion

| Knob | Default | Safe Range | What It Affects |
|---|---|---|---|
| `camera_lerp_speed` | `6.0` | `3.0–12.0` | Camera responsiveness. Too low = sluggish/floaty; too high = jittery |
| `camera_catch_up_speed` | `4.0` | `2.0–8.0` | Speed of catch-up after direction reversal. Lower = more cinematic lag |
| `bonnie_vertical_position` | `380 px` | `340–420` | BONNIE's vertical position in the 540px viewport. Lower = more grounded |

### Ledge Bias

| Knob | Default | Safe Range | What It Affects |
|---|---|---|---|
| `ledge_bias_activation_radius` | `80 px` | `48–120` | Too large: bias fires on irrelevant geometry; too small: no warning before parry window |
| `ledge_bias_strength` | `40 px` | `20–80` | How aggressively the camera shifts toward the surface |

### Recon Zoom

| Knob | Default | Safe Range | What It Affects |
|---|---|---|---|
| `zoom_normal` | `1.0` | **Fixed** | Native viewport scale — do not change |
| `zoom_max_out` | `0.33` | `0.25–0.5` | Maximum zoom-out depth. Below 0.25: BONNIE too small to track; above 0.5: insufficient recon value |
| `zoom_lod_threshold` | `0.75` | `0.6–0.85` | Where LOD sprites activate. Must stay below `zoom_normal` and above `zoom_max_out` |
| `zoom_out_rate` | `0.8 /s` | `0.4–2.0` | How fast the camera zooms out when held. Lower = more deliberate recon ritual |
| `zoom_return_rate` | `2.0 /s` | `1.0–4.0` | How fast zoom snaps back on release. Higher = snappier return to action |

---

## 8. Acceptance Criteria

**AC-C01: Look-ahead leads movement at the correct distances**
- [ ] BONNIE running right: camera target is visibly ahead of her in the run direction
- [ ] BONNIE stopping from full run: camera smoothly catches up to center — no snap
- [ ] BONNIE in SNEAKING: look-ahead is visibly smaller than WALKING; difference is perceptible
- [ ] BONNIE in SLIDING: camera lead is the widest of any grounded state

**AC-C02: Vertical framing is cat's-eye level**
- [ ] BONNIE's center sits at approximately y=380 of 540 in the viewport
- [ ] More floor/environment is visible below BONNIE than ceiling/sky above her

**AC-C03: Ledge Parry is visible before the window opens**
- [ ] BONNIE falling toward a ledge: ledge is visible in the viewport before BONNIE's body reaches `parry_detection_radius` (24px)
- [ ] Bias does not activate during grounded states — running past a wall does not cause camera wobble
- [ ] A skilled player can execute the Ledge Parry using only visual information (no prompts, no highlights)

**AC-C04: Room transitions are seamless**
- [ ] Crossing a room boundary: camera lerps smoothly to new room anchor with no cut or snap
- [ ] `Engine.get_frames_per_second()` reads 60 during the transition — no dropped frames
- [ ] BONNIE continues moving normally throughout the transition

**AC-C05: SQUEEZING locks camera to room view**
- [ ] BONNIE enters SQUEEZING: camera stops tracking her and holds at room center
- [ ] BONNIE exits SQUEEZING: camera resumes tracking immediately

**AC-C06: Recon zoom functions correctly**
- [ ] Holding zoom button: camera pulls back smoothly and continuously toward `zoom_max_out = 0.33`
- [ ] At 0.33 zoom: full room layout is visible; potentially adjacent rooms visible; BONNIE at ~33% normal screen size
- [ ] Releasing zoom button: camera returns to `zoom_normal = 1.0` at `zoom_return_rate`
- [ ] Zoom works in all movement states including RUNNING and FALLING

**AC-C07: LOD sprites activate at threshold**
- [ ] At `zoom = 0.76` (above threshold): full-detail sprites render
- [ ] At `zoom = 0.74` (below threshold): LOD sprites render — swap is clean, no flash or pop
- [ ] LOD sprites read clearly at `zoom_max_out = 0.33` — room layout, NPC locations, platform positions identifiable
- [ ] *(Vertical Slice scope — not required for prototype)*

**AC-C08: Look-ahead and zoom are independent and additive**
- [ ] BONNIE running right while zoom is held at 0.6: both running look-ahead (180px) and zoom-out are active simultaneously
- [ ] No conflict or override between the two systems

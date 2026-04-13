# System GDD: Input System

> **Status**: Approved
> **Author**: Michael Raftery + Hawaii Zeke
> **Last Updated**: 2026-04-09
> **System #**: 1 (Input System)
> **Priority**: MVP — Foundation Layer
> **Implements Pillar**: "BONNIE Moves Like She Means It" (primary)

---

## 1. Overview

The Input System is the translation layer between hardware events and BONNIE's verbs. It defines the canonical set of named actions the game responds to, the mapping of hardware inputs to those actions, buffering rules for time-sensitive inputs, analog-to-digital conversion thresholds for controller support, and the full remapping interface required for accessibility.

Every system that reads player intent — traversal, camera, mini-games — reads from this system's action map. No system polls hardware directly. The input map is the single source of truth for what BONNIE can be told to do.

Two buffering philosophies coexist by design: `jump` uses pre-land buffering (a queued jump fires on the next landing), because platformer feel requires it; `grab` uses no buffer at all, because the Ledge Parry is a pure timing mechanic — early input is a miss, not a hold. This distinction is intentional and must be preserved across any input system refactor.

---

## 2. Player Fantasy

The player never thinks about the input system. BONNIE responds to intent, not to buttons. The moment a directional key is pressed, BONNIE is already moving — no startup lag, no animation gate, no waiting. Controls are snappy because the input system delivers actions to the traversal system in the same frame they arrive.

The one place input design becomes consciously felt is the Ledge Parry: the player learns — through failure, not through a tutorial — that the grab button is a *now* button, not an *eventually* button. There is no forgiveness window. Pressing it too early is the same as not pressing it. When they finally nail the timing, it feels like skill, not luck. That clarity is a design property of the input system, not just the traversal system.

Gamepad and keyboard/mouse feel equally native. No layout is a port of the other. Accessibility remapping means every player can put every action where their hands naturally rest.

---

## 3. Detailed Rules

### 3.1 Action Map

All 10 actions are fully remappable. No system polls hardware directly — all input is read through named actions.

| Action | Input Type | Default KB/Mouse | Default Gamepad | Notes |
|--------|-----------|-----------------|-----------------|-------|
| `move_left` | Digital + Analog | A, ← | Left Stick Left, D-pad ← | Analog magnitude used for sneak_threshold check |
| `move_right` | Digital + Analog | D, → | Left Stick Right, D-pad → | Analog magnitude used for sneak_threshold check |
| `move_up` | Digital + Analog | W, ↑ | Left Stick Up, D-pad ↑ | Fires in all states; consumed only during CLIMBING (drives ascent speed). Ignored by traversal in all other states. |
| `move_down` | Digital + Analog | S, ↓ | Left Stick Down, D-pad ↓ | Context: slide trigger during RUNNING; descend during CLIMBING; drop if held past bottom of surface |
| `run` | Digital (hold) | Left Shift | X / □ | Hold to run; release returns to WALKING. Tap has no effect. |
| `jump` | Digital (tap + hold) | Space | A / × | Tap = hop; hold = full arc. Pre-land buffer active (see §3.2). During CLIMBING: wall jump. |
| `sneak` | Analog (hold) | Left Ctrl | LT | Any press above deadzone activates sneak. Also triggers via stick magnitude — see §3.3. |
| `grab` | Digital (instant) | E | RB | **Ledge Parry only.** Valid during FALLING or JUMPING near geometry. NO buffer. Frame-exact. Clamber-up from CLIMBING is automatic — `grab` is not used. |
| `zoom` | Digital (hold) | RMB | RT | Any press = zoom active. Analog magnitude unused — on/off. Available in all movement states. |
| `interact` | Digital (press) | F | Y / △ | *Provisional.* Reserved for Social System (rub, headbutt, sit near). Trigger conditions defined in `bidirectional-social-system.md`. |

**Slide:** No dedicated action. `move_down` during RUNNING above `slide_trigger_speed` = explicit slide trigger. Auto-slide also fires from opposing momentum — no input required.

**Drop / Clamber-up:** No dedicated `drop` action. `move_down` during CLIMBING = descend; past the bottom edge = drops to FALLING. Reaching the **top** of a Climbable surface while CLIMBING = auto-transition to LEDGE_PULLUP (same animation as Ledge Parry success). No additional input required.

**Cross-system note:** `bonnie-traversal.md` §3.1 CLIMBING exits correctly states "LEDGE_PULLUP (reach top of surface) — same animation as Ledge Parry success, auto-triggered, no input required." Verified Session 005.

### 3.2 Input Buffering Rules

Input buffering: when the player presses an action slightly early, the input is "remembered" and executed as soon as conditions allow. Buffering makes controls feel forgiving and anticipatory. Deliberate *removal* of buffering makes an action feel like a pure timing test. BONNIE uses both, intentionally, for different actions.

**Buffered actions:**

| Action | Buffer Type | Buffer Window | Behavior |
|--------|-------------|---------------|----------|
| `jump` | Pre-land | `jump_buffer_frames` (4–8 frames) | Jump pressed before BONNIE lands → fires on the next landing contact. Player gets credit for good timing. |
| `jump` | Coyote time | `coyote_time_frames` (4–6 frames) | BONNIE walks off a ledge → jump is still available for `coyote_time_frames` after leaving ground. Feels like BONNIE was still on the ledge. Never announced to the player. |

**Unbuffered actions (exact timing only):**

| Action | Rationale |
|--------|-----------|
| `grab` | The Ledge Parry is a pure timing mechanic. An early press is a miss. A buffered grab would allow the player to mash the button and eventually succeed — removing skill from the parry. No buffer. Frame-exact. |
| All others | `run`, `sneak`, `zoom`, `move_*`, `interact` — hold-or-press semantics. No buffering concept applies. |

**What buffering is NOT:**
Coyote time is not an input buffer — it extends when BONNIE *can* jump, not when the jump *input* is accepted. The jump buffer extends when an early input is accepted. Both are invisible to the player. Both should feel like BONNIE has cat-like grace.

### 3.3 Analog vs. Digital Handling

BONNIE supports keyboard/mouse and gamepad from the same action map. Godot reads all 4 directional actions via `Input.get_vector("move_left", "move_right", "move_up", "move_down")`, returning a normalized `Vector2` that works correctly for both keyboard (digital, magnitude = 1.0) and analog stick (continuous, magnitude 0.0–1.0).

**Analog stick dead zone:**

| Parameter | Default | Effect |
|-----------|---------|--------|
| `stick_deadzone` | `0.2` | Stick inputs below this magnitude are ignored. Prevents drift. Applied globally to all 4 movement actions. |

**Sneak threshold — dual trigger paths:**

`sneak` activates via either:
1. **Dedicated button held** (`Left Ctrl` / LT) — always activates sneak regardless of stick position
2. **Analog stick magnitude below `sneak_threshold`** — when moving, if stick magnitude < `sneak_threshold`, BONNIE automatically enters SNEAKING without pressing the sneak button. This allows fine analog control: barely push the stick to sneak, push it fully to walk/run.

| Parameter | Default | Effect |
|-----------|---------|--------|
| `sneak_threshold` | `0.35` | Stick magnitude below this = auto-sneak. Above this = WALKING (or RUNNING if run held). |

*On keyboard, this path never triggers — digital keys always report full magnitude (1.0). Keyboard players use the dedicated sneak button.*

**Analog triggers treated as digital:**

| Action | Hardware | Behavior |
|--------|----------|----------|
| `sneak` | LT (analog trigger) | Any analog value above `trigger_deadzone` = sneak active. Magnitude unused beyond on/off. |
| `zoom` | RT (analog trigger) | Any analog value above `trigger_deadzone` = zoom active. Camera zoom is continuous (see camera-system.md §4); the trigger magnitude does not control zoom speed — that is time-based. |

| Parameter | Default | Effect |
|-----------|---------|--------|
| `trigger_deadzone` | `0.1` | Trigger inputs below this are ignored. Prevents phantom sneak/zoom from bumping the trigger. |

**Jump hold — duration-based, not pressure-based:**

`jump` tap vs. hold differentiation is measured by *held duration*, not analog pressure. Both keyboard Space and gamepad A/× are digital. The traversal system measures `jump_hold_timer` from the moment of press to determine hop vs. full arc — the input system just delivers the `is_action_pressed("jump")` boolean each frame.

### 3.4 Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **BONNIE Traversal (6)** | Reads from Input | Polls all 10 actions each `_physics_process()` frame. Uses `Input.get_vector()` for directional movement; `is_action_pressed()` for hold actions (run, sneak, zoom, grab); `is_action_just_pressed()` for edge-detection (jump initiation, grab timing). |
| **Camera System (4)** | Reads from Input | Reads `is_action_pressed("zoom")` in `_process()` each frame to drive recon zoom. No edge detection needed — held boolean only. |
| **Mini-Game Framework (20)** | Reads from Input | *Provisional — Mini-Game GDD not yet designed.* Mini-games may require additional action mappings (e.g., timing actions for specific sequences). Those actions will be added to this GDD when Mini-Game Framework is designed. |
| **Bidirectional Social System (12)** | Reads from Input | *Provisional.* Will read `interact` action. Exact conditions (proximity requirements, NPC state gates) defined in `bidirectional-social-system.md`. |
| **Accessibility / Settings UI** | Writes to Input | The settings screen (Full Vision scope) exposes the full remapping interface, writing to Godot's `InputMap` at runtime. All 10 actions must be individually remappable with no hardcoded fallbacks. |

**No system writes to the Input System during gameplay.** Action bindings are set at startup (from saved config or defaults) and are only changed through the settings UI. The input map is read-only during play.

**Accessibility cross-reference:** `autorun_enabled` is an accessibility toggle defined in `bonnie-traversal.md §3.1` — it is a traversal system responsibility, not an input system responsibility. When enabled, sustained directional input past `run_buildup_time` auto-escalates to RUNNING without requiring the `run` button held. Implementers working on `run` input behavior should read that section.

---

## 4. Formulas

The Input System has no complex mathematical formulas. Its computations are threshold comparisons and Godot API calls. These are the two meaningful ones:

### Movement Vector

```gdscript
# Called each _physics_process() frame by traversal system
func get_movement_vector() -> Vector2:
    return Input.get_vector(
        &"move_left", &"move_right", &"move_up", &"move_down",
        stick_deadzone  # 0.2 default; filters drift below threshold
    )
```

`Input.get_vector()` normalizes the result to unit length for diagonal movement, preventing faster diagonal movement on keyboard. Deadzone is applied per-axis before normalization.

| Variable | Description | Default |
|----------|-------------|---------|
| `stick_deadzone` | Minimum analog magnitude to register movement | `0.2` |

### Sneak Auto-Trigger (Analog Path)

```gdscript
# Called by traversal system when determining movement state
func is_auto_sneaking(input_vec: Vector2) -> bool:
    var magnitude: float = input_vec.length()
    return magnitude > stick_deadzone and magnitude < sneak_threshold
```

Returns `true` when the player is moving (above deadzone) but moving slowly (below sneak threshold). Only meaningful on analog input — keyboard always reports `1.0` or `0.0`.

| Variable | Description | Default |
|----------|-------------|---------|
| `sneak_threshold` | Stick magnitude below this = auto-sneak | `0.35` |

*Note: `StringName` literals (`&"move_left"`) are required in Godot 4.6 for all `InputMap` lookups — see `docs/engine-reference/godot/breaking-changes.md`.*

---

## 5. Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| `grab` pressed during CLIMBING, RUNNING, IDLE, or any non-airborne state | Input is consumed and ignored. No action fires. | `grab` is valid only during FALLING/JUMPING within `parry_detection_radius`. Outside that context, pressing it has no effect — it is not buffered for later use. |
| `run` and `sneak` held simultaneously | `sneak` wins. BONNIE sneaks. | Conflicting intent resolves in favor of the quieter state. Run cannot override a deliberate sneak hold. |
| Analog stick below `sneak_threshold` AND dedicated sneak button held | Both paths produce the same result — BONNIE sneaks. No conflict. | Two paths to the same state; redundant inputs are harmless. |
| `move_down` pressed while RUNNING above `slide_trigger_speed` | Triggers SLIDING. | Intentional slide. This is the explicit slide input path. |
| `move_down` pressed while RUNNING below `slide_trigger_speed` | No slide. BONNIE decelerates normally or continues at walk. | Below threshold, move_down has no special meaning during ground movement. |
| Player remaps two actions to the same hardware input | Permitted — Godot's `InputMap` allows shared bindings. Both actions fire simultaneously when that input is pressed. The player takes responsibility for any resulting state conflicts. | No enforced exclusivity. Accessibility requires full remapping freedom. |
| Gamepad disconnects mid-play | Input defaults to keyboard/mouse map. If no keyboard is present, all actions report `false`. BONNIE stops moving — no phantom input. | Godot's `InputMap` handles device disconnection gracefully; the game reads `false` for all disconnected device actions. |
| `jump` buffer active at landing, AND BONNIE is in RUNNING state at moment of landing | Buffered jump fires as a running jump — full horizontal momentum preserved. | Jump type is determined by velocity at the moment it fires, not when the buffer was queued. This is the correct behavior: good timing should be rewarded with the better jump. |
| `zoom` held during ROUGH_LANDING or DAZED recovery states | Zoom remains active. Camera re-centers on BONNIE (look-ahead = 0px) but pull-back still works. | Per camera-system.md §5: zoom is valid during recovery states. Explicitly designed to let players survey the room after a rough landing. |
| `grab` pressed exactly 1 frame too early (outside `parry_window_frames`) | Miss. BONNIE continues FALLING. No buffer, no forgiveness. | This is the intended design. The parry is a pure timing mechanic. |

---

## 6. Dependencies

**This system depends on:** Nothing. The Input System is a Foundation Layer root. It has no upstream dependencies and cannot be blocked by other undesigned systems.

**Systems that depend on this:**

| System | Priority | Nature of Dependency | GDD Status |
|--------|----------|----------------------|------------|
| **BONNIE Traversal (6)** | MVP | Reads all 10 actions every physics frame. Cannot function without a defined input map. | Approved — `design/gdd/bonnie-traversal.md` |
| **Camera System (4)** | MVP | Reads `zoom` action. Cannot implement recon zoom without it. | Approved — `design/gdd/camera-system.md` |
| **Bidirectional Social System (12)** | MVP | Reads `interact` action (provisional). Social interactions require a confirmed input binding. | Not yet designed |
| **Mini-Game Framework (20)** | Alpha | May require additional action definitions when designed. | Not yet designed |
| **Accessibility / Settings UI** | Full Vision | Writes to `InputMap` at runtime to apply remapping. The remapping interface can only expose actions that are defined here. | Not yet designed |

**Bidirectional consistency check:**
- `bonnie-traversal.md §6` lists Input System as a dependency ✅
- `camera-system.md §6` lists Input System as a dependency ✅
- Social System and Mini-Game Framework GDDs not yet written — will need to list Input System when authored

---

## 7. Tuning Knobs

| Parameter | Default | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|---------|------------|-------------------|-------------------|
| `stick_deadzone` | `0.2` | `0.1–0.35` | Larger dead zone — requires harder stick push to register movement. Reduces drift on worn controllers. | Smaller dead zone — more sensitive. May cause drift on older hardware. |
| `trigger_deadzone` | `0.1` | `0.05–0.2` | Larger dead zone — requires harder trigger press for sneak/zoom. Prevents phantom activation. | Smaller dead zone — more responsive. May cause phantom sneak/zoom from resting fingers. |
| `sneak_threshold` | `0.35` | `0.2–0.5` | Higher threshold — larger range of stick positions auto-sneak. Fine analog control easier to achieve. | Lower threshold — only very gentle stick pushes auto-sneak. More aggressive feel from partial pushes. |
| `jump_buffer_frames` | `6` | `4–10` | More forgiveness window — jump queued further before landing. Feels more generous. | Smaller window — player must time pre-land jump more precisely. |
| `coyote_time_frames` | `5` | `3–8` | More coyote time — BONNIE can jump longer after walking off a ledge. Very forgiving. | Less coyote time — must jump before leaving the ledge. Less forgiving on edges. |

**Extremes:**
- `jump_buffer_frames` > 10: Jumping can feel "sticky" — a jump queued too far back fires unexpectedly on landing
- `coyote_time_frames` > 8: Starts to feel like BONNIE is floating at ledge edges; breaks the physics-driven feel
- `sneak_threshold` > 0.5: More than half the stick range triggers auto-sneak; intended walking feel lost on gamepad
- `stick_deadzone` > 0.35: Movement requires aggressive stick push; feels unresponsive

---

## 8. Acceptance Criteria

**AC-I01: All default bindings respond correctly**
- [ ] KB: A/← moves left, D/→ moves right, W/↑ climbs up (CLIMBING state only), S/↓ activates slide (RUNNING) / descends (CLIMBING)
- [ ] KB: Space = jump, Left Shift = run, Left Ctrl = sneak, E = grab, F = interact (provisional), RMB = zoom
- [ ] Gamepad: Left Stick and D-pad drive movement; A/× = jump, X/□ = run, LT = sneak, RB = grab, Y/△ = interact (provisional), RT = zoom

**AC-I02: `grab` has no input buffer — pure timing**
- [ ] `grab` pressed 2 frames before entering `parry_window_frames` → miss. BONNIE continues FALLING
- [ ] `grab` pressed on the first valid frame of `parry_window_frames` → parry succeeds
- [ ] `grab` pressed outside FALLING or JUMPING → no action, no queuing

**AC-I03: `jump` pre-land buffer functions**
- [ ] `jump` pressed `jump_buffer_frames` frames before landing → jump fires on landing contact
- [ ] `jump` pressed `jump_buffer_frames + 1` frames before landing → no buffered jump fires; normal landing

**AC-I04: Coyote time functions**
- [ ] BONNIE walks off a ledge → jump input within `coyote_time_frames` frames → jumps successfully
- [ ] BONNIE walks off a ledge → jump input after `coyote_time_frames` expire → falls (no jump)

**AC-I05: Analog movement vector is correct**
- [ ] Keyboard: diagonal movement (A + W simultaneously) reports `Vector2(-0.707, -0.707)` — normalized, not `(-1.0, -1.0)` (which would be ~41% faster)
- [ ] Gamepad: full stick push in any direction reports magnitude ≤ 1.0

**AC-I06: Auto-sneak threshold fires correctly**
- [ ] Gamepad: stick magnitude `0.34` → auto-sneak activates (below `sneak_threshold = 0.35`)
- [ ] Gamepad: stick magnitude `0.36` → walking, no auto-sneak
- [ ] Keyboard: directional key held → no auto-sneak (magnitude = 1.0)

**AC-I07: `run` + `sneak` conflict resolves correctly**
- [ ] Both held simultaneously → BONNIE sneaks. Run does not override sneak.

**AC-I08: `zoom` is available in all movement states**
- [ ] `zoom` held during RUNNING → zoom activates
- [ ] `zoom` held during FALLING → zoom activates
- [ ] `zoom` held during ROUGH_LANDING → zoom activates

**AC-I09: Full remapping — all 10 actions are individually remappable**
- [ ] Each action can be rebound to a different hardware input through the settings interface
- [ ] Remapped bindings persist across sessions (saved to user config)
- [ ] No action has a hardcoded fallback that bypasses the remapping

**AC-I10: No system polls hardware directly**
- [ ] Grep codebase for `Input.is_key_pressed`, `Input.get_joy_axis`, `Input.is_joy_button_pressed` — zero results in gameplay code. All input reads through named actions.

---

## Open Questions

| Question | Owner | Resolution |
|----------|-------|-----------|
| `interact` action — what are the exact trigger conditions? Proximity-only? Button press at any range? NPC state requirements? | Social System GDD (`bidirectional-social-system.md`) | Provisional action reserved. Conditions defined when Social System is designed. |
| `bonnie-traversal.md §3.1` CLIMBING exits says "IDLE (reach top of surface)" — should read "LEDGE_PULLUP (reach top of surface)" | Traversal system implementation | Confirmed design: auto-clamber-up triggers LEDGE_PULLUP. Traversal GDD needs correction before implementation. |
| Does `interact` need an input buffer? | Social System GDD | Unknown until interaction timing requirements are defined. Likely no buffer (presence-based interactions are ambient; button-press interactions should be intentional). |

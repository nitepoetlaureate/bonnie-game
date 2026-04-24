# ADR-001: InputManager — Centralized Input Translation Layer

## Status
Accepted

## Date
2026-04-22

## Context

### Problem Statement
BONNIE's traversal system (13-state FSM) needs reliable, frame-accurate input every physics tick. Multiple systems — traversal, camera, future social interactions, future mini-games — all need to read player intent. The question is: where does input interpretation live, and how do buffering mechanics (jump buffer, coyote time) and device switching get managed without scattering input logic across every consumer?

### Constraints
- 60fps locked — frame budget is 16.6ms, input processing must be negligible
- Keyboard and gamepad must feel equally native (no "ported" layout)
- Ledge Parry (`grab`) is frame-exact with NO buffer — this is core identity, non-negotiable
- Jump buffer and coyote time must be deterministic — identical behavior on every machine at 60fps
- gl_compatibility renderer, 720×540 internal resolution (no GPU-dependent input latency variance)

### Requirements
- Single source of truth for all 10 player actions
- Jump buffer (pre-land) and coyote time (post-ledge) with frame-exact windows
- Analog stick support: deadzone filtering, sneak-threshold auto-trigger
- Device switching detection for UI prompt updates (keyboard ↔ gamepad)
- All actions fully remappable for accessibility
- No gameplay system polls hardware directly — all reads through named actions

## Decision

**InputManager is a centralized autoload (singleton Node) that owns the translation layer between hardware events and BONNIE's verbs.** All gameplay systems read input exclusively through InputManager's public API. No system calls `Input.is_key_pressed()`, `Input.get_joy_axis()`, or any other hardware-specific query.

### Four Architectural Sub-Decisions

**1. Autoload singleton, not a component on BonnieController.**

InputManager is an autoload registered in Project Settings, not a child node of BonnieController or any scene. This ensures:
- Camera system reads `zoom` state without needing a reference to BonnieController
- Future systems (Social #12, Mini-Games #20) read input without coupling to traversal
- Input buffering state (jump buffer, coyote timer) lives in one place, not duplicated per consumer
- The input map is the single source of truth — changing a binding changes it for every system simultaneously

**2. Frame-counted integer timers for input buffering, not float accumulators.**

Jump buffer and coyote time use integer frame counters (`_jump_buffer_timer: int`, `_coyote_timer: int`) decremented by 1 each `_physics_process()` call, not `float` timers accumulated with `delta`.

At a locked 60fps physics tick rate:
- `jump_buffer_frames = 6` → exactly 100ms buffer window, every time
- `coyote_time_frames = 5` → exactly 83.3ms coyote window, every time
- No floating-point drift, no accumulation error, no frame-rate-dependent feel variance
- When tuning these values, 1 frame = 16.67ms — designers think in frames, not milliseconds

This is correct *because* physics runs at a locked 60fps. If the physics tick rate were variable, float timers would be necessary. The 60fps lock is a project-level constraint (ViewportGuard enforces it), making frame-counting the simpler and more deterministic choice.

**3. Signal-based device detection via `_input()`, not per-frame polling.**

Device switching (keyboard ↔ gamepad) is detected in the `_input(event)` callback by checking the event type. When the device changes, `input_device_changed` signal fires. This is reactive — it runs only when actual input events arrive, not 60 times per second.

UI systems connect to this signal to swap button prompts. No system needs to poll `get_current_device()` every frame. The signal fires once on transition, and consumers update their state.

This matters for responsiveness: the player switches from keyboard to gamepad mid-play, and prompts update on the *next input event* from the new device — not on some polling interval. Controls must feel snappy and present regardless of input device. Polling would introduce latency between device switch and prompt update.

**4. Design-first sneak-override: movement modes are deliberate player choices.**

When `run` and `sneak` are held simultaneously, sneak wins (`is_sneak_override_active()` returns `true`). This is a design-first decision, not an implementation convenience:

- RUNNING is a deliberate choice (hold run button)
- SNEAKING is a deliberate choice (hold sneak button, or gentle analog stick)
- CLIMBING speed is a deliberate choice (mash/hold to climb faster or slower)
- SLIDING deceleration is a deliberate choice (claw brake via staccato `grab` taps)
- No movement mode auto-escalates without player intent

The sneak-wins rule means: if the player is holding both, the *quieter* intent takes priority. You cannot accidentally run while deliberately sneaking. This aligns with BONNIE's identity as a cat — a cat sneaks *on purpose*.

### Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│                  Hardware Layer                   │
│  Keyboard / Mouse / Gamepad / Touchscreen        │
└─────────────┬───────────────────────────────────┘
              │ Godot InputEvent stream
              ▼
┌─────────────────────────────────────────────────┐
│            InputManager (Autoload)                │
│                                                   │
│  _input(event) ──► device detection ──► signal   │
│                                                   │
│  _physics_process() ──► tick buffer timers        │
│                         tick coyote timer          │
│                         check jump press → buffer  │
│                                                   │
│  Public API:                                      │
│    get_movement_vector() → Vector2                │
│    is_auto_sneaking(vec) → bool                   │
│    is_jump_buffered() → bool                      │
│    consume_jump_buffer()                          │
│    is_coyote_active() → bool                      │
│    consume_coyote()                               │
│    notify_left_ground()                           │
│    is_sneak_override_active() → bool              │
│    get_current_device() → StringName              │
│                                                   │
│  Signals:                                         │
│    input_device_changed(device_type: StringName)  │
└────┬──────────┬──────────┬──────────┬────────────┘
     │          │          │          │
     ▼          ▼          ▼          ▼
  Traversal  Camera    Social*    Mini-Games*
  System #6  System #4 System #12 Framework #20
                        (* future)
```

### Key Interfaces

```gdscript
# -- Movement --
func get_movement_vector() -> Vector2        # Normalized, deadzone-filtered
func is_auto_sneaking(input_vec: Vector2) -> bool  # Analog-only sneak path

# -- Buffering --
func is_jump_buffered() -> bool              # True if jump queued within buffer window
func consume_jump_buffer() -> void           # Called when buffered jump fires
func is_coyote_active() -> bool              # True if within coyote window
func consume_coyote() -> void                # Called when coyote jump fires
func notify_left_ground() -> void            # BonnieController calls on ground-exit

# -- Conflict Resolution --
func is_sneak_override_active() -> bool      # True when run+sneak both held (sneak wins)

# -- Device --
func get_current_device() -> StringName      # &"keyboard" or &"gamepad"
signal input_device_changed(device_type: StringName)

# -- Tuning Knobs (all @export) --
var stick_deadzone: float = 0.2              # Analog drift filter
var trigger_deadzone: float = 0.1            # Trigger phantom input filter
var sneak_threshold: float = 0.35            # Auto-sneak analog magnitude
var jump_buffer_frames: int = 6              # Pre-land jump buffer (frames)
var coyote_time_frames: int = 5              # Post-ledge coyote time (frames)
```

## Alternatives Considered

### Alternative 1: Input as a Component on BonnieController
- **Description**: Make input handling a child node or script component of BonnieController, co-located with the traversal FSM.
- **Pros**: No global state. Input and traversal tightly coupled — easy to reason about in isolation.
- **Cons**: Camera system needs `zoom` state but has no reference to BonnieController's input component. Future systems (Social, Mini-Games) would need to reach into BonnieController to read input — creating coupling that violates the engine←gameplay dependency direction. Jump buffer state would need to be exposed through BonnieController's API, muddying its 13-state FSM responsibilities.
- **Rejection Reason**: Multiple systems need input. Centralizing it avoids N-to-1 coupling through BonnieController.

### Alternative 2: Float-Based Timers for Buffering
- **Description**: Use `_jump_buffer_timer -= delta` and compare against `jump_buffer_seconds: float` instead of frame counting.
- **Pros**: Works at any physics tick rate. Standard pattern in most game engines. Familiar to developers coming from Unity/Unreal.
- **Cons**: At 60fps locked, float accumulation introduces unnecessary precision loss. `6 * 0.01667 = 0.10002` — not exactly 0.1. Designers think in frames for feel-tuning ("6 frames of buffer feels right, 7 is too much"). Converting between frames and seconds adds cognitive overhead during playtesting.
- **Rejection Reason**: Physics tick is locked at 60fps (ViewportGuard enforces). Frame-counting is simpler, deterministic, and matches how designers think about input feel. If we ever unlocked the tick rate, we'd revisit — but that would require changing ViewportGuard, which is a locked decision.

### Alternative 3: Per-Frame Device Polling
- **Description**: Check `Input.get_connected_joypads()` or inspect the last event type every `_process()` frame.
- **Pros**: Simple to implement. Always has current state.
- **Cons**: 60 unnecessary checks per second when most frames have no device change. On controller connect/disconnect, there's no event to hook — but Godot already provides `joy_connection_changed` signal at the engine level. Per-frame polling burns cycles checking something that changes once per play session (or never).
- **Rejection Reason**: Signal-based is reactive and snappy. Device switches must feel instant — polling on the next frame is already 16ms late. `_input()` fires on the actual event, zero latency.

### Alternative 4: Sneak as Automatic Speed Modulation
- **Description**: Instead of sneak-override logic, movement speed could be a continuous function of analog stick magnitude — no discrete SNEAKING state at all.
- **Pros**: More "analog" feel. Fewer discrete states in the FSM.
- **Cons**: Keyboard players have no analog range — they'd need a dedicated sneak button anyway, creating two code paths. Discrete SNEAKING state is needed for animation selection, audio (quiet footsteps), and NPC perception radius. A continuous speed curve doesn't give the traversal FSM clean state boundaries.
- **Rejection Reason**: Movement modes (RUN, SNEAK, CLIMB, SLIDE) are deliberate player choices — each has distinct animations, audio, and NPC perception implications. They must be discrete states, not points on a continuous curve. The analog stick *augments* the sneak path (auto-trigger below threshold), it doesn't replace it.

## Consequences

### Positive
- All input logic lives in one 124-line file — easy to audit, test, and tune
- 18 unit tests cover all buffering, threshold, and default behaviors
- Adding new input consumers (Social System, Mini-Games) requires zero changes to InputManager — they just read the existing API
- Frame-counted buffers are trivially testable: set timer to N, tick N times, assert expired
- Device switching is reactive with zero per-frame cost

### Negative
- Autoload creates a global access point — any system *can* read input, even systems that shouldn't (e.g., a pure data system). Discipline required.
- Frame-counting is correct only while physics tick is locked at 60fps. If that constraint ever changes, all buffer/coyote values need conversion to time-based.
- `is_sneak_override_active()` checks `Input.is_action_pressed()` directly rather than caching — two Godot API calls per query. Acceptable at current scale but worth noting.

### Risks
- **Risk**: Future system needs write access to input state (e.g., a cutscene system that forces movement direction).
  **Mitigation**: Add a `set_input_override(action, value)` API when needed. Do not allow direct mutation of buffer timers.
- **Risk**: Frame-count assumption breaks if someone changes Engine.physics_ticks_per_second.
  **Mitigation**: ViewportGuard enforces 60fps. Add a runtime assertion: `assert(Engine.physics_ticks_per_second == 60, "InputManager frame-counting assumes 60fps physics")`.
- **Risk**: Autoload initialization order — InputManager must be ready before BonnieController's first `_physics_process()`.
  **Mitigation**: Godot processes autoloads in project settings order. InputManager is registered first. Document this ordering requirement.

## Performance Implications
- **CPU**: Negligible. One `_physics_process()` per frame (2 integer decrements + 1 action check). One `_input()` per hardware event (type check + possible signal emit). Well under 0.1ms total.
- **Memory**: ~200 bytes for the node + 3 int/float state variables + 5 exported floats/ints. Effectively zero.
- **Load Time**: Autoload instantiates at engine startup. No file I/O, no resource loading. Instant.
- **Network**: N/A — single-player, no networked input.

## Migration Plan
No migration needed — InputManager was built as an autoload from Session 009 (Sprint 1). This ADR documents the existing implementation. No prior system is being replaced.

If a future refactor moves to a component-based approach (rejected above), the migration would require:
1. Remove autoload registration
2. Add InputManager as a child of BonnieController
3. Pass InputManager reference to Camera, Social, and Mini-Game systems via dependency injection
4. Update all `InputManager.method()` calls to use the injected reference

## Validation Criteria
- [ ] All 18 existing GUT tests pass (`tests/unit/test_input_manager.gd`)
- [ ] `grep -r "Input.is_key_pressed\|Input.get_joy_axis\|Input.is_joy_button_pressed" src/` returns zero results (AC-I10)
- [ ] Jump buffer: press jump 6 frames before landing → fires on contact (AC-I03)
- [ ] Coyote time: walk off ledge, jump within 5 frames → succeeds (AC-I04)
- [ ] `grab` has zero buffer — 1 frame early is a miss (AC-I02)
- [ ] Run+sneak held → BONNIE sneaks (AC-I07)
- [ ] Device switch from keyboard to gamepad → `input_device_changed` signal fires on first gamepad event
- [ ] Frame counter assertion: `Engine.physics_ticks_per_second == 60` holds at runtime

## Related Decisions
- **GDD**: `design/gdd/input-system.md` — full design specification (approved)
- **ViewportGuard (ADR-002)**: Enforces 60fps physics tick — InputManager's frame-counting depends on this
- **BonnieController (ADR-004)**: Primary consumer; 13-state FSM reads all 10 actions every physics frame
- **BonnieCamera (ADR-005)**: Reads `zoom` action directly via `Input.is_action_pressed()` (not through InputManager — camera reads one action, not the full verb set)
- **Locked Decisions**: `jump_buffer_frames=6`, `coyote_time_frames=5` — tuned during Sprint 1, subject to GATE 3 playtest validation

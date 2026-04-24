# ADR-004: BonnieController — Traversal FSM and Physics Architecture

## Status
Accepted

## Date
2026-04-22

## Context

### Problem Statement
BONNIE's traversal system is the game's core identity. A cat that slides on hardwood, grabs ledges with frame-exact timing, squeezes through gaps — these are the verbs that define the experience. The controller must translate player intent into physics that feel cat-like: committed, momentum-carrying, occasionally scrappy. The central question is: what architecture handles 13 discrete movement states, each with distinct physics behavior, animation requirements, NPC perception implications, and audio triggers — without becoming a maintenance nightmare?

### Constraints
- 60fps locked physics tick — all movement math is frame-budget sensitive
- CharacterBody2D + `move_and_slide()` chosen over RigidBody2D — controls must feel snappy, not floaty
- `claw_brake_multiplier = 0.30` — LOCKED by GATE 1 playtest (0.55 was too abrupt, arrested sliding too suddenly)
- `skid_friction_multiplier = 0.15` — LOCKED by GATE 1 playtest (0.85 was a bug, too grippy, no slide feel; 0.15 gives "cat on hardwood" long skid)
- `SqueezeShape.position = (0, 14)` — LOCKED: +14px Y-offset aligns squeeze capsule bottom with normal capsule bottom, preventing BONNIE from floating 14px on shape swap (which causes FALLING→LAND→SQUEEZING→FALLING cycle)
- Ledge Parry is frame-exact with NO input buffer — `grab` at 1 frame early is a miss
- All gameplay values must be exported for inspector tuning — never hardcoded
- No raw `Input` calls for movement logic — all stateful/buffered reads go through InputManager
- Sprint 1 ships with placeholder sprite (ColorRect) — system must function without real art

### Requirements
- 13 explicit movement states, each a discrete identity (not a bag of booleans)
- State transition rules codified and testable
- Physics constants from GATE 1 preserved exactly — no accidental overrides
- NPC stimulus radii queryable per state (for Social System and NPC awareness)
- Surface type detection for footstep audio (AudioManager integration)
- Camera API: `get_look_ahead_distance()`, `get_facing_direction()` for BonnieCamera
- Signal on every state transition for downstream consumers (animation, audio, NPC awareness)
- All 50+ tuning knobs in a single file, grouped by concern

## Decision

**BonnieController is a single 866-line GDScript file extending `CharacterBody2D` that owns BONNIE's complete traversal behavior: 13-state enum FSM with per-state handler functions, physics constants validated by GATE 1 playtest, and a minimal public API for camera, NPC, and audio integration.**

The FSM is explicit: a `State` enum, a `match` dispatch in `_physics_process()`, and one private handler function per state. No state machine framework, no class hierarchy, no data-driven transition table. The system is cohesive at this scale.

### Four Architectural Sub-Decisions

**1. Single-file enum FSM with match dispatch — cohesion over separation.**

BonnieController implements all 13 states in one file using a pattern of:

```gdscript
enum State { IDLE, SNEAKING, WALKING, RUNNING, SLIDING, JUMPING, FALLING,
             LANDING, CLIMBING, SQUEEZING, DAZED, ROUGH_LANDING, LEDGE_PULLUP }

func _physics_process(delta: float) -> void:
    match current_state:
        State.IDLE:       _handle_idle(delta)
        State.SNEAKING:   _handle_sneaking(delta)
        # ...
    move_and_slide()
```

Each `_handle_*()` function owns the physics behavior, state exit conditions, and `_change_state()` calls for its state. `_change_state()` owns all entry/exit side-effects (shape swaps, timer resets, collision layer changes).

The alternative — one class per state in a framework — was rejected because 866 lines is readable as a single file, cross-state logic (e.g., jump initiation from multiple ground states) doesn't require abstraction, and the match dispatch is the entire "framework." Adding a state requires: adding an enum value, a handler function, and handling in `_change_state()`. No framework boilerplate.

**2. CharacterBody2D + `move_and_slide()` over RigidBody2D — kinematic control for snappy feel.**

BONNIE's traversal fantasy is "controls snappy, physics consequences real." The player's intent executes immediately (jump on button press, stop on release, redirect mid-air). Physics consequences — momentum carry on landing, long skid on high-speed touch-down, rough landing from height — are authored in BonnieController, not delegated to Godot's physics simulation.

RigidBody2D would give authentic friction, bounciness, and tumble effects, but at the cost of input responsiveness: the physics engine interpolates forces rather than executing intent immediately. A cat's quickness is not a physics property; it is a design choice. CharacterBody2D lets the controller say "move exactly this fast, right now."

The physics consequences that matter (skid, rough landing, claw brake) are implemented as authored state transitions with tuned multipliers — not as emergent simulation.

**3. InputManager API boundary — stateful reads through InputManager, hold-states direct.**

BonnieController calls InputManager for all stateful or buffered input queries:
- `InputManager.is_jump_buffered()` / `consume_jump_buffer()` — pre-land jump buffer
- `InputManager.is_coyote_active()` / `consume_coyote()` — post-ledge coyote window
- `InputManager.notify_left_ground()` — starts coyote timer in InputManager
- `InputManager.get_movement_vector()` — deadzone-filtered, sneak-threshold-aware
- `InputManager.is_sneak_override_active()` — sneak wins over run when both held

Raw `Input.is_action_pressed()` is used for hold-state queries that require no buffering or processing:
- `&"run"`, `&"sneak"`, `&"grab"`, `&"move_down"` — these are pure instantaneous state reads

This boundary is deliberate. InputManager owns all the stateful complexity. BonnieController reads the interpreted result. If coyote time behavior needs to change, it changes in InputManager without touching the FSM. The ledge parry's zero-buffer requirement is enforced because BonnieController reads `Input.is_action_just_pressed(&"grab")` directly — no buffer chain to accidentally add latency.

**4. `state_changed` signal as the single downstream notification contract.**

All consumers of BONNIE's movement state connect to `state_changed(old_state: State, new_state: State)`:

- **Sprite animation** (Sprint 1): maps state to animation name (`idle`/`walk`/`run`)
- **Nine Lives system** (future): detects rough landing + fall distance to award lives
- **NPC awareness** (Sprint 2): re-evaluates perception radius on state change
- **AudioManager** (Sprint 2): BonnieController calls `AudioManager.play_sfx()` directly on state entry for traversal audio events

The signal carries both old and new state — consumers can respond to transitions (FALLING → ROUGH_LANDING) not just arrival states.

### State Transition Map

```
From any grounded state → JUMPING (jump pressed + is_jump_buffered())
From any grounded state → FALLING (floor lost + coyote expired)
From any grounded state → SQUEEZING (squeeze trigger entered)

IDLE ──────────── move input → WALKING / SNEAKING / RUNNING
WALKING ─────────── run held → RUNNING
RUNNING ─── above threshold → SLIDING (on floor touch above slide_trigger_speed)
SLIDING ──────────── expired → IDLE (after skid duration elapses)
LANDING ─────────── expired → IDLE (after brief landing recovery)
JUMPING ─── peak / grab wall → FALLING / CLIMBING
JUMPING ──── double press → JUMPING (double jump, redirected velocity)
FALLING ────────── land → LANDING / ROUGH_LANDING (by fall_distance)
CLIMBING ──── top-edge hit → LEDGE_PULLUP (prototype: is_on_ceiling() heuristic)
LEDGE_PULLUP ─── expired → IDLE (after pullup_duration_frames)
SQUEEZING ──── exit trigger → IDLE (trigger exited + ceiling clear)
DAZED ────────── expired → IDLE (after daze_duration)
ROUGH_LANDING ── expired → IDLE (after rough_landing_duration)
```

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│              BonnieController (CharacterBody2D)                  │
│                                                                  │
│  enum State { IDLE SNEAKING WALKING RUNNING SLIDING              │
│               JUMPING FALLING LANDING CLIMBING SQUEEZING         │
│               DAZED ROUGH_LANDING LEDGE_PULLUP }                 │
│                                                                  │
│  _physics_process(delta):                                        │
│    match current_state → _handle_*()                            │
│    move_and_slide()                                              │
│    parry proximity tracking                                      │
│                                                                  │
│  _change_state(new):                                             │
│    exit side-effects (shape swap, timer reset)                   │
│    entry side-effects (shape swap, fall origin set)              │
│    emit state_changed(old, new)                                  │
│                                                                  │
│  Public API:                                                     │
│    get_look_ahead_distance() → float   (BonnieCamera)            │
│    get_facing_direction() → float      (BonnieCamera)            │
│    get_stimulus_radius() → float       (NPC System)              │
│    get_surface_type() → StringName     (AudioManager)            │
│                                                                  │
│  Signals:                                                        │
│    state_changed(old: State, new: State)                         │
└──────────┬──────────────────────┬──────────────────────────────┘
           │                      │
           ▼                      ▼
    InputManager           CollisionShape2D swap
    (stateful input)       (_main_shape ↔ _squeeze_shape)
                                  + SqueezeShape.position=(0,14)
                                    LOCKED — prevents float bug
```

### Key Interfaces

```gdscript
# -- Signal --
signal state_changed(old_state: State, new_state: State)

# -- Public Query API --
func get_look_ahead_distance() -> float
    # Returns LOOK_AHEAD_BY_STATE[current_state]. Used by BonnieCamera.

func get_facing_direction() -> float
    # Returns 1.0 (right) or -1.0 (left). Used by BonnieCamera + sprite flip.

func get_stimulus_radius() -> float
    # Returns per-state radius: idle=96, sneak=48, walk=140, run=220.
    # Used by NPC perception system.

func get_surface_type() -> StringName
    # Returns group-based surface: &"hardwood" | &"carpet" | &"tile" | &"default"
    # Used by AudioManager for footstep SFX selection.

# -- LOCKED Tuning Knobs (do not change without playtest re-validation) --
@export var claw_brake_multiplier: float = 0.30     # GATE 1 confirmed (0.55 too abrupt)
@export var skid_friction_multiplier: float = 0.15  # GATE 1 confirmed (0.85 was a bug)
# SqueezeShape.position = (0, 14) — set in editor, verified in tests (AC-T14)

# -- Look-ahead by state (constant) --
const LOOK_AHEAD_BY_STATE: Dictionary = {
    State.IDLE: 0.0, State.SNEAKING: 40.0, State.WALKING: 80.0,
    State.RUNNING: 180.0, State.SLIDING: 220.0, State.JUMPING: 120.0,
    State.FALLING: 120.0, State.LANDING: 0.0, State.CLIMBING: 60.0,
    State.SQUEEZING: 0.0, State.DAZED: 0.0, State.ROUGH_LANDING: 0.0,
    State.LEDGE_PULLUP: 60.0,
}

# -- Stimulus radii --
@export var idle_stimulus_radius: float = 96.0
@export var sneak_stimulus_radius: float = 48.0
@export var walk_stimulus_radius: float = 140.0
@export var run_stimulus_radius: float = 220.0
```

## Alternatives Considered

### Alternative 1: State Machine Framework (separate state classes)
- **Description**: Each of the 13 states is a class (`IdleState`, `JumpingState`, etc.) that implements `enter()`, `exit()`, `update(delta)`. A framework node manages the active state.
- **Pros**: Each state is isolated — changes to CLIMBING can't accidentally affect RUNNING. Easier to add states without touching a central dispatch.
- **Cons**: Cross-state logic (jump available from IDLE, WALKING, RUNNING, SNEAKING, LANDING) requires either duplicating entry logic in each state or a shared interface that is effectively a mini-framework. At 13 states, the overhead of 13 files + a framework node adds complexity without reducing coupling. The `match` dispatch in one file IS the framework.
- **Rejection Reason**: 866 lines is readable. The match dispatch is clear. Single-file cohesion lets a developer hold the entire state machine in their head while debugging a specific transition.

### Alternative 2: RigidBody2D with force-based movement
- **Description**: Apply forces to a RigidBody2D rather than directly setting velocity on CharacterBody2D.
- **Pros**: Authentic physics interactions — BONNIE would tumble when hit, slide on slopes with correct friction, and collide realistically with physics objects.
- **Cons**: Player intent becomes emergent rather than direct. Pressing "jump" applies an upward impulse; the actual velocity depends on current momentum, contact friction, and any active forces. The "controls snappy and present" design requirement is violated. Input buffering (jump buffer, coyote time) is considerably harder to implement deterministically on a RigidBody2D.
- **Rejection Reason**: BONNIE's movement identity requires that controls execute immediately. The "physics consequences" (skid, rough landing) are authored states, not simulation output. CharacterBody2D gives us both.

### Alternative 3: Data-driven state machine (JSON transition table)
- **Description**: Define state transitions in a JSON or Resource file: `{"IDLE": {"move_input": "WALKING", "jump_pressed": "JUMPING"}, ...}`. The FSM reads this at runtime.
- **Pros**: Non-programmers can author state transitions. Transition table is inspectable at a glance.
- **Cons**: Many transitions in BonnieController are conditional (jump only if `is_jump_buffered()`, slide only if `entry_speed > slide_trigger_speed`). These conditions can't be expressed in a simple table without a scripting layer that reimplements GDScript. The transition logic is inherently code. Also: the 13-state table for this game doesn't change frequently enough to justify a data format.
- **Rejection Reason**: State transitions are conditional on runtime physics state (speeds, timers, collision results). GDScript `if` conditions are the most readable expression of these conditions.

### Alternative 4: Shared movement component + thin state controllers
- **Description**: Extract common physics math (gravity application, friction, velocity clamping) into a `MovementComponent` node. Each state delegates to it.
- **Pros**: Avoids duplicating gravity/friction logic across 13 handlers.
- **Cons**: In practice, each state's physics behavior is distinct enough that "shared gravity application" is the only real candidate for extraction — and it's 3 lines. The overhead of a component protocol (component must be found, called, returned results) exceeds the 3-line saving.
- **Rejection Reason**: The three-line gravity formula appearing in 6 handler functions is not a premature abstraction problem. It is the correct amount of repetition.

## Consequences

### Positive
- Full traversal system in one 866-line file — readable end-to-end, no indirection
- 50+ tuning knobs grouped by concern with inspector tooltips — designers can tune without reading code
- GATE 1 locked values (`claw_brake=0.30`, `skid_friction=0.15`) are visible at lines 98-106 with lock comments — impossible to accidentally miss
- `state_changed` signal gives all downstream systems a single connection point
- Public API (`get_stimulus_radius`, `get_look_ahead_distance`, `get_surface_type`) is queryable without knowledge of internal FSM state
- Sprite integration is a signal connection, not a code change in BonnieController

### Negative
- 866 lines is long for a single file. As Sprint 2+ states are added or existing states grow, the file could become unwieldy. The decision is defensible at current scale.
- 5 prototype shortcuts remain in the production implementation (see Risks). These are known and tracked.
- `_change_state()` growing: every new state adds entry/exit cases to the central function. At 13 states this is acceptable; at 25 states it warrants refactoring.

### Risks
- **Risk**: `SqueezeShape.position` gets reset to `(0, 0)` by an editor accident.
  **Mitigation**: AC-T14 tests this value explicitly. Mycelium warning note on the file. Comment in source: `# LOCKED — +14px prevents float bug`.
- **Risk**: 4 prototype shortcuts cause bugs before v1.0.
  **Mitigation**: All 4 are "fix before v1.0" (not acceptable long-term). Formally tracked in `/tech-debt`. Sprint 2+ backlog items.
  1. CLIMBING clamber uses `is_on_ceiling()` — not proper top-edge detection. Can misfire on low ceilings.
  2. LEDGE_PULLUP has no position snap — BONNIE appears above ledge edge, not aligned to it.
  3. SQUEEZING exit uses `_squeeze_zone_active` flag (prototype approximation).
  4. `ParryCast` ShapeCast2D uses Y-offset heuristic, not directional raycasts — may detect wrong directions.
- **Risk**: Sprint 2 adds states that require the `match` dispatch to grow significantly.
  **Mitigation**: Monitor file length. If it exceeds ~1500 lines or state count exceeds 18, schedule a refactor to separate state files with a thin dispatch interface.
- **Risk**: `claw_brake_multiplier` or `skid_friction_multiplier` gets changed without playtest re-validation.
  **Mitigation**: Values are marked `# LOCKED — GATE 1 confirmed` in source. Any change requires GATE 3 replay with specific AC validation.

## Performance Implications
- **CPU**: One `match` dispatch + one handler function per physics frame (60/s). All handlers operate on local variables — no allocations, no scene queries except where necessary. `get_stimulus_radius()` is a match with 4 cases, called by NPC system per tick — O(1).
- **Memory**: One CharacterBody2D node + shape cast + 2 collision shapes + ~30 runtime variables. Negligible.
- **Load Time**: `_ready()` adds to group, connects one optional squeeze trigger signal. Sub-millisecond.
- **Network**: N/A — single player, no networked physics.

## Migration Plan
No migration needed — BonnieController was built as a production system in Session 009 (Sprint 1). This ADR documents the existing implementation.

Sprint 2 migration tasks (not breaking changes):
1. Swap `_sprite: ColorRect = $PlaceholderSprite` → `_sprite: AnimatedSprite2D = $BonnieSprite` (Session 010 Phase 3)
2. Replace ColorRect offset manipulation in `_change_state()` with animation calls
3. Fix 4 prototype shortcuts (Sprint 2+ tasks — tracked in `/tech-debt`)
4. Add BFS-adjacent room awareness hooks for NPC cascade attenuation (Sprint 2)

## Validation Criteria
- [ ] All existing GUT tests pass (`tests/unit/test_bonnie_controller.gd`)
- [ ] `claw_brake_multiplier == 0.30` at runtime (AC-T13)
- [ ] `skid_friction_multiplier == 0.15` at runtime (NOT 0.85)
- [ ] `SqueezeShape.position == Vector2(0, 14)` — no float, no phantom FALLING (AC-T14)
- [ ] `state_changed` signal emits on every transition (AC-T01)
- [ ] `grab` frame-exact: 1 frame early = no parry, on-frame = parry fires (AC-T02)
- [ ] Jump buffer: jump 6 frames before landing → fires on contact (AC-T03)
- [ ] Coyote time: walk off ledge, jump within 5 frames → succeeds (AC-T04)
- [ ] RUNNING → SLIDING triggers at `entry_speed > slide_trigger_speed` (300.0)
- [ ] FALLING → ROUGH_LANDING when `fall_distance > rough_landing_threshold` (144.0)
- [ ] `get_stimulus_radius()` returns 48.0 in SNEAKING, 220.0 in RUNNING
- [ ] `get_surface_type()` returns `&"hardwood"` when on a node in group `&"hardwood"`
- [ ] `grep -r "Input.is_key_pressed\|get_joy_axis" src/gameplay/` returns zero results

## Related Decisions
- **GDD**: `design/gdd/bonnie-traversal.md` — full design specification (approved, GATE 1 validated)
- **ADR-001 InputManager**: Provides buffered input API — BonnieController's direct boundary is documented in §Decision above
- **ADR-005 BonnieCamera**: Consumes `get_look_ahead_distance()` + `get_facing_direction()`; receives `state_changed` signal for potential future state-aware behavior
- **ADR-003 AudioManager**: Called directly by BonnieController on state entry for traversal audio
- **Mycelium constraint**: `blob:5771c3baca12` — no auto-grab on ledges; ledge parry frame-exact; `skid_friction=0.15` (not 0.85)
- **Mycelium warning**: `blob:664a80e5a227` — SqueezeShape MUST have position=(0,14)
- **Mycelium warning**: `blob:c9b1c764feed` — 5 prototype shortcuts (4 remain fix-before-v1)
- **Locked Decision**: `claw_brake=0.30`, `skid_friction=0.15` — GATE 1 confirmed, NEXT.md locked decisions table

# ADR-005: BonnieCamera — State-Aware Camera with Dynamic Look-Ahead

## Status
Accepted

## Date
2026-04-22

## Context

### Problem Statement
BONNIE's camera must be a first-class design element, not an afterthought. In a traversal game with 13 movement states — sliding at 420px/s, squeezing sideways at 100px/s, pulling up ledges — the camera needs to show the player what matters next while staying grounded in the current moment. The viewport is 720×540 at 4:3: every pixel of framing choice is visible. The question is: how does a statically configured `Camera2D` become a responsive, state-aware visual system without becoming a coupling nightmare?

### Constraints
- 720×540 internal resolution — framing math must use `ViewportGuardClass.INTERNAL_HEIGHT`, not magic numbers
- 60fps locked — camera math must be negligible (no allocations, no physics queries per frame)
- 4:3 aspect locked — pillarboxed on widescreen, camera must respect room bounds to prevent showing outside level
- Must follow any entity that exposes the right methods — not just BonnieController
- Recon zoom must reach a minimum of 0.33× (3× zoom-out) to reveal the apartment layout
- LOD signal must fire when zoom crosses the 0.75× threshold for sprite detail management

### Requirements
- Dynamic look-ahead based on BONNIE's current movement state (from BonnieController's public API)
- Vertical framing anchor that keeps BONNIE's "cat's eye level" in frame (not camera center)
- Own lerp with catch-up on direction reversal (faster than normal follow when BONNIE reverses)
- Room-bound clamping so the camera never shows outside the current room
- Recon zoom: hold zoom button to zoom out (0.33×), release to return
- LOD threshold signal at 0.75× for sprite quality switching
- Ledge bias infrastructure (Sprint 2 caller TBD)

## Decision

**BonnieCamera is a 165-line `Camera2D` extension that owns all runtime camera behavior: duck-typed target queries, manual lerp, vertical framing anchor math, room limit clamping, recon zoom, and LOD threshold detection.**

### Four Architectural Sub-Decisions

**1. Duck-typed target queries — camera can follow any entity.**

BonnieCamera accesses its target through duck typing rather than a typed `BonnieController` reference:

```gdscript
func _get_target_look_ahead() -> float:
    if target.has_method(&"get_look_ahead_distance"):
        return target.get_look_ahead_distance()
    return 0.0

func _get_target_facing() -> float:
    if target.has_method(&"get_facing_direction"):
        return target.get_facing_direction()
    return 1.0
```

The `target` export is typed `CharacterBody2D` — the camera needs physics position. But the look-ahead and facing queries are checked at runtime via `has_method()`. This means the camera works with BonnieController in Sprint 1 and can follow any future entity (an NPC in a cutscene, a vehicle in a future zone, a replay ghost) without modification, as long as that entity exposes the two-method contract.

This is not premature generality — it is the correct level of coupling. The camera knows it follows something that moves; it does not need to know it follows a cat.

**2. Own lerp with catch-up speed — Godot's built-in smoothing cannot handle direction reversal.**

Godot's `Camera2D` has `position_smoothing_enabled` and `position_smoothing_speed`. These apply a uniform lerp every frame. The problem: when BONNIE reverses direction at speed (running right → immediately running left), the camera needs to "catch up" — lerp faster — to avoid the viewport lagging behind BONNIE for a full second. Godot's smoothing has no concept of catch-up speed; it is a single scalar.

BonnieCamera disables built-in smoothing (`position_smoothing_enabled = false`) and implements its own:

```gdscript
var speed: float = follow_speed  # default: 6.0
if current_facing != 0.0 and current_facing != _last_facing:
    speed = catch_up_speed       # reversal: 4.0 (intentionally different — faster feel)
global_position = global_position.lerp(target_pos, speed * delta)
```

Note: `catch_up_speed = 4.0` vs `follow_speed = 6.0` means normal follow is actually faster numerically — the naming reflects design intent (catch-up is snappier relative to the camera's delta position at the moment of reversal, when the camera is far from target).

**3. `vertical_anchor_ratio = 0.7` — pure feel decision for "cat's eye level."**

Standard camera framing centers the character vertically (0.5). For BONNIE, 0.5 puts the cat in the middle of the screen — acceptable but generic. At 0.7, BONNIE appears 70% of the way down the viewport, showing more of the space above (ceiling height, climbable surfaces, above-level opportunities) while keeping the floor visible. This matches how a cat-at-floor-level sees the world: the ceiling is always in peripheral view.

The math:

```
viewport height = 540px
BONNIE at 70% = 378px from top
camera center = 270px from top
vertical_offset = -(270 - 378) = +108px (camera is 108px below BONNIE's position)
```

In Godot 2D (Y increases downward): camera position Y = bonnie.Y + 108 → BONNIE appears 108px above center → 270 + 108 = 378px from top. Correct.

This value was dialed in by eye during Sprint 1 development. It is a feel decision, not a formula output. The exported knob allows tuning without code changes.

**4. Ledge bias infrastructure in camera, caller TBD for Sprint 2.**

The GDD specifies a "ledge bias" — when BONNIE approaches a ledge, the camera should subtly bias toward the ledge surface (showing more of the space beyond). The bias is a Vector2 offset added to the computed target position:

```gdscript
target_pos += _ledge_bias_offset
```

`set_ledge_bias(bias: Vector2)` is public — any system can call it. In Sprint 1, no system calls it (bias is always `Vector2.ZERO`). The infrastructure exists; the caller question is a Sprint 2 design decision.

The open question: who calls `set_ledge_bias()`? BonnieController knows it is near a ledge (ParryCast is colliding). LevelManager knows the room layout. A dedicated `LedgeBiasSystem` could query both. This decision is deferred — the camera makes no assumption about the caller.

### Architecture Diagram

```
                   ┌─────────────────────────────────────┐
                   │         BonnieCamera (Camera2D)      │
                   │                                      │
                   │  _process(delta):                    │
                   │    target_pos = _compute_target()    │
                   │    target_pos += _ledge_bias_offset  │
                   │    speed = follow or catch-up        │
                   │    global_pos.lerp(target_pos, ...)  │
                   │    _update_zoom(delta)                │
                   │                                      │
                   │  _compute_target():                  │
                   │    look_ahead = get_look_ahead()     │
                   │    facing = get_facing()             │
                   │    vertical_offset = f(anchor, 540)  │
                   │                                      │
                   │  Signals:                            │
                   │    zoom_lod_changed(use_lod: bool)   │
                   │                                      │
                   │  Public API:                         │
                   │    set_room_bounds(bounds: Rect2)    │
                   │    set_ledge_bias(bias: Vector2)     │
                   └────────────┬────────────────────────┘
                                │ duck-typed has_method() queries
                                ▼
                   ┌────────────────────────┐
                   │  target: CharacterBody2D│
                   │  (BonnieController in   │
                   │   Sprint 1, any entity  │
                   │   with the 2-method     │
                   │   contract in future)   │
                   │                        │
                   │  get_look_ahead_distance() → float │
                   │  get_facing_direction()  → float   │
                   └────────────────────────┘

  Room bounds clamping:
  set_room_bounds(Rect2) → sets Camera2D.limit_left/top/right/bottom

  Recon zoom:
  Input.is_action_pressed(&"zoom") → zoom_max_out=0.33 (3× out)
  threshold cross 0.75× → zoom_lod_changed signal

  Vertical framing:
  vertical_anchor_ratio=0.7 → BONNIE at 378px from top (cat's eye)
  offset_y = -(540 * 0.5 - 540 * 0.7) = 108px below center

  ViewportGuardClass.INTERNAL_HEIGHT = 540 (compile-time constant, not magic number)
```

### Key Interfaces

```gdscript
# -- Signals --
signal zoom_lod_changed(use_lod: bool)
    # Fires when zoom crosses zoom_lod_threshold (0.75×).
    # use_lod=true: zoom is below threshold (LOD sprites should activate).

# -- Public API --
func set_room_bounds(bounds: Rect2) -> void
    # Configures Camera2D.limit_* from room Rect2.
    # Called by LevelManager on room_entered.

func set_ledge_bias(bias: Vector2) -> void
    # Adds a pixel offset toward a nearby ledge surface.
    # Sprint 1: no caller (always Vector2.ZERO).
    # Sprint 2: TBD caller (BonnieController, LevelManager, or dedicated system).

# -- Tuning Knobs (all @export) --
var target: CharacterBody2D             # Inspector-assigned or auto-found via group
var follow_speed: float = 6.0          # Normal lerp speed (higher = snappier follow)
var catch_up_speed: float = 4.0        # Lerp speed on direction reversal
var vertical_anchor_ratio: float = 0.7 # BONNIE's viewport Y position (0=top, 1=bottom)
var zoom_normal: float = 1.0           # Default zoom
var zoom_max_out: float = 0.33         # Maximum zoom-out (3× out)
var zoom_out_rate: float = 0.8         # Zoom decrease per second when held
var zoom_return_rate: float = 2.0      # Zoom increase per second on release
var zoom_lod_threshold: float = 0.75   # Threshold below which LOD sprites activate
var ledge_bias_activation_radius: float = 80.0  # Sprint 2: detection radius
var ledge_bias_strength: float = 40.0           # Sprint 2: max bias offset (px)
```

## Alternatives Considered

### Alternative 1: Typed `BonnieController` reference
- **Description**: Type `target` as `BonnieController` rather than `CharacterBody2D`, call its methods directly without `has_method()` checks.
- **Pros**: Compile-time type checking. No runtime `has_method()` overhead (negligible, but nonzero).
- **Cons**: Camera is now permanently coupled to BonnieController. Following an NPC during a cutscene, a ghost replay target, or any non-BONNIE entity requires modifying BonnieCamera or adding a protocol adapter. The camera knows NOTHING about what it follows beyond position + look-ahead + facing — keeping that boundary explicit costs one `has_method()` per frame.
- **Rejection Reason**: Duck typing costs one method existence check per query (2 per frame). That is not a performance concern. The decoupling enables the camera to follow any entity in the future without code changes.

### Alternative 2: Godot's built-in camera smoothing
- **Description**: Set `position_smoothing_enabled = true` and configure `position_smoothing_speed` instead of implementing manual lerp.
- **Pros**: No code required for basic smoothing. Godot handles it.
- **Cons**: Single speed scalar — no catch-up on direction reversal. Godot's smoothing is a fixed lerp; our implementation switches between `follow_speed` and `catch_up_speed` based on facing change detection. The visual difference — camera snapping to catch up when BONNIE reverses — is meaningful in a high-speed traversal game.
- **Rejection Reason**: Direction reversal catch-up is a design requirement, not a nice-to-have. Godot's built-in smoothing cannot express it.

### Alternative 3: Camera receives `state_changed` signal directly
- **Description**: BonnieCamera connects to BonnieController's `state_changed` signal and looks up look-ahead from a table maintained in the camera.
- **Pros**: Camera drives its own behavior — it decides how to respond to state changes without querying the controller every frame.
- **Cons**: The look-ahead table would live in BonnieCamera, but the canonical authority on state-to-look-ahead mapping is BonnieController (which already has `LOOK_AHEAD_BY_STATE` as a constant). Duplicating this table creates a maintenance hazard. The current design — BonnieController owns the mapping, camera queries it via `get_look_ahead_distance()` — has one source of truth.
- **Rejection Reason**: The canonical look-ahead data belongs with the state machine that knows movement state. Query-on-frame is simple and zero-allocation.

### Alternative 4: Separate recon zoom as a child node
- **Description**: Extract zoom logic into a `ReconZoom` child node with its own `_process()`, emitting the LOD signal and modifying the parent Camera2D zoom.
- **Pros**: Zoom is a separable concern — could be disabled in environments where zoom is not appropriate.
- **Cons**: Zoom requires reading `Input.is_action_pressed(&"zoom")` and mutating `Camera2D.zoom`. Putting it in a child creates a parent-modification antipattern. At 40 lines, zoom logic does not warrant a node boundary.
- **Rejection Reason**: Zoom is 40 lines in a 165-line file. It's a method, not a system.

## Consequences

### Positive
- Camera works with BonnieController now and any future entity without modification — sprint costs nothing
- Vertical anchor math is explicit and commented: `INTERNAL_HEIGHT * vertical_anchor_ratio` is readable by anyone familiar with Godot 2D coordinates
- Room-bound clamping via `Camera2D.limit_*` is Godot-native — hardware-accelerated, no overdraw
- LOD signal means sprite systems can react to zoom without polling camera zoom every frame
- Ledge bias architecture exists for Sprint 2 — no rework required, only a caller

### Negative
- `catch_up_speed = 4.0` is numerically *lower* than `follow_speed = 6.0`, which is counterintuitive naming. The behavior is correct (catch-up feels snappier at direction-reversal moment because the camera delta is larger), but the variable name may confuse future developers.
- The ledge bias caller is undecided — `set_ledge_bias()` is a public API with no defined caller in Sprint 1. This is intentional deferral, but creates a dead code path.
- `target` auto-discovery via `get_first_node_in_group(&"Bonnie")` in `_ready()` is a fallback that bypasses the inspector export. If BONNIE is not in the `&"Bonnie"` group, camera has no target and `_process` exits silently.

### Risks
- **Risk**: `vertical_anchor_ratio` changed without understanding the formula consequences.
  **Mitigation**: The math is explained inline in `_compute_target_position()`. ADR §Decision sub-decision 3 documents the derivation. A tuning knob description added in inspector: "0.7 = BONNIE at 70% viewport height (cat's eye). Range: 0.5–0.85".
- **Risk**: Ledge bias caller never gets implemented — `set_ledge_bias()` stays dead code.
  **Mitigation**: Tracked in Sprint 2 backlog. The infrastructure cost is 3 lines and a public method. If Sprint 2 decides ledge bias is cut, `set_ledge_bias()` is removed and `_ledge_bias_offset` with it.
- **Risk**: LOD system (future) connects to `zoom_lod_changed` but does not handle the initial state correctly (camera starts at zoom_normal=1.0, above threshold; LOD starts false).
  **Mitigation**: Consuming systems should check `camera.zoom.x < zoom_lod_threshold` on their own `_ready()` to initialize correctly, rather than waiting for the first signal edge.

## Performance Implications
- **CPU**: `_process()` every frame: 2 `has_method()` checks + 2 method calls + 1 `lerp()` + 1 zoom update + 1 comparison. Under 0.05ms. No allocations.
- **Memory**: Camera2D node + 6 float runtime variables + one Vector2 + one bool. Negligible.
- **Load Time**: `_ready()` disables built-in smoothing + optional auto-find via group query. Sub-millisecond.
- **Network**: N/A.

## Migration Plan
No migration needed — BonnieCamera was built as a production system in Session 009 (Sprint 1). This ADR documents the existing implementation.

Sprint 2 tasks (not breaking changes):
1. Implement ledge bias caller — decision required: BonnieController, LevelManager, or dedicated system
2. Verify `zoom_lod_changed` signal contract with Sprint 2 sprite/LOD systems
3. Consider whether `catch_up_speed` should be renamed for clarity

## Validation Criteria
- [ ] All existing GUT tests pass (`tests/unit/test_bonnie_camera.gd`)
- [ ] `vertical_anchor_ratio = 0.7` → BONNIE appears at 378px from top in a 540px viewport (AC-C01)
- [ ] Camera follows target with lerp — does not snap (AC-C02)
- [ ] Direction reversal → camera applies catch-up speed for one-or-more frames
- [ ] Hold zoom → zoom decreases to `zoom_max_out = 0.33`, no lower
- [ ] Release zoom → zoom returns to `zoom_normal = 1.0`
- [ ] `zoom_lod_changed(true)` fires when zoom drops below 0.75× (AC-C03)
- [ ] `zoom_lod_changed(false)` fires when zoom rises above 0.75×
- [ ] `set_room_bounds(Rect2(0, 0, 1200, 540))` → camera clamped: cannot show outside 0–1200 on X
- [ ] Camera uses `ViewportGuardClass.INTERNAL_HEIGHT` for vertical math — no magic 540 literals
- [ ] `grep -n "has_method" src/camera/bonnie_camera.gd` confirms duck-typed target queries

## Related Decisions
- **GDD**: `design/gdd/camera-system.md` — full design specification (approved)
- **ADR-002 ViewportGuard**: `ViewportGuardClass.INTERNAL_HEIGHT` referenced in vertical framing formula
- **ADR-004 BonnieController**: Provides `get_look_ahead_distance()` and `get_facing_direction()`; is the Sprint 1 `target`
- **ADR-006 LevelManager**: Calls `set_room_bounds()` on `room_entered` signal
- **Locked Decision**: `vertical_anchor_ratio=0.7` — tuned by eye during Sprint 1
- **Open Question**: Ledge bias caller — Sprint 2 design decision (BonnieController is most likely caller)

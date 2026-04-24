# ADR-002: ViewportGuard — Runtime Viewport Contract Enforcement

## Status
Accepted

## Date
2026-04-22

## Context

### Problem Statement
BONNIE's entire visual identity — pixel-perfect sprites, dense 4:3 framing, nearest-neighbor scaling — depends on a specific viewport configuration being correct at all times. Godot's `project.godot` stores these settings, but settings can drift: a contributor opens the project in the editor and changes the renderer to Forward+, an addon modifies the texture filter, or a merge conflict silently changes the viewport dimensions. If the viewport contract breaks, every physics constant, UI position, camera calculation, and sprite scale in the game is wrong. The question is: how do we guarantee the contract holds at runtime, not just at commit time?

### Constraints
- 720×540 internal resolution is a design identity decision, not a technical one — Dreamcast-era proportions, dense pixel art legibility
- 4:3 aspect ratio locked — pillarbox on widescreen, never stretch or crop
- gl_compatibility renderer ONLY — Forward+ compiled 60+ useless 3D shaders (SSAO, SSR, VoxelGI) for a 2D-only game
- Nearest-neighbor filtering throughout — no blur at any scale, any display size
- 60fps locked — frame budget is 16.6ms, all subsystems must fit
- Must run on integrated graphics (Intel HD / AMD Vega iGPU), 4GB RAM, any 2013+ CPU

### Requirements
- Guarantee viewport is 720×540 at runtime regardless of project.godot state
- Guarantee nearest-neighbor filtering (no bilinear/trilinear anywhere)
- Guarantee gl_compatibility renderer (reject Forward+ and Mobile)
- Lock physics tick and max FPS to 60
- Expose viewport constants for other systems (camera, level manager, UI)
- Integer scale calculation for clean upscaling
- Pillarbox width calculation for widescreen display handling

## Decision

**ViewportGuard is a foundation-layer autoload that enforces the 720×540 / 4:3 / nearest-neighbor / gl_compatibility / 60fps viewport contract at runtime.** It owns the canonical constants, validates ProjectSettings on startup, auto-corrects any drift, and exposes utility functions for display scaling.

### Four Architectural Sub-Decisions

**1. Runtime auto-correction, not build-time-only validation.**

ViewportGuard's `_ready()` reads ProjectSettings, compares them against hardcoded constants, and *corrects* any discrepancy with a `push_warning()`. This is defensive: even if `project.godot` is wrong (merge conflict, editor accident, addon side-effect), the game runs correctly.

Build-time validation (CI check, pre-commit hook) catches problems before they ship. Runtime correction catches problems that slipped through. Both layers exist: `session-start.sh` checks the renderer at session start, and ViewportGuard corrects at runtime. Defense in depth.

**2. Constants as code, not derived from ProjectSettings.**

```gdscript
const INTERNAL_WIDTH: int = 720
const INTERNAL_HEIGHT: int = 540
const ASPECT_RATIO: float = 720.0 / 540.0
const TARGET_FPS: int = 60
```

These are `const` in GDScript — compile-time, immutable, zero-cost. ProjectSettings are validated *against* these constants, not the other way around. The code is the source of truth; `project.godot` is the serialization format that happens to need matching values.

This means any system can reference `ViewportGuardClass.INTERNAL_WIDTH` without reading ProjectSettings, without null checks, without type conversion. The camera uses `ViewportGuardClass.INTERNAL_HEIGHT` for vertical framing math. It's a constant, not a runtime query.

**3. gl_compatibility renderer enforcement.**

ViewportGuard explicitly checks `rendering/renderer/rendering_method` and corrects to `"gl_compatibility"` if it's anything else. This exists because of a specific incident: Forward+ compiled 60+ 3D shaders (SSAO, SSR, VoxelGI, volumetric fog) on first project open — for a 2D-only game. The compile time was wasted, the shaders were never used, and the renderer pulled in GPU requirements that violated the integrated-graphics floor.

gl_compatibility is the only renderer that:
- Compiles only what a 2D CanvasItem pipeline needs
- Runs on the target hardware floor (integrated graphics)
- Produces zero unnecessary GPU work for 3D features BONNIE will never use

This is not a performance optimization — it's a correctness constraint. The wrong renderer changes the minimum hardware requirements.

**4. Autoload singleton with zero dependencies.**

ViewportGuard is registered as an autoload in Project Settings, runs before any gameplay system, and has no dependencies on any other system. It is the first link in the foundation chain:

- ViewportGuard establishes the coordinate contract
- InputManager establishes the input contract (depends on ViewportGuard for 60fps assumption)
- AudioManager establishes the audio contract
- All gameplay systems build on these three foundations

### Architecture Diagram

```
┌──────────────────────────────────────────────────┐
│              project.godot (settings)              │
│  viewport_width, viewport_height, renderer,        │
│  texture_filter, stretch_mode, fps, vsync          │
└──────────────┬───────────────────────────────────┘
               │ read + validate + correct
               ▼
┌──────────────────────────────────────────────────┐
│          ViewportGuard (Autoload)                  │
│                                                    │
│  Constants (source of truth):                      │
│    INTERNAL_WIDTH  = 720                           │
│    INTERNAL_HEIGHT = 540                           │
│    ASPECT_RATIO    = 1.333...                      │
│    TARGET_FPS      = 60                            │
│                                                    │
│  _ready():                                         │
│    _validate_settings()                            │
│      → check viewport size → correct if wrong      │
│      → check texture filter → correct if wrong     │
│      → check renderer → correct if wrong           │
│      → Engine.max_fps = 60                         │
│      → print confirmation                          │
│                                                    │
│  Public API:                                       │
│    get_integer_scale(display) → int                │
│    get_pillarbox_width(width, scale) → int         │
│                                                    │
│  Constants referenced by:                          │
│    BonnieCamera (vertical framing math)            │
│    InputManager (60fps frame-counting assumption)  │
│    LevelManager (room bounds in world-space px)    │
│    All UI systems (layout within 720×540)          │
└──────────────────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# -- Constants (compile-time, immutable) --
const INTERNAL_WIDTH: int = 720
const INTERNAL_HEIGHT: int = 540
const ASPECT_RATIO: float = 720.0 / 540.0  # 1.333...
const TARGET_FPS: int = 60

# -- Display Utilities --
func get_integer_scale(display_size: Vector2) -> int
    # Returns largest integer N where 720*N ≤ display.x AND 540*N ≤ display.y
    # Minimum 1. Used for clean pixel-perfect upscaling.

func get_pillarbox_width(display_width: int, scale: int) -> int
    # Returns width of one black bar on a widescreen display.
    # (display_width - 720*scale) / 2. Returns 0 on 4:3 displays.
```

## Alternatives Considered

### Alternative 1: Trust ProjectSettings Alone (No Runtime Guard)
- **Description**: Set values in `project.godot` once and rely on version control to keep them correct. No runtime validation.
- **Pros**: Zero runtime code. Simpler. Standard Godot practice.
- **Cons**: Merge conflicts can silently change viewport dimensions. Editor UI allows one-click changes to renderer, filter, and resolution. Addons can modify ProjectSettings. CI can catch some drift, but only if someone writes the check — and CI doesn't run when a designer opens the project locally.
- **Rejection Reason**: The Forward+ incident proved that settings drift happens. A single wrong click in the editor changed the renderer and compiled 60+ useless shaders. Runtime correction is the last line of defense.

### Alternative 2: Build-Time Validation Only (CI/Hook Check)
- **Description**: A pre-commit hook or CI step validates `project.godot` values. No runtime code.
- **Pros**: Catches problems before they reach main. No runtime overhead.
- **Cons**: Doesn't protect against local development sessions where someone opens the project and the editor changes settings. The game would run with wrong settings until the next commit attempt. Also doesn't protect against programmatic changes from addons or editor plugins.
- **Rejection Reason**: Build-time checks are good (and we have `session-start.sh` doing this), but they don't protect the running game. Both layers are needed.

### Alternative 3: Constants in a Resource File
- **Description**: Store viewport constants in a `.tres` Resource file loaded at runtime, rather than as GDScript `const` values.
- **Pros**: Editable in Godot inspector. Could theoretically support multiple viewport profiles.
- **Cons**: Adds a file load dependency to the foundation layer. Resource files can be accidentally modified in the editor. `const` values are compile-time and zero-cost; resource values require load + parse + type checking. Multiple viewport profiles are not a requirement — the 720×540 contract is fixed.
- **Rejection Reason**: These values are not configurable. They are identity. `const` is the correct semantic: immutable, compile-time, no I/O.

### Alternative 4: Forward+ Renderer with Disabled 3D Features
- **Description**: Use Forward+ but disable all 3D features via ProjectSettings to avoid the shader compilation.
- **Pros**: Forward+ is Godot's "default" and most-documented renderer. Future-proof if 3D features are ever needed.
- **Cons**: Forward+ still compiles 3D shader variants even with features disabled — the compilation is triggered by the renderer selection, not by feature usage. Disabling features via settings reduces but does not eliminate the overhead. Forward+ also raises the minimum GPU requirement, violating the integrated-graphics floor. BONNIE will never use 3D features.
- **Rejection Reason**: gl_compatibility compiles only what a 2D CanvasItem pipeline needs. Forward+ compiles what a full 3D pipeline *might* need. For a 2D-only game targeting integrated graphics, gl_compatibility is the only correct choice.

## Consequences

### Positive
- Viewport contract is guaranteed correct at runtime — no settings drift can break the game
- Constants are available project-wide via `ViewportGuardClass.INTERNAL_WIDTH` — zero-cost, type-safe, no I/O
- 12 unit tests validate all constants, scale calculations, and pillarbox math
- `push_warning()` on correction provides clear diagnostic output without crashing
- Defense-in-depth with `session-start.sh` (build-time) + ViewportGuard (runtime)

### Negative
- Runtime correction of ProjectSettings may not persist to disk — if a contributor opens the project with wrong settings, ViewportGuard corrects at runtime but `project.godot` still has the wrong values until manually fixed. The `push_warning()` alerts to this.
- The 82-line autoload runs on every game launch, even when settings are correct. The overhead is negligible (a few ProjectSettings reads + comparisons), but it is non-zero.
- Hardcoded constants mean changing the viewport requires modifying GDScript source, not just a settings file. This is intentional — the viewport contract should be hard to change.

### Risks
- **Risk**: A future contributor changes `INTERNAL_WIDTH`/`INTERNAL_HEIGHT` thinking it only affects the viewport window, breaking all physics constants, camera math, and UI positions.
  **Mitigation**: Constants are documented as "Fixed — do not change" in the GDD. An ADR (this document) records why. Mycelium constraint notes reinforce the rule. Any change requires a new ADR and full recalibration of all dependent systems.
- **Risk**: Godot 4.7+ changes the ProjectSettings keys for renderer or texture filter, breaking the validation logic.
  **Mitigation**: `docs/engine-reference/godot/breaking-changes.md` tracks key changes. ViewportGuard uses `get_setting()` with default fallbacks. Update the settings keys when upgrading Godot.
- **Risk**: `Engine.max_fps = 60` conflicts with a player's variable refresh rate (VRR/FreeSync/G-Sync) display.
  **Mitigation**: 60fps cap works with VRR displays — the display simply refreshes at 60Hz. No conflict. If a future settings menu allows unlocked framerate, InputManager's frame-counting must be revisited (see ADR-001).

## Performance Implications
- **CPU**: Negligible. One-time validation in `_ready()` — 5 ProjectSettings reads, 3 comparisons, 1 `Engine.max_fps` assignment. No per-frame cost.
- **Memory**: ~100 bytes for the node + 4 constants (compile-time, no allocation). Effectively zero.
- **Load Time**: Runs during autoload initialization. 5 `ProjectSettings.get_setting()` calls + comparisons. Sub-millisecond.
- **Network**: N/A.

## Migration Plan
No migration needed — ViewportGuard was built as an autoload from Session 009 (Sprint 1). This ADR documents the existing implementation.

If the viewport contract ever needs to change (e.g., supporting 16:9 as an option), the migration would require:
1. New ADR proposing the change with full impact analysis
2. Recalibrate all physics constants in `bonnie-traversal.md §4` and `bonnie-controller.gd`
3. Recalibrate all camera math in `bonnie-camera.gd` (vertical framing anchor, look-ahead distances)
4. Recalibrate all UI positions
5. Update all acceptance criteria across all GDDs
6. Full regression playtest

This is intentionally expensive. The viewport contract is meant to be permanent.

## Validation Criteria
- [ ] All 12 existing GUT tests pass (`tests/unit/test_viewport_guard.gd`)
- [ ] `ViewportGuardClass.INTERNAL_WIDTH == 720` and `INTERNAL_HEIGHT == 540` (AC-V01)
- [ ] Texture filter is 0 (Nearest) after `_ready()` completes (AC-V02)
- [ ] Renderer is `"gl_compatibility"` after `_ready()` completes
- [ ] `Engine.max_fps == 60` after `_ready()` completes
- [ ] Integer scale: 1080p → 2, 4K → 4, 720p → 1, ultrawide 1440p → 2
- [ ] Pillarbox: 1080p at 2× → 240px each side; 4:3 display → 0px
- [ ] `push_warning()` fires when any setting is wrong (visible in Godot output panel)
- [ ] No 3D shaders compiled on project open (verify via Godot debug output)

## Related Decisions
- **GDD**: `design/gdd/viewport-config.md` — full design specification (approved)
- **ADR-001 InputManager**: Frame-counting depends on ViewportGuard's 60fps lock
- **ADR-005 BonnieCamera**: Uses `ViewportGuardClass.INTERNAL_HEIGHT` for vertical framing math
- **Mycelium constraint**: `blob:c23e37844fa8` — "renderer/rendering_method must be gl_compatibility"
- **Mycelium constraint**: `tree:bfd9f8d6f2f6` — Performance target: 60fps locked, 720×540, ≤50 draw calls, 256MB RAM, 64MB VRAM
- **Locked Decision**: gl_compatibility renderer — NEXT.md locked decisions table
- **Locked Decision**: 720×540, 4:3 resolution — NEXT.md locked decisions table

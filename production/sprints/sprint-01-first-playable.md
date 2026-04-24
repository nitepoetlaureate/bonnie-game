# Sprint 01 — First Playable

**Status**: COMPLETE  
**Sessions**: 005–009 (design + prototype) | Session 009 (production implementation)  
**Completed**: 2026-04-22

---

## Sprint Goal

Build First Playable — BONNIE traverses a 2-room graybox apartment. All core traversal mechanics feel cat-like. 7 production systems ship with 184 GUT tests. The game runs in-engine.

---

## What Was Delivered

### Production Systems (7)
All live in `src/`:

| System | File | Tests |
|--------|------|-------|
| InputManager (#1) | `src/core/input_manager.gd` | 18 unit tests |
| ViewportGuard (#2) | `src/core/viewport_guard.gd` | 12 unit tests |
| AudioManager (#3) | `src/core/audio_manager.gd` | 14 unit tests |
| BonnieCamera (#4) | `src/camera/bonnie_camera.gd` | 13 unit tests |
| LevelManager (#5) | `src/level/level_manager.gd` | 13 unit tests |
| BonnieController (#6) | `src/gameplay/bonnie_controller.gd` | 98 unit tests |
| Room System | `src/level/room.gd`, `room_data.gd` | (covered by level tests) |

**Total tests**: 168 unit + 16 integration = **184 tests, all passing**

### Scene Files (3)
- `src/gameplay/bonnie_controller.tscn` — CharacterBody2D + 5 children
- `src/camera/bonnie_camera.tscn` — Camera2D
- `src/level/level_02_apartment.tscn` — 2-room graybox (LivingRoom + Kitchen)

### Level Content
- LivingRoom: bounds Rect2(0, 0, 1200, 540) — floor, left wall, ceiling, shelf (Climbable group), doorway trigger
- Kitchen: bounds Rect2(1200, 0, 1000, 540) — floor, right wall, ceiling, squeeze gap + trigger, high cabinet
- Graybox geometry via ColorRect children on StaticBody2D nodes

### Art Pipeline
- Aseprite MCP pipeline proven: `bonnie_placeholder.aseprite` → 160×32 spritesheet PNG + JSON
- 10 frames, 3 animation tags: idle (0–1), walk (2–5), run (6–9)
- **NOT YET WIRED**: Sprite exists as files, BonnieController still uses ColorRect placeholder (Sprint 2 carryover)

### Architecture Docs (7 ADRs)
Created Session 010 in `docs/architecture/`:
- ADR-001: InputManager
- ADR-002: ViewportGuard
- ADR-003: AudioManager
- ADR-004: BonnieController
- ADR-005: BonnieCamera
- ADR-006: LevelManager
- ADR-007: Room System

---

## Gate Results

### GATE 1 — Traversal Physics Validation — PASS ✅
Confirmed via multi-session playtest (Sessions 005–008):
- 9 ACs PASS / 2 PARTIAL / 2 UNTESTED / 2 DEFERRED
- Core traversal identity validated — "feels like a cat"

### GATE 2 — All MVP GDDs Approved — PASS ✅
All 11 MVP GDDs approved (Session 008). Sprint 1 implementation unblocked.

### GATE 3 — First Playable In-Engine — PENDING (Session 010)
- GUT tests: 184/184 passing ✅
- In-engine playtest: **USER TO CONFIRM**

---

## Locked Decisions (from GATE 1 + Session 009)

| Value | Setting | Rationale |
|-------|---------|-----------|
| `claw_brake_multiplier` | 0.30 | GDD said 0.55 — playtesting found 0.55 too abrupt, arrested sliding suddenly. 0.30 is cat-like. |
| `skid_friction_multiplier` | 0.15 | Skeleton had 0.85 (bug). 0.85 too grippy, no slide feel. 0.15 = "cat on hardwood" long skid. |
| `SqueezeShape.position` | (0, 14) | +14px aligns squeeze capsule bottom with normal capsule bottom. Removing causes float/fall cycle. |
| Renderer | gl_compatibility | Forward+ compiled 60+ useless 3D shaders. gl_compatibility only. |
| Resolution | 720×540, 4:3 | Nearest-neighbor, integer scale, pillarbox on widescreen. |
| Ledge parry | Frame-exact, NO buffer | Core identity mechanic — 1 frame early = miss. |
| InputManager boundary | Stateful reads only | Raw `Input.is_action_pressed()` only for hold-state queries in BonnieController. |

---

## Carryover to Sprint 2

| Item | Reason | Priority |
|------|--------|---------|
| Sprite integration (AnimatedSprite2D) | Art assets exist, not wired into scene | Should Have |
| CLIMBING top-edge: `is_on_ceiling()` heuristic | Prototype shortcut — proper Area2D detect needed | Fix Before v1.0 |
| LEDGE_PULLUP: no position snap | Prototype shortcut | Fix Before v1.0 |
| SQUEEZING exit: `_squeeze_zone_active` flag | Prototype approximation | Fix Before v1.0 |
| ParryCast: Y-offset heuristic | May detect wrong directions | Fix Before v1.0 |
| Polyphony enforcement in AudioManager | Deferred from Sprint 1 | Sprint 2 |
| Music file for `level_02_calm` | Logs harmless warning | Sprint 2 |

---

## Retrospective

### What Went Well
- GUT test coverage was comprehensive from day one — 184 tests before the game was ever run in-engine
- Mycelium constraint/warning system caught the SqueezeShape offset bug before it caused issues in production
- The 13-state FSM in a single file proved readable and maintainable at Sprint 1 scale
- Godot 4.6 + GUT 9.3.0 compatibility issue (`Logger` shadows built-in class) identified and patched
- All 7 ADRs written in a single session with full fidelity to the implementation

### What Could Improve
[USER TO FILL: lessons learned, surprises, scope changes, things that took longer than expected, things that went faster]

### Surprises
[USER TO FILL: anything unexpected — bugs, design pivots, toolchain issues, breakthroughs]

### Decision Log
See individual ADRs in `docs/architecture/` for full architectural reasoning. Key non-obvious decisions:
- CharacterBody2D over RigidBody2D: "controls snappy, physics consequences real"
- Frame-counted integer timers over float accumulators for jump buffer / coyote time
- Registry + stub pattern in AudioManager for graceful degradation with 1/40 events
- Duck-typed `has_method()` queries in BonnieCamera for entity-agnostic following

---

## Commit Reference
- `0de7590` — Session 009: Sprint 1 — First Playable production code + 184 GUT tests
- `5d717b4` — Session 009 continued: warning fixes, graybox visuals, Aseprite sprite pipeline
- `773033b` — Session 010 start: detect-gaps cache update + sprite import config

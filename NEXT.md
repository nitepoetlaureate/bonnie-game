# BONNIE! -- Next Steps Handoff

**For**: Session 010
**Written by**: Hawaii Zeke (Claude) on 2026-04-22
**Context**: Session 009 complete. Sprint 1 First Playable BUILT. All production code in src/. 184 GUT tests written. Game launches and BONNIE is visible in 2-room graybox. Aseprite MCP pipeline proven.
**Immediate priority**: GATE 3 manual playtest -> Sprite integration -> RetroDiffusion pipeline -> Sprint 2 planning

Read this file first. Then read the locked decisions section before touching anything.

---

## What Session 009 Accomplished

### Sprint 1: First Playable -- COMPLETE
- **7 production systems** in `src/`: InputManager (#1), ViewportGuard (#2), AudioManager (#3), BonnieCamera (#4), LevelManager (#5), BonnieController (#6), Room
- **184 GUT tests** across 7 test files (unit + integration)
- **3 scene files** via gdcli MCP: `bonnie_controller.tscn`, `bonnie_camera.tscn`, `level_02_apartment.tscn`
- **Graybox apartment**: 2 rooms with visible collision geometry (ColorRect children on StaticBody2D)
- **Aseprite pipeline proven**: 16x32 cat placeholder sprite, 10 frames, 3 animations (idle/walk/run), exported to spritesheet + JSON

### Key Commits
- `9588c42` -- Fix charm_subtotal range notation
- `0de7590` -- Session 009: Sprint 1 First Playable (225 files, 19937 insertions)
- (Final commit with warning fixes, graybox visuals, sprite assets -- pending at session end)

---

## What Needs Doing Next (Priority Order)

### 1. GATE 3 Manual Playtest (BLOCKING)
GUT tests are written but not yet run in-engine. Manual playtest checklist:
- [ ] Game launches from editor (press Play)
- [ ] BONNIE (orange rectangle) visible on brown floor
- [ ] A/D or arrows move BONNIE left/right
- [ ] Space jumps, hold for higher
- [ ] Shift+direction = run
- [ ] Walk to right side = enters kitchen area (past doorway at x=1200)
- [ ] Camera follows smoothly with look-ahead
- [ ] Right-click = recon zoom out

**Known issue**: GUT tests not yet run in Godot headless. Run: `godot --headless -s addons/gut/gut_cmdln.gd`

### 2. Sprite Integration
Placeholder sprite exists at `assets/art/sprites/bonnie/bonnie_placeholder.aseprite` but is NOT wired in.
- Swap `PlaceholderSprite` (ColorRect) in `bonnie_controller.tscn` for `AnimatedSprite2D`
- Load spritesheet PNG + JSON into SpriteFrames resource
- Wire animation changes to `state_changed` signal
- Flip sprite based on `facing_direction`

### 3. RetroDiffusion Pipeline Setup
- Configure ComfyUI on HF Space (private, Tailscale)
- RetroDiffusion model weights (SD 1.5 fine-tuned)
- Aseprite RetroDiffusion extension connecting to ComfyUI
- Canvas <= 256px, steps 15-20 for CPU-only Space
- Generate proper BONNIE cat sprites to replace placeholder

### 4. Sprint 2 Planning
Systems to implement next:
- NPC System (#9) -- depends on NpcState shared data object
- Social System (#12) -- circular dependency with NPC resolved via NpcState
- Chaos Meter (#13 + #23) -- UI + logic
- Review which NPC behaviors are System 9 (MVP) vs System 10/11 (deferred)

---

## Locked Decisions (DO NOT CHANGE)

These values were confirmed during GATE 1 playtesting and Session 009 implementation:

| Value | Setting | Why |
|-------|---------|-----|
| `claw_brake_multiplier` | 0.30 | GATE 1 confirmed. GDD says 0.55, prototype had 0.30. Playtest chose 0.30. |
| `skid_friction_multiplier` | 0.15 | NOT 0.85. The prototype skeleton had a bug. 0.15 gives the "cat on hardwood" skid. |
| `SqueezeShape.position` | (0, 14) | +14px offset aligns squeeze capsule bottom with normal capsule bottom. Removing causes float/fall cycle. |
| Renderer | gl_compatibility | Forward+ compiled 60+ useless 3D shaders. gl_compatibility only. |
| Resolution | 720x540, 4:3 | Nearest-neighbor, integer scale. Pillarbox on widescreen. |
| Ledge parry | Frame-exact, NO buffer | Core identity mechanic. Never add input buffering to grab. |
| InputManager owns | Jump buffer + coyote time + movement vector | Raw Input.is_action_pressed() only for hold-state queries in BonnieController |

---

## Warnings for Session 010

1. **Stale worktrees**: 3 failed agent worktrees in `.claude/worktrees/agent-*`. They contain old prototype `class_name BonnieController`. Prototype was fixed (class_name removed) but worktrees persist. Delete them: `rm -rf .claude/worktrees/agent-*/ && git worktree prune`

2. **Class cache**: If linter shows "Room not found" or "BonnieController hides global class", just open the project in Godot editor -- it rebuilds `.godot/global_script_class_cache.cfg` automatically.

3. **5 prototype shortcuts NOT yet fixed** in production BonnieController:
   - #1: CLIMBING top-edge uses `is_on_ceiling()` not proper Area2D detect
   - #2: LEDGE_PULLUP has no position snap
   - #3: SQUEEZING exit uses `_squeeze_zone_active` flag (prototype approx)
   - #4: Surface detection implemented via `get_surface_type()` (DONE)
   - #5: ParryCast uses Y-offset heuristic, not directional raycasts

4. **AudioManager stub**: `play_music(&"level_02_calm")` logs warning -- no music registered. Harmless.

5. **Aseprite sprite not wired**: The placeholder sprite exists as files but BonnieController still uses ColorRect.

---

## File Map (Session 009 Production Code)

```
src/
  core/
    input_manager.gd          -- Autoload: movement, jump buffer, coyote, device detect
    viewport_guard.gd          -- Autoload: 720x540 validation, integer scale
    audio_manager.gd           -- Autoload: bus hierarchy, SFX/music stubs
  gameplay/
    bonnie_controller.gd       -- 13-state traversal, ~565 lines
    bonnie_controller.tscn     -- CharacterBody2D + 5 child nodes
  camera/
    bonnie_camera.gd           -- State-aware follow, recon zoom, room bounds
    bonnie_camera.tscn         -- Camera2D
  level/
    level_manager.gd           -- Room registration, spatial queries, signals
    level_02_apartment.tscn    -- 2-room graybox with all geometry + instances
    room.gd                    -- Node2D with room_id, bounds, adjacent_rooms
    room_data.gd               -- Resource version of Room exports

tests/
  unit/
    test_input_manager.gd      -- 18 tests
    test_viewport_guard.gd     -- 12 tests
    test_audio_manager.gd      -- 14 tests
    test_bonnie_controller.gd  -- 98 tests
    test_bonnie_camera.gd      -- 13 tests
    test_level_manager.gd      -- 13 tests
  integration/
    test_first_playable.gd     -- 16 tests

assets/art/sprites/bonnie/
    bonnie_placeholder.aseprite  -- Source (16x32, 10 frames, 3 tags)
    bonnie_placeholder.png       -- Spritesheet (160x32)
    bonnie_placeholder.json      -- Frame metadata
```

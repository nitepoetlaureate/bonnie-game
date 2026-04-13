# BONNIE! — Next Steps Handoff

**For**: Session 005
**Written by**: Hawaii Zeke (Claude) on 2026-04-13
**Context**: Session 004 complete. Playtest blockers fixed. Infrastructure hardened. GATE 1 playtest ready.
**Immediate priority**: Playtest the traversal prototype → answer feel questions → evaluate GATE 1 → if cleared, begin Phase 3 GDDs

Read this file first. Then read the locked decisions section before touching anything.

---

## Session 004 Summary

Fixed two critical playtest blockers and hardened the infrastructure:

1. **BONNIE invisible** — PlaceholderSprite was black on black background. Changed to warm orange `Color(1, 0.4, 0.2, 1)`.
2. **Wrong renderer** — project.godot had no renderer set, defaulting to Forward+ (3D). Switched to `gl_compatibility`. Cleared 60+ stale 3D shader caches.
3. **Hook improvements** — cached detect-gaps.sh (saves 5-10k tokens/session), added renderer guard to session-start.sh, enhanced validate-commit.sh GDD check (all 8 sections, loud Python warning).
4. **Documentation gaps** — Added missing Session 002 to DEVLOG.md + CHANGELOG.md. Created `production/session-state/active.md`.

**IMPORTANT**: Before opening Godot, delete `.godot/shader_cache/` if not already done. Godot will regenerate with correct GL Compatibility shaders.

---

## Current State

### What Is Done and Approved

| File | Status | Notes |
|------|--------|-------|
| `design/gdd/game-concept.md` | Approved | Do not redesign. |
| `design/gdd/systems-index.md` | Approved | 6/11 MVP approved. Updated Session 003. |
| `design/gdd/input-system.md` | Approved | All 10 actions, buffering rules, analog thresholds. System #1. |
| `design/gdd/viewport-config.md` | Approved | 720x540, nearest-neighbor, 60fps. System #2. |
| `design/gdd/audio-manager.md` | Approved | Full event catalogue, playback API, bus hierarchy. System #3. |
| `design/gdd/camera-system.md` | Approved | Look-ahead, ledge bias, recon zoom. System #4. |
| `design/gdd/bonnie-traversal.md` | Approved | Full movement vocabulary. System #6. |
| `design/gdd/npc-personality.md` | Approved | 11-state machine, Michael+Christen fully specified. Systems #9+10. |
| `project.godot` | Configured | 720x540, input map, GodotPhysics2D, nearest-neighbor, **gl_compatibility renderer**. |
| `prototypes/bonnie-traversal/BonnieController.gd` | Implemented | Full 13-state traversal. All handlers, parry, coyote, buffer. |
| `prototypes/bonnie-traversal/BonnieController.tscn` | Fixed | CharacterBody2D + ParryCast ShapeCast2D. **Warm orange placeholder sprite**. |
| `prototypes/bonnie-traversal/TestLevel.tscn` | Exists | 10 test zones for full state coverage. |
| `prototypes/bonnie-traversal/README.md` | Exists | Hypothesis, how to run, test coverage. |

### What Does NOT Exist Yet

- Chaos Meter GDD (`design/gdd/chaos-meter.md`) — **BLOCKED on GATE 1**
- Bidirectional Social System GDD (`design/gdd/bidirectional-social-system.md`) — **BLOCKED on GATE 1**
- Level Manager GDD (`design/gdd/level-manager.md`) — MVP, not started
- Interactive Object System GDD (`design/gdd/interactive-object-system.md`) — MVP, not started
- Chaos Meter UI GDD (`design/gdd/chaos-meter-ui.md`) — MVP, not started
- Sprint 1 plan — **BLOCKED on GATE 2** (all 11 MVP GDDs approved)
- Any production code in `src/`
- Any art assets in `assets/`

---

## Locked Decisions — Do Not Re-Litigate

All decisions from Sessions 001-003 still apply. Additional Session 004 locks:

### Renderer
- **GL Compatibility renderer** — `renderer/rendering_method="gl_compatibility"` in project.godot. Forward+ is forbidden for this 2D project. Session-start.sh hook guards against regression.

### Audio Manager
- **Bus hierarchy is final**: Master → Music + SFX. No additional buses.
- **AudioManager is Autoload (infrastructure exception)**: wraps AudioServer, not game state.
- **No uncompressed music in repo, ever.** OGG only for music assets.
- **AudioStreamRandomizer pitch in semitones** (Godot 4.6) — NOT frequency multipliers.
- **All gameplay audio calls go through AudioManager API**. No direct AudioServer access.

### Prototype Implementation
- **Ledge parry is ShapeCast2D proximity** for the prototype — full ledge-plane timing comes in production rewrite.
- **Coyote time is consumed in FALLING state** (not IDLE) — walking off a ledge triggers FALLING first, then coyote timer is active.
- **skid_friction_multiplier = 0.15** (not 0.85 — the skeleton had a bug). 15% of normal decel = very slippery.
- **Prototype code is throwaway**. Do not migrate directly to `src/`. Rewrite to production standards when Sprint 1 begins.

---

## Critical Path

```
GATE 1 (playtest) ← YOU ARE HERE
     |
T-CHAOS + T-SOC  ← parallel GDDs, start immediately after GATE 1
     |
T-PROTO remaining (T-PROTO-10: Camera, if not done)
     |
GATE 2 (all 11 MVP GDDs approved — currently 6/11)
     |
T-SPRINT-01 (Sprint 1 plan)
     |
T-IMPL (Sprint 1 Implementation)
```

---

## Session 005 Opening Protocol

### Step 0: Pre-Flight Check

Before opening Godot:
1. Delete `.godot/shader_cache/` if not already done (stale Forward+ 3D caches)
2. Open project in Godot 4.6 — verify no "2D is not supported" error
3. Verify BONNIE is visible (warm orange rectangle) in TestLevel
4. Verify no 3D shader warnings in Output panel

### Step 1: Receive Playtest Feedback

The developer will provide playtest notes. Run `/playtest-report` to structure findings.

The four feel questions (only Michael can answer):
1. Does the parry window feel like cat reflexes, or an invisible wall?
2. Is post-double-jump commitment readable as physics, or does it feel like input failure?
3. Does the Kaneda slide feel like a consequence, or a punishment?
4. Is the rough landing threshold right at 144px, or does it trigger too often/rarely?

### Step 2: GATE 1 Evaluation

| Gate | Condition | Unlocks |
|------|-----------|---------|
| GATE 1 | Prototype playtested, ACs pass, tuning locked | T-CHAOS + T-SOC GDDs |

**If GATE 1 clears:**
- Lock revised tuning values into `bonnie-traversal.md` Section 7
- Update GATE 1 status in verification table below
- Begin Phase 3 immediately

**If GATE 1 needs more work:**
- Document failing ACs
- Fix BonnieController.gd issues
- Re-playtest before proceeding

### Step 3: Lock Tuning Values

After playtest, update these in `bonnie-traversal.md` §7 with actual tested values:
- `parry_window_frames` — was the 6-frame window right?
- `rough_landing_threshold` — was 144px right?
- `slide_friction` — did the Kaneda slide feel earned or punishing?
- `post_double_jump_air_control` — did commitment feel like physics or input failure?
- Any other values the playtest flagged

---

## Atomic Task Breakdown

### PHASE 3 — Core Gameplay GDDs (after GATE 1)

Run these two in parallel — they are independent of each other.

#### T-CHAOS — Chaos Meter GDD

**T-CHAOS-01** — Create `design/gdd/chaos-meter.md` via `/design-system chaos-meter`

Key constraints for the design agent:
- Pure chaos path must plateau BELOW feeding threshold
- Charm contributions MUST be mathematically required for full meter fill
- NPC entering REACTING: `base_npc_contribution × emotional_level_at_entry`
- Cascade events (secondary NPC triggered): 0.6× weight
- Object destruction: per-object `chaos_value`
- Pest catch: `pest_chaos_value`
- The meter rewards creativity, not persistence

> **Agents**: `game-designer` + `economy-designer`
> **Effort**: M (2–3 sessions)

#### T-SOC — Bidirectional Social System GDD

**T-SOC-01** — Create `design/gdd/bidirectional-social-system.md` via `/design-system bidirectional-social-system`

Key constraints for the design agent:
- Must read `design/gdd/npc-personality.md` Section 3 (full NpcState field list) FIRST
- Must define NpcState write contract — this is the other half of the circular dependency
- Charm interactions: rub/headbutt, sit near, sit on lap, meow at, purr
- Feedback must make the social axis discoverable without a tutorial
- Cross-ref: Social System writes to NpcState; NPC System reads it. Neither calls the other.

> **Agents**: `game-designer` + `ux-designer` (for feedback clarity)
> **Effort**: M (2–3 sessions)

---

### PHASE 3 — Remaining MVP GDDs (can overlap with T-CHAOS/T-SOC)

These do NOT depend on the playtest — start anytime.

#### T-FOUND-04 — Level Manager GDD (System #5)

`/design-system level-manager`

Key design concerns:
- NPC instance registration (NPC System depends on this)
- Room topology for cascade attenuation
- Music event ID selection (Level Manager calls AudioManager.play_music)
- Viewport config dependency (720×540 window; world space unbounded)

> **Agent**: `game-designer` + `gameplay-programmer`

#### T-FOUND-05 — Interactive Object System GDD (System #7)

`/design-system interactive-object-system`

Key design concerns:
- Reads BONNIE's velocity and collision events for interaction force
- Object `chaos_value` (feeds Chaos Meter System #13)
- Environmental chaos events (env_* audio events pre-defined in audio-manager.md)
- RigidBody2D physics objects in prototype already exist in TestLevel.tscn

> **Agent**: `game-designer`

#### T-FOUND-06 — Chaos Meter UI GDD (System #23)

`/design-system chaos-meter-ui`

Key design concerns:
- Must be readable in 720×540 at pixel art scale
- Visible but not prominent — not a health bar
- Depends on Chaos Meter (13) — design after or alongside T-CHAOS
- Consider: is the visual literal (food bowl filling?) or abstract?

> **Agent**: `game-designer` + `ui-programmer`

---

### GATE 2 — All 11 MVP GDDs Approved

Currently 6/11 approved. Remaining 5:

| System | GDD | Status |
|--------|-----|--------|
| Level Manager (5) | Not started | T-FOUND-04 |
| Interactive Object System (7) | Not started | T-FOUND-05 |
| Bidirectional Social System (12) | Not started | T-SOC |
| Chaos Meter (13) | Not started | T-CHAOS |
| Chaos Meter UI (23) | Not started | T-FOUND-06 |

GATE 2 → Sprint 1 plan → Implementation.

---

### PHASE 5 — Art + Music (Independent — Start Anytime)

**T-ART-01** — Aseprite CLI export pipeline (`tools-programmer`)
**T-ART-02** — BONNIE placeholder sprite (32×32px, developer draws)
**T-ART-03** — Apartment mood board (`design/levels/level-02-apartment-reference.md`)
**T-MUSIC-01** — `level_02_apartment.ogg` — developer composes original chiptune

---

## Known Issues in Prototype

1. **CLIMBING → LEDGE_PULLUP auto-clamber**: Uses `is_on_ceiling()` as approximation. Production needs proper top-edge detection via Area2D or raycast.
2. **Ledge parry position snap**: LEDGE_PULLUP fires without snapping BONNIE's position to ledge top. Prototype approximation only.
3. **SQUEEZING exit**: Exits on no input (placeholder). Production needs height probe to detect passage clearing.
4. **Surface detection for footsteps**: Not implemented. AudioManager footstep events need tilemap metadata or physics layer to distinguish hardwood/carpet (OQ-A02 in audio-manager.md).
5. **Parry ShapeCast2D**: Circle shape — may detect geometry in wrong directions. Production needs directional raycasts.

These are intentional prototype shortcuts. Do not fix in `prototypes/` — address in production rewrite.

---

## Verification Gates

| Gate | Condition | Status | Unlocks |
|------|-----------|--------|---------|
| GATE 0 | Camera + Viewport GDDs approved | CLEARED | Streams A+B+C |
| GATE 1 | Prototype playtested, ACs pass, tuning locked | **PENDING — playtest now** | Phase 3 GDDs |
| GATE 2 | All 11 MVP system GDDs approved (6/11 done) | Pending | Sprint 1 plan |
| GATE 3 | Sprint 1 plan approved | Pending | Implementation |

---

## Parallel Subagent Opportunities

### Set B — After GATE 1 (NOW AVAILABLE IF PLAYTEST PASSES)

Launch in one message with two parallel Agent tool calls:

**Agent 1** — `/design-system chaos-meter` (`game-designer` + `economy-designer`)

**Agent 2** — `/design-system bidirectional-social-system` (`game-designer` + `ux-designer`)

### Set C — Anytime (MVP GDDs, no gate dependency)

Launch in one message with up to three parallel Agent tool calls:

**Agent 1** — `/design-system level-manager`
**Agent 2** — `/design-system interactive-object-system`
**Agent 3** — `/design-system chaos-meter-ui` (after T-CHAOS has a draft)

---

## Warnings for Next Session

1. **Delete `.godot/shader_cache/`** before opening Godot — stale Forward+ 3D shaders will cause errors.
2. **GL Compatibility renderer** — must remain `gl_compatibility`. Do not change. Session-start.sh guards this.
3. **AudioStreamRandomizer pitch in semitones** — Godot 4.6. NOT frequency multipliers. Documented in audio-manager.md §4.2 and OQ-A01.
4. **Prototype is throwaway**. BonnieController.gd is not the production implementation. Rewrite to production standards when Sprint 1 begins.
5. **The circular dependency** (Social System ↔ NPC System) is resolved via NpcState. Neither system calls the other. Design both GDDs before implementing either.
6. **BONNIE never dies.** No HP. No game-over. Non-negotiable.
7. **No auto-grab on ledges.** Pure parry only. Non-negotiable.
8. **720×540 = viewport window, NOT world size.** World is unbounded.
9. **Commit identity**: `Co-Authored-By: Hawaii Zeke <(302) 319-3895>`
10. **LOD sprites are Vertical Slice scope.** Prototype uses colored rectangles. Do not block MVP on them.
11. **Prototype known issues** are documented above — do not fix in `prototypes/`, address in production rewrite.
12. **detect-gaps.sh is now cached** — pass `--force` if you need a fresh scan.

---

*Hawaii Zeke — Session 004 is complete. Playtest blockers cleared. Infrastructure hardened.
Delete .godot/shader_cache/, open TestLevel.tscn in Godot 4.6, and play it.
Answer the four feel questions. Come back with notes.
Everything that comes next depends on how BONNIE feels to move.*

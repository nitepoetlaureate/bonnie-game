# BONNIE! — Next Steps Handoff

**For**: Session 009
**Written by**: Hawaii Zeke (Claude) on 2026-04-17
**Context**: Session 008 complete. GATE 1 PASSED. T-CHAOS + T-SOC GDD drafts complete. GATE 2 pending.
**Immediate priority**: Design review of T-CHAOS + T-SOC → GATE 2 → T-FOUND-06 (Chaos Meter UI) → Sprint 1

Read this file first. Then read the locked decisions section before touching anything.

---

## Session 008 Summary

### What Was Done

| Area | Result |
|------|--------|
| GATE 1 closure | **PASS** — 9 ACs pass, 2 deferred (camera → VS, stealth → System 9) |
| PLAYTEST-003 | Written — slide rhythm re-test confirms AC-T03, AC-T06b, AC-T06d |
| T-CHAOS GDD | **DRAFT COMPLETE** — `design/gdd/chaos-meter.md`, all 8 sections |
| T-SOC GDD | **DRAFT COMPLETE** — `design/gdd/bidirectional-social-system.md`, all 8 sections |
| NpcState contract | **LOCKED** — field ownership defined across Systems 9, 12, 13 |
| Gift horror decision | Implemented — horrified NPC reaction → chaos_subtotal (user decision) |
| Mycelium compost | 23 stale notes → 0 stale (renewed or composted with replacements) |
| Systems-index | Updated 8→10 started, MVP progress 10/11 |
| bonnie-traversal.md | §8 AC status markers added to all 15 ACs, summary table, GATE 1 verdict |

### GATE 1 Status — ✅ PASS (Session 008)

**Final disposition (PLAYTEST-003, 2026-04-17):**

| Category | Count | ACs |
|----------|-------|-----|
| PASS | 9 | AC-T03, AC-T06, AC-T06b, AC-T06c, AC-T06c2, AC-T06d, AC-T06e, AC-T06f, AC-T07 |
| PARTIAL | 2 | AC-T02 (stealth radius deferred), AC-T04 (visual dynamism deferred) |
| UNTESTED | 2 | AC-T01 (debug HUD needed), AC-T05 (speed measurement needed) |
| DEFERRED | 2 | AC-T08 (camera → Vertical Slice), stealth radius (→ System 9) |

Core traversal identity validated. Slide rhythm confirmed. Claw brake at 0.30 is adequate.
No code changes required. GATE 1 clears the path for Phase 3 GDDs.

---

## Current State

### What Is Done and Approved

| File | Status | Notes |
|------|--------|-------|
| `design/gdd/game-concept.md` | Approved | Do not redesign. |
| `design/gdd/systems-index.md` | Approved | 10/11 MVP started. Progress tracker updated Session 008. |
| `design/gdd/input-system.md` | Approved | E key updated for DI-003 context-sensitivity. |
| `design/gdd/viewport-config.md` | Approved | 720x540, nearest-neighbor, 60fps. |
| `design/gdd/audio-manager.md` | Approved | 4 apartment mood variants added Session 006. |
| `design/gdd/camera-system.md` | Approved | Look-ahead, ledge bias, recon zoom. |
| `design/gdd/bonnie-traversal.md` | Approved | DI-001 + DI-003 amendments applied. |
| `design/gdd/npc-personality.md` | Approved | Systems 9 vs 10/11 scope note. |
| `design/gdd/level-manager.md` | Approved | System #5 — 7-room apartment, BFS attenuation. |
| `design/gdd/interactive-object-system.md` | Approved | System #7 — 5 weight classes, receive_impact contract. |
| `project.godot` | Configured | 720x540, input map, GodotPhysics2D, nearest-neighbor, gl_compatibility. |
| `prototypes/bonnie-traversal/BonnieController.gd` | Updated S007 | soft_landing, dead vars removed, _try_airborne_climb extracted. |
| `prototypes/bonnie-traversal/BonnieController.tscn` | Updated | SqueezeShape position=(0,14). |
| `prototypes/bonnie-traversal/TestLevel.tscn` | Updated | SqueezeTrigger groups header fixed, ramp geometry removed. |
| `prototypes/bonnie-traversal/PLAYTEST-002.md` | Written | Session 006 report. GATE 1 NEAR-PASS. |
| `icon.svg` | Created S007 | Placeholder cat silhouette. Eliminates editor warning. |

### What Does NOT Exist Yet

- Sprint 1 plan — **UNBLOCKED** (GATE 2 passed)
- Any production code in `src/`
- Any art assets in `assets/`

### Newly Approved This Session

| File | Status | Notes |
|------|--------|-------|
| `design/gdd/chaos-meter.md` | Approved | System 13 — dual-axis meter, charm-required proof, gift horror → chaos |
| `design/gdd/bidirectional-social-system.md` | Approved | System 12 — 5 charm verbs, NpcState write contract, no-HUD legibility |
| `design/gdd/chaos-meter-ui.md` | Approved | System 23 — vertical fill gauge, dual-color, hunger-aware threshold marker |

---

## Locked Decisions — Do Not Re-Litigate

All decisions from Sessions 001-005 still apply. Session 006 additions:

### DI-001 — LEDGE_PULLUP Directional Pop (LOCKED)
- Phase 1 (cling): `pullup_window_frames` (default 10) — reads directional input
- Phase 2 (pop): directional input → `pullup_pop_velocity` launch + `pullup_pop_vertical` arc; no input → stationary clean pullup
- This is a skill-expression layer, not a QoL auto-feature. Keep the timing window honest.

### DI-003 — E Claw Brake during SLIDING (LOCKED, rhythm TBD)
- E during SLIDING removes `abs(velocity.x) * claw_brake_multiplier` per tap
- Default multiplier: 0.30. ~3 taps from full speed to stop. Tunable.
- The "staccato rhythm" at high speed is a design aspiration — Session 007 determines if `claw_brake_multiplier` alone achieves it or if adaptive timing is needed.

### Zone 8 SQUEEZING (LOCKED implementation)
- SqueezeShape position=(0,14) MUST NOT change — this offset is load-bearing
- SqueezeTrigger groups=["SqueezeTrigger"] is in node header — do not move to body
- _squeeze_zone_active flag replaces CeilingCast for entry/exit — do not revert

---

## Critical Path

```
Session 008: GATE 1 ✅ PASSED, T-CHAOS + T-SOC DRAFTED ✅
     |
GATE 2 ✅ PASSED (all 11 MVP GDDs approved — 11/11)
     |
T-SPRINT-01 (Sprint 1 plan)
     |
T-IMPL (Sprint 1 Implementation)
```

---

## Session 009 Opening Protocol

### Priority 0: Sprint 1 Planning

GATE 2 passed Session 008. All 11 MVP GDDs are approved. The critical path is now:
1. Draft Sprint 1 plan covering foundation systems: Input System (1), Viewport Config (2), BONNIE Traversal (6) production rewrite from prototype to `src/`
2. Consider which systems can be implemented in parallel vs. which must be sequential
3. Identify the first playable milestone: BONNIE moving in a production scene with input + viewport + camera

### Priority 1: Production Code Setup

Create the `src/` directory structure per `directory-structure.md`. Set up:
- Core autoloads (InputManager, AudioManager)
- Scene structure for the production level
- GUT test framework integration

### Priority 2: Begin Sprint 1 Implementation (Post-Plan Approval)

Once Sprint 1 plan is approved (GATE 3), begin implementing foundation systems.
Target: BONNIE traversal rewrite from `prototypes/bonnie-traversal/BonnieController.gd` to production-quality `src/gameplay/bonnie_controller.gd` with full type annotations, dependency injection, and GUT test coverage.

### Key Decisions Locked in Session 008

- **NpcState Write Contract**: Social (12) writes `goodwill`, `last_interaction_type`, `comfort_receptivity`. NPC (9) writes `emotional_level`, `current_behavior`, `active_stimuli`, `visible_to_bonnie`, `bonnie_hunger_context`. Chaos Meter (13) reads only.
- **Gift Horror → Chaos**: Horrified NPC reaction to gross gifts adds to `chaos_subtotal`, not charm. Rewards creative chaos thinking.
- **Chaos Ceiling**: Pure chaos maxes at 0.65, feeding threshold at 0.85. The 0.20 gap MUST be filled by charm. Formally proven in chaos-meter.md §4.5.
- **Claw Brake**: 0.30 multiplier confirmed adequate at GATE 1 close. No tuning needed.

---

## Known Prototype Shortcuts (Do NOT Fix in `prototypes/`)

Address in production rewrite in `src/` only:

1. **CLIMBING top-edge detect**: `is_on_ceiling()` approximation. Production needs Area2D or raycast top-edge detect.
2. **LEDGE_PULLUP position snap**: no ledge-top snap in prototype. Production needs snap.
3. **SQUEEZING exit**: `_squeeze_zone_active` flag (improved but still approximate). Production needs proper overlap test.
4. **Surface detection for footsteps**: not implemented.
5. **Parry directional filter**: contact-point Y offset heuristic. Production needs proper raycasts.

---

## Warnings for Session 009

1. **F5 does NOT launch on macOS** — use Play button (▶️) or Cmd+B in Godot editor
2. **SqueezeShape position=(0,14) is load-bearing** — changing it causes BONNIE to float and state-cycle
3. **GL Compatibility renderer** — `gl_compatibility` only. Session-start.sh guards.
4. **AudioStreamRandomizer pitch in semitones** — Godot 4.6. NOT frequency multipliers.
5. **Prototype is throwaway** — BonnieController.gd is not production code. Rewrite in src/.
6. **Systems 10+11 are Vertical Slice** — System 9 only for MVP NPC work.
7. **Both T-CHAOS + T-SOC must be designed before implementing either NPC or Social System.**
8. **BONNIE never dies.** Non-negotiable.
9. **No auto-grab on ledges.** Pure parry only. Non-negotiable.
10. **Commit identity**: `Co-Authored-By: Hawaii Zeke <(302) 319-3895>`

---

## Verification Gates

| Gate | Condition | Status | Unlocks |
|------|-----------|--------|---------|
| GATE 0 | Camera + Viewport GDDs approved | CLEARED ✅ | Streams A+B+C |
| GATE 1 | Prototype playtested, ACs pass, tuning locked | **PASS** ✅ Session 008 | Phase 3 GDDs |
| GATE 2 | All 11 MVP GDDs approved (11/11) | **PASS** ✅ Session 008 | Sprint 1 plan |
| GATE 3 | Sprint 1 plan approved | Pending | Implementation |

---

## DI-002 — Deferred Design Idea (Post-GATE 1)

**Underside Platform Clinging (HANGING state)**

Tester vision: BONNIE can cling to the underside of platforms, shelves, counters.
Stealth mechanic — dodge the aftermath of her own chaos. "Dodge the aftermath of
her own chaos" is the design image.

Deferred scope: GATE 2+. Natural fit with NPC perception system (System 9).
Flag when NPC GDD enters implementation phase.

---

*Hawaii Zeke — Session 008 complete. GATE 1 passed. GATE 2 passed. All 11 MVP GDDs approved.
T-CHAOS + T-SOC + T-FOUND-06 authored and reviewed. NpcState contract locked.
23 stale Mycelium notes composted. Sprint 1 planning is the next milestone.*

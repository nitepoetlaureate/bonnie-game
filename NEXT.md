# BONNIE! — Next Steps Handoff

**For**: Session 008
**Written by**: Hawaii Zeke (Claude) on 2026-04-15
**Context**: Session 007 complete. Comprehensive audit executed (URGENTPLAN.md). Phase 0 triage done (6 tasks). Mycelium fully integrated (sync-init, git hooks, enhanced Claude Code hooks). GATE 1 disposition pending user decision on deferrals.
**Immediate priority**: GATE 1 final call (slide re-test + deferral decisions) → T-CHAOS + T-SOC GDDs

Read this file first. Then read the locked decisions section before touching anything.

---

## Session 007 Summary

### What Was Done

| Area | Result |
|------|--------|
| Mycelium audit | CONFIRMED WORKING — audit CRITICAL-01 was wrong; 51 notes, 4 slots |
| Mycelium sync-init | DONE — notes now travel with `git push`/`git fetch` |
| Mycelium git hooks | INSTALLED — post-commit (doctor), post-checkout (awareness), pre-push (gitleaks), reference-transaction (export gating) |
| Git config cleanup | DONE — deduplicated 4x refspecs, 2x displayref, 2x branch sections |
| Session hooks enhanced | session-start shows stale count; session-stop runs departure protocol |
| P0-02: soft_landing | DONE — `_on_landed()` now checks floor group, Zone 4 works as documented |
| P0-03: icon.svg | DONE — placeholder cat silhouette eliminates editor warning |
| P0-04: dead variables | DONE — removed legacy `skid_timer` and `jump_hold_timer` |
| P0-05: _try_airborne_climb | DONE — extracted from duplicate blocks, placed under PHYSICS HELPERS |
| P0-06: .gdignore files | DONE — mycelium/, production/, docs/, .claude/, .github/ |
| P0-07: progress tracker | DONE — systems-index.md updated from 0/0 to 8/8 started/reviewed |

### GATE 1 Status — CONDITIONALLY NEAR-PASS (unchanged)

**5 ACs passing:**
- AC-T06 Rough landing ✅
- AC-T06c Directional pop ✅
- AC-T06e Climbing (ground + mid-air) ✅
- AC-T06f Claw brake ✅
- AC-T07 Squeezing ✅

**Remaining before GATE 1 PASS:**
1. **Slide rhythm** — claw brake works; slide → brake → stop → pivot cycle needs one targeted re-test
2. **Camera leads movement (AC-T08)** — audit recommends defer to GATE 2 (polish, not traversal-feel)
3. **Stealth radius** — audit recommends defer to post-T-SOC (no NPCs to perceive BONNIE)

---

## Current State

### What Is Done and Approved

| File | Status | Notes |
|------|--------|-------|
| `design/gdd/game-concept.md` | Approved | Do not redesign. |
| `design/gdd/systems-index.md` | Approved | 8/11 MVP approved. Progress tracker fixed Session 007. |
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

- Chaos Meter GDD — **BLOCKED on GATE 1**
- Bidirectional Social System GDD — **BLOCKED on GATE 1**
- Chaos Meter UI GDD — **BLOCKED on T-CHAOS**
- Sprint 1 plan — **BLOCKED on GATE 2**
- Any production code in `src/`
- Any art assets in `assets/`

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
Session 008 Priority A: GATE 1 final call (slide re-test + deferral decisions)
     |
T-CHAOS + T-SOC  ← parallel GDDs, immediately after GATE 1 PASS
     |
T-FOUND-06 (Chaos Meter UI — after T-CHAOS skeleton)
     |
GATE 2 (all 11 MVP GDDs approved — currently 8/11)
     |
T-SPRINT-01 (Sprint 1 plan)
     |
T-IMPL (Sprint 1 Implementation)
```

---

## Session 008 Opening Protocol

### Priority 0: GATE 1 Final Call

**Remaining items:**
1. **Slide rhythm re-test** — launch prototype, execute Kaneda slide → claw brake → stop → pivot cycle
2. **Camera (AC-T08)** — recommend defer to GATE 2 (polish, not traversal-feel)
3. **Stealth radius** — recommend defer to post-T-SOC (no NPCs exist yet)

**How to trigger the Kaneda slide:**
1. Hold Shift (run) in any direction
2. Run until speed > 300 px/s (debug HUD speed counter confirms this)
3. Then: press S (down) OR press the opposite direction key
4. SLIDING state fires

**What to evaluate:**
- Does pressing E during SLIDING feel like a handbrake or a full-stop?
- Can you execute: run → slide → 2-3 E taps → controlled stop → immediate pivot?
- Does the rhythm feel "cat-like" or "mechanical"?
- Try tuning `claw_brake_multiplier` in the Inspector (default 0.30): lower = softer stops

### Priority 1 (Post-GATE 1): T-CHAOS + T-SOC

**Agent 1** → `game-designer` + `economy-designer`: `/design-system chaos-meter`
Key constraints:
- Pure chaos plateaus below the feeding threshold — charm MUST be mathematically required
- No HP/death. Chaos Meter is social/environmental pressure, not a kill condition.
- Max chaos level should feel like REACTING-on-all-NPCs, not game-over warning

**Agent 2** → `game-designer` + `ux-designer`: `/design-system bidirectional-social-system`
Key constraints:
- Read `npc-personality.md` Section 3 first — define NpcState write contract carefully
- Social axis must be visually legible without a UI (NPC body language, reactions)
- NPC↔Social circular dependency is resolved via NpcState shared object (mycelium constraint)

### Priority 2: Stale Mycelium Notes

21 stale notes on old blob versions. Run `! mycelium/scripts/compost-workflow.sh` interactively
to renew valid notes and compost outdated ones.

---

## Known Prototype Shortcuts (Do NOT Fix in `prototypes/`)

Address in production rewrite in `src/` only:

1. **CLIMBING top-edge detect**: `is_on_ceiling()` approximation. Production needs Area2D or raycast top-edge detect.
2. **LEDGE_PULLUP position snap**: no ledge-top snap in prototype. Production needs snap.
3. **SQUEEZING exit**: `_squeeze_zone_active` flag (improved but still approximate). Production needs proper overlap test.
4. **Surface detection for footsteps**: not implemented.
5. **Parry directional filter**: contact-point Y offset heuristic. Production needs proper raycasts.

---

## Warnings for Session 007

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
| GATE 1 | Prototype playtested, ACs pass, tuning locked | **NEAR-PASS** — slide + camera remain | Phase 3 GDDs |
| GATE 2 | All 11 MVP GDDs approved (8/11 done) | Pending | Sprint 1 plan |
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

*Hawaii Zeke — Session 007 complete. Audit executed. Phase 0 triage done. Mycelium fully integrated.
Infrastructure solid. GATE 1 awaiting slide re-test and deferral decisions. Let's close it.*

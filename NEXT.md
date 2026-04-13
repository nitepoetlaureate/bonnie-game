# BONNIE! — Next Steps Handoff

**For**: Session 006
**Written by**: Hawaii Zeke (Claude) on 2026-04-13
**Context**: Session 005 complete. GATE 1 playtest conducted. Prototype bugs fixed. Infrastructure cleaned. GATE 1 NOT YET CLEARED — prototype needs a second playtest after fixes.
**Immediate priority**: Open Godot → playtest the fixed prototype → evaluate GATE 1 → if cleared, begin Phase 3 GDDs

Read this file first. Then read the locked decisions section before touching anything.

---

## Session 005 Summary

### Playtest Results
Conducted first GATE 1 playtest. **GATE 1 NEEDS WORK** — prototype had 3 critical bugs preventing full evaluation:

1. **B01**: No ground-based CLIMBING entry — fixed
2. **B02**: SQUEEZING state unreachable — fixed  
3. **B03**: `parry_window_frames` export existed but wasn't used — fixed (temporal window now implemented)
4. **B04**: ParryCast circle detected floor geometry — fixed (directional filter added)
5. **Debug HUD added** — shows state, velocity, speed thresholds, timer states, fall distance

### Infrastructure Cleanup
- Mycelium seeded with 6 live notes (5 constraints, 1 warning)
- quick-start.md updated to remove Unity/Unreal references
- npc-personality.md: scope clarification added (Systems 9 vs 10/11)
- input-system.md: stale cross-ref note resolved

### Pending (your action needed)
Run these commands to complete the cleanup:
```bash
! rm -rf docs/engine-reference/unity docs/engine-reference/unreal
! rm .claude/agents/unity-specialist.md .claude/agents/unity-addressables-specialist.md .claude/agents/unity-dots-specialist.md .claude/agents/unity-shader-specialist.md .claude/agents/unity-ui-specialist.md .claude/agents/unreal-specialist.md .claude/agents/ue-blueprint-specialist.md .claude/agents/ue-gas-specialist.md .claude/agents/ue-replication-specialist.md .claude/agents/ue-umg-specialist.md .claude/agents/community-manager.md .claude/agents/live-ops-designer.md .claude/agents/localization-lead.md
```

---

## Current State

### What Is Done and Approved

| File | Status | Notes |
|------|--------|-------|
| `design/gdd/game-concept.md` | Approved | Do not redesign. |
| `design/gdd/systems-index.md` | Approved | 6/11 MVP approved. |
| `design/gdd/input-system.md` | Approved | Stale cross-ref note fixed Session 005. |
| `design/gdd/viewport-config.md` | Approved | 720x540, nearest-neighbor, 60fps. |
| `design/gdd/audio-manager.md` | Approved | Full event catalogue, bus hierarchy, playback API. |
| `design/gdd/camera-system.md` | Approved | Look-ahead, ledge bias, recon zoom. |
| `design/gdd/bonnie-traversal.md` | Approved | Full movement vocabulary. |
| `design/gdd/npc-personality.md` | Approved | Scope note added Session 005 (Systems 9 vs 10/11). |
| `project.godot` | Configured | 720x540, input map, GodotPhysics2D, nearest-neighbor, gl_compatibility. |
| `prototypes/bonnie-traversal/BonnieController.gd` | Fixed | B01+B02+B03+B04 fixed. Debug HUD added. |
| `prototypes/bonnie-traversal/BonnieController.tscn` | Updated | CeilingCast + DebugHUD nodes added. |
| `prototypes/bonnie-traversal/TestLevel.tscn` | Exists | 10 test zones. |
| `prototypes/bonnie-traversal/PLAYTEST-001.md` | Written | Session 005 playtest report. GATE 1 NEEDS WORK. |

### What Does NOT Exist Yet

- Chaos Meter GDD — **BLOCKED on GATE 1**
- Bidirectional Social System GDD — **BLOCKED on GATE 1**
- Level Manager GDD — MVP, not started (no gate dependency)
- Interactive Object System GDD — MVP, not started
- Chaos Meter UI GDD — MVP, not started
- Sprint 1 plan — **BLOCKED on GATE 2**
- Any production code in `src/`
- Any art assets in `assets/`

---

## Locked Decisions — Do Not Re-Litigate

All decisions from Sessions 001-004 still apply. Session 005 additions:

### Prototype fixes (Session 005)
- Ground climbing entry: grab button + near Climbable → CLIMBING from IDLE/WALK/RUN/SNEAK
- Slide auto-climb: SLIDING collision with Climbable auto-grabs (no input needed)
- SQUEEZING: CeilingCast RayCast2D triggers entry; clears when ceiling gone
- Parry: temporal window opened on proximity zone entry, directional floor filter applied
- Debug HUD: CanvasLayer/RichTextLabel, layer 128, shows all tuning-relevant state

### Design doc fixes (Session 005)
- Systems 10+11 are Vertical Slice scope (NOT MVP). System 9 only for MVP NPC work.
- NpcState circular dependency note added to mycelium.

---

## Critical Path

```
GATE 1 (re-playtest with fixed prototype) ← YOU ARE HERE
     |
T-CHAOS + T-SOC  ← parallel GDDs, immediately after GATE 1
     |
T-FOUND-04/05/06 ← Level Manager, Interactive Objects, Chaos Meter UI (anytime)
     |
GATE 2 (all 11 MVP GDDs approved — currently 6/11)
     |
T-SPRINT-01 (Sprint 1 plan)
     |
T-IMPL (Sprint 1 Implementation)
```

---

## Session 006 Opening Protocol

### Step 0: Pre-Flight
1. Run any pending cleanup commands from this file's "Pending" section (if not done)
2. Open Godot 4.6 → TestLevel.tscn

### Step 1: Re-Playtest the Fixed Prototype
The debug HUD now shows:
- Current state name (color-coded)
- Velocity (vx/vy) and speed
- Speed thresholds (slide triggers when speed > slide_trigger_speed)
- All timer countdowns (coyote, jump buffer, parry window)
- Fall distance vs rough landing threshold
- Parry proximity and ceiling detection status

**How to trigger the previously-broken mechanics:**
- **Climbing (ground):** Stand near the brown climbable wall (Zone 6), press E (grab)
- **Squeezing:** Walk into Zone 8 (32px gap) — CeilingCast triggers auto-SQUEEZING
- **Kaneda Slide:** Hold Shift + run right until speed > 300, then press S or reverse direction. Watch the debug HUD speed counter.
- **Coyote time:** Watch the "coyote: X/5" counter in the HUD after walking off a ledge
- **Parry window:** Watch "parry_w: X/6" — it opens when near geometry, closes after 6 frames

**Re-answer the four feel questions:**
1. Does the parry window feel like cat reflexes, or an invisible wall?
2. Is post-double-jump commitment readable as physics, or input failure?
3. Does the Kaneda slide feel like a consequence, or a punishment?
4. Is the rough landing threshold right at 144px, or does it trigger too often/rarely?

### Step 2: GATE 1 Evaluation
If all ACs pass on re-playtest → GATE 1 CLEARED → begin Phase 3 immediately.

### Step 3: Controller Verification
Gamepad bindings exist in project.godot for all 10 actions. Plug in controller before launching, verify Godot recognizes it in Input Map settings.

---

## Known Issues in Prototype (Updated Session 005)

Remaining prototype shortcuts (do NOT fix in `prototypes/` — address in production rewrite):

1. **CLIMBING → LEDGE_PULLUP**: `is_on_ceiling()` approximation. Production needs proper top-edge detect via Area2D or raycast.
2. **Ledge parry position snap**: LEDGE_PULLUP fires without snapping to ledge top. Prototype only.
3. **SQUEEZING exit**: CeilingCast-based (improved from Session 004 "no input" placeholder, but still approximate).
4. **Surface detection for footsteps**: Not implemented.
5. **Parry directional filter**: Uses contact-point Y offset heuristic. Production needs proper raycasts.

B01, B02, B03, B04 are now fixed. Items 1-5 above are known intentional shortcuts.

---

## Parallel Subagent Opportunities (After GATE 1)

### Set B — Launch Together (immediately after GATE 1 clears)

**Agent 1** → `game-designer` + `economy-designer`: `/design-system chaos-meter`
Key: pure chaos plateaus below feeding threshold; charm MUST be mathematically required

**Agent 2** → `game-designer` + `ux-designer`: `/design-system bidirectional-social-system`
Key: read `npc-personality.md` Section 3 first; define NpcState write contract

### Set C — Launch Anytime (no gate dependency)

**Agent 1** → `/design-system level-manager`
**Agent 2** → `/design-system interactive-object-system`
**Agent 3** → `/design-system chaos-meter-ui` (after T-CHAOS has a draft)

---

## Warnings for Session 006

1. **Debug HUD is for playtesting only** — do not persist in production code
2. **GL Compatibility renderer** — `gl_compatibility` only. Session-start.sh guards.
3. **AudioStreamRandomizer pitch in semitones** — Godot 4.6. NOT frequency multipliers.
4. **Prototype is throwaway** — BonnieController.gd is not production code. Rewrite in src/.
5. **Systems 10+11 are Vertical Slice** — design and implement System 9 only for MVP.
6. **Both T-CHAOS + T-SOC must be designed before implementing either NPC or Social System.**
7. **BONNIE never dies.** Non-negotiable.
8. **No auto-grab on ledges.** Pure parry only. Non-negotiable.
9. **Commit identity**: `Co-Authored-By: Hawaii Zeke <(302) 319-3895>`
10. **Prototype known issues 1-5 above** — do not fix in `prototypes/`, address in production rewrite.

---

## Verification Gates

| Gate | Condition | Status | Unlocks |
|------|-----------|--------|---------|
| GATE 0 | Camera + Viewport GDDs approved | CLEARED | Streams A+B+C |
| GATE 1 | Prototype playtested, ACs pass, tuning locked | **NEEDS WORK — re-playtest Session 006** | Phase 3 GDDs |
| GATE 2 | All 11 MVP GDDs approved (6/11 done) | Pending | Sprint 1 plan |
| GATE 3 | Sprint 1 plan approved | Pending | Implementation |

---

*Hawaii Zeke — Session 005 complete. Prototype fixed. Infrastructure leaner.
Playtest the fixed prototype with the debug HUD — you'll finally be able to see what's happening.
Come back with GATE 1 pass/fail and tuning notes.*

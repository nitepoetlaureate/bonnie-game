# BONNIE! — Next Steps Handoff

**For**: The next Claude session / collaborator picking up this project
**Written by**: Hawaii Zeke (Claude Sonnet 4.6) on 2026-04-05
**Context**: Pre-production Sprint 0 is complete. All foundation design docs are approved.
**Immediate priority**: Camera GDD → Traversal Prototype → Sprint 1

Read this file first. Then read the locked decisions section before touching anything.

---

## Current State

### What Is Done and Approved

| File | Status | Notes |
|------|--------|-------|
| `design/gdd/game-concept.md` | ✅ Approved | Full game bible. Do not redesign. |
| `design/gdd/systems-index.md` | ✅ Approved | 27 systems, dependency graph, design order. |
| `design/gdd/npc-personality.md` | ✅ Approved | 11-state machine, NpcState interface, Michael+Christen. |
| `design/gdd/bonnie-traversal.md` | ✅ Approved | Full movement vocabulary, all mechanics locked. |
| `DEVLOG.md` | ✅ Live | Session 001 documented. |
| `CHANGELOG.md` | ✅ Live | Pre-production 0.1 documented. |
| `README.md` | ✅ Updated | Active project section added. |
| Mycelium notes | ✅ Pushed | All four GDDs noted. |
| Engine reference | ✅ Configured | Godot 4.6 breaking changes, deprecated APIs, best practices. |

### What Does NOT Exist Yet

- `project.godot` — Godot project file does not exist
- `src/` — No game code whatsoever
- `assets/` — No art assets
- `prototypes/` — No prototype directory
- Camera GDD — Does not exist. **This is a blocker.**
- Chaos Meter GDD — Does not exist.
- Social System GDD — Does not exist.
- Foundation GDDs (input, viewport, audio) — Do not exist.
- Sprint 1 plan — Does not exist.
- `production/session-state/active.md` — Does not exist.

---

## Locked Decisions — Do Not Re-Litigate

These were settled by the developer after full design sessions. Do not propose alternatives.

### Traversal
- **Jump**: tap = hop, hold = full arc (variable height via hold). Double jump is apex-locked (available from first jump's peak, not immediately on leaving ground).
- **Post-double-jump**: air control drops to near-zero (~30 px/s²). BONNIE is committed to her arc. This is intentional — it gives the Ledge Parry its weight.
- **Ledge Parry**: pure timing mechanic, no auto-grab, no visual telegraph. Cat reflexes or BONNIE falls. Miss it → FALLING continues. On success: platform edge → LEDGE_PULLUP, climbable wall → CLIMBING.
- **Wall jump**: only on surfaces tagged `Climbable`. Climbable = carpet, fabric, curtains, rope, cat trees, door frames, shelving. NOT climbable = metal, glass, hardwood, tile, painted drywall.
- **Run input**: dedicated run button (default). Autorun buildup is an accessibility toggle only (off by default).
- **No death**: ever. Looney Tunes / Nine Lives / Felix the Cat physics. DAZED and ROUGH_LANDING are setbacks, not punishments. BONNIE always gets up.
- **The Kaneda slide**: at speed, BONNIE cannot stop instantly. High-speed direction reversal = SLIDING state. Very low friction. Objects in path get knocked over. Pop-jump available from SLIDING.

### NPC System
- **Michael**: apartment owner. Does NOT flee (his apartment). comfort_receptivity floor 0.15. Work phase lowers reaction_threshold by -0.1.
- **Christen**: Michael's partner. CAN flee (to another room). comfort_receptivity floor 0.20. Cascade bleed between them elevated by +0.2 (`relationship_cascade_bonus`).
- **NpcState** is the shared object resolving the Social System / NPC System circular dependency. Neither system calls the other directly.
- **Pre-emptive stimulus removal** (phone off hook, close blinds): Vertical Slice scope. NOT MVP.
- **CHASING state**: Vertical Slice scope (antagonist NPCs). NOT MVP.

### Art + Tech
- **Internal render**: 720×540 nearest-neighbor, pillarboxed on widescreen. Never change this.
- **Performance floor**: integrated graphics (Intel HD / AMD Vega iGPU), 4GB RAM, 2013+ CPU.
- **Draw calls**: ≤50 per frame.
- **Godot 4.6** is beyond LLM training cutoff. ALWAYS check `docs/engine-reference/godot/` before suggesting any API call. Breaking changes in 4.4, 4.5, and 4.6 are real and documented there.

### Project Identity
- BONNIE is a real cat, found under a dumpster on Germantown Ave, Philadelphia.
- Christen is Michael's partner — "the sun, moon, and stars of the apartment's emotional ecosystem."
- Commit co-author line: `Co-Authored-By: Hawaii Zeke <(302) 319-3895>`
- No console target. PC / Steam only.
- Do NOT add Untitled Goose Game to public-facing materials. It appears in the inspiration table inside game-concept.md (design-internal only) — keep it there, remove from anything public-facing.

---

## Critical Path

```
T-CAM (Camera GDD)              ← BLOCKER for prototype
        ↓
T-PROTO (Traversal Prototype)   ← HIGHEST RISK — validates everything
        ↓
T-NPC-FIX + T-FOUND             ← Run in parallel
        ↓
T-CHAOS + T-SOC                 ← Run in parallel
        ↓
T-SPRINT (Sprint 1 Plan)
        ↓
T-IMPL (Sprint 1 Implementation)
```

Art pipeline and music are a fully independent parallel track at any point.

---

## Atomic Task Breakdown

### PHASE 0 — Camera GDD (IMMEDIATE BLOCKER)

The traversal prototype cannot be properly evaluated without a camera built to spec.
The Ledge Parry is timing-sensitive to what the player can *see* — camera look-ahead
determines when the ledge registers, which directly affects whether the parry window
feels fair or arbitrary.

**T-CAM-01** — Create `design/gdd/camera-system.md` skeleton (8 section headers)

**T-CAM-02** — Write Overview + Player Fantasy:
- Camera as a gameplay system, not just a viewport follower
- Look-ahead IS information — what BONNIE can see determines when she can react
- At full run, the player needs to see what's coming before they're in it

**T-CAM-03** — Write Detailed Rules:
- Look-ahead: camera leads BONNIE's direction by state-scaled distance
  (SNEAKING: minimal, WALKING: small, RUNNING: significant, SLIDING: maximum)
- Vertical framing: BONNIE sits in lower third — cat's-eye level, more ground than sky
- Direction reversal: smooth catch-up curve, no hard whip/snap
- Ledge approach bias: during FALLING/JUMPING near geometry, look-ahead biases
  toward the surface so the player sees the ledge before the parry window opens
- Room transitions: lerp to new room anchor when BONNIE crosses boundary
- Optional: slight speed-based zoom-out at full RUNNING (more look-ahead space)

**T-CAM-04** — Write Formulas: smoothing lerp coefficient, look-ahead distance per
state, deadzone radius, direction-anticipation damping

**T-CAM-05** — Write Edge Cases:
- BONNIE in SQUEEZING: camera locks to room view, no character tracking
- Rapid sneak → sprint: look-ahead extends smoothly, no jump cut
- Ledge Parry window: at what point does look-ahead bias kick in exactly?

**T-CAM-06** — Write Dependencies, Tuning Knobs, Acceptance Criteria (at least 4 ACs)

**T-CAM-07** — Write Mycelium note on camera-system.md after developer approval

> **Agent**: `game-designer` for rules, `godot-specialist` review for Godot 4.6 Camera2D API
> **Effort**: S (1 session)
> **Gate**: Developer approval before prototype begins

---

### PHASE 1 — Traversal Prototype

The highest-priority technical task in the entire project. Run `/prototype bonnie-traversal`.
Do NOT timebox this. The traversal must feel right before anything is built on top of it.

**T-PROTO-01** — Create `project.godot`:
- Viewport: 720×540, stretch mode `viewport`, aspect `keep`
- Rendering: nearest-neighbor (Texture Filter: Nearest, no antialiasing)
- Default window: 1440×1080 (2× integer scale), resizable
- Physics: Godot Physics 2D (NOT Jolt — Jolt is 3D-only, not relevant here)
- Cross-reference `docs/engine-reference/godot/current-best-practices.md`

**T-PROTO-02** — Configure input map:
- `move_left`, `move_right` — directional
- `run` — dedicated button, hold to run
- `jump` — tap detection + hold detection both needed
- `sneak` — hold to sneak
- `slide` — explicit slide input (also auto-triggers from opposing-run at speed)
- `grab` — Ledge Parry input
- `drop` — deliberate fall from climb

**T-PROTO-03** — Implement `BonnieController.gd` (CharacterBody2D):
- State machine enum: IDLE, SNEAKING, WALKING, RUNNING, SLIDING, JUMPING,
  FALLING, LANDING, CLIMBING, SQUEEZING, DAZED, ROUGH_LANDING, LEDGE_PULLUP
- velocity: Vector2, processed via move_and_slide()
- Cross-reference breaking-changes.md: CharacterBody2D changed between 4.3→4.6

**T-PROTO-04** — Implement ground movement (SNEAKING / WALKING / RUNNING / SLIDING):
- Speed caps per state (bonnie-traversal.md §4.5)
- ground_acceleration / ground_deceleration formula (§4.1)
- Slide trigger: speed > slide_trigger_speed + opposing input → SLIDING
- slide_friction (very low decel during SLIDING — ~80 px/s²)
- Pop-jump from SLIDING: jump input fires with full horizontal momentum carried

**T-PROTO-05** — Implement jump system (§3.3 + §4.2):
- Tap vs. hold height differentiation (additive hold force up to ceiling)
- Coyote time: 5 frames grace after leaving ledge
- Jump buffering: 6 frames pre-land
- Double jump: apex-locked (`double_jump_window` frames from first jump peak)
- Post-double: air control = `post_double_jump_air_control` (~30 px/s²)

**T-PROTO-06** — Implement landing + skid system (§4.3):
- Speed-proportional skid on landing
- skid_friction_multiplier window (0.15× normal decel)
- Hard skid above 320 px/s (longer window, brief stumble animation)
- Pop-jump during skid: jump input carries full horizontal momentum

**T-PROTO-07** — Implement fall tracking + ROUGH_LANDING (§4.4):
- Track fall_distance from when BONNIE leaves ground non-voluntarily
- rough_landing_threshold default: 144px (recalibrate to actual character art height)
- ROUGH_LANDING: flat recovery animation, limited input for duration
- Cushion surface detection (soft_landing group) resets fall_distance

**T-PROTO-08** — Implement LEDGE PARRY (§3.2):
- During FALLING/JUMPING: detect within `parry_detection_radius` of geometry
- `grab` input within `parry_window_frames` of ledge-plane crossing:
  - Platform edge → LEDGE_PULLUP (snap to top, short animation, full control)
  - Climbable wall → CLIMBING
- NO auto-grab. NO visual telegraph. Miss the window = FALLING continues.

**T-PROTO-09** — Implement CLIMBING + WALL JUMP:
- Climbable surfaces: nodes in `Climbable` group
- Move up/down at climb_speed; left/right input detaches → FALLING/JUMPING
- Wall jump: `jump` while in CLIMBING → perpendicular launch at wall_jump_velocity
- Double jump resets on any Climbable contact

**T-PROTO-10** — Implement basic Camera (to camera GDD spec, T-CAM must be done first):
- Look-ahead scaled by movement state
- Lower-third vertical framing (BONNIE in bottom 40% of screen)
- Smooth catch-up on direction reversal
- Ledge-approach bias during FALLING

**T-PROTO-11** — Build test level geometry:
- Flat ground run corridor (test RUNNING + SLIDING + pop-jump)
- Platforms at varying heights: 1 hop, 1 full jump, 1 double-jump required
- Tall drop ~200px to hard surface (test ROUGH_LANDING)
- Tall drop ~200px to soft surface (test cushion interrupt — no ROUGH_LANDING)
- Series of ledge edges for LEDGE PARRY practice
- Climbable wall sections (carpet-textured Climbable group nodes)
- Smooth wall sections (no Climbable group — test parry FAIL behavior)
- Narrow gap ~32px height (test SQUEEZING)
- Enclosed test space for SLIDING collision (objects to knock over)

**T-PROTO-12** — Playtest + validate against bonnie-traversal.md ACs:
- Run all 12 acceptance criteria (AC-T01 through AC-T08 including the new AC-T06b/c/d/e)
- Capture tuning notes: which default values feel wrong
- Pay particular attention to: parry_window_frames (does it feel like cat reflexes
  or like an invisible wall?), post_double_jump_air_control (is the commitment
  readable or does it feel like input failure?), skid_base_duration (too short = no
  Kaneda, too long = frustrating)
- Run `/playtest-report` to structure findings
- Lock revised tuning values back into bonnie-traversal.md §7

> **Agents**: `godot-specialist` + `gameplay-programmer`
> **Critical**: Cross-reference `docs/engine-reference/godot/breaking-changes.md`
>   before EVERY API call. AudioServer, AnimationPlayer, and CharacterBody2D all changed.
> **Effort**: L (multiple sessions). The prototype is not a deliverable — the *feel* is.

---

### PHASE 2 — NPC Completion + Foundation GDDs (parallel after prototype)

#### Subgroup A — Fix NPC GDD

**T-NPC-FIX-01** — Add Christen arrival trigger to `design/gdd/npc-personality.md`:
Currently Christen's routine has no timing. Add: arrival_trigger (time-based OR
event-based), phase durations in seconds of ROUTINE-state time, departure condition.
Her phases need the same specificity as Michael's 6-phase schedule.

**T-NPC-FIX-02** — Add routine phase advancement spec:
Currently undefined: what triggers Michael from Morning → Work phase?
Add: each phase has `phase_duration` (seconds of ROUTINE time, pauses in other states).
Add phase_duration as a tuning knob per NPC per phase in §7.

> **Agent**: `game-designer`
> **Effort**: XS (30 min)

#### Subgroup B — Foundation GDDs (all three in one session)

**T-FOUND-01** — Write `design/gdd/input-system.md`:
- All button actions with semantic names
- Input buffering rules (jump: 6 frames; grab/parry: NO buffer — pure timing)
- Analog vs. digital (sneak on analog stick below sneak_threshold)
- Accessibility: full button remapping required

**T-FOUND-02** — Write `design/gdd/viewport-config.md`:
- 720×540 internal, nearest-neighbor, pillarbox
- Stretch mode: `viewport` + `keep`
- Integer scaling: 1× / 2× / 4×
- Widescreen: black pillars, no stretching, no content cropping
- No post-processing effects requiring discrete GPU

**T-FOUND-03** — Write `design/gdd/audio-manager.md`:
- Bus structure: Master → Music (OGG streaming) + SFX (short uncompressed WAV)
- Volume controls: Music, SFX, Master (saved to user config)
- BONNIE audio events: footstep variants by surface, meow, chirp, thud, slide SFX,
  parry-grab SFX, rough-landing SFX, DAZED stars SFX
- NPC vocal samples: crunchy SNES/Genesis-style digitized exclamations —
  surprise, anger, delight, fear — short, expressive, era-appropriate
- No uncompressed music in repository

> **Agent**: `game-designer` for content, `godot-specialist` review for Godot 4.6 audio API
> **Effort**: S (all three in one session)

---

### PHASE 3 — Core Gameplay GDDs (after prototype validated)

Run these two in parallel — they're independent of each other.

#### T-CHAOS — Chaos Meter GDD

**T-CHAOS-01** — Create `design/gdd/chaos-meter.md` skeleton

**T-CHAOS-02** — Design contribution sources:
- NPC entering REACTING: `base_npc_contribution × emotional_level_at_entry`
- Charm during VULNERABLE (levity multiplier path): high value, earns charm meter
- Object destruction: per-object `chaos_value`
- Pest catch: `pest_chaos_value`
- Cascade events (secondary NPC triggered): reduced (×0.6 weight)

**T-CHAOS-03** — Design the feeding threshold constraint:
> "The meter rewards creativity, not persistence."
- Pure chaos path must plateau below feeding threshold
- Charm contributions MUST be required to reach max meter
- Formula must enforce this mathematically, not just as a rule

**T-CHAOS-04** — Design visual representation:
- Visible but not prominent — this is not a health bar
- Consider: is it literal (food bowl filling?) or abstract?
- Must be readable in 720×540 at pixel art scale

**T-CHAOS-05** — Write full GDD (all 8 sections, formulas, ACs)

> **Agents**: `game-designer` + `economy-designer`
> **Effort**: M

#### T-SOC — Bidirectional Social System GDD

**T-SOC-01** — Create `design/gdd/bidirectional-social-system.md` skeleton

**T-SOC-02** — Define charm interaction types with NpcState write specs:
- Rub/headbutt: +goodwill, requires adjacency, NPC not in REACTING
- Sit near: ambient goodwill trickle (proximity radius, passive)
- Sit on lap: higher rate, NPC must be in ROUTINE/RECOVERING/VULNERABLE
- Meow at: small goodwill + bumps NPC toward AWARE
- Purr: while sitting on NPC, significant goodwill during VULNERABLE

**T-SOC-03** — Spec NpcState writes per interaction:
This is the other half of the circular dependency. The Social System writes to NpcState;
the NPC System reads it. Define exactly what fields are written and under what conditions.

**T-SOC-04** — Design feedback clarity:
The player must discover the social axis exists without being told.
Goodwill gain feedback must be legible but not UI-heavy at 720×540.
Consider: what does the player see/hear when charm is working?

**T-SOC-05** — Write full GDD (all 8 sections, formulas, ACs)

> **Agents**: `game-designer` + `ux-designer` (feedback clarity)
> **Effort**: M

---

### PHASE 4 — Sprint 1 Plan

**T-SPRINT-01** — Run `/sprint-plan new` once all of the following exist:
- Traversal prototype validated (T-PROTO-12 complete)
- Foundation GDDs approved (T-FOUND complete)
- Chaos Meter GDD approved (T-CHAOS complete)
- Social System GDD approved (T-SOC complete)

Sprint 1 goal recommendation: **BONNIE moves, Michael reacts, chaos meter ticks.**
No art, no audio, placeholder geometry only.

Suggested Sprint 1 scope:
- Foundation: viewport config, input map, audio bus skeleton
- BONNIE traversal code (migrate from prototype into `src/`)
- NpcState class + 11-state machine skeleton (Michael only, ROUTINE/AWARE/REACTING minimum)
- Michael routine: Morning + Work phases only
- Chaos meter: float increments correctly on REACTING event
- Verify: BONNIE runs → Michael enters AWARE → REACTING → chaos meter ticks

> **Agent**: `producer`
> **Effort**: S

---

### PHASE 5 — Art + Music (Independent Track — Start Anytime)

**T-ART-01** — Set up Aseprite CLI export pipeline:
```bash
aseprite -b --sheet output.png --data output.json input.aseprite
```
Target: Godot SpriteFrames resource. Output: `assets/art/sprites/`
Agent: `tools-programmer`

**T-ART-02** — BONNIE placeholder sprite:
32×32px black cat silhouette in Aseprite. Developer draws; tools-programmer sets up import.
Purpose: validates the pipeline, gives prototype something to render.

**T-ART-03** — Apartment mood board:
Reference images for Level 2. Color palette, tile set needs, furniture inventory, lighting tone.
Output: `design/levels/level-02-apartment-reference.md`

**T-MUSIC-01** — Level 2 apartment theme:
Developer composes original chiptune. No tooling needed.
Style: cozy with undercurrent of chaos potential.
Output: `assets/audio/music/level_02_apartment.ogg` when ready.

---

## Parallel Subagent Opportunities

### Set A — GDD Writing Sprint (3 agents simultaneously, after T-CAM approved)

Launch in one message with three parallel Agent tool calls:

**Agent 1** — Foundation GDDs (`game-designer`)
Write input-system.md + viewport-config.md + audio-manager.md.
Context: bonnie-traversal.md for input needs, technical-preferences.md for viewport,
game-concept.md §NPC Dialogue for audio philosophy.

**Agent 2** — Christen Routine Fix (`game-designer`)
Edit `design/gdd/npc-personality.md` §3.4.
Add arrival trigger, phase timings, phase_duration tuning knobs for Christen.
Match the specificity of Michael's 6-phase routine schedule.

**Agent 3** — Session State File (`general-purpose`)
Create `production/session-state/active.md` using template in
`.claude/docs/context-management.md`. Populate with current state:
stage = Pre-Production, active task = Camera GDD → Traversal Prototype,
key files = all four approved GDDs.

### Set B — Gameplay GDDs (2 agents simultaneously, after T-PROTO-12)

**Agent 1** — Chaos Meter GDD (`game-designer` + `economy-designer`)
Write `design/gdd/chaos-meter.md`. All 8 sections.
Key constraint: charm MUST be required for full meter fill. Brute-force chaos plateaus.

**Agent 2** — Social System GDD (`game-designer` + `ux-designer`)
Write `design/gdd/bidirectional-social-system.md`. All 8 sections.
Key challenge: feedback must make the social axis discoverable without explicit tutorial.
Must define NpcState write contract (other half of NPC circular dependency).

### Set C — Prototype Implementation (2 agents, after T-PROTO-03 state machine exists)

**Agent 1** — Ground movement + jump (`godot-specialist`)
Implement T-PROTO-04 through T-PROTO-06.
File: `prototypes/bonnie-traversal/BonnieController.gd`
Context: bonnie-traversal.md §3.1 (SNEAKING/WALKING/RUNNING/SLIDING/JUMPING/LANDING),
§3.3 (jump input model), §4.1–4.3 (formulas).

**Agent 2** — Camera implementation (`godot-specialist`)
Implement T-PROTO-10 in parallel with movement work.
File: `prototypes/bonnie-traversal/BonnieCamera.gd`
Context: camera-system.md (must exist first), bonnie-traversal.md §3.4 (stimulus radii
table shows state-by-state spatial context useful for look-ahead scaling).

---

## Warnings for the Next Collaborator

1. **Godot 4.6 is beyond LLM training cutoff.** Check `docs/engine-reference/godot/`
   before every API suggestion. Specific traps:
   - `AnimationPlayer.play()` now uses StringName: `play(&"animation_name")`
   - AudioServer API changed in 4.6
   - CharacterBody2D behavior changed between 4.3 and 4.6
   - Jolt is 3D-only and completely irrelevant to BONNIE's 2D physics

2. **Camera before prototype.** T-CAM must be approved before T-PROTO begins.
   The Ledge Parry cannot be evaluated without a camera built to spec.

3. **NPC + Social designed together.** They share NpcState. Cannot implement
   the NPC state machine without knowing what the Social System writes.
   Design both GDDs before implementing either.

4. **No Singleton for mutable game state.** Hard rule. Use signals or dependency
   injection. NpcState is a resource object, not a singleton.

5. **No auto-grab on ledges.** This was explicitly rejected. Pure parry only.
   Auto-grab breaks aerial sequences and hides exploration. Non-negotiable.

6. **Run button is explicit.** Not auto-run. Auto-run is accessibility toggle only.

7. **BONNIE never dies.** No HP. No game-over. DAZED and ROUGH_LANDING are max.

8. **Commit identity**: `Co-Authored-By: Hawaii Zeke <(302) 319-3895>`

9. **Prototype code is throwaway.** `prototypes/` is isolated from `src/`.
   Standards relaxed for speed. No doc comments required in prototype.

10. **Stage/commit before Mycelium-noting new files.** Unstaged files can't be
    noted by path. Stage first, then `mycelium.sh note <file> -k <kind> -m "..."`.
    For already-committed files with existing notes, use `-f` to overwrite.

11. **Christen's routine is currently underspecified** in npc-personality.md.
    She has phase names but no timings or arrival trigger. Fix this before
    attempting NPC implementation (T-NPC-FIX).

---

## Recommended Reading Order for a New Session

```bash
# 1. Start here
cat NEXT.md  # this file

# 2. Studio config and rules
cat CLAUDE.md
cat .claude/docs/technical-preferences.md

# 3. Engine warnings (before any Godot code)
cat docs/engine-reference/godot/VERSION.md
cat docs/engine-reference/godot/breaking-changes.md

# 4. Design docs (read whichever is relevant to current task)
cat design/gdd/bonnie-traversal.md   # if working on prototype
cat design/gdd/npc-personality.md    # if working on NPC/Social

# 5. Session context
mycelium.sh find constraint
mycelium.sh find warning
mycelium/scripts/context-workflow.sh <file-you-are-working-on>
```

---

## Quick Reference: Key Formulas

**Horizontal movement** (bonnie-traversal.md §4.1):
```gdscript
velocity.x = move_toward(velocity.x, target_speed, accel * delta)
# accel = 800 px/s² (moving), 600 px/s² (stopping), 80 px/s² (SLIDING)
```

**Jump velocities** (§4.2):
- Tap → `hop_velocity` = 280 px/s
- Hold → additive up to `jump_velocity` = 480 px/s
- Double jump → `double_jump_velocity` = 380 px/s
- Post-double `air_control` = 30 px/s² (near-zero, committed)

**Landing skid** (§4.3):
- Skid triggers above 180 px/s impact speed
- Hard skid above 320 px/s
- Skid friction multiplier: 0.15× normal deceleration

**Rough landing** (§4.4):
- `fall_distance ≥ 144px` without cushion surface → ROUGH_LANDING

**NPC emotional decay** (npc-personality.md §4.1):
```gdscript
emotional_level += (baseline_tension - emotional_level) * emotion_decay_rate * delta
```

**Goodwill** (§4.2):
```gdscript
goodwill = clamp(goodwill + charm_value * comfort_receptivity, 0.0, 1.0)
```

**Cascade** (§4.4):
```gdscript
cascade_stimulus = emotional_level_A * cascade_bleed_factor
# Michael ↔ Christen: cascade_bleed_factor + 0.2 (relationship_cascade_bonus)
```

---

*Hawaii Zeke — Pre-production Sprint 0 is complete. The design foundation is solid.
Build BONNIE. Make her feel right to move. Everything else follows from that.*

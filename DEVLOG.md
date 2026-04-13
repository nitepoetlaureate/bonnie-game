# BONNIE! — Development Log

Design decisions, session notes, and milestone progress for BONNIE! —
a sandbox chaos puzzle game developed with Claude Code Game Studios.

---

## [2026-04-05] Session 001 — Pre-Production Sprint 0

**Developer**: m. raftery
**Studio**: Claude Code Game Studios (Godot 4.6)
**Focus**: Foundation — game concept, systems architecture, core design GDDs

---

### Studio Infrastructure

Configured the full Claude Code Game Studios environment for BONNIE! development:

- Engine reference docs populated for Godot 4.6 (breaking changes 4.4→4.5→4.6,
  deprecated APIs, current best practices, version-pinned at 2026-02-12)
- Mycelium knowledge layer initialized — session hooks wired (session-start,
  session-stop, pre-compact), departure protocol active
- `/setup-engine godot 4.6` confirmed ready
- `.mycelium/repo-id` + zone initialized; notes push/fetch wired to remote

---

### Game Concept Locked

**File**: `design/gdd/game-concept.md` — **Approved**

BONNIE! is a sandbox chaos / puzzle game. You are BONNIE — a big black cat
(a real cat, found under a dumpster on Germantown Ave in Philadelphia) with
an unshakeable belief that she deserves tuna. Engineer cascading chaos until
somebody feeds you. Play it completely cool while everything burns.

**Core fantasy**: *You are a cat. You are not sorry about any of it.*

**Comparable titles**: Haunting Starring Polterguy × Maniac Mansion.
The replayability model is variable-stuffed systems,
not scripted linearity — no two runs feel identical.

**Key decisions locked this session:**
- Bidirectional social system: charm AND chaos both fill the chaos meter
- NPCs speak: SNES-style text boxes + crunchy Genesis/SNES vocal samples
- Mini-games discovered organically mid-play (Yo! Noid / Nightshade model)
- End-of-level feeding cutscenes unique per level, hand-crafted
- Five levels: Germantown Ave → Apartment → Vet → K-Mart → Italian Market
- Performance target: "most beloved cult classic 2D game ever made for the
  Sega Dreamcast" — 720×540, nearest-neighbor, ≤50 draw calls, integrated
  graphics capable

**MVP definition**: BONNIE movement + one environment (Level 2: apartment) +
two NPCs + chaos meter + fed animation. 4–6 weeks.

---

### Systems Architecture

**File**: `design/gdd/systems-index.md` — **Approved**

27 systems identified and mapped with full dependency graph, design order,
effort estimates, and priority tiers.

**MVP systems (11)**: Input, Viewport/Rendering Config, Audio Manager, BONNIE
Traversal, Camera, Level Manager, Interactive Object System, Reactive NPC,
Bidirectional Social System, Chaos Meter, Chaos Meter UI.

**Highest-risk systems flagged:**
- BONNIE Traversal — prototype immediately, physics feel is make-or-break
- Reactive NPC — most complex system, scope-balloon risk, design with strict limits
- Bidirectional Social — novel mechanic, feedback must make the social axis visible
- Chaos Meter — balance-sensitive, tuning only knowable through playtesting

**Key architectural decision**: NPC System / Social System circular dependency
resolved via shared `NpcState` data object. Neither system calls the other directly.

---

### NPC Personality System

**File**: `design/gdd/npc-personality.md` — **Approved**

Full design for the most complex system in the game. Maniac Mansion-depth NPC
simulation built on a continuous emotional state model.

**State machine — 11 states:**

| State | What It Means |
|-------|---------------|
| ASLEEP | Sleeping. Below wake threshold, stimulus is ignored. |
| GROGGY | Just woken. Confused, low reactivity, comedy target. |
| ROUTINE | Going about their day. Following schedule. |
| AWARE | Noticed something. "What was that?" Not yet reacting. |
| REACTING | Active emotional response. Loud, visible, cascades to others. |
| RECOVERING | Cooling down. Hair-trigger window. Comfort starts landing. |
| VULNERABLE | Post-stress exhaustion. Max comfort_receptivity. Jackpot state. |
| CLOSED_OFF | Social shutdown. Won't engage. Too much chaos without goodwill recovery. |
| FLEEING | Running away (Christen can flee; Michael does not — his apartment). |
| CHASING | Antagonist pursuit. Vertical Slice scope. |
| FED | Terminal. Level complete. |

**NpcState interface (8 fields):**
```
emotional_level: float       — 0.0 (calm) → 1.0 (max stress)
goodwill: float              — 0.0 (hostile) → 1.0 (loves BONNIE)
current_behavior: NpcBehavior
comfort_receptivity: float   — floor is per-NPC
active_stimuli: Array[Stimulus]
visible_to_bonnie: bool
last_interaction_type: InteractionType
bonnie_hunger_context: bool
```

**MVP NPCs:**
- **Michael** — apartment owner, works from home. Moderate patience. Work phase
  lowers reaction threshold (-0.1). Does not flee. comfort_receptivity floor 0.15.
- **Christen** — Michael's partner (the sun, moon, and stars of the apartment's
  emotional ecosystem, and BONNIE knows this). More easily startled. Can flee
  to another room. comfort_receptivity floor 0.20.

**Domino Rally cascade**: When NPC A enters REACTING, it emits a cascade
stimulus weighted by emotional_level × cascade_bleed_factor to nearby NPCs.
Michael ↔ Christen mutual cascade is elevated by relationship_cascade_bonus (0.2).
Chain depth: max 2 (MVP). Loops prevented via cascade_source_id.

**New mechanics surfaced:**
- **Levity multiplier** (1.5×): charm interaction within 4s of a chaos event earns bonus goodwill
- **Hunger boost** (ambient): BONNIE unfed >300s → increased clumsiness + NPC feeding_threshold -0.1
- **VULNERABLE state**: post-REACTING crash — emotional_level below threshold, max comfort_receptivity
- **Pre-emptive stimulus removal** (phone off hook, close blinds): Vertical Slice scope

---

### BONNIE Traversal System

**File**: `design/gdd/bonnie-traversal.md` — **Approved**

Full physics and movement design. Core principle: **controls are snappy, physics
consequences are real.** Input registers instantly; the challenge is managing what
happens after you commit.

Reference: *clumsy feline Ryu Hayabusa.*

**Complete movement vocabulary:**

| State | Description |
|-------|-------------|
| SNEAKING | Slow, quiet, minimal stimulus radius. NPCs don't notice. |
| WALKING | Default ground move. |
| RUNNING | Full speed. Dedicated run button (autorun as accessibility toggle). |
| SLIDING | The Kaneda. Can't stop. Objects in path get knocked over. Pop-jump available. |
| JUMPING | Tap = hop. Hold = full arc. Coyote time + jump buffering. |
| DOUBLE JUMP | Apex-locked. Post-double air control near zero — BONNIE commits to arc. |
| LEDGE PARRY | Pure timing. No auto-grab. No telegraph. Cat reflexes or you fall. |
| WALL JUMP | On climbable surfaces (carpet/fabric) only. Metal/glass/hardwood: no grab. |
| CLIMBING | On designated Climbable nodes. Hunger-boost adds slip chance. |
| SQUEEZING | Narrow passages. Hidden from NPCs. |
| DAZED | Brief stun. Comic. Time cost only — no health damage. |
| ROUGH_LANDING | ~18ft+ fall. Extended recovery. Nine Lives trigger candidate. |
| LEDGE_PULLUP | Post-parry. BONNIE scrambles up. Short animation, full control restored. |

**Key design decisions:**
- Run button is default; autorun is an accessibility toggle
- Double jump available from first jump's apex (not immediately on leaving ground)
- Post-double-jump air control: ~30 px/s² (near zero). BONNIE is twisted and committed.
- The intended high-skill combo: run → jump → double jump at apex → committed arc
  → LEDGE PARRY at the right moment → stick it. The reduced post-double control
  is what gives the parry its weight.
- No auto-grab on ledges. BONNIE goes flying off and stays flying off unless the
  player executes the parry. Auto-grab would break aerial sequences and hide exploration.
- No death. Ever. Looney Tunes / Nine Lives / Felix the Cat logic. BONNIE always
  gets up. DAZED and ROUGH_LANDING are setbacks, not punishments.
- Camera is co-equal with traversal. Bad camera = bad game. Camera must be
  prototyped alongside traversal.

---

### What's Next

- **`/prototype bonnie-traversal`** — create Godot project, BONNIE moves for the
  first time. Validate physics feel. This is the most critical risk in the project.
- **Foundation GDDs** — `input-system.md`, `viewport-config.md`, `audio-manager.md`
  (small, ~30 min each, unblock everything)
- **`/sprint-plan new`** — Sprint 1 after traversal prototype validated
- **Art pipeline** — BONNIE placeholder sprite in Aseprite; starts the toolchain
- **Music** — first original track (apartment theme); no tooling needed, just start

---

---

## [2026-04-08] Session 002 — Foundation Systems

**Developer**: m. raftery
**Focus**: Viewport configuration + Camera system GDDs — unblock prototype

### Completed
- **Viewport Config GDD** (System #2) — Approved. 720×540 internal resolution, nearest-neighbor filtering, 4:3 locked, stretch mode "viewport", integer scaling (2× default, 4× supported).
- **Camera System GDD** (System #4) — Approved. Look-ahead, ledge bias, recon zoom, per-state camera values.

### GATE Status
- GATE 0: CLEARED — Camera + Viewport GDDs approved. Prototype stream unblocked.

### What Happened
Two foundation GDDs that were blocking the traversal prototype. Both small, both approved in a single session. GATE 0 cleared, enabling parallel work streams: prototype implementation (Set A), Phase 3 GDDs (Set B, after GATE 1), and Level Manager / Interactive Object / Chaos Meter UI GDDs (Set C, anytime).

---

---

## [2026-04-11] Session 003 — Foundation GDDs + Traversal Prototype

**Focus**: Foundation GDDs complete + Traversal Prototype implemented

### Completed
- **Input System GDD** (System #1) — Approved. 10 actions, buffering rules (jump buffered, grab frame-exact), analog thresholds, accessibility remapping.
- **Audio Manager GDD** (System #3) — Approved. Bus hierarchy, full event catalogue (17 traversal SFX, 6 BONNIE vocal, 8 NPC vocal, 4 env, 1 music), playback API, Godot 4.6 semitone trap documented.
- **T-NPC-FIX** — Christen routine fully specified: arrival trigger (Michael Afternoon→Evening transition), 6 phases with durations, flee behavior with stress carry stacking.
- **T-PROTO-01/02/03** — `project.godot` (720×540, nearest-neighbor, GodotPhysics2D), input map (10 actions), BonnieController.gd skeleton (13-state enum).
- **T-PROTO-04 through T-PROTO-09** — Full BonnieController.gd implementation: all 13 state handlers, ledge parry via ShapeCast2D, coyote time, jump buffer, apex-locked double jump, pop-jump from slide/skid.
- **T-PROTO-11** — TestLevel.tscn: 10 test zones (run corridor, platform steps, hard/soft drop, ledge parry practice, climbable/smooth walls, squeeze gap, collision objects, end wall).

### Systems Index
- 6/11 MVP systems approved: Input (1), Viewport (2), Audio Manager (3), Camera (4), Traversal (6), NPC (9)

### GATE Status
- GATE 0: CLEARED
- GATE 1: PENDING — prototype ready, awaiting playtest

### Next Session Opens With
Playtest feedback → GATE 1 evaluation → T-CHAOS + T-SOC GDDs (parallel)

---

---

## [2026-04-13] Session 004 — Playtest Unblock + Infrastructure Hardening

**Developer**: m. raftery
**Focus**: Fix critical playtest blockers, harden hooks/infrastructure, fill documentation gaps

### Critical Fixes
- **BONNIE invisible** — PlaceholderSprite was `Color(0,0,0,1)` (black) on black background. Changed to warm orange `Color(1, 0.4, 0.2, 1)`.
- **Wrong renderer** — `project.godot` had no `renderer/rendering_method` set. Godot defaulted to Forward+ (3D), compiling 60+ 3D shader caches (SSAO, SSR, VoxelGI, volumetric fog) for a pure 2D game. Switched to `gl_compatibility`.

### Infrastructure Improvements
- **detect-gaps.sh** — Added caching. Saves 5-10k tokens per session start by skipping filesystem scans when `design/`, `src/`, `prototypes/` are unchanged. `--force` flag bypasses cache.
- **session-start.sh** — Added renderer guard. Warns if `project.godot` has no renderer set or uses Forward+ for a 2D-only project.
- **validate-commit.sh** — Enhanced GDD section check to validate all 8 required sections by name with a missing count. Fixed silent Python failure (now surfaces as visible warning).

### Documentation Gaps Filled
- Added missing Session 002 entry to DEVLOG.md (viewport-config + camera-system, 2026-04-08)
- Added [Pre-Production 0.2] to CHANGELOG.md
- Created `production/session-state/active.md` (living session checkpoint)

### GATE Status
- GATE 0: CLEARED
- GATE 1: **READY FOR PLAYTEST** — blockers resolved

### Next Session Opens With
Delete `.godot/shader_cache/` → Open Godot → Playtest → Answer feel questions → GATE 1 evaluation

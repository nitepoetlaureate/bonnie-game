# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Pre-Production 0.7] — 2026-04-17

### Added — GDDs (Session 008)
- `design/gdd/chaos-meter.md` — Chaos Meter GDD (System 13): dual-axis meter, chaos ceiling 0.65, feeding threshold 0.85, charm-required proof, gift horror → chaos, 10 ACs
- `design/gdd/bidirectional-social-system.md` — Bidirectional Social System GDD (System 12): 5 charm verbs, NpcState write contract, no-HUD visual legibility, goodwill decay, 10 ACs
- `prototypes/bonnie-traversal/PLAYTEST-003.md` — Session 008 slide rhythm re-test report

### Changed — GATE 1 Verdict (Session 008)
- GATE 1: **NEAR-PASS → PASS** — slide rhythm re-test confirmed AC-T03, AC-T06b, AC-T06d
- AC-T08 (camera leads movement): DEFERRED to Vertical Slice by user decision
- Stealth radius: DEFERRED pending System 9 (NPC AI) by user decision
- `design/gdd/bonnie-traversal.md` §8 — AC status markers added to all 15 acceptance criteria

### Changed — Systems Index (Session 008)
- `design/gdd/systems-index.md` — Systems 12 + 13 status: Not Started → Draft; progress 8→10/11 MVP started

### Changed — Mycelium (Session 008)
- 23 stale notes composted to 0 — renewed or replaced with context notes on HEAD
- NpcState write contract locked as constraint on `npc-personality.md`

### Locked Decisions (Session 008)
- **NpcState Write Contract**: Social writes goodwill/last_interaction_type/comfort_receptivity; NPC writes emotional_level/current_behavior/active_stimuli/visible_to_bonnie/bonnie_hunger_context; Chaos Meter reads only
- **Gift Horror → Chaos**: Horrified NPC reaction adds to chaos_subtotal, not charm
- **Chaos Ceiling**: 0.65 < feeding_threshold 0.85 — charm mathematically required (proven §4.5)

### GATE Status
- GATE 1: **PASS** ✅ — 9 PASS / 2 PARTIAL / 2 UNTESTED / 2 DEFERRED. Core traversal identity validated.
- GATE 2: Pending — 8/11 approved, 10/11 started. Needs: design review of Systems 12+13, then System 23 (Chaos Meter UI).

---

## [Pre-Production 0.6] — 2026-04-15

### Fixed — Prototype (Session 006)
- B02 (regression/incomplete): SQUEEZING fully fixed — three-layer fix:
  (1) `groups=["SqueezeTrigger"]` moved to node header (was silently ignored as body property)
  (2) SqueezeApproachLeft/Right removed (tops at y=468 = zero clearance, physically blocked entry)
  (3) `CollisionShape2D` position `Vector2(0,0)` → `Vector2(0,14)` — squeeze shape now floor-aligned; eliminates float→fall→squeeze cycle
- B07: F5 macOS shortcut — documented workaround: use Play button (▶️) or Cmd+B in Godot editor
- B08: LEDGE_PULLUP redesigned — replaced auto-fire with two-phase directional pop system (DI-001)

### Added — Prototype (Session 006)
- DI-001: LEDGE_PULLUP directional pop — Phase 1 cling reads directional input; Phase 2 resolves as momentum-carry launch or stationary pullup
- DI-003: Claw brake during SLIDING — E key removes `abs(velocity.x) * claw_brake_multiplier` per tap; ~3 taps from full speed to stop
- Mid-air climbing: E-press during JUMPING/FALLING while touching Climbable → instant CLIMBING entry
- E-scramble burst: pressing E during CLIMBING fires `climb_claw_impulse` for `climb_claw_burst_frames` — more cat-like than smooth surface slide
- Auto-clamber: CLIMBING state exits to JUMPING without player UP input when `is_on_ceiling()` or slide normal y > 0.5
- `_squeeze_zone_active` flag-based SQUEEZING trigger — safe from physics flushing errors; replaces CeilingCast-based entry

### Added — GDDs (Session 006)
- `design/gdd/level-manager.md` — Level Manager GDD approved (System #5): 7-room apartment topology, BFS cascade attenuation, mood-based music transitions, post-win contract
- `design/gdd/interactive-object-system.md` — Interactive Object System GDD approved (System #7): 5 weight classes, `receive_impact()` contract, liquid two-signal pattern, object_displaced stimulus

### Changed — GDDs (Session 006)
- `design/gdd/bonnie-traversal.md` — DI-001 + DI-003 amendments: LEDGE_PULLUP two-phase redesign, SLIDING claw brake formula, 4 new tuning knobs, 2 new ACs (AC-T06c2, AC-T06f)
- `design/gdd/input-system.md` — E key `grab` action expanded: context-sensitive across FALLING/JUMPING (ledge parry), SLIDING (claw brake); CLIMBING excluded from claw brake
- `design/gdd/audio-manager.md` — Level 2 apartment music: single track → 4 mood variants (calm/chaotic/dangerous/other)
- `design/gdd/systems-index.md` — Systems 5 and 7 status → Approved; progress 6/11 → 8/11 MVP

### Added — Infrastructure (Session 006)
- `.claude/hooks/pre-tool-use-mycelium.sh` — runs `context-workflow.sh` before Write/Edit; guards uncommitted files via `git rev-parse --verify`
- `.claude/hooks/post-tool-use-mycelium.sh` — tracks touched file paths to `.mycelium-touched` for departure reminder
- `.claude/settings.json` — PreToolUse `Write|Edit` → mycelium hook; PostToolUse `Write|Edit` → mycelium hook

### GATE Status
- GATE 1: **CONDITIONALLY NEAR-PASS** — 5 ACs passing. Slide rhythm + camera lead remain before final call.

---

## [Pre-Production 0.5] — 2026-04-13

### Fixed — Prototype Bugs
- B01: CLIMBING state had no ground-based entry — added grab-near-Climbable from IDLE/WALK/RUN/SNEAK
- B02: SQUEEZING state was completely unreachable — added CeilingCast RayCast2D auto-trigger
- B03: `parry_window_frames` tuning knob existed but had no effect — temporal window now implemented
- B04: ParryCast circle detected floor geometry as valid parry targets — directional filter added

### Added — Prototype
- Debug HUD (CanvasLayer/RichTextLabel) — shows state, velocity, all timer states, fall distance, proximity flags
- `prototypes/bonnie-traversal/PLAYTEST-001.md` — Session 005 playtest report documenting GATE 1 NEEDS WORK status

### Added — Infrastructure
- Mycelium seeded with 6 live notes: renderer constraint, audio pitch semitone constraint, traversal constraints (no auto-grab, skid multiplier, no death), performance budget constraint, prototype warning (5 known shortcuts), NPC scope warning, NPC↔Social circular dependency constraint

### Changed — Documentation
- `quick-start.md` — removed Unity/Unreal-specific agent references; scoped to Godot/BONNIE!
- `npc-personality.md` — added scope clarification note: Systems 10+11 are Vertical Slice, not MVP
- `input-system.md` — resolved stale cross-ref note (CLIMBING exit was already correct in traversal GDD)
- `NEXT.md` — updated for Session 006 handoff (GATE 1 NEEDS WORK, re-playtest protocol)

### GATE Status
- GATE 1: **NEEDS WORK** — re-playtest required after prototype fixes

---

## [Pre-Production 0.4] — 2026-04-13

### Fixed
- BONNIE invisible — PlaceholderSprite changed from black to warm orange for playtesting
- Wrong renderer — Forward+ (3D) switched to GL Compatibility (2D), eliminating 60+ stale 3D shader caches

### Changed
- `detect-gaps.sh` — cached output, skips expensive scans if design/src/prototypes unchanged
- `session-start.sh` — renderer guard warns if wrong renderer for project type
- `validate-commit.sh` — all 8 GDD sections checked by name, Python absence now surfaces as visible warning

### Added
- Session 002 entries in DEVLOG.md + CHANGELOG.md (were missing)
- `production/session-state/active.md` — live session checkpoint file

### Design Decisions Locked
- GL Compatibility renderer — Forward+ forbidden for this 2D project

---

## [Pre-Production 0.2] — 2026-04-08

### Added
- Viewport Config GDD (`design/gdd/viewport-config.md`) — 720×540, nearest-neighbor, 4:3 locked, integer scaling
- Camera System GDD (`design/gdd/camera-system.md`) — look-ahead, ledge bias, recon zoom, per-state values

### Changed
- GATE 0 cleared — prototype stream unblocked

---

## [Pre-Production 0.1] — 2026-04-05

### Added — BONNIE! Design Sprint 0

**Game Design Documents:**
- `design/gdd/game-concept.md` — Complete game bible: concept, player fantasy, MDA analysis,
  mechanics overview, NPC dialogue/audio spec, mini-games, end-of-level payoff structure,
  game pillars + anti-pillars, inspiration references, player profile, technical considerations,
  full 5-level arc, replayability architecture, risks, MVP definition, scope tiers
- `design/gdd/systems-index.md` — 27-system dependency map with full dependency graph,
  priority tier breakdown (MVP/VS/Alpha/Full Vision), design order, effort estimates,
  high-risk system flags, and progress tracker
- `design/gdd/npc-personality.md` — NPC Personality System GDD (Systems 9+10):
  11-state behavioral machine, NpcState interface (8 fields), Michael+Christen MVP profiles,
  Domino Rally cascade rules, all formulas (emotional decay, goodwill, comfort_receptivity,
  cascade, feeding threshold), 8 edge cases, dependency map, tuning knobs, 8 acceptance criteria
- `design/gdd/bonnie-traversal.md` — BONNIE Traversal System GDD (System 6):
  13-state movement vocabulary, Ledge Parry mechanic, Kaneda slide, double jump (apex-locked),
  wall jump (climbable surfaces only), Nine Lives / no-death physics contract,
  complete formulas, 12 edge cases, tuning knob table, 12 acceptance criteria

**Studio Infrastructure:**
- Mycelium knowledge layer — structured git notes with session hooks (session-start,
  session-stop, pre-compact), mandatory departure protocol, notes push/fetch wired to remote
- Godot 4.6 engine reference — breaking changes (4.4→4.5→4.6), deprecated APIs,
  current best practices, verified sources (engine pinned 2026-02-12)

**Documentation:**
- `DEVLOG.md` — development log, session-by-session record of decisions and progress
- `CHANGELOG.md` — this file

---

## [0.3.0] — 2026-04-04

### Added — Claude Code Game Studios Framework

- `/design-system` skill — guided, section-by-section GDD authoring for a single game system
- `/map-systems` skill — decompose a game concept into individual systems with dependency mapping
- Status line integration — session context breadcrumb (Epic > Feature > Task)
- `UPGRADING.md` — step-by-step migration guide for template updates between versions

---

## [0.2.0] — 2026-04-04

### Added — Claude Code Game Studios Framework

- Context resilience system — `production/session-state/active.md` as living checkpoint,
  incremental file-writing protocol, recovery-after-crash workflow
- `AskUserQuestion` tool integration for structured clarification requests
- `/design-systems` skill (precursor to `/design-system`)
- `.claude/docs/context-management.md` — context budget guidance and compaction instructions

---

## [0.1.0] — 2026-04-04

### Added — Claude Code Game Studios Framework

Initial public release of the Claude Code Game Studios template:

- **48 specialized agents** across design, programming, art, audio, narrative, QA, and production
- **37 slash command skills** (`/start`, `/sprint-plan`, `/prototype`, `/playtest-report`, etc.)
- **8 automated hooks** — commit validation, push validation, asset validation, session
  lifecycle (start/stop), context compaction, agent audit trail, documentation gap detection
- **11 path-scoped coding rules** — standards auto-enforced by file location
- **29 document templates** — GDDs, ADRs, sprint plans, economy models, faction design, etc.
- **Engine specialist agent sets**: Godot 4 (GDScript + Shaders + GDExtension),
  Unity (DOTS/ECS + Shaders + Addressables + UI Toolkit),
  Unreal Engine 5 (GAS + Blueprints + Replication + UMG/CommonUI)
- Studio hierarchy: 3-tier delegation (Directors → Leads → Specialists)
- Collaborative protocol: Question → Options → Decision → Draft → Approval

## [Pre-Production 0.3] — 2026-04-11

### Added
- Input System GDD (`design/gdd/input-system.md`) — 10 actions, buffering rules, analog thresholds
- Audio Manager GDD (`design/gdd/audio-manager.md`) — full event catalogue, bus hierarchy, playback API
- Traversal prototype: `project.godot`, `BonnieController.gd` (full 13-state implementation), `BonnieController.tscn`, `TestLevel.tscn` (10 test zones), `README.md`

### Changed
- `design/gdd/npc-personality.md` — Christen routine fully specified (arrival trigger, phase durations, flee/stress-carry)
- `design/gdd/bonnie-traversal.md` — CLIMBING exit corrected: IDLE → LEDGE_PULLUP
- `design/gdd/systems-index.md` — 6/11 MVP systems approved, Audio Manager linked

### Design Decisions Locked
- AudioStreamRandomizer pitch in semitones (Godot 4.6) — not frequency multipliers
- Ledge parry = frame-exact, no auto-grab, no buffer. Non-negotiable.
- skid_friction_multiplier = 0.15 (not 0.85)
- AudioManager as Autoload (infrastructure exception to singleton rule)

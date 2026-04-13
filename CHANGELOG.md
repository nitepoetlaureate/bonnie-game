# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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

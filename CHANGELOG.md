# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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

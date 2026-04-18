# Systems Index: BONNIE!

> **Status**: Approved
> **Created**: 2026-04-05
> **Last Updated**: 2026-04-15
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

BONNIE! is a sandbox chaos puzzle game built on three interlocking pillars: expressive
physical traversal, deep reactive NPC simulation, and a bidirectional social/chaos meter.
The game needs no combat system, no inventory, no procedural generation — but it does need
an NPC personality system of unusual depth (Maniac Mansion-level), a physics-based movement
system with genuine momentum and clumsiness, and an environmental interaction model where
presence is a mechanic before direct action is.

The 27 systems below span five gameplay layers plus art pipeline infrastructure. The NPC
cluster (Systems 9–11) is the highest-risk and most design-intensive work. The BONNIE
traversal system (System 6) must be prototyped earliest — if it doesn't feel right, nothing
built on top of it will save it. Art pipeline systems (26–27) are infrastructure, not
gameplay, and can be developed in parallel with design work.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Input System | Core | MVP | Approved | design/gdd/input-system.md | — |
| 2 | Viewport / Rendering Config | Core | MVP | Approved | design/gdd/viewport-config.md | — |
| 3 | Audio Manager | Core | MVP | Approved | design/gdd/audio-manager.md | — |
| 4 | Camera System | Core | MVP | Approved | design/gdd/camera-system.md | BONNIE Traversal (6), Viewport Config (2), Input (1) |
| 5 | Level Manager | Core | MVP | Approved | design/gdd/level-manager.md | Viewport Config (2), Audio Manager (3) |
| 6 | BONNIE Traversal System | Gameplay | MVP | Approved | design/gdd/bonnie-traversal.md | Input (1), Viewport (2) |
| 7 | Interactive Object System | Gameplay | MVP | Approved | design/gdd/interactive-object-system.md | Viewport (2), Audio Manager (3), BONNIE Traversal (6) |
| 8 | Environmental Chaos System | Gameplay | Vertical Slice | Not Started | — | Traversal (6), Objects (7) |
| 9 | Reactive NPC System | Gameplay | MVP | Approved | design/gdd/npc-personality.md | Traversal (6), Level Manager (5) |
| 10 | NPC Behavior / Routine System (inferred) | Gameplay | Vertical Slice | Not Started | — | Reactive NPC (9) |
| 11 | NPC Relationship Graph (inferred) | Gameplay | Vertical Slice | Not Started | — | Reactive NPC (9) |
| 12 | Bidirectional Social System | Gameplay | MVP | Approved | design/gdd/bidirectional-social-system.md | Traversal (6), NPC (9) |
| 13 | Chaos Meter | Gameplay | MVP | Approved | design/gdd/chaos-meter.md | Social (12), Chaos (8), Pest (15) |
| 14 | Antagonist / Trap System | Gameplay | Vertical Slice | Not Started | — | NPC (9), Chaos (8), Traversal (6) |
| 15 | Pest / Survival System | Gameplay | Alpha | Not Started | — | Traversal (6), Objects (7) |
| 16 | Nine Lives System (inferred) | Gameplay | Alpha | Not Started | — | Traversal (6), Level Manager (5) |
| 17 | Dialogue System | Narrative | Vertical Slice | Not Started | — | NPC (9), Relationship Graph (11) |
| 18 | Dialogue UI System (inferred) | Narrative | Vertical Slice | Not Started | — | Dialogue (17), Audio Manager (3) |
| 19 | Feeding Cutscene System | Narrative | Full Vision | Not Started | — | Dialogue (17), Chaos Meter (13) |
| 20 | Mini-Game Framework | Gameplay | Alpha | Not Started | — | Input (1), Nine Lives (16) |
| 21 | Notoriety System | Progression | Alpha | Not Started | — | Chaos Meter (13), Level Manager (5) |
| 22 | Save / Load System (inferred) | Persistence | Full Vision | Not Started | — | Notoriety (21), Level Manager (5) |
| 23 | Chaos Meter UI | UI | MVP | Approved | design/gdd/chaos-meter-ui.md | Chaos Meter (13), Viewport Config (2) |
| 24 | HUD / Game UI (inferred) | UI | Full Vision | Not Started | — | Chaos Meter UI (23), Nine Lives (16) |
| 25 | Parallax Background System (inferred) | Rendering | Alpha | Not Started | — | Viewport Config (2), Camera (4) |
| 26 | Aseprite Export Pipeline (inferred) | Art Pipeline | Vertical Slice | Not Started | — | Viewport Config (2) |
| 27 | RetroDiffusion / ComfyUI Pipeline | Art Pipeline | Alpha | Not Started | — | Aseprite Pipeline (26) |

---

## Categories

| Category | Description | Systems |
|----------|-------------|---------|
| **Core** | Infrastructure everything depends on | 1–5 |
| **Gameplay** | The systems that make it fun | 6–16, 20 |
| **Narrative** | Story, dialogue, payoff sequences | 17–19 |
| **Progression** | How the game changes across levels | 21 |
| **Persistence** | Save state and continuity | 22 |
| **UI** | Player-facing information displays | 23–24 |
| **Rendering** | Visual systems beyond core Godot config | 25 |
| **Art Pipeline** | Tooling for asset creation and import | 26–27 |

---

## Priority Tiers

| Tier | Definition | Systems |
|------|------------|---------|
| **MVP** | Core loop playable and testable. Tests: "Is this fun?" | 1, 2, 3, 4, 5, 6, 7, 9, 12, 13, 23 |
| **Vertical Slice** | One complete polished level. Full NPC depth, dialogue, antagonists, Aseprite pipeline. | 8, 10, 11, 14, 17, 18, 26 |
| **Alpha** | All features rough. Pests, mini-games, notoriety, parallax, RetroDiffusion. | 15, 16, 20, 21, 25, 27 |
| **Full Vision** | Polish, cutscenes, save/load, complete HUD. | 19, 22, 24 |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Input System** — Everything that reads player intent. Nothing works without it.
2. **Viewport / Rendering Config** — 720×540 nearest-neighbor pipeline. All rendering depends on this being correct.
3. **Audio Manager** — Music/SFX bus. Required before any audio feedback can be implemented.

### Core Layer (depends on Foundation)

4. **BONNIE Traversal System** — depends on: Input (1), Viewport (2)
5. **Camera System** — depends on: Traversal (6), Viewport (2)
6. **Level Manager** — depends on: Viewport (2)
7. **Interactive Object System** — depends on: Viewport (2)
8. **Parallax Background System** — depends on: Viewport (2), Camera (4)

### Gameplay Layer (depends on Core)

9. **Environmental Chaos System** — depends on: Traversal (6), Objects (7)
10. **Reactive NPC System** — depends on: Traversal (6), Level Manager (5)
11. **NPC Behavior / Routine System** — depends on: Reactive NPC (9)
12. **NPC Relationship Graph** — depends on: Reactive NPC (9)
12. **Bidirectional Social System** — depends on: Traversal (6), NPC (9) *[see circular dep note]*
13. **Chaos Meter** — depends on: Social (12), NPC (9), Chaos (8), Pest (15)
15. **Pest / Survival System** — depends on: Traversal (6), Objects (7)
16. **Nine Lives System** — depends on: Traversal (6), Level Manager (5)
17. **Antagonist / Trap System** — depends on: NPC (9), Chaos (8), Traversal (6)

### Feature Layer (depends on Gameplay)

18. **Dialogue System** — depends on: NPC (9), Relationship Graph (11)
19. **Mini-Game Framework** — depends on: Input (1), Nine Lives (16)
20. **Notoriety System** — depends on: Chaos Meter (13), Level Manager (5)

### Presentation Layer (depends on Features)

23. **Chaos Meter UI** — depends on: Chaos Meter (13), Viewport Config (2)
18. **Dialogue UI System** — depends on: Dialogue (17), Audio Manager (3)
19. **Feeding Cutscene System** — depends on: Dialogue (17), Chaos Meter (13)
24. **HUD / Game UI** — depends on: Chaos Meter UI (23), Nine Lives (16)
22. **Save / Load System** — depends on: Notoriety (21), Level Manager (5)

### Art Pipeline Layer (depends on Foundation — parallel track)

26. **Aseprite Export Pipeline** — depends on: Viewport Config (2) [pixel format, filter settings]
27. **RetroDiffusion / ComfyUI Pipeline** — depends on: Aseprite Pipeline (26)

---

## Circular Dependencies

**Bidirectional Social System (13) ↔ Reactive NPC System (9)**

The Social System produces social inputs that change NPC state. The NPC System
produces reactions that change what social options are available to BONNIE.

*Resolution*: Define a shared **NpcState** data object that both systems read and
write. Social System reads NpcState to determine available interactions. NPC System
reads Social inputs and updates NpcState. Neither system calls the other directly.
Design both systems simultaneously; define the NpcState interface first.

No other circular dependencies found.

---

## High-Risk Systems

| System | Risk Type | Description | Mitigation |
|--------|-----------|-------------|------------|
| BONNIE Traversal (6) | Technical | Physics feel is make-or-break. Momentum, clumsiness, and the "it feels like a cat" quality cannot be designed in a GDD — they must be felt. | **Prototype first**, before any other system is built on top of it. Use `/prototype bonnie-traversal`. |
| Reactive NPC System (9) | Design + Scope | Most complex system in the game. Personality profiles, routines, cascade logic, relationship-aware reactions. Risk of ballooning scope. | Design the minimum NPC model that produces Polterguy-level fun, then add depth. Use `/design-system` with strict scope checkpoints. |
| Bidirectional Social System (12) | Design | Novel mechanic. Players must understand that charming NPCs fills the chaos meter too — if the feedback isn't clear, the bidirectional nature is invisible. | Design the feedback system explicitly. Playtest early: can players discover the social axis without being told? |
| Chaos Meter (13) | Design | Balance-sensitive. Too easy = no satisfaction. Too hard = directionless frustration. The tuning knobs won't be knowable until playtesting. | Design the formula with wide tuning ranges. Prototype with exaggerated values first. `/balance-check` after first playtest. |
| RetroDiffusion/ComfyUI (27) | Technical | CPU-only generation speed is unknown. HF Space + Tailscale setup has tooling unknowns. | Treat as infrastructure; don't block art work on it. Build Aseprite CLI pipeline (26) first; add RetroDiffusion when it's working locally. |

---

## Recommended Design Order

Design in dependency order within each priority tier. Independent systems at the
same layer can be designed in parallel. Prototype high-risk systems immediately
after their GDD is written — don't wait until Alpha.

| Order | System | Priority | Layer | Lead Agent | Est. Effort |
|-------|--------|----------|-------|------------|-------------|
| 1 | Reactive NPC System (9) | MVP | Gameplay | game-designer + ai-programmer | L |
| 2 | BONNIE Traversal System (6) | MVP | Core | gameplay-programmer | M |
| — | **→ PROTOTYPE traversal after #2** | — | — | godot-specialist | M |
| 3 | Bidirectional Social System (12) | MVP | Gameplay | game-designer | M |
| 4 | NPC Behavior / Routine System (10) | VS | Gameplay | game-designer + ai-programmer | M |
| 5 | NPC Relationship Graph (11) | VS | Gameplay | game-designer | S |
| 6 | Interactive Object System (7) | MVP | Core | gameplay-programmer | M |
| 7 | Environmental Chaos System (8) | VS | Gameplay | game-designer | M |
| 8 | Chaos Meter (13) | MVP | Gameplay | game-designer + economy-designer | M |
| 9 | Antagonist / Trap System (14) | VS | Gameplay | game-designer | M |
| 10 | Input System (1) | MVP | Foundation | godot-specialist | S |
| 11 | Viewport / Rendering Config (2) | MVP | Foundation | godot-specialist | S |
| 12 | Audio Manager (3) | MVP | Foundation | audio-director | S |
| 13 | Dialogue System (17) | VS | Narrative | game-designer + writer | M |
| 14 | Dialogue UI System (18) | VS | Narrative | ui-programmer | S |
| 15 | Chaos Meter UI (23) | MVP | UI | ui-programmer | S |
| 16 | Aseprite Export Pipeline (26) | VS | Art Pipeline | tools-programmer | S |
| 17 | Pest / Survival System (15) | Alpha | Gameplay | gameplay-programmer | S |
| 18 | Nine Lives System (16) | Alpha | Gameplay | gameplay-programmer | S |
| 19 | Mini-Game Framework (20) | Alpha | Gameplay | game-designer | M |
| 20 | Notoriety System (21) | Alpha | Progression | game-designer | S |
| 21 | Parallax Background System (25) | Alpha | Rendering | godot-shader-specialist | S |
| 22 | RetroDiffusion / ComfyUI Pipeline (27) | Alpha | Art Pipeline | tools-programmer | L |
| 23 | Camera System (4) | MVP | Core | gameplay-programmer | S |
| 24 | Level Manager (5) | MVP | Core | gameplay-programmer | S |
| 25 | Feeding Cutscene System (19) | Full Vision | Narrative | gameplay-programmer + writer | L |
| 26 | HUD / Game UI (24) | Full Vision | UI | ui-programmer | S |
| 27 | Save / Load System (22) | Full Vision | Persistence | gameplay-programmer | M |

*Effort: S = 1 session, M = 2–3 sessions, L = 4+ sessions*

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 27 |
| Design docs started | 11 |
| Design docs reviewed | 11 |
| Design docs approved | 11 |
| MVP systems designed | 11 / 11 |
| Vertical Slice systems designed | 0 / 7 |
| Alpha systems designed | 0 / 6 |
| Full Vision systems designed | 0 / 3 |

---

## Next Steps

- [ ] Run `/design-system npc-personality` — System 9, highest priority, highest risk
- [ ] Run `/design-system bonnie-traversal` — System 6, must be prototyped immediately after
- [ ] Run `/prototype bonnie-traversal` — validate physics feel before building on top of it
- [ ] Run `/design-review design/gdd/systems-index.md` to validate this document
- [ ] Run `/gate-check pre-production` when all MVP system GDDs are approved

# Sprint 02 — NPC, Social, Chaos

**Status**: NOT STARTED  
**Starts**: Session 011  
**Milestone**: First Social Loop — full chaos loop observable end-to-end

---

## Sprint Goal

Full chaos loop end-to-end: BONNIE does something loud → NPC notices → reacts → chain reactions propagate → Chaos Meter UI updates. All running in the graybox apartment.

---

## Scope

Four systems shipping this sprint:

| System | # | GDD | Depends On |
|--------|---|-----|------------|
| NPC System | 9 | `design/gdd/npc-personality.md` | NpcState (design first), BonnieController stimulus API |
| Bidirectional Social System | 12 | `design/gdd/bidirectional-social-system.md` | NpcState, NPC System |
| Chaos Meter | 13 | `design/gdd/chaos-meter.md` | Social System, LevelManager BFS |
| Chaos Meter UI | 23 | `design/gdd/chaos-meter-ui.md` | Chaos Meter, ViewportGuard |
| Interactive Object System | 7 | `design/gdd/interactive-object-system.md` | BonnieController, AudioManager |

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Depends On | Acceptance Criteria | Status |
|----|------|-------|-----------|---------------------|--------|
| S2-001 | Design NpcState shared data object | game-designer | — | NpcState class defined with all fields NPC + Social systems read/write. Neither system imports the other. | Not Started |
| S2-006 | Clarify NPC GDD scope: System 9 vs 10/11 | game-designer | — | Mycelium warning `blob:d696782575c9` resolved. Clear list of which behaviors are MVP (System 9) vs deferred (10/11). | Not Started |
| S2-002 | Implement NPC System (#9) | gameplay-programmer + ai-programmer | S2-001, S2-006 | NPC detects BONNIE via `get_stimulus_radius()`. NpcState transitions on stimulus. GUT tests cover detection + state changes. | Not Started |
| S2-003 | Implement Bidirectional Social System (#12) | gameplay-programmer | S2-001, S2-002 | NPC reacts visibly to BONNIE. Tolerance system works. Feeding interaction works. GUT tests pass. | Not Started |
| S2-004 | Implement Chaos Meter logic (#13) | gameplay-programmer + economy-designer | S2-003, LevelManager BFS | `chaos_level` increases on NPC reactions. Cascade attenuation via room adjacency. GUT tests cover formula + cascade. | Not Started |
| S2-005 | Implement Chaos Meter UI (#23) | ui-programmer | S2-004 | HUD meter visible in 720×540 viewport. Meter updates in real time. No hardcoded pixel positions. GUT tests cover display states. | Not Started |

### Should Have

| ID | Task | Owner | Depends On | Acceptance Criteria | Status |
|----|------|-------|-----------|---------------------|--------|
| S2-007 | Interactive Object System (#7) | gameplay-programmer | BonnieController | Knockable objects respond to BONNIE collision. Feedable objects trigger social interaction. Hideable spots work. GUT tests pass. | Not Started |
| S2-008 | Sprite integration (AnimatedSprite2D) | gameplay-programmer | Aseprite pipeline | `PlaceholderSprite` (ColorRect) replaced with `AnimatedSprite2D`. Idle/walk/run animations wired to `state_changed`. Sprite flips on `facing_direction`. | Not Started |
| S2-009 | LevelManager: BFS adjacency graph | gameplay-programmer | Room.adjacent_rooms | `_bfs_graph` computed from Room adjacency arrays. `get_cascade_attenuation()` returns correct tier values. GUT tests pass. | Not Started |
| S2-010 | LevelManager: NPC registry | gameplay-programmer | S2-002 | `register_npc()` / `unregister_npc()`. `get_npcs_in_room()` returns correct set. NPC unregisters on `_exit_tree()`. | Not Started |

### Nice to Have (Cut First)

| ID | Task | Owner | Depends On | Acceptance Criteria | Status |
|----|------|-------|-----------|---------------------|--------|
| S2-011 | AudioManager: polyphony enforcement | gameplay-programmer | — | Voice-stealing per category. Polyphony limits enforced. Sprint 1 deferred. | Not Started |
| S2-012 | AudioManager: AudioStreamRandomizer pitch variation | gameplay-programmer | Godot 4.6 API verification | Pitch varies by ±1–2 semitones on footsteps. Godot 4.6 property name verified before implementing. | Not Started |
| S2-013 | AudioManager: user config save/load (AC-A06) | gameplay-programmer | — | Volume settings persist across launches via `ConfigFile`. | Not Started |
| S2-014 | Ledge bias caller (BonnieCamera) | gameplay-programmer | BonnieController | `set_ledge_bias()` called when BONNIE is near a ledge. Design decision: who calls it. | Not Started |

---

## Critical Dependencies

### NpcState Design Blocks Everything
NpcState is a shared data object that breaks the circular dependency between NPC System (#9) and Social System (#12). **Neither system can be implemented until NpcState is designed.**

```
NpcState (Resource or class)
  Fields owned by NPC System:   perception_state, tolerance, current_stimulus
  Fields owned by Social System: reaction_history, fed_recently, interaction_queue
  
NPC System reads/writes → NpcState
Social System reads/writes → NpcState
NPC System NEVER imports Social System
Social System NEVER imports NPC System
```

See Mycelium constraint: `tree:466bd80f49a7`, `tree:525c5eb3694e`, `tree:78799b241ef8`

### NPC GDD Scope Ambiguity
The NPC GDD (`design/gdd/npc-personality.md`) header says "System #9+10" but systems-index.md lists Systems 10+11 as Vertical Slice scope (not MVP). S2-006 must clarify which behaviors are System 9 MVP before any implementation begins.

See Mycelium warning: `blob:d696782575c9`

### BFS Graph Required for Chaos Cascade
`LevelManager.get_cascade_attenuation()` and the Chaos Meter's cascade formula both need the room adjacency BFS graph. S2-009 (LevelManager BFS) must complete before S2-004 (Chaos Meter logic) if cascade is in scope for Sprint 2.

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| NpcState design is larger than expected — many edge cases in NPC/Social interaction | Medium | High | Design NpcState first as a standalone document before writing any code. Both GDDs reviewed together. |
| NPC GDD conflates Systems 9/10/11 — scope creep during implementation | High | Medium | S2-006 must produce a clear MVP/deferred split before S2-002 starts. |
| `AudioStreamRandomizer` pitch property name differs in Godot 4.6 | High | Low | Check `docs/engine-reference/godot/breaking-changes.md` before implementing S2-012. Mycelium constraint `blob:2c5668f4080f`. |
| Chaos Meter formula produces un-fun values before tuning | Medium | Medium | Export all chaos knobs (charm_subtotal weights, cascade multipliers). Run `/balance-check` before GATE 4. |
| Interactive Objects (#7) scope is large — knockables + feedables + hideables | Medium | Medium | Scope to MVP interactions only: 1 knockable, 1 feedable, 1 hideable. Expand post-Sprint 2. |

---

## Definition of Done

- [ ] Full chaos loop observable: BONNIE runs → NPC notices → reacts → Chaos Meter ticks
- [ ] All Must Have tasks completed and passing acceptance criteria
- [ ] GUT tests written for all new systems — no system ships without tests
- [ ] NpcState circular dependency respected — NPC and Social never import each other
- [ ] No hardcoded gameplay values — all tuning knobs exported for inspector
- [ ] Architecture decision records updated for any new systems
- [ ] GATE 4 checklist passes

---

## Carryover from Sprint 1

| Item | Type | Handling |
|------|------|---------|
| Sprite integration (AnimatedSprite2D) | S2-008 Should Have | Wire in early — needed for visual feedback of NPC reactions |
| 4 prototype shortcuts in BonnieController | Fix before v1.0 | Not Sprint 2 scope — tracked in tech debt |
| Music file for `level_02_calm` | Audio stub | Register in AudioManager when audio asset is created |

---

## Session Start Protocol (Session 011)

Before writing any code:
1. `mycelium.sh find constraint` — read all constraints (especially NpcState circular dep)
2. `mycelium.sh find warning` — read all warnings (especially NPC GDD scope)
3. Read `design/gdd/npc-personality.md` + `design/gdd/bidirectional-social-system.md` together
4. Design NpcState object (S2-001) — get approval before implementation
5. Resolve S2-006 NPC scope question — document the MVP/deferred split

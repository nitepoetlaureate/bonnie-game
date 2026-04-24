# ADR-006: LevelManager — Level Context, Room Registry, and Transition System

## Status
Accepted

## Date
2026-04-22

## Context

### Problem Statement
BONNIE's apartment is not one connected space — it is a graph of named rooms, each with a spatial extent, neighboring rooms, and audio/visual identity. Something needs to own the runtime context for a level session: which rooms exist, where BONNIE is, how the camera bounds update when she crosses a threshold, what music plays. The question is: where does room topology live, who discovers it, and how does room-crossing behavior scale from Sprint 1's 2-room graybox to the GDD's full 7-room apartment with NPC cascade attenuation?

### Constraints
- Sprint 1 ships with exactly 2 rooms (living room + kitchen) in a single scene
- NPC registration and BFS cascade attenuation are Sprint 2+ features — the architecture must accommodate them without Sprint 1 implementing them
- Room topology must be determined by scene structure, not hardcoded data — a designer adding a new room means adding a child `Room` node, not editing a registry
- LevelManager is the root of the level scene, not a global autoload — each level owns its own context
- Rooms have logical spatial bounds (`Rect2`), not physics collision bounds — the bounds are for camera clamping and position queries, not collision

### Requirements
- Register all `Room` child nodes at `_ready()` automatically
- Spatial query: given a world-space position, which room contains it?
- Emit `room_entered` signal when BONNIE crosses into a new room
- Provide level bounds (union of all rooms) for full-level camera queries
- Provide per-room bounds for BonnieCamera room-clamping
- Play level music stub (graceful if audio file missing)
- GDD: BFS cascade attenuation for NPC awareness propagation (Sprint 2)
- GDD: NPC registry for chaos meter and social system queries (Sprint 2)

## Decision

**LevelManager is a `Node`-extending scene root that auto-discovers `Room` children, maintains a room registry, provides spatial queries for camera and position lookups, and emits transition signals for downstream consumers. It documents both what is built (Sprint 1: 2 rooms, no BFS, no NPC registry) and what is designed (full GDD: 7 rooms, BFS attenuation, NPC cascade).**

### Four Architectural Sub-Decisions

**1. Child-discovery pattern — levels own their own topology.**

LevelManager discovers rooms by iterating its own children and filtering for `Room` type nodes:

```gdscript
func _register_rooms() -> void:
    for child: Node in get_children():
        if child is Room:
            var room: Room = child as Room
            if room.room_id != &"":
                _room_registry[room.room_id] = room
```

This is intentional: the level scene owns its room graph. Adding a new room means adding a `Room` child node in the editor. No external registration step, no data file to update, no separate room list to maintain. The scene IS the topology.

The alternative — LevelManager reading room definitions from a JSON or Resource file — was rejected because it creates a split between scene structure (what you see in the editor) and runtime topology (what the game uses). When the scene IS the source of truth, there is nothing to get out of sync.

**2. LevelManager as scene root — each level owns its context.**

LevelManager extends `Node`, not a globally registered autoload. It is the root of `level_02_apartment.tscn`:

```
LevelManager (root)
├── LivingRoom (Room)
├── Kitchen (Room)
├── BonnieController (scene instance)
└── BonnieCamera (scene instance)
```

This means:
- Level-specific state (room registry, current room, BFS graph) lives in the level scene, not globally
- Loading a different level means instantiating a different LevelManager — no global state to clean up
- BonnieController and BonnieCamera are children of the level, not global nodes — they are destroyed and recreated with the level
- Multiple levels can exist in the scene tree simultaneously (for future streaming or transition effects) without state conflicts

The cost: BonnieController and BonnieCamera cannot be persistent autoloads. This is acceptable — BONNIE's physical state resets at level load, which is the correct behavior.

**3. This ADR documents Sprint 1 (built) and GDD design (Sprint 2+).**

Sprint 1 implementation is fully functional but minimal:
- 2 rooms, hard-coded in the scene
- No NPC registry
- No BFS cascade attenuation
- Music stub only (no audio file exists for `&"level_02_calm"`)

The full GDD design (7-room apartment, BFS cascade, NPC awareness propagation) is documented here as the Sprint 2+ migration path. The architecture is designed to accommodate this growth: the room registry is already a dictionary keyed by `StringName`, BFS traversal can be added to `_register_rooms()` without changing the API, and NPC registration is an additive `register_npc()` method.

**4. Spatial query model — position-in-bounds, not physics overlap.**

Room membership is determined by `Rect2.has_point()` on the room's exported `bounds`:

```gdscript
func get_room_for_position(pos: Vector2) -> StringName:
    for room_id: StringName in _room_registry:
        var room: Room = _room_registry[room_id]
        if room.bounds.has_point(pos):
            return room_id
    return &""
```

No physics queries, no `Area2D` overlap detection. This is deliberate:
- Room membership is a logical concept (which room context applies), not a physics concept (what is touching what)
- Physics Area2D for room detection would require exit/enter event handling, race conditions at room boundaries, and physics queries every frame
- `Rect2.has_point()` is O(n_rooms) per call — negligible for ≤10 rooms
- Room bounds are designer-authored logical regions that can overlap slightly at doorways without creating physics artifacts

### Architecture Diagram

```
level_02_apartment.tscn:
┌─────────────────────────────────────────────────────────────────────┐
│  LevelManager (Node — scene root)                                    │
│                                                                      │
│  _ready():                                                           │
│    _register_rooms()     → child-discovery, populates _room_registry│
│    _compute_level_bounds()→ union of all room bounds                 │
│    _find_bonnie()         → initial room for BONNIE                  │
│    AudioManager.play_music(&"level_02_calm")  → music stub           │
│    level_ready.emit()                                                │
│                                                                      │
│  Public API:                                                         │
│    get_room_for_position(pos) → StringName                           │
│    get_level_bounds()         → Rect2                                │
│    get_room_bounds(room_id)   → Rect2                                │
│    update_bonnie_room(pos)    → emits room_entered on change         │
│    get_current_room()         → StringName                           │
│                                                                      │
│  Signals:                                                            │
│    level_ready                                                       │
│    room_entered(room_id: StringName)                                 │
│                                                                      │
│  Sprint 1 registry:                                                  │
│    { &"living_room": Room(bounds=Rect2(0,0,1200,540)),               │
│      &"kitchen":    Room(bounds=Rect2(1200,0,1000,540)) }            │
│                                                                      │
│  Sprint 2+ additions (GDD):                                          │
│    _npc_registry: Dictionary[StringName, NpcState]                  │
│    register_npc(npc_id, npc_state) / unregister_npc(npc_id)         │
│    get_npcs_in_room(room_id) → Array[NpcState]                       │
│    _bfs_graph: room adjacency for cascade attenuation                │
│    get_cascade_attenuation(source, target) → float                  │
│      tier 0 = 1.0, tier 1 = 0.5, tier 2 = 0.2, tier 3+ = 0.0       │
│                                                                      │
│  Children:                                                           │
├── LivingRoom (Room) ── bounds: Rect2(0, 0, 1200, 540)               │
│   ├── Floor (StaticBody2D)                                           │
│   ├── LeftWall (StaticBody2D)                                        │
│   ├── Ceiling (StaticBody2D)                                         │
│   ├── Shelf (StaticBody2D, group "Climbable")                        │
│   └── DoorwayTrigger (Area2D)                                        │
├── Kitchen (Room) ── bounds: Rect2(1200, 0, 1000, 540)               │
│   ├── Floor (StaticBody2D)                                           │
│   ├── RightWall (StaticBody2D)                                       │
│   ├── Ceiling (StaticBody2D)                                         │
│   ├── SqueezeGap (collision + SqueezeTrigger Area2D)                 │
│   └── HighCabinet (StaticBody2D)                                     │
├── BonnieController (scene instance)                                  │
└── BonnieCamera (scene instance)                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# -- Signals --
signal level_ready
    # Emitted after all rooms registered and initial room set.

signal room_entered(room_id: StringName)
    # Emitted when BONNIE crosses into a new room.
    # Consumers: BonnieCamera (set_room_bounds), AudioManager (music transition, Sprint 2)

# -- Spatial Queries --
func get_room_for_position(pos: Vector2) -> StringName
    # Returns room_id for the room containing pos, or &"" if outside all rooms.

func get_level_bounds() -> Rect2
    # Returns union of all room bounds. Used by camera for full-level queries.

func get_room_bounds(room_id: StringName) -> Rect2
    # Returns bounds for a specific room. Used by BonnieCamera.set_room_bounds().

func get_current_room() -> StringName
    # Returns the room BONNIE is currently in.

# -- Room Tracking --
func update_bonnie_room(pos: Vector2) -> void
    # Call each frame with BONNIE's position. Emits room_entered if room changed.

# -- Sprint 2+ (planned additions, not yet implemented) --
# func register_npc(npc_id: StringName, npc_state: NpcState) -> void
# func unregister_npc(npc_id: StringName) -> void
# func get_npcs_in_room(room_id: StringName) -> Array[NpcState]
# func get_cascade_attenuation(source_room: StringName, target_room: StringName) -> float
```

## Alternatives Considered

### Alternative 1: LevelManager as global autoload
- **Description**: Register LevelManager as a project-wide autoload that persists across scene loads.
- **Pros**: Any system can access room data via `LevelManager.get_room_for_position()` without a scene reference. Persists between level transitions.
- **Cons**: Level-specific data (room registry, NPC locations) becomes global state that must be explicitly cleared on level load. Two levels cannot coexist in the scene tree (future streaming). BonnieController and BonnieCamera would need to be separate autoloads or found via group queries. The autoload's correct state depends on which level is currently loaded — a hidden assumption.
- **Rejection Reason**: Level state belongs to the level, not the project. Each level instance manages its own context. Global state for level-specific data creates hidden dependencies on load order and level identity.

### Alternative 2: Room definitions in a JSON or Resource file
- **Description**: Store room topology (bounds, adjacency, NPC spawn points) in a `.json` or `.tres` Resource file. LevelManager loads and parses this file at `_ready()`.
- **Pros**: Rooms are data, not code. The topology file could be generated by an external tool.
- **Cons**: Creates split between the scene (what you see in the editor) and the data file (what the game uses). When a designer adds a room, they edit two places. The scene itself already contains all the information needed — nodes have positions and bounds. Making Room nodes the authoritative source (child-discovery) keeps the scene as the single source of truth.
- **Rejection Reason**: The Godot scene IS the data format. Room nodes in the scene tree are the most editor-friendly way to express room topology — they can be positioned visually, and their bounds are visible in the editor.

### Alternative 3: Physics Area2D for room detection
- **Description**: Each `Room` has a `CollisionShape2D` defining its bounds. BONNIE's body enters/exits this Area2D, firing `body_entered`/`body_exited` signals that LevelManager connects to.
- **Pros**: Godot handles spatial membership — no custom `has_point()` logic. Multiple rooms can be entered simultaneously.
- **Cons**: Physics Area2D room membership adds physics engine overhead for a spatial query that is 4 comparisons (`Rect2.has_point()`). Exit/enter events are asynchronous with the frame loop — there can be a one-frame gap between position and room update. At doorways (thin boundaries), rapid crossing can fire multiple enter/exit events per frame.
- **Rejection Reason**: Room membership is a logical spatial concept. `Rect2.has_point()` called once per frame on ≤10 rooms is simpler, cheaper, and more predictable than Area2D event-driven detection.

### Alternative 4: Room graph as an explicit data structure at project level
- **Description**: Define the full room graph (adjacency, BFS depth) as a project-level Resource loaded by an autoload, so NPC and Social systems can query it without a reference to the level's LevelManager.
- **Pros**: NPC systems and Social systems can query room topology without knowing which level is loaded.
- **Cons**: Introduces project-level coupling to level-specific data. Room graphs differ between levels — the 7-room apartment graph should not be loaded when running a tutorial level with 2 rooms.
- **Rejection Reason**: Room graph data is level-specific. The NPC and Social systems receive their room context via `room_entered` signals and NPC state — they don't need to know the full graph. BFS cascade queries are mediated through LevelManager's API, not a global graph resource.

## Consequences

### Positive
- Adding a new room is a single scene edit — add a `Room` child node with bounds. No code changes, no data files.
- Level-specific state is contained in the level scene — loading a new level creates a fresh LevelManager with a clean registry
- `room_entered` signal is the single integration point for all room-aware systems: camera bounds, music transitions, NPC cascade
- Sprint 2 additions (NPC registry, BFS attenuation) are additive — no existing API changes
- `update_bonnie_room()` called from game loop with BONNIE's position — simple, no async complexity

### Negative
- `update_bonnie_room()` is called externally (the game loop must call it each frame). In Sprint 1, no caller is implemented — room transitions are only detected when something explicitly calls this. Future: consider connecting to BonnieController's position update or using a physics callback.
- Sprint 1 music stub (`AudioManager.play_music(&"level_02_calm")`) logs a warning every level load because the audio file doesn't exist. This is by design (registry+stub pattern), but generates console noise.
- LevelManager accesses AudioManager via string path (`has_node("/root/AudioManager")`) rather than typed reference — this is a Sprint 1 pragmatism, not the long-term pattern.

### Risks
- **Risk**: Two rooms have overlapping bounds — `get_room_for_position()` returns the first match in dict iteration order.
  **Mitigation**: Rooms in `level_02_apartment.tscn` have non-overlapping bounds by design (LivingRoom: 0–1200, Kitchen: 1200–2200). The doorway at x=1200 belongs to whichever room the iteration finds first — acceptable for a single pixel boundary. If rooms ever need true overlap, the query logic must be updated.
- **Risk**: Sprint 2 NPC registry grows stale — NPCs added but not removed on death/despawn.
  **Mitigation**: `register_npc`/`unregister_npc` are paired. NPC `_exit_tree()` must call `unregister_npc()`. Document this contract in the Sprint 2 implementation.
- **Risk**: BFS attenuation graph not computed until Sprint 2 — any Sprint 1 code that tries to call `get_cascade_attenuation()` will crash.
  **Mitigation**: Sprint 1 has no NPC cascade callers. The method doesn't exist in Sprint 1 — no crash possible. Sprint 2 adds it additively.

## Performance Implications
- **CPU**: `_ready()` iterates children once (O(n_children)) and calls `Rect2.merge()` once per room (O(n_rooms)). Per-frame: `update_bonnie_room()` iterates `_room_registry` (O(n_rooms) `Rect2.has_point()` — 4 comparisons × 2–10 rooms = 8–40 comparisons per call). Negligible.
- **Memory**: Dictionary with ≤10 room entries. One `Rect2` for level bounds. Negligible.
- **Load Time**: Child iteration + bounds union at `_ready()`. Sub-millisecond for ≤20 children.
- **Network**: N/A.

## Migration Plan
No migration needed — LevelManager was built as a production system in Session 009 (Sprint 1). This ADR documents the existing implementation.

Sprint 2 migration tasks (additive, no breaking changes):
1. Add `register_npc(npc_id, npc_state)` and `unregister_npc(npc_id)` when NPC system (System #9) is implemented
2. Compute BFS adjacency graph from `Room.adjacent_rooms` arrays in `_register_rooms()` — add `_bfs_graph: Dictionary`
3. Add `get_cascade_attenuation(source, target) → float` for chaos cascade
4. Ensure `update_bonnie_room()` is called from the appropriate game loop caller (BonnieController `_physics_process`, a dedicated game loop node, or a connected signal)
5. Replace AudioManager `has_node()` check with typed reference once the autoload integration pattern stabilizes

## Validation Criteria
- [ ] All existing GUT tests pass (`tests/unit/test_level_manager.gd`)
- [ ] `_room_registry` populated with 2 rooms after `_ready()` in `level_02_apartment.tscn`
- [ ] `get_room_for_position(Vector2(600, 270))` returns `&"living_room"` (center of LivingRoom)
- [ ] `get_room_for_position(Vector2(1700, 270))` returns `&"kitchen"` (center of Kitchen)
- [ ] `get_room_for_position(Vector2(9999, 270))` returns `&""` (outside all rooms)
- [ ] `update_bonnie_room(kitchen_pos)` emits `room_entered(&"kitchen")` when called after living room position
- [ ] `room_entered` fires only once per room change (not every frame while in same room)
- [ ] `get_level_bounds()` returns union: `Rect2(0, 0, 2200, 540)`
- [ ] `level_ready` signal emits in `_ready()` (AC-L01)
- [ ] Console: "LevelManager: 2 rooms registered, bounds=..." on level load

## Related Decisions
- **GDD**: `design/gdd/level-manager.md` — full design specification including BFS cascade attenuation formula
- **ADR-007 Room System**: Room (Node2D) structure discovered by LevelManager
- **ADR-005 BonnieCamera**: Connects to `room_entered` to call `set_room_bounds()`
- **ADR-003 AudioManager**: Receives music transition calls from LevelManager on `room_entered` (Sprint 2)
- **NPC System (System #9)**: Will register with LevelManager and query room topology (Sprint 2)
- **Social System (System #12)**: Consumes cascade attenuation for NPC reaction propagation (Sprint 2)
- **BFS cascade formula** (GDD §5.2): `attenuation(tier) = [1.0, 0.5, 0.2, 0.0][tier]`

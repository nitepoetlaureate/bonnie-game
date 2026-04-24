# ADR-007: Room System — Room Node and RoomData Resource Architecture

## Status
Accepted

## Date
2026-04-22

## Context

### Problem Statement
Rooms are the atomic units of BONNIE's level architecture. They have spatial extent (camera bounds, NPC awareness zones), topological relationships (adjacency for chaos cascade), and visual identity (geometry, props, lighting). Two distinct patterns are needed: rooms that exist in the scene tree as placed Node2D objects (the scene editor is the authoring tool), and rooms that exist as data (for future streaming, procedural generation, or save/load of room state). The question is: should these be one type or two, and what is the minimal interface each needs to expose for LevelManager, BonnieCamera, and the NPC system to work correctly?

### Constraints
- Sprint 1: 2 rooms in a single scene, manually placed, manually bounded
- Bounds are logical spatial regions (camera and position queries), NOT collision geometry
- Adjacent room list is manually authored by the designer — no automatic adjacency computation from geometry
- `Room` must be discoverable by LevelManager's child-iteration pattern (`child is Room`)
- RoomData is a future-use Resource — not instantiated in Sprint 1

### Requirements
- `Room` (Node2D): scene-placed rooms with exportable bounds and adjacency
- `RoomData` (Resource): data-only mirror of Room for streaming/procedural use (Sprint 2+)
- `room_id: StringName` — unique identifier for registry keying and signal payloads
- `bounds: Rect2` — explicit designer-authored bounding box for camera clamping and spatial queries
- `adjacent_rooms: Array[StringName]` — explicitly listed neighbors for BFS traversal
- Both types expose the same logical fields — a future migration from Node-based to data-driven is possible without API changes

## Decision

**The Room System consists of two types that coexist: `Room` (extends `Node2D`) for scene-placed rooms authored in the Godot editor, and `RoomData` (extends `Resource`) for future data-driven and streaming use cases. Both expose identical logical fields. Sprint 1 uses only `Room`.**

### Three Architectural Sub-Decisions

**1. Two types that coexist — different use cases, same logical interface.**

`Room` and `RoomData` are not alternatives; they serve different contexts:

**`Room` (Node2D)** — the authoring primitive:
- Lives in the scene tree as a child of LevelManager
- Visible in the Godot editor with all other scene nodes
- Discoverable by LevelManager's `child is Room` iteration
- Contains child nodes (collision shapes, triggers, props)
- Cannot be serialized independently of the scene

**`RoomData` (Resource)** — the data primitive:
- A `.tres` Resource that can be serialized, loaded, and streamed
- No scene hierarchy — pure data
- Used when rooms need to be loaded from disk without instantiating a full scene
- Sprint 2+ use cases: procedural apartment generation, streaming large levels, save/load of room state

The fields are identical: `room_id`, `bounds`, `adjacent_rooms`. A system that needs to query room bounds can accept either type if it checks both, or can use `RoomData` exclusively if all rooms are data-driven. In Sprint 1, LevelManager only uses `Room`.

**2. Manual `bounds: Rect2` export — logical regions, not collision geometry.**

Room bounds are designer-authored `Rect2` values, not computed from collision shapes:

```gdscript
# Room (Node2D)
@export var bounds: Rect2
```

The bounds define the camera clamping region and the spatial extent for NPC awareness — "which room is BONNIE in?" Camera limits are set from bounds (`Camera2D.limit_left/right/top/bottom`). NPC perception is range-checked against bounds for cascade attenuation tier determination.

This is not the same as collision geometry. A room's collision floor may not extend to the exact bounds edge. A doorway may be passable geometry but is still "inside" the room's logical bounds until BONNIE crosses the threshold x-coordinate.

Manual authoring is correct here because:
- Logical bounds represent designer intent, not physics truth
- Bounds may extend slightly beyond visible geometry (to avoid camera pop at exact boundaries)
- Computing bounds from collision shape extents would require complex AABB union code and would incorrectly include ceiling/wall geometry as room extent

**3. Manual `adjacent_rooms: Array[StringName]` — designer controls the graph.**

Room adjacency is explicitly listed:

```gdscript
@export var adjacent_rooms: Array[StringName]
# Example: [&"kitchen"] for the living room
```

LevelManager's BFS cascade uses this array to determine which rooms are tier-1, tier-2, tier-3 neighbors for NPC chaos propagation.

This is a Sprint 1 simplification that is also the correct long-term pattern for authored levels:
- The designer decides which rooms are "adjacent" for gameplay purposes — topology is a design decision, not a geometry computation
- Two rooms can share a wall but NOT be adjacent for cascade purposes (a locked room, a room separated by a thick wall with no acoustic path)
- The adjacency graph is sparse and small (≤10 rooms in the apartment) — manual authoring is faster than any automatic inference
- Automatic adjacency from geometry (shared edge, touching bounds) would produce false positives (rooms on opposite sides of a thick wall with touching Rect2 bounds)

### Architecture Diagram

```
Scene-Placed (Sprint 1):                    Data-Driven (Sprint 2+):

LevelManager (Node)                          Resource file: living_room.tres
├── LivingRoom (Room)                        ┌─────────────────────────┐
│   @export var room_id = &"living_room"     │  RoomData               │
│   @export var bounds = Rect2(0,0,1200,540) │  room_id = &"kitchen"   │
│   @export var adjacent_rooms = [&"kitchen"]│  bounds = Rect2(1200...)│
│   children: Floor, Ceiling, Walls,         │  adjacent_rooms = [...]  │
│             DoorwayTrigger                 └─────────────────────────┘
│                                            (loaded by future streaming
└── Kitchen (Room)                            system, not LevelManager)
    @export var room_id = &"kitchen"
    @export var bounds = Rect2(1200,0,1000,540)
    @export var adjacent_rooms = [&"living_room"]
    children: Floor, Ceiling, SqueezeGap,
              HighCabinet, SqueezeTrigger

Discovery:
LevelManager._register_rooms():
  for child in get_children():
    if child is Room:          ← type check, not name check
      _room_registry[room.room_id] = room

Queried by:
  LevelManager.get_room_for_position() → Rect2.has_point()
  BonnieCamera: set_room_bounds(room.bounds)
  NPC System (Sprint 2): adjacent_rooms for BFS cascade
```

### Key Interfaces

```gdscript
# -- Room (Node2D) --
class_name Room
extends Node2D

## Unique identifier for this room. Used as registry key and signal payload.
@export var room_id: StringName

## Logical bounding box for camera clamping and spatial queries.
## Designer-authored — not computed from collision geometry.
@export var bounds: Rect2

## Room IDs of spatially adjacent rooms for BFS chaos cascade (Sprint 2).
## Manually authored — designer controls the adjacency graph.
@export var adjacent_rooms: Array[StringName]


# -- RoomData (Resource) --
class_name RoomData
extends Resource

## Unique identifier matching the corresponding Room node's room_id.
@export var room_id: StringName

## Logical bounding box — same semantic as Room.bounds.
@export var bounds: Rect2

## Adjacent room IDs — same semantic as Room.adjacent_rooms.
@export var adjacent_rooms: Array[StringName]
```

## Alternatives Considered

### Alternative 1: Room only (no RoomData)
- **Description**: Only `Room` (Node2D) exists. All rooms are scene-placed. Data-driven/streaming needs are addressed when they arise.
- **Pros**: Simpler — one type to understand. YAGNI: Sprint 1 and Sprint 2 don't need RoomData.
- **Cons**: When streaming is needed, migrating from Node2D-only rooms requires either adding a Resource type (the design here) or making Room instances serialize in a non-standard way. Adding RoomData now costs 11 lines and zero runtime overhead — it never needs to be instantiated until streaming is needed.
- **Rejection Reason**: RoomData is 11 lines of `@export` declarations. The cost is negligible. The cost of not having it when streaming is needed is a non-trivial refactor of LevelManager's API.

### Alternative 2: RoomData only (no Room Node2D)
- **Description**: Rooms are defined as Resource files loaded by LevelManager. Scene-placed geometry (collision shapes, triggers) references room IDs but rooms themselves are not nodes.
- **Pros**: All room data is serializable. Level topology is data, not scene structure. Future streaming is trivial.
- **Cons**: Removes the scene tree as the authoring interface. Designers cannot see room bounds in the editor relative to the level geometry. Child nodes (floor, ceiling, triggers) need a different attachment mechanism. LevelManager's child-discovery pattern (which is intentional, see ADR-006 decision 1) doesn't work.
- **Rejection Reason**: The scene tree IS the authoring tool for this project. Visual authoring of room bounds relative to level geometry is essential. RoomData is additive; removing Room entirely sacrifices the editor workflow.

### Alternative 3: Compute bounds from collision shapes
- **Description**: Room bounds are not manually exported. Instead, Room computes its bounds at `_ready()` by querying its `CollisionShape2D` children.
- **Pros**: No manual bounds authoring — bounds stay in sync with collision geometry automatically.
- **Cons**: Logical bounds (for camera and spatial queries) and collision bounds (for physics) have different semantics. A room's logical extent may include a doorway threshold that has no collision shape. Ceiling/wall collision shapes would incorrectly expand the logical bounds. Computing AABB union of arbitrary child shapes is complex and fragile.
- **Rejection Reason**: Logical bounds are a design intent, not a geometry property. Manual authoring is correct and takes 30 seconds per room.

### Alternative 4: Automatic adjacency from shared bounds edges
- **Description**: LevelManager computes adjacency by finding rooms whose `Rect2` bounds share an edge (or overlap at a thin threshold).
- **Pros**: No manual adjacency authoring. Adding a room automatically joins the graph.
- **Cons**: Rooms on different floors or separated by thick walls may have touching bounds but NOT be acoustically adjacent. Adjacency is a gameplay concept (NPC chaos propagation path), not purely a geometry concept. False positives would incorrectly propagate chaos through walls.
- **Rejection Reason**: Adjacency is a design decision. A locked closet shares a wall with the living room but should not propagate chaos. Manual authoring ensures the designer explicitly specifies the intended chaos propagation graph.

## Consequences

### Positive
- 16-line `Room` and 11-line `RoomData` are the simplest possible implementations — no logic, pure data containers
- Scene-tree placement means room bounds are visually verifiable in the Godot editor
- `adjacent_rooms` as `Array[StringName]` is directly usable for BFS traversal without conversion
- RoomData is ready for Sprint 2+ streaming with zero Sprint 1 overhead
- Both types have identical logical fields — a future migration between them is non-breaking

### Negative
- Manual `bounds` authoring means bounds can become stale if level geometry changes without updating the Rect2 export.
- Manual `adjacent_rooms` means a designer can create an asymmetric graph (LivingRoom lists Kitchen as adjacent, but Kitchen doesn't list LivingRoom). The BFS would behave asymmetrically. Future: add a validation check that adjacency is bidirectional.
- RoomData is unused in Sprint 1 — it is future infrastructure. If streaming is never implemented, RoomData is dead code.

### Risks
- **Risk**: Room bounds don't match actual level geometry — camera shows outside the level.
  **Mitigation**: GUT test: place BONNIE at the level bounds edge, verify camera doesn't exceed `Room.bounds`. Visual verification in GATE 3 playtest.
- **Risk**: Asymmetric adjacency graph causes NPC cascade to propagate one-way.
  **Mitigation**: Sprint 2 LevelManager validation: after building BFS graph, assert bidirectionality. Log warning if room A lists room B as adjacent but room B doesn't list room A.
- **Risk**: RoomData accumulates as dead code if streaming/procedural features are indefinitely deferred.
  **Mitigation**: Review at Sprint 4 milestone. If no streaming use case has materialized, remove RoomData as dead code.

## Performance Implications
- **CPU**: Room nodes have no `_process()` or `_physics_process()` — they are pure data containers with child collision geometry. Zero per-frame cost.
- **Memory**: One `Rect2` + one `StringName` + one `Array[StringName]` per room. Under 100 bytes per room.
- **Load Time**: `Room._ready()` does nothing (no override). RoomData is a Resource — load time depends on caller. Sub-millisecond for the data fields themselves.
- **Network**: N/A.

## Migration Plan
No migration needed — Room and RoomData were built as production types in Session 009 (Sprint 1). This ADR documents the existing implementation.

Sprint 2 migration tasks:
1. Populate `adjacent_rooms` in `level_02_apartment.tscn` scenes when BFS cascade is implemented
2. Add bidirectionality validation to LevelManager's `_register_rooms()`
3. Verify RoomData is needed before implementing streaming — if not needed by Sprint 4, evaluate removal

## Validation Criteria
- [ ] `Room.room_id`, `Room.bounds`, `Room.adjacent_rooms` all exportable via inspector
- [ ] `RoomData.room_id`, `RoomData.bounds`, `RoomData.adjacent_rooms` all exportable via inspector
- [ ] LevelManager's `child is Room` check correctly discovers all Room children
- [ ] `LivingRoom.bounds = Rect2(0, 0, 1200, 540)` in `level_02_apartment.tscn`
- [ ] `Kitchen.bounds = Rect2(1200, 0, 1000, 540)` in `level_02_apartment.tscn`
- [ ] BONNIE at x=600 → `get_room_for_position()` returns `&"living_room"`
- [ ] BONNIE at x=1700 → `get_room_for_position()` returns `&"kitchen"`
- [ ] Room nodes have no script logic that could create per-frame overhead

## Related Decisions
- **ADR-006 LevelManager**: Discovers Room nodes via child iteration; queries `room.bounds` for spatial lookups
- **ADR-005 BonnieCamera**: Receives room bounds via LevelManager's `room_entered` signal → `set_room_bounds()`
- **GDD**: `design/gdd/level-manager.md` §3 — Room topology specification and 7-room apartment layout
- **NPC System (System #9)**: Will query `adjacent_rooms` for BFS cascade (Sprint 2)
- **Social System (System #12)**: Receives cascade attenuation computed from Room adjacency graph

## LevelManager — Core Layer (System #5)
##
## Infrastructure node that initializes and owns the runtime context for a
## single level session. Defines room topology, exposes level bounds for
## camera clamping, and fires room transition signals.
##
## Sprint 1 scope: 2 rooms (living room + kitchen). NPC registration and
## BFS cascade attenuation deferred to Sprint 2.
##
## See: design/gdd/level-manager.md
##
## level_02_apartment.tscn intended structure:
##   LevelManager (root)
##   ├── LivingRoom (Room) — bounds: Rect2(0, 0, 1200, 540)
##   │   ├── Floor (StaticBody2D)
##   │   ├── LeftWall (StaticBody2D)
##   │   ├── Ceiling (StaticBody2D)
##   │   ├── Shelf (StaticBody2D, in "Climbable" group)
##   │   └── DoorwayTrigger (Area2D) — right side
##   ├── Kitchen (Room) — bounds: Rect2(1200, 0, 1000, 540)
##   │   ├── Floor (StaticBody2D)
##   │   ├── RightWall (StaticBody2D)
##   │   ├── Ceiling (StaticBody2D)
##   │   ├── SqueezeGap (collision + SqueezeTrigger Area2D)
##   │   └── HighCabinet (StaticBody2D) — for rough landing test
##   ├── BonnieController (scene instance)
##   └── BonnieCamera (scene instance)
class_name LevelManager
extends Node


# -- Signals ------------------------------------------------------------------

## Emitted after all rooms are registered and level is ready.
signal level_ready

## Emitted when BONNIE crosses from one room to another.
signal room_entered(room_id: StringName)


# -- Runtime State ------------------------------------------------------------

## Registry of all rooms in this level, keyed by room_id.
var _room_registry: Dictionary = {}  # Dictionary[StringName, Room]

## The room BONNIE is currently in.
var _current_room: StringName = &""

## Union of all room bounds.
var _level_bounds: Rect2 = Rect2()


# -- Public API ---------------------------------------------------------------

## Returns which room contains the given world-space position.
## Returns &"" if position is outside all rooms.
func get_room_for_position(pos: Vector2) -> StringName:
	for room_id: StringName in _room_registry:
		var room: Room = _room_registry[room_id]
		if room.bounds.has_point(pos):
			return room_id
	return &""


## Returns the union bounding box of all rooms in this level.
func get_level_bounds() -> Rect2:
	return _level_bounds


## Returns the bounds of a specific room.
func get_room_bounds(room_id: StringName) -> Rect2:
	if _room_registry.has(room_id):
		return (_room_registry[room_id] as Room).bounds
	return Rect2()


## Updates BONNIE's current room. Emits room_entered if room changed.
## Call this from the game loop with BONNIE's position each frame.
func update_bonnie_room(pos: Vector2) -> void:
	var room_id: StringName = get_room_for_position(pos)
	if room_id != &"" and room_id != _current_room:
		_current_room = room_id
		room_entered.emit(_current_room)


## Returns the current room BONNIE is in.
func get_current_room() -> StringName:
	return _current_room


# -- Engine Callbacks ---------------------------------------------------------

func _ready() -> void:
	_register_rooms()
	_compute_level_bounds()

	# Set initial room if a BonnieController exists
	var bonnie: CharacterBody2D = _find_bonnie()
	if bonnie:
		_current_room = get_room_for_position(bonnie.global_position)

	# Play level music (stub — no actual music file in Sprint 1)
	if has_node("/root/AudioManager"):
		AudioManager.play_music(&"level_02_calm")

	level_ready.emit()
	print("LevelManager: %d rooms registered, bounds=%s" % [_room_registry.size(), _level_bounds])


# -- Private ------------------------------------------------------------------

func _register_rooms() -> void:
	for child: Node in get_children():
		if child is Room:
			var room: Room = child as Room
			if room.room_id != &"":
				_room_registry[room.room_id] = room


func _compute_level_bounds() -> void:
	var first: bool = true
	for room_id: StringName in _room_registry:
		var room: Room = _room_registry[room_id]
		if first:
			_level_bounds = room.bounds
			first = false
		else:
			_level_bounds = _level_bounds.merge(room.bounds)


func _find_bonnie() -> CharacterBody2D:
	var bonnie: Node = get_tree().get_first_node_in_group(&"Bonnie")
	if bonnie is CharacterBody2D:
		return bonnie as CharacterBody2D
	return null

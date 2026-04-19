## Unit tests for LevelManager (System #5)
extends GutTest


var _manager: LevelManager


func before_each() -> void:
	_manager = LevelManager.new()
	# Add two rooms manually
	var living_room := Room.new()
	living_room.room_id = &"living_room"
	living_room.bounds = Rect2(0, 0, 1200, 540)
	living_room.adjacent_rooms = [&"kitchen"]

	var kitchen := Room.new()
	kitchen.room_id = &"kitchen"
	kitchen.bounds = Rect2(1200, 0, 1000, 540)
	kitchen.adjacent_rooms = [&"living_room"]

	_manager.add_child(living_room)
	_manager.add_child(kitchen)
	add_child_autofree(_manager)
	# _ready() fires, registering rooms


# -- Room Registration --------------------------------------------------------

func test_rooms_registered() -> void:
	assert_eq(_manager._room_registry.size(), 2, "Should register 2 rooms")


func test_living_room_registered() -> void:
	assert_true(_manager._room_registry.has(&"living_room"), "living_room should be registered")


func test_kitchen_registered() -> void:
	assert_true(_manager._room_registry.has(&"kitchen"), "kitchen should be registered")


# -- Spatial Query ------------------------------------------------------------

func test_get_room_for_position_living_room() -> void:
	var room: StringName = _manager.get_room_for_position(Vector2(600, 270))
	assert_eq(room, &"living_room", "Center of living room should return living_room")


func test_get_room_for_position_kitchen() -> void:
	var room: StringName = _manager.get_room_for_position(Vector2(1500, 270))
	assert_eq(room, &"kitchen", "Center of kitchen should return kitchen")


func test_get_room_for_position_outside() -> void:
	var room: StringName = _manager.get_room_for_position(Vector2(-100, -100))
	assert_eq(room, &"", "Position outside all rooms should return empty StringName")


# -- Level Bounds -------------------------------------------------------------

func test_level_bounds_union() -> void:
	var bounds: Rect2 = _manager.get_level_bounds()
	assert_eq(bounds.position.x, 0.0, "Level bounds should start at x=0")
	assert_eq(bounds.position.y, 0.0, "Level bounds should start at y=0")
	assert_eq(bounds.size.x, 2200.0, "Level bounds width should be 1200+1000=2200")
	assert_eq(bounds.size.y, 540.0, "Level bounds height should be 540")


# -- Room Adjacency -----------------------------------------------------------

func test_adjacency_bidirectional() -> void:
	var living: Room = _manager._room_registry[&"living_room"]
	var kitchen: Room = _manager._room_registry[&"kitchen"]
	assert_true(
		&"kitchen" in living.adjacent_rooms,
		"living_room should list kitchen as adjacent"
	)
	assert_true(
		&"living_room" in kitchen.adjacent_rooms,
		"kitchen should list living_room as adjacent"
	)


# -- Room Tracking ------------------------------------------------------------

func test_room_entered_signal_fires() -> void:
	watch_signals(_manager)

	_manager.update_bonnie_room(Vector2(600, 270))  # living room
	assert_signal_emitted(_manager, "room_entered", "room_entered should fire on first room")

	_manager.update_bonnie_room(Vector2(1500, 270))  # kitchen
	assert_signal_emitted_with_parameters(
		_manager, "room_entered", [&"kitchen"],
		"room_entered should fire with kitchen id"
	)


func test_room_entered_does_not_fire_same_room() -> void:
	_manager.update_bonnie_room(Vector2(600, 270))  # living room
	watch_signals(_manager)
	_manager.update_bonnie_room(Vector2(601, 270))  # still living room
	assert_signal_not_emitted(_manager, "room_entered", "room_entered should not fire for same room")


func test_get_current_room() -> void:
	_manager.update_bonnie_room(Vector2(1500, 270))
	assert_eq(_manager.get_current_room(), &"kitchen", "Current room should be kitchen")


# -- Room Bounds Query --------------------------------------------------------

func test_get_room_bounds() -> void:
	var bounds: Rect2 = _manager.get_room_bounds(&"kitchen")
	assert_eq(bounds, Rect2(1200, 0, 1000, 540), "Kitchen bounds should match")


func test_get_room_bounds_unknown() -> void:
	var bounds: Rect2 = _manager.get_room_bounds(&"nonexistent")
	assert_eq(bounds, Rect2(), "Unknown room should return empty Rect2")

## Integration tests for Sprint 1 First Playable (WP-07)
## Verifies all systems wire together in the level scene.
extends GutTest


const LEVEL_SCENE: PackedScene = preload("res://src/level/level_02_apartment.tscn")


var _level: Node


func before_each() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_child_autofree(_level)
	# Allow _ready() to fire on all children
	await get_tree().process_frame


# -- Scene Structure ----------------------------------------------------------

func test_level_loads_without_error() -> void:
	assert_not_null(_level, "Level scene should instantiate")


func test_bonnie_exists_in_scene() -> void:
	var bonnie: Node = _level.get_node_or_null("Bonnie")
	assert_not_null(bonnie, "Bonnie instance should exist in level")


func test_bonnie_is_character_body() -> void:
	var bonnie: Node = _level.get_node("Bonnie")
	assert_is(bonnie, CharacterBody2D, "Bonnie should be CharacterBody2D")


func test_camera_exists_in_scene() -> void:
	var camera: Node = _level.get_node_or_null("Camera")
	assert_not_null(camera, "Camera instance should exist in level")


func test_camera_is_camera2d() -> void:
	var camera: Node = _level.get_node("Camera")
	assert_is(camera, Camera2D, "Camera should be Camera2D")


# -- Room Registration --------------------------------------------------------

func test_rooms_registered_on_ready() -> void:
	# LevelManager registers Room children in _ready()
	var manager: LevelManager = _level as LevelManager
	assert_not_null(manager, "Root should be LevelManager")
	assert_eq(manager._room_registry.size(), 2, "Should register 2 rooms")


func test_living_room_registered() -> void:
	var manager: LevelManager = _level as LevelManager
	assert_true(manager._room_registry.has(&"living_room"))


func test_kitchen_registered() -> void:
	var manager: LevelManager = _level as LevelManager
	assert_true(manager._room_registry.has(&"kitchen"))


# -- BONNIE Initial State -----------------------------------------------------

func test_bonnie_starts_idle() -> void:
	var bonnie: BonnieController = _level.get_node("Bonnie") as BonnieController
	assert_eq(bonnie.current_state, BonnieController.State.IDLE, "BONNIE should start IDLE")


func test_bonnie_in_bonnie_group() -> void:
	var bonnie: Node = _level.get_node("Bonnie")
	assert_true(bonnie.is_in_group(&"Bonnie"), "BONNIE should be in 'Bonnie' group")


func test_bonnie_has_collision_shape() -> void:
	var shape: Node = _level.get_node_or_null("Bonnie/CollisionShape2D")
	assert_not_null(shape, "BONNIE should have CollisionShape2D")


func test_bonnie_has_squeeze_shape() -> void:
	var shape: CollisionShape2D = _level.get_node("Bonnie/SqueezeShape") as CollisionShape2D
	assert_not_null(shape, "BONNIE should have SqueezeShape")
	assert_true(shape.disabled, "SqueezeShape should start disabled")


func test_squeeze_shape_position_locked() -> void:
	var shape: Node2D = _level.get_node("Bonnie/SqueezeShape") as Node2D
	assert_eq(shape.position, Vector2(0, 14), "SqueezeShape position=(0,14) LOCKED")


# -- Climbable and Squeeze Geometry -------------------------------------------

func test_climbable_wall_in_group() -> void:
	var wall: Node = _level.get_node("ClimbableWall")
	assert_true(wall.is_in_group(&"Climbable"), "ClimbableWall should be in Climbable group")


func test_squeeze_trigger_in_group() -> void:
	var trigger: Node = _level.get_node("SqueezeTrigger")
	assert_true(trigger.is_in_group(&"SqueezeTrigger"), "SqueezeTrigger should be in SqueezeTrigger group")


# -- Level Bounds -------------------------------------------------------------

func test_level_bounds_span_both_rooms() -> void:
	var manager: LevelManager = _level as LevelManager
	var bounds: Rect2 = manager.get_level_bounds()
	assert_eq(bounds.size.x, 2200.0, "Level width = living(1200) + kitchen(1000)")
	assert_eq(bounds.size.y, 540.0, "Level height = 540")

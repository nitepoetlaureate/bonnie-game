## BonnieCamera — Core Layer (System #4)
##
## State-aware camera that follows BONNIE with dynamic look-ahead,
## vertical framing, room-bound clamping, and recon zoom.
##
## See: design/gdd/camera-system.md
class_name BonnieCamera
extends Camera2D


# -- Signals ------------------------------------------------------------------

## Emitted when zoom crosses the LOD threshold (sprites should swap).
signal zoom_lod_changed(use_lod: bool)


# -- Tuning Knobs (GDD §4/§7) ------------------------------------------------

@export_group("Follow")
## Target node to follow. Must expose get_look_ahead_distance() and get_facing_direction().
@export var target: CharacterBody2D
## How fast the camera catches up to its target (higher = snappier).
@export var follow_speed: float = 6.0
## Lerp multiplier applied during direction reversal catch-up.
@export var catch_up_speed: float = 4.0
## BONNIE's vertical position in viewport (0.0 = top, 1.0 = bottom).
@export var vertical_anchor_ratio: float = 0.7

@export_group("Recon Zoom")
## Default zoom level (no zoom held).
@export var zoom_normal: float = 1.0
## Maximum zoom-out when zoom is held.
@export var zoom_max_out: float = 0.33
## Zoom decrease per second while zoom button held.
@export var zoom_out_rate: float = 0.8
## Zoom increase per second when zoom button released.
@export var zoom_return_rate: float = 2.0
## Zoom level below which LOD sprites should activate.
@export var zoom_lod_threshold: float = 0.75

@export_group("Ledge Bias")
## Distance at which ledge bias activates (px). Sprint 1: infrastructure only.
@export var ledge_bias_activation_radius: float = 80.0
## Maximum pixel offset added toward nearby surface.
@export var ledge_bias_strength: float = 40.0


# -- Runtime State ------------------------------------------------------------

var _current_zoom: float = 1.0
var _was_lod_active: bool = false
var _last_facing: float = 1.0
var _ledge_bias_offset: Vector2 = Vector2.ZERO
var _room_center: Vector2 = Vector2.ZERO


# -- Public API ---------------------------------------------------------------

## Set room boundaries for camera clamping.
func set_room_bounds(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.position.x + bounds.size.x)
	limit_bottom = int(bounds.position.y + bounds.size.y)
	_room_center = bounds.get_center()


## Set ledge bias offset (called by physics-aware systems, not camera itself).
func set_ledge_bias(offset: Vector2) -> void:
	_ledge_bias_offset = offset


# -- Engine Callbacks ---------------------------------------------------------

func _ready() -> void:
	_current_zoom = zoom_normal
	# Disable Godot's built-in camera smoothing — we do our own lerp
	position_smoothing_enabled = false


func _process(delta: float) -> void:
	if target == null:
		return

	# -- Compute target position --
	var target_pos: Vector2 = _compute_target_position()

	# -- Apply ledge bias --
	target_pos += _ledge_bias_offset

	# -- Smooth follow --
	var speed: float = follow_speed
	# Use catch-up speed when direction reversed
	var current_facing: float = _get_target_facing()
	if current_facing != 0.0 and current_facing != _last_facing:
		speed = catch_up_speed
	if current_facing != 0.0:
		_last_facing = current_facing

	global_position = global_position.lerp(target_pos, speed * delta)

	# -- Recon zoom --
	_update_zoom(delta)


# -- Private ------------------------------------------------------------------

func _compute_target_position() -> Vector2:
	var look_ahead: float = _get_target_look_ahead()
	var facing: float = _get_target_facing()

	var look_ahead_offset := Vector2(facing * look_ahead, 0.0)

	# Vertical framing: position BONNIE at vertical_anchor_ratio down the viewport.
	# viewport height = 540. If anchor = 0.7, BONNIE at y=378 (70% of 540).
	# Camera center is at y=270. Offset = -(270 - 378) = +108... no.
	# Actually: camera position = BONNIE position + vertical_offset
	# We want BONNIE at 70% down. Camera center shows 50% down.
	# So camera needs to be ABOVE BONNIE by (0.7 - 0.5) * 540 = 108px
	# That means vertical_offset.y = -(540.0 * 0.5 - 540.0 * vertical_anchor_ratio)
	# = -(270 - 378) = -(-108) = +108... wait.
	# GDD §4 formula: vertical_offset = -(540.0 * 0.5 - 380.0) = -(270 - 380) = -(-110) = 110
	# But that's world offset. Camera position = bonnie.position + offset.
	# If offset.y = -110, camera is 110px ABOVE bonnie, meaning bonnie appears lower on screen.
	# Actually in Godot 2D, Y increases downward.
	# Camera at bonnie.y - 110 means camera center is 110px above bonnie.
	# In viewport: bonnie appears at center + 110 = 270 + 110 = 380px from top. Correct!
	var vertical_offset_y: float = -(ViewportGuardClass.INTERNAL_HEIGHT * 0.5 - ViewportGuardClass.INTERNAL_HEIGHT * vertical_anchor_ratio)

	return target.global_position + look_ahead_offset + Vector2(0.0, vertical_offset_y)


func _get_target_look_ahead() -> float:
	if target.has_method(&"get_look_ahead_distance"):
		return target.get_look_ahead_distance()
	return 0.0


func _get_target_facing() -> float:
	if target.has_method(&"get_facing_direction"):
		return target.get_facing_direction()
	return 1.0


func _update_zoom(delta: float) -> void:
	if Input.is_action_pressed(&"zoom"):
		_current_zoom = maxf(zoom_max_out, _current_zoom - zoom_out_rate * delta)
	else:
		_current_zoom = minf(zoom_normal, _current_zoom + zoom_return_rate * delta)

	zoom = Vector2(_current_zoom, _current_zoom)

	# LOD threshold crossing
	var lod_active: bool = _current_zoom < zoom_lod_threshold
	if lod_active != _was_lod_active:
		_was_lod_active = lod_active
		zoom_lod_changed.emit(lod_active)

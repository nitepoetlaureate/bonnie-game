## BonnieController — Gameplay Layer (System #6)
##
## Production traversal controller for BONNIE. 13 movement states,
## physics-driven momentum, frame-exact ledge parry, and the "feels
## like a cat" quality that is the game's core identity.
##
## All input reads go through InputManager autoload. No raw Input calls
## for movement vector, jump buffering, or coyote time. Raw Input is
## used only for hold-state queries (run, sneak, grab, zoom, move_down).
##
## See: design/gdd/bonnie-traversal.md
class_name BonnieController
extends CharacterBody2D


# -- Signals ------------------------------------------------------------------

## Emitted on every state transition.
signal state_changed(old_state: State, new_state: State)


# -- State Machine ------------------------------------------------------------

enum State {
	IDLE,
	SNEAKING,
	WALKING,
	RUNNING,
	SLIDING,
	JUMPING,
	FALLING,
	LANDING,
	CLIMBING,
	SQUEEZING,
	DAZED,
	ROUGH_LANDING,
	LEDGE_PULLUP,
}


# -- Constants ----------------------------------------------------------------

## Look-ahead distances per state for the Camera System (GDD camera-system §3).
const LOOK_AHEAD_BY_STATE: Dictionary = {
	State.IDLE: 0.0,
	State.SNEAKING: 40.0,
	State.WALKING: 80.0,
	State.RUNNING: 180.0,
	State.SLIDING: 220.0,
	State.JUMPING: 120.0,
	State.FALLING: 120.0,
	State.LANDING: 0.0,
	State.CLIMBING: 60.0,
	State.SQUEEZING: 0.0,
	State.DAZED: 0.0,
	State.ROUGH_LANDING: 0.0,
	State.LEDGE_PULLUP: 60.0,
}


# -- Exported Tuning Knobs (GDD §7) ------------------------------------------

@export_group("Movement Speeds")
@export var sneak_max_speed: float = 80.0
@export var walk_speed: float = 180.0
@export var run_max_speed: float = 420.0
@export var climb_speed: float = 90.0
@export var squeeze_speed: float = 100.0

@export_group("Ground Physics")
@export var ground_acceleration: float = 800.0
@export var ground_deceleration: float = 600.0
@export var slide_trigger_speed: float = 300.0
@export var slide_friction: float = 80.0

@export_group("Jump")
@export var hop_velocity: float = 280.0
@export var jump_velocity: float = 480.0
@export var jump_hold_force: float = 900.0
@export var jump_hold_window: int = 12
@export var double_jump_velocity: float = 380.0
@export var double_jump_redirect_factor: float = 0.45
@export var gravity: float = 980.0
@export var fall_velocity_max: float = 900.0
@export var air_control_force: float = 260.0
@export var post_double_jump_air_control: float = 30.0

@export_group("Jump Timing (frames)")
@export var double_jump_window_frames: int = 40
@export var parry_window_frames: int = 6

@export_group("Ledge and Climb")
@export var parry_detection_radius: float = 24.0
@export var wall_jump_velocity: float = 360.0
@export var pullup_duration_frames: int = 10
@export var climb_claw_impulse: float = 180.0
@export var climb_claw_burst_frames: int = 4
@export var claw_brake_multiplier: float = 0.30  # LOCKED — GATE 1 confirmed
@export var pullup_pop_velocity: float = 260.0
@export var pullup_pop_vertical: float = 200.0
## Horizontal nudge when mounting a climbable surface top — enough to clear the edge.
@export var pullup_mount_velocity: float = 80.0

@export_group("Landing")
@export var clean_land_threshold: float = 80.0
@export var skid_threshold: float = 180.0
@export var hard_skid_threshold: float = 320.0
@export var skid_friction_multiplier: float = 0.15  # LOCKED — NOT 0.85
@export var skid_base_duration: float = 0.6
@export var hard_skid_base_duration: float = 1.1
@export var rough_landing_threshold: float = 144.0

@export_group("Recovery")
@export var daze_duration: float = 1.0
@export var daze_collision_threshold: float = 280.0
@export var rough_landing_duration: float = 2.5

@export_group("NPC Stimulus Radii")
@export var idle_stimulus_radius: float = 96.0
@export var sneak_stimulus_radius: float = 48.0
@export var walk_stimulus_radius: float = 140.0
@export var run_stimulus_radius: float = 220.0


# -- Node References ----------------------------------------------------------

@onready var _main_shape: CollisionShape2D = $CollisionShape2D
@onready var _squeeze_shape: CollisionShape2D = $SqueezeShape
@onready var _sprite: ColorRect = $PlaceholderSprite
@onready var _parry_cast: ShapeCast2D = $ParryCast


# -- Runtime State ------------------------------------------------------------

var current_state: State = State.IDLE
var facing_direction: float = 1.0

# Fall tracking
var fall_distance: float = 0.0
var fall_origin_y: float = 0.0

# Double jump
var double_jump_available: bool = true
var double_jump_window_timer: int = 0

# Landing skid
var in_skid_window: bool = false

# Jump hold
var is_jump_held: bool = false


# -- Private Runtime State ----------------------------------------------------

var _post_double_jumped: bool = false
var _was_on_floor_last_frame: bool = false
var _at_apex: bool = false
var _ledge_pullup_timer: float = 0.0
var _landing_impact_speed: float = 0.0
var _jump_hold_timer: int = 0
var _skid_timer: float = 0.0
var _skid_is_hard: bool = false
var _parry_window_timer: int = 0
var _parry_cast_was_colliding: bool = false
var _claw_burst_timer: int = 0
var _pullup_direction: float = 0.0
var _pullup_from_climb: bool = false
var _at_climb_top: bool = false
var _squeeze_zone_active: bool = false
var _daze_timer: float = 0.0
var _rough_landing_timer: float = 0.0


# =============================================================================
# PUBLIC API
# =============================================================================

## Returns state-dependent look-ahead distance for camera system.
func get_look_ahead_distance() -> float:
	return LOOK_AHEAD_BY_STATE.get(current_state, 0.0)


## Returns current facing direction: 1.0 = right, -1.0 = left.
func get_facing_direction() -> float:
	return facing_direction


## Returns state-dependent stimulus radius for NPC perception system.
func get_stimulus_radius() -> float:
	match current_state:
		State.IDLE, State.LANDING, State.DAZED, State.ROUGH_LANDING, State.LEDGE_PULLUP:
			return idle_stimulus_radius
		State.SNEAKING, State.SQUEEZING:
			return sneak_stimulus_radius
		State.WALKING, State.CLIMBING:
			return walk_stimulus_radius
		State.RUNNING, State.SLIDING, State.JUMPING, State.FALLING:
			return run_stimulus_radius
		_:
			return idle_stimulus_radius


## Returns the surface type beneath BONNIE's feet based on group membership.
func get_surface_type() -> StringName:
	if not is_on_floor():
		return &"default"
	var col: KinematicCollision2D = get_last_slide_collision()
	if col == null:
		return &"default"
	var collider: Object = col.get_collider()
	if collider == null:
		return &"default"
	if collider.is_in_group(&"hardwood"):
		return &"hardwood"
	if collider.is_in_group(&"carpet"):
		return &"carpet"
	if collider.is_in_group(&"tile"):
		return &"tile"
	return &"default"


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	add_to_group(&"Bonnie")

	# Connect squeeze trigger if present in scene
	var squeeze_trigger: Node = get_tree().get_first_node_in_group(&"SqueezeTrigger")
	if squeeze_trigger:
		squeeze_trigger.body_entered.connect(_on_squeeze_trigger_entered)
		squeeze_trigger.body_exited.connect(_on_squeeze_trigger_exited)


func _physics_process(delta: float) -> void:
	_was_on_floor_last_frame = is_on_floor()

	# Tick frame counters
	if double_jump_window_timer > 0:
		double_jump_window_timer -= 1
	if _parry_window_timer > 0:
		_parry_window_timer -= 1

	# Dispatch to per-state handler
	match current_state:
		State.IDLE:
			_handle_idle(delta)
		State.SNEAKING:
			_handle_sneaking(delta)
		State.WALKING:
			_handle_walking(delta)
		State.RUNNING:
			_handle_running(delta)
		State.SLIDING:
			_handle_sliding(delta)
		State.JUMPING:
			_handle_jumping(delta)
		State.FALLING:
			_handle_falling(delta)
		State.LANDING:
			_handle_landing(delta)
		State.CLIMBING:
			_handle_climbing(delta)
		State.SQUEEZING:
			_handle_squeezing(delta)
		State.DAZED:
			_handle_dazed(delta)
		State.ROUGH_LANDING:
			_handle_rough_landing(delta)
		State.LEDGE_PULLUP:
			_handle_ledge_pullup(delta)

	move_and_slide()

	# Parry proximity tracking
	var parry_colliding_now: bool = _parry_cast.is_colliding() and _has_wall_or_ledge_collision()
	if parry_colliding_now and not _parry_cast_was_colliding:
		_parry_window_timer = parry_window_frames
	_parry_cast_was_colliding = parry_colliding_now


# =============================================================================
# STATE MACHINE
# =============================================================================

func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return

	var old_state: State = current_state

	# Exit logic
	match old_state:
		State.JUMPING, State.FALLING:
			fall_distance = 0.0
			fall_origin_y = 0.0
		State.SLIDING:
			in_skid_window = false
		State.SQUEEZING:
			_squeeze_shape.disabled = true
			_main_shape.disabled = false
			_sprite.offset_left = -8.0
			_sprite.offset_right = 8.0
			_sprite.offset_top = -16.0
			_sprite.offset_bottom = 16.0

	# Entry logic
	match new_state:
		State.SQUEEZING:
			_main_shape.disabled = true
			_squeeze_shape.disabled = false
			_sprite.offset_left = -12.0
			_sprite.offset_right = 12.0
			_sprite.offset_top = -4.0
			_sprite.offset_bottom = 4.0
		State.FALLING:
			fall_origin_y = global_position.y
		State.JUMPING:
			is_jump_held = true
			_jump_hold_timer = 0
			double_jump_available = true
			double_jump_window_timer = 0
			_at_apex = false
			_post_double_jumped = false
		State.LANDING:
			in_skid_window = false
		State.LEDGE_PULLUP:
			_ledge_pullup_timer = pullup_duration_frames / 60.0
			_pullup_direction = 0.0
			_pullup_from_climb = false
			velocity = Vector2.ZERO
		State.DAZED:
			_daze_timer = daze_duration
		State.ROUGH_LANDING:
			_rough_landing_timer = rough_landing_duration

	current_state = new_state
	state_changed.emit(old_state, new_state)


# =============================================================================
# PER-STATE HANDLERS
# =============================================================================

func _handle_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)

	if not is_on_floor() and _was_on_floor_last_frame:
		InputManager.notify_left_ground()
		_change_state(State.FALLING)
		return

	if _try_ground_climb():
		return
	if _check_squeeze_entry():
		return

	if (Input.is_action_just_pressed(&"jump") or InputManager.is_jump_buffered()) and is_on_floor():
		InputManager.consume_jump_buffer()
		velocity.y = -hop_velocity
		_change_state(State.JUMPING)
		return

	var input_vec: Vector2 = InputManager.get_movement_vector()
	if input_vec.x != 0.0:
		if InputManager.is_auto_sneaking(input_vec) or Input.is_action_pressed(&"sneak"):
			_change_state(State.SNEAKING)
		elif Input.is_action_pressed(&"run"):
			_change_state(State.RUNNING)
		else:
			_change_state(State.WALKING)


func _handle_sneaking(delta: float) -> void:
	var input_vec: Vector2 = InputManager.get_movement_vector()
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)
	velocity.x = move_toward(velocity.x, input_vec.x * sneak_max_speed, ground_acceleration * delta)

	if not is_on_floor():
		_change_state(State.FALLING)
		return
	if _try_ground_climb():
		return
	if _check_squeeze_entry():
		return
	if Input.is_action_just_pressed(&"jump") or InputManager.is_jump_buffered():
		InputManager.consume_jump_buffer()
		velocity.y = -hop_velocity
		_change_state(State.JUMPING)
		return
	if input_vec.x == 0.0:
		_change_state(State.IDLE)
		return
	if not InputManager.is_auto_sneaking(input_vec) and not Input.is_action_pressed(&"sneak"):
		_change_state(State.WALKING)


func _handle_walking(delta: float) -> void:
	var input_vec: Vector2 = InputManager.get_movement_vector()
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)
	velocity.x = move_toward(velocity.x, input_vec.x * walk_speed, ground_acceleration * delta)

	if not is_on_floor():
		InputManager.notify_left_ground()
		_change_state(State.FALLING)
		return
	if _try_ground_climb():
		return
	if _check_squeeze_entry():
		return
	if Input.is_action_just_pressed(&"jump") or InputManager.is_jump_buffered():
		InputManager.consume_jump_buffer()
		velocity.y = -hop_velocity
		_change_state(State.JUMPING)
		return
	if InputManager.is_auto_sneaking(input_vec) or Input.is_action_pressed(&"sneak"):
		_change_state(State.SNEAKING)
		return
	if Input.is_action_pressed(&"run") and input_vec.x != 0.0:
		_change_state(State.RUNNING)
		return
	if input_vec.x == 0.0:
		_change_state(State.IDLE)


func _handle_running(delta: float) -> void:
	var input_vec: Vector2 = InputManager.get_movement_vector()
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)

	# Slide triggers
	var opposing_input: bool = (
		input_vec.x != 0.0
		and sign(input_vec.x) != sign(velocity.x)
		and abs(velocity.x) > slide_trigger_speed
	)
	var explicit_slide: bool = (
		Input.is_action_pressed(&"move_down")
		and abs(velocity.x) > slide_trigger_speed
	)
	if opposing_input or explicit_slide:
		_change_state(State.SLIDING)
		return

	velocity.x = move_toward(velocity.x, input_vec.x * run_max_speed, ground_acceleration * delta)

	if not is_on_floor():
		InputManager.notify_left_ground()
		_change_state(State.FALLING)
		return
	if _try_ground_climb():
		return
	if _check_squeeze_entry():
		return
	if Input.is_action_just_pressed(&"jump") or InputManager.is_jump_buffered():
		InputManager.consume_jump_buffer()
		velocity.y = -hop_velocity
		_change_state(State.JUMPING)
		return
	if not Input.is_action_pressed(&"run"):
		_change_state(State.WALKING)
		return
	if abs(velocity.x) < walk_speed and input_vec.x == 0.0:
		_change_state(State.IDLE)


func _handle_sliding(delta: float) -> void:
	var input_vec: Vector2 = InputManager.get_movement_vector()

	velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)

	# Slight steer in direction of travel
	if input_vec.x != 0.0 and sign(input_vec.x) == sign(velocity.x):
		velocity.x = move_toward(velocity.x, input_vec.x * run_max_speed, slide_friction * 0.5 * delta)

	# Claw brake — E tap: speed-dependent friction spike
	if Input.is_action_just_pressed(&"grab"):
		var brake: float = abs(velocity.x) * claw_brake_multiplier
		velocity.x = move_toward(velocity.x, 0.0, brake)

	# Pop-jump
	if Input.is_action_just_pressed(&"jump") or InputManager.is_jump_buffered():
		InputManager.consume_jump_buffer()
		velocity.y = -jump_velocity
		_change_state(State.JUMPING)
		return

	# Auto-grab Climbable on collision
	if _try_slide_auto_climb():
		return

	# Wall daze
	if get_slide_collision_count() > 0:
		for i: int in get_slide_collision_count():
			var collision: KinematicCollision2D = get_slide_collision(i)
			if abs(collision.get_normal().x) > 0.7 and abs(velocity.x) > daze_collision_threshold:
				velocity.x = 0.0
				_change_state(State.DAZED)
				return

	if not is_on_floor():
		_change_state(State.FALLING)
		return
	if abs(velocity.x) < walk_speed:
		_change_state(State.IDLE)


func _handle_jumping(delta: float) -> void:
	_apply_gravity(delta)
	velocity.y = max(velocity.y, -fall_velocity_max)

	# Jump hold — additive force while held
	if is_jump_held and Input.is_action_pressed(&"jump"):
		_jump_hold_timer += 1
		if _jump_hold_timer <= jump_hold_window:
			velocity.y -= jump_hold_force * delta
			velocity.y = max(velocity.y, -jump_velocity)
		else:
			is_jump_held = false
	elif not Input.is_action_pressed(&"jump"):
		is_jump_held = false

	# Apex detection
	if velocity.y >= 0.0 and not _at_apex:
		_at_apex = true
		double_jump_window_timer = double_jump_window_frames

	# Air control
	var input_vec: Vector2 = InputManager.get_movement_vector()

	# Double jump
	if _at_apex and double_jump_available and double_jump_window_timer > 0:
		if Input.is_action_just_pressed(&"jump"):
			velocity.y = -double_jump_velocity
			velocity.x = lerpf(velocity.x, input_vec.x * run_max_speed, double_jump_redirect_factor)
			double_jump_available = false
			_post_double_jumped = true
			double_jump_window_timer = 0

	var air_ctrl: float = post_double_jump_air_control if _post_double_jumped else air_control_force
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)
		velocity.x = move_toward(velocity.x, input_vec.x * run_max_speed, air_ctrl * delta)

	if _try_airborne_climb():
		return
	_check_ledge_parry()

	if is_on_floor():
		_on_landed()
	elif velocity.y > 0.0 and _at_apex:
		_change_state(State.FALLING)


func _handle_falling(delta: float) -> void:
	_apply_gravity(delta)
	velocity.y = min(velocity.y, fall_velocity_max)
	fall_distance = global_position.y - fall_origin_y

	var input_vec: Vector2 = InputManager.get_movement_vector()
	var air_ctrl: float = post_double_jump_air_control if _post_double_jumped else air_control_force
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)
		velocity.x = move_toward(velocity.x, input_vec.x * run_max_speed, air_ctrl * delta)

	# Coyote jump
	if InputManager.is_coyote_active() and Input.is_action_just_pressed(&"jump"):
		InputManager.consume_coyote()
		InputManager.consume_jump_buffer()
		velocity.y = -hop_velocity
		is_jump_held = true
		_jump_hold_timer = 0
		_post_double_jumped = false
		_at_apex = false
		_change_state(State.JUMPING)
		return

	# Double jump from fall (no first jump used)
	if double_jump_available and not InputManager.is_coyote_active() and Input.is_action_just_pressed(&"jump"):
		velocity.y = -double_jump_velocity
		velocity.x = lerpf(velocity.x, input_vec.x * run_max_speed, double_jump_redirect_factor)
		double_jump_available = false
		_post_double_jumped = true

	if _try_airborne_climb():
		return
	_check_ledge_parry()

	if is_on_floor():
		_on_landed()


func _on_landed() -> void:
	_landing_impact_speed = abs(velocity.x)
	_post_double_jumped = false
	_at_apex = false

	# Soft landing surfaces reset fall distance
	var floor_col: KinematicCollision2D = get_last_slide_collision()
	if floor_col:
		var floor_body: Object = floor_col.get_collider()
		if floor_body and floor_body.is_in_group(&"soft_landing"):
			fall_distance = 0.0

	if fall_distance >= rough_landing_threshold:
		_change_state(State.ROUGH_LANDING)
		fall_distance = 0.0
		return

	fall_distance = 0.0

	# Jump buffer fires on landing
	if InputManager.is_jump_buffered():
		InputManager.consume_jump_buffer()
		velocity.y = -hop_velocity
		_change_state(State.JUMPING)
		return

	_change_state(State.LANDING)


func _handle_landing(delta: float) -> void:
	if not in_skid_window and _landing_impact_speed > 0.0:
		if _landing_impact_speed >= hard_skid_threshold:
			in_skid_window = true
			_skid_is_hard = true
			_skid_timer = (_landing_impact_speed / run_max_speed) * hard_skid_base_duration
		elif _landing_impact_speed >= skid_threshold:
			in_skid_window = true
			_skid_is_hard = false
			_skid_timer = (_landing_impact_speed / run_max_speed) * skid_base_duration
		_landing_impact_speed = 0.0

	if in_skid_window:
		_skid_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * skid_friction_multiplier * delta)

		if Input.is_action_just_pressed(&"jump") or InputManager.is_jump_buffered():
			InputManager.consume_jump_buffer()
			velocity.y = -hop_velocity
			in_skid_window = false
			_change_state(State.JUMPING)
			return

		if _skid_timer <= 0.0 or abs(velocity.x) < walk_speed:
			in_skid_window = false
			_change_state(State.IDLE)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
		_change_state(State.IDLE)


func _handle_climbing(_delta: float) -> void:
	var input_vec: Vector2 = InputManager.get_movement_vector()

	# Top-edge detection — runs first so E-handling can read the flag this same frame.
	# Three layers; no longer auto-transitions. Just sets _at_climb_top.
	# 1. Normal pointing upward on a Climbable (top face hit)
	# 2. Ceiling fallback (climbable flush against room ceiling)
	# Failsafe auto-mount (lost contact entirely) is handled at the bottom.
	var touching_climbable: bool = false
	for i: int in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = col.get_collider()
		if collider and collider.is_in_group(&"Climbable"):
			touching_climbable = true
			# In Godot 2D, Y increases downward. Upward normals have negative Y.
			_at_climb_top = col.get_normal().y < -0.5
			break
	if is_on_ceiling():
		_at_climb_top = true
	if not touching_climbable:
		_at_climb_top = false

	# Claw burst — or mount if E pressed while at the top edge.
	# "The last E at the ledge puts her on top." — fluid scramble intent.
	if Input.is_action_just_pressed(&"grab"):
		if _at_climb_top:
			_pullup_from_climb = true
			_change_state(State.LEDGE_PULLUP)
			return
		_claw_burst_timer = climb_claw_burst_frames

	if _claw_burst_timer > 0:
		_claw_burst_timer -= 1
		velocity.y = -climb_claw_impulse
	else:
		velocity.y = 0.0
		if input_vec.y != 0.0:
			velocity.y = input_vec.y * climb_speed

	# Horizontal detach
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)
		velocity.x = input_vec.x * walk_speed
		_change_state(State.FALLING)
		return

	velocity.x = 0.0

	# Wall jump
	if Input.is_action_just_pressed(&"jump"):
		velocity.x = facing_direction * -1.0 * wall_jump_velocity
		velocity.y = -wall_jump_velocity
		double_jump_available = true
		_post_double_jumped = false
		_change_state(State.JUMPING)
		return

	# Failsafe: BONNIE has drifted entirely above the surface without an E press
	# (e.g. a burst carried her past). Auto-mount so she doesn't float away.
	if not touching_climbable and velocity.y <= 0.0 and _claw_burst_timer <= 0:
		_pullup_from_climb = true
		_change_state(State.LEDGE_PULLUP)
		return

	# Drop
	if Input.is_action_pressed(&"move_down") and velocity.y > 0.0 and not is_on_floor():
		_change_state(State.FALLING)


func _handle_squeezing(delta: float) -> void:
	var input_vec: Vector2 = InputManager.get_movement_vector()
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)
	velocity.x = move_toward(velocity.x, input_vec.x * squeeze_speed, ground_acceleration * delta)

	if not _squeeze_zone_active:
		_change_state(State.IDLE)
		return
	if not is_on_floor():
		_change_state(State.FALLING)


func _handle_dazed(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
	_daze_timer -= delta
	if _daze_timer <= 0.0:
		_change_state(State.IDLE)


func _handle_rough_landing(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
	_rough_landing_timer -= delta
	if _rough_landing_timer <= 0.0:
		_change_state(State.IDLE)


func _handle_ledge_pullup(delta: float) -> void:
	velocity = Vector2.ZERO
	var input_vec: Vector2 = InputManager.get_movement_vector()
	if input_vec.x != 0.0:
		_pullup_direction = sign(input_vec.x)

	_ledge_pullup_timer -= delta
	if _ledge_pullup_timer > 0.0:
		return

	# Phase 2 — resolve
	if _pullup_from_climb:
		# Mounting a climbable surface top: step forward onto the shelf and let gravity settle.
		# Use facing_direction (or player input if they redirected during the pullup pause).
		var mount_dir: float = _pullup_direction if _pullup_direction != 0.0 else facing_direction
		facing_direction = mount_dir
		velocity.x = mount_dir * pullup_mount_velocity
		velocity.y = 0.0
		_post_double_jumped = false
		_change_state(State.FALLING)
	elif _pullup_direction != 0.0:
		# Ledge parry pop: player earned a directional boost.
		facing_direction = _pullup_direction
		velocity.x = _pullup_direction * pullup_pop_velocity
		velocity.y = -pullup_pop_vertical
		_post_double_jumped = false
		_change_state(State.JUMPING)
	else:
		_change_state(State.IDLE)


# =============================================================================
# PHYSICS HELPERS
# =============================================================================

func _try_airborne_climb() -> bool:
	if not Input.is_action_pressed(&"grab"):
		return false
	for i: int in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = col.get_collider()
		if collider and collider.is_in_group(&"Climbable"):
			double_jump_available = true
			_post_double_jumped = false
			velocity.x = 0.0
			_change_state(State.CLIMBING)
			return true
	return false


func _try_ground_climb() -> bool:
	if not Input.is_action_pressed(&"grab"):
		return false
	if _parry_cast.is_colliding():
		for i: int in _parry_cast.get_collision_count():
			var collider: Object = _parry_cast.get_collider(i)
			if collider and collider.is_in_group(&"Climbable"):
				double_jump_available = true
				_post_double_jumped = false
				_change_state(State.CLIMBING)
				return true
	for i: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider and collider.is_in_group(&"Climbable"):
			double_jump_available = true
			_post_double_jumped = false
			_change_state(State.CLIMBING)
			return true
	return false


func _try_slide_auto_climb() -> bool:
	for i: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider and collider.is_in_group(&"Climbable"):
			double_jump_available = true
			_post_double_jumped = false
			velocity.x = 0.0
			_change_state(State.CLIMBING)
			return true
	return false


func _check_squeeze_entry() -> bool:
	if _squeeze_zone_active and is_on_floor():
		_change_state(State.SQUEEZING)
		return true
	return false


func _has_wall_or_ledge_collision() -> bool:
	for i: int in _parry_cast.get_collision_count():
		var point: Vector2 = _parry_cast.get_collision_point(i)
		var delta_y: float = point.y - global_position.y
		if delta_y < 12.0:
			return true
	return false


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


func _check_ledge_parry() -> void:
	# grab has NO buffer — frame-exact per GDD
	if not Input.is_action_just_pressed(&"grab"):
		return
	if _parry_window_timer <= 0:
		return
	if not _parry_cast.is_colliding():
		return
	if not _has_wall_or_ledge_collision():
		return

	for i: int in _parry_cast.get_collision_count():
		var collider: Object = _parry_cast.get_collider(i)
		if collider == null:
			continue
		var point: Vector2 = _parry_cast.get_collision_point(i)
		if point.y - global_position.y >= 12.0:
			continue
		if collider.is_in_group(&"Climbable"):
			double_jump_available = true
			_post_double_jumped = false
			_parry_window_timer = 0
			_change_state(State.CLIMBING)
			return
		else:
			_parry_window_timer = 0
			_change_state(State.LEDGE_PULLUP)
			return


# =============================================================================
# SIGNAL CALLBACKS
# =============================================================================

func _on_squeeze_trigger_entered(body: Node) -> void:
	if body == self:
		_squeeze_zone_active = true


func _on_squeeze_trigger_exited(body: Node) -> void:
	if body == self:
		_squeeze_zone_active = false

## Prototype — class_name removed to avoid conflict with production src/gameplay/bonnie_controller.gd
extends CharacterBody2D

# =============================================================================
# BONNIE Traversal Prototype — BonnieController.gd
# Godot 4.6 | prototype/bonnie-traversal/
# Reference: design/gdd/bonnie-traversal.md, input-system.md, camera-system.md
# =============================================================================

# --- Signals -----------------------------------------------------------------

signal state_changed(old_state: State, new_state: State)

# --- State Machine -----------------------------------------------------------

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

# --- Constants ---------------------------------------------------------------

# Look-ahead distances per state for the Camera System.
# Source: design/gdd/camera-system.md §3 and §4.
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

# --- Exported Tuning Knobs ---------------------------------------------------
# All defaults from design/gdd/bonnie-traversal.md §7.

@export_group("Movement Speeds")
@export var sneak_max_speed: float = 80.0        # px/s — bonnie-traversal §7
@export var walk_speed: float = 180.0            # px/s
@export var run_max_speed: float = 420.0         # px/s
@export var climb_speed: float = 90.0            # px/s
@export var squeeze_speed: float = 100.0         # px/s — between sneak and walk

@export_group("Ground Physics")
@export var ground_acceleration: float = 800.0  # px/s²
@export var ground_deceleration: float = 600.0  # px/s²
@export var slide_trigger_speed: float = 300.0  # px/s — speed above which slide activates
@export var slide_friction: float = 80.0         # px/s² — deceleration during slide

@export_group("Jump")
@export var hop_velocity: float = 280.0          # px/s — tap jump
@export var jump_velocity: float = 480.0         # px/s — full held jump
@export var jump_hold_force: float = 900.0       # px/s² — additive while held
@export var jump_hold_window: int = 12           # max frames of additive hold
@export var double_jump_velocity: float = 380.0  # px/s
@export var double_jump_redirect_factor: float = 0.45  # lerp factor at double jump
@export var gravity: float = 980.0              # px/s² — matches Godot 2D default
@export var fall_velocity_max: float = 900.0    # px/s — terminal velocity clamp
@export var air_control_force: float = 260.0    # px/s²
@export var post_double_jump_air_control: float = 30.0  # px/s²

@export_group("Jump Timing (frames)")
@export var coyote_time_frames: int = 5          # bonnie-traversal §7 + input-system §7
@export var jump_buffer_frames: int = 6          # pre-land buffer
@export var double_jump_window_frames: int = 40  # frames after apex where double jump is valid
@export var parry_window_frames: int = 6         # tight grab timing window

@export_group("Ledge and Climb")
@export var parry_detection_radius: float = 24.0  # px — must be near geometry for parry
@export var wall_jump_velocity: float = 360.0      # px/s perpendicular to surface
@export var pullup_duration_frames: int = 10       # frames BONNIE is locked during pullup
@export var climb_claw_impulse: float = 180.0      # px/s — burst speed per E press while climbing
@export var climb_claw_burst_frames: int = 4       # frames the burst lasts
@export var claw_brake_multiplier: float = 0.30    # fraction of slide speed removed per E tap (0.30 = ~3 taps to stop)
@export var pullup_pop_velocity: float = 260.0     # px/s horizontal on directional pop
@export var pullup_pop_vertical: float = 200.0     # px/s upward on directional pop

@export_group("Landing")
@export var clean_land_threshold: float = 80.0    # px/s — below this = always clean landing
@export var skid_threshold: float = 180.0         # px/s — speed above which skid fires
@export var hard_skid_threshold: float = 320.0    # px/s
@export var skid_friction_multiplier: float = 0.15  # multiplier on deceleration during skid (very slippery)
@export var skid_base_duration: float = 0.6       # seconds at run_max_speed (scales with speed)
@export var hard_skid_base_duration: float = 1.1  # hard skid duration at full speed
@export var rough_landing_threshold: float = 144.0  # px of fall distance to trigger ROUGH_LANDING

@export_group("Recovery")
@export var daze_duration: float = 1.0           # seconds
@export var daze_collision_threshold: float = 280.0  # slide speed at which wall hit dazes BONNIE
@export var rough_landing_duration: float = 2.5  # seconds

@export_group("Input Thresholds")
# From design/gdd/input-system.md §3.3 and §7.
@export var stick_deadzone: float = 0.2
@export var sneak_threshold: float = 0.35        # stick magnitude below this = auto-sneak
@export var trigger_deadzone: float = 0.1        # LT/RT minimum for sneak/zoom

# --- Node References ---------------------------------------------------------

@onready var _parry_cast: ShapeCast2D = $ParryCast
@onready var _ceiling_cast: RayCast2D = $CeilingCast
@onready var _debug_label: RichTextLabel = $DebugHUD/DebugLabel
@onready var _main_shape: CollisionShape2D = $CollisionShape2D
@onready var _squeeze_shape: CollisionShape2D = $SqueezeShape
@onready var _sprite: ColorRect = $PlaceholderSprite

# --- Runtime State -----------------------------------------------------------

var current_state: State = State.IDLE
var facing_direction: float = 1.0               # 1.0 = right, -1.0 = left

# Fall tracking — for ROUGH_LANDING detection
var fall_distance: float = 0.0
var fall_origin_y: float = 0.0

# Input buffering (frame counters, count down each physics frame)
var jump_buffer_timer: int = 0
var coyote_timer: int = 0

# Double jump
var double_jump_available: bool = true
var double_jump_window_timer: int = 0

# Landing skid
var in_skid_window: bool = false

# Jump hold (duration-based, not pressure-based — see input-system §3.3)
var is_jump_held: bool = false

# Recovery timers (seconds)
var _daze_timer: float = 0.0
var _rough_landing_timer: float = 0.0

# --- Private Runtime State ---------------------------------------------------

var _post_double_jumped: bool = false
var _was_on_floor_last_frame: bool = false
var _at_apex: bool = false
var _ledge_pullup_timer: float = 0.0
var _landing_impact_speed: float = 0.0
var _jump_hold_timer: int = 0  # frame counter for hold (distinct from legacy float above)
var _skid_timer: float = 0.0
var _skid_is_hard: bool = false
var _parry_window_timer: int = 0  # countdown: frames remaining in parry window
var _parry_cast_was_colliding: bool = false  # track new proximity entries
var _claw_burst_timer: int = 0      # frames remaining in E-press climbing burst
var _pullup_direction: float = 0.0  # directional input captured during LEDGE_PULLUP window
var _squeeze_zone_active: bool = false  # true while BONNIE is inside SqueezeTrigger Area2D

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	var squeeze_trigger: Node = get_tree().get_first_node_in_group(&"SqueezeTrigger")
	if squeeze_trigger:
		squeeze_trigger.body_entered.connect(_on_squeeze_trigger_entered)
		squeeze_trigger.body_exited.connect(_on_squeeze_trigger_exited)


func _physics_process(delta: float) -> void:
	# Track floor state before movement so coyote logic sees the previous frame.
	_was_on_floor_last_frame = is_on_floor()

	# --- Tick-down frame counters ---
	if jump_buffer_timer > 0:
		jump_buffer_timer -= 1
	if coyote_timer > 0:
		coyote_timer -= 1
	if double_jump_window_timer > 0:
		double_jump_window_timer -= 1
	if _parry_window_timer > 0:
		_parry_window_timer -= 1

	# --- Buffer jump input this frame ---
	if Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = jump_buffer_frames

	# --- Dispatch to per-state handler ---
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

	# --- Parry proximity tracking (open window when entering detection zone) ---
	var _parry_colliding_now: bool = _parry_cast.is_colliding() and _has_wall_or_ledge_collision()
	if _parry_colliding_now and not _parry_cast_was_colliding:
		_parry_window_timer = parry_window_frames
	_parry_cast_was_colliding = _parry_colliding_now

	# --- Debug HUD ---
	_update_debug_hud()

# =============================================================================
# INPUT
# =============================================================================

func _get_input_vector() -> Vector2:
	# Use StringName literals (&"...") per Godot 4.6 requirements.
	# stick_deadzone passed as the deadzone parameter — normalises output
	# and filters sub-threshold drift from analog sticks.
	# See input-system.md §4 formula.
	return Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down",
		stick_deadzone
	)


func _is_auto_sneaking(input_vec: Vector2) -> bool:
	# Returns true when analog stick is in motion but below sneak_threshold.
	# Always false on keyboard (digital magnitude = 1.0). See input-system §4.
	var magnitude: float = input_vec.length()
	return magnitude > stick_deadzone and magnitude < sneak_threshold

# =============================================================================
# STATE MACHINE
# =============================================================================

func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return

	var old_state: State = current_state

	# --- Exit logic for old state ---
	match old_state:
		State.JUMPING, State.FALLING:
			# Reset fall tracking on landing
			fall_distance = 0.0
			fall_origin_y = 0.0
		State.SLIDING:
			in_skid_window = false
		State.SQUEEZING:
			# Restore full collision shape and sprite when leaving SQUEEZING.
			_squeeze_shape.disabled = true
			_main_shape.disabled = false
			_sprite.offset_left = -8.0
			_sprite.offset_right = 8.0
			_sprite.offset_top = -16.0
			_sprite.offset_bottom = 16.0
		_:
			pass

	# --- Entry logic for new state ---
	match new_state:
		State.SQUEEZING:
			# Swap to smaller collision shape (20px) and reshape sprite to crawling-cat silhouette:
			# wide and flat (24px wide × 8px tall) vs normal upright (16px wide × 32px tall).
			# Shape offset is +14px down so bottom stays floor-aligned (no floating on swap).
			_main_shape.disabled = true
			_squeeze_shape.disabled = false
			_sprite.offset_left = -12.0
			_sprite.offset_right = 12.0
			_sprite.offset_top = -4.0
			_sprite.offset_bottom = 4.0
		State.FALLING:
			# Begin tracking fall distance for ROUGH_LANDING detection.
			fall_origin_y = global_position.y
		State.JUMPING:
			is_jump_held = true
			_jump_hold_timer = 0
			double_jump_available = true
			double_jump_window_timer = 0
			_at_apex = false
			_post_double_jumped = false
		State.LANDING:
			# _landing_impact_speed set by _on_landed() before _change_state is called.
			in_skid_window = false  # will be set true in _handle_landing if speed warrants
		State.LEDGE_PULLUP:
			_ledge_pullup_timer = pullup_duration_frames / 60.0
			_pullup_direction = 0.0
			velocity = Vector2.ZERO
		State.DAZED:
			_daze_timer = daze_duration
		State.ROUGH_LANDING:
			_rough_landing_timer = rough_landing_duration
		_:
			pass

	current_state = new_state
	emit_signal(&"state_changed", old_state, new_state)


# =============================================================================
# PER-STATE HANDLERS
# Gravity is applied explicitly via _apply_gravity() in airborne states.
# =============================================================================

func _handle_idle(delta: float) -> void:
	# Bleed off any residual velocity.
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)

	# Coyote time — if left ground without a jump, start timer and fall.
	if not is_on_floor() and _was_on_floor_last_frame:
		coyote_timer = coyote_time_frames
		_change_state(State.FALLING)
		return

	# Ground climbing — grab near Climbable surface.
	if _try_ground_climb():
		return

	# Squeeze detection — low ceiling auto-trigger.
	if _check_squeeze_entry():
		return

	# Jump check (coyote time included — handled in FALLING if coyote active).
	if (Input.is_action_just_pressed(&"jump") or jump_buffer_timer > 0) and is_on_floor():
		jump_buffer_timer = 0
		velocity.y = -hop_velocity
		_change_state(State.JUMPING)
		return

	# Input → transitions
	var input_vec: Vector2 = _get_input_vector()
	if input_vec.x != 0.0:
		if _is_auto_sneaking(input_vec) or Input.is_action_pressed(&"sneak"):
			_change_state(State.SNEAKING)
		elif Input.is_action_pressed(&"run"):
			_change_state(State.RUNNING)
		else:
			_change_state(State.WALKING)


func _handle_sneaking(delta: float) -> void:
	var input_vec: Vector2 = _get_input_vector()
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)
	var target_speed: float = input_vec.x * sneak_max_speed
	velocity.x = move_toward(velocity.x, target_speed, ground_acceleration * delta)

	if not is_on_floor():
		_change_state(State.FALLING)
		return
	if _try_ground_climb():
		return
	if _check_squeeze_entry():
		return
	if Input.is_action_just_pressed(&"jump") or jump_buffer_timer > 0:
		jump_buffer_timer = 0
		velocity.y = -hop_velocity
		_change_state(State.JUMPING)
		return
	if input_vec.x == 0.0:
		_change_state(State.IDLE)
		return
	if not _is_auto_sneaking(input_vec) and not Input.is_action_pressed(&"sneak"):
		_change_state(State.WALKING)


func _handle_walking(delta: float) -> void:
	var input_vec: Vector2 = _get_input_vector()
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)

	var target_speed: float = input_vec.x * walk_speed
	velocity.x = move_toward(velocity.x, target_speed, ground_acceleration * delta)

	if not is_on_floor():
		coyote_timer = coyote_time_frames
		_change_state(State.FALLING)
		return
	if _try_ground_climb():
		return
	if _check_squeeze_entry():
		return
	if Input.is_action_just_pressed(&"jump") or jump_buffer_timer > 0:
		jump_buffer_timer = 0
		velocity.y = -hop_velocity
		_change_state(State.JUMPING)
		return
	if _is_auto_sneaking(input_vec) or Input.is_action_pressed(&"sneak"):
		_change_state(State.SNEAKING)
		return
	if Input.is_action_pressed(&"run") and input_vec.x != 0.0:
		_change_state(State.RUNNING)
		return
	if input_vec.x == 0.0:
		_change_state(State.IDLE)


func _handle_running(delta: float) -> void:
	var input_vec: Vector2 = _get_input_vector()
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)

	# Slide triggers — opposing input at speed, or explicit move_down at speed.
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

	var target_speed: float = input_vec.x * run_max_speed
	velocity.x = move_toward(velocity.x, target_speed, ground_acceleration * delta)

	if not is_on_floor():
		coyote_timer = coyote_time_frames
		_change_state(State.FALLING)
		return
	if _try_ground_climb():
		return
	if _check_squeeze_entry():
		return
	if Input.is_action_just_pressed(&"jump") or jump_buffer_timer > 0:
		jump_buffer_timer = 0
		velocity.y = -hop_velocity
		_change_state(State.JUMPING)
		return
	if not Input.is_action_pressed(&"run"):
		_change_state(State.WALKING)
		return
	if abs(velocity.x) < walk_speed and input_vec.x == 0.0:
		_change_state(State.IDLE)


func _handle_sliding(delta: float) -> void:
	var input_vec: Vector2 = _get_input_vector()

	# Constant friction deceleration.
	velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)

	# Slight steer — can nudge in direction of travel only, cannot reverse.
	if input_vec.x != 0.0 and sign(input_vec.x) == sign(velocity.x):
		velocity.x = move_toward(velocity.x, input_vec.x * run_max_speed, slide_friction * 0.5 * delta)

	# Claw brake — E tap during slide: speed-dependent friction spike.
	# Staccato tapping scrubs speed in chunks; holding applies once per press.
	if Input.is_action_just_pressed(&"grab"):
		var brake: float = abs(velocity.x) * claw_brake_multiplier
		velocity.x = move_toward(velocity.x, 0.0, brake)

	# Pop-jump — full momentum carries, velocity.x untouched.
	if Input.is_action_just_pressed(&"jump") or jump_buffer_timer > 0:
		jump_buffer_timer = 0
		velocity.y = -jump_velocity
		_change_state(State.JUMPING)
		return

	# Slide into Climbable surface — auto-grab.
	if _try_slide_auto_climb():
		return

	# Wall daze — slide into wall above threshold.
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
	# Clamp to terminal velocity (negative = upward, so clamp the upward ceiling separately).
	velocity.y = max(velocity.y, -fall_velocity_max)

	# Jump hold — additive upward force while held, capped at jump_velocity.
	if is_jump_held and Input.is_action_pressed(&"jump"):
		_jump_hold_timer += 1
		if _jump_hold_timer <= jump_hold_window:
			velocity.y -= jump_hold_force * delta
			velocity.y = max(velocity.y, -jump_velocity)
		else:
			is_jump_held = false
	elif not Input.is_action_pressed(&"jump"):
		is_jump_held = false

	# Apex detection — velocity.y crosses from negative to zero or positive.
	if velocity.y >= 0.0 and not _at_apex:
		_at_apex = true
		double_jump_window_timer = double_jump_window_frames

	# Double jump — after apex, within window.
	if _at_apex and double_jump_available and double_jump_window_timer > 0:
		if Input.is_action_just_pressed(&"jump"):
			velocity.y = -double_jump_velocity
			velocity.x = lerpf(velocity.x, _get_input_vector().x * run_max_speed, double_jump_redirect_factor)
			double_jump_available = false
			_post_double_jumped = true
			double_jump_window_timer = 0

	# Air control.
	var input_vec: Vector2 = _get_input_vector()
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

	var input_vec: Vector2 = _get_input_vector()
	var air_ctrl: float = post_double_jump_air_control if _post_double_jumped else air_control_force
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)
		velocity.x = move_toward(velocity.x, input_vec.x * run_max_speed, air_ctrl * delta)

	# Coyote jump — treat as a normal first jump, not double jump.
	if coyote_timer > 0 and Input.is_action_just_pressed(&"jump"):
		coyote_timer = 0
		jump_buffer_timer = 0
		velocity.y = -hop_velocity
		is_jump_held = true
		_jump_hold_timer = 0
		_post_double_jumped = false
		_at_apex = false
		_change_state(State.JUMPING)
		return

	# Double jump available while falling (e.g., fell off a ledge, no jump used).
	if double_jump_available and coyote_timer <= 0 and Input.is_action_just_pressed(&"jump"):
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

	# Soft landing surfaces reset fall distance (Zone 4 — fall → LANDING not ROUGH_LANDING)
	var _floor_col: KinematicCollision2D = get_last_slide_collision()
	if _floor_col:
		var _floor_body: Object = _floor_col.get_collider()
		if _floor_body and _floor_body.is_in_group(&"soft_landing"):
			fall_distance = 0.0

	if fall_distance >= rough_landing_threshold:
		_change_state(State.ROUGH_LANDING)
		fall_distance = 0.0
		return

	fall_distance = 0.0

	# Jump buffer fires on landing — instant re-launch.
	if jump_buffer_timer > 0:
		jump_buffer_timer = 0
		velocity.y = -hop_velocity
		_change_state(State.JUMPING)
		return

	_change_state(State.LANDING)


func _handle_landing(delta: float) -> void:
	# Determine skid type from _landing_impact_speed on first entry.
	if not in_skid_window and _landing_impact_speed > 0.0:
		if _landing_impact_speed >= hard_skid_threshold:
			in_skid_window = true
			_skid_is_hard = true
			_skid_timer = (_landing_impact_speed / run_max_speed) * hard_skid_base_duration
		elif _landing_impact_speed >= skid_threshold:
			in_skid_window = true
			_skid_is_hard = false
			_skid_timer = (_landing_impact_speed / run_max_speed) * skid_base_duration
		_landing_impact_speed = 0.0  # consumed

	if in_skid_window:
		_skid_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * skid_friction_multiplier * delta)

		# Pop-jump during skid — velocity.x untouched (full momentum carries).
		if Input.is_action_just_pressed(&"jump") or jump_buffer_timer > 0:
			jump_buffer_timer = 0
			velocity.y = -hop_velocity
			in_skid_window = false
			_change_state(State.JUMPING)
			return

		if _skid_timer <= 0.0 or abs(velocity.x) < walk_speed:
			in_skid_window = false
			_change_state(State.IDLE)
	else:
		# Clean landing — bleed to stop and hand back control.
		velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
		_change_state(State.IDLE)


func _handle_climbing(_delta: float) -> void:
	var input_vec: Vector2 = _get_input_vector()

	# E-grab: cat scramble burst — each press launches BONNIE upward with a velocity spike.
	if Input.is_action_just_pressed(&"grab"):
		_claw_burst_timer = climb_claw_burst_frames

	# Vertical movement: claw burst overrides normal climb speed for tactile scramble feel.
	if _claw_burst_timer > 0:
		_claw_burst_timer -= 1
		velocity.y = -climb_claw_impulse
	else:
		velocity.y = 0.0
		if input_vec.y != 0.0:
			velocity.y = input_vec.y * climb_speed

	# Horizontal input detaches BONNIE from the surface.
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)
		velocity.x = input_vec.x * walk_speed
		_change_state(State.FALLING)
		return

	velocity.x = 0.0

	# Wall jump — perpendicular to surface, resets double jump.
	if Input.is_action_just_pressed(&"jump"):
		velocity.x = facing_direction * -1.0 * wall_jump_velocity
		velocity.y = -wall_jump_velocity
		double_jump_available = true
		_post_double_jumped = false
		_change_state(State.JUMPING)
		return

	# Auto-clamber at top — BONNIE pops over when she reaches the top of the surface.
	# is_on_ceiling() handles it normally; slide-normal fallback catches geometry edge cases.
	var at_top: bool = is_on_ceiling()
	if not at_top:
		for i: int in get_slide_collision_count():
			var col: KinematicCollision2D = get_slide_collision(i)
			if col.get_normal().y > 0.5:  # hit something from below (ceiling-like)
				at_top = true
				break
	if at_top:
		_change_state(State.LEDGE_PULLUP)
		return

	# Drop: move_down held while descending past bottom of surface.
	if Input.is_action_pressed(&"move_down") and velocity.y > 0.0 and not is_on_floor():
		_change_state(State.FALLING)
		return


func _handle_squeezing(delta: float) -> void:
	var input_vec: Vector2 = _get_input_vector()
	if input_vec.x != 0.0:
		facing_direction = sign(input_vec.x)
	velocity.x = move_toward(velocity.x, input_vec.x * squeeze_speed, ground_acceleration * delta)

	# Exit when BONNIE leaves the squeeze zone (trigger body_exited cleared the flag).
	if not _squeeze_zone_active:
		_change_state(State.IDLE)
		return

	if not is_on_floor():
		_change_state(State.FALLING)


func _handle_dazed(delta: float) -> void:
	# BONNIE is incapacitated — no movement input accepted.
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
	_daze_timer -= delta
	if _daze_timer <= 0.0:
		_change_state(State.IDLE)


func _handle_rough_landing(delta: float) -> void:
	# BONNIE is down — no movement input accepted.
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
	_rough_landing_timer -= delta
	# TODO: Nine Lives system hook fires here (see bonnie-traversal §8 AC-T06c).
	if _rough_landing_timer <= 0.0:
		_change_state(State.IDLE)


func _handle_ledge_pullup(delta: float) -> void:
	# Phase 1 — cling window: BONNIE hangs on the ledge, reads directional input.
	# Last held direction during the window becomes the pop direction.
	velocity = Vector2.ZERO
	var input_vec: Vector2 = _get_input_vector()
	if input_vec.x != 0.0:
		_pullup_direction = sign(input_vec.x)

	_ledge_pullup_timer -= delta
	if _ledge_pullup_timer > 0.0:
		return

	# Phase 2 — resolve: directional pop or clean stationary pullup.
	if _pullup_direction != 0.0:
		# Momentum-carry pop: launch in chosen direction with approach energy.
		facing_direction = _pullup_direction
		velocity.x = _pullup_direction * pullup_pop_velocity
		velocity.y = -pullup_pop_vertical
		_post_double_jumped = false
		_change_state(State.JUMPING)
	else:
		# Clean pullup: land stationary on top of surface.
		_change_state(State.IDLE)


# =============================================================================
# PHYSICS HELPERS
# =============================================================================


func _try_airborne_climb() -> bool:
	## Mid-air grab onto Climbable — hold grab while contacting wall to start climbing.
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


# =============================================================================
# GROUND-BASED CLIMBING + SQUEEZING DETECTION
# =============================================================================

func _try_ground_climb() -> bool:
	# Enter CLIMBING from ground states when grab is held near a Climbable surface.
	# Checks ParryCast first; falls back to slide collision (catches running-into-wall case).
	if not Input.is_action_pressed(&"grab"):
		return false
	# ParryCast path — proximity detection.
	if _parry_cast.is_colliding():
		for i: int in _parry_cast.get_collision_count():
			var collider: Object = _parry_cast.get_collider(i)
			if collider and collider.is_in_group(&"Climbable"):
				double_jump_available = true
				_post_double_jumped = false
				_change_state(State.CLIMBING)
				return true
	# Slide collision fallback — catches running directly into wall with grab held.
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
	# During SLIDING, auto-grab Climbable surfaces on collision (no grab input needed).
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
	# Enter SQUEEZING when BONNIE is inside the SqueezeTrigger Area2D and on the ground.
	# Flag is set/cleared by body_entered / body_exited signals from the trigger.
	if _squeeze_zone_active and is_on_floor():
		_change_state(State.SQUEEZING)
		return true
	return false


func _has_wall_or_ledge_collision() -> bool:
	# Returns true if ParryCast is detecting a wall or ledge (not just the floor).
	# Filters out collisions where the contact is directly below BONNIE.
	for i: int in _parry_cast.get_collision_count():
		var point: Vector2 = _parry_cast.get_collision_point(i)
		var delta_y: float = point.y - global_position.y
		# If contact point is more than 12px below BONNIE's center, it's likely floor.
		if delta_y < 12.0:
			return true
	return false


func _apply_gravity(delta: float) -> void:
	# Applies gravity when BONNIE is airborne.
	# Only call from JUMPING and FALLING handlers.
	if not is_on_floor():
		velocity.y += gravity * delta


func _check_ledge_parry() -> void:
	# Valid during FALLING or JUMPING only. grab has NO buffer — frame-exact.
	if not Input.is_action_just_pressed(&"grab"):
		return

	# Must be within the temporal parry window (opened when entering proximity zone).
	if _parry_window_timer <= 0:
		return  # Outside window — missed timing.

	if not _parry_cast.is_colliding():
		return  # Nothing within parry_detection_radius.

	# Directional filter: ignore collisions that are directly below (floor).
	if not _has_wall_or_ledge_collision():
		return

	# Check what we hit — Climbable group = CLIMBING, anything else = LEDGE_PULLUP.
	for i: int in _parry_cast.get_collision_count():
		var collider: Object = _parry_cast.get_collider(i)
		if collider == null:
			continue
		# Skip floor-like contacts (collision point well below BONNIE's center).
		var point: Vector2 = _parry_cast.get_collision_point(i)
		if point.y - global_position.y >= 12.0:
			continue
		if collider.is_in_group(&"Climbable"):
			double_jump_available = true  # reset on climbable contact
			_post_double_jumped = false
			_parry_window_timer = 0
			_change_state(State.CLIMBING)
			return
		else:
			# Platform edge — lock position and pull up.
			_parry_window_timer = 0
			_change_state(State.LEDGE_PULLUP)
			return


# =============================================================================
# DEBUG HUD
# =============================================================================

const _STATE_COLORS: Dictionary = {
	State.IDLE:         Color(0.7, 0.7, 0.7),
	State.SNEAKING:     Color(0.4, 0.8, 0.4),
	State.WALKING:      Color(0.6, 0.9, 0.6),
	State.RUNNING:      Color(0.2, 1.0, 0.2),
	State.SLIDING:      Color(1.0, 0.8, 0.0),
	State.JUMPING:      Color(0.4, 0.7, 1.0),
	State.FALLING:      Color(0.3, 0.5, 1.0),
	State.LANDING:      Color(0.8, 0.6, 1.0),
	State.CLIMBING:     Color(0.9, 0.5, 0.2),
	State.SQUEEZING:    Color(0.2, 0.9, 0.9),
	State.DAZED:        Color(1.0, 0.3, 0.3),
	State.ROUGH_LANDING:Color(1.0, 0.1, 0.1),
	State.LEDGE_PULLUP: Color(1.0, 1.0, 0.3),
}

func _update_debug_hud() -> void:
	var speed: float = abs(velocity.x)
	var state_name: String = State.keys()[current_state]
	var col: Color = _STATE_COLORS.get(current_state, Color.WHITE)

	var lines: Array[String] = [
		"[color=#%s]STATE: %s[/color]" % [col.to_html(false), state_name],
		"vx: %4.0f  vy: %4.0f  spd: %4.0f" % [velocity.x, velocity.y, speed],
		"─────────────────────────────────",
		"slide_trigger: %d  (need >%d)" % [int(speed), int(slide_trigger_speed)],
		"run_max:       %d" % int(run_max_speed),
		"─────────────────────────────────",
		"coyote:  %d/%d" % [coyote_timer, coyote_time_frames],
		"jbuffer: %d/%d" % [jump_buffer_timer, jump_buffer_frames],
		"parry_w: %d/%d" % [_parry_window_timer, parry_window_frames],
		"dbl_jmp: %s  (window: %d)" % ["YES" if double_jump_available else " no", double_jump_window_timer],
		"─────────────────────────────────",
		"fall_dist: %3.0f  (rough@%d)" % [fall_distance, int(rough_landing_threshold)],
		"daze: %.1fs" % _daze_timer if current_state == State.DAZED else "daze: —",
		"rough: %.1fs" % _rough_landing_timer if current_state == State.ROUGH_LANDING else "rough: —",
		"─────────────────────────────────",
		"facing: %s" % ("→" if facing_direction > 0 else "←"),
		"parry_prox: %s  ceil: %s" % [
			"YES" if _parry_cast.is_colliding() else " no",
			"YES" if _ceiling_cast.is_colliding() else " no",
		],
		"[GRAB=E  SNEAK=Ctrl  RUN=Shift]",
		"[SLIDE: run+S or run+reverse dir]",
	]
	_debug_label.text = "\n".join(lines)


# =============================================================================
# SIGNAL CALLBACKS
# =============================================================================

func _on_squeeze_trigger_entered(body: Node) -> void:
	# Just set the flag — safe from a physics signal (no shape mutation here).
	# _check_squeeze_entry() reads the flag each frame and calls _change_state()
	# from within _physics_process, where shape changes are allowed.
	if body == self:
		_squeeze_zone_active = true


func _on_squeeze_trigger_exited(body: Node) -> void:
	if body == self:
		_squeeze_zone_active = false

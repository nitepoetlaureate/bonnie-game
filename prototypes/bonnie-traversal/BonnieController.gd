class_name BonnieController
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

@export_group("Ground Physics")
@export var ground_acceleration: float = 800.0  # px/s²
@export var ground_deceleration: float = 600.0  # px/s²
@export var slide_trigger_speed: float = 300.0  # px/s — speed above which slide activates
@export var slide_friction: float = 80.0         # px/s² — deceleration during slide

@export_group("Jump")
@export var hop_velocity: float = 280.0          # px/s — tap jump
@export var jump_velocity: float = 480.0         # px/s — full held jump
@export var double_jump_velocity: float = 380.0  # px/s
@export var gravity: float = 980.0              # px/s² — matches Godot 2D default
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

@export_group("Landing")
@export var skid_threshold: float = 180.0         # px/s — speed above which skid fires
@export var hard_skid_threshold: float = 320.0    # px/s
@export var skid_friction_multiplier: float = 0.85  # velocity multiplier per frame during skid
@export var rough_landing_threshold: float = 144.0  # px of fall distance to trigger ROUGH_LANDING

@export_group("Recovery")
@export var daze_duration: float = 1.0           # seconds
@export var rough_landing_duration: float = 2.5  # seconds

@export_group("Input Thresholds")
# From design/gdd/input-system.md §3.3 and §7.
@export var stick_deadzone: float = 0.2
@export var sneak_threshold: float = 0.35        # stick magnitude below this = auto-sneak
@export var trigger_deadzone: float = 0.1        # LT/RT minimum for sneak/zoom

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
var skid_timer: float = 0.0

# Jump hold (duration-based, not pressure-based — see input-system §3.3)
var jump_hold_timer: float = 0.0
var is_jump_held: bool = false

# Recovery timers (seconds)
var _daze_timer: float = 0.0
var _rough_landing_timer: float = 0.0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Ensure gravity is read from project settings if not overridden.
	# TODO: decide whether to read from ProjectSettings or keep @export default.
	pass


func _physics_process(delta: float) -> void:
	# --- Tick-down frame counters ---
	if jump_buffer_timer > 0:
		jump_buffer_timer -= 1
	if coyote_timer > 0:
		coyote_timer -= 1
	if double_jump_window_timer > 0:
		double_jump_window_timer -= 1

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
		_:
			pass

	# --- Entry logic for new state ---
	match new_state:
		State.FALLING:
			# Begin tracking fall distance for ROUGH_LANDING detection.
			fall_origin_y = global_position.y
		State.JUMPING:
			is_jump_held = true
			jump_hold_timer = 0.0
			double_jump_available = true
			double_jump_window_timer = 0
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
	# TODO: Apply ground deceleration to bleed off any residual velocity.
	# TODO: Check input vector — transition to SNEAKING, WALKING, or JUMPING.
	# TODO: Start coyote timer if no longer on floor (walked off ledge).
	pass


func _handle_sneaking(delta: float) -> void:
	# TODO: Apply movement up to sneak_max_speed using ground_acceleration.
	# TODO: Transition to IDLE (no input), WALKING (sneak released + input),
	#       JUMPING (jump input).
	# TODO: Stimulus radius is sneak_stimulus_radius — NPCs barely notice.
	pass


func _handle_walking(delta: float) -> void:
	# TODO: Apply movement up to walk_speed using ground_acceleration.
	# TODO: Transition to SNEAKING (_is_auto_sneaking or sneak held),
	#       RUNNING (run button held), SLIDING (opposing input + speed check),
	#       JUMPING (jump input or buffered jump), FALLING (left ground).
	pass


func _handle_running(delta: float) -> void:
	# TODO: Apply movement up to run_max_speed using ground_acceleration.
	# TODO: Slide trigger: move_down pressed + speed > slide_trigger_speed → SLIDING.
	# TODO: Opposing input at high speed → SLIDING.
	# TODO: Transition to WALKING (run released), JUMPING, FALLING.
	pass


func _handle_sliding(delta: float) -> void:
	# TODO: Apply slide_friction deceleration each frame (constant rate).
	# TODO: Minimal air steering while sliding.
	# TODO: Jump input during slide → JUMPING with full horizontal momentum.
	# TODO: Wall collision at high speed (daze_collision_threshold) → DAZED.
	# TODO: Transition to IDLE/WALKING when speed falls below slide_trigger_speed.
	pass


func _handle_jumping(delta: float) -> void:
	_apply_gravity(delta)

	# Jump hold: extend height if held, commit to hop if tapped.
	# TODO: measure jump_hold_timer; cap at jump_hold_window frames.
	# TODO: Double jump: available within double_jump_window_frames after apex.
	# TODO: Coyote timer: not applicable in JUMPING (only after walking off edge).
	# TODO: Parry check: _check_ledge_parry() while near geometry.
	# TODO: Transition to FALLING (apex passed), CLIMBING/LEDGE_PULLUP (parry).

	_check_ledge_parry()


func _handle_falling(delta: float) -> void:
	_apply_gravity(delta)

	# Track cumulative fall distance for ROUGH_LANDING detection.
	fall_distance = global_position.y - fall_origin_y

	# TODO: Air control at air_control_force (post-double-jump at lower value).
	# TODO: Parry check during FALLING.
	# TODO: On landing (is_on_floor()): check fall_distance vs rough_landing_threshold.
	#       fall_distance > rough_landing_threshold → ROUGH_LANDING.
	#       Otherwise → LANDING (check skid_threshold for skid type).
	# TODO: Buffered jump fires on landing contact (jump_buffer_timer > 0).

	_check_ledge_parry()


func _handle_landing(delta: float) -> void:
	# TODO: Determine skid type from landing velocity:
	#       < skid_threshold → clean landing → IDLE or WALKING.
	#       >= skid_threshold and < hard_skid_threshold → skid.
	#       >= hard_skid_threshold → hard skid (more deceleration, longer).
	# TODO: Apply skid_friction_multiplier per frame during skid window.
	# TODO: Jump input during skid → JUMPING with full horizontal momentum.
	# TODO: Transition to IDLE/WALKING when skid velocity drains.
	pass


func _handle_climbing(delta: float) -> void:
	# TODO: Vertical movement at climb_speed (W = up, S = down).
	# TODO: Reaching top edge → LEDGE_PULLUP (auto-clamber, no grab input needed).
	#       Note: bonnie-traversal §3.1 says IDLE here — input-system §3.1 correction:
	#       reaching top = LEDGE_PULLUP. See open question in input-system.md.
	# TODO: Reaching bottom edge past surface → FALLING.
	# TODO: Jump input → wall jump (perpendicular to surface, wall_jump_velocity).
	# TODO: Double jump resets on successful grab of climbable surface.
	pass


func _handle_squeezing(delta: float) -> void:
	# TODO: Move at squeeze_speed.
	# TODO: Camera locks to room center while in this state (no character tracking).
	#       Camera reads current_state — this is handled camera-side.
	# TODO: Transition to IDLE/WALKING on exit from squeeze passage.
	pass


func _handle_dazed(delta: float) -> void:
	# BONNIE is incapacitated — no movement input accepted.
	_daze_timer -= delta
	# TODO: Play daze animation (loop until timer expires).
	if _daze_timer <= 0.0:
		_change_state(State.IDLE)


func _handle_rough_landing(delta: float) -> void:
	# BONNIE is down — no movement input accepted.
	_rough_landing_timer -= delta
	# TODO: Play rough landing animation (dazed stars, slow recovery).
	# TODO: Nine Lives system hook fires here (see bonnie-traversal §8 AC-T06c).
	if _rough_landing_timer <= 0.0:
		_change_state(State.IDLE)


func _handle_ledge_pullup(delta: float) -> void:
	# TODO: Play LEDGE_PULLUP animation (pullup_duration frames).
	# TODO: Lock position to ledge anchor point during animation.
	# TODO: Transition to IDLE on animation complete.
	# Camera look-ahead: 60px toward the surface (reads current_state = LEDGE_PULLUP).
	pass


# =============================================================================
# PHYSICS HELPERS
# =============================================================================

func _apply_gravity(delta: float) -> void:
	# Applies gravity when BONNIE is airborne.
	# Only call from JUMPING and FALLING handlers.
	if not is_on_floor():
		velocity.y += gravity * delta


func _check_ledge_parry() -> void:
	# Valid during FALLING or JUMPING only (input-system §5 edge cases).
	# grab action has NO buffer — frame-exact timing only.
	# TODO: Raycast/shape-cast within parry_detection_radius.
	# TODO: If geometry found AND grab pressed this exact frame (just_pressed, not pressed):
	#       - Climbable surface → CLIMBING (wall parry)
	#       - Platform edge → LEDGE_PULLUP
	# TODO: grab outside parry_window_frames = miss, do nothing.
	# TODO: double_jump_available resets on successful grab of climbable surface.
	if not Input.is_action_just_pressed(&"grab"):
		return
	# TODO: implement proximity check and state transition.
	pass

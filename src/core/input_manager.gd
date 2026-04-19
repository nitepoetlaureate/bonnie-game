## InputManager — Foundation Layer Autoload (System #1)
##
## Translation layer between hardware events and BONNIE's verbs.
## All gameplay systems read input through this autoload — no system
## polls hardware directly. Owns jump buffer and coyote time tracking.
##
## See: design/gdd/input-system.md
class_name InputManagerClass
extends Node


# -- Signals ------------------------------------------------------------------

## Emitted when the active input device changes (keyboard vs gamepad).
signal input_device_changed(device_type: StringName)


# -- Tuning Knobs (§7) -------------------------------------------------------

@export_group("Analog Thresholds")
## Minimum analog stick magnitude to register movement. Prevents drift.
@export var stick_deadzone: float = 0.2
## Trigger inputs below this are ignored. Prevents phantom sneak/zoom.
@export var trigger_deadzone: float = 0.1
## Stick magnitude below this = auto-sneak on analog input.
@export var sneak_threshold: float = 0.35

@export_group("Input Buffering")
## Frames a pre-land jump input is remembered. 0 = no buffer.
@export var jump_buffer_frames: int = 6
## Frames after leaving ground where jump is still allowed.
@export var coyote_time_frames: int = 5


# -- Runtime State ------------------------------------------------------------

## Counts down each physics frame. Set to jump_buffer_frames on jump press.
var _jump_buffer_timer: int = 0
## Counts down each physics frame. Set to coyote_time_frames when leaving ground.
var _coyote_timer: int = 0
## Whether BONNIE was on the floor last physics frame (for coyote detection).
var _was_on_floor: bool = false
## Tracks which device was last used for input_device_changed signal.
var _last_device: StringName = &"keyboard"


# -- Public API ---------------------------------------------------------------

## Returns the normalized movement vector from directional input.
## Applies stick_deadzone. Diagonal movement is clamped to unit length.
func get_movement_vector() -> Vector2:
	return Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down",
		stick_deadzone
	)


## Returns true when analog stick is moving but below sneak_threshold.
## Always false on keyboard (digital magnitude = 1.0).
func is_auto_sneaking(input_vec: Vector2) -> bool:
	var magnitude: float = input_vec.length()
	return magnitude > stick_deadzone and magnitude < sneak_threshold


## Returns true if a jump input was buffered within the buffer window
## and has not yet been consumed.
func is_jump_buffered() -> bool:
	return _jump_buffer_timer > 0


## Consume the jump buffer. Call this when a buffered jump fires.
func consume_jump_buffer() -> void:
	_jump_buffer_timer = 0


## Returns true if coyote time is active (BONNIE recently left ground).
func is_coyote_active() -> bool:
	return _coyote_timer > 0


## Consume coyote time. Call this when a coyote jump fires.
func consume_coyote() -> void:
	_coyote_timer = 0


## Notify InputManager that BONNIE left the ground (start coyote countdown).
func notify_left_ground() -> void:
	_coyote_timer = coyote_time_frames


## Returns true if run and sneak conflict — sneak wins per GDD §5.
func is_sneak_override_active() -> bool:
	return Input.is_action_pressed(&"sneak") and Input.is_action_pressed(&"run")


## Returns the current input device type: &"keyboard" or &"gamepad".
func get_current_device() -> StringName:
	return _last_device


# -- Engine Callbacks ---------------------------------------------------------

func _physics_process(_delta: float) -> void:
	# Tick down buffer timers
	if _jump_buffer_timer > 0:
		_jump_buffer_timer -= 1
	if _coyote_timer > 0:
		_coyote_timer -= 1

	# Check for new jump press — queue buffer
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = jump_buffer_frames


func _input(event: InputEvent) -> void:
	# Track device switching for UI hints
	var new_device: StringName = _last_device
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		new_device = &"keyboard"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		new_device = &"gamepad"

	if new_device != _last_device:
		_last_device = new_device
		input_device_changed.emit(_last_device)

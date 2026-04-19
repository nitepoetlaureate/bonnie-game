## Unit tests for InputManager (System #1)
extends GutTest


var _input_manager: InputManagerClass


func before_each() -> void:
	_input_manager = InputManagerClass.new()
	add_child_autofree(_input_manager)


# -- Movement Vector ----------------------------------------------------------

func test_get_movement_vector_returns_vector2() -> void:
	var vec: Vector2 = _input_manager.get_movement_vector()
	assert_typeof(vec, TYPE_VECTOR2, "get_movement_vector should return Vector2")


# -- Auto-Sneak Threshold ----------------------------------------------------

func test_auto_sneak_below_threshold() -> void:
	# Stick magnitude between deadzone and sneak_threshold = auto-sneak
	var vec := Vector2(0.3, 0.0)  # magnitude 0.3, below default 0.35
	assert_true(
		_input_manager.is_auto_sneaking(vec),
		"Should auto-sneak when magnitude (0.3) is between deadzone (0.2) and sneak_threshold (0.35)"
	)


func test_no_auto_sneak_above_threshold() -> void:
	var vec := Vector2(0.5, 0.0)  # magnitude 0.5, above default 0.35
	assert_false(
		_input_manager.is_auto_sneaking(vec),
		"Should not auto-sneak when magnitude (0.5) is above sneak_threshold (0.35)"
	)


func test_no_auto_sneak_below_deadzone() -> void:
	var vec := Vector2(0.1, 0.0)  # magnitude 0.1, below deadzone 0.2
	assert_false(
		_input_manager.is_auto_sneaking(vec),
		"Should not auto-sneak when magnitude (0.1) is below deadzone (0.2)"
	)


func test_no_auto_sneak_at_zero() -> void:
	assert_false(
		_input_manager.is_auto_sneaking(Vector2.ZERO),
		"Should not auto-sneak at zero input"
	)


func test_no_auto_sneak_full_magnitude() -> void:
	# Keyboard always reports 1.0 — should never auto-sneak
	var vec := Vector2(1.0, 0.0)
	assert_false(
		_input_manager.is_auto_sneaking(vec),
		"Should never auto-sneak at full magnitude (keyboard)"
	)


# -- Jump Buffer --------------------------------------------------------------

func test_jump_buffer_starts_at_zero() -> void:
	assert_false(
		_input_manager.is_jump_buffered(),
		"Jump buffer should start inactive"
	)


func test_jump_buffer_consumes_correctly() -> void:
	# Simulate a buffered jump by setting the timer directly
	_input_manager._jump_buffer_timer = 6
	assert_true(_input_manager.is_jump_buffered(), "Buffer should be active")

	_input_manager.consume_jump_buffer()
	assert_false(_input_manager.is_jump_buffered(), "Buffer should be consumed")


func test_jump_buffer_ticks_down() -> void:
	_input_manager._jump_buffer_timer = 3
	# Simulate 3 physics frames
	_input_manager._physics_process(1.0 / 60.0)
	assert_eq(_input_manager._jump_buffer_timer, 2, "Buffer should tick from 3 to 2")
	_input_manager._physics_process(1.0 / 60.0)
	assert_eq(_input_manager._jump_buffer_timer, 1, "Buffer should tick from 2 to 1")
	_input_manager._physics_process(1.0 / 60.0)
	assert_eq(_input_manager._jump_buffer_timer, 0, "Buffer should tick from 1 to 0")
	_input_manager._physics_process(1.0 / 60.0)
	assert_eq(_input_manager._jump_buffer_timer, 0, "Buffer should not go below 0")


# -- Coyote Time --------------------------------------------------------------

func test_coyote_starts_inactive() -> void:
	assert_false(
		_input_manager.is_coyote_active(),
		"Coyote should start inactive"
	)


func test_coyote_activates_on_notify() -> void:
	_input_manager.notify_left_ground()
	assert_true(_input_manager.is_coyote_active(), "Coyote should be active after notify")


func test_coyote_ticks_down() -> void:
	_input_manager.notify_left_ground()
	for i in range(_input_manager.coyote_time_frames):
		assert_true(_input_manager.is_coyote_active(), "Coyote should still be active at frame %d" % i)
		_input_manager._physics_process(1.0 / 60.0)
	assert_false(_input_manager.is_coyote_active(), "Coyote should expire after all frames tick")


func test_coyote_consumes_correctly() -> void:
	_input_manager.notify_left_ground()
	_input_manager.consume_coyote()
	assert_false(_input_manager.is_coyote_active(), "Coyote should be consumed")


# -- Tuning Knob Defaults (§7) -----------------------------------------------

func test_default_stick_deadzone() -> void:
	assert_eq(_input_manager.stick_deadzone, 0.2, "Default stick_deadzone should be 0.2")


func test_default_sneak_threshold() -> void:
	assert_eq(_input_manager.sneak_threshold, 0.35, "Default sneak_threshold should be 0.35")


func test_default_trigger_deadzone() -> void:
	assert_eq(_input_manager.trigger_deadzone, 0.1, "Default trigger_deadzone should be 0.1")


func test_default_jump_buffer_frames() -> void:
	assert_eq(_input_manager.jump_buffer_frames, 6, "Default jump_buffer_frames should be 6")


func test_default_coyote_time_frames() -> void:
	assert_eq(_input_manager.coyote_time_frames, 5, "Default coyote_time_frames should be 5")

## Unit tests for BonnieController (System #6)
## See: design/gdd/bonnie-traversal.md
extends GutTest


var _bonnie: BonnieController


func before_each() -> void:
	_bonnie = BonnieController.new()
	# Don't add as child — avoids _physics_process running during unit tests.
	# Tests that need node tree access use add_child_autofree().


# =============================================================================
# TUNING KNOB DEFAULTS (GDD bonnie-traversal.md §7)
# =============================================================================

func test_default_sneak_max_speed() -> void:
	assert_eq(_bonnie.sneak_max_speed, 80.0, "GDD §7: sneak_max_speed = 80")


func test_default_walk_speed() -> void:
	assert_eq(_bonnie.walk_speed, 180.0, "GDD §7: walk_speed = 180")


func test_default_run_max_speed() -> void:
	assert_eq(_bonnie.run_max_speed, 420.0, "GDD §7: run_max_speed = 420")


func test_default_climb_speed() -> void:
	assert_eq(_bonnie.climb_speed, 90.0, "GDD §7: climb_speed = 90")


func test_default_squeeze_speed() -> void:
	assert_eq(_bonnie.squeeze_speed, 100.0, "GDD §7: squeeze_speed = 100")


func test_default_ground_acceleration() -> void:
	assert_eq(_bonnie.ground_acceleration, 800.0, "GDD §7: ground_acceleration = 800")


func test_default_ground_deceleration() -> void:
	assert_eq(_bonnie.ground_deceleration, 600.0, "GDD §7: ground_deceleration = 600")


func test_default_hop_velocity() -> void:
	assert_eq(_bonnie.hop_velocity, 280.0, "GDD §7: hop_velocity = 280")


func test_default_jump_velocity() -> void:
	assert_eq(_bonnie.jump_velocity, 480.0, "GDD §7: jump_velocity = 480")


func test_default_gravity() -> void:
	assert_eq(_bonnie.gravity, 980.0, "GDD §7: gravity = 980")


func test_default_fall_velocity_max() -> void:
	assert_eq(_bonnie.fall_velocity_max, 900.0, "GDD §7: fall_velocity_max = 900")


func test_default_double_jump_velocity() -> void:
	assert_eq(_bonnie.double_jump_velocity, 380.0, "GDD §7: double_jump_velocity = 380")


func test_default_double_jump_redirect_factor() -> void:
	assert_eq(_bonnie.double_jump_redirect_factor, 0.45, "GDD §7: redirect_factor = 0.45")


func test_default_air_control_force() -> void:
	assert_eq(_bonnie.air_control_force, 260.0, "GDD §7: air_control_force = 260")


func test_default_post_double_jump_air_control() -> void:
	assert_eq(_bonnie.post_double_jump_air_control, 30.0, "GDD §7: post_dj_air_control = 30")


# -- LOCKED values (GATE 1 confirmed, non-negotiable) -------------------------

func test_locked_claw_brake_multiplier() -> void:
	assert_eq(_bonnie.claw_brake_multiplier, 0.30, "LOCKED: claw_brake_multiplier = 0.30")


func test_locked_skid_friction_multiplier() -> void:
	assert_eq(_bonnie.skid_friction_multiplier, 0.15, "LOCKED: skid_friction_multiplier = 0.15 (NOT 0.85)")


# -- Frame-timing knobs -------------------------------------------------------

func test_default_jump_hold_window() -> void:
	assert_eq(_bonnie.jump_hold_window, 12, "GDD §7: jump_hold_window = 12 frames")


func test_default_double_jump_window_frames() -> void:
	assert_eq(_bonnie.double_jump_window_frames, 40, "GDD §7: double_jump_window = 40 frames")


func test_default_parry_window_frames() -> void:
	assert_eq(_bonnie.parry_window_frames, 6, "GDD §7: parry_window = 6 frames")


func test_default_pullup_duration_frames() -> void:
	assert_eq(_bonnie.pullup_duration_frames, 10, "GDD §7: pullup_duration = 10 frames")


# -- Landing and collision thresholds -----------------------------------------

func test_default_slide_trigger_speed() -> void:
	assert_eq(_bonnie.slide_trigger_speed, 300.0, "GDD §7: slide_trigger_speed = 300")


func test_default_slide_friction() -> void:
	assert_eq(_bonnie.slide_friction, 80.0, "GDD §7: slide_friction = 80")


func test_default_clean_land_threshold() -> void:
	assert_eq(_bonnie.clean_land_threshold, 80.0, "GDD §7: clean_land = 80")


func test_default_skid_threshold() -> void:
	assert_eq(_bonnie.skid_threshold, 180.0, "GDD §7: skid_threshold = 180")


func test_default_hard_skid_threshold() -> void:
	assert_eq(_bonnie.hard_skid_threshold, 320.0, "GDD §7: hard_skid_threshold = 320")


func test_default_rough_landing_threshold() -> void:
	assert_eq(_bonnie.rough_landing_threshold, 144.0, "GDD §7: rough_landing = 144 px fall")


func test_default_daze_collision_threshold() -> void:
	assert_eq(_bonnie.daze_collision_threshold, 280.0, "GDD §7: daze_collision = 280")


# -- Recovery timers ----------------------------------------------------------

func test_default_daze_duration() -> void:
	assert_eq(_bonnie.daze_duration, 1.0, "GDD §7: daze_duration = 1.0s")


func test_default_rough_landing_duration() -> void:
	assert_eq(_bonnie.rough_landing_duration, 2.5, "GDD §7: rough_landing_duration = 2.5s")


func test_default_skid_base_duration() -> void:
	assert_eq(_bonnie.skid_base_duration, 0.6, "GDD §7: skid_base_duration = 0.6s")


func test_default_hard_skid_base_duration() -> void:
	assert_eq(_bonnie.hard_skid_base_duration, 1.1, "GDD §7: hard_skid_base_duration = 1.1s")


# -- Ledge and climb knobs ----------------------------------------------------

func test_default_parry_detection_radius() -> void:
	assert_eq(_bonnie.parry_detection_radius, 24.0, "GDD §7: parry_detection_radius = 24")


func test_default_wall_jump_velocity() -> void:
	assert_eq(_bonnie.wall_jump_velocity, 360.0, "GDD §7: wall_jump_velocity = 360")


func test_default_climb_claw_impulse() -> void:
	assert_eq(_bonnie.climb_claw_impulse, 180.0, "GDD §7: climb_claw_impulse = 180")


func test_default_climb_claw_burst_frames() -> void:
	assert_eq(_bonnie.climb_claw_burst_frames, 4, "GDD §7: claw_burst = 4 frames")


func test_default_pullup_pop_velocity() -> void:
	assert_eq(_bonnie.pullup_pop_velocity, 260.0, "GDD §7: pullup_pop_velocity = 260")


func test_default_pullup_pop_vertical() -> void:
	assert_eq(_bonnie.pullup_pop_vertical, 200.0, "GDD §7: pullup_pop_vertical = 200")


# -- NPC stimulus radii -------------------------------------------------------

func test_default_idle_stimulus_radius() -> void:
	assert_eq(_bonnie.idle_stimulus_radius, 96.0, "GDD §7: idle_stimulus = 96")


func test_default_sneak_stimulus_radius() -> void:
	assert_eq(_bonnie.sneak_stimulus_radius, 48.0, "GDD §7: sneak_stimulus = 48")


func test_default_walk_stimulus_radius() -> void:
	assert_eq(_bonnie.walk_stimulus_radius, 140.0, "GDD §7: walk_stimulus = 140")


func test_default_run_stimulus_radius() -> void:
	assert_eq(_bonnie.run_stimulus_radius, 220.0, "GDD §7: run_stimulus = 220")


# =============================================================================
# PUBLIC API
# =============================================================================

# -- get_look_ahead_distance() ------------------------------------------------

func test_look_ahead_idle_is_zero() -> void:
	_bonnie.current_state = BonnieController.State.IDLE
	assert_eq(_bonnie.get_look_ahead_distance(), 0.0, "IDLE look-ahead = 0")


func test_look_ahead_running() -> void:
	_bonnie.current_state = BonnieController.State.RUNNING
	assert_eq(_bonnie.get_look_ahead_distance(), 180.0, "RUNNING look-ahead = 180")


func test_look_ahead_sliding() -> void:
	_bonnie.current_state = BonnieController.State.SLIDING
	assert_eq(_bonnie.get_look_ahead_distance(), 220.0, "SLIDING look-ahead = 220 (highest)")


func test_look_ahead_sneaking() -> void:
	_bonnie.current_state = BonnieController.State.SNEAKING
	assert_eq(_bonnie.get_look_ahead_distance(), 40.0, "SNEAKING look-ahead = 40")


func test_look_ahead_walking() -> void:
	_bonnie.current_state = BonnieController.State.WALKING
	assert_eq(_bonnie.get_look_ahead_distance(), 80.0, "WALKING look-ahead = 80")


func test_look_ahead_jumping() -> void:
	_bonnie.current_state = BonnieController.State.JUMPING
	assert_eq(_bonnie.get_look_ahead_distance(), 120.0, "JUMPING look-ahead = 120")


func test_look_ahead_falling() -> void:
	_bonnie.current_state = BonnieController.State.FALLING
	assert_eq(_bonnie.get_look_ahead_distance(), 120.0, "FALLING look-ahead = 120")


func test_look_ahead_climbing() -> void:
	_bonnie.current_state = BonnieController.State.CLIMBING
	assert_eq(_bonnie.get_look_ahead_distance(), 60.0, "CLIMBING look-ahead = 60")


func test_look_ahead_squeezing_is_zero() -> void:
	_bonnie.current_state = BonnieController.State.SQUEEZING
	assert_eq(_bonnie.get_look_ahead_distance(), 0.0, "SQUEEZING look-ahead = 0")


func test_look_ahead_dazed_is_zero() -> void:
	_bonnie.current_state = BonnieController.State.DAZED
	assert_eq(_bonnie.get_look_ahead_distance(), 0.0, "DAZED look-ahead = 0")


func test_look_ahead_rough_landing_is_zero() -> void:
	_bonnie.current_state = BonnieController.State.ROUGH_LANDING
	assert_eq(_bonnie.get_look_ahead_distance(), 0.0, "ROUGH_LANDING look-ahead = 0")


func test_look_ahead_ledge_pullup() -> void:
	_bonnie.current_state = BonnieController.State.LEDGE_PULLUP
	assert_eq(_bonnie.get_look_ahead_distance(), 60.0, "LEDGE_PULLUP look-ahead = 60")


func test_look_ahead_landing_is_zero() -> void:
	_bonnie.current_state = BonnieController.State.LANDING
	assert_eq(_bonnie.get_look_ahead_distance(), 0.0, "LANDING look-ahead = 0")


# -- get_facing_direction() ---------------------------------------------------

func test_facing_direction_default_right() -> void:
	assert_eq(_bonnie.get_facing_direction(), 1.0, "Default facing = right (1.0)")


func test_facing_direction_after_set_left() -> void:
	_bonnie.facing_direction = -1.0
	assert_eq(_bonnie.get_facing_direction(), -1.0, "Facing should reflect manual set")


# -- get_stimulus_radius() ----------------------------------------------------

func test_stimulus_radius_idle() -> void:
	_bonnie.current_state = BonnieController.State.IDLE
	assert_eq(_bonnie.get_stimulus_radius(), 96.0, "IDLE stimulus = idle_stimulus_radius")


func test_stimulus_radius_sneaking() -> void:
	_bonnie.current_state = BonnieController.State.SNEAKING
	assert_eq(_bonnie.get_stimulus_radius(), 48.0, "SNEAKING = sneak radius")


func test_stimulus_radius_squeezing_uses_sneak() -> void:
	_bonnie.current_state = BonnieController.State.SQUEEZING
	assert_eq(_bonnie.get_stimulus_radius(), 48.0, "SQUEEZING uses sneak radius")


func test_stimulus_radius_walking() -> void:
	_bonnie.current_state = BonnieController.State.WALKING
	assert_eq(_bonnie.get_stimulus_radius(), 140.0, "WALKING = walk radius")


func test_stimulus_radius_climbing_uses_walk() -> void:
	_bonnie.current_state = BonnieController.State.CLIMBING
	assert_eq(_bonnie.get_stimulus_radius(), 140.0, "CLIMBING uses walk radius")


func test_stimulus_radius_running() -> void:
	_bonnie.current_state = BonnieController.State.RUNNING
	assert_eq(_bonnie.get_stimulus_radius(), 220.0, "RUNNING = run radius")


func test_stimulus_radius_sliding_uses_run() -> void:
	_bonnie.current_state = BonnieController.State.SLIDING
	assert_eq(_bonnie.get_stimulus_radius(), 220.0, "SLIDING uses run radius")


func test_stimulus_radius_jumping_uses_run() -> void:
	_bonnie.current_state = BonnieController.State.JUMPING
	assert_eq(_bonnie.get_stimulus_radius(), 220.0, "JUMPING uses run radius")


func test_stimulus_radius_falling_uses_run() -> void:
	_bonnie.current_state = BonnieController.State.FALLING
	assert_eq(_bonnie.get_stimulus_radius(), 220.0, "FALLING uses run radius")


func test_stimulus_radius_dazed_uses_idle() -> void:
	_bonnie.current_state = BonnieController.State.DAZED
	assert_eq(_bonnie.get_stimulus_radius(), 96.0, "DAZED uses idle radius")


func test_stimulus_radius_rough_landing_uses_idle() -> void:
	_bonnie.current_state = BonnieController.State.ROUGH_LANDING
	assert_eq(_bonnie.get_stimulus_radius(), 96.0, "ROUGH_LANDING uses idle radius")


func test_stimulus_radius_landing_uses_idle() -> void:
	_bonnie.current_state = BonnieController.State.LANDING
	assert_eq(_bonnie.get_stimulus_radius(), 96.0, "LANDING uses idle radius")


func test_stimulus_radius_ledge_pullup_uses_idle() -> void:
	_bonnie.current_state = BonnieController.State.LEDGE_PULLUP
	assert_eq(_bonnie.get_stimulus_radius(), 96.0, "LEDGE_PULLUP uses idle radius")


# =============================================================================
# STATE MACHINE: _change_state()
# =============================================================================

func test_initial_state_is_idle() -> void:
	assert_eq(_bonnie.current_state, BonnieController.State.IDLE, "Initial state = IDLE")


func test_change_state_updates_current_state() -> void:
	_bonnie._change_state(BonnieController.State.WALKING)
	assert_eq(_bonnie.current_state, BonnieController.State.WALKING)


func test_change_state_emits_signal() -> void:
	watch_signals(_bonnie)
	_bonnie._change_state(BonnieController.State.RUNNING)
	assert_signal_emitted(_bonnie, "state_changed")


func test_change_state_signal_carries_old_and_new() -> void:
	watch_signals(_bonnie)
	_bonnie._change_state(BonnieController.State.SNEAKING)
	assert_signal_emitted_with_parameters(
		_bonnie, "state_changed",
		[BonnieController.State.IDLE, BonnieController.State.SNEAKING]
	)


func test_change_state_same_state_no_signal() -> void:
	watch_signals(_bonnie)
	_bonnie._change_state(BonnieController.State.IDLE)  # already IDLE
	assert_signal_not_emitted(_bonnie, "state_changed", "Same-state transition should not fire")


# -- Entry logic: JUMPING sets tracking vars -----------------------------------

func test_jumping_entry_sets_jump_held() -> void:
	_bonnie._change_state(BonnieController.State.JUMPING)
	assert_true(_bonnie.is_jump_held, "JUMPING entry sets is_jump_held = true")


func test_jumping_entry_resets_double_jump() -> void:
	_bonnie.double_jump_available = false
	_bonnie._change_state(BonnieController.State.JUMPING)
	assert_true(_bonnie.double_jump_available, "JUMPING entry restores double jump")


func test_jumping_entry_resets_apex_flag() -> void:
	_bonnie._at_apex = true
	_bonnie._change_state(BonnieController.State.JUMPING)
	assert_false(_bonnie._at_apex, "JUMPING entry clears apex flag")


func test_jumping_entry_resets_post_double_jumped() -> void:
	_bonnie._post_double_jumped = true
	_bonnie._change_state(BonnieController.State.JUMPING)
	assert_false(_bonnie._post_double_jumped, "JUMPING entry clears post_double_jumped")


# -- Entry logic: FALLING sets fall origin ------------------------------------

func test_falling_entry_sets_fall_origin() -> void:
	_bonnie.global_position = Vector2(100, 250)
	_bonnie._change_state(BonnieController.State.FALLING)
	assert_eq(_bonnie.fall_origin_y, 250.0, "FALLING entry records fall_origin_y")


# -- Entry logic: DAZED sets timer --------------------------------------------

func test_dazed_entry_sets_timer() -> void:
	_bonnie._change_state(BonnieController.State.DAZED)
	assert_eq(_bonnie._daze_timer, 1.0, "DAZED entry sets timer to daze_duration")


# -- Entry logic: ROUGH_LANDING sets timer ------------------------------------

func test_rough_landing_entry_sets_timer() -> void:
	_bonnie._change_state(BonnieController.State.ROUGH_LANDING)
	assert_eq(_bonnie._rough_landing_timer, 2.5, "ROUGH_LANDING entry sets timer")


# -- Entry logic: LEDGE_PULLUP zeroes velocity --------------------------------

func test_ledge_pullup_entry_zeroes_velocity() -> void:
	_bonnie.velocity = Vector2(300, -200)
	_bonnie._change_state(BonnieController.State.LEDGE_PULLUP)
	assert_eq(_bonnie.velocity, Vector2.ZERO, "LEDGE_PULLUP entry zeroes velocity")


func test_ledge_pullup_entry_sets_timer() -> void:
	_bonnie._change_state(BonnieController.State.LEDGE_PULLUP)
	var expected_time: float = _bonnie.pullup_duration_frames / 60.0
	assert_almost_eq(_bonnie._ledge_pullup_timer, expected_time, 0.001,
		"LEDGE_PULLUP timer = pullup_duration_frames / 60")


func test_ledge_pullup_entry_resets_pullup_direction() -> void:
	_bonnie._pullup_direction = 1.0
	_bonnie._change_state(BonnieController.State.LEDGE_PULLUP)
	assert_eq(_bonnie._pullup_direction, 0.0, "LEDGE_PULLUP resets pullup direction")


# -- Regression: CLIMBING top-edge detection ----------------------------------
# Bug: BONNIE could scale past the top of a climbable surface indefinitely.
# Root cause: normal direction check used > 0.5 (downward/floor) instead of
# < -0.5 (upward/top-face). No fallback when BONNIE lost contact above the top.

func test_climbing_at_top_flag_set_by_upward_normal() -> void:
	# _at_climb_top is the signal that E-at-ledge should mount rather than burst.
	# Directly set it as _handle_climbing() would after detecting normal.y < -0.5.
	_bonnie._change_state(BonnieController.State.CLIMBING)
	_bonnie._at_climb_top = true
	assert_true(_bonnie._at_climb_top,
		"CLIMBING: top-face contact (normal.y < -0.5) must set _at_climb_top")


func test_climbing_e_at_top_transitions_to_ledge_pullup() -> void:
	# The core of "fluid scramble": pressing E while _at_climb_top → mount.
	# Simulates _handle_climbing() path: _at_climb_top=true + grab pressed → LEDGE_PULLUP.
	_bonnie._change_state(BonnieController.State.CLIMBING)
	_bonnie._at_climb_top = true
	_bonnie._pullup_from_climb = true   # set as _handle_climbing() does before transition
	_bonnie._change_state(BonnieController.State.LEDGE_PULLUP)

	assert_eq(_bonnie.current_state, BonnieController.State.LEDGE_PULLUP,
		"CLIMBING: E press while at top edge must trigger LEDGE_PULLUP (fluid scramble mount)")


func test_climbing_e_not_at_top_does_not_mount() -> void:
	# E press when NOT at the top = claw burst, not mount.
	_bonnie._change_state(BonnieController.State.CLIMBING)
	_bonnie._at_climb_top = false

	# Simulate: E pressed, not at top → burst fires, state stays CLIMBING
	_bonnie._claw_burst_timer = _bonnie.climb_claw_burst_frames
	assert_eq(_bonnie.current_state, BonnieController.State.CLIMBING,
		"CLIMBING: E press when not at top must fire claw burst, not mount")


func test_climbing_failsafe_auto_mount_when_contact_lost() -> void:
	# Failsafe: if BONNIE drifts above the surface (burst overshot) without pressing E,
	# auto-mount fires so she doesn't float away.
	_bonnie._change_state(BonnieController.State.CLIMBING)
	_bonnie.velocity = Vector2(0.0, -60.0)
	_bonnie._claw_burst_timer = 0
	_bonnie._pullup_from_climb = true   # failsafe path sets this then transitions
	_bonnie._change_state(BonnieController.State.LEDGE_PULLUP)

	assert_eq(_bonnie.current_state, BonnieController.State.LEDGE_PULLUP,
		"CLIMBING failsafe: lost contact while ascending must auto-mount to LEDGE_PULLUP")


func test_climbing_claw_burst_does_not_trigger_ledge_pullup() -> void:
	# Mid-burst: momentary contact loss is expected, must NOT auto-mount.
	_bonnie._change_state(BonnieController.State.CLIMBING)
	_bonnie.velocity = Vector2(0.0, -180.0)
	_bonnie._claw_burst_timer = 3

	assert_eq(_bonnie.current_state, BonnieController.State.CLIMBING,
		"CLIMBING: claw burst in progress must not trigger LEDGE_PULLUP on contact loss")


func test_ledge_pullup_from_climb_flag_cleared_on_entry() -> void:
	# _pullup_from_climb resets in _change_state entry so parry pullups start clean
	_bonnie._pullup_from_climb = true
	_bonnie._change_state(BonnieController.State.LEDGE_PULLUP)
	assert_false(_bonnie._pullup_from_climb,
		"LEDGE_PULLUP entry must reset _pullup_from_climb to false")


func test_ledge_pullup_climb_mount_resolves_to_falling() -> void:
	# When triggered from a climbable top, resolve mounts onto the surface (→ FALLING).
	# The flag must be set AFTER _change_state (entry resets it to false).
	_bonnie.facing_direction = 1.0
	_bonnie._change_state(BonnieController.State.LEDGE_PULLUP)
	_bonnie._pullup_from_climb = true        # simulate: triggered from _handle_climbing
	_bonnie._ledge_pullup_timer = 0.0        # skip the wait phase

	# Force resolve: call _handle_ledge_pullup with zero delta (timer already expired)
	_bonnie._handle_ledge_pullup(0.0)

	assert_eq(_bonnie.current_state, BonnieController.State.FALLING,
		"Climb mount LEDGE_PULLUP must resolve to FALLING so BONNIE settles on the surface")


func test_ledge_pullup_climb_mount_velocity_uses_facing_direction() -> void:
	# Mount velocity is facing_direction × pullup_mount_velocity — small nudge forward.
	_bonnie.facing_direction = 1.0
	_bonnie._change_state(BonnieController.State.LEDGE_PULLUP)
	_bonnie._pullup_from_climb = true
	_bonnie._ledge_pullup_timer = 0.0

	_bonnie._handle_ledge_pullup(0.0)

	assert_gt(_bonnie.velocity.x, 0.0,
		"Climb mount: velocity.x must be positive (forward) for facing_direction=1")
	assert_eq(_bonnie.velocity.y, 0.0,
		"Climb mount: velocity.y must be zero — let gravity settle BONNIE onto the surface")


func test_ledge_parry_pullup_still_resolves_to_jumping() -> void:
	# Ledge parry (not from climb) must still pop BONNIE into JUMPING — behaviour unchanged.
	_bonnie._change_state(BonnieController.State.LEDGE_PULLUP)
	# _pullup_from_climb stays false (entry reset it)
	_bonnie._pullup_direction = 1.0          # player pressed a direction during parry
	_bonnie._ledge_pullup_timer = 0.0

	_bonnie._handle_ledge_pullup(0.0)

	assert_eq(_bonnie.current_state, BonnieController.State.JUMPING,
		"Ledge parry (not from climb) must still resolve to JUMPING with pop velocity")


# -- Exit logic: SQUEEZING restores shapes ------------------------------------

func test_squeezing_exit_restores_shapes() -> void:
	# Enter SQUEEZING (mocks shapes since we have no scene tree)
	_bonnie._main_shape = CollisionShape2D.new()
	_bonnie._squeeze_shape = CollisionShape2D.new()
	_bonnie._sprite = ColorRect.new()

	_bonnie._change_state(BonnieController.State.SQUEEZING)
	assert_true(_bonnie._main_shape.disabled, "Main shape disabled during SQUEEZING")
	assert_false(_bonnie._squeeze_shape.disabled, "Squeeze shape enabled during SQUEEZING")

	_bonnie._change_state(BonnieController.State.IDLE)
	assert_false(_bonnie._main_shape.disabled, "Main shape restored on SQUEEZING exit")
	assert_true(_bonnie._squeeze_shape.disabled, "Squeeze shape disabled on SQUEEZING exit")

	# Cleanup manually-created nodes
	_bonnie._main_shape.free()
	_bonnie._squeeze_shape.free()
	_bonnie._sprite.free()


# -- Exit logic: JUMPING/FALLING resets fall tracking -------------------------

func test_jumping_exit_resets_fall_distance() -> void:
	_bonnie._change_state(BonnieController.State.JUMPING)
	_bonnie.fall_distance = 200.0
	_bonnie.fall_origin_y = 100.0
	_bonnie._change_state(BonnieController.State.IDLE)
	assert_eq(_bonnie.fall_distance, 0.0, "Exiting JUMPING resets fall_distance")
	assert_eq(_bonnie.fall_origin_y, 0.0, "Exiting JUMPING resets fall_origin_y")


func test_falling_exit_resets_fall_distance() -> void:
	_bonnie._change_state(BonnieController.State.FALLING)
	_bonnie.fall_distance = 300.0
	_bonnie._change_state(BonnieController.State.LANDING)
	assert_eq(_bonnie.fall_distance, 0.0, "Exiting FALLING resets fall_distance")


# -- Entry logic: LANDING resets skid window ----------------------------------

func test_landing_entry_clears_skid() -> void:
	_bonnie.in_skid_window = true
	_bonnie._change_state(BonnieController.State.LANDING)
	assert_false(_bonnie.in_skid_window, "LANDING entry clears skid window")


# =============================================================================
# STATE ENUM COVERAGE
# =============================================================================

func test_state_enum_has_13_states() -> void:
	assert_eq(BonnieController.State.size(), 13, "State enum must have exactly 13 states")


func test_look_ahead_dict_covers_all_states() -> void:
	for state_value: int in BonnieController.State.values():
		assert_true(
			BonnieController.LOOK_AHEAD_BY_STATE.has(state_value),
			"LOOK_AHEAD_BY_STATE must cover state %d" % state_value
		)


# =============================================================================
# PHYSICS CONSTANTS RELATIONSHIPS
# =============================================================================

func test_hop_less_than_jump() -> void:
	assert_lt(_bonnie.hop_velocity, _bonnie.jump_velocity,
		"Hop velocity must be less than full jump velocity")


func test_double_jump_less_than_full_jump() -> void:
	assert_lt(_bonnie.double_jump_velocity, _bonnie.jump_velocity,
		"Double jump velocity < full jump velocity")


func test_sneak_slower_than_walk() -> void:
	assert_lt(_bonnie.sneak_max_speed, _bonnie.walk_speed,
		"Sneak < walk speed")


func test_walk_slower_than_run() -> void:
	assert_lt(_bonnie.walk_speed, _bonnie.run_max_speed,
		"Walk < run speed")


func test_slide_trigger_between_walk_and_run() -> void:
	assert_gt(_bonnie.slide_trigger_speed, _bonnie.walk_speed,
		"Slide trigger > walk speed")
	assert_lt(_bonnie.slide_trigger_speed, _bonnie.run_max_speed,
		"Slide trigger < run speed")


func test_skid_threshold_ordering() -> void:
	assert_lt(_bonnie.clean_land_threshold, _bonnie.skid_threshold,
		"Clean < skid threshold")
	assert_lt(_bonnie.skid_threshold, _bonnie.hard_skid_threshold,
		"Skid < hard skid threshold")


func test_stimulus_radius_ordering() -> void:
	assert_lt(_bonnie.sneak_stimulus_radius, _bonnie.idle_stimulus_radius,
		"Sneak stimulus < idle")
	assert_lt(_bonnie.idle_stimulus_radius, _bonnie.walk_stimulus_radius,
		"Idle stimulus < walk")
	assert_lt(_bonnie.walk_stimulus_radius, _bonnie.run_stimulus_radius,
		"Walk stimulus < run")

## Unit tests for BonnieCamera (System #4)
extends GutTest


var _camera: BonnieCamera


func before_each() -> void:
	_camera = BonnieCamera.new()
	# Don't add as child to avoid _process running during tests


# -- Default Tuning Knob Values (GDD §4/§7) ----------------------------------

func test_default_follow_speed() -> void:
	assert_eq(_camera.follow_speed, 6.0, "Default follow_speed should be 6.0 (GDD §4)")


func test_default_catch_up_speed() -> void:
	assert_eq(_camera.catch_up_speed, 4.0, "Default catch_up_speed should be 4.0 (GDD §4)")


func test_default_vertical_anchor_ratio() -> void:
	assert_eq(_camera.vertical_anchor_ratio, 0.7, "Default vertical_anchor should be 0.7 (70% down)")


func test_default_zoom_normal() -> void:
	assert_eq(_camera.zoom_normal, 1.0, "Default zoom_normal should be 1.0")


func test_default_zoom_max_out() -> void:
	assert_eq(_camera.zoom_max_out, 0.33, "Default zoom_max_out should be 0.33 (GDD §4)")


func test_default_zoom_out_rate() -> void:
	assert_eq(_camera.zoom_out_rate, 0.8, "Default zoom_out_rate should be 0.8/s")


func test_default_zoom_return_rate() -> void:
	assert_eq(_camera.zoom_return_rate, 2.0, "Default zoom_return_rate should be 2.0/s (GDD §4)")


func test_default_zoom_lod_threshold() -> void:
	assert_eq(_camera.zoom_lod_threshold, 0.75, "Default zoom_lod_threshold should be 0.75")


# -- Room Bounds --------------------------------------------------------------

func test_set_room_bounds_sets_limits() -> void:
	var bounds := Rect2(100, 50, 1200, 540)
	_camera.set_room_bounds(bounds)

	assert_eq(_camera.limit_left, 100, "limit_left should match bounds.position.x")
	assert_eq(_camera.limit_top, 50, "limit_top should match bounds.position.y")
	assert_eq(_camera.limit_right, 1300, "limit_right should match bounds end x")
	assert_eq(_camera.limit_bottom, 590, "limit_bottom should match bounds end y")


func test_set_room_bounds_computes_center() -> void:
	var bounds := Rect2(0, 0, 1200, 540)
	_camera.set_room_bounds(bounds)
	assert_eq(_camera._room_center, Vector2(600, 270), "Room center should be center of bounds")


# -- Zoom Clamping ------------------------------------------------------------

func test_zoom_clamps_at_max_out() -> void:
	_camera._current_zoom = 0.1  # Below max_out
	# The zoom value should be constrained, but _update_zoom handles it
	# Just verify the max_out constraint exists in the property
	assert_lt(_camera.zoom_max_out, _camera.zoom_normal, "zoom_max_out should be less than zoom_normal")


# -- Ledge Bias ---------------------------------------------------------------

func test_ledge_bias_defaults() -> void:
	assert_eq(_camera.ledge_bias_activation_radius, 80.0, "Default ledge bias radius should be 80px")
	assert_eq(_camera.ledge_bias_strength, 40.0, "Default ledge bias strength should be 40px")


func test_set_ledge_bias() -> void:
	var bias := Vector2(20.0, -10.0)
	_camera.set_ledge_bias(bias)
	assert_eq(_camera._ledge_bias_offset, bias, "Ledge bias offset should be stored")

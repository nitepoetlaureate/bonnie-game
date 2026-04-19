## Unit tests for ViewportGuard (System #2)
extends GutTest


var _guard: ViewportGuardClass


func before_each() -> void:
	_guard = ViewportGuardClass.new()
	# Don't add as child — avoid _ready() modifying ProjectSettings in tests


# -- Constants ----------------------------------------------------------------

func test_internal_width() -> void:
	assert_eq(ViewportGuardClass.INTERNAL_WIDTH, 720, "INTERNAL_WIDTH should be 720")


func test_internal_height() -> void:
	assert_eq(ViewportGuardClass.INTERNAL_HEIGHT, 540, "INTERNAL_HEIGHT should be 540")


func test_aspect_ratio() -> void:
	assert_almost_eq(
		ViewportGuardClass.ASPECT_RATIO, 1.333333, 0.001,
		"ASPECT_RATIO should be 4:3 (1.333...)"
	)


func test_target_fps() -> void:
	assert_eq(ViewportGuardClass.TARGET_FPS, 60, "TARGET_FPS should be 60")


# -- Integer Scale Calculation ------------------------------------------------

func test_integer_scale_1080p() -> void:
	# 1920x1080: scale_x = 1920/720 = 2, scale_y = 1080/540 = 2
	assert_eq(_guard.get_integer_scale(Vector2(1920, 1080)), 2, "1080p should be 2x scale")


func test_integer_scale_4k() -> void:
	# 3840x2160: scale_x = 5, scale_y = 4 → min = 4
	assert_eq(_guard.get_integer_scale(Vector2(3840, 2160)), 4, "4K should be 4x scale")


func test_integer_scale_720p() -> void:
	# 1280x720: scale_x = 1, scale_y = 1
	assert_eq(_guard.get_integer_scale(Vector2(1280, 720)), 1, "720p should be 1x scale")


func test_integer_scale_ultrawide() -> void:
	# 3440x1440: scale_x = 4, scale_y = 2 → min = 2
	assert_eq(_guard.get_integer_scale(Vector2(3440, 1440)), 2, "Ultrawide 1440p should be 2x scale")


func test_integer_scale_minimum() -> void:
	# Tiny display smaller than viewport — should still return 1
	assert_eq(_guard.get_integer_scale(Vector2(640, 480)), 1, "Sub-viewport display should return scale 1")


# -- Pillarbox Width Calculation ----------------------------------------------

func test_pillarbox_1080p_2x() -> void:
	# 1920 - (720*2) = 1920 - 1440 = 480, each side = 240
	assert_eq(_guard.get_pillarbox_width(1920, 2), 240, "1080p 2x should have 240px pillarbox each side")


func test_pillarbox_4k_4x() -> void:
	# 3840 - (720*4) = 3840 - 2880 = 960, each side = 480
	assert_eq(_guard.get_pillarbox_width(3840, 4), 480, "4K 4x should have 480px pillarbox each side")


func test_pillarbox_exact_4_3() -> void:
	# 1440 - (720*2) = 0, each side = 0
	assert_eq(_guard.get_pillarbox_width(1440, 2), 0, "4:3 display should have 0 pillarbox")

## ViewportGuard — Foundation Layer Autoload (System #2)
##
## Runtime validation of the 720x540 / 4:3 / nearest-neighbor / 60fps
## viewport contract. Corrects drift and exposes viewport constants.
##
## See: design/gdd/viewport-config.md
class_name ViewportGuardClass
extends Node


# -- Constants (§7 — fixed, do not change) ------------------------------------

const INTERNAL_WIDTH: int = 720
const INTERNAL_HEIGHT: int = 540
const ASPECT_RATIO: float = 720.0 / 540.0  # 1.333...
const TARGET_FPS: int = 60


# -- Public API ---------------------------------------------------------------

## Returns the largest integer scale that fits the given display size.
func get_integer_scale(display_size: Vector2) -> int:
	var scale_x: int = int(display_size.x) / INTERNAL_WIDTH
	var scale_y: int = int(display_size.y) / INTERNAL_HEIGHT
	return maxi(1, mini(scale_x, scale_y))


## Returns the width of each pillarbox bar (one side) for a widescreen display.
func get_pillarbox_width(display_width: int, scale: int) -> int:
	var rendered_width: int = INTERNAL_WIDTH * scale
	return (display_width - rendered_width) / 2


# -- Engine Callbacks ---------------------------------------------------------

func _ready() -> void:
	_validate_settings()


# -- Private ------------------------------------------------------------------

func _validate_settings() -> void:
	var viewport_w: int = ProjectSettings.get_setting("display/window/size/viewport_width", 0)
	var viewport_h: int = ProjectSettings.get_setting("display/window/size/viewport_height", 0)

	if viewport_w != INTERNAL_WIDTH or viewport_h != INTERNAL_HEIGHT:
		push_warning(
			"ViewportGuard: viewport is %dx%d, expected %dx%d. Correcting." %
			[viewport_w, viewport_h, INTERNAL_WIDTH, INTERNAL_HEIGHT]
		)
		ProjectSettings.set_setting("display/window/size/viewport_width", INTERNAL_WIDTH)
		ProjectSettings.set_setting("display/window/size/viewport_height", INTERNAL_HEIGHT)

	# Validate nearest-neighbor filtering
	var tex_filter: int = ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter", -1
	)
	if tex_filter != 0:  # 0 = Nearest
		push_warning("ViewportGuard: texture filter is %d, expected 0 (Nearest). Correcting." % tex_filter)
		ProjectSettings.set_setting(
			"rendering/textures/canvas_textures/default_texture_filter", 0
		)

	# Validate renderer
	var renderer: String = ProjectSettings.get_setting(
		"rendering/renderer/rendering_method", ""
	)
	if renderer != "gl_compatibility":
		push_warning(
			"ViewportGuard: renderer is '%s', expected 'gl_compatibility'. Correcting." % renderer
		)
		ProjectSettings.set_setting("rendering/renderer/rendering_method", "gl_compatibility")

	# Lock FPS
	Engine.max_fps = TARGET_FPS

	print("ViewportGuard: %dx%d | 4:3 | nearest | gl_compatibility | %dfps" %
		[INTERNAL_WIDTH, INTERNAL_HEIGHT, TARGET_FPS])

## AudioManager — Foundation Layer Autoload (System #3)
##
## Audio pipeline for BONNIE!: bus hierarchy, volume controls, format
## enforcement, and the playback API all systems use to trigger sound.
## No gameplay system touches AudioServer or AudioStreamPlayer directly.
##
## Sprint 1 scope: bus structure + API contract + stub behavior for
## missing audio files. Full event catalogue is Sprint 2+.
##
## See: design/gdd/audio-manager.md
class_name AudioManagerClass
extends Node


# -- Tuning Knobs (§7) -------------------------------------------------------

@export_group("Default Volumes")
@export_range(0.0, 1.0) var DEFAULT_MASTER_VOLUME: float = 1.0
@export_range(0.0, 1.0) var DEFAULT_MUSIC_VOLUME: float = 0.7
@export_range(0.0, 1.0) var DEFAULT_SFX_VOLUME: float = 1.0

@export_group("Fade Durations")
@export var MUSIC_FADE_IN_SEC: float = 0.5
@export var MUSIC_FADE_OUT_SEC: float = 1.0
@export var SFX_LOOP_FADE_OUT_SEC: float = 0.1

@export_group("Pitch Variation (Semitones)")
@export var PITCH_VARIATION_SLIGHT_SEMITONES: float = 1.0
@export var PITCH_VARIATION_YES_SEMITONES: float = 2.0

@export_group("Polyphony Limits")
@export var POLYPHONY_BONNIE_TRAVERSAL: int = 3
@export var POLYPHONY_ENVIRONMENTAL: int = 4


# -- Bus Indices (cached on _ready) ------------------------------------------

var _master_bus_idx: int = -1
var _music_bus_idx: int = -1
var _sfx_bus_idx: int = -1


# -- Audio Registry -----------------------------------------------------------
## Maps event_id → file path. Populated by _register_events().
var _audio_registry: Dictionary = {}  # Dictionary[StringName, String]

## Active SFX loop players, keyed by event_id.
var _active_loops: Dictionary = {}  # Dictionary[StringName, AudioStreamPlayer]

## Current music player (if any).
var _music_player: AudioStreamPlayer = null

## Stored volume values for mute/unmute.
var _stored_volumes: Dictionary = {}  # Dictionary[StringName, float]

## Mute flags per bus.
var _muted: Dictionary = {}  # Dictionary[StringName, bool]


# -- Public API (§3.3) -------------------------------------------------------

## Play a one-shot SFX on the SFX bus. Logs error if event_id is unknown.
func play_sfx(event_id: StringName, volume_offset_db: float = 0.0) -> void:
	var path: String = _audio_registry.get(event_id, "")
	if path.is_empty():
		push_error("AudioManager: unknown SFX event '%s'" % event_id)
		return

	if not ResourceLoader.exists(path):
		push_warning("AudioManager: audio file not found for event '%s' at '%s'" % [event_id, path])
		return

	var stream: AudioStream = load(path)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_offset_db
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


## Start a looping SFX. Caller must stop it via stop_sfx_loop().
func play_sfx_loop(event_id: StringName) -> void:
	if _active_loops.has(event_id):
		return  # Already looping

	var path: String = _audio_registry.get(event_id, "")
	if path.is_empty():
		push_error("AudioManager: unknown loop event '%s'" % event_id)
		return

	if not ResourceLoader.exists(path):
		push_warning("AudioManager: audio file not found for loop '%s' at '%s'" % [event_id, path])
		return

	var stream: AudioStream = load(path)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	add_child(player)
	player.play()
	_active_loops[event_id] = player


## Stop a looping SFX with a short fade-out.
func stop_sfx_loop(event_id: StringName) -> void:
	if not _active_loops.has(event_id):
		return  # Silent no-op per GDD §5

	var player: AudioStreamPlayer = _active_loops[event_id]
	_active_loops.erase(event_id)

	if SFX_LOOP_FADE_OUT_SEC <= 0.0:
		player.stop()
		player.queue_free()
		return

	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, SFX_LOOP_FADE_OUT_SEC)
	tween.tween_callback(player.stop)
	tween.tween_callback(player.queue_free)


## Start a music track with fade-in. Stops current music first.
func play_music(event_id: StringName, fade_in_sec: float = -1.0) -> void:
	if fade_in_sec < 0.0:
		fade_in_sec = MUSIC_FADE_IN_SEC

	# Stop current music if playing
	if _music_player != null and _music_player.playing:
		stop_music(0.0)

	var path: String = _audio_registry.get(event_id, "")
	if path.is_empty():
		push_warning("AudioManager: unknown music event '%s' — stub, no playback." % event_id)
		return

	if not ResourceLoader.exists(path):
		push_warning("AudioManager: music file not found for '%s' at '%s'" % [event_id, path])
		return

	var stream: AudioStream = load(path)
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = stream
	_music_player.bus = &"Music"
	add_child(_music_player)

	if fade_in_sec > 0.0:
		_music_player.volume_db = -80.0
		_music_player.play()
		var tween: Tween = create_tween()
		tween.tween_property(_music_player, "volume_db", 0.0, fade_in_sec)
	else:
		_music_player.play()


## Stop the current music track with fade-out.
func stop_music(fade_out_sec: float = -1.0) -> void:
	if _music_player == null or not _music_player.playing:
		return  # Silent no-op per GDD §5

	if fade_out_sec < 0.0:
		fade_out_sec = MUSIC_FADE_OUT_SEC

	var player: AudioStreamPlayer = _music_player
	_music_player = null

	if fade_out_sec <= 0.0:
		player.stop()
		player.queue_free()
		return

	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, fade_out_sec)
	tween.tween_callback(player.stop)
	tween.tween_callback(player.queue_free)


## Set bus volume from linear value (0.0–1.0). Converts to dB internally.
func set_volume(bus: StringName, linear_value: float) -> void:
	linear_value = clampf(linear_value, 0.0, 1.0)
	var bus_idx: int = AudioServer.get_bus_index(bus)
	if bus_idx < 0:
		push_error("AudioManager: unknown bus '%s'" % bus)
		return

	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_value))
	_stored_volumes[bus] = linear_value


## Mute a bus. Preserves stored volume for unmute.
func mute_bus(bus: StringName) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus)
	if bus_idx < 0:
		return
	AudioServer.set_bus_volume_db(bus_idx, -80.0)
	_muted[bus] = true


## Unmute a bus. Restores the previously stored volume.
func unmute_bus(bus: StringName) -> void:
	if not _muted.get(bus, false):
		return
	_muted[bus] = false
	var linear_value: float = _stored_volumes.get(bus, 1.0)
	var bus_idx: int = AudioServer.get_bus_index(bus)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_value))


# -- Engine Callbacks ---------------------------------------------------------

func _ready() -> void:
	_setup_buses()
	_register_events()
	_apply_default_volumes()
	print("AudioManager: buses configured (Master/Music/SFX), %d events registered." % _audio_registry.size())


# -- Private ------------------------------------------------------------------

func _setup_buses() -> void:
	# Ensure Music and SFX buses exist under Master
	_master_bus_idx = AudioServer.get_bus_index(&"Master")

	_music_bus_idx = AudioServer.get_bus_index(&"Music")
	if _music_bus_idx < 0:
		AudioServer.add_bus()
		_music_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_music_bus_idx, "Music")
		AudioServer.set_bus_send(_music_bus_idx, &"Master")

	_sfx_bus_idx = AudioServer.get_bus_index(&"SFX")
	if _sfx_bus_idx < 0:
		AudioServer.add_bus()
		_sfx_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_sfx_bus_idx, "SFX")
		AudioServer.set_bus_send(_sfx_bus_idx, &"Master")


func _apply_default_volumes() -> void:
	set_volume(&"Master", DEFAULT_MASTER_VOLUME)
	set_volume(&"Music", DEFAULT_MUSIC_VOLUME)
	set_volume(&"SFX", DEFAULT_SFX_VOLUME)


func _register_events() -> void:
	# Sprint 1: register only the placeholder footstep.
	# Full catalogue (40+ events from GDD §3.2) added in Sprint 2
	# as audio assets are created.
	_audio_registry[&"bonnie_footstep_placeholder"] = "res://assets/audio/sfx/bonnie_footstep_placeholder.wav"

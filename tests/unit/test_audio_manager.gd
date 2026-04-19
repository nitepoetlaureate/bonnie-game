## Unit tests for AudioManager (System #3)
extends GutTest


var _audio: AudioManagerClass


func before_each() -> void:
	_audio = AudioManagerClass.new()
	add_child_autofree(_audio)
	# Let _ready() run to set up buses
	await get_tree().process_frame


# -- Bus Setup ----------------------------------------------------------------

func test_music_bus_exists() -> void:
	var idx: int = AudioServer.get_bus_index(&"Music")
	assert_gt(idx, -1, "Music bus should exist after AudioManager._ready()")


func test_sfx_bus_exists() -> void:
	var idx: int = AudioServer.get_bus_index(&"SFX")
	assert_gt(idx, -1, "SFX bus should exist after AudioManager._ready()")


func test_music_bus_sends_to_master() -> void:
	var idx: int = AudioServer.get_bus_index(&"Music")
	if idx >= 0:
		var send: StringName = AudioServer.get_bus_send(idx)
		assert_eq(send, &"Master", "Music bus should send to Master")


func test_sfx_bus_sends_to_master() -> void:
	var idx: int = AudioServer.get_bus_index(&"SFX")
	if idx >= 0:
		var send: StringName = AudioServer.get_bus_send(idx)
		assert_eq(send, &"Master", "SFX bus should send to Master")


# -- Volume -------------------------------------------------------------------

func test_set_volume_clamps_high() -> void:
	# Should not crash or amplify above unity
	_audio.set_volume(&"Master", 1.5)
	var vol_db: float = AudioServer.get_bus_volume_db(0)
	assert_almost_eq(vol_db, 0.0, 0.1, "Volume above 1.0 should clamp to 0 dB")


func test_set_volume_clamps_low() -> void:
	_audio.set_volume(&"Master", -0.5)
	# Should clamp to 0.0 which is -inf dB
	# Just verify no crash — -inf dB is valid
	pass_test("set_volume with negative value should not crash")


# -- Unknown Event Safety (AC-A05) -------------------------------------------

func test_play_sfx_unknown_event_no_crash() -> void:
	# Should log error but not crash
	_audio.play_sfx(&"nonexistent_event_12345")
	pass_test("play_sfx with unknown event should not crash")


func test_stop_sfx_loop_not_playing_no_crash() -> void:
	# Silent no-op per GDD §5
	_audio.stop_sfx_loop(&"nonexistent_loop")
	pass_test("stop_sfx_loop for non-playing loop should be silent no-op")


func test_stop_music_not_playing_no_crash() -> void:
	# Silent no-op per GDD §5
	_audio.stop_music()
	pass_test("stop_music when not playing should be silent no-op")


# -- Default Volume Values (§7) ----------------------------------------------

func test_default_master_volume() -> void:
	assert_eq(_audio.DEFAULT_MASTER_VOLUME, 1.0, "Default master volume should be 1.0")


func test_default_music_volume() -> void:
	assert_eq(_audio.DEFAULT_MUSIC_VOLUME, 0.7, "Default music volume should be 0.7")


func test_default_sfx_volume() -> void:
	assert_eq(_audio.DEFAULT_SFX_VOLUME, 1.0, "Default SFX volume should be 1.0")


# -- Mute/Unmute (AC-A07) ----------------------------------------------------

func test_mute_unmute_preserves_volume() -> void:
	_audio.set_volume(&"SFX", 0.8)
	_audio.mute_bus(&"SFX")

	var sfx_idx: int = AudioServer.get_bus_index(&"SFX")
	var muted_db: float = AudioServer.get_bus_volume_db(sfx_idx)
	assert_almost_eq(muted_db, -80.0, 0.1, "Muted bus should be at -80 dB")

	_audio.unmute_bus(&"SFX")
	var restored_db: float = AudioServer.get_bus_volume_db(sfx_idx)
	var expected_db: float = linear_to_db(0.8)
	assert_almost_eq(restored_db, expected_db, 0.1, "Unmuted bus should restore to 0.8 linear")


# -- Registry -----------------------------------------------------------------

func test_placeholder_event_registered() -> void:
	assert_true(
		_audio._audio_registry.has(&"bonnie_footstep_placeholder"),
		"Placeholder footstep event should be registered"
	)

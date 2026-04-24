# ADR-003: AudioManager — Audio Pipeline and Playback API

## Status
Accepted

## Date
2026-04-22

## Context

### Problem Statement
BONNIE's audio is load-bearing for two things that cannot be faked: control feel and chaos feedback. A slide that sounds wrong undermines the traversal system. A cascade of NPC reactions that sounds thin undermines the chaos fantasy. Multiple systems — traversal, NPC reactions, level manager, environmental chaos, future dialogue UI — all need to trigger audio. The question is: who owns the bus hierarchy, volume state, format rules, pitch variation, and polyphony limits? And how does Sprint 1 ship playable when only 1 of 40+ planned audio events exists?

### Constraints
- No gameplay system may touch `AudioServer` or `AudioStreamPlayer` directly — single API surface
- Music: OGG Vorbis, streamed (low memory). SFX: WAV, uncompressed, short (low latency)
- No uncompressed music assets in the repository — hard pipeline rule
- Pitch variation uses semitones in Godot 4.6 (post-4.3 API change — verify exact property name before implementation)
- Polyphony limits per category (footsteps: 1, BONNIE traversal: 3, per-NPC vocal: 1, environmental: 4, music: 1)
- Must run within 16.6ms frame budget on integrated graphics
- Sprint 1 has exactly 1 registered audio event (`bonnie_footstep_placeholder`). The system must be fully functional with a near-empty catalogue.

### Requirements
- Bus hierarchy: Master → Music, Master → SFX
- Independent volume control per bus, saved to user config
- Mute/unmute that preserves stored volume (mute ≠ volume 0)
- Graceful handling of unknown or missing audio events (no crash, clear diagnostics)
- Music fade-in/fade-out with configurable durations
- SFX loop lifecycle management (start, stop with fade)
- Linear-to-dB volume conversion (UI shows 0–100%, AudioServer uses dB)
- All tuning knobs exported for inspector editing

## Decision

**AudioManager is a foundation-layer autoload that owns the entire audio pipeline.** It wraps `AudioServer` bus configuration, maintains a registry of event IDs to file paths, and exposes the only valid API for all audio playback. No gameplay system creates `AudioStreamPlayer` nodes, queries `AudioServer`, or references audio file paths directly.

### Four Architectural Sub-Decisions

**1. Autoload wrapping AudioServer — infrastructure exception to the singleton anti-pattern.**

AudioManager is an autoload registered in Project Settings. This is explicitly *not* a violation of the "no singletons for mutable game state" rule — AudioManager holds audio infrastructure state (bus indices, volume levels, active players), not game state (chaos meter, NPC emotions, player position). It is the audio equivalent of `AudioServer` itself: a service that all systems need, with no game logic.

The alternative — passing an AudioManager reference via dependency injection to every system that plays sound — would mean every system (traversal, NPC, level manager, environmental chaos, dialogue UI, future mini-games) needs an AudioManager parameter in its constructor or `_ready()`. The coupling cost exceeds the singleton risk, because AudioManager has no game logic to create hidden dependencies on.

**2. Registry + stub pattern — graceful degradation with near-empty catalogue.**

The `_audio_registry` dictionary maps `StringName` event IDs to file paths:

```gdscript
_audio_registry[&"bonnie_footstep_placeholder"] = "res://assets/audio/sfx/bonnie_footstep_placeholder.wav"
```

When `play_sfx()` or `play_music()` is called:
- Unknown event ID → `push_error()`, no crash, no sound
- Known event ID but file missing → `push_warning()`, no crash, no sound
- Known event ID and file exists → loads and plays

This means Sprint 1 ships with 1 registered event and the full API contract in place. Gameplay systems call `AudioManager.play_sfx(&"bonnie_land_soft")` from day one — the call works (logs a warning, plays nothing) even before the audio file is created. When the audio asset is added and registered, the gameplay code doesn't change.

The registry is populated in `_register_events()`, a single method that will grow from 1 event (Sprint 1) to 40+ events (full catalogue) as assets are created. No gameplay system needs to know or care how many events are registered.

**3. Programmatic bus creation — self-healing, no editor state dependency.**

Music and SFX buses are created in `_ready()` by checking `AudioServer.get_bus_index()` and calling `AudioServer.add_bus()` if the bus doesn't exist. This is deliberate:

- No dependency on a `.tres` bus layout file that can be accidentally deleted or corrupted
- No merge conflict on bus configuration (buses are created from code, not serialized editor state)
- Self-healing: if someone removes the Music bus in the editor, AudioManager recreates it on next launch
- Bus hierarchy (Music → Master, SFX → Master) is enforced in code, not trusted from editor state

The bus indices are cached (`_master_bus_idx`, `_music_bus_idx`, `_sfx_bus_idx`) for O(1) lookups during playback.

**4. One-directional dependency sink — AudioManager never queries game state.**

AudioManager receives calls and plays audio. It never asks "what state is BONNIE in?" or "what's the chaos meter level?" or "which NPC just reacted?" The caller makes all gameplay decisions and passes only the resolved event ID and optional parameters (volume offset, fade duration).

This means:
- AudioManager has zero gameplay dependencies — it cannot create circular dependency chains
- Testing AudioManager requires no gameplay mocks — just call the API with event IDs
- Adding a new caller system (environmental chaos, dialogue UI, mini-games) requires zero changes to AudioManager
- AudioManager's behavior is fully determined by its inputs — same call, same result, regardless of game state

### Architecture Diagram

```
Callers (one-directional):
┌─────────────┐  ┌───────────┐  ┌──────────────┐  ┌─────────────┐
│ Traversal(6)│  │ NPC Sys(9)│  │ Level Mgr(5) │  │ Env Chaos(8)│
│ play_sfx()  │  │ play_sfx()│  │ play_music() │  │ play_sfx()  │
└──────┬──────┘  └─────┬─────┘  └──────┬───────┘  └──────┬──────┘
       │               │               │                  │
       ▼               ▼               ▼                  ▼
┌──────────────────────────────────────────────────────────────┐
│                   AudioManager (Autoload)                     │
│                                                              │
│  _audio_registry: Dictionary[StringName, String]             │
│    Maps event_id → file path. Unknown IDs → push_error().    │
│    Missing files → push_warning(). Sprint 1: 1 event.        │
│                                                              │
│  _ready():                                                   │
│    _setup_buses()        → create Music + SFX if missing     │
│    _register_events()    → populate _audio_registry          │
│    _apply_default_volumes() → set Master/Music/SFX levels    │
│                                                              │
│  Public API:                                                 │
│    play_sfx(event_id, volume_offset_db)                      │
│    play_sfx_loop(event_id)                                   │
│    stop_sfx_loop(event_id)                                   │
│    play_music(event_id, fade_in_sec)                         │
│    stop_music(fade_out_sec)                                  │
│    set_volume(bus, linear_value)                              │
│    mute_bus(bus) / unmute_bus(bus)                            │
│                                                              │
│  Internal state:                                             │
│    _active_loops: Dict[StringName, AudioStreamPlayer]        │
│    _music_player: AudioStreamPlayer (nullable)               │
│    _stored_volumes: Dict[StringName, float]                  │
│    _muted: Dict[StringName, bool]                            │
└──────────────────────┬───────────────────────────────────────┘
                       │ wraps
                       ▼
              ┌──────────────────┐
              │   AudioServer    │
              │ (Godot built-in) │
              │                  │
              │  Master bus      │
              │  ├── Music bus   │
              │  └── SFX bus     │
              └──────────────────┘
```

### Key Interfaces

```gdscript
# -- Playback --
func play_sfx(event_id: StringName, volume_offset_db: float = 0.0) -> void
func play_sfx_loop(event_id: StringName) -> void
func stop_sfx_loop(event_id: StringName) -> void
func play_music(event_id: StringName, fade_in_sec: float = -1.0) -> void
func stop_music(fade_out_sec: float = -1.0) -> void

# -- Volume --
func set_volume(bus: StringName, linear_value: float) -> void
    # Clamps to [0.0, 1.0], converts to dB, stores for mute/unmute
func mute_bus(bus: StringName) -> void
    # Sets bus to -80 dB, preserves stored volume
func unmute_bus(bus: StringName) -> void
    # Restores previously stored volume

# -- Tuning Knobs (all @export) --
var DEFAULT_MASTER_VOLUME: float = 1.0       # 0 dB
var DEFAULT_MUSIC_VOLUME: float = 0.7        # ≈-3 dB (sits under SFX in mix)
var DEFAULT_SFX_VOLUME: float = 1.0          # 0 dB
var MUSIC_FADE_IN_SEC: float = 0.5
var MUSIC_FADE_OUT_SEC: float = 1.0
var SFX_LOOP_FADE_OUT_SEC: float = 0.1
var PITCH_VARIATION_SLIGHT_SEMITONES: float = 1.0
var PITCH_VARIATION_YES_SEMITONES: float = 2.0
var POLYPHONY_BONNIE_TRAVERSAL: int = 3
var POLYPHONY_ENVIRONMENTAL: int = 4
```

## Alternatives Considered

### Alternative 1: Decentralized Audio — Each System Creates Its Own AudioStreamPlayers
- **Description**: Traversal, NPC, and Level Manager each create and manage their own `AudioStreamPlayer` nodes, setting bus targets directly.
- **Pros**: No global dependency. Each system owns its audio completely. Simpler for prototyping.
- **Cons**: Bus hierarchy not enforced — any system could route audio to the wrong bus. Volume control requires reaching into every system. Polyphony limits impossible to enforce across systems. Format rules (OGG for music, WAV for SFX) not centrally enforced. Mute/unmute requires every system to implement independently. Sprint 1 stub behavior (graceful missing-file handling) must be duplicated in every caller.
- **Rejection Reason**: Audio is cross-cutting infrastructure. Decentralizing it duplicates every safeguard and makes the audio mix uncontrollable.

### Alternative 2: Bus Layout as Editor Resource (.tres File)
- **Description**: Define the Master → Music → SFX bus hierarchy in a `.tres` resource file, loaded by AudioManager at startup.
- **Pros**: Visual editing in Godot's Audio panel. Familiar pattern for Godot developers.
- **Cons**: `.tres` files are binary-ish serialized state — merge conflicts are common and hard to resolve. If the file is accidentally deleted or corrupted, buses don't exist. The bus layout is simple enough (3 buses, 2 parent-child relationships) that code creation is clearer than a resource file.
- **Rejection Reason**: Programmatic creation is self-healing, merge-conflict-free, and trivially readable. The bus hierarchy is 3 buses — it doesn't need a visual editor.

### Alternative 3: Event System with Signal-Based Audio Triggers
- **Description**: Gameplay systems emit signals (`sfx_requested`, `music_requested`); AudioManager connects to these signals and handles playback.
- **Pros**: Fully decoupled — callers don't need a reference to AudioManager. Testable via signal spying.
- **Cons**: Adds indirection that makes the call graph harder to follow. Signal connections must be established somewhere (either AudioManager finds all emitters, or each emitter finds AudioManager — same coupling, more steps). Direct API calls are simpler, debuggable, and already work via autoload. The "decoupling" is artificial — every system that plays sound already knows it wants to play sound.
- **Rejection Reason**: Direct API calls via autoload are simpler and equally testable. Signal indirection adds complexity without meaningful decoupling.

### Alternative 4: Full Audio Catalogue at Sprint 1
- **Description**: Register all 40+ event IDs in the registry from Sprint 1, even though audio files don't exist yet.
- **Pros**: All event IDs are in one place immediately. Calls to unregistered events are impossible.
- **Cons**: 39 registry entries pointing to non-existent files. Every `play_sfx` call generates a "file not found" warning — noisy console output during development. The registry is code, not data — adding 39 dummy entries is noise.
- **Rejection Reason**: Registry grows with the asset catalogue. Sprint 1 registers 1 event. Sprint 2+ registers more as assets are created. The stub pattern (unknown ID → error, missing file → warning) handles the gap cleanly.

## Consequences

### Positive
- All audio routing, volume, polyphony, and format rules live in one 253-line file
- 14 unit tests cover bus setup, volume clamping, mute/unmute, unknown event safety, and defaults
- Sprint 1 ships with the full API contract — gameplay code written now will work unchanged when audio assets arrive
- Adding new audio events requires only adding a line to `_register_events()` and the audio file
- Mute/unmute preserves stored volume — no state loss on toggle
- Programmatic bus creation self-heals if editor state is corrupted

### Negative
- Autoload creates global access — any system can play any sound, even sounds that don't belong to its domain. Naming conventions (event IDs prefixed by system: `bonnie_`, `npc_`, `env_`) provide soft enforcement.
- `load(path)` in `play_sfx()` does a synchronous resource load on first call for each event. For short WAV files this is sub-millisecond. For OGG music streams, `play_music()` should preload — current implementation loads synchronously, acceptable for Sprint 1 but may need `ResourceLoader.load_threaded_request()` for larger tracks.
- Polyphony limits are defined as exported knobs but NOT YET ENFORCED in the Sprint 1 implementation. Voice-stealing logic described in the GDD is deferred to Sprint 2. Current implementation creates a new `AudioStreamPlayer` per `play_sfx` call with no limit check.

### Risks
- **Risk**: Synchronous `load()` in `play_sfx()` causes a frame hitch when loading a large audio file for the first time.
  **Mitigation**: SFX files are short WAVs (sub-100KB). Music files are OGG streams. For Sprint 2, add preloading for known heavy assets or switch to `ResourceLoader.load_threaded_request()`.
- **Risk**: Godot 4.6 `AudioStreamRandomizer` API differs from training data. Pitch variation property name may be wrong.
  **Mitigation**: Mycelium constraint `blob:2c5668f4080f` flags this. Verify against `docs/engine-reference/godot/breaking-changes.md` before implementing pitch variation. Sprint 1 does not use `AudioStreamRandomizer`.
- **Risk**: Sprint 1 polyphony is unlimited — rapid `play_sfx` calls can create unbounded `AudioStreamPlayer` nodes.
  **Mitigation**: Each player auto-frees on `finished` signal. For short WAVs, node lifetime is <1 second. Acceptable for Sprint 1 with limited audio events. Polyphony enforcement is a Sprint 2 task.

## Performance Implications
- **CPU**: Negligible per-frame. AudioManager has no `_process()` or `_physics_process()` — it only runs when called. Bus setup is one-time in `_ready()`. Tween-based fades are Godot-managed.
- **Memory**: One `AudioStreamPlayer` node per active sound. Sprint 1: at most 1-2 active at any time. Full catalogue: bounded by polyphony limits (3 BONNIE + 4 environmental + 1 music + N×1 NPC = ~10 simultaneous voices maximum).
- **Load Time**: `_ready()` creates 2 buses + registers 1 event. Sub-millisecond. Full catalogue (40+ events) is dictionary insertions — still sub-millisecond.
- **Network**: N/A.

## Migration Plan
No migration needed — AudioManager was built as an autoload from Session 009 (Sprint 1). This ADR documents the existing implementation.

Sprint 2 migration tasks (not breaking changes):
1. Add 39+ event registrations to `_register_events()` as audio assets are created
2. Implement polyphony enforcement (voice-stealing per category)
3. Implement `AudioStreamRandomizer` for pitch variation (verify Godot 4.6 API first)
4. Add user config save/load for volume settings (AC-A06)
5. Consider `ResourceLoader.load_threaded_request()` for music streams if synchronous load causes hitches

## Validation Criteria
- [ ] All 14 existing GUT tests pass (`tests/unit/test_audio_manager.gd`)
- [ ] Music and SFX buses exist after `_ready()` with correct parent (Master)
- [ ] `play_sfx(&"nonexistent")` logs error, no crash (AC-A05)
- [ ] `stop_sfx_loop` / `stop_music` on inactive sound → silent no-op
- [ ] `set_volume(&"Master", 1.5)` clamps to 1.0 (0 dB)
- [ ] Mute + unmute preserves stored volume (AC-A07)
- [ ] `DEFAULT_MUSIC_VOLUME = 0.7` (below unity — music sits under SFX in default mix)
- [ ] Console output on startup: "AudioManager: buses configured (Master/Music/SFX), N events registered."
- [ ] `grep -r "AudioServer\.\|AudioStreamPlayer" src/gameplay/ src/camera/ src/level/` returns zero results outside AudioManager (no direct AudioServer access from gameplay)

## Related Decisions
- **GDD**: `design/gdd/audio-manager.md` — full design specification (approved)
- **ADR-001 InputManager**: Same autoload-as-infrastructure pattern; AudioManager is the audio equivalent
- **ADR-002 ViewportGuard**: Foundation layer peer — AudioManager depends on nothing, provides to all
- **ADR-004 BonnieController**: Primary caller — triggers all BONNIE traversal and vocal SFX
- **ADR-006 LevelManager**: Calls `play_music()` / `stop_music()` for level mood tracks
- **Mycelium constraint**: `blob:2c5668f4080f` — AudioStreamRandomizer pitch uses semitones (Godot 4.6), NOT frequency multipliers. Verify exact property before implementing.
- **Mycelium constraint**: `blob:d328f842c933` — Same pitch/semitone warning (duplicate note on different blob)

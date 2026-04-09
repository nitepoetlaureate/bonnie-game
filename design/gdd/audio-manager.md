# System GDD: Audio Manager

> **Status**: In Design
> **Author**: Michael Raftery + Hawaii Zeke
> **Last Updated**: 2026-04-09
> **System #**: 3 (Audio Manager)
> **Priority**: MVP — Foundation Layer
> **Implements Pillar**: "Chaos is Comedy, Not Combat" (primary); "BONNIE Moves Like She Means It" (supporting)

---

## 1. Overview

The Audio Manager governs BONNIE!'s entire audio pipeline: bus hierarchy, volume controls, format rules, and the playback API that all other systems use to trigger sound. It is not a gameplay system — it has no game logic, no state machine, no player-facing decisions. Its job is to ensure that when traversal fires a landing SFX, when an NPC reacts with a crunchy vocal exclamation, or when the apartment theme streams in the background, the right audio plays at the right volume with the right pitch variation, on the right bus, without dropping frames.

The bus structure is `Master → Music → [stream]` and `Master → SFX → [oneshots]`. Volume for each bus is independently controllable and saved to user config. Music streams as OGG; SFX plays as short uncompressed WAV. No uncompressed audio file may exist in the repository as a music asset — this is a hard constraint enforced at the pipeline level.

Audio is load-bearing for two things that cannot be faked: control feel and chaos feedback. A slide that sounds wrong undermines the traversal system. A cascade of NPC reactions that sounds thin undermines the chaos fantasy. The Audio Manager exists so those moments land.

---

## 2. Player Fantasy

The player never thinks about the audio system. They think about BONNIE. They think about the apartment. They think about Michael's reaction. The audio manager's success is measured by how thoroughly it disappears into the experience it serves.

What the player *does* notice is BONNIE. She sounds like a cat — specifically, like *this* cat. Her footsteps change under her paws when she crosses from hardwood to carpet. Her slide has the exact scraping, surprised quality of a cat who committed to a direction before checking where it led. Her rough landing has weight and then comedy — the thud, the moment of stillness, the cartoon recovery sound. Her meow is expressive. Her chirp is alert. Her purr, when she's happy, is content. The sounds are not abstract feedback — they are BONNIE's personality made audible.

NPC reactions sound like they were recorded in 1992 on a Genesis sound chip. Short, crunchy, perfectly expressive. Michael's surprise bark when BONNIE knocks something over is funnier because of the compression. Christen's delight sound when BONNIE rubs against her leg has the specific warmth of era-appropriate digitized audio. When NPCs cascade — when Michael's reaction trips Christen's — the vocal samples stack in ways that feel chaotic and earned.

Music sets the apartment's emotional temperature without announcing itself. At baseline, the apartment theme is cozy — something you'd leave on while doing other things. When the meter climbs, the music doesn't change dramatically; the environment does. The score is a mood, not a mechanic. Reference quality bar: Streets of Rage 2's ability to make you feel where you are without telling you how to feel about it.

---

## 3. Detailed Rules

### 3.1 Bus Structure

**Bus hierarchy:**

```
Master
├── Music  (OGG streaming — one track at a time)
└── SFX    (WAV oneshots — polyphonic)
        ├── BONNIE movement + action sounds
        ├── NPC vocal exclamation samples
        └── Environmental chaos SFX
```

**AudioManager Autoload:**
`AudioManager` is implemented as a Godot Autoload (project-wide script). This is an infrastructure exception to the singleton anti-pattern — it wraps `AudioServer` bus configuration and volume state, not mutable game state. All gameplay systems call it directly: `AudioManager.play_sfx(&"bonnie_land")`. No gameplay system touches `AudioServer` directly.

**Volume controls:**

| Control | Bus | Saved to user config |
|---------|-----|----------------------|
| `master_volume_db` | Master | Yes |
| `music_volume_db` | Music | Yes |
| `sfx_volume_db` | SFX | Yes |

Volumes stored in dB (Godot native). UI exposes linear sliders (0–100%) — converted to dB on write: `AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))`.

**Format rules (hard constraints):**

| Category | Format | Why |
|----------|--------|-----|
| Music | OGG Vorbis, streamed | Low memory — never fully loaded into RAM |
| SFX | WAV, uncompressed, short | Low-latency playback; no decode delay |
| NPC vocal samples | WAV, uncompressed, < 1 second | Same as SFX |
| Music in repository | OGG only | **No uncompressed music assets in repo, ever.** Pipeline rule. |

**Mute behavior:** Muting a bus sets its volume to `-80 dB` (effectively silent). The stored volume value is preserved — unmuting restores the previous level. A volume of `0` (`-inf dB`) is not the same as mute.

### 3.2 Audio Event Catalogue

All event IDs are snake_case. All gameplay systems call `AudioManager.play_sfx(&"event_id")` or `AudioManager.play_music(&"event_id")`. No system references file paths directly.

**BONNIE — Traversal SFX**

| Event ID | Loop | Pitch Variation | Trigger |
|----------|------|-----------------|---------|
| `bonnie_footstep_hardwood` | No | Yes (2–3 variants, random) | Each step during WALKING/RUNNING on hardwood |
| `bonnie_footstep_carpet` | No | Yes (2–3 variants, random) | Each step during WALKING/RUNNING on carpet |
| `bonnie_jump` | No | Slight | JUMPING state entry from ground |
| `bonnie_double_jump` | No | Slight | Double jump fires |
| `bonnie_wall_jump` | No | Slight | Wall jump from CLIMBING |
| `bonnie_climb_step` | No | Yes | Each move increment during CLIMBING |
| `bonnie_ledge_grab` | No | No | Ledge Parry success (FALLING/JUMPING → CLIMBING or LEDGE_PULLUP) |
| `bonnie_ledge_pullup` | No | No | LEDGE_PULLUP state entry |
| `bonnie_land_soft` | No | No | LANDING at speed below `skid_threshold` |
| `bonnie_land_skid` | No | No | LANDING with skid (above `skid_threshold`) |
| `bonnie_land_hard_skid` | No | No | LANDING with hard skid (above `hard_skid_threshold`) |
| `bonnie_slide_start` | No | No | SLIDING state entry |
| `bonnie_slide_loop` | **Yes** | No | Continuous during SLIDING state; fades out on exit |
| `bonnie_rough_landing` | No | No | ROUGH_LANDING state entry — impact thud |
| `bonnie_rough_landing_recover` | No | No | ROUGH_LANDING → WALKING transition — cartoon recovery |
| `bonnie_dazed` | **Yes** | No | Loops during DAZED state; stops on recovery |
| `bonnie_thud` | No | Yes | BONNIE collides with wall/object at speed |

**BONNIE — Vocal SFX**

| Event ID | Loop | Notes |
|----------|------|-------|
| `bonnie_meow_curious` | No | Idle, near unexplored space |
| `bonnie_meow_demanding` | No | Near NPC at low goodwill |
| `bonnie_meow_annoyed` | No | Picked up, cornered, or interrupted |
| `bonnie_chirp` | No | Alert, hunting mode — SNEAKING near prey |
| `bonnie_purr` | **Yes** | Ambient during IDLE/SNEAKING while near or on NPC in VULNERABLE state |
| `bonnie_eating` | No | Plays during fed payoff sequence |

**NPC — Vocal Samples (MVP: Michael + Christen, 4 emotions each)**

| Event ID | Notes |
|----------|-------|
| `npc_michael_surprise` | Crunchy, SNES/Genesis-era digitized — short, expressive |
| `npc_michael_anger` | |
| `npc_michael_delight` | |
| `npc_michael_fear` | |
| `npc_christen_surprise` | Same style; distinct voice character from Michael |
| `npc_christen_anger` | |
| `npc_christen_delight` | |
| `npc_christen_fear` | |

*(Additional NPCs: add 4 variants per NPC as levels are built.)*

**Environmental SFX**

| Event ID | Loop | Pitch Variation | Notes |
|----------|------|-----------------|-------|
| `env_object_knock_light` | No | Yes | Small objects knocked over |
| `env_object_knock_heavy` | No | Yes | Large or heavy objects |
| `env_glass_break` | No | No | Glass objects specifically |
| `env_liquid_spill` | No | No | Liquid from knocked containers |

**Music**

| Event ID | Loop | Format | Notes |
|----------|------|--------|-------|
| `level_02_apartment` | Yes | OGG | Level 2 apartment theme — cozy, chiptune original score |

*(Additional level tracks added as levels are built. Level 1 street theme is not MVP.)*

### 3.3 Playback Rules

**AudioManager API — the only valid interface for all gameplay systems:**

```gdscript
# One-shot SFX. volume_offset_db is additive on top of SFX bus volume.
AudioManager.play_sfx(event_id: StringName, volume_offset_db: float = 0.0) -> void

# Start a looping SFX. Caller is responsible for stopping it.
AudioManager.play_sfx_loop(event_id: StringName) -> void

# Stop a looping SFX. Fades out over a short default duration.
AudioManager.stop_sfx_loop(event_id: StringName) -> void

# Start a music track. Fades in over fade_in_sec.
AudioManager.play_music(event_id: StringName, fade_in_sec: float = 0.5) -> void

# Stop the current music track. Fades out over fade_out_sec.
AudioManager.stop_music(fade_out_sec: float = 1.0) -> void

# Set bus volume. linear_value is 0.0–1.0; AudioManager converts to dB internally.
AudioManager.set_volume(bus: StringName, linear_value: float) -> void
```

No gameplay system ever touches `AudioStreamPlayer`, `AudioServer`, or file paths directly. All calls go through AudioManager.

**Pitch variation:**

Events marked "Yes" for pitch variation use `AudioStreamRandomizer` on their `AudioStreamPlayer`. Randomizer `random_pitch` is specified in **semitones** (Godot 4.6) — not frequency multipliers. Exact values are in Section 4.

**Polyphony limits (per category):**

| Category | Max simultaneous voices |
|----------|------------------------|
| Footstep (bonnie_footstep_*) | 1 — each step interrupts the previous |
| BONNIE traversal SFX (non-footstep) | 3 |
| NPC vocal (per NPC) | 1 — only one emotional reaction per NPC at a time |
| Environmental SFX | 4 |
| Music | 1 — cross-fade handled by AudioManager |

If polyphony limit is exceeded, the oldest voice in the category is stopped and the new sound plays. Music is never interrupted mid-play except by explicit `stop_music` or `play_music` calls from Level Manager.

**Footstep timing:**

Footstep SFX are triggered by animation step events in BONNIE's walk/run cycle — not by a timer. BONNIE's animator emits `step_event` at foot-plant frames; BonnieController calls `AudioManager.play_sfx(&"bonnie_footstep_hardwood")` or `bonnie_footstep_carpet` based on the current surface material. Surface detection is a physics query on the tile beneath BONNIE's feet. Footstep rate changes naturally as walk/run animations have different frame counts.

**Looping SFX lifecycle:**

| Loop event | Start trigger | Stop trigger |
|-----------|---------------|--------------|
| `bonnie_slide_loop` | SLIDING state entry | SLIDING → any state exit |
| `bonnie_dazed` | DAZED state entry | DAZED → any state exit |
| `bonnie_purr` | IDLE/SNEAKING + near VULNERABLE NPC | BONNIE leaves IDLE/SNEAKING, or NPC leaves VULNERABLE |
| Level music | Level Manager `play_music()` call | Level Manager `stop_music()` call, or level exit |

The state that starts a loop is responsible for stopping it on exit. BonnieController does not leave a loop running across state transitions — `_change_state()` checks for active loops and stops them if the new state does not continue them.

**Music cross-fade:**

`play_music()` fades in the new track (default 0.5s) while `stop_music()` fades out the current track (default 1.0s). Level Manager sequences these: it calls `stop_music()` on level exit and `play_music()` on level entry. There is no simultaneous dual-track crossfade — music pauses between levels if fade times don't overlap. This is intentional: the apartment theme begins when the player arrives, not before.

### 3.4 Interactions with Other Systems

AudioManager is a dependency sink — it receives calls from other systems but never calls back into gameplay. All communication is one-directional: callers invoke the AudioManager API; AudioManager does not query game state.

**Caller: BONNIE Traversal System (6)**

- Calls `play_sfx(&"bonnie_[event]")` for all BONNIE traversal and vocal SFX
- Calls `play_sfx_loop` / `stop_sfx_loop` for `bonnie_slide_loop`, `bonnie_dazed`, `bonnie_purr`
- Footstep events are triggered by animation step events (not a timer) — BonnieController listens for the `step_event` signal from BONNIE's animator and calls AudioManager with the appropriate surface-variant event ID
- Surface material detection (hardwood vs. carpet) is BonnieController's responsibility — AudioManager receives only the resolved event ID
- Purr loop logic lives in BonnieController: it queries NPC proximity and NPC VULNERABLE state, then calls `play_sfx_loop` / `stop_sfx_loop` accordingly. AudioManager is unaware of NPC state.

**Caller: Reactive NPC System (9)**

- Calls `play_sfx(&"npc_[name]_[emotion]")` when an NPC reacts
- Polyphony constraint: 1 voice per NPC is enforced by AudioManager's polyphony limit. The NPC System must not fire two simultaneous reactions for the same NPC — if it does, the older sound stops. This is AudioManager's behavior, but the NPC System should not rely on it as a concurrency mechanism.

**Caller: Level Manager (5)**

- Calls `play_music(event_id, fade_in_sec)` on level entry
- Calls `stop_music(fade_out_sec)` on level exit or level restart
- Level Manager owns the music event ID selection; AudioManager just plays what it's given

**Caller: Environmental Chaos System (8)** *(not yet designed — provisional)*

- Will call `play_sfx` for `env_object_knock_light`, `env_object_knock_heavy`, `env_glass_break`, `env_liquid_spill` when objects are disturbed
- Event selection (light vs. heavy, glass vs. liquid) is the Environmental Chaos System's responsibility

**Caller: Dialogue UI System (18)** *(not yet designed — provisional)*

- Will call `play_sfx` for UI feedback sounds and dialogue event cues
- Interface is not yet defined; the existing AudioManager API is sufficient without changes

**AudioManager does NOT:**

- Query chaos meter level, NPC emotional state, or goodwill values
- Make any gameplay decisions
- Know who triggered a sound or why it was triggered

---

## 4. Formulas

### 4.1 Volume Conversion

`AudioManager.set_volume(bus, linear_value)` converts the UI linear value to dB before writing to the bus:

```
volume_db = linear_to_db(linear_value)
```

| `linear_value` | `volume_db` | Perceived level |
|---------------|-------------|-----------------|
| `0.0` | `-inf` dB | Silence |
| `0.1` | ≈ `−20.0` dB | Very quiet |
| `0.5` | ≈ `−6.0` dB | Half power |
| `1.0` | `0.0` dB | Unity gain (no amplification) |

**Mute behavior**: Muting sets `volume_db = -80.0`. The prior `linear_value` is stored in AudioManager state. Unmuting restores it via `linear_to_db(stored_value)`. A `linear_value` of `0.0` is not the same as mute — mute is a discrete flag.

**Safe range**: `linear_value ∈ [0.0, 1.0]`. Values above `1.0` are clamped; AudioManager does not allow amplification above unity on any bus.

### 4.2 Pitch Variation

Events with pitch variation use `AudioStreamRandomizer`. In Godot 4.6, the randomizer's pitch property is specified in **semitones** (not frequency multipliers — this is a post-4.3 change).

> ⚠ **Implementation trap**: Verify the exact property name against `docs/engine-reference/godot/breaking-changes.md` before implementation. The property may be `random_pitch` or `pitch_scale` depending on Godot version — do not assume from LLM training data.

| Variation label | Semitone range | `random_pitch` value |
|----------------|---------------|----------------------|
| `No` | None | `0.0` |
| `Slight` | ±1 semitone | `1.0` |
| `Yes` | ±2 semitones | `2.0` |

*Events using `Slight`: `bonnie_jump`, `bonnie_double_jump`, `bonnie_wall_jump`*
*Events using `Yes`: `bonnie_footstep_hardwood`, `bonnie_footstep_carpet`, `bonnie_climb_step`, `bonnie_thud`, `env_object_knock_light`, `env_object_knock_heavy`*

### 4.3 Voice-Stealing (Polyphony Enforcement)

When a `play_sfx` call would exceed a category's polyphony limit:

```
if active_voices[category].size() >= polyphony_limit[category]:
    oldest_voice = active_voices[category].front()
    oldest_voice.stop()
    active_voices[category].pop_front()

new_voice.play()
active_voices[category].push_back(new_voice)
```

Voice-stealing is instantaneous (no fade). Music is exempt — `play_music` never voice-steals; it requires an explicit `stop_music` call first.

---

## 5. Edge Cases

| Situation | Behavior |
|-----------|----------|
| `play_sfx` called with unknown event ID | Logs error to console, no sound plays, no crash |
| `stop_sfx_loop` called for a loop not currently playing | Silent no-op — not an error condition |
| `play_music` called while music is already playing | Current track stops (fade-out begins); new track fades in. No simultaneous dual-track crossfade — sequential only |
| `stop_music` called with no music playing | Silent no-op |
| `set_volume` called with value outside `[0.0, 1.0]` | Clamped silently to valid range; no error |
| BONNIE state-changes so fast a loop starts and stops in the same frame | `stop_sfx_loop` from state exit cancels `play_sfx_loop` from state entry in the same frame — no audible artifact |
| Two NPCs react simultaneously | Both play — each NPC has an independent 1-voice polyphony pool. Simultaneous reactions from different NPCs are intended and by design |
| BONNIE crosses a tile boundary mid-footstep cycle | Next `step_event` resolves to the new tile's material. No buffering — footstep sounds switch immediately on the next step |
| Game is paused | AudioManager respects `SceneTree.paused` — music and all SFX pause with the tree. Bus volumes are not modified; playback resumes at the same position on unpause |
| User drags volume slider to 0 then back | Stored `linear_value` is updated continuously. Mute flag is independent — mute does not overwrite stored volume, so unmute always restores the last explicit setting |

---

## 6. Dependencies

AudioManager is Foundation Layer — it has no upstream game system dependencies.

### Downstream Systems (depend on AudioManager)

| System | Dependency type | Interface used |
|--------|----------------|----------------|
| BONNIE Traversal System (6) | Hard | `play_sfx`, `play_sfx_loop`, `stop_sfx_loop` for all BONNIE SFX |
| Reactive NPC System (9) | Hard | `play_sfx` for NPC vocal samples |
| Level Manager (5) | Hard | `play_music`, `stop_music` for level tracks |
| Environmental Chaos System (8) | Hard *(GDD not yet written)* | `play_sfx` for `env_*` events |
| Dialogue UI System (18) | Soft *(GDD not yet written)* | `play_sfx` for UI and dialogue audio cues |

### Engine Dependency

AudioManager wraps `AudioServer` (Godot built-in). No other game system is a dependency. If AudioServer is unavailable (e.g., headless export), AudioManager methods no-op silently — this is not an expected runtime condition for BONNIE.

### Bidirectional Consistency Note

BONNIE Traversal (6) and Reactive NPC (9) GDDs are approved; they should each reference AudioManager (3) in their own Dependencies sections if not already present. Environmental Chaos (8) and Dialogue UI (18) must add this dependency when their GDDs are written.

---

## 7. Tuning Knobs

All knobs are exported constants on the AudioManager Autoload script, editable in the Godot Inspector without code changes.

| Knob | Default | Safe Range | Too High | Too Low |
|------|---------|------------|----------|---------|
| `DEFAULT_MASTER_VOLUME` | `1.0` (0 dB) | `0.5 – 1.0` | Clipping on loud moments | Inaudible at start |
| `DEFAULT_MUSIC_VOLUME` | `0.7` (≈−3 dB) | `0.3 – 1.0` | Music overwhelms SFX | Music is inaudible |
| `DEFAULT_SFX_VOLUME` | `1.0` (0 dB) | `0.5 – 1.0` | SFX harsh and fatiguing | Audio feedback absent |
| `MUSIC_FADE_IN_SEC` | `0.5` | `0.0 – 3.0` | Music entrance feels sluggish | Jarring cut-in |
| `MUSIC_FADE_OUT_SEC` | `1.0` | `0.0 – 5.0` | Level exit feels sluggish | Jarring cut-out |
| `SFX_LOOP_FADE_OUT_SEC` | `0.1` | `0.0 – 0.5` | Loop tails bleed into next state | Audible click on stop |
| `PITCH_VARIATION_SLIGHT_SEMITONES` | `1.0` | `0.0 – 2.0` | Jumps sound detuned | Jump sounds robotic |
| `PITCH_VARIATION_YES_SEMITONES` | `2.0` | `0.0 – 4.0` | Footsteps sound cartoony | Footsteps sound robotic |
| `POLYPHONY_BONNIE_TRAVERSAL` | `3` | `2 – 5` | Wasteful; unlikely to saturate | Movement sounds cut off |
| `POLYPHONY_ENVIRONMENTAL` | `4` | `2 – 8` | Crowded during cascade events | Chaos cascade sounds sparse |

**Note**: `DEFAULT_MUSIC_VOLUME` is intentionally below unity — music should sit under SFX in the default mix. Adjust if specific tracks feel too quiet or too present.

---

## 8. Acceptance Criteria

| ID | Criterion | Pass condition |
|----|-----------|----------------|
| AC-A01 | AudioManager Autoload registered | Project Settings → AutoLoad lists `AudioManager`. All scenes can call `AudioManager.play_sfx()` without errors. |
| AC-A02 | Bus hierarchy configured | Godot Audio panel shows: Master → Music, Master → SFX. No other top-level buses. |
| AC-A03 | `play_sfx` routes to SFX bus | Call `AudioManager.play_sfx(&"bonnie_jump")` — audio plays, visible on SFX bus VU meter, not Music bus. |
| AC-A04 | `play_music` routes to Music bus | Call `AudioManager.play_music(&"level_02_apartment")` — audio streams, visible on Music bus VU meter. |
| AC-A05 | Unknown event ID is safe | Call `AudioManager.play_sfx(&"nonexistent_event")` — error logged to console, no crash, no audio. |
| AC-A06 | Volume persists across sessions | Set music volume to 50%, quit game, relaunch — music volume loads at 50%. |
| AC-A07 | Mute preserves stored volume | Set SFX to 80%, mute SFX bus, unmute — volume returns to 80%, not 0%. |
| AC-A08 | SFX loop lifecycle correct | Trigger SLIDING state — `bonnie_slide_loop` starts. Exit SLIDING — loop stops within 0.1s (within `SFX_LOOP_FADE_OUT_SEC`). |
| AC-A09 | Polyphony enforced | Rapidly fire 5 `bonnie_jump` sounds — at most 3 simultaneous voices active on the BONNIE traversal polyphony pool. |
| AC-A10 | Pitch variation audible | 10 consecutive `bonnie_footstep_hardwood` calls — audible pitch variation across the sequence. |
| AC-A11 | No uncompressed music in repo | `git ls-files assets/audio/music/` returns zero `.wav` files. All music is `.ogg`. |
| AC-A12 | All catalogue event IDs playable | A test script iterates every event ID from Section 3.2 and calls the appropriate `play_sfx` or `play_music` — zero "unknown event" errors. |

---

## Open Questions

| # | Question | Owner | Status |
|---|----------|-------|--------|
| OQ-A01 | What is the exact Godot 4.6 property name for `AudioStreamRandomizer` pitch variation in semitones? (`random_pitch`? `pitch_scale`?) Verify against `docs/engine-reference/godot/breaking-changes.md` before implementation — this is a known post-4.3 API change. | godot-specialist | Open |
| OQ-A02 | How does the surface type detection work at the tilemap level? Which physics layer or tile metadata property signals "hardwood" vs "carpet"? Needs coordination with Level Manager (5) tilemap setup. | gameplay-programmer | Open |
| OQ-A03 | What is the production method for NPC vocal samples? Original voice recordings processed through a bitcrusher/sample-rate reducer, or created with a chiptune tool? The answer affects asset pipeline (recording sessions vs. tool workflow). | audio-director (Michael) | Open |
| OQ-A04 | Who is composing `level_02_apartment`? When is the OGG asset expected? The audio pipeline can be validated with a placeholder track, but the final mix depends on the actual composition. | audio-director (Michael) | Open |

# System GDD: BONNIE Traversal System

*Status: Approved*
*Created: 2026-04-05*
*System #: 6 (BONNIE Traversal System)*
*Priority: MVP — prototype immediately after this GDD is approved*

---

## 1. Overview

BONNIE moves like she means it. The traversal system governs every physical verb
BONNIE has: sneaking, walking, running, sliding, jumping, double-jumping, wall-jumping,
ledge-parrying, falling, climbing, squeezing, and the various states of recovery
when things go wrong.

The design principle is a deliberate split between **input** and **result**:

> Controls are snappy. Physics consequences are real.

BONNIE responds to input immediately — there is no input lag, no animation lock,
no waiting for a step cycle to complete before turning. The player's intent lands
on screen in the same frame it was entered. However, at speed, BONNIE is on
hardwood floors with cat claws — momentum carries through, turns generate skids,
jumps commit to arcs, and slides don't stop until they stop. The skill expression
lives in managing consequences, not wrestling with unresponsive controls.

Reference bar for input feel: **Streets of Rage 2**. Reference bar for movement
vocabulary and consequence: **clumsy feline Ryu Hayabusa**.

The traversal system is the highest-priority technical risk in the project. If
BONNIE doesn't feel right to move, nothing built on top of her will compensate.
This GDD must be prototyped immediately after approval.

---

## 2. Player Fantasy

> You zoom across the apartment at full speed, can't stop, Kaneda-slide across
> the kitchen floor, pop up mid-slide into a jump, land on the counter, and
> knock everything over. You did not plan any of that. It was perfect.

BONNIE's traversal delivers two distinct pleasures that coexist and play off
each other:

**The stealth read.** BONNIE is a black cat. She can move through a room without
making a sound, hugging walls, staying low — invisible until she isn't.
Sneaking is patient, deliberate, satisfying in its own right. The player
reads the room. They identify the pressure point. They position.

**The manic burst.** Then BONNIE commits. She hits full sprint and the physics
take over. The Kaneda slide. The overcorrected jump. The table cleared in one
bound. At full tilt, BONNIE is a force of nature that the player is directing
but not fully controlling — and that loss of perfect control is the game.

The transition between these two modes — from silent stalker to absolute chaos
engine — is the traversal system's core emotional beat. Both modes should feel
incredible to inhabit. Neither should feel like the "wrong" way to play.

**What the player should never feel:** fighting the controls. If they slide into
something they didn't mean to, it should feel like a physics consequence, not
input lag. If a jump goes wrong, they should be able to tell why. Bad camera
and bad controls are the two things players never stop complaining about.
Both are first-class constraints, not polish problems.

---

## 3. Detailed Rules

### 3.1 Movement States

BONNIE exists in exactly one movement state at any frame. Transitions are
immediate (no queuing, no animation lock on input).

---

#### IDLE
Standing still. No input.

- Stimulus radius: `idle_stimulus_radius` (small — presence barely felt)
- `comfort_receptivity` contribution: none from movement
- NPC awareness: minimal
- Exits to: SNEAKING (slow input), WALKING (normal input), RUNNING (run input or
  held input during WALKING above `run_buildup_threshold`), JUMPING (jump input)

---

#### SNEAKING
Slow, deliberate, quiet. BONNIE is hunting or observing.

- Speed cap: `sneak_max_speed` (default: ~30% of `run_max_speed`)
- Stimulus radius: `sneak_stimulus_radius` — significantly smaller than WALKING.
  NPCs are less likely to notice BONNIE's proximity while sneaking.
- Sound: silent. BONNIE's footsteps do not register as environmental stimuli
  in SNEAKING state.
- Input: held sneak button (or analog stick below `sneak_threshold`)
- Exits to: IDLE (no input), WALKING (normal input without sneak held), JUMPING
  (jump input — quiet jump; reduced `jump_velocity` option, see Section 4.2)

---

#### WALKING
Normal movement. Default ground state with directional input.

- Speed: `walk_speed`
- Stimulus radius: `walk_stimulus_radius`
- Sound: light footstep audio
- **Run is a dedicated button.** WALKING does not automatically become RUNNING
  over time. The player must hold the run button to run.
- `autorun_enabled` is an accessibility toggle (off by default). When on,
  held directional input past `run_buildup_time` auto-escalates to RUNNING
  without the run button. This setting is for players who cannot comfortably
  hold two inputs simultaneously.
- Exits to: IDLE, SNEAKING, RUNNING (run button held + direction input), JUMPING,
  SLIDING (slide input above `slide_trigger_speed`)

---

#### RUNNING
Full speed. Momentum is live.

- Speed: up to `run_max_speed`
- Stimulus radius: `run_stimulus_radius` — large. At full sprint, BONNIE's
  presence is felt throughout the room.
- Sound: full footstep audio, panting optional above sustained duration
- **Direction reversal at speed** triggers a brief skid before new direction takes
  hold. Input registers immediately but velocity carries through `run_skid_duration`.
- **Stopping at speed** triggers a forward-momentum skid (see SLIDING).
- Exits to: IDLE (gradual decel), SLIDING (above `slide_trigger_speed` + opposing
  input or explicit slide input), JUMPING, CLIMBING (approach climbable surface)

---

#### SLIDING
The Kaneda. BONNIE is committed to forward momentum with minimal ability to steer.

Triggered when:
1. Running at speed above `slide_trigger_speed` + directional input opposes
   current velocity (trying to stop or reverse)
2. Explicit slide input (e.g., hold down/crouch while running)

- Horizontal velocity: decelerates slowly. `slide_friction` is very low.
- Steering: limited — `slide_air_control_factor` applies (small directional nudge
  only; cannot reverse mid-slide)
- Collision during slide: objects in BONNIE's path receive `slide_collision_force`
  — she does not stop, she hits through at reduced momentum. Environmental chaos
  potential is high.
- **Pop jump**: jump input during SLIDING launches BONNIE at current slide velocity
  + full `jump_velocity`. This is the high-skill move: slide → pop → airborne with
  full horizontal momentum.
- Exits to: WALKING/IDLE (velocity decays to `walk_speed`), JUMPING (pop jump),
  DAZED (slide into wall at speed above `daze_collision_threshold`), CLIMBING
  (slide into climbable surface — BONNIE grabs it)

---

#### JUMPING
Airborne from voluntary jump input.

Two jump types based on input:
- **Tap**: short hop — `hop_velocity` vertical, full horizontal momentum preserved
- **Hold**: full jump — `jump_velocity` vertical (higher), horizontal momentum preserved

**Double jump**: available after first jump. Second jump must be input before
`double_jump_window` expires (frames from peak of first jump — apex-locked, not
available the moment you leave the ground). Double jump provides `double_jump_velocity`
vertical boost. BONNIE does a little twist in the air. It looks intentional.
It is not always intentional.

**Post-double-jump air control is severely reduced.** After the second jump fires,
BONNIE is twisted and committed — `post_double_jump_air_control` applies, which is
near zero. She can no longer steer meaningfully. This is by design: the double jump
launches BONNIE toward something (a ledge, a wall, a surface) and the player is now
committed to that arc. The skill expression is the *approach* — get the jump right,
then the LEDGE PARRY (see Section 3.2) is what determines whether you stick it.

**The intended high-skill combo**: run → jump → at apex → double jump toward ledge →
restricted lateral control commits BONNIE to the approach → execute LEDGE PARRY at
the right moment → grab. Players who internalize this sequence will be running wall-
to-wall at height in ways that feel kinetic and expressive. The reduced post-double
air control is what gives the parry its weight — you're not floating into a safe grab,
you're committing and then reacting.

- Air control (first jump): `air_control_force` — less than ground, more than zero.
  BONNIE can nudge her arc but not fully redirect.
- Air control (after double jump): `post_double_jump_air_control` — near zero.
  Committed.
- Horizontal momentum: carried from launch state. Running jump >> standing jump
  in horizontal reach.
- Exits to: LANDING (touches ground), ROUGH_LANDING (fall above threshold),
  CLIMBING (LEDGE PARRY success on climbable surface), FALLING (apex reached
  without landing)

---

#### FALLING
Airborne from non-jump source: walked off edge, missed jump, knocked off surface.

- Same air control as JUMPING (first jump air control, not post-double-jump)
- **Fall tracking**: distance fallen is tracked per-fall. If `fall_distance_pixels`
  exceeds `rough_landing_threshold` without a cushion surface, landing triggers
  ROUGH_LANDING instead of LANDING.
- Cushion surfaces (see Section 3.3) interrupt fall tracking and reset fall distance.
- **LEDGE PARRY available** during FALLING (see Section 3.2).
- Exits to: LANDING, ROUGH_LANDING, CLIMBING (LEDGE PARRY success on climbable
  surface), LEDGE_PULLUP (LEDGE PARRY success on platform edge)

---

#### LANDING
Brief grounded state immediately after any airborne → ground contact below
rough-landing threshold.

- Duration: `landing_window` frames (2–4 frames)
- **Skid**: horizontal velocity at landing determines skid character:
  - Below `clean_land_threshold`: clean landing, immediate control
  - Above `skid_threshold`: skid — deceleration is dramatically reduced for
    `skid_duration` seconds. BONNIE is still moving. Player can steer the skid.
  - Above `hard_skid_threshold`: hard skid — longer duration, reduced steering,
    brief landing stumble animation before control returns
- Full input responsiveness resumes when velocity drops below `walk_speed` OR
  `skid_duration` expires (whichever first)
- Exits to: WALKING/IDLE (velocity decays), SLIDING (jump input during skid
  converts to slide-out)

---

#### CLIMBING
On a vertical or near-vertical climbable surface.

- Speed: `climb_speed` (slow, deliberate — slower than SNEAKING)
- Climbable surfaces: designated `Climbable` nodes only. Surface material logic:
  soft/grip surfaces (carpet, fabric, curtains, rope, cat trees, door frames,
  shelving uprights) = climbable. Hard smooth surfaces (metal, glass, hardwood,
  tile, painted drywall) = NOT climbable. Level design must tag all surfaces.
- Input: up/down moves along surface; left/right detaches (BONNIE pushes off
  and enters FALLING/JUMPING)
- Can drop from any height — BONNIE lets go and enters FALLING
- **Wall jump**: from a climbable vertical surface, jump input launches BONNIE
  perpendicular to the surface with `wall_jump_velocity`. Horizontal momentum
  carries away from wall. Double jump resets on wall contact (touching any
  climbable surface mid-air restores the double jump).
- **Slip chance**: if BONNIE is in hunger-boost state, periodic slip events
  reduce velocity briefly. Never causes a fall without player input — slips
  are speed interrupts, not detaches.
- Exits to: JUMPING/FALLING (push off or wall jump), LEDGE_PULLUP (reach top of surface — same animation as Ledge Parry success, auto-triggered, no input required)

---

#### SQUEEZING
Moving through narrow passages below `squeeze_height_threshold`.

- Auto-triggered: when BONNIE enters a space below her standing height
- Speed: `squeeze_speed` (slow — between sneak and walk)
- Stimulus radius: same as SNEAKING — very small. BONNIE is hidden.
- BONNIE cannot be seen by NPCs while squeezing (she is under/behind something)
- Exits to: WALKING (passage clears above `squeeze_height_threshold`),
  IDLE (stop input)

---

#### DAZED
Brief loss of control from moderate impact: slide-into-wall above threshold,
botched landing, minor fall, getting trapped.

- Duration: `daze_duration` seconds (short — 0.8–1.5s)
- Input: accepted but no movement output. BONNIE stumbles/shakes.
- Visual: stars or equivalent cartoon indicator
- Audio: comic daze SFX
- No gameplay penalty beyond the time cost — the level continues around BONNIE
- Exits to: WALKING (timer expires)

---

#### LEDGE_PULLUP
Brief recovery state after a successful LEDGE PARRY on a platform edge.

- Duration: `pullup_duration` frames (short — 6–12 frames)
- BONNIE's position snaps to the top of the platform edge
- Brief animation: BONNIE scrambles up, lands on top
- No input during pullup animation — she's committing to the surface
- Exits to: IDLE (pullup complete, full control restored)

---

#### ROUGH_LANDING
Extended recovery from a fall above `rough_landing_threshold` (roughly one full
story — ~18 feet real-world equivalent in pixel distance).

- Duration: `rough_landing_duration` seconds (longer than DAZED — 2.0–3.5s)
- Input: partially accepted — BONNIE can begin slow movement during recovery
  but full speed is locked until recovery complete
- Visual: dramatic landing animation — BONNIE is flat for a beat, then slowly
  stands. Felix the Cat energy. Looney Tunes physics.
- Nine Lives framing: this *can* be a mini-game trigger. A fall that should have
  killed anyone else triggers a BONNIE-specific "and somehow she survived that" sequence.
- No permanent damage. No death. BONNIE always gets up.
- Exits to: WALKING (recovery complete)

---

### 3.2 Ledge Parry

BONNIE does not auto-grab ledges. If she falls off something, she falls. The LEDGE
PARRY is a **pure timing mechanic** — cat-like reflexes or you go down.

**When it's available**: during FALLING or JUMPING, when BONNIE is within
`parry_detection_radius` of a ledge edge or climbable wall surface. The window is
not telegraphed to the player beyond BONNIE's proximity to geometry. There is no
flashing prompt, no ghost hand, no highlighted ledge. You either feel it or you don't.

**How to execute**: press the grab/parry button within `parry_window_frames` of the
moment BONNIE's body passes the ledge plane. The window is tight. This is intentional.
Players who learn the timing will run around at height. Players who don't will fall,
which is also fine — BONNIE survives.

**On success — platform edge**: BONNIE transitions to LEDGE_PULLUP. She scrambles
up onto the surface. Short animation, then full control.

**On success — climbable wall surface**: BONNIE transitions to CLIMBING. She digs in
and is now on the wall. From here, wall jump is available.

**On failure**: BONNIE continues FALLING. No penalty beyond the fall itself. No
"almost got it" state. You missed; she falls.

**Nine Lives connection**: a failed LEDGE PARRY that results in a ROUGH_LANDING is
a prime Nine Lives trigger — BONNIE almost had it, absolutely did not have it, and
landed hard. Looney Tunes.

**The double-jump combo**: the intended high-skill sequence is:
run → jump → at apex → double jump toward target → reduced post-double air control
commits BONNIE to approach → LEDGE PARRY at the right moment → stick it.
The reduced post-double-jump control is what gives the parry its weight.
You don't float safely into a grab; you commit to the arc and then react.

```
on grab_button_pressed (during FALLING or JUMPING):
    if within parry_detection_radius of ledge or climbable surface:
        if within parry_window_frames of ledge_plane_crossing:
            if surface is Climbable (wall):
                transition_to(CLIMBING)
            else:  # platform edge
                transition_to(LEDGE_PULLUP)
        else:
            pass  # missed window — FALLING continues
```

---

### 3.3 Jump Input Model

```
on jump_button_pressed:
    if is_on_floor() or coyote_timer > 0:
        start jump input window
        apply hop_velocity immediately

on jump_button_held (within jump_hold_window):
    # Additive vertical force while held, up to max
    velocity.y -= jump_hold_force * delta
    # Clamps when jump_velocity ceiling reached

on jump_button_released (or hold_window expires):
    # Jump arc locked in
    end jump input window

on jump_button_pressed (while airborne, within double_jump_window):
    apply double_jump_velocity
    # Horizontal velocity may be partially redirected by current input direction
    play double_jump_animation
```

**Coyote time**: `coyote_timer` gives a small grace window (4–6 frames) after
walking off an edge where BONNIE can still jump. Standard feel-good platformer
technique. Never announce this to the player. It should feel like BONNIE is
good at her job.

**Jump buffering**: jump input is buffered for `jump_buffer_frames` (4–8 frames).
If BONNIE is about to land and the player presses jump just before touchdown,
the jump fires on landing. Also never announced.

---

### 3.4 Cushion Surfaces and Fall Interrupts

Certain surfaces interrupt a fall and reset fall distance tracking, preventing
ROUGH_LANDING even in a long fall:

| Surface Type | Example | Effect |
|---|---|---|
| Climbable (auto-grab) | Curtain, shelving | Grab triggers CLIMBING — fall ends |
| Soft landing | Couch cushion, pile of laundry, bed | Landing impact reduced, skid threshold doubled |
| Intermediate platform | Shelf, table mid-fall | Normal LANDING rules apply, fall distance resets |
| Bounce surface | (level-specific) | Launches BONNIE upward — comedic |

A fall from four stories onto a couch cushion is a soft landing. A fall from
one story straight to kitchen tile is a hard LANDING that may skid. A fall from
two stories to kitchen tile with nothing between them is ROUGH_LANDING.

---

### 3.4 Stimulus Radius by Movement State

BONNIE's physical presence in the world creates ambient stimuli for NPCs and
interactive objects before any direct interaction occurs.

| State | Stimulus Radius | NPC Awareness Impact |
|---|---|---|
| SNEAKING | `sneak_stimulus_radius` (small) | NPCs rarely notice |
| IDLE | `idle_stimulus_radius` (small-medium) | NPCs may notice in AWARE threshold |
| WALKING | `walk_stimulus_radius` (medium) | NPCs enter AWARE if within range |
| RUNNING | `run_stimulus_radius` (large) | NPCs enter AWARE at distance |
| SLIDING | `run_stimulus_radius` + `slide_bonus` | Elevated — the sound and motion of a slide is conspicuous |
| CLIMBING | `sneak_stimulus_radius` | Quiet |
| SQUEEZING | `sneak_stimulus_radius` | Hidden |

---

### 3.5 The Nine Lives Principle

BONNIE does not die. She does not take health damage. She does not have a game-over
state. The physics consequences of traversal errors are **setbacks**, not **punishments**.

> Tom & Jerry logic. Felix the Cat logic. Looney Tunes logic. The Roadrunner
> never truly gets hurt. BONNIE always gets up.

The DAZED and ROUGH_LANDING states are the system's consequences for poor
traversal decisions. They cost time. They are comedic. They may leave BONNIE in
a bad position (in the middle of an NPC's path, in a room she didn't mean to
enter). But she gets up.

The **Nine Lives System** (System 16) is the formal framing of this: near-disaster
events feed into a separate tracking system that can trigger mini-games and
narrative beats. The traversal system's job is to identify and emit the events —
what happens next is Nine Lives' concern.

Events that qualify as Nine Lives triggers:
- ROUGH_LANDING
- DAZED from collision above `nine_lives_daze_threshold`
- Getting trapped (SQUEEZING into dead end and unable to exit)
- Any physics event that would have been fatal in a different game

---

## 4. Formulas

All values are for `CharacterBody2D` with `move_and_slide()`. `delta` is frame
delta in seconds. Horizontal velocity and vertical velocity are tracked separately.

---

### 4.1 Horizontal Movement

```gdscript
# Target speed based on input and current state
var target_speed: float = input_direction.x * get_state_max_speed()

# Determine acceleration/deceleration factor
var accel: float
if input_direction.x != 0:
    accel = ground_acceleration  # snappy toward target
else:
    accel = ground_deceleration  # carry-through toward 0

# Apply momentum carry-through modifiers
if current_state == SLIDING:
    accel = slide_friction  # very low — BONNIE doesn't stop
elif in_skid_window:
    accel = ground_deceleration * skid_friction_multiplier  # reduced stop

velocity.x = move_toward(velocity.x, target_speed, accel * delta)
```

| Variable | Description | Default |
|---|---|---|
| `ground_acceleration` | How fast BONNIE reaches target speed | `800 px/s²` |
| `ground_deceleration` | How fast BONNIE stops with no input | `600 px/s²` |
| `slide_friction` | Deceleration force during SLIDING | `80 px/s²` |
| `skid_friction_multiplier` | Multiplier on deceleration during landing skid | `0.15` |

### 4.2 Jump Velocities

```gdscript
# Tap jump (short press — hop)
velocity.y = -hop_velocity

# Hold jump (additive while held, per-frame)
if jump_held and jump_hold_timer < jump_hold_window:
    velocity.y -= jump_hold_force * delta
    velocity.y = max(velocity.y, -jump_velocity)  # ceiling

# Double jump (mid-air)
velocity.y = -double_jump_velocity
# Partial horizontal redirect:
velocity.x = lerp(velocity.x, input_direction.x * run_max_speed, double_jump_redirect_factor)
```

| Variable | Description | Default | Range |
|---|---|---|---|
| `hop_velocity` | Tap jump vertical velocity | `280 px/s` | `200–350` |
| `jump_velocity` | Full hold jump ceiling | `480 px/s` | `380–580` |
| `jump_hold_force` | Additive force per second while held | `900 px/s²` | `600–1200` |
| `jump_hold_window` | Max frames of additive hold | `12 frames` | `8–18` |
| `double_jump_velocity` | Second jump vertical velocity | `380 px/s` | `280–460` |
| `double_jump_redirect_factor` | Horizontal redirect applied at moment double jump fires | `0.45` | `0.2–0.7` |
| `post_double_jump_air_control` | Air control force after double jump fires (near zero — committed arc) | `30 px/s²` | `0–80` |

### 4.3 Landing Skid

```gdscript
func on_landed():
    var impact_speed: float = abs(velocity.x)
    
    if impact_speed < clean_land_threshold:
        pass  # clean, no skid
    elif impact_speed < hard_skid_threshold:
        begin_skid(impact_speed / run_max_speed * skid_base_duration)
    else:
        begin_hard_skid(impact_speed / run_max_speed * hard_skid_base_duration)

func begin_skid(duration: float):
    skid_active = true
    skid_timer = duration
    # skid_friction_multiplier applied in movement formula above

func on_skid_tick(delta: float):
    skid_timer -= delta
    if skid_timer <= 0 or abs(velocity.x) < walk_speed:
        skid_active = false
```

| Variable | Description | Default |
|---|---|---|
| `clean_land_threshold` | Speed below which landing is always clean | `80 px/s` |
| `skid_threshold` | Speed above which skid begins | `180 px/s` |
| `hard_skid_threshold` | Speed above which hard skid triggers | `320 px/s` |
| `skid_base_duration` | Seconds of skid at run_max_speed (scales with speed) | `0.6s` |
| `hard_skid_base_duration` | Hard skid duration at full speed | `1.1s` |

### 4.4 Fall Distance and Rough Landing

```gdscript
var fall_start_y: float
var fall_distance: float = 0.0

func on_left_ground():
    if not jumped:  # walked off edge / knocked off
        fall_start_y = global_position.y

func on_tick_falling():
    fall_distance = global_position.y - fall_start_y

func on_cushion_surface():
    fall_distance = 0.0  # reset — cushion interrupted fall

func on_landed():
    if fall_distance >= rough_landing_threshold:
        enter_state(ROUGH_LANDING)
    else:
        # Normal LANDING, skid rules apply
        on_landed_normal()
    fall_distance = 0.0
```

| Variable | Description | Default |
|---|---|---|
| `rough_landing_threshold` | Pixel distance for rough landing (~18ft equiv.) | `144 px` |

*(At an assumed scale of ~8 pixels per real-world foot, 144px ≈ 18 feet.
Scale to match final art proportions during prototype calibration.)*

### 4.5 Speed Values by State

| State | Speed | Notes |
|---|---|---|
| SNEAKING | `80 px/s` | Cap, not target — can be slower |
| WALKING | `180 px/s` | Default ground move |
| RUNNING | `420 px/s` | Max horizontal speed |
| SLIDING | Carries from run, decays slowly | No cap — can exceed run speed briefly on slope |
| CLIMBING | `90 px/s` | Vertical only |
| SQUEEZING | `100 px/s` | Horizontal only |

---

## 5. Edge Cases

**Q: BONNIE is mid-slide and an NPC walks into her path.**
A: BONNIE does not stop. The slide collision force registers as an environmental
stimulus to the NPC. The NPC enters AWARE or REACTING depending on their
current `emotional_level` and the impact intensity. BONNIE continues sliding
with reduced velocity post-collision. This is a feature, not a bug.

**Q: BONNIE attempts to jump immediately after landing (before skid clears).**
A: Jump input during skid window: jump fires immediately (no lock), with current
skid velocity carried into the jump. This enables the "pop up mid-skid" move —
BONNIE launches with full horizontal momentum. Intended and powerful.

**Q: Double jump used — then BONNIE grabs a climbable surface. Is double jump restored?**
A: Yes. Touching any grounded surface (floor, platform, or climbable grab) restores
the double jump. Standard platformer rule.

**Q: BONNIE is SQUEEZING and the entrance collapses or an NPC blocks the exit.**
A: BONNIE enters DAZED if she is wedged (velocity goes to zero while trying to
exit squeeze). This is a Nine Lives trigger candidate. She cannot be permanently
stuck — level design rules must ensure all squeeze passages have exit paths.

**Q: Slide into a wall below `daze_collision_threshold`.**
A: BONNIE stops, velocity zeroed, enters IDLE. No DAZED. Sub-threshold wall contact
is a soft stop — just a bump. Comic bump sound, brief wall-stare animation.

**Q: BONNIE is in SNEAKING and jumps — is it a quiet jump?**
A: Yes. Jump from SNEAKING uses `hop_velocity` as default (quieter, smaller).
Full hold jump is available from SNEAK but breaks stealth — BONNIE exits SNEAKING
mid-air and her stimulus radius expands on landing.

**Q: ROUGH_LANDING mid-NPC-chase (VS scope — antagonist NPC is pursuing BONNIE).**
A: NPC continues toward BONNIE's position. ROUGH_LANDING recovery is a genuine
vulnerability window. This is intentional — big falls during a chase are risky.

**Q: Player holds run input while BONNIE is in DAZED.**
A: Input is accepted but produces no movement. Input is NOT buffered through DAZED
(unlike jump buffering). BONNIE exits DAZED and must provide fresh input. This
prevents the player from pre-queueing their way past the consequence.

**Q: What is BONNIE's maximum falling speed? Does she accelerate infinitely?**
A: `fall_velocity_max` clamps terminal velocity. Prevents extreme impact values
from long falls that would otherwise create oversized rough landing durations.

---

## 6. Dependencies

**This system depends on:**
- **Input System (1)** — all movement driven by input events. Frame-perfect
  input reading is non-negotiable (see Player Fantasy section).
- **Viewport / Rendering Config (2)** — pixel scale determines all distance values
  in this document. Values above assume 720×540 internal render. Must recalibrate
  if viewport changes.

**Systems that depend on this:**
- **Camera System (4)** — must lead BONNIE's movement direction, provide sufficient
  look-ahead at run speed, handle sudden direction changes without whipping.
  **Camera quality is co-equal with traversal feel. Bad camera = bad game.**
  Camera system must be prototyped alongside traversal, not after.
- **Reactive NPC System (9)** — reads BONNIE's current movement state and
  stimulus radius to determine `visible_to_bonnie` and ambient NPC stimulus
- **Interactive Object System (7)** — reads BONNIE's velocity and collision
  events to determine object interaction force
- **Bidirectional Social System (12)** — proximity interaction (rub, sit-near)
  is gated on BONNIE being in low-speed states (IDLE, SNEAKING, WALKING)
- **Environmental Chaos System (8)** — SLIDING collision force, ROUGH_LANDING
  impact, and movement-triggered object interactions feed into chaos events
- **Nine Lives System (16)** — traversal emits Nine Lives trigger events
  (ROUGH_LANDING, extreme DAZED, squeeze traps)

---

## 7. Tuning Knobs

All values are initial prototype targets. The traversal feel cannot be finalized
from a GDD — it requires iterative playtesting. These values are a starting point,
not a specification.

### Movement Speeds

| Knob | Default | Safe Range | What It Affects |
|---|---|---|---|
| `sneak_max_speed` | `80 px/s` | `50–120` | How slow/deliberate sneaking feels |
| `walk_speed` | `180 px/s` | `140–240` | Default move feel |
| `run_max_speed` | `420 px/s` | `320–560` | How fast full sprint is |
| `run_buildup_time` | `0.4s` | `0.2–0.8` | Time held-walk before auto-run |
| `climb_speed` | `90 px/s` | `60–140` | Climb feel |
| `squeeze_speed` | `100 px/s` | `70–140` | Squeeze feel |

### Momentum and Control

| Knob | Default | Safe Range | What It Affects |
|---|---|---|---|
| `ground_acceleration` | `800 px/s²` | `500–1400` | How snappy direction input feels |
| `ground_deceleration` | `600 px/s²` | `400–1000` | How quickly BONNIE stops normally |
| `slide_trigger_speed` | `300 px/s` | `220–400` | When running becomes sliding |
| `slide_friction` | `80 px/s²` | `40–180` | How long the Kaneda slide lasts |
| `air_control_force` | `260 px/s²` | `150–420` | How much arc can be nudged mid-air |
| `double_jump_redirect_factor` | `0.45` | `0.2–0.7` | Horizontal redirect applied at moment double jump fires |
| `post_double_jump_air_control` | `30 px/s²` | `0–80` | Air control after double jump — near zero, BONNIE is committed |
| `parry_detection_radius` | `24 px` | `16–40` | How close BONNIE must be to geometry for parry to be available |
| `parry_window_frames` | `6 frames` | `4–12` | Tight timing window for successful parry |
| `pullup_duration` | `10 frames` | `6–14` | LEDGE_PULLUP animation length |
| `wall_jump_velocity` | `360 px/s` | `260–460` | Speed of wall jump (perpendicular to surface) |

### Jump

| Knob | Default | Safe Range | What It Affects |
|---|---|---|---|
| `hop_velocity` | `280 px/s` | `200–350` | Tap jump height |
| `jump_velocity` | `480 px/s` | `380–580` | Full held jump height |
| `double_jump_velocity` | `380 px/s` | `280–460` | Second jump height |
| `jump_hold_window` | `12 frames` | `8–18` | How long a hold extends jump height |
| `coyote_timer_frames` | `5 frames` | `3–8` | Grace window after walking off edge |
| `jump_buffer_frames` | `6 frames` | `4–10` | Pre-land jump buffer |
| `double_jump_window` | `40 frames` | `25–60` | Frames after jump apex where double jump is available |

### Landing and Recovery

| Knob | Default | Safe Range | What It Affects |
|---|---|---|---|
| `clean_land_threshold` | `80 px/s` | `50–130` | Speed below which landing is always clean |
| `skid_threshold` | `180 px/s` | `120–260` | Speed above which skid triggers |
| `hard_skid_threshold` | `320 px/s` | `240–420` | Speed for hard skid |
| `skid_base_duration` | `0.6s` | `0.3–1.2` | How long the landing slide lasts |
| `rough_landing_threshold` | `144 px` | `100–200` | Fall distance to trigger ROUGH_LANDING |
| `rough_landing_duration` | `2.5s` | `1.5–4.0` | Recovery time from big fall |
| `daze_duration` | `1.0s` | `0.6–1.8` | Recovery time from daze |
| `daze_collision_threshold` | `280 px/s` | `200–380` | Slide speed that triggers daze on wall |

### Stimulus Radii

| Knob | Default | Safe Range | What It Affects |
|---|---|---|---|
| `sneak_stimulus_radius` | `48 px` | `32–80` | NPC awareness while sneaking |
| `idle_stimulus_radius` | `96 px` | `64–140` | NPC awareness while still |
| `walk_stimulus_radius` | `140 px` | `100–200` | NPC awareness while walking |
| `run_stimulus_radius` | `220 px` | `160–300` | NPC awareness while running |

---

## 8. Acceptance Criteria

All criteria must be verifiable in the traversal prototype before other systems
are built on top of BONNIE's movement.

---

**AC-T01: Input responsiveness — frame-perfect**
- [ ] Direction input registers on the same frame it is received
- [ ] No perceptible input lag between button press and BONNIE beginning to change velocity
- [ ] Jumps fire on the frame of input (with coyote/buffer grace, not delay)

**AC-T02: Sneak → sprint transition is expressive**
- [ ] BONNIE enters SNEAKING with sneak input
- [ ] Transitioning to full run from sneak: BONNIE accelerates through walk → run naturally
- [ ] From full run, attempting to stop triggers SLIDING (at or above `slide_trigger_speed`)
- [ ] The slide feels like a committed physical consequence, not input failure

**AC-T03: The Kaneda slide works**
- [ ] Running at full speed + opposing input triggers SLIDE
- [ ] During SLIDE, BONNIE has minimal steering
- [ ] BONNIE can pop-jump from SLIDE (jump input during slide fires with full horizontal momentum)
- [ ] BONNIE hits a static object during slide: object receives collision force, BONNIE continues
      at reduced speed (not stopped)
- [ ] BONNIE hits a wall at speed during slide: DAZED state, 1.0s recovery

**AC-T04: Jump feel matches design intent**
- [ ] Tap: hop clears approximately BONNIE's body height + 50%
- [ ] Hold: full jump clears approximately 2.5× BONNIE's body height
- [ ] Horizontal momentum from running fully carries into jump arc
- [ ] Standing jump has noticeably less horizontal reach than running jump
- [ ] Double jump fires reliably within `double_jump_window`, redirects arc

**AC-T05: Landing skid is speed-proportional**
- [ ] Walking into a landing: clean (no skid)
- [ ] Running into a landing: visible skid — BONNIE doesn't stop immediately
- [ ] Full-speed landing: hard skid — BONNIE slides noticeably before stopping
- [ ] Player can jump mid-skid and carry full horizontal momentum into the jump

**AC-T06: Rough landing triggers correctly**
- [ ] Fall of less than `rough_landing_threshold`: normal LANDING rules
- [ ] Fall above `rough_landing_threshold` to hard surface: ROUGH_LANDING triggers
- [ ] ROUGH_LANDING: BONNIE is visually incapacitated for `rough_landing_duration`
- [ ] Fall onto cushion surface above threshold: LANDING (not ROUGH_LANDING)
- [ ] BONNIE always exits ROUGH_LANDING and returns to playable state — no death

**AC-T06b: Run button model works correctly**
- [ ] Default: BONNIE does not run without run button held
- [ ] Run button + direction = RUNNING state
- [ ] Without run button, max speed is `walk_speed` regardless of hold duration
- [ ] `autorun_enabled = true`: BONNIE auto-escalates to run after `run_buildup_time`
      without run button — same top speed, just different trigger

**AC-T06c: Ledge Parry fires on skill, not on proximity**
- [ ] BONNIE falls past a ledge with NO grab input: she falls, no auto-grab
- [ ] BONNIE falls past a ledge with grab input OUTSIDE `parry_window_frames`:
      she falls, no grab (missed window)
- [ ] BONNIE falls past a ledge with grab input WITHIN `parry_window_frames`:
      transitions to LEDGE_PULLUP (platform edge) or CLIMBING (climbable wall)
- [ ] No visual prompt or highlighted ledge telegraphs the parry window
- [ ] Failed parry that results in ROUGH_LANDING: Nine Lives trigger fires

**AC-T06d: Double jump + parry combo is executable**
- [ ] Run → jump → at apex → double jump: BONNIE twists, air control significantly reduced
- [ ] Post-double-jump: player cannot meaningfully redirect arc laterally
- [ ] At the committed approach, grab input within parry window succeeds
- [ ] Full combo (run → jump → double jump → parry → pullup) is completable
      in a single fluid sequence without breaking to a menu or state error

**AC-T06e: Wall jump on climbable surfaces**
- [ ] Climbable wall (carpet/fabric): BONNIE can grab via LEDGE PARRY → CLIMBING → wall jump
- [ ] Hard smooth wall (hardwood, metal, glass): LEDGE PARRY input on this surface
      fails — BONNIE cannot grab it, falls
- [ ] Wall jump from CLIMBING: BONNIE launches perpendicular to surface with `wall_jump_velocity`
- [ ] Double jump resets on successful wall grab (touching climbable surface restores it)

**AC-T07: Stealth mechanics function**
- [ ] NPC in range during SNEAKING: NPC does NOT enter AWARE
- [ ] Same NPC in same range during WALKING: NPC enters AWARE
- [ ] BONNIE in SQUEEZING state: NPC cannot detect BONNIE through wall/object
- [ ] Jump from SNEAK: quieter hop, brief stealth break on landing

**AC-T08: Camera leads movement**
- [ ] Camera position leads BONNIE's movement direction (not trailing)
- [ ] At run speed, sufficient look-ahead to see what's coming
- [ ] Rapid direction reversal: camera catches up smoothly (no hard whip)
- [ ] Camera framing at rest: BONNIE is not centered vertically — more ground
      shown below than above (cat's-eye-level framing)

# System GDD: NPC Personality System

*Status: Draft — Awaiting Review*
*Created: 2026-04-05*
*System #: 9 (Reactive NPC System) + 10 (NPC Behavior/Routine System)*
*Priority: MVP*

---

## 1. Overview

Each NPC in BONNIE! is a behavioral simulation, not a scripted actor. NPCs have
internal emotional state that evolves continuously — rising under stress, decaying
toward a personal baseline, spiking in reaction to BONNIE and to each other. They
follow their own daily routines independent of BONNIE's presence. They talk. They
exhaust themselves. They become vulnerable. They shut down. Sometimes they feed you.

The system is built on two interlocking components:

**NpcState** — a shared data object holding the NPC's live emotional, social, and
behavioral status. Every system that needs to know what an NPC is feeling reads from
NpcState. Every system that changes an NPC writes to NpcState. No cross-system
direct calls.

**State Machine** — 11 behavioral states governing how an NPC acts and what inputs
they can receive. States drive animation, dialogue selection, cascade potential,
and feeding threshold checks.

MVP scope covers two NPCs: **Michael** (the apartment owner) and **Christen**
(Michael's partner — she is the sun, moon, and stars of the apartment's emotional
ecosystem, and BONNIE knows this). Their relationship is the primary cascade
vector: Michael's reactions amplify Christen's, and vice versa. Both are written
to Level 2 (the apartment). All other NPC profiles are post-MVP.

## 2. Player Fantasy

> You are reading a room the way only a cat can.

The NPC system delivers the specific pleasure of *knowing your audience*. Before
BONNIE touches anything, the player should be watching — clocking what Michael is
doing, how tightly wound he seems today, whether Christen is in a mood. The best
chaos isn't random. It's engineered from knowledge.

The fantasy has three beats:

**The read.** Observing an NPC in ROUTINE and understanding their pressure points.
Michael is on a work call. He's already mid-stress. One thing could tip him.

**The choice.** Charm them first to build goodwill and make the eventual chaos land
harder — or go straight for the threshold. Both are valid. Both feel different.
High-goodwill NPC reactions are funnier and earn more chaos meter. Pure chaos is
faster and riskier.

**The cascade.** Engineering a chain reaction. Getting Michael upset specifically
because it will pull Christen into a spiral. Watching one triggered NPC set off
another — a Domino Rally you designed.

The VULNERABLE state is the system's emotional payoff: an NPC who has been through
enough and needs comfort. BONNIE sitting with an exhausted, overwhelmed Christen
and purring until she feeds you. The chaos and the warmth are the same game.

## 3. Detailed Rules

### 3.1 NpcState Interface

The shared data object. Both the NPC system and the Social System read and write
this. Neither calls the other directly.

```gdscript
class_name NpcState

var emotional_level: float          # 0.0 (calm) → 1.0 (max stress). Continuous.
var goodwill: float                  # 0.0 (hostile) → 1.0 (loves BONNIE). Decays slowly.
var current_behavior: NpcBehavior   # Active state machine state (enum below)
var comfort_receptivity: float      # 0.0 (closed) → 1.0 (open). Floor is per-NPC.
var active_stimuli: Array[Stimulus] # Live stimuli affecting this NPC this frame
var visible_to_bonnie: bool         # Is this NPC in BONNIE's awareness range?
var last_interaction_type: InteractionType  # CHARM / CHAOS / NONE
var bonnie_hunger_context: bool     # True if BONNIE is in hunger-boost state
```

`NpcBehavior` enum (11 states):
```gdscript
enum NpcBehavior {
    ASLEEP, GROGGY, ROUTINE, AWARE, REACTING,
    RECOVERING, VULNERABLE, CLOSED_OFF,
    FLEEING, CHASING, FED
}
```

### 3.2 Behavioral States

---

#### ASLEEP
NPC is sleeping. Minimal responsiveness.

- `emotional_level`: at or below `0.05`
- `comfort_receptivity`: `0.0` — cannot be charmed while asleep
- **Stimulus response**: stimuli below `wake_threshold` are silently ignored
- **Exits to**: GROGGY (any stimulus above `wake_threshold`; direct BONNIE contact always wakes)
- **Key behavior**: BONNIE can operate near a sleeping NPC freely below the wake threshold.
  Sleeping NPCs react to very loud chaos stimuli (e.g., object crash in same room).
  Sleeping NPCs do NOT react to proximity alone.

---

#### GROGGY
Just woken up. Disoriented, not yet fully reactive.

- `emotional_level`: `0.05` → `baseline_tension` (rising during groggy window)
- `comfort_receptivity`: `0.1` — barely receptive; won't process social interaction meaningfully
- **Duration**: `groggy_duration` seconds (per-NPC tuning knob)
- **Exits to**: ROUTINE (timer expires), AWARE (strong stimulus — half `reaction_threshold`)
- **Key behavior**: NPCs in GROGGY have dialogue like "...mmmph" and "wh—". They are
  comedy targets. Their reactions are soft and confused. Chaos during GROGGY builds
  a small `emotional_level` bump that carries into ROUTINE.

---

#### ROUTINE
NPC going about their day. Following their schedule, minding their business.

- `emotional_level`: at `baseline_tension` ± small drift
- `comfort_receptivity`: at per-NPC default
- **Exits to**: AWARE (any stimulus above `awareness_threshold`)
- **Key behavior**: NPCs follow a timed routine (see Section 3.4). They comment on
  mundane things. BONNIE can interact positively (rub, sit near) to build `goodwill`.
  They notice BONNIE but don't react until threshold is crossed.

---

#### AWARE
NPC noticed something. Alert but not yet reacting. "What was that?" state.

- `emotional_level`: `baseline_tension + awareness_bump`
- `comfort_receptivity`: slightly reduced
- **Exits to**: REACTING (stimulus escalation above `reaction_threshold`, or direct
  BONNIE interaction that crosses threshold), ROUTINE (no escalation within
  `awareness_window` seconds — stimulus fades)
- **Key behavior**: NPC stops current activity, looks toward source. Tension visible.
  Dialogue: "BONNIE…" or "Did you just—" or "What's going on in there?" If BONNIE
  does nothing, the NPC settles. This is the crucial window for social play — a well-
  timed rub during AWARE can convert a reaction into goodwill.

---

#### REACTING
Active emotional response. NPC is upset, alarmed, or exasperated. Vocalization.

- `emotional_level`: at or above `reaction_threshold` (typically `0.6`+)
- `comfort_receptivity`: near `0.0` — unreachable during active reaction
- **Exits to**: RECOVERING (reaction expression completes — natural decay begins),
  FLEEING (emotional_level exceeds `flee_threshold` — NPC-specific, not all NPCs flee),
  CHASING (antagonist NPCs only — not MVP)
- **Key behavior**: Loud, visible reaction. Dialogue. Animation shift. NPC behavior
  interrupts current routine. Stimuli from this NPC bleed into nearby NPCs as
  cascade stimuli (see Section 3.3 — Domino Rally). `goodwill` takes a hit from
  the REACTING event itself. Multiple REACTING cycles in a short window stack
  `emotional_level` higher — the hair-trigger effect.

---

#### RECOVERING
Cooling down after REACTING. Emotional level declining.

- `emotional_level`: declining from peak toward `baseline_tension`
- `comfort_receptivity`: low but rising — begins to recover as `emotional_level` drops
- **Exits to**: ROUTINE (`emotional_level` returns to near `baseline_tension`),
  VULNERABLE (`emotional_level` drops *below* `vulnerability_threshold`)
- **Key behavior**: NPC is tense and raw. Re-triggering during RECOVERING is cheaper —
  the next stimulus needs less to push them back to REACTING (hair-trigger window).
  Social play is possible but risky: comfort starts to land again, but a poorly-timed
  chaos event while in RECOVERING immediately re-triggers REACTING.

---

#### VULNERABLE
Post-stress emotional exhaustion. The jackpot state for social play.

Triggered when `emotional_level` drops *below* `vulnerability_threshold` after a
REACTING spike. This is the adrenaline-crash state. The NPC is depleted, soft,
and receptive.

- `emotional_level`: below `vulnerability_threshold` (typically `0.15`)
- `comfort_receptivity`: **maximum** — at or above per-NPC ceiling.
  Comfort interactions earn boosted `goodwill` and chaos meter contribution.
  The levity multiplier activates here: cute-after-chaos interactions earn
  a `levity_multiplier` bonus to goodwill.
- **Exits to**: ROUTINE (time + no interaction — NPC self-recovers),
  CLOSED_OFF (if chaos resumes before NPC recovers — final shutdown)
- **Key behavior**: NPC may be sitting, quiet, staring at nothing, picking up the
  mess slowly. Dialogue is exhausted: "I just… I can't today." BONNIE sitting
  with them, rubbing on them — this is where the relationship is real.
  Getting fed from VULNERABLE is emotionally meaningful. Getting fed from
  REACTING is comedic. Both are valid paths.

---

#### CLOSED_OFF
Social shutdown. NPC has had enough. Won't engage.

Triggered by: chaos resuming during VULNERABLE, or exceeding a total `chaos_event_count`
threshold in a session without sufficient goodwill recovery between events.

- `emotional_level`: moderate, flat (`0.4–0.6`) — not hot, just done
- `comfort_receptivity`: at per-NPC `comfort_receptivity_floor` or `0.0`
  Some NPCs have a floor above zero (cannot fully close off). Others fully shut down.
- **Exits to**: ROUTINE (extended no-chaos period — `closed_off_recovery_time`)
- **Key behavior**: NPC ignores BONNIE. Blocks interactions. Dialogue shuts down.
  This state feels bad on purpose. It's the penalty for playing chaotically without
  any social recovery. The way out is time and no further chaos events — BONNIE
  can't charm her way out of CLOSED_OFF, but she can wait it out.

---

#### FLEEING
NPC running away from BONNIE or source of chaos.

- Not available to all NPCs — only NPCs with `flee_threshold` set and `can_flee: true`
- **Exits to**: RECOVERING (reached destination / safe zone)
- **Key behavior**: NPC pathfinds away from stimulus source. Dialogue: screaming,
  exclamations. In MVP, Michael does NOT flee (his apartment, his turf).
  Christen *can* flee (to another room) — marks her `flee_threshold` as reachable.

---

#### CHASING
Antagonist NPC pursuing BONNIE.

- **MVP scope: NOT ACTIVE.** Antagonist/Trap System is Vertical Slice.
- Reserved for Level 3+ NPCs (Vet, K-Mart staff).

---

#### FED
Terminal state for this level run. NPC breaks and feeds BONNIE.

- **Entry conditions**: goodwill above `feeding_threshold` **AND** chaos context
  has been sufficiently established, OR cumulative `chaos_event_count` has
  overwhelmed the NPC's resistance entirely (pure chaos path to fed — less satisfying)
- BONNIE's `bonnie_hunger_context = true` reduces `feeding_threshold` by
  `hunger_threshold_reduction` (NPC can perceive BONNIE is really hungry)
- **Exits to**: Level complete (feeding cutscene triggers)
- **Key behavior**: The payoff. Different paths to FED produce different feeding
  circumstances — charmed NPC feeds warmly and immediately; chaos-overwhelmed NPC
  feeds in exasperation. Both trigger the feeding cutscene but with different
  dialogue and animation states.

---

### 3.3 Domino Rally — Cascade Rules

When NPC A enters REACTING, it emits a cascade stimulus to all NPCs within
`cascade_radius` units. This stimulus is weighted by A's `emotional_level` at
the moment of entry into REACTING:

```
cascade_stimulus_strength = emotional_level_A * cascade_bleed_factor
```

NPC B receives this as an `active_stimuli` entry. If B is in ROUTINE or AWARE,
this contributes to B's `emotional_level` bump toward their `reaction_threshold`.

**Chain rules:**
- MVP allows chains up to depth 2 (A triggers B, B can trigger C, C cannot trigger further)
- Cascades do not loop (A cannot be re-triggered by B's cascade from A's original event)
- NPCs in RECOVERING, VULNERABLE, or CLOSED_OFF receive cascade stimuli at half weight
  (already emotionally occupied)
- NPCs in ASLEEP/GROGGY receive cascade stimuli at full weight for wake purposes,
  but their REACTING cascade bleed is zero (they don't re-broadcast while groggy)

**Michael + Christen cascade dynamic:**
Michael and Christen have a `relationship_link` that increases cascade bleed between
them specifically: `cascade_bleed_factor` for their mutual stimuli is elevated by
`relationship_cascade_bonus` (default `+0.2`). This makes their mutual escalation
more volatile than two strangers — they amplify each other.

---

### 3.4 NPC Routines

Each NPC follows a schedule during ROUTINE state. The schedule defines what activity
the NPC is performing, which affects: dialogue pool selection, available interaction
types, chaos sensitivity, and which environmental objects they are using or near.

Routines are time-based within a level session (not real-time clock). They advance
when the NPC is in ROUTINE and pause during any other state.

#### Michael — Apartment Routine

| Phase | Activity | Location | Sensitivity Notes |
|-------|----------|----------|-------------------|
| Morning | Coffee, slow start | Kitchen | Low sensitivity — still waking |
| Work | Laptop, phone calls | Desk/living room | HIGH sensitivity — do not interrupt |
| Lunch | Food prep, eating | Kitchen | Medium — distracted but present |
| Afternoon | Continued work | Desk | HIGH — crunch window |
| Evening | TV, decompressing | Couch | Low — winding down, more receptive |
| Late | Bed | Bedroom | ASLEEP state |

*Work phase is the highest-chaos-value target. Michael's `reaction_threshold` is
lower during work phase (modifier: `-0.1`) because he's already under stress.*

#### Christen — Apartment Routine

| Phase | Activity | Location | Sensitivity Notes |
|-------|----------|----------|-------------------|
| Arrival | Coming in, settling | Entryway → living room | Medium — transition state |
| Socializing | Talking with Michael, phone | Living room | Low-medium — engaged, not focused |
| Task-focused | Cooking, working, reading | Variable | Medium — depends on activity |
| Relaxing | TV, couch time | Living room | Low — receptive to BONNIE |
| Departure | Leaving or staying over | Variable | Transition state |

*Christen spends less total time in the apartment than Michael — her schedule has
natural gaps. The player must catch her during her windows.*

---

### 3.5 New Mechanics (Surfaced in Design Session)

#### Levity Multiplier
When BONNIE performs a comfort/charm interaction immediately following a chaos event
(within `levity_window` seconds), the goodwill earned receives a `levity_multiplier`
bonus (default `1.5×`). The comedy of "caused chaos, immediately sat on lap purring"
is mechanically rewarded. Works in any state where comfort_receptivity > 0.

#### Hunger Boost (Ambient Only)
If BONNIE has not received a feeding in the current level session for longer than
`hunger_threshold_time` (internal timer, no UI), BONNIE enters hunger-boost state:
- `bonnie_hunger_context = true` on all NpcState objects
- Reduces NPC `feeding_threshold` by `hunger_threshold_reduction` (default `-0.1`)
- BONNIE's physics: slightly increased stumble frequency from traversal system
  (no explicit UI — ambient effect only. Players may notice BONNIE is clumsier.)

#### comfort_receptivity Floor
Each NPC has a per-NPC `comfort_receptivity_floor`. This is the minimum value
`comfort_receptivity` can ever reach, even in CLOSED_OFF or REACTING.
- Some NPCs can never fully shut out BONNIE (floor `0.2`)
- Some NPCs fully shut down under max stress (floor `0.0`)
- Michael: floor `0.15` — he always has *some* soft spot for BONNIE
- Christen: floor `0.2` — she's more emotionally open by nature

#### Pre-emptive Stimulus Removal
*(Vertical Slice scope — not MVP)*
BONNIE can interact with certain environmental triggers to prevent an NPC emotional
event before it occurs: taking the phone off the hook before a stressful call,
closing the blinds before a noisy street event. Reduces `active_stimuli` count.
Requires Vertical Slice environmental awareness systems.

## 4. Formulas

All float values are clamped to `[0.0, 1.0]` unless noted. `delta` is frame delta in seconds.

---

### 4.1 Emotional Level Decay

`emotional_level` continuously decays toward `baseline_tension` at rate `emotion_decay_rate`:

```
emotional_level += (baseline_tension - emotional_level) * emotion_decay_rate * delta
```

| Variable | Description | Typical Range |
|----------|-------------|---------------|
| `baseline_tension` | NPC's resting stress level (per-NPC) | `0.1–0.4` |
| `emotion_decay_rate` | How fast they calm down (per-NPC) | `0.05–0.20` |

Example: Michael at `emotional_level = 0.8`, `baseline_tension = 0.2`, `decay_rate = 0.1`:
At 60fps (delta ≈ 0.0167): each frame moves level ~`0.001` toward `0.2`.
Rough time to recover from peak: ~20–30 seconds at default rate.

**During RECOVERING state**: `emotion_decay_rate` is multiplied by `recovery_rate_multiplier`
(default `1.5×`) — RECOVERING NPCs calm down faster than ambient decay.

**During VULNERABLE state**: `emotional_level` has reached below `vulnerability_threshold`
(typically `0.15`). Decay formula continues normally but the floor is the threshold.

---

### 4.2 Goodwill Accumulation and Decay

```
# On charm interaction:
goodwill = clamp(goodwill + charm_value * comfort_receptivity, 0.0, 1.0)

# Passive decay each frame:
goodwill += (goodwill_baseline - goodwill) * goodwill_decay_rate * delta

# On chaos event:
goodwill = clamp(goodwill - chaos_goodwill_cost, 0.0, 1.0)
```

| Variable | Description | Typical Range |
|----------|-------------|---------------|
| `charm_value` | Goodwill earned per charm interaction type | `0.05–0.20` |
| `comfort_receptivity` | Multiplier on goodwill earned — scales down when NPC is closed | `0.0–1.0` |
| `goodwill_baseline` | NPC's resting goodwill (typically `0.0` — goodwill earned, not given) | `0.0–0.1` |
| `goodwill_decay_rate` | How fast goodwill fades without reinforcement | `0.005–0.02` |
| `chaos_goodwill_cost` | Goodwill lost per chaos event (varies by severity) | `0.05–0.3` |

**Levity multiplier**: When `last_interaction_type == CHAOS` and time since chaos < `levity_window`:
```
goodwill += charm_value * comfort_receptivity * levity_multiplier
```
`levity_multiplier` default: `1.5`. Range: `1.2–2.0`.

---

### 4.3 comfort_receptivity

```
# On entering REACTING:
comfort_receptivity = max(comfort_receptivity - receptivity_reacting_drop, comfort_receptivity_floor)

# On entering VULNERABLE:
comfort_receptivity = min(comfort_receptivity + receptivity_vulnerable_boost, receptivity_max)

# Passive recovery (when not in REACTING):
comfort_receptivity += (receptivity_default - comfort_receptivity) * receptivity_recovery_rate * delta
```

| Variable | Description | Michael | Christen |
|----------|-------------|---------|----------|
| `comfort_receptivity_floor` | Minimum ever | `0.15` | `0.20` |
| `receptivity_default` | Resting value | `0.55` | `0.65` |
| `receptivity_reacting_drop` | Drop on REACTING entry | `0.4` | `0.45` |
| `receptivity_vulnerable_boost` | Boost on VULNERABLE entry | `0.35` | `0.30` |
| `receptivity_max` | Maximum (cap) | `0.90` | `0.95` |
| `receptivity_recovery_rate` | Passive recovery speed | `0.08` | `0.10` |

---

### 4.4 Cascade Stimulus

```
cascade_stimulus_strength = emotional_level_A * cascade_bleed_factor_A

# Applied to NPC B:
emotional_level_B = clamp(emotional_level_B + cascade_stimulus_strength, 0.0, 1.0)
```

Michael ↔ Christen mutual cascade uses elevated bleed:
```
cascade_bleed_factor_mutual = cascade_bleed_factor_base + relationship_cascade_bonus
```
Default `relationship_cascade_bonus`: `0.2`.

---

### 4.5 Feeding Threshold Check

Checked each frame when NPC is in ROUTINE, RECOVERING, or VULNERABLE:

```
effective_feeding_threshold = feeding_threshold
if bonnie_hunger_context:
    effective_feeding_threshold -= hunger_threshold_reduction

if goodwill >= effective_feeding_threshold AND chaos_context_met:
    transition_to(FED)
```

`chaos_context_met` = at least `min_chaos_events_for_feed` REACTING events have
occurred this level session. Prevents NPCs from feeding from goodwill alone without
any chaos (the meter must be justified).

| Variable | Michael | Christen |
|----------|---------|----------|
| `feeding_threshold` | `0.75` | `0.70` |
| `hunger_threshold_reduction` | `0.10` | `0.10` |
| `min_chaos_events_for_feed` | `2` | `2` |

## 5. Edge Cases

**Q: BONNIE leaves the room mid-REACTING. Does the NPC calm down faster?**
A: No. REACTING runs to completion regardless of BONNIE's position. The NPC reacts
to what happened, not BONNIE's current location. Decay to RECOVERING begins after
the reaction expression completes (animation/dialogue finishes). This prevents the
exploit of "trigger and immediately leave."

**Q: Two NPCs enter REACTING simultaneously. Does the cascade loop?**
A: No. Cascade loops are prevented by a `cascade_source_id` tag on each stimulus.
If NPC B's cascade stimulus originated from NPC A, NPC A cannot be re-triggered by
NPC B's re-broadcast of that stimulus. A cascade chain can still propagate (A→B→C)
but cannot loop back (C cannot trigger A from the same chain).

**Q: BONNIE attempts comfort interaction during REACTING.**
A: Interaction is received but effective goodwill gain is near zero:
`goodwill += charm_value * comfort_receptivity` where `comfort_receptivity ≈ 0.0`.
The animation still plays (BONNIE is trying). The NPC does not respond warmly.
This teaches the player that REACTING is not the time — they must wait for RECOVERING
or VULNERABLE.

**Q: NPC is in VULNERABLE. Player triggers a chaos event. Does NPC skip straight to CLOSED_OFF?**
A: Yes, but with a buffer. One small chaos event during VULNERABLE does not immediately
trigger CLOSED_OFF. It pushes `emotional_level` up — if it exceeds `reaction_threshold`
from VULNERABLE, the NPC enters REACTING (not CLOSED_OFF). CLOSED_OFF triggers only if
the NPC reaches REACTING from VULNERABLE AND `chaos_event_count` exceeds
`closed_off_trigger_count` in this session. This prevents a single accidental chaos
event from permanently souring a VULNERABLE NPC.

**Q: NPC in ASLEEP. Major chaos event in another room (not same room).**
A: Adjacent-room stimuli are attenuated by `room_attenuation_factor` (default `0.5`).
A stimulus that would wake an NPC in the same room requires double the strength
to wake them from an adjacent room. Sleeping through chaos in a nearby room is
expected and intentional.

**Q: Both NPCs reach their `feeding_threshold` simultaneously.**
A: First-to-check wins. Check order is deterministic per frame (NPC list order).
In practice this is very rare because Michael and Christen have different thresholds
and different goodwill states. If it happens, the first NPC to trigger FED fires the
cutscene and the level ends. The other NPC's state is irrelevant.

**Q: BONNIE has been in HUNGER state the whole level. Does every NPC feeding threshold drop?**
A: Yes. `bonnie_hunger_context = true` is a global flag set on all NpcState instances.
This is intentional — a very hungry BONNIE pressures every NPC slightly. The ambient
clumsiness increase (from traversal system) makes this legible to attentive players
without a UI element.

**Q: Can CLOSED_OFF and VULNERABLE coexist?**
A: No. They are mutually exclusive states in the state machine. CLOSED_OFF can only
be entered from REACTING (or from VULNERABLE→REACTING→CLOSED_OFF path). VULNERABLE
is entered from RECOVERING. Once CLOSED_OFF, the NPC must exit to ROUTINE before
VULNERABLE is reachable again.

## 6. Dependencies

**This system depends on:**
- **Input System (1)** — BONNIE's interaction inputs trigger charm/chaos classifications
- **BONNIE Traversal System (6)** — Proximity radius drives `visible_to_bonnie` and
  ambient stimulus detection. Hunger-boost clumsiness modifier sourced from traversal.
- **Level Manager (5)** — NPC instances are registered with the level. Level Manager
  provides room topology for cascade attenuation and routine advancement.

**Systems that depend on this:**
- **Bidirectional Social System (12)** — Reads `NpcState` (goodwill, comfort_receptivity,
  current_behavior) to determine available interactions and their values. Writes
  goodwill updates back to NpcState.
- **Chaos Meter (13)** — Reads REACTING events and their `emotional_level` at time
  of entry to determine chaos meter contribution. VULNERABLE + charm interactions
  contribute to meter via levity multiplier path.
- **Dialogue System (17)** — Reads `current_behavior`, `emotional_level`, `goodwill`,
  and `last_interaction_type` to select appropriate dialogue pool. (Vertical Slice scope.)
- **Environmental Chaos System (8)** — Emits `active_stimuli` into NpcState. Reads
  NPC positions and routines to determine which NPCs are near which objects.

**Circular dependency (NPC ↔ Social System):**
Resolved via NpcState as shared data object. Neither system calls the other directly.
Execution order: NPC system processes stimuli and updates state → Social System reads
updated state → Social System writes interaction results back to NpcState →
NPC system reads on next frame.

## 7. Tuning Knobs

All values below are initial targets for MVP prototype. Expect significant revision
after first playtest sessions. Ranges indicate safe tuning bounds.

### Per-NPC Profile Values

| Knob | What It Controls | Michael | Christen | Safe Range |
|------|-----------------|---------|----------|------------|
| `baseline_tension` | Resting stress level | `0.20` | `0.25` | `0.05–0.45` |
| `emotion_decay_rate` | Speed of calming | `0.10` | `0.12` | `0.04–0.25` |
| `awareness_threshold` | Stimulus to enter AWARE | `0.25` | `0.20` | `0.10–0.40` |
| `reaction_threshold` | Stimulus to enter REACTING | `0.60` | `0.55` | `0.40–0.80` |
| `flee_threshold` | Stimulus to FLEE (if can_flee) | n/a | `0.90` | `0.75–1.0` |
| `vulnerability_threshold` | emotional_level floor for VULNERABLE entry | `0.15` | `0.15` | `0.05–0.25` |
| `feeding_threshold` | goodwill needed for FED | `0.75` | `0.70` | `0.50–0.90` |
| `comfort_receptivity_floor` | Minimum receptivity ever | `0.15` | `0.20` | `0.0–0.35` |
| `comfort_receptivity_default` | Resting receptivity | `0.55` | `0.65` | `0.30–0.80` |
| `cascade_bleed_factor` | How much their REACTING bleeds to others | `0.40` | `0.45` | `0.10–0.70` |
| `groggy_duration` | Time in GROGGY state (seconds) | `8.0` | `6.0` | `4.0–15.0` |
| `awareness_window` | Seconds before AWARE decays to ROUTINE | `6.0` | `5.0` | `3.0–10.0` |
| `closed_off_recovery_time` | Seconds to exit CLOSED_OFF | `45.0` | `40.0` | `20.0–90.0` |
| `can_flee` | Whether this NPC can enter FLEEING | `false` | `true` | boolean |

### Global Tuning Values

| Knob | What It Controls | Default | Safe Range |
|------|-----------------|---------|------------|
| `relationship_cascade_bonus` | Extra bleed between linked NPCs | `0.20` | `0.05–0.40` |
| `levity_window` | Seconds after chaos where levity multiplier applies | `4.0` | `2.0–8.0` |
| `levity_multiplier` | Goodwill bonus for charm-after-chaos | `1.5` | `1.1–2.5` |
| `hunger_threshold_time` | Seconds until hunger boost activates (no feed) | `300.0` | `180–600` |
| `hunger_threshold_reduction` | Feeding threshold reduction when hungry | `0.10` | `0.05–0.20` |
| `cascade_max_depth` | Maximum chain length for Domino Rally | `2` | `1–3` |
| `room_attenuation_factor` | Stimulus strength reduction across rooms | `0.50` | `0.20–0.80` |
| `recovery_rate_multiplier` | Speed boost to decay during RECOVERING | `1.5` | `1.0–3.0` |
| `min_chaos_events_for_feed` | REACTING events required before FED is possible | `2` | `1–4` |

### Work-Phase Sensitivity Modifier (Michael)

During Michael's Work routine phase, apply:
```
reaction_threshold += work_phase_threshold_modifier  # default: -0.10
```
This makes Michael easier to trigger during work. Range: `-0.05` to `-0.20`.

## 8. Acceptance Criteria

All criteria must be verifiable by a QA tester running the MVP prototype.

---

**AC-01: Michael reacts distinctly to three different stimulus types**
- [ ] Stimulus A (loud noise — object crash): Michael enters AWARE, then REACTING
      within `awareness_window` if no counter-interaction. Dialogue distinct from B and C.
- [ ] Stimulus B (direct BONNIE interaction — jump on desk): Michael enters REACTING
      immediately (skips AWARE). Dialogue reflects direct BONNIE contact.
- [ ] Stimulus C (ongoing low-level stimulus — BONNIE sitting on keyboard during
      work phase): Michael enters AWARE and escalates to REACTING over time rather
      than instantly. Reaction is slower-burn than A or B.

**AC-02: Christen cascades from Michael's REACTING event**
- [ ] Michael enters REACTING with `emotional_level >= 0.65`
- [ ] Christen (in same or adjacent room) receives cascade stimulus
- [ ] Christen's `emotional_level` visibly increases (she changes behavior/dialogue)
- [ ] If Christen was already in AWARE, Michael's cascade pushes her to REACTING

**AC-03: VULNERABLE state is reachable**
- [ ] Trigger Michael through a full REACTING → RECOVERING cycle
- [ ] Wait for `emotional_level` to decay below `vulnerability_threshold`
- [ ] Michael enters VULNERABLE state (confirmed by changed animation/dialogue)
- [ ] BONNIE rub interaction during VULNERABLE earns visibly more goodwill than
      the same interaction during ROUTINE (testable: observe goodwill meter delta)

**AC-04: CLOSED_OFF state blocks comfort**
- [ ] Trigger Michael to CLOSED_OFF via excess chaos (>= `closed_off_trigger_count` REACTING cycles)
- [ ] BONNIE rub interaction during CLOSED_OFF: goodwill delta is zero or near-zero
- [ ] CLOSED_OFF dialogue is distinct from REACTING dialogue
- [ ] After `closed_off_recovery_time` with no chaos events, Michael returns to ROUTINE

**AC-05: FED state triggers at correct conditions**
- [ ] Build Michael's goodwill above `feeding_threshold` via charm interactions
- [ ] Confirm at least `min_chaos_events_for_feed` REACTING events have occurred
- [ ] FED transition triggers (feeding cutscene stub, or at minimum: state change confirmed)
- [ ] FED via high goodwill path shows different dialogue than FED via pure chaos overwhelm

**AC-06: Levity multiplier activates correctly**
- [ ] Trigger a chaos event (Michael enters REACTING)
- [ ] Within `levity_window` seconds, perform a charm interaction
- [ ] Goodwill delta is >= `levity_multiplier` × normal charm_value × comfort_receptivity
- [ ] After `levity_window` expires, same charm interaction earns normal goodwill

**AC-07: Cascade does not loop**
- [ ] Trigger Michael's REACTING; cascade stimulus reaches Christen; Christen enters REACTING
- [ ] Christen's REACTING cascade bleed DOES NOT re-trigger Michael from the same chain
- [ ] Confirm via debug log: cascade_source_id prevents loop

**AC-08: Sleeping NPC behaves correctly**
- [ ] Michael in ASLEEP state: BONNIE moving in same room below `wake_threshold` — no response
- [ ] Michael in ASLEEP state: loud stimulus above `wake_threshold` — transitions to GROGGY
- [ ] Michael in GROGGY: soft/confused dialogue, reduced reactivity
- [ ] Michael in GROGGY → ROUTINE after `groggy_duration` with no further stimulus

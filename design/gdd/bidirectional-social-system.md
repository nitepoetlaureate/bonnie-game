# Bidirectional Social System

> **Status**: Approved
> **System**: #12
> **Priority**: MVP
> **Created**: 2026-04-17
> **Design Doc Owner**: game-designer
> **Depends On**: BONNIE Traversal (6), Reactive NPC System (9)
> **Required By**: Chaos Meter (13)

---

## 1. Overview

The Bidirectional Social System governs every social interaction between BONNIE and
the NPCs in her environment. It is bidirectional in a precise sense: BONNIE can earn
genuine affection through charm verbs (rubbing on NPCs, meowing, sitting nearby,
purring, bringing comedic "gifts"), and she can burn that affection through chaos
events — and both axes contribute to the chaos meter in different ways. Neither path
alone is sufficient. Charm is not optional decoration; reaching the feeding threshold
mathematically requires social play across both directions. The system integrates with
the Reactive NPC System (9) through a shared data object, NpcState, without coupling
the two systems directly. The Social System owns three NpcState fields: `goodwill`
(the accumulated relationship value, 0.0–1.0), `last_interaction_type` (CHARM, CHAOS,
or NONE), and `comfort_receptivity` (a modifier the Social System adjusts in response
to interactions during VULNERABLE and RECOVERING states). It reads but never writes
`emotional_level`, `current_behavior`, `active_stimuli`, `visible_to_bonnie`, and
`bonnie_hunger_context` — those fields belong to the NPC System. Social state is
communicated to the player entirely through NPC body language, dialogue samples, and
animation — no social HUD, no goodwill meter. The player reads the room.

---

## 2. Player Fantasy

The player is a cat who knows exactly what they are doing. They see an irritated NPC
— someone they just rattled — and they make a choice: walk away and let it cool, or
glide over and push a head into that person's hand and listen to the tone of the room
change. When it works, there is a specific warmth to it. The NPC softens. The music
shifts slightly. That is not a number going up — it is a relationship becoming real.

The tension lives in knowing that the goodwill you spent twenty seconds earning can
evaporate the moment something falls off a shelf near them. That cost makes the charm
feel worth something. It also makes the comedy land: BONNIE arrives at someone's feet
carrying a dead mouse with absolute sincerity, drops it at their shoes, and the NPC's
reaction — horrified or oddly touched — is determined by the social history BONNIE
has built with them. The gift means something because the relationship means something.

The design insight is that chaos and charm are not opposites here. Chaos is what makes
an NPC vulnerable enough to receive comfort. Comfort is what makes an NPC susceptible
enough to tip into feeding. Players who discover this — that causing a scene and then
immediately sitting on someone's lap earns a levity bonus — are discovering the game's
real fluency. The social axis is not a second mechanic layered on top of chaos. It is
the mechanic that gives chaos its meaning.

---

## 3. Detailed Rules

### 3.1 NpcState Write Contract

The Social System and the NPC System (9) share a single data object, `NpcState`, as
their integration boundary. Neither system calls into the other. Both read and write
to `NpcState` as a passive shared record. This contract is the resolution to the
circular dependency between System 9 and System 12.

**Social System WRITES — these fields are owned exclusively by the Social System:**

| Field | Type | Range | Description |
|---|---|---|---|
| `goodwill` | `float` | 0.0–1.0 | Accumulated relationship value for this NPC |
| `last_interaction_type` | `InteractionType` | CHARM / CHAOS / NONE | Most recent social event classification |
| `comfort_receptivity` | `float` | 0.0–1.0 | Modifier adjusted during VULNERABLE and RECOVERING interactions |

**Social System READS — these fields are observed but never written:**

| Field | Owner | Description |
|---|---|---|
| `emotional_level` | NPC System | Current emotional intensity (0.0–1.0) |
| `current_behavior` | NPC System | Active NpcBehavior enum state |
| `active_stimuli` | NPC System | Set of stimuli currently acting on the NPC |
| `visible_to_bonnie` | NPC System | Whether the NPC has line-of-sight to BONNIE |
| `bonnie_hunger_context` | NPC System | BONNIE's current hunger state as observed by this NPC |

**NPC System WRITES — these fields are owned exclusively by the NPC System and the
Social System must never write them:**

`emotional_level`, `current_behavior`, `active_stimuli`, `visible_to_bonnie`,
`bonnie_hunger_context`

The Social System inspects `current_behavior` to determine verb validity on every
interaction attempt. It never sets `current_behavior` — behavior transitions are the
NPC System's responsibility.

---

### 3.2 Social Verbs — Charm Interactions

All charm verbs share two invariants:

1. They set `last_interaction_type = CHARM` on any successful application.
2. They are silently rejected (no error, no animation, no penalty) when the NPC is in
   an invalid state for that verb. Rejection feedback comes from the NPC's own behavior
   (turning away, not responding) — not from a system message.

#### Verb 1: Rub

BONNIE presses into an NPC, earning goodwill continuously while held.

- **Activation**: BONNIE's center within `rub_range` (default: 48 px) of NPC's center.
  Player holds the interact button.
- **Tick interval**: Goodwill is applied once per `rub_tick_interval` (default: 0.5 s)
  while the button is held and both the range and state conditions remain satisfied.
- **Effect per tick**: `goodwill += rub_goodwill_rate` (default: 0.02). Clamped to 1.0.
- **Valid NPC states**: ROUTINE, AWARE, RECOVERING, VULNERABLE.
- **Invalid NPC states**: ASLEEP (no response, NPC does not wake), GROGGY (no response),
  REACTING (NPC is too agitated to register contact), CLOSED_OFF (NPC refuses contact),
  FLEEING, CHASING, FED.
- **Input release**: Goodwill accrual stops immediately. No decay bonus or penalty for
  releasing early.

#### Verb 2: Meow

BONNIE vocalizes toward a nearby NPC, delivering an immediate goodwill bump.

- **Activation**: BONNIE's center within `meow_range` (default: 96 px) of NPC's center.
  Player presses the vocalize button. The button press is consumed; holding does not
  repeat.
- **Cooldown**: `meow_cooldown` (default: 3.0 s) per NPC, tracked separately per NPC
  instance. The cooldown prevents the player from rapidly re-triggering meow against
  the same NPC.
- **Effect**: `goodwill += meow_goodwill_bump` (default: 0.03). Clamped to 1.0.
- **Valid NPC states**: ROUTINE, AWARE, RECOVERING, VULNERABLE, GROGGY.
  - In GROGGY: meow applies the goodwill bump AND notifies the NPC System to evaluate
    an early GROGGY exit (the Social System writes `last_interaction_type = CHARM`; the
    NPC System reads it and decides whether to advance the GROGGY timer — this is the
    NPC System's decision, not Social's).
- **Invalid NPC states**: REACTING, CLOSED_OFF, FLEEING, CHASING, FED, ASLEEP (meow
  is too quiet to wake a sleeping NPC — use a chaos event for that).

#### Verb 3: Sit Near

BONNIE rests in proximity to an NPC, building goodwill passively through sustained
presence.

- **Activation**: BONNIE's center within `sit_range` (default: 64 px) of NPC's center,
  AND no movement input from the player for `sit_onset_time` (default: 2.0 s). The
  2-second onset delay prevents accidental activation during traversal.
- **Effect while active**: `goodwill += sit_goodwill_rate` (default: 0.01) per second.
  Clamped to 1.0.
- **VULNERABLE bonus**: When NPC `current_behavior == VULNERABLE`, the rate becomes
  `sit_goodwill_rate * vulnerable_sit_multiplier` (default multiplier: 2.0), yielding
  0.02/s at defaults.
- **Deactivation**: Any player movement input ends the sit. Goodwill accrual stops
  immediately. The NPC state does not change as a result of deactivation.
- **Valid NPC states**: ROUTINE, AWARE, RECOVERING, VULNERABLE.
- **Invalid NPC states**: ASLEEP, GROGGY, REACTING, CLOSED_OFF, FLEEING, CHASING, FED.

#### Verb 4: Purr

After sustained stillness near an NPC, BONNIE begins purring — a deeper engagement
that replaces the Sit Near rate and unlocks the levity multiplier in VULNERABLE.

- **Activation**: Purr activates automatically after BONNIE has been in the Sit Near
  active state for `purr_onset_time` (default: 4.0 s). No additional player input is
  required. Sit Near must remain active continuously — any movement that interrupts
  Sit Near resets the purr timer.
- **Effect while active**: `goodwill += purr_goodwill_rate` (default: 0.025) per
  second. This REPLACES the sit_goodwill_rate — the two rates do not stack.
- **VULNERABLE levity bonus**: When NPC `current_behavior == VULNERABLE`, purr rate
  becomes `purr_goodwill_rate * levity_multiplier`. The `levity_multiplier` value
  (default: 1.5) is sourced from the NPC's personality data — the Social System reads
  it as a property of the NpcState object. At defaults, VULNERABLE purr yields 0.0375/s.
- **Valid NPC states**: ROUTINE, RECOVERING, VULNERABLE. (NOT AWARE — an alert NPC
  cannot relax into a purr response.)
- **Invalid NPC states**: AWARE, ASLEEP, GROGGY, REACTING, CLOSED_OFF, FLEEING,
  CHASING, FED.
- **Deactivation**: Any player movement ends Sit Near, which ends Purr. Purr timer
  resets to zero.

#### Verb 5: Gift Delivery

BONNIE delivers a caught pest as a social offering. The NPC's response — touched or
horrified — is determined by the current goodwill level and produces comedy regardless
of the mechanical outcome.

- **Activation**: BONNIE must be carrying a caught pest item (mouse, bug, or equivalent
  collectible). Player drops the item within `gift_range` (default: 48 px) of the NPC's
  center.
- **Condition branch**:
  - If `goodwill > 0.3` at the moment of drop: `goodwill += gift_goodwill_base`
    (default: 0.05). NPC registers the gift as endearing. Reaction: "touched" animation
    and warm-register dialogue.
  - If `goodwill <= 0.3` at the moment of drop: `goodwill -= gift_disgust_penalty`
    (default: 0.02). NPC registers the gift as horrifying. Reaction: "horrified"
    animation and aversive-register dialogue.
  - When touched: `last_interaction_type = CHARM`. BONNIE's social intent lands.
  - When horrified: `last_interaction_type = CHAOS`. The disgust reaction registers as
    a chaos event — the NPC's revulsion emits a chaos signal that the Chaos Meter
    reads. A player who hoards pests and dumps them on an uptight, low-goodwill NPC
    is rewarded with chaos meter progress for each delivery.
- **One-time per item**: Each pest instance can be gifted exactly once. After delivery,
  the item is consumed and removed from BONNIE's inventory.
- **Goodwill floor**: Goodwill cannot drop below 0.0. The disgust penalty is clamped.
- **Valid NPC states**: ROUTINE, AWARE, RECOVERING, VULNERABLE.
- **Invalid NPC states**: ASLEEP, GROGGY, REACTING, CLOSED_OFF, FLEEING, CHASING, FED.
  If BONNIE drops a pest item near an NPC in an invalid state, the item falls to the
  ground as a loose prop with no social effect.

---

### 3.3 Chaos Events — Goodwill Impact

When a chaos event is generated by any game system within `chaos_proximity_range`
(default: 128 px) of an NPC's center:

1. `goodwill -= chaos_goodwill_penalty` (default: 0.05). Clamped to 0.0.
2. `last_interaction_type = CHAOS`.
3. If multiple chaos events occur in the same frame, each applies its penalty
   independently. There is no per-frame deduplication — rapid consecutive chaos
   stacks.
4. The Social System records the goodwill hit and sets `last_interaction_type`. The
   NPC System reads `last_interaction_type` and `goodwill` to drive behavior
   transitions (e.g., tipping into REACTING or CLOSED_OFF) — those transitions are
   the NPC System's decision.
5. Special case — NPC in VULNERABLE receiving a chaos event: the Social System applies
   the standard goodwill penalty and sets `last_interaction_type = CHAOS`. The NPC
   System is responsible for detecting that a VULNERABLE NPC has just received a chaos
   event and transitioning it to CLOSED_OFF if appropriate. The Social System does not
   trigger that transition.

---

### 3.4 Goodwill Decay

Goodwill is not permanent. It degrades when BONNIE is absent.

- **Decay condition**: BONNIE's center is NOT within `social_range` (default: 128 px)
  of the NPC's center.
- **Decay rate**: `goodwill -= goodwill_decay_rate` (default: 0.005) per second while
  the decay condition is true. Clamped to 0.0.
- **Decay pause**: Decay is suspended for the entire duration that BONNIE is within
  `social_range`, even if no active charm verb is being performed. Proximity alone
  maintains the relationship.
- **Per-NPC independence**: Each NPC's goodwill decays on its own timer. Decay of one
  NPC's goodwill has no effect on any other NPC.
- **State exceptions**: Goodwill does NOT decay during ASLEEP or FED states, regardless
  of BONNIE's position. A sleeping NPC and a fed NPC retain their current goodwill
  until they exit those states.

---

### 3.5 Comfort Receptivity Modification

`comfort_receptivity` is the Social System's mechanism for influencing how quickly
an NPC emotionally recovers. The NPC System reads this field to modulate its own
`emotional_level` decay rate — higher receptivity means the NPC cools faster. The
Social System writes `comfort_receptivity` based on the following rules:

- **During VULNERABLE** (`current_behavior == VULNERABLE`):
  Each successful charm interaction (any verb that applies goodwill) raises
  `comfort_receptivity` by `comfort_boost` (default: 0.1), up to the per-NPC
  `comfort_receptivity_ceiling` (range: 0.5–1.0, set per NPC personality).

- **During RECOVERING** (`current_behavior == RECOVERING`):
  Each successful charm interaction raises `comfort_receptivity` by
  `comfort_boost * 0.5` (default: 0.05). The NPC is cooling but not fully open;
  the effect is half-strength.

- **During CLOSED_OFF** (`current_behavior == CLOSED_OFF`):
  `comfort_receptivity` is locked at the per-NPC `comfort_receptivity_floor`
  (range: 0.0–0.2, set per NPC personality). The Social System cannot modify
  `comfort_receptivity` while the NPC is in CLOSED_OFF. It will not attempt
  to write the field in this state. The NPC naturally exits CLOSED_OFF on its
  own timer (NPC System's responsibility), at which point Social System resumes
  normal write access.

- **All other states**: `comfort_receptivity` is not modified by the Social System.
  It persists at its last written value.

The Social System is responsible only for writing `comfort_receptivity`. It does not
read back the value to make decisions. Interpreting `comfort_receptivity` and acting
on it is entirely the NPC System's domain.

---

### 3.6 Visual Legibility — No-HUD Contract

There is no goodwill meter, no social status indicator, and no on-screen feedback
overlay. All social state is communicated through NPC body language, animation, and
dialogue samples. The following behavioral signals are required and must be implementable
by the NPC animation and dialogue systems.

**Goodwill tiers and their required NPC signals:**

| Tier | Goodwill Range | Required NPC Signal |
|---|---|---|
| Low | 0.0–0.3 | NPC ignores BONNIE; turns body away; idle dialogue is short and dismissive in register |
| Medium | 0.3–0.6 | NPC acknowledges BONNIE with a glance; idle dialogue is neutral; body posture is tolerant but not open |
| High | 0.6–1.0 | NPC orients toward BONNIE; idle dialogue is warm; posture is relaxed and open; NPC may initiate animation (reaching down, leaning) |

**Required per-verb feedback signals:**

| Verb | Required NPC Animation Response |
|---|---|
| Rub | NPC shifts hand/arm toward BONNIE; posture softens within first rub tick |
| Meow | NPC turns head toward BONNIE; brief single-line dialogue response plays |
| Sit Near | NPC idle animation relaxes progressively over 4–6 seconds of sustained proximity |
| Purr | NPC animation fully shifts to relaxed register; NPC may sit or crouch; ambient music layer shifts |
| Gift Delivery (touched) | NPC bends down, warm gesture toward item; warm-register dialogue plays |
| Gift Delivery (horrified) | NPC recoils; aversive-register dialogue plays; brief REACTING micro-state |

**Required chaos feedback signals:**

| Trigger | Required NPC Signal |
|---|---|
| Chaos event near NPC | NPC posture sharpens; dialogue shifts to harsher register |
| Repeated chaos (3+ events) | NPC's transition time to REACTING visibly decreases; body language is tense at idle |

**QA legibility standard**: A QA tester with no access to debug overlays must be
able to identify whether a given NPC's goodwill is in the Low, Medium, or High tier
within 5 seconds of observing the NPC's idle behavior, without BONNIE performing any
action.

---

## 4. Formulas

### 4.1 Goodwill Modification

All goodwill changes from charm verbs are scaled by the NPC's current `comfort_receptivity` (read from NpcState), then applied as additive deltas, clamped to `[0.0, 1.0]`:

```
goodwill_new = clamp(goodwill + (Δgoodwill × comfort_receptivity), 0.0, 1.0)
```

This means charm interactions are less effective on NPCs who are currently unreceptive (e.g., RECOVERING at `comfort_receptivity = 0.15` yields only 15% of the base delta). Chaos goodwill penalties are NOT scaled by `comfort_receptivity` — they apply at full strength regardless of NPC state.

**Note**: `npc-personality.md` §4.2 uses the same formula. This system (Social) is the writer; NPC Personality defines the receptivity values. Both must agree on this contract.

**Charm verb deltas:**

| Source | Formula | Default Δgoodwill | Frequency |
|--------|---------|-------------------|-----------|
| Rub tick | `+rub_goodwill_rate` | +0.02 | Per `rub_tick_interval` (0.5s) while held |
| Meow | `+meow_goodwill_bump` | +0.03 | One-shot, per `meow_cooldown` (3.0s) per NPC |
| Sit Near | `+sit_goodwill_rate × Δt` | +0.01/s | Continuous while sitting |
| Sit Near (VULNERABLE) | `+sit_goodwill_rate × vulnerable_sit_multiplier × Δt` | +0.02/s | Continuous, VULNERABLE only |
| Purr | `+purr_goodwill_rate × Δt` | +0.025/s | Replaces Sit Near rate |
| Purr (VULNERABLE) | `+purr_goodwill_rate × levity_multiplier × Δt` | +0.0375/s | VULNERABLE with levity bonus |
| Gift (touched) | `+gift_goodwill_base` | +0.05 | One-shot, requires `goodwill > 0.3` |
| Gift (horrified) | `-gift_disgust_penalty` | -0.02 | One-shot, when `goodwill <= 0.3` |

**Chaos event delta:**

```
Δgoodwill_chaos = -chaos_goodwill_penalty    (per event within chaos_proximity_range)
```

| Variable | Default | Range | Description |
|----------|---------|-------|-------------|
| `chaos_goodwill_penalty` | 0.05 | [0.01, 0.10] | Goodwill lost per chaos event near this NPC |
| `chaos_proximity_range` | 128 px | [64, 256] px | Range within which chaos events affect goodwill |

**Example — charm session:**
Starting goodwill = 0.0. Player rubs for 5s (10 ticks × 0.02 = +0.20), meows once (+0.03), sits for 10s (+0.10). Final goodwill = 0.33.

**Example — chaos disruption:**
Starting goodwill = 0.50. Three chaos events near NPC (3 × -0.05 = -0.15). Final goodwill = 0.35.

---

### 4.2 Goodwill Decay

```
if distance(bonnie, npc) > social_range
   AND npc.current_behavior NOT IN {ASLEEP, FED}:
    goodwill -= goodwill_decay_rate × Δt
    goodwill = max(goodwill, 0.0)
```

| Variable | Default | Range | Description |
|----------|---------|-------|-------------|
| `social_range` | 128 px | [64, 256] px | Proximity threshold; decay pauses when BONNIE is within this range |
| `goodwill_decay_rate` | 0.005/s | [0.001, 0.02]/s | Rate of passive goodwill loss when BONNIE is absent |

**Example:** BONNIE leaves an NPC at goodwill = 0.50. After 60s away: `0.50 - (0.005 × 60) = 0.20`.

---

### 4.3 Comfort Receptivity Modification

```
if current_behavior == VULNERABLE:
    comfort_receptivity += comfort_boost                    # +0.10
elif current_behavior == RECOVERING:
    comfort_receptivity += comfort_boost × 0.5              # +0.05
elif current_behavior == CLOSED_OFF:
    comfort_receptivity = comfort_receptivity_floor          # locked
```

| Variable | Default | Range | Description |
|----------|---------|-------|-------------|
| `comfort_boost` | 0.10 | [0.03, 0.20] | Comfort receptivity increase per charm interaction in VULNERABLE |
| `comfort_receptivity_ceiling` | 0.5–1.0 | Per-NPC | Maximum comfort_receptivity (set by NPC personality) |
| `comfort_receptivity_floor` | 0.0–0.2 | Per-NPC | Minimum during CLOSED_OFF (set by NPC personality) |

---

### 4.4 Effective Purr Rate (VULNERABLE with Levity)

```
effective_purr_rate = purr_goodwill_rate × levity_multiplier
                    = 0.025 × 1.5
                    = 0.0375/s
```

| Variable | Default | Source | Description |
|----------|---------|-------|-------------|
| `purr_goodwill_rate` | 0.025/s | Social System | Base purr goodwill rate |
| `levity_multiplier` | 1.5 | NPC personality (System 9) | Post-chaos emotional contrast bonus |

**Example — full VULNERABLE purr sequence** (assumes `comfort_receptivity = 1.0`):
BONNIE sits near VULNERABLE NPC for 2s (onset) → sits for 4s (purr onset) → purrs for 10s.
Goodwill earned: `(2s × 0.02 × 1.0) + (4s × 0.02 × 1.0) + (10s × 0.0375 × 1.0) = 0.04 + 0.08 + 0.375 = 0.495`
Note: At `comfort_receptivity = 0.5` (partially receptive), total would be `0.2475`.

---

## 5. Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| BONNIE performs charm verb while NPC transitions to REACTING mid-interaction | Interaction cancelled immediately; partial tick goodwill not applied | NPC state change is authoritative; interrupted ticks are discarded |
| Two chaos events hit same NPC on same frame | Both penalties apply independently (-0.10 total) | No per-frame deduplication; rapid chaos stacks |
| BONNIE sits near two NPCs with overlapping ranges | Both NPCs receive sit goodwill independently | Each NPC has independent NpcState; no interaction between them |
| Goodwill already at 1.0, charm verb applied | No goodwill increase (clamped); interaction animation still plays | Visual feedback is consistent; no wasted animation |
| Gift delivered to NPC at exactly goodwill = 0.3 | Horrified branch fires (`<= 0.3` threshold); goodwill penalty + chaos contribution | Consistent boundary: "must exceed 0.3" for touched |
| NPC exits VULNERABLE while BONNIE is purring | Purr continues at non-VULNERABLE rate; levity multiplier deactivates on the frame of state change | State is checked per-tick, not at purr onset |
| BONNIE starts meow but exits meow_range before sound completes | Meow fires if range check passes at button press frame; subsequent movement does not cancel | Range is checked at activation, not sustained |
| Meow cooldown active, player presses vocalize again | Input consumed silently; no effect, no feedback | Cooldown is per-NPC; spamming is inert, not punished |
| All NPCs in CLOSED_OFF simultaneously | Social System cannot modify any comfort_receptivity; all charm verbs rejected; player must wait for NPC CLOSED_OFF timers to expire naturally | CLOSED_OFF is the cost of pure chaos without recovery; forced patience |
| Goodwill decay brings NPC below `minimum_feeding_goodwill` during feeding transition | Feeding aborts; `feeding_threshold_reached` was permission, not guarantee. NPC system re-checks goodwill at FED entry. | Decay is continuous; the goodwill gate is authoritative at transition time |
| BONNIE carrying pest enters gift_range of NPC in REACTING | Item drops as loose prop; no social effect; no goodwill change | REACTING is invalid for Gift Delivery; NPC is too agitated |
| Purr active, NPC enters AWARE state | Purr immediately deactivates (AWARE is invalid for Purr); reverts to Sit Near if still valid | AWARE NPC is too alert to relax into purr |

---

## 6. Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| Reactive NPC System (9) | Bidirectional via NpcState | Social writes `goodwill`, `last_interaction_type`, `comfort_receptivity`; NPC System writes `emotional_level`, `current_behavior`, `active_stimuli`, `visible_to_bonnie`, `bonnie_hunger_context`. Neither calls the other. |
| BONNIE Traversal (6) | Social depends on | BONNIE's position and movement state determine verb activation ranges, sit/purr onset, and goodwill decay |
| Chaos Meter (13) | Depends on Social | Reads goodwill for charm-boosted reactions; reads VULNERABLE comfort events for charm contributions; reads gift horror events for chaos contributions |
| Environmental Chaos System (8) | Social depends on | Chaos events (object displacement) near NPCs trigger goodwill penalties via `chaos_proximity_range` |
| Pest / Survival System (15) | Social depends on | Gift delivery requires caught pest items from inventory |
| Audio Manager (3) | Social depends on | Meow verb requires vocal sample playback; NPC dialogue responses require audio system |
| Input System (1) | Social depends on | Charm verb inputs: interact button (rub), vocalize button (meow), drop button (gift) |
| Camera System (4) | Depends on Social (indirect) | NPC body language changes (goodwill tiers) are visible through camera framing |

**Bidirectional NpcState contract** (the circular dependency resolution):
- This is the critical architectural boundary. The Social System and NPC System share NpcState as a passive data record. Neither system has a reference to the other. Both read and write on their own schedule.
- **Violation guard**: If any future system change introduces a direct call from Social→NPC or NPC→Social, this contract is broken and the circular dependency returns. This is a Mycelium constraint.

---

## 7. Tuning Knobs

### Charm Verb Parameters

| Parameter | Default | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|---------|------------|-------------------|-------------------|
| `rub_range` | 48 px | [24, 96] px | Easier to activate rub; less precision needed. | Requires close contact; more deliberate. |
| `rub_tick_interval` | 0.5s | [0.25, 1.0] s | Slower goodwill accrual per rub. | Faster accrual; rub becomes dominant verb. |
| `rub_goodwill_rate` | 0.02 | [0.005, 0.05] | Rub is more effective per tick. | Rub feels weak; long holds needed. |
| `meow_range` | 96 px | [48, 192] px | Meow works from further away. | Requires closer proximity. |
| `meow_cooldown` | 3.0s | [1.0, 8.0] s | Less frequent meowing; more deliberate. | Meow spam viable but low-value per use. |
| `meow_goodwill_bump` | 0.03 | [0.01, 0.08] | Single meow is impactful. | Meow is negligible; a greeting, not a strategy. |
| `sit_range` | 64 px | [32, 128] px | Wider sit activation zone. | Must be very close to NPC. |
| `sit_onset_time` | 2.0s | [0.5, 5.0] s | Quick sit onset; easy to trigger accidentally. | Long stillness required; very deliberate. |
| `sit_goodwill_rate` | 0.01/s | [0.003, 0.03]/s | Passive sitting more rewarding. | Sitting barely matters; must purr for value. |
| `vulnerable_sit_multiplier` | 2.0 | [1.0, 4.0] | VULNERABLE sitting much more effective. | VULNERABLE sit same as normal. At 1.0: no bonus. |
| `purr_onset_time` | 4.0s | [2.0, 8.0] s | Purr activates sooner; less commitment. | Purr requires long sustained sit; high commitment. |
| `purr_goodwill_rate` | 0.025/s | [0.01, 0.05]/s | Purr is highly effective. | Purr barely outperforms sit. |
| `gift_range` | 48 px | [24, 96] px | Easier gift delivery. | Must be very close. |
| `gift_goodwill_base` | 0.05 | [0.02, 0.10] | Gifts are a strong charm path. | Gifts are mostly comedy. |
| `gift_disgust_penalty` | 0.02 | [0.005, 0.05] | Horror gifts punish goodwill more. | Horror gifts are nearly free. |

### Chaos Impact Parameters

| Parameter | Default | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|---------|------------|-------------------|-------------------|
| `chaos_goodwill_penalty` | 0.05 | [0.01, 0.10] | Chaos burns goodwill faster; social play is fragile. | Chaos barely affects goodwill; social play is risk-free. |
| `chaos_proximity_range` | 128 px | [64, 256] px | Chaos affects NPCs from further away. | Only close-range chaos hits goodwill. |

### Goodwill Decay

| Parameter | Default | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|---------|------------|-------------------|-------------------|
| `social_range` | 128 px | [64, 256] px | BONNIE can be further away without decay. | Must stay close to maintain goodwill. |
| `goodwill_decay_rate` | 0.005/s | [0.001, 0.02]/s | Goodwill evaporates quickly; demands constant attention. At 0.02: goodwill halves in 25s. | Goodwill is nearly permanent. At 0.001: takes 500s to decay from 0.5 to 0. |

### Comfort Receptivity

| Parameter | Default | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|---------|------------|-------------------|-------------------|
| `comfort_boost` | 0.10 | [0.03, 0.20] | Fewer charm interactions to max comfort_receptivity. | Slow comfort recovery; requires sustained social engagement. |

---

## 8. Acceptance Criteria

**AC-SOC01: Goodwill accrues from charm verbs**
- [ ] Rub for 5s (10 ticks at default) → goodwill increases by 0.20
- [ ] Meow → goodwill increases by 0.03; second meow within 3s has no effect (cooldown)
- [ ] Sit near for 10s → goodwill increases by 0.10
- [ ] Purr for 10s (after sit onset + purr onset) → goodwill increases by 0.25

**AC-SOC02: Chaos burns goodwill**
- [ ] Object displacement within 128px of NPC → goodwill decreases by 0.05
- [ ] Three chaos events within 1s → goodwill decreases by 0.15 (no deduplication)
- [ ] Goodwill never drops below 0.0

**AC-SOC03: NPC state validity enforced**
- [ ] Charm verb on NPC in REACTING → no effect, no goodwill change, interaction silently rejected
- [ ] Charm verb on NPC in CLOSED_OFF → no effect, silently rejected
- [ ] Charm verb on NPC in ROUTINE → goodwill increases normally

**AC-SOC04: VULNERABLE levity multiplier**
- [ ] Purr on VULNERABLE NPC → goodwill rate is `purr_goodwill_rate × levity_multiplier` (0.0375/s at defaults)
- [ ] Same purr on ROUTINE NPC → goodwill rate is `purr_goodwill_rate` (0.025/s)
- [ ] NPC exits VULNERABLE mid-purr → rate drops to non-VULNERABLE rate on same frame

**AC-SOC05: Gift delivery branches**
- [ ] Gift to NPC with goodwill 0.5 → goodwill +0.05, `last_interaction_type = CHARM`
- [ ] Gift to NPC with goodwill 0.2 → goodwill -0.02, `last_interaction_type = CHAOS`, chaos meter receives `gift_disgust_chaos`
- [ ] Gift to NPC in REACTING → item drops as prop, no social effect

**AC-SOC06: Goodwill decay functions**
- [ ] BONNIE at 200px from NPC (beyond `social_range`) → goodwill decays at 0.005/s
- [ ] BONNIE at 100px from NPC (within `social_range`) → goodwill does not decay
- [ ] NPC in ASLEEP → goodwill does not decay regardless of BONNIE's position
- [ ] NPC in FED → goodwill does not decay

**AC-SOC07: Visual legibility (no-HUD contract)**
- [ ] NPC at goodwill 0.1 (Low tier) → NPC ignores BONNIE, dismissive body language
- [ ] NPC at goodwill 0.5 (Medium tier) → NPC acknowledges BONNIE, neutral posture
- [ ] NPC at goodwill 0.8 (High tier) → NPC orients toward BONNIE, warm posture
- [ ] QA tester can identify goodwill tier within 5 seconds of observation without debug tools

**AC-SOC08: NpcState write contract respected**
- [ ] Social System never writes `emotional_level`, `current_behavior`, `active_stimuli`, `visible_to_bonnie`, or `bonnie_hunger_context`
- [ ] Social System only writes `goodwill`, `last_interaction_type`, `comfort_receptivity`
- [ ] No direct function call from Social System to NPC System or vice versa

**AC-SOC09: Comfort receptivity modification**
- [ ] Charm interaction during VULNERABLE → `comfort_receptivity` increases by 0.10
- [ ] Charm interaction during RECOVERING → `comfort_receptivity` increases by 0.05
- [ ] During CLOSED_OFF → `comfort_receptivity` locked at floor; Social System does not write

**AC-SOC10: Performance**
- [ ] Goodwill evaluation for all active NPCs completes within 0.5ms per frame
- [ ] Verb activation range checks use spatial indexing, not brute-force iteration

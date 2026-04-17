# Chaos Meter

> **Status**: Draft
> **System**: #13 — Chaos Meter
> **Priority**: MVP
> **Authors**: game-designer (Session 008)
> **Created**: 2026-04-17
> **Depends On**: Bidirectional Social System (12), Environmental Chaos System (8), Pest / Survival System (15), Reactive NPC System (9)
> **Downstream**: Chaos Meter UI (23), Notoriety System (21), Feeding Cutscene System (19)

---

## 1. Overview

The Chaos Meter is BONNIE!'s primary progress indicator — the visible, fillable gauge that gates the session's payoff: getting fed. It is not a health bar, not a timer, and not a fail condition. It is a measure of how much of a scene BONNIE has made of herself, and how much social capital she has spent or earned doing it.

The meter has two contribution axes. The **chaos axis** fills via environmental disturbance and NPC distress: knocking objects over, triggering NPC REACTING states, engineering multi-NPC cascade chains (Domino Rally), catching pests, and causing general mayhem. The **charm axis** fills via social goodwill: rubbing against legs in ROUTINE, sitting with VULNERABLE NPCs until they soften, and performing comfort interactions that activate the levity multiplier. Both axes push the same meter needle, but by different amounts and through different gameplay.

The critical design constraint is that pure chaos has a mathematical ceiling below the feeding threshold. No matter how aggressively BONNIE smashes and bolts, brute-force destruction cannot reach FED alone. Charm contributions — amplified by the NPC goodwill system and the levity multiplier — are the mechanism that carries the meter over the top. The meter rewards reading the room. Scraps get you most of the way there. Real feeding requires going further.

---

## 2. Player Fantasy

The chaos meter should make the player feel like the smartest cat in the building.

The base satisfaction is chaotic: knocking a glass off a counter, watching Michael startle, seeing the meter tick up. That's the hook — the Katamari Damacy dopamine hit of making something happen and watching the world react. The meter is visible and responsive. Every action lands. The player is never confused about whether chaos is contributing.

But the deeper satisfaction is social intelligence. The player who notices Christen slumped on the kitchen floor — exhausted, VULNERABLE after Michael's meltdown — and chooses to sit with her, to purr, to let the moment breathe, earns a disproportionate meter reward. The levity multiplier fires: chaos immediately followed by warmth is the funniest and most mechanically potent sequence in the game. The player who discovered this doesn't feel clever by accident. They feel like they *read the room*.

The design tension is the player's most satisfying puzzle: I can smash my way to 80% of the meter without thinking. The last 20% requires me to stop, observe, and be a cat who actually gives a damn — at least briefly. The frustration of that final gap, and the warmth of bridging it through a charm chain or a perfectly-timed VULNERABLE exploit, is the emotional arc of every session.

This is the MDA Aesthetics at play: **Challenge** (the meter gap is a real obstacle) and **Expression** (the path to bridging it is the player's to discover) sitting inside a frame of **Fantasy** (you are a cat who understands these humans better than they understand themselves).

---

## 3. Detailed Rules

### 3.1 Meter Structure

The chaos meter is a single float value, `meter_value`, ranging from `0.0` to `1.0`. It is visible to the player at all times; display is handled by Chaos Meter UI (System 23). The meter does **not** decay over time. Progress earned stays earned. This is a deliberate design choice that prevents the treadmill anti-pattern, where players feel punished for stopping to explore rather than grinding meter contributions.

Two configurable threshold values gate the meter's behavior:

| Field | Default | Meaning |
|---|---|---|
| `feeding_threshold` | `0.85` | The `meter_value` at which the FED transition becomes available |
| `chaos_ceiling` | `0.65` | The maximum `meter_value` reachable through chaos contributions alone |

The gap between `chaos_ceiling` and `feeding_threshold` (default: `0.20`) is the mathematical proof that charm is required. A player who only causes mayhem will reach `0.65` and stall. Charm contributions are the mechanism that carries the meter over the top.

Internally, the meter tracks two independent running subtotals:

- `chaos_subtotal` — the accumulated sum of all chaos contributions
- `charm_subtotal` — the accumulated sum of all charm contributions

`meter_value` is derived each frame:

```
meter_value = clamp(chaos_subtotal, 0.0, chaos_ceiling) + charm_subtotal
meter_value = clamp(meter_value, 0.0, 1.0)
```

The chaos subtotal is clamped to `chaos_ceiling` before being added to the charm subtotal. Charm contributions are uncapped and are the only mechanism by which `meter_value` can exceed `chaos_ceiling`.

---

### 3.2 Contribution Sources

All contributions are additive to their respective subtotal. The Chaos Meter never writes to NpcState — all NPC fields listed below are read-only from the perspective of this system.

#### Chaos Contributions

These feed `chaos_subtotal`. Collectively, they are capped at `chaos_ceiling` (0.65).

**1. NPC REACTING event**

Trigger: Any NPC whose `current_behavior` transitions to `REACTING`.

Contribution: `npc_reaction_base` (default: `0.04`) is added to `chaos_subtotal`.

This is the most frequent chaos contribution in a typical session. The value is read from the NPC system's state signal, not polled.

**2. Cascade bonus**

Trigger: A cascade chain fires — NPC A enters REACTING and, as a result, NPC B also enters REACTING within the cascade propagation window defined in Reactive NPC System (System 9).

Contribution:
- Depth-1 cascade (A triggers B): the second NPC's reaction contributes `npc_reaction_base * cascade_multiplier` (default `cascade_multiplier`: `1.5`) rather than the base rate.
- Depth-2 cascade (A triggers B triggers C): C's reaction contributes `npc_reaction_base * cascade_multiplier * cascade_multiplier` (i.e., `npc_reaction_base * 1.5 * 1.5 = npc_reaction_base * 2.25`).
- Maximum cascade depth is 2, as specified in npc-personality.md §3.3. Contributions beyond depth 2 are not generated.

Note: The initiating NPC (A) contributes at the base rate. Only subsequent chain members receive the multiplier.

**3. Object displacement**

Trigger: Any interactive object emits the `object_displaced` signal (System 7 — Environmental Chaos System).

Contribution: `object_displacement_base * weight_class_multiplier` is added to `chaos_subtotal`.

- `object_displacement_base` default: `0.02`
- `weight_class_multiplier` is a per-object property defined in the Environmental Chaos System (System 8). Light objects use `1.0`; heavier objects use a multiplier greater than `1.0`. The exact multiplier table lives in System 8's data.

**4. Pest catch**

Trigger: BONNIE catches a mouse or bug (as defined by the Pest / Survival System, System 15).

Contribution: `pest_catch_base` (default: `0.01`) is added to `chaos_subtotal`.

Small but consistent. Designed to reward active pest hunting without making it a dominant path.

**5. Environmental combo**

Trigger: Three or more `object_displaced` signals occur within a rolling `combo_window`-second window (default: `2.0` seconds).

Contribution: `combo_bonus` (default: `0.03`) is added to `chaos_subtotal` once per combo event.

The combo window is evaluated as a sliding window, not a resetting timer. Displacing objects 1, 2, and 3 within 2.0 seconds triggers one combo bonus. If object 4 is displaced within 2.0 seconds of object 2, a second combo fires. The combo system does not have an internal cooldown between firings — rapid displacement chains can trigger multiple combos.

---

#### Charm Contributions

These feed `charm_subtotal`. They are **not subject to `chaos_ceiling`** and are the only mechanism by which `meter_value` can exceed `0.65`. The charm contributions are also the highest single-event contributions in the game.

**1. Goodwill-boosted reaction**

Trigger: An NPC enters REACTING and that NPC's `goodwill` value is greater than `goodwill_bonus_threshold` (default: `0.4`).

Contribution: The NPC still contributes `npc_reaction_base` to `chaos_subtotal` as normal. Additionally, `goodwill * charm_reaction_bonus` (default `charm_reaction_bonus`: `0.06`) is added to `charm_subtotal`.

Example: An NPC with `goodwill = 0.6` entering REACTING contributes `0.04` to `chaos_subtotal` and `0.6 * 0.06 = 0.036` to `charm_subtotal`.

This mechanic rewards the player for investing in goodwill before triggering chaos — NPCs who like BONNIE make even her mayhem feel warmer.

**2. VULNERABLE comfort**

Trigger: BONNIE performs a comfort interaction (rub, sit, or purr) with an NPC whose `current_behavior` is `VULNERABLE`.

Contribution: `vulnerable_comfort_base * levity_multiplier` is added to `charm_subtotal`.

- `vulnerable_comfort_base` default: `0.05`
- `levity_multiplier` is sourced from the NPC personality system (System 9). The default levity multiplier applied to VULNERABLE comfort is `1.5`, making the effective contribution `0.05 * 1.5 = 0.075`.

This is the highest single-event contribution in the game. It is also the most situationally demanding: VULNERABLE state only occurs after an NPC has been brought to distress. The player who sequences chaos followed by comfort earns a disproportionate reward — this is intentional. That sequence is the funniest and most BONNIE-accurate behavior in the game.

**3. Routine charm**

Trigger: BONNIE performs a charm verb (rub, meow, or sit) with an NPC whose `current_behavior` is `ROUTINE` or `AWARE`.

Contribution: `routine_charm_base` (default: `0.015`) is added to `charm_subtotal`.

Small per-event, but accumulates across a session. Rewards players who engage socially with NPCs throughout normal movement rather than only in crisis moments.

**4. Gift delivery**

Trigger: BONNIE brings a caught pest (mouse or bug) to an NPC and performs the gift verb.

Contribution depends on the NPC's reaction, which is determined by `goodwill` (threshold: `0.3`, evaluated by the Social System):

- **Touched** (`goodwill > 0.3`): `gift_base` (default: `0.03`) is added to `charm_subtotal`. The NPC finds the gift endearing.
- **Horrified** (`goodwill <= 0.3`): `gift_disgust_chaos` (default: `0.03`) is added to `chaos_subtotal` instead. The NPC's revulsion IS chaos — a cat dumping a pile of roaches at an uptight NPC's feet is exactly the kind of creative mayhem the meter should reward.

Multiple gifts stack. A player who hoards pests and delivers them all at once to a low-goodwill NPC earns chaos for each delivery. This rewards creative pest-accumulation strategies.

---

### 3.3 The Chaos Ceiling Mechanic

The chaos ceiling is the core design constraint. This section specifies its behavior precisely.

All chaos contributions (NPC REACTING at zero goodwill, object displacement, pest catches, combos) accumulate into `chaos_subtotal`. This value is not clamped as it accumulates — it is clamped only during `meter_value` derivation:

```
meter_value = clamp(chaos_subtotal, 0.0, chaos_ceiling) + charm_subtotal
```

This means `chaos_subtotal` can exceed `chaos_ceiling` internally. A player who continues causing chaos after the ceiling is reached does not lose the excess — they simply stop gaining `meter_value` from chaos alone. The subtotal above the ceiling sits inert until a design iteration determines whether it has future use (it currently does not).

`charm_subtotal` is always added in full, uncapped. A player at `chaos_subtotal = 1.0` (far above ceiling) still gains the full benefit of every charm contribution.

`meter_value` is then clamped to `1.0` to prevent overflow.

**The minimum charm required to reach `feeding_threshold`:**

```
minimum_charm_required = feeding_threshold - chaos_ceiling
                       = 0.85 - 0.65
                       = 0.20
```

A player who has maxed out chaos contributions needs `charm_subtotal >= 0.20` to unlock feeding. Reference contribution counts at defaults:

| Path | Contributions needed to reach 0.20 |
|---|---|
| VULNERABLE comfort only | `ceil(0.20 / 0.075)` = 3 interactions |
| Routine charm only | `ceil(0.20 / 0.015)` = 14 interactions |
| Goodwill-boosted reactions only (goodwill = 0.6) | `ceil(0.20 / 0.036)` = 6 reactions |
| Mixed (2 VULNERABLE + routine charm) | 2 × 0.075 = 0.15, then `ceil(0.05 / 0.015)` = 4 routine charms |

These are minimums assuming maxed chaos. In practice, players reach `chaos_ceiling` partway through a session and begin accumulating charm contributions earlier, so the effective count is lower.

---

### 3.4 Feeding Trigger

When `meter_value >= feeding_threshold`, the Chaos Meter emits the signal `feeding_threshold_reached`.

This signal does **not** automatically trigger the FED state. It is a permission signal. The Reactive NPC System (System 9) listens for it and, when received, makes the FED transition available.

**Which NPC feeds BONNIE:**

The NPC with the highest `goodwill` value at the moment `feeding_threshold_reached` is emitted is the designated feeder. If two or more NPCs share the highest `goodwill`, proximity to BONNIE is the tiebreaker — the nearest tied NPC feeds her.

**Minimum goodwill gate:**

If no NPC has `goodwill > minimum_feeding_goodwill` (default: `0.3`), the feeding transition does not fire even if `meter_value >= feeding_threshold`. Crossing the threshold is insufficient without at least one NPC who has been charmed enough to actually want to feed BONNIE. The signal is emitted regardless; the NPC system is responsible for enforcing the goodwill gate.

**Hunger context modifier:**

The `bonnie_hunger_context` flag is set by the Pest / Survival System (System 15) when BONNIE has been active for `hunger_onset_time` seconds without being fed. When this flag is active, the effective `feeding_threshold` is reduced by `hunger_threshold_reduction` (default: `0.10`):

```
effective_threshold = feeding_threshold - (bonnie_hunger_context ? hunger_threshold_reduction : 0.0)
                    = 0.85 - 0.10
                    = 0.75   (when hunger context is active)
```

The Chaos Meter reads `bonnie_hunger_context` as a signal or property from System 15. It does not write to it. The hunger context reduces the threshold at the evaluation point each frame — it does not retroactively alter the history of `chaos_subtotal` or `charm_subtotal`.

---

### 3.5 Meter Readback and Signal Emission

**UI readback:**

`meter_value` is exposed as a read-only property. Chaos Meter UI (System 23) reads it each frame for display. The Chaos Meter does not push to the UI; the UI pulls from the meter.

**Atmosphere signals:**

The meter emits one-shot signals at configurable threshold values for music and atmosphere systems to respond to. Each signal fires once as `meter_value` crosses upward through the threshold. Signals do not re-fire if `meter_value` drops below a threshold and crosses it again (the meter does not drop, but this rule is stated for implementation clarity).

| Signal | Default Threshold | Intended Effect |
|---|---|---|
| `chaos_meter_low` | `0.25` | First quarter crossed — subtle atmosphere shift begins |
| `chaos_meter_mid` | `0.50` | Halfway — tension rises, NPC alertness increases |
| `chaos_meter_high` | `0.75` | Three quarters — all NPCs on edge, music reaches near-peak |
| `feeding_threshold_reached` | `0.85` (or effective threshold) | Feeding unlocked — NPC system may initiate FED |

All threshold values are configurable via tuning knobs (§7). The signal names are fixed contracts; thresholds are data-driven.

---

## 4. Formulas

### 4.1 Meter Derivation

`meter_value` is a float in `[0.0, 1.0]` derived each frame from two independent running subtotals.

**Core formula:**

```
meter_value = clamp( clamp(chaos_subtotal, 0.0, C_ceil) + charm_subtotal, 0.0, 1.0 )
```

**Variable table:**

| Symbol | Field Name | Type | Range | Description |
|--------|------------|------|-------|-------------|
| `M` | `meter_value` | float | [0.0, 1.0] | Final meter value exposed to UI and threshold evaluator |
| `CS` | `chaos_subtotal` | float | [0.0, ∞) | Accumulated sum of all chaos contributions; not internally clamped |
| `XS` | `charm_subtotal` | float | [0.0, 1.0] | Accumulated sum of all charm contributions; uncapped |
| `C_ceil` | `chaos_ceiling` | float | (0.0, 1.0) | Maximum meter value reachable from chaos contributions alone; default `0.65` |
| `F_thresh` | `feeding_threshold` | float | (0.0, 1.0) | Meter value at which `feeding_threshold_reached` is emitted; default `0.85` |

**Expansion:**

```
M = clamp( clamp(CS, 0.0, C_ceil) + XS, 0.0, 1.0 )
```

Because `C_ceil < F_thresh` by design constraint, the meter can only reach `F_thresh` when `XS > 0`.

**Example (typical mid-session state):**

- `chaos_subtotal = 0.55`, `charm_subtotal = 0.08`
- `clamp(0.55, 0.0, 0.65) = 0.55`
- `meter_value = clamp(0.55 + 0.08, 0.0, 1.0) = 0.63`

---

### 4.2 Chaos Contribution Formulas

All chaos contributions are added to `chaos_subtotal`. The subtotal is not clamped during accumulation; clamping occurs only during meter derivation (§4.1).

---

**4.2.1 NPC REACTING (base)**

```
ΔCS_react = R_base
```

| Symbol | Field Name | Default | Range | Description |
|--------|------------|---------|-------|-------------|
| `ΔCS_react` | — | — | [0.0, R_base] | Contribution added to `chaos_subtotal` per REACTING event |
| `R_base` | `npc_reaction_base` | `0.04` | [0.01, 0.10] | Base chaos added per NPC entering REACTING state |

Fires once per NPC per transition into REACTING. Does not fire on re-entry if the NPC was already in REACTING.

**Example:** 10 REACTING events → `ΔCS = 10 × 0.04 = 0.40`

---

**4.2.2 Cascade Bonus**

```
ΔCS_cascade(d) = R_base × C_mult^d
```

| Symbol | Field Name | Default | Range | Description |
|--------|------------|---------|-------|-------------|
| `ΔCS_cascade(d)` | — | — | — | Contribution for a chain member at depth `d` |
| `d` | depth | — | {1, 2} | Cascade depth of this NPC (1 = triggered by initiator, 2 = triggered by depth-1 NPC) |
| `R_base` | `npc_reaction_base` | `0.04` | [0.01, 0.10] | Base reaction value |
| `C_mult` | `cascade_multiplier` | `1.5` | [1.0, 3.0] | Multiplier applied per cascade depth |

The initiating NPC (depth 0) contributes `R_base` via §4.2.1 only. Only chain members receive the cascade formula.

**Expanded values at defaults:**

| Depth | Formula | Value |
|-------|---------|-------|
| 0 (initiator) | `R_base` | `0.040` |
| 1 | `0.04 × 1.5^1` | `0.060` |
| 2 | `0.04 × 1.5^2` | `0.090` |

**Example:** Initiator + depth-1 + depth-2 chain → `0.04 + 0.06 + 0.09 = 0.19`

---

**4.2.3 Object Displacement**

```
ΔCS_obj = D_base × W_mult
```

| Symbol | Field Name | Default | Range | Description |
|--------|------------|---------|-------|-------------|
| `ΔCS_obj` | — | — | — | Contribution added to `chaos_subtotal` per displaced object |
| `D_base` | `object_displacement_base` | `0.02` | [0.005, 0.05] | Base chaos per object displacement |
| `W_mult` | `weight_class_multiplier` | `1.0` (light) | [1.0, 3.0] | Per-object multiplier defined in System 8; light = 1.0, heavier objects use higher values |

`W_mult` values are owned by Environmental Chaos System (System 8). This formula consumes them read-only.

**Example:** 5 light objects + 2 medium objects (W_mult = 1.5) → `(5 × 0.02 × 1.0) + (2 × 0.02 × 1.5) = 0.10 + 0.06 = 0.16`

---

**4.2.4 Pest Catch**

```
ΔCS_pest = P_base
```

| Symbol | Field Name | Default | Range | Description |
|--------|------------|---------|-------|-------------|
| `ΔCS_pest` | — | — | — | Contribution added to `chaos_subtotal` per pest caught |
| `P_base` | `pest_catch_base` | `0.01` | [0.005, 0.03] | Flat chaos value per pest catch |

**Example:** 6 pests caught → `6 × 0.01 = 0.06`

---

**4.2.5 Environmental Combo**

```
ΔCS_combo = B_combo    (fires once per qualifying combo event)
```

| Symbol | Field Name | Default | Range | Description |
|--------|------------|---------|-------|-------------|
| `ΔCS_combo` | — | — | — | Contribution added to `chaos_subtotal` per combo trigger |
| `B_combo` | `combo_bonus` | `0.03` | [0.01, 0.08] | Flat bonus per combo event |
| `T_combo` | `combo_window` | `2.0` s | [0.5, 5.0] s | Sliding window duration for combo detection |

A combo event fires when 3 or more `object_displaced` signals occur within any `T_combo`-second sliding window. The combo has no internal cooldown. Multiple combos can fire in rapid succession during a displacement chain.

**Example:** 6 objects displaced in 2.0 s, qualifying as 2 overlapping combos → `2 × 0.03 = 0.06`

---

**4.2.6 Maximum Theoretical Chaos Contribution**

`chaos_subtotal` is unbounded in principle but produces no `meter_value` benefit beyond `C_ceil = 0.65`.

```
contribution_to_M_from_chaos = min(CS, C_ceil) = min(CS, 0.65)
```

Regardless of how large `CS` grows, the chaos contribution to `M` asymptotes at `0.65`.

---

### 4.3 Charm Contribution Formulas

All charm contributions are added to `charm_subtotal`. This subtotal is not subject to `chaos_ceiling`. It feeds directly into `meter_value` without an intermediate cap (the final `clamp` to `1.0` is the only ceiling).

---

**4.3.1 Goodwill-Boosted Reaction**

```
ΔXS_goodwill = goodwill × X_react    (only if goodwill > G_thresh)
```

| Symbol | Field Name | Default | Range | Description |
|--------|------------|---------|-------|-------------|
| `ΔXS_goodwill` | — | — | — | Charm contribution when a high-goodwill NPC enters REACTING |
| `goodwill` | `NPC.goodwill` | — | [0.0, 1.0] | NPC's current goodwill value; read from Reactive NPC System (9) |
| `X_react` | `charm_reaction_bonus` | `0.06` | [0.02, 0.15] | Charm bonus coefficient per unit of goodwill |
| `G_thresh` | `goodwill_bonus_threshold` | `0.4` | [0.1, 0.8] | Minimum goodwill for charm bonus to fire |

The NPC simultaneously contributes `R_base` to `chaos_subtotal` via §4.2.1. These contributions are not mutually exclusive.

**Example (bonus fires):** NPC with `goodwill = 0.7` enters REACTING → `ΔXS = 0.7 × 0.06 = 0.042`

**Example (bonus suppressed):** NPC with `goodwill = 0.3` enters REACTING → no charm contribution (below `G_thresh`); `ΔCS += 0.04` only.

---

**4.3.2 VULNERABLE Comfort**

```
ΔXS_vuln = V_base × L_mult
```

| Symbol | Field Name | Default | Range | Description |
|--------|------------|---------|-------|-------------|
| `ΔXS_vuln` | — | — | — | Charm contribution per VULNERABLE comfort interaction |
| `V_base` | `vulnerable_comfort_base` | `0.05` | [0.02, 0.12] | Base charm value for comforting a VULNERABLE NPC |
| `L_mult` | `levity_multiplier` | `1.5` | [1.0, 3.0] | Multiplier sourced from NPC personality system (System 9); represents post-chaos emotional contrast |

At defaults: `ΔXS_vuln = 0.05 × 1.5 = 0.075`

This is the highest single-event charm contribution in the game.

**Example:** 3 VULNERABLE comfort interactions → `3 × 0.075 = 0.225`

---

**4.3.3 Routine Charm**

```
ΔXS_routine = RC_base
```

| Symbol | Field Name | Default | Range | Description |
|--------|------------|---------|-------|-------------|
| `ΔXS_routine` | — | — | — | Charm contribution per routine charm interaction |
| `RC_base` | `routine_charm_base` | `0.015` | [0.005, 0.04] | Flat charm value per charm verb in ROUTINE or AWARE state |

**Example:** 10 routine charm interactions → `10 × 0.015 = 0.15`

---

**4.3.4 Gift Delivery (Touched)**

```
ΔXS_gift = GF_base    (only if goodwill > 0.3)
```

| Symbol | Field Name | Default | Range | Description |
|--------|------------|---------|-------|-------------|
| `ΔXS_gift` | — | — | — | Charm contribution per endearing gift delivery |
| `GF_base` | `gift_base` | `0.03` | [0.01, 0.08] | Flat charm value per touched gift reaction |

**Example:** 4 gifts to a charmed NPC → `4 × 0.03 = 0.12` to `charm_subtotal`

**4.3.5 Gift Delivery (Horrified) — Chaos Path**

When the NPC is horrified by the gift (`goodwill <= 0.3`), the contribution goes to `chaos_subtotal` instead:

```
ΔCS_gift_horror = GH_base    (only if goodwill <= 0.3)
```

| Symbol | Field Name | Default | Range | Description |
|--------|------------|---------|-------|-------------|
| `ΔCS_gift_horror` | — | — | — | Chaos contribution per horrified gift reaction |
| `GH_base` | `gift_disgust_chaos` | `0.03` | [0.01, 0.08] | Flat chaos value per horrified gift reaction |

Multiple gifts stack. A player hoarding pests and dumping them on an uptight NPC earns chaos for each delivery.

**Example:** 5 roaches dumped on a low-goodwill NPC → `5 × 0.03 = 0.15` to `chaos_subtotal`

---

### 4.4 Feeding Threshold Evaluation

The threshold evaluated each frame is not a constant. It is modified by BONNIE's hunger context:

```
T_eff = F_thresh - (H_context × H_reduction)
```

| Symbol | Field Name | Default | Range | Description |
|--------|------------|---------|-------|-------------|
| `T_eff` | `effective_threshold` | — | [0.0, 1.0] | The threshold actually used for feeding evaluation this frame |
| `F_thresh` | `feeding_threshold` | `0.85` | (C_ceil, 1.0) | Base feeding threshold |
| `H_context` | `bonnie_hunger_context` | — | {0, 1} | Boolean flag from Pest / Survival System (15); 1 when BONNIE is hungry |
| `H_reduction` | `hunger_threshold_reduction` | `0.10` | [0.0, 0.20] | Amount by which hunger reduces the effective threshold |

**Evaluated states:**

| Hunger Context | T_eff | Formula |
|----------------|-------|---------|
| Not hungry | `0.85` | `0.85 - (0 × 0.10)` |
| Hungry | `0.75` | `0.85 - (1 × 0.10)` |

**Feeding trigger condition (both must be true):**

```
feeding_available = (M >= T_eff) AND (max(NPC.goodwill) > G_feed)
```

| Symbol | Field Name | Default | Description |
|--------|------------|---------|-------------|
| `M` | `meter_value` | — | Current meter value |
| `T_eff` | `effective_threshold` | — | From above |
| `G_feed` | `minimum_feeding_goodwill` | `0.3` | At least one NPC must exceed this value for feeding to fire |

The `feeding_threshold_reached` signal is emitted when `M >= T_eff`. The goodwill gate is enforced by Reactive NPC System (System 9) on receipt of that signal.

---

### 4.5 Charm-Required Proof

**Claim:** No assignment of chaos contributions alone can cause `meter_value` to reach `feeding_threshold`. Charm contributions are a mathematical necessity.

**Definitions:**

- "Pure chaos scenario": `charm_subtotal = 0` for all time; only chaos contributions are non-zero.
- `CS_pure`: the value of `chaos_subtotal` in a pure chaos scenario. This is a non-negative real number with no upper bound.
- `XS_pure = 0` by definition.

---

**Step 1 — Meter value under pure chaos.**

Substituting `XS = 0` into the core formula (§4.1):

```
M_pure = clamp( clamp(CS_pure, 0.0, C_ceil) + 0, 0.0, 1.0 )
       = clamp( clamp(CS_pure, 0.0, 0.65), 0.0, 1.0 )
       = clamp(CS_pure, 0.0, 0.65)          [outer clamp is redundant since 0.65 ≤ 1.0]
```

For all `CS_pure ≥ 0`:

```
M_pure ≤ 0.65
```

**Step 2 — Feeding threshold (not hungry).**

```
T_eff = 0.85    when H_context = 0
```

**Step 3 — Comparison (not hungry).**

```
M_pure ≤ 0.65 < 0.85 = T_eff
```

The condition `M >= T_eff` is never satisfied under pure chaos in the non-hungry case. QED (not hungry).

**Step 4 — Hungry case.**

```
T_eff = 0.75    when H_context = 1
M_pure ≤ 0.65 < 0.75 = T_eff
```

The gap narrows from 0.20 to 0.10, but the strict inequality holds. Pure chaos is still insufficient even with maximum hunger discount. QED (hungry).

**Step 5 — Minimum charm required.**

```
min_XS_required (not hungry) = F_thresh - C_ceil = 0.85 - 0.65 = 0.20
min_XS_required (hungry)     = T_eff    - C_ceil = 0.75 - 0.65 = 0.10
```

**Step 6 — Worst-case pure-chaos worked example.**

Suppose a player engineers the maximum observable chaos in a session:

- 20 objects displaced (light, W_mult = 1.0): `CS_obj = 20 × 0.02 = 0.40`
- 2 NPCs enter REACTING at base rate: `CS_react = 2 × 0.04 = 0.08`
- Full cascade chain fires (initiator + depth-1 + depth-2): `CS_cascade = 0.04 + 0.06 + 0.09 = 0.19`
- 3 environmental combos triggered: `CS_combo = 3 × 0.03 = 0.09`
- 5 pests caught: `CS_pest = 5 × 0.01 = 0.05`

Total:

```
CS_pure = 0.40 + 0.08 + 0.19 + 0.09 + 0.05 = 0.81
```

Meter value:

```
M_pure = clamp(0.81, 0.0, 0.65) = 0.65
```

The player has triggered every possible chaos event. `meter_value = 0.65`. Feeding threshold is `0.85`. The player is `0.20` short with `charm_subtotal = 0`.

**Minimum-effort charm paths to close the gap (from `charm_subtotal = 0`, not hungry):**

| Charm path | Interactions required | charm_subtotal gained |
|------------|----------------------|-----------------------|
| VULNERABLE comfort | 3 | `3 × 0.075 = 0.225` |
| Goodwill-boosted reactions (goodwill = 0.6) | 7 | `7 × 0.036 = 0.252` |
| Routine charm interactions | 14 | `14 × 0.015 = 0.210` |
| Gift deliveries | 7 | `7 × 0.030 = 0.210` |
| Mixed: 2 VULNERABLE + 4 routine | 6 | `0.150 + 0.060 = 0.210` |

The proof is robust: no combination of chaos-only contributions can satisfy `M >= T_eff`. The design constraint is mathematically enforced by the formula structure, not by game logic conditionals. A developer verifying this needs only confirm that `C_ceil < (F_thresh - H_reduction)` holds in the tuning data.

---

## 5. Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| `chaos_subtotal` exceeds `chaos_ceiling` | Subtotal accumulates normally; `meter_value` is clamped at `chaos_ceiling` during derivation. Excess chaos is inert. | Allows post-ceiling chaos play without feeling punished; clamping at derivation not accumulation avoids branching logic |
| `charm_subtotal` pushes `meter_value` above 1.0 | Final `meter_value` clamped to 1.0 | Hard ceiling on the meter |
| NPC enters REACTING twice in rapid succession (re-trigger during RECOVERING) | Each transition into REACTING fires a separate contribution. The meter does not deduplicate. | Hair-trigger re-reactions are a valid gameplay outcome the player engineered |
| Cascade chain where initiator NPC has high goodwill | Initiator contributes both `R_base` to chaos AND `goodwill * X_react` to charm. Chain members contribute only their cascade bonus to chaos (they inherit the chaos event, not the goodwill relationship). | Goodwill bonus is per-NPC, not per-chain. Only the NPC with the relationship earns the charm bonus. |
| All NPCs in CLOSED_OFF — no REACTING events possible | Chaos contributions from NPC reactions stop. Player must rely on object displacement, pest catches, and combos for remaining chaos. Charm contributions from NPCs are also blocked (CLOSED_OFF refuses interaction). | This is the penalty for pure chaos without recovery. The meter stalls. Player must wait for NPC timers. |
| Gift delivery to NPC at exactly goodwill = 0.3 | Horrified branch fires (≤ 0.3 threshold). `gift_disgust_chaos` added to `chaos_subtotal`. | Consistent boundary — "must exceed 0.3" for touched reaction |
| `bonnie_hunger_context` activates mid-session after meter is already above effective threshold | `feeding_threshold_reached` signal fires on the next frame where `M >= T_eff` is evaluated. No retroactive adjustment. | The hunger modifier is evaluated each frame, not on state change |
| `meter_value` reaches `feeding_threshold` but no NPC has `goodwill > minimum_feeding_goodwill` | Signal `feeding_threshold_reached` emits. NPC system receives it but does not trigger FED (goodwill gate fails). The meter stays at or above threshold. Player must charm an NPC above 0.3 to unlock feeding. | The meter and the goodwill gate are independent checks. Crossing the threshold alone is insufficient. |
| Environmental combo fires simultaneously with an NPC REACTING event | Both contributions apply independently to their respective categories. No interaction or suppression. | Systems are additive; events from different sources never cancel each other |
| Zero NPCs in the level (hypothetical edge case) | Chaos meter can only be filled via object displacement, pest catches, and combos. Charm contributions are impossible. `meter_value` caps at `chaos_ceiling`. Feeding is impossible. | This is correct — feeding requires NPCs. A level with zero NPCs is a sandbox without a win condition. |

---

## 6. Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| Reactive NPC System (9) | Chaos Meter reads from | Reads `current_behavior` transitions to detect REACTING events; reads `goodwill` for charm bonus evaluation; reads `bonnie_hunger_context` for threshold modifier |
| Bidirectional Social System (12) | Chaos Meter reads from | VULNERABLE comfort events generate charm contributions; goodwill values determine charm-boosted reaction eligibility |
| Environmental Chaos System (8) | Chaos Meter reads from | Reads `object_displaced` signals and `weight_class_multiplier` per object |
| Pest / Survival System (15) | Chaos Meter reads from | Reads pest catch events for `pest_catch_base` contributions; reads `bonnie_hunger_context` flag |
| Chaos Meter UI (23) | Depends on Chaos Meter | Reads `meter_value` each frame for display; listens for atmosphere signals |
| Audio Manager (3) | Depends on Chaos Meter (indirect) | Atmosphere signals (`chaos_meter_low/mid/high`) drive music layer transitions |
| Level Manager (5) | Depends on Chaos Meter (indirect) | `feeding_threshold_reached` enables level completion via FED state |
| Notoriety System (21) | Depends on Chaos Meter | Reads cumulative chaos/charm history for cross-level reputation (Vertical Slice scope) |
| Feeding Cutscene System (19) | Depends on Chaos Meter (indirect) | FED trigger originates from meter threshold; cutscene variant depends on which NPC feeds |

**Cross-reference obligations:**
- NPC Personality GDD (System 9) §3 must document that REACTING transitions emit a signal/event the Chaos Meter can subscribe to
- Social System GDD (System 12) must document that VULNERABLE comfort events are observable by the Chaos Meter
- Environmental Chaos System GDD (System 8) must document the `object_displaced` signal contract and `weight_class_multiplier` property

---

## 7. Tuning Knobs

### Meter Structure

| Parameter | Default | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|---------|------------|-------------------|-------------------|
| `chaos_ceiling` | 0.65 | [0.40, 0.80] | More meter reachable via pure chaos; charm less critical. At 0.80+: charm becomes trivially easy. | Less meter from chaos; charm becomes dominant path. At 0.40-: chaos feels unrewarding. |
| `feeding_threshold` | 0.85 | [0.70, 0.95] | Harder to reach feeding; longer sessions. At 0.95: frustrating grind. | Easier feeding; shorter sessions. At 0.70: too easy, no tension. |
| **CONSTRAINT**: `chaos_ceiling` must ALWAYS be less than `feeding_threshold - hunger_threshold_reduction`. If violated, the charm-required proof breaks and pure chaos can reach FED. | | | | |

### Chaos Sources

| Parameter | Default | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|---------|------------|-------------------|-------------------|
| `npc_reaction_base` | 0.04 | [0.01, 0.10] | NPC reactions matter more; fewer reactions needed. At 0.10: 7 reactions cap chaos. | NPC reactions feel insignificant. At 0.01: 65 reactions needed to cap chaos. |
| `cascade_multiplier` | 1.5 | [1.0, 3.0] | Cascades much more rewarding; Domino Rally becomes dominant strategy. At 3.0: single cascade = 0.40 chaos. | Cascades barely better than individual reactions. At 1.0: no cascade bonus at all. |
| `object_displacement_base` | 0.02 | [0.005, 0.05] | Object chaos more rewarding; environment destruction viable strategy. | Objects feel irrelevant to meter. |
| `pest_catch_base` | 0.01 | [0.005, 0.03] | Pest hunting becomes a real strategy. | Pest catching is purely cosmetic. |
| `combo_bonus` | 0.03 | [0.01, 0.08] | Environmental chain reactions rewarded more. | Combos feel like noise. |
| `combo_window` | 2.0s | [0.5, 5.0] s | Easier to trigger combos; more forgiving timing. | Combos require rapid, precise displacement chains. |
| `gift_disgust_chaos` | 0.03 | [0.01, 0.08] | Pest-dumping on uptight NPCs becomes a viable chaos strategy. | Horror gifts contribute negligibly. |

### Charm Sources

| Parameter | Default | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|---------|------------|-------------------|-------------------|
| `goodwill_bonus_threshold` | 0.4 | [0.1, 0.8] | More goodwill needed before charm bonus fires; rewards deeper investment. | Even low goodwill earns charm bonus; less differentiation between social playstyles. |
| `charm_reaction_bonus` | 0.06 | [0.02, 0.15] | High-goodwill reactions are very rewarding; social investment pays off strongly. | Goodwill bonus is marginal; less incentive to charm before causing chaos. |
| `vulnerable_comfort_base` | 0.05 | [0.02, 0.12] | VULNERABLE comfort is extremely potent; 2 interactions might close the gap. | VULNERABLE comfort feels weak; more routine charm needed. |
| `routine_charm_base` | 0.015 | [0.005, 0.04] | Casual social play contributes meaningfully; fewer interactions needed. | Routine charm is negligible; forces VULNERABLE exploitation. |
| `gift_base` | 0.03 | [0.01, 0.08] | Gift delivery is a strong charm verb. | Gifts are cosmetic comedy only. |

### Feeding

| Parameter | Default | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|---------|------------|-------------------|-------------------|
| `minimum_feeding_goodwill` | 0.3 | [0.1, 0.6] | Requires deeper NPC relationship for feeding; at 0.6: only well-charmed NPCs feed. | Almost any NPC will feed once threshold is met; at 0.1: brief contact suffices. |
| `hunger_threshold_reduction` | 0.10 | [0.0, 0.20] | Hunger makes feeding much easier; at 0.20: threshold drops to 0.65 (equals chaos_ceiling — BREAKS charm requirement). | Hunger has minimal effect. At 0.0: hunger context is cosmetic. |
| **CONSTRAINT**: `hunger_threshold_reduction` must be less than `feeding_threshold - chaos_ceiling`. At defaults: `0.10 < 0.20`. If violated, a hungry BONNIE can reach FED via pure chaos. | | | | |

### Atmosphere Signals

| Parameter | Default | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|---------|------------|-------------------|-------------------|
| `chaos_meter_low_threshold` | 0.25 | [0.10, 0.40] | Atmosphere shift occurs later in session. | Earlier atmosphere shift; tension rises sooner. |
| `chaos_meter_mid_threshold` | 0.50 | [0.30, 0.65] | Midpoint signal fires later. | Earlier midpoint; faster tension ramp. |
| `chaos_meter_high_threshold` | 0.75 | [0.60, 0.85] | Near-peak atmosphere delayed. | Earlier peak atmosphere; more time at high tension. |

---

## 8. Acceptance Criteria

**AC-CM01: Chaos ceiling enforced**
- [ ] Player causes maximum chaos (all objects, all NPC reactions, all cascades) with zero charm interactions → `meter_value` never exceeds `chaos_ceiling` (0.65 at defaults)
- [ ] `feeding_threshold_reached` signal does NOT fire under pure chaos conditions

**AC-CM02: Charm bridges the gap**
- [ ] Player reaches `chaos_ceiling` via chaos, then performs 3 VULNERABLE comfort interactions → `meter_value` exceeds `feeding_threshold` (0.85)
- [ ] `feeding_threshold_reached` signal fires after sufficient charm contributions

**AC-CM03: Feeding requires goodwill gate**
- [ ] `meter_value >= feeding_threshold` with no NPC having `goodwill > minimum_feeding_goodwill` → FED state does NOT trigger
- [ ] Same meter value with one NPC at `goodwill = 0.5` → FED state triggers (NPC system handles)

**AC-CM04: Cascade multiplier applies correctly**
- [ ] NPC A enters REACTING → chaos_subtotal increases by `npc_reaction_base` (0.04)
- [ ] NPC A triggers NPC B (depth-1) → B's contribution is `npc_reaction_base * cascade_multiplier` (0.06)
- [ ] NPC B triggers NPC C (depth-2) → C's contribution is `npc_reaction_base * cascade_multiplier^2` (0.09)

**AC-CM05: Gift delivery branches correctly**
- [ ] Gift to NPC with `goodwill > 0.3` → `gift_base` (0.03) added to `charm_subtotal`
- [ ] Gift to NPC with `goodwill <= 0.3` → `gift_disgust_chaos` (0.03) added to `chaos_subtotal`
- [ ] Multiple gifts stack: 5 horror gifts = 5 × 0.03 = 0.15 to chaos_subtotal

**AC-CM06: Hunger context modifier**
- [ ] Without `bonnie_hunger_context`: effective threshold = 0.85
- [ ] With `bonnie_hunger_context`: effective threshold = 0.75
- [ ] Threshold change applies on the frame hunger context activates, not retroactively

**AC-CM07: Atmosphere signals fire at correct thresholds**
- [ ] `chaos_meter_low` fires once when `meter_value` crosses 0.25 upward
- [ ] `chaos_meter_mid` fires once at 0.50
- [ ] `chaos_meter_high` fires once at 0.75
- [ ] `feeding_threshold_reached` fires once at effective threshold
- [ ] None of these signals re-fire if meter remains at or above their threshold

**AC-CM08: Meter does not decay**
- [ ] `meter_value` never decreases over time with no player input
- [ ] Player can leave the game idle for 5 minutes → `meter_value` unchanged

**AC-CM09: Environmental combo detection**
- [ ] 2 object displacements within `combo_window` → no combo fires
- [ ] 3 object displacements within `combo_window` → exactly 1 combo bonus (0.03)
- [ ] 6 object displacements in rapid succession → multiple combos fire correctly

**AC-CM10: Performance**
- [ ] Meter derivation (`meter_value` calculation) completes within 0.1ms per frame
- [ ] Signal emission does not cause frame drops

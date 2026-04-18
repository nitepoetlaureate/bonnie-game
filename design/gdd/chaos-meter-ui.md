# Chaos Meter UI

> **Status**: Approved
> **System**: #23 — Chaos Meter UI
> **Priority**: MVP
> **Authors**: Studio Director (Session 008)
> **Created**: 2026-04-17
> **Depends On**: Chaos Meter (13), Viewport / Rendering Config (2)
> **Downstream**: HUD / Game UI (24)

---

## 1. Overview

The Chaos Meter UI is the visual representation of `meter_value` — the single progress indicator that gates BONNIE's feeding payoff. It is a read-only display that pulls `meter_value` from the Chaos Meter system (System 13) each frame and renders it within the 720x540 viewport.

The meter must communicate three things at a glance: (1) how full the meter is, (2) whether recent contributions came from chaos or charm, and (3) when the feeding threshold is within reach. It must do all of this without creating HP-bar anxiety. The meter is a progress indicator — closer to a Katamari size gauge than a health bar. Getting fuller is always good. There is no fail state.

The visual design philosophy is **environmental integration over HUD overlay**. The meter should feel like part of BONNIE's world, not a clinical game UI element stapled to the corner of the screen. The pixel art aesthetic (720x540, nearest-neighbor, no blur) constrains the design to crisp, readable elements at low resolution.

---

## 2. Player Fantasy

The meter should make the player feel like they're building toward something delicious.

The emotional arc of watching the meter fill mirrors BONNIE's arc in each level: start empty, cause chaos, hit a wall, figure out the charm angle, push through to feeding. The meter is the player's companion through this arc — it should celebrate momentum, acknowledge the chaos ceiling stall without punishing it, and crescendo as charm contributions push past the threshold.

The player who glances at the meter mid-chaos-spree should feel satisfaction: "look at all that mayhem I caused." The player who hits the ceiling and sees the meter stall should feel challenged, not frustrated: "okay, I need to try something different." The player who watches charm contributions push past the ceiling into feeding range should feel the warmth of earned progress.

The meter should never create anxiety. It does not tick down. It does not flash red. It does not count down. It fills up, and filling up is always progress. The worst that happens is it stops filling — and even then, it waits patiently for the player to figure out the charm path.

---

## 3. Detailed Rules

### 3.1 Display Architecture

The Chaos Meter UI is a CanvasLayer node at layer index `10` (above game world, below any modal UI). It renders within the 720x540 viewport coordinate space. All positions and sizes are in viewport pixels (not world-space pixels) — the UI does not scroll with the camera.

The UI node reads the following values from the Chaos Meter system each frame:

| Property | Type | Source | Usage |
|----------|------|--------|-------|
| `meter_value` | float [0.0, 1.0] | ChaosManager.meter_value | Current fill level |
| `chaos_subtotal` | float [0.0, +inf) | ChaosManager.chaos_subtotal | Chaos contribution total |
| `charm_subtotal` | float [0.0, +inf) | ChaosManager.charm_subtotal | Charm contribution total |
| `chaos_ceiling` | float | ChaosManager.chaos_ceiling | Where chaos stalls |
| `feeding_threshold` | float | ChaosManager.feeding_threshold | Static feeding threshold (0.85 at defaults) |
| `effective_threshold` | float | ChaosManager.effective_threshold | Actual threshold after hunger reduction (may be lower than `feeding_threshold` when `bonnie_hunger_context` is active) |

The UI **never writes** to the Chaos Meter system. It is strictly a display.

**Hunger context**: When `bonnie_hunger_context` is active, `effective_threshold` drops below `feeding_threshold` (e.g., `0.85 - 0.10 = 0.75`). The UI reads `effective_threshold` for the feeding threshold marker position, ensuring the gold marker moves down when hunger makes feeding easier. This gives the player visual feedback that the goal has shifted.

### 3.2 Meter Visual Design

The meter is a **vertical fill gauge** positioned in the bottom-right corner of the viewport. Vertical orientation reinforces the "filling up" metaphor — progress goes up, toward the food.

**Dimensions** (in viewport pixels):
- Width: 12px (narrow — should not dominate the screen)
- Height: 80px (enough for readable fill resolution at 720x540)
- Position: anchored to bottom-right corner, inset 8px from right edge and 8px from bottom edge
- Corner position: `(700, 452)` top-left of the meter frame → `(712, 532)` bottom-right

**Frame**: A 1px border in a muted color (dark grey, `Color(0.25, 0.25, 0.25, 0.8)`) surrounds the fill area. The frame is always visible, even when the meter is empty.

**Fill**: The interior of the meter fills from bottom to top as `meter_value` increases.

### 3.3 Dual-Axis Color Coding

The fill uses two colors to distinguish chaos and charm contributions:

| Contribution | Fill Color | Hex | Rationale |
|-------------|-----------|-----|-----------|
| Chaos | Warm orange | `#E06020` / `Color(0.88, 0.38, 0.13, 1.0)` | Energetic, mischievous — matches BONNIE's placeholder sprite color. Chaos is fun, not evil. |
| Charm | Soft teal | `#40B0A0` / `Color(0.25, 0.69, 0.63, 1.0)` | Calm, warm-cool contrast against orange. Legible against dark backgrounds. Not clinical blue. |

**How the two colors are rendered:**

The fill area is divided into two stacked regions within the gauge:

1. **Chaos region** (bottom): height proportional to `min(chaos_subtotal, chaos_ceiling)` / 1.0 * gauge_height. This is the orange portion. It fills from the bottom and stops at the chaos ceiling mark.

2. **Charm region** (top, stacked above chaos): height proportional to `charm_subtotal` / 1.0 * gauge_height. This is the teal portion. It sits directly on top of the chaos fill. The charm region height is individually clamped to `gauge_height - chaos_fill_height` to prevent overflow — this ensures the two regions never exceed the gauge bounds, even if `charm_subtotal` exceeds `1.0 - chaos_ceiling` (which is possible since `charm_subtotal` is uncapped in System 13).

The total fill height equals `meter_value * gauge_height` (since `meter_value = clamped_chaos + charm`, itself clamped to 1.0). The two colors show the player where their progress came from.

### 3.4 Threshold Markers

Two horizontal tick marks are rendered on the meter frame to indicate key thresholds:

**Chaos ceiling marker** (at `chaos_ceiling`, default 0.65):
- A 2px horizontal line extending 3px to the left of the meter frame
- Color: same muted grey as the frame, `Color(0.25, 0.25, 0.25, 0.8)`
- This marker is subtle — it indicates where the chaos fill will stall but should not dominate the visual. The player discovers the ceiling through gameplay, not through a prominent UI marker.

**Feeding threshold marker** (at `effective_threshold`, default 0.85, drops to 0.75 when hungry):
- A 2px horizontal line extending 3px to the left of the meter frame
- Color: warm gold, `Color(0.85, 0.75, 0.30, 0.9)` — visually distinct from both chaos orange and charm teal
- This marker is more prominent than the ceiling marker. It is the player's goal.
- When `bonnie_hunger_context` becomes active, the marker smoothly moves down to the new `effective_threshold` position over 12 frames (0.2s). This communicates "the goal just got closer" without jarring the player.

### 3.5 Contribution Flash

When the meter receives a contribution (chaos or charm), the newly added fill region briefly flashes white (`Color(1.0, 1.0, 1.0, 0.6)`) for 6 frames (0.1 seconds at 60fps), then fades to the appropriate color over 6 more frames. This gives every contribution visible feedback without being distracting.

**Flash behavior:**
- Multiple contributions within the flash window extend the flash duration (additive, capped at 18 frames / 0.3s)
- The flash color is always white regardless of whether the contribution was chaos or charm — the distinction is shown by the final fill color after the flash fades
- Flash is purely cosmetic; it does not affect `meter_value`

### 3.6 Feeding-Ready State

When `meter_value >= effective_threshold`, the meter enters the **feeding-ready** visual state:

- The feeding threshold marker changes from gold to pulsing gold-white (alternates between `Color(0.85, 0.75, 0.30, 1.0)` and `Color(1.0, 0.95, 0.70, 1.0)`) on a 30-frame (0.5s) cycle
- The entire fill area gains a subtle 1px bright outline on the fill edge (top of the fill), color matching the charm teal
- No screen shake, no alarm, no urgency — the meter communicates "you're ready" without pressure

This state persists as long as `meter_value >= effective_threshold`. Since the meter does not decay, once feeding-ready is reached it stays until the FED transition fires.

### 3.7 Atmosphere Signal Response

The Chaos Meter emits atmosphere signals at 0.25, 0.50, and 0.75. The UI does not directly listen for these signals (they are for the Audio Manager and environmental systems), but the fill level naturally reflects these milestones. No special UI treatment is applied at atmosphere thresholds — the meter's visual communication is continuous, not stepped.

### 3.8 Empty and Full States

**Empty** (`meter_value = 0.0`): The frame is visible with no fill. The threshold markers are visible. The meter is present but empty — communicating "there's something to fill here."

**Full** (`meter_value = 1.0`): The fill reaches the top of the gauge. Both chaos and charm regions are at their maximum visual representation. The feeding-ready pulse continues. The meter communicates "you've done everything possible."

### 3.9 Visibility

The meter is always visible during gameplay. It is hidden during:
- The feeding cutscene (FED transition, System 19)
- Any full-screen modal (pause menu, if implemented)
- Level transition sequences (Level Manager, System 5)

Visibility is toggled via `visible` property on the CanvasLayer node. No fade-in/fade-out animation — the pixel art aesthetic favors crisp state changes.

---

## 4. Formulas

### 4.1 Fill Height Calculation

```
chaos_fill_height = floor(min(chaos_subtotal, chaos_ceiling) * gauge_height)
charm_fill_height = min(floor(charm_subtotal * gauge_height), gauge_height - chaos_fill_height)
total_fill_height = chaos_fill_height + charm_fill_height
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `chaos_subtotal` | float | [0.0, +inf) | ChaosManager | Raw chaos accumulation |
| `charm_subtotal` | float | [0.0, +inf) | ChaosManager | Raw charm accumulation |
| `chaos_ceiling` | float | [0.0, 1.0] | ChaosManager | Ceiling cap for chaos |
| `gauge_height` | int | 78 | UI constant | Interior fill height (80px frame - 2px border) |

`floor()` is used to prevent sub-pixel rendering artifacts at nearest-neighbor scale. Every fill height is an integer pixel count.

**Example calculation** (defaults):
- `chaos_subtotal = 0.55`, `charm_subtotal = 0.08`, `chaos_ceiling = 0.65`
- `chaos_fill_height = floor(min(0.55, 0.65) * 78) = floor(0.55 * 78) = floor(42.9) = 42`
- `charm_fill_height = floor(0.08 * 78) = floor(6.24) = 6`
- `total_fill_height = min(42 + 6, 78) = 48`
- Visual: 42px orange from bottom, 6px teal on top, 30px empty above.

### 4.2 Threshold Marker Position

```
marker_y = gauge_top + floor((1.0 - threshold_value) * gauge_height)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `gauge_top` | int | 453 | UI constant | Top y-coordinate of fill area interior |
| `threshold_value` | float | [0.0, 1.0] | ChaosManager | Either `chaos_ceiling` or `effective_threshold` |
| `gauge_height` | int | 78 | UI constant | Interior fill height |

**Example** (chaos ceiling at 0.65):
- `marker_y = 453 + floor((1.0 - 0.65) * 78) = 453 + floor(27.3) = 453 + 27 = 480`

**Example** (effective threshold at 0.85, no hunger):
- `marker_y = 453 + floor((1.0 - 0.85) * 78) = 453 + floor(11.7) = 453 + 11 = 464`

**Example** (effective threshold at 0.75, hunger active):
- `marker_y = 453 + floor((1.0 - 0.75) * 78) = 453 + floor(19.5) = 453 + 19 = 472`

### 4.3 Flash Timing

```
flash_remaining = min(flash_remaining + FLASH_DURATION, MAX_FLASH_DURATION)
```

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `FLASH_DURATION` | int | 6 frames | Duration added per contribution |
| `MAX_FLASH_DURATION` | int | 18 frames | Maximum flash time (0.3s) |
| `FLASH_FADE_FRAMES` | int | 6 frames | Frames to lerp from white to fill color |

Each frame while `flash_remaining > 0`:
- If `flash_remaining > FLASH_FADE_FRAMES`: render flash region as white overlay
- If `flash_remaining <= FLASH_FADE_FRAMES`: lerp alpha from `0.6` to `0.0` over remaining frames
- Decrement `flash_remaining` by 1

### 4.4 Feeding-Ready Pulse

```
pulse_t = (Engine.get_frames_drawn() % PULSE_PERIOD) / float(PULSE_PERIOD)
pulse_color = gold_base.lerp(gold_bright, sin(pulse_t * TAU) * 0.5 + 0.5)
```

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `PULSE_PERIOD` | int | 30 frames | Full pulse cycle (0.5s at 60fps) |
| `gold_base` | Color | `Color(0.85, 0.75, 0.30, 1.0)` | Resting gold |
| `gold_bright` | Color | `Color(1.0, 0.95, 0.70, 1.0)` | Peak pulse brightness |

---

## 5. Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| `meter_value` is exactly 0.0 | Empty frame visible, no fill, threshold markers visible | Player should see the meter exists and know it's empty |
| `meter_value` is exactly 1.0 | Full fill, feeding-ready pulse active | Maximum progress state |
| `chaos_subtotal` exceeds `chaos_ceiling` | Orange fill stops at ceiling marker height; no visual overflow | Matches System 13 behavior — excess chaos is inert |
| `charm_subtotal` is 0.0 but `chaos_subtotal` > 0 | Only orange fill visible; no teal region | Pure chaos gameplay — common early in a session |
| `chaos_subtotal` is 0.0 but `charm_subtotal` > 0 | Only teal fill visible; no orange region | Unusual but valid — pure charm approach |
| Both subtotals are 0.0 | Empty meter (same as meter_value 0.0) | Session start state |
| Very small contribution (< 1px of fill) | Fill does not visually change until enough accumulates for 1px | `floor()` prevents sub-pixel artifacts; contributions are not lost in the data model |
| Multiple rapid contributions in same frame | Single flash trigger; fill updates atomically | UI reads `meter_value` once per frame; doesn't track individual events |
| Meter positioned at screen edge during viewport resize | Anchor to bottom-right maintains position within 720x540 viewport | Viewport stretch mode handles upscaling; UI coordinates are always viewport-relative |
| Feeding cutscene begins while flash is active | Meter hidden immediately; flash state reset | Clean transition to cutscene; no lingering UI artifacts |
| `feeding_threshold` changed via tuning while meter is above old threshold | Pulse state re-evaluated against new threshold | Threshold markers update dynamically; feeding-ready state is rechecked each frame |

---

## 6. Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| Chaos Meter (13) | This depends on Chaos Meter | Reads `meter_value`, `chaos_subtotal`, `charm_subtotal`, `chaos_ceiling`, `feeding_threshold` each frame |
| Viewport / Rendering Config (2) | This depends on Viewport Config | All UI coordinates are within 720x540 viewport space; nearest-neighbor rendering applies to UI sprites |
| Audio Manager (3) | Independent (parallel) | Atmosphere signals are consumed by Audio Manager, not UI — but the visual fill level corresponds to the same thresholds |
| Level Manager (5) | Level Manager triggers UI hide | Meter hidden during level transitions; Level Manager signals transition start/end |
| Feeding Cutscene System (19) | Cutscene triggers UI hide | Meter hidden during FED cutscene |
| HUD / Game UI (24) | Depends on this system | Full Vision HUD integrates the chaos meter display into a broader UI framework; this system provides the standalone MVP implementation |

**Bidirectional notes:**
- Chaos Meter (13) lists this system as a downstream dependent in its §6 Dependencies table.
- Viewport Config (2) lists "All UI systems (23, 24)" as dependents in its §6 Dependencies section.

---

## 7. Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `gauge_width` | 12px | [8, 20] px | More prominent on screen; easier to read fill colors. At 20: starts to obstruct gameplay view. | Less screen presence; harder to distinguish chaos/charm colors at small widths. At 8: minimum readable size at 720x540. |
| `gauge_height` | 80px | [60, 120] px | Better fill resolution; more precise visual feedback. At 120: takes significant vertical screen space. | Coarser fill resolution; harder to see small contributions. At 60: minimum for two threshold markers to be visually distinct. |
| `gauge_inset_right` | 8px | [4, 16] px | Further from screen edge; more integrated with game view. | Closer to edge; more HUD-like. At 4: minimum breathing room from viewport border. |
| `gauge_inset_bottom` | 8px | [4, 16] px | Higher on screen. | Lower; closer to viewport floor. |
| `chaos_color` | `Color(0.88, 0.38, 0.13, 1.0)` | warm hues | — | Must contrast with charm color and dark backgrounds. Avoid red (HP connotation). |
| `charm_color` | `Color(0.25, 0.69, 0.63, 1.0)` | cool hues | — | Must contrast with chaos color. Avoid clinical blue (mana connotation). |
| `frame_color` | `Color(0.25, 0.25, 0.25, 0.8)` | [0.15, 0.40] grey | More visible frame. | More subtle frame; blends with dark backgrounds. |
| `flash_duration` | 6 frames | [3, 12] frames | Longer flash per contribution; more visible feedback. At 12: flash dominates the meter visual. | Briefer flash; subtler feedback. At 3: barely perceptible. |
| `max_flash_duration` | 18 frames | [12, 30] frames | Rapid contributions create longer sustained flash. | Flash resolves faster during chaos chains. |
| `flash_fade_frames` | 6 frames | [3, 12] frames | Slower fade; flash lingers. | Snappier transition from flash to fill color. |
| `pulse_period` | 30 frames | [20, 60] frames | Slower, more relaxed feeding-ready pulse. At 60: lazy, ambient throb. | Faster pulse; more urgent feeling. At 20: noticeably quick. Avoid < 20 (epilepsy risk at low period values). |
| `canvas_layer_index` | 10 | [5, 15] | Renders above more game elements. | Renders below more overlays. Must stay above game world CanvasLayer. |

**CONSTRAINT**: `chaos_color` and `charm_color` must pass WCAG AA contrast ratio (4.5:1) against a black background (`Color(0, 0, 0, 1)`) to ensure readability during dark scenes. Current values: orange on black = ~5.2:1, teal on black = ~7.1:1 — both pass.

---

## 8. Acceptance Criteria

**AC-UI01: Meter is always visible during gameplay**
- [ ] Meter frame renders at bottom-right of viewport from session start
- [ ] Meter remains visible during all gameplay states (traversal, NPC interaction, chaos events)
- [ ] Meter is hidden during feeding cutscene and level transitions

**AC-UI02: Fill reflects meter_value accurately**
- [ ] `meter_value = 0.0` → empty meter (no fill, frame visible)
- [ ] `meter_value = 0.5` → fill reaches approximately halfway up the gauge
- [ ] `meter_value = 1.0` → fill reaches the top of the gauge
- [ ] Fill height updates within 1 frame of `meter_value` changing

**AC-UI03: Dual-axis colors are visually distinct**
- [ ] Chaos contributions render in orange; charm contributions render in teal
- [ ] A player can distinguish chaos fill from charm fill at a glance (5-second legibility test)
- [ ] Both colors are readable against dark backgrounds (WCAG AA contrast)

**AC-UI04: Chaos ceiling stall is perceptible**
- [ ] When `chaos_subtotal >= chaos_ceiling`, orange fill stops growing even as chaos events continue
- [ ] The chaos ceiling marker is visible on the meter frame
- [ ] Player notices the stall within 2-3 additional chaos events after ceiling is reached

**AC-UI05: Feeding threshold marker is visible and meaningful**
- [ ] Gold threshold marker is visible on the meter frame at the feeding threshold position
- [ ] Threshold marker is visually distinct from the chaos ceiling marker
- [ ] A new player can identify "that gold line is the goal" within their first session

**AC-UI06: Contribution flash provides feedback**
- [ ] Each chaos contribution triggers a visible white flash on the added fill region
- [ ] Each charm contribution triggers a visible white flash on the added fill region
- [ ] Rapid contributions extend flash duration (capped at max_flash_duration)
- [ ] Flash fades smoothly to the appropriate fill color

**AC-UI07: Feeding-ready state is clearly communicated**
- [ ] When `meter_value >= feeding_threshold`, the threshold marker begins pulsing gold-white
- [ ] The pulse is noticeable but not urgent or anxiety-inducing
- [ ] The feeding-ready state persists as long as meter is at or above threshold

**AC-UI08: No HP-bar anxiety**
- [ ] The meter never flashes red, uses warning colors, or creates urgency
- [ ] The meter never decreases (no decay visualization needed)
- [ ] Playtest: 3/3 testers describe the meter as "progress" not "health" when asked

**AC-UI09: Performance budget met**
- [ ] Meter rendering completes within 0.5ms per frame (including flash and pulse effects)
- [ ] No texture allocations during gameplay (all sprites pre-loaded)
- [ ] CanvasLayer does not trigger additional draw calls beyond 2 (frame + fill)

**AC-UI10: Viewport compliance**
- [ ] Meter renders at correct position across all window sizes (1x through 4x scale)
- [ ] Nearest-neighbor filtering applies to meter sprites — no blur at any scale
- [ ] Meter does not overflow viewport boundaries at any supported resolution

---

*GDD authored Session 008. Last MVP GDD before GATE 2.*

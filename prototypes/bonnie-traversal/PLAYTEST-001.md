# Playtest Report

## Session Info
- **Date**: 2026-04-13
- **Build**: 870eb07 (Session 004 — playtest blockers fixed)
- **Duration**: ~10–15 min (exploratory)
- **Tester**: m. raftery (developer/creative director)
- **Platform**: macOS / Godot 4.6 editor
- **Input Method**: Keyboard
- **Session Type**: First playtest of traversal prototype

## Test Focus
Full traversal vocabulary: all 13 movement states, ledge parry, climbing, sliding, object interaction, squeezing. GATE 1 evaluation against 12 acceptance criteria.

## First Impressions
- **Understood the goal?** Partially — test zones exist but without labels or a debug HUD, the tester couldn't tell what each zone was testing
- **Understood the controls?** Partially — basic movement worked, but advanced mechanics (slide trigger, parry timing, sneak entry, climbing) were unclear without feedback
- **Emotional response**: Frustrated — multiple mechanics felt broken or invisible
- **Notes**: The core problem is **zero state feedback**. With a colored rectangle and no debug display, the tester cannot distinguish which state BONNIE is in, what input triggered a transition, or why a failure occurred.

## Gameplay Flow

### What worked
- Basic movement (walking with directional input)
- Jumping (basic hop/hold distinction appears functional)
- BONNIE visible (warm orange — Session 004 fix confirmed working)

### Pain points
- **Climbing not entering from ground approach** — Severity: HIGH
- **Parry unreliable** — works sometimes, no feedback on why it fails — Severity: HIGH
- **Repeated daze/stun during jumps** — feels like punishment, not physics — Severity: HIGH
- **Walk vs run indistinguishable** without animation/sound — Severity: MEDIUM
- **Kaneda slide undiscoverable** without speed feedback — Severity: MEDIUM
- **No controller support verified** — Severity: MEDIUM

### Confusion points
- How to enter SNEAKING state (sneak button? analog stick? auto?)
- How to enter SQUEEZING state (auto-trigger not firing)
- How to initiate climbing from the ground (expected grab against surface)
- How to trigger Kaneda slide (speed threshold not visible)
- Why coyote time doesn't seem to help (5 frames = 83ms — possibly too tight)

### Moments of delight
- None reported — frustration dominated this session due to missing feedback

## Bugs Found

| # | Description | Severity | Reproducible | Root Cause |
|---|-------------|----------|-------------|------------|
| B01 | No ground-based CLIMBING entry | Critical | Yes | `_handle_running()` and `_handle_sliding()` have no CLIMBING transition. GDD says RUNNING exits to CLIMBING on climbable surface approach, but code only enters CLIMBING via `_check_ledge_parry()` (airborne + grab). | 
| B02 | SQUEEZING state unreachable | Critical | Yes | No state handler transitions INTO SQUEEZING. The handler exists but nothing calls `_change_state(State.SQUEEZING)`. GDD says auto-trigger on entering low-ceiling space. |
| B03 | `parry_window_frames` export unused | Major | Yes | `_check_ledge_parry()` checks proximity only (is ParryCast colliding?), not temporal window around ledge-plane crossing. The `parry_window_frames = 6` tuning knob exists but has no effect on behavior. |
| B04 | ShapeCast2D circle detects wrong directions | Major | Intermittent | Circle shape has no directional bias — detects floor below, ceiling above, and walls to sides equally. Parry fires on irrelevant geometry. Known Issue #5. |
| B05 | Object collision force not implemented | Minor | Yes | RigidBody2D objects in Zone 9 don't respond to CharacterBody2D contact. No `slide_collision_force` code exists. Depends on Interactive Object System (System #7, not designed yet). |
| B06 | `hop_velocity` used for all grounded jumps | Minor | Yes | IDLE, SNEAKING, WALKING, RUNNING all launch with `hop_velocity` (280). GDD implies running jumps should use `jump_velocity` (480) for full arc. Jump hold force compensates but initial launch is always a hop. |

## Feature-Specific Feedback

### Climbing (CRITICAL)
- **Understood purpose?** Yes — user expected to press against wall + grab
- **Working?** No — only accessible via airborne parry, not ground approach
- **Root cause**: Missing transition in `_handle_running()` and `_handle_walking()`

### Ledge Parry
- **Understood purpose?** Yes — user knows the mechanic
- **Working?** Intermittently
- **Root cause**: Proximity-only check (no temporal window), circle ShapeCast2D fires on wrong geometry
- **User quote**: "works the way it should SOME of the time"

### Kaneda Slide
- **Understood purpose?** Conceptually yes, but couldn't discover how to trigger it
- **Working?** Code appears correct (opposing input at >300px/s), but without speed feedback, user can't tell when they've crossed the threshold
- **Suggestion**: Debug HUD showing speed + state would make this testable

### Sneaking / Squeezing
- **Understood purpose?** Partially
- **Working?** Sneaking: probably (Left Ctrl), but user unsure. Squeezing: completely broken (no entry transition)

## Quantitative Data
Not available — no debug HUD, no telemetry. This is the core problem.

## Acceptance Criteria Evaluation (GATE 1)

| AC | Description | Status | Notes |
|----|------------|--------|-------|
| AC-T01 | Input responsiveness | UNTESTABLE | No state feedback to verify frame accuracy |
| AC-T02 | Sneak → sprint transition | FAIL | Walk/run difference not perceivable without feedback |
| AC-T03 | Kaneda slide | FAIL | Undiscoverable. Object collision unimplemented. |
| AC-T04 | Jump feel | PARTIAL | Basic jump works. "Dazed mid-jump" issue unclear. |
| AC-T05 | Landing skid | UNTESTABLE | Can't distinguish skid from normal deceleration visually |
| AC-T06 | Rough landing | UNTESTABLE | Can't distinguish ROUGH_LANDING from DAZED visually |
| AC-T06b | Run button model | FAIL | User couldn't tell running from walking |
| AC-T06c | Ledge parry | FAIL | Intermittent. parry_window_frames unused. ShapeCast2D issues. |
| AC-T06d | Double jump + parry combo | FAIL | Parry unreliable, combo not completable |
| AC-T06e | Wall jump on climbable | FAIL | Can't enter CLIMBING from ground. No ground approach. |
| AC-T07 | Stealth mechanics | FAIL | SQUEEZING unreachable. Sneaking unclear. |
| AC-T08 | Camera leads movement | N/A | Camera system not prototyped yet |

**Result: 0/11 testable ACs pass. 4/11 FAIL on implementation bugs. 5/11 UNTESTABLE without debug feedback. 2/11 PARTIAL or N/A.**

## GATE 1 Verdict: NEEDS WORK

The prototype is **not ready for feel-tuning** because two separate problems block it:

### Problem 1: Missing State Transitions (Code Bugs)
Three states are unreachable or broken:
- CLIMBING has no ground-based entry (B01)
- SQUEEZING has no entry at all (B02)
- Ledge parry temporal window not implemented (B03)

### Problem 2: No Feedback Layer (Tooling Gap)
Without a debug HUD, the tester cannot:
- See which state BONNIE is in
- See current velocity (can't tell walk from run, can't tell when slide triggers)
- See timer states (coyote countdown, parry window, jump buffer)
- Understand why a failure occurred (was it timing? distance? wrong state?)

The user's suggestion — **on-screen debug display** — is exactly right. This should have been part of the prototype from Session 003.

## Top 3 Priorities

1. **Add debug HUD** — Current state, velocity, active timers (coyote, buffer, parry), facing direction. Without this, playtesting is guesswork.
2. **Fix B01 + B02** — Ground-based CLIMBING entry + SQUEEZING auto-trigger. Two whole movement states are broken.
3. **Fix B03 + B04** — Implement temporal parry window + replace circle ShapeCast2D with directional raycasts. Parry is the signature mechanic and it needs to work.

## Tester Requests
- Debug HUD showing state + failure reasons
- Controller support verification (gamepad bindings exist in project.godot but untested)
- Clearer visual distinction between states (even just color-coded rectangles per state)

---

*Report generated Session 005. Next playtest after fixes applied.*

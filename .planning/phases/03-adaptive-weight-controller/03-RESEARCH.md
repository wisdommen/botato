# Phase 3: Adaptive Weight Controller - Research

**Researched:** 2026-04-13
**Domain:** GDScript EMA controller, Godot 3.5 node lifecycle, dynamic weight adaptation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Track `damage_rate` by polling `player.current_stats.health` delta between frames divided by delta time. Track `health_ratio` as `player.current_stats.health / player.max_stats.health`. Both properties are already accessed per-frame in `_build_context()`.
- **D-02:** Use polling-based health tracking exclusively — no damage event signals exist in the mod codebase.
- **D-03:** Detect wave boundaries by polling `$"/root/Main"._wave_timer.time_left` each frame — when the value transitions from near-zero (< 0.05) back to a high value, a new wave has started.
- **D-04:** Use polling over Timer.timeout signal connection — polling is the established mod pattern, signal reliability during Brotato's wave transitions is unverified for modded code.
- **D-05:** AdaptiveWeightController is a standalone GDScript file (not a Script Extension) instantiated as a child Node of `AutobattlerOptions`. It has its own `_process(delta)` for per-frame EMA updates.
- **D-06:** Instantiate the controller in `autobattler_options.gd`'s `_ready()`, following the same pattern as `main.gd` adding `AICanvas` as a child. The controller script lives at `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/adaptive_weight_controller.gd`.
- **D-07:** In Godot 3.5, `_process()` runs before `_physics_process()` each frame. The adaptive controller updates EMA in `_process()`, so fresh multipliers are available when `get_movement()` reads them during `_physics_process()`. No one-frame-stale issue.
- **D-08:** Apply adaptive multipliers in `_build_context()` of `player_movement_behavior.gd`. The pattern is: `ctx.item_weight = options.item_weight * controller.get_multiplier("item")`. Base weights in `AutobattlerOptions` remain untouched — only effective weights passed to force calculators are adjusted.
- **D-09:** Two-group adaptation split: **defensive weights** (projectile, boss, boundary) increase toward +30% when taking more damage; **offensive/pickup weights** (consumable, gold, tree) decrease toward -30%. When damage_rate is low, the inverse occurs.
- **D-10:** All multipliers clamped to [0.7, 1.3] range. The controller exposes `get_multiplier(force_type: String) -> float`.
- **D-11:** EMA lerp rate of ~0.02 per frame, producing ~3-second convergence at 60fps. Formula: `ema_value = lerp(ema_value, raw_value, 0.02)`.
- **D-12:** At wave boundary, all EMA accumulators and multipliers hard-reset to baseline (multiplier = 1.0, damage_rate = 0.0, health_ratio = 1.0). No carry-over between waves.

### Claude's Discretion

- Exact mapping function from EMA metrics to multiplier values (as long as it respects the two-group split, ±30% clamp, and ~3s convergence)
- Internal data structure for tracking per-type multipliers
- Whether to store previous-frame health as a member variable or compute delta differently
- Exact threshold for "high damage" vs "low damage" classification
- Whether the controller exposes debug data for potential future visualization of adaptation state

### Deferred Ideas (OUT OF SCOPE)

- Wave phase profiles (early/mid/late wave behavior shifts) — ADAPT-V2-01
- Strategy presets (aggressive/defensive/balanced toggle) — ADAPT-V2-02
- Character-specific adaptive profiles — ADAPT-V2-03
- Visualization of adaptive state — potential future enhancement, not Phase 3 scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ADAPT-01 | EMA-based performance metrics track damage_rate and health_ratio per frame | EMA lerp formula verified; `player.current_stats.health` and `player.max_stats.health` confirmed as per-frame polling targets in `_build_context()` |
| ADAPT-02 | Dynamic weight multipliers adjust effective weights based on performance metrics (clamped ±30%) | `clamp()` is GDScript built-in; multiplier dictionary keyed by force type verified as the extensible pattern; _build_context() confirmed as the single injection point |
| ADAPT-03 | Adaptive state hard-resets at wave boundaries (no carry-over between waves) | Wave timer polling `$"/root/Main"._wave_timer.time_left < 0.05` confirmed in `ai_canvas.gd`; transition detection pattern (low-to-high transition) specified |
| ADAPT-04 | AdaptiveWeightController owned by AutobattlerOptions node (not Script Extension) to avoid _process double-call | `main.gd` child-node pattern (AICanvas) confirmed as precedent; `autobattler_options.gd` `_ready()` as instantiation site verified |
| ADAPT-05 | Adaptive adjustments produce smooth transitions (lerp rate ~0.02, ~3-second convergence at 60fps) | `lerp()` is GDScript built-in; math verified: 0.02 rate × 60fps ≈ 3.3s half-life for EMA |
</phase_requirements>

---

## Summary

Phase 3 adds a self-contained `AdaptiveWeightController` node that tracks two EMA-smoothed performance metrics (`damage_rate` and `health_ratio`) and uses them to adjust the effective weights passed into force calculators each frame. The controller lives as a child node of `AutobattlerOptions`, not as a Script Extension, which means it has its own `_process(delta)` that runs exactly once per frame before `_physics_process()` — when `get_movement()` reads its multipliers. All decisions are locked in CONTEXT.md.

The phase has a clean, two-file implementation surface: one new file (`adaptive_weight_controller.gd`), and one modification to `_build_context()` in `player_movement_behavior.gd`. No other files require changes. The simulation test suite (Python, stdlib `unittest`) provides the validation harness — Phase 3 adds an `AdaptiveController` Python port plus new test classes covering all five success criteria.

**Primary recommendation:** Implement the controller as a plain GDScript `Node` child with a dictionary of per-type multipliers. Apply multipliers at `_build_context()` by multiplying base weights. Port the controller logic to Python for simulation testing. One plan is sufficient.

---

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| GDScript | Godot 3.5 | Controller logic | Project constraint; all mod code is GDScript |
| `lerp()` | Built-in | EMA smoothing | GDScript built-in — no import needed |
| `clamp()` | Built-in | Multiplier capping | GDScript built-in — no import needed |
| Python 3.12 | stdlib only | Simulation testing | Already established; 67 existing tests prove the harness |
| `unittest` | stdlib | Test framework | No pytest installed; existing suite uses `unittest` |

### Established Mod Patterns Used
| Pattern | Where | How Phase 3 Uses It |
|---------|-------|---------------------|
| Child-node instantiation | `main.gd` → `AICanvas` | `autobattler_options.gd` → `AdaptiveWeightController` |
| Node singleton access | `$"/root/AutobattlerOptions"` | Controller accessible via property on AutobattlerOptions |
| Wave-end poll | `ai_canvas.gd` line 4 | Wave boundary detection for reset |
| Per-frame health poll | `consumable_force.gd` | EMA input for `damage_rate` and `health_ratio` |
| Dictionary key multiplier | `_build_context()` | Weight injection via `options.X_weight * controller.get_multiplier("X")` |

**Installation:** No packages needed — pure GDScript + Python stdlib.

---

## Architecture Patterns

### Recommended File Structure
```
mods-unpacked/Pasha-AutoBattlerEnhanced/
├── autobattler_options.gd          # MODIFIED: instantiate controller in _ready()
│                                   #           expose controller as property
├── extensions/
│   ├── adaptive_weight_controller.gd  # NEW: standalone Node (not a Script Extension)
│   └── entities/units/movement_behaviors/
│       └── player_movement_behavior.gd  # MODIFIED: _build_context() applies multipliers
tests/
├── sim/
│   ├── adaptive_controller.py      # NEW: Python port of controller logic
│   └── mocks.py                    # unchanged
├── test_adaptive.py                # NEW: unit + scenario tests for Phase 3
```

### Pattern 1: AdaptiveWeightController Node Structure

```gdscript
# Source: CONTEXT.md D-05, D-06, D-10, D-11 (locked decisions)
# File: mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/adaptive_weight_controller.gd

extends Node

# EMA state — reset at wave boundary
var _ema_damage_rate: float = 0.0
var _ema_health_ratio: float = 1.0
var _prev_health: float = -1.0  # -1 signals "not yet initialized"

# Multiplier state per force type (D-10: clamped [0.7, 1.3])
var _multipliers: Dictionary = {}

# Group assignments (D-09)
const DEFENSIVE_TYPES = ["projectile", "boss", "bumper"]
const OFFENSIVE_TYPES = ["consumable", "item", "tree"]

const EMA_RATE = 0.02         # D-11: ~3s convergence at 60fps
const MULT_MIN = 0.7          # D-10
const MULT_MAX = 1.3          # D-10

func _ready():
    _reset()

func _reset():
    _ema_damage_rate = 0.0
    _ema_health_ratio = 1.0
    _prev_health = -1.0
    for t in DEFENSIVE_TYPES + OFFENSIVE_TYPES:
        _multipliers[t] = 1.0

func get_multiplier(force_type: String) -> float:
    return _multipliers.get(force_type, 1.0)

func _process(delta):
    # ... EMA update + multiplier adjustment + wave-boundary reset
```

**Source:** CONTEXT.md D-05, D-07, D-10, D-11 [VERIFIED: read autobattler_options.gd and main.gd]

### Pattern 2: Instantiation in AutobattlerOptions._ready()

```gdscript
# Source: CONTEXT.md D-06 (locked decision), mirrors main.gd AICanvas pattern
# [VERIFIED: read main.gd lines 7-9, autobattler_options.gd lines 50-61]

# At top of autobattler_options.gd:
const AdaptiveWeightController = preload(
    "res://mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/adaptive_weight_controller.gd"
)
var adaptive_controller  # exposed as property for _build_context() to read

func _ready():
    adaptive_controller = AdaptiveWeightController.new()
    add_child(adaptive_controller)
    reset_defaults()
    load_mod_options()
    # ... rest of existing _ready()
```

**Source:** `main.gd` AICanvas instantiation pattern [VERIFIED: read main.gd]

### Pattern 3: Multiplier Injection in _build_context()

```gdscript
# Source: CONTEXT.md D-08 (locked decision)
# [VERIFIED: read player_movement_behavior.gd lines 35-67]

func _build_context(options) -> Dictionary:
    var ctrl = options.adaptive_controller  # cached property, no node lookup overhead
    # ... existing setup code ...
    return {
        # ... existing entries ...
        "item_weight":       options.item_weight       * ctrl.get_multiplier("item"),
        "projectile_weight": options.projectile_weight * ctrl.get_multiplier("projectile"),
        "tree_weight":       options.tree_weight        * ctrl.get_multiplier("tree"),
        "boss_weight":       options.boss_weight        * ctrl.get_multiplier("boss"),
        "bumper_weight":     options.bumper_weight      * ctrl.get_multiplier("bumper"),
        "egg_weight":        options.egg_weight,  # egg: no separate adaptive group in Phase 3
        "consumable_weight": (1.0 - (cur_hp / max_hp)) * 2.0 * ctrl.get_multiplier("consumable"),
        # ... rest unchanged
    }
```

**Source:** CONTEXT.md D-08, D-09 [VERIFIED: read player_movement_behavior.gd `_build_context()`]

### Pattern 4: EMA Update + Multiplier Shift

The exact mapping function is Claude's discretion (per CONTEXT.md). The locked constraints are:
- EMA rate 0.02, clamp [0.7, 1.3], two-group split, ~3s convergence
- `damage_rate` = HP delta / delta, `health_ratio` = cur_hp / max_hp

A linear centred-on-0.5 approach:

```gdscript
# damage_signal = normalized damage intensity (0.0 = safe, 1.0 = heavy damage)
# Approaches: use health_ratio as the primary signal (already normalized to [0,1])
# damage_rate provides rate-of-change signal

func _update_multipliers():
    # health_ratio: 0 = dying, 1 = full. Low ratio = more defensive.
    var threat_level = 1.0 - _ema_health_ratio  # [0, 1] -- 0 = safe, 1 = dying

    # EMA rate * threat_level controls how fast multipliers shift toward their extremes
    var shift_rate = EMA_RATE  # same rate as EMA for consistency

    for t in DEFENSIVE_TYPES:
        var target = lerp(MULT_MIN, MULT_MAX, threat_level)
        _multipliers[t] = lerp(_multipliers[t], target, shift_rate)
        _multipliers[t] = clamp(_multipliers[t], MULT_MIN, MULT_MAX)

    for t in OFFENSIVE_TYPES:
        var target = lerp(MULT_MAX, MULT_MIN, threat_level)
        _multipliers[t] = lerp(_multipliers[t], target, shift_rate)
        _multipliers[t] = clamp(_multipliers[t], MULT_MIN, MULT_MAX)
```

**Source:** CONTEXT.md D-09, D-10, D-11; mapping function is Claude's discretion [ASSUMED: specific mapping is discretionary per CONTEXT.md]

### Pattern 5: Wave Boundary Detection and Reset

```gdscript
# Source: CONTEXT.md D-03, D-12 (locked decisions)
# [VERIFIED: read ai_canvas.gd line 4: time_left < .05 is established wave-end poll]

var _prev_wave_time_left: float = 1.0

func _process(delta):
    var wave_timer = $"/root/Main"._wave_timer
    var current_time = wave_timer.time_left

    # Transition: was near-zero (< 0.05), now high (> 1.0) → new wave started
    if _prev_wave_time_left < 0.05 and current_time > 1.0:
        _reset()
        _prev_wave_time_left = current_time
        return

    _prev_wave_time_left = current_time
    _update_ema(delta)
    _update_multipliers()
```

**Source:** CONTEXT.md D-03, D-12; `ai_canvas.gd` wave polling [VERIFIED: read ai_canvas.gd line 4]

### Anti-Patterns to Avoid

- **Accessing controller via `get_node()` inside `_build_context()`**: This is called every physics frame — use a cached property reference on `AutobattlerOptions` instead. `get_node()` with a long path is slower than a property read.
- **Making AdaptiveWeightController a Script Extension**: Script Extensions can have `_process()` called twice (once by the extension, once by the base class). A standalone node child avoids this entirely (ADAPT-04 requirement).
- **Connecting to Timer.timeout signal for wave reset**: Signal reliability during Brotato's wave transitions is unverified for modded code (CONTEXT.md D-04). Poll `_wave_timer.time_left` exclusively.
- **Mutating base weights in AutobattlerOptions**: Base weights (`options.item_weight`, etc.) must remain user-set values. Only compute effective weights in `_build_context()` — never overwrite the base variables.
- **Applying multipliers inside individual force calculators**: The single injection point is `_build_context()`. Force calculators must remain stateless and unmodified.
- **Carrying EMA state across waves**: At each wave boundary, hard-reset all accumulators and multipliers to baseline (D-12). No carry-over.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Smoothing | Custom IIR filter | `lerp()` built-in | GDScript built-in, well-tested, produces correct EMA at constant rate |
| Clamping | Manual min/max chain | `clamp()` built-in | GDScript built-in, correct and readable |
| Type mapping | Match/switch per type | Dictionary keyed by type name | Extensible for Phase 4 new force types (EXT-01, EXT-02, EXT-03 add new keys) |
| Player health access | Signal subscription | Direct property poll | No damage signals exist in mod codebase (D-02) |
| Wave detection | Timer signal | Time-left polling | Signal reliability unverified for modded wave transitions (D-04) |

**Key insight:** The entire adaptive controller is approximately 70-90 lines of GDScript. Nothing in this domain justifies a library or framework — GDScript built-ins cover all mathematical needs.

---

## Common Pitfalls

### Pitfall 1: First-Frame _prev_health Spike
**What goes wrong:** On the first frame after instantiation (or after reset), `_prev_health` is uninitialized. If `delta` for `damage_rate = (prev_health - cur_hp) / delta` uses a garbage value, the first-frame EMA input is a large spike, temporarily spiking all defensive multipliers.
**Why it happens:** Forgetting to initialize `_prev_health` to the actual current health value in `_reset()`, or initializing it to 0 (which causes a false "took max damage" reading).
**How to avoid:** In `_reset()`, set `_prev_health = -1.0` as a sentinel. In `_process()`, if `_prev_health < 0.0`, read current health and store it without computing damage_rate (skip the EMA update for that frame only).
**Warning signs:** Multipliers immediately jump to extreme values (1.3 defensive, 0.7 offensive) at wave start even though no damage was taken.

### Pitfall 2: Double-Processing in Script Extension
**What goes wrong:** If `AdaptiveWeightController` were registered as a Script Extension via `ModLoaderMod.install_script_extension()`, its `_process()` can be called twice per frame by some ModLoader versions.
**Why it happens:** Script Extension patching in Godot's inheritance chain can invoke both the extension and parent lifecycle methods.
**How to avoid:** The controller is a plain `Node` instantiated with `new()` and added with `add_child()`. It is never registered in `mod_main.gd`. (ADAPT-04, D-05).
**Warning signs:** EMA converges twice as fast as expected; multipliers reach extremes in ~1.5 seconds instead of ~3 seconds.

### Pitfall 3: Stale Controller Reference in _build_context()
**What goes wrong:** `_build_context()` calls `get_node("/root/AutobattlerOptions/AdaptiveWeightController")` every physics frame (60 fps). This is a string-parsed node lookup each frame.
**Why it happens:** Naively copying the `$"/root/..."` access pattern from `get_movement()` without thinking about per-frame cost.
**How to avoid:** Cache the controller reference as a property on `AutobattlerOptions` (e.g., `var adaptive_controller`) and expose it directly. In `_build_context()`, access it as `options.adaptive_controller` — one property read, no node lookup.
**Warning signs:** Profiling shows unexpected overhead in `_build_context()`.

### Pitfall 4: egg_weight Adaptive Group Assignment
**What goes wrong:** Assigning `egg_weight` to the offensive group causes the AI to reduce egg attraction when taking damage — but eggs hatch into swarms, so the AI should prioritize them *more* under pressure, not less.
**Why it happens:** Treating eggs like regular pickups. Eggs are an exception to the offensive/defensive split.
**How to avoid:** Leave `egg_weight` out of both groups in Phase 3. Do not apply a multiplier to `egg_weight` in `_build_context()`. This matches the Phase 3 scope boundary (D-09 covers consumable/gold/tree as offensive; eggs are an outlier case deferred to Phase 4 or v2 character-specific profiles).
**Warning signs:** Test shows AI stops pursuing eggs when taking damage, leading to hatching swarms.

### Pitfall 5: bumper_weight Key Name Mismatch
**What goes wrong:** `autobattler_options.gd` uses the variable name `bumper_weight`, but if the multiplier dictionary key is named `"boundary"` instead of `"bumper"`, `get_multiplier("bumper")` returns 1.0 (the default fallback) and adaptation has no effect on boundary force.
**Why it happens:** Naming the multiplier key after the calculator file (`"boundary"`) rather than after the options variable (`"bumper"`).
**How to avoid:** Name dictionary keys to match the force type label used in `_build_context()`. The `_build_context()` injection lines `options.bumper_weight * ctrl.get_multiplier("bumper")` must agree with the key names in `_multipliers`. Document the key-to-weight mapping explicitly in the controller.
**Warning signs:** Boundary force never adapts during heavy projectile pressure despite multiplier logic running.

### Pitfall 6: Wave Boundary Detection Fires During Active Combat
**What goes wrong:** `_prev_wave_time_left < 0.05 and current_time > 1.0` is the transition check. If the timer briefly reads a low value during an in-progress wave (e.g., due to timer precision jitter), this triggers a spurious reset mid-wave.
**Why it happens:** Using `< 0.05` as the "wave over" threshold is borrowed from `ai_canvas.gd` where it's used as an early-exit guard, not as a transition detector.
**How to avoid:** The full condition is `_prev_wave_time_left < 0.05 AND current_time > 1.0` (both sides of the transition). This is robustly directional — jitter at low values can't produce a jump to > 1.0. Monitor in tests using a simulated timer.
**Warning signs:** Adaptive state randomly resets to baseline mid-wave; multipliers snap back to 1.0 unexpectedly.

---

## Code Examples

### EMA Formula Verified
```gdscript
# Source: GDScript 3.5 built-in lerp() — exact semantics
# lerp(a, b, t) = a + (b - a) * t
# At t=0.02, per-frame decay factor = 0.98
# After N frames: value is within (1 - e^(-N*0.02)) of target
# At N=150 frames (2.5s at 60fps): ~95% convergence — close enough for "~3s"

_ema_health_ratio = lerp(_ema_health_ratio, raw_health_ratio, 0.02)
_ema_damage_rate  = lerp(_ema_damage_rate,  raw_damage_rate,  0.02)
```
[VERIFIED: lerp is a GDScript 3.5 built-in; confirmed by reading existing code using it in Godot]

### damage_rate Computation
```gdscript
# Source: CONTEXT.md D-01 (locked decision)
# raw_damage_rate: HP lost per second, normalized to max_hp to get [0, 1] scale
# Clamped to [0, 1] to prevent negative (healing) values from inverting logic

func _compute_damage_rate(player, delta: float) -> float:
    var cur_hp = float(player.current_stats.health)
    if _prev_health < 0.0:  # first frame sentinel
        _prev_health = cur_hp
        return 0.0
    var max_hp = float(player.max_stats.health)
    var raw_rate = (_prev_health - cur_hp) / (delta * max_hp)  # normalized [0,1]
    _prev_health = cur_hp
    return clamp(raw_rate, 0.0, 1.0)  # healing = 0 damage rate
```
[VERIFIED: health property access pattern confirmed in `consumable_force.gd` and `_build_context()`]

### Python Port Structure for Testing
```python
# Source: Mirrors existing sim/force_calculators.py pattern
# File: tests/sim/adaptive_controller.py

class AdaptiveController:
    DEFENSIVE = ["projectile", "boss", "bumper"]
    OFFENSIVE = ["consumable", "item", "tree"]
    EMA_RATE = 0.02
    MULT_MIN = 0.7
    MULT_MAX = 1.3

    def __init__(self):
        self._reset()

    def _reset(self):
        self.ema_damage_rate = 0.0
        self.ema_health_ratio = 1.0
        self._prev_health = -1.0
        self._multipliers = {t: 1.0 for t in self.DEFENSIVE + self.OFFENSIVE}

    def get_multiplier(self, force_type: str) -> float:
        return self._multipliers.get(force_type, 1.0)

    def update(self, player_hp: float, max_hp: float, delta: float = 1/60):
        # EMA updates then multiplier shift
        ...
```
[ASSUMED: Python port structure — will be implemented to match GDScript logic exactly]

### build_ctx extension for adaptive testing
```python
# Extend mocks.build_ctx to accept a controller parameter:
def build_ctx_with_adaptive(controller: AdaptiveController, **kwargs) -> dict:
    ctx = build_ctx(**kwargs)
    ctx["item_weight"]       *= controller.get_multiplier("item")
    ctx["projectile_weight"] *= controller.get_multiplier("projectile")
    ctx["tree_weight"]       *= controller.get_multiplier("tree")
    ctx["boss_weight"]       *= controller.get_multiplier("boss")
    ctx["bumper_weight"]     *= controller.get_multiplier("bumper")
    ctx["consumable_weight"] *= controller.get_multiplier("consumable")
    return ctx
```
[ASSUMED: helper function design; exact signature TBD by implementer]

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Static weights (user-set once) | EMA-smoothed dynamic multipliers [0.7, 1.3] | AI adapts to combat pressure automatically |
| Inline consumable health-urgency in `consumable_force.gd` | Generalized across ALL force types via controller | Consistent adaptive behavior; consumable urgency still applies on top |
| Wave-end detection as guard (`< 0.05` early exit) | Wave-end as reset trigger (transition detection) | Clean state isolation between waves |

**Deprecated/outdated:**
- `consumable_weight = (1.0 - hp_ratio) * 2.0` in `_build_context()` remains as the per-frame consumable base — Phase 3 multiplies this value by `ctrl.get_multiplier("consumable")` on top, so the health-urgency still functions. The adaptive system amplifies/dampens it rather than replacing it.

---

## Integration Points: What Changes and What Doesn't

### Files Modified (2)

**`autobattler_options.gd`**
- Add `const AdaptiveWeightController = preload("...adaptive_weight_controller.gd")`
- Add `var adaptive_controller` property
- In `_ready()`: instantiate and `add_child(adaptive_controller)` before `reset_defaults()`
- No changes to weight variables, save/load, or `setting_changed()`

**`extensions/entities/units/movement_behaviors/player_movement_behavior.gd`**
- In `_build_context()`: multiply 6 weight values by `ctrl.get_multiplier(key)` before inserting into dict
- Cache the controller reference via `options.adaptive_controller`
- No changes to `get_movement()`, `_compute_weapon_range()`, or any other method

### Files Created (1 GDScript + 2 Python)

**`extensions/adaptive_weight_controller.gd`** — new standalone Node
**`tests/sim/adaptive_controller.py`** — Python port for simulation
**`tests/test_adaptive.py`** — unit + scenario tests

### Files Unchanged (all force calculators, mod_main.gd, main.gd, manifest.json, translations)

`mod_main.gd` does NOT need to be modified — the controller is not a Script Extension and requires no ModLoader registration.

---

## Validation Architecture

> `nyquist_validation: true` in config.json — this section is required.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Python 3.12 stdlib `unittest` |
| Config file | none — `python3 -m unittest discover -s tests` |
| Quick run command | `python3 -m unittest tests.test_adaptive -v` |
| Full suite command | `python3 -m unittest discover -s tests -v` |

**Note:** pytest is not installed. Existing 67 tests use `unittest`. Phase 3 tests continue the same pattern.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADAPT-01 | EMA damage_rate and health_ratio update each frame | unit | `python3 -m unittest tests.test_adaptive.TestEMAMetrics -v` | No — Wave 0 |
| ADAPT-01 | EMA values are readable as controller properties | unit | `python3 -m unittest tests.test_adaptive.TestControllerInterface -v` | No — Wave 0 |
| ADAPT-02 | Under sustained damage, effective weights shift within ±30% over ~3s | unit | `python3 -m unittest tests.test_adaptive.TestMultiplierShift -v` | No — Wave 0 |
| ADAPT-02 | Multipliers never exceed [0.7, 1.3] range | unit | `python3 -m unittest tests.test_adaptive.TestMultiplierClamp -v` | No — Wave 0 |
| ADAPT-03 | Wave boundary resets all EMA accumulators and multipliers to baseline | unit | `python3 -m unittest tests.test_adaptive.TestWaveReset -v` | No — Wave 0 |
| ADAPT-04 | AdaptiveWeightController is NOT a Script Extension (structural test) | manual | Code inspection — controller does not appear in `mod_main.gd` | No — Wave 0 |
| ADAPT-05 | Multipliers converge to within 5% of target within 300 frames (5s at 60fps) | unit | `python3 -m unittest tests.test_adaptive.TestConvergenceRate -v` | No — Wave 0 |
| ADAPT-01,02 | Scenario: sustained damage shifts defensive weights up, offensive down | scenario | `python3 -m unittest tests.test_adaptive.TestAdaptiveScenarios -v` | No — Wave 0 |
| ADAPT-01,02 | Scenario: no damage restores weights toward baseline | scenario | `python3 -m unittest tests.test_adaptive.TestAdaptiveScenarios -v` | No — Wave 0 |

### Sampling Rate
- **Per task commit:** `python3 -m unittest tests.test_adaptive -v`
- **Per wave merge:** `python3 -m unittest discover -s tests -v` (all 67 existing + new adaptive tests)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `tests/sim/adaptive_controller.py` — Python port of GDScript controller (covers ADAPT-01, ADAPT-02, ADAPT-03, ADAPT-05)
- [ ] `tests/test_adaptive.py` — all test classes listed above

*(All other test infrastructure exists: `unittest`, `tests/sim/mocks.py`, `tests/sim/vector2.py`, `tests/sim/force_calculators.py`, `tests/sim/arena.py`)*

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3 | Simulation tests | Yes | 3.12.3 | — |
| `unittest` | Test runner | Yes | stdlib | — |
| `pytest` | (Not used) | No | — | Use `python3 -m unittest discover -s tests` |
| GDScript / Godot 3.5 | In-game validation | Not verified on dev machine | — | Simulation tests cover all success criteria |

**Missing dependencies with no fallback:**
- Godot 3.5 game runtime — in-game validation is not possible on dev machine. All verification is via Python simulation (established project pattern per MEMORY.md: "Never ask for manual game testing; build automated simulation on dev machine").

**Missing dependencies with fallback:**
- pytest not installed — stdlib `unittest` used instead (existing project pattern, 67 tests already running).

---

## Open Questions

1. **Should `egg_weight` receive an adaptive multiplier?**
   - What we know: Eggs use `egg_weight` via `enemy_force.gd`; D-09 assigns consumable/gold/tree to offensive group; boss/projectile/boundary to defensive
   - What's unclear: Eggs are aggressive threats (hatch into swarms) but also items to be attacked (offensive goal). Under pressure, should egg attraction increase (defensive: kill them before they hatch) or decrease (offensive group logic says reduce pickup aggression)?
   - Recommendation: Leave `egg_weight` out of both groups for Phase 3 (no multiplier applied). This is the safe default — egg behavior is intentionally extreme (D-07) and Phase 3 should not accidentally reduce it under pressure. Revisit in Phase 4 EXT requirements.

2. **Wave timer access from AdaptiveWeightController node**
   - What we know: `ai_canvas.gd` accesses `$"/root/Main"._wave_timer.time_left` from a Node2D added as child of Main. `AdaptiveWeightController` is added as child of `AutobattlerOptions` (a singleton node at `/root/AutobattlerOptions`).
   - What's unclear: Whether `$"/root/Main"._wave_timer` is accessible from a node parented to a different branch of the scene tree.
   - Recommendation: Use `get_node("/root/Main")._wave_timer.time_left` (absolute path) — established mod pattern for cross-tree node access. This mirrors the `$"/root/AutobattlerOptions"` pattern used in `player_movement_behavior.gd`.

3. **Player node access from AdaptiveWeightController**
   - What we know: The controller needs `player.current_stats.health` and `player.max_stats.health` to compute `damage_rate`. In `player_movement_behavior.gd`, `player = get_parent()` is used. `AdaptiveWeightController` is not parented to the player.
   - What's unclear: How the controller acquires the player reference.
   - Recommendation: Access via `get_node("/root/Main")._players[0]` — the same global singleton pattern used throughout the codebase. Cache the reference in `_ready()` after the scene tree is stable. Guard with `if get_node("/root/Main").has_node(...)` if needed.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The exact mapping function from EMA metrics to multiplier values uses `threat_level = 1 - ema_health_ratio` as the primary signal driving defensive/offensive shift | Architecture Patterns, Pattern 4 | Multipliers may not produce meaningful behavioral change if the chosen signal is too noisy or too slow; Claude's discretion allows any mapping that satisfies the clamp and convergence constraints |
| A2 | `_players[0]` provides the correct player reference from within AdaptiveWeightController | Open Questions | If multiplayer coop is active (F1 bot), `_players[0]` may be the bot player; however, coop mode is currently unstable and rolled back, so single-player is the assumed context |
| A3 | Python port of adaptive controller (`adaptive_controller.py`) can be ported line-for-line from GDScript to Python with the same semantics as the existing force_calculators.py port | Validation Architecture | If GDScript semantics diverge from Python (e.g., GDScript `lerp()` behavior at boundary), tests may pass in Python but fail in-game |
| A4 | The `egg_weight` multiplier group assignment (excluded from both groups) is the correct default for Phase 3 | Common Pitfalls, Open Questions | If eggs should adapt with defensive weights, the Phase 3 implementation underserves survival under swarm pressure |

**If this table is empty:** It is not — A1-A4 are discretionary choices flagged for planner awareness.

---

## Sources

### Primary (HIGH confidence)
- `mods-unpacked/Pasha-AutoBattlerEnhanced/autobattler_options.gd` — confirmed `_ready()` lifecycle, `_process()`, weight variables, child-node pattern opportunity
- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/player_movement_behavior.gd` — confirmed `_build_context()` as injection point, health property access pattern
- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/ai_canvas.gd` — confirmed `_wave_timer.time_left < .05` polling pattern, `_process()` on standalone Node
- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/main.gd` — confirmed AICanvas child-node instantiation pattern (the template for D-06)
- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/force_result.gd` — confirmed ForceResult contract, `_safe_force()` utility
- All 7 force calculator files — confirmed weight key names (`ctx.item_weight`, `ctx.projectile_weight`, etc.)
- `tests/sim/` directory — confirmed Python simulation harness, stdlib unittest, 67 existing passing tests
- `.planning/phases/03-adaptive-weight-controller/03-CONTEXT.md` — all locked decisions sourced from here

### Secondary (MEDIUM confidence)
- GDScript 3.5 `lerp()` and `clamp()` semantics inferred from existing codebase usage patterns
- `_process()` before `_physics_process()` ordering: CONTEXT.md D-07; standard Godot 3.x frame lifecycle behavior

### Tertiary (LOW confidence)
- None — all critical claims are verified against actual source files

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified from actual source files and working test suite
- Architecture patterns: HIGH — all patterns derived directly from existing mod code (main.gd, ai_canvas.gd, autobattler_options.gd)
- Pitfalls: HIGH — derived from code analysis of actual integration points; LOW for specific mapping function (discretionary)

**Research date:** 2026-04-13
**Valid until:** 2026-05-13 (stable GDScript mod; no external dependencies that can change)

# Phase 3: Adaptive Weight Controller - Context

**Gathered:** 2026-04-13 (auto mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

The AI tracks its own performance during a run and smoothly adjusts force weights in response, resetting cleanly at each wave boundary. This phase adds EMA-based performance metrics, dynamic weight multipliers (clamped ±30%), and a wave-boundary reset mechanism. It does NOT add new force types, new UI controls, or cross-run persistence.

</domain>

<decisions>
## Implementation Decisions

### Performance Metric Data Sources
- **D-01:** Track `damage_rate` by polling `player.current_stats.health` delta between frames divided by delta time. Track `health_ratio` as `player.current_stats.health / player.max_stats.health`. Both properties are already accessed per-frame in `_build_context()` of `player_movement_behavior.gd`.
- **D-02:** Use polling-based health tracking exclusively — no damage event signals exist in the mod codebase. The consumable_force.gd health-urgency pattern `(1.0 - hp_ratio) * 2.0` proves these properties are reliable per-frame data.

### Wave Boundary Detection
- **D-03:** Detect wave boundaries by polling `$"/root/Main"._wave_timer.time_left` each frame — when the value transitions from near-zero (< 0.05) back to a high value, that signals a new wave has started. This is the same polling pattern established in `ai_canvas.gd`.
- **D-04:** Use polling over Timer.timeout signal connection — polling is the established mod pattern, and signal reliability during Brotato's wave transitions is unverified for modded code. The reset trigger must be robust.

### Controller Ownership and Architecture
- **D-05:** AdaptiveWeightController is a standalone GDScript file (not a Script Extension) instantiated as a child Node of `AutobattlerOptions`. It has its own `_process(delta)` for per-frame EMA updates. This satisfies ADAPT-04 and avoids the Script Extension double-call problem.
- **D-06:** Instantiate the controller in `autobattler_options.gd`'s `_ready()`, following the same pattern as `main.gd` adding `AICanvas` as a child. The controller script lives at `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/adaptive_weight_controller.gd`.
- **D-07:** In Godot 3.5, `_process()` runs before `_physics_process()` each frame. The adaptive controller updates EMA in `_process()`, so fresh multipliers are available when `get_movement()` reads them during `_physics_process()`. No one-frame-stale issue.

### Weight Multiplier Integration
- **D-08:** Apply adaptive multipliers in `_build_context()` of `player_movement_behavior.gd` when populating the context dictionary. The pattern is: `ctx.item_weight = options.item_weight * controller.get_multiplier("item")`. Base weights in `AutobattlerOptions` remain untouched — only the effective weights passed to force calculators are adjusted.
- **D-09:** Two-group adaptation split based on damage_rate: **defensive weights** (projectile, boss, bumper) increase toward +30% when taking more damage, while **offensive/pickup weights** (consumable, item, tree) decrease toward -30%. When damage_rate is low, the inverse occurs. Key names match `_build_context()` dictionary keys: `gold_force.gd` uses `ctx.item_weight`, `boundary_force.gd` uses `ctx.bumper_weight`.
- **D-10:** All multipliers clamped to [0.7, 1.3] range per ADAPT-02. The controller exposes a `get_multiplier(force_type: String) -> float` method that returns the current clamped multiplier for a given force type.

### EMA Smoothing
- **D-11:** Both `damage_rate` and `health_ratio` EMA use a lerp rate of ~0.02 per frame, producing ~3-second convergence at 60fps per ADAPT-05. The formula is: `ema_value = lerp(ema_value, raw_value, 0.02)`.
- **D-12:** At wave boundary (detected per D-03), all EMA accumulators and multipliers hard-reset to baseline (multiplier = 1.0, damage_rate = 0.0, health_ratio = 1.0). No carry-over between waves per ADAPT-03.

### Claude's Discretion
- Exact mapping function from EMA metrics to multiplier values (as long as it respects the two-group split, ±30% clamp, and ~3s convergence)
- Internal data structure for tracking per-type multipliers
- Whether to store previous-frame health as a member variable or compute delta differently
- Exact threshold for "high damage" vs "low damage" classification
- Whether the controller exposes debug data for potential future visualization of adaptation state

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Output (Weight System)
- `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/player_movement_behavior.gd` — `_build_context()` method where adaptive multipliers must be applied, `get_movement()` force accumulation loop, `_last_force_results` array
- `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/force_result.gd` — ForceResult contract consumed by all calculators

### Configuration Singleton (Controller Host)
- `mods-unpacked/Pasha-AutoBattler/autobattler_options.gd` — AutobattlerOptions singleton where AdaptiveWeightController will be instantiated as child node; weight variables, `_process()`, `_ready()` lifecycle

### Force Calculators (Consumers of Adapted Weights)
- `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/consumable_force.gd` — Uses `ctx.item_weight` and health_ratio pattern
- `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/gold_force.gd` — Uses `ctx.item_weight`
- `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/projectile_force.gd` — Uses `ctx.projectile_weight`
- `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/enemy_force.gd` — Uses enemy weight from ctx
- `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/boss_force.gd` — Uses boss weight from ctx
- `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/boundary_force.gd` — Uses bumper weight from ctx
- `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/tree_force.gd` — Uses `ctx.tree_weight`

### Scene Integration (Wave Timer)
- `mods-unpacked/Pasha-AutoBattler/extensions/main.gd` — Scene attachment pattern, `_wave_timer` access
- `mods-unpacked/Pasha-AutoBattler/extensions/ai_canvas.gd` — Wave timer polling pattern at line 4

### Requirements
- `.planning/REQUIREMENTS.md` §ADAPT — ADAPT-01 through ADAPT-05 requirement definitions
- `.planning/phases/01-force-architecture-algorithm-fixes/01-CONTEXT.md` — Phase 1 decisions D-10 (sign convention), D-11 (linear mapping), D-14 (ForceResult debug_items)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_build_context()` in `player_movement_behavior.gd` — single integration point for applying adaptive multipliers to all force calculator weights
- `AutobattlerOptions` singleton pattern — established child-node instantiation, `_ready()` lifecycle, `_process()` loop already present
- Health ratio computation in `consumable_force.gd` — `(1.0 - hp_ratio) * 2.0` pattern proves health-based behavioral adaptation already works per-frame
- Wave timer polling in `ai_canvas.gd` — `$"/root/Main"._wave_timer.time_left < .05` as wave-end detection

### Established Patterns
- Node singleton access: `$"/root/AutobattlerOptions"` — controller will be accessible via `$"/root/AutobattlerOptions/AdaptiveWeightController"` or through a property on AutobattlerOptions
- Per-frame polling (not signals) for game state detection
- Distance-squared optimization and NaN guards for numerical safety
- `lerp()` is a GDScript built-in — no import needed for EMA computation
- `clamp()` is a GDScript built-in — no import needed for multiplier capping

### Integration Points
- `autobattler_options.gd` `_ready()` — instantiate and add controller as child node
- `player_movement_behavior.gd` `_build_context()` — apply multipliers when building ctx dictionary
- `mod_main.gd` — does NOT need to register the controller (it's not a Script Extension)
- Wave timer on `$"/root/Main"` — accessible from any node in the scene tree

</code_context>

<specifics>
## Specific Ideas

- The health-urgency pattern in consumable_force.gd (`(1.0 - hp_ratio) * 2.0`) is a localized precursor to the adaptive system — Phase 3 generalizes this concept across ALL force types, not just consumables
- The controller must be accessible from `_build_context()` without expensive lookups — consider caching the controller reference in `player_movement_behavior.gd` `_ready()` or as a property on AutobattlerOptions
- Future Phase 4 will add new force types (fruit, crate, boss avoidance) — the multiplier system should use a dictionary keyed by force type name for easy extensibility

</specifics>

<deferred>
## Deferred Ideas

- Wave phase profiles (early/mid/late wave behavior shifts) — deferred to ADAPT-V2-01
- Strategy presets (aggressive/defensive/balanced toggle) — deferred to ADAPT-V2-02
- Character-specific adaptive profiles — deferred to ADAPT-V2-03
- Visualization of adaptive state (showing current multipliers as overlay) — potential future enhancement, not in Phase 3 scope

None — analysis stayed within phase scope

</deferred>

---

*Phase: 03-adaptive-weight-controller*
*Context gathered: 2026-04-13*

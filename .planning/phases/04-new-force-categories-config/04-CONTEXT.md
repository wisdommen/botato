# Phase 4: New Force Categories + Config - Context

**Gathered:** 2026-04-13 (auto mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Add fruit/consumable configurable weight and crate attraction as new force capabilities, verify boss avoidance is independently configurable (already done in Phase 1), integrate all new types into the arrow-based visualization, expose new parameters in the ModOptions UI, and ensure old save files load gracefully with default fallbacks. This phase does NOT add new adaptive logic, new movement algorithms, or character-specific behavior.

</domain>

<decisions>
## Implementation Decisions

### Consumable Weight Parameterization (EXT-01)
- **D-01:** Add a `CONSUMABLE_WEIGHT` slider as a base multiplier applied ON TOP of the existing health-ratio scaling. The consumable force formula becomes: `force = (direction / dist_sq) * 10.0 * health_ratio_weight * consumable_weight` where `consumable_weight` is the new user-configurable slider value. This preserves the health-urgency behavior (low health = stronger attraction) while adding user control over the overall pickup priority.
- **D-02:** The `consumable_weight` parameter flows through `_build_context()` the same way other weights do: `ctx.consumable_weight = (1.0 - hp_ratio) * 2.0 * options.consumable_weight * ctrl.get_multiplier("consumable")`. The health-ratio component stays in `_build_context()`, not in the calculator, because it needs `player.current_stats` which belongs in context-building.
- **D-03:** Default value for `CONSUMABLE_WEIGHT` slider: `1.0` — neutral multiplier that preserves current behavior. Range: `0.0` to `5.0`.

### Crate/Box Force (EXT-02)
- **D-04:** Create a new `crate_force.gd` calculator following the ForceResult contract. Crate attraction is simple inverse-distance-squared with configurable weight — no repulsion zone, no special behavior. Crates are always attractive (break them for loot).
- **D-05:** Researcher MUST investigate how crates are represented in Brotato's scene tree. Likely candidates: part of `EntitySpawner.neutrals` (filtered by type), a separate container, or `_consumables`-style array on Main. The calculator's `ctx.crates` source depends on this discovery.
- **D-06:** Default value for `CRATE_WEIGHT` slider: `0.5` — moderate attraction, less than tree weight. Range: `0.0` to `10.0`.

### Boss Avoidance Verification (EXT-03)
- **D-07:** `BOSS_WEIGHT` already satisfies EXT-03. Phase 1 separated boss into its own calculator (`boss_force.gd`) with its own weight slider, independent from enemy weight. The boss force already implements attract-far/repel-near with charge detection. No new parameter or calculator needed for EXT-03 — only verification that the existing setup meets the requirement.
- **D-08:** The success criteria "three new force weights as sliders" is interpreted as: (1) NEW `CONSUMABLE_WEIGHT`, (2) NEW `CRATE_WEIGHT`, (3) EXISTING `BOSS_WEIGHT` verified as independently configurable. Only 2 truly new sliders are added.

### Visualization Integration (EXT-04)
- **D-09:** Extend the Phase 2 arrow-based `ai_canvas.gd` (committed at `mods-unpacked/Pasha-AutoBattler/extensions/ai_canvas.gd`) with a new color entry for crate force. Consumable and boss already have visualization colors (green and dark red respectively) — no changes needed for them.
- **D-10:** Crate color: use a warm brown/tan (e.g., `Color(0.8, 0.6, 0.2, 0.7)`) to suggest "wooden crate" without conflicting with existing gold (pure yellow) or enemy (orange).
- **D-11:** The `_type_colors` array and `_calculators` array must remain index-coupled. Crate calculator is appended as the 8th entry (`index 7`) in both arrays.

### Config System (EXT-05, EXT-06, EXT-07)
- **D-12:** New config keys (`CONSUMABLE_WEIGHT`, `CRATE_WEIGHT`) added to `manifest.json` config_schema, `autobattler_options.gd` (variable + constant + setting_changed case + load/save), and `translations/autobattler_options.csv`.
- **D-13:** Config loading uses `get_value(key, default)` fallback pattern already established in `load_mod_options()`. When loading a save file that lacks new keys, the default values are used automatically. No migration code needed.
- **D-14:** `setting_changed()` function already handles unknown keys with `print_debug("WARNING, UNKNOWN CHANGE")`. Adding new `elif` cases for the new keys prevents this warning. EXT-07's `has()` guard pattern is for external ModOptions interface calls — the `setting_changed()` handler itself doesn't need `has()` since it's a controlled switch/elif chain.

### Adaptive Weight Integration
- **D-15:** New `consumable_weight` already has adaptive multiplier integration from Phase 3 (it flows through `ctrl.get_multiplier("consumable")` in `_build_context()`). The new user-configurable base weight simply multiplies into this chain.
- **D-16:** New `crate_weight` joins the offensive/pickup group in Phase 3's two-group adaptation split. In `_build_context()`: `ctx.crate_weight = options.crate_weight * ctrl.get_multiplier("crate")`. The adaptive controller's group mapping needs a "crate" entry in the offensive/pickup category.

### Directory State Resolution
- **D-17:** Phase 1-2 code is tracked under `mods-unpacked/Pasha-AutoBattler/`, Phase 3 additions under `mods-unpacked/Pasha-AutoBattlerEnhanced/`. The planner must decide whether Phase 4 consolidates into one directory or continues the split. The canonical ai_canvas with arrow-based visualization is at `Pasha-AutoBattler/extensions/ai_canvas.gd` (committed). The enhanced directory has a stale pre-rewrite copy that must NOT be used as a base.

### Claude's Discretion
- Exact approach to discovering crate entities in Brotato's scene tree (researcher handles)
- Whether to filter neutrals for crate type or use a separate container
- Crate force distance cutoff threshold (if any — trees have half-weapon-range repulsion, crates may not need one)
- Exact tooltip text for new ModOptions sliders
- Whether consumable_weight slider should be labeled "Fruit Weight" or "Consumable Weight" in the UI
- Internal structure of the crate_force.gd calculator (as long as it follows ForceResult contract)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Force Architecture (Foundation)
- `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/force_result.gd` — ForceResult contract: `calculate(ctx) -> {vector, debug_items}`, `_safe_force()` helper
- `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/consumable_force.gd` — Existing consumable calculator (will be modified to use new configurable weight)
- `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/boss_force.gd` — Existing boss calculator (verification target for EXT-03)
- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/player_movement_behavior.gd` — `_calculators` array, `_build_context()`, `get_movement()` loop

### Phase 2 Visualization (Extension Target)
- `mods-unpacked/Pasha-AutoBattler/extensions/ai_canvas.gd` — Arrow-based visualization reader with `_type_colors` array (GIT VERSION, not the stale working copy in Pasha-AutoBattlerEnhanced)

### Phase 3 Adaptive Controller (Integration Point)
- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/adaptive_weight_controller.gd` — `get_multiplier(type)` method, two-group mapping
- `mods-unpacked/Pasha-AutoBattlerEnhanced/autobattler_options.gd` — Config singleton, `setting_changed()`, `load_mod_options()`, `save_configs()`, adaptive controller instantiation

### Config and UI
- `mods-unpacked/Pasha-AutoBattlerEnhanced/manifest.json` — Config schema for ModOptions UI sliders
- `mods-unpacked/Pasha-AutoBattlerEnhanced/translations/autobattler_options.csv` — Localization keys for slider labels and tooltips
- `mods-unpacked/Pasha-AutoBattlerEnhanced/mod_main.gd` — Extension registration (force files are NOT extensions, crate_force.gd does NOT need registration here)

### Requirements
- `.planning/REQUIREMENTS.md` §EXT — EXT-01 through EXT-07 requirement definitions
- `.planning/phases/01-force-architecture-algorithm-fixes/01-CONTEXT.md` — D-05 (7 calculators), D-10 (sign convention), D-11 (linear weights), D-14 (debug_items format)
- `.planning/phases/02-visualization-decoupling/02-CONTEXT.md` — D-01 (per-type colors), D-03 (arrow-based), D-06 (boundary wall arrows)
- `.planning/phases/03-adaptive-weight-controller/03-CONTEXT.md` — D-08 (multipliers in _build_context), D-09 (two-group split), D-16 (dictionary-based multipliers)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ForceResult._safe_force()` — distance-floor + NaN guard in one call, used by new `crate_force.gd`
- `consumable_force.gd` — template for simple attraction calculator, crate force will be structurally similar
- `_build_context()` — single integration point for adding new ctx entries (crate list, consumable_weight, crate_weight)
- `autobattler_options.gd` config pattern — var + const + setting_changed case + load/save, replicate for new params

### Established Patterns
- Force calculators extend `force_result.gd` and implement `calculate(ctx) -> Dictionary`
- `_calculators` array order matches `_type_colors` array order in ai_canvas
- Config loading: `config.get_value(section, key, default)` pattern throughout `load_mod_options()`
- Adaptive multipliers: `options.weight * ctrl.get_multiplier("type")` pattern in `_build_context()`
- ModOptions schema in `manifest.json` with `type`, `minimum`, `maximum`, `default`, `tooltip`, `format`

### Integration Points
- `player_movement_behavior.gd` `_ready()` — add crate_force.gd to `_calculators` array
- `player_movement_behavior.gd` `_build_context()` — add `ctx.consumable_weight` (modified formula), `ctx.crate_weight`, `ctx.crates` (source TBD by research)
- `ai_canvas.gd` `_type_colors` — append crate color at index 7
- `autobattler_options.gd` — add 2 new weight variables, constants, setting_changed cases, load/save entries
- `manifest.json` config_schema — add 2 new slider definitions
- `translations/autobattler_options.csv` — add label and tooltip for each new key
- `adaptive_weight_controller.gd` — add "crate" to the offensive/pickup group mapping

</code_context>

<specifics>
## Specific Ideas

- The consumable weight formula chains three factors: user slider × health-ratio urgency × adaptive multiplier. This gives maximum control: the user sets base priority, health drives dynamic urgency, and the adaptive system fine-tunes under stress.
- Crate force is the simplest possible calculator — pure attraction with no repulsion zone or distance cutoff. Crates are always good to break.
- The `_type_colors` / `_calculators` index coupling is fragile — future refactoring could use a dictionary keyed by type name. For Phase 4, maintain the array convention for consistency with Phase 1-2 code.
- Boss avoidance (EXT-03) is already satisfied by Phase 1's architecture. The success criteria should be verified during UAT rather than implemented.

</specifics>

<deferred>
## Deferred Ideas

- Dictionary-based `_type_colors` keyed by force type name (replaces fragile array index coupling) — could be its own cleanup phase
- Consumable sub-type filtering (healing vs damage vs utility pickups) — would need Brotato entity property research
- Crate priority based on loot quality prediction — not feasible without game state access
- UI label localization for Chinese/other languages — currently English only

</deferred>

---

*Phase: 04-new-force-categories-config*
*Context gathered: 2026-04-13*

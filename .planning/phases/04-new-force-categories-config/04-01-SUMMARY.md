---
phase: 04-new-force-categories-config
plan: 01
subsystem: force-config
tags: [config, force-calculator, gdscript, modOptions]
dependency_graph:
  requires: [03-02]
  provides: [consumable_weight_config, crate_weight_config, crate_force_calculator]
  affects: [player_movement_behavior, autobattler_options, manifest, translations]
tech_stack:
  added: []
  patterns: [inverse-distance-squared, force-result-contract, config-get-value-default]
key_files:
  created:
    - mods-unpacked/Pasha-AutoBattlerEnhanced/manifest.json
    - mods-unpacked/Pasha-AutoBattlerEnhanced/translations/autobattler_options.csv
    - mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/crate_force.gd
    - mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/force_result.gd
  modified:
    - mods-unpacked/Pasha-AutoBattlerEnhanced/autobattler_options.gd
    - mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/player_movement_behavior.gd
decisions:
  - "force_result.gd duplicated into Enhanced forces directory so crate_force.gd can extend it from the correct res:// path"
  - "crate_weight uses get_multiplier('crate') which safely returns 1.0 until Plan 02 adds 'crate' to OFFENSIVE_TYPES"
  - "consumable_weight formula chains: health-ratio * options.consumable_weight * adaptive_multiplier per D-02"
metrics:
  duration: ~30 minutes
  completed: 2026-04-13
  tasks_completed: 2
  files_created: 4
  files_modified: 2
---

# Phase 04 Plan 01: New Force Categories Config Summary

**One-liner:** Config stack and force pipeline extended with CONSUMABLE_WEIGHT (0.0-5.0 default 1.0) and CRATE_WEIGHT (0.0-10.0 default 0.5) sliders, backed by crate_force.gd using inverse-distance-squared attraction filtered by consumable_data.my_id.

## What Was Built

Two new ModOptions sliders are fully wired through the config stack, and a new crate attraction force calculator is integrated into the movement pipeline.

### Task 1: Config stack for CONSUMABLE_WEIGHT and CRATE_WEIGHT

- `autobattler_options.gd`: Added `consumable_weight` (default 1.0) and `crate_weight` (default 0.5) with paired `_OPTION_NAME` constants. Both wired into `setting_changed()`, `load_mod_options()` (with default fallback for backward compatibility), `save_configs()`, and `reset_defaults()`.
- `manifest.json`: Created for Pasha-AutoBattlerEnhanced with full config_schema. CONSUMABLE_WEIGHT range 0.0-5.0, CRATE_WEIGHT range 0.0-10.0, both with %.2f X format.
- `translations/autobattler_options.csv`: Created with all existing labels plus CONSUMABLE_WEIGHT, CRATE_WEIGHT, CONSUMABLE_WEIGHT_TOOLTIP, CRATE_WEIGHT_TOOLTIP.

### Task 2: crate_force.gd and movement pipeline wiring

- `force_result.gd`: Duplicated into Enhanced forces directory so crate_force.gd can extend it from the correct `res://mods-unpacked/Pasha-AutoBattlerEnhanced/` path.
- `crate_force.gd`: Extends force_result.gd. Filters `ctx.consumables` by `CRATE_IDS = ["consumable_item_box", "consumable_legendary_item_box"]`. Uses `_safe_force()` for distance-floor and NaN guard (T-04-02 mitigation). Returns `{vector, debug_items}` per ForceResult contract.
- `player_movement_behavior.gd`: `crate_force.gd` appended at `_calculators[7]`. `consumable_weight` in `_build_context()` now chains `options.consumable_weight` into the health-ratio formula per D-02. `crate_weight` context entry added using `options.crate_weight * ctrl.get_multiplier("crate")`.
- Boss avoidance independence (EXT-03) verified: `boss_force.gd` uses `ctx.boss_weight` independently from enemy weight, already satisfying the requirement from Phase 1.

## Deviations from Plan

### Auto-added Missing Files

**1. [Rule 2 - Missing Critical File] Created force_result.gd in Enhanced forces directory**
- **Found during:** Task 2
- **Issue:** `crate_force.gd` extends force_result.gd from the Enhanced path (`res://mods-unpacked/Pasha-AutoBattlerEnhanced/...`) but that file didn't exist in the Enhanced mod. At runtime Godot would fail to load crate_force.gd.
- **Fix:** Created `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/force_result.gd` as a copy of the Phase 1 contract.
- **Files modified:** force_result.gd (new)
- **Commit:** 46b964c

None beyond the above. Plan executed as written for all other items.

## Verification Results

All 9 plan verification checks pass:

1. CONSUMABLE_WEIGHT count in autobattler_options.gd: 5 (>= 5 per acceptance criteria)
2. CRATE_WEIGHT count in autobattler_options.gd: 5
3. CONSUMABLE_WEIGHT count in manifest.json: 2
4. CRATE_WEIGHT count in manifest.json: 2
5. crate_force.gd has `func calculate()`: 1
6. crate_force.gd has `consumable_item_box`: 1
7. player_movement_behavior has `crate_force.gd`: 1
8. player_movement_behavior has `options.consumable_weight`: 1
9. player_movement_behavior has `crate_weight` in _build_context: 1

## Known Stubs

None. All config values flow through to the force pipeline. `ctrl.get_multiplier("crate")` returns 1.0 (safe default via `.get(key, 1.0)`) until Plan 02 adds "crate" to OFFENSIVE_TYPES — this is intentional and documented in the plan, not a stub.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries beyond what the plan's threat model already covers.

## Self-Check

Files created/modified:

- `mods-unpacked/Pasha-AutoBattlerEnhanced/autobattler_options.gd`: EXISTS
- `mods-unpacked/Pasha-AutoBattlerEnhanced/manifest.json`: EXISTS
- `mods-unpacked/Pasha-AutoBattlerEnhanced/translations/autobattler_options.csv`: EXISTS
- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/crate_force.gd`: EXISTS
- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/force_result.gd`: EXISTS
- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/player_movement_behavior.gd`: EXISTS

Commits:

- `15dfd1a`: feat(04-01): add CONSUMABLE_WEIGHT and CRATE_WEIGHT to config stack
- `46b964c`: feat(04-01): create crate_force.gd and wire into movement pipeline

## Self-Check: PASSED

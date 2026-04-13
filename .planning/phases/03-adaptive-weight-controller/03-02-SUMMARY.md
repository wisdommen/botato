---
phase: 03-adaptive-weight-controller
plan: "02"
subsystem: adaptive-ai
tags: [adaptive-ai, ema, gdscript, weight-controller, integration]
dependency_graph:
  requires: [03-01-SUMMARY]
  provides: [AdaptiveWeightController-gdscript, adaptive-multiplier-injection]
  affects: [player_movement_behavior, autobattler_options]
tech_stack:
  added: []
  patterns: [EMA-smoothing, two-group-multiplier-shift, wave-boundary-detection, first-frame-sentinel, standalone-node-child]
key_files:
  created:
    - mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/adaptive_weight_controller.gd
  modified:
    - mods-unpacked/Pasha-AutoBattlerEnhanced/autobattler_options.gd
    - mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/player_movement_behavior.gd
decisions:
  - "First-frame sentinel also updates ema_health_ratio (matches Python port behavior, not just the plan spec description)"
  - "Controller checks players.empty() guard before accessing _players[0] to handle pre-spawn frames"
  - "egg_weight excluded from both groups — passes through unmodified per ADAPT-04 and Pitfall 4"
  - "mod_main.gd untouched — controller is a plain Node child, not a Script Extension"
metrics:
  duration: "8m"
  completed: "2026-04-13"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 2
requirements:
  - ADAPT-01
  - ADAPT-02
  - ADAPT-03
  - ADAPT-04
  - ADAPT-05
---

# Phase 03 Plan 02: GDScript AdaptiveWeightController Integration Summary

GDScript AdaptiveWeightController node created as standalone Node child of AutobattlerOptions, with EMA tracking, two-group multiplier shift, wave reset, and injection of adaptive multipliers into _build_context() for all 6 force types except egg.

## What Was Built

`mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/adaptive_weight_controller.gd` — Production GDScript implementation mirroring the Python port from Plan 01.

- **EMA metrics**: `_ema_damage_rate` and `_ema_health_ratio` smoothed at rate 0.02 per frame via Godot's `lerp()`
- **First-frame sentinel**: `_prev_health = -1.0` prevents spurious damage spike; also updates `ema_health_ratio` on sentinel frame (matching Python port)
- **Two-group multiplier shift**: DEFENSIVE (`projectile`, `boss`, `bumper`) increases toward 1.3 under threat; OFFENSIVE (`consumable`, `item`, `tree`) decreases toward 0.7
- **Wave boundary detection**: `_prev_wave_time_left < 0.05 AND wave_time_left > 1.0` triggers `_reset()`, hard-resetting all EMA and multiplier state
- **Clamping**: all multipliers bounded to `[0.7, 1.3]` via `clamp()`
- **get_multiplier()**: returns `_multipliers.get(force_type, 1.0)` — unknown types (egg) return 1.0 (no-op)
- **Safety guard**: checks `players.empty()` before accessing `_players[0]`

`mods-unpacked/Pasha-AutoBattlerEnhanced/autobattler_options.gd` — Added preload and instantiation:
- `const AdaptiveWeightControllerScript = preload("res://mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/adaptive_weight_controller.gd")`
- `var adaptive_controller` property exposed for `_build_context()` to read
- `_ready()` instantiates controller via `AdaptiveWeightControllerScript.new()` + `add_child(adaptive_controller)` before `reset_defaults()`

`mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/player_movement_behavior.gd` — Injected adaptive multipliers:
- `var ctrl = options.adaptive_controller` cached once per frame (no node lookup per call)
- 6 weight types multiplied: consumable, item, projectile, tree, boss, bumper
- `egg_weight` passes through unmodified

## Task Results

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create AdaptiveWeightController + instantiate in AutobattlerOptions | 48d7f74 | adaptive_weight_controller.gd (new), autobattler_options.gd |
| 2 | Inject adaptive multipliers into _build_context() | 855af01 | player_movement_behavior.gd |

## Verification Results

| Check | Result |
|-------|--------|
| `extends Node` in adaptive_weight_controller.gd | PASS |
| `install_script_extension.*adaptive` in mod_main.gd = 0 | PASS (ADAPT-04) |
| `add_child(adaptive_controller)` in autobattler_options.gd | PASS |
| `get_multiplier` count in player_movement_behavior.gd = 6 | PASS |
| `egg_weight.*options.egg_weight` (no multiplier) | PASS |
| `python3 -m unittest discover tests/ -v` (90/90) | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing safety guard] Added players.empty() check in _process()**

- **Found during:** Task 1 implementation review
- **Issue:** `$"/root/Main"._players[0]` would throw an error if called before the player spawns (pre-wave or loading screen). The Python port has no equivalent guard since the Python simulation always provides player data.
- **Fix:** Added `if players.empty(): return` guard before accessing `_players[0]`
- **Files modified:** `adaptive_weight_controller.gd`
- **Commit:** 48d7f74

**2. [Rule 1 - Behavioral alignment] First-frame sentinel also updates ema_health_ratio**

- **Found during:** Task 1, comparing plan spec vs Python port
- **Issue:** The plan spec says "set `_prev_health = cur_hp` and return (skip first frame)" but the Python port's `_update_ema()` ALSO updates `ema_health_ratio` on the sentinel frame so it starts converging. GDScript must match the Python port (the behavioral contract).
- **Fix:** GDScript `_update_ema` updates `_ema_health_ratio` on the first-frame sentinel path, matching the Python port exactly.
- **Files modified:** `adaptive_weight_controller.gd`
- **Commit:** 48d7f74

## Known Stubs

None. All multipliers computed from live EMA state. No hardcoded return values.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The controller reads from Godot scene tree paths established by existing mod patterns (`$"/root/Main"`, `$"/root/AutobattlerOptions"`).

## Self-Check: PASSED

- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/adaptive_weight_controller.gd` — EXISTS
- `mods-unpacked/Pasha-AutoBattlerEnhanced/autobattler_options.gd` — EXISTS (modified)
- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/player_movement_behavior.gd` — EXISTS (modified)
- Commit `48d7f74` (Task 1) — FOUND
- Commit `855af01` (Task 2) — FOUND
- `python3 -m unittest discover tests/ -v` — 90/90 PASS

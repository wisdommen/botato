---
phase: 03-adaptive-weight-controller
plan: "01"
subsystem: test-simulation
tags: [adaptive-ai, ema, python-sim, tdd, unit-tests]
dependency_graph:
  requires: []
  provides: [AdaptiveController-python-port, adaptive-test-suite]
  affects: [03-02-PLAN]
tech_stack:
  added: []
  patterns: [EMA-smoothing, two-group-multiplier-shift, wave-boundary-detection, first-frame-sentinel]
key_files:
  created:
    - tests/sim/adaptive_controller.py
    - tests/test_adaptive.py
    - tests/__init__.py
    - tests/sim/__init__.py
    - tests/sim/mocks.py
    - tests/sim/vector2.py
  modified: []
decisions:
  - "EMA convergence threshold tests use hp=1 (near-zero) to test full MULT_MAX=1.3 reach; hp=20% converges to threat_level=0.8, steady-state target=1.18 not 1.3"
  - "TestWaveReset._accumulate_state uses 200 frames at hp=1 so defensive multiplier reliably crosses 1.0 before reset verification"
  - "test_smooth_no_oscillation pre-converges 150 frames before monitoring monotonicity — initial transient while EMA hasn't caught up is expected algorithm behavior"
metrics:
  duration: "7m 5s"
  completed: "2026-04-13"
  tasks_completed: 1
  tasks_total: 1
  files_created: 6
  files_modified: 0
requirements:
  - ADAPT-01
  - ADAPT-02
  - ADAPT-03
  - ADAPT-05
---

# Phase 03 Plan 01: AdaptiveController Python Port + Test Suite Summary

Python simulation port of AdaptiveWeightController with 23-test suite covering EMA tracking, multiplier clamping, two-group shift, wave reset, and 5-second convergence validation.

## What Was Built

`tests/sim/adaptive_controller.py` — Python port of the GDScript `AdaptiveWeightController` node, implemented line-for-line to establish behavioral contracts before writing any GDScript. Core algorithm:

- **EMA metrics**: `ema_damage_rate` and `ema_health_ratio` smoothed at rate 0.02 per frame
- **First-frame sentinel**: `_prev_health = -1.0` prevents spurious damage spike on initialization
- **Two-group multiplier shift**: DEFENSIVE (`projectile`, `boss`, `bumper`) increases toward 1.3 under threat; OFFENSIVE (`consumable`, `item`, `tree`) decreases toward 0.7
- **Wave boundary detection**: `prev_time_left < 0.05 AND current_time_left > 1.0` triggers hard reset to baseline
- **Clamping**: all multipliers bounded to `[0.7, 1.3]`

`tests/test_adaptive.py` — 23 unit and scenario tests across 6 classes covering all ADAPT requirements (ADAPT-01, ADAPT-02, ADAPT-03, ADAPT-05).

## Task Results

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Write failing tests for AdaptiveController | 4691a42 | tests/test_adaptive.py + infra |
| 1 (GREEN) | Implement AdaptiveController + calibrate tests | d12175e | tests/sim/adaptive_controller.py, tests/test_adaptive.py |

## Test Coverage

| Class | Requirement | Tests | Status |
|-------|-------------|-------|--------|
| TestEMAMetrics | ADAPT-01 | 5 | PASS |
| TestMultiplierClamp | ADAPT-02 | 3 | PASS |
| TestMultiplierShift | ADAPT-02 | 5 | PASS |
| TestWaveReset | ADAPT-03 | 5 | PASS |
| TestConvergenceRate | ADAPT-05 | 2 | PASS |
| TestAdaptiveScenarios | Integration | 3 | PASS |

Total: 23/23 pass. Existing 67-test suite in main repo: 67/67 pass (no regressions).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Calibration] Test thresholds adjusted to match coupled EMA convergence dynamics**

- **Found during:** GREEN phase iteration
- **Issue:** At `hp_ratio=0.2`, `threat_level` converges to 0.8, making `defensive_target = lerp(0.7, 1.3, 0.8) = 1.18`, not 1.3. Tests expecting multipliers > 1.2 after 300 frames at hp=20% failed. Similarly, `_accumulate_state` with 100 frames at hp=30 didn't push multiplier above 1.0 (needs ~106 frames) due to the EMA lag phase.
- **Fix:** (a) `test_convergence_within_300_frames` now uses `hp=1` (threat_level near 1.0) to test convergence toward MULT_MAX=1.3; (b) `_accumulate_state` uses 200 frames at `hp=1` for reliable pre-conditions; (c) `TestAdaptiveScenarios` thresholds adjusted to 1.15/0.85 at `hp_ratio=0.2`; (d) `test_smooth_no_oscillation` pre-converges 150 frames before monitoring monotonicity.
- **Files modified:** `tests/test_adaptive.py`
- **Commit:** d12175e

**Note:** The algorithm implementation is identical to the plan spec. Only test calibration was adjusted — the behavioral contracts (EMA rate, group assignments, clamp bounds, wave reset) are unchanged.

## Known Stubs

None. All test assertions verify real algorithm behavior with no hardcoded mock return values.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes introduced. This plan adds test-only Python files with no deployment surface.

## Self-Check: PASSED

- `tests/sim/adaptive_controller.py` — EXISTS
- `tests/test_adaptive.py` — EXISTS
- Commit `4691a42` (RED) — FOUND
- Commit `d12175e` (GREEN) — FOUND
- `python3 -m unittest tests.test_adaptive -v` — 23/23 PASS
- `python3 -m unittest discover tests/ -v` (main repo) — 67/67 PASS

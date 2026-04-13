---
phase: 4
slug: new-force-categories-config
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-13
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Python unittest + custom simulation (no in-engine test framework for Godot mods) |
| **Config file** | `tests/` directory (Python simulation tests from Phase 3) |
| **Quick run command** | `python -m pytest tests/ -x --tb=short` |
| **Full suite command** | `python -m pytest tests/ -v --tb=long` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `python -m pytest tests/ -x --tb=short`
- **After each plan completes:** Run full suite
- **Before phase sign-off:** Full suite + manual verification against success criteria

---

## Validation Architecture

### Dimension Coverage

| Dimension | Method | Target |
|-----------|--------|--------|
| 1. Force calculation correctness | Unit tests for crate_force.gd Python port | 100% of new calculator paths |
| 2. Config loading fallback | Unit test: load config without new keys, verify defaults | EXT-06, EXT-07 |
| 3. Weight parameterization | Unit test: consumable_weight slider affects force output | EXT-01 |
| 4. Visualization integration | Verify _type_colors array length matches _calculators length | EXT-04 |
| 5. Setting change propagation | Unit test: setting_changed() updates variable immediately | Success criteria #4 |
| 6. Adaptive integration | Unit test: crate multiplier in offensive group | D-16 |
| 7. Backward compatibility | Integration test: old config file loads without crash | Success criteria #3 |
| 8. Index coupling | Verify calculator order matches color order | Structural integrity |

### Critical Paths

1. `_build_context()` → `ctx.crates` pre-filter → `crate_force.calculate()` → ForceResult
2. `_build_context()` → `ctx.consumable_weight` with user slider → `consumable_force.calculate()`
3. `load_mod_options()` → `get_value(key, default)` for new keys → no crash on old config
4. `setting_changed()` → new key handler → variable update → next physics frame reads new value

### Verification Commands

```bash
# Quick verification: all tests pass
python -m pytest tests/ -x --tb=short

# Full verification: verbose with coverage
python -m pytest tests/ -v --tb=long

# Structural checks
grep -c "def calculate" mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/crate_force.gd
grep -c "CRATE_WEIGHT" mods-unpacked/Pasha-AutoBattlerEnhanced/autobattler_options.gd
grep -c "CONSUMABLE_WEIGHT" mods-unpacked/Pasha-AutoBattlerEnhanced/autobattler_options.gd
```

---
phase: 3
slug: adaptive-weight-controller
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-13
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Python stdlib `unittest` |
| **Config file** | none — existing harness in tests/ |
| **Quick run command** | `python3 -m unittest tests.test_adaptive -v` |
| **Full suite command** | `python3 -m unittest discover tests/ -v` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `python3 -m unittest tests.test_adaptive -v`
- **After every plan wave:** Run `python3 -m unittest discover tests/ -v`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | ADAPT-01 | unit | `python3 -m unittest tests.test_adaptive.TestEMAMetrics -v` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | ADAPT-02 | unit | `python3 -m unittest tests.test_adaptive.TestMultiplierClamp -v` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | ADAPT-03 | unit | `python3 -m unittest tests.test_adaptive.TestWaveReset -v` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | ADAPT-04 | integration | manual verification — node ownership check | N/A | ⬜ pending |
| TBD | TBD | TBD | ADAPT-05 | unit | `python3 -m unittest tests.test_adaptive.TestConvergenceRate -v` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/sim/adaptive_controller.py` — Python port of AdaptiveWeightController
- [ ] `tests/test_adaptive.py` — Test classes for all 5 ADAPT requirements

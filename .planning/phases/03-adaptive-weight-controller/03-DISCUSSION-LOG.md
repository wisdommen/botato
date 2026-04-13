# Phase 3: Adaptive Weight Controller - Discussion Log (Auto Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-04-13
**Phase:** 03-adaptive-weight-controller
**Mode:** auto (assumptions-based, all auto-resolved)
**Areas analyzed:** Performance Metric Data Sources, Wave Boundary Detection, Controller Ownership, Weight Multiplier Integration, EMA Smoothing

## Assumptions Presented

### Performance Metric Data Sources
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Poll player.current_stats.health delta between frames for damage_rate | Confident | player_movement_behavior.gd _build_context() already reads health per frame |
| Use polling-based tracking, no damage signals | Confident | No damage event signals exist in mod codebase |

### Wave Boundary Detection
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Poll _wave_timer.time_left transition from near-zero to high | Likely | ai_canvas.gd line 4 uses same pattern; no wave-start signal available |

Alternatives considered:
- **A:** Poll time_left, detect near-zero→high transition (selected)
- **B:** Connect to Timer.timeout signal (rejected — unverified reliability in modded code)

### Controller Ownership and Architecture
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Child Node of AutobattlerOptions with own _process(delta) | Confident | ADAPT-04 explicit requirement; AutobattlerOptions already has _process |
| Instantiate in autobattler_options.gd _ready() | Confident | Same pattern as main.gd adding AICanvas |
| _process runs before _physics_process in Godot 3.5 | Confident | Standard Godot engine behavior |

### Weight Multiplier Integration
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Apply multipliers in _build_context() ctx dictionary | Confident | All force calculators read from ctx; single integration point |
| Two-group split: defensive up / offensive down under damage | Likely | Matches survival-first core value; consumable_force hp_ratio precedent |

Alternatives considered:
- **A:** Two-group split: defensive vs offensive (selected — recommended)
- **B:** Per-weight independent mapping with individual metric curves (rejected — more complexity, same outcome for v1)

### EMA Smoothing
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| lerp rate ~0.02 per frame, ~3s convergence at 60fps | Confident | ADAPT-05 explicit requirement |
| Hard-reset all accumulators at wave boundary | Confident | ADAPT-03 explicit requirement |

## Corrections Made

No corrections — all assumptions auto-confirmed.

## Auto-Resolved

- Wave boundary detection: auto-selected polling (Alternative A) over signal (Alternative B) — established codebase pattern
- Weight adaptation direction: auto-selected two-group split (Alternative A) over per-weight independent mapping (Alternative B) — simpler, sufficient for v1

## External Research

- Godot 3.5 Timer.timeout reliability: Resolved via codebase pattern analysis — polling is safer for modded code
- Godot 3.5 _process execution order: Resolved via engine knowledge — _process guaranteed before _physics_process

# Roadmap: Botato AI Refactor

## Overview

The refactor proceeds in four stages that mirror how the codebase depends on itself. Phase 1 extracts the force calculation architecture and fixes the hard algorithm bugs — every later phase reads from the ForceResult contract this creates. Phase 2 decouples the visualization layer so it reads from that contract instead of re-computing forces. Phase 3 adds the adaptive weight controller that consumes the effective weights produced by Phase 1. Phase 4 adds new force categories and the ModOptions parameters that expose them, completing the extensibility story.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Force Architecture + Algorithm Fixes** - Extract composable force calculators and fix all hard logic bugs
- [x] **Phase 2: Visualization Decoupling** - Decouple ai_canvas from force math by reading ForceResult contract
- [ ] **Phase 3: Adaptive Weight Controller** - Add EMA-based performance tracking and dynamic weight multipliers
- [ ] **Phase 4: New Force Categories + Config** - Add fruit/crate/boss forces, visualization, and ModOptions exposure

## Phase Details

### Phase 1: Force Architecture + Algorithm Fixes
**Goal**: The AI's force calculation code is extracted into composable units with a shared ForceResult contract, and all known hard logic bugs are fixed
**Depends on**: Nothing (first phase)
**Requirements**: ARCH-01, ARCH-02, ARCH-04, ARCH-05, ARCH-06, ALGO-01, ALGO-02, ALGO-03, ALGO-04
**Plans:** 4 plans

Plans:
- [x] 01-01-PLAN.md — Scaffold forces/ directory, ForceResult contract, rewrite orchestrator
- [x] 01-02-PLAN.md — Create 5 behavior-preserving force calculators (consumable, gold, tree, enemy, boss)
- [x] 01-03-PLAN.md — Create 2 algorithm-fix force calculators (projectile perpendicular dodge, analytical boundary)
- [x] 01-04-PLAN.md — Re-tune default weight values for linear mapping, update manifest.json

**Success Criteria** (what must be TRUE):
  1. Each force type lives in its own file under `forces/` and returns `{vector: Vector2, debug_items: Array}`
  2. `get_movement()` is a context-building + accumulation loop under 30 lines with no inline force math
  3. Adding a new force type requires creating one new file and adding one line to the accumulation loop — verified by tracing the code path
  4. Projectile avoidance moves perpendicular to the projectile's velocity vector, not directly away from it
  5. Two projectiles approaching symmetrically produce a valid (non-cancelling) dodge direction

### Phase 2: Visualization Decoupling
**Goal**: The visualization layer reads the AI's already-computed ForceResult data instead of recalculating forces independently
**Depends on**: Phase 1
**Requirements**: ARCH-03
**Plans:** 1 plan

Plans:
- [x] 02-01-PLAN.md — Rewrite ai_canvas.gd as arrow-based ForceResult reader with per-type colors and boundary wall origins

**Success Criteria** (what must be TRUE):
  1. `ai_canvas.gd` contains no force calculation logic — all vector math is read from `_last_force_results`
  2. Debug arrows in-game match the forces that actually drove the AI decision that frame

### Phase 3: Adaptive Weight Controller
**Goal**: The AI tracks its own performance during a run and smoothly adjusts force weights in response, resetting cleanly at each wave boundary
**Depends on**: Phase 1
**Requirements**: ADAPT-01, ADAPT-02, ADAPT-03, ADAPT-04, ADAPT-05
**Success Criteria** (what must be TRUE):
  1. The damage_rate and health_ratio metrics update every frame via EMA and are readable on the AdaptiveWeightController node
  2. Under sustained damage, effective weights shift within ±30% of their base values over roughly 3 seconds at 60fps
  3. At the start of each new wave, adaptive state resets to baseline with no carry-over from the previous wave
  4. AdaptiveWeightController lives on the AutobattlerOptions node, not in a Script Extension — `_process` is not called twice
**Plans**: TBD

### Phase 4: New Force Categories + Config
**Goal**: Fruit attraction, crate attraction, and boss avoidance are live force types with visualization and ModOptions knobs, and the config system handles old save files gracefully
**Depends on**: Phase 1, Phase 2
**Requirements**: EXT-01, EXT-02, EXT-03, EXT-04, EXT-05, EXT-06, EXT-07
**Success Criteria** (what must be TRUE):
  1. Fruit pickup attraction, crate attraction, and boss avoidance each appear as independent arrows in the AI debug visualization
  2. All three new force weights appear as sliders in the mod settings menu
  3. Loading a save file created before the refactor does not crash — missing keys fall back to defaults
  4. Changing a new parameter via ModOptions takes effect in the next physics frame without restart

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Force Architecture + Algorithm Fixes | 4/4 | Complete | 2026-04-13 |
| 2. Visualization Decoupling | 1/1 | Complete | 2026-04-13 |
| 3. Adaptive Weight Controller | 0/? | Not started | - |
| 4. New Force Categories + Config | 0/? | Not started | - |

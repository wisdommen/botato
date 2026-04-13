# Phase 4: New Force Categories + Config - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 04-new-force-categories-config
**Mode:** Auto (all decisions auto-selected)
**Areas discussed:** Consumable Weight, Crate Entity Discovery, Boss Avoidance Scope, Visualization Integration, Config Backward Compatibility, Adaptive Integration

---

## Consumable Weight Parameterization

| Option | Description | Selected |
|--------|-------------|----------|
| Add CONSUMABLE_WEIGHT slider as base multiplier on top of health-ratio scaling | Preserves health-urgency behavior, adds user control | ✓ |
| Replace health-ratio scaling with pure user slider | Simpler but removes dynamic health urgency | |
| Keep consumable weight hardcoded, no slider | No user control, doesn't satisfy EXT-01 | |

**User's choice:** Add CONSUMABLE_WEIGHT slider as base multiplier (auto-selected, recommended default)
**Notes:** Health-ratio scaling is a core behavior from the original design. Adding a multiplicative base weight gives user control without removing dynamic health urgency.

---

## Crate Entity Discovery

| Option | Description | Selected |
|--------|-------------|----------|
| Researcher investigates Brotato scene tree for crate entities | Necessary — crate container unknown | ✓ |
| Assume crates are in EntitySpawner.neutrals | May work but unverified | |
| Assume crates are a separate container on Main | Possible but needs confirmation | |

**User's choice:** Researcher investigates (auto-selected, recommended default)
**Notes:** The exact scene tree location of crate entities is unknown. Neutrals include trees but may also include crates. Research needed before planning can proceed with implementation details.

---

## Boss Avoidance Scope

| Option | Description | Selected |
|--------|-------------|----------|
| BOSS_WEIGHT already satisfies EXT-03 — no new parameter | Phase 1 separated boss from enemy. Already configurable. | ✓ |
| Add separate BOSS_AVOIDANCE_WEIGHT for repulsion-only tuning | More granular but adds complexity | |
| Rename BOSS_WEIGHT to BOSS_AVOIDANCE_WEIGHT | Misleading — boss force is attract/repel dual behavior | |

**User's choice:** BOSS_WEIGHT already satisfies EXT-03 (auto-selected, recommended default)
**Notes:** EXT-03 asks for "boss avoidance with configurable strength separate from generic enemy weight." Phase 1 already achieved this separation. The success criteria mention "three new force weights as sliders" but boss already has a slider — only consumable and crate are truly new.

---

## Visualization Integration

| Option | Description | Selected |
|--------|-------------|----------|
| Extend Phase 2 arrow-based ai_canvas with new crate color entry | Consistent with existing architecture | ✓ |
| Add separate visualization module for new types | Over-engineered, breaks the indexed array pattern | |

**User's choice:** Extend Phase 2 arrow-based ai_canvas (auto-selected, recommended default)
**Notes:** Crate needs one new color in _type_colors array. Consumable and boss already have visualization. The _calculators and _type_colors arrays must stay index-coupled.

---

## Config Backward Compatibility

| Option | Description | Selected |
|--------|-------------|----------|
| get_value(key, default) fallback — same pattern as existing load | Already proven, no migration code needed | ✓ |
| Explicit version migration with converter | Over-engineered for 2 new keys | |

**User's choice:** get_value(key, default) fallback (auto-selected, recommended default)
**Notes:** The existing load_mod_options() already uses this pattern for all keys. Adding new keys follows the exact same pattern.

---

## Adaptive Integration

| Option | Description | Selected |
|--------|-------------|----------|
| New types join offensive/pickup group in two-group adaptation | Consistent with Phase 3 design. Crate = pickup behavior. | ✓ |
| New types excluded from adaptive system | Simpler but inconsistent, reduces adaptive controller value | |
| New types get their own third adaptation group | Over-scoped for Phase 4 | |

**User's choice:** Join offensive/pickup group (auto-selected, recommended default)
**Notes:** consumable already has adaptive multiplier integration. Crate naturally belongs in the same group (offensive/pickup). Defensive group (projectile, boss, bumper) remains unchanged.

---

## Claude's Discretion

- Exact approach to discovering crate entities in Brotato's scene tree
- Crate force distance cutoff threshold
- UI label text ("Fruit Weight" vs "Consumable Weight")
- Tooltip wording for new sliders

## Deferred Ideas

- Dictionary-based _type_colors keyed by type name (fragile array coupling cleanup)
- Consumable sub-type filtering
- Crate loot quality prediction
- Multi-language UI localization

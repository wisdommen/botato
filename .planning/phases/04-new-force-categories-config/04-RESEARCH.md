# Phase 4: New Force Categories + Config - Research

**Researched:** 2026-04-13
**Domain:** Godot 3.5 mod — new force calculators, config system, Brotato entity taxonomy
**Confidence:** HIGH (core findings verified against Brotato source files; directory state verified against git)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Consumable Weight Parameterization (EXT-01)**
- D-01: Add a `CONSUMABLE_WEIGHT` slider as a base multiplier applied ON TOP of the existing health-ratio scaling. Formula: `force = (direction / dist_sq) * 10.0 * health_ratio_weight * consumable_weight`. Preserves health-urgency behavior while adding user control.
- D-02: `consumable_weight` flows through `_build_context()`: `ctx.consumable_weight = (1.0 - hp_ratio) * 2.0 * options.consumable_weight * ctrl.get_multiplier("consumable")`. Health-ratio stays in `_build_context()`.
- D-03: Default `CONSUMABLE_WEIGHT` = `1.0`. Range: `0.0` to `5.0`.

**Crate/Box Force (EXT-02)**
- D-04: New `crate_force.gd` calculator, simple inverse-distance-squared attraction, no repulsion zone.
- D-05: Researcher MUST investigate entity representation — RESOLVED below.
- D-06: Default `CRATE_WEIGHT` = `0.5`. Range: `0.0` to `10.0`.

**Boss Avoidance Verification (EXT-03)**
- D-07: `BOSS_WEIGHT` already satisfies EXT-03. No new parameter or calculator needed — verification only.
- D-08: Success criteria "three new force weights" = (1) NEW `CONSUMABLE_WEIGHT`, (2) NEW `CRATE_WEIGHT`, (3) EXISTING `BOSS_WEIGHT` verified.

**Visualization Integration (EXT-04)**
- D-09: Extend the Phase 2 arrow-based `ai_canvas.gd` (at `mods-unpacked/Pasha-AutoBattler/extensions/ai_canvas.gd`) with crate color.
- D-10: Crate color: `Color(0.8, 0.6, 0.2, 0.7)` — warm brown/tan.
- D-11: `_type_colors` and `_calculators` arrays must remain index-coupled. Crate is index 7.

**Config System (EXT-05, EXT-06, EXT-07)**
- D-12: New config keys added to `manifest.json`, `autobattler_options.gd`, and CSV translations.
- D-13: Config loading uses `get_value(key, default)` — no migration code needed.
- D-14: New `elif` cases in `setting_changed()` for the new keys.

**Adaptive Weight Integration**
- D-15: `consumable_weight` adaptive chain already exists from Phase 3.
- D-16: `crate_weight` joins the offensive/pickup group. In `_build_context()`: `ctx.crate_weight = options.crate_weight * ctrl.get_multiplier("crate")`. Add "crate" to `OFFENSIVE_TYPES` in `adaptive_weight_controller.gd`.

**Directory State Resolution**
- D-17: Phase 1-2 code tracked under `mods-unpacked/Pasha-AutoBattler/`, Phase 3 additions under `mods-unpacked/Pasha-AutoBattlerEnhanced/`. Planner must decide consolidation strategy. The canonical arrow-based `ai_canvas.gd` is at `Pasha-AutoBattler/extensions/ai_canvas.gd`. The Enhanced directory's `ai_canvas.gd` is the STALE pre-Phase-2 circle-based version and must NOT be used as a base.

### Claude's Discretion
- Exact approach to discovering crate entities in Brotato's scene tree — RESOLVED below.
- Whether to filter neutrals for crate type or use a separate container — RESOLVED below.
- Crate force distance cutoff threshold (if any).
- Exact tooltip text for new ModOptions sliders.
- Whether consumable_weight slider should be labeled "Fruit Weight" or "Consumable Weight" in UI.
- Internal structure of `crate_force.gd` (must follow ForceResult contract).

### Deferred Ideas (OUT OF SCOPE)
- Dictionary-based `_type_colors` keyed by force type name.
- Consumable sub-type filtering (healing vs damage vs utility pickups).
- Crate priority based on loot quality prediction.
- UI label localization for Chinese/other languages.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EXT-01 | Fruit/consumable attraction with configurable weight | `consumable_force.gd` modification pattern verified; formula is `(direction / dist_sq) * 10.0 * consumable_weight`. Update consumable_weight computation in `_build_context()` to multiply by `options.consumable_weight`. |
| EXT-02 | Crate/box attraction with configurable weight | Crates are `Consumable` nodes in `_consumables` with `consumable_data.my_id == "consumable_item_box"` or `"consumable_legendary_item_box"`. New `crate_force.gd` iterates filtered subset of `ctx.consumables`. |
| EXT-03 | Boss avoidance with configurable strength (separate from generic enemy) | Already satisfied by Phase 1's `boss_force.gd` + `BOSS_WEIGHT` slider. Verify via code audit only. |
| EXT-04 | All new force categories have visualization in ai_canvas | Extend `Pasha-AutoBattler/extensions/ai_canvas.gd` `_type_colors` at index 7 with crate color. Consumable and boss already have colors at indices 0 and 5. |
| EXT-05 | ModOptions UI exposes all new parameters | Add `CONSUMABLE_WEIGHT` and `CRATE_WEIGHT` to `manifest.json` config_schema with type/min/max/default/tooltip/format. |
| EXT-06 | Config loading uses `get_value(key, default)` fallback | Pattern already established in `load_mod_options()`. New keys added at end of function with defaults matching D-03 and D-06. |
| EXT-07 | `on_setting_changed()` guards new keys with `has()` check | D-14 clarifies: add `elif` cases in `setting_changed()`. The `has()` guard is for external ModOptions interface calls, not the `setting_changed()` switch chain itself. |
</phase_requirements>

---

## Summary

Phase 4 adds two new force calculators (`crate_force.gd`) and parameterizes an existing one (`consumable_force.gd`), extends the arrow visualization with a crate color, and wires new sliders through the full config stack. The phase is mechanically straightforward because the force architecture (Phase 1), visualization contract (Phase 2), and adaptive system (Phase 3) all exist and work.

**The critical research question — "how are crates represented in Brotato?" — is now resolved with HIGH confidence.** Crates (item boxes) are `Consumable` nodes stored in the same `_consumables` array that `consumable_force.gd` already iterates. They are NOT in `EntitySpawner.neutrals`. Trees are confirmed as the only neutral unit type in Brotato. Crates are distinguishable from fruit by inspecting `consumable.consumable_data.my_id`: fruit has `"consumable_fruit"`, item box has `"consumable_item_box"`, legendary item box has `"consumable_legendary_item_box"`.

**The directory state is also resolved.** The git working tree shows all Phase 1-3 `Pasha-AutoBattler/` files deleted (` D` status) and `Pasha-AutoBattlerEnhanced/` files as untracked (`??`) — meaning Phase 3 performed a directory rename that has not yet been committed. The ONLY file remaining committed in `Pasha-AutoBattler/` is `extensions/ai_canvas.gd` (the canonical arrow-based Phase 2 version). Phase 4 must use `Pasha-AutoBattlerEnhanced/` as the canonical directory for all new files.

**Primary recommendation:** Create `crate_force.gd` in `Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/` that filters `ctx.consumables` by `consumable_data.my_id` for the two crate IDs. Do not use `ctx.neutrals` for crates — that is tree-only.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| GDScript | Godot 3.5 built-in | All mod logic | Engine constraint, no alternative |
| Godot ConfigFile | Godot 3.5 built-in | Persistent settings storage at `user://` | Established pattern from existing `autobattler_options.gd` |
| ModLoader API | 6.0.0 | Script extension registration, translation loading | Mod framework constraint |
| dami-ModOptions | Required dep | In-game UI sliders for mod settings | Established by existing mod |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Python unittest | stdlib | Simulation tests for force calculators | All new force calculators need Python port + tests |

**Installation:** No new packages. All tooling is in-tree or Godot engine built-ins.

---

## Architecture Patterns

### Recommended Project Structure (Phase 4 additions)

```
mods-unpacked/Pasha-AutoBattlerEnhanced/
├── autobattler_options.gd          # Add: consumable_weight, crate_weight vars+consts+cases
├── manifest.json                   # Add: CONSUMABLE_WEIGHT, CRATE_WEIGHT schema entries
├── translations/
│   └── autobattler_options.csv     # Add: label + tooltip keys for 2 new sliders
└── extensions/
    ├── ai_canvas.gd                # STALE — must NOT be used; use Pasha-AutoBattler version
    ├── adaptive_weight_controller.gd  # Add: "crate" to OFFENSIVE_TYPES
    └── entities/units/movement_behaviors/
        ├── player_movement_behavior.gd  # Add: crate_force to _calculators, ctx entries
        └── forces/
            ├── crate_force.gd       # NEW: filters ctx.consumables for crate my_ids
            └── consumable_force.gd  # MODIFY: use ctx.consumable_weight (with user multiplier)

mods-unpacked/Pasha-AutoBattler/extensions/
    └── ai_canvas.gd               # CANONICAL — add crate color at index 7
```

### Pattern 1: Crate Entity Discovery (RESOLVED — D-05)

**What:** Crates are `Consumable` nodes stored in `$"/root/Main/"._consumables`, the same array as fruit. They are distinguished by `consumable.consumable_data.my_id`.

**Verified from:** Brotato source files via `danbopes/BrotatoServer` repository:
- Fruit: `my_id = "consumable_fruit"`, `to_be_processed_at_end_of_wave = false`
- Item Box (crate): `my_id = "consumable_item_box"`, `to_be_processed_at_end_of_wave = true`
- Legendary Item Box: `my_id = "consumable_legendary_item_box"`, `to_be_processed_at_end_of_wave = true`

Trees: `EntitySpawner.neutrals` — trees are the **only** neutral unit type in Brotato. No crates live there.

**Crate filter pattern for `crate_force.gd`:**

```gdscript
# Source: verified from Brotato consumable_data.tres files
const CRATE_IDS = ["consumable_item_box", "consumable_legendary_item_box"]

func calculate(ctx: Dictionary) -> Dictionary:
    var move_vector = Vector2.ZERO
    var debug_items = []
    var player = ctx.player
    var weight = ctx.crate_weight

    for consumable in ctx.consumables:
        if not (consumable.consumable_data.my_id in CRATE_IDS):
            continue
        var to_entity = consumable.position - player.position
        var dist_sq = to_entity.length_squared()
        var force = _safe_force(to_entity, dist_sq, weight)
        if not is_nan(force.x) and not is_nan(force.y):
            move_vector += force
            debug_items.append({
                "position": consumable.position,
                "force_vector": force,
                "weight": weight
            })

    return {"vector": move_vector, "debug_items": debug_items}
```

**Extends:** `res://mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/force_result.gd`

### Pattern 2: Consumable Force Modification (EXT-01)

The existing `consumable_force.gd` uses `ctx.consumable_weight` which is computed in `_build_context()` as `(1.0 - hp_ratio) * 2.0 * ctrl.get_multiplier("consumable")`.

D-02 requires multiplying `options.consumable_weight` into this:

```gdscript
# In player_movement_behavior.gd _build_context():
# BEFORE (Phase 3):
"consumable_weight": (1.0 - (cur_hp / max_hp)) * 2.0 * ctrl.get_multiplier("consumable"),

# AFTER (Phase 4):
"consumable_weight": (1.0 - (cur_hp / max_hp)) * 2.0 * options.consumable_weight * ctrl.get_multiplier("consumable"),
```

`consumable_force.gd` itself is UNCHANGED — it still reads `ctx.consumable_weight` and multiplies by `10.0`.

### Pattern 3: _calculators Array + _type_colors Index Coupling

Current state of `_calculators` in `player_movement_behavior.gd`:
```
[0] consumable_force
[1] gold_force
[2] tree_force
[3] projectile_force
[4] enemy_force
[5] boss_force
[6] boundary_force
```

Phase 4 adds at index 7:
```
[7] crate_force
```

Current `_type_colors` in the canonical `Pasha-AutoBattler/extensions/ai_canvas.gd`:
```gdscript
# [0] consumable: Color(0.2, 0.8, 0.2, 0.7)  green
# [1] gold:       Color(1.0, 0.84, 0.0, 0.7)  gold/yellow
# [2] tree:       Color(0.0, 0.6, 0.4, 0.7)   teal
# [3] projectile: Color(1.0, 0.3, 0.3, 0.7)   red
# [4] enemy:      Color(1.0, 0.5, 0.0, 0.7)   orange
# [5] boss:       Color(0.8, 0.0, 0.0, 0.7)   dark red
# [6] boundary:   Color(0.7, 0.4, 1.0, 0.7)   purple
```

Add at index 7:
```gdscript
# [7] crate:      Color(0.8, 0.6, 0.2, 0.7)   warm brown/tan
```

**CRITICAL:** `BOUNDARY_TYPE_INDEX = 6` is a named constant in the Phase 2 `ai_canvas.gd`. This constant does NOT need updating when crate is added at index 7 — boundary remains at index 6. The `_draw()` loop checks `if i == BOUNDARY_TYPE_INDEX` before calling `_draw_boundary_arrows()`, so appending a new type at index 7 is safe.

### Pattern 4: Config Stack (replicate verbatim for new keys)

**In `autobattler_options.gd`:**
```gdscript
var consumable_weight : float = 1.0
const CONSUMABLE_WEIGHT_OPTION_NAME = "CONSUMABLE_WEIGHT"

var crate_weight : float = 0.5
const CRATE_WEIGHT_OPTION_NAME = "CRATE_WEIGHT"
```

**In `setting_changed()`** (add two `elif` branches before the final `else`):
```gdscript
elif key == CONSUMABLE_WEIGHT_OPTION_NAME:
    consumable_weight = value
elif key == CRATE_WEIGHT_OPTION_NAME:
    crate_weight = value
```

**In `load_mod_options()`** (add two lines after the existing bumper_distance block):
```gdscript
consumable_weight = config.get_value(CONFIG_SECTION, CONSUMABLE_WEIGHT_OPTION_NAME, 1.0)
mod_configs_interface.on_setting_changed(CONSUMABLE_WEIGHT_OPTION_NAME, consumable_weight, MOD_NAME)

crate_weight     = config.get_value(CONFIG_SECTION, CRATE_WEIGHT_OPTION_NAME, 0.5)
mod_configs_interface.on_setting_changed(CRATE_WEIGHT_OPTION_NAME, crate_weight, MOD_NAME)
```

**In `save_configs()`** (add two lines):
```gdscript
config.set_value(CONFIG_SECTION, CONSUMABLE_WEIGHT_OPTION_NAME, consumable_weight)
config.set_value(CONFIG_SECTION, CRATE_WEIGHT_OPTION_NAME,      crate_weight)
```

**In `reset_defaults()`** (add two lines):
```gdscript
consumable_weight = 1.0
crate_weight = 0.5
```

### Pattern 5: AdaptiveWeightController Group Addition

Add "crate" to `OFFENSIVE_TYPES` in `adaptive_weight_controller.gd`:

```gdscript
# BEFORE:
const OFFENSIVE_TYPES = ["consumable", "item", "tree"]

# AFTER:
const OFFENSIVE_TYPES = ["consumable", "item", "tree", "crate"]
```

The `_reset()` function already initializes multipliers for all types in `DEFENSIVE_TYPES + OFFENSIVE_TYPES`, so adding "crate" here automatically initializes `_multipliers["crate"] = 1.0` at reset. No other changes to the adaptive controller are needed.

### Pattern 6: manifest.json Config Schema

```json
"CONSUMABLE_WEIGHT": {
    "type": "number",
    "minimum": 0.0,
    "maximum": 5.0,
    "default": 1.0,
    "tooltip": "CONSUMABLE_WEIGHT_TOOLTIP",
    "format": "%.2f X"
},
"CRATE_WEIGHT": {
    "type": "number",
    "minimum": 0.0,
    "maximum": 10.0,
    "default": 0.5,
    "tooltip": "CRATE_WEIGHT_TOOLTIP",
    "format": "%.2f X"
}
```

### Pattern 7: Translations CSV

Two label rows and two tooltip rows added to `translations/autobattler_options.csv`:

```csv
CONSUMABLE_WEIGHT,Consumable Weight
CRATE_WEIGHT,Crate Weight
CONSUMABLE_WEIGHT_TOOLTIP,"Controls the base strength of fruit/consumable attraction. Higher values cause the bot to prioritize pickups more aggressively."
CRATE_WEIGHT_TOOLTIP,"Controls how strongly the bot is attracted to item boxes (crates). Higher values cause the bot to pursue crates."
```

The label discretion item (fruit vs consumable) is resolved in favor of "Consumable Weight" — the existing consumable_force.gd attracts ALL consumables including fruit, so "Consumable Weight" is more accurate.

### Anti-Patterns to Avoid

- **Using `ctx.neutrals` for crates:** Trees are the ONLY neutral unit. Crates are in `ctx.consumables`, not neutrals. Filtering neutrals for crates would always return empty.
- **Using the Enhanced ai_canvas.gd as base:** The Enhanced directory's `ai_canvas.gd` is the pre-Phase-2 circle-based stale version. All canvas work targets `Pasha-AutoBattler/extensions/ai_canvas.gd`.
- **Registering crate_force.gd in mod_main.gd:** Force files are NOT Script Extensions. They are loaded via `load(...).new()` in `player_movement_behavior.gd._ready()`. Adding them to `mod_main.gd` would cause a ModLoader error.
- **Modifying consumable_force.gd formula:** The `* 10.0` multiplier in `consumable_force.gd` is intentional (D-09). Only `_build_context()` changes for EXT-01, not the calculator.
- **Squaring the new weight values:** D-11 established linear weights throughout Phase 1. New weights must follow the same linear convention.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Crate type detection | Custom node type check or scene name parsing | `consumable.consumable_data.my_id in ["consumable_item_box", "consumable_legendary_item_box"]` | my_id is the stable Brotato identifier for consumable subtypes |
| NaN / division-by-zero guard | Inline check in crate_force | `_safe_force(direction, dist_sq, weight)` from `force_result.gd` | Already implemented, tested, and used by all other calculators |
| Config backward compat | Migration function | `config.get_value(section, key, default)` | ConfigFile.get_value() third parameter is the default; returns default when key missing |

---

## Runtime State Inventory

This phase is greenfield additions (new calculator file, config additions, array append), not a rename/refactor. No runtime state migration is required.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | User config file at `user://pasha-botato-options.cfg` — missing new keys will use defaults | None — ConfigFile.get_value() default handles this automatically (EXT-06) |
| Live service config | None | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | Phase 3 unstaged migration: all Pasha-AutoBattler/ files deleted in git index, Pasha-AutoBattlerEnhanced/ files untracked | The planner must include a Wave 0 task to commit/stage the directory migration before Phase 4 files are added |

**Directory migration state (CRITICAL for planner):**

The git working tree is in a partial-migration state from Phase 3:
- Files showing ` D` (staged deletion): all `Pasha-AutoBattler/` files except `extensions/ai_canvas.gd`
- Files showing `??` (untracked): all `Pasha-AutoBattlerEnhanced/` files

This means `Pasha-AutoBattlerEnhanced/` is the correct canonical directory for Phase 4, but the git state is not committed. The planner should address whether to commit the Phase 3 migration as Wave 0 before adding Phase 4 files, or add Phase 4 files first and commit everything together.

---

## Common Pitfalls

### Pitfall 1: Crate Force Calculator Uses `ctx.neutrals` Instead of `ctx.consumables`

**What goes wrong:** The calculator iterates `ctx.neutrals` (which contains trees only) and finds zero crates, producing a zero force vector every frame.

**Why it happens:** The assumption that "crates are neutral entities" seems intuitive, but Brotato's entity taxonomy classifies all consumables — fruit, item boxes, legendary boxes — as `Consumable` nodes in `_consumables`. Trees are the only neutral unit.

**How to avoid:** Filter `ctx.consumables` by `consumable_data.my_id`. See Architecture Pattern 1 above.

**Warning signs:** Crate force always zero; no crate arrows appear in visualization even when crates are present.

### Pitfall 2: Editing the Enhanced Directory's `ai_canvas.gd` Instead of the Canonical Version

**What goes wrong:** The stale circle-based visualization (in `Pasha-AutoBattlerEnhanced/extensions/ai_canvas.gd`) is modified, but the game is actually running the committed arrow-based version (in `Pasha-AutoBattler/extensions/ai_canvas.gd`). No crate arrows appear.

**Why it happens:** There are two `ai_canvas.gd` files. The Enhanced directory's version is untracked, old code. The canonical version is the committed Phase 2 rewrite in the original `Pasha-AutoBattler` directory.

**How to avoid:** Always target `mods-unpacked/Pasha-AutoBattler/extensions/ai_canvas.gd` for canvas changes.

**Warning signs:** `_type_colors` array has 7 entries but no brown crate color; `_last_force_results` not referenced.

### Pitfall 3: `consumable.consumable_data` Null-Check

**What goes wrong:** A consumable node in `_consumables` has `consumable_data = null` (e.g., during pickup transition), causing a null-reference crash on `.my_id` access.

**Why it happens:** Consumables may be in the pool/transition state when iterated. The Rainbow Crate mod shows that nodes go through `already_picked_up` and `drop()` lifecycle states.

**How to avoid:** Guard the my_id check: `if consumable.consumable_data != null and consumable.consumable_data.my_id in CRATE_IDS`.

**Warning signs:** Occasional null-object crash during play, especially when crates are picked up.

### Pitfall 4: `consumable_force.gd` Attracts Crates Too (Double-Counting)

**What goes wrong:** `consumable_force.gd` already iterates ALL consumables, including crates. Adding `crate_force.gd` means crates are attracted by BOTH calculators — effectively double-weighted.

**Why it happens:** Both calculators share `ctx.consumables`.

**How to avoid:** Two valid approaches:
1. (Recommended) Leave both calculators running. `consumable_force.gd` applies base health-ratio attraction to crates as well. The crate force adds the separate user-configurable weight on top. This is actually correct behavior — crates also heal, so health-urgency attraction is appropriate.
2. (Alternative) Filter consumable_force.gd to exclude crate IDs. This makes `CONSUMABLE_WEIGHT` purely for fruit, and `CRATE_WEIGHT` purely for crates.

The choice is Claude's discretion per CONTEXT.md. Approach 1 preserves simplicity; approach 2 gives cleaner separation. CONTEXT.md D-04 says crates are "always attractive" and heal HP, which aligns with approach 1 — the health-ratio factor is legitimate for crates too.

**Recommendation:** Use approach 1 (no change to consumable_force.gd iteration). Document this in crate_force.gd comments.

### Pitfall 5: Forgetting `ctx.crates` vs Filtering `ctx.consumables`

**What goes wrong:** `_build_context()` adds `ctx.crates` as a pre-filtered list, but then `crate_force.gd` tries to access `ctx.consumables` directly. Or vice versa.

**How to avoid:** Decide one approach and be consistent:
- **Option A:** Pre-filter in `_build_context()`: `ctx.crates = ctx.consumables.filter(...)`. `crate_force.gd` iterates `ctx.crates`.
- **Option B:** No pre-filtering. `crate_force.gd` iterates `ctx.consumables` and skips non-crates.

Option A is recommended — it follows the existing pattern where data is prepared in `_build_context()` and calculators receive clean inputs. Option B requires the calculator to do filtering, which is logic that doesn't belong in the calculator. Either works.

---

## Code Examples

### Complete `crate_force.gd` (verified pattern)

```gdscript
# Source: ForceResult contract verified from force_result.gd;
# Crate entity IDs verified from danbopes/BrotatoServer repository

extends "res://mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/force_result.gd"

# Crate/item-box attraction force.
#
# Crates are Consumable nodes stored in _consumables.
# They are distinguished by consumable_data.my_id:
#   "consumable_item_box"            -- standard crate (20% drop from trees, enemy drops)
#   "consumable_legendary_item_box"  -- legendary crate (elite/boss drop)
#
# Both are always attractive -- break them for item upgrades + 3 HP heal.
# No repulsion zone, no distance cutoff.
#
# D-11: LINEAR -- crate_weight used directly as multiplier.

const CRATE_IDS = ["consumable_item_box", "consumable_legendary_item_box"]

func calculate(ctx: Dictionary) -> Dictionary:
    var move_vector = Vector2.ZERO
    var debug_items = []
    var player = ctx.player
    var weight = ctx.crate_weight

    for consumable in ctx.crates:
        var to_entity = consumable.position - player.position
        var dist_sq = to_entity.length_squared()
        var force = _safe_force(to_entity, dist_sq, weight)
        if not is_nan(force.x) and not is_nan(force.y):
            move_vector += force
            debug_items.append({
                "position": consumable.position,
                "force_vector": force,
                "weight": weight
            })

    return {"vector": move_vector, "debug_items": debug_items}
```

### `_build_context()` additions

```gdscript
# In player_movement_behavior.gd _build_context():
# New keys to add to the returned dict:

# Pre-filter crates from consumables for crate_force.gd
var all_consumables = $"/root/Main/"._consumables
var crate_ids = ["consumable_item_box", "consumable_legendary_item_box"]
var crates = []
for c in all_consumables:
    if c.consumable_data != null and c.consumable_data.my_id in crate_ids:
        crates.append(c)

return {
    # ... existing keys unchanged ...
    # MODIFIED:
    "consumable_weight": (1.0 - (cur_hp / max_hp)) * 2.0 * options.consumable_weight * ctrl.get_multiplier("consumable"),
    # NEW:
    "crates": crates,
    "crate_weight": options.crate_weight * ctrl.get_multiplier("crate"),
}
```

### Simulation test pattern for `crate_force`

```python
# In tests/sim/force_calculators.py — add crate_force function:
CRATE_IDS = {"consumable_item_box", "consumable_legendary_item_box"}

def crate_force(ctx: dict) -> dict:
    move_vector = Vector2(0, 0)
    debug_items = []
    player_pos = ctx["player"].position
    weight = ctx["crate_weight"]

    for consumable in ctx.get("crates", []):
        to_entity = consumable.position - player_pos
        dist_sq = to_entity.length_squared()
        if dist_sq < 0.001:
            dist_sq = 0.001
        force = to_entity.normalized() / dist_sq * weight
        if not force.is_nan():
            move_vector = move_vector + force
            debug_items.append({
                "position": consumable.position,
                "force_vector": force,
                "weight": weight,
            })

    return {"vector": move_vector, "debug_items": debug_items}
```

In `tests/sim/mocks.py` — extend `build_ctx()` to accept `crates` and `crate_weight` parameters:
```python
def build_ctx(
    ...existing params...
    crates: list | None = None,
    crate_weight: float = 1.0,
    consumable_weight: float = 1.0,  # UPDATE: was previously health-ratio only
) -> dict:
    ...
    return {
        ...existing keys...
        "crates": crates or [],
        "crate_weight": crate_weight,
        "consumable_weight": consumable_weight,  # now includes user multiplier
    }
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `consumable_weight` hardcoded to `(1-hp_ratio)*2` | `consumable_weight = (1-hp_ratio)*2 * options.consumable_weight * ctrl.get_multiplier("consumable")` | Phase 4 | User can scale fruit attraction independently of health urgency |
| 7 force calculators | 8 force calculators (adds crate) | Phase 4 | New attraction type for item boxes |
| 7-entry `_type_colors` | 8-entry `_type_colors` | Phase 4 | Crate arrows visible in debug visualization |
| `adaptive_weight_controller.gd` OFFENSIVE_TYPES: `["consumable", "item", "tree"]` | Adds `"crate"` | Phase 4 | Crate weight adapts under threat (decreases when player in danger) |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `consumable.consumable_data.my_id` is accessible on all live consumable nodes | Architecture Pattern 1 | Null-crash if any consumable node lacks consumable_data at iteration time. Mitigated by null-check guard in crate_force.gd. |
| A2 | The crate ID strings `"consumable_item_box"` and `"consumable_legendary_item_box"` are stable across Brotato versions | Architecture Pattern 1 | Crates never attract if IDs changed. Verified from BrotatoServer (Brotato 1.0 source) but future Brotato updates could change IDs. |
| A3 | Leaving `consumable_force.gd` iterating ALL consumables (including crates) is acceptable double-counting behavior | Pitfall 4 | If undesirable, consumable_force.gd would need to skip crate IDs. Low risk — crates heal like fruit, so health-urgency attraction is appropriate for both. |
| A4 | The directory migration (Pasha-AutoBattler → Pasha-AutoBattlerEnhanced) is conceptually "done" and Phase 4 should target Pasha-AutoBattlerEnhanced exclusively | Directory state | If game still loads from Pasha-AutoBattler, changes to Enhanced would have no effect. Risk mitigated by checking mod_main.gd registration (it uses Enhanced). |

---

## Open Questions

1. **Should `consumable_force.gd` be updated to skip crate IDs?**
   - What we know: Currently iterates all consumables; crates also heal (3 HP), making health-ratio attraction legitimate for them.
   - What's unclear: Is double-counting (both consumable_force and crate_force acting on crates) the intended behavior? D-04 says crates are "always attractive" without specifying interaction with existing consumable force.
   - Recommendation: Leave as-is (double-counting). Document it. The combined effect is stronger attraction to crates, which is probably desirable (crates give items + heal). If playtesting shows it's too strong, the planner can add a filter as a follow-up task.

2. **Should `ctx.crates` be pre-filtered in `_build_context()` or filtered in `crate_force.gd`?**
   - What we know: Both work technically. Pre-filtering in context matches the existing pattern (neutrals are already the filtered tree list).
   - Recommendation: Pre-filter in `_build_context()`. This keeps calculators as pure functions with clean inputs, matching the architectural principle.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3 | Simulation tests | Yes | 3.12.3 | — |
| Python unittest | Simulation tests | Yes (stdlib) | stdlib | — |
| pytest | Simulation tests | No (not installed) | — | `python3 -m unittest tests.test_forces` — all 33 tests pass |
| Godot 3.5 | GDScript validation | Not installed on dev machine | — | Simulation tests validate logic; GDScript syntax verified by inspection |

**Test run verified:** `python3 -m unittest tests.test_forces` produces `Ran 33 tests in 0.001s OK` against the current codebase.

**Missing dependencies with no fallback:** None that block the plan.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Python unittest (stdlib, no install required) |
| Config file | none |
| Quick run command | `python3 -m unittest tests.test_forces tests.test_canvas tests.test_scenarios tests.test_adaptive -v` |
| Full suite command | `python3 -m unittest discover tests/ -v` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EXT-01 | `consumable_weight` user multiplier scales attraction | unit | `python3 -m unittest tests.test_forces.TestConsumableForce -v` | Partial — need new test for user-multiplier scaling |
| EXT-02 | `crate_force` attracts toward crates, ignores fruit | unit | `python3 -m unittest tests.test_forces.TestCrateForce -v` | No — Wave 0 gap |
| EXT-03 | `boss_force.gd` exists independently of `enemy_force` | code audit | `grep -n "boss_weight" mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/player_movement_behavior.gd` | Yes (code audit) |
| EXT-04 | `_type_colors` has 8 entries with crate at index 7 | code audit | `grep -c "Color" mods-unpacked/Pasha-AutoBattler/extensions/ai_canvas.gd` | Yes |
| EXT-05 | `manifest.json` has `CONSUMABLE_WEIGHT` and `CRATE_WEIGHT` entries | code audit | `python3 -c "import json; s=json.load(open('mods-unpacked/Pasha-AutoBattlerEnhanced/manifest.json')); print(list(s['extra']['godot']['config_schema']['properties'].keys()))"` | Wave 0 after edits |
| EXT-06 | Old save file loads without crash (missing keys use defaults) | unit | `python3 -m unittest tests.test_config.TestConfigBackwardCompat -v` | No — Wave 0 gap |
| EXT-07 | Unknown keys in `setting_changed()` print warning but don't crash | unit | `python3 -m unittest tests.test_config.TestSettingChanged -v` | No — Wave 0 gap |

### Sampling Rate

- **Per task commit:** `python3 -m unittest tests.test_forces -v`
- **Per wave merge:** `python3 -m unittest discover tests/ -v`
- **Phase gate:** Full suite green + code audits passing before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `tests/test_forces.py::TestCrateForce` — covers EXT-02 (crate attraction, fruit excluded, null consumable_data guard)
- [ ] `tests/test_forces.py::TestConsumableForce::test_user_multiplier_scales_force` — covers EXT-01 (3-factor formula)
- [ ] `tests/sim/force_calculators.py` — add `crate_force()` function, add "crate" support to `ALL_CALCULATORS`, update `build_ctx()` signature
- [ ] `tests/sim/mocks.py` — update `build_ctx()` to accept `crates`, `crate_weight`, update `consumable_weight` to represent user-configurable float
- [ ] `tests/test_config.py` — new file covering EXT-06 (backward compat) and EXT-07 (setting_changed unknown key warning)

---

## Security Domain

No security concerns for this phase. The mod operates entirely within Godot's local process, reads no user input from external sources, writes only to `user://pasha-botato-options.cfg` (a local config file), and has no network operations.

---

## Sources

### Primary (HIGH confidence)

- `danbopes/BrotatoServer` GitHub repository — Brotato consumable entity IDs verified:
  - `fruit_data.tres`: `my_id = "consumable_fruit"`
  - `item_box_data.tres`: `my_id = "consumable_item_box"`, `to_be_processed_at_end_of_wave = true`
  - `legendary_item_box_data.tres`: `my_id = "consumable_legendary_item_box"`
  - `consumable_data.gd`: `class_name ConsumableData extends ItemData`
  - `consumable.gd`: `class_name Consumable extends Item`, has `consumable_data: Resource` property
- `boardengineer/Brotato-Rainbow-Crate` GitHub repository — confirmed crates go into `_consumables` via `_consumables.push_back(consumable)` in `main.gd`
- Brotato Wiki (Trees page) — confirmed "Trees are currently the only Neutral Unit implemented in the game"
- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/player_movement_behavior.gd` — verified current `_build_context()` and `_calculators` array
- `mods-unpacked/Pasha-AutoBattler/extensions/ai_canvas.gd` — verified canonical `_type_colors` array (7 entries, indices 0-6)
- `mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/adaptive_weight_controller.gd` — verified `OFFENSIVE_TYPES` and `get_multiplier()` pattern
- `mods-unpacked/Pasha-AutoBattlerEnhanced/autobattler_options.gd` — verified full config stack (var/const/setting_changed/load/save)
- `mods-unpacked/Pasha-AutoBattlerEnhanced/manifest.json` — verified config_schema structure

### Secondary (MEDIUM confidence)

- Brotato Wiki (Consumables page) — confirmed three consumable types: Fruit, Crate, Legendary Crate
- Brotato Wiki (Loot Crate / Modding Notes pages) — confirmed crates are consumable-type entities

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**
- Crate entity taxonomy: HIGH — verified from Brotato source `.tres` and `.gd` files via GitHub
- Standard stack: HIGH — no new libraries, all patterns established in prior phases
- Architecture patterns: HIGH — all code verified from current working tree
- Pitfalls: HIGH — derived from verified code structure and entity taxonomy
- Directory state: HIGH — verified from git status

**Research date:** 2026-04-13
**Valid until:** Until Brotato game version changes entity IDs (stable since 1.0) or mod framework changes (unlikely 30+ days)

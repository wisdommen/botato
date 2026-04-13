# Plan 02-01 Summary: Rewrite ai_canvas.gd as Arrow-Based ForceResult Reader

**Completed:** 2026-04-13
**Commit:** ba9ad85
**Status:** Task 1 complete; Task 2 (human-verify) PENDING

## What Was Done

Completely rewrote `ai_canvas.gd` from a 275-line monolith that independently replicated all force calculations into a 127-line thin reader that consumes `_last_force_results` from the player's movement behavior node.

### Key Changes

| Aspect | Before | After |
|--------|--------|-------|
| Line count | 275 | 127 |
| Force math | Full replication of all 7 force types | Zero -- reads ForceResult contract |
| Visualization | Circles (size proportional to force) | Arrows (direction + magnitude) |
| Data source | Direct entity container traversal | `_last_force_results` array |
| Weight reads | 6 weight variables from AutobattlerOptions | None (baked into debug_items) |
| Boundary rendering | 4 sampling loops (O(n) per wall) | 0-4 arrows from debug_items |

### New File Structure

1. **Constants**: ARROW_SCALE, ARROW_MAX_LEN, ARROW_MIN_LEN, ARROWHEAD_SIZE, SUM_ARROW_WIDTH, ENTITY_ARROW_WIDTH, BOUNDARY_TYPE_INDEX
2. **Color palette**: 7-entry `_type_colors` array (green/gold/teal/red/orange/dark-red/purple)
3. **`_draw_arrow()`**: Arrow helper with zero-guard, scale, cap, and arrowhead
4. **`_draw_boundary_arrows()`**: Derives wall arrow origin from force_vector direction
5. **`_draw()`**: Wave-end guard, visuals guard, weapon range arc, force result loop with sum accumulation, composite white sum arrow
6. **`_process()`**: Calls `update()` for redraw

### Design Decisions Implemented

- **D-01**: Per-type color mapping (7 distinct colors)
- **D-03**: Arrow-based visualization replacing circles
- **D-04**: Composite sum arrow at player position (white, wider)
- **D-05**: Weapon range arc retained (only standalone computation)
- **D-06**: Boundary wall arrows originate from nearest wall point, not player position

### Deviation

The plan references directory `Pasha-AutoBattlerEnhanced` but the actual git-tracked directory is `Pasha-AutoBattler`. All work was done on the correct path.

## Verification

### Automated (PASSED)

- **Negative check**: 1 match (only `length_squared` zero-guard in `_draw_arrow`) -- zero matches for all 17 other banned patterns
- **Positive check**: 19 matches for required patterns (`_last_force_results`, `_draw_arrow`, `draw_line`, `draw_arc`, `_type_colors`, `sum_vector`, `_draw_boundary_arrows`)
- **Line count**: 127 lines (under 200 limit)

### Human Verification (PENDING)

Task 2 requires in-game visual verification. See checkpoint below.

## Pending Checkpoint: Human In-Game Verification

**Gate:** blocking -- Phase 2 cannot be marked complete until this passes.

Steps for verification:
1. Launch Brotato with the mod enabled
2. Start a new run (any character)
3. Toggle AI on with Shift+Space
4. Enable AI Visuals in the mod options menu (dami-ModOptions)
5. Start a wave and verify:
   - Per-entity arrows render at entity positions with distinct colors per force type
   - Composite white sum arrow at player position matches AI movement direction
   - Weapon range red arc renders around player
   - Boundary wall arrows originate from wall edges (not player center)
   - Arrows disappear cleanly at wave end
   - No crashes or errors in Godot console
   - Arrows update smoothly each frame

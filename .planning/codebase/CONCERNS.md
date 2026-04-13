# Codebase Concerns

**Analysis Date:** 2026-04-13

## Tech Debt

**Duplicate Code in Movement & Visualization Logic:**
- Issue: Core pathfinding calculation repeated verbatim in two separate files with slight differences
- Files: `extensions/ai_canvas.gd` (274 lines), `extensions/entities/units/movement_behaviors/player_movement_behavior.gd` (251 lines)
- Impact: Changes to AI behavior require modifications in two places, increasing bug risk and maintenance burden. Inconsistencies between visual representation and actual movement behavior are difficult to prevent.
- Fix approach: Extract shared vector calculation logic into a utility module. Define weight-based force calculation as a reusable function that both visualization and movement use.

**Large, Complex Files:**
- Issue: Movement behavior and visualization files exceed reasonable bounds (250+ lines each)
- Files: `extensions/ai_canvas.gd` (274 lines), `extensions/entities/units/movement_behaviors/player_movement_behavior.gd` (251 lines)
- Impact: Difficult to test individual force calculations in isolation. Cognitive load high when making changes. No granularity for unit testing different attraction/repulsion forces.
- Fix approach: Split into separate modules: item_weight_calculator, enemy_distance_calculator, projectile_avoidance, bumper_logic, etc. Each module handles one concern.

**Hardcoded Magic Numbers Without Explanation:**
- Issue: Numeric constants scattered throughout code with minimal context
- Files: `extensions/ai_canvas.gd` (lines 30-40, 74-103, 129-135), `extensions/entities/units/movement_behaviors/player_movement_behavior.gd` (lines 36, 42-45, 177-178, 191-192)
- Examples: `1_000_000` (circle size multiplier), `250_000` (projectile distance threshold), `circle_max_size = 100`, `bumper_spacing = 50`
- Impact: Intent of algorithms unclear; impossible to tune behavior without reverse-engineering code. Future maintainers cannot understand design decisions.
- Fix approach: Create a constants file (`ai_behavior_constants.gd`) documenting each magic number with comments explaining physics/balancing intent.

**Incomplete Empty Stub Extension:**
- Issue: `extensions/ui/menus/ingame/upgrades_ui.gd` is installed but contains only boilerplate comments with no actual code
- Files: `extensions/ui/menus/ingame/upgrades_ui.gd` (16 lines of mostly comments)
- Impact: Extension is loaded but provides no functionality, wasting startup resources. Suggests incomplete feature or cleanup oversight.
- Fix approach: Either implement intended UI integration or remove the extension from `mod_main.gd` line 23.

## Known Bugs

**Phantom Projectiles in Visualization:**
- Symptoms: AI visualization draws circles for projectiles that no longer have active hitboxes, creating visual noise and confusing player about true danger zones
- Files: `extensions/ai_canvas.gd` (lines 108-140)
- Trigger: Projectiles become inactive or hitbox removed mid-wave, but visualization loop still processes stale references
- Status: FIXED in commit 876a582 (added hitbox active check on line 111-112), but code review shows pattern risk remains in other collision detection loops
- Current state: Checks for `projectile._hitbox.active` but pattern could recur in similar iteration logic elsewhere

**Potential Null Reference in Enemy AI:**
- Symptoms: Crash if game state changes mid-calculation (e.g., enemy dies while movement vector is being computed)
- Files: `extensions/entities/units/movement_behaviors/player_movement_behavior.gd` (lines 128-145, 156-172)
- Trigger: Enemy killed by another player/projectile between iteration start and vector calculation
- Workaround: Game typically handles this via frame timing, but no explicit null checks present
- Risk: Medium — occurs in loop iteration but game mechanics may naturally prevent simultaneous deletion

**Typo in Coop Service Device Mapping:**
- Issue: `get_remapped_player_device()` returns hardcoded 7 with commented original code
- Files: `extensions/singletons/coop_service.gd` (lines 18-22)
- Impact: All bot players mapped to device 7 regardless of actual device; if this was meant to be dynamic remapping, current code breaks multi-device input
- Fix approach: Uncomment the commented logic and test with actual multi-device setup, or document why device 7 is correct

**Load-Bearing TODO Comment in Focus Handling:**
- Symptoms: Code works but logic is unclear and fragile
- Files: `extensions/ui/menus/global/focus_emulator.gd` (line 31)
- Context: `# TODO explains the player_index == -1 check that seems to be load-bearing`
- Impact: Indicates developer uncertainty about why condition is necessary. Future refactoring could accidentally break this
- Fix approach: Add detailed comment explaining the -1 case with a reference to when it occurs in the game flow

## Security Considerations

**No Input Validation on Config Values:**
- Risk: User config file (`user://pasha-botato-options.cfg`) read without validation
- Files: `autobattler_options.gd` (lines 118-164)
- Current mitigation: ConfigFile.get_value() provides type hints, so severe violations may fail safe
- Recommendations: Explicitly clamp weight values to documented ranges even after loading from file. Add file integrity check or whitelist approach.

**Global Singleton Access Pattern:**
- Risk: Mod directly accesses global game singletons (`$"/root/Main"`, `$"/root/ModLoader"`, `$"/root/AutobattlerOptions"`) via hardcoded paths
- Files: `extensions/ai_canvas.gd` (lines 4-20, 108, 145, 172, 189), `extensions/entities/units/movement_behaviors/player_movement_behavior.gd` (lines 4-5, 25-28)
- Impact: Brittle architecture; if base game restructures scene tree, all mod code breaks. No encapsulation or dependency injection.
- Recommendations: Create a central service locator or dependency injection module that abstracts node access paths

## Performance Bottlenecks

**Repeated Per-Frame Vector Calculations:**
- Problem: Every frame calls normalized() on repeated distance vectors; some calculations performed twice (visualization and movement)
- Files: `extensions/ai_canvas.gd` (lines 62, 81, 93, 131, 156, 179, 204, 224, 244, 264), `extensions/entities/units/movement_behaviors/player_movement_behavior.gd` (lines 62-67, 76, 87, 117, 133, 143)
- Cause: Visualization (`_draw()` called every frame) and movement both independently calculate identical force vectors
- Profile data: Not measured, but potential for 2x redundant vector math with large entity counts (late waves with 100+ enemies)
- Improvement path: Cache shared calculations. Compute force vector once in a frame-global context, share results between systems

**Unbounded Loop Over Zone Boundaries:**
- Problem: Bumper calculation loops hardcoded without early exit optimization
- Files: `extensions/ai_canvas.gd` (lines 194-271), `extensions/entities/units/movement_behaviors/player_movement_behavior.gd` (lines 190-246)
- Issue: 4 while-loops iterate across entire map boundaries by bumper spacing (50 pixels default = ~10-20 iterations per edge at typical map size)
- Impact: O(n) work on zone dimensions, not entity count. With large zones or small spacing, becomes noticeable
- Improvement path: Pre-calculate grid positions or use a quadtree for boundary attraction

**Inefficient Collision Shape Inspection:**
- Problem: Projectile hitbox shape type checked via isinstance for every projectile every frame
- Files: `extensions/ai_canvas.gd` (lines 113-120), `extensions/entities/units/movement_behaviors/player_movement_behavior.gd` (lines 101-108)
- Cause: Shape types determined at runtime instead of cached during projectile creation
- Risk: Negligible impact in practice but pattern indicates lack of caching awareness
- Improvement: Cache shape type as property on projectile when hitbox attached

**Per-Frame String Lookups in Config Interface:**
- Problem: Weight/distance parameters retrieved via string key lookup from dictionary every frame
- Files: `extensions/ai_canvas.gd` (lines 10-28), `extensions/entities/units/movement_behaviors/player_movement_behavior.gd` (lines 4-14)
- Cause: Querying global mod config interface by string every movement calculation
- Alternative approach: Load config once during `_ready()` and use local cached variables
- Improvement: Cache all config values as instance variables, only re-read on setting_changed signal

## Fragile Areas

**Focus Emulator Player Index Logic:**
- Files: `extensions/ui/menus/global/focus_emulator.gd` (lines 25-51)
- Why fragile: Complex state synchronization between multiple players, main player device tracking, and bot flag checking. Magic number player_index == -1 is load-bearing but undocumented. Conditional logic across three different systems (focus control, device mapping, player tracking).
- Safe modification: Add unit tests for all combinations of (main_player_device state, bot_by_index values, connected_players.size()). Document the -1 case explicitly.
- Test coverage: No test files found; this menu interaction logic has zero test coverage

**CoopService State Machine:**
- Files: `extensions/singletons/coop_service.gd` (lines 3-22)
- Why fragile: Maintains `is_bot_by_index` array and `main_player_device/index` with no validation. If array bounds are wrong, crashes occur. No atomic state updates.
- Safe modification: Add bounds checking before accessing is_bot_by_index. Document state invariants (e.g., "main_player_device must be set before adding bot players").
- Test coverage: None

**Bumper Distance Parameter Scaling:**
- Files: `extensions/ai_canvas.gd` (line 192), `extensions/entities/units/movement_behaviors/player_movement_behavior.gd` (line 191)
- Why fragile: Bumper calculation uses raw distance for collision detection (line 192: `bumper_distance * bumper_distance * 40` in visualization). Multiplier 40 appears arbitrary and differs from movement logic (`bumper_distance * bumper_distance` only). These should match but don't.
- Inconsistency: ai_canvas uses `* 40` multiplier, player_movement_behavior doesn't, causing visual bumpers to activate at different range than actual avoidance
- Safe modification: Define single BUMPER_DISTANCE_SCALE constant and apply uniformly

**Character-Specific Logic Hardcoded:**
- Files: `extensions/entities/units/movement_behaviors/player_movement_behavior.gd` (lines 30-45)
- Why fragile: Soldier and Bull character-specific behavior hardcoded by string name comparison. If game adds characters or renames them, logic silently breaks.
- Risk: Medium — affects gameplay for specific characters but not others
- Safe modification: Create a character behavior registry or config system that maps character ID to behavior parameters

## Test Coverage Gaps

**No Unit Tests for AI Force Calculations:**
- What's not tested: All vector force calculations in player_movement_behavior.gd and ai_canvas.gd
- Files: `extensions/entities/units/movement_behaviors/player_movement_behavior.gd`, `extensions/ai_canvas.gd`
- Risk: Logic errors in distance calculations, weight multipliers, or vector normalization undetected. Physics-based AI behavior entirely untested. Changes to core algorithm have no safety net.
- Priority: HIGH — AI movement is the core feature

**No Tests for Config Load/Save:**
- What's not tested: autobattler_options.gd config persistence, default values, setting_changed signal propagation
- Files: `autobattler_options.gd`
- Risk: Config corruption, missing persisted settings, signal relay failures could cause unexpected behavior in menu
- Priority: MEDIUM — menu interaction is secondary to gameplay

**No Integration Tests for Multi-Player State:**
- What's not tested: CoopService state transitions, player device tracking, bot flag management with multiple players
- Files: `extensions/singletons/coop_service.gd`, `extensions/ui/menus/global/focus_emulator.gd`
- Risk: Player joining/leaving, bot addition, and device swaps could leave state inconsistent. Only discovered through live play.
- Priority: MEDIUM

**No Tests for Edge Cases:**
- Untested scenarios:
  - Player with 0 health (consumable_weight calculation could be undefined)
  - No weapons equipped (weapon_range loops over empty list = stays 1000)
  - Map boundary edge cases with bumper logic when player is outside zone
  - Zero weight values in config (divide by zero not prevented in force calculations)
- Priority: MEDIUM

---

*Concerns audit: 2026-04-13*

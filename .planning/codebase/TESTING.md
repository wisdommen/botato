# Testing Patterns

**Analysis Date:** 2026-04-13

## Test Framework

**Runner:**
- No test runner detected
- No test configuration files found (`jest.config.*`, `vitest.config.*`, `pytest.ini`, etc.)
- GDScript testing not configured in this project

**Assertion Library:**
- None detected
- Project appears to use manual testing only

**Run Commands:**
- No automated test commands available
- Testing must be performed manually in Godot engine
- No CI/CD pipeline configuration found

## Test File Organization

**Location:**
- No dedicated `test/` or `tests/` directory
- No `*.test.gd`, `*.spec.gd`, or similar test files found
- Code is not organized for automated testing

**Naming:**
- Not applicable - no test files present

**Structure:**
- Not applicable - no test infrastructure exists

## Code Organization for Testability

**Current State:**
The codebase is **not structured for automated testing**. Key observations:

1. **Tight Coupling to Godot Scene Tree:**
   - Extensive use of `$"/root/..."` global node paths
   - Makes isolation and unit testing extremely difficult
   - Example from `player_movement_behavior.gd`:
     ```gdscript
     var options_node = $"/root/AutobattlerOptions"
     var _entity_spawner = $"/root/Main/EntitySpawner"
     var _consumables_container = $"/root/Main/"._consumables
     ```

2. **Hard Dependencies on Game State:**
   - Direct access to game singletons and services
   - Example from `ai_canvas.gd`:
     ```gdscript
     var ModsConfigInterface = get_node("/root/ModLoader/dami-ModOptions/ModsConfigInterface")
     var player = $"/root/Main"._players[0]
     ```

3. **Engine Lifecycle Dependence:**
   - All state management tied to `_ready()`, `_input()`, `_process()` lifecycle methods
   - Cannot be tested outside Godot engine execution context

4. **External Service Dependencies:**
   - Depends on `ModLoaderMod` from mod loader framework
   - Depends on `RunData`, `ZoneService`, `CoopService` singletons
   - These are game runtime services, not testable without full game context

## Mocking

**Framework:** None

**Patterns:** Not applicable - no mocking infrastructure present

**What to Mock:** Cannot be determined - testing framework not in place

**What NOT to Mock:** Cannot be determined - testing framework not in place

## Fixtures and Factories

**Test Data:**
- No test data fixtures found
- Configuration is loaded from game runtime: `ConfigFile` from `user://pasha-botato-options.cfg`

**Location:**
- Not applicable - no fixtures present

## Manual Testing Coverage

**Areas Being Tested Manually:**

1. **Configuration Management:** (`autobattler_options.gd`)
   - Load/save configuration from file
   - Sync with mod options UI
   - Signal emission on config changes
   - Testing: Manual play-through, changing options in game menu

2. **Movement Behavior:** (`player_movement_behavior.gd`)
   - AI movement calculation based on multiple weighted factors
   - Projectile avoidance
   - Enemy proximity handling
   - Special character behavior (Soldier, Bull)
   - Testing: Visual observation in-game, AI movement quality

3. **Visualization:** (`ai_canvas.gd`)
   - Debug drawing of AI decision factors
   - Circle positioning based on weights
   - Color coding (red for danger, blue for attraction)
   - Testing: Visual verification with AI visuals enabled

4. **UI Integration:** (`player.gd`, `coop_join_panel.gd`, `upgrades_ui.gd`)
   - AI marker visibility
   - Bot instructions display
   - Configuration change handling
   - Testing: Manual interaction during gameplay

5. **Input Handling:** (`focus_emulator.gd`, `autobattler_options.gd`)
   - Keyboard input for toggling autobattler (Shift+Space)
   - Player switching (backtick key)
   - Test data: Manual keyboard input during game

## Coverage Assessment

**Areas With No Automated Testing:**
- Movement algorithm (complex vector math, 250+ lines)
- Configuration persistence (file I/O)
- Signal propagation (event handling)
- UI state management
- Input event processing
- Integration with mod loader framework

**Current Coverage:** 0% (no automated tests exist)

**Required Coverage Target:** 0% (not a requirement for this mod project)

## Known Testing Gaps

**High-Risk Code Without Tests:**

1. **Movement Calculation Logic** (`player_movement_behavior.gd:get_movement()`)
   - 250+ lines of vector math
   - No validation of NaN checking sufficiency
   - Commented-out debug statements suggest prior issues
   - Changes could silently break AI behavior
   - Test gap: No regression tests for movement weights

2. **Configuration Synchronization** (`autobattler_options.gd`)
   - Complex state sync between local variables, ConfigFile, and mod options UI
   - 12 different configuration parameters
   - Risk: Config mismatch between UI and actual behavior
   - Test gap: No verification that UI changes actually affect behavior

3. **Special Character Logic** (`player_movement_behavior.gd`)
   - Soldier and Bull characters have conditional behavior
   - Example:
     ```gdscript
     if is_soldier:
         return Vector2.ZERO  # Soldier doesn't move when shooting
     ```
   - Test gap: No coverage that this only applies to Soldier

4. **Phantom Projectile Bug Fix** (referenced in git log)
   - Bug "Fix phantom projectiles" was fixed (commit 876a582)
   - No test prevents regression
   - Test gap: No verification that fix still works in new code paths

## Type Safety

**Type System:**
- GDScript 2.0 (Godot 4.x) or GDScript 1.0 (Godot 3.x) - version unclear
- Uses optional type hints for critical parameters
- Many variables lack explicit type annotations

**Type Coverage:**
```gdscript
# Well-typed function signature
func setting_changed(key:String, value, mod) -> void:

# Implicit typing (no annotations)
var player = get_parent()
var move_vector = Vector2.ZERO  # Type inferred from literal
var item_weight = 0.5  # Type inferred from assignment
```

**Validation:**
- No static type checking tool configured
- No LSP (Language Server Protocol) integration detected
- Type errors only caught at runtime

## Testing Barriers

**Why This Project Isn't Tested:**

1. **Game Engine Dependence:** Godot mods must run in engine context
2. **Mod Framework:** Relies on `ModLoaderMod` framework from Brotato mod system
3. **Scene Tree Access:** Uses global node paths impossible to mock
4. **Runtime Configuration:** Loads game state at startup
5. **No Testing Culture:** Mod projects typically rely on manual testing

**Realistic Alternatives:**
- Manual testing with debug visualization enabled
- Git commit history as implicit test (regressions caught in play-testing)
- Visual regression by comparing AI behavior across versions

## Recommended Future Testing Strategy

If testing were to be added:

1. **Extract Business Logic:**
   ```gdscript
   # Move NaN checking to reusable function
   func is_valid_vector(v: Vector2) -> bool:
       return not is_nan(v.x) and not is_nan(v.y)
   
   # Extract weight calculations
   func calculate_movement_force(distance: float, weight: float) -> float:
       # Pure function, testable independently
   ```

2. **Dependency Injection:**
   ```gdscript
   # Instead of: var options = $"/root/AutobattlerOptions"
   # Use: var options: AutobattlerOptions
   # Passed in via constructor or _init()
   ```

3. **Static Helper Methods:**
   ```gdscript
   # Create static utility module for calculations
   static func calculate_vector_weight(
       entity_pos: Vector2,
       player_pos: Vector2,
       weight: float,
       range_squared: float
   ) -> Vector2:
       # Pure function, easily testable
   ```

4. **Integration Tests:**
   - Test mod loading with ModLoaderMod
   - Test configuration file I/O
   - Test signal emission chains

---

*Testing analysis: 2026-04-13*

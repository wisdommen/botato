# Coding Conventions

**Analysis Date:** 2026-04-13

## Naming Patterns

**Files:**
- Extension modules use clear, descriptive names reflecting their purpose
- Example: `player_movement_behavior.gd`, `coop_join_panel.gd`, `autobattler_options.gd`
- Convention: `snake_case` with no abbreviations
- Paths follow domain hierarchy: `extensions/entities/units/player/player.gd`

**Functions:**
- Use `snake_case` for all function names
- Convention: Prefixed with underscore for lifecycle methods (`_ready()`, `_input()`, `_process()`)
- Public methods use action-based names: `get_movement()`, `on_setting_changed()`, `load_mod_options()`
- Examples from codebase:
  - `get_remapped_player_device()` - returns a value
  - `setting_changed()` - handles configuration changes
  - `save_configs()` - performs side effects
  - `reset_defaults()` - restores initial state

**Variables:**
- Use `snake_case` for all variable names
- Constants use `SCREAMING_SNAKE_CASE`
- Example: `enable_autobattler`, `item_weight`, `squared_distance_to_item`
- Configuration option constants pair with corresponding variables:
  ```gdscript
  var enable_autobattler : bool = false
  const ENABLE_AUTOBATTLER_OPTION_NAME = "ENABLE_AUTOBATTLER"
  ```
- Magic numbers stored in named constants: `DEFAULT_COOLDOWN = .2`, `circle_max_size = 100`

**Types:**
- GDScript uses implicit typing, but code shows type hints in function signatures
- Example: `func setting_changed(key:String, value, mod) -> void:`
- Return types explicitly declared with `->`
- Some parameters use implicit types when obvious from context

## Code Style

**Formatting:**
- No formal formatter detected (no Prettier, .prettierrc, or ESLint config)
- Indentation: Tabs (default GDScript style, 2-4 spaces equivalent)
- Line length: Some lines exceed 100 characters without wrap enforcement
- Spacing: Consistent spacing around operators

**Linting:**
- No formal linting tool configured
- Code follows GDScript conventions informally
- Some inconsistencies in comment formatting (see examples below)
- No automated checks for code quality detected

## Import Organization

**Order:**
1. Extends declarations (engine classes or mod-loader base classes)
2. Preload constants (scene/script references)
3. Member variables
4. Signal declarations
5. Functions (lifecycle first, then public, then private)

**Pattern Example from `main_menu.gd`:**
```gdscript
extends "res://ui/menus/pages/main_menu.gd"

const AutobattlerOptions = preload("res://mods-unpacked/Pasha-AutoBattler/autobattler_options.gd")

func _ready():
    var options_node = AutobattlerOptions.new()
    # ...
```

**Path Aliases:**
- Uses Godot's `res://` prefix for resource paths
- Absolute paths within mod structure: `res://mods-unpacked/Pasha-AutoBattler/`
- Node paths use `$"/root/..."` for global node access

## Error Handling

**Patterns:**
- Minimal explicit error handling in observable code
- Silent returns on missing dependencies: If ModOptions not available, functions return early
- Example from `autobattler_options.gd`:
  ```gdscript
  if not get_node("/root/ModLoader").has_node("dami-ModOptions"):
      return
  ```
- Validates node existence before accessing properties
- No try-catch patterns (GDScript uses assertions and early returns)
- Debug prints used for warnings: `print_debug("WARNING, UNKNOWN CHANGE ", key)`

## Logging

**Framework:** Built-in `print_debug()` function

**Patterns:**
- Used sparingly for debugging and warnings
- Example: `print_debug("bumper distnace: ", bumper_distance)` (note typo in variable name)
- Only console output, no persistent logs
- Development-time debugging only (commented-out debug calls exist)

## Comments

**When to Comment:**
- Minimal commenting in observed code
- Comments used for clarifying non-obvious logic
- Example: `# Weigh down nearby trees to keep from getting stuck on them`

**JSDoc/TSDoc:**
- Not used (GDScript alternative would be docstrings, but none observed)
- Type hints in function signatures provide minimal documentation

**Comment Quality:**
- Some outdated or incomplete comments exist
- Example in `coop_join_panel.gd`: Comment references "botato" instructions but code shows general instructions handling
- Comments sometimes explain "why" rather than "what": `# Disable "wrong" players from using input`

## Function Design

**Size:**
- Functions range from 3 to 250+ lines
- Example small functions: `get_remapped_player_device()` (2 lines), `_ready()` variations (3-10 lines)
- Large functions: `get_movement()` in `player_movement_behavior.gd` (250+ lines)
- Longest file: `ai_canvas.gd` with 275 lines of single `_draw()` method

**Parameters:**
- Functions use explicit parameter lists, not vargs
- Type hints for critical parameters
- Example: `func setting_changed(key:String, value, mod) -> void:`

**Return Values:**
- Clear return types declared with `->`
- Return patterns:
  - `Vector2` for movement calculations
  - `void` for event handlers
  - `int` for index calculations
- Early returns used for guard conditions

## Module Design

**Exports:**
- Classes exported implicitly through script extension mechanism
- `ModLoaderMod.install_script_extension()` used to register behavior modifications
- Example: `mod_main.gd` registers 7+ extension scripts

**Barrel Files:**
- No barrel/index files observed
- Each extension handles single responsibility

**File Organization Principle:**
- One module per file
- Extensions separate from base implementation
- Configuration isolated to dedicated modules (`autobattler_options.gd`)

## Special Conventions

**Godot-Specific Patterns:**

1. **Extension Pattern:** Files use `extends "path/to/base.gd"` to inject behavior
   - Allows non-invasive modifications to base game code
   - Used heavily in this mod architecture

2. **Node Paths:** Global access via `$"/root/..."` for singletons and managers
   ```gdscript
   var options_node = $"/root/AutobattlerOptions"
   var entity_spawner = $"/root/Main/EntitySpawner"
   ```

3. **Signals:** Godot-style event system
   ```gdscript
   signal setting_changed(setting_name, value, mod_name)
   options_node.connect("setting_changed", self, "on_setting_changed")
   ```

4. **Lifecycle Methods:** `_ready()`, `_input()`, `_process()`, `_draw()` are virtual methods
   - Called automatically by engine
   - Prefix convention makes them easily recognizable

5. **Type Inference:** Variables often lack explicit types, relying on assignment inference
   ```gdscript
   var canvas_layer  # Type inferred from AICanvas.new()
   var player = get_parent()  # Type from context
   ```

## Common Issues Observed

1. **Inconsistent NaN Checks:** Repeated patterns like `if not is_nan(to_add.x) and not is_nan(to_add.y):`
   - Could be extracted to utility function

2. **Duplicate Logic:** Movement calculation logic duplicated between `player_movement_behavior.gd` (actual movement) and `ai_canvas.gd` (visualization)
   - Both implement same weighting algorithm independently

3. **Magic Numbers:** Hardcoded values throughout code
   - `1_000` for weapon range
   - `100` for arc circles
   - `250_000` for projectile distance threshold
   - These are sometimes named, sometimes not

4. **Commented Code:** Several `#func _process(delta):` and `#pass` patterns suggest incomplete extensions or cleanup

---

*Convention analysis: 2026-04-13*

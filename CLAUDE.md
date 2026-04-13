<!-- GSD:project-start source:PROJECT.md -->
## Project

**Botato AI Refactor**

Pasha-AutoBattler 是 Brotato（土豆兄弟）的 AI 自动战斗 Mod，为玩家提供 AI 自动操作功能，包含可视化决策展示和合作模式支持。当前版本存在核心 AI 逻辑缺陷和扩展性不足的问题，需要从架构层面进行全面重构升级。

**Core Value:** AI 必须在复杂战斗场景中做出正确的生存决策 — 正确闪避弹幕、智能适应难度变化、提供足够的行为调节维度。

### Constraints

- **引擎版本**: Godot 3.5 — Brotato 使用 Godot 3.5 构建，所有代码必须兼容此版本
- **Mod 框架限制**: Script Extensions 不能重定义成员变量、不能替换虚函数、不能修改预加载脚本
- **性能**: 所有 AI 计算在 `_physics_process` 中逐帧执行，必须保持高性能（当前使用距离平方避免 sqrt）
- **兼容性**: 必须兼容 Brotato 1.1.10.4+，不破坏现有 ModOptions 配置
- **无外部依赖**: 不能引入 Brotato/Godot 生态之外的库
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- GDScript - Godot's built-in scripting language used for all mod logic
- GDShader - Godot shader language for visual effects (if any used)
- JSON - Configuration and manifest files
## Runtime
- Godot Engine 4.x (mod loader compatible version 6.0.0)
- Brotato game version 0.8.0.3 or later
- Steam/Windows (Brotato is a Steam game)
## Frameworks
- Brotato Game Engine - Base game framework that the mod extends
- ModLoader - Godot mod loading framework (version 6.0.0 compatible)
- ContentLoader - Required dependency for content management
- Mod Options (dami-ModOptions) - Required dependency for mod configuration UI and settings management
## Key Dependencies
- ModLoaderMod - Core mod loading API for script extensions and translation management
- ConfigFile - Godot's built-in configuration file system for persistent settings storage
- Node2D - Godot's 2D rendering system for AI visualization canvas
- InputEvent system - Godot's input handling for keyboard shortcuts and player control
- Godot Signals - Event system for setting changes and callbacks
- Godot Scene System (*.tscn) - For UI scenes and AI visualization overlay
- Translation System - For multi-language support in mod options
## Configuration
- Local config file storage at `user://pasha-botato-options.cfg`
- ConfigFile format with sections and key-value pairs
- Runtime options in Mod Options menu (accessed through dami-ModOptions interface)
- No build configuration needed - pure GDScript mod
- Mod metadata in `manifest.json` defining version, dependencies, and config schema
- Schema-based configuration system in manifest for in-game options UI
- Location: `mods-unpacked/Pasha-AutoBattler/manifest.json`
- Defines mod metadata, version (1.3.0), game compatibility (Brotato 0.8.0.3+)
- Includes JSON schema for 10 configurable AI behavior parameters
- Config parameters: enable_autobattler, enable_ai_visuals, enable_ai_marker, enable_smoothing, smoothing_speed, item_weight, projectile_weight, tree_weight, boss_weight, bumper_weight, egg_weight, bumper_distance
## Platform Requirements
- Godot Engine 4.x installed
- Text editor for GDScript files (.gd)
- Optional: Godot editor for testing mods in-game
- Brotato game client (Steam)
- ModLoader mod installed from Steam workshop
- ContentLoader mod installed from Steam workshop
- Mod Options mod installed from Steam workshop
- Game data files and assets from Brotato installation
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Extension modules use clear, descriptive names reflecting their purpose
- Example: `player_movement_behavior.gd`, `coop_join_panel.gd`, `autobattler_options.gd`
- Convention: `snake_case` with no abbreviations
- Paths follow domain hierarchy: `extensions/entities/units/player/player.gd`
- Use `snake_case` for all function names
- Convention: Prefixed with underscore for lifecycle methods (`_ready()`, `_input()`, `_process()`)
- Public methods use action-based names: `get_movement()`, `on_setting_changed()`, `load_mod_options()`
- Examples from codebase:
- Use `snake_case` for all variable names
- Constants use `SCREAMING_SNAKE_CASE`
- Example: `enable_autobattler`, `item_weight`, `squared_distance_to_item`
- Configuration option constants pair with corresponding variables:
- Magic numbers stored in named constants: `DEFAULT_COOLDOWN = .2`, `circle_max_size = 100`
- GDScript uses implicit typing, but code shows type hints in function signatures
- Example: `func setting_changed(key:String, value, mod) -> void:`
- Return types explicitly declared with `->`
- Some parameters use implicit types when obvious from context
## Code Style
- No formal formatter detected (no Prettier, .prettierrc, or ESLint config)
- Indentation: Tabs (default GDScript style, 2-4 spaces equivalent)
- Line length: Some lines exceed 100 characters without wrap enforcement
- Spacing: Consistent spacing around operators
- No formal linting tool configured
- Code follows GDScript conventions informally
- Some inconsistencies in comment formatting (see examples below)
- No automated checks for code quality detected
## Import Organization
- Uses Godot's `res://` prefix for resource paths
- Absolute paths within mod structure: `res://mods-unpacked/Pasha-AutoBattler/`
- Node paths use `$"/root/..."` for global node access
## Error Handling
- Minimal explicit error handling in observable code
- Silent returns on missing dependencies: If ModOptions not available, functions return early
- Example from `autobattler_options.gd`:
- Validates node existence before accessing properties
- No try-catch patterns (GDScript uses assertions and early returns)
- Debug prints used for warnings: `print_debug("WARNING, UNKNOWN CHANGE ", key)`
## Logging
- Used sparingly for debugging and warnings
- Example: `print_debug("bumper distnace: ", bumper_distance)` (note typo in variable name)
- Only console output, no persistent logs
- Development-time debugging only (commented-out debug calls exist)
## Comments
- Minimal commenting in observed code
- Comments used for clarifying non-obvious logic
- Example: `# Weigh down nearby trees to keep from getting stuck on them`
- Not used (GDScript alternative would be docstrings, but none observed)
- Type hints in function signatures provide minimal documentation
- Some outdated or incomplete comments exist
- Example in `coop_join_panel.gd`: Comment references "botato" instructions but code shows general instructions handling
- Comments sometimes explain "why" rather than "what": `# Disable "wrong" players from using input`
## Function Design
- Functions range from 3 to 250+ lines
- Example small functions: `get_remapped_player_device()` (2 lines), `_ready()` variations (3-10 lines)
- Large functions: `get_movement()` in `player_movement_behavior.gd` (250+ lines)
- Longest file: `ai_canvas.gd` with 275 lines of single `_draw()` method
- Functions use explicit parameter lists, not vargs
- Type hints for critical parameters
- Example: `func setting_changed(key:String, value, mod) -> void:`
- Clear return types declared with `->`
- Return patterns:
- Early returns used for guard conditions
## Module Design
- Classes exported implicitly through script extension mechanism
- `ModLoaderMod.install_script_extension()` used to register behavior modifications
- Example: `mod_main.gd` registers 7+ extension scripts
- No barrel/index files observed
- Each extension handles single responsibility
- One module per file
- Extensions separate from base implementation
- Configuration isolated to dedicated modules (`autobattler_options.gd`)
## Special Conventions
## Common Issues Observed
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Extension-based architecture leveraging Godot's script inheritance system
- ModLoader integration for seamless game modification
- Weights-based steering behavior system with configurable parameters
- Separation of concerns between movement AI, visualization, configuration, and UI
## Layers
- Purpose: Centralized configuration management, persistence, and signal broadcasting
- Location: `mods-unpacked/Pasha-AutoBattler/autobattler_options.gd`
- Contains: Option state management, default values, save/load logic, configuration file I/O
- Depends on: Godot ConfigFile API, ModOptions system
- Used by: Movement behavior, visualization, UI extensions, player extensions
- Purpose: Compute steering vector based on weighted forces from game entities
- Location: `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/player_movement_behavior.gd`
- Contains: Force accumulation from consumables, items, projectiles, enemies, bosses, map boundaries
- Depends on: AutobattlerOptions, EntitySpawner, Player state, ZoneService, Enemy AI detection (ChargingAttackBehavior)
- Used by: Player movement system (overrides parent class)
- Purpose: Render debug circles and overlays to show AI decision-making weights visually
- Location: `mods-unpacked/Pasha-AutoBattler/extensions/ai_canvas.gd`
- Contains: Draw calls for weighted entities, circle size calculations based on distance squared
- Depends on: AutobattlerOptions, movement calculation logic (mirrors force computations)
- Used by: Main scene (added as child node)
- Purpose: Inject AI marker visuals, camera smoothing configuration, settings change handling
- Location: `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/player/player.gd`
- Contains: AI icon scene instantiation, marker visibility toggle, camera smoothing parameter updates
- Depends on: AutobattlerOptions, AI marker scene (AIScene.tscn), Camera node
- Used by: Player entity (overrides parent class)
- Purpose: Enable bot/human player switching in cooperative mode, handle multi-player input coordination
- Location: `mods-unpacked/Pasha-AutoBattler/extensions/singletons/coop_service.gd` and `mods-unpacked/Pasha-AutoBattler/extensions/ui/menus/global/focus_emulator.gd`
- Contains: Bot-by-player tracking, device remapping, player index management, keyboard shortcut handling (F1, backtick)
- Depends on: Player type enums, keyboard input system
- Used by: Menu systems, character selection, in-game focus management
- Purpose: ModLoader initialization and script extension registration
- Location: `mods-unpacked/Pasha-AutoBattler/mod_main.gd`
- Contains: Extension file registration, translation loading
- Depends on: ModLoaderMod API
- Used by: Godot ModLoader framework
- Purpose: Attach AI canvas to main game scene, provide empty overrides for UI extensibility
- Location: `mods-unpacked/Pasha-AutoBattler/extensions/main.gd`, UI menu overrides
- Contains: Canvas layer creation/cleanup
- Depends on: AICanvas, inherited parent scenes
- Used by: Game scenes during _ready() callbacks
## Data Flow
## Key Abstractions
- Purpose: Represent attraction/repulsion to/from game entities as 2D vectors
- Examples: `player_movement_behavior.gd` lines 55-251
- Pattern: `to_add = (direction.normalized() / distance_squared) * weight`
- Accumulation: Forces summed into `move_vector`, then normalized before return
- Purpose: Avoid expensive sqrt() calls while maintaining proper inverse-distance falloff
- Examples: `squared_distance_to_item`, `squared_distance_to_projectile`
- Pattern: Compare squared distances to squared thresholds; multiply squared distances for weighting
- Impact: Critical for per-frame performance with 100+ entities
- Purpose: Maintain safe combat distance by using minimum of equipped weapons' max_range
- Examples: `player_movement_behavior.gd` lines 47-53
- Pattern: Iterate weapons, track minimum range as `preferred_distance_squared`
- Usage: Determines when to attack (close) vs. maintain distance (far)
- Purpose: Global configuration access without string-key lookups
- Examples: `$"/root/AutobattlerOptions"` accessed from movement behavior, UI, visualization
- Pattern: Create constant OPTION_NAME for each setting, mirror in node variable for fast lookup
- Benefit: Reduces ModOptions config interface calls, improves performance
- Purpose: Handle character class variations (Soldier freezes when shooting, Bull adjusts range)
- Examples: `player_movement_behavior.gd` lines 30-45
- Pattern: Query character name from `RunData.get_player_character()`, branch on is_soldier/is_bull
- Extensibility: New characters can be added with additional elif branches
## Entry Points
- Location: `mods-unpacked/Pasha-AutoBattler/mod_main.gd`
- Triggers: ModLoader framework initialization
- Responsibilities: Register script extensions, load translations, setup mod metadata
- Location: `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/player_movement_behavior.gd`
- Triggers: Every frame when player input processed, called by Godot physics
- Responsibilities: Compute AI steering vector or delegate to parent class
- Location: `manifest.json` config_schema
- Triggers: ModOptions menu system
- Responsibilities: Define settable parameters, tooltips, min/max ranges, validation
- Shift+Space: Toggle autobattler enable (in `autobattler_options.gd`)
- F1: Add bot player to coop (in `coop_service.gd`)
- Backtick (`): Rotate player focus (in `focus_emulator.gd`)
## Error Handling
- NaN checks before applying force vector: `if not is_nan(to_add.x) and not is_nan(to_add.y)`
- Distance floor to prevent division by zero: `if squared_distance_to_item < 0: squared_distance_to_item = .001`
- Safe projectile shape detection: `if not projectile._hitbox or not projectile._hitbox.active`
- Graceful fallback to parent class when options system unavailable
## Cross-Cutting Concerns
- Inverse distance squared weighting over frame-by-frame integration
- Circular force field approximation (no pathfinding)
- Wave-end render skip (if wave_timer < 0.05s)
- Distance thresholds to zero out forces beyond effective range
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->

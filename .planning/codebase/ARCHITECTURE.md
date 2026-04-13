# Architecture

**Analysis Date:** 2026-04-13

## Pattern Overview

**Overall:** Godot Mod Extension Pattern (Script Override Architecture)

**Key Characteristics:**
- Extension-based architecture leveraging Godot's script inheritance system
- ModLoader integration for seamless game modification
- Weights-based steering behavior system with configurable parameters
- Separation of concerns between movement AI, visualization, configuration, and UI

## Layers

**Configuration & Options:**
- Purpose: Centralized configuration management, persistence, and signal broadcasting
- Location: `mods-unpacked/Pasha-AutoBattler/autobattler_options.gd`
- Contains: Option state management, default values, save/load logic, configuration file I/O
- Depends on: Godot ConfigFile API, ModOptions system
- Used by: Movement behavior, visualization, UI extensions, player extensions

**AI Movement Calculation:**
- Purpose: Compute steering vector based on weighted forces from game entities
- Location: `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/player_movement_behavior.gd`
- Contains: Force accumulation from consumables, items, projectiles, enemies, bosses, map boundaries
- Depends on: AutobattlerOptions, EntitySpawner, Player state, ZoneService, Enemy AI detection (ChargingAttackBehavior)
- Used by: Player movement system (overrides parent class)

**AI Visualization:**
- Purpose: Render debug circles and overlays to show AI decision-making weights visually
- Location: `mods-unpacked/Pasha-AutoBattler/extensions/ai_canvas.gd`
- Contains: Draw calls for weighted entities, circle size calculations based on distance squared
- Depends on: AutobattlerOptions, movement calculation logic (mirrors force computations)
- Used by: Main scene (added as child node)

**Player Integration:**
- Purpose: Inject AI marker visuals, camera smoothing configuration, settings change handling
- Location: `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/player/player.gd`
- Contains: AI icon scene instantiation, marker visibility toggle, camera smoothing parameter updates
- Depends on: AutobattlerOptions, AI marker scene (AIScene.tscn), Camera node
- Used by: Player entity (overrides parent class)

**Cooperative Multiplayer Support:**
- Purpose: Enable bot/human player switching in cooperative mode, handle multi-player input coordination
- Location: `mods-unpacked/Pasha-AutoBattler/extensions/singletons/coop_service.gd` and `mods-unpacked/Pasha-AutoBattler/extensions/ui/menus/global/focus_emulator.gd`
- Contains: Bot-by-player tracking, device remapping, player index management, keyboard shortcut handling (F1, backtick)
- Depends on: Player type enums, keyboard input system
- Used by: Menu systems, character selection, in-game focus management

**Main Entry Point:**
- Purpose: ModLoader initialization and script extension registration
- Location: `mods-unpacked/Pasha-AutoBattler/mod_main.gd`
- Contains: Extension file registration, translation loading
- Depends on: ModLoaderMod API
- Used by: Godot ModLoader framework

**Scene Extensions:**
- Purpose: Attach AI canvas to main game scene, provide empty overrides for UI extensibility
- Location: `mods-unpacked/Pasha-AutoBattler/extensions/main.gd`, UI menu overrides
- Contains: Canvas layer creation/cleanup
- Depends on: AICanvas, inherited parent scenes
- Used by: Game scenes during _ready() callbacks

## Data Flow

**Initialization Flow:**
1. `mod_main.gd` registers all script extensions with ModLoader
2. Translation assets loaded for UI configuration schema
3. Game starts, `AutobattlerOptions` singleton instantiated in scene
4. `AutobattlerOptions._ready()` loads persisted config from disk, syncs with ModOptions interface
5. Player entity instantiates AI marker scene, connects to options change signals
6. `AICanvas` instantiated in main scene, ready for per-frame visualization

**Movement Calculation Flow (per-frame):**
1. Player movement system calls `player_movement_behavior.get_movement()`
2. Movement function checks `enable_autobattler` flag from options
3. If disabled and player is not a bot, call parent class movement (allows manual control)
4. If enabled or is_bot: Calculate weighted forces from all entity types:
   - Consumables (health-weighted attraction)
   - Gold items (squared weight applied)
   - Trees (with repulsion near preferred distance)
   - Projectiles (negative weight = repulsion, inverse distance squared falloff)
   - Enemies (distance-squared-based attraction/repulsion, egg-specific handling)
   - Bosses (separate weight, charge detection for tangent movement)
   - Map boundaries (four corner bumpers, perimeter bumpers)
5. Special case: Soldier character freezes when shooting at close range
6. Return normalized movement vector

**Visualization Flow (per-frame when enabled):**
1. `_process()` calls `update()` triggering `_draw()`
2. `_draw()` mirrors movement calculation logic:
   - Fetch all weights, option parameters
   - Get weapon range for preferred distance
   - Draw circles for each entity type, sized by inverse distance squared
   - Color by category: blue (attraction), red (repulsion/nearby danger)
   - Skip rendering if wave timer < 0.05s (end of wave)

**Configuration Change Flow:**
1. User changes setting in ModOptions menu
2. ModsConfigInterface broadcasts `setting_changed` signal
3. `AutobattlerOptions.setting_changed()` syncs the new value to local variable
4. Calls `save_configs()` to persist to disk
5. `Player.on_setting_changed()` callback triggered:
   - Reloads marker visibility based on enable_autobattler + enable_ai_marker
   - Updates camera smoothing parameters
6. Next frame, movement calculation uses updated weights

**Multiplayer Input Coordination Flow:**
1. Character selection scene: F1 key press adds bot player
2. `CoopService._input()` calls `_add_player()` with `PlayerType.KEYBOARD_AND_MOUSE`, marks as bot
3. `focus_emulator.gd` intercepts input, restricts to current_player_index
4. Backtick (`) key rotates control to next connected player
5. `get_remapped_player_device()` returns device 7 for all players (device routing layer)

## Key Abstractions

**Weighted Force Vector:**
- Purpose: Represent attraction/repulsion to/from game entities as 2D vectors
- Examples: `player_movement_behavior.gd` lines 55-251
- Pattern: `to_add = (direction.normalized() / distance_squared) * weight`
- Accumulation: Forces summed into `move_vector`, then normalized before return

**Distance-Squared Optimization:**
- Purpose: Avoid expensive sqrt() calls while maintaining proper inverse-distance falloff
- Examples: `squared_distance_to_item`, `squared_distance_to_projectile`
- Pattern: Compare squared distances to squared thresholds; multiply squared distances for weighting
- Impact: Critical for per-frame performance with 100+ entities

**Adaptive Weapon Range:**
- Purpose: Maintain safe combat distance by using minimum of equipped weapons' max_range
- Examples: `player_movement_behavior.gd` lines 47-53
- Pattern: Iterate weapons, track minimum range as `preferred_distance_squared`
- Usage: Determines when to attack (close) vs. maintain distance (far)

**Option Node Singleton Pattern:**
- Purpose: Global configuration access without string-key lookups
- Examples: `$"/root/AutobattlerOptions"` accessed from movement behavior, UI, visualization
- Pattern: Create constant OPTION_NAME for each setting, mirror in node variable for fast lookup
- Benefit: Reduces ModOptions config interface calls, improves performance

**Character-Specific Logic:**
- Purpose: Handle character class variations (Soldier freezes when shooting, Bull adjusts range)
- Examples: `player_movement_behavior.gd` lines 30-45
- Pattern: Query character name from `RunData.get_player_character()`, branch on is_soldier/is_bull
- Extensibility: New characters can be added with additional elif branches

## Entry Points

**`mod_main.gd`:**
- Location: `mods-unpacked/Pasha-AutoBattler/mod_main.gd`
- Triggers: ModLoader framework initialization
- Responsibilities: Register script extensions, load translations, setup mod metadata

**Player Movement System Override:**
- Location: `mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/player_movement_behavior.gd`
- Triggers: Every frame when player input processed, called by Godot physics
- Responsibilities: Compute AI steering vector or delegate to parent class

**Configuration UI:**
- Location: `manifest.json` config_schema
- Triggers: ModOptions menu system
- Responsibilities: Define settable parameters, tooltips, min/max ranges, validation

**Keyboard Input Handlers:**
- Shift+Space: Toggle autobattler enable (in `autobattler_options.gd`)
- F1: Add bot player to coop (in `coop_service.gd`)
- Backtick (`): Rotate player focus (in `focus_emulator.gd`)

## Error Handling

**Strategy:** NaN guards and distance validation

**Patterns:**
- NaN checks before applying force vector: `if not is_nan(to_add.x) and not is_nan(to_add.y)`
- Distance floor to prevent division by zero: `if squared_distance_to_item < 0: squared_distance_to_item = .001`
- Safe projectile shape detection: `if not projectile._hitbox or not projectile._hitbox.active`
- Graceful fallback to parent class when options system unavailable

## Cross-Cutting Concerns

**Logging:** Debug prints currently commented out; `print_debug()` used for option warnings

**Validation:** Config load validation, projectile hitbox existence checks, NaN detection

**Authentication:** CoopService device remapping ensures bots receive no actual input

**Performance Optimization:**
- Inverse distance squared weighting over frame-by-frame integration
- Circular force field approximation (no pathfinding)
- Wave-end render skip (if wave_timer < 0.05s)
- Distance thresholds to zero out forces beyond effective range

---

*Architecture analysis: 2026-04-13*

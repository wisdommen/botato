# External Integrations

**Analysis Date:** 2026-04-13

## APIs & External Services

**Game Integration:**
- Brotato Game Engine - Core game integration via script extensions
  - Access to: player entities, enemy spawners, projectiles, consumables, game state
  - Method: Script extensions that override base game behavior
  - Key files: `extensions/entities/units/movement_behaviors/player_movement_behavior.gd`, `extensions/entities/units/player/player.gd`

**Mod Framework:**
- ModLoader API - Provides mod installation and lifecycle management
  - Methods used: ModLoaderMod.install_script_extension(), ModLoaderMod.add_translation()
  - Used in: `mod_main.gd`
  - Purpose: Dynamically extend game scripts and add translations

**Steam Integration:**
- Steam Workshop - Distribution platform for the mod
  - Steam ID: 2965027290 (BOTato mod)
  - Dependency mods on Steam Workshop:
    - ContentLoader (ID: 2931387684)
    - Mod Options (ID: 2944608034)

## Data Storage

**Local Configuration:**
- Godot ConfigFile system
  - Location: `user://pasha-botato-options.cfg` (user's local game directory)
  - Format: INI-style configuration file
  - Purpose: Persist mod settings across game sessions
  - Sections: `[options]` containing all AI behavior weights and parameters

**Game State Access (Read-only):**
- Player entity stats: health, weapons, position
  - Accessed via: `player.current_stats`, `player.max_stats`, `player.current_weapons`, `player.position`
- Enemy/Boss spawner data: enemy positions, types, attack behaviors
  - Accessed via: `_entity_spawner.enemies`, `_entity_spawner.bosses`, `_entity_spawner.neutrals`
- Game world data: map boundaries, zone information
  - Accessed via: `ZoneService.current_zone_max_position`
- Projectile data: projectile positions, hitbox information, collision shapes
  - Accessed via: `projectiles_container.get_children()`, `projectile._hitbox`
- Consumables and items: food pickups, gold items
  - Accessed via: `_consumables_container`, `items_container._active_golds`

**File Storage:**
- Translation files: `.en.translation` (Godot compiled translation format)
  - Built from: `translations/autobattler_options.csv`
  - Purpose: Multi-language support for mod options UI

## Authentication & Identity

**Not Applicable**
- Mod does not implement authentication
- No user accounts or identity management
- No external user identity required

## Monitoring & Observability

**Logging:**
- Godot console output via `print_debug()` for debugging
  - Used in: `autobattler_options.gd` for unknown config warnings
- Debug output when parsing AI behavior weights
  - Optional: Can be enabled for troubleshooting bot behavior
  - Examples: movement vector debug prints (currently commented out in code)

**Error Tracking:**
- None - No external error tracking service
- Local error handling via Godot's built-in error system
- ConfigFile load errors caught locally and handled gracefully
  - Location: `autobattler_options.gd` line 125-128

**No Analytics or Telemetry**
- Mod does not send data to external services
- No user behavior tracking
- Completely offline operation

## CI/CD & Deployment

**Hosting:**
- Steam Workshop - Primary distribution platform
- GitHub repository (source code, not deployment)
  - Repository: https://github.com/boardengineer/botato
  - Issues tracked: Phantom projectiles bug (fixed in commit 876a582)

**Mod Distribution:**
- Manual installation via Steam Workshop subscription
- Users enable mod in Brotato's mod menu (Options → Mods)
- Requires manual installation of dependency mods (ContentLoader, Mod Options)

**Version Management:**
- Semantic versioning: 1.3.0 (current version in manifest)
- Compatible game version pinned in manifest: 0.8.0.3+
- Compatible mod loader version: 6.0.0+

## Environment Configuration

**Required Environment Variables:**
- None - All configuration is via local config file or in-game mod options menu

**Required Files/Directories:**
- Godot user directory (for config file storage)
  - Path: `user://pasha-botato-options.cfg` (resolves to OS-specific user directory)
- Brotato game installation directory
- ModLoader mod installed
- ContentLoader mod installed
- Mod Options mod installed

**No Secrets Management**
- Mod does not use API keys, credentials, or secrets
- All configuration is in plaintext in local config file
- No authentication tokens required

## Webhooks & Callbacks

**Input System Callbacks:**
- Keyboard input handling for auto-battler toggle
  - Trigger: Shift+Space key combination
  - Handler: `autobattler_options.gd` `_input()` method
  - Effect: Toggles `enable_autobattler` setting and notifies mod options interface

- Keyboard input handling for player switching
  - Trigger: Backtick/Grave key (`) in Main game scene or character selection
  - Handler: `focus_emulator.gd` `_handle_input()` method
  - Effect: Cycles current player index for co-op play

**Signal Callbacks:**
- Setting changed signal from ModOptions interface
  - Source: `dami-ModOptions/ModsConfigInterface`
  - Handler: `autobattler_options.gd` `setting_changed()` method
  - Effect: Updates local config mirror and saves to disk

- Connected players updated signal
  - Source: CoopService (Brotato base)
  - Handler: `focus_emulator.gd` `_on_connected_players_updated()` method
  - Effect: Sets device mapping for bot players vs human players

**Game Engine Callbacks:**
- _ready() lifecycle - Called when node enters scene tree
  - Used in: All extension scripts to initialize configuration and UI
  
- _process(delta) lifecycle - Called every frame
  - Used in: Movement behavior for AI decision-making, AI canvas for visualization
  
- _draw() lifecycle - Called when Node2D needs to render
  - Used in: `ai_canvas.gd` to visualize AI decision weights as colored circles

## Integrations Summary

The mod operates purely through Godot's extension system and the ModLoader framework. All data flows through the base Brotato game engine's internal APIs. There are no external HTTP APIs, databases, or third-party services. The mod is self-contained except for the required Steam Workshop dependencies (ContentLoader and Mod Options).

---

*Integration audit: 2026-04-13*

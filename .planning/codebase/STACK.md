# Technology Stack

**Analysis Date:** 2026-04-13

## Languages

**Primary:**
- GDScript - Godot's built-in scripting language used for all mod logic
- GDShader - Godot shader language for visual effects (if any used)

**Secondary:**
- JSON - Configuration and manifest files

## Runtime

**Environment:**
- Godot Engine 4.x (mod loader compatible version 6.0.0)
- Brotato game version 0.8.0.3 or later

**Target Platform:**
- Steam/Windows (Brotato is a Steam game)

## Frameworks

**Core:**
- Brotato Game Engine - Base game framework that the mod extends
- ModLoader - Godot mod loading framework (version 6.0.0 compatible)

**Supporting Mods (Dependencies):**
- ContentLoader - Required dependency for content management
- Mod Options (dami-ModOptions) - Required dependency for mod configuration UI and settings management

## Key Dependencies

**Critical:**
- ModLoaderMod - Core mod loading API for script extensions and translation management
- ConfigFile - Godot's built-in configuration file system for persistent settings storage
- Node2D - Godot's 2D rendering system for AI visualization canvas
- InputEvent system - Godot's input handling for keyboard shortcuts and player control

**Infrastructure:**
- Godot Signals - Event system for setting changes and callbacks
- Godot Scene System (*.tscn) - For UI scenes and AI visualization overlay
- Translation System - For multi-language support in mod options

## Configuration

**Environment:**
- Local config file storage at `user://pasha-botato-options.cfg`
- ConfigFile format with sections and key-value pairs
- Runtime options in Mod Options menu (accessed through dami-ModOptions interface)

**Build:**
- No build configuration needed - pure GDScript mod
- Mod metadata in `manifest.json` defining version, dependencies, and config schema
- Schema-based configuration system in manifest for in-game options UI

**Manifest Configuration:**
- Location: `mods-unpacked/Pasha-AutoBattler/manifest.json`
- Defines mod metadata, version (1.3.0), game compatibility (Brotato 0.8.0.3+)
- Includes JSON schema for 10 configurable AI behavior parameters
- Config parameters: enable_autobattler, enable_ai_visuals, enable_ai_marker, enable_smoothing, smoothing_speed, item_weight, projectile_weight, tree_weight, boss_weight, bumper_weight, egg_weight, bumper_distance

## Platform Requirements

**Development:**
- Godot Engine 4.x installed
- Text editor for GDScript files (.gd)
- Optional: Godot editor for testing mods in-game

**Production:**
- Brotato game client (Steam)
- ModLoader mod installed from Steam workshop
- ContentLoader mod installed from Steam workshop
- Mod Options mod installed from Steam workshop
- Game data files and assets from Brotato installation

---

*Stack analysis: 2026-04-13*

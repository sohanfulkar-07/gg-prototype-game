# SwordStrike — Version Tracking & Change Reminder

> [!IMPORTANT]
> **DEVELOPMENT REMINDER RULE:**
> For every iteration, bug fix, redesign, or feature added:
> 1. Increment and update the project version accordingly.
> 2. Ensure the version string is synchronized across `project.godot`, `export_presets.cfg`, `main_menu.tscn`, `SaveManager.gd`, and APK build targets.
> 3. Document all changes under the Version History table below.

---

## Current Status
* **Current Game Name:** `SwordStrike`
* **Current Game Version:** `5.3.42`
* **Target Engine:** Godot Engine 4.7.2 (stable.official)
* **Android Package Name:** `com.sohanfulkar.swordstrike`
* **Android Version Code:** `50342`
* **Export Artifact:** `build/android/SwordStrike_v5.3.42_debug.apk`

---

## Version History & Changelog

### [v5.3.42] - 2026-10-30
* **Game Renaming & Version Increment:**
  * Officially rebranded the game to **SwordStrike**.
  * Advanced project version to **5.3.42** (Version Code: `50342`).
  * Updated `project.godot` with `config/name="SwordStrike"`.
  * Updated `export_presets.cfg` with package `SwordStrike`, ID `com.sohanfulkar.swordstrike`, and version `5.3.42`.
  * Generated matching APK build target: `build/android/SwordStrike_v5.3.42_debug.apk`.
  * Integrated version constant into `SaveManager` (`GAME_NAME = "SwordStrike"`, `GAME_VERSION = "5.3.42"`) with JSON save state persistence.
  * Updated Main Menu Title, Subtitle, Footer badge, and Credits to display `SwordStrike v5.3.42`.
  * Established the mandatory change-tracking rule.

### [v0.2.0] - 2026-10-30
* **Cinematic Opening & 3D Main Menu Redesign:**
  * Implemented 5-shot cinematic sequence (Darkness & Whispers -> The World -> The Kingdom -> The Hero -> Title Reveal).
  * Created real-time 3D living environment with dynamic dawn sun, mountains, starter town, lanterns, and animated hero.
  * Added instant Skip button (`SKIP ⏭`) with first-time tracking (`SaveManager.has_watched_intro`).
  * Added Live 3D Menu Camera with smooth continuous idle drift.
  * Implemented Settings modal (Master/SFX/Music sliders, 60/30 FPS toggle, dynamic shadows, camera sensitivity).
  * Implemented Overwrite Protection confirmation modal for New Game.
  * Implemented Credits modal with "Replay Cinematic" trigger.
  * Enhanced `SoundManager` with secondary procedural ambience/music synthesizer and UI audio juice.

### [v0.1.0] - 2026-09-11
* **Initial Project Prototype:**
  * Core 3D movement with rotatable third-person camera and SpringArm3D collision.
  * 3-hit melee combat combo system with hitboxes, damage numbers, and slash arcs.
  * 3 mission levels (Forest, Ruins, Dungeon), Town hub, and Final Boss encounter.
  * RPG progression: XP, leveling, coins, potion recovery, and weapon upgrades.
  * Dual-touch mobile controls with virtual joystick and combat action cluster.


# SWORDSTRIKE — MANDATORY VERSION TRACKING RULE

**Current Official Game Name:** `SwordStrike`  
**Current Official Version:** `5.3.42`  
**Current Android Version Code:** `50342`  
**Official APK Directory:** `build/android/`  
**APK Naming Convention:** `SwordStrike_v[VERSION]_debug.apk`  

---

## Mandatory Protocol For Every Development Task

For **EVERY** future development task, feature addition, bug fix, UI modification, environment change, optimization, or gameplay improvement, the following 12-step protocol MUST be executed:

1. **Read `VERSION_TRACKER.md`** before making any changes.
2. **Identify the current official game version.**
3. **Determine the appropriate next version** based on semantic increments (patch for minor fixes/polish, minor for new features/systems, major for fundamental overhauls).
4. **Increment the version** according to the changes made.
5. **Update the version in all relevant project locations:**
   * `project.godot` (`config/name="SwordStrike"`)
   * `export_presets.cfg` (`version/name` and `version/code`)
6. **Update the Android version name and monotonically increasing version code** in `export_presets.cfg` (e.g., version `5.3.43` -> code `50343`).
7. **Update the main menu version display** in `scenes/ui/main_menu.tscn` (footer badge and credits text).
8. **Update `SaveManager` version constants** (`GAME_NAME = "SwordStrike"`, `GAME_VERSION = "[VERSION]"` in `autoload/save_manager.gd`).
9. **Add a dated entry to `VERSION_TRACKER.md`** describing every change made in that iteration.
10. **Update `MIGRATION_REPORT.md`** when relevant to document architectural changes.
11. **Generate/mirror the APK** using the new versioned filename: `build/android/SwordStrike_v[VERSION]_debug.apk`.
12. **Verify that the APK exists on disk** before reporting successful export.

---

## Inviolable Rules

* **Never reuse an old version number for a new build.**
* **Never change the official game name from `SwordStrike` without explicit permission.**
* **Never reset the version to `0.1.0`.**
* **Every new development task must leave the project with an updated version history.**

---

## Current Status & Artifact Targets

* **Game Name:** `SwordStrike`
* **Version:** `5.3.42`
* **Target Engine:** Godot Engine 4.7.2 (stable.official)
* **Android Package Name:** `com.sohanfulkar.swordstrike`
* **Android Version Code:** `50342`
* **Active Export Artifact:** `build/android/SwordStrike_v5.3.42_debug.apk`

---

## Version History & Detailed Changelog

### [v5.3.42] - 2026-10-31
* **Complete Project Migration to `gg-prototype-game`:**
  * Completed automated bulk migration of all 35 scenes (.tscn), 26 GDScripts (.gd), autoload singletons, data configurations, and export presets into `gg-prototype-game`.
  * Verified 0 broken dependencies across all `res://` paths project-wide.
  * Re-imported all project resources using Godot Engine 4.7.2 headless console.
  * Fixed unnecessary save trigger side-effect in `_hide_all_modals()`.
  * Successfully verified headlessly booted scenes (Main Menu, Town, Forest Mission, Ruins Mission, Dungeon Mission, Final Boss Arena).
  * Maintained official version `5.3.42` (Code `50342`) and official APK `SwordStrike_v5.3.42_debug.apk`.

### [v5.3.42] - 2026-10-30
* **Official Branding & Version Establishment:**
  * Officially established game title as **`SwordStrike`**.
  * Set project baseline version to **`5.3.42`** with monotonically increasing Android Version Code **`50342`**.
  * Configured `project.godot` with `config/name="SwordStrike"`.
  * Configured `export_presets.cfg` with package `SwordStrike`, ID `com.sohanfulkar.swordstrike`, version `5.3.42`, and code `50342`.
  * Generated and verified APK artifact: `build/android/SwordStrike_v5.3.42_debug.apk`.
  * Embedded version constants into `SaveManager` with JSON persistence.
  * Synchronized Main Menu Title, Subtitle, Footer badge, and Credits to display `SwordStrike v5.3.42`.
  * Codified the mandatory 12-step version tracking protocol and inviolable rules.

### [v0.2.0] - 2026-10-30
* **Cinematic Opening & 3D Main Menu Redesign:**
  * Implemented 5-shot cinematic sequence (Darkness & Whispers -> The World -> The Kingdom -> The Hero -> Title Reveal).
  * Built real-time 3D living environment (`scenes/levels/main_menu_environment.tscn`) with dynamic dawn lighting, mountains, starter town, lanterns, and animated hero.
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

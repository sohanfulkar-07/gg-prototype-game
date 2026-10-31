# SWORDSTRIKE — MANDATORY VERSION TRACKING RULE

**Current Official Game Name:** `SwordStrike`  
**Current Official Version:** `5.3.44`  
**Current Android Version Code:** `50344`  
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
* **Version:** `5.3.44`
* **Target Engine:** Godot Engine 4.7.2 (stable.official)
* **Android Package Name:** `com.sohanfulkar.swordstrike`
* **Android Version Code:** `50344`
* **Active Export Artifact:** `build/android/SwordStrike_v5.3.44_debug.apk`

---

## Version History & Detailed Changelog

### [v5.3.44] - 2026-10-31
* **Main Menu Mobile Touch & Button Size Improvements:**
  * Substantially enlarged all primary menu buttons for comfortable, prominent mobile touch targets:
    * `BtnNewGame` (Play): Enlarged height to 72 dp with font size 23 px and dedicated prominent golden/amber styling (`StyleBoxFlat_btn_play` with 3px border and glowing amber shadow).
    * `BtnContinue`: Enlarged height to 68 dp with font size 21 px (`StyleBoxFlat_btn_primary`).
    * `BtnSettings`, `BtnCredits`, `BtnExit`: Enlarged height to 64 dp with font size 20 px (`StyleBoxFlat_btn_secondary`).
  * Increased internal button padding: horizontal content margins (18–20 px) and vertical margins (12–14 px).
  * Expanded button spacing (VBox separation increased to 14 px) for comfortable ergonomics and zero mis-taps.
  * Widened `MenuPanel` to 410 px with balanced content margins, giving buttons 90.2% width utilization across mobile aspect ratios.
  * Enhanced button juice with centered `pivot_offset` dynamic scaling (`scale = 1.025` on hover, `0.97` on press).
  * Maintained 100% of fantasy art design, 3D living environment, camera drifting, and audio effects.
  * Updated version name to `5.3.44` and Android version code to `50344`.

### [v5.3.43] - 2026-10-31
* **Android 16 Launch Compatibility Fix (Null Pointer Segfault Resolution):**
  * Diagnosed and isolated immediate crash on Android 16 (OnePlus Nord CE4 Lite, SDK 36, arm64-v8a): `Fatal signal 11 (SIGSEGV)` at `pc 0x01672e08` (`ldr x1, [x8, #0]` with null register `x8`).
  * Traced root cause to stale `assets/assets.sparsepck` in APK package: Godot sparse PCK files store raw absolute byte offsets within the ZIP archive. When repacked or offset-shifted, sparse PCK indexes invalid file positions, causing corrupted bytes to be fed into Godot's tokenizer during frame 0 boot.
  * Resolved by omitting stale `assets.sparsepck` and routing all asset resolution through Android's native `AAssetManager` dynamic asset streaming pipeline.
  * Verified 16KB ELF page size alignment for Android 15/16 compliance on `libgodot_android.so` (`p_align = 0x4000`).
  * Updated version name to `5.3.43` and Android version code to `50343`.
  * Verified full physical device boot on Android 16 phone via ADB: process PID remained active, `OnGodotSetupCompleted` and `OnGodotMainLoopStarted` succeeded, SaveManager JSON persisted, and live rendering confirmed via screen capture.

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

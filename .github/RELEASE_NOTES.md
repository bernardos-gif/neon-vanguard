## NEON VANGUARD v0.1.0: first playable prototype

An original 3D fighting game made with Godot 4.7.2.

### Download and play (Windows 10/11, 64-bit)
1. Download **`NeonVanguard_Windows_x86_64.zip`** below (under *Assets*).
2. Right-click it → **Extract All…** → **Extract**.
3. Open the `NEON_VANGUARD` folder and double-click **`NeonVanguard.exe`**.
4. If Windows SmartScreen warns you: **More info → Run anyway** (the build is not code-signed).
5. Black screen or no start? Double-click **`NeonVanguard_SafeMode.bat`** instead.

### What's in this build
- Two original fighters: **KAIRO** (counter specialist) and **VESPER** (agile pressure fighter), each with normals, three specials, a throw, blocking and combos
- **Neon District Rooftop** stage with rain, fog, wet reflections and an animated city
- Player vs CPU (Easy / Normal / Hard), Player vs Player on one PC, and CPU vs CPU watch mode
- Rounds, timer, K.O. / time-out, victory and defeat screens, rematch, pause menu
- Settings: audio volumes, fullscreen, V-Sync, frame limit, 4 graphics quality levels, screen shake
- Keyboard and Xbox-style gamepad support

**Controls (Player 1):** A/D move · W jump · S crouch · J/K/L light/medium/heavy · I special (+direction) · U throw · hold back to block · Esc pause

### Status
This is a **pre-release**. All automated tests pass (25 combat logic tests and 54 scene checks), including inside an exported build.
The `.exe` was exported with Godot's official Windows template, but it has **not yet been launched on Windows**, and the visuals have not been reviewed on a real screen.
The characters are original placeholder models. See `TESTING.md` for the manual checklist.

SHA-256 of `NeonVanguard_Windows_x86_64.zip`: `b93c161f198256bb25708b6903cbeaac347212b865d404d9c12beb69b3256b3d`

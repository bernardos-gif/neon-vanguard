# NEON VANGUARD on macOS

## Play the ready-made build
1. Download **`NeonVanguard_macOS.zip`** from the
   [v0.1.0 release page](https://github.com/bernardos-gif/neon-vanguard/releases/tag/v0.1.0)
   (under **Assets**). The same zip is in this repository's `release` folder.
2. Double-click the zip to unpack it. You get **`NEON VANGUARD.app`**.
   Drag it into **Applications** if you like.
3. Double-click **`NEON VANGUARD.app`**.
4. The first time, macOS says it cannot verify the developer, because the game is not
   notarized by Apple (that requires a paid Apple Developer account). To allow it once:
   - click **Done**,
   - open **System Settings → Privacy & Security**,
   - scroll down and click **Open Anyway** next to "NEON VANGUARD", then confirm with **Open**.
5. If macOS instead says the app **"is damaged and can't be opened"**, open **Terminal**
   (Applications → Utilities) and run:
   ```
   xattr -dr com.apple.quarantine "/Applications/NEON VANGUARD.app"
   ```
   (adjust the path if the app is elsewhere), then open the app again.

The build is **universal**, so it runs natively on Apple Silicon (M1 and later) and on Intel Macs.
Controls are the same as on Windows (see README.md). On a Mac laptop there is no numpad, so Player 2
uses the arrow keys plus `,` `.` `/` `;` `'`.

## Build it yourself on a Mac
1. Download **Godot 4.7.x – Standard** for macOS from <https://godotengine.org/download/macos/>
   and move `Godot.app` to Applications.
2. Download this repository (green **Code** button → **Download ZIP**) and unzip it.
3. Open Godot → **Import** → select `project.godot` → **Import & Edit**.
4. **Editor → Manage Export Templates… → Download and Install** (one time).
5. **Project → Export…** → select the **macOS** preset → **Export Project…** → untick
   **Export With Debug** → save as `NeonVanguard_macOS.zip` (or `.app`).

On a Mac you can also sign and notarize the app with your own Apple Developer ID:
in the macOS preset, set **Codesign → Codesign** to *Xcode codesign*, fill in your identity, and
enable **Notarization**. The included build uses ad-hoc signing only.

## How the included macOS build was produced
- Engine: Godot **4.7.2.stable.official** (`ed1daf0bf`) with the official 4.7.2 macOS export template.
- Host: Ubuntu 24.04 cloud container, command:
  `godot --headless --path . --export-release "macOS" build/macos/NeonVanguard_macOS.zip`
- Preset: universal binary (x86_64 + arm64), bundle id `com.neonvanguard.game`, version 0.1.0,
  built-in ad-hoc code signature, not notarized. The project setting
  *Rendering → Textures → VRAM Compression → Import ETC2 ASTC* is enabled because Apple Silicon needs it.
- Verified there: valid `.app` bundle (`Info.plist`, icon, code signature), `Mach-O universal binary`
  with `x86_64` and `arm64`, executable permission kept inside the zip, and the game data pack holds all
  game content (tests/tools excluded).
- **Not verified:** launching on a Mac. No Mac was available.
- SHA-256 of `NeonVanguard_macOS.zip`: `3d0e1168758323019e83cb1333fb86a67c6157e8299edf9bdc3b4ddc811ef2f5`

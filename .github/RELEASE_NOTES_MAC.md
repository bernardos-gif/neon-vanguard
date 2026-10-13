
---

### macOS (Apple Silicon and Intel), added
1. Download **`NeonVanguard_macOS.zip`** below (under *Assets*) and double-click it.
2. Double-click **`NEON VANGUARD.app`**.
3. The first time, macOS says it cannot verify the developer (the app is not notarized). Click **Done**, open **System Settings → Privacy & Security**, click **Open Anyway**, then **Open**.
4. If macOS says the app "is damaged", run this in Terminal, then open it again:
   `xattr -dr com.apple.quarantine "/Applications/NEON VANGUARD.app"`

Universal build (arm64 + x86_64) exported with Godot's official macOS template and ad-hoc signed. It has **not yet been launched on a Mac**. See `BUILD_MAC.md`.

SHA-256 of `NeonVanguard_macOS.zip`: `3d0e1168758323019e83cb1333fb86a67c6157e8299edf9bdc3b4ddc811ef2f5`

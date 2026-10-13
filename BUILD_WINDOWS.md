# Building the Windows `.exe` yourself

This takes about 5 minutes the first time and needs no programming.
You need Windows 10/11 64-bit and an internet connection.

## Step 1: Install Godot 4.7 (Standard)
1. Go to <https://godotengine.org/download/windows/>.
2. Download **Godot Engine 4.7.x – Standard** (do **not** pick ".NET").
3. Unzip it to a folder, e.g. `C:\Godot`. The program is
   `Godot_v4.7.x-stable_win64.exe`. There is nothing to install.

## Step 2: Get the project
1. On the GitHub page of this repository click the green **Code** button → **Download ZIP**.
2. Right-click the zip → **Extract All…** (e.g. to `C:\Games\NeonVanguard-source`).

## Step 3: Open the project
1. Double-click `Godot_v4.7.x-stable_win64.exe`.
2. In the Project Manager click **Import**.
3. Browse to the extracted folder, select **`project.godot`**, click **Open**, then **Import & Edit**.
4. Wait for the first import to finish (progress bar at the bottom).
5. Optional: press **F5** to play inside the editor.

## Step 4: Install the export templates (one time only)
1. Menu **Editor → Manage Export Templates…**
2. Click **Download and Install**. Wait until it shows the templates as installed (~1 GB).
3. Close the window.

## Step 5: Export
1. Menu **Project → Export…**
2. Select the preset **Windows Desktop** in the list on the left (it is already configured:
   x86_64, game data embedded inside the `.exe`, test files excluded).
3. Click **Export Project…** (bottom of the window).
4. Choose a folder, for example `C:\Games\NeonVanguard`, keep the file name
   `NeonVanguard.exe`, and **untick "Export With Debug"** for a release build.
5. Click **Save**.

You now have **`NeonVanguard.exe`**, a single file containing the whole game.
Double-click it to play. You can copy it to any 64-bit Windows 10/11 PC.

### Optional: give the `.exe` the game icon
Godot needs the free tool **rcedit** for this:
1. Download `rcedit-x64.exe` from <https://github.com/electron/rcedit/releases>.
2. In Godot: **Editor → Editor Settings → Export → Windows → rcedit**, pick the downloaded file.
3. **Project → Export… → Windows Desktop → Options**: turn on **Application → Modify Resources**,
   and set **Application → Icon** to an `.ico` file.
4. Export again.

## Exact command-line export (for advanced users)
From the project folder (where `project.godot` is):
```
"C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" build\windows\NeonVanguard.exe
```

## Troubleshooting
| Problem | Fix |
|---|---|
| "No export template found" | Do Step 4 (Manage Export Templates → Download and Install). |
| Black screen / crash at start on an old PC | Run `NeonVanguard.exe --rendering-method gl_compatibility` (or use the included `NeonVanguard_SafeMode.bat`). |
| Low frame rate | In the game: **Settings → Graphics quality → MEDIUM or LOW**. |
| Windows SmartScreen warning | Click **More info → Run anyway** (the build is not code-signed). |
| Game too loud / quiet | **Settings → Audio**. Settings are saved automatically. |

## How the included `release/NeonVanguard_Windows_x86_64.zip` was produced
- Engine: Godot **4.7.2.stable.official** (`ed1daf0bf`), official export templates 4.7.2.
- Host: Ubuntu 24.04 cloud container (x86_64), command:
  `godot --headless --path . --export-release "Windows Desktop" build/windows/NEON_VANGUARD/NeonVanguard.exe`
- Result verified there: valid `PE32+ executable (GUI) x86-64` with the game data pack embedded
  (fighter data, scenes, scripts, shaders and fonts present; tests/tools excluded).
- The same project exported for Linux passed the complete automated test suite **inside the
  exported package** (see TESTING.md).
- **Not verified:** launching the `.exe` on Windows. No Windows machine was available.
- SHA-256 of `NeonVanguard.exe`: `dfeb4d9afa6fcefb24a02f8b09408b27d896d75ed048022e7856022d240e8a50`
- SHA-256 of `NeonVanguard_Windows_x86_64.zip`: `b93c161f198256bb25708b6903cbeaac347212b865d404d9c12beb69b3256b3d`

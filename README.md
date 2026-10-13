# NEON VANGUARD — First Playable Build (v0.1.0)

An original cinematic 3D fighting game made with **Godot 4.7 (standard edition)** and **GDScript**.
Two original fighters battle on a rain-soaked neon rooftop, in matches against the CPU
or against a friend on the same PC.

> **Status:** first playable prototype. The combat, match flow, menus, CPU opponent and
> audio work and are covered by automated tests. The 3D characters and stage are
> original **placeholder art** built from simple shapes. They are styled to look
> cohesive, but they are not final sculpted models. See *Known limitations* below.

---

## 1. Play it right now (no installation)

1. Open the **[v0.1.0 release page](https://github.com/bernardos-gif/neon-vanguard/releases/tag/v0.1.0)**
   (or click **Releases** on the right side of the repository page) and, under **Assets**, click
   **`NeonVanguard_Windows_x86_64.zip`** to download it. The same zip is also in the `release` folder.
2. Right-click the downloaded zip → **Extract All…** → **Extract**.
3. Open the extracted **`NEON_VANGUARD`** folder and double-click **`NeonVanguard.exe`**.
4. If Windows shows *"Windows protected your PC"*, click **More info** → **Run anyway**.
   (The game is not code-signed. That is normal for a hobby build.)
5. If the screen stays black or the game will not start, double-click
   **`NeonVanguard_SafeMode.bat`** instead. It uses a simpler renderer that works on older graphics cards.

> This `.exe` was exported in a cloud Linux environment using Godot's official
> Windows export template. It was **not launched on Windows** there, because no Windows
> machine was available. If it misbehaves, build your own copy in two minutes with
> [BUILD_WINDOWS.md](BUILD_WINDOWS.md).

## 2. Open the project in Godot (to edit or export it yourself)

1. Download **Godot 4.7.x – Standard** (not the ".NET" version) from
   <https://godotengine.org/download/windows/> and unzip it anywhere.
2. Download this repository: green **Code** button → **Download ZIP**, then extract it.
3. Start Godot. In the Project Manager click **Import**, browse to the extracted folder,
   select **`project.godot`**, click **Open** → **Import & Edit**.
   The first import takes a few seconds.
4. Press **F5** (or the ▶ "Run Project" button, top right) to play.

No code editing is needed for anything in this guide.

## 3. How to play

**Main menu:** `PLAY` starts a quick match (Player 1 vs CPU). `CHARACTER SELECT` lets you pick
fighters, the mode (vs CPU, vs Player 2, or watch CPU vs CPU), the CPU difficulty
(Easy / Normal / Hard), the match length and the round time.

| Action | Player 1 keyboard | Player 2 keyboard | Gamepad |
|---|---|---|---|
| Move left / right | A / D | ← / → | D-pad or left stick |
| Jump (+ direction) | W | ↑ | D-pad up / stick up |
| Crouch | S | ↓ | D-pad down / stick down |
| Light attack | J | Numpad 1 or `,` | X |
| Medium attack | K | Numpad 2 or `.` | Y |
| Heavy attack | L | Numpad 3 or `/` | RB |
| Special (+ direction) | I | Numpad 5 or `;` | A |
| Throw | U | Numpad 4 or `'` | B |
| Pause | Esc | Esc | Start |

Gamepad 1 controls Player 1, and gamepad 2 controls Player 2. Menus work with the mouse,
the keyboard (arrows/WASD + Enter/J) or any gamepad (D-pad + A, B to go back).

**Fighting basics**
- **Block:** hold *back* (away from the opponent). Hold *down-back* to block low attacks.
  Jump attacks must be blocked standing.
- **Throw** beats blocking. Press Throw just as you are grabbed to break it.
- **Dash:** double-tap forward or back.
- **Combos:** when an attack connects (hit or block), you can chain
  Light → Medium → Heavy → Special.
- **Specials:** press Special alone, with forward, or with back. Each fighter has three.

### The fighters

| | **KAIRO** — The Counter Specialist | **VESPER** — The Agile Pressure Fighter |
|---|---|---|
| Look | cobalt technical jacket, white wraps, cyan glow, headband ribbon | asymmetric black/magenta streetwear, glowing visor, long ponytail |
| Style | balanced, precise, punishes mistakes | fast, aggressive, long strings |
| Special | **Pulse Shot**: energy projectile | **Razor Flurry**: 4-hit rush |
| Forward + Special | **Comet Drive**: advancing knee strike (knockdown) | **Ghost Step**: low-profile dash strike that slides under projectiles |
| Back + Special | **Still Water**: timed counter stance → Riposte | **Mirage Flip**: invulnerable back-flip |
| Throw | Ridge Fall | Cross Spin |

Press **F1** during a match to show the hit boxes (red), hurt boxes (green) and push boxes (yellow).

## 4. What is in the project

```
project.godot             Godot project file (open this)
export_presets.cfg        Windows (and Linux) export settings
scenes/                   Main menu, character select, match, stage scenes
scripts/combat/           Deterministic 60 Hz fighting engine (no rendering code)
scripts/ai/               CPU opponent
scripts/visual/           Procedural 3D fighters, poses/animation, hit effects
scripts/stages/           Neon District Rooftop stage builder
scripts/match/            Match controller, camera, HUD, pause and results screens
scripts/ui/               Menus, settings, theme
scripts/autoload/         Settings, input mapping, audio, game state (global singletons)
data/fighters/*.tres      Fighter stats and every move's frame data (editable in the Inspector)
data/ai/*.tres            CPU difficulty profiles (editable in the Inspector)
shaders/                  Wet floor, city windows, animated screens, flag, light beams
assets/fonts/             Orbitron + Rajdhani (SIL Open Font License)
tests/                    Automated tests (see TESTING.md)
tools/                    Data generator and benchmark (developer tools)
release/                  Ready-to-run Windows build (zip)
```

### Tuning without code
In Godot's **FileSystem** panel, double-click `data/fighters/kairo.tres` (or `vesper.tres`).
The **Inspector** shows health, walk speed, jump height and every move. Click a move to edit its
startup / active / recovery frames, damage, hit stun, hit box and more. Difficulty profiles in
`data/ai/` work the same way. Save with **Ctrl+S**.

### How it is built (short version)
- **Combat runs on a fixed 60 Hz simulation** (`CombatWorld`, `FighterSim`, `MatchFlow`)
  that is independent of the rendering frame rate and of the node tree. Keyboard, gamepad and
  CPU all produce the same `InputState`, so every control method follows the same rules.
- Hits use **frame data + rectangular hit/hurt boxes** on the 2D combat plane. Physics
  collisions are never used to decide hits.
- The visuals (`FighterView`, `Vfx`, `FightCamera`, HUD) only *read* the simulation and
  react to its events.

## 5. Known limitations (honest list)

- **Placeholder characters.** The fighters are built from primitive shapes with PBR materials,
  procedural pose animation, foot grounding and hair/ribbon physics. They are original and
  readable, but far from AAA sculpted, rigged and motion-captured characters.
- **Visual quality has not been seen on a real screen.** The cloud build environment has no GPU or
  display, so lighting, colours, rain, fog and effects were never viewed. Please check them on
  your PC (see the visual checklist in [TESTING.md](TESTING.md)).
- One stage (Neon District Rooftop) and two fighters in this milestone. No super meter yet.
- Key remapping is supported by the input architecture (`scripts/autoload/input_config.gd`),
  but there is no in-game remapping screen yet.
- Sound effects and music are synthesised by code. They are functional and original, but simple.
- The exported `.exe` has no custom icon (setting it requires the `rcedit` tool on Windows;
  see BUILD_WINDOWS.md).

## 6. Documentation
- [BUILD_WINDOWS.md](BUILD_WINDOWS.md): make your own Windows `.exe`, step by step
- [TESTING.md](TESTING.md): the tests that were actually run, and what still needs a human
- [ASSET_LICENSES.md](ASSET_LICENSES.md): every third-party asset and its licence

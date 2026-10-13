# Asset licences

NEON VANGUARD uses **no paid assets and no proprietary asset packs.**

## Third-party assets

| Asset | Files | Author | Licence | Source |
|---|---|---|---|---|
| Orbitron (ExtraBold 800) | `assets/fonts/Orbitron-ExtraBold.ttf` | The Orbitron Project Authors (Matt McInerney) | SIL Open Font License 1.1 (`assets/fonts/OFL-Orbitron.txt`) | Google Fonts |
| Rajdhani (SemiBold 600, Bold 700) | `assets/fonts/Rajdhani-SemiBold.ttf`, `assets/fonts/Rajdhani-Bold.ttf` | Indian Type Foundry | SIL Open Font License 1.1 (`assets/fonts/OFL-Rajdhani.txt`) | Google Fonts |
| Godot Engine 4.7.2 (runtime inside the exported `.exe`) | export template | Godot Engine contributors | MIT License (see <https://godotengine.org/license>) | godotengine.org |

The SIL OFL allows the fonts to be bundled and redistributed with the game, including commercially,
as long as the licence files stay with them and the fonts are not sold on their own.

Godot's MIT licence asks that its copyright notice be included with the game. The main menu shows
*"Made with Godot Engine (MIT License), © Godot Engine contributors · Fonts: Orbitron, Rajdhani (SIL OFL 1.1)"*
in its bottom-right corner.

## Original assets created for this project

Everything else was created specifically for NEON VANGUARD and is original:

- **Characters (KAIRO, VESPER):** built procedurally from primitive meshes in
  `scripts/visual/fighter_rig.gd`; poses in `scripts/visual/pose_library.gd`.
- **Stage (Neon District Rooftop):** built procedurally in `scripts/stages/neon_rooftop.gd`.
  All signs and brands (VOLTEX, NOODLE 24H, HOTEL ORBITA, KAIZEN LABS, SYNTH COLA, VANGUARD CHAMPIONSHIP) are fictional.
- **Shaders:** `shaders/*.gdshader`.
- **Sound effects and music:** synthesised at runtime by `scripts/audio/sfx_synth.gd`.
  No audio files or samples are used.
- **Icon:** `icon.svg`.
- **Fighter names, biographies, move names and frame data:** original writing in `data/` and `tools/build_data.gd`.

No characters, models, logos, move lists, music or interface art from any existing game were used.

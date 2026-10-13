# Testing

This file records the tests that were **actually run** for v0.1.0, their results, the bugs they
found, and the checks that still need a person with a Windows PC, a screen and a controller.

## Test environment

| | |
|---|---|
| Engine | Godot **4.7.2.stable.official** (`ed1daf0bf`), standard edition, Linux x86_64 binary |
| Host | Ubuntu 24.04 cloud container, Intel Xeon @ 2.80 GHz (4 cores), 15 GB RAM |
| GPU / display | **None.** Godot ran in `--headless` mode (dummy renderer, dummy audio driver) |
| Date | 2026-10-13 |

Because the environment has no GPU, **nothing was ever rendered to a screen**. Everything below
proves logic, scene loading, scripts, input routing and packaging. It does not prove how the game
looks or feels.

## How to run the tests yourself

From the project folder (where `project.godot` is), using the Godot 4.7 console executable:

```
# Full suite (logic + scene tests), as a scene: works in the editor and in exported builds
godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn

# Same suite via script entry point
godot --headless --path . --fixed-fps 60 --script res://tests/run_all_tests.gd

# Logic tests only (fast)
godot --headless --path . --script res://tests/logic_runner.gd

# Inside an exported build that includes the tests folder (the Linux preset does)
./NeonVanguard.x86_64 --headless --fixed-fps 60 -- --self-test
```
The process exits with code 0 when everything passes and 1 otherwise, and prints
`ALL TESTS PASSED (...)` or a list of failures.

## 1. Project opens / parses (passed)

- `godot --headless --path . --import`: project imports with **no errors and no warnings**.
  All scripts, scenes, shaders references and fonts load.
- `godot --headless --path . --quit-after 200` (boot into the main menu and run 200 frames): exit 0, no errors.

## 2. Automated combat logic tests: 25/25 passed

File: `tests/combat_tests.gd`. These drive the real `CombatWorld` / `FighterSim` / `MatchFlow` /
`CpuController` frame by frame.

| Test | What it proves |
|---|---|
| `test_data_complete` | Both fighters load and define all 13 required moves with valid frame data |
| `test_jab_damages_only_on_active_frame` | Damage lands exactly on the first active frame (frame `1 + startup`) and equals the move's damage |
| `test_out_of_range_whiffs` | Attacks do not hit from 3 m away |
| `test_standing_block_prevents_damage` | Holding back blocks: 0 damage, exactly one block event, block stat recorded |
| `test_low_attack_needs_crouch_block` | Lows hit standing guards; crouching guard blocks them |
| `test_block_level_rules` | Mid/low/overhead/unblockable rules, no blocking while holding forward, no air blocking |
| `test_chip_damage_cannot_ko` | Blocked special at 3 HP leaves exactly 1 HP |
| `test_chain_combo_and_scaling` | Light→Medium→Heavy chain is a true 3-hit combo, damage scaling gives exactly 30+55+81 |
| `test_throw_beats_block` | Throws grab blocking opponents, deal throw damage, cause knockdown |
| `test_throw_tech` | Pressing Throw while grabbed breaks the throw with no damage |
| `test_projectile_hits` | Pulse Shot spawns, travels, hits, is cleaned up; only one projectile at a time |
| `test_projectiles_clash` | Opposing projectiles cancel with no damage |
| `test_counter_stance` | Still Water absorbs a jab and the Riposte deals its damage |
| `test_evade_is_invulnerable` | Mirage Flip cannot be hit during its invulnerable frames |
| `test_knockdown_and_wakeup` | Sweep → knockdown (invulnerable) → wake-up → idle |
| `test_held_button_triggers_once` | Holding a button for 40 frames starts exactly one attack (no repeat triggering) |
| `test_no_duplicate_hits_per_attack` | A single-hit move registers exactly one hit |
| `test_multi_hit_special` | Razor Flurry hits exactly 4 times |
| `test_determinism` | Two identical CPU-vs-CPU matches produce identical results, frame for frame |
| `test_round_transition` | Intro locks input, KO ends the round, wins recorded, round 2 resets health, winner poses |
| `test_match_completion` | Two round wins end the match exactly once. No events after the end. Rematch resets |
| `test_timeout_rules` | Time-out goes to the healthier fighter; equal health is a draw with no win awarded |
| `test_double_ko_is_draw` | Simultaneous KO is a draw. Endless draws end as a "draw game" (no infinite loop) |
| `test_soak_invariants` | 3 full Hard-vs-Hard matches: health always in range, fighters never leave the stage, never sink below the floor, never stuck in stun > 400 frames, never exceed the camera separation limit |
| `test_ai_completes_matches` | All 3 difficulties × 4 fighter pairings play complete best-of-3 matches against Normal. Each CPU attacks repeatedly (not passive) and lands hits |

CPU results from `test_ai_completes_matches` (difficulty shown is P1's; P2 is always Normal):

| P1 difficulty | Match-ups | P1 match wins |
|---|---|---|
| Easy | 4 | 0 of 4 |
| Normal | 4 | 3 of 4 |
| Hard | 4 | 4 of 4 |

This confirms the difficulty levels behave differently through decision-making alone. Hard and Easy
use the same combat rules as Normal; they differ only in reaction delay, blocking, punishing and combo choices.

## 3. Automated scene tests: 54/54 checks passed

File: `tests/test_suite.gd`. These load the **real game scenes** headlessly.

- Autoloads, input actions, audio buses and the 24-sound library exist. Both music loops finish generating.
- Main menu loads with PLAY / CHARACTER SELECT / CONTROLS / SETTINGS / QUIT and has keyboard/gamepad focus.
- Character select loads, has its option rows, and changing a fighter updates the selection and cycles back.
- Settings: LOW disables MSAA and ULTRA enables 4× MSAA on the viewport, and the music volume reaches the audio bus.
- **A complete CPU-vs-CPU best-of-3 match runs inside the real match scene** (stage, fighters,
  HUD, effects, camera): it reaches FIGHT, finishes (6,082 frames, 3 rounds), shows the results
  screen, and restores normal time after the KO slow motion. Fighter visuals stay on their simulated positions.
- **Rematch twice in a row**: each reload starts a fresh match (round 1, 0–0) and reaches FIGHT.
- **Keyboard pipeline:** injected `p1_light` starts exactly one attack, and `p1_left` makes the fighter walk.
- **Pause:** the simulation does not advance while paused and resumes afterwards.
- **Local versus input routing:** Player 2's keys move only Player 2 and Player 1's keys only Player 1.
- Returning to the main menu leaves the game unpaused at normal speed.

## 4. Packaging tests

| Check | Result |
|---|---|
| Windows export (`--export-release "Windows Desktop"`) | **Succeeded.** `PE32+ executable (GUI) x86-64`, 109.9 MB, data pack embedded |
| Embedded pack contents | Fighter data, scenes, scripts, shaders, fonts present; `tests/` and `tools/` excluded |
| Linux export of the same project | Succeeded |
| **Full test suite inside the exported Linux package** (`-- --self-test`) | **ALL TESTS PASSED (25 logic tests, 54 scene checks)** |
| Windows `.exe` launched on Windows | **Not tested.** No Windows machine was available |

## 5. Performance measured

`tools/benchmark_match.gd`, 3,600 frames of a Hard-vs-Hard match scene, headless:

| mean | median | 99th percentile |
|---|---|---|
| 0.69 ms | 0.63 ms | 2.28 ms |

This is **CPU time for game logic only** (simulation, AI, animation, effects, HUD), with no rendering.
At 60 FPS the budget is 16.7 ms, so game logic is not a bottleneck. **GPU cost was not measured.**
It depends on your graphics card and the Graphics quality setting.

## 6. Bugs found by testing and fixed

| Found by | Bug | Fix |
|---|---|---|
| `test_chain_combo_and_scaling` | Fighters in hitstun/blockstun never lost their pushback speed and slid across the stage, so combos dropped | Ground friction now applies in every non-moving state |
| Exit-time leak report | Fighter ↔ world reference cycle leaked memory after each match | Fighters hold the world through a weak reference |
| Scene tests | Effect timers and settings listeners used lambdas that could run after their node was freed on scene change | Effects free themselves with node-owned tweens. Listeners use method callables (auto-disconnect) |
| Scene tests | Deferred menu focus could fire after the menu was replaced | Focus helper checks the node is still in the tree |
| Code review of shaders (headless cannot compile shaders) | Wet floor normal-map value was normalised, tilting every floor normal | Uses the correct flat tangent-space encoding |
| Framing review | Main menu shade and character-select panels covered the fighters | Fighters and info cards repositioned |

Remaining log line, harmless: when the headless test process quits, Godot reports ~11 audio stream
objects still held by the dummy audio driver ("ObjectDB instances were leaked at exit"). It happens only at
process exit with the headless audio driver and does not affect gameplay.

## 7. Manual checks still needed on your Windows PC

These need eyes, ears and hands, so they were **not** done. Please go through them once:

**Launch & display**
- [ ] `NeonVanguard.exe` starts and shows the main menu (rain, neon city, two fighters idling).
- [ ] If it does not start or shows a black screen, try `NeonVanguard_SafeMode.bat` and note which works.
- [ ] Settings → Window mode FULLSCREEN / WINDOWED switches correctly. V-Sync and Frame limit apply.
- [ ] Settings → Graphics quality LOW / MEDIUM / HIGH / ULTRA visibly changes quality (fog, reflections,
      rain density) and the frame rate stays smooth (note your GPU and FPS).

**Visual quality** (never seen by the developer)
- [ ] Fighters are clearly readable against the background. Kairo is cobalt/white/cyan, Vesper magenta/black.
- [ ] Limbs bend the right way in every move. Feet stay roughly on the floor. Hair/ribbon swing naturally.
- [ ] Wet floor shows puddle reflections of the neon. Rain is visible but not overwhelming. Fog does not hide the fighters.
- [ ] Neon signs, billboard screens, flying traffic and searchlights animate. Text on signs is readable.
- [ ] Hit sparks, flashes, block effects and dust appear at the point of contact and do not hide the fighters.
- [ ] Brightness and colours look good (not too dark, not blown out).
- [ ] HUD: health bars drain correctly with a red damage trail. Timer, round markers, combo counter and announcements are readable.

**Feel & audio**
- [ ] Controls respond immediately. Walking, jumping, dashing (double-tap) and crouching feel right.
- [ ] Every move of both fighters can be performed (see README controls), including all three specials and the throw.
- [ ] Music plays in menus and matches. Hit/block/whiff sounds play. Volume sliders work.
- [ ] Screen shake can be turned off in Settings.

**Controllers**
- [ ] An Xbox-style gamepad controls Player 1 in matches and navigates every menu.
- [ ] With two gamepads, pad 2 controls Player 2 only.

**Flow**
- [ ] Play several matches: Rematch, Character Select and Main Menu buttons all work. Pause → every option works.
- [ ] Easy feels beatable, Hard feels challenging.

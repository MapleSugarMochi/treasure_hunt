# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

《校园寻宝》 — a single-player, silent, offline pixel-art treasure-hunt game built in **Godot 4.6.3** for a high-school tech-festival exhibition. Players move a student around a campus map, find a treasure, answer one AI multiple-choice question, then a new treasure spawns and the loop repeats. No save data, no network, no audio, no branding/leaderboards/counters. Designed to be operated by on-site staff and played in 2–3 minute turns.

The Godot binary is **vendored, not installed** — use the copy under `.superpowers/toolchains/godot-4.6.3/`. On Windows, the `_console.exe` variant prints stdout (use it for headless/test runs); the plain `.exe` is for the GUI.

## Commands

All commands run from the repo root. Set an alias first:

```bash
GODOT=".superpowers/toolchains/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe"
```

**Import resources once before anything else** (required after cloning or adding assets):
```bash
$GODOT --headless --import --path .
```

**Run the game** (GUI, fullscreen):
```bash
.superpowers/toolchains/godot-4.6.3/Godot_v4.6.3-stable_win64.exe --path .
```

**Run the full test suite** (headless). `test_runner.gd` is a `SceneTree` script that auto-discovers and runs every `tests/test_*.gd`:
```bash
$GODOT --headless --path . --script tests/test_runner.gd
```
There is **no single-test flag** — each `tests/test_*.gd` is a `RefCounted` suite exposing `run(t: SceneTree)` and depends on the runner's `assert_true/assert_eq/assert_approx` helpers, so it cannot be launched standalone. To focus work, run the whole runner (it is fast; ~8k assertions). Exit code is non-zero on any failure; the final line is `RESULT assertions=N failures=M`.

**Regenerate art atlases** (headless) — PNGs under `assets/generated/` are produced from code, never hand-edited:
```bash
$GODOT --headless --path . --script tools/generate_art.gd
```

**Validate art against the palette** (headless):
```bash
$GODOT --headless --path . --script tools/validate_art.gd
```

**Capture UI evidence PNGs** (requires a real GPU — **not** `--headless`):
```bash
.superpowers/toolchains/godot-4.6.3/Godot_v4.6.3-stable_win64.exe --path . --script tools/capture_quiz_evidence.gd
```

EXE export is configured in `export_presets.cfg` (outputs `build/CampusTreasureHunt.exe`, excludes `docs/`, `tests/`, `tools/`, `assets/source/`) but **packaging is currently deferred by request** — development runs the source project, not a built EXE.

## Architecture

The main scene `src/main/main.tscn` composes all subsystems as direct children of a `Main` node, wired together in `src/main/main.gd`:

```
Main (Node, process_mode=ALWAYS)
├── GameFlow        — state machine (Node)
├── World           — tilemap layers, props, collisions (instance of world.tscn)
├── TreasureSpawner — picks spawn point, instantiates treasure (Node2D)
├── Player          — CharacterBody2D + Camera2D (instance of player.tscn)
└── UI (CanvasLayer)
    ├── NavigationHUD — rotating arrow + integer-metre distance
    └── GameUI        — start / quiz / celebration / game-over / fatal-error overlays + hearts indicator
```

**State machine** (`src/core/game_flow.gd`): `WAITING_START → SEARCHING → QUIZZING → CELEBRATING → WON → (reset) WAITING_START …`, with the wrong-answer path `QUIZZING → (failure feedback) → SEARCHING` while lives remain, or `QUIZZING → GAME_OVER → (reset) WAITING_START` when lives hit zero. Only `SEARCHING` allows player movement (`can_player_move()`). Every transition is guarded against illegal prior states, so duplicate signals (e.g. a second treasure contact) are no-ops. `Main` is the single orchestrator: it connects signals from `GameFlow`, `Treasure`, and `GameUI`, and owns `quiz_round_index` and `lives`.

**Lives & win/lose** (added 2026-08-13): each player starts with `GameConfig.STARTING_LIVES` (3) lives shown as a left-corner hearts indicator (full/empty atlas regions in `ui.png`, driven by `GameUI.set_lives(n)`; hidden on the title and terminal overlays via `set_hearts_visible`). Touching a treasure still enters `QUIZZING` and shows a `QuizBank` question (sequential, cycles every 10 rounds). Answering is **mouse-only**. One attempt per question: correct → 4s celebration → **win terminal** (`WON`, no next treasure) → auto-restart to title after the celebration; wrong → deduct one life, 2s "本轮无奖" feedback → if lives remain, `_finish_round()` spawns the next treasure and returns to `SEARCHING`; if lives are exhausted, `on_game_over()` enters `GAME_OVER`, shows the `GameOverOverlay`, and a 3s `RestartTimer` auto-restarts to `WAITING_START`. Restart (`_start_new_run()`) deterministically resets lives, question index, player position, treasure, and hearts. The 4s celebration doubles as the victory screen — there is deliberately no separate victory overlay.

**World & layout** (`src/world/`): the map is 96×72 tiles of 16px. `world_layout.gd` is the source of truth for buildings, the irregular lake, garden beds, tree/flower cells, and the 40 hand-placed `TREASURE_CELLS`. `world.gd` builds TileMapLayers, props, and collisions procedurally in `_ready()` and draws buildings, the lake outline, and the garden in `_draw()`. Spawn selection (`treasure_spawner.gd.choose_spawn_index`) filters candidate points by the 18 m minimum distance and "not the previous point", falling back to the farthest valid point.

**Pixel/metre convention**: `16 pixels = 1 metre` (`GameConfig.PIXELS_PER_METRE`). Distances are Euclidean, rounded to integer metres. Logical canvas is 640×360, integer-scaled to fullscreen; renderer is `gl_compatibility` for integrated-GPU compatibility.

**Focus/pause**: `Main` uses `process_mode = ALWAYS` while all children are `PROCESS_MODE_PAUSABLE`. `_notification(APPLICATION_FOCUS_OUT)` sets `get_tree().paused = true`; focus-in resumes. This pauses player movement and both feedback timers (celebration + failure) during blur — verified by `test_focus_pause.gd`.

## Testing conventions

Tests instantiate `main.tscn` (or individual UI scenes) into the root tree and drive them through **public test hooks** on `Main`: `start_game_for_test()`, `complete_treasure_for_test()`, `finish_celebration_for_test()`, `set_window_focused_for_test()`. They also call private methods directly via `node.call("_on_answer_pressed", index)` etc. — this is the established pattern, not a smell to refactor away.

`test_focus_pause.gd` **asserts on the content of `README.md` and `docs/qa/manual-test-checklist.md`** (e.g. README must mention `--import`, `WASD`, `Alt+F4`, "4 秒", silence, and must *not* mention an EXE double-click; the checklist must contain unchecked `- [ ]` rows and no `[x]`). Editing those docs will break tests — keep them in sync.

## Content constraints (exhibition requirements)

These are enforced by tests and by the manual QA checklist; do not regress them:
- **Silent & offline**: no audio bus/resource, no network. `test_focus_pause.gd` asserts no `default_bus_layout.tres` ships.
- **No branding, names, codes, counters, leaderboards** on screen or in logs. The only counter allowed is the lives hearts indicator (left-corner ♥♥♥); no other numeric HUD.
- **No teleport**: the player stays put across quiz/celebration/game-over/restart; `test_continuous_loop.gd` runs many bounded cycles asserting position never changes.
- **Mouse-only quiz**: never add keyboard answer handling (no `1–4`, `A–D`, Enter).

## Workflow

Design specs live in `docs/superpowers/specs/` and implementation plans in `docs/superpowers/plans/` (dated `YYYY-MM-DD-<topic>`). New features follow the spec → plan → implement sequence; the approved design doc is the authority on scope — out-of-scope ideas (NPCs, inventory, scoring, multi-map, audio) are explicitly listed as "不做" in the specs and should not be introduced.

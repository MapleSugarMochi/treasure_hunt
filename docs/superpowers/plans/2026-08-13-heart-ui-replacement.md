# Heart UI Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generated atlas hearts with 16×16 full and dimmed heart textures derived from `assets/generated/heart.jpg`.

**Architecture:** `tools/generate_art.gd` will isolate the red/black heart from the opaque JPEG checkerboard, crop it to a square, and generate two transparent PNG textures. `GameUI` will select those resources directly for the three existing heart slots; the tests and art validator will check resource identity, dimensions, transparency, and color state.

**Tech Stack:** Godot 4.6.3, GDScript, Image API, SceneTree test runner.

## Global Constraints

- Preserve `assets/generated/heart.jpg` as the user-provided source image; do not overwrite it.
- Output `heart-full.png` and `heart-empty.png` as 16×16 RGBA PNG files with nearest-neighbor scaling and transparent backgrounds.
- The empty heart must be a gray/dimmed version of the same source-heart silhouette.
- Preserve heart-slot positions, slot count, visibility rules, and existing game flow.
- Keep the game silent, offline, and dependency-free.

---

### Task 1: Generate and validate source-derived textures

**Files:**
- Modify: `tools/generate_art.gd`
- Modify: `tools/validate_art.gd`
- Modify: `assets/source/palette.md`
- Add: `assets/generated/heart.jpg`
- Add (generated): `assets/generated/heart-full.png`
- Add (generated): `assets/generated/heart-empty.png`
- Test: `tests/test_quiz_ui.gd`

**Interfaces:**
- Consumes: `HEART_SOURCE_PATH := "res://assets/generated/heart.jpg"`.
- Produces: `_heart_textures() -> Dictionary` with `full: Image` and `empty: Image`, both 16×16 RGBA.

- [ ] **Step 1: Write the failing UI texture test**

Change the full/empty assertions in `tests/test_quiz_ui.gd` to require direct `Texture2D` resources at `res://assets/generated/heart-full.png` and `res://assets/generated/heart-empty.png`, each with size `Vector2i(16, 16)`.

```gdscript
var full := hearts[0].texture
t.assert_true(full is Texture2D, "full life heart uses a direct texture")
t.assert_eq(full.resource_path, "res://assets/generated/heart-full.png", "full life uses the supplied heart")
t.assert_eq(full.get_size(), Vector2i(16, 16), "full life heart is 16 by 16")
```

- [ ] **Step 2: Verify the test fails before production changes**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --log-file '.superpowers\heart-ui-red.log' --script tests/test_runner.gd
```

Expected: `test_quiz_ui.gd` fails because the runtime still creates `AtlasTexture` regions from `ui.png` and the two separate PNGs do not exist.

- [ ] **Step 3: Implement deterministic JPEG extraction**

Add the source-path and size constants in `tools/generate_art.gd`, then generate both texture files in `_initialize()`:

```gdscript
var textures := _heart_textures()
failures += _save_png(textures.full, "heart-full.png")
failures += _save_png(textures.empty, "heart-empty.png")
```

`_heart_textures()` must classify red-dominant pixels and the dark outline as foreground, make neutral white/gray checkerboard pixels transparent, find the foreground bounds, crop a centered square, resize it with `Image.INTERPOLATE_NEAREST`, and create the dimmed texture by retaining alpha while assigning equal RGB channels at lower luminance. Keep `ui.png` at 96×32 for its navigation-and-particle consumers, clear its now-unused heart regions, and remove the old heart-mask code.

Add explicit validator checks for the two separate PNGs: 16×16 size, nonblank opaque pixels, transparent padding, red full-heart pixels, and grayscale dimmed-heart pixels. Preserve the `ui.png` 96×32 atlas-size contract in `assets/source/palette.md`.

- [ ] **Step 4: Generate and validate the assets**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --log-file '.superpowers\heart-ui-generate.log' --script tools/generate_art.gd
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --log-file '.superpowers\heart-ui-art.log' --script tools/validate_art.gd
```

Expected: both commands exit 0; both heart files are 16×16, nonblank, transparent outside the heart, and correctly colored.

- [ ] **Step 5: Commit the source, generator, validator, and generated assets**

```powershell
git add assets/generated/heart.jpg assets/generated/heart-full.png assets/generated/heart-empty.png assets/source/palette.md tools/generate_art.gd tools/validate_art.gd tests/test_quiz_ui.gd
git commit -m "feat: generate custom heart textures"
```

### Task 2: Switch GameUI to direct heart textures

**Files:**
- Modify: `src/ui/game_ui.gd`
- Modify: `tests/test_quiz_ui.gd`
- Modify: `tests/test_quiz_integration.gd`

**Interfaces:**
- Consumes: `res://assets/generated/heart-full.png` and `res://assets/generated/heart-empty.png`.
- Produces: `GameUI.set_lives(lives: int) -> void`, assigning the full texture when `index < lives` and otherwise the dimmed texture.

- [ ] **Step 1: Write the failing integration regression test**

After the first wrong answer in `tests/test_quiz_integration.gd`, assert that the third heart directly uses the dimmed source texture.

```gdscript
var depleted := ui.get_node("HeartsContainer/Heart2") as TextureRect
t.assert_eq(
    depleted.texture.resource_path,
    "res://assets/generated/heart-empty.png",
    "wrong click changes the lost life to the dimmed supplied heart"
)
```

- [ ] **Step 2: Verify the integration test fails**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --log-file '.superpowers\heart-ui-integration-red.log' --script tests/test_runner.gd
```

Expected: the new assertion fails because `GameUI` still assigns atlas textures.

- [ ] **Step 3: Replace atlas regions with direct preloaded resources**

Replace heart atlas constants and `_make_heart_atlas()` in `src/ui/game_ui.gd` with direct preloads and direct assignment:

```gdscript
const HEART_FULL_TEXTURE := preload("res://assets/generated/heart-full.png")
const HEART_EMPTY_TEXTURE := preload("res://assets/generated/heart-empty.png")

func set_lives(lives: int) -> void:
    for index in range(hearts.size()):
        hearts[index].texture = HEART_FULL_TEXTURE if index < lives else HEART_EMPTY_TEXTURE
```

Remove only atlas-construction initialization from `_ready()`. Do not change the slots, timer logic, signals, overlays, or heart visibility logic.

- [ ] **Step 4: Reimport and run the complete test suite**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --import --path . --log-file '.superpowers\heart-ui-import.log'
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --log-file '.superpowers\heart-ui-green.log' --script tests/test_runner.gd
```

Expected: both exit 0 and the final runner line reports `failures=0`.

- [ ] **Step 5: Commit UI wiring and regression tests**

```powershell
git add src/ui/game_ui.gd tests/test_quiz_ui.gd tests/test_quiz_integration.gd
git commit -m "feat: use custom heart life indicator"
```

### Task 3: Inspect and complete final verification

**Files:**
- Test: `assets/generated/heart-full.png`
- Test: `assets/generated/heart-empty.png`
- Test: `tools/validate_art.gd`
- Test: `tests/test_runner.gd`

**Interfaces:**
- Consumes: generated texture resources and `GameUI.set_lives()` from Tasks 1 and 2.
- Produces: verified source-heart UI with no regression in the life system.

- [ ] **Step 1: Inspect both generated textures at native resolution**

Open `assets/generated/heart-full.png` and `assets/generated/heart-empty.png`; confirm the full heart is red/black without checkerboard pixels and the empty heart is the same silhouette in gray.

- [ ] **Step 2: Run final validation**

Run:

```powershell
git diff --check
git status --short
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --log-file '.superpowers\heart-ui-final-art.log' --script tools/validate_art.gd
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --log-file '.superpowers\heart-ui-final-tests.log' --script tests/test_runner.gd
```

Expected: no whitespace errors; art validation reports `ART RESULT failures=0`; tests report `failures=0`.

- [ ] **Step 3: Commit final documentation or evidence only if changed**

```powershell
git add docs/qa/evidence
git commit -m "docs: verify custom heart UI"
```

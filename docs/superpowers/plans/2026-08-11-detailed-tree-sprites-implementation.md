# Detailed Tree Sprites Implementation Plan

> Superseded by `2026-08-12-faithful-tree-sprites-implementation.md`. Retained as historical implementation context only.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two flat map trees with faithful 64-by-96 pixel-art adaptations of the approved orange six-cluster tree and gold four-cluster asymmetric tree shown in the user-provided reference image.

**Architecture:** Keep `tools/generate_art.gd` as the deterministic source of truth and regenerate the existing 256-by-128 `props.png` atlas. Repack the two tree regions so they do not overlap, update runtime region constants, and enforce the visual contract through a focused image test plus the existing art validator.

**Tech Stack:** Godot 4.6.3, GDScript, Godot `Image` API, project-local headless test runner, nearest-neighbor pixel rendering.

## Global Constraints

- Treat `C:/Users/dongx/AppData/Local/Temp/codex-clipboard-52d76b3e-b717-43f9-b729-3e3994313da0.png` as the sole visual reference.
- Preserve the 256-by-128 `props.png` atlas and 64-by-96 runtime tree regions.
- Preserve tree positions, centered sprite anchors, z-index, and 16-by-16 collision footprints.
- Use approved palette colors only, with alpha values limited to 0 or 255.
- Preserve hard pixel edges; do not add antialiasing, gradients, blur, animation, particles, or cast shadows.
- Orange tree: six rounded interlocking clusters, dense silhouette, deep-green interior gaps.
- Gold tree: four offset clusters, asymmetric umbrella silhouette, exposed forked branches.
- The user selected inline execution with no intermediate confirmation gate.

---

## File map

- `tests/test_tree_art.gd`: executable visual-data contract for the two tree sprites.
- `docs/superpowers/specs/2026-08-11-detailed-tree-sprites-design.md`: update the gold tree from five clusters to the four-cluster silhouette in the final reference.
- `tools/generate_art.gd`: deterministic drawing helpers and both approved tree designs.
- `tools/validate_art.gd`: atlas layout, transparent-border, palette, and detail validation.
- `assets/generated/props.png`: regenerated runtime atlas.
- `src/world/world.gd`: nonoverlapping tree and bench region constants consumed at runtime.
- `tests/test_world_layout.gd`: integration assertions for runtime sprite regions.

### Task 1: Lock the approved tree contract with a failing test

**Files:**
- Create: `tests/test_tree_art.gd`

**Interfaces:**
- Consumes: `assets/generated/props.png` and Godot `Image.load_from_file(path)`.
- Produces: headless assertions for `TREE_REGIONS`, approved color coverage, transparent borders, occupied bounds, and silhouette difference.

- [x] **Step 1: Add the focused image contract test**

Create `tests/test_tree_art.gd` with these constants and assertions:

```gdscript
extends RefCounted

const PROPS_PATH := "res://assets/generated/props.png"
const TREE_REGIONS := [Rect2i(96, 0, 64, 96), Rect2i(160, 0, 64, 96)]
const MAX_ART_BOUNDS := [Vector2i(61, 84), Vector2i(58, 83)]
const REQUIRED_COLORS := [
    [Color("3b302b"), Color("a6533e"), Color("d87943"), Color("e2a244"), Color("527d45")],
    [Color("3b302b"), Color("a6533e"), Color("e2a244"), Color("d87943"), Color("527d45")],
]

func run(t: SceneTree) -> void:
    var image := Image.load_from_file(ProjectSettings.globalize_path(PROPS_PATH))
    t.assert_true(image != null and not image.is_empty(), "props atlas loads")
    t.assert_eq(image.get_size(), Vector2i(256, 128), "props atlas keeps its contract")
    for index in range(TREE_REGIONS.size()):
        var rect: Rect2i = TREE_REGIONS[index]
        t.assert_true(_has_transparent_border(image, rect), "tree region has transparent padding: %d" % index)
        var bounds := _opaque_bounds(image, rect)
        t.assert_true(bounds.size.x <= MAX_ART_BOUNDS[index].x, "tree width stays inside region: %d" % index)
        t.assert_true(bounds.size.y <= MAX_ART_BOUNDS[index].y, "tree height stays inside region: %d" % index)
        t.assert_true(_opaque_count(image, rect) >= 900, "tree has a substantial detailed silhouette: %d" % index)
        for color in REQUIRED_COLORS[index]:
            t.assert_true(_color_count(image, rect, color) >= 8, "tree uses required palette color: %d %s" % [index, color])
    t.assert_true(_alpha_mask_difference(image, TREE_REGIONS[0], TREE_REGIONS[1]) >= 400, "tree silhouettes differ independently of color")
```

Add local helpers `_has_transparent_border`, `_opaque_bounds`, `_opaque_count`, `_color_count`, and `_alpha_mask_difference`; each iterates only within the supplied `Rect2i` and compares pixels with `Color.to_rgba32()`.

- [x] **Step 2: Run the focused test and record the expected red state**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: nonzero exit with failures from `test_tree_art.gd` because the original flat atlas does not populate the new regions or required five-color detail.

### Task 2: Draw and validate the approved sprites

**Files:**
- Modify: `docs/superpowers/specs/2026-08-11-detailed-tree-sprites-design.md:22-28,91-94`
- Modify: `tools/generate_art.gd:42-82`
- Modify: `tools/validate_art.gd:11-32,75-90,184-214`
- Modify: `assets/generated/props.png`
- Test: `tests/test_tree_art.gd`

**Interfaces:**
- Consumes: `C` palette dictionary, `_rect(image, rect, color)`, and the local origin of each 64-by-96 region.
- Produces: `_orange_tree(image: Image, origin: Vector2i) -> void`, `_gold_tree(image: Image, origin: Vector2i) -> void`, and a regenerated atlas with tree origins at `(96, 0)` and `(160, 0)`.

- [x] **Step 1: Add deterministic pixel drawing helpers**

First align the design spec with the final user reference: the gold tree uses four, not five, offset clusters; the supplied image is the sole visual source of truth.

Implement:

```gdscript
func _ellipse_contains(point: Vector2i, center: Vector2i, radius: Vector2i) -> bool
func _thick_line(image: Image, from: Vector2i, to: Vector2i, width: int, color: Color) -> void
func _branch(image: Image, origin: Vector2i, from: Vector2i, to: Vector2i, width: int) -> void
func _leaf_cluster(image: Image, origin: Vector2i, center: Vector2i, radius: Vector2i, main: Color, shadow: Color, highlight: Color, seed: int) -> void
```

`_leaf_cluster` must draw a one-pixel dark-brown ellipse outline, a main fill, a lower shadow band, a compact upper-left highlight, and deterministic one- or two-pixel texture accents based on `(x * 17 + y * 31 + seed) % 23`. All pixels come from `C`.

- [x] **Step 2: Implement the orange reference silhouette**

Use six cluster specifications:

```gdscript
[
        [Vector2i(32, 15), Vector2i(13, 10)],
        [Vector2i(16, 32), Vector2i(14, 11)],
        [Vector2i(48, 32), Vector2i(13, 11)],
        [Vector2i(31, 43), Vector2i(14, 11)],
        [Vector2i(13, 53), Vector2i(12, 10)],
        [Vector2i(49, 53), Vector2i(12, 10)],
]
```

Draw forked branches before the clusters. Use `C.orange` main planes, `C.brick` lower shadows, `C.gold` highlights, and small `C.leaf` gaps. Keep all opaque pixels within local x=1..61 and y=5..88.

- [x] **Step 3: Implement the gold reference silhouette**

Use four cluster specifications:

```gdscript
[
        [Vector2i(37, 16), Vector2i(13, 10)],
        [Vector2i(17, 34), Vector2i(13, 10)],
        [Vector2i(49, 35), Vector2i(12, 10)],
        [Vector2i(17, 54), Vector2i(13, 10)],
]
```

Draw the exposed asymmetric fork structure before the clusters. Use `C.gold` main planes, `C.orange` lower shadows, `C.nav` highlights, and restrained `C.leaf` gaps. Keep all opaque pixels within local x=4..61 and y=6..88.

- [x] **Step 4: Repack the atlas and strengthen validation**

Draw the two trees at `(96, 0)` and `(160, 0)`, move the bench to `Rect2i(208, 96, 48, 32)`, and update validator key regions. Add a `PROP_RUNTIME_REGIONS` table and verify that regions are in bounds, pairwise nonintersecting, tree borders are transparent, tree regions use at least five colors, and no semitransparent or unapproved pixels exist.

- [x] **Step 5: Regenerate the atlas and run green checks**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . -s tools/generate_art.gd
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . -s tools/validate_art.gd
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: generator exit 0, `ART RESULT failures=0`, and the test runner reports zero failures.

### Task 3: Wire the nonoverlapping regions into the world

**Files:**
- Modify: `src/world/world.gd:14-16,80-87`
- Modify: `tests/test_world_layout.gd:43-48`

**Interfaces:**
- Produces: `CampusWorld.TREE_REGIONS: Array[Rect2]` and `CampusWorld.BENCH_REGION: Rect2`.
- Consumes: the atlas regions generated in Task 2.

- [x] **Step 1: Add failing runtime-region assertions**

Assert that the two tree regions do not intersect, every tree sprite alternates between the expected regions, and every bench sprite uses the repacked bench region.

- [x] **Step 2: Run the suite and verify the red state**

Run the headless test runner. Expected: parse or assertion failure because `CampusWorld.TREE_REGIONS` and `BENCH_REGION` do not exist yet.

- [x] **Step 3: Add runtime constants and consume them**

Add:

```gdscript
const TREE_REGIONS: Array[Rect2] = [Rect2(96, 0, 64, 96), Rect2(160, 0, 64, 96)]
const BENCH_REGION := Rect2(208, 96, 48, 32)
```

Use `TREE_REGIONS[index % TREE_REGIONS.size()]` and `BENCH_REGION` in `_add_prop_sprites()`.

- [x] **Step 4: Run the suite and validator**

Expected: zero failures and unchanged tree/bench counts and collision footprints.

### Task 4: Final visual and regression verification

**Files:**
- Verify: all modified files from Tasks 1-3

**Interfaces:**
- Consumes: generated atlas and running world.
- Produces: evidence that the visual reference and gameplay constraints are both satisfied.

- [x] **Step 1: Inspect the atlas at original and enlarged scale**

Confirm that the orange tree has six dense round clusters and the gold tree has four offset clusters with visible forks; confirm transparent padding and no atlas leakage.

- [x] **Step 2: Run full automated verification**

Run art generation, art validation, the full test runner, headless project boot, and a project resource-pack export. Every command must exit 0.

- [x] **Step 3: Inspect an actual 640-by-360 game capture**

Verify that both tree silhouettes remain distinct next to the player, match the warm map palette, and preserve player overlap and navigation readability.

- [x] **Step 4: Commit the completed implementation**

Stage the plan, generator, validator, runtime code, tests, and regenerated atlas. Commit with:

```powershell
git commit -m "feat: add detailed autumn tree sprites"
```

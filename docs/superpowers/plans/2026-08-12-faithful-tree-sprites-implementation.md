# Faithful Tree Sprites V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bubble-like procedural trees with palette-safe 64-by-96 source sprites faithfully extracted from the approved reference image.

**Architecture:** Store the two final tree sprites under `assets/source/trees`. Make `tools/generate_art.gd` validate and copy those source pixels into the existing atlas regions without scaling, and use image-data tests to enforce source presence, pixel equality, palette detail, transparent borders, and runtime contracts.

**Tech Stack:** Godot 4.6.3, GDScript, Godot `Image`, nearest-neighbor raster extraction, 17-color project palette, project-local headless tests.

## Global Constraints

- Use `C:/Users/dongx/AppData/Local/Temp/codex-clipboard-d47bf1b7-31f4-4c17-b98d-de7dacf604f9.png` as the visual source of truth.
- Preserve the 256-by-128 `props.png` atlas.
- Preserve tree regions `(96, 0, 64, 96)` and `(160, 0, 64, 96)` and bench region `(208, 96, 48, 32)`.
- Preserve centered anchors, tree positions, z-index, and 16-by-16 collision footprints.
- Use only the approved 17 colors and alpha values 0 or 255.
- Preserve a fully transparent one-pixel border around each tree region.
- Do not add gradients, runtime resampling, antialiasing, blur, animation, particles, or cast shadows.

---

### Task 1: Lock the source-art contract with a failing test

**Files:**
- Modify: `tests/test_tree_art.gd`

**Interfaces:**
- Consumes: `assets/generated/props.png` and the intended source paths.
- Produces: source existence, 64-by-96 size, pixel equality, distinct-color, and opaque-color-edge assertions.

- [x] **Step 1: Add source and texture assertions**

Add these literal contracts:

```gdscript
const TREE_SOURCE_PATHS := [
    "res://assets/source/trees/orange-tree-reference.png",
    "res://assets/source/trees/gold-tree-reference.png",
]
const MIN_DISTINCT_COLORS := [10, 10]
const MIN_OPAQUE_COLOR_EDGES := [2200, 2000]
```

For each tree, assert that the source exists, loads as 64 by 96, matches the atlas region pixel-for-pixel, uses at least the required number of opaque colors, and contains the required number of adjacent opaque color changes.

- [x] **Step 2: Verify RED on the procedural atlas**

Run the complete test runner. Expected: six focused failures—two missing source files, two insufficient shading-range failures, and two insufficient texture-density failures.

### Task 2: Produce palette-safe source sprites from the reference

**Files:**
- Create: `assets/source/trees/orange-tree-reference.png`
- Create: `assets/source/trees/gold-tree-reference.png`

**Interfaces:**
- Consumes: the approved 1200-by-1316 reference image.
- Produces: two transparent, hard-edged, palette-safe 64-by-96 PNGs.

- [x] **Step 1: Extract the clean standalone trees**

Use source rectangles `(52,35,520,675)` for orange and `(650,70,510,645)` for gold. Resize with nearest-neighbor sampling to 62 by 84 at offset `(1,4)` and 60 by 81 at offset `(2,7)` respectively inside transparent 64-by-96 canvases.

- [x] **Step 2: Remove the cream background and map colors**

Discard near-neutral cream pixels where red is above 220, green above 215, blue above 195, and the RGB channel spread is below 50. Map every remaining pixel to the nearest approved palette color by squared RGB distance, then force alpha to 255.

- [x] **Step 3: Inspect both source sprites**

Confirm that orange retains the six interlocking leaf masses and broad trunk, while gold retains four asymmetric masses, visible forks, negative space, and roots.

### Task 3: Make source sprites the deterministic atlas input

**Files:**
- Modify: `tools/generate_art.gd`
- Modify: `assets/generated/props.png`
- Test: `tests/test_tree_art.gd`

**Interfaces:**
- Produces: `_validate_tree_sources() -> int` and `_blit_tree_source(image: Image, source_path: String, origin: Vector2i) -> void`.
- Consumes: the two source PNGs and the existing atlas origins `(96,0)` and `(160,0)`.

- [x] **Step 1: Validate source files before generation**

Fail generation when either source is missing, unreadable, or not exactly 64 by 96 pixels.

- [x] **Step 2: Copy source pixels into the atlas**

Use `Image.blit_rect` to copy each full source image into its existing runtime region. Do not scale, recolor, or procedurally overdraw the source pixels.

- [x] **Step 3: Remove the obsolete procedural tree renderer**

Delete the ellipse, lobe, branch, trunk, root, orange-tree, and gold-tree functions so only one tree generation path remains.

- [x] **Step 4: Regenerate and verify GREEN**

Run the generator, validator, and full test runner. Expected: `ART GENERATION failures=0`, `ART RESULT failures=0`, and zero test failures.

### Task 4: Visual and regression verification

**Files:**
- Verify: `assets/generated/props.png`
- Verify: `assets/source/trees/*.png`
- Verify: all modified code, tests, and documentation

**Interfaces:**
- Produces: an 8x atlas review, a native 640-by-360 map review, complete test evidence, and a commit.

- [x] **Step 1: Render review images**

Render both atlas regions at 8x nearest-neighbor scale. Render both trees at native scale beside the 24-by-32 player on a 640-by-360 project-grass background.

- [x] **Step 2: Inspect against the approved reference**

Verify irregular layered foliage, orange density, gold asymmetry and branch negative space, modeled trunks, visible roots, hard transparent edges, and correct player-relative scale.

- [x] **Step 3: Run final regression verification**

Run `git diff --check`, art generation, art validation, the complete test runner, headless boot, and Windows resource-pack export. Every command must exit 0.

- [x] **Step 4: Commit the implementation**

Stage only the design/plan, source sprites, tests, generator, and regenerated atlas. Commit with:

```powershell
git commit -m "feat: redraw autumn trees from reference"
```

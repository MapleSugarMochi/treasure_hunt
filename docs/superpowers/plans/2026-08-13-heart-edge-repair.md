# Heart Edge Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Regenerate `heart-full.png` and `heart-empty.png` as clean 16×16 hard-edged pixel art with continuous silhouettes, preserved highlights, and no internal transparent holes.

**Architecture:** `tools/generate_art.gd` remains the only producer of the runtime heart textures. It will replace color-only cutout plus nearest-neighbor sampling with border-connected background extraction and coverage-based 16×16 quantization; `tools/validate_art.gd` will enforce topology and pairwise Alpha invariants on the generated artifacts.

**Tech Stack:** Godot 4.6.3, GDScript, Godot `Image`, PNG RGBA8, headless art validation and project tests.

## Global Constraints

- Keep both runtime assets at exactly 16×16 RGBA PNG.
- Alpha values must be only 0 or 255; do not introduce antialiasing.
- Preserve red fill, dark outline, light highlight, and right-side shading from `assets/generated/heart.jpg`.
- Full and empty heart Alpha masks must match pixel-for-pixel.
- Do not change UI layout, resource paths, life count, or gameplay logic.
- Do not modify unrelated generated atlases or untracked map-layout files.

## File Structure

- Modify `tools/validate_art.gd`: own artifact-level Alpha, connectivity, and transparent-hole assertions.
- Modify `tools/generate_art.gd`: own source-background extraction, 16×16 coverage quantization, and topology cleanup.
- Regenerate `assets/generated/heart-full.png`: source-derived full-life texture.
- Regenerate `assets/generated/heart-empty.png`: grayscale texture derived from the full-life Alpha mask.

---

### Task 1: Repair and validate heart generation

**Files:**
- Modify: `tools/validate_art.gd:99-181`
- Modify: `tools/generate_art.gd:89-170`
- Regenerate: `assets/generated/heart-full.png`
- Regenerate: `assets/generated/heart-empty.png`
- Test: `assets/generated/heart-full.png`
- Test: `assets/generated/heart-empty.png`

**Interfaces:**
- Consumes: `assets/generated/heart.jpg`, the existing `_heart_bounds()` result, `HEART_TEXTURE_SIZE`, and the generated PNGs loaded as Godot `Image` values.
- Produces: `_opaque_component_count(image: Image) -> int`, `_has_transparent_hole(image: Image) -> bool`, `_validate_heart_pair() -> int`, `_connected_background(region: Image) -> Dictionary`, `_quantize_heart(region: Image, background: Dictionary) -> Image`, `_keep_largest_component(image: Image) -> void`, and `_fill_internal_holes(image: Image) -> void`.

#### Phase A: Add the failing artifact validation

- [ ] **Step 1: Add the pairwise and topology assertions**

After the existing per-heart loop in `_initialize()`, call:

```gdscript
failures += _validate_heart_pair()
```

In `_validate_heart_texture()`, after counting pixels, require one 8-connected opaque component and no 4-connected transparent region enclosed by the icon:

```gdscript
var components := _opaque_component_count(image)
if components != 1:
    push_error("Heart texture must contain one connected foreground in %s: components=%d" % [file_name, components])
    failures += 1
if _has_transparent_hole(image):
    push_error("Heart texture has an internal transparent hole: %s" % file_name)
    failures += 1
```

Add `_validate_heart_pair()` to load both images and compare Alpha byte-for-byte:

```gdscript
func _validate_heart_pair() -> int:
    var full := Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/heart-full.png"))
    var empty := Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/heart-empty.png"))
    if full == null or empty == null or full.is_empty() or empty.is_empty():
        push_error("Cannot compare heart Alpha masks")
        return 1
    var failures := 0
    for y in range(full.get_height()):
        for x in range(full.get_width()):
            var full_alpha := int(round(full.get_pixel(x, y).a * 255.0))
            var empty_alpha := int(round(empty.get_pixel(x, y).a * 255.0))
            if full_alpha != empty_alpha:
                push_error("Heart Alpha mismatch at (%d,%d): full=%d empty=%d" % [x, y, full_alpha, empty_alpha])
                failures += 1
    return failures
```

Implement connectivity with an explicit frontier of opaque coordinates and the eight offsets around each pixel. Implement hole detection by seeding all transparent border coordinates, traversing transparent pixels with the four cardinal offsets, and reporting any transparent coordinate not reached from the border.

- [ ] **Step 2: Run the validator and prove the current asset fails**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --log-file '.superpowers\heart-edge-red.log' --script tools/validate_art.gd
```

Expected: nonzero exit and `Heart texture has an internal transparent hole` for the current full and empty textures. If it does not fail for that reason, stop and correct the topology assertion before changing the generator.

#### Phase B: Replace color-only extraction with connected-background extraction

- [ ] **Step 1: Preserve the existing red/dark bounds detector but replace the cutout loop**

Change `_heart_textures()` so it crops the source, classifies only border-connected neutral checker pixels as background, and passes the result to the quantizer:

```gdscript
var crop_rect := _square_crop(bounds, source.get_size())
var region := source.get_region(crop_rect)
var background := _connected_background(region)
var full := _quantize_heart(region, background)
return {"full": full, "empty": _dimmed_heart(full)}
```

Classify a JPEG pixel as a possible checkerboard pixel only when it is bright and nearly neutral:

```gdscript
func _is_checker_candidate(pixel: Color) -> bool:
    var red := int(round(pixel.r * 255.0))
    var green := int(round(pixel.g * 255.0))
    var blue := int(round(pixel.b * 255.0))
    var minimum := mini(red, mini(green, blue))
    var maximum := maxi(red, maxi(green, blue))
    return minimum >= 185 and maximum - minimum <= 24
```

`_connected_background()` must seed candidate pixels on all four borders, then traverse only candidate pixels with four-way adjacency. Return a `Dictionary` keyed by `Vector2i`, so identical white pixels enclosed by the black/red heart remain foreground while the baked checkerboard remains background.

- [ ] **Step 2: Add an extraction guard before quantization**

Count the non-background region pixels. If the count is zero or fills the entire crop, emit `Invalid connected-background heart extraction` and return an empty image. In `_heart_textures()`, treat an empty quantized image as a generation error and return `{}`.

- [ ] **Step 3: Run the validator without regenerating to keep the red test stable**

Run the Task 1 validator command again.

Expected: the same transparent-hole failure, proving only generator code changed and the failing artifact has not been silently replaced.

#### Phase C: Quantize by coverage and repair topology

- [ ] **Step 1: Implement coverage-based 16×16 quantization**

For each target coordinate, calculate source cell bounds with floor/ceil scaling:

```gdscript
var x_start := floori(float(target_x) * region.get_width() / HEART_TEXTURE_SIZE.x)
var x_end := ceili(float(target_x + 1) * region.get_width() / HEART_TEXTURE_SIZE.x)
var y_start := floori(float(target_y) * region.get_height() / HEART_TEXTURE_SIZE.y)
var y_end := ceili(float(target_y + 1) * region.get_height() / HEART_TEXTURE_SIZE.y)
```

Count coordinates not present in `background`. Emit an opaque target pixel when foreground coverage is at least 35%. Select the foreground source pixel nearest the source-cell center; when the cell mixes foreground and background and contains a dark foreground pixel with all channels at or below 80, select the nearest such dark pixel so boundary cells keep a continuous dark outline. Always write Alpha 255.

- [ ] **Step 2: Remove quantization specks and fill enclosed transparent cells**

`_keep_largest_component()` must find all 8-connected opaque components, keep the component with the most coordinates, and clear every other coordinate to transparent.

`_fill_internal_holes()` must flood transparent pixels from the 16×16 border using four-way adjacency. For each unreached transparent coordinate, copy the RGB value of the nearest opaque coordinate and write Alpha 255. Call the cleanup functions in this order:

```gdscript
_keep_largest_component(result)
_fill_internal_holes(result)
```

- [ ] **Step 3: Regenerate the art and run the focused validator**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --log-file '.superpowers\heart-edge-generate.log' --script tools/generate_art.gd
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --log-file '.superpowers\heart-edge-green.log' --script tools/validate_art.gd
```

Expected: both exit 0; validator reports `ART RESULT failures=0`; both heart reports show nonzero opaque and transparent pixels.

- [ ] **Step 4: Inspect the exact 16×16 pixel matrices**

Print each texture as a 16-line grid where `.` is transparent, `#` is dark outline, `R` is red/pink fill, `L` is light highlight, and `g` is grayscale. Confirm:

- no transparent cell is enclosed by the opaque silhouette;
- the outer outline is continuous without isolated `#` cells;
- the full heart contains at least one light highlight cell;
- full and empty grids use the same transparent coordinates.

- [ ] **Step 5: Run project import and the full regression suite**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --import --path . --log-file '.superpowers\heart-edge-import.log'
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --log-file '.superpowers\heart-edge-tests.log' --script tests/test_runner.gd
git diff --check
```

Expected: import exits 0, the runner reports `failures=0`, and Git reports no whitespace errors.

- [ ] **Step 6: Commit the repair without staging unrelated files**

```powershell
git add tools/generate_art.gd tools/validate_art.gd assets/generated/heart-full.png assets/generated/heart-empty.png
git commit -m "fix: clean up heart icon edges"
```

Before committing, verify `git status --short` shows the existing untracked map-layout and cache files remain unstaged.

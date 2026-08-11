# Detailed Tree Sprites Design

Date: 2026-08-11
Status: Implemented and verified

## Objective

Replace the two flat tree silhouettes in `assets/generated/props.png` with two detailed, clearly different autumn tree silhouettes based on the approved layered-canopy concept. Preserve the existing warm campus pixel-art language and all gameplay behavior.

## Approved visual direction

Both trees belong to one sprite family: hard-edged 16-bit pixel art, dark-brown outlines, stepped canopy contours, clustered highlight and shadow planes, and the same trunk baseline. They differ in silhouette rather than merely changing color.

### Orange tree: rounded clustered crown

- Use six interlocking leaf clusters to form a wide, dense, rounded crown.
- Use orange as the main plane, gold on upper-facing cluster edges, and deep green in interior gaps.
- Reveal only short branch segments between clusters so the tree remains full and friendly.
- Keep the occupied artwork within a maximum 61-by-84-pixel box inside its 64-by-96-pixel region.
- Keep the root/trunk baseline at local y=88 so the existing centered sprite anchor remains visually stable.

### Gold tree: asymmetric umbrella crown

- Use four offset leaf clusters to create a narrower, visibly asymmetric umbrella silhouette matching the final user-provided reference image.
- Use gold as the main plane, orange on lower-facing cluster edges, and restrained deep green in inner shadow pockets.
- Reveal a forked trunk and longer branch segments to distinguish it from the orange tree at gameplay size.
- Keep the occupied artwork within a maximum 58-by-83-pixel box inside its 64-by-96-pixel region.
- Use the same local y=88 root/trunk baseline as the orange tree.

## Shared constraints

- Preserve the `props.png` atlas size at 256 by 128 pixels.
- Preserve 64-by-96 runtime tree regions and the current centered `Sprite2D` anchor behavior.
- Preserve the 16-by-16 single-cell collision footprint, tree locations, z-index, and player overlap behavior.
- Use only the approved project palette, principally:
  - outline `#3B302B`
  - orange `#D87943`
  - gold `#E2A244`
  - deep leaf green `#527D45`
- Use fully opaque or fully transparent pixels only. Do not add antialiasing, gradients, blur, semitransparency, cast shadows, animation, or extra world decorations.
- Both trees must remain readable at the native 640-by-360 logical viewport and under integer scaling.

## Atlas layout

The current runtime tree regions start at x=88 and x=136, which overlap by 16 pixels. Detailed silhouettes would risk leaking pixels between variants. Repack the atlas without changing its total dimensions:

- Keep the existing building artwork in the left side of the atlas.
- Orange tree region: `Rect2(96, 0, 64, 96)`.
- Gold tree region: `Rect2(160, 0, 64, 96)`.
- Bench region: `Rect2(208, 96, 48, 32)`.
- Leave transparent padding around each tree so no nontransparent pixel touches an adjacent runtime region.

Update the runtime region selection and validator expectations to match this nonoverlapping layout. No scene or world-layout changes are required.

## Asset generation

`tools/generate_art.gd` remains the source of truth. Build each canopy from deterministic stepped pixel clusters rather than importing the concept image directly. Draw in this order:

1. trunk and primary branches;
2. dark outline or underside silhouette;
3. main-color leaf clusters;
4. secondary shadow planes;
5. sparse highlight pixels and small deep-green interior gaps.

Regenerate `assets/generated/props.png` from the script. Do not hand-edit the generated atlas without updating the generator.

## Runtime and validation changes

- Update `src/world/world.gd` to use both new tree regions and the new bench region.
- Update `tools/validate_art.gd` key regions for the repacked atlas.
- Extend validation where necessary to confirm atlas dimensions, nonblank tree regions, approved colors, and the absence of unintended alpha values.
- Preserve existing tree count, collision positions, and alternating variant selection.

## Failure handling

- Art generation must exit nonzero if the atlas cannot be saved.
- Atlas validation must fail on wrong dimensions, blank required regions, disallowed colors, or semitransparent pixels.
- If either silhouette becomes unclear at native scale, simplify interior pixels before enlarging the sprite or changing gameplay geometry.

## Verification

1. Run the deterministic art generator and atlas validator.
2. Run the existing automated test suite to confirm world layout, tree count, collisions, scene boot, and UI behavior remain unchanged.
3. Inspect both tree regions at 800% nearest-neighbor scale for stray pixels or region leakage.
4. Inspect the running game at the native 640-by-360 viewport and verify that:
   - the two silhouettes are distinguishable without relying on color;
   - both trees match the existing terrain, player, buildings, and props;
   - the player/tree overlap remains legible;
   - no tree pixels leak into the other tree or bench sprite.

## Acceptance criteria

- The orange tree reads as a wide rounded six-cluster crown.
- The gold tree reads as a narrower asymmetric four-cluster umbrella crown with more visible branches.
- Both sprites show substantially more internal detail than the original flat blocks.
- The atlas remains 256 by 128 pixels and uses the approved palette with hard opaque pixels.
- Existing world geometry, collision behavior, camera behavior, treasure placement, and HUD behavior are unchanged.
- Art validation and the full automated test suite pass.

## Out of scope

- Tree animation or seasonal transitions.
- New tree placements, collision sizes, shadows, particles, falling leaves, or sound.
- Redesigning terrain, buildings, benches, flowers, player art, UI, or treasure art.

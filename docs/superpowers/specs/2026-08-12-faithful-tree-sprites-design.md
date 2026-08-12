# Faithful Tree Sprites V2 Design

Date: 2026-08-12
Status: Implemented and verified

## Objective

Replace the bubble-like tree rendering with two detailed 64-by-96 pixel-art trees that reproduce the composition, weight, and autumn color hierarchy of the supplied reference as closely as the existing atlas and palette permit.

## Problem with the current sprites

The current generator treats every canopy mass as a smooth ellipse with a uniform one-pixel ring. At native scale this reads as a collection of separate orange circles on thin sticks. The reference instead uses broad overlapping leaf masses, irregular stepped edges, layered shadows, thick trunks, visible forks, and wide roots.

## Approaches considered

1. Enlarge the existing ellipses. This increases coverage but preserves the bubble silhouette and was rejected.
2. Build hand-directed, multi-lobed masses in code. A tested prototype improved coverage but still read as regular circles at native scale, so it was rejected after visual inspection.
3. Extract the two approved trees from the clean upper portion of the reference, resize with nearest-neighbor sampling, remove the cream background, and map every opaque pixel to the approved palette. Store the resulting 64-by-96 PNGs as source art and blit them into the generated atlas without resampling. This is the selected approach because it preserves the reference composition and remains deterministic.

## Selected visual design

### Orange tree

- Six large, interlocking canopy masses form one dense, rounded silhouette taken directly from the approved reference.
- Stepped outer edges and irregular internal leaf planes must survive palette mapping and native-size rendering.
- Gold highlights occupy upper-left planes, orange is the main body, brick red forms broad lower shadow planes, and dark brown defines outer and inter-mass edges.
- Deep-green gaps are limited to small branch junctions; no large transparent holes may split the crown.
- The trunk and roots retain the reference's dark brown, brick red, warm highlight, and gray-brown shadow modeling.

### Gold tree

- Four offset canopy masses reproduce the asymmetric umbrella silhouette: top, middle-left, middle-right, and lower-left.
- The masses remain visually separate enough to expose the reference's forked branch structure and negative space.
- Navigation gold is the highlight, autumn gold is the main body, orange is the lower shadow, and brick red supplies the deepest leaf shadow.
- The curved trunk, branches, and roots retain their reference proportions after downscaling.

## Rendering architecture

`assets/source/trees/orange-tree-reference.png` and `assets/source/trees/gold-tree-reference.png` are the editable source-of-truth sprites. Each is exactly 64 by 96 pixels with hard alpha and approved palette colors. `tools/generate_art.gd` validates that both files exist, load successfully, and have the required size before copying them pixel-for-pixel into `props.png`.

The generator performs no scaling, recoloring, or procedural overdrawing. Both trees keep the existing atlas origins, runtime regions, centered anchors, z-index, and 16-by-16 collision footprints.

## Hard constraints

- `props.png` remains 256 by 128 pixels.
- Tree regions remain `Rect2i(96, 0, 64, 96)` and `Rect2i(160, 0, 64, 96)`.
- The bench remains in `Rect2i(208, 96, 48, 32)`.
- Every opaque pixel uses the approved 17-color palette and alpha 255; every other pixel has alpha 0.
- Every tree keeps a fully transparent one-pixel region border.
- No gradients, antialiasing, blur, semitransparency, animation, or cast shadows.
- The reference image is the visual source of truth; numeric tests are regression guards, not substitutes for visual inspection.

## Verification

- A focused tree-art test must fail when the source sprites are missing or the bubble-like atlas lacks the reference's shading range and texture density.
- The test must verify that each generated atlas region matches its corresponding 64-by-96 source sprite pixel-for-pixel.
- The art generator and validator must report zero failures.
- The full Godot test runner must report zero failures.
- A native 640-by-360 capture and an enlarged atlas review must be inspected against the supplied reference.
- Headless project boot and resource-pack export must exit successfully.

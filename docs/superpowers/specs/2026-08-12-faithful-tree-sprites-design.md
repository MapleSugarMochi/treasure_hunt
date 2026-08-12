# Faithful Tree Sprites V2 Design

Date: 2026-08-12
Status: Approved by the user-provided reference image

## Objective

Replace the bubble-like tree rendering with two detailed 64-by-96 pixel-art trees that reproduce the composition, weight, and autumn color hierarchy of the supplied reference as closely as the existing atlas and palette permit.

## Problem with the current sprites

The current generator treats every canopy mass as a smooth ellipse with a uniform one-pixel ring. At native scale this reads as a collection of separate orange circles on thin sticks. The reference instead uses broad overlapping leaf masses, irregular stepped edges, layered shadows, thick trunks, visible forks, and wide roots.

## Approaches considered

1. Enlarge the existing ellipses. This increases coverage but preserves the bubble silhouette and was rejected.
2. Scale or paste the reference into the atlas. This introduces uncontrolled colors and resampling artifacts and breaks deterministic regeneration, so it was rejected.
3. Build hand-directed, multi-lobed pixel masses in the deterministic generator. This preserves the atlas contract while allowing irregular outlines and layered shading. This is the selected approach.

## Selected visual design

### Orange tree

- Six large, interlocking canopy masses form one dense, rounded silhouette.
- Each mass is the union of several offset lobes, producing stepped and scalloped edges rather than mathematical ellipses.
- Gold highlights occupy upper-left planes, orange is the main body, brick red forms broad lower shadow planes, and dark brown defines outer and inter-mass edges.
- Deep-green gaps are limited to small branch junctions; no large transparent holes may split the crown.
- The top canopy scanline at local y=15 must cover at least 33 pixels.
- The trunk and roots use dark brown, brick red, warm path highlights, and warm gray-brown shadow accents. The opaque trunk span at local y=70 must cover at least 15 pixels.

### Gold tree

- Four offset canopy masses reproduce the asymmetric umbrella silhouette: top, middle-left, middle-right, and lower-left.
- Each mass uses the same multi-lobed edge construction but remains visually separate enough to expose the forked branch structure.
- Navigation gold is the highlight, autumn gold is the main body, orange is the lower shadow, and brick red supplies the deepest leaf shadow.
- The top canopy scanline at local y=15 must cover at least 31 pixels; the lower-left mass at local y=55 must cover at least 42 pixels.
- The curved trunk and forks are substantially thicker than the current version. The opaque trunk span at local y=70 must cover at least 15 pixels.

## Rendering architecture

`tools/generate_art.gd` remains the source of truth. A leaf-mass helper evaluates a union of a base ellipse and several smaller lobe ellipses. A pixel is outlined when any four-neighbor lies outside that union. Interior pixels are assigned to highlight, main, shadow, or deep-shadow planes by vertical position plus a deterministic coordinate hash. Hand-placed accent pixels reinforce leaf texture without adding colors.

Branches and trunk are rendered before foliage. The trunk uses multiple tapered thick lines, a dark central shadow, a narrow warm highlight, and wider asymmetric roots. Both trees keep the existing atlas origins, runtime regions, centered anchors, z-index, and 16-by-16 collision footprints.

## Hard constraints

- `props.png` remains 256 by 128 pixels.
- Tree regions remain `Rect2i(96, 0, 64, 96)` and `Rect2i(160, 0, 64, 96)`.
- The bench remains in `Rect2i(208, 96, 48, 32)`.
- Every opaque pixel uses the approved 17-color palette and alpha 255; every other pixel has alpha 0.
- Every tree keeps a fully transparent one-pixel region border.
- No gradients, antialiasing, blur, semitransparency, animation, or cast shadows.
- The reference image is the visual source of truth; numeric tests are regression guards, not substitutes for visual inspection.

## Verification

- A focused tree-art test must fail on the current thin trunk and narrow top canopies, then pass on the replacement.
- The art generator and validator must report zero failures.
- The full Godot test runner must report zero failures.
- A native 640-by-360 capture and an enlarged atlas review must be inspected against the supplied reference.
- Headless project boot and resource-pack export must exit successfully.

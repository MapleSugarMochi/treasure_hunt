# Hand-Drawn Heart Edge Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace both runtime heart PNGs with deterministic hand-drawn 16×16 pixel art that has a clean shared silhouette.

**Architecture:** The runtime continues loading the same two PNG paths. `tools/validate_art.gd` owns artifact-level topology and pairwise Alpha checks; no generator or gameplay code changes.

**Tech Stack:** Godot 4.6.3, GDScript `Image`, 16×16 RGBA PNG.

## Global Constraints

- Modify only the two heart PNGs, their artifact validator, their palette note, and these updated design/plan documents.
- Keep Alpha binary: 0 or 255.
- Keep full and empty Alpha masks identical.
- Do not change `tools/generate_art.gd`, UI layout, resource paths, life count, or gameplay logic.

---

### Task 1: Validate and replace the heart assets

**Files:**
- Modify: `tools/validate_art.gd`
- Modify: `assets/generated/heart-full.png`
- Modify: `assets/generated/heart-empty.png`
- Modify: `assets/source/palette.md`

**Interfaces:**
- Consumes: both heart PNGs as Godot `Image` values.
- Produces: topology-safe heart assets at the existing resource paths.

- [ ] Add validator checks for one connected opaque component, no internal transparent hole, matching Alpha masks, and at least one light highlight pixel in the full heart.
- [ ] Run the validator and confirm the existing PNGs fail because of internal transparent holes.
- [ ] Draw both 16×16 images from one explicit pixel matrix; use a dark outline, red fill, light highlight, and dark-red shadow for full, then map the same nontransparent cells to grayscale for empty.
- [ ] Run art validation and confirm `ART RESULT failures=0`.
- [ ] Inspect both files at native resolution and as enlarged nearest-neighbor previews.
- [ ] Reimport with Godot, run all project tests, run `git diff --check`, and verify unrelated files remain untouched.
- [ ] Commit with `fix: redraw heart icon edges`.

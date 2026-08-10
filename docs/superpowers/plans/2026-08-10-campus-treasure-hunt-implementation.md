# Campus Treasure Hunt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and export the approved Windows x64 Godot game 《校园寻宝》, including original warm-autumn pixel art, a continuous treasure loop, exact compass navigation, automated tests, and operator documentation.

**Architecture:** A single `Main` scene composes focused Godot nodes for game flow, player movement, world rendering, treasure spawning, camera, and UI. Pure rules such as direction math, spawn selection, state transitions, and world reachability remain in independently testable GDScript classes; scenes communicate through signals and public methods. Original PNG atlases are generated deterministically from a checked-in pixel-art source script, then consumed by the runtime scenes.

**Tech Stack:** Godot 4.6.3 stable (Compatibility renderer), GDScript, Godot `Image` API for original pixel assets, a lightweight headless GDScript test runner, Windows x64 export templates, Git.

---

## Scope and file map

The approved design is one cohesive deliverable and does not require separate sub-project plans. The implementation creates the following focused files:

```text
project.godot                              Project, input, display, renderer settings
export_presets.cfg                        Windows x64 single-file export settings
README.md                                 Operator startup, exit, restart, recovery

assets/fonts/NotoSansCJKsc-Regular.otf    Bundled Chinese UI font
assets/fonts/OFL.txt                      Font license
assets/generated/terrain.png              16 px terrain atlas
assets/generated/props.png                Buildings, trees, water-edge, benches
assets/generated/player.png               Four-direction 24×32 character sheet
assets/generated/treasure.png             Treasure animation sheet
assets/generated/ui.png                   Compass arrow and celebration particles
assets/source/palette.md                   Approved palette and asset dimensions

src/config/game_config.gd                 Shared gameplay/display constants
src/config/input_setup.gd                 Runtime WASD and arrow-key action setup
src/core/game_flow.gd                     WAITING/SEARCHING/CELEBRATING state machine
src/main/main.gd                          Runtime orchestration and signal wiring
src/main/main.tscn                        Root composition scene
src/player/player.gd                      Input, collision movement, animation state
src/player/player.tscn                    CharacterBody2D, sprite, collider, camera
src/treasure/treasure.gd                  Contact detection and found signal
src/treasure/treasure.tscn                Area2D, sprite, collider
src/treasure/treasure_spawner.gd          Candidate filtering, random choice, fallback
src/ui/navigation_math.gd                 Exact arrow angle and integer metre math
src/ui/navigation_hud.gd                  Runtime compass and distance display
src/ui/navigation_hud.tscn                HUD layout and arrow pivot
src/ui/game_ui.gd                         Start and 4.0-second celebration overlays
src/ui/game_ui.tscn                       Chinese labels, panels, particles, timer
src/world/world_layout.gd                 96×72 layout data and 40 spawn coordinates
src/world/world.gd                        Tile layers, props, collisions, spawn markers
src/world/world.tscn                      World node and TileMapLayer composition

tests/test_runner.gd                      Headless test discovery and assertions
tests/test_project_boot.gd                Project/settings/main-scene smoke test
tests/test_navigation_math.gd             Compass and metre tests
tests/test_treasure_spawner.gd            Random selection and fallback tests
tests/test_game_flow.gd                    State transition and movement-lock tests
tests/test_player.gd                       Normalized movement and lock tests
tests/test_world_layout.gd                 Count, bounds, clearance, reachability tests
tests/test_continuous_loop.gd              Scene-level 500-cycle integration test

tools/generate_art.gd                     Deterministic original PNG atlas generator
tools/validate_art.gd                     Atlas dimensions and palette validator
docs/qa/manual-test-checklist.md           Display, controls, endurance, timing checklist
```

All commands below run from `C:\Users\dongx\Desktop\平和展会游戏`. In PowerShell examples, `$godotExe` is a task-specific variable and must not be replaced with a broad system variable.

Implementation invariants carried directly from the approved specification: the minimum normal treasure spawn distance is 18 米; the player is never teleported between rounds; and the shipped runtime performs no 网络 access and loads no audio resources.

---

### Task 1: Pin the Godot toolchain and bootstrap a tested project

**Files:**
- Create: `project.godot`
- Create: `src/main/main.tscn`
- Create: `tests/test_runner.gd`
- Create: `tests/test_project_boot.gd`
- Modify: `.gitignore`

- [ ] **Step 1: Download and unpack the portable Godot editor into the ignored toolchain directory**

Run:

```powershell
New-Item -ItemType Directory -Force -Path '.superpowers\downloads','.superpowers\toolchains\godot-4.6.3' | Out-Null
$ProgressPreference='SilentlyContinue'
Invoke-WebRequest -Uri 'https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_win64.exe.zip' -OutFile '.superpowers\downloads\godot-4.6.3-win64.zip'
Expand-Archive -LiteralPath '.superpowers\downloads\godot-4.6.3-win64.zip' -DestinationPath '.superpowers\toolchains\godot-4.6.3' -Force
Get-Item '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
```

Expected: the console executable exists and reports a non-zero file size. Keep `.superpowers/` ignored because the portable editor is tooling, not product source.

- [ ] **Step 2: Add the headless test runner**

Create `tests/test_runner.gd`:

```gdscript
extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
    call_deferred("_run_all")

func _run_all() -> void:
    var dir := DirAccess.open("res://tests")
    if dir == null:
        push_error("Cannot open res://tests")
        quit(1)
        return
    var files := dir.get_files()
    files.sort()
    for file_name in files:
        if not file_name.begins_with("test_") or not file_name.ends_with(".gd"):
            continue
        if file_name == "test_runner.gd":
            continue
        var suite_script: Script = load("res://tests/%s" % file_name)
        var suite: RefCounted = suite_script.new()
        print("RUN %s" % file_name)
        suite.run(self)
    print("RESULT assertions=%d failures=%d" % [assertions, failures])
    quit(1 if failures > 0 else 0)

func assert_true(value: bool, message: String) -> void:
    assertions += 1
    if not value:
        failures += 1
        push_error("ASSERT TRUE FAILED: %s" % message)

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
    assertions += 1
    if actual != expected:
        failures += 1
        push_error("ASSERT EQ FAILED: %s; actual=%s expected=%s" % [message, actual, expected])

func assert_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
    assertions += 1
    if absf(actual - expected) > tolerance:
        failures += 1
        push_error("ASSERT APPROX FAILED: %s; actual=%f expected=%f" % [message, actual, expected])
```

- [ ] **Step 3: Write the failing boot test**

Create `tests/test_project_boot.gd`:

```gdscript
extends RefCounted

func run(t: SceneTree) -> void:
    t.assert_true(FileAccess.file_exists("res://project.godot"), "project.godot exists")
    t.assert_true(ResourceLoader.exists("res://src/main/main.tscn"), "main scene exists")
    var packed := load("res://src/main/main.tscn") as PackedScene
    t.assert_true(packed != null, "main scene loads")
    if packed != null:
        var instance := packed.instantiate()
        t.assert_eq(instance.name, "Main", "root node is Main")
        instance.free()
```

- [ ] **Step 4: Run the test and verify the missing project fails**

Run:

```powershell
$godotExe='.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godotExe --headless --path . -s tests/test_runner.gd
```

Expected: non-zero exit with missing `project.godot` or `src/main/main.tscn` assertions.

- [ ] **Step 5: Create the minimal project and root scene**

Create `project.godot`:

```ini
config_version=5

[application]
config/name="校园寻宝"
run/main_scene="res://src/main/main.tscn"

[display]
window/size/viewport_width=640
window/size/viewport_height=360
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/size/mode=3

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
textures/canvas_textures/default_texture_filter=0

```

Create `src/main/main.tscn`:

```ini
[gd_scene format=3]

[node name="Main" type="Node"]
```

Append to `.gitignore`:

```gitignore
*.tmp
*.log
```

- [ ] **Step 6: Run the boot test and import smoke test**

Run:

```powershell
$godotExe='.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godotExe --headless --path . -s tests/test_runner.gd
& $godotExe --headless --path . --quit-after 2
```

Expected: test output ends with `failures=0`; project import exits with code 0 and no script parse errors.

- [ ] **Step 7: Commit the bootstrap**

```powershell
git add .gitignore project.godot src/main/main.tscn tests/test_runner.gd tests/test_project_boot.gd
git commit -m "build: bootstrap Godot project and test runner"
```

---

### Task 2: Implement exact compass angle and metre calculations

**Files:**
- Create: `src/config/game_config.gd`
- Create: `src/ui/navigation_math.gd`
- Create: `tests/test_navigation_math.gd`

- [ ] **Step 1: Write failing navigation tests**

Create `tests/test_navigation_math.gd`:

```gdscript
extends RefCounted

const NavigationMath = preload("res://src/ui/navigation_math.gd")

func run(t: SceneTree) -> void:
    t.assert_approx(NavigationMath.direction_angle(Vector2.ZERO, Vector2.RIGHT), 0.0, 0.0001, "right is zero radians")
    t.assert_approx(NavigationMath.direction_angle(Vector2.ZERO, Vector2.DOWN), PI / 2.0, 0.0001, "down is pi over two")
    t.assert_approx(NavigationMath.direction_angle(Vector2.ZERO, Vector2.LEFT), PI, 0.0001, "left is pi radians")
    t.assert_approx(NavigationMath.direction_angle(Vector2.ZERO, Vector2.UP), -PI / 2.0, 0.0001, "up is negative pi over two")
    t.assert_eq(NavigationMath.distance_metres(Vector2.ZERO, Vector2(368.0, 0.0)), 23, "368 pixels is 23 metres")
    t.assert_eq(NavigationMath.distance_metres(Vector2.ZERO, Vector2(23.0, 0.0)), 1, "distance rounds to nearest integer")
```

- [ ] **Step 2: Run the test and verify the missing script fails**

Run the headless test command from Task 1. Expected: load failure for `navigation_math.gd`.

- [ ] **Step 3: Add shared constants and minimal navigation math**

Create `src/config/game_config.gd`:

```gdscript
class_name GameConfig
extends RefCounted

const TILE_SIZE := 16
const PIXELS_PER_METRE := 16.0
const MIN_TREASURE_DISTANCE_METRES := 18.0
const PLAYER_SPEED_PIXELS_PER_SECOND := 72.0
const CELEBRATION_SECONDS := 4.0
const MAP_WIDTH_TILES := 96
const MAP_HEIGHT_TILES := 72
const VIEWPORT_SIZE := Vector2i(640, 360)
```

Create `src/ui/navigation_math.gd`:

```gdscript
class_name NavigationMath
extends RefCounted

const GameConfig = preload("res://src/config/game_config.gd")

static func direction_angle(from_position: Vector2, to_position: Vector2) -> float:
    return (to_position - from_position).angle()

static func distance_metres(from_position: Vector2, to_position: Vector2) -> int:
    return roundi(from_position.distance_to(to_position) / GameConfig.PIXELS_PER_METRE)
```

- [ ] **Step 4: Run all tests**

Expected: `test_navigation_math.gd` covers right/down/left/up directions and metre rounding; output ends with `failures=0`.

- [ ] **Step 5: Commit navigation math**

```powershell
git add src/config/game_config.gd src/ui/navigation_math.gd tests/test_navigation_math.gd
git commit -m "feat: add exact treasure navigation math"
```

---

### Task 3: Implement deterministic treasure-point selection

**Files:**
- Create: `src/treasure/treasure_spawner.gd`
- Create: `tests/test_treasure_spawner.gd`

- [ ] **Step 1: Write failing selection tests**

Create `tests/test_treasure_spawner.gd`:

```gdscript
extends RefCounted

const TreasureSpawner = preload("res://src/treasure/treasure_spawner.gd")

func run(t: SceneTree) -> void:
    var points: Array[Vector2] = [Vector2.ZERO, Vector2(64, 0), Vector2(320, 0), Vector2(640, 0)]
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345
    for iteration in range(30):
        var index := TreasureSpawner.choose_spawn_index(points, Vector2.ZERO, 2, 288.0, rng)
        t.assert_true(index == 3, "selection excludes previous point and points closer than 18 metres")

    var fallback_points: Array[Vector2] = [Vector2.ZERO, Vector2(80, 0), Vector2(160, 0)]
    var fallback := TreasureSpawner.choose_spawn_index(fallback_points, Vector2.ZERO, 0, 9999.0, rng)
    t.assert_eq(fallback, 2, "fallback chooses farthest non-previous point")

    var impossible: Array[Vector2] = [Vector2.ZERO]
    t.assert_eq(TreasureSpawner.choose_spawn_index(impossible, Vector2.ZERO, 0, 10.0, rng), -1, "one repeated point is invalid")
```

- [ ] **Step 2: Run the test and verify it fails because the selector is missing**

Expected: load failure for `treasure_spawner.gd`.

- [ ] **Step 3: Implement the pure selection rule**

Create `src/treasure/treasure_spawner.gd`:

```gdscript
class_name TreasureSpawner
extends Node2D

signal treasure_spawned(treasure: Area2D)

@export var treasure_scene: PackedScene
var previous_index := -1
var current_treasure: Area2D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

static func choose_spawn_index(
    points: Array[Vector2],
    player_position: Vector2,
    previous: int,
    minimum_distance_pixels: float,
    random: RandomNumberGenerator
) -> int:
    var eligible: Array[int] = []
    for index in range(points.size()):
        if index == previous:
            continue
        if points[index].distance_to(player_position) >= minimum_distance_pixels:
            eligible.append(index)
    if not eligible.is_empty():
        return eligible[random.randi_range(0, eligible.size() - 1)]

    var farthest_index := -1
    var farthest_distance := -1.0
    for index in range(points.size()):
        if index == previous:
            continue
        var distance := points[index].distance_to(player_position)
        if distance > farthest_distance:
            farthest_distance = distance
            farthest_index = index
    return farthest_index

func spawn_next(points: Array[Vector2], player_position: Vector2, minimum_distance_pixels: float) -> Area2D:
    var index := choose_spawn_index(points, player_position, previous_index, minimum_distance_pixels, rng)
    if index < 0 or treasure_scene == null:
        return null
    if is_instance_valid(current_treasure):
        current_treasure.queue_free()
    current_treasure = treasure_scene.instantiate() as Area2D
    current_treasure.global_position = points[index]
    add_child(current_treasure)
    previous_index = index
    treasure_spawned.emit(current_treasure)
    return current_treasure
```

- [ ] **Step 4: Run all tests**

Expected: valid random choices always satisfy the minimum distance and previous-index exclusion; fallback and impossible cases pass.

- [ ] **Step 5: Commit treasure selection**

```powershell
git add src/treasure/treasure_spawner.gd tests/test_treasure_spawner.gd
git commit -m "feat: add validated treasure spawn selection"
```

---

### Task 4: Implement the three-state game flow

**Files:**
- Create: `src/core/game_flow.gd`
- Create: `tests/test_game_flow.gd`

- [ ] **Step 1: Write failing state-machine tests**

Create `tests/test_game_flow.gd`:

```gdscript
extends RefCounted

const GameFlow = preload("res://src/core/game_flow.gd")

func run(t: SceneTree) -> void:
    var flow := GameFlow.new()
    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "starts on title state")
    t.assert_true(not flow.can_player_move(), "movement is locked on title")
    flow.request_start()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "movement starts search")
    t.assert_true(flow.can_player_move(), "movement enabled while searching")
    flow.on_treasure_found()
    t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "found treasure starts celebration")
    t.assert_true(not flow.can_player_move(), "movement locked during celebration")
    flow.on_treasure_found()
    t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "duplicate found event is ignored")
    flow.on_celebration_finished()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "celebration returns directly to search")
    flow.free()
```

- [ ] **Step 2: Run the test and verify the missing state machine fails**

Expected: load failure for `game_flow.gd`.

- [ ] **Step 3: Implement only the approved transitions**

Create `src/core/game_flow.gd`:

```gdscript
class_name GameFlow
extends Node

signal state_changed(previous: int, current: int)
signal search_started
signal celebration_started

enum State { WAITING_START, SEARCHING, CELEBRATING }

var state := State.WAITING_START

func can_player_move() -> bool:
    return state == State.SEARCHING

func request_start() -> void:
    if state != State.WAITING_START:
        return
    _set_state(State.SEARCHING)
    search_started.emit()

func on_treasure_found() -> void:
    if state != State.SEARCHING:
        return
    _set_state(State.CELEBRATING)
    celebration_started.emit()

func on_celebration_finished() -> void:
    if state != State.CELEBRATING:
        return
    _set_state(State.SEARCHING)
    search_started.emit()

func _set_state(next: int) -> void:
    var previous := state
    state = next
    state_changed.emit(previous, state)
```

- [ ] **Step 4: Run all tests**

Expected: the only accepted sequence is `WAITING_START → SEARCHING → CELEBRATING → SEARCHING`; output ends with `failures=0`.

- [ ] **Step 5: Commit the game flow**

```powershell
git add src/core/game_flow.gd tests/test_game_flow.gd
git commit -m "feat: add continuous treasure game flow"
```

---

### Task 5: Generate and validate the original pixel-art atlases

**Files:**
- Create: `tools/generate_art.gd`
- Create: `tools/validate_art.gd`
- Create: `assets/source/palette.md`
- Generate: `assets/generated/terrain.png`
- Generate: `assets/generated/props.png`
- Generate: `assets/generated/player.png`
- Generate: `assets/generated/treasure.png`
- Generate: `assets/generated/ui.png`
- Create: `assets/fonts/NotoSansCJKsc-Regular.otf`
- Create: `assets/fonts/OFL.txt`

- [ ] **Step 1: Record the exact original palette and atlas contracts**

Create `assets/source/palette.md` with this table:

```markdown
# 暖秋校园色板

| 用途 | HEX |
|---|---|
| 深棕轮廓 | `#3B302B` |
| 暖灰阴影 | `#66574B` |
| 草地亮 | `#A8C878` |
| 草地主色 | `#8EB361` |
| 草地暗 | `#6F914D` |
| 道路亮 | `#E8CF91` |
| 道路主色 | `#D2AE6E` |
| 砖红 | `#A6533E` |
| 奶油墙面 | `#E9D3A5` |
| 秋叶橙 | `#D87943` |
| 秋叶金 | `#E2A244` |
| 深叶绿 | `#527D45` |
| 水面 | `#61A1A5` |
| 水面高光 | `#8BC7B6` |
| 导航金 | `#F0BD46` |
| 角色蓝 | `#315F82` |
| 皮肤 | `#E8B88E` |

Atlas contracts: `terrain.png` 128×32, `props.png` 256×128,
`player.png` 72×128, `treasure.png` 96×32, `ui.png` 64×32.
All hard edges align to integer pixels and use no antialiasing.
```

- [ ] **Step 2: Write the failing art validator**

Create `tools/validate_art.gd`:

```gdscript
extends SceneTree

const EXPECTED := {
    "terrain.png": Vector2i(128, 32),
    "props.png": Vector2i(256, 128),
    "player.png": Vector2i(72, 128),
    "treasure.png": Vector2i(96, 32),
    "ui.png": Vector2i(64, 32),
}

func _initialize() -> void:
    var failures := 0
    for file_name in EXPECTED:
        var path := "res://assets/generated/%s" % file_name
        var image := Image.load_from_file(path)
        if image == null or image.is_empty():
            push_error("Missing image: %s" % path)
            failures += 1
        elif image.get_size() != EXPECTED[file_name]:
            push_error("Wrong size for %s: %s" % [path, image.get_size()])
            failures += 1
    print("ART RESULT failures=%d" % failures)
    quit(1 if failures > 0 else 0)
```

Run `& $godotExe --headless --path . -s tools/validate_art.gd`. Expected: five missing-image failures.

- [ ] **Step 3: Implement the deterministic atlas generator**

Create `tools/generate_art.gd` as a `SceneTree` script. It must:

```gdscript
extends SceneTree

const OUT := "res://assets/generated"
const C := {
    "outline": Color("3b302b"), "grass": Color("8eb361"),
    "grass_light": Color("a8c878"), "grass_dark": Color("6f914d"),
    "path": Color("d2ae6e"), "path_light": Color("e8cf91"),
    "brick": Color("a6533e"), "wall": Color("e9d3a5"),
    "orange": Color("d87943"), "gold": Color("e2a244"),
    "leaf": Color("527d45"), "water": Color("61a1a5"),
    "water_light": Color("8bc7b6"), "nav": Color("f0bd46"),
    "blue": Color("315f82"), "skin": Color("e8b88e")
}

func _initialize() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    _terrain().save_png("%s/terrain.png" % OUT)
    _props().save_png("%s/props.png" % OUT)
    _player().save_png("%s/player.png" % OUT)
    _treasure().save_png("%s/treasure.png" % OUT)
    _ui().save_png("%s/ui.png" % OUT)
    quit(0)

func _new_image(size: Vector2i) -> Image:
    var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 0))
    return image

func _rect(image: Image, rect: Rect2i, color: Color) -> void:
    image.fill_rect(rect, color)

func _terrain() -> Image:
    var image := _new_image(Vector2i(128, 32))
    _rect(image, Rect2i(0, 0, 16, 16), C.grass)
    _rect(image, Rect2i(4, 5, 2, 2), C.grass_light)
    _rect(image, Rect2i(11, 12, 2, 2), C.grass_dark)
    _rect(image, Rect2i(16, 0, 16, 16), C.path)
    _rect(image, Rect2i(16, 0, 16, 2), C.path_light)
    _rect(image, Rect2i(32, 0, 16, 16), C.water)
    _rect(image, Rect2i(35, 5, 9, 1), C.water_light)
    _rect(image, Rect2i(37, 11, 8, 1), C.water_light)
    _rect(image, Rect2i(48, 0, 16, 16), C.wall)
    _rect(image, Rect2i(48, 0, 16, 4), C.brick)
    _rect(image, Rect2i(64, 0, 16, 16), C.grass_dark)
    _rect(image, Rect2i(67, 3, 2, 2), C.grass)
    _rect(image, Rect2i(80, 0, 16, 16), C.path_light)
    _rect(image, Rect2i(96, 0, 16, 16), C.leaf)
    _rect(image, Rect2i(112, 0, 16, 16), C.brick)
    return image

func _props() -> Image:
    var image := _new_image(Vector2i(256, 128))
    _rect(image, Rect2i(8, 32, 80, 56), C.wall)
    _rect(image, Rect2i(4, 20, 88, 18), C.brick)
    _rect(image, Rect2i(24, 53, 14, 18), C.water)
    _rect(image, Rect2i(58, 53, 14, 18), C.water)
    _rect(image, Rect2i(108, 44, 18, 44), C.outline)
    _rect(image, Rect2i(91, 14, 52, 48), C.orange)
    _rect(image, Rect2i(156, 46, 16, 42), C.outline)
    _rect(image, Rect2i(139, 19, 50, 45), C.gold)
    _rect(image, Rect2i(202, 63, 45, 10), C.outline)
    _rect(image, Rect2i(205, 57, 39, 8), C.path)
    return image

func _player() -> Image:
    var image := _new_image(Vector2i(72, 128))
    for direction in range(4):
        for frame in range(3):
            var origin := Vector2i(frame * 24, direction * 32)
            _rect(image, Rect2i(origin + Vector2i(7, 5), Vector2i(10, 9)), C.skin)
            _rect(image, Rect2i(origin + Vector2i(5, 3), Vector2i(14, 5)), C.outline)
            _rect(image, Rect2i(origin + Vector2i(6, 14), Vector2i(12, 11)), C.blue)
            var stride := 1 if frame == 1 else 0
            _rect(image, Rect2i(origin + Vector2i(7 - stride, 25), Vector2i(4, 6)), C.outline)
            _rect(image, Rect2i(origin + Vector2i(13 + stride, 25), Vector2i(4, 6)), C.outline)
            if direction == 0: # down
                _rect(image, Rect2i(origin + Vector2i(9, 9), Vector2i(2, 2)), C.outline)
                _rect(image, Rect2i(origin + Vector2i(14, 9), Vector2i(2, 2)), C.outline)
            elif direction == 1: # up
                _rect(image, Rect2i(origin + Vector2i(7, 7), Vector2i(10, 6)), C.outline)
            elif direction == 2: # left
                _rect(image, Rect2i(origin + Vector2i(8, 9), Vector2i(2, 2)), C.outline)
                _rect(image, Rect2i(origin + Vector2i(5, 15), Vector2i(3, 8)), C.skin)
            else: # right
                _rect(image, Rect2i(origin + Vector2i(15, 9), Vector2i(2, 2)), C.outline)
                _rect(image, Rect2i(origin + Vector2i(16, 15), Vector2i(3, 8)), C.skin)
    return image

func _treasure() -> Image:
    var image := _new_image(Vector2i(96, 32))
    for frame in range(3):
        var x := frame * 32
        _rect(image, Rect2i(x + 5, 12, 22, 15), C.outline)
        _rect(image, Rect2i(x + 8, 14, 16, 10), C.gold)
        _rect(image, Rect2i(x + 6, 8 - frame, 20, 7), C.brick)
        _rect(image, Rect2i(x + 15, 14, 3, 6), C.nav)
    return image

func _ui() -> Image:
    var image := _new_image(Vector2i(64, 32))
    _rect(image, Rect2i(4, 13, 20, 6), C.nav)
    _rect(image, Rect2i(20, 9, 5, 14), C.nav)
    _rect(image, Rect2i(25, 12, 3, 8), C.nav)
    _rect(image, Rect2i(28, 15, 3, 2), C.nav)
    _rect(image, Rect2i(45, 3, 4, 26), C.nav)
    _rect(image, Rect2i(34, 14, 26, 4), C.nav)
    _rect(image, Rect2i(39, 8, 16, 16), C.path_light)
    return image
```

Run:

```powershell
& $godotExe --headless --path . -s tools/generate_art.gd
& $godotExe --headless --path . -s tools/validate_art.gd
```

Expected: five PNGs are created; validator ends with `ART RESULT failures=0`.

- [ ] **Step 4: Bundle a redistributable Chinese font and license**

Run:

```powershell
New-Item -ItemType Directory -Force -Path 'assets\fonts' | Out-Null
$ProgressPreference='SilentlyContinue'
Invoke-WebRequest -Uri 'https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf' -OutFile 'assets\fonts\NotoSansCJKsc-Regular.otf'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/notofonts/noto-cjk/main/LICENSE' -OutFile 'assets\fonts\OFL.txt'
```

Expected: the OTF and license files are non-empty. Open the license and confirm redistribution is permitted before committing.

- [ ] **Step 5: Import and visually inspect each atlas at 800% zoom**

Open the PNGs in an image viewer. Expected: hard pixel edges, transparent unused regions, warm-autumn palette, blue student character, three readable chest frames, and a right-pointing gold arrow. If any silhouette is unclear, edit only `tools/generate_art.gd`, regenerate, and rerun validation so generated files stay reproducible.

- [ ] **Step 6: Commit art source, generated atlases, font, and license**

```powershell
git add tools/generate_art.gd tools/validate_art.gd assets/source/palette.md assets/generated assets/fonts
git commit -m "art: add original warm autumn pixel atlases"
```

---

### Task 6: Implement the player scene and camera

**Files:**
- Create: `src/config/input_setup.gd`
- Create: `src/player/player.gd`
- Create: `src/player/player.tscn`
- Create: `tests/test_player.gd`

- [ ] **Step 1: Write failing movement-rule tests**

Create `tests/test_player.gd`:

```gdscript
extends RefCounted

const Player = preload("res://src/player/player.gd")

func run(t: SceneTree) -> void:
    t.assert_eq(Player.normalized_input(Vector2(1, 0)), Vector2.RIGHT, "cardinal input unchanged")
    t.assert_approx(Player.normalized_input(Vector2(1, 1)).length(), 1.0, 0.0001, "diagonal input normalized")
    var player := Player.new()
    player.movement_enabled = false
    t.assert_eq(player.velocity_for_input(Vector2.RIGHT), Vector2.ZERO, "movement lock produces zero velocity")
    player.movement_enabled = true
    t.assert_eq(player.velocity_for_input(Vector2.RIGHT), Vector2(72, 0), "enabled movement uses configured speed")
    player.free()
```

- [ ] **Step 2: Run tests and verify `player.gd` is missing**

Expected: load failure for `src/player/player.gd`.

- [ ] **Step 3: Install keyboard actions without fragile hand-written resource serialization**

Create `src/config/input_setup.gd`:

```gdscript
class_name InputSetup
extends RefCounted

const ACTIONS := {
    "move_left": [KEY_A, KEY_LEFT],
    "move_right": [KEY_D, KEY_RIGHT],
    "move_up": [KEY_W, KEY_UP],
    "move_down": [KEY_S, KEY_DOWN],
}

static func ensure_actions() -> void:
    for action_name in ACTIONS:
        if not InputMap.has_action(action_name):
            InputMap.add_action(action_name, 0.2)
        for keycode: int in ACTIONS[action_name]:
            var event := InputEventKey.new()
            event.keycode = keycode
            if not InputMap.action_has_event(action_name, event):
                InputMap.action_add_event(action_name, event)
```

- [ ] **Step 4: Implement movement and animation selection**

Create `src/player/player.gd`:

```gdscript
class_name Player
extends CharacterBody2D

const GameConfig = preload("res://src/config/game_config.gd")
const InputSetup = preload("res://src/config/input_setup.gd")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var movement_enabled := false
var facing := "down"

func _ready() -> void:
    InputSetup.ensure_actions()

static func normalized_input(value: Vector2) -> Vector2:
    return value.normalized() if value.length_squared() > 1.0 else value

func velocity_for_input(value: Vector2) -> Vector2:
    if not movement_enabled:
        return Vector2.ZERO
    return normalized_input(value) * GameConfig.PLAYER_SPEED_PIXELS_PER_SECOND

func _physics_process(_delta: float) -> void:
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = velocity_for_input(input_vector)
    if velocity != Vector2.ZERO:
        if absf(velocity.x) > absf(velocity.y):
            facing = "right" if velocity.x > 0.0 else "left"
        else:
            facing = "down" if velocity.y > 0.0 else "up"
        sprite.play("walk_%s" % facing)
    else:
        sprite.play("idle_%s" % facing)
    move_and_slide()
```

- [ ] **Step 5: Create the Player scene**

Create `src/player/player.tscn` with:

- `CharacterBody2D` root using `player.gd`.
- `AnimatedSprite2D` with eight named animations: `idle_down`, `idle_up`, `idle_left`, `idle_right`, and matching `walk_*`; frames come from 24×32 regions in `player.png`.
- `CapsuleShape2D` collision sized to the lower 12×12 pixels so the head can visually overlap foliage.
- `Camera2D` child with `position_smoothing_enabled=true`, smoothing speed `8.0`, and integer camera positioning.

Use Godot’s scene resource syntax or create it in the editor; verify the final `.tscn` contains no external texture besides `res://assets/generated/player.png`.

- [ ] **Step 6: Run tests and a player-scene load check**

Extend `tests/test_player.gd` to load and instantiate `res://src/player/player.tscn`, add it to the tree, then assert the root is `CharacterBody2D`, the camera exists, all eight animation names exist, and all four `move_*` actions are registered. Run all tests; expected `failures=0`.

- [ ] **Step 7: Commit the player**

```powershell
git add src/config/input_setup.gd src/player/player.gd src/player/player.tscn tests/test_player.gd
git commit -m "feat: add keyboard player and follow camera"
```

---

### Task 7: Build the 96×72 campus world and validate all 40 spawn points

**Files:**
- Create: `src/world/world_layout.gd`
- Create: `src/world/world.gd`
- Create: `src/world/world.tscn`
- Create: `tests/test_world_layout.gd`

- [ ] **Step 1: Write failing layout contract and reachability tests**

Create `tests/test_world_layout.gd`. Its `run(t)` must:

```gdscript
extends RefCounted

const Layout = preload("res://src/world/world_layout.gd")

func run(t: SceneTree) -> void:
    t.assert_eq(Layout.WIDTH, 96, "map width is fixed")
    t.assert_eq(Layout.HEIGHT, 72, "map height is fixed")
    t.assert_eq(Layout.TREASURE_CELLS.size(), 40, "exactly 40 candidate points")
    t.assert_true(Layout.is_walkable(Layout.PLAYER_START_CELL), "player start is walkable")
    for cell in Layout.TREASURE_CELLS:
        t.assert_true(Layout.in_bounds(cell), "candidate is in bounds: %s" % cell)
        t.assert_true(Layout.is_walkable(cell), "candidate is walkable: %s" % cell)
        t.assert_true(Layout.has_clearance(cell, 1), "candidate has one-tile clearance: %s" % cell)
    var reachable := _flood_fill(Layout.PLAYER_START_CELL)
    for cell in Layout.TREASURE_CELLS:
        t.assert_true(reachable.has(cell), "candidate is reachable: %s" % cell)

func _flood_fill(start: Vector2i) -> Dictionary:
    var visited := {start: true}
    var queue: Array[Vector2i] = [start]
    while not queue.is_empty():
        var current := queue.pop_front()
        for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var next := current + direction
            if not visited.has(next) and Layout.is_walkable(next):
                visited[next] = true
                queue.append(next)
    return visited
```

- [ ] **Step 2: Run tests and verify the layout script is missing**

Expected: load failure for `world_layout.gd`.

- [ ] **Step 3: Define one authoritative layout data file**

Create `src/world/world_layout.gd` with:

```gdscript
class_name WorldLayout
extends RefCounted

const WIDTH := 96
const HEIGHT := 72
const PLAYER_START_CELL := Vector2i(48, 36)

const BLOCKED_RECTS: Array[Rect2i] = [
    Rect2i(5, 4, 25, 13),       # teaching building
    Rect2i(63, 6, 26, 12),      # second teaching building
    Rect2i(70, 49, 20, 15),     # garden pavilion
    Rect2i(6, 48, 22, 17),      # lake body
    Rect2i(35, 8, 6, 12),       # grove cluster
    Rect2i(52, 51, 5, 12),      # grove cluster
]

const TREASURE_CELLS: Array[Vector2i] = [
    Vector2i(3, 22), Vector2i(11, 21), Vector2i(21, 22), Vector2i(31, 20),
    Vector2i(45, 18), Vector2i(56, 20), Vector2i(68, 22), Vector2i(82, 21),
    Vector2i(92, 24), Vector2i(6, 31), Vector2i(18, 32), Vector2i(29, 30),
    Vector2i(39, 29), Vector2i(52, 28), Vector2i(64, 30), Vector2i(76, 31),
    Vector2i(89, 33), Vector2i(4, 40), Vector2i(15, 41), Vector2i(26, 39),
    Vector2i(37, 42), Vector2i(47, 44), Vector2i(59, 41), Vector2i(71, 40),
    Vector2i(84, 42), Vector2i(93, 39), Vector2i(3, 68), Vector2i(31, 53),
    Vector2i(40, 55), Vector2i(48, 66), Vector2i(61, 56), Vector2i(67, 66),
    Vector2i(93, 55), Vector2i(34, 3), Vector2i(48, 4), Vector2i(57, 4),
    Vector2i(3, 3), Vector2i(93, 3), Vector2i(34, 68), Vector2i(93, 68),
]

static func in_bounds(cell: Vector2i) -> bool:
    return cell.x >= 1 and cell.y >= 1 and cell.x < WIDTH - 1 and cell.y < HEIGHT - 1

static func is_walkable(cell: Vector2i) -> bool:
    if not in_bounds(cell):
        return false
    for blocked in BLOCKED_RECTS:
        if blocked.has_point(cell):
            return false
    return true

static func has_clearance(cell: Vector2i, radius: int) -> bool:
    for y in range(cell.y - radius, cell.y + radius + 1):
        for x in range(cell.x - radius, cell.x + radius + 1):
            if not is_walkable(Vector2i(x, y)):
                return false
    return true

static func to_world(cell: Vector2i) -> Vector2:
    return Vector2(cell.x * 16 + 8, cell.y * 16 + 8)

static func treasure_world_positions() -> Array[Vector2]:
    var result: Array[Vector2] = []
    for cell in TREASURE_CELLS:
        result.append(to_world(cell))
    return result
```

- [ ] **Step 4: Run reachability tests and adjust only invalid coordinates**

Expected: 40 candidates pass bounds, walkability, one-tile clearance, and flood-fill reachability. If a listed coordinate fails, move that coordinate to the nearest walkable cell while preserving the count of 40; do not weaken the assertions.

- [ ] **Step 5: Build the visual world from the same layout data**

Create `src/world/world.tscn` with a `Node2D` root, three `TileMapLayer` children named `Ground`, `Paths`, and `Details`, a `Node2D` named `Props`, and a `StaticBody2D` named `Obstacles`. Attach `src/world/world.gd` to the root.

Create `src/world/world.gd` with this complete data-driven implementation. The three building rectangles, lake, two groves, looping paths, benches, flowers, and side gate all derive from the same coordinate system used by the tests:

```gdscript
class_name CampusWorld
extends Node2D

const WorldLayout = preload("res://src/world/world_layout.gd")
const TILE_SIZE := 16
const PATH_SEGMENTS: Array[PackedVector2Array] = [
    PackedVector2Array([Vector2(2, 36), Vector2(94, 36)]),
    PackedVector2Array([Vector2(48, 2), Vector2(48, 70)]),
    PackedVector2Array([Vector2(4, 23), Vector2(31, 25), Vector2(48, 36)]),
    PackedVector2Array([Vector2(48, 36), Vector2(70, 28), Vector2(92, 24)]),
    PackedVector2Array([Vector2(48, 36), Vector2(65, 47), Vector2(93, 68)]),
    PackedVector2Array([Vector2(48, 36), Vector2(34, 52), Vector2(29, 68)]),
]
const TREE_CELLS: Array[Vector2i] = [
    Vector2i(36, 9), Vector2i(39, 12), Vector2i(37, 17),
    Vector2i(53, 52), Vector2i(55, 57), Vector2i(53, 61),
    Vector2i(31, 11), Vector2i(60, 17), Vector2i(64, 46),
]
const BENCH_CELLS: Array[Vector2i] = [Vector2i(31, 46), Vector2i(61, 35), Vector2i(30, 66)]

@onready var ground: TileMapLayer = $Ground
@onready var paths: TileMapLayer = $Paths
@onready var details: TileMapLayer = $Details
@onready var props: Node2D = $Props
@onready var obstacles: StaticBody2D = $Obstacles
var source_id := -1

func _ready() -> void:
    _configure_tiles()
    _paint_ground()
    _paint_paths()
    _paint_lake()
    _add_prop_sprites()
    _add_collisions()
    queue_redraw()

func _configure_tiles() -> void:
    var tile_set := TileSet.new()
    tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
    var atlas := TileSetAtlasSource.new()
    atlas.texture = load("res://assets/generated/terrain.png")
    atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
    for atlas_x in range(8):
        atlas.create_tile(Vector2i(atlas_x, 0))
    source_id = tile_set.add_source(atlas)
    ground.tile_set = tile_set
    paths.tile_set = tile_set
    details.tile_set = tile_set

func _paint_ground() -> void:
    for y in range(WorldLayout.HEIGHT):
        for x in range(WorldLayout.WIDTH):
            var variant := Vector2i(4, 0) if (x * 17 + y * 31) % 23 == 0 else Vector2i(0, 0)
            ground.set_cell(Vector2i(x, y), source_id, variant)

func _paint_paths() -> void:
    for polyline in PATH_SEGMENTS:
        for index in range(polyline.size() - 1):
            _paint_corridor(Vector2i(polyline[index]), Vector2i(polyline[index + 1]), 2)
    for y in range(31, 42):
        for x in range(42, 55):
            if WorldLayout.is_walkable(Vector2i(x, y)):
                paths.set_cell(Vector2i(x, y), source_id, Vector2i(1, 0))

func _paint_corridor(from_cell: Vector2i, to_cell: Vector2i, radius: int) -> void:
    var delta := to_cell - from_cell
    var steps := maxi(absi(delta.x), absi(delta.y))
    for step in range(steps + 1):
        var ratio := float(step) / float(maxi(steps, 1))
        var center := Vector2i(Vector2(from_cell).lerp(Vector2(to_cell), ratio).round())
        for offset_y in range(-radius, radius + 1):
            for offset_x in range(-radius, radius + 1):
                var cell := center + Vector2i(offset_x, offset_y)
                if WorldLayout.is_walkable(cell):
                    paths.set_cell(cell, source_id, Vector2i(1, 0))

func _paint_lake() -> void:
    var lake := WorldLayout.BLOCKED_RECTS[3]
    for y in range(lake.position.y, lake.end.y):
        for x in range(lake.position.x, lake.end.x):
            details.set_cell(Vector2i(x, y), source_id, Vector2i(2, 0))

func _add_prop_sprites() -> void:
    var texture: Texture2D = load("res://assets/generated/props.png")
    for index in range(TREE_CELLS.size()):
        var region := Rect2(88, 0, 64, 96) if index % 2 == 0 else Rect2(136, 0, 64, 96)
        _add_region_sprite(texture, region, WorldLayout.to_world(TREE_CELLS[index]), index)
    for index in range(BENCH_CELLS.size()):
        _add_region_sprite(texture, Rect2(200, 48, 48, 32), WorldLayout.to_world(BENCH_CELLS[index]), 100 + index)

func _add_region_sprite(texture: Texture2D, region: Rect2, world_position: Vector2, order: int) -> void:
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.region_enabled = true
    sprite.region_rect = region
    sprite.position = world_position
    sprite.z_index = 2
    sprite.name = "Prop%03d" % order
    props.add_child(sprite)

func _add_collisions() -> void:
    for blocked in WorldLayout.BLOCKED_RECTS:
        var shape := RectangleShape2D.new()
        shape.size = Vector2(blocked.size.x * TILE_SIZE, blocked.size.y * TILE_SIZE)
        var collision := CollisionShape2D.new()
        collision.shape = shape
        collision.position = Vector2(
            (blocked.position.x + blocked.size.x / 2.0) * TILE_SIZE,
            (blocked.position.y + blocked.size.y / 2.0) * TILE_SIZE
        )
        obstacles.add_child(collision)

func _draw() -> void:
    var wall := Color("e9d3a5")
    var roof := Color("a6533e")
    var outline := Color("3b302b")
    for index in [0, 1, 2]:
        var blocked := WorldLayout.BLOCKED_RECTS[index]
        var rect := Rect2(
            Vector2(blocked.position.x * TILE_SIZE, blocked.position.y * TILE_SIZE),
            Vector2(blocked.size.x * TILE_SIZE, blocked.size.y * TILE_SIZE)
        )
        draw_rect(rect, outline)
        draw_rect(rect.grow(-6.0), wall)
        draw_rect(Rect2(rect.position + Vector2(6, 6), Vector2(rect.size.x - 12, 20)), roof)
    draw_rect(Rect2(0, 34 * TILE_SIZE, 2 * TILE_SIZE, 6 * TILE_SIZE), outline)
    draw_rect(Rect2(94 * TILE_SIZE, 34 * TILE_SIZE, 2 * TILE_SIZE, 6 * TILE_SIZE), outline)

func get_player_start() -> Vector2:
    return WorldLayout.to_world(WorldLayout.PLAYER_START_CELL)

func get_treasure_positions() -> Array[Vector2]:
    return WorldLayout.treasure_world_positions()

func get_world_rect() -> Rect2:
    return Rect2(Vector2.ZERO, Vector2(WorldLayout.WIDTH * 16, WorldLayout.HEIGHT * 16))
```

- [ ] **Step 6: Add a scene-level world test**

Extend `tests/test_world_layout.gd` to load `world.tscn`, instantiate it, and add it to `t.root`. Godot calls `_ready()` synchronously during `add_child`, so the test can immediately assert:

- `get_treasure_positions().size() == 40`.
- `get_player_start() == WorldLayout.to_world(WorldLayout.PLAYER_START_CELL)`.
- `get_world_rect().size == Vector2(1536, 1152)`.
- `Ground`, `Paths`, `Details`, `Props`, and `Obstacles` all exist.

Run all tests. Expected: `failures=0` and no orphan-node warnings.

- [ ] **Step 7: Visually inspect the map in the editor**

Expected: all six landmarks are recognizable, the main path forms a readable loop, no corridor is narrower than two tiles, and every treasure candidate has visible standing space. Compare the result with the approved warm-autumn visual mockup in `.superpowers/brainstorm/`.

- [ ] **Step 8: Commit the world**

```powershell
git add src/world/world_layout.gd src/world/world.gd src/world/world.tscn tests/test_world_layout.gd
git commit -m "feat: build validated warm autumn campus map"
```

---

### Task 8: Implement the treasure scene, exact navigation HUD, and overlays

**Files:**
- Create: `src/treasure/treasure.gd`
- Create: `src/treasure/treasure.tscn`
- Create: `src/ui/navigation_hud.gd`
- Create: `src/ui/navigation_hud.tscn`
- Create: `src/ui/game_ui.gd`
- Create: `src/ui/game_ui.tscn`
- Create: `tests/test_ui_scenes.gd`

- [ ] **Step 1: Write failing UI and treasure scene tests**

Create `tests/test_ui_scenes.gd` that loads all three scenes and asserts:

```gdscript
extends RefCounted

func run(t: SceneTree) -> void:
    var treasure := _instance(t, "res://src/treasure/treasure.tscn")
    var hud := _instance(t, "res://src/ui/navigation_hud.tscn")
    var ui := _instance(t, "res://src/ui/game_ui.tscn")
    t.assert_true(treasure is Area2D, "treasure root is Area2D")
    t.assert_true(treasure.has_signal("found"), "treasure exposes found signal")
    t.assert_true(hud.has_method("set_target"), "HUD accepts player and treasure")
    t.assert_true(ui.has_method("show_start"), "UI exposes start state")
    t.assert_true(ui.has_method("play_celebration"), "UI exposes celebration")
    t.assert_approx(ui.get_node("CelebrationTimer").wait_time, 4.0, 0.0001, "celebration is exactly four seconds")
    treasure.queue_free()
    hud.queue_free()
    ui.queue_free()

func _instance(t: SceneTree, path: String) -> Node:
    var packed := load(path) as PackedScene
    t.assert_true(packed != null, "%s loads" % path)
    var node := packed.instantiate()
    t.root.add_child(node)
    return node
```

Run all tests. Expected: missing-scene failures.

- [ ] **Step 2: Implement the treasure contact signal**

Create `src/treasure/treasure.gd`:

```gdscript
class_name Treasure
extends Area2D

signal found
var consumed := false

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if consumed or not (body is Player):
        return
    consumed = true
    monitoring = false
    found.emit()
```

Create `treasure.tscn` with an `Area2D` root, `AnimatedSprite2D` using the three 32×32 frames from `treasure.png`, and a 22×16 `RectangleShape2D` collision.

- [ ] **Step 3: Implement the exact navigation HUD**

Create `src/ui/navigation_hud.gd`:

```gdscript
class_name NavigationHUD
extends Control

const NavigationMath = preload("res://src/ui/navigation_math.gd")

@onready var arrow: TextureRect = %Arrow
@onready var distance_label: Label = %DistanceLabel
var player: Node2D
var treasure: Node2D

func set_target(next_player: Node2D, next_treasure: Node2D) -> void:
    player = next_player
    treasure = next_treasure
    visible = is_instance_valid(player) and is_instance_valid(treasure)
    update_now()

func clear_target() -> void:
    treasure = null
    visible = false

func _process(_delta: float) -> void:
    update_now()

func update_now() -> void:
    if not is_instance_valid(player) or not is_instance_valid(treasure):
        visible = false
        return
    visible = true
    arrow.rotation = NavigationMath.direction_angle(player.global_position, treasure.global_position)
    distance_label.text = "距离宝藏 %d 米" % NavigationMath.distance_metres(player.global_position, treasure.global_position)
```

Create `navigation_hud.tscn` as a top-right `Control` with a dark translucent panel, circular compass frame, centered 32×32 arrow region from `ui.png`, and the bundled Chinese font. Set the arrow pivot to its center so `rotation` is exact.

- [ ] **Step 4: Implement start and celebration overlays**

Create `src/ui/game_ui.gd`:

```gdscript
class_name GameUI
extends Control

signal celebration_finished

@onready var start_overlay: Control = %StartOverlay
@onready var celebration_overlay: Control = %CelebrationOverlay
@onready var celebration_timer: Timer = $CelebrationTimer

func _ready() -> void:
    celebration_timer.timeout.connect(_on_celebration_timeout)

func show_start() -> void:
    start_overlay.visible = true
    celebration_overlay.visible = false

func hide_start() -> void:
    start_overlay.visible = false

func play_celebration() -> void:
    celebration_overlay.visible = true
    celebration_timer.start()

func _on_celebration_timeout() -> void:
    celebration_overlay.visible = false
    celebration_finished.emit()
```

Create `game_ui.tscn` with a fullscreen `Control` root and:

- Fullscreen start overlay containing `校园寻宝` and `按 WASD 或方向键开始`.
- Fullscreen celebration overlay containing `找到宝藏！` and `请领取奖品`.
- A gold pixel particle effect using `ui.png`.
- `CelebrationTimer` configured one-shot with `wait_time=4.0`.
- All Chinese labels using `NotoSansCJKsc-Regular.otf`.

- [ ] **Step 5: Make the UI tests pass and add a known-coordinate HUD assertion**

Extend `tests/test_ui_scenes.gd` with player at `(0, 0)` and treasure at `(368, 0)`. Call `hud.set_target`, then assert arrow rotation is `0.0` and the label is exactly `距离宝藏 23 米`.

Run all tests. Expected: scene contracts, four-second timer, and exact Chinese distance text all pass.

- [ ] **Step 6: Commit treasure and UI**

```powershell
git add src/treasure/treasure.gd src/treasure/treasure.tscn src/ui/navigation_hud.gd src/ui/navigation_hud.tscn src/ui/game_ui.gd src/ui/game_ui.tscn tests/test_ui_scenes.gd
git commit -m "feat: add treasure navigation and celebration UI"
```

---

### Task 9: Integrate the complete continuous game loop

**Files:**
- Create: `src/main/main.gd`
- Modify: `src/main/main.tscn`
- Modify: `src/treasure/treasure_spawner.gd`
- Create: `tests/test_continuous_loop.gd`

- [ ] **Step 1: Write a failing integration test for 500 continuous rounds**

Create `tests/test_continuous_loop.gd`:

```gdscript
extends RefCounted

func run(t: SceneTree) -> void:
    var packed := load("res://src/main/main.tscn") as PackedScene
    var main := packed.instantiate()
    t.root.add_child(main)
    var player: Node2D = main.get_node("Player")
    var start_position := player.global_position
    main.start_game_for_test()
    for round_index in range(500):
        var before := player.global_position
        var old_treasure: Area2D = main.current_treasure
        main.complete_treasure_for_test()
        main.finish_celebration_for_test()
        t.assert_eq(player.global_position, before, "round %d preserves player position" % round_index)
        t.assert_true(is_instance_valid(main.current_treasure), "round %d has a treasure" % round_index)
        t.assert_true(main.current_treasure != old_treasure, "round %d replaces treasure" % round_index)
        t.assert_eq(main.flow.state, GameFlow.State.SEARCHING, "round %d returns to searching" % round_index)
    t.assert_eq(start_position, player.global_position, "test does not teleport player")
    main.queue_free()
```

Run all tests. Expected: missing integration methods and node-composition failures.

- [ ] **Step 2: Compose the root scene**

Modify `src/main/main.tscn` so the `Main` node contains instances/nodes named exactly:

```text
Main
├── GameFlow
├── World
├── TreasureSpawner
├── Player
└── UI (CanvasLayer)
    ├── NavigationHUD
    └── GameUI
```

Attach `main.gd` to `Main`, assign `treasure.tscn` to `TreasureSpawner.treasure_scene`, and ensure the player renders above ground but below tree canopies.

- [ ] **Step 3: Implement orchestration without teleporting after the first start**

Create `src/main/main.gd`:

```gdscript
class_name Main
extends Node

const GameConfig = preload("res://src/config/game_config.gd")

@onready var flow: GameFlow = $GameFlow
@onready var world: Node2D = $World
@onready var spawner: TreasureSpawner = $TreasureSpawner
@onready var player: Player = $Player
@onready var navigation_hud: NavigationHUD = $UI/NavigationHUD
@onready var game_ui: GameUI = $UI/GameUI
var current_treasure: Area2D

func _ready() -> void:
    var points := world.get_treasure_positions()
    if points.size() < 2:
        _show_fatal_error("地图至少需要两个宝箱候选点")
        return
    player.global_position = world.get_player_start()
    _apply_camera_limits(world.get_world_rect())
    flow.state_changed.connect(_on_state_changed)
    game_ui.celebration_finished.connect(_on_celebration_finished)
    current_treasure = _spawn_next(points)
    player.movement_enabled = false
    game_ui.show_start()

func _unhandled_input(event: InputEvent) -> void:
    if flow.state == GameFlow.State.WAITING_START and event.is_pressed() and _is_move_event(event):
        flow.request_start()
        game_ui.hide_start()
        get_viewport().set_input_as_handled()

func _is_move_event(event: InputEvent) -> bool:
    return event.is_action("move_left") or event.is_action("move_right") or event.is_action("move_up") or event.is_action("move_down")

func _spawn_next(points: Array[Vector2]) -> Area2D:
    var minimum := GameConfig.MIN_TREASURE_DISTANCE_METRES * GameConfig.PIXELS_PER_METRE
    var treasure := spawner.spawn_next(points, player.global_position, minimum)
    if treasure == null:
        _show_fatal_error("无法生成新的宝箱")
        return null
    treasure.found.connect(_on_treasure_found, CONNECT_ONE_SHOT)
    current_treasure = treasure
    navigation_hud.set_target(player, treasure)
    return treasure

func _on_treasure_found() -> void:
    flow.on_treasure_found()
    game_ui.play_celebration()
    _spawn_next(world.get_treasure_positions())
    navigation_hud.visible = false

func _on_celebration_finished() -> void:
    navigation_hud.visible = true
    flow.on_celebration_finished()

func _on_state_changed(_previous: int, _current: int) -> void:
    player.movement_enabled = flow.can_player_move()

func _apply_camera_limits(rect: Rect2) -> void:
    var camera: Camera2D = player.get_node("Camera2D")
    camera.limit_left = roundi(rect.position.x)
    camera.limit_top = roundi(rect.position.y)
    camera.limit_right = roundi(rect.end.x)
    camera.limit_bottom = roundi(rect.end.y)

func _show_fatal_error(message: String) -> void:
    player.movement_enabled = false
    push_error(message)
    game_ui.show_fatal_error(message)

func start_game_for_test() -> void:
    flow.request_start()

func complete_treasure_for_test() -> void:
    _on_treasure_found()

func finish_celebration_for_test() -> void:
    _on_celebration_finished()
```

Add a hidden fullscreen `FatalErrorOverlay` and child `FatalErrorLabel` to `game_ui.tscn`, then add this exact method to `game_ui.gd`:

```gdscript
func show_fatal_error(message: String) -> void:
    celebration_timer.stop()
    start_overlay.visible = false
    celebration_overlay.visible = false
    %FatalErrorLabel.text = message
    %FatalErrorOverlay.visible = true
```

The error overlay remains visible until the process is restarted.

- [ ] **Step 4: Make spawn replacement safe during queued deletion**

Update `TreasureSpawner.spawn_next` so the previous treasure is detached before `queue_free`, preventing two active collision areas in one frame:

```gdscript
if is_instance_valid(current_treasure):
    current_treasure.set_deferred("monitoring", false)
    current_treasure.queue_free()
```

Do not move the player inside `_spawn_next`, `_on_treasure_found`, or `_on_celebration_finished`.

- [ ] **Step 5: Run the complete automated suite**

Run:

```powershell
& $godotExe --headless --path . -s tests/test_runner.gd
```

Expected: the 500-cycle test completes with zero failures, the player position is unchanged across every round, each treasure instance is replaced, and every round returns to `SEARCHING`.

- [ ] **Step 6: Run the game and manually verify the first two rounds**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64.exe' --path .
```

Expected: title appears; a movement key starts; arrow points exactly at the treasure; distance decreases while approaching; touching treasure shows the four-second overlay; the next target appears without moving the player.

- [ ] **Step 7: Commit the playable vertical slice**

```powershell
git add src/main/main.gd src/main/main.tscn src/treasure/treasure_spawner.gd src/ui/game_ui.gd src/ui/game_ui.tscn tests/test_continuous_loop.gd
git commit -m "feat: integrate continuous campus treasure loop"
```

---

### Task 10: Add focus pause, display behavior, and operator documentation

**Files:**
- Modify: `src/main/main.gd`
- Modify: `project.godot`
- Create: `README.md`
- Create: `docs/qa/manual-test-checklist.md`
- Create: `tests/test_focus_pause.gd`

- [ ] **Step 1: Write a failing focus-pause test**

Create `tests/test_focus_pause.gd`:

```gdscript
extends RefCounted

func run(t: SceneTree) -> void:
    var packed := load("res://src/main/main.tscn") as PackedScene
    var main := packed.instantiate()
    t.root.add_child(main)
    main.set_window_focused_for_test(false)
    t.assert_true(t.paused, "losing focus pauses the scene tree")
    main.set_window_focused_for_test(true)
    t.assert_true(not t.paused, "regaining focus resumes the scene tree")
    t.paused = false
    main.queue_free()
```

Run all tests. Expected: failure because `set_window_focused_for_test` does not exist.

- [ ] **Step 2: Implement focus handling**

Add to `main.gd`:

```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        get_tree().paused = true
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        get_tree().paused = false

func set_window_focused_for_test(focused: bool) -> void:
    get_tree().paused = not focused
```

Set `Main.process_mode = Node.PROCESS_MODE_ALWAYS` in `main.tscn` so focus-in can resume the paused tree.

- [ ] **Step 3: Lock approved presentation settings**

Confirm `project.godot` contains fullscreen mode, 640×360 logical size, `keep` aspect, nearest texture filtering, Compatibility renderer, and no audio bus resource. Add:

```ini
[application]
config/name="校园寻宝"
run/main_scene="res://src/main/main.tscn"

[display]
window/energy_saving/keep_screen_on=true
```

- [ ] **Step 4: Write operator documentation**

Create `README.md` with exact instructions:

```markdown
# 校园寻宝

## 现场启动
1. 双击 `CampusTreasureHunt.exe`。
2. 等待标题画面出现。
3. 玩家按 WASD 或方向键开始。

## 退出
按 `Alt+F4` 关闭游戏。

## 重启与恢复
如果画面或流程异常，按 `Alt+F4` 关闭，再次双击 EXE。游戏不保存玩家数据，重启后角色回到中央广场并生成首个宝箱。

## 正常表现
- 游戏全程静音。
- 右上角箭头精确指向宝箱。
- 距离显示为直线距离的整数米数。
- 找到宝箱后庆祝 4 秒，角色留在原地，下一轮自动开始。
```

- [ ] **Step 5: Add the manual QA checklist**

Create `docs/qa/manual-test-checklist.md` with unchecked rows for:

- 1280×720, 1366×768, and 1920×1080 fullscreen/black-bar behavior.
- WASD, arrows, key hold, opposite keys, diagonal keys, wall collision, and map edges.
- Exact arrow at four cardinal and four diagonal target positions.
- Distance display at 0 m, 1 m, 18 m, and 23 m.
- Twenty consecutive real treasure rounds with no teleport.
- Lost-focus pause and focus-return resume.
- No sound, network requests, brand content, codes, player names, counters, or leaderboard.
- Ten first-time players, their completion times, and a calculated percentage completing within 180 seconds.
- 60 FPS check at 1280×720 on the exhibition computer.

- [ ] **Step 6: Run tests and commit operations behavior**

Expected: all automated tests pass, including focus pause.

```powershell
git add project.godot src/main/main.gd src/main/main.tscn tests/test_focus_pause.gd README.md docs/qa/manual-test-checklist.md
git commit -m "docs: add exhibition operations and QA checklist"
```

---

### Task 11: Configure and verify the Windows x64 single-file export

**Files:**
- Create: `export_presets.cfg`
- Generate: `build/CampusTreasureHunt.exe`

- [ ] **Step 1: Download the matching export templates into an isolated Godot app-data directory**

Run:

```powershell
New-Item -ItemType Directory -Force -Path '.superpowers\downloads','.superpowers\godot_appdata\Godot\export_templates\4.6.3.stable' | Out-Null
$ProgressPreference='SilentlyContinue'
Invoke-WebRequest -Uri 'https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz' -OutFile '.superpowers\downloads\godot-4.6.3-export-templates.zip'
Expand-Archive -LiteralPath '.superpowers\downloads\godot-4.6.3-export-templates.zip' -DestinationPath '.superpowers\downloads\godot-templates-expanded' -Force
Copy-Item -Path '.superpowers\downloads\godot-templates-expanded\templates\*' -Destination '.superpowers\godot_appdata\Godot\export_templates\4.6.3.stable' -Recurse -Force
```

Expected: `windows_release_x86_64.exe` and `windows_debug_x86_64.exe` exist in the isolated template directory.

- [ ] **Step 2: Create a single-file Windows export preset**

Create `export_presets.cfg`:

```ini
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="docs/*,tests/*,tools/*,assets/source/*"
export_path="build/CampusTreasureHunt.exe"
script_export_mode=2

[preset.0.options]
custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=0
binary_format/embed_pck=true
binary_format/architecture="x86_64"
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
application/icon=""
application/console_wrapper_icon=""
application/modify_resources=true
application/product_name="校园寻宝"
application/file_description="高中科技节校园寻宝游戏"
application/copyright="Original assets for this project"
```

- [ ] **Step 3: Run all tests before exporting**

```powershell
$godotExe='.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godotExe --headless --path . -s tests/test_runner.gd
& $godotExe --headless --path . -s tools/validate_art.gd
```

Expected: both commands exit 0 with `failures=0`.

- [ ] **Step 4: Export using the isolated app-data directory**

```powershell
$env:APPDATA=(Resolve-Path '.superpowers\godot_appdata').Path
New-Item -ItemType Directory -Force -Path 'build' | Out-Null
& $godotExe --headless --path . --export-release 'Windows Desktop' 'build\CampusTreasureHunt.exe'
Get-ChildItem -LiteralPath 'build' | Select-Object Name,Length
```

Expected: export exits 0 and `build` contains exactly `CampusTreasureHunt.exe`; no separate `.pck` exists.

- [ ] **Step 5: Smoke-test the exported executable**

Run:

```powershell
& '.\build\CampusTreasureHunt.exe' --headless --quit-after 2
$LASTEXITCODE
```

Expected: exit code 0, no missing-resource or font errors.

- [ ] **Step 6: Commit the preset, not the binary**

```powershell
git add export_presets.cfg
git commit -m "build: configure Windows single-file export"
```

The executable stays under ignored `build/` and is delivered separately as the release artifact.

---

### Task 12: Perform final verification and exhibition acceptance

**Files:**
- Modify: `docs/qa/manual-test-checklist.md`
- Modify: `README.md` only if observed operator behavior differs

- [ ] **Step 1: Verify the clean source tree**

Run:

```powershell
git status --short
git diff --check
```

Expected: no unexpected source changes and no whitespace errors. `build/` and `.superpowers/` remain ignored.

- [ ] **Step 2: Run the complete automated verification sequence**

```powershell
$godotExe='.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godotExe --headless --path . --quit-after 2
& $godotExe --headless --path . -s tests/test_runner.gd
& $godotExe --headless --path . -s tools/validate_art.gd
& '.\build\CampusTreasureHunt.exe' --headless --quit-after 2
```

Expected: all four commands exit 0, test output reports zero failures, and no parser/import/resource errors appear.

- [ ] **Step 3: Complete display and control acceptance**

Run the exported EXE at 1280×720, 1366×768, and 1920×1080. Check the matching rows in `docs/qa/manual-test-checklist.md` only after observing correct integer scaling or black bars, readable Chinese text, exact arrow behavior, all keyboard combinations, collisions, map boundaries, silent audio, and focus pause/resume.

- [ ] **Step 4: Complete the 20-round endurance run**

Find 20 treasures without restarting. Record each treasure’s visible location and confirm after every celebration that the character remains on the same pixel, the old chest is gone, the new chest is not the previous point, and the HUD updates to the new target. Check the endurance row only if all 20 rounds pass.

- [ ] **Step 5: Complete first-time-player timing acceptance**

Have at least ten first-time players each begin a search without verbal route guidance. Record seconds-to-treasure in the checklist and compute `players_at_or_below_180_seconds / total_players`. Acceptance requires at least 90%. If it fails, change only path obstructions, treasure candidate distribution, player speed, or minimum spawn distance; rerun all automated tests and repeat timing acceptance.

- [ ] **Step 6: Verify the final artifact contents**

Deliver:

```text
CampusTreasureHunt.exe
README.md
source/  (clean Git working tree containing Godot project, tests, art source, PNGs, font license, specs, and plan)
```

Confirm the EXE starts by double-click, uses no network, produces no sound, includes no school branding or兑奖 verification, and returns to the central plaza only after a full process restart.

- [ ] **Step 7: Commit completed QA evidence**

```powershell
git add docs/qa/manual-test-checklist.md README.md
git commit -m "test: record exhibition acceptance results"
```

Expected final state: clean Git status, all automated checks passing, all required manual checklist rows checked with evidence, and one verified Windows x64 EXE ready for the exhibition computer.

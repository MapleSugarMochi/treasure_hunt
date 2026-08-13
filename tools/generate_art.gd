extends SceneTree

const OUT := "res://assets/generated"
const TREE_SOURCE_PATHS := [
    "res://assets/source/trees/orange-tree-reference.png",
    "res://assets/source/trees/gold-tree-reference.png",
]
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
    var output_path := ProjectSettings.globalize_path(OUT)
    var directory_error := DirAccess.make_dir_recursive_absolute(output_path)
    if directory_error != OK:
        push_error("Failed to create art output directory %s (error=%d)" % [output_path, directory_error])
        quit(1)
        return
    var tree_result := _load_tree_sources()
    if tree_result.failures > 0:
        print("ART GENERATION failures=%d" % tree_result.failures)
        quit(1)
        return
    var tree_sources: Array[Image] = tree_result.images
    var failures := 0
    failures += _save_png(_terrain(), "terrain.png")
    failures += _save_png(_props(tree_sources), "props.png")
    failures += _save_png(_player(), "player.png")
    failures += _save_png(_treasure(), "treasure.png")
    failures += _save_png(_ui(), "ui.png")
    print("ART GENERATION failures=%d" % failures)
    quit(1 if failures > 0 else 0)

func _save_png(image: Image, file_name: String) -> int:
    var path := "%s/%s" % [OUT, file_name]
    var absolute_path := ProjectSettings.globalize_path(path)
    if FileAccess.file_exists(path):
        var existing := Image.load_from_file(absolute_path)
        if (
            existing != null
            and not existing.is_empty()
            and existing.get_size() == image.get_size()
            and existing.get_format() == image.get_format()
            and existing.get_data() == image.get_data()
        ):
            return 0
    var save_error := image.save_png(path)
    if save_error != OK:
        push_error("Failed to save art PNG %s (error=%d)" % [absolute_path, save_error])
        return 1
    return 0

func _load_tree_sources() -> Dictionary:
    var failures := 0
    var images: Array[Image] = []
    for path in TREE_SOURCE_PATHS:
        if not FileAccess.file_exists(path):
            push_error("Missing tree source image: %s" % path)
            failures += 1
            continue
        var source := Image.load_from_file(ProjectSettings.globalize_path(path))
        if source == null or source.is_empty():
            push_error("Unreadable tree source image: %s" % path)
            failures += 1
        elif source.get_size() != Vector2i(64, 96):
            push_error("Wrong tree source size: %s size=%s" % [path, source.get_size()])
            failures += 1
        else:
            images.append(source)
    return {"failures": failures, "images": images}

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

func _props(tree_sources: Array[Image]) -> Image:
    var image := _new_image(Vector2i(256, 128))
    _rect(image, Rect2i(8, 32, 80, 56), C.wall)
    _rect(image, Rect2i(4, 20, 88, 18), C.brick)
    _rect(image, Rect2i(24, 53, 14, 18), C.water)
    _rect(image, Rect2i(58, 53, 14, 18), C.water)
    var tree_source_rect := Rect2i(0, 0, 64, 96)
    image.blit_rect(tree_sources[0], tree_source_rect, Vector2i(96, 0))
    image.blit_rect(tree_sources[1], tree_source_rect, Vector2i(160, 0))
    _rect(image, Rect2i(210, 102, 45, 10), C.outline)
    _rect(image, Rect2i(213, 96, 39, 8), C.path)
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
    var image := _new_image(Vector2i(96, 32))
    _rect(image, Rect2i(4, 13, 20, 6), C.nav)
    _rect(image, Rect2i(20, 9, 5, 14), C.nav)
    _rect(image, Rect2i(25, 12, 3, 8), C.nav)
    _rect(image, Rect2i(28, 15, 3, 2), C.nav)
    _rect(image, Rect2i(45, 3, 4, 26), C.nav)
    _rect(image, Rect2i(34, 14, 26, 4), C.nav)
    _rect(image, Rect2i(39, 8, 16, 16), C.path_light)
    _draw_heart(image, Vector2i(64, 0), C.orange, C.outline)
    _draw_heart(image, Vector2i(80, 0), C.outline, C.outline, false)
    return image

const HEART_MASK := [
    "................",
    "...XXX....XXX...",
    "..XXXXX..XXXXX..",
    ".XXXXXXXXXXXXXX.",
    ".XXXXXXXXXXXXXX.",
    ".XXXXXXXXXXXXXX.",
    ".XXXXXXXXXXXXXX.",
    "..XXXXXXXXXXXX..",
    "..XXXXXXXXXXXX..",
    "...XXXXXXXXXX...",
    "....XXXXXXXX....",
    ".....XXXXXX.....",
    "......XXXX......",
    ".......XX.......",
    "................",
    "................",
]

const HEART_NEIGHBORS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

func _draw_heart(image: Image, origin: Vector2i, fill: Color, outline: Color, use_fill: bool = true) -> void:
    var size := Vector2i(HEART_MASK[0].length(), HEART_MASK.size())
    for y in range(size.y):
        var row: String = HEART_MASK[y]
        for x in range(size.x):
            if row[x] != "X":
                continue
            var pixel := origin + Vector2i(x, y)
            var is_border := false
            for offset in HEART_NEIGHBORS:
                var neighbor: Vector2i = Vector2i(x, y) + offset
                if neighbor.x < 0 or neighbor.x >= size.x or neighbor.y < 0 or neighbor.y >= size.y:
                    is_border = true
                    break
                if HEART_MASK[neighbor.y][neighbor.x] != "X":
                    is_border = true
                    break
            if is_border:
                image.set_pixelv(pixel, outline)
            elif use_fill:
                image.set_pixelv(pixel, fill)

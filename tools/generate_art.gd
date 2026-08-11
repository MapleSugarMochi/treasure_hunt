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
    var output_path := ProjectSettings.globalize_path(OUT)
    var directory_error := DirAccess.make_dir_recursive_absolute(output_path)
    if directory_error != OK:
        push_error("Failed to create art output directory %s (error=%d)" % [output_path, directory_error])
        quit(1)
        return
    var failures := 0
    failures += _save_png(_terrain(), "terrain.png")
    failures += _save_png(_props(), "props.png")
    failures += _save_png(_player(), "player.png")
    failures += _save_png(_treasure(), "treasure.png")
    failures += _save_png(_ui(), "ui.png")
    print("ART GENERATION failures=%d" % failures)
    quit(1 if failures > 0 else 0)

func _save_png(image: Image, file_name: String) -> int:
    var path := "%s/%s" % [OUT, file_name]
    var save_error := image.save_png(path)
    if save_error != OK:
        push_error("Failed to save art PNG %s (error=%d)" % [ProjectSettings.globalize_path(path), save_error])
        return 1
    return 0

func _new_image(size: Vector2i) -> Image:
    var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 0))
    return image

func _rect(image: Image, rect: Rect2i, color: Color) -> void:
    image.fill_rect(rect, color)

func _ellipse_contains(point: Vector2i, center: Vector2i, radius: Vector2i) -> bool:
    if radius.x <= 0 or radius.y <= 0:
        return false
    var normalized_x := float(point.x - center.x) / float(radius.x)
    var normalized_y := float(point.y - center.y) / float(radius.y)
    return normalized_x * normalized_x + normalized_y * normalized_y <= 1.0

func _thick_line(image: Image, from: Vector2i, to: Vector2i, width: int, color: Color) -> void:
    var delta := to - from
    var steps := maxi(absi(delta.x), absi(delta.y))
    var half_width := width / 2
    for step in range(steps + 1):
        var ratio := float(step) / float(maxi(steps, 1))
        var point := Vector2i(Vector2(from).lerp(Vector2(to), ratio).round())
        _rect(
            image,
            Rect2i(point - Vector2i(half_width, half_width), Vector2i(width, width)),
            color
        )

func _branch(image: Image, origin: Vector2i, from: Vector2i, to: Vector2i, width: int) -> void:
    _thick_line(image, origin + from, origin + to, width + 2, C.outline)
    _thick_line(image, origin + from, origin + to, width, C.brick)

func _leaf_cluster(
    image: Image,
    origin: Vector2i,
    center: Vector2i,
    radius: Vector2i,
    main: Color,
    shadow: Color,
    highlight: Color,
    seed: int
) -> void:
    var inner_radius := radius - Vector2i.ONE
    var highlight_center := center + Vector2i(-maxi(2, radius.x / 3), -maxi(2, radius.y / 3))
    var highlight_radius := Vector2i(maxi(2, radius.x / 3), maxi(2, radius.y / 3))
    for local_y in range(center.y - radius.y, center.y + radius.y + 1):
        for local_x in range(center.x - radius.x, center.x + radius.x + 1):
            var local_point := Vector2i(local_x, local_y)
            if not _ellipse_contains(local_point, center, radius):
                continue
            var color := main
            if not _ellipse_contains(local_point, center, inner_radius):
                color = C.outline
            elif local_y - center.y >= maxi(2, radius.y / 4):
                var shadow_hash := posmod(local_x * 17 + local_y * 31 + seed * 13, 11)
                color = main if shadow_hash == 0 or shadow_hash == 1 else shadow
            elif _ellipse_contains(local_point, highlight_center, highlight_radius):
                color = highlight
            else:
                var texture_hash := posmod(local_x * 17 + local_y * 31 + seed * 13, 23)
                if texture_hash <= 2:
                    color = highlight if local_y <= center.y else shadow
                elif texture_hash == 3 and local_y > center.y - radius.y / 3:
                    color = shadow
            image.set_pixelv(origin + local_point, color)

func _draw_trunk(
    image: Image,
    origin: Vector2i,
    base: Vector2i,
    crown_base: Vector2i,
    width: int
) -> void:
    var bend := Vector2i(Vector2(base).lerp(Vector2(crown_base), 0.45).round())
    _thick_line(image, origin + base, origin + bend, width + 4, C.outline)
    _thick_line(image, origin + base - Vector2i(0, 1), origin + bend, width, C.brick)
    _thick_line(image, origin + bend, origin + crown_base, width + 2, C.outline)
    _thick_line(image, origin + bend, origin + crown_base, maxi(3, width - 2), C.brick)
    _thick_line(
        image,
        origin + base + Vector2i(-2, -4),
        origin + crown_base + Vector2i(-2, 4),
        2,
        C.path
    )
    _rect(image, Rect2i(origin + Vector2i(22, 84), Vector2i(11, 5)), C.outline)
    _rect(image, Rect2i(origin + Vector2i(33, 84), Vector2i(10, 5)), C.outline)
    _rect(image, Rect2i(origin + Vector2i(25, 84), Vector2i(7, 3)), C.brick)
    _rect(image, Rect2i(origin + Vector2i(34, 84), Vector2i(6, 3)), C.brick)

func _draw_root_grass(image: Image, origin: Vector2i) -> void:
    _rect(image, Rect2i(origin + Vector2i(18, 86), Vector2i(4, 2)), C.leaf)
    _rect(image, Rect2i(origin + Vector2i(20, 84), Vector2i(2, 2)), C.grass_dark)
    _rect(image, Rect2i(origin + Vector2i(43, 86), Vector2i(4, 2)), C.leaf)
    _rect(image, Rect2i(origin + Vector2i(43, 83), Vector2i(2, 3)), C.grass_dark)

func _orange_tree(image: Image, origin: Vector2i) -> void:
    _branch(image, origin, Vector2i(31, 60), Vector2i(17, 34), 3)
    _branch(image, origin, Vector2i(33, 59), Vector2i(47, 35), 3)
    _branch(image, origin, Vector2i(31, 54), Vector2i(32, 27), 3)
    _draw_trunk(image, origin, Vector2i(32, 83), Vector2i(32, 51), 7)
    var clusters := [
        [Vector2i(32, 15), Vector2i(13, 10)],
        [Vector2i(16, 32), Vector2i(14, 11)],
        [Vector2i(48, 32), Vector2i(13, 11)],
        [Vector2i(31, 43), Vector2i(14, 11)],
        [Vector2i(13, 53), Vector2i(12, 10)],
        [Vector2i(49, 53), Vector2i(12, 10)],
    ]
    for index in range(clusters.size()):
        _leaf_cluster(image, origin, clusters[index][0], clusters[index][1], C.orange, C.brick, C.gold, index)
    _rect(image, Rect2i(origin + Vector2i(27, 25), Vector2i(4, 3)), C.leaf)
    _rect(image, Rect2i(origin + Vector2i(37, 35), Vector2i(3, 4)), C.leaf)
    _rect(image, Rect2i(origin + Vector2i(23, 44), Vector2i(4, 3)), C.leaf)
    _rect(image, Rect2i(origin + Vector2i(38, 51), Vector2i(3, 3)), C.leaf)
    _draw_root_grass(image, origin)

func _gold_tree(image: Image, origin: Vector2i) -> void:
    _branch(image, origin, Vector2i(33, 61), Vector2i(18, 39), 3)
    _branch(image, origin, Vector2i(34, 55), Vector2i(38, 27), 3)
    _branch(image, origin, Vector2i(35, 58), Vector2i(49, 42), 3)
    _branch(image, origin, Vector2i(33, 65), Vector2i(20, 54), 3)
    _draw_trunk(image, origin, Vector2i(32, 83), Vector2i(35, 50), 7)
    var clusters := [
        [Vector2i(37, 16), Vector2i(13, 10)],
        [Vector2i(17, 34), Vector2i(13, 10)],
        [Vector2i(49, 35), Vector2i(12, 10)],
        [Vector2i(17, 54), Vector2i(13, 10)],
    ]
    for index in range(clusters.size()):
        _leaf_cluster(image, origin, clusters[index][0], clusters[index][1], C.gold, C.orange, C.nav, 10 + index)
    _rect(image, Rect2i(origin + Vector2i(31, 27), Vector2i(3, 3)), C.leaf)
    _rect(image, Rect2i(origin + Vector2i(37, 38), Vector2i(3, 3)), C.leaf)
    _rect(image, Rect2i(origin + Vector2i(24, 42), Vector2i(3, 2)), C.leaf)
    _draw_root_grass(image, origin)

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
    _orange_tree(image, Vector2i(96, 0))
    _gold_tree(image, Vector2i(160, 0))
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
    var image := _new_image(Vector2i(64, 32))
    _rect(image, Rect2i(4, 13, 20, 6), C.nav)
    _rect(image, Rect2i(20, 9, 5, 14), C.nav)
    _rect(image, Rect2i(25, 12, 3, 8), C.nav)
    _rect(image, Rect2i(28, 15, 3, 2), C.nav)
    _rect(image, Rect2i(45, 3, 4, 26), C.nav)
    _rect(image, Rect2i(34, 14, 26, 4), C.nav)
    _rect(image, Rect2i(39, 8, 16, 16), C.path_light)
    return image

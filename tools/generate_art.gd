extends SceneTree

const OUT := "res://assets/generated"
const HEART_SOURCE_PATH := "res://assets/generated/heart.jpg"
const HEART_TEXTURE_SIZE := Vector2i(16, 16)
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
    var heart_textures := _heart_textures()
    if heart_textures.is_empty():
        failures += 1
    else:
        var full_heart: Image = heart_textures["full"]
        var empty_heart: Image = heart_textures["empty"]
        failures += _save_png(full_heart, "heart-full.png")
        failures += _save_png(empty_heart, "heart-empty.png")
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

func _heart_textures() -> Dictionary:
    if not FileAccess.file_exists(HEART_SOURCE_PATH):
        push_error("Missing heart source image: %s" % HEART_SOURCE_PATH)
        return {}
    var source := Image.load_from_file(ProjectSettings.globalize_path(HEART_SOURCE_PATH))
    if source == null or source.is_empty():
        push_error("Unreadable heart source image: %s" % HEART_SOURCE_PATH)
        return {}
    var bounds := _heart_bounds(source)
    if bounds.size.x <= 0 or bounds.size.y <= 0:
        push_error("No red heart foreground found in: %s" % HEART_SOURCE_PATH)
        return {}
    var crop_rect := _square_crop(bounds, source.get_size())
    var isolated := _new_image(crop_rect.size)
    for y in range(crop_rect.size.y):
        for x in range(crop_rect.size.x):
            var source_pixel := source.get_pixel(crop_rect.position.x + x, crop_rect.position.y + y)
            if _is_heart_foreground(source_pixel):
                isolated.set_pixel(x, y, Color(source_pixel.r, source_pixel.g, source_pixel.b, 1.0))
    isolated.resize(HEART_TEXTURE_SIZE.x, HEART_TEXTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
    return {"full": isolated, "empty": _dimmed_heart(isolated)}

func _heart_bounds(image: Image) -> Rect2i:
    var min_x := image.get_width()
    var min_y := image.get_height()
    var max_x := -1
    var max_y := -1
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            if not _is_heart_foreground(image.get_pixel(x, y)):
                continue
            min_x = mini(min_x, x)
            min_y = mini(min_y, y)
            max_x = maxi(max_x, x)
            max_y = maxi(max_y, y)
    if max_x < min_x or max_y < min_y:
        return Rect2i()
    return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _square_crop(bounds: Rect2i, image_size: Vector2i) -> Rect2i:
    var side := maxi(bounds.size.x, bounds.size.y)
    var center := bounds.position + Vector2i(bounds.size.x / 2, bounds.size.y / 2)
    var x := clampi(center.x - side / 2, 0, image_size.x - side)
    var y := clampi(center.y - side / 2, 0, image_size.y - side)
    return Rect2i(x, y, side, side)

func _is_heart_foreground(pixel: Color) -> bool:
    var red := int(round(pixel.r * 255.0))
    var green := int(round(pixel.g * 255.0))
    var blue := int(round(pixel.b * 255.0))
    var red_fill := red >= 80 and red > green * 1.30 and red > blue * 1.30
    var dark_outline := red <= 60 and green <= 60 and blue <= 60
    return red_fill or dark_outline

func _dimmed_heart(full: Image) -> Image:
    var dimmed := _new_image(full.get_size())
    for y in range(full.get_height()):
        for x in range(full.get_width()):
            var pixel := full.get_pixel(x, y)
            if pixel.a <= 0.0:
                continue
            var luminance := int(round((pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722) * 255.0 * 0.42))
            var shade := clampi(maxi(luminance, 28), 0, 255)
            dimmed.set_pixel(x, y, Color8(shade, shade, shade, 255))
    return dimmed

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
    return image

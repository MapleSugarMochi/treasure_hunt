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

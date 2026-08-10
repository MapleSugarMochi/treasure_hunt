extends SceneTree

const EXPECTED := {
    "terrain.png": Vector2i(128, 32),
    "props.png": Vector2i(256, 128),
    "player.png": Vector2i(72, 128),
    "treasure.png": Vector2i(96, 32),
    "ui.png": Vector2i(64, 32),
}

const FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Regular.otf"

# Every opaque pixel in a generated atlas must be one of these source colors.
# Transparent pixels are intentionally exempt because their RGB bytes are not
# rendered and may vary between image encoders.
const APPROVED_RGB := {
    0x3b302b: true, 0x66574b: true, 0xa8c878: true,
    0x8eb361: true, 0x6f914d: true, 0xe8cf91: true,
    0xd2ae6e: true, 0xa6533e: true, 0xe9d3a5: true,
    0xd87943: true, 0xe2a244: true, 0x527d45: true,
    0x61a1a5: true, 0x8bc7b6: true, 0xf0bd46: true,
    0x315f82: true, 0xe8b88e: true,
}

# These regions correspond to the cells/silhouettes consumed by the game.
# Checking each one catches an accidentally blank frame while still allowing
# transparent padding around the art.
const KEY_REGIONS := {
    "terrain.png": [
        {"label": "terrain_grass", "rect": Rect2i(0, 0, 16, 16)},
        {"label": "terrain_path", "rect": Rect2i(16, 0, 16, 16)},
        {"label": "terrain_water", "rect": Rect2i(32, 0, 16, 16)},
        {"label": "terrain_wall", "rect": Rect2i(48, 0, 16, 16)},
        {"label": "terrain_dark_grass", "rect": Rect2i(64, 0, 16, 16)},
        {"label": "terrain_light_path", "rect": Rect2i(80, 0, 16, 16)},
        {"label": "terrain_leaf", "rect": Rect2i(96, 0, 16, 16)},
        {"label": "terrain_brick", "rect": Rect2i(112, 0, 16, 16)},
    ],
    "props.png": [
        {"label": "building", "rect": Rect2i(0, 20, 92, 68)},
        {"label": "orange_prop", "rect": Rect2i(91, 14, 52, 48)},
        {"label": "gold_prop", "rect": Rect2i(139, 19, 50, 45)},
        {"label": "bench", "rect": Rect2i(202, 57, 45, 16)},
    ],
    "player.png": [
        {"label": "down_idle", "rect": Rect2i(0, 0, 24, 32)},
        {"label": "down_walk", "rect": Rect2i(24, 0, 24, 32)},
        {"label": "down_alt", "rect": Rect2i(48, 0, 24, 32)},
        {"label": "up_idle", "rect": Rect2i(0, 32, 24, 32)},
        {"label": "up_walk", "rect": Rect2i(24, 32, 24, 32)},
        {"label": "up_alt", "rect": Rect2i(48, 32, 24, 32)},
        {"label": "left_idle", "rect": Rect2i(0, 64, 24, 32)},
        {"label": "left_walk", "rect": Rect2i(24, 64, 24, 32)},
        {"label": "left_alt", "rect": Rect2i(48, 64, 24, 32)},
        {"label": "right_idle", "rect": Rect2i(0, 96, 24, 32)},
        {"label": "right_walk", "rect": Rect2i(24, 96, 24, 32)},
        {"label": "right_alt", "rect": Rect2i(48, 96, 24, 32)},
    ],
    "treasure.png": [
        {"label": "treasure_closed", "rect": Rect2i(0, 0, 32, 32)},
        {"label": "treasure_opening", "rect": Rect2i(32, 0, 32, 32)},
        {"label": "treasure_open", "rect": Rect2i(64, 0, 32, 32)},
    ],
    "ui.png": [
        {"label": "compass_arrow", "rect": Rect2i(0, 0, 32, 32)},
        {"label": "celebration_sparkle", "rect": Rect2i(32, 0, 32, 32)},
    ],
}

func _initialize() -> void:
    var failures := 0
    for file_name in EXPECTED:
        var path := "res://assets/generated/%s" % file_name
        # Resolve to the filesystem so this validator exercises Image directly,
        # without asking the resource loader to import the PNG a second time.
        var image := Image.load_from_file(ProjectSettings.globalize_path(path))
        if image == null or image.is_empty():
            push_error("Missing image: %s" % path)
            failures += 1
            continue
        if image.get_size() != EXPECTED[file_name]:
            push_error("Wrong size for %s: %s" % [path, image.get_size()])
            failures += 1
            continue
        var pixel_result := _validate_pixels(file_name, image)
        failures += pixel_result.failures
        failures += _validate_regions(file_name, image)
        print("ART ATLAS %s size=%dx%d opaque=%d colors=%d" % [
            file_name,
            image.get_width(),
            image.get_height(),
            pixel_result.opaque,
            pixel_result.colors,
        ])
    failures += _validate_font()
    print("ART HUMAN REVIEW required: inspect every atlas at 800% with a controller or human; this validator does not claim visual approval.")
    print("ART RESULT failures=%d" % failures)
    quit(1 if failures > 0 else 0)

func _validate_pixels(file_name: String, image: Image) -> Dictionary:
    var failures := 0
    var opaque := 0
    var colors := {}
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var pixel := image.get_pixel(x, y)
            var alpha_byte := int(round(clamp(pixel.a, 0.0, 1.0) * 255.0))
            if alpha_byte != 0 and alpha_byte != 255:
                push_error("Semi-transparent pixel in %s at (%d,%d): alpha=%d" % [file_name, x, y, alpha_byte])
                failures += 1
                continue
            if alpha_byte == 0:
                continue
            opaque += 1
            var red := int(round(clamp(pixel.r, 0.0, 1.0) * 255.0))
            var green := int(round(clamp(pixel.g, 0.0, 1.0) * 255.0))
            var blue := int(round(clamp(pixel.b, 0.0, 1.0) * 255.0))
            var rgb := (red << 16) | (green << 8) | blue
            colors[rgb] = true
            if not APPROVED_RGB.has(rgb):
                push_error("Unapproved color in %s at (%d,%d): #%06x" % [file_name, x, y, rgb])
                failures += 1
    return {"failures": failures, "opaque": opaque, "colors": colors.size()}

func _validate_regions(file_name: String, image: Image) -> int:
    var failures := 0
    for region in KEY_REGIONS[file_name]:
        var rect: Rect2i = region.rect
        var non_empty := false
        var x_end := mini(rect.position.x + rect.size.x, image.get_width())
        var y_end := mini(rect.position.y + rect.size.y, image.get_height())
        for y in range(maxi(rect.position.y, 0), y_end):
            for x in range(maxi(rect.position.x, 0), x_end):
                if image.get_pixel(x, y).a > 0.0:
                    non_empty = true
                    break
            if non_empty:
                break
        if not non_empty:
            push_error("Blank key region in %s: %s" % [file_name, region.label])
            failures += 1
    return failures

func _validate_font() -> int:
    if not FileAccess.file_exists(FONT_PATH):
        push_error("Missing font: %s" % FONT_PATH)
        return 1
    var font_file := FontFile.new()
    var load_error := font_file.load_dynamic_font(ProjectSettings.globalize_path(FONT_PATH))
    if load_error != OK:
        push_error("Godot could not read font as FontFile: %s (error=%d)" % [FONT_PATH, load_error])
        return 1
    var bytes := FileAccess.get_file_as_bytes(FONT_PATH).size()
    print("ART FONT loaded type=%s bytes=%d" % [font_file.get_class(), bytes])
    return 0

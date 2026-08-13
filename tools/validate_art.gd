extends SceneTree

const EXPECTED := {
    "terrain.png": Vector2i(128, 32),
    "props.png": Vector2i(256, 128),
    "player.png": Vector2i(72, 128),
    "treasure.png": Vector2i(96, 32),
    "ui.png": Vector2i(96, 32),
}
const HEART_TEXTURES := {
    "heart-full.png": true,
    "heart-empty.png": false,
}

const FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
const PALETTE_PATH := "res://assets/source/palette.md"
const EXPECTED_PALETTE_COLORS := 17
const PROP_RUNTIME_REGIONS := [
    {"label": "orange_tree", "rect": Rect2i(96, 0, 64, 96), "transparent_border": true},
    {"label": "gold_tree", "rect": Rect2i(160, 0, 64, 96), "transparent_border": true},
]
const REMOVED_PROP_REGIONS := [
    {"label": "removed_bench", "rect": Rect2i(208, 96, 48, 32)},
]

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
        {"label": "orange_tree", "rect": Rect2i(96, 0, 64, 96)},
        {"label": "gold_tree", "rect": Rect2i(160, 0, 64, 96)},
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
    var palette_result := _load_palette()
    failures += palette_result.failures
    var approved_rgb: Dictionary = palette_result.colors
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
        var pixel_result := _validate_pixels(file_name, image, approved_rgb)
        failures += pixel_result.failures
        failures += _validate_regions(file_name, image)
        if file_name == "props.png":
            failures += _validate_prop_layout(image)
        print("ART ATLAS %s size=%dx%d opaque=%d colors=%d" % [
            file_name,
            image.get_width(),
            image.get_height(),
            pixel_result.opaque,
            pixel_result.colors,
        ])
    for file_name in HEART_TEXTURES:
        failures += _validate_heart_texture(file_name, HEART_TEXTURES[file_name])
    failures += _validate_font()
    print("ART HUMAN REVIEW required: inspect every atlas at 800% with a controller or human; this validator does not claim visual approval.")
    print("ART RESULT failures=%d" % failures)
    quit(1 if failures > 0 else 0)

func _validate_pixels(file_name: String, image: Image, approved_rgb: Dictionary) -> Dictionary:
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
            if not approved_rgb.has(rgb):
                push_error("Disallowed color in %s at (%d,%d): #%06x" % [file_name, x, y, rgb])
                failures += 1
    return {"failures": failures, "opaque": opaque, "colors": colors.size()}

func _validate_heart_texture(file_name: String, should_be_red: bool) -> int:
    var failures := 0
    var path := "res://assets/generated/%s" % file_name
    var image := Image.load_from_file(ProjectSettings.globalize_path(path))
    if image == null or image.is_empty():
        push_error("Missing heart texture: %s" % path)
        return 1
    if image.get_size() != Vector2i(16, 16):
        push_error("Wrong heart texture size for %s: %s" % [path, image.get_size()])
        return 1
    var opaque := 0
    var transparent := 0
    var red_pixels := 0
    var grey_pixels := 0
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var pixel := image.get_pixel(x, y)
            var alpha := int(round(pixel.a * 255.0))
            if alpha == 0:
                transparent += 1
                continue
            if alpha != 255:
                push_error("Semi-transparent heart pixel in %s at (%d,%d)" % [file_name, x, y])
                failures += 1
                continue
            opaque += 1
            var red := int(round(pixel.r * 255.0))
            var green := int(round(pixel.g * 255.0))
            var blue := int(round(pixel.b * 255.0))
            if red > green * 1.30 and red > blue * 1.30:
                red_pixels += 1
            if red == green and green == blue:
                grey_pixels += 1
    if opaque == 0:
        push_error("Blank heart texture: %s" % path)
        failures += 1
    if transparent == 0:
        push_error("Heart texture lacks transparent padding: %s" % path)
        failures += 1
    if should_be_red and red_pixels == 0:
        push_error("Full heart lacks red source pixels: %s" % path)
        failures += 1
    if not should_be_red and grey_pixels != opaque:
        push_error("Dimmed heart is not entirely grayscale: %s" % path)
        failures += 1
    print("ART HEART %s opaque=%d transparent=%d red=%d grey=%d" % [file_name, opaque, transparent, red_pixels, grey_pixels])
    return failures

func _load_palette() -> Dictionary:
    var failures := 0
    var approved := {}
    if not FileAccess.file_exists(PALETTE_PATH):
        push_error("Missing palette source: %s" % PALETTE_PATH)
        return {"failures": 1, "colors": approved}
    var palette_text := FileAccess.get_file_as_string(PALETTE_PATH)
    if palette_text.is_empty():
        push_error("Empty palette source: %s" % PALETTE_PATH)
        return {"failures": 1, "colors": approved}
    var entry_count := 0
    var lines := palette_text.split("\n")
    for line_index in range(lines.size()):
        var line := lines[line_index].strip_edges()
        if not line.begins_with("|") or not line.ends_with("|"):
            continue
        var cells := line.trim_prefix("|").trim_suffix("|").split("|")
        if cells.size() != 2:
            push_error("Malformed palette table row at %s:%d" % [PALETTE_PATH, line_index + 1])
            failures += 1
            continue
        var label := cells[0].strip_edges()
        var color_text := cells[1].strip_edges()
        if color_text.to_lower() == "hex":
            continue
        var separator := true
        for cell in cells:
            if not cell.strip_edges().replace("-", "").is_empty():
                separator = false
                break
        if separator:
            continue
        if label.is_empty():
            push_error("Missing palette label at %s:%d" % [PALETTE_PATH, line_index + 1])
            failures += 1
        var rgb := _parse_palette_rgb(color_text)
        if rgb < 0:
            push_error("Malformed palette color at %s:%d: %s" % [PALETTE_PATH, line_index + 1, color_text])
            failures += 1
            continue
        entry_count += 1
        if approved.has(rgb):
            push_error("Duplicate palette color at %s:%d: %s" % [PALETTE_PATH, line_index + 1, color_text])
            failures += 1
        approved[rgb] = true
    if entry_count != EXPECTED_PALETTE_COLORS:
        push_error("Palette entry count mismatch in %s: expected %d, got %d" % [PALETTE_PATH, EXPECTED_PALETTE_COLORS, entry_count])
        failures += 1
    if approved.size() != EXPECTED_PALETTE_COLORS:
        push_error("Palette unique color count mismatch in %s: expected %d, got %d" % [PALETTE_PATH, EXPECTED_PALETTE_COLORS, approved.size()])
        failures += 1
    return {"failures": failures, "colors": approved}

func _parse_palette_rgb(color_text: String) -> int:
    if not color_text.begins_with("`#") or not color_text.ends_with("`") or color_text.length() != 9:
        return -1
    var hex_digits := color_text.substr(2, 6).to_lower()
    var rgb := 0
    const HEX_DIGITS := "0123456789abcdef"
    for index in range(hex_digits.length()):
        var digit := HEX_DIGITS.find(hex_digits.substr(index, 1))
        if digit < 0:
            return -1
        rgb = rgb * 16 + digit
    return rgb

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

func _validate_prop_layout(image: Image) -> int:
    var failures := 0
    for index in range(PROP_RUNTIME_REGIONS.size()):
        var region: Dictionary = PROP_RUNTIME_REGIONS[index]
        var rect: Rect2i = region.rect
        if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > image.get_width() or rect.end.y > image.get_height():
            push_error("Prop region out of bounds: %s %s" % [region.label, rect])
            failures += 1
            continue
        for other_index in range(index + 1, PROP_RUNTIME_REGIONS.size()):
            var other: Rect2i = PROP_RUNTIME_REGIONS[other_index].rect
            if rect.intersects(other):
                push_error("Overlapping prop regions: %s and %s" % [region.label, PROP_RUNTIME_REGIONS[other_index].label])
                failures += 1
        if region.transparent_border and not _has_transparent_border(image, rect):
            push_error("Tree art touches runtime region border: %s" % region.label)
            failures += 1
        var colors := {}
        for y in range(rect.position.y, rect.end.y):
            for x in range(rect.position.x, rect.end.x):
                var pixel := image.get_pixel(x, y)
                if pixel.a > 0.0:
                    colors[pixel.to_rgba32()] = true
        if region.label.ends_with("tree") and colors.size() < 5:
            push_error("Tree region lacks color detail: %s colors=%d" % [region.label, colors.size()])
            failures += 1
    for removed_region in REMOVED_PROP_REGIONS:
        var removed_rect: Rect2i = removed_region.rect
        for y in range(removed_rect.position.y, removed_rect.end.y):
            for x in range(removed_rect.position.x, removed_rect.end.x):
                if image.get_pixel(x, y).a > 0.0:
                    push_error("Removed prop region is not empty: %s" % removed_region.label)
                    failures += 1
                    break
            if failures > 0:
                break
    return failures

func _has_transparent_border(image: Image, rect: Rect2i) -> bool:
    for x in range(rect.position.x, rect.end.x):
        if image.get_pixel(x, rect.position.y).a > 0.0 or image.get_pixel(x, rect.end.y - 1).a > 0.0:
            return false
    for y in range(rect.position.y, rect.end.y):
        if image.get_pixel(rect.position.x, y).a > 0.0 or image.get_pixel(rect.end.x - 1, y).a > 0.0:
            return false
    return true

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

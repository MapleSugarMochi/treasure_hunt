extends RefCounted

const PROPS_PATH := "res://assets/generated/props.png"
const TREE_REGIONS := [Rect2i(96, 0, 64, 96), Rect2i(160, 0, 64, 96)]
const MAX_ART_BOUNDS := [Vector2i(61, 84), Vector2i(58, 83)]
const MIN_LOWER_CANOPY_WIDTH := [30, 24]
const REQUIRED_COLORS := [
    [Color("3b302b"), Color("a6533e"), Color("d87943"), Color("e2a244"), Color("527d45")],
    [Color("3b302b"), Color("a6533e"), Color("e2a244"), Color("d87943"), Color("527d45")],
]

func run(t: SceneTree) -> void:
    var image := Image.load_from_file(ProjectSettings.globalize_path(PROPS_PATH))
    t.assert_true(image != null and not image.is_empty(), "props atlas loads")
    if image == null or image.is_empty():
        return
    t.assert_eq(image.get_size(), Vector2i(256, 128), "props atlas keeps its contract")
    for index in range(TREE_REGIONS.size()):
        var rect: Rect2i = TREE_REGIONS[index]
        t.assert_true(_has_transparent_border(image, rect), "tree region has transparent padding: %d" % index)
        var bounds := _opaque_bounds(image, rect)
        t.assert_true(not bounds.has_area() or bounds.size.x <= MAX_ART_BOUNDS[index].x, "tree width stays inside region: %d" % index)
        t.assert_true(not bounds.has_area() or bounds.size.y <= MAX_ART_BOUNDS[index].y, "tree height stays inside region: %d" % index)
        t.assert_true(_opaque_count(image, rect) >= 900, "tree has a substantial detailed silhouette: %d" % index)
        t.assert_true(
            _opaque_row_count(image, rect, 58) >= MIN_LOWER_CANOPY_WIDTH[index],
            "tree canopy stays full above the trunk: %d" % index
        )
        for color in REQUIRED_COLORS[index]:
            t.assert_true(
                _color_count(image, rect, color) >= 8,
                "tree uses required palette color: %d #%08x" % [index, color.to_rgba32()]
            )
    t.assert_true(
        _alpha_mask_difference(image, TREE_REGIONS[0], TREE_REGIONS[1]) >= 400,
        "tree silhouettes differ independently of color"
    )

func _has_transparent_border(image: Image, rect: Rect2i) -> bool:
    for x in range(rect.position.x, rect.end.x):
        if image.get_pixel(x, rect.position.y).a > 0.0 or image.get_pixel(x, rect.end.y - 1).a > 0.0:
            return false
    for y in range(rect.position.y, rect.end.y):
        if image.get_pixel(rect.position.x, y).a > 0.0 or image.get_pixel(rect.end.x - 1, y).a > 0.0:
            return false
    return true

func _opaque_bounds(image: Image, rect: Rect2i) -> Rect2i:
    var minimum := rect.end
    var maximum := rect.position - Vector2i.ONE
    for y in range(rect.position.y, rect.end.y):
        for x in range(rect.position.x, rect.end.x):
            if image.get_pixel(x, y).a <= 0.0:
                continue
            minimum.x = mini(minimum.x, x)
            minimum.y = mini(minimum.y, y)
            maximum.x = maxi(maximum.x, x)
            maximum.y = maxi(maximum.y, y)
    if maximum.x < minimum.x or maximum.y < minimum.y:
        return Rect2i()
    return Rect2i(minimum - rect.position, maximum - minimum + Vector2i.ONE)

func _opaque_count(image: Image, rect: Rect2i) -> int:
    var count := 0
    for y in range(rect.position.y, rect.end.y):
        for x in range(rect.position.x, rect.end.x):
            if image.get_pixel(x, y).a > 0.0:
                count += 1
    return count

func _opaque_row_count(image: Image, rect: Rect2i, local_y: int) -> int:
    var count := 0
    for local_x in range(rect.size.x):
        if image.get_pixelv(rect.position + Vector2i(local_x, local_y)).a > 0.0:
            count += 1
    return count

func _color_count(image: Image, rect: Rect2i, color: Color) -> int:
    var count := 0
    var target := color.to_rgba32()
    for y in range(rect.position.y, rect.end.y):
        for x in range(rect.position.x, rect.end.x):
            var pixel := image.get_pixel(x, y)
            if pixel.a > 0.0 and pixel.to_rgba32() == target:
                count += 1
    return count

func _alpha_mask_difference(image: Image, first: Rect2i, second: Rect2i) -> int:
    var difference := 0
    for local_y in range(first.size.y):
        for local_x in range(first.size.x):
            var offset := Vector2i(local_x, local_y)
            var first_opaque := image.get_pixelv(first.position + offset).a > 0.0
            var second_opaque := image.get_pixelv(second.position + offset).a > 0.0
            if first_opaque != second_opaque:
                difference += 1
    return difference

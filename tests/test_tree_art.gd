extends RefCounted

const PROPS_PATH := "res://assets/generated/props.png"
const TREE_REGIONS := [Rect2i(96, 0, 64, 96), Rect2i(160, 0, 64, 96)]
const TREE_SOURCE_PATHS := [
    "res://assets/source/trees/orange-tree-reference.png",
    "res://assets/source/trees/gold-tree-reference.png",
]
const EXPECTED_SOURCE_SHA256 := [
    "21e9562b4648fd292fcdde9d4841b806eba2807c08d362167a642259e4529637",
    "f94bfc707a47f41352da8c64469153162b6f4379806e42f4faefe8132f20270d",
]
const MAX_ART_BOUNDS := [Vector2i(62, 87), Vector2i(62, 87)]
const MIN_LOWER_CANOPY_WIDTH := [30, 24]
const MIN_DISTINCT_COLORS := [10, 10]
const MIN_OPAQUE_COLOR_EDGES := [2200, 2000]
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
        t.assert_true(
            _distinct_opaque_colors(image, rect) >= MIN_DISTINCT_COLORS[index],
            "tree preserves the reference shading range: %d" % index
        )
        t.assert_true(
            _opaque_color_edges(image, rect) >= MIN_OPAQUE_COLOR_EDGES[index],
            "tree preserves dense reference pixel texture: %d" % index
        )
        var source_path: String = TREE_SOURCE_PATHS[index]
        var source_exists := FileAccess.file_exists(source_path)
        t.assert_true(source_exists, "tree source sprite exists: %d" % index)
        if source_exists:
            t.assert_eq(
                FileAccess.get_sha256(source_path),
                EXPECTED_SOURCE_SHA256[index].to_lower(),
                "tree source sprite remains the approved reference extraction: %d" % index
            )
            var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
            t.assert_true(source != null and not source.is_empty(), "tree source sprite loads: %d" % index)
            if source != null and not source.is_empty():
                t.assert_eq(source.get_size(), rect.size, "tree source sprite keeps the runtime size: %d" % index)
                t.assert_true(_region_matches_source(image, rect, source), "tree atlas preserves the approved source pixels: %d" % index)
                t.assert_eq(_enclosed_pinhole_count(source), 0, "tree edge has no enclosed transparent pinholes: %d" % index)
                t.assert_eq(_weak_accent_edge_count(source), 0, "tree edge has no one-pixel accent spikes: %d" % index)
        var upper_highlights := _color_count_in_local_rect(
            image,
            rect,
            Rect2i(0, 0, 64, 48),
            [Color("f0bd46"), Color("e2a244")]
        )
        var lower_highlights := _color_count_in_local_rect(
            image,
            rect,
            Rect2i(0, 48, 64, 48),
            [Color("f0bd46"), Color("e2a244")]
        )
        t.assert_true(upper_highlights > lower_highlights * 2, "tree highlights stay concentrated above: %d" % index)
        var upper_shadows := _color_count_in_local_rect(
            image,
            rect,
            Rect2i(0, 0, 64, 48),
            [Color("3b302b"), Color("66574b"), Color("a6533e")]
        )
        var lower_shadows := _color_count_in_local_rect(
            image,
            rect,
            Rect2i(0, 48, 64, 48),
            [Color("3b302b"), Color("66574b"), Color("a6533e")]
        )
        t.assert_true(lower_shadows > upper_shadows, "tree shadows and trunk weight stay concentrated below: %d" % index)
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

func _distinct_opaque_colors(image: Image, rect: Rect2i) -> int:
    var colors := {}
    for y in range(rect.position.y, rect.end.y):
        for x in range(rect.position.x, rect.end.x):
            var pixel := image.get_pixel(x, y)
            if pixel.a > 0.0:
                colors[pixel.to_rgba32()] = true
    return colors.size()

func _opaque_color_edges(image: Image, rect: Rect2i) -> int:
    var edges := 0
    for local_y in range(rect.size.y):
        for local_x in range(rect.size.x):
            var point := rect.position + Vector2i(local_x, local_y)
            var pixel := image.get_pixelv(point)
            if pixel.a <= 0.0:
                continue
            if local_x > 0:
                var left := image.get_pixelv(point + Vector2i.LEFT)
                if left.a > 0.0 and left.to_rgba32() != pixel.to_rgba32():
                    edges += 1
            if local_y > 0:
                var above := image.get_pixelv(point + Vector2i.UP)
                if above.a > 0.0 and above.to_rgba32() != pixel.to_rgba32():
                    edges += 1
    return edges

func _region_matches_source(atlas: Image, rect: Rect2i, source: Image) -> bool:
    for local_y in range(rect.size.y):
        for local_x in range(rect.size.x):
            var offset := Vector2i(local_x, local_y)
            if atlas.get_pixelv(rect.position + offset).to_rgba32() != source.get_pixelv(offset).to_rgba32():
                return false
    return true

func _color_count_in_local_rect(
    image: Image,
    region: Rect2i,
    local_rect: Rect2i,
    colors: Array[Color]
) -> int:
    var targets := {}
    for color in colors:
        targets[color.to_rgba32()] = true
    var count := 0
    for local_y in range(local_rect.position.y, local_rect.end.y):
        for local_x in range(local_rect.position.x, local_rect.end.x):
            var pixel := image.get_pixelv(region.position + Vector2i(local_x, local_y))
            if pixel.a > 0.0 and targets.has(pixel.to_rgba32()):
                count += 1
    return count

func _enclosed_pinhole_count(image: Image) -> int:
    var count := 0
    for y in range(1, image.get_height() - 1):
        for x in range(1, image.get_width() - 1):
            var point := Vector2i(x, y)
            if image.get_pixelv(point).a > 0.0:
                continue
            if (
                image.get_pixelv(point + Vector2i.LEFT).a > 0.0
                and image.get_pixelv(point + Vector2i.RIGHT).a > 0.0
                and image.get_pixelv(point + Vector2i.UP).a > 0.0
                and image.get_pixelv(point + Vector2i.DOWN).a > 0.0
            ):
                count += 1
    return count

func _weak_accent_edge_count(image: Image) -> int:
    var count := 0
    var outline := Color("3b302b").to_rgba32()
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var point := Vector2i(x, y)
            var pixel := image.get_pixelv(point)
            if pixel.a <= 0.0 or pixel.to_rgba32() == outline:
                continue
            var neighbors := 0
            for offset_y in range(-1, 2):
                for offset_x in range(-1, 2):
                    if offset_x == 0 and offset_y == 0:
                        continue
                    var neighbor := point + Vector2i(offset_x, offset_y)
                    if (
                        neighbor.x >= 0
                        and neighbor.y >= 0
                        and neighbor.x < image.get_width()
                        and neighbor.y < image.get_height()
                        and image.get_pixelv(neighbor).a > 0.0
                    ):
                        neighbors += 1
            if neighbors <= 2:
                count += 1
    return count

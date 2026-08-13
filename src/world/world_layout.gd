class_name WorldLayout
extends RefCounted

const WIDTH := 96
const HEIGHT := 72
const TILE_SIZE := 16
const PLAYER_START_CELL := Vector2i(48, 36)

# A3 layout: a compact square teaching building faces the wider north-east
# building across the garden ring. The south-east building was removed.
const BUILDING_RECTS: Array[Rect2i] = [
    Rect2i(7, 3, 15, 15),
    Rect2i(66, 4, 26, 11),
]

const PLAZA_RECT := Rect2i(38, 28, 20, 16)
const GARDEN_RECT := Rect2i(70, 57, 22, 13)
const GARDEN_BED_RECTS: Array[Rect2i] = [
    Rect2i(72, 58, 7, 3),
    Rect2i(83, 58, 7, 3),
    Rect2i(72, 65, 7, 3),
    Rect2i(83, 65, 7, 3),
]

# Tile-space shoreline vertices. Cell centres inside the polygon are water.
const LAKE_POLYGON: Array[Vector2] = [
    Vector2(6, 51), Vector2(9, 48), Vector2(15, 47), Vector2(22, 49),
    Vector2(27, 53), Vector2(28, 58), Vector2(25, 64), Vector2(19, 66),
    Vector2(11, 65), Vector2(6, 62), Vector2(4, 57),
]

const TREE_CELLS: Array[Vector2i] = [
    Vector2i(34, 8), Vector2i(61, 10), Vector2i(8, 22),
    Vector2i(29, 20), Vector2i(64, 22), Vector2i(89, 21),
    Vector2i(33, 49), Vector2i(61, 50), Vector2i(93, 47),
    Vector2i(39, 62), Vector2i(52, 63), Vector2i(66, 60),
    Vector2i(31, 58),
]

# Flowers are decorative and walkable. The final twelve cells form four
# planted beds in the south-east garden; the bed rectangles provide collision.
const FLOWER_CELLS: Array[Vector2i] = [
    Vector2i(13, 24), Vector2i(22, 29), Vector2i(35, 20),
    Vector2i(58, 20), Vector2i(73, 30), Vector2i(83, 43),
    Vector2i(32, 53), Vector2i(43, 57), Vector2i(57, 58),
    Vector2i(67, 51), Vector2i(93, 29), Vector2i(4, 24),
    Vector2i(73, 59), Vector2i(75, 59), Vector2i(77, 59),
    Vector2i(84, 59), Vector2i(86, 59), Vector2i(88, 59),
    Vector2i(73, 66), Vector2i(75, 66), Vector2i(77, 66),
    Vector2i(84, 66), Vector2i(86, 66), Vector2i(88, 66),
]

const TREASURE_CELLS: Array[Vector2i] = [
    Vector2i(3, 18), Vector2i(12, 20), Vector2i(23, 18), Vector2i(34, 18),
    Vector2i(45, 18), Vector2i(56, 18), Vector2i(67, 18), Vector2i(78, 18),
    Vector2i(91, 18), Vector2i(5, 27), Vector2i(17, 26), Vector2i(29, 26),
    Vector2i(41, 24), Vector2i(54, 24), Vector2i(66, 26), Vector2i(78, 25),
    Vector2i(91, 27), Vector2i(4, 36), Vector2i(16, 36), Vector2i(29, 35),
    Vector2i(35, 32), Vector2i(62, 34), Vector2i(76, 35), Vector2i(92, 36),
    Vector2i(4, 44), Vector2i(16, 44), Vector2i(31, 44), Vector2i(42, 47),
    Vector2i(54, 47), Vector2i(67, 45), Vector2i(79, 44), Vector2i(92, 45),
    Vector2i(3, 68), Vector2i(30, 67), Vector2i(48, 56), Vector2i(59, 56),
    Vector2i(80, 62), Vector2i(91, 62), Vector2i(80, 68), Vector2i(91, 68),
]

static func in_bounds(cell: Vector2i) -> bool:
    return cell.x >= 1 and cell.y >= 1 and cell.x < WIDTH - 1 and cell.y < HEIGHT - 1

static func is_lake_cell(cell: Vector2i) -> bool:
    return Geometry2D.is_point_in_polygon(
        Vector2(cell) + Vector2(0.5, 0.5),
        PackedVector2Array(LAKE_POLYGON)
    )

static func is_structural_blocked(cell: Vector2i) -> bool:
    for building in BUILDING_RECTS:
        if building.has_point(cell):
            return true
    for bed in GARDEN_BED_RECTS:
        if bed.has_point(cell):
            return true
    return is_lake_cell(cell)

static func is_prop_blocked(cell: Vector2i) -> bool:
    return cell in TREE_CELLS

static func is_walkable(cell: Vector2i) -> bool:
    if not in_bounds(cell):
        return false
    return not is_structural_blocked(cell) and not is_prop_blocked(cell)

static func has_clearance(cell: Vector2i, radius: int) -> bool:
    for y in range(cell.y - radius, cell.y + radius + 1):
        for x in range(cell.x - radius, cell.x + radius + 1):
            if not is_walkable(Vector2i(x, y)):
                return false
    return true

static func to_world(cell: Vector2i) -> Vector2:
    return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2, cell.y * TILE_SIZE + TILE_SIZE / 2)

static func polygon_to_world(points: Array[Vector2]) -> PackedVector2Array:
    var result := PackedVector2Array()
    for point in points:
        result.append(point * TILE_SIZE)
    return result

static func treasure_world_positions() -> Array[Vector2]:
    var result: Array[Vector2] = []
    for cell in TREASURE_CELLS:
        result.append(to_world(cell))
    return result

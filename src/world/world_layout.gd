class_name WorldLayout
extends RefCounted

const WIDTH := 96
const HEIGHT := 72
const TILE_SIZE := 16
const PLAYER_START_CELL := Vector2i(48, 36)

const BLOCKED_RECTS: Array[Rect2i] = [
    Rect2i(5, 4, 25, 13),       # teaching building
    Rect2i(63, 6, 26, 12),      # second teaching building
    Rect2i(70, 49, 20, 15),     # garden pavilion
    Rect2i(6, 48, 22, 17),      # lake body
    Rect2i(35, 8, 6, 12),       # grove cluster
    Rect2i(52, 51, 5, 12),      # grove cluster
]

const TREE_CELLS: Array[Vector2i] = [
    Vector2i(36, 9), Vector2i(39, 12), Vector2i(37, 17),
    Vector2i(53, 52), Vector2i(55, 57), Vector2i(53, 61),
    Vector2i(31, 11), Vector2i(60, 17), Vector2i(64, 46),
]

const BENCH_CELLS: Array[Vector2i] = [Vector2i(31, 46), Vector2i(61, 35), Vector2i(30, 66)]

# Flowers are decorative and walkable; the world scene renders these cells as
# small petal/stem clusters using the approved palette.
const FLOWER_CELLS: Array[Vector2i] = [
    Vector2i(9, 28), Vector2i(23, 27), Vector2i(42, 24), Vector2i(57, 23),
    Vector2i(74, 37), Vector2i(87, 38), Vector2i(42, 64), Vector2i(64, 68),
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

static func is_prop_blocked(cell: Vector2i) -> bool:
    return cell in TREE_CELLS or cell in BENCH_CELLS

static func is_walkable(cell: Vector2i) -> bool:
    if not in_bounds(cell):
        return false
    for blocked in BLOCKED_RECTS:
        if blocked.has_point(cell):
            return false
    return not is_prop_blocked(cell)

static func has_clearance(cell: Vector2i, radius: int) -> bool:
    for y in range(cell.y - radius, cell.y + radius + 1):
        for x in range(cell.x - radius, cell.x + radius + 1):
            if not is_walkable(Vector2i(x, y)):
                return false
    return true

static func to_world(cell: Vector2i) -> Vector2:
    return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2, cell.y * TILE_SIZE + TILE_SIZE / 2)

static func treasure_world_positions() -> Array[Vector2]:
    var result: Array[Vector2] = []
    for cell in TREASURE_CELLS:
        result.append(to_world(cell))
    return result

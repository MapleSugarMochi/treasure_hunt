class_name CampusWorld
extends Node2D

const WorldLayout = preload("res://src/world/world_layout.gd")
const TILE_SIZE := 16
var path_segments: Array[PackedVector2Array] = [
    PackedVector2Array([
        Vector2(18, 21), Vector2(31, 20), Vector2(48, 19), Vector2(64, 20),
        Vector2(78, 21), Vector2(86, 27), Vector2(90, 34), Vector2(89, 41),
        Vector2(84, 48), Vector2(73, 54), Vector2(60, 56), Vector2(48, 56),
        Vector2(36, 54), Vector2(31, 52), Vector2(27, 47), Vector2(18, 45),
        Vector2(12, 39), Vector2(9, 32), Vector2(12, 25), Vector2(18, 21),
    ]),
    PackedVector2Array([Vector2(48, 19), Vector2(48, 28)]),
    PackedVector2Array([Vector2(58, 36), Vector2(90, 36)]),
    PackedVector2Array([Vector2(48, 44), Vector2(48, 56)]),
    PackedVector2Array([Vector2(38, 36), Vector2(12, 36)]),
]
const TREE_CELLS: Array[Vector2i] = WorldLayout.TREE_CELLS
const TREE_REGIONS: Array[Rect2] = [Rect2(96, 0, 64, 96), Rect2(160, 0, 64, 96)]

@onready var ground: TileMapLayer = $Ground
@onready var paths: TileMapLayer = $Paths
@onready var details: TileMapLayer = $Details
@onready var props: Node2D = $Props
@onready var obstacles: StaticBody2D = $Obstacles
var source_id := -1

func _ready() -> void:
    _configure_tiles()
    _paint_ground()
    _paint_paths()
    _paint_lake()
    _add_prop_sprites()
    _add_flower_decorations()
    _add_collisions()
    queue_redraw()

func _configure_tiles() -> void:
    var tile_set := TileSet.new()
    tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
    var atlas := TileSetAtlasSource.new()
    atlas.texture = load("res://assets/generated/terrain.png")
    atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
    for atlas_x in range(8):
        atlas.create_tile(Vector2i(atlas_x, 0))
    source_id = tile_set.add_source(atlas)
    ground.tile_set = tile_set
    paths.tile_set = tile_set
    details.tile_set = tile_set

func _paint_ground() -> void:
    for y in range(WorldLayout.HEIGHT):
        for x in range(WorldLayout.WIDTH):
            var variant := Vector2i(4, 0) if (x * 17 + y * 31) % 23 == 0 else Vector2i(0, 0)
            ground.set_cell(Vector2i(x, y), source_id, variant)

func _paint_paths() -> void:
    for path_index in range(path_segments.size()):
        var polyline := path_segments[path_index]
        var radius := 2 if path_index == 0 else 1
        for index in range(polyline.size() - 1):
            _paint_corridor(Vector2i(polyline[index]), Vector2i(polyline[index + 1]), radius)
    for y in range(WorldLayout.PLAZA_BOUNDS.position.y, WorldLayout.PLAZA_BOUNDS.end.y):
        for x in range(WorldLayout.PLAZA_BOUNDS.position.x, WorldLayout.PLAZA_BOUNDS.end.x):
            var cell := Vector2i(x, y)
            if WorldLayout.is_plaza_cell(cell) and WorldLayout.is_walkable(cell):
                paths.set_cell(cell, source_id, Vector2i(1, 0))

func _paint_corridor(from_cell: Vector2i, to_cell: Vector2i, radius: int) -> void:
    var delta := to_cell - from_cell
    var steps := maxi(absi(delta.x), absi(delta.y))
    for step in range(steps + 1):
        var ratio := float(step) / float(maxi(steps, 1))
        var center := Vector2i(Vector2(from_cell).lerp(Vector2(to_cell), ratio).round())
        for offset_y in range(-radius, radius + 1):
            for offset_x in range(-radius, radius + 1):
                var cell := center + Vector2i(offset_x, offset_y)
                if WorldLayout.is_walkable(cell):
                    paths.set_cell(cell, source_id, Vector2i(1, 0))

func _paint_lake() -> void:
    for cell in WorldLayout.lake_cells():
        details.set_cell(cell, source_id, Vector2i(2, 0))

func _add_prop_sprites() -> void:
    var texture: Texture2D = load("res://assets/generated/props.png")
    for index in range(TREE_CELLS.size()):
        var region: Rect2 = TREE_REGIONS[index % TREE_REGIONS.size()]
        _add_region_sprite(texture, region, WorldLayout.to_world(TREE_CELLS[index]), index)

func _add_region_sprite(texture: Texture2D, region: Rect2, world_position: Vector2, order: int) -> void:
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.region_enabled = true
    sprite.region_rect = region
    sprite.position = world_position
    sprite.z_index = 2
    sprite.name = "Prop%03d" % order
    props.add_child(sprite)

func _add_flower_decorations() -> void:
    var flowers := Node2D.new()
    flowers.name = "Flowers"
    flowers.z_index = 3
    props.add_child(flowers)
    for index in range(WorldLayout.FLOWER_CELLS.size()):
        var flower := Node2D.new()
        flower.name = "Flower%02d" % index
        flower.position = WorldLayout.to_world(WorldLayout.FLOWER_CELLS[index])
        var stem := Line2D.new()
        stem.name = "Stem"
        stem.width = 2.0
        stem.default_color = Color("527d45")
        stem.points = PackedVector2Array([Vector2(0, 1), Vector2(0, 7)])
        flower.add_child(stem)
        var petals := Polygon2D.new()
        petals.name = "Petals"
        petals.color = Color("d87943")
        petals.polygon = PackedVector2Array([
            Vector2(0, -5), Vector2(3, -2), Vector2(5, 0), Vector2(3, 2),
            Vector2(0, 5), Vector2(-3, 2), Vector2(-5, 0), Vector2(-3, -2),
        ])
        flower.add_child(petals)
        var center := Polygon2D.new()
        center.name = "Center"
        center.color = Color("f0bd46")
        center.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
        flower.add_child(center)
        flowers.add_child(flower)

func _add_collisions() -> void:
    for index in range(WorldLayout.BUILDING_RECTS.size()):
        _add_rect_collision(WorldLayout.BUILDING_RECTS[index], "BuildingRect%02d" % index)
    _add_lake_tile_collisions()
    for index in range(TREE_CELLS.size()):
        _add_prop_collision(TREE_CELLS[index], "TreeCollision%02d" % index)
    _add_boundary_collisions()

func _add_lake_tile_collisions() -> void:
    var lake_tile_shape := RectangleShape2D.new()
    lake_tile_shape.size = Vector2(TILE_SIZE, TILE_SIZE)
    for cell in WorldLayout.lake_cells():
        var collision := CollisionShape2D.new()
        collision.name = "LakeTileCollision_%02d_%02d" % [cell.x, cell.y]
        collision.shape = lake_tile_shape
        collision.position = WorldLayout.to_world(cell)
        collision.set_meta("lake_cell", cell)
        obstacles.add_child(collision)

func _add_rect_collision(blocked: Rect2i, collision_name: String) -> void:
    var shape := RectangleShape2D.new()
    shape.size = Vector2(blocked.size.x * TILE_SIZE, blocked.size.y * TILE_SIZE)
    var collision := CollisionShape2D.new()
    collision.name = collision_name
    collision.shape = shape
    collision.position = Vector2(
        (blocked.position.x + blocked.size.x / 2.0) * TILE_SIZE,
        (blocked.position.y + blocked.size.y / 2.0) * TILE_SIZE
    )
    obstacles.add_child(collision)

func _add_prop_collision(cell: Vector2i, collision_name: String) -> void:
    var shape := RectangleShape2D.new()
    shape.size = Vector2(TILE_SIZE, TILE_SIZE)
    var collision := CollisionShape2D.new()
    collision.name = collision_name
    collision.shape = shape
    collision.position = WorldLayout.to_world(cell)
    collision.set_meta("blocked_cell", cell)
    obstacles.add_child(collision)

func _add_boundary_collisions() -> void:
    var world_size := Vector2(WorldLayout.WIDTH * TILE_SIZE, WorldLayout.HEIGHT * TILE_SIZE)
    var boundaries := [
        ["BoundaryTop", Vector2(world_size.x / 2.0, -TILE_SIZE / 2.0), Vector2(world_size.x, TILE_SIZE)],
        ["BoundaryBottom", Vector2(world_size.x / 2.0, world_size.y + TILE_SIZE / 2.0), Vector2(world_size.x, TILE_SIZE)],
        ["BoundaryLeft", Vector2(-TILE_SIZE / 2.0, world_size.y / 2.0), Vector2(TILE_SIZE, world_size.y)],
        ["BoundaryRight", Vector2(world_size.x + TILE_SIZE / 2.0, world_size.y / 2.0), Vector2(TILE_SIZE, world_size.y)],
    ]
    for boundary in boundaries:
        var shape := RectangleShape2D.new()
        shape.size = boundary[2]
        var collision := CollisionShape2D.new()
        collision.name = boundary[0]
        collision.shape = shape
        collision.position = boundary[1]
        collision.set_meta("world_boundary", true)
        obstacles.add_child(collision)

func _draw() -> void:
    var wall := Color("e9d3a5")
    var roof := Color("a6533e")
    var outline := Color("3b302b")

    for index in range(WorldLayout.BUILDING_RECTS.size()):
        _draw_teaching_building(WorldLayout.BUILDING_RECTS[index], index, wall, roof, outline)

    draw_rect(Rect2(0, 34 * TILE_SIZE, 2 * TILE_SIZE, 6 * TILE_SIZE), outline)
    draw_rect(Rect2(94 * TILE_SIZE, 34 * TILE_SIZE, 2 * TILE_SIZE, 6 * TILE_SIZE), outline)

func _draw_teaching_building(
    blocked: Rect2i,
    building_index: int,
    wall: Color,
    roof: Color,
    outline: Color
) -> void:
    var rect := Rect2(
        Vector2(blocked.position.x * TILE_SIZE, blocked.position.y * TILE_SIZE),
        Vector2(blocked.size.x * TILE_SIZE, blocked.size.y * TILE_SIZE)
    )
    var inner := rect.grow(-6.0)
    var roof_height := 34.0
    var roof_rect := Rect2(inner.position, Vector2(inner.size.x, roof_height))

    draw_rect(Rect2(rect.position + Vector2(6, 8), rect.size), Color("5471447a"))
    draw_rect(rect, outline)
    draw_rect(inner, wall)
    draw_rect(Rect2(inner.position, Vector2(inner.size.x, 5)), Color("c06a4e"))
    draw_rect(roof_rect.grow_side(SIDE_TOP, -5.0), roof)
    draw_line(
        roof_rect.position + Vector2(0, roof_rect.size.y),
        roof_rect.position + Vector2(roof_rect.size.x, roof_rect.size.y),
        outline,
        4.0
    )
    for roof_x in range(int(roof_rect.position.x) + 24, int(roof_rect.end.x), 32):
        draw_line(
            Vector2(roof_x, roof_rect.position.y + 6),
            Vector2(roof_x - 10, roof_rect.end.y - 4),
            Color("853e34"),
            2.0
        )

    var facade_top := roof_rect.end.y + 14.0
    draw_rect(
        Rect2(Vector2(inner.position.x, facade_top - 8), Vector2(inner.size.x, 5)),
        Color("d2ae6e")
    )
    var column_count := 3 if building_index == 0 else 6
    var row_count := 2 if building_index == 0 else 1
    var side_margin := 22.0
    var column_step := (inner.size.x - side_margin * 2.0) / float(column_count)
    for row in range(row_count):
        var window_y := facade_top + 18.0 + row * 42.0
        for column in range(column_count):
            var window_center_x := inner.position.x + side_margin + column_step * (column + 0.5)
            var window_rect := Rect2(Vector2(window_center_x - 12.0, window_y), Vector2(24, 15))
            draw_rect(window_rect.grow(3.0), outline)
            draw_rect(window_rect, Color("5f8f99"))
            draw_rect(Rect2(window_rect.position + Vector2(3, 3), Vector2(18, 3)), Color("9bc8be"))
            draw_line(
                Vector2(window_rect.get_center().x, window_rect.position.y),
                Vector2(window_rect.get_center().x, window_rect.end.y),
                outline,
                2.0
            )

    var door_size := Vector2(30, 38)
    var door_rect := Rect2(
        Vector2(rect.get_center().x - door_size.x / 2.0, inner.end.y - door_size.y),
        door_size
    )
    draw_rect(door_rect.grow(4.0), outline)
    draw_rect(door_rect, Color("765044"))
    draw_rect(Rect2(door_rect.position + Vector2(5, 5), Vector2(8, 24)), Color("b9d3c5"))
    draw_rect(Rect2(door_rect.position + Vector2(17, 5), Vector2(8, 24)), Color("b9d3c5"))
    draw_circle(door_rect.position + Vector2(15, 32), 2.0, Color("f0bd46"))
    draw_rect(
        Rect2(Vector2(door_rect.position.x - 10, inner.end.y - 2), Vector2(door_size.x + 20, 5)),
        Color("d2ae6e")
    )

func get_player_start() -> Vector2:
    return WorldLayout.to_world(WorldLayout.PLAYER_START_CELL)

func get_treasure_positions() -> Array[Vector2]:
    return WorldLayout.treasure_world_positions()

func get_world_rect() -> Rect2:
    return Rect2(Vector2.ZERO, Vector2(WorldLayout.WIDTH * TILE_SIZE, WorldLayout.HEIGHT * TILE_SIZE))

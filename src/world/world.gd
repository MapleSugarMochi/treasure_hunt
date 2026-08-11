class_name CampusWorld
extends Node2D

const WorldLayout = preload("res://src/world/world_layout.gd")
const TILE_SIZE := 16
var path_segments: Array[PackedVector2Array] = [
    PackedVector2Array([Vector2(2, 36), Vector2(94, 36)]),
    PackedVector2Array([Vector2(48, 2), Vector2(48, 70)]),
    PackedVector2Array([Vector2(4, 23), Vector2(31, 25), Vector2(48, 36)]),
    PackedVector2Array([Vector2(48, 36), Vector2(70, 28), Vector2(92, 24)]),
    PackedVector2Array([Vector2(48, 36), Vector2(65, 47), Vector2(93, 68)]),
    PackedVector2Array([Vector2(48, 36), Vector2(34, 52), Vector2(29, 68)]),
]
const TREE_CELLS: Array[Vector2i] = WorldLayout.TREE_CELLS
const BENCH_CELLS: Array[Vector2i] = WorldLayout.BENCH_CELLS
const TREE_REGIONS: Array[Rect2] = [Rect2(96, 0, 64, 96), Rect2(160, 0, 64, 96)]
const BENCH_REGION := Rect2(208, 96, 48, 32)

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
    for polyline in path_segments:
        for index in range(polyline.size() - 1):
            _paint_corridor(Vector2i(polyline[index]), Vector2i(polyline[index + 1]), 2)
    for y in range(31, 42):
        for x in range(42, 55):
            if WorldLayout.is_walkable(Vector2i(x, y)):
                paths.set_cell(Vector2i(x, y), source_id, Vector2i(1, 0))

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
    var lake := WorldLayout.BLOCKED_RECTS[3]
    for y in range(lake.position.y, lake.end.y):
        for x in range(lake.position.x, lake.end.x):
            details.set_cell(Vector2i(x, y), source_id, Vector2i(2, 0))

func _add_prop_sprites() -> void:
    var texture: Texture2D = load("res://assets/generated/props.png")
    for index in range(TREE_CELLS.size()):
        var region: Rect2 = TREE_REGIONS[index % TREE_REGIONS.size()]
        _add_region_sprite(texture, region, WorldLayout.to_world(TREE_CELLS[index]), index)
    for index in range(BENCH_CELLS.size()):
        _add_region_sprite(texture, BENCH_REGION, WorldLayout.to_world(BENCH_CELLS[index]), 100 + index)

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
    for index in range(WorldLayout.BLOCKED_RECTS.size()):
        var blocked := WorldLayout.BLOCKED_RECTS[index]
        var shape := RectangleShape2D.new()
        shape.size = Vector2(blocked.size.x * TILE_SIZE, blocked.size.y * TILE_SIZE)
        var collision := CollisionShape2D.new()
        collision.name = "BlockedRect%02d" % index
        collision.shape = shape
        collision.position = Vector2(
            (blocked.position.x + blocked.size.x / 2.0) * TILE_SIZE,
            (blocked.position.y + blocked.size.y / 2.0) * TILE_SIZE
        )
        obstacles.add_child(collision)
    for index in range(TREE_CELLS.size()):
        _add_prop_collision(TREE_CELLS[index], "TreeCollision%02d" % index)
    for index in range(BENCH_CELLS.size()):
        _add_prop_collision(BENCH_CELLS[index], "BenchCollision%02d" % index)
    _add_boundary_collisions()

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
    for index in [0, 1, 2]:
        var blocked := WorldLayout.BLOCKED_RECTS[index]
        var rect := Rect2(
            Vector2(blocked.position.x * TILE_SIZE, blocked.position.y * TILE_SIZE),
            Vector2(blocked.size.x * TILE_SIZE, blocked.size.y * TILE_SIZE)
        )
        draw_rect(rect, outline)
        draw_rect(rect.grow(-6.0), wall)
        draw_rect(Rect2(rect.position + Vector2(6, 6), Vector2(rect.size.x - 12, 20)), roof)
    draw_rect(Rect2(0, 34 * TILE_SIZE, 2 * TILE_SIZE, 6 * TILE_SIZE), outline)
    draw_rect(Rect2(94 * TILE_SIZE, 34 * TILE_SIZE, 2 * TILE_SIZE, 6 * TILE_SIZE), outline)

func get_player_start() -> Vector2:
    return WorldLayout.to_world(WorldLayout.PLAYER_START_CELL)

func get_treasure_positions() -> Array[Vector2]:
    return WorldLayout.treasure_world_positions()

func get_world_rect() -> Rect2:
    return Rect2(Vector2.ZERO, Vector2(WorldLayout.WIDTH * TILE_SIZE, WorldLayout.HEIGHT * TILE_SIZE))

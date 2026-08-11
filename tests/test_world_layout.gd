extends RefCounted

const Layout = preload("res://src/world/world_layout.gd")
const CampusWorld = preload("res://src/world/world.gd")

func run(t: SceneTree) -> void:
    t.assert_eq(Layout.WIDTH, 96, "map width is fixed")
    t.assert_eq(Layout.HEIGHT, 72, "map height is fixed")
    t.assert_eq(Layout.TREASURE_CELLS.size(), 40, "exactly 40 candidate points")
    t.assert_true(Layout.is_walkable(Layout.PLAYER_START_CELL), "player start is walkable")
    for cell in Layout.TREASURE_CELLS:
        t.assert_true(Layout.in_bounds(cell), "candidate is in bounds: %s" % cell)
        t.assert_true(Layout.is_walkable(cell), "candidate is walkable: %s" % cell)
        t.assert_true(Layout.has_clearance(cell, 1), "candidate has one-tile clearance: %s" % cell)
    var reachable := _flood_fill(Layout.PLAYER_START_CELL)
    for cell in Layout.TREASURE_CELLS:
        t.assert_true(reachable.has(cell), "candidate is reachable: %s" % cell)

    for cell in Layout.TREE_CELLS:
        t.assert_true(not Layout.is_walkable(cell), "tree cell is blocked: %s" % cell)
    for cell in Layout.BENCH_CELLS:
        t.assert_true(not Layout.is_walkable(cell), "bench cell is blocked: %s" % cell)

    var world_scene := load("res://src/world/world.tscn") as PackedScene
    t.assert_true(world_scene != null, "world scene loads")
    if world_scene == null:
        return
    var world := world_scene.instantiate() as CampusWorld
    t.assert_true(world != null, "world scene instantiates CampusWorld")
    if world == null:
        return
    t.root.add_child(world)
    t.assert_eq(world.get_treasure_positions().size(), 40, "world exposes all 40 treasure positions")
    t.assert_eq(world.get_player_start(), Layout.to_world(Layout.PLAYER_START_CELL), "world exposes player start")
    t.assert_eq(world.get_world_rect().size, Vector2(1536, 1152), "world rect is 96x72 tiles")
    for node_name in ["Ground", "Paths", "Details", "Props", "Obstacles"]:
        t.assert_true(world.get_node_or_null(node_name) != null, "world has node: %s" % node_name)

    for index in range(Layout.TREASURE_CELLS.size()):
        t.assert_eq(world.get_treasure_positions()[index], Layout.to_world(Layout.TREASURE_CELLS[index]), "world marker position matches layout")

    var obstacles := world.get_node("Obstacles")
    var boundary_specs := {
        "BoundaryTop": [Vector2(768, -8), Vector2(1536, 16)],
        "BoundaryBottom": [Vector2(768, 1160), Vector2(1536, 16)],
        "BoundaryLeft": [Vector2(-8, 576), Vector2(16, 1152)],
        "BoundaryRight": [Vector2(1544, 576), Vector2(16, 1152)],
    }
    var boundary_count := 0
    for boundary_name in boundary_specs:
        var boundary := obstacles.get_node_or_null(boundary_name) as CollisionShape2D
        t.assert_true(boundary != null, "world has boundary collision: %s" % boundary_name)
        if boundary != null:
            boundary_count += 1
            t.assert_true(boundary.shape is RectangleShape2D, "boundary uses rectangle shape: %s" % boundary_name)
            t.assert_eq(boundary.position, boundary_specs[boundary_name][0], "boundary position is exact: %s" % boundary_name)
            t.assert_eq((boundary.shape as RectangleShape2D).size, boundary_specs[boundary_name][1], "boundary size is exact: %s" % boundary_name)
    t.assert_eq(boundary_count, 4, "world has four edge boundaries")

    var blocked_count := 0
    var tree_count := 0
    var bench_count := 0
    for child in obstacles.get_children():
        if child.name.begins_with("BlockedRect"):
            blocked_count += 1
        elif child.name.begins_with("TreeCollision"):
            tree_count += 1
        elif child.name.begins_with("BenchCollision"):
            bench_count += 1
    t.assert_eq(blocked_count, Layout.BLOCKED_RECTS.size(), "building/lake collision count matches layout")
    t.assert_eq(tree_count, Layout.TREE_CELLS.size(), "tree collision count matches layout")
    t.assert_eq(bench_count, Layout.BENCH_CELLS.size(), "bench collision count matches layout")
    for index in range(Layout.TREE_CELLS.size()):
        var tree_collision := obstacles.get_node("TreeCollision%02d" % index) as CollisionShape2D
        t.assert_true(tree_collision != null, "tree collision node exists: %d" % index)
        if tree_collision != null:
            t.assert_eq(tree_collision.position, Layout.to_world(Layout.TREE_CELLS[index]), "tree collision position matches cell")
            t.assert_eq((tree_collision.shape as RectangleShape2D).size, Vector2(16, 16), "tree collision footprint is one tile")
    for index in range(Layout.BENCH_CELLS.size()):
        var bench_collision := obstacles.get_node("BenchCollision%02d" % index) as CollisionShape2D
        t.assert_true(bench_collision != null, "bench collision node exists: %d" % index)
        if bench_collision != null:
            t.assert_eq(bench_collision.position, Layout.to_world(Layout.BENCH_CELLS[index]), "bench collision position matches cell")
            t.assert_eq((bench_collision.shape as RectangleShape2D).size, Vector2(16, 16), "bench collision footprint is one tile")

    var flowers := world.get_node("Props/Flowers")
    t.assert_eq(flowers.get_child_count(), Layout.FLOWER_CELLS.size(), "world renders every flower cell")
    for flower in flowers.get_children():
        t.assert_true(flower.name.begins_with("Flower"), "flower node has stable name")
        t.assert_true(flower.get_child_count() >= 3, "flower has stem, petals, and center")
    world.free()

func _flood_fill(start: Vector2i) -> Dictionary:
    var visited := {start: true}
    var queue: Array[Vector2i] = [start]
    while not queue.is_empty():
        var current: Vector2i = queue.pop_front()
        for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var next: Vector2i = current + direction
            if not visited.has(next) and Layout.is_walkable(next):
                visited[next] = true
                queue.append(next)
    return visited

extends RefCounted

const TreasureSpawner = preload("res://src/treasure/treasure_spawner.gd")

var spawn_events: Array[Area2D] = []

func _record_spawn(treasure: Area2D) -> void:
    spawn_events.append(treasure)

func run(t: SceneTree) -> void:
    var points: Array[Vector2] = [Vector2(288, 0), Vector2(320, 0), Vector2(640, 0)]
    var rng_a := RandomNumberGenerator.new()
    rng_a.seed = 12345
    var rng_b := RandomNumberGenerator.new()
    rng_b.seed = 12345
    var sequence_a: Array[int] = []
    var sequence_b: Array[int] = []
    var seen_indices := {}
    for iteration in range(30):
        var index_a: int = TreasureSpawner.choose_spawn_index(points, Vector2.ZERO, 1, 288.0, rng_a)
        var index_b: int = TreasureSpawner.choose_spawn_index(points, Vector2.ZERO, 1, 288.0, rng_b)
        sequence_a.append(index_a)
        sequence_b.append(index_b)
        seen_indices[index_a] = true
        t.assert_true(index_a != 1, "selection excludes previous point")
        t.assert_true(index_a >= 0 and points[index_a].distance_to(Vector2.ZERO) >= 288.0, "selection meets minimum distance")
        t.assert_true(index_a in [0, 2], "selection uses the eligible candidate set")
        t.assert_eq(index_a, index_b, "same seed produces the same selection at each draw")
    t.assert_eq(sequence_a, sequence_b, "same seed produces a reproducible sequence")
    t.assert_true(seen_indices.size() >= 2, "seeded selection produces a non-trivial sequence")

    var boundary_rng := RandomNumberGenerator.new()
    boundary_rng.seed = 24680
    var boundary_seen := {}
    for iteration in range(30):
        var boundary_index: int = TreasureSpawner.choose_spawn_index(
            [Vector2(288, 0), Vector2(640, 0)], Vector2.ZERO, -1, 288.0, boundary_rng
        )
        boundary_seen[boundary_index] = true
    t.assert_true(boundary_seen.has(0), "288 pixels is included at the minimum boundary")
    t.assert_true(boundary_seen.has(1), "another qualifying point remains selectable")

    var below_rng := RandomNumberGenerator.new()
    below_rng.seed = 24680
    for iteration in range(30):
        var below_index: int = TreasureSpawner.choose_spawn_index(
            [Vector2(287.99, 0), Vector2(640, 0)], Vector2.ZERO, -1, 288.0, below_rng
        )
        t.assert_eq(below_index, 1, "slightly-below-boundary point is excluded")

    var fallback_rng := RandomNumberGenerator.new()
    fallback_rng.seed = 111
    var fallback_points: Array[Vector2] = [Vector2.ZERO, Vector2(80, 0), Vector2(160, 0)]
    var fallback := TreasureSpawner.choose_spawn_index(fallback_points, Vector2.ZERO, 2, 9999.0, fallback_rng)
    t.assert_eq(fallback, 1, "fallback excludes the farthest previous point")

    t.assert_eq(TreasureSpawner.choose_spawn_index([], Vector2.ZERO, -1, 10.0, fallback_rng), -1, "empty points return -1")

    var tie_points: Array[Vector2] = [Vector2(100, 0), Vector2(-100, 0), Vector2(10, 0)]
    var tie_rng_a := RandomNumberGenerator.new()
    tie_rng_a.seed = 1
    var tie_rng_b := RandomNumberGenerator.new()
    tie_rng_b.seed = 2
    t.assert_eq(TreasureSpawner.choose_spawn_index(tie_points, Vector2.ZERO, -1, 9999.0, tie_rng_a), 0, "equal farthest distances choose the first index")
    t.assert_eq(TreasureSpawner.choose_spawn_index(tie_points, Vector2.ZERO, -1, 9999.0, tie_rng_b), 0, "equal farthest tie is independent of RNG")

    t.assert_eq(TreasureSpawner.choose_spawn_index([Vector2.ZERO], Vector2.ZERO, 0, 10.0, fallback_rng), -1, "only previous point returns -1")

    var treasure_template := Area2D.new()
    treasure_template.name = "Treasure"
    var treasure_scene := PackedScene.new()
    t.assert_eq(treasure_scene.pack(treasure_template), OK, "real Area2D scene packs")
    treasure_template.free()

    var spawner := TreasureSpawner.new()
    spawner.treasure_scene = treasure_scene
    spawner.rng.seed = 97531
    spawner.treasure_spawned.connect(_record_spawn)
    t.root.add_child(spawner)
    var spawn_points: Array[Vector2] = [Vector2(100, 20), Vector2(200, 20), Vector2(300, 20)]

    spawn_events.clear()
    var first_treasure: Area2D = spawner.spawn_next(spawn_points, Vector2.ZERO, 0.0)
    var first_index: int = spawn_points.find(first_treasure.global_position)
    t.assert_true(first_treasure != null and first_treasure == spawner.current_treasure, "first spawn becomes current treasure")
    t.assert_true(first_index >= 0, "first spawn position comes from points")
    t.assert_eq(spawner.previous_index, first_index, "first spawn updates previous index")
    t.assert_eq(spawn_events.size(), 1, "first spawn emits exactly one signal")
    t.assert_true(spawn_events[0] == first_treasure, "first signal carries the spawned treasure")

    var second_treasure: Area2D = spawner.spawn_next(spawn_points, Vector2.ZERO, 0.0)
    var second_index: int = spawn_points.find(second_treasure.global_position)
    t.assert_true(second_treasure != first_treasure, "second spawn creates a new instance")
    t.assert_true(second_treasure == spawner.current_treasure, "second spawn replaces current treasure")
    t.assert_true(second_index >= 0 and second_index != first_index, "second spawn excludes the previous point")
    t.assert_true(first_treasure.is_queued_for_deletion(), "replaced treasure is queued for deletion")
    t.assert_eq(spawner.previous_index, second_index, "second spawn updates previous index")
    t.assert_eq(spawn_events.size(), 2, "second spawn emits exactly one additional signal")
    t.assert_true(spawn_events[1] == second_treasure, "second signal carries the replacement treasure")

    var current_before_failure: Area2D = spawner.current_treasure
    var previous_before_failure: int = spawner.previous_index
    spawner.treasure_scene = null
    var null_scene_result: Area2D = spawner.spawn_next(spawn_points, Vector2.ZERO, 0.0)
    t.assert_true(null_scene_result == null, "missing treasure scene fails safely")
    t.assert_true(spawner.current_treasure == current_before_failure, "missing scene preserves current treasure")
    t.assert_eq(spawner.previous_index, previous_before_failure, "missing scene preserves previous index")
    t.assert_eq(spawn_events.size(), 2, "missing scene emits no signal")

    var impossible_spawner := TreasureSpawner.new()
    impossible_spawner.treasure_scene = treasure_scene
    t.root.add_child(impossible_spawner)
    impossible_spawner.previous_index = 0
    var impossible_result: Area2D = impossible_spawner.spawn_next([Vector2.ZERO], Vector2.ZERO, 0.0)
    t.assert_true(impossible_result == null, "no valid index fails safely")
    t.assert_true(impossible_spawner.current_treasure == null, "no valid index leaves current treasure empty")
    t.assert_eq(impossible_spawner.previous_index, 0, "no valid index preserves previous index")

    spawner.free()
    impossible_spawner.free()

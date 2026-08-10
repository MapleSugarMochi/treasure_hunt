extends RefCounted

const TreasureSpawner = preload("res://src/treasure/treasure_spawner.gd")

func run(t: SceneTree) -> void:
    var points: Array[Vector2] = [Vector2.ZERO, Vector2(64, 0), Vector2(320, 0), Vector2(640, 0)]
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345
    for iteration in range(30):
        var index := TreasureSpawner.choose_spawn_index(points, Vector2.ZERO, 2, 288.0, rng)
        t.assert_true(index == 3, "selection excludes previous point and points closer than 18 metres")

    var fallback_points: Array[Vector2] = [Vector2.ZERO, Vector2(80, 0), Vector2(160, 0)]
    var fallback := TreasureSpawner.choose_spawn_index(fallback_points, Vector2.ZERO, 0, 9999.0, rng)
    t.assert_eq(fallback, 2, "fallback chooses farthest non-previous point")

    var impossible: Array[Vector2] = [Vector2.ZERO]
    t.assert_eq(TreasureSpawner.choose_spawn_index(impossible, Vector2.ZERO, 0, 10.0, rng), -1, "one repeated point is invalid")

class_name TreasureSpawner
extends Node2D

signal treasure_spawned(treasure: Area2D)

@export var treasure_scene: PackedScene
var previous_index := -1
var current_treasure: Area2D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

static func choose_spawn_index(
    points: Array[Vector2],
    player_position: Vector2,
    previous: int,
    minimum_distance_pixels: float,
    random: RandomNumberGenerator
) -> int:
    var eligible: Array[int] = []
    for index in range(points.size()):
        if index == previous:
            continue
        if points[index].distance_to(player_position) >= minimum_distance_pixels:
            eligible.append(index)
    if not eligible.is_empty():
        return eligible[random.randi_range(0, eligible.size() - 1)]

    var farthest_index := -1
    var farthest_distance := -1.0
    for index in range(points.size()):
        if index == previous:
            continue
        var distance := points[index].distance_to(player_position)
        if distance > farthest_distance:
            farthest_distance = distance
            farthest_index = index
    return farthest_index

func spawn_next(points: Array[Vector2], player_position: Vector2, minimum_distance_pixels: float) -> Area2D:
    var index := choose_spawn_index(points, player_position, previous_index, minimum_distance_pixels, rng)
    if index < 0 or treasure_scene == null:
        return null
    if is_instance_valid(current_treasure):
        current_treasure.monitoring = false
        current_treasure.set_deferred("monitoring", false)
        current_treasure.queue_free()
    current_treasure = treasure_scene.instantiate() as Area2D
    current_treasure.global_position = points[index]
    add_child(current_treasure)
    previous_index = index
    treasure_spawned.emit(current_treasure)
    return current_treasure

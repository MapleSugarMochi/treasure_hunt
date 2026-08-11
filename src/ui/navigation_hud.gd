class_name NavigationHUD
extends Control

const NavigationMath = preload("res://src/ui/navigation_math.gd")

@onready var arrow: TextureRect = %Arrow
@onready var distance_label: Label = %DistanceLabel
var player: Node2D
var treasure: Node2D

func set_target(next_player: Node2D, next_treasure: Node2D) -> void:
    player = next_player
    treasure = next_treasure
    visible = is_instance_valid(player) and is_instance_valid(treasure)
    update_now()

func clear_target() -> void:
    player = null
    treasure = null
    visible = false

func _process(_delta: float) -> void:
    update_now()

func update_now() -> void:
    if not is_instance_valid(player) or not is_instance_valid(treasure):
        visible = false
        return
    visible = true
    arrow.rotation = NavigationMath.direction_angle(player.global_position, treasure.global_position)
    distance_label.text = "距离宝藏 %d 米" % NavigationMath.distance_metres(player.global_position, treasure.global_position)

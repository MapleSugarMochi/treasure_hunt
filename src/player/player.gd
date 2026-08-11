class_name Player
extends CharacterBody2D

const GameConfig = preload("res://src/config/game_config.gd")
const InputSetup = preload("res://src/config/input_setup.gd")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var movement_enabled := false
var facing := "down"

func _ready() -> void:
    InputSetup.ensure_actions()

static func normalized_input(value: Vector2) -> Vector2:
    return value.normalized() if value.length_squared() > 1.0 else value

func velocity_for_input(value: Vector2) -> Vector2:
    if not movement_enabled:
        return Vector2.ZERO
    return normalized_input(value) * GameConfig.PLAYER_SPEED_PIXELS_PER_SECOND

func _physics_process(_delta: float) -> void:
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = velocity_for_input(input_vector)
    if velocity != Vector2.ZERO:
        if absf(velocity.x) > absf(velocity.y):
            facing = "right" if velocity.x > 0.0 else "left"
        else:
            facing = "down" if velocity.y > 0.0 else "up"
        sprite.play("walk_%s" % facing)
    else:
        sprite.play("idle_%s" % facing)
    move_and_slide()

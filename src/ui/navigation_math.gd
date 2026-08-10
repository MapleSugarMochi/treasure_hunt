class_name NavigationMath
extends RefCounted

const GameConfig = preload("res://src/config/game_config.gd")

static func direction_angle(from_position: Vector2, to_position: Vector2) -> float:
    return (to_position - from_position).angle()

static func distance_metres(from_position: Vector2, to_position: Vector2) -> int:
    return roundi(from_position.distance_to(to_position) / GameConfig.PIXELS_PER_METRE)

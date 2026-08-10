extends RefCounted

const NavigationMath = preload("res://src/ui/navigation_math.gd")

func run(t: SceneTree) -> void:
    t.assert_approx(NavigationMath.direction_angle(Vector2.ZERO, Vector2.RIGHT), 0.0, 0.0001, "right is zero radians")
    t.assert_approx(NavigationMath.direction_angle(Vector2.ZERO, Vector2.DOWN), PI / 2.0, 0.0001, "down is pi over two")
    t.assert_approx(NavigationMath.direction_angle(Vector2.ZERO, Vector2.LEFT), PI, 0.0001, "left is pi radians")
    t.assert_approx(NavigationMath.direction_angle(Vector2.ZERO, Vector2.UP), -PI / 2.0, 0.0001, "up is negative pi over two")
    t.assert_eq(NavigationMath.distance_metres(Vector2.ZERO, Vector2(368.0, 0.0)), 23, "368 pixels is 23 metres")
    t.assert_eq(NavigationMath.distance_metres(Vector2.ZERO, Vector2(23.0, 0.0)), 1, "distance rounds to nearest integer")

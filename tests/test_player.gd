extends RefCounted

const Player = preload("res://src/player/player.gd")
const InputSetup = preload("res://src/config/input_setup.gd")

const ACTION_KEYS := {
    "move_left": [KEY_A, KEY_LEFT],
    "move_right": [KEY_D, KEY_RIGHT],
    "move_up": [KEY_W, KEY_UP],
    "move_down": [KEY_S, KEY_DOWN],
}
const ANIMATIONS := [
    &"idle_down", &"idle_up", &"idle_left", &"idle_right",
    &"walk_down", &"walk_up", &"walk_left", &"walk_right",
]

func run(t: SceneTree) -> void:
    t.assert_eq(Player.normalized_input(Vector2(1, 0)), Vector2.RIGHT, "cardinal input unchanged")
    t.assert_approx(Player.normalized_input(Vector2(1, 1)).length(), 1.0, 0.0001, "diagonal input normalized")
    var rule_player := Player.new()
    rule_player.movement_enabled = false
    t.assert_eq(rule_player.velocity_for_input(Vector2.RIGHT), Vector2.ZERO, "movement lock produces zero velocity")
    rule_player.movement_enabled = true
    t.assert_eq(rule_player.velocity_for_input(Vector2.RIGHT), Vector2(72, 0), "enabled movement uses configured speed")
    t.assert_approx(rule_player.velocity_for_input(Vector2(1, 1)).length(), 72.0, 0.0001, "enabled diagonal speed stays configured")
    rule_player.free()

    InputSetup.ensure_actions()
    var event_counts := {}
    for action_name in ACTION_KEYS:
        t.assert_true(InputMap.has_action(action_name), "action is registered: %s" % action_name)
        event_counts[action_name] = InputMap.action_get_events(action_name).size()
        var keycodes := {}
        for event in InputMap.action_get_events(action_name):
            if event is InputEventKey:
                keycodes[(event as InputEventKey).keycode] = true
        for keycode: int in ACTION_KEYS[action_name]:
            t.assert_true(keycodes.has(keycode), "action has required key: %s/%d" % [action_name, keycode])
    InputSetup.ensure_actions()
    for action_name in ACTION_KEYS:
        t.assert_eq(InputMap.action_get_events(action_name).size(), event_counts[action_name], "ensure_actions is idempotent: %s" % action_name)

    var player_scene := load("res://src/player/player.tscn") as PackedScene
    t.assert_true(player_scene != null, "player scene loads")
    if player_scene == null:
        return
    var player := player_scene.instantiate()
    t.assert_true(player is CharacterBody2D, "player scene root is CharacterBody2D")
    t.root.add_child(player)

    var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
    t.assert_true(sprite != null, "player has AnimatedSprite2D")
    var camera := player.get_node_or_null("Camera2D") as Camera2D
    t.assert_true(camera != null, "player has Camera2D")
    if camera != null:
        t.assert_true(camera.position_smoothing_enabled, "camera smoothing is enabled")
        t.assert_approx(camera.position_smoothing_speed, 8.0, 0.0001, "camera smoothing speed is 8")
        t.assert_eq(camera.position, Vector2.ZERO, "camera starts at integer origin")

    var collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
    t.assert_true(collision != null, "player has collision shape")
    if collision != null:
        var capsule := collision.shape as CapsuleShape2D
        t.assert_true(capsule != null, "player collision is a capsule")
        if capsule != null:
            t.assert_approx(capsule.radius, 6.0, 0.0001, "collision radius is 6 pixels")
            t.assert_approx(capsule.height, 12.0, 0.0001, "collision height is 12 pixels")
        t.assert_eq(collision.position, Vector2(0, 10), "collision sits on lower player body")

    if sprite == null:
        player.free()
        return
    var source_paths := {}
    for animation_name: StringName in ANIMATIONS:
        t.assert_true(sprite.sprite_frames.has_animation(animation_name), "animation exists: %s" % animation_name)
        var frame_count := sprite.sprite_frames.get_frame_count(animation_name)
        t.assert_true(frame_count > 0, "animation has frames: %s" % animation_name)
        for frame_index in range(frame_count):
            var frame_texture := sprite.sprite_frames.get_frame_texture(animation_name, frame_index)
            t.assert_true(frame_texture is AtlasTexture, "animation frame uses AtlasTexture: %s" % animation_name)
            if frame_texture is AtlasTexture:
                var atlas_texture := frame_texture as AtlasTexture
                t.assert_eq(atlas_texture.region.size, Vector2(24, 32), "frame region is 24x32: %s" % animation_name)
                if atlas_texture.atlas != null:
                    source_paths[atlas_texture.atlas.resource_path] = true
    t.assert_eq(source_paths.size(), 1, "all animation frames share one source texture")
    t.assert_true(source_paths.has("res://assets/generated/player.png"), "animation source is player.png")

    player.movement_enabled = false
    Input.action_press("move_right")
    player._physics_process(0.0)
    t.assert_eq(player.velocity, Vector2.ZERO, "real player movement lock produces zero velocity")
    t.assert_eq(sprite.animation, &"idle_down", "locked player remains idle")
    player.movement_enabled = true
    player._physics_process(0.0)
    t.assert_eq(player.facing, "right", "right input updates facing")
    t.assert_eq(sprite.animation, &"walk_right", "right input selects walk animation")
    Input.action_release("move_right")
    player._physics_process(0.0)
    t.assert_eq(sprite.animation, &"idle_right", "released input selects facing idle animation")
    player.free()

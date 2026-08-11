extends RefCounted

var found_count := 0
var celebration_count := 0

func run(t: SceneTree) -> void:
    var treasure := _instance(t, "res://src/treasure/treasure.tscn")
    var hud := _instance(t, "res://src/ui/navigation_hud.tscn")
    var ui := _instance(t, "res://src/ui/game_ui.tscn")

    _assert_treasure_contract(t, treasure)
    _assert_treasure_contact(t, treasure)
    _assert_hud_contract(t, hud)
    _assert_hud_navigation(t, hud)
    _assert_game_ui_contract(t, ui)

    treasure.free()
    hud.free()
    ui.free()

func _assert_treasure_contract(t: SceneTree, treasure: Node) -> void:
    t.assert_true(treasure is Area2D, "treasure root is Area2D")
    t.assert_true(treasure.has_signal("found"), "treasure exposes found signal")
    var sprite := treasure.get_node("AnimatedSprite2D") as AnimatedSprite2D
    t.assert_true(sprite != null, "treasure has an animated sprite")
    if sprite != null:
        t.assert_eq(sprite.sprite_frames.get_frame_count(&"idle"), 3, "treasure animation has three frames")
        for frame_index in range(3):
            t.assert_true(
                sprite.sprite_frames.get_frame_texture(&"idle", frame_index) != null,
                "treasure frame %d has a texture" % frame_index
            )
        t.assert_eq(sprite.autoplay, &"idle", "treasure animation autoplays")
        t.assert_true(sprite.visible, "treasure animation is visible")
    var collision := treasure.get_node("CollisionShape2D") as CollisionShape2D
    t.assert_true(collision != null, "treasure has a collision shape")
    if collision != null:
        var rectangle := collision.shape as RectangleShape2D
        t.assert_true(rectangle != null, "treasure collision is rectangular")
        if rectangle != null:
            t.assert_eq(rectangle.size, Vector2(22, 16), "treasure collision is 22 by 16 pixels")

func _assert_treasure_contact(t: SceneTree, treasure: Node) -> void:
    found_count = 0
    treasure.found.connect(_record_found)
    var non_player := Node2D.new()
    treasure.call("_on_body_entered", non_player)
    t.assert_eq(found_count, 0, "non-player bodies do not find treasure")
    t.assert_true(not treasure.consumed, "non-player contact leaves treasure unconsumed")
    t.assert_true(treasure.monitoring, "non-player contact keeps monitoring enabled")

    var player := _instance(treasure.get_tree(), "res://src/player/player.tscn")
    treasure.call("_on_body_entered", player)
    t.assert_eq(found_count, 1, "first player contact emits found once")
    t.assert_true(treasure.consumed, "first player contact consumes treasure")
    t.assert_true(not treasure.monitoring, "consumed treasure disables monitoring")
    treasure.call("_on_body_entered", player)
    t.assert_eq(found_count, 1, "repeat player contact does not emit found")
    non_player.free()
    player.free()

func _assert_hud_contract(t: SceneTree, hud: Node) -> void:
    t.assert_true(hud.has_method("set_target"), "HUD accepts player and treasure")
    t.assert_eq(hud.mouse_filter, Control.MOUSE_FILTER_IGNORE, "HUD ignores mouse input")
    t.assert_eq(hud.anchor_left, 1.0, "HUD is anchored to the top-right")
    t.assert_eq(hud.anchor_right, 1.0, "HUD is anchored to the top-right")
    var arrow := hud.get_node("Arrow") as TextureRect
    t.assert_true(arrow != null, "HUD has an arrow")
    if arrow != null:
        t.assert_eq(arrow.mouse_filter, Control.MOUSE_FILTER_IGNORE, "arrow ignores mouse input")
        t.assert_eq(arrow.pivot_offset, Vector2(16, 16), "arrow pivots around its center")
        var arrow_texture := arrow.texture as AtlasTexture
        t.assert_true(arrow_texture != null, "arrow uses an atlas texture")
        if arrow_texture != null:
            t.assert_eq(arrow_texture.region, Rect2(0, 0, 32, 32), "arrow uses the 32 by 32 ui region")
    t.assert_true(hud.get_node("DistanceLabel") is Label, "HUD displays a distance label")

func _assert_hud_navigation(t: SceneTree, hud: Node) -> void:
    var player := Node2D.new()
    var treasure := Node2D.new()
    hud.get_tree().root.add_child(player)
    hud.get_tree().root.add_child(treasure)
    player.global_position = Vector2.ZERO

    treasure.global_position = Vector2.ZERO
    hud.set_target(player, treasure)
    t.assert_true(hud.visible, "HUD is visible with valid targets")
    t.assert_approx(hud.get_node("Arrow").rotation, 0.0, 0.0001, "zero vector points right")
    t.assert_eq(hud.get_node("DistanceLabel").text, "距离宝藏 0 米", "zero distance is labeled exactly")

    treasure.global_position = Vector2(16, 0)
    hud.update_now()
    t.assert_approx(hud.get_node("Arrow").rotation, 0.0, 0.0001, "east points right")
    t.assert_eq(hud.get_node("DistanceLabel").text, "距离宝藏 1 米", "one metre is labeled exactly")

    treasure.global_position = Vector2(0, 16)
    hud.update_now()
    t.assert_approx(hud.get_node("Arrow").rotation, PI / 2.0, 0.0001, "south points down")

    treasure.global_position = Vector2(16, 16)
    hud.update_now()
    t.assert_approx(hud.get_node("Arrow").rotation, PI / 4.0, 0.0001, "diagonal points between axes")

    treasure.global_position = Vector2(288, 0)
    hud.update_now()
    t.assert_eq(hud.get_node("DistanceLabel").text, "距离宝藏 18 米", "18 metres is labeled exactly")
    treasure.global_position = Vector2(368, 0)
    hud.update_now()
    t.assert_eq(hud.get_node("DistanceLabel").text, "距离宝藏 23 米", "23 metres is labeled exactly")

    hud.clear_target()
    t.assert_true(not hud.visible, "clearing the target hides the HUD")
    hud.set_target(null, treasure)
    t.assert_true(not hud.visible, "invalid targets hide the HUD")
    player.free()
    treasure.free()

func _assert_game_ui_contract(t: SceneTree, ui: Node) -> void:
    t.assert_true(ui.has_method("show_start"), "UI exposes start state")
    t.assert_true(ui.has_method("play_celebration"), "UI exposes celebration")
    t.assert_eq(ui.mouse_filter, Control.MOUSE_FILTER_IGNORE, "UI ignores mouse input")
    var start_overlay := ui.get_node("StartOverlay") as Control
    var celebration_overlay := ui.get_node("CelebrationOverlay") as Control
    t.assert_eq(start_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "start overlay ignores mouse input")
    t.assert_eq(celebration_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "celebration overlay ignores mouse input")
    t.assert_true(start_overlay.visible, "UI starts on the start overlay")
    t.assert_true(not celebration_overlay.visible, "celebration overlay starts hidden")

    var title := ui.get_node("StartOverlay/StartCard/Title") as Label
    var hint := ui.get_node("StartOverlay/StartCard/StartHint") as Label
    var found := ui.get_node("CelebrationOverlay/CelebrationCard/FoundLabel") as Label
    var reward := ui.get_node("CelebrationOverlay/CelebrationCard/RewardLabel") as Label
    t.assert_eq(title.text, "校园寻宝", "start title uses the required text")
    t.assert_eq(hint.text, "按 WASD 或方向键开始", "start hint uses the required text")
    t.assert_eq(found.text, "找到宝藏！", "celebration title uses the required text")
    t.assert_eq(reward.text, "请领取奖品", "celebration reward uses the required text")
    for label in [title, hint, found, reward]:
        var font := label.get_theme_font("font") as FontFile
        t.assert_true(font != null, "Chinese labels use a bundled font")
        if font != null:
            t.assert_eq(
                font.resource_path,
                "res://assets/fonts/NotoSansCJKsc-Regular.otf",
                "Chinese labels use Noto Sans CJK SC"
            )

    var particles := ui.get_node("CelebrationOverlay/GoldParticles") as GPUParticles2D
    t.assert_true(particles != null, "celebration includes gold particles")
    if particles != null:
        t.assert_true(particles.texture != null, "gold particles use a texture")
        t.assert_true(particles.amount > 0, "gold particles emit visible sparks")
        var particle_texture := particles.texture as AtlasTexture
        t.assert_true(particle_texture != null, "gold particles use a ui atlas region")
        if particle_texture != null:
            t.assert_eq(particle_texture.region, Rect2(32, 0, 32, 32), "gold particles use the ui spark region")

    var timer := ui.get_node("CelebrationTimer") as Timer
    t.assert_approx(timer.wait_time, 4.0, 0.0001, "celebration is exactly four seconds")
    t.assert_true(timer.one_shot, "celebration timer fires once")
    ui.show_start()
    t.assert_true(start_overlay.visible and not celebration_overlay.visible, "show_start makes overlays mutually exclusive")
    ui.play_celebration()
    t.assert_true(not start_overlay.visible and celebration_overlay.visible, "play_celebration makes overlays mutually exclusive")
    t.assert_true(timer.time_left > 3.5, "play_celebration starts a fresh four-second timer")
    celebration_count = 0
    ui.celebration_finished.connect(_record_celebration_finished)
    ui.call("_on_celebration_timeout")
    t.assert_true(not celebration_overlay.visible, "timeout hides celebration overlay")
    t.assert_eq(celebration_count, 1, "timeout emits celebration_finished once")

func _record_found() -> void:
    found_count += 1

func _record_celebration_finished() -> void:
    celebration_count += 1

func _instance(t: SceneTree, path: String) -> Node:
    var packed := load(path) as PackedScene
    t.assert_true(packed != null, "%s loads" % path)
    if packed == null:
        return Node.new()
    var node := packed.instantiate()
    t.root.add_child(node)
    return node

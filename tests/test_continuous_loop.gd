extends RefCounted

const GameFlow = preload("res://src/core/game_flow.gd")
const GameConfig = preload("res://src/config/game_config.gd")

var celebration_events := 0
var search_events := 0

func run(t: SceneTree) -> void:
    var main := _instance(t, "res://src/main/main.tscn")
    _assert_composition(t, main)
    _assert_initial_state(t, main)
    _assert_input_start(t, main)
    _assert_connected_500_rounds(t, main)
    _assert_fatal_overlay(t, main)
    main.free()

func _assert_composition(t: SceneTree, main: Node) -> void:
    t.assert_true(main.has_method("start_game_for_test"), "Main exposes a start test hook")
    t.assert_true(main.has_method("complete_treasure_for_test"), "Main exposes a completion test hook")
    t.assert_true(main.has_method("finish_celebration_for_test"), "Main exposes a finish test hook")
    t.assert_true(main.get_node("GameFlow") is GameFlow, "Main contains GameFlow")
    t.assert_true(main.get_node("World") is Node2D, "Main contains World")
    t.assert_true(main.get_node("TreasureSpawner") is TreasureSpawner, "Main contains TreasureSpawner")
    t.assert_true(main.get_node("Player") is Player, "Main contains Player")
    t.assert_true(main.get_node("UI") is CanvasLayer, "Main contains a UI CanvasLayer")
    t.assert_true(main.get_node("UI/NavigationHUD") is NavigationHUD, "UI contains NavigationHUD")
    t.assert_true(main.get_node("UI/GameUI") is GameUI, "UI contains GameUI")

    var spawner: TreasureSpawner = main.get_node("TreasureSpawner")
    t.assert_true(spawner.treasure_scene != null, "TreasureSpawner has a treasure scene")
    var world: Node2D = main.get_node("World")
    var player: Node2D = main.get_node("Player")
    var ground: CanvasItem = world.get_node("Ground")
    var canopy: CanvasItem = world.get_node("Props/Prop000")
    t.assert_true(player.z_index > ground.z_index, "player renders above ground")
    t.assert_true(player.z_index < canopy.z_index, "player renders below tree canopy")

    var camera: Camera2D = player.get_node("Camera2D")
    var world_rect: Rect2 = world.get_world_rect()
    t.assert_eq(camera.limit_left, roundi(world_rect.position.x), "camera left limit matches world")
    t.assert_eq(camera.limit_top, roundi(world_rect.position.y), "camera top limit matches world")
    t.assert_eq(camera.limit_right, roundi(world_rect.end.x), "camera right limit matches world")
    t.assert_eq(camera.limit_bottom, roundi(world_rect.end.y), "camera bottom limit matches world")

func _assert_initial_state(t: SceneTree, main: Node) -> void:
    var flow: GameFlow = main.get_node("GameFlow")
    var player: Player = main.get_node("Player")
    var world: Node2D = main.get_node("World")
    var ui: GameUI = main.get_node("UI/GameUI")
    var hud: NavigationHUD = main.get_node("UI/NavigationHUD")
    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "game starts waiting for input")
    t.assert_true(not player.movement_enabled, "movement is locked before start")
    t.assert_true(ui.get_node("StartOverlay").visible, "start overlay is visible before start")
    t.assert_true(not ui.get_node("CelebrationOverlay").visible, "celebration overlay starts hidden")
    t.assert_true(is_instance_valid(main.current_treasure), "initial target is spawned")
    t.assert_true(hud.visible, "navigation target is visible before start")
    t.assert_eq(player.global_position, world.get_player_start(), "player is placed at world start exactly once")
    t.assert_true(
        main.current_treasure.global_position.distance_to(player.global_position)
            >= GameConfig.MIN_TREASURE_DISTANCE_METRES * GameConfig.PIXELS_PER_METRE,
        "initial target honors the 288 pixel minimum"
    )

func _assert_input_start(t: SceneTree, main: Node) -> void:
    var flow: GameFlow = main.get_node("GameFlow")
    var player: Player = main.get_node("Player")
    var ui: GameUI = main.get_node("UI/GameUI")

    var other_action := InputEventAction.new()
    other_action.action = "ui_accept"
    other_action.pressed = true
    main.call("_unhandled_input", other_action)
    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "non-movement input does not start game")

    var move_action := InputEventAction.new()
    move_action.action = "move_up"
    move_action.pressed = true
    main.call("_unhandled_input", move_action)
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "movement input starts the game")
    t.assert_true(player.movement_enabled, "movement input enables the player")
    t.assert_true(not ui.get_node("StartOverlay").visible, "movement input hides start overlay")
    t.assert_true(main.get_viewport().is_input_handled(), "movement input is marked handled")

    main.call("_unhandled_input", move_action)
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "repeated movement input does not restart game")

func _assert_connected_500_rounds(t: SceneTree, main: Node) -> void:
    var flow: GameFlow = main.get_node("GameFlow")
    var ui: GameUI = main.get_node("UI/GameUI")
    var hud: NavigationHUD = main.get_node("UI/NavigationHUD")
    var player: Player = main.get_node("Player")
    player.global_position += Vector2(32, 0)
    var start_position := player.global_position
    celebration_events = 0
    search_events = 0
    flow.celebration_started.connect(_record_celebration)
    flow.search_started.connect(_record_search)

    for round_index in range(500):
        var before := player.global_position
        var old_treasure: Area2D = main.current_treasure
        old_treasure.found.emit()
        t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "round %d found signal enters celebration" % round_index)
        t.assert_true(ui.get_node("CelebrationOverlay").visible, "round %d shows celebration" % round_index)
        t.assert_true(not hud.visible, "round %d hides navigation during celebration" % round_index)
        t.assert_true(old_treasure.is_queued_for_deletion(), "round %d queues old treasure" % round_index)
        t.assert_true(not old_treasure.monitoring, "round %d disables old treasure monitoring" % round_index)
        t.assert_true(main.current_treasure != old_treasure, "round %d replaces treasure" % round_index)
        t.assert_true(is_instance_valid(main.current_treasure), "round %d has a valid replacement" % round_index)
        t.assert_true(
            main.current_treasure.global_position.distance_to(player.global_position)
                >= GameConfig.MIN_TREASURE_DISTANCE_METRES * GameConfig.PIXELS_PER_METRE,
            "round %d replacement honors the 288 pixel minimum" % round_index
        )
        old_treasure.found.emit()
        t.assert_eq(celebration_events, round_index + 1, "round %d has one celebration lifecycle" % round_index)

        ui.call("_on_celebration_timeout")
        t.assert_eq(flow.state, GameFlow.State.SEARCHING, "round %d returns to searching" % round_index)
        t.assert_true(not ui.get_node("CelebrationOverlay").visible, "round %d hides celebration after finish" % round_index)
        t.assert_true(hud.visible, "round %d restores navigation after finish" % round_index)
        t.assert_true(player.movement_enabled, "round %d restores movement after finish" % round_index)
        t.assert_eq(player.global_position, before, "round %d preserves player position" % round_index)
        ui.call("_on_celebration_timeout")
        t.assert_eq(search_events, round_index + 1, "round %d has one finish lifecycle" % round_index)

    t.assert_eq(start_position, player.global_position, "500 rounds never teleport player")
    t.assert_eq(celebration_events, 500, "500 found signals produce 500 celebrations")
    t.assert_eq(search_events, 500, "500 finish signals produce 500 searches")

func _assert_fatal_overlay(t: SceneTree, main: Node) -> void:
    var ui: GameUI = main.get_node("UI/GameUI")
    var player: Player = main.get_node("Player")
    var hud: NavigationHUD = main.get_node("UI/NavigationHUD")
    var timer: Timer = ui.get_node("CelebrationTimer")
    main.call("_show_fatal_error", "测试错误")
    t.assert_true(ui.get_node("FatalErrorOverlay").visible, "fatal overlay is visible")
    t.assert_eq(ui.get_node("FatalErrorOverlay/FatalErrorLabel").text, "测试错误", "fatal overlay displays its message")
    t.assert_true(not ui.get_node("StartOverlay").visible, "fatal overlay hides start overlay")
    t.assert_true(not ui.get_node("CelebrationOverlay").visible, "fatal overlay hides celebration overlay")
    t.assert_true(timer.is_stopped(), "fatal overlay stops celebration timer")
    t.assert_true(not player.movement_enabled, "fatal overlay stops player movement")
    t.assert_true(not hud.visible, "fatal overlay hides navigation")

func _record_celebration() -> void:
    celebration_events += 1

func _record_search() -> void:
    search_events += 1

func _instance(t: SceneTree, path: String) -> Node:
    var packed := load(path) as PackedScene
    t.assert_true(packed != null, "%s loads" % path)
    if packed == null:
        return Node.new()
    var node := packed.instantiate()
    t.root.add_child(node)
    return node

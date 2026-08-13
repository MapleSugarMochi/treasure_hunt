extends RefCounted

const GameFlow = preload("res://src/core/game_flow.gd")
const GameConfig = preload("res://src/config/game_config.gd")
const QuizBank = preload("res://src/quiz/quiz_bank.gd")

func run(t: SceneTree) -> void:
    var main := _instance(t, "res://src/main/main.tscn")
    if not main is Main:
        return
    _assert_composition(t, main)
    _assert_initial_state(t, main)
    _assert_input_start(t, main)
    _assert_bounded_loop(t, main)
    _assert_fatal_overlay(t, main)
    main.free()

func _assert_composition(t: SceneTree, main: Node) -> void:
    t.assert_true(main.has_method("start_game_for_test"), "Main exposes a start test hook")
    t.assert_true(main.has_method("complete_treasure_for_test"), "Main exposes a completion test hook")
    t.assert_true(main.has_method("finish_celebration_for_test"), "Main exposes a finish test hook")
    t.assert_true(main.has_method("fail_quiz_for_test"), "Main exposes a fail quiz test hook")
    t.assert_true(main.has_method("restart_for_test"), "Main exposes a restart test hook")
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
    t.assert_eq(main.lives, GameConfig.STARTING_LIVES, "game starts with full lives")
    t.assert_eq(main.quiz_round_index, 0, "question index starts at zero")
    t.assert_true(ui.get_node("StartOverlay").visible, "start overlay is visible before start")
    t.assert_true(not ui.get_node("QuizOverlay").visible, "quiz overlay starts hidden")
    t.assert_true(not ui.get_node("CelebrationOverlay").visible, "celebration overlay starts hidden")
    t.assert_true(not ui.get_node("GameOverOverlay").visible, "game over overlay starts hidden")
    t.assert_true(not ui.get_node("HeartsContainer").visible, "hearts are hidden on the title screen")
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
    t.assert_true(ui.get_node("HeartsContainer").visible, "movement input reveals the hearts indicator")
    t.assert_true(main.get_viewport().is_input_handled(), "movement input is marked handled")

    main.call("_unhandled_input", move_action)
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "repeated movement input does not restart game")

func _assert_bounded_loop(t: SceneTree, main: Node) -> void:
    var flow: GameFlow = main.get_node("GameFlow")
    var ui: GameUI = main.get_node("UI/GameUI")
    var hud: NavigationHUD = main.get_node("UI/NavigationHUD")
    var player: Player = main.get_node("Player")
    var world: CampusWorld = main.get_node("World")
    var home := world.get_player_start()

    const CYCLES := 30
    for cycle in range(CYCLES):
        main.start_game_for_test()
        t.assert_eq(flow.state, GameFlow.State.SEARCHING, "cycle %d starts searching" % cycle)
        t.assert_eq(main.lives, GameConfig.STARTING_LIVES, "cycle %d restores full lives" % cycle)
        t.assert_eq(main.quiz_round_index, 0, "cycle %d resets the question index" % cycle)
        t.assert_true(ui.get_node("HeartsContainer").visible, "cycle %d shows hearts while searching" % cycle)

        for attempt in range(GameConfig.STARTING_LIVES):
            var old_treasure: Area2D = main.current_treasure
            old_treasure.call("_on_body_entered", player)
            t.assert_eq(flow.state, GameFlow.State.QUIZZING, "cycle %d attempt %d enters quiz" % [cycle, attempt])
            t.assert_true(ui.get_node("QuizOverlay").visible, "cycle %d attempt %d shows quiz" % [cycle, attempt])
            t.assert_true(not ui.get_node("CelebrationOverlay").visible, "cycle %d attempt %d does not reward before an answer" % [cycle, attempt])
            t.assert_true(not hud.visible, "cycle %d attempt %d hides navigation during quiz" % [cycle, attempt])
            t.assert_true(not old_treasure.is_queued_for_deletion(), "cycle %d attempt %d keeps treasure until settlement" % [cycle, attempt])
            t.assert_true(not old_treasure.monitoring, "cycle %d attempt %d disables old treasure monitoring" % [cycle, attempt])
            t.assert_true(main.current_treasure == old_treasure, "cycle %d attempt %d does not replace treasure early" % [cycle, attempt])
            t.assert_eq(ui.current_question.prompt, QuizBank.question_for_round(attempt).prompt, "cycle %d attempt %d uses the sequential question" % [cycle, attempt])
            t.assert_eq(main.quiz_round_index, attempt + 1, "cycle %d attempt %d advances question index once" % [cycle, attempt])
            old_treasure.call("_on_body_entered", player)
            t.assert_eq(main.quiz_round_index, attempt + 1, "cycle %d attempt %d ignores duplicate treasure signals" % [cycle, attempt])

            var wrong_indices := _wrong_indices(int(ui.current_question.correct_index))
            ui.answer_buttons[wrong_indices[0]].pressed.emit()
            t.assert_eq(flow.state, GameFlow.State.QUIZZING, "cycle %d attempt %d failure feedback stays in quiz state" % [cycle, attempt])
            t.assert_true(ui.failure_pending, "cycle %d attempt %d starts failure timer" % [cycle, attempt])
            t.assert_true(not ui.get_node("CelebrationOverlay").visible, "cycle %d attempt %d failure never shows reward" % [cycle, attempt])
            t.assert_true(main.current_treasure == old_treasure, "cycle %d attempt %d keeps treasure through failure feedback" % [cycle, attempt])
            t.assert_eq(main.lives, GameConfig.STARTING_LIVES - (attempt + 1), "cycle %d attempt %d depletes life after the wrong click" % [cycle, attempt])

            ui.call("_on_failure_timeout")
            # Duplicate completion callbacks must be no-ops.
            ui.call("_on_failure_timeout")
            ui.call("_on_celebration_timeout")

            if attempt < GameConfig.STARTING_LIVES - 1:
                t.assert_eq(flow.state, GameFlow.State.SEARCHING, "cycle %d attempt %d returns to searching" % [cycle, attempt])
                t.assert_eq(main.lives, GameConfig.STARTING_LIVES - (attempt + 1), "cycle %d attempt %d keeps the depleted life count" % [cycle, attempt])
                t.assert_true(not ui.get_node("QuizOverlay").visible, "cycle %d attempt %d hides quiz after finish" % [cycle, attempt])
                t.assert_true(hud.visible, "cycle %d attempt %d restores navigation after finish" % [cycle, attempt])
                t.assert_true(player.movement_enabled, "cycle %d attempt %d restores movement after finish" % [cycle, attempt])
                t.assert_true(old_treasure.is_queued_for_deletion(), "cycle %d attempt %d queues settled treasure" % [cycle, attempt])
                t.assert_true(main.current_treasure != old_treasure, "cycle %d attempt %d replaces treasure after settlement" % [cycle, attempt])
                t.assert_true(is_instance_valid(main.current_treasure), "cycle %d attempt %d has a valid replacement" % [cycle, attempt])
                t.assert_true(
                    main.current_treasure.global_position.distance_to(player.global_position)
                        >= GameConfig.MIN_TREASURE_DISTANCE_METRES * GameConfig.PIXELS_PER_METRE,
                    "cycle %d attempt %d replacement honors the 288 pixel minimum" % [cycle, attempt]
                )
            else:
                t.assert_eq(flow.state, GameFlow.State.GAME_OVER, "cycle %d final attempt ends in game over" % cycle)
                t.assert_eq(main.lives, 0, "cycle %d final attempt depletes all lives" % cycle)
                t.assert_true(ui.get_node("GameOverOverlay").visible, "cycle %d final attempt shows the game over overlay" % cycle)
                t.assert_true(not ui.get_node("QuizOverlay").visible, "cycle %d final attempt hides quiz" % cycle)
                t.assert_true(not ui.get_node("CelebrationOverlay").visible, "cycle %d final attempt never shows reward" % cycle)
                t.assert_true(main.current_treasure == old_treasure, "cycle %d final attempt keeps the last treasure" % cycle)
                t.assert_true(not old_treasure.is_queued_for_deletion(), "cycle %d final attempt keeps the last treasure alive" % cycle)
                t.assert_true(not player.movement_enabled, "cycle %d final attempt locks movement" % cycle)
                t.assert_true(not ui.get_node("HeartsContainer").visible, "cycle %d final attempt hides hearts" % cycle)
                ui.call("_on_restart_timeout")
                t.assert_eq(flow.state, GameFlow.State.WAITING_START, "cycle %d restart returns to title" % cycle)
                t.assert_true(not ui.get_node("GameOverOverlay").visible, "cycle %d restart hides game over overlay" % cycle)
                t.assert_true(not ui.get_node("HeartsContainer").visible, "cycle %d restart hides hearts on title" % cycle)

            t.assert_eq(player.global_position, home, "cycle %d attempt %d never teleports the player" % [cycle, attempt])

    t.assert_eq(player.global_position, home, "bounded loop never teleports the player across cycles")

func _assert_fatal_overlay(t: SceneTree, main: Node) -> void:
    var ui: GameUI = main.get_node("UI/GameUI")
    var player: Player = main.get_node("Player")
    var hud: NavigationHUD = main.get_node("UI/NavigationHUD")
    var timer: Timer = ui.get_node("CelebrationTimer")
    var failure_timer: Timer = ui.get_node("FailureTimer")
    var restart_timer: Timer = ui.get_node("RestartTimer")
    main.call("_show_fatal_error", "测试错误")
    t.assert_true(ui.get_node("FatalErrorOverlay").visible, "fatal overlay is visible")
    t.assert_eq(ui.get_node("FatalErrorOverlay/FatalErrorLabel").text, "测试错误", "fatal overlay displays its message")
    t.assert_true(not ui.get_node("StartOverlay").visible, "fatal overlay hides start overlay")
    t.assert_true(not ui.get_node("CelebrationOverlay").visible, "fatal overlay hides celebration overlay")
    t.assert_true(not ui.get_node("QuizOverlay").visible, "fatal overlay hides quiz overlay")
    t.assert_true(not ui.get_node("GameOverOverlay").visible, "fatal overlay hides game over overlay")
    t.assert_true(timer.is_stopped(), "fatal overlay stops celebration timer")
    t.assert_true(failure_timer.is_stopped(), "fatal overlay stops failure timer")
    t.assert_true(restart_timer.is_stopped(), "fatal overlay stops restart timer")
    t.assert_true(not player.movement_enabled, "fatal overlay stops player movement")
    t.assert_true(not hud.visible, "fatal overlay hides navigation")

func _wrong_indices(correct_index: int) -> Array[int]:
    var result: Array[int] = []
    for index in range(4):
        if index != correct_index:
            result.append(index)
    return result

func _instance(t: SceneTree, path: String) -> Node:
    var packed := load(path) as PackedScene
    t.assert_true(packed != null, "%s loads" % path)
    if packed == null:
        return Node.new()
    var node := packed.instantiate()
    t.root.add_child(node)
    return node

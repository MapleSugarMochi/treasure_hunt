extends RefCounted

const GameFlow = preload("res://src/core/game_flow.gd")
const GameConfig = preload("res://src/config/game_config.gd")
const QuizBank = preload("res://src/quiz/quiz_bank.gd")

func run(t: SceneTree) -> void:
    var main := _instance(t, "res://src/main/main.tscn")
    if not main is Main:
        return
    var flow: GameFlow = main.get_node("GameFlow")
    var player: Player = main.get_node("Player")
    var hud: NavigationHUD = main.get_node("UI/NavigationHUD")
    var ui: GameUI = main.get_node("UI/GameUI")
    var start_position := player.global_position
    main.start_game_for_test()
    t.assert_eq(main.lives, GameConfig.STARTING_LIVES, "run starts with full lives")

    # Round 1: wrong answer depletes one life and continues the run.
    var first_treasure: Area2D = main.current_treasure
    first_treasure.call("_on_body_entered", player)
    t.assert_eq(flow.state, GameFlow.State.QUIZZING, "first treasure contact enters quiz state")
    t.assert_true(not player.movement_enabled, "quiz contact locks movement")
    t.assert_true(not hud.visible, "quiz contact hides navigation")
    t.assert_true(ui.get_node("QuizOverlay").visible, "quiz contact opens quiz panel")
    t.assert_true(main.current_treasure == first_treasure, "quiz contact does not replace treasure early")
    t.assert_eq(ui.current_question.prompt, QuizBank.question_for_round(0).prompt, "first treasure uses question one")
    t.assert_eq(main.quiz_round_index, 1, "question index advances once at contact")

    var wrong_indices := _wrong_indices(int(ui.current_question.correct_index))
    ui.answer_buttons[wrong_indices[0]].pressed.emit()
    t.assert_eq(flow.state, GameFlow.State.QUIZZING, "first wrong answer stays in quiz during feedback")
    t.assert_true(ui.failure_pending, "first wrong answer starts delayed failure")
    t.assert_eq(main.lives, GameConfig.STARTING_LIVES - 1, "wrong click depletes one life immediately")
    var second_heart := ui.get_node("HeartsContainer/Heart2") as TextureRect
    var second_heart_texture := second_heart.texture as AtlasTexture
    t.assert_eq(second_heart_texture.region, Rect2(80, 0, 16, 16), "wrong click empties one heart immediately")
    t.assert_true(main.current_treasure == first_treasure, "failure feedback does not replace treasure early")
    ui.call("_on_failure_timeout")
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "first wrong answer returns to search")
    t.assert_eq(main.lives, GameConfig.STARTING_LIVES - 1, "first wrong answer depletes one life")
    var second_treasure: Area2D = main.current_treasure
    t.assert_true(second_treasure != first_treasure, "first wrong answer replaces treasure once")
    t.assert_true(player.movement_enabled and hud.visible, "search resumes after no-award result")
    t.assert_eq(player.global_position, start_position, "wrong answer path preserves player position")

    # Round 2: correct answer ends the run in a win (no next treasure).
    second_treasure.call("_on_body_entered", player)
    t.assert_eq(ui.current_question.prompt, QuizBank.question_for_round(1).prompt, "second treasure uses question two")
    var correct_index := int(ui.current_question.correct_index)
    ui.answer_buttons[correct_index].pressed.emit()
    t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "correct answer enters celebration")
    t.assert_true(ui.get_node("CelebrationOverlay").visible, "correct answer shows reward")
    t.assert_true(main.current_treasure == second_treasure, "reward keeps old treasure until celebration ends")
    ui.call("_on_celebration_timeout")
    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "celebration completion returns to title for the next player")
    t.assert_true(main.current_treasure != second_treasure, "next player's title state has a fresh first treasure")
    t.assert_true(not player.movement_enabled, "title locks movement for the next player")
    t.assert_eq(main.lives, GameConfig.STARTING_LIVES, "next player starts with full lives")
    t.assert_eq(main.quiz_round_index, 0, "next player starts from question one")
    t.assert_eq(player.global_position, start_position, "next player starts at the start position")
    t.assert_true(ui.get_node("StartOverlay").visible, "next player sees the title overlay")

    # Duplicate completion cannot advance the next player's title state.
    ui.call("_on_celebration_timeout")
    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "duplicate celebration timeout cannot start the next run")
    main.call("_finish_round")
    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "finish_round cannot leave the title state")

    # A brand-new run uses question one again.
    main.start_game_for_test()
    main.current_treasure.call("_on_body_entered", player)
    t.assert_eq(ui.current_question.prompt, QuizBank.question_for_round(0).prompt, "restarted run uses question one again")
    t.assert_eq(main.quiz_round_index, 1, "restarted run advances the question index once")
    main.free()

    # Separate scenario: three consecutive wrong answers reach game over and restart.
    _assert_game_over_scenario(t)

func _assert_game_over_scenario(t: SceneTree) -> void:
    var main := _instance(t, "res://src/main/main.tscn")
    if not main is Main:
        return
    var flow: GameFlow = main.get_node("GameFlow")
    var player: Player = main.get_node("Player")
    var ui: GameUI = main.get_node("UI/GameUI")
    var start_position := player.global_position
    main.start_game_for_test()

    for attempt in range(GameConfig.STARTING_LIVES):
        var previous_lives: int = main.lives
        main.current_treasure.call("_on_body_entered", player)
        var wrong := _wrong_indices(int(ui.current_question.correct_index))
        ui.answer_buttons[wrong[0]].pressed.emit()
        t.assert_eq(main.lives, previous_lives - 1, "wrong click %d depletes one life immediately" % attempt)
        ui.call("_on_failure_timeout")
        if attempt < GameConfig.STARTING_LIVES - 1:
            t.assert_eq(flow.state, GameFlow.State.SEARCHING, "wrong answer %d keeps the run alive" % attempt)
            t.assert_eq(main.lives, previous_lives - 1, "wrong answer %d depletes one life" % attempt)
        else:
            t.assert_eq(flow.state, GameFlow.State.GAME_OVER, "final wrong answer ends the run in game over")
            t.assert_eq(main.lives, 0, "final wrong answer depletes the last life")
            t.assert_true(ui.get_node("GameOverOverlay").visible, "game over shows the game over overlay")
            t.assert_true(ui.get_node("RestartTimer").time_left > 0.0, "game over starts the restart timer")

    t.assert_true(main.current_treasure != null, "game over keeps the last treasure without spawning a new one")
    t.assert_eq(player.global_position, start_position, "game over path preserves player position")

    ui.call("_on_restart_timeout")
    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "restart timeout returns to the title state")
    t.assert_eq(main.lives, GameConfig.STARTING_LIVES, "restart restores full lives after game over")
    t.assert_true(not ui.get_node("GameOverOverlay").visible, "restart hides the game over overlay")
    main.free()

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

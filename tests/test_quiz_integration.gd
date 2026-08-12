extends RefCounted

const GameFlow = preload("res://src/core/game_flow.gd")
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

    var first_treasure: Area2D = main.current_treasure
    first_treasure.call("_on_body_entered", player)
    t.assert_eq(flow.state, GameFlow.State.QUIZZING, "treasure contact enters quiz state")
    t.assert_true(not player.movement_enabled, "quiz contact locks movement")
    t.assert_true(not hud.visible, "quiz contact hides navigation")
    t.assert_true(ui.get_node("QuizOverlay").visible, "quiz contact opens quiz panel")
    t.assert_true(main.current_treasure == first_treasure, "quiz contact does not replace treasure early")
    t.assert_true(not first_treasure.is_queued_for_deletion(), "old treasure remains until settlement")
    if not ui.get_node("QuizOverlay").visible or ui.current_question.is_empty():
        main.free()
        return
    t.assert_eq(ui.current_question.prompt, QuizBank.question_for_round(0).prompt, "first treasure uses question one")
    t.assert_eq(main.quiz_round_index, 1, "question index advances once at contact")

    var correct_index := int(ui.current_question.correct_index)
    ui.answer_buttons[correct_index].pressed.emit()
    t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "correct answer enters celebration")
    t.assert_true(ui.get_node("CelebrationOverlay").visible, "correct answer shows reward")
    t.assert_true(main.current_treasure == first_treasure, "reward keeps old treasure until celebration ends")
    ui.call("_on_celebration_timeout")
    var second_treasure: Area2D = main.current_treasure
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "celebration completion returns to search")
    t.assert_true(second_treasure != first_treasure, "celebration completion replaces treasure once")
    t.assert_true(first_treasure.is_queued_for_deletion(), "settled treasure is queued for deletion")
    t.assert_true(player.movement_enabled and hud.visible, "search resumes after reward")
    t.assert_eq(player.global_position, start_position, "reward path preserves player position")

    second_treasure.call("_on_body_entered", player)
    t.assert_eq(ui.current_question.prompt, QuizBank.question_for_round(1).prompt, "second treasure uses question two")
    var wrong_indices := _wrong_indices(int(ui.current_question.correct_index))
    ui.answer_buttons[wrong_indices[0]].pressed.emit()
    ui.answer_buttons[wrong_indices[1]].pressed.emit()
    t.assert_eq(flow.state, GameFlow.State.QUIZZING, "final wrong answer remains in quiz during feedback")
    t.assert_true(ui.failure_pending, "final wrong answer starts delayed failure")
    t.assert_true(main.current_treasure == second_treasure, "failure feedback does not replace treasure early")
    t.assert_true(not ui.get_node("CelebrationOverlay").visible, "failure never shows reward celebration")
    ui.call("_on_failure_timeout")
    var third_treasure: Area2D = main.current_treasure
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "failure timeout returns to search")
    t.assert_true(third_treasure != second_treasure, "failure timeout replaces treasure once")
    t.assert_true(player.movement_enabled and hud.visible, "search resumes after no-award result")
    t.assert_eq(player.global_position, start_position, "failure path preserves player position")
    t.assert_eq(main.quiz_round_index, 2, "success and failure each advance one question")

    ui.call("_on_failure_timeout")
    ui.call("_on_celebration_timeout")
    t.assert_true(main.current_treasure == third_treasure, "duplicate completion callbacks cannot replace another treasure")
    t.assert_eq(main.quiz_round_index, 2, "duplicate completion callbacks cannot advance question index")
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

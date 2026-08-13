extends RefCounted

var correct_events := 0
var incorrect_events := 0
var failed_events := 0
var restart_events := 0

func run(t: SceneTree) -> void:
    var ui := _instance(t, "res://src/ui/game_ui.tscn") as GameUI
    if not ui is GameUI:
        return
    var quiz_overlay := ui.get_node_or_null("QuizOverlay") as Control
    var quiz_card := ui.get_node("QuizOverlay/QuizCard") as Panel
    var quiz_title := ui.get_node("QuizOverlay/QuizCard/QuizTitle") as Label
    var question_label := ui.get_node_or_null("QuizOverlay/QuizCard/QuestionLabel") as Label
    var feedback_label := ui.get_node_or_null("QuizOverlay/QuizCard/FeedbackLabel") as Label
    var badges: Array[Label] = [
        ui.get_node("QuizOverlay/QuizCard/AnswerA/Badge") as Label,
        ui.get_node("QuizOverlay/QuizCard/AnswerB/Badge") as Label,
        ui.get_node("QuizOverlay/QuizCard/AnswerC/Badge") as Label,
        ui.get_node("QuizOverlay/QuizCard/AnswerD/Badge") as Label,
    ]
    var buttons: Array[Button] = [
        ui.get_node_or_null("QuizOverlay/QuizCard/AnswerA") as Button,
        ui.get_node_or_null("QuizOverlay/QuizCard/AnswerB") as Button,
        ui.get_node_or_null("QuizOverlay/QuizCard/AnswerC") as Button,
        ui.get_node_or_null("QuizOverlay/QuizCard/AnswerD") as Button,
    ]
    var failure_timer := ui.get_node_or_null("FailureTimer") as Timer
    var restart_timer := ui.get_node_or_null("RestartTimer") as Timer
    var game_over_overlay := ui.get_node_or_null("GameOverOverlay") as Control
    var hearts_container := ui.get_node_or_null("HeartsContainer") as Control

    t.assert_true(quiz_overlay != null, "quiz overlay exists")
    t.assert_true(quiz_card != null, "quiz card exists")
    t.assert_true(quiz_title != null, "quiz title exists")
    t.assert_true(question_label != null and feedback_label != null, "quiz text labels exist")
    t.assert_true(buttons.all(func(button: Button) -> bool: return button != null), "quiz has four answer buttons")
    t.assert_true(badges.all(func(badge: Label) -> bool: return badge != null), "quiz answer badges exist")
    t.assert_true(failure_timer != null, "quiz has a failure feedback timer")
    t.assert_true(restart_timer != null, "UI has a restart timer")
    t.assert_true(game_over_overlay != null, "UI has a game over overlay")
    t.assert_true(hearts_container != null, "UI has a hearts container")
    if quiz_overlay == null or question_label == null or feedback_label == null or failure_timer == null:
        ui.free()
        return
    if restart_timer == null or game_over_overlay == null or hearts_container == null:
        ui.free()
        return
    for button in buttons:
        if button == null:
            ui.free()
            return

    t.assert_eq(quiz_card.position, Vector2(28, 20), "quiz card keeps a relaxed outer margin")
    t.assert_eq(quiz_card.size, Vector2(584, 320), "quiz card uses the wide approved footprint")
    t.assert_eq(quiz_title.get_theme_font_size("font_size"), 18, "quiz title uses the smaller display size")
    t.assert_eq(question_label.get_theme_font_size("font_size"), 15, "question uses the smaller readable size")
    t.assert_eq(feedback_label.get_theme_font_size("font_size"), 12, "feedback fits the compact header")
    t.assert_eq(buttons[0].position.y, buttons[1].position.y, "A and B share the first row")
    t.assert_eq(buttons[2].position.y, buttons[3].position.y, "C and D share the second row")
    t.assert_true(buttons[0].position.x < buttons[1].position.x, "B sits to the right of A")
    t.assert_true(buttons[2].position.x < buttons[3].position.x, "D sits to the right of C")
    t.assert_true(buttons.all(func(button: Button) -> bool: return button.size == Vector2(258, 68)), "answer cards share the approved size")
    t.assert_true(buttons.all(func(button: Button) -> bool: return button.autowrap_mode != TextServer.AUTOWRAP_OFF), "answer text wraps inside two-column cards")
    t.assert_eq(badges.map(func(badge: Label) -> String: return badge.text), ["A", "B", "C", "D"], "answer cards expose separate letter badges")

    t.assert_true(not quiz_overlay.visible, "quiz starts hidden")
    t.assert_eq(quiz_overlay.mouse_filter, Control.MOUSE_FILTER_STOP, "quiz overlay captures mouse input")
    t.assert_true(not ui.has_method("_unhandled_input"), "quiz UI has no keyboard-answer handler")
    t.assert_approx(failure_timer.wait_time, 2.0, 0.0001, "failure feedback lasts two seconds")
    t.assert_true(failure_timer.one_shot, "failure timer fires once")
    t.assert_approx(restart_timer.wait_time, 3.0, 0.0001, "restart delay is three seconds")
    t.assert_true(restart_timer.one_shot, "restart timer fires once")
    for button in buttons:
        t.assert_eq(button.focus_mode, Control.FOCUS_NONE, "answer buttons cannot be activated by keyboard focus")

    ui.restart_requested.connect(_record_restart)
    _assert_hearts(t, ui, hearts_container)
    _assert_game_over(t, ui, game_over_overlay, restart_timer)

    correct_events = 0
    incorrect_events = 0
    failed_events = 0
    restart_events = 0
    ui.quiz_answered_correctly.connect(_record_correct)
    ui.quiz_answered_incorrectly.connect(_record_incorrect)
    ui.quiz_failed.connect(_record_failed)
    var question := {
        "prompt": "测试题目？",
        "options": ["错误选项", "正确选项", "另一个错误选项", "搞笑错误选项"],
        "correct_index": 1,
    }
    ui.show_quiz(question)
    t.assert_true(quiz_overlay.visible, "show_quiz opens quiz")
    t.assert_eq(question_label.text, "测试题目？", "quiz renders prompt")
    t.assert_eq(feedback_label.text, "请选择一个答案（仅 1 次机会）", "quiz explains the single attempt")
    t.assert_eq(buttons[0].text, "错误选项", "first option renders visible text without a letter prefix")
    t.assert_eq(buttons[3].text, "搞笑错误选项", "fourth option renders visible text without a letter prefix")
    buttons[1].pressed.emit()
    t.assert_eq(correct_events, 1, "correct answer emits award once")
    t.assert_true(ui.quiz_settled, "correct answer settles quiz")
    t.assert_eq(feedback_label.text, "回答正确！", "correct answer shows success feedback")
    for button in buttons:
        t.assert_true(button.disabled, "correct answer disables every option")
    buttons[1].pressed.emit()
    t.assert_eq(correct_events, 1, "settled quiz ignores repeat clicks")

    ui.play_celebration()
    t.assert_true(not quiz_overlay.visible, "celebration hides quiz")
    t.assert_true(ui.get_node("CelebrationOverlay").visible, "correct answer opens reward celebration")
    t.assert_eq(ui.get_node("CelebrationOverlay/CelebrationCard/RewardLabel").text, "回答正确，请领取奖品", "reward copy requires a correct answer")
    ui.call("_on_celebration_timeout")

    ui.show_quiz(question)
    for button in buttons:
        t.assert_true(not button.disabled, "next quiz re-enables every option")
    ui.call("_on_answer_pressed", 99)
    t.assert_true(not ui.quiz_settled, "invalid option index is ignored")
    buttons[0].pressed.emit()
    t.assert_true(ui.quiz_settled, "first wrong answer settles quiz")
    t.assert_true(ui.failure_pending, "first wrong answer starts pending failure")
    t.assert_eq(feedback_label.text, "挑战失败，本轮无奖", "first wrong answer shows no-award message")
    t.assert_true(failure_timer.time_left > 1.5, "first wrong answer starts fresh failure timer")
    t.assert_eq(incorrect_events, 1, "first wrong answer emits immediate life-loss event once")
    var wrong_style := buttons[0].get_theme_stylebox("disabled") as StyleBoxFlat
    t.assert_true(wrong_style != null and wrong_style.bg_color == Color("9e3945"), "selected wrong answer is red")
    t.assert_eq(failed_events, 0, "failure emits only after feedback delay")
    for button in buttons:
        t.assert_true(button.disabled, "first wrong answer disables every option")
    buttons[1].pressed.emit()
    buttons[2].pressed.emit()
    t.assert_eq(correct_events, 1, "settled failure ignores later correct clicks")
    t.assert_eq(incorrect_events, 1, "settled failure ignores repeated wrong clicks")
    t.assert_eq(failed_events, 0, "settled failure ignores repeated answer clicks")

    ui.call("_on_failure_timeout")
    t.assert_true(not quiz_overlay.visible, "failure timeout hides quiz")
    t.assert_eq(failed_events, 1, "failure timeout emits once")
    ui.call("_on_failure_timeout")
    t.assert_eq(failed_events, 1, "duplicate failure timeout is ignored")

    ui.show_fatal_error("测试致命错误")
    ui.show_start()
    t.assert_true(ui.get_node("StartOverlay").visible, "show_start restores only the start overlay")
    t.assert_true(not ui.get_node("FatalErrorOverlay").visible, "show_start hides a previous fatal overlay")
    ui.show_fatal_error("测试致命错误")
    ui.play_celebration()
    t.assert_true(ui.get_node("CelebrationOverlay").visible, "play_celebration restores only the reward overlay")
    t.assert_true(not ui.get_node("FatalErrorOverlay").visible, "play_celebration hides a previous fatal overlay")

    ui.show_quiz({
        "prompt": "无效题目",
        "options": ["有效选项", "", "有效选项", "有效选项"],
        "correct_index": 0,
    })
    t.assert_true(ui.get_node("FatalErrorOverlay").visible, "empty option shows the fatal error overlay")
    t.assert_true(not quiz_overlay.visible, "invalid options never open the quiz")
    ui.free()

func _assert_hearts(t: SceneTree, ui: GameUI, hearts_container: Control) -> void:
    var hearts: Array[TextureRect] = [
        ui.get_node_or_null("HeartsContainer/Heart0") as TextureRect,
        ui.get_node_or_null("HeartsContainer/Heart1") as TextureRect,
        ui.get_node_or_null("HeartsContainer/Heart2") as TextureRect,
    ]
    t.assert_true(hearts.all(func(h: TextureRect) -> bool: return h != null), "three heart slots exist")
    if hearts.any(func(h: TextureRect) -> bool: return h == null):
        return
    t.assert_true(not hearts_container.visible, "hearts start hidden on the title overlay")

    ui.set_hearts_visible(true)
    ui.set_lives(3)
    t.assert_true(hearts_container.visible, "set_hearts_visible reveals the hearts container")
    for h in hearts:
        _assert_heart_texture(t, h.texture, "res://assets/generated/heart-full.png", "full life heart uses the supplied red heart")

    ui.set_lives(1)
    _assert_heart_texture(t, hearts[0].texture, "res://assets/generated/heart-full.png", "first heart stays red at one life")
    for index in range(1, hearts.size()):
        _assert_heart_texture(t, hearts[index].texture, "res://assets/generated/heart-empty.png", "heart %d becomes dimmed grey at one life" % index)

    ui.set_lives(0)
    for index in range(hearts.size()):
        _assert_heart_texture(t, hearts[index].texture, "res://assets/generated/heart-empty.png", "heart %d is dimmed grey at zero lives" % index)

    ui.show_start()
    t.assert_true(not hearts_container.visible, "show_start hides hearts")
    ui.show_game_over()
    t.assert_true(not hearts_container.visible, "show_game_over hides hearts")
    ui.set_hearts_visible(true)
    ui.show_fatal_error("测试错误")
    t.assert_true(not hearts_container.visible, "show_fatal_error hides hearts")


func _assert_heart_texture(t: SceneTree, texture: Texture2D, expected_path: String, message: String) -> void:
    t.assert_true(texture != null, message)
    if texture != null:
        t.assert_eq(texture.resource_path, expected_path, message)
        t.assert_eq(texture.get_size(), Vector2(16, 16), "heart textures fit the existing 16px slots")

func _assert_game_over(t: SceneTree, ui: GameUI, game_over_overlay: Control, restart_timer: Timer) -> void:
    t.assert_true(not game_over_overlay.visible, "game over overlay starts hidden")
    ui.show_game_over()
    t.assert_true(game_over_overlay.visible, "show_game_over reveals the game over overlay")
    t.assert_true(not ui.get_node("StartOverlay").visible, "show_game_over hides the start overlay")
    t.assert_true(not ui.get_node("QuizOverlay").visible, "show_game_over hides the quiz overlay")
    t.assert_true(not ui.get_node("CelebrationOverlay").visible, "show_game_over hides the celebration overlay")
    t.assert_true(not ui.get_node("FatalErrorOverlay").visible, "show_game_over hides the fatal overlay")
    t.assert_true(restart_timer.time_left > 2.5, "show_game_over starts the restart timer")

    restart_events = 0
    ui.call("_on_restart_timeout")
    t.assert_eq(restart_events, 1, "restart timeout emits restart_requested once")
    t.assert_true(not game_over_overlay.visible, "restart timeout hides the game over overlay")
    ui.call("_on_restart_timeout")
    t.assert_eq(restart_events, 1, "duplicate restart timeout is ignored after the overlay closes")

func _record_correct() -> void:
    correct_events += 1

func _record_incorrect() -> void:
    incorrect_events += 1

func _record_failed() -> void:
    failed_events += 1

func _record_restart() -> void:
    restart_events += 1

func _instance(t: SceneTree, path: String) -> Node:
    var packed := load(path) as PackedScene
    t.assert_true(packed != null, "%s loads" % path)
    if packed == null:
        return Node.new()
    var node := packed.instantiate()
    t.root.add_child(node)
    return node

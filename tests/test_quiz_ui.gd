extends RefCounted

var correct_events := 0
var failed_events := 0

func run(t: SceneTree) -> void:
    var ui := _instance(t, "res://src/ui/game_ui.tscn") as GameUI
    if not ui is GameUI:
        return
    var quiz_overlay := ui.get_node_or_null("QuizOverlay") as Control
    var question_label := ui.get_node_or_null("QuizOverlay/QuizCard/QuestionLabel") as Label
    var feedback_label := ui.get_node_or_null("QuizOverlay/QuizCard/FeedbackLabel") as Label
    var buttons: Array[Button] = [
        ui.get_node_or_null("QuizOverlay/QuizCard/AnswerA") as Button,
        ui.get_node_or_null("QuizOverlay/QuizCard/AnswerB") as Button,
        ui.get_node_or_null("QuizOverlay/QuizCard/AnswerC") as Button,
        ui.get_node_or_null("QuizOverlay/QuizCard/AnswerD") as Button,
    ]
    var failure_timer := ui.get_node_or_null("FailureTimer") as Timer

    t.assert_true(quiz_overlay != null, "quiz overlay exists")
    t.assert_true(question_label != null and feedback_label != null, "quiz text labels exist")
    t.assert_true(buttons.all(func(button: Button) -> bool: return button != null), "quiz has four answer buttons")
    t.assert_true(failure_timer != null, "quiz has a failure feedback timer")
    if quiz_overlay == null or question_label == null or feedback_label == null or failure_timer == null:
        ui.free()
        return
    for button in buttons:
        if button == null:
            ui.free()
            return

    t.assert_true(not quiz_overlay.visible, "quiz starts hidden")
    t.assert_eq(quiz_overlay.mouse_filter, Control.MOUSE_FILTER_STOP, "quiz overlay captures mouse input")
    t.assert_true(not ui.has_method("_unhandled_input"), "quiz UI has no keyboard-answer handler")
    t.assert_approx(failure_timer.wait_time, 2.0, 0.0001, "failure feedback lasts two seconds")
    t.assert_true(failure_timer.one_shot, "failure timer fires once")
    for button in buttons:
        t.assert_eq(button.focus_mode, Control.FOCUS_NONE, "answer buttons cannot be activated by keyboard focus")

    correct_events = 0
    failed_events = 0
    ui.quiz_answered_correctly.connect(_record_correct)
    ui.quiz_failed.connect(_record_failed)
    var question := {
        "prompt": "测试题目？",
        "options": ["错误选项", "正确选项", "另一个错误选项", "搞笑错误选项"],
        "correct_index": 1,
    }
    ui.show_quiz(question)
    t.assert_true(quiz_overlay.visible, "show_quiz opens quiz")
    t.assert_eq(question_label.text, "测试题目？", "quiz renders prompt")
    t.assert_eq(feedback_label.text, "请选择一个答案（共 2 次机会）", "quiz explains attempt count")
    t.assert_eq(buttons[0].text, "A. 错误选项", "first option has A prefix")
    t.assert_eq(buttons[3].text, "D. 搞笑错误选项", "fourth option has D prefix")
    t.assert_eq(ui.attempts_used, 0, "new quiz starts with no attempts")

    buttons[0].pressed.emit()
    t.assert_eq(ui.attempts_used, 1, "first wrong click consumes one attempt")
    t.assert_eq(feedback_label.text, "回答错误，还剩 1 次机会", "first wrong click shows remaining chance")
    t.assert_true(buttons[0].disabled, "first wrong choice is disabled")
    t.assert_true(not buttons[1].disabled and not buttons[2].disabled and not buttons[3].disabled, "other choices remain available")
    t.assert_eq(correct_events, 0, "wrong answer does not award")
    t.assert_eq(failed_events, 0, "first wrong answer does not fail")

    buttons[0].pressed.emit()
    t.assert_eq(ui.attempts_used, 1, "disabled answer cannot consume another attempt")
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
    t.assert_eq(ui.attempts_used, 0, "next quiz resets attempts")
    for button in buttons:
        t.assert_true(not button.disabled, "next quiz re-enables every option")
    ui.call("_on_answer_pressed", 99)
    t.assert_eq(ui.attempts_used, 0, "invalid option index is ignored")
    buttons[0].pressed.emit()
    buttons[2].pressed.emit()
    t.assert_true(ui.quiz_settled, "second wrong answer settles quiz")
    t.assert_eq(ui.attempts_used, 2, "two wrong clicks use both attempts")
    t.assert_eq(feedback_label.text, "挑战失败，本轮无奖", "second wrong answer shows no-award message")
    t.assert_true(failure_timer.time_left > 1.5, "second wrong answer starts fresh failure timer")
    t.assert_eq(failed_events, 0, "failure emits only after feedback delay")
    for button in buttons:
        t.assert_true(button.disabled, "final failure disables every option")

    ui.call("_on_failure_timeout")
    t.assert_true(not quiz_overlay.visible, "failure timeout hides quiz")
    t.assert_eq(failed_events, 1, "failure timeout emits once")
    ui.call("_on_failure_timeout")
    t.assert_eq(failed_events, 1, "duplicate failure timeout is ignored")
    ui.free()

func _record_correct() -> void:
    correct_events += 1

func _record_failed() -> void:
    failed_events += 1

func _instance(t: SceneTree, path: String) -> Node:
    var packed := load(path) as PackedScene
    t.assert_true(packed != null, "%s loads" % path)
    if packed == null:
        return Node.new()
    var node := packed.instantiate()
    t.root.add_child(node)
    return node

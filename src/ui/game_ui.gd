class_name GameUI
extends Control

signal celebration_finished
signal quiz_answered_correctly
signal quiz_failed

const ANSWER_PREFIXES := ["A", "B", "C", "D"]
const DEFAULT_DISABLED_COLOR := Color("526174")
const WRONG_COLOR := Color("9e3945")
const CORRECT_COLOR := Color("2f7d55")
const DEFAULT_BORDER_COLOR := Color("73839a")
const WRONG_BORDER_COLOR := Color("f07b82")
const CORRECT_BORDER_COLOR := Color("7bdca5")

@onready var start_overlay: Control = %StartOverlay
@onready var quiz_overlay: Control = %QuizOverlay
@onready var question_label: Label = %QuestionLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var celebration_overlay: Control = %CelebrationOverlay
@onready var fatal_error_overlay: Control = %FatalErrorOverlay
@onready var celebration_timer: Timer = $CelebrationTimer
@onready var failure_timer: Timer = $FailureTimer
@onready var answer_buttons: Array[Button] = [%AnswerA, %AnswerB, %AnswerC, %AnswerD]

var current_question: Dictionary = {}
var attempts_used := 0
var quiz_settled := false
var failure_pending := false

func _ready() -> void:
    celebration_timer.timeout.connect(_on_celebration_timeout)
    failure_timer.timeout.connect(_on_failure_timeout)
    for index in range(answer_buttons.size()):
        answer_buttons[index].pressed.connect(_on_answer_pressed.bind(index))
    show_start()

func show_start() -> void:
    celebration_timer.stop()
    failure_timer.stop()
    failure_pending = false
    start_overlay.visible = true
    quiz_overlay.visible = false
    celebration_overlay.visible = false
    fatal_error_overlay.visible = false

func hide_start() -> void:
    start_overlay.visible = false

func show_quiz(question: Dictionary) -> void:
    if not _is_valid_question(question):
        show_fatal_error("题目数据无效")
        return
    celebration_timer.stop()
    failure_timer.stop()
    failure_pending = false
    current_question = question.duplicate(true)
    attempts_used = 0
    quiz_settled = false
    question_label.text = current_question.prompt
    feedback_label.text = "请选择一个答案（共 2 次机会）"
    feedback_label.add_theme_color_override("font_color", Color("dbe8f5"))
    for index in range(answer_buttons.size()):
        var button := answer_buttons[index]
        button.text = "%s. %s" % [ANSWER_PREFIXES[index], current_question.options[index]]
        button.disabled = false
        _set_disabled_style(button, DEFAULT_DISABLED_COLOR, DEFAULT_BORDER_COLOR)
    start_overlay.visible = false
    celebration_overlay.visible = false
    fatal_error_overlay.visible = false
    quiz_overlay.visible = true

func _on_answer_pressed(option_index: int) -> void:
    if not quiz_overlay.visible or quiz_settled:
        return
    if option_index < 0 or option_index >= answer_buttons.size():
        return
    var selected := answer_buttons[option_index]
    if selected.disabled:
        return

    attempts_used += 1
    if option_index == int(current_question.correct_index):
        quiz_settled = true
        feedback_label.text = "回答正确！"
        feedback_label.add_theme_color_override("font_color", CORRECT_BORDER_COLOR)
        _disable_all_answers()
        _set_disabled_style(selected, CORRECT_COLOR, CORRECT_BORDER_COLOR)
        quiz_answered_correctly.emit()
        return

    selected.disabled = true
    _set_disabled_style(selected, WRONG_COLOR, WRONG_BORDER_COLOR)
    if attempts_used < 2:
        feedback_label.text = "回答错误，还剩 1 次机会"
        feedback_label.add_theme_color_override("font_color", WRONG_BORDER_COLOR)
        return

    quiz_settled = true
    failure_pending = true
    feedback_label.text = "挑战失败，本轮无奖"
    feedback_label.add_theme_color_override("font_color", WRONG_BORDER_COLOR)
    _disable_all_answers()
    failure_timer.start()

func play_celebration() -> void:
    failure_timer.stop()
    failure_pending = false
    start_overlay.visible = false
    quiz_overlay.visible = false
    celebration_overlay.visible = true
    fatal_error_overlay.visible = false
    celebration_timer.start()

func _on_celebration_timeout() -> void:
    if not celebration_overlay.visible:
        return
    celebration_overlay.visible = false
    celebration_finished.emit()

func _on_failure_timeout() -> void:
    if not failure_pending:
        return
    failure_pending = false
    failure_timer.stop()
    quiz_overlay.visible = false
    quiz_failed.emit()

func show_fatal_error(message: String) -> void:
    celebration_timer.stop()
    failure_timer.stop()
    failure_pending = false
    start_overlay.visible = false
    quiz_overlay.visible = false
    celebration_overlay.visible = false
    %FatalErrorLabel.text = message
    fatal_error_overlay.visible = true

func _disable_all_answers() -> void:
    for button in answer_buttons:
        button.disabled = true

func _set_disabled_style(button: Button, background: Color, border: Color) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_right = 6
    style.corner_radius_bottom_left = 6
    button.add_theme_stylebox_override("disabled", style)
    button.add_theme_color_override("font_disabled_color", Color("ffffff"))

func _is_valid_question(question: Dictionary) -> bool:
    if not question.has("prompt") or not question.prompt is String or question.prompt.is_empty():
        return false
    if not question.has("options") or not question.options is Array or question.options.size() != 4:
        return false
    for option in question.options:
        if not option is String or option.is_empty():
            return false
    if not question.has("correct_index") or not question.correct_index is int:
        return false
    return question.correct_index >= 0 and question.correct_index < question.options.size()

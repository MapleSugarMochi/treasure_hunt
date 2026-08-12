class_name Main
extends Node

const GameConfig = preload("res://src/config/game_config.gd")
const QuizBank = preload("res://src/quiz/quiz_bank.gd")

@onready var flow: GameFlow = $GameFlow
@onready var world: Node2D = $World
@onready var spawner: TreasureSpawner = $TreasureSpawner
@onready var player: Player = $Player
@onready var navigation_hud: NavigationHUD = $UI/NavigationHUD
@onready var game_ui: GameUI = $UI/GameUI

var current_treasure: Area2D
var quiz_round_index := 0

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        get_tree().paused = true
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        get_tree().paused = false

func _ready() -> void:
    flow.state_changed.connect(_on_state_changed)
    game_ui.quiz_answered_correctly.connect(_on_quiz_answered_correctly)
    game_ui.quiz_failed.connect(_on_quiz_failed)
    game_ui.celebration_finished.connect(_on_celebration_finished)
    if not QuizBank.is_valid():
        _show_fatal_error("AI 题库数据无效")
        return
    var points: Array[Vector2] = world.get_treasure_positions()
    if points.size() < 2:
        _show_fatal_error("地图至少需要两个宝箱候选点")
        return
    player.global_position = world.get_player_start()
    _apply_camera_limits(world.get_world_rect())
    current_treasure = _spawn_next(points)
    if current_treasure == null:
        return
    player.movement_enabled = false
    game_ui.show_start()

func _unhandled_input(event: InputEvent) -> void:
    if flow.state == GameFlow.State.WAITING_START and event.is_pressed() and _is_move_event(event):
        flow.request_start()
        game_ui.hide_start()
        get_viewport().set_input_as_handled()

func _is_move_event(event: InputEvent) -> bool:
    return (
        event.is_action("move_left")
        or event.is_action("move_right")
        or event.is_action("move_up")
        or event.is_action("move_down")
    )

func _spawn_next(points: Array[Vector2]) -> Area2D:
    var minimum := GameConfig.MIN_TREASURE_DISTANCE_METRES * GameConfig.PIXELS_PER_METRE
    var treasure := spawner.spawn_next(points, player.global_position, minimum)
    if treasure == null:
        _show_fatal_error("无法生成新的宝箱")
        return null
    treasure.found.connect(_on_treasure_found, CONNECT_ONE_SHOT)
    current_treasure = treasure
    navigation_hud.set_target(player, treasure)
    return treasure

func _on_treasure_found() -> void:
    if flow.state != GameFlow.State.SEARCHING:
        return
    flow.on_treasure_found()
    navigation_hud.visible = false
    game_ui.show_quiz(QuizBank.question_for_round(quiz_round_index))
    quiz_round_index += 1

func _on_quiz_answered_correctly() -> void:
    if flow.state != GameFlow.State.QUIZZING:
        return
    flow.on_quiz_answered_correctly()
    game_ui.play_celebration()

func _on_quiz_failed() -> void:
    if flow.state != GameFlow.State.QUIZZING:
        return
    _finish_round()

func _on_celebration_finished() -> void:
    if flow.state != GameFlow.State.CELEBRATING:
        return
    _finish_round()

func _finish_round() -> void:
    if flow.state != GameFlow.State.QUIZZING and flow.state != GameFlow.State.CELEBRATING:
        return
    var treasure := _spawn_next(world.get_treasure_positions())
    if treasure == null:
        return
    navigation_hud.visible = true
    flow.on_round_finished()

func _on_state_changed(_previous: int, _current: int) -> void:
    player.movement_enabled = flow.can_player_move()

func _apply_camera_limits(rect: Rect2) -> void:
    var camera: Camera2D = player.get_node("Camera2D")
    camera.limit_left = roundi(rect.position.x)
    camera.limit_top = roundi(rect.position.y)
    camera.limit_right = roundi(rect.end.x)
    camera.limit_bottom = roundi(rect.end.y)

func _show_fatal_error(message: String) -> void:
    player.movement_enabled = false
    navigation_hud.visible = false
    push_error(message)
    game_ui.show_fatal_error(message)

func start_game_for_test() -> void:
    flow.request_start()

func complete_treasure_for_test() -> void:
    _on_treasure_found()

func finish_celebration_for_test() -> void:
    _on_celebration_finished()

func set_window_focused_for_test(focused: bool) -> void:
    get_tree().paused = not focused

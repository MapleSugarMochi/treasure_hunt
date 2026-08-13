class_name GameFlow
extends Node

signal state_changed(previous: int, current: int)
signal search_started
signal quiz_started
signal celebration_started
signal win_reached
signal game_over_reached
signal run_reset

enum State { WAITING_START, SEARCHING, QUIZZING, CELEBRATING, WON, GAME_OVER }

var state := State.WAITING_START

func can_player_move() -> bool:
    return state == State.SEARCHING

func is_terminal() -> bool:
    return state == State.WON or state == State.GAME_OVER

func request_start() -> void:
    if state != State.WAITING_START:
        return
    _set_state(State.SEARCHING)
    search_started.emit()

func on_treasure_found() -> void:
    if state != State.SEARCHING:
        return
    _set_state(State.QUIZZING)
    quiz_started.emit()

func on_quiz_answered_correctly() -> void:
    if state != State.QUIZZING:
        return
    _set_state(State.CELEBRATING)
    celebration_started.emit()

func on_round_finished() -> void:
    # Only the wrong-answer-still-alive path finishes a round back into search.
    # The celebration path no longer returns to search; it ends in a win.
    if state != State.QUIZZING:
        return
    _set_state(State.SEARCHING)
    search_started.emit()

func on_win() -> void:
    if state != State.CELEBRATING:
        return
    _set_state(State.WON)
    win_reached.emit()

func on_game_over() -> void:
    if state != State.QUIZZING:
        return
    _set_state(State.GAME_OVER)
    game_over_reached.emit()

func reset_to_start() -> void:
    if state != State.WON and state != State.GAME_OVER:
        return
    _set_state(State.WAITING_START)
    run_reset.emit()

func _set_state(next: int) -> void:
    var previous := state
    state = next
    state_changed.emit(previous, state)

class_name GameFlow
extends Node

signal state_changed(previous: int, current: int)
signal search_started
signal quiz_started
signal celebration_started

enum State { WAITING_START, SEARCHING, QUIZZING, CELEBRATING }

var state := State.WAITING_START

func can_player_move() -> bool:
    return state == State.SEARCHING

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
    if state != State.QUIZZING and state != State.CELEBRATING:
        return
    _set_state(State.SEARCHING)
    search_started.emit()

func _set_state(next: int) -> void:
    var previous := state
    state = next
    state_changed.emit(previous, state)

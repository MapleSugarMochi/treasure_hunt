class_name GameFlow
extends Node

signal state_changed(previous: int, current: int)
signal search_started
signal celebration_started

enum State { WAITING_START, SEARCHING, CELEBRATING }

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
    _set_state(State.CELEBRATING)
    celebration_started.emit()

func on_celebration_finished() -> void:
    if state != State.CELEBRATING:
        return
    _set_state(State.SEARCHING)
    search_started.emit()

func _set_state(next: int) -> void:
    var previous := state
    state = next
    state_changed.emit(previous, state)

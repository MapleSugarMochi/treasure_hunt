extends RefCounted

const GameFlow = preload("res://src/core/game_flow.gd")

var state_events := []
var lifecycle_events := []

func _record_state(previous: int, current: int) -> void:
    state_events.append([previous, current])

func _record_search_started() -> void:
    lifecycle_events.append("search_started")

func _record_celebration_started() -> void:
    lifecycle_events.append("celebration_started")

func run(t: SceneTree) -> void:
    var flow := GameFlow.new()
    flow.state_changed.connect(_record_state)
    flow.search_started.connect(_record_search_started)
    flow.celebration_started.connect(_record_celebration_started)

    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "starts on title state")
    t.assert_true(not flow.can_player_move(), "movement is locked on title")

    flow.request_start()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "movement starts search")
    t.assert_true(flow.can_player_move(), "movement enabled while searching")
    t.assert_eq(state_events, [[GameFlow.State.WAITING_START, GameFlow.State.SEARCHING]], "start emits the expected state transition")
    t.assert_eq(lifecycle_events, ["search_started"], "start emits search_started after the state transition")

    flow.request_start()
    flow.on_celebration_finished()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "illegal repeat events leave searching unchanged")
    t.assert_eq(state_events.size(), 1, "illegal repeat events emit no state transition")
    t.assert_eq(lifecycle_events, ["search_started"], "illegal repeat events emit no lifecycle signal")

    flow.on_treasure_found()
    t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "found treasure starts celebration")
    t.assert_true(not flow.can_player_move(), "movement locked during celebration")
    t.assert_eq(state_events[1], [GameFlow.State.SEARCHING, GameFlow.State.CELEBRATING], "found emits the expected state transition")
    t.assert_eq(lifecycle_events[1], "celebration_started", "found emits celebration_started after the state transition")

    flow.on_treasure_found()
    t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "duplicate found event is ignored")
    t.assert_eq(state_events.size(), 2, "duplicate found emits no state transition")
    t.assert_eq(lifecycle_events.size(), 2, "duplicate found emits no lifecycle signal")

    flow.on_celebration_finished()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "celebration returns directly to search")
    t.assert_true(flow.can_player_move(), "movement unlocks after celebration")
    t.assert_eq(state_events[2], [GameFlow.State.CELEBRATING, GameFlow.State.SEARCHING], "celebration finish emits the expected state transition")
    t.assert_eq(lifecycle_events[2], "search_started", "celebration finish emits search_started after the state transition")

    flow.on_celebration_finished()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "duplicate celebration finish is ignored")
    t.assert_eq(state_events.size(), 3, "duplicate celebration finish emits no state transition")
    t.assert_eq(lifecycle_events.size(), 3, "duplicate celebration finish emits no lifecycle signal")
    flow.free()

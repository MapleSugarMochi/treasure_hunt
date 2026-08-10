extends RefCounted

const GameFlow = preload("res://src/core/game_flow.gd")

var timeline := []
var observed_flow

func _record_state(previous: int, current: int) -> void:
    timeline.append(["state_changed", previous, current, observed_flow.state])

func _record_search_started() -> void:
    timeline.append(["search_started"])

func _record_celebration_started() -> void:
    timeline.append(["celebration_started"])

func run(t: SceneTree) -> void:
    var flow := GameFlow.new()
    observed_flow = flow
    flow.state_changed.connect(_record_state)
    flow.search_started.connect(_record_search_started)
    flow.celebration_started.connect(_record_celebration_started)

    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "starts on title state")
    t.assert_true(not flow.can_player_move(), "movement is locked on title")

    flow.on_treasure_found()
    flow.on_celebration_finished()
    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "events before start leave the title state unchanged")
    t.assert_true(not flow.can_player_move(), "events before start keep movement locked")
    t.assert_eq(timeline, [], "events before start emit no signals")

    flow.request_start()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "movement starts search")
    t.assert_true(flow.can_player_move(), "movement enabled while searching")
    t.assert_eq(
        timeline,
        [
            ["state_changed", GameFlow.State.WAITING_START, GameFlow.State.SEARCHING, GameFlow.State.SEARCHING],
            ["search_started"],
        ],
        "start emits state_changed first and search_started second after updating state"
    )

    flow.request_start()
    flow.on_celebration_finished()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "illegal repeat events leave searching unchanged")
    t.assert_eq(timeline.size(), 2, "illegal repeat events emit no additional signals")

    flow.on_treasure_found()
    t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "found treasure starts celebration")
    t.assert_true(not flow.can_player_move(), "movement locked during celebration")
    t.assert_eq(
        timeline,
        [
            ["state_changed", GameFlow.State.WAITING_START, GameFlow.State.SEARCHING, GameFlow.State.SEARCHING],
            ["search_started"],
            ["state_changed", GameFlow.State.SEARCHING, GameFlow.State.CELEBRATING, GameFlow.State.CELEBRATING],
            ["celebration_started"],
        ],
        "found emits state_changed first and celebration_started second after updating state"
    )

    flow.on_treasure_found()
    t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "duplicate found event is ignored")
    t.assert_eq(timeline.size(), 4, "duplicate found emits no additional signals")

    flow.on_celebration_finished()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "celebration returns directly to search")
    t.assert_true(flow.can_player_move(), "movement unlocks after celebration")
    t.assert_eq(
        timeline,
        [
            ["state_changed", GameFlow.State.WAITING_START, GameFlow.State.SEARCHING, GameFlow.State.SEARCHING],
            ["search_started"],
            ["state_changed", GameFlow.State.SEARCHING, GameFlow.State.CELEBRATING, GameFlow.State.CELEBRATING],
            ["celebration_started"],
            ["state_changed", GameFlow.State.CELEBRATING, GameFlow.State.SEARCHING, GameFlow.State.SEARCHING],
            ["search_started"],
        ],
        "celebration finish emits state_changed first and search_started second after updating state"
    )

    flow.on_celebration_finished()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "duplicate celebration finish is ignored")
    t.assert_eq(timeline.size(), 6, "duplicate celebration finish emits no additional signals")
    flow.free()

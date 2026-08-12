extends RefCounted

const GameFlow = preload("res://src/core/game_flow.gd")

var timeline := []
var observed_flow: GameFlow

func _record_state(previous: int, current: int) -> void:
    timeline.append(["state_changed", previous, current, observed_flow.state])

func _record_search_started() -> void:
    timeline.append(["search_started"])

func _record_quiz_started() -> void:
    timeline.append(["quiz_started"])

func _record_celebration_started() -> void:
    timeline.append(["celebration_started"])

func run(t: SceneTree) -> void:
    var flow := GameFlow.new()
    observed_flow = flow
    flow.state_changed.connect(_record_state)
    flow.search_started.connect(_record_search_started)
    flow.quiz_started.connect(_record_quiz_started)
    flow.celebration_started.connect(_record_celebration_started)

    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "starts on title state")
    t.assert_true(not flow.can_player_move(), "movement is locked on title")

    flow.on_treasure_found()
    flow.on_quiz_answered_correctly()
    flow.on_round_finished()
    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "events before start leave title unchanged")
    t.assert_eq(timeline, [], "events before start emit no signals")

    flow.request_start()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "movement starts search")
    t.assert_true(flow.can_player_move(), "movement is enabled only while searching")
    t.assert_eq(
        timeline,
        [
            ["state_changed", GameFlow.State.WAITING_START, GameFlow.State.SEARCHING, GameFlow.State.SEARCHING],
            ["search_started"],
        ],
        "start updates state before emitting search signal"
    )

    flow.on_treasure_found()
    t.assert_eq(flow.state, GameFlow.State.QUIZZING, "treasure contact starts quiz")
    t.assert_true(not flow.can_player_move(), "movement is locked during quiz")
    t.assert_eq(timeline[-2], ["state_changed", GameFlow.State.SEARCHING, GameFlow.State.QUIZZING, GameFlow.State.QUIZZING], "quiz updates state first")
    t.assert_eq(timeline[-1], ["quiz_started"], "quiz emits once")

    var before_duplicate := timeline.size()
    flow.on_treasure_found()
    t.assert_eq(flow.state, GameFlow.State.QUIZZING, "duplicate treasure contact is ignored")
    t.assert_eq(timeline.size(), before_duplicate, "duplicate treasure emits nothing")

    flow.on_round_finished()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "failed quiz can finish round directly")
    t.assert_true(flow.can_player_move(), "movement returns after failed round")
    t.assert_eq(timeline[-1], ["search_started"], "failed round starts next search")

    flow.on_treasure_found()
    flow.on_quiz_answered_correctly()
    t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "correct answer starts celebration")
    t.assert_true(not flow.can_player_move(), "movement stays locked during celebration")
    t.assert_eq(timeline[-2], ["state_changed", GameFlow.State.QUIZZING, GameFlow.State.CELEBRATING, GameFlow.State.CELEBRATING], "correct answer updates state first")
    t.assert_eq(timeline[-1], ["celebration_started"], "correct answer emits celebration once")

    before_duplicate = timeline.size()
    flow.on_quiz_answered_correctly()
    flow.on_treasure_found()
    t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "duplicate quiz events are ignored during celebration")
    t.assert_eq(timeline.size(), before_duplicate, "duplicate celebration events emit nothing")

    flow.on_round_finished()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "successful celebration finishes into search")
    t.assert_true(flow.can_player_move(), "movement returns after successful round")
    before_duplicate = timeline.size()
    flow.on_round_finished()
    t.assert_eq(timeline.size(), before_duplicate, "duplicate round finish is ignored")
    flow.free()

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

func _record_win() -> void:
    timeline.append(["win_reached"])

func _record_game_over() -> void:
    timeline.append(["game_over_reached"])

func _record_reset() -> void:
    timeline.append(["run_reset"])

func run(t: SceneTree) -> void:
    var flow := GameFlow.new()
    observed_flow = flow
    flow.state_changed.connect(_record_state)
    flow.search_started.connect(_record_search_started)
    flow.quiz_started.connect(_record_quiz_started)
    flow.celebration_started.connect(_record_celebration_started)
    flow.win_reached.connect(_record_win)
    flow.game_over_reached.connect(_record_game_over)
    flow.run_reset.connect(_record_reset)

    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "starts on title state")
    t.assert_true(not flow.can_player_move(), "movement is locked on title")
    t.assert_true(not flow.is_terminal(), "title is not a terminal state")

    # Events before start are no-ops.
    flow.on_treasure_found()
    flow.on_quiz_answered_correctly()
    flow.on_round_finished()
    flow.on_win()
    flow.on_game_over()
    flow.reset_to_start()
    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "events before start leave title unchanged")
    t.assert_eq(timeline, [], "events before start emit no signals")

    flow.request_start()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "movement starts search")
    t.assert_true(flow.can_player_move(), "movement is enabled only while searching")

    flow.on_treasure_found()
    t.assert_eq(flow.state, GameFlow.State.QUIZZING, "treasure contact starts quiz")
    t.assert_true(not flow.can_player_move(), "movement is locked during quiz")

    var before_duplicate := timeline.size()
    flow.on_treasure_found()
    t.assert_eq(flow.state, GameFlow.State.QUIZZING, "duplicate treasure contact is ignored")
    t.assert_eq(timeline.size(), before_duplicate, "duplicate treasure emits nothing")

    # Wrong-answer-still-alive path: QUIZZING -> SEARCHING.
    flow.on_round_finished()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "failed quiz with lives finishes round into search")
    t.assert_true(flow.can_player_move(), "movement returns after failed round")
    t.assert_eq(timeline[-1], ["search_started"], "failed round starts next search")

    # Correct-answer path: SEARCHING -> QUIZZING -> CELEBRATING -> WON.
    flow.on_treasure_found()
    flow.on_quiz_answered_correctly()
    t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "correct answer starts celebration")
    t.assert_true(not flow.can_player_move(), "movement stays locked during celebration")
    t.assert_eq(timeline[-1], ["celebration_started"], "correct answer emits celebration once")

    # on_round_finished must no longer accept CELEBRATING.
    before_duplicate = timeline.size()
    flow.on_round_finished()
    t.assert_eq(flow.state, GameFlow.State.CELEBRATING, "celebration no longer finishes into search")
    t.assert_eq(timeline.size(), before_duplicate, "celebration rejects on_round_finished")

    flow.on_win()
    t.assert_eq(flow.state, GameFlow.State.WON, "celebration ends in a win")
    t.assert_true(flow.is_terminal(), "won is a terminal state")
    t.assert_true(not flow.can_player_move(), "movement stays locked after a win")
    t.assert_eq(timeline[-1], ["win_reached"], "win emits once")

    # Terminal states reject play transitions.
    before_duplicate = timeline.size()
    flow.on_treasure_found()
    flow.on_quiz_answered_correctly()
    flow.on_round_finished()
    flow.on_game_over()
    t.assert_eq(flow.state, GameFlow.State.WON, "won rejects play transitions")
    t.assert_eq(timeline.size(), before_duplicate, "won emits nothing on play transitions")

    flow.reset_to_start()
    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "win resets to title")
    t.assert_eq(timeline[-1], ["run_reset"], "reset emits once")
    t.assert_true(not flow.can_player_move(), "title locks movement after reset")

    # Game-over path: three wrong answers deplete lives and reach GAME_OVER.
    flow.request_start()
    flow.on_treasure_found()
    flow.on_round_finished()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "first wrong answer keeps the run alive")
    flow.on_treasure_found()
    flow.on_round_finished()
    t.assert_eq(flow.state, GameFlow.State.SEARCHING, "second wrong answer keeps the run alive")
    flow.on_treasure_found()
    flow.on_game_over()
    t.assert_eq(flow.state, GameFlow.State.GAME_OVER, "depleted lives reach game over")
    t.assert_true(flow.is_terminal(), "game over is a terminal state")
    t.assert_eq(timeline[-1], ["game_over_reached"], "game over emits once")

    before_duplicate = timeline.size()
    flow.on_treasure_found()
    flow.on_quiz_answered_correctly()
    flow.on_round_finished()
    flow.on_win()
    t.assert_eq(flow.state, GameFlow.State.GAME_OVER, "game over rejects play transitions")
    t.assert_eq(timeline.size(), before_duplicate, "game over emits nothing on play transitions")

    flow.reset_to_start()
    t.assert_eq(flow.state, GameFlow.State.WAITING_START, "game over resets to title")

    # reset_to_start only works from a terminal state.
    before_duplicate = timeline.size()
    flow.reset_to_start()
    t.assert_eq(timeline.size(), before_duplicate, "reset is ignored outside terminal states")
    flow.free()

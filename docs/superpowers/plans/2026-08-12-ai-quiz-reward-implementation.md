# AI Quiz Reward Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require one sequential AI multiple-choice question after every treasure contact, award only a correct answer within two mouse clicks, and continue without a reward after two wrong answers.

**Architecture:** Add a pure-data `QuizBank`, extend `GameFlow` with a `QUIZZING` state, and let `GameUI` own answer-button presentation and attempt tracking. `Main` remains the integration coordinator: it assigns the next sequential question at treasure contact and replaces the treasure only after success celebration or final-failure feedback finishes.

**Tech Stack:** Godot 4.6.3, GDScript, `.tscn` scenes, the repository's custom headless `tests/test_runner.gd` harness.

## Global Constraints

- The bank contains exactly 10 approved questions, each with exactly 4 options and one valid correct index.
- Question order is fixed and wraps after question 10; a fresh process begins with question 1.
- Each question permits at most 2 mouse-click answers; there are no keyboard answer shortcuts.
- First wrong answer disables and marks only that choice; second wrong answer gives no reward and ends after 2 seconds.
- A correct answer gives the existing 4-second reward celebration.
- Treasure replacement happens exactly once after a round is settled, never at initial contact.
- Player position is preserved and movement stays disabled throughout quiz and feedback states.
- Existing offline, silent, 640×360 logical-canvas and bundled-font constraints remain unchanged.

---

### Task 1: Sequential quiz bank

**Files:**
- Create: `src/quiz/quiz_bank.gd`
- Create: `tests/test_quiz_bank.gd`

**Interfaces:**
- Produces: `QuizBank.question_count() -> int`
- Produces: `QuizBank.is_valid() -> bool`
- Produces: `QuizBank.question_for_round(round_index: int) -> Dictionary`
- Question dictionaries contain `prompt: String`, `options: Array[String]`, and `correct_index: int`.

- [ ] **Step 1: Write the failing quiz-bank test**

Create `tests/test_quiz_bank.gd` with literal assertions that the bank has 10 valid four-option questions, known prompts and answer indices are preserved, rounds 0 and 9 return the ends of the sequence, and rounds 10 and 20 wrap to question 1. Also assert a negative round maps safely to question 1.

```gdscript
extends RefCounted

const QuizBank = preload("res://src/quiz/quiz_bank.gd")

func run(t: SceneTree) -> void:
    t.assert_eq(QuizBank.question_count(), 10, "bank contains ten approved questions")
    t.assert_true(QuizBank.is_valid(), "every question has four options and a valid answer")
    t.assert_eq(QuizBank.question_for_round(0).prompt, "当前主流 LLM 的底层架构是什么？", "round zero starts with question one")
    t.assert_eq(QuizBank.question_for_round(9).correct_index, 0, "round nine uses question ten")
    t.assert_eq(QuizBank.question_for_round(10).prompt, QuizBank.question_for_round(0).prompt, "round ten wraps")
    t.assert_eq(QuizBank.question_for_round(20).prompt, QuizBank.question_for_round(0).prompt, "later cycles wrap")
    t.assert_eq(QuizBank.question_for_round(-1).prompt, QuizBank.question_for_round(0).prompt, "negative input falls back safely")
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: the suite fails because `res://src/quiz/quiz_bank.gd` does not exist.

- [ ] **Step 3: Implement the minimal bank**

Create `QuizBank` as a `RefCounted` class with a constant array containing the approved text from the design. Return a duplicated dictionary so UI code cannot mutate the shared bank. Use `maxi(round_index, 0) % QUESTIONS.size()` for order and wrap behavior.

```gdscript
class_name QuizBank
extends RefCounted

static func question_count() -> int:
    return QUESTIONS.size()

static func question_for_round(round_index: int) -> Dictionary:
    if QUESTIONS.is_empty():
        return {}
    return QUESTIONS[maxi(round_index, 0) % QUESTIONS.size()].duplicate(true)
```

- [ ] **Step 4: Run the full suite and verify GREEN**

Run the command from Step 2. Expected: all quiz-bank assertions and the existing suite pass.

- [ ] **Step 5: Commit the bank**

```powershell
git add src/quiz/quiz_bank.gd tests/test_quiz_bank.gd
git commit -m "feat: add sequential AI quiz bank"
```

### Task 2: Quiz-aware game state

**Files:**
- Modify: `src/core/game_flow.gd`
- Modify: `tests/test_game_flow.gd`

**Interfaces:**
- Produces: `GameFlow.State.QUIZZING`
- Produces: signals `quiz_started`, `celebration_started`, and `search_started`
- Produces: `on_treasure_found()`, `on_quiz_answered_correctly()`, and `on_round_finished()` legal transitions.

- [ ] **Step 1: Rewrite the state-flow expectations first**

Update `tests/test_game_flow.gd` so the observable sequence is:

```text
WAITING_START -> SEARCHING -> QUIZZING -> CELEBRATING -> SEARCHING
```

Assert that treasure contact emits `quiz_started`, a correct answer is accepted only in `QUIZZING`, round finish is accepted from `QUIZZING` (failed path) or `CELEBRATING` (success path), and illegal duplicate calls emit nothing. Assert `can_player_move()` is true only in `SEARCHING`.

- [ ] **Step 2: Run and verify RED**

Run the full test command. Expected: missing `QUIZZING`, `quiz_started`, `on_quiz_answered_correctly`, and `on_round_finished` failures.

- [ ] **Step 3: Implement minimal legal transitions**

Use this state contract:

```gdscript
enum State { WAITING_START, SEARCHING, QUIZZING, CELEBRATING }

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
    if state not in [State.QUIZZING, State.CELEBRATING]:
        return
    _set_state(State.SEARCHING)
    search_started.emit()
```

- [ ] **Step 4: Run and verify GREEN**

Run the full suite and confirm state tests pass without changing unrelated behavior.

- [ ] **Step 5: Commit the state machine**

```powershell
git add src/core/game_flow.gd tests/test_game_flow.gd
git commit -m "feat: add quiz state to game flow"
```

### Task 3: Mouse-only quiz UI

**Files:**
- Modify: `src/ui/game_ui.gd`
- Modify: `src/ui/game_ui.tscn`
- Modify: `tests/test_ui_scenes.gd`

**Interfaces:**
- Consumes: question dictionaries from `QuizBank.question_for_round`.
- Produces: signals `quiz_answered_correctly` and `quiz_failed`.
- Produces: `show_quiz(question: Dictionary) -> void`.
- Produces: `_on_answer_pressed(option_index: int) -> void` as the single answer-settlement path called only by button `pressed` signals.

- [ ] **Step 1: Add failing scene and behavior assertions**

Extend `tests/test_ui_scenes.gd` to assert:

- `QuizOverlay` exists, is hidden initially, and stops mouse events while visible.
- Four `Button` children exist and are connected through their `pressed` behavior.
- `show_quiz` renders the prompt and `A.` through `D.` labels and resets attempts.
- First wrong press keeps the overlay open, disables only the selected button, and shows `回答错误，还剩 1 次机会`.
- A correct press emits once, marks the correct choice and disables all buttons; the integration coordinator then starts the reward celebration.
- Two wrong presses emit `quiz_failed` only after the two-second failure timer callback and never show celebration.
- Pressing an already disabled choice or pressing after settlement has no effect.
- No `_unhandled_input` or answer-key method is part of `GameUI`; only real button presses settle answers.

- [ ] **Step 2: Run and verify RED**

Run the full suite. Expected: missing quiz overlay, signals and `show_quiz` failures.

- [ ] **Step 3: Build the quiz panel and attempt logic**

Add a full-screen `QuizOverlay` with a dim backdrop and centered `QuizCard`. Use the bundled Noto Sans CJK font for title, prompt, feedback, and button text. Create four vertically stacked buttons sized for the longest approved text. Add red, green, hover, and disabled `StyleBoxFlat` resources. Add a one-shot `FailureTimer` with `wait_time = 2.0`.

In `GameUI`, keep:

```gdscript
var current_question: Dictionary = {}
var attempts_used := 0
var quiz_settled := false
```

`_on_answer_pressed` rejects invalid, disabled or settled input. It increments attempts, compares against `correct_index`, then either emits success exactly once, marks the first wrong button, or starts failure feedback after the second wrong answer. Tests invoke the real timer callback just as the existing celebration test does; no test-only production methods are added. `show_start`, `show_quiz`, success, failure, and fatal-error functions enforce mutually exclusive overlays and stop irrelevant timers.

- [ ] **Step 4: Run and verify GREEN**

Run the full suite and confirm UI tests pass, including real `Button.pressed.emit()` calls.

- [ ] **Step 5: Commit the UI**

```powershell
git add src/ui/game_ui.gd src/ui/game_ui.tscn tests/test_ui_scenes.gd
git commit -m "feat: add mouse-only AI quiz panel"
```

### Task 4: Integrate round settlement and sequential questions

**Files:**
- Modify: `src/main/main.gd`
- Modify: `tests/test_continuous_loop.gd`

**Interfaces:**
- Consumes: `QuizBank.question_for_round(round_index)`.
- Consumes: `GameUI.quiz_answered_correctly`, `GameUI.quiz_failed`, and `GameUI.celebration_finished`.
- Produces: exactly one `_finish_round()` path that spawns the next treasure and returns the flow to `SEARCHING`.

- [ ] **Step 1: Replace old integration expectations with failing quiz lifecycle tests**

Update `tests/test_continuous_loop.gd` so each treasure signal first asserts:

- flow is `QUIZZING`;
- the old treasure remains current and is not queued for deletion;
- navigation and movement are disabled;
- the displayed prompt matches `QuizBank.question_for_round(round_index)`.

Cover a success on first try, success after one wrong answer, and two-wrong failure. After the relevant timer callback, assert exactly one new treasure exists, the player position is unchanged, movement/navigation return, and the next treasure presents the next question. Run at least 500 alternating success/failure rounds to prove wrap behavior and no duplicate lifecycle.

- [ ] **Step 2: Run and verify RED**

Run the full suite. Expected: current `Main` still celebrates and replaces treasure immediately, contradicting the new lifecycle.

- [ ] **Step 3: Implement integration**

Preload `QuizBank`, initialize `quiz_round_index := 0`, connect the three UI completion signals, and change treasure contact to:

```gdscript
func _on_treasure_found() -> void:
    if flow.state != GameFlow.State.SEARCHING:
        return
    flow.on_treasure_found()
    navigation_hud.visible = false
    game_ui.show_quiz(QuizBank.question_for_round(quiz_round_index))
    quiz_round_index += 1
```

Correct answers call `flow.on_quiz_answered_correctly()` and `game_ui.play_celebration()`. Both `celebration_finished` and final failure call `_finish_round()`, which spawns one replacement, restores navigation only on success, and calls `flow.on_round_finished()`. If spawning fails, preserve the fatal state instead of unlocking movement.

- [ ] **Step 4: Run and verify GREEN**

Run the full suite. Expected: all legacy and new lifecycle assertions pass with zero failures.

- [ ] **Step 5: Commit integration**

```powershell
git add src/main/main.gd tests/test_continuous_loop.gd
git commit -m "feat: gate treasure rewards behind AI quiz"
```

### Task 5: Operator documentation and final verification

**Files:**
- Modify: `README.md`
- Modify: `docs/qa/manual-test-checklist.md`

**Interfaces:**
- Documents the final player and operator-visible contract only; no new runtime API.

- [ ] **Step 1: Update usage and manual QA**

Document that movement remains keyboard-driven while answers are mouse-only. Add checks for all four buttons, first-wrong feedback, second-wrong no-award behavior, successful reward behavior, position preservation, timer pause on focus loss, and 12 rounds of sequential question order including question 10 to question 1 wrap.

- [ ] **Step 2: Import and parse the project**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --import --path .
```

Expected: exit code 0 with no script or scene parse errors.

- [ ] **Step 3: Run the complete automated suite freshly**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: `RESULT assertions=<positive number> failures=0` and exit code 0.

- [ ] **Step 4: Run a main-scene smoke test**

Run:

```powershell
& '.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --quit-after 5
```

Expected: main scene initializes and exits without script, resource, or scene errors.

- [ ] **Step 5: Render and inspect the quiz layout**

Launch a deterministic capture scene or the main scene, place `GameUI` in quiz state with the longest approved prompt/option, capture the 640×360 viewport, and inspect the PNG for clipping, overlap, unreadable contrast, or hidden buttons. Repeat after marking a wrong option and after correct settlement.

- [ ] **Step 6: Audit requirements and commit documentation**

Cross-check every item in `docs/superpowers/specs/2026-08-12-ai-quiz-reward-design.md` against code, tests, runtime output and rendered UI evidence. Then run `git diff --check` and commit:

```powershell
git add README.md docs/qa/manual-test-checklist.md
git commit -m "docs: explain AI quiz treasure flow"
```

# Quiz Page Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the cramped four-row quiz overlay with the approved wide 2×2 answer-card layout while preserving every quiz behavior and feedback state.

**Architecture:** Keep `GameUI` as the existing presentation and state owner. Put fixed geometry and theme resources in `game_ui.tscn`, and make only the minimal runtime styling changes in `game_ui.gd` needed for wrapped option text and consistent disabled states.

**Tech Stack:** Godot 4.6.3, GDScript, Godot scene resources, the existing custom `SceneTree` test runner.

## Global Constraints

- The logical canvas remains exactly 640×360 and integer-scaled.
- Preserve the deep-navy and gold treasure-hunt identity.
- Quiz answers remain mouse-only and allow exactly one attempt.
- Do not change quiz signals, timers, question order, life loss, or celebration behavior.
- Use only the bundled Noto Sans CJK SC font and existing project resources.
- Do not add audio, network access, branding, counters, or new dependencies.

---

### Task 1: Lock the approved quiz layout into the UI contract

**Files:**
- Modify: `tests/test_quiz_ui.gd`

**Interfaces:**
- Consumes: `res://src/ui/game_ui.tscn` and its existing `QuizOverlay/QuizCard` node paths.
- Produces: executable assertions for the card safe area, 2×2 geometry, font scale, wrapped text, and A-D badges.

- [ ] **Step 1: Write the failing layout assertions**

Add literal assertions after the quiz nodes are resolved:

```gdscript
var quiz_card := ui.get_node("QuizOverlay/QuizCard") as Panel
var quiz_title := ui.get_node("QuizOverlay/QuizCard/QuizTitle") as Label
var badges: Array[Label] = [
    ui.get_node("QuizOverlay/QuizCard/AnswerA/Badge") as Label,
    ui.get_node("QuizOverlay/QuizCard/AnswerB/Badge") as Label,
    ui.get_node("QuizOverlay/QuizCard/AnswerC/Badge") as Label,
    ui.get_node("QuizOverlay/QuizCard/AnswerD/Badge") as Label,
]
t.assert_eq(quiz_card.position, Vector2(28, 20), "quiz card keeps a relaxed outer margin")
t.assert_eq(quiz_card.size, Vector2(584, 320), "quiz card uses the wide approved footprint")
t.assert_eq(quiz_title.get_theme_font_size("font_size"), 18, "quiz title uses the smaller display size")
t.assert_eq(question_label.get_theme_font_size("font_size"), 15, "question uses the smaller readable size")
t.assert_eq(feedback_label.get_theme_font_size("font_size"), 12, "feedback fits the compact header")
t.assert_eq(buttons[0].position.y, buttons[1].position.y, "A and B share the first row")
t.assert_eq(buttons[2].position.y, buttons[3].position.y, "C and D share the second row")
t.assert_true(buttons[0].position.x < buttons[1].position.x, "B sits to the right of A")
t.assert_true(buttons[2].position.x < buttons[3].position.x, "D sits to the right of C")
t.assert_true(buttons.all(func(button: Button) -> bool: return button.size == Vector2(258, 68)), "answer cards share the approved size")
t.assert_true(buttons.all(func(button: Button) -> bool: return button.autowrap_mode != TextServer.AUTOWRAP_OFF), "answer text wraps inside two-column cards")
t.assert_eq(badges.map(func(badge: Label) -> String: return badge.text), ["A", "B", "C", "D"], "answer cards expose separate letter badges")
```

Update the existing rendered-text checks to expect option text without `A. ` and `D. ` prefixes.

- [ ] **Step 2: Run the full suite and verify the new contract fails**

Run:

```powershell
& '..\..\.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script tests/test_runner.gd
```

Expected: non-zero exit with failures for the old `QuizCard` position/size, old one-column button geometry, missing `Badge` nodes, old font sizes, or prefixed answer text.

### Task 2: Implement the wide 2×2 challenge card

**Files:**
- Modify: `src/ui/game_ui.tscn`
- Modify: `src/ui/game_ui.gd`
- Test: `tests/test_quiz_ui.gd`

**Interfaces:**
- Consumes: question dictionaries with `prompt`, four `options`, and `correct_index`.
- Produces: the unchanged `show_quiz(question: Dictionary) -> void` and `_on_answer_pressed(option_index: int) -> void` behavior in the approved layout.

- [ ] **Step 1: Update static scene geometry and visual resources**

Set `QuizCard` to `(28, 20)` with size `(584, 320)`. Add a gold question-mark emblem in the header, left-align the 18 px title and 15 px wrapped question, and place the 12 px feedback label at the right side of the header.

Place answer cards at these exact local rectangles:

```text
AnswerA: Rect2(28, 124, 258, 68)
AnswerB: Rect2(298, 124, 258, 68)
AnswerC: Rect2(28, 204, 258, 68)
AnswerD: Rect2(298, 204, 258, 68)
```

Each button uses a 12 px font, left alignment, automatic word wrapping, and a 48 px left content margin. Add a mouse-ignoring child `Label` named `Badge` with the literal text A, B, C, or D.

- [ ] **Step 2: Align runtime answer and disabled styling**

Change answer population to keep the visible option text separate from the letter badge:

```gdscript
button.text = current_question.options[index]
```

Update `_set_disabled_style` to use the approved 10 px corners and the same content margins as normal answer cards:

```gdscript
style.corner_radius_top_left = 10
style.corner_radius_top_right = 10
style.corner_radius_bottom_right = 10
style.corner_radius_bottom_left = 10
style.content_margin_left = 48.0
style.content_margin_right = 12.0
style.content_margin_top = 8.0
style.content_margin_bottom = 8.0
```

- [ ] **Step 3: Run the full suite and verify green**

Run the full Godot test command from Task 1.

Expected: exit 0 and `RESULT assertions=<N> failures=0`.

### Task 3: Capture and inspect all answer states

**Files:**
- Modify: `docs/qa/evidence/ai-quiz-initial-640x360.png`
- Modify: `docs/qa/evidence/ai-quiz-failed-640x360.png`
- Modify: `docs/qa/evidence/ai-quiz-reward-640x360.png`

**Interfaces:**
- Consumes: `tools/capture_quiz_evidence.gd` and the completed `GameUI` scene.
- Produces: fresh 640×360 evidence for initial, wrong-answer, and reward states.

- [ ] **Step 1: Capture the three evidence images**

Run the non-headless capture script with the vendored Godot GUI binary:

```powershell
& '..\..\.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64.exe' --path . --script tools/capture_quiz_evidence.gd
```

Expected: exit 0 with three `CAPTURED` lines and `CAPTURE_RESULT failures=0`.

- [ ] **Step 2: Inspect the images**

Verify the initial screenshot has a complete two-line maximum question, four equal 2×2 answer cards, readable 12 px option text, visible A-D badges, no overlap, and at least 20 px outer breathing room. Verify the wrong state preserves the grid and highlights only the selected wrong answer. Verify the reward state remains unchanged.

- [ ] **Step 3: Run final verification**

Run:

```powershell
& '..\..\.superpowers\toolchains\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script tests/test_runner.gd
git diff --check
git status --short
```

Expected: tests exit 0 with zero failures, `git diff --check` prints nothing, and status lists only the approved UI, test, evidence, spec, and plan files.

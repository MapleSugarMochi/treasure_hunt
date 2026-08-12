extends RefCounted

const QuizBank = preload("res://src/quiz/quiz_bank.gd")

func run(t: SceneTree) -> void:
    t.assert_eq(QuizBank.question_count(), 10, "bank contains ten approved questions")
    t.assert_true(QuizBank.is_valid(), "every question has four options and a valid answer")

    var first: Dictionary = QuizBank.question_for_round(0)
    var last: Dictionary = QuizBank.question_for_round(9)
    t.assert_eq(first.prompt, "当前主流 LLM 的底层架构是什么？", "round zero starts with question one")
    t.assert_eq(first.options, ["Transformer", "Transaction", "Agentic Workflow", "其实大模型都是人类假扮的"], "question one keeps its approved options")
    t.assert_eq(first.correct_index, 0, "question one identifies Transformer")
    t.assert_eq(last.prompt, "AI Agent 与普通聊天模型相比，通常多了什么能力？", "round nine uses question ten")
    t.assert_eq(last.correct_index, 0, "question ten identifies autonomous planning and tool use")
    t.assert_eq(QuizBank.question_for_round(10).prompt, first.prompt, "round ten wraps to question one")
    t.assert_eq(QuizBank.question_for_round(20).prompt, first.prompt, "later cycles wrap consistently")
    t.assert_eq(QuizBank.question_for_round(-1).prompt, first.prompt, "negative input falls back safely")

    first.options[0] = "mutated"
    t.assert_eq(QuizBank.question_for_round(0).options[0], "Transformer", "callers cannot mutate the shared bank")

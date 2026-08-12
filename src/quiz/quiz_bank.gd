class_name QuizBank
extends RefCounted

const QUESTIONS := [
    {
        "prompt": "当前主流 LLM 的底层架构是什么？",
        "options": ["Transformer", "Transaction", "Agentic Workflow", "其实大模型都是人类假扮的"],
        "correct_index": 0,
    },
    {
        "prompt": "AI 的英文全称是什么？",
        "options": ["Automatic Internet", "Artificial Intelligence", "“爱”的英文缩写，电脑看了也会心动", "Advanced Information"],
        "correct_index": 1,
    },
    {
        "prompt": "GPT 中的字母 G 代表什么？",
        "options": ["General", "Global", "Generative", "Give me the answer（快把答案告诉我）"],
        "correct_index": 2,
    },
    {
        "prompt": "大模型处理文字时，通常会先把文字拆分成什么？",
        "options": ["Token", "Pixel", "电子芝麻粒", "Folder"],
        "correct_index": 0,
    },
    {
        "prompt": "AI“幻觉”指的是什么？",
        "options": ["屏幕出现了重影", "AI 生成了看似合理但实际错误的信息", "AI 拒绝回答所有问题", "AI 昨晚做梦，到现在还没睡醒"],
        "correct_index": 1,
    },
    {
        "prompt": "我们输入给 AI 的问题或指令通常称为什么？",
        "options": ["Prompt", "Password", "对电脑施放的许愿咒语", "Program"],
        "correct_index": 0,
    },
    {
        "prompt": "大量训练数据对大模型的主要作用是什么？",
        "options": ["增加电脑的存储空间", "喂饱 AI，让它不再喊饿", "帮助模型学习语言和信息中的规律", "自动连接所有网站"],
        "correct_index": 2,
    },
    {
        "prompt": "“多模态 AI”通常表示 AI 能够处理什么？",
        "options": ["同时戴很多副眼镜", "只有文字", "文字、图片、声音等多种信息", "只有数字"],
        "correct_index": 2,
    },
    {
        "prompt": "对已经训练好的模型进行“微调”，主要目的是什么？",
        "options": ["清除模型的全部知识", "让模型更适合某个特定任务或领域", "减少模型使用的颜色", "拿螺丝刀把模型拧小半圈"],
        "correct_index": 1,
    },
    {
        "prompt": "AI Agent 与普通聊天模型相比，通常多了什么能力？",
        "options": ["自主规划步骤并调用工具完成任务", "永远不会犯错", "从屏幕里钻出来替人上班", "不需要任何输入"],
        "correct_index": 0,
    },
]

static func question_count() -> int:
    return QUESTIONS.size()

static func is_valid() -> bool:
    if QUESTIONS.size() != 10:
        return false
    for question in QUESTIONS:
        if not question is Dictionary:
            return false
        if not question.has("prompt") or not question.prompt is String or question.prompt.is_empty():
            return false
        if not question.has("options") or not question.options is Array or question.options.size() != 4:
            return false
        if not question.has("correct_index") or not question.correct_index is int:
            return false
        if question.correct_index < 0 or question.correct_index >= question.options.size():
            return false
        for option in question.options:
            if not option is String or option.is_empty():
                return false
    return true

static func question_for_round(round_index: int) -> Dictionary:
    if QUESTIONS.is_empty():
        return {}
    var safe_index := maxi(round_index, 0) % QUESTIONS.size()
    return QUESTIONS[safe_index].duplicate(true)

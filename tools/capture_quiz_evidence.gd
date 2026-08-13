extends SceneTree

const UI_SCENE := preload("res://src/ui/game_ui.tscn")
const OUTPUT_DIR := "res://docs/qa/evidence"

var failures := 0

func _initialize() -> void:
    call_deferred("_capture_all")

func _capture_all() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(640, 360)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)

    var ui := UI_SCENE.instantiate() as GameUI
    viewport.add_child(ui)
    await process_frame

    var question := {
        "prompt": "大量训练数据对大模型的主要作用是什么？",
        "options": [
            "增加电脑的存储空间",
            "喂饱 AI，让它不再喊饿",
            "帮助模型学习语言和信息中的规律",
            "自动连接所有网站",
        ],
        "correct_index": 2,
    }

    ui.show_quiz(question)
    await _save_viewport(viewport, "ai-quiz-initial-640x360.png")

    ui.answer_buttons[0].pressed.emit()
    await process_frame
    await _save_viewport(viewport, "ai-quiz-failed-640x360.png")

    ui.show_quiz(question)
    ui.answer_buttons[2].pressed.emit()
    ui.play_celebration()
    ui.get_node("CelebrationOverlay/GoldParticles").visible = false
    await _save_viewport(viewport, "ai-quiz-reward-640x360.png")

    viewport.queue_free()
    await process_frame
    print("CAPTURE_RESULT failures=%d" % failures)
    quit(1 if failures > 0 else 0)

func _save_viewport(viewport: SubViewport, file_name: String) -> void:
    await RenderingServer.frame_post_draw
    var image := viewport.get_texture().get_image()
    if image.get_size() != Vector2i(640, 360):
        failures += 1
        push_error("Unexpected capture size for %s: %s" % [file_name, image.get_size()])
        return
    var path := "%s/%s" % [OUTPUT_DIR, file_name]
    var save_error := image.save_png(path)
    if save_error != OK:
        failures += 1
        push_error("Cannot save %s: %s" % [path, error_string(save_error)])
        return
    print("CAPTURED %s size=%s" % [path, image.get_size()])

extends RefCounted

func run(t: SceneTree) -> void:
    t.paused = false
    _assert_project_settings(t)
    _assert_operator_documents(t)

    var packed := load("res://src/main/main.tscn") as PackedScene
    t.assert_true(packed != null, "focus test loads the main scene")
    if packed == null:
        return
    var main := packed.instantiate()
    t.root.add_child(main)
    t.assert_true(main.has_method("set_window_focused_for_test"), "Main exposes the focus test hook")

    var expected_roots := [
        ["GameFlow", Node.PROCESS_MODE_PAUSABLE],
        ["World", Node.PROCESS_MODE_PAUSABLE],
        ["TreasureSpawner", Node.PROCESS_MODE_PAUSABLE],
        ["Player", Node.PROCESS_MODE_PAUSABLE],
        ["UI", Node.PROCESS_MODE_PAUSABLE],
        ["UI/NavigationHUD", Node.PROCESS_MODE_PAUSABLE],
        ["UI/GameUI", Node.PROCESS_MODE_PAUSABLE],
    ]
    t.assert_eq(main.process_mode, Node.PROCESS_MODE_ALWAYS, "Main always processes for focus recovery")
    for item in expected_roots:
        var path: String = item[0]
        var node: Node = main.get_node(path)
        t.assert_eq(node.process_mode, item[1], "%s explicitly uses pausable processing" % path)

    var paused_nodes: Array[Node] = []
    for item in expected_roots:
        paused_nodes.append(main.get_node(item[0]))
    paused_nodes.append(main.get_node("UI/GameUI/CelebrationTimer"))
    paused_nodes.append(main.get_node("UI/GameUI/FailureTimer"))
    paused_nodes.append(main.get_node("UI/GameUI/RestartTimer"))

    if main.has_method("set_window_focused_for_test"):
        main.set_window_focused_for_test(false)
    else:
        t.paused = true
    t.assert_true(t.paused, "losing focus pauses the scene tree")
    t.assert_true(main.can_process(), "Main can process while the tree is paused")
    for node in paused_nodes:
        t.assert_true(not node.can_process(), "%s cannot process while paused" % node.get_path())

    if main.has_method("set_window_focused_for_test"):
        main.set_window_focused_for_test(true)
    else:
        t.paused = false
    t.assert_true(not t.paused, "regaining focus resumes the scene tree")
    for node in paused_nodes:
        t.assert_true(node.can_process(), "%s resumes processing after focus returns" % node.get_path())

    if main.has_method("_notification"):
        main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
        t.assert_true(t.paused, "focus-out notification pauses the tree")
        main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
        t.assert_true(not t.paused, "focus-in notification resumes the tree")

    t.paused = false
    main.free()

func _assert_project_settings(t: SceneTree) -> void:
    t.assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640, "logical viewport width is 640")
    t.assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360, "logical viewport height is 360")
    t.assert_eq(ProjectSettings.get_setting("display/window/size/window_width_override"), 1280, "window width override is 1280")
    t.assert_eq(ProjectSettings.get_setting("display/window/size/window_height_override"), 720, "window height override is 720")
    t.assert_eq(ProjectSettings.get_setting("display/window/size/mode"), 3, "window starts fullscreen")
    t.assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "stretch mode uses canvas items")
    t.assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep", "stretch aspect is kept")
    t.assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer", "stretch scaling is integer")
    t.assert_eq(ProjectSettings.get_setting("display/window/energy_saving/keep_screen_on"), true, "screen stays on for exhibition")
    t.assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility", "Compatibility renderer is selected")
    t.assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0, "textures use nearest filtering")
    t.assert_eq(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel"), false, "2D transforms remain unsnapped for smooth movement")
    t.assert_eq(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel"), false, "2D vertices remain unsnapped for smooth movement")
    t.assert_true(not FileAccess.file_exists("res://default_bus_layout.tres"), "no audio bus resource is shipped")

func _assert_operator_documents(t: SceneTree) -> void:
    var readme := FileAccess.get_file_as_string("res://README.md")
    t.assert_true(readme.contains("--import --path ."), "README starts with the source import preflight")
    t.assert_true(readme.contains("Godot 4.6.3"), "README names the supported Godot version")
    t.assert_true(readme.contains("WASD") and readme.contains("方向键"), "README documents movement keys")
    t.assert_true(readme.contains("Alt+F4"), "README documents the exit shortcut")
    t.assert_true(readme.contains("4 秒") or readme.contains("4秒"), "README documents the four-second celebration")
    t.assert_true(readme.contains("整数米") or readme.contains("整数"), "README documents integer distance")
    t.assert_true(readme.contains("不传送") or readme.contains("原地"), "README documents the no-teleport behavior")
    t.assert_true(readme.contains("静音") or readme.contains("无声"), "README documents silent operation")
    t.assert_true(readme.contains("CampusTreasureHunt.exe") == false, "README does not claim a game EXE exists")
    t.assert_true(readme.contains("双击") == false and readme.to_lower().contains("double-click") == false, "README has no game EXE double-click instruction")

    var checklist := FileAccess.get_file_as_string("res://docs/qa/manual-test-checklist.md")
    t.assert_true(checklist.contains("- [ ]"), "manual QA rows are present and unchecked")
    t.assert_true(checklist.contains("[x]") == false and checklist.contains("[X]") == false, "manual QA has no passed rows")

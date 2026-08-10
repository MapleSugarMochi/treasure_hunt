extends RefCounted

func run(t: SceneTree) -> void:
    t.assert_true(FileAccess.file_exists("res://project.godot"), "project.godot exists")
    t.assert_true(ResourceLoader.exists("res://src/main/main.tscn"), "main scene exists")
    var packed := load("res://src/main/main.tscn") as PackedScene
    t.assert_true(packed != null, "main scene loads")
    if packed != null:
        var instance := packed.instantiate()
        t.assert_eq(instance.name, "Main", "root node is Main")
        instance.free()

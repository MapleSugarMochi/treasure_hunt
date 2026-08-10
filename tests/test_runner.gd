extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
    call_deferred("_run_all")

func _run_all() -> void:
    var dir := DirAccess.open("res://tests")
    if dir == null:
        push_error("Cannot open res://tests")
        quit(1)
        return
    var files := dir.get_files()
    files.sort()
    for file_name in files:
        if not file_name.begins_with("test_") or not file_name.ends_with(".gd"):
            continue
        if file_name == "test_runner.gd":
            continue
        var suite_script: Script = load("res://tests/%s" % file_name)
        var suite: RefCounted = suite_script.new()
        print("RUN %s" % file_name)
        suite.run(self)
    print("RESULT assertions=%d failures=%d" % [assertions, failures])
    quit(1 if failures > 0 else 0)

func assert_true(value: bool, message: String) -> void:
    assertions += 1
    if not value:
        failures += 1
        push_error("ASSERT TRUE FAILED: %s" % message)

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
    assertions += 1
    if actual != expected:
        failures += 1
        push_error("ASSERT EQ FAILED: %s; actual=%s expected=%s" % [message, actual, expected])

func assert_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
    assertions += 1
    if absf(actual - expected) > tolerance:
        failures += 1
        push_error("ASSERT APPROX FAILED: %s; actual=%f expected=%f" % [message, actual, expected])

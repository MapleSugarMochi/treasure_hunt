extends SceneTree

const WORLD_SCENE := preload("res://src/world/world.tscn")
const PLAYER_SCENE := preload("res://src/player/player.tscn")
const OUTPUT_DIR := "res://docs/qa/evidence"

var failures := 0

func _initialize() -> void:
    call_deferred("_capture_all")

func _capture_all() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(1024, 768)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    root.add_child(viewport)

    var world := WORLD_SCENE.instantiate() as CampusWorld
    viewport.add_child(world)
    var camera := Camera2D.new()
    camera.position = world.get_world_rect().get_center()
    camera.zoom = Vector2(2.0 / 3.0, 2.0 / 3.0)
    camera.enabled = true
    viewport.add_child(camera)
    await process_frame
    await _save_viewport(viewport, "map-a3-overview-1024x768.png")

    var player := PLAYER_SCENE.instantiate() as Player
    player.position = world.get_player_start()
    viewport.add_child(player)
    viewport.size = Vector2i(640, 360)
    camera.position = world.get_player_start()
    camera.zoom = Vector2.ONE
    await process_frame
    await _save_viewport(viewport, "map-a3-player-view-640x360.png")

    viewport.queue_free()
    await process_frame
    print("MAP_CAPTURE_RESULT failures=%d" % failures)
    quit(1 if failures > 0 else 0)

func _save_viewport(viewport: SubViewport, file_name: String) -> void:
    await RenderingServer.frame_post_draw
    var image := viewport.get_texture().get_image()
    if image.get_size() != viewport.size:
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

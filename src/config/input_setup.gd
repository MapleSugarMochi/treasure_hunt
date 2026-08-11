class_name InputSetup
extends RefCounted

const ACTIONS := {
    "move_left": [KEY_A, KEY_LEFT],
    "move_right": [KEY_D, KEY_RIGHT],
    "move_up": [KEY_W, KEY_UP],
    "move_down": [KEY_S, KEY_DOWN],
}

static func ensure_actions() -> void:
    for action_name in ACTIONS:
        if not InputMap.has_action(action_name):
            InputMap.add_action(action_name, 0.2)
        for keycode: int in ACTIONS[action_name]:
            var event := InputEventKey.new()
            event.keycode = keycode
            if not InputMap.action_has_event(action_name, event):
                InputMap.action_add_event(action_name, event)

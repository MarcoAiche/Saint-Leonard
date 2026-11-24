class_name Controls
extends RefCounted
## Tastenbelegung. Wird beim Start einmal angelegt, damit project.godot schlank bleibt.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],  # im Auto: Handbremse
	"sprint": [KEY_SHIFT],
	"interact": [KEY_F, KEY_E],  # ein-/aussteigen
	"reset_vehicle": [KEY_R],
	"horn": [KEY_H],
	"toggle_help": [KEY_F1],
	"map": [KEY_M, KEY_TAB],
	"pause": [KEY_ESCAPE],
}


static func setup() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

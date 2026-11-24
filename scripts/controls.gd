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
	"crouch": [KEY_C],
	"interact": [KEY_F, KEY_E],
	"cargo": [KEY_G],  # tragen, auf-/abladen
	"reset_vehicle": [KEY_R],
	"reload": [KEY_R],
	"horn": [KEY_H],
	"lights": [KEY_L],
	"radio": [KEY_K],
	"winch": [KEY_T],
	"slot_1": [KEY_1],
	"slot_2": [KEY_2],
	"slot_3": [KEY_3],
	"slot_4": [KEY_4],
	"slot_5": [KEY_5],
	"slot_6": [KEY_6],
	"smoke": [KEY_Z, KEY_Y],
	"drink": [KEY_X],
	"inventory": [KEY_I],
	"phone": [KEY_P, KEY_UP],
	"toggle_view": [KEY_V],
	"minimap": [KEY_N],
	"voice": [KEY_B],
	"mute": [KEY_J],
	"toggle_help": [KEY_F1],
	"map": [KEY_M, KEY_TAB],
	"pause": [KEY_ESCAPE],
}
const MOUSE := {
	"fire": MOUSE_BUTTON_LEFT,
	"aim": MOUSE_BUTTON_RIGHT,
}


static func setup() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in KEYS[action]:
			if action == "phone" and key == KEY_UP:
				continue  # Pfeiltaste bleibt fürs Laufen
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in MOUSE:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE[action]
		InputMap.action_add_event(action, mb)

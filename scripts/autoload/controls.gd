extends Node
## Registers the input map in code so bindings live in one readable place.
## Keyboard and gamepad are both bound; Settings can rebind an action's first
## key and its first pad button (pass 365).

const DEADZONE := 0.35
## Pad bindings answer every pad. An event made in code belongs to device 0
## unless told otherwise, so a pad Windows numbered 1 (behind a Razer keypad or
## any other joystick-like device) was ignored in play.
const ANY_PAD := -1
## What the Controls page calls each pad button (Xbox names; a pad's own glyphs
## would come with art).
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Pad up", JOY_BUTTON_DPAD_DOWN: "Pad down",
	JOY_BUTTON_DPAD_LEFT: "Pad left", JOY_BUTTON_DPAD_RIGHT: "Pad right",
	JOY_BUTTON_MISC1: "Share", JOY_BUTTON_PADDLE1: "P1", JOY_BUTTON_PADDLE2: "P2",
	JOY_BUTTON_PADDLE3: "P3", JOY_BUTTON_PADDLE4: "P4", JOY_BUTTON_TOUCHPAD: "Touchpad",
}

const BINDINGS := {
	"move_left": {"keys": [KEY_LEFT, KEY_A], "buttons": [JOY_BUTTON_DPAD_LEFT], "axis": [JOY_AXIS_LEFT_X, -1.0]},
	"move_right": {"keys": [KEY_RIGHT, KEY_D], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axis": [JOY_AXIS_LEFT_X, 1.0]},
	"move_up": {"keys": [KEY_UP, KEY_W], "buttons": [JOY_BUTTON_DPAD_UP], "axis": [JOY_AXIS_LEFT_Y, -1.0]},
	"move_down": {"keys": [KEY_DOWN, KEY_S], "buttons": [JOY_BUTTON_DPAD_DOWN], "axis": [JOY_AXIS_LEFT_Y, 1.0]},
	"jump": {"keys": [KEY_SPACE, KEY_Z, KEY_K], "buttons": [JOY_BUTTON_A]},
	"attack": {"keys": [KEY_X, KEY_J], "buttons": [JOY_BUTTON_X]},
	"dash": {"keys": [KEY_C, KEY_L, KEY_SHIFT], "buttons": [JOY_BUTTON_B], "trigger": JOY_AXIS_TRIGGER_RIGHT},
	"throw": {"keys": [KEY_B, KEY_SEMICOLON], "buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	"block": {"keys": [KEY_V, KEY_I], "buttons": [JOY_BUTTON_LEFT_SHOULDER]},
	"spell": {"keys": [KEY_F, KEY_U], "buttons": [JOY_BUTTON_Y]},
	"spell_next": {"keys": [KEY_G, KEY_O], "buttons": [JOY_BUTTON_RIGHT_STICK]},
	"heal": {"keys": [KEY_Q, KEY_H], "trigger": JOY_AXIS_TRIGGER_LEFT},
	"stillstone": {"keys": [KEY_T, KEY_E], "buttons": [JOY_BUTTON_LEFT_STICK]},
	"map": {"keys": [KEY_TAB, KEY_M], "buttons": [JOY_BUTTON_BACK]},
	"pause": {"keys": [KEY_ESCAPE, KEY_P], "buttons": [JOY_BUTTON_START]},
	"debug_glove": {"keys": [KEY_F1]},
	"debug_delvers_pick": {"keys": [KEY_F2]},
	"debug_boots": {"keys": [KEY_F3]},
	"debug_stride": {"keys": [KEY_F4]},
	"debug_reset": {"keys": [KEY_F5, KEY_R]},
	"debug_hud": {"keys": [KEY_F6]},
	"debug_torrent": {"keys": [KEY_F7]},
}


func _ready() -> void:
	restore_defaults()


## Rebuilds every action from BINDINGS.
func restore_defaults() -> void:
	for action: String in BINDINGS:
		var spec: Dictionary = BINDINGS[action]
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, DEADZONE)
		for key: Key in spec.get("keys", []):
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for button: JoyButton in spec.get("buttons", []):
			var jb := InputEventJoypadButton.new()
			jb.device = ANY_PAD
			jb.button_index = button
			InputMap.action_add_event(action, jb)
		if spec.has("axis"):
			var jm := InputEventJoypadMotion.new()
			jm.device = ANY_PAD
			jm.axis = spec["axis"][0]
			jm.axis_value = spec["axis"][1]
			InputMap.action_add_event(action, jm)
		if spec.has("trigger"):
			var jt := InputEventJoypadMotion.new()
			jt.device = ANY_PAD
			jt.axis = spec["trigger"]
			jt.axis_value = 1.0
			InputMap.action_add_event(action, jt)


## The physical keycode of an action's first key (0 if it has none).
func primary_key(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return int((ev as InputEventKey).physical_keycode)
	return 0


## Makes `keycode` the action's first key, replacing the default first key.
## Any other action that also had that key loses it.
func rebind(action: String, keycode: int) -> void:
	for other: String in BINDINGS:
		if other == action:
			continue
		for ev in InputMap.action_get_events(other):
			if ev is InputEventKey and int((ev as InputEventKey).physical_keycode) == keycode:
				InputMap.action_erase_event(other, ev)
	var first: InputEvent = null
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			first = ev
			break
	if first != null:
		InputMap.action_erase_event(action, first)
	var key := InputEventKey.new()
	key.physical_keycode = keycode as Key
	InputMap.action_add_event(action, key)
	# Put it back first: the menus show and swap the first key.
	var events := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, key)
	for ev in events:
		if ev != key:
			InputMap.action_add_event(action, ev)


## A short name for the key an action uses ("Space", "X").
func key_name(action: String) -> String:
	var code := primary_key(action)
	return OS.get_keycode_string(code as Key) if code != 0 else "-"


## An action's first pad button (-1 if it has none; the heal sits on a trigger).
func primary_button(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			return int((ev as InputEventJoypadButton).button_index)
	return -1


## Makes `button` the action's first pad button, replacing its default one.
## Any other action that also had that button loses it.
func rebind_button(action: String, button: int) -> void:
	for other: String in BINDINGS:
		if other == action:
			continue
		for ev in InputMap.action_get_events(other):
			if ev is InputEventJoypadButton and int((ev as InputEventJoypadButton).button_index) == button:
				InputMap.action_erase_event(other, ev)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			InputMap.action_erase_event(action, ev)
			break
	var jb := InputEventJoypadButton.new()
	jb.device = ANY_PAD
	jb.button_index = button as JoyButton
	var events := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	# Keys stay ahead of it, so key_name still reads the first key.
	for ev in events:
		if ev is InputEventKey:
			InputMap.action_add_event(action, ev)
	InputMap.action_add_event(action, jb)
	for ev in events:
		if not ev is InputEventKey:
			InputMap.action_add_event(action, ev)


## A short name for the pad button an action uses ("A", "LB"), or the trigger.
func button_name(action: String) -> String:
	var b := primary_button(action)
	if b >= 0:
		return PAD_NAMES.get(b, "Button %d" % b)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion and (ev as InputEventJoypadMotion).axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			return "LT" if (ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_LEFT else "RT"
	return "-"

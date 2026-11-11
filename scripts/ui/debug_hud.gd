class_name DebugHud
extends CanvasLayer
## Prototype overlay: ability toggles, live movement readouts and controls.

var player: Player
var _label: Label


func _ready() -> void:
	layer = 10
	_label = Label.new()
	_label.position = Vector2(6, 54)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color("f1ead2"))
	_label.add_theme_color_override("font_outline_color", Color("1d1a2b"))
	_label.add_theme_constant_override("outline_size", 3)
	add_child(_label)


func _process(_delta: float) -> void:
	if player == null:
		return
	var a := player.abilities
	var on := func(k: String) -> String: return "ON " if a[k] else "off"
	_label.text = "vel %4d,%4d   %s   combo %d\n" % [player.velocity.x, player.velocity.y, PlayerVisual.current_pose(player), player.combo_index] \
		+ "F1 Glove %s  F2 Delver's Pick %s  F3 Featherstep Boots %s  F4 Elven Stride %s  F7 Deluge %s\n" % [on.call("glove"), on.call("delvers_pick"), on.call("boots"), on.call("stride"), on.call("torrent")] \
		+ "Move: arrows/WASD  Crouch: Down  Jump: Space/Z  Attack: X  Dash: C  Block/parry: V  Spell: F  Potion: Q\nReset: R  Hide this: F6"

extends Node
## Draws every zone's chest, closed and open, at 4x to one PNG (pass 595).
## Run: <godot> --headless --path . res://tools/art/chest_sheet.tscn -- --out=OUT.png


func _ready() -> void:
	var out := "user://chests.png"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var zones: Array = Chest.LOOKS.keys()
	var cell := 64
	var scale := 4
	var img := Image.create(zones.size() * cell * scale, 2 * cell * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color("3a3a48"))
	for i in zones.size():
		for row in 2:
			var ox := i * cell + cell / 2
			var oy := row * cell + cell - 6
			for q: Array in Chest.parts(Chest.look_for(zones[i]), row == 1):
				var col := Color(String(q[4]))
				# Half-pixels: render at 2x then scale 2 more (4x of world).
				for y in range(int(q[1]), int(q[1]) + int(q[3])):
					for x in range(int(q[0]), int(q[0]) + int(q[2])):
						var px := (ox * 2 + x) * scale / 2
						var py := (oy * 2 + y) * scale / 2
						img.fill_rect(Rect2i(px, py, scale / 2, scale / 2), col)
	img.save_png(out)
	print("wrote ", out, " zones: ", zones)
	get_tree().quit()

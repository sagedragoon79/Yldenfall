extends Node
## Prints rooms with the reach checker's standing spots marked, for building and fixing
## layouts (pass 508). Each reachable standing spot shows as `▪` over the room's grid; every
## other cell keeps its legend character. Abilities are a comma list (as in tests/test_reachability.gd).
##
## Usage: <godot> --headless --path . res://tools/levels/reach_map.tscn -- [<room> ...] [--abilities=glove,boots]
## With no rooms named it lists the rooms those abilities never reach. `--alone` maps one room by
## itself from its own start (`P`), as the trials are checked.


func _ready() -> void:
	var rooms: Array[String] = []
	var abilities := {"glove": true}
	var alone := false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--alone":
			alone = true
		elif arg.begins_with("--abilities="):
			abilities = {}
			for a in arg.trim_prefix("--abilities=").split(",", false):
				abilities[a] = true
		else:
			rooms.append(arg)
	var texts := {}
	for zone: String in DirAccess.get_directories_at("res://levels"):
		if zone in World.OFF_MAP:
			continue
		for file: String in DirAccess.get_files_at("res://levels/" + zone):
			if file.ends_with(".room"):
				texts[zone + "/" + file.trim_suffix(".room")] = FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, file])
	if alone:
		# Just the named room, from its own start (a Ringreader trial, off the map).
		texts = {rooms[0]: FileAccess.get_file_as_string("res://levels/%s.room" % rooms[0])}
	var reach := Reach.new(texts, abilities, not alone)
	var nodes := reach.reachable(reach.spot_of(rooms[0] if alone else "hearthroot/west_gate", "P"))
	if rooms.is_empty():
		# No rooms named: list the rooms these abilities never reach.
		var seen := {}
		for k: String in nodes:
			seen[Reach.unkey(k)[0]] = true
		print("not reached: ", reach.rooms.keys().filter(func(id: String) -> bool: return not seen.has(id)))
	for id in rooms:
		var g: Array[String] = reach.rooms[id].grid
		print("== %s (%s)" % [id, ", ".join(abilities.keys())])
		for y in g.size():
			var row := ""
			for x in g[y].length():
				row += "▪" if nodes.has(Reach.key(id, x, y)) else g[y][x]
			print("%3d %s" % [y, row])
	get_tree().quit()

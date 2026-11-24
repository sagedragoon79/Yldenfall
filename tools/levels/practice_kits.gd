extends Node
## Counts the stat finds (Life Fruit, Mana Dew, Potion Shard, Stillglass Shard) a
## thorough player can hold on reaching each guardian of the boss rush: the reach
## checker walks the rooms with what the critical path (bible 4.2) gives before
## the guardian's arena opens. Boss practice (BossPractice.KITS) bakes these in.
## Run: godot --headless --path . res://tools/levels/practice_kits.tscn

const ACT := ["glove", "amber", "delvers_pick", "winch", "boots", "lantern", "torrent", "spring_haar", "stride", "fire", "thunder", "sky_spring", "sky_key", "stillstone"]
const START := "hearthroot/west_gate"
const STATS := "LWF("


func _ready() -> void:
	var texts := {}
	for zone: String in DirAccess.get_directories_at("res://levels"):
		if zone in World.OFF_MAP:
			continue
		for file: String in DirAccess.get_files_at("res://levels/" + zone):
			if file.ends_with(".room"):
				texts[zone + "/" + file.trim_suffix(".room")] = FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, file])
	var cache := {}
	for row: Array in BossRush.ORDER:
		var arena: String = row[1]
		for n in ACT.size() + 1:
			var kit := {}
			for a: String in ACT.slice(0, n):
				kit[a] = true
			if not cache.has(n):
				var reach := Reach.new(texts, kit, true)
				cache[n] = [reach, reach.reachable(reach.spot_of(START, "P"))]
			var reach: Reach = cache[n][0]
			var nodes: Dictionary = cache[n][1]
			var rooms := {}
			for k: String in nodes:
				rooms[Reach.unkey(k)[0]] = true
			if not rooms.has(arena):
				continue
			var counts := {"L": 0, "W": 0, "F": 0, "(": 0}
			for id: String in reach.rooms:
				var g: Array = reach.rooms[id].grid
				var finds: Array = []
				for y in g.size():
					for x in String(g[y]).length():
						if STATS.contains(String(g[y])[x]):
							finds.append([String(g[y])[x], x, y])
				for f: Array in reach.rooms[id].finds:
					if STATS.contains(String(f[0])):
						finds.append(f)
				for f: Array in finds:
					if reach.touchable(nodes, id, f[1], f[2]):
						counts[f[0]] += 1
			print("%s\tact=%s\tlife=%d dew=%d shard=%d stillglass=%d" % [row[0], ACT.slice(0, n), counts.L, counts.W, counts.F, counts["("]])
			break
	get_tree().quit()

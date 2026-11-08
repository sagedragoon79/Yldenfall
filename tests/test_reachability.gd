extends TestSuite
## The reachability checker on the real rooms (design bible 14): the critical
## path works in order, every pickup can be reached, ability gates hold, and
## no reachable spot is a soft-lock.

const START_ROOM := "hearthroot/west_gate"
const PICKUPS := "GXOdhnzLWF*$SN&{(}:"
## Secrets that only open once the Heartwood Spring hardens the sap (bible 4.4):
## [room, tile x, tile y].
const AMBER_SECRETS := [["heartwood/amber_falls", 31, 13]]
## Caches behind cracked stone outside the Delver's Pick rooms (pass 135): the town
## shows you one from the first step, and only the Delver's Pick opens it.
const DELVERS_PICK_SECRETS := [["hearthroot/west_gate", 2, 20]]
## Pickups only a second jump reaches, once the Featherstep Boots are found (bible 4.1, A3).
## The Sky Steps' purse sits on the climb's first island, a boots leap up from the
## one below (pass 211: it had been listed as the Stride's). Pass 219 raised the
## island a row: at four rows a plain jump landed on it (test_abilities.gd).
const BOOT_SECRETS := [["haar/feather_hollow", 18, 6], ["spires/sky_steps", 6, 19]]
## Pickups only an air dash reaches, once the Elven Stride is found (bible 4.1, A5),
## even with the Featherstep Boots, which always come first: behind an elven veil (pass 216;
## the gap of pass 211 was crossed by a real jump).
const STRIDE_SECRETS := [["boughs/north_bough", 2, 6]]
## Critical-path pickups only the Featherstep Boots' second jump reaches (pass 232):
## the Elven Stride hangs in the Windloft's open air, nine rows over the floor and
## far from any wall, so the Boots must come before the Stride.
const BOOT_GATES := [["boughs/windloft", 24, 11]]
## Pickups only the High Boughs' wind reaches once the Sky Spring turns it
## (bible 6.9, the "sky_spring" ability): the elves' wind-niche over the Thicket Road.
const WIND_SECRETS := [["boughs/thicket_road", 38, 8]]
## Pickups behind bramble, which only the Emberfall spell burns away (bible 4.5).
const FIRE_SECRETS := [["spires/spires", 76, 19]]
## Caches behind cracked stone seals, which only a Lithic Fracture cast shatters
## (bible 4.5, pass 497): [room, tile x, tile y]. Optional, off the critical path.
const FRACTURE_SECRETS := [["hearthroot/west_gate", 24, 20], ["heartwood/dwarf_larder", 6, 19],
	["tower/ore_vault", 20, 20], ["tower/old_flue", 35, 39]]
## Rooms beyond cracked stone, open only once the Foreman gives up the Delver's Pick,
## or above the flue damper, open once Durgan falls (the "winch" ability),
## and the Haar, reached by the ore road east of the Deep Workings (its rooms
## past the bound fog also need the Lantern Key: the "lantern" ability).
const DELVERS_PICK_ROOMS := ["tower/old_flue", "tower/rafters", "tower/kettleforge_stair", "tower/kettleforge_gate", "tower/kettleforge_lift", "tower/kettleforge", "tower/ore_vault",
	"tower/mine_mouth", "tower/mine_shaft", "tower/rail_gallery", "tower/mine_vault", "tower/smelter", "tower/sorting_floor", "tower/slag_heap",
	"tower/crown_lookout", "tower/bell_loft", "haar/fog_cut", "haar/drowned_stair", "haar/lantern_landing", "haar/sunken_chapel",
	"haar/veiled_rise", "haar/lampwick_causeway", "haar/feather_hollow", "haar/lampwick", "haar/polesend", "haar/hag_mire", "haar/marsh_road", "haar/scorched_hall", "haar/dry_cistern",
	"haar/spring_of_haar", "boughs/windward_climb", "boughs/sunlit_bough", "boughs/leaf_landing", "boughs/thicket_road", "boughs/canopy_bridge", "boughs/sylvarre", "boughs/thorn_yard",
	"boughs/north_bough", "boughs/windloft", "boughs/crown_leaf", "spires/storm_ledge", "spires/sky_steps",
	"spires/broken_shrine", "spires/fallen_bridge", "spires/spires", "spires/spire_foot", "spires/spire_stair", "spires/roost", "spires/sky_spring", "vorrhallow/upper_stair", "vorrhallow/gate_hall", "vorrhallow/flooded_hall", "vorrhallow/sunken_stair", "vorrhallow/seers_lens_crypt", "vorrhallow/drowned_nave", "vorrhallow/waterfall_stair", "vorrhallow/drowned_market", "vorrhallow/kings_stair", "vorrhallow/kings_kennels", "vorrhallow/alpha_den", "vorrhallow/throne_hall", "vorrhallow/meteor_rise", "vorrhallow/evercrown_gate", "evercrown/threshold", "evercrown/heart_stair", "evercrown/drift_well", "evercrown/heart_gate", "evercrown/proving_scar", "evercrown/throne", "evercrown/veins", "evercrown/heart", "sunken/spring_gate", "sunken/drowned_aqueduct", "sunken/source_hall", "sunken/wellspring"]
## Rooms past an air-dash gap: open only with the Elven Stride (above Carillon's
## Sky Steps, bible 3.2). The Stride test checks them. Since pass 388 the
## Windloft's veil bars the Crown-Leaf, so Snapcrown's arena and the way on to
## Carillon (the Storm Ledge and the Sky Steps) need it too (bible 8.5).
const STRIDE_ROOMS := ["boughs/crown_leaf", "spires/storm_ledge", "spires/sky_steps", "spires/broken_shrine", "spires/fallen_bridge", "spires/spires", "spires/spire_foot"]
## Rooms past a conduit gate: open only once Tempest Lance wakes the conduits (bible 4.1, A6).
const THUNDER_ROOMS := ["spires/spire_stair", "spires/roost", "spires/sky_spring", "vorrhallow/upper_stair", "vorrhallow/gate_hall", "vorrhallow/flooded_hall", "vorrhallow/sunken_stair", "vorrhallow/seers_lens_crypt", "vorrhallow/drowned_nave", "vorrhallow/waterfall_stair", "vorrhallow/drowned_market", "vorrhallow/kings_stair", "vorrhallow/kings_kennels", "vorrhallow/alpha_den", "vorrhallow/throne_hall", "vorrhallow/meteor_rise", "vorrhallow/evercrown_gate", "evercrown/threshold", "evercrown/heart_stair", "evercrown/drift_well", "evercrown/heart_gate", "evercrown/proving_scar", "evercrown/throne", "evercrown/veins", "evercrown/heart", "sunken/spring_gate", "sunken/drowned_aqueduct", "sunken/source_hall", "sunken/wellspring"]


func _texts() -> Dictionary:
	var out := {}
	for zone: String in DirAccess.get_directories_at("res://levels"):
		# The trials are entered through the Ringreader's menu, not doors: tested on their own.
		if zone in World.OFF_MAP:
			continue
		for file: String in DirAccess.get_files_at("res://levels/" + zone):
			if file.ends_with(".room"):
				out[zone + "/" + file.trim_suffix(".room")] = FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, file])
	return out


func _rooms_reached(nodes: Dictionary) -> Dictionary:
	var out := {}
	for k: String in nodes:
		out[Reach.unkey(k)[0]] = true
	return out


## Every pickup marker in the rooms: [room, char, x, y].
func _pickups(reach: Reach) -> Array:
	var out := []
	for id: String in reach.rooms:
		var g: Array[String] = reach.rooms[id].grid
		for y in g.size():
			for x in g[y].length():
				if PICKUPS.contains(g[y][x]):
					out.append([id, g[y][x], x, y])
		# Pass 203: the finds a `prop:` line lays are pickups too.
		for f: Array in reach.rooms[id].finds:
			out.append([id, f[0], f[1], f[2]])
	return out


func _save_spots(reach: Reach) -> Array:
	var out := [reach.spot_of(START_ROOM, "P")]
	for id: String in reach.rooms:
		var spot := reach.spot_of(id, "S")
		if spot != "":
			out.append(spot)
	return out


func test_start_spot_exists() -> void:
	var reach := Reach.new(_texts(), {})
	check(reach.spot_of(START_ROOM, "P") != "", "the new game spawn is a standing spot")


func test_glove_reachable_without_abilities() -> void:
	var reach := Reach.new(_texts(), {})
	var nodes := reach.reachable(reach.spot_of(START_ROOM, "P"))
	var glove := false
	for p: Array in _pickups(reach):
		if p[1] == "G":
			glove = reach.touchable(nodes, p[0], p[2], p[3])
	check(glove, "the Climbing Glove can be reached with no abilities")
	var rooms := _rooms_reached(nodes)
	check(not rooms.has("heartwood/root_chamber"), "the boss is behind the glove gate")
	check(rooms.has("hearthroot/king_hall") and rooms.has("hearthroot/ringreader_temple") and rooms.has("hearthroot/market"), "all of Hearthroot is open from the start")


func test_no_soft_locks_before_the_glove() -> void:
	var reach := Reach.new(_texts(), {})
	var nodes := reach.reachable(reach.spot_of(START_ROOM, "P"))
	var goals := _save_spots(reach)
	goals.append(reach.spot_of("heartwood/glove_shrine", "G"))
	var stuck := reach.stuck(nodes, goals)
	check(stuck.is_empty(), "every spot reachable without the glove can get back to a save or on to the glove: %s" % [stuck.slice(0, 6)])


func test_with_glove_everything_is_reachable() -> void:
	var reach := Reach.new(_texts(), {"glove": true}, true)
	var nodes := reach.reachable(reach.spot_of(START_ROOM, "P"))
	var rooms := _rooms_reached(nodes)
	var missing_rooms: Array[String] = []
	for id: String in reach.rooms:
		if not rooms.has(id) and not DELVERS_PICK_ROOMS.has(id):
			missing_rooms.append(id)
	check(missing_rooms.is_empty(), "with the glove and keys every room is reachable: missing %s" % [missing_rooms])
	var missing: Array = []
	for p: Array in _pickups(reach):
		if not reach.touchable(nodes, p[0], p[2], p[3]) and not AMBER_SECRETS.has([p[0], p[2], p[3]]) and not DELVERS_PICK_ROOMS.has(p[0]) \
				and not WIND_SECRETS.has([p[0], p[2], p[3]]) and not DELVERS_PICK_SECRETS.has([p[0], p[2], p[3]]) \
				and not FRACTURE_SECRETS.has([p[0], p[2], p[3]]):
			missing.append(p)
	check(missing.is_empty(), "every pickup, chest and shrine is reachable: missing %s" % [missing])
	var opened := DELVERS_PICK_ROOMS.filter(func(id: String) -> bool: return rooms.has(id))
	check(opened.is_empty(), "the cracked stone keeps the Delver's Pick rooms shut: %s" % [opened])


func test_amber_secrets_need_the_spring() -> void:
	var reach := Reach.new(_texts(), {"glove": true}, true)
	var nodes := reach.reachable(reach.spot_of(START_ROOM, "P"))
	for s: Array in AMBER_SECRETS:
		check(not reach.touchable(nodes, s[0], s[1], s[2]), "%s is out of reach until the sap hardens" % [s])


func test_delvers_pick_secrets_need_the_delvers_pick() -> void:
	var reach := Reach.new(_texts(), {"glove": true, "amber": true}, true)
	var nodes := reach.reachable(reach.spot_of(START_ROOM, "P"))
	var dug := Reach.new(_texts(), {"glove": true, "amber": true, "delvers_pick": true}, true)
	var dug_nodes := dug.reachable(dug.spot_of(START_ROOM, "P"))
	for s: Array in DELVERS_PICK_SECRETS:
		check(not reach.touchable(nodes, s[0], s[1], s[2]), "%s waits behind cracked stone" % [s])
		check(dug.touchable(dug_nodes, s[0], s[1], s[2]), "%s opens to the Delver's Pick" % [s])


## The caches behind cracked stone seals open only to a Lithic Fracture cast, and
## the scroll that teaches it lies open in the Kettleforge tower (pass 497).
func test_fracture_caches_need_the_fracture_spell() -> void:
	var base := {"glove": true, "delvers_pick": true, "amber": true, "winch": true, "lantern": true, "torrent": true}
	var reach := Reach.new(_texts(), base, true)
	var nodes := reach.reachable(reach.spot_of(START_ROOM, "P"))
	var cast := base.duplicate()
	cast["fracture"] = true
	var broken := Reach.new(_texts(), cast, true)
	var broken_nodes := broken.reachable(broken.spot_of(START_ROOM, "P"))
	check(not FRACTURE_SECRETS.is_empty() and FRACTURE_SECRETS.size() >= 4, "four to six caches across several zones (%d)" % FRACTURE_SECRETS.size())
	for s: Array in FRACTURE_SECRETS:
		check(not reach.touchable(nodes, s[0], s[1], s[2]), "%s waits behind a cracked stone seal" % [s])
		check(broken.touchable(broken_nodes, s[0], s[1], s[2]), "%s opens to Lithic Fracture" % [s])
	# The scroll itself is reachable without the spell, in the Kettleforge tower.
	var scroll_ok := false
	for p: Array in _pickups(reach):
		if p[1] == ":":
			scroll_ok = reach.touchable(nodes, p[0], p[2], p[3]) and p[0].begins_with("tower/")
	check(scroll_ok, "the Lithic Fracture scroll can be reached without the spell, in the Kettleforge tower")


func test_no_soft_locks_with_glove() -> void:
	var reach := Reach.new(_texts(), {"glove": true}, true)
	var nodes := reach.reachable(reach.spot_of(START_ROOM, "P"))
	var stuck := reach.stuck(nodes, _save_spots(reach))
	check(stuck.is_empty(), "with the glove, every reachable spot can get back to a save: %s" % [stuck.slice(0, 6)])


func test_amber_keeps_everything_reachable() -> void:
	# After the Heartwood Spring, sap is solid amber: nothing may be cut off.
	var reach := Reach.new(_texts(), {"glove": true, "amber": true}, true)
	var nodes := reach.reachable(reach.spot_of(START_ROOM, "P"))
	var missing: Array = []
	for p: Array in _pickups(reach):
		if not reach.touchable(nodes, p[0], p[2], p[3]) and not DELVERS_PICK_ROOMS.has(p[0]) and not WIND_SECRETS.has([p[0], p[2], p[3]]) \
				and not DELVERS_PICK_SECRETS.has([p[0], p[2], p[3]]) and not FRACTURE_SECRETS.has([p[0], p[2], p[3]]):
			missing.append(p)
	check(missing.is_empty(), "with amber, every pickup is still reachable: missing %s" % [missing])
	var stuck := reach.stuck(nodes, _save_spots(reach))
	check(stuck.is_empty(), "with amber, no soft-locks: %s" % [stuck.slice(0, 6)])


func test_with_the_delvers_pick_everything_is_reachable() -> void:
	# The Act I set: glove, Delver's Pick (from the Foreman), keys, the Spring restored,
	# Durgan beaten (the winch opens the flue damper) and Gloamweaver's Lantern Key.
	var reach := Reach.new(_texts(), {"glove": true, "delvers_pick": true, "amber": true, "winch": true, "lantern": true, "torrent": true}, true)
	var nodes := reach.reachable(reach.spot_of(START_ROOM, "P"))
	var rooms := _rooms_reached(nodes)
	var missing_rooms: Array[String] = []
	for id: String in reach.rooms:
		if not rooms.has(id) and not STRIDE_ROOMS.has(id) and not THUNDER_ROOMS.has(id):
			missing_rooms.append(id)
	check(missing_rooms.is_empty(), "with the Delver's Pick every room is reachable: missing %s" % [missing_rooms])
	check(STRIDE_ROOMS.all(func(id: String) -> bool: return not rooms.has(id)), "but not the sky islands past the air-dash gaps")
	var missing: Array = []
	for p: Array in _pickups(reach):
		if not reach.touchable(nodes, p[0], p[2], p[3]) and not BOOT_SECRETS.has([p[0], p[2], p[3]]) and not BOOT_GATES.has([p[0], p[2], p[3]]) \
				and not STRIDE_SECRETS.has([p[0], p[2], p[3]]) and not STRIDE_ROOMS.has(p[0]) and not THUNDER_ROOMS.has(p[0]) and not WIND_SECRETS.has([p[0], p[2], p[3]]) \
				and not FRACTURE_SECRETS.has([p[0], p[2], p[3]]):
			missing.append(p)
	check(missing.is_empty(), "with the Delver's Pick every pickup is reachable: missing %s" % [missing])
	var stuck := reach.stuck(nodes, _save_spots(reach))
	check(stuck.is_empty(), "with the Delver's Pick, no soft-locks: %s" % [stuck.slice(0, 6)])


func test_bound_fog_holds_until_the_lantern_key() -> void:
	# Bible 4.4: the Lantern Key opens the way past Lantern Landing. Without it
	# the bound fog seals the shaft, and the rooms above stay out of reach.
	var set := {"glove": true, "delvers_pick": true, "amber": true, "winch": true}
	var shut := Reach.new(_texts(), set, true)
	var rooms := _rooms_reached(shut.reachable(shut.spot_of(START_ROOM, "P")))
	check(rooms.has("haar/lantern_landing") and rooms.has("haar/sunken_chapel"), "the landing and the chapel are open without the key")
	check(not rooms.has("haar/veiled_rise") and not rooms.has("haar/lampwick_causeway"), "but the bound fog keeps the Veiled Rise shut")
	set["lantern"] = true
	var open := Reach.new(_texts(), set, true)
	var opened := _rooms_reached(open.reachable(open.spot_of(START_ROOM, "P")))
	check(opened.has("haar/veiled_rise") and opened.has("haar/lampwick_causeway"), "with the Lantern Key the shaft climbs to the causeway")
	check(not rooms.has("haar/lampwick") and opened.has("haar/lampwick"), "and on past the Feather Hollow to Lampwick")


func test_polesend_lies_across_the_black_water() -> void:
	# Pass 148: Polesend lies under the Scorched Hall, down a ladder shaft and
	# across the black water. Before the Haar Spring its drowned boardwalks
	# are nothing to stand on: only pogoing along the spikes with the Delver's Pick and
	# climbing the far side with the Glove gets you over (a skill route, like the
	# Storm Ledge's). Once the spring flows they rise and the town is a walk.
	var set := {"glove": true, "delvers_pick": true, "amber": true, "winch": true, "lantern": true, "torrent": true}
	var dry := Reach.new(_texts(), set, true)
	check(not dry.supported("haar/polesend", 20, 16), "before the spring the boardwalks are drowned")
	var before := dry.reachable(dry.spot_of(START_ROOM, "P"))
	check(dry.touchable(before, "haar/polesend", 4, 16), "the road's landing is reached down the shaft")
	check(dry.touchable(before, "haar/scorched_hall", 5, 19), "and the ladder climbs back out")
	set["spring_haar"] = true
	var wet := Reach.new(_texts(), set, true)
	check(wet.supported("haar/polesend", 20, 16), "with the spring the boardwalks rise")
	var after := wet.reachable(wet.spot_of(START_ROOM, "P"))
	var people := 0
	for line: String in _texts()["haar/polesend"].split("\n"):
		if line.begins_with("npc:"):
			var parts := line.substr(4).split(",")
			people += 1
			check(dry.touchable(before, "haar/polesend", int(parts[0]), int(parts[1])) and wet.touchable(after, "haar/polesend", int(parts[0]), int(parts[1])),
				"%s can be reached, before the spring and after" % parts[2].strip_edges())
	check(people >= 4, "Polesend has its people (%d)" % people)


func test_the_pendant_and_the_rod_can_be_reached() -> void:
	# Pass 201: the source game's two relics, laid by `prop:` lines: the Acorn Charm
	# on the Matriarch's floor, the Rod on Sylvarre's high plank by the ladder.
	# The Haar's set reaches both (the sweeps check them too since pass 203).
	var set := {"glove": true, "delvers_pick": true, "amber": true, "winch": true, "lantern": true, "torrent": true, "boots": true}
	var reach := Reach.new(_texts(), set, true)
	var nodes := reach.reachable(reach.spot_of(START_ROOM, "P"))
	for room_id: String in _texts():
		for line: String in _texts()[room_id].split("\n"):
			if line.begins_with("prop:") and (line.ends_with("pendant") or line.ends_with("briar_wand")):
				var parts := line.substr(5).split(",")
				check(reach.touchable(nodes, room_id, int(parts[0]), int(parts[1])), "%s in %s can be reached" % [parts[2].strip_edges(), room_id])


func test_everyone_in_lampwick_can_be_reached() -> void:
	# Pass 145: Lampwick, the Haar's lamp town, is reached by the Feather Hollow's
	# west shelf with no more than the Lantern Key, and every person in it can be
	# spoken to, the fogwalker on his loft too.
	var set := {"glove": true, "delvers_pick": true, "amber": true, "winch": true, "lantern": true}
	var reach := Reach.new(_texts(), set, true)
	var nodes := reach.reachable(reach.spot_of(START_ROOM, "P"))
	var people := 0
	for line: String in _texts()["haar/lampwick"].split("\n"):
		if line.begins_with("npc:"):
			var parts := line.substr(4).split(",")
			people += 1
			check(reach.touchable(nodes, "haar/lampwick", int(parts[0]), int(parts[1])), "%s can be reached" % parts[2].strip_edges())
	check(people >= 5, "Lampwick has its people (%d)" % people)


func test_featherstep_boots_reach_the_high_perch() -> void:
	# Bible 4.1 (A3): the Featherstep Boots wait in Feather Hollow, reachable without
	# them; the Life Fruit on the perch above is six rows up, past any single jump.
	var set := {"glove": true, "delvers_pick": true, "amber": true, "winch": true, "lantern": true, "torrent": true}
	var bare := Reach.new(_texts(), set, true)
	var nodes := bare.reachable(bare.spot_of(START_ROOM, "P"))
	check(bare.touchable(nodes, "haar/feather_hollow", 30, 15), "the Featherstep Boots can be reached without them")
	for s: Array in BOOT_SECRETS + BOOT_GATES:
		check(not bare.touchable(nodes, s[0], s[1], s[2]), "%s is out of reach without the Featherstep Boots" % [s])
	set["boots"] = true
	var reach := Reach.new(_texts(), set, true)
	var with_boots := reach.reachable(reach.spot_of(START_ROOM, "P"))
	var missing: Array = []
	for p: Array in _pickups(reach):
		if not reach.touchable(with_boots, p[0], p[2], p[3]) and not STRIDE_SECRETS.has([p[0], p[2], p[3]]) and not STRIDE_ROOMS.has(p[0]) \
				and not THUNDER_ROOMS.has(p[0]) and not WIND_SECRETS.has([p[0], p[2], p[3]]) and not FRACTURE_SECRETS.has([p[0], p[2], p[3]]):
			missing.append(p)
	check(missing.is_empty(), "with the Featherstep Boots every pickup is reachable: missing %s" % [missing])
	var stuck := reach.stuck(with_boots, _save_spots(reach))
	check(stuck.is_empty(), "with the Featherstep Boots, no soft-locks: %s" % [stuck.slice(0, 6)])


func test_fire_seal_and_dry_basin_hold_until_torrent() -> void:
	# Bible 4.1 (A4) and 4.5: the Deluge scroll lies on the Marsh Road before
	# the fire seal, and the seal keeps the Scorched Hall shut until water douses it.
	var set := {"glove": true, "delvers_pick": true, "amber": true, "winch": true, "lantern": true}
	var dry := Reach.new(_texts(), set, true)
	var nodes := dry.reachable(dry.spot_of(START_ROOM, "P"))
	var rooms := _rooms_reached(nodes)
	check(rooms.has("haar/marsh_road") and dry.touchable(nodes, "haar/marsh_road", 21, 14), "the Deluge scroll can be reached without it")
	check(not rooms.has("haar/scorched_hall"), "but the fire seal keeps the Scorched Hall shut")
	set["torrent"] = true
	var wet := Reach.new(_texts(), set, true)
	var wet_nodes := wet.reachable(wet.spot_of(START_ROOM, "P"))
	check(_rooms_reached(wet_nodes).has("haar/scorched_hall"), "with Deluge the road east opens")
	check(wet.touchable(wet_nodes, "haar/dry_cistern", 18, 7), "and the raft floats up to the cistern shelf")


func test_checker_floats_the_basin_raft_only_with_torrent() -> void:
	# A dry tank too wide to jump, a shelf over its middle: only the raft reaches it.
	var rows := grid_rows(40, 23)
	put_tiles(rows, 3, 19, "P")
	put_tiles(rows, 2, 16, "-", 3, 1)
	put_tiles(rows, 6, 13, "#", 1, 7)
	put_tiles(rows, 31, 13, "#", 1, 7)
	put_tiles(rows, 7, 19, "u", 24, 1)
	put_tiles(rows, 7, 13, "=", 24, 1)
	put_tiles(rows, 17, 8, "-", 4, 1)
	put_tiles(rows, 18, 7, "W")
	var texts := {"t/tank": room_text(["name: Tank"], rows)}
	for kit: Dictionary in [{"glove": true}, {"glove": true, "boots": true}]:
		var dry := Reach.new(texts, kit)
		check(not dry.touchable(dry.reachable(dry.spot_of("t/tank", "P")), "t/tank", 18, 7), "the shelf is out of reach while the tank is dry (%s)" % [kit.keys()])
	var wet := Reach.new(texts, {"glove": true, "torrent": true})
	check(wet.touchable(wet.reachable(wet.spot_of("t/tank", "P")), "t/tank", 18, 7), "with Deluge the raft floats up to it")


func test_checker_stands_on_drowned_boardwalks_only_after_the_spring() -> void:
	# A spiked dip too wide to jump, a drowned boardwalk over it, a fruit past it.
	var rows := grid_rows(40, 23)
	put_tiles(rows, 3, 19, "P")
	put_tiles(rows, 8, 20, ".", 22, 2)
	put_tiles(rows, 8, 21, "^", 22, 1)
	put_tiles(rows, 8, 20, "b", 22, 1)
	put_tiles(rows, 34, 19, "L")
	var texts := {"t/dip": room_text(["name: Dip"], rows)}
	var dry := Reach.new(texts, {"glove": true})
	check(not dry.touchable(dry.reachable(dry.spot_of("t/dip", "P")), "t/dip", 34, 19), "the drowned boardwalk is nothing to stand on")
	var risen := Reach.new(texts, {"glove": true, "spring_haar": true})
	check(risen.touchable(risen.reachable(risen.spot_of("t/dip", "P")), "t/dip", 34, 19), "once the spring flows it carries you across")


func test_checker_stands_on_hidden_planks_without_the_seers_lens() -> void:
	# Hidden planks are always there; the Seer's Lens only shows them.
	var rows := grid_rows(40, 23)
	put_tiles(rows, 3, 19, "P")
	put_tiles(rows, 8, 20, ".", 22, 2)
	put_tiles(rows, 8, 21, "^", 22, 1)
	put_tiles(rows, 8, 20, "i", 22, 1)
	put_tiles(rows, 34, 19, "L")
	var texts := {"t/dip": room_text(["name: Dip"], rows)}
	var blind := Reach.new(texts, {"glove": true})
	check(blind.touchable(blind.reachable(blind.spot_of("t/dip", "P")), "t/dip", 34, 19), "the unseen planks carry you across")


func test_checker_climbs_falling_water_only_with_the_stillstone() -> void:
	# A shaft full of falling water, a fruit at its top: it beats you back down
	# until the Stillstone freezes it into footholds (bible A8).
	var rows := grid_rows(40, 23)
	put_tiles(rows, 0, 4, "#", 40, 16)
	# Passages four tiles tall for the 2x hero (Reach.BODY_ROWS, pass 508).
	put_tiles(rows, 1, 16, ".", 12, 4)
	put_tiles(rows, 3, 19, "P")
	put_tiles(rows, 13, 4, "f", 3, 16)
	put_tiles(rows, 16, 4, ".", 10, 4)
	put_tiles(rows, 22, 7, "L")
	var texts := {"t/falls": room_text(["name: Falls"], rows)}
	var dry := Reach.new(texts, {"glove": true})
	check(not dry.touchable(dry.reachable(dry.spot_of("t/falls", "P")), "t/falls", 22, 7), "the falling water bars the shaft")
	var held := Reach.new(texts, {"glove": true, "stillstone": true})
	check(held.touchable(held.reachable(held.spot_of("t/falls", "P")), "t/falls", 22, 7), "frozen, its footholds climb it")


func test_checker_rides_bounce_pods() -> void:
	# A ledge seven tiles up: out of a plain jump's reach, but for the pod. (The
	# Featherstep Boots' second jump reaches seven since pass 235.)
	var rows := grid_rows(40, 23)
	put_tiles(rows, 3, 19, "P")
	put_tiles(rows, 14, 13, "#", 25, 1)
	put_tiles(rows, 30, 12, "L")
	var texts := {"t/ledge": room_text(["name: Ledge"], rows)}
	var bare := Reach.new(texts, {})
	check(not bare.touchable(bare.reachable(bare.spot_of("t/ledge", "P")), "t/ledge", 30, 12), "the ledge is too high to jump to")
	put_tiles(rows, 12, 19, "@")
	texts = {"t/ledge": room_text(["name: Ledge"], rows)}
	var pod := Reach.new(texts, {})
	check(pod.touchable(pod.reachable(pod.spot_of("t/ledge", "P")), "t/ledge", 30, 12), "a bounce-pod beside it throws you up there")


func test_checker_rides_wind_currents_downwind_only() -> void:
	# A current blowing east across the sky, and a ledge past its far end, far
	# beyond any jump from the launch shelf.
	var rows := grid_rows(60, 23)
	put_tiles(rows, 3, 19, "P")
	put_tiles(rows, 5, 16, "#", 4, 4)
	put_tiles(rows, 10, 9, ">", 40, 3)
	put_tiles(rows, 52, 13, "#", 4, 1)
	put_tiles(rows, 53, 12, "L")
	var texts := {"t/wind": room_text(["name: Wind"], rows)}
	var east := Reach.new(texts, {})
	var nodes := east.reachable(east.spot_of("t/wind", "P"))
	check(east.touchable(nodes, "t/wind", 53, 12), "a jump into the current rides it east, past its end, onto the ledge")
	var west := Reach.new(texts, {"sky_spring": true})
	nodes = west.reachable(west.spot_of("t/wind", "P"))
	check(not west.touchable(nodes, "t/wind", 53, 12), "turned west, it carries you away from the ledge")
	check(west.stuck(nodes, [west.spot_of("t/wind", "P")]).is_empty(), "and wherever it drops you, you can walk back")
	put_tiles(rows, 10, 9, ".", 40, 3)
	# Thorns under the ledge: the Boots' second jump climbs seven rows (pass 235),
	# so with no current the only way up would be from the floor right below it.
	put_tiles(rows, 44, 19, "^", 15, 1)
	texts = {"t/wind": room_text(["name: Wind"], rows)}
	var calm := Reach.new(texts, {"boots": true, "stride": true})
	check(not calm.touchable(calm.reachable(calm.spot_of("t/wind", "P")), "t/wind", 53, 12), "with no current, not even the boots and stride get there")


func test_the_turned_wind_reaches_the_thicket_niche() -> void:
	# Bible 6.9: the Sky Spring turns the High Boughs' wind, and the Thicket
	# Road's current then carries you west into the elves' wind-niche.
	var set := {"glove": true, "delvers_pick": true, "amber": true, "winch": true, "lantern": true, "torrent": true, "stride": true,
		"fire": true, "thunder": true, "sky_key": true, "stillstone": true, "boots": true, "severance": true}
	var before := Reach.new(_texts(), set, true)
	var nodes := before.reachable(before.spot_of(START_ROOM, "P"))
	for s: Array in WIND_SECRETS:
		check(not before.touchable(nodes, s[0], s[1], s[2]), "%s is out of reach while the storm wind blows east" % [s])
	set["sky_spring"] = true
	var reach := Reach.new(_texts(), set, true)
	var turned := reach.reachable(reach.spot_of(START_ROOM, "P"))
	var missing: Array = []
	for p: Array in _pickups(reach):
		if not reach.touchable(turned, p[0], p[2], p[3]) and not FRACTURE_SECRETS.has([p[0], p[2], p[3]]):
			missing.append(p)
	check(missing.is_empty(), "with the wind turned, every pickup in the game is reachable: missing %s" % [missing])
	var stuck := reach.stuck(turned, _save_spots(reach))
	check(stuck.is_empty(), "with the wind turned, no soft-locks: %s" % [stuck.slice(0, 6)])


func test_checker_pogoes_across_spikes_with_the_delvers_pick() -> void:
	# A floor of spikes too wide to jump: only pogo bounces cross it.
	var rows := grid_rows(40, 23)
	put_tiles(rows, 3, 19, "P")
	put_tiles(rows, 6, 19, "^", 26, 1)
	put_tiles(rows, 34, 19, "L")
	var texts := {"t/pit": room_text(["name: Pit"], rows)}
	var bare := Reach.new(texts, {"glove": true})
	check(not bare.touchable(bare.reachable(bare.spot_of("t/pit", "P")), "t/pit", 34, 19), "the spike floor can't be crossed without the Delver's Pick")
	var pogo := Reach.new(texts, {"glove": true, "delvers_pick": true})
	check(pogo.touchable(pogo.reachable(pogo.spot_of("t/pit", "P")), "t/pit", 34, 19), "with it, the player pogoes across")


func test_the_old_flue_skips_the_tower_once_the_winch_turns() -> void:
	# Bible 4.3: after Durgan, a wall-jump climb from the Tower Foot over the
	# Rafters reaches the Deep Workings without the lift or Kettleforge.
	var texts := _texts()
	var skip := {}
	for id: String in texts:
		if id.begins_with("tower/") and id not in ["tower/kettleforge", "tower/kettleforge_lift", "tower/mine_mouth", "tower/winch_hall"]:
			skip[id] = texts[id]
	var shut := Reach.new(skip, {"glove": true, "delvers_pick": true})
	check(not _rooms_reached(shut.reachable(_foot_spot(shut))).has("tower/rafters"), "the damper keeps the flue shut before Durgan falls")
	var open := Reach.new(skip, {"glove": true, "delvers_pick": true, "winch": true})
	var reached := _rooms_reached(open.reachable(_foot_spot(open)))
	check(reached.has("tower/rafters") and reached.has("tower/rail_gallery"), "with the winch turning, the flue climbs to the Deep Workings: %s" % [reached.keys()])


func _foot_spot(reach: Reach) -> String:
	for x in range(1, 39):
		if reach.standable("tower/foot", x, 41):
			return Reach.key("tower/foot", x, 41)
	return ""


func test_checker_respects_walls() -> void:
	# A sanity check on a tiny pair of rooms: a 6-tile wall can't be jumped
	# without the glove, but can be climbed with it.
	var rows := grid_rows(30, 23)
	put_tiles(rows, 3, 19, "P")
	put_tiles(rows, 14, 13, "#", 3, 7)
	put_tiles(rows, 22, 19, "L")
	var texts := {"t/wall": room_text(["name: Wall"], rows)}
	var bare := Reach.new(texts, {})
	var n0 := bare.reachable(bare.spot_of("t/wall", "P"))
	check(not bare.touchable(n0, "t/wall", 22, 19), "a 6-tile wall stops a bare jump")
	var gloved := Reach.new(texts, {"glove": true})
	var n1 := gloved.reachable(gloved.spot_of("t/wall", "P"))
	check(gloved.touchable(n1, "t/wall", 22, 19), "the glove climbs it")


func test_checker_wont_climb_through_thorns() -> void:
	# The same wall faced with thorn bulbs (Carillon's crystal-thorned cliffs):
	# the glove can't cling through them.
	var rows := grid_rows(30, 23)
	put_tiles(rows, 3, 19, "P")
	put_tiles(rows, 14, 13, "#", 3, 7)
	put_tiles(rows, 13, 13, "o", 1, 7)
	put_tiles(rows, 22, 19, "L")
	var texts := {"t/wall": room_text(["name: Wall"], rows)}
	var gloved := Reach.new(texts, {"glove": true})
	var n1 := gloved.reachable(gloved.spot_of("t/wall", "P"))
	check(not gloved.touchable(n1, "t/wall", 22, 19), "thorns on the wall stop the climb")


func test_checker_opens_root_gates_from_their_heart() -> void:
	var rows := grid_rows(30, 23)
	put_tiles(rows, 3, 19, "P")
	# A gate four tiles tall, the body's height (pass 508).
	put_tiles(rows, 14, 2, "#", 1, 14)
	put_tiles(rows, 14, 16, "R", 1, 4)
	put_tiles(rows, 22, 19, "L")
	var blocked := {"t/gate": room_text(["name: Gate"], rows)}
	var r0 := Reach.new(blocked, {"glove": true})
	check(not r0.touchable(r0.reachable(r0.spot_of("t/gate", "P")), "t/gate", 22, 19), "a root-gate with no heart stays shut")
	put_tiles(rows, 6, 19, "N")
	var hearted := {"t/gate": room_text(["name: Gate"], rows)}
	var r1 := Reach.new(hearted, {})
	check(r1.touchable(r1.reachable(r1.spot_of("t/gate", "P")), "t/gate", 22, 19), "with its heart in reach, it opens")


func test_every_room_boots_and_the_player_lands() -> void:
	var bad: Array[String] = []
	for id: String in _texts():
		GameState.new_game()
		var w := World.new()
		w.instant = true
		arena.add_child(w)
		w.start(id)
		w.player.input.scripted = true
		await frames(40)
		var p := w.player
		if p.dead or p.hp < p.max_hp or not p.is_on_floor() or w.room.id != id:
			bad.append("%s (on floor %s, hp %d, in %s)" % [id, p.is_on_floor(), p.hp, w.room.id])
		w.queue_free()
		await frames(1)
	check(bad.is_empty(), "every room loads and the player lands safely at its entrance: %s" % [bad])



func test_elven_stride_crosses_the_gap_to_the_warden_cache() -> void:
	# Bible 4.1 (A5): the Elven Stride waits in the Windloft, reachable without
	# it; the cache across the north bough's gap needs an air dash.
	# The Featherstep Boots always come before it (the Haar before the High Boughs), so a
	# Stride secret must hold against a double jump too (pass 211).
	var set := {"glove": true, "delvers_pick": true, "amber": true, "winch": true, "lantern": true, "torrent": true, "boots": true}
	var bare := Reach.new(_texts(), set, true)
	var nodes := bare.reachable(bare.spot_of(START_ROOM, "P"))
	check(bare.touchable(nodes, "boughs/windloft", 24, 11), "the Elven Stride can be reached without it")
	for s: Array in STRIDE_SECRETS:
		check(not bare.touchable(nodes, s[0], s[1], s[2]), "%s is out of reach without the Stride, even with the Featherstep Boots" % [s])
	set["stride"] = true
	var reach := Reach.new(_texts(), set, true)
	var strided := reach.reachable(reach.spot_of(START_ROOM, "P"))
	var missing: Array = []
	for p: Array in _pickups(reach):
		if not reach.touchable(strided, p[0], p[2], p[3]) and not BOOT_SECRETS.has([p[0], p[2], p[3]]) and not FIRE_SECRETS.has([p[0], p[2], p[3]]) \
				and not THUNDER_ROOMS.has(p[0]) and not WIND_SECRETS.has([p[0], p[2], p[3]]) and not FRACTURE_SECRETS.has([p[0], p[2], p[3]]):
			missing.append(p)
	check(missing.is_empty(), "with the Stride every other pickup is reachable: missing %s" % [missing])
	var rooms := _rooms_reached(strided)
	check(STRIDE_ROOMS.all(func(id: String) -> bool: return rooms.has(id)), "and the Stride reaches the sky islands")
	# Carillon's spell gates (bible 4.5), checked on the same flood to keep the suite quick.
	check(reach.touchable(strided, "spires/spires", 66, 13), "the bell-ringer on the gallery can be reached")
	check(reach.touchable(strided, "spires/spire_foot", 16, 19), "the Tempest Lance scroll can be reached without it")
	for s: Array in FIRE_SECRETS:
		check(not reach.touchable(strided, s[0], s[1], s[2]), "%s is out of reach behind the bramble" % [s])
	check(THUNDER_ROOMS.all(func(id: String) -> bool: return not rooms.has(id)), "the conduit gate keeps the Spire Stair shut")
	var stuck := reach.stuck(strided, _save_spots(reach))
	check(stuck.is_empty(), "with the Stride, no soft-locks: %s" % [stuck.slice(0, 6)])


func test_fire_and_thunder_open_the_spires_gates() -> void:
	# Bible 4.5: bramble holds until Emberfall, conduit gates until Tempest Lance. The
	# without-spell side is checked in the Stride test's flood.
	var set := {"glove": true, "delvers_pick": true, "amber": true, "winch": true, "lantern": true, "torrent": true, "stride": true,
		"fire": true, "thunder": true, "sky_key": true, "stillstone": true, "severance": true, "boots": true}
	var reach := Reach.new(_texts(), set, true)
	var lit := reach.reachable(reach.spot_of(START_ROOM, "P"))
	for s: Array in FIRE_SECRETS:
		check(reach.touchable(lit, s[0], s[1], s[2]), "%s is reachable once the bramble burns" % [s])
	var opened := _rooms_reached(lit)
	check(THUNDER_ROOMS.all(func(id: String) -> bool: return opened.has(id)), "with Tempest Lance the Spire Stair opens, and with the Sky Key the stair down to Vorrhallow")
	check(reach.touchable(lit, "spires/spire_stair", 24, 8), "and its top landing's chest can be reached")
	var missing: Array = []
	for p: Array in _pickups(reach):
		if THUNDER_ROOMS.has(p[0]) and not reach.touchable(lit, p[0], p[2], p[3]):
			missing.append(p)
	check(missing.is_empty(), "every pickup past the conduit gate (Vorrhallow too, with the Stillstone) is reachable: missing %s" % [missing])
	var stuck := reach.stuck(lit, _save_spots(reach))
	check(stuck.is_empty(), "with Emberfall and Tempest Lance, no soft-locks: %s" % [stuck.slice(0, 6)])


func test_dartmoors_upper_gate_needs_the_sky_key() -> void:
	# The flood above runs with the Sky Key; this checks the gate tile itself.
	var texts := _texts()
	check(Reach.new(texts, {}).solid("spires/sky_spring", 33, 19), "the upper gate is shut without the Sky Key")
	check(not Reach.new(texts, {"sky_key": true}).solid("spires/sky_spring", 33, 19), "and open with it")


func test_the_throne_lies_behind_the_flesh_only_the_severance_cuts() -> void:
	var set := {"glove": true, "delvers_pick": true, "amber": true, "winch": true, "lantern": true, "torrent": true, "stride": true,
		"fire": true, "thunder": true, "sky_key": true, "stillstone": true, "boots": true}
	var reach := Reach.new(_texts(), set, true)
	var rooms := _rooms_reached(reach.reachable(reach.spot_of(START_ROOM, "P")))
	check(rooms.has("evercrown/heart_gate") and not rooms.has("evercrown/throne"), "without the Severance the flesh holds the throne shut")
	set["severance"] = true
	reach = Reach.new(_texts(), set, true)
	rooms = _rooms_reached(reach.reachable(reach.spot_of(START_ROOM, "P")))
	check(rooms.has("evercrown/throne"), "with it, the way to the throne is open")


func test_checker_swims_through_deep_water() -> void:
	# A ledge (left) over a pool whose only way on is a passage under a low wall,
	# and a bank (right) level with the surface. Without water the drop is a pit.
	var rows := [
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#P.....######................#",
		"#####aaa######aaaaaaa#########",
		"#####aaa######aaaaaaa#########",
		"#####aaaaaaaaaaaaaaaa#########",
		"#####aaaaaaaaaaaaaaaa#########",
		"#####aaaaaaaaaaaaaaaa#########",
		"##############################",
	]
	var reach := Reach.new({"t/pool": "zone: test\n---\n" + "\n".join(PackedStringArray(rows))}, {})
	var nodes := reach.reachable(reach.spot_of("t/pool", "P"))
	check(nodes.has(Reach.key("t/pool", 6, 10)), "the checker swims down to the bottom of the pool")
	check(nodes.has(Reach.key("t/pool", 15, 9)), "and under the low wall into the next pool")
	check(nodes.has(Reach.key("t/pool", 22, 5)), "and jumps out of the surface onto the bank")
	check(reach.stuck(nodes, [reach.spot_of("t/pool", "P")]).is_empty(), "and can always swim back up and out the way it came")


func test_the_sunken_spring_lies_under_the_last_stone_of_the_rise() -> void:
	var texts := _texts()
	check(Reach.new(texts, {}).solid("vorrhallow/meteor_rise", 14, 60), "the cracked stone holds without the Delver's Pick")
	check(not Reach.new(texts, {"delvers_pick": true}).solid("vorrhallow/meteor_rise", 14, 60), "and breaks with it")
	var set := {"glove": true, "delvers_pick": true, "amber": true, "winch": true, "lantern": true, "torrent": true, "stride": true,
		"fire": true, "thunder": true, "sky_key": true, "stillstone": true, "boots": true}
	var reach := Reach.new(texts, set, true)
	var rooms := _rooms_reached(reach.reachable(reach.spot_of(START_ROOM, "P")))
	check(rooms.has("sunken/spring_gate") and rooms.has("sunken/drowned_aqueduct") and rooms.has("sunken/source_hall"),
		"down through it, every room of the Sunken Spring is in reach")


## The Inner Rings (bible 3.1) are entered through the Ringreader, not by doors: each
## built trial's bell can be reached from its start with only the abilities it
## needs (the Climbing Glove for the first two, which open after the first
## spring; the Delver's Pick too for Thorns), and no spot the trial can put you on is
## cut off from the bell.
func test_every_ringreader_trial_can_be_cleared_with_the_glove() -> void:
	for t: Dictionary in Trials.built():
		var text := FileAccess.get_file_as_string(World.room_path(t.room))
		var abilities := {}
		for a: String in t.get("needs", ["glove"]):
			abilities[a] = true
		var reach := Reach.new({t.room: text}, abilities)
		var start := reach.spot_of(t.room, "P")
		check(start != "", "%s has a start" % t.name)
		var goal := ""
		for line: String in text.split("\n"):
			if line.begins_with("prop:") and line.ends_with("trial_goal"):
				var parts := line.substr(5).split(",")
				goal = Reach.key(t.room, int(parts[0]), int(parts[1]))
		check(goal != "", "%s has a bell" % t.name)
		var nodes := reach.reachable(start)
		check(nodes.has(goal), "%s: the bell can be reached from the start" % t.name)
		var stuck := reach.stuck(nodes, [goal])
		check(stuck.is_empty(), "%s: every spot can still get to the bell: %s" % [t.name, stuck.slice(0, 6)])


## Bible 6.11 (pass 124): the checker climbs ladders. A shaft through a floor too
## high to jump has a ladder up it: the loft is in reach only with the ladder
## there, and the ladder is the way back down.
func test_checker_climbs_ladders() -> void:
	# The loft is four tiles tall, the body's height (pass 508).
	var rows := [
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#########\"#########",
		"#........\"........#",
		"#........\"........#",
		"#........\"........#",
		"#........\"........#",
		"#........\"........#",
		"#P.......\"........#",
		"####################",
	]
	var text := "zone: test\n---\n" + "\n".join(PackedStringArray(rows))
	var reach := Reach.new({"t/shaft": text}, {})
	var nodes := reach.reachable(reach.spot_of("t/shaft", "P"))
	check(nodes.has(Reach.key("t/shaft", 9, 8)), "the checker hangs on the ladder halfway up")
	check(nodes.has(Reach.key("t/shaft", 3, 4)), "and climbs over its top into the loft")
	check(reach.stuck(nodes, [reach.spot_of("t/shaft", "P")]).is_empty(), "and can always climb back down")
	var bare := Reach.new({"t/shaft": text.replace("\"", ".").replace("#########.#########", "####################")}, {})
	check(not bare.reachable(bare.spot_of("t/shaft", "P")).has(Reach.key("t/shaft", 3, 4)), "without the ladder the loft is out of reach")


## Pass 125: ladders are a convenience, never a key. Take every ladder out (its
## top cell left as a plank, the rest open air) and nothing the player could
## reach before the Glove, or with it, is lost: no ladder opens a room a gate
## should hold shut.
func test_ladders_never_open_a_gated_room() -> void:
	var texts := _texts()
	var bare := {}
	var ladders := 0
	for id: String in texts:
		var parsed := Room.parse(texts[id])
		var grid: Array[String] = parsed.grid
		if not "\n".join(PackedStringArray(grid)).contains(Reach.LADDER):
			bare[id] = texts[id]
			continue
		var head: String = texts[id].substr(0, texts[id].find("\n---\n") + 5)
		var rows := []
		for y in grid.size():
			var row := grid[y]
			var out := ""
			for x in row.length():
				var c := row[x]
				if c == Reach.LADDER:
					ladders += 1
					var top := y == 0 or x >= grid[y - 1].length() or grid[y - 1][x] != Reach.LADDER
					c = "-" if top else "."
				out += c
			rows.append(out)
		bare[id] = head + "\n".join(PackedStringArray(rows))
	check(ladders > 0, "the world has ladders (%d cells)" % ladders)
	for abilities: Dictionary in [{}, {"glove": true}]:
		var with := Reach.new(texts, abilities, true)
		var without := Reach.new(bare, abilities, true)
		var a := _rooms_reached(with.reachable(with.spot_of(START_ROOM, "P")))
		var b := _rooms_reached(without.reachable(without.spot_of(START_ROOM, "P")))
		var extra := a.keys().filter(func(id: String) -> bool: return not b.has(id))
		check(extra.is_empty(), "with %s, ladders open no room the rooms without them keep shut: %s" % [abilities.keys(), extra])



const SCAR := "evercrown/proving_scar"
const SCAR_KIT := {"glove": true, "boots": true, "stride": true, "delvers_pick": true, "thunder": true, "torrent": true, "stillstone": true}


## Whether the checker crosses the Proving Scar alone, from its west door to its shrine.
func _scar_crossed(kit: Dictionary) -> bool:
	var texts := {SCAR: FileAccess.get_file_as_string(World.room_path(SCAR))}
	var reach := Reach.new(texts, kit)
	var nodes := reach.reachable(Reach.key(SCAR, 3, 42))
	return reach.touchable(nodes, SCAR, 72, 42)


func test_the_proving_scar_asks_for_every_ability() -> void:
	check(_scar_crossed(SCAR_KIT), "with every ability the checker crosses the Scar to its shrine")
	for ability: String in SCAR_KIT:
		var kit := SCAR_KIT.duplicate()
		kit.erase(ability)
		check(not _scar_crossed(kit), "without %s it can't" % ability)




## Pass 388 (bible 8): "each boss has ... an ability it tests", and each of the
## original's guardians names the one it tests. A fight can only test what the
## map makes you hold by the time you reach it. With what the critical path
## (4.2) gives before each, the arena must be out of reach without the ability
## it tests and in reach with it. Snapcrown "tests air dash", but the Windloft let
## you walk past the Stride hung in its air and on to the Crown-Leaf; an elven
## veil now bars the Windloft's east door, so the Bloom is met with the Stride.
func test_every_guardian_is_met_with_the_ability_it_tests() -> void:
	var act := ["glove", "amber", "delvers_pick", "winch", "boots", "lantern", "torrent", "spring_haar", "stride", "fire", "thunder", "sky_spring", "sky_key", "stillstone"]
	# Guardian, arena, the ability its fight tests, the bible's words for it.
	var fights := [
		["Gnarlmaw", "heartwood/root_chamber", "glove", "**Tests:** wall jumping"],
		["Durgan", "tower/kettleforge_lift", "delvers_pick", "**Tests:** pogo"],
		["The Haar Wyrm", "haar/spring_of_haar", "torrent", "**Tests:** Deluge"],
		["Snapcrown", "boughs/crown_leaf", "stride", "**Tests:** air dash"],
		["Skyrend", "spires/roost", "thunder", "**Tests:** Tempest Lance"],
		["Thane Vorrund", "vorrhallow/throne_hall", "stillstone", "**Tests:** Stillstone"],
	]
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var texts := _texts()
	for f: Array in fights:
		check(bible.contains(f[3]), "bible 8 says %s %s" % [f[0], f[3]])
		var kit := {}
		for a: String in act.slice(0, act.find(f[2])):
			kit[a] = true
		var bare := Reach.new(texts, kit, true)
		var without := _rooms_reached(bare.reachable(bare.spot_of(START_ROOM, "P")))
		kit[f[2]] = true
		var reach := Reach.new(texts, kit, true)
		var with := _rooms_reached(reach.reachable(reach.spot_of(START_ROOM, "P")))
		check(not without.has(f[1]) and with.has(f[1]), "%s's arena (%s) needs %s, the ability its fight tests (without: %s, with: %s)" % [
			f[0], f[1], f[2], without.has(f[1]), with.has(f[1])])
	check(bible.contains("`test_every_guardian_is_met_with_the_ability_it_tests`"), "bible 8 names the test")

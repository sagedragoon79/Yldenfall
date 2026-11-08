extends TestSuite
## The player's sprite animation (design bible 12.4): the generated sheet, which
## animation plays for each action, and swing recovery.

const ARENA := [
	"####################",
	"#..................#",
	"#..................#",
	"#..................#",
	"#..................#",
	"#..................#",
	"#..................#",
	"####################",
]
const POSES := ["idle", "run", "rise", "apex", "fall", "dash", "wall", "attack_side", "attack_up",
	"attack_down", "drink", "block", "cast", "hurt", "death"]


func test_sheet_covers_every_pose() -> void:
	var d := PlayerVisual.data()
	var anims: Dictionary = d.animations
	var missing: Array[String] = []
	for pose: String in POSES:
		var names := ["slash1", "slash2", "slash3"] if pose == "attack_side" else [PlayerVisual.anim_for(null, pose)]
		for n: String in names:
			if not anims.has(n):
				missing.append(n)
	check(missing.is_empty(), "every pose has an animation (missing %s)" % [missing])
	var bad: Array[String] = []
	for n: String in anims:
		var a: Dictionary = anims[n]
		for f: Dictionary in a.frames:
			if not f.has("hand") or not f.has("neck"):
				bad.append(n)
		var swing: bool = n.begins_with("slash") or n == "strike_down"
		for f: Dictionary in a.frames:
			# A swing shows its blade: drawn from the frame's angle, or in the art (Autosprite).
			if swing != (f.has("blade") or f.has("art_blade")):
				bad.append(n)
		for i: Variant in a.seq:
			if int(i) >= a.frames.size():
				bad.append(n)
	check(bad.is_empty(), "frames carry hand and neck points, and blades only in swings (bad %s)" % [bad])
	var sheet := (load(PlayerVisual.SHEET) as Texture2D).get_image()
	var cell: Vector2 = d.cell
	check(sheet.get_width() >= int(d.columns) * cell.x and sheet.get_height() >= anims.size() * cell.y,
		"the sheet is big enough for every row")


## Pass 185: the hero's sheet is bare-headed and the Elven Helm is its own
## layer, so every frame marks the crown of the head (found in the pixels on
## import), and the sheet's pixels really are there.
func test_every_hero_frame_marks_the_crown_for_the_helmet() -> void:
	var d := PlayerVisual.data()
	var sheet := (load(PlayerVisual.SHEET) as Texture2D).get_image()
	var cell: Vector2 = d.cell
	var origin: Vector2 = d.origin
	var den := float(d.get("density", 1))
	var bad: Array[String] = []
	for n: String in d.animations:
		var a: Dictionary = d.animations[n]
		for i in a.frames.size():
			var f: Dictionary = a.frames[i]
			if not f.has("head"):
				bad.append("%s:%d none" % [n, i])
				continue
			var at := Vector2(i * cell.x, int(a.row) * cell.y) + origin + Vector2(f.head[0], f.head[1]) * den
			# The crown is the top of something solid: the sheet is opaque just under it.
			var solid := false
			for dy in range(0, 6):
				solid = solid or sheet.get_pixelv(at + Vector2(0, dy)).a > 0.5
			if not solid or (n != "death" and float(f.head[1]) > -30.0):
				bad.append("%s:%d %s" % [n, i, f.head])
	check(bad.is_empty(), "every frame marks a crown on the head (bad %s)" % [bad])
	GameState.new_game()
	GameState.data.equipment.helmet = "elven_helm"
	var room := make_room(["#####", "#...#", "#####"])
	var p := make_player(room, Vector2i(2, 1))
	await frames(2)
	check(p.visual.frame_info().has("head"), "the drawn frame carries its crown")
	GameState.new_game()


func test_the_master_palette_has_muted_ramps_and_a_pixellab_copy() -> void:
	# Bible 12.2 (pass 506): 12 ramps of 8, the last four muted, and master.json carries
	# the same colours in order for PixelLab's target_palette.
	var colors: Array = []
	var ramps := {}
	for line in FileAccess.get_file_as_string("res://art/palette/master.gpl").split("
"):
		var parts := line.replace("	", " ").strip_edges().split(" ", false)
		if parts.size() >= 4 and parts[0].is_valid_int():
			colors.append("#%02x%02x%02x" % [int(parts[0]), int(parts[1]), int(parts[2])])
			ramps[parts[3].get_slice("-", 0)] = true
	check(colors.size() == 96 and ramps.size() == 12, "the master palette is 12 ramps of 8 (%d colours, %d ramps)" % [colors.size(), ramps.size()])
	for ramp in ["umber", "ash", "moss", "ochre"]:
		check(ramps.has(ramp), "the master palette has the muted %s ramp" % ramp)
	var target = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	check(target is Dictionary and target.get("colors", []) == colors, "master.json lists the master colours in order for PixelLab")


func test_sheets_use_the_master_palette() -> void:
	var allowed := {}
	for line in FileAccess.get_file_as_string("res://art/palette/master.gpl").split("\n"):
		var parts := line.replace("\t", " ").strip_edges().split(" ", false)
		if parts.size() >= 3 and parts[0].is_valid_int():
			allowed[Color8(int(parts[0]), int(parts[1]), int(parts[2])).to_rgba32()] = true
	var bad: Array[String] = []
	var count := 0
	for file in DirAccess.get_files_at(Sheet.DIR):
		if not file.ends_with(".json"):
			continue
		count += 1
		var img := (load(Sheet.DIR + file.trim_suffix(".json") + ".png") as Texture2D).get_image()
		img.decompress()
		if Sheet.get_sheet(file.trim_suffix(".json")).get("own_palette", false):
			# HD characters keep their own small palette (12.2); still a limited, pixel-art one.
			var seen := {}
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.0:
						seen[Color(c.r, c.g, c.b, 1.0).to_rgba32()] = true
			if seen.size() > 96:
				bad.append("%s (%d colors)" % [file, seen.size()])
			continue
		var off := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and not allowed.has(Color(c.r, c.g, c.b, 1.0).to_rgba32()):
					off += 1
		if off > 0:
			bad.append("%s (%d px)" % [file, off])
	check(count >= 4 and bad.is_empty(), "every character sheet is on the master palette (%d sheets; off: %s)" % [count, bad])


func test_cast_has_sheets() -> void:
	var want := {"blinkhop": ["idle", "windup", "hop"], "hornet": ["fly", "windup", "swoop"],
		"rot_dwarf": ["walk", "windup", "swing", "recover", "stagger"], "sap_spitter": ["idle", "windup", "spit"], "grub_lump": ["crawl", "windup", "drop"],
		"iron_dwarf": ["walk", "windup", "slam", "stuck", "recover", "stagger"],
		"gear_bat": ["roost", "fly", "windup", "bare", "stagger"],
		"foreman": ["idle", "walk", "pound_tell", "pound", "charge_tell", "charge", "stunned", "throw_tell", "throw", "recover"]}
	var missing: Array[String] = []
	for sheet: String in want:
		for anim: String in want[sheet]:
			if not Sheet.exists(sheet) or not Sheet.has_anim(sheet, anim):
				missing.append(sheet + ":" + anim)
	for npc_id: String in GameData.table("npcs"):
		if not Sheet.exists("npc_" + npc_id):
			missing.append("npc_" + npc_id)
	check(missing.is_empty(), "every enemy state and every person has a sheet (missing %s)" % [missing])
	check(Sheet.info("blinkhop", "idle", 0).has("eye"), "the Blinkhop's frames mark its eye for the pupil")
	check(Sheet.info("sap_spitter", "windup", 1).has("mouth"), "the Sap Spitter's frames mark its mouth for the glob")


func test_combo_plays_three_swings() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	var seen: Array[String] = []
	var first: Array[int] = []
	for i in 3:
		p.input.attack_pressed = true
		await frames(2)
		seen.append(p.visual.anim)
		first.append(p.visual.frame)
		await frames(int(p.combat.combo_cooldowns[i] * 60.0))
	check(seen == ["slash1", "slash2", "slash3"], "the combo plays each swing (%s)" % [seen])
	check(first == [0, 0, 0], "each swing starts on its strike frame (%s)" % [first])


func test_swing_recovery_holds_then_returns_to_idle() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.input.attack_pressed = true
	await frames(int(p.tuning.slash_active * 60.0) + 2)
	check(not p.is_attacking and p.visual.anim == "slash1", "the recovery frames play after the hitbox ends (%s)" % p.visual.anim)
	await frames(20)
	check(p.visual.anim == "idle", "then back to idle (%s)" % p.visual.anim)


func test_actions_pick_their_animations() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.input.move_x = 1
	await frames(12)
	var run_frame := p.visual.frame
	await frames(6)
	check(p.visual.anim == "run" and p.visual.frame != run_frame, "running animates (%s %d)" % [p.visual.anim, p.visual.frame])
	p.input.move_x = 0
	p.input.attack_pressed = true
	p.input.up = true
	await frames(2)
	check(p.visual.anim == "slash_up", "up slash (%s)" % p.visual.anim)
	p.input.up = false
	await frames(30)
	p.take_damage(1, false, -1)
	await frames(2)
	check(p.visual.anim == "hurt", "hurt (%s)" % p.visual.anim)
	await frames(30)
	check(p.visual.anim != "hurt", "the hurt pose is brief (%s)" % p.visual.anim)


func test_death_plays_the_collapse() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.take_damage(p.hp, false, -1)
	await frames(30)
	check(p.dead and p.visual.anim == "death" and p.visual.visible, "the elf collapses where they fell (%s)" % p.visual.anim)
	check(p.visual.frame > 0, "the collapse plays through (frame %d)" % p.visual.frame)


func test_scarf_hangs_from_the_neck() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.input.dash_pressed = true
	await frames(3)
	var neck := p.visual.neck_position()
	check(p.scarf.anchor().distance_to(neck) < 4.0, "the scarf follows the frame's neck (%s vs %s)" % [p.scarf.anchor(), neck])
	check(p.scarf.visible == Sheet.flag("player", "scarf", true), "the scarf shows only when the sheet asks for it")


func test_dense_sheets_keep_world_size() -> void:
	var one := Sheet.dest_rect("player")
	Sheet._cache["test_dense"] = {"cell": Vector2(128, 128), "origin": Vector2(64, 122), "density": 2.0}
	var two := Sheet.dest_rect("test_dense")
	Sheet._cache.erase("test_dense")
	check(two == Rect2(-32, -61, 64, 64), "a density-2 cell covers half its pixels in the world (%s)" % two)
	var d := PlayerVisual.data()
	check(one.size == (d.cell as Vector2) / float(d.density), "the player sheet keeps its world size at its density (%s)" % one)


func test_a_worn_blade_swings_from_its_own_clips() -> void:
	# Swords are drawn into the attacks (design bible 13.5): with any blade but
	# the Short Sword, a set's attacks play from "<set>_<blade>"; the rest of
	# its clips stay the set's own.
	for sheet in ["hero_base", "hero_leather", "hero_riveted", "hero_plate", "hero_battle", "hero_battle_helm"]:
		for blade: String in PlayerVisual.BLADE_SHEETS.values():
			for clip in PlayerVisual.BLADE_CLIPS:
				check(Sheet.has_anim(sheet + "_" + blade, clip), "%s_%s has %s" % [sheet, blade, clip])
	GameState.data.equipment["armor"] = "full_plate"
	GameState.data.equipment["blade"] = "long_sword"
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	check(p.visual.sheet == "hero_plate" and p.visual.anim == "idle", "idle is the set's own (%s %s)" % [p.visual.sheet, p.visual.anim])
	p.input.attack_pressed = true
	await frames(2)
	check(p.visual.anim == "slash1" and p.visual.sheet == "hero_plate_long_sword", "the Wayfarer's Sword swings from its clips (%s %s)" % [p.visual.sheet, p.visual.anim])
	await frames(40)
	GameState.data.equipment["blade"] = "short_sword"
	p.input.attack_pressed = true
	await frames(2)
	check(p.visual.anim == "slash1" and p.visual.sheet == "hero_plate", "the Short Sword is the set's own (%s %s)" % [p.visual.sheet, p.visual.anim])
	GameState.data.equipment["armor"] = ""


func test_a_worn_shield_is_drawn_into_the_block() -> void:
	# Shields are drawn into the block pose (design bible 13.5): with a shield on,
	# a set blocks from "<set>_<shield>" and the code-drawn shield is not added.
	for sheet in ["hero_base", "hero_leather", "hero_riveted", "hero_plate", "hero_battle", "hero_battle_helm"]:
		for shield: String in PlayerVisual.SHIELD_SHEETS:
			check(Sheet.has_anim(sheet + "_" + shield, "block"), "%s_%s has block" % [sheet, shield])
	GameState.data.equipment["armor"] = "leather_armor"
	GameState.data.equipment["shield"] = "large_shield"
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.input.block_held = true
	await frames(3)
	check(p.is_blocking, "the hero blocks")
	check(p.visual.anim == "block" and p.visual.sheet == "hero_leather_large_shield", "the block plays from the shield's clip (%s %s)" % [p.visual.sheet, p.visual.anim])
	check(p.visual.shield_drawn(), "its art holds the shield, so none is drawn over it")
	p.input.block_held = false
	await frames(2)
	GameState.data.equipment["armor"] = ""
	GameState.data.equipment["shield"] = "magic_shield"
	p.input.block_held = true
	await frames(3)
	check(p.visual.sheet == "hero_base_magic_shield", "unarmored, the base set holds it (%s)" % p.visual.sheet)
	p.input.block_held = false
	await frames(2)
	PlayerVisual.body_sets = false
	p.input.block_held = true
	await frames(3)
	check(p.visual.sheet == "player" and not p.visual.shield_drawn(), "the old hero holds the drawn shield (%s)" % p.visual.sheet)
	p.input.block_held = false
	PlayerVisual.body_sets = true
	GameState.data.equipment["shield"] = ""


func test_a_rune_dagger_throw_plays_its_flick() -> void:
	# The Rune Dagger's throw (design bible 13.5): each set flicks it forward, or
	# up when thrown up, over the legs' poses; the old hero has no flick.
	for sheet in ["hero_base", "hero_leather", "hero_riveted", "hero_plate", "hero_battle", "hero_battle_helm"]:
		for clip in ["throw", "throw_up"]:
			check(Sheet.has_anim(sheet, clip), "%s has %s" % [sheet, clip])
			# Flicked from the left hand, so each blade's sheet has it too, the sword kept in hand.
			for blade: String in PlayerVisual.BLADE_SHEETS.values():
				check(Sheet.has_anim(sheet + "_" + blade, clip), "%s_%s has %s" % [sheet, blade, clip])
	GameState.data.equipment["armor"] = "full_plate"
	var held := String(GameState.data.equipment.get("blade", ""))
	GameState.data.equipment["blade"] = "short_sword"
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	p.abilities["rune_dagger"] = true
	await frames(6)
	p.input.throw_pressed = true
	await frames(2)
	p.input.throw_pressed = false
	check(p.visual.anim == "throw" and p.visual.sheet == "hero_plate", "the forward flick plays (%s %s)" % [p.visual.sheet, p.visual.anim])
	await frames(30)
	GameState.data.equipment["blade"] = "long_sword"
	p.throw_dagger()
	await frames(2)
	check(p.visual.anim == "throw" and p.visual.sheet == "hero_plate_long_sword", "with the Wayfarer's Sword kept in hand (%s %s)" % [p.visual.sheet, p.visual.anim])
	GameState.data.equipment["blade"] = held
	await frames(30)
	check(p.visual.anim == "idle", "and gives way to the idle when done (%s)" % p.visual.anim)
	p.input.up = true
	p.throw_dagger()
	await frames(2)
	p.input.up = false
	check(p.visual.anim == "throw_up", "thrown up, the flick goes up (%s)" % p.visual.anim)
	await frames(30)
	PlayerVisual.body_sets = false
	p.throw_dagger()
	await frames(2)
	check(p.visual.sheet == "player" and p.visual.anim == "idle", "the old hero just stands (%s %s)" % [p.visual.sheet, p.visual.anim])
	PlayerVisual.body_sets = true
	GameState.data.equipment["armor"] = ""
	for d in runner.get_tree().get_nodes_in_group("projectile"):
		d.free()


func test_armor_picks_its_body_set() -> void:
	# Paper doll (design bible 13.4): each armor has a body sheet of its own,
	# with the same clips, and anchors for the layers drawn over it.
	var bad: Array[String] = []
	var sheets: Array = PlayerVisual.ARMOR_SHEETS.values() + PlayerVisual.HELMED_SHEETS.values()
	for sheet: String in sheets:
		if not Sheet.exists(sheet):
			bad.append(sheet + " missing")
			continue
		var d := Sheet.get_sheet(sheet)
		var img := (load(Sheet.DIR + sheet + ".png") as Texture2D).get_image()
		var den := float(d.get("density", 1))
		for anim: String in ["idle", "walk", "run"]:
			if not Sheet.has_anim(sheet, anim):
				bad.append(sheet + ":" + anim)
				continue
			var a: Dictionary = d.animations[anim]
			for i in a.frames.size():
				var f: Dictionary = a.frames[i]
				for key: String in ["hand", "neck", "head", "back"]:
					if not f.has(key):
						bad.append("%s:%s no %s" % [sheet, anim, key])
				if not f.has("head"):
					continue
				# The head point is the crown the helmet sits on: the sheet is solid just under it.
				var at := Vector2(i * d.cell[0], int(a.row) * d.cell[1]) + Vector2(d.origin[0], d.origin[1]) + Vector2(f.head[0], f.head[1]) * den
				var solid := false
				for dy in range(0, 6):
					solid = solid or img.get_pixelv(at + Vector2(0, dy)).a > 0.5
				if not solid:
					bad.append("%s:%s:%d crown %s" % [sheet, anim, i, f.head])
	check(bad.is_empty(), "every armor has idle, walk and run with hand, neck, head (on the crown) and back points (%s)" % [bad])
	# The Elven Helm is cut from the PixelLab helmed elf, a little wider than the head at the 2x density.
	var helm := PlayerVisual.HELMET.get_size()
	check(helm.x >= 16 and helm.x <= 26 and helm.y >= 16 and helm.y <= 28, "the helmet layer is a head-sized sprite (%s)" % helm)
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	check(p.visual.sheet == "hero_base" and p.visual.anim == "idle", "no armor: the base body (%s)" % p.visual.sheet)
	var info := p.visual.frame_info()
	var head: Array = info.head
	var hand: Array = info.hand
	check(head[1] < -38 and head[1] > -50 and hand[1] < -14 and hand[1] > -32, "the head is up top and the hand at the hip (%s, %s)" % [head, hand])
	GameState.data.equipment.armor = "full_plate"
	await frames(2)
	check(p.visual.sheet == "hero_plate", "Knight's Plate swaps the body (%s)" % p.visual.sheet)
	p.input.move_x = 1
	await frames(12)
	check(p.visual.anim == "run" and p.visual.sheet == "hero_plate", "and runs in it (%s %s)" % [p.visual.anim, p.visual.sheet])
	p.input.move_x = 0
	await frames(20)
	p.input.block_held = true
	await frames(4)
	check(p.visual.anim == "block" and p.visual.sheet == PlayerVisual.SHEET_NAME, "a clip the set lacks plays from the old sheet (%s %s)" % [p.visual.anim, p.visual.sheet])
	p.input.block_held = false
	# The Elven Plate worn with the Elven Helm has a body of its own, drawn helmed.
	GameState.data.equipment.armor = "elven_plate"
	GameState.data.equipment.helmet = "elven_helm"
	p.input.jump_pressed = false
	p.input.jump_held = false
	await frames(90)
	check(p.visual.sheet == "hero_battle_helm", "Elven Plate and Elven Helm: the helmed body (%s %s)" % [p.visual.anim, p.visual.sheet])
	GameState.data.equipment.helmet = ""
	await frames(2)
	check(p.visual.sheet == "hero_battle", "the helmet off: the bare-headed Elven Plate (%s)" % p.visual.sheet)
	GameState.data.equipment.armor = ""



func test_the_hood_is_down_in_town_and_up_outside() -> void:
	# The cloak layer (design bible 13.4): its hood is up out in the world,
	# down in a town, and down under a helmet. Every PixelLab set draws its
	# cloak in, in key green (13.5), so over them the layer is not drawn.
	GameState.data.equipment["armor"] = "leather_armor"
	var wild := make_room(ARENA)
	var p := make_player(wild, Vector2i(3, 6))
	await frames(10)
	for set: String in PlayerVisual.ARMOR_SHEETS.values() + PlayerVisual.HELMED_SHEETS.values():
		check(Sheet.flag(set, "cloak", false) and Sheet.flag(set, "key_cloak", false), "%s draws its cloak in, in key green" % set)
	check(not wild.is_town() and p.cloak.hood == 1.0 and not p.cloak.shown(), "out in the world the hood is up, and the layer hides over the set")
	var town := make_room(ARENA)
	town.position = Vector2(0, 400)
	town._people = 1
	p.reparent(town)
	await frames(6)
	check(town.is_town() and p.cloak.hood > 0.0 and p.cloak.hood < 1.0, "in a town it comes down, not at once (%.2f)" % p.cloak.hood)
	await frames(int(Cloak.HOOD_TIME * 60.0) + 2)
	check(p.cloak.hood == 0.0, "and stays down")
	p.reparent(wild)
	GameState.data.equipment["helmet"] = "elven_helm"
	await frames(int(Cloak.HOOD_TIME * 60.0) + 2)
	check(p.cloak.hood == 0.0, "under a helmet it stays down outside too")
	GameState.data.equipment["helmet"] = ""
	await frames(int(Cloak.HOOD_TIME * 60.0) + 2)
	check(p.cloak.hood == 1.0, "and goes up again without it")
	var hem: Vector2 = p.cloak._inner[Cloak.SEGMENTS]
	check(hem.y > p.global_position.y - 12.0 and hem.y <= p.global_position.y, "the cape hangs to the ankles (%s, feet %s)" % [hem, p.global_position])
	p.input.block_held = true
	await frames(4)
	check(not p.cloak.shown(), "a clip from the ranger's sheet draws its own cloak too")
	p.input.block_held = false
	GameState.data.equipment["armor"] = ""


## The PixelLab hero (design bible 13.5): the Delver's Pick is drawn on a pogo,
## its iron head reaching under the feet into the strike's hitbox, and the blow
## plays out over the bounce (a pogo ends the attack the frame it lands).
func test_the_delvers_pick_pogo_reaches_under_the_feet_and_plays_out() -> void:
	var s := Sheet.get_sheet("hero_base")
	check(Sheet.has_anim("hero_base", "strike_down"), "the base hero has a Delver's Pick pogo")
	var img := (s.tex as Texture2D).get_image()
	var cell: Vector2 = s.cell
	var origin: Vector2 = s.origin
	var den := float(s.density)
	var a: Dictionary = s.animations["strike_down"]
	var deepest := 0.0
	for i in a.frames.size():
		for y in range(int(origin.y), int(cell.y)):
			for x in range(int(cell.x)):
				if img.get_pixel(int(i * cell.x) + x, int(a.row * cell.y) + y).a > 0.5:
					deepest = maxf(deepest, (y - origin.y) / den)
	check(deepest >= 8.0 and deepest <= 24.0, "the Delver's Pick's head reaches under the feet, into the hitbox (%.1f px)" % deepest)
	GameState.new_game()
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(5, 2))
	p.global_position.y -= 40.0
	await frames(1)
	p.visual.anim = "strike_down"
	p.visual.anim_time = 0.0
	await frames(3)
	check(not p.is_attacking and p.visual.anim == "strike_down", "the blow plays on after the strike ends (%s)" % p.visual.anim)
	await frames(30)
	check(p.visual.anim != "strike_down", "and then gives way (%s)" % p.visual.anim)
	GameState.new_game()

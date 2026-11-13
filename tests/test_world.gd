extends TestSuite
## Rooms, breakables, targets and the gym file.


func test_gym_room_loads() -> void:
	var room := Room.from_file("res://levels/gym/gym.room")
	arena.add_child(room)
	check(room.title == "Movement Gym", "room title from header")
	check(room.size_tiles == Vector2i(170, 46), "gym size 170x46 tiles (got %s)" % room.size_tiles)
	check(room.spawn_position != Vector2.ZERO, "spawn marker found")
	var dummies := 0
	var cracked := 0
	var spikes := 0
	var bulbs := 0
	for c in room.get_children():
		if c is TrainingDummy: dummies += 1
		elif c is CrackedBlock: cracked += 1
		elif c is Spikes: spikes += 1
		elif c is ThornBulb: bulbs += 1
	check(dummies >= 3 and cracked >= 6 and spikes >= 20 and bulbs == 3, "gym entities: %d dummies, %d cracked, %d spikes, %d bulbs" % [dummies, cracked, spikes, bulbs])


func test_gym_spawn_is_safe() -> void:
	var room := Room.from_file("res://levels/gym/gym.room")
	arena.add_child(room)
	var p := Player.new()
	p.input.scripted = true
	p.position = room.spawn_position
	room.add_child(p)
	await frames(30)
	check(p.is_on_floor() and p.hp == p.max_hp, "player stands safely at the gym spawn")


func test_slash_hits_dummy() -> void:
	var room := make_room([
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"#....E.....#",
		"############",
	])
	var p := make_player(room, Vector2i(3, 4))
	await frames(6)
	var dummy: TrainingDummy
	for c in room.get_children():
		if c is TrainingDummy:
			dummy = c
	p.facing = 1
	p.input.attack_pressed = true
	await frames(8)
	check(dummy.hits_taken == 1, "one slash lands exactly one hit (got %d)" % dummy.hits_taken)


func test_down_strike_breaks_cracked_floor() -> void:
	var rows := [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"#........#",
		"#........#",
		"####CC####",
		"#........#",
		"##########",
	]
	var room := make_room(rows)
	var p := make_player(room, Vector2i(4, 1))
	p.position.x = 5 * Room.TILE
	var floor_y := 6 * Room.TILE
	for i in 60:
		if p.velocity.y > 0.0 and p.global_position.y > floor_y - 28.0 and not p.is_attacking:
			p.input.down = true
			p.input.attack_pressed = true
		await frames(1)
	check(p.global_position.y > 7 * Room.TILE, "fell through the broken floor (y %.1f)" % p.global_position.y)


func test_cracked_wall_needs_delvers_pick() -> void:
	var rows := [
		"##########",
		"#........#",
		"#........#",
		"#....C...#",
		"#....C...#",
		"#....C...#",
		"##########",
	]
	var room := make_room(rows)
	var p := make_player(room, Vector2i(4, 5), {"delvers_pick": false})
	await frames(6)
	p.facing = 1
	p.input.attack_pressed = true
	await frames(10)
	var intact := 0
	for c in room.get_children():
		if c is CrackedBlock and c.visible:
			intact += 1
	check(intact == 3, "slash without the Delver's Pick leaves the wall intact")
	p.abilities["delvers_pick"] = true
	await frames(20)
	p.input.attack_pressed = true
	await frames(10)
	intact = 0
	for c in room.get_children():
		if c is CrackedBlock and c.visible:
			intact += 1
	check(intact < 3, "slash with the Delver's Pick breaks cracked stone")


## Pass 465 (bible 11): a hidden room found with the buttons. Every secret test
## counted covers or set flags; none walked into one. Right held walks the hero
## through the fake wall: the cover fades, the find chimes and is kept. Walking
## out brings the wall back. The chime marks a find, so it rang again every time
## the room was entered; now a room already found fades in silence.
func test_a_hidden_room_is_found_with_the_buttons() -> void:
	GameState.new_game()
	var rows := grid_rows(40, 23)
	put_tiles(rows, 5, 19, "P")
	var rooms := {"test/town": room_text(["name: Town", "zone: test", "secret: 20, 16, 26, 19"], rows)}
	var w := make_world(rooms, "test/town", cell_feet(14, 19))
	var p := w.player
	p.input = PlayerInput.new()
	await frames(5)
	check(w.room.secrets != null and w.room.secrets.modulate.a == 1.0, "the cover stands whole")
	var inside := func() -> bool: return w.room.is_secret_at(p.global_position + Vector2(0, -12))
	var chimes: int = await _walk_counting_chimes("move_right", 90, inside)
	check(chimes == 1 and GameState.flag("secret:test/town"), "Right walks him through the fake wall: it chimes once and is kept (%d)" % chimes)
	check(inside.call() and w.room.secrets.modulate.a < 0.5, "and the cover fades (%.2f)" % w.room.secrets.modulate.a)
	await _walk_counting_chimes("move_left", 40)
	await frames(30)
	check(w.room.secrets.modulate.a == 1.0, "Left walks him out, and the wall stands again")
	chimes = await _walk_counting_chimes("move_right", 60, inside)
	check(w.room.secrets.modulate.a < 0.5 and chimes == 0, "in again: it fades without a second chime (%d)" % chimes)
	# Leave and come back: a fresh room, a find already made. He steps out of
	# the cover first, so the new room meets him outside it.
	await _walk_counting_chimes("move_left", 40)
	check(not inside.call(), "out of the cover again")
	w._enter("test/town")
	await frames(5)
	p.teleport(cell_feet(14, 19))
	await frames(5)
	chimes = await _walk_counting_chimes("move_right", 90, inside)
	check(w.room.secrets.modulate.a < 0.5, "back in the room, the cover still fades")
	check(chimes == 0, "but a room already found does not chime again (%d)" % chimes)


## Holds `action` for real for up to `steps` frames and counts the find chimes
## heard. Footsteps fill the sound log, so it is read and cleared every frame.
## With `stop`, it lets go once `stop` holds and stands a third of a second.
func _walk_counting_chimes(action: String, steps: int, stop := Callable()) -> int:
	var chimes := 0
	Sfx.recent.clear()
	Input.action_press(action)
	for i in steps:
		await frames(1)
		chimes += Sfx.recent.count("secret")
		Sfx.recent.clear()
		if stop.is_valid() and stop.call():
			break
	Input.action_release(action)
	for i in 20:
		await frames(1)
		chimes += Sfx.recent.count("secret")
		Sfx.recent.clear()
	return chimes


## Pass 427: cracked stone, through the real controller. The two tests above
## break it with a scripted intent that lasts one step; every large zone hides
## something behind it (pass 135). Here the buttons do it: Attack held with no
## Delver's Pick leaves the wall whole, and gaining the Delver's Pick with Attack still
## held breaks nothing (a held button is not pressed again); a fresh tap does.
## Down held alone lands on a cracked floor and leaves it; Down held with a
## tap of Attack on the way down breaks it, and you fall through.
func test_cracked_stone_answers_the_real_controller() -> void:
	var room := make_room([
		"##########",
		"#........#",
		"#........#",
		"#....C...#",
		"#....C...#",
		"#....C...#",
		"##########",
	])
	var p := make_player(room, Vector2i(4, 5), {"delvers_pick": false})
	p.input = PlayerInput.new()
	await frames(6)
	await press_for_real(p, ["move_right"])
	release_for_real(["move_right"])
	await frames(2)
	check(p.facing == 1, "Right turns you to the wall")
	Sfx.recent.clear()
	Input.action_press("attack")
	await frames(12)
	check(_whole(room) == 3 and not Sfx.recent.has("break"), "Attack with no Delver's Pick leaves the wall whole")
	p.abilities["delvers_pick"] = true
	await frames(30)
	check(_whole(room) == 3, "gaining the Delver's Pick with Attack still held breaks nothing")
	Input.action_release("attack")
	await frames(2)
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(10)
	check(_whole(room) < 3 and Sfx.recent.has("break"), "a fresh tap breaks the cracked stone, heard (%d whole)" % _whole(room))
	room.free()
	# The floor: Down alone lands on it; Down with a tap of Attack breaks it.
	room = make_room([
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"#........#",
		"#........#",
		"####CC####",
		"#........#",
		"##########",
	])
	p = make_player(room, Vector2i(4, 1), {"delvers_pick": true})
	p.position.x = 5 * Room.TILE
	p.input = PlayerInput.new()
	Input.action_press("move_down")
	for i in 60:
		await frames(1)
		if p.is_on_floor():
			break
	await frames(6)
	check(p.is_on_floor() and p.global_position.y <= 6 * Room.TILE + 1.0 and _whole(room) == 2,
		"Down held alone lands on the cracked floor and leaves it (y %.1f)" % p.global_position.y)
	Input.action_release("move_down")
	await frames(2)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(2)
	var floor_y := 6 * Room.TILE
	for i in 90:
		await frames(1)
		if p.velocity.y > 0.0 and p.global_position.y > floor_y - 28.0:
			break
	Input.action_press("move_down")
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(30)
	Input.action_release("move_down")
	check(_whole(room) < 2 and p.global_position.y > 7 * Room.TILE,
		"Down with a tap of Attack on the way down breaks it and you fall through (y %.1f)" % p.global_position.y)
	room.free()


func _whole(room: Room) -> int:
	var n := 0
	for c in room.get_children():
		if c is CrackedBlock and c.visible:
			n += 1
	return n


func test_gym_enemies_stay_put() -> void:
	var room := Room.from_file("res://levels/gym/gym.room")
	arena.add_child(room)
	var enemies: Array[Enemy] = []
	for c in room.get_children():
		if c is Enemy:
			enemies.append(c)
	check(enemies.size() == 3, "gym has 3 enemies (got %d)" % enemies.size())
	await frames(120)
	for e in enemies:
		var inside := room.pixel_rect().has_point(e.global_position)
		check(inside and not e.dead and e.global_position.distance_to(e.home) < 120.0,
			"%s stays near its post (home %s, now %s)" % [e.get_script().get_global_name(), e.home, e.global_position])


## Pass 390: a door that fades is heard. Tests skip fades (`World.instant`), so
## no whole run had ever played the door's creak: a door into another zone fades
## out on it, and the creak plays once, as the fade begins.
## A save whose room still stands but whose rested spot now sits in solid — a
## build that reshaped the room, or one hand-edited — must not wake the hero
## embedded in a wall, a soft-lock. He falls back to the room's own spawn; a
## still-valid saved spot is left where it is (pass 495).
func test_a_restored_position_in_solid_wakes_at_the_spawn() -> void:
	var rows := grid_rows(40, 23)
	put_tiles(rows, 5, 19, "P")
	put_tiles(rows, 20, 4, "#", 3, 6)
	var text := room_text(["name: Reshaped", "zone: hearthroot"], rows)
	# Rested in a spot the build has since walled over (deep inside the block).
	var in_solid := cell_center(21, 7)
	var w := make_world({"test/reshaped": text}, "test/reshaped", in_solid)
	check(w.room.is_solid_at(in_solid), "the old rested spot is now solid (%s)" % in_solid)
	check(w.player.global_position == w.room.spawn_position, "the hero wakes at the spawn, not in the wall (%s, spawn %s)" % [w.player.global_position, w.room.spawn_position])
	check(not w._embedded_at(w.player.global_position), "and his body is clear of solid")
	await frames(30)
	check(w.player.is_on_floor() and w.player.hp == w.player.max_hp, "he stands safely and can play on")
	w.queue_free()
	await frames(2)
	# A still-valid saved spot is honoured, not thrown away.
	var on_floor := cell_feet(14, 19)
	var w2 := make_world({"test/reshaped": text}, "test/reshaped", on_floor)
	check(w2.player.global_position == on_floor, "a valid restored spot is kept (%s, wanted %s)" % [w2.player.global_position, on_floor])
	w2.queue_free()
	await frames(2)


func test_a_door_that_fades_is_heard() -> void:
	var w := make_world({}, "hearthroot/east_gate")
	w.fader = ColorRect.new()
	w.fader.color = Color(0, 0, 0, 0)
	w.add_child(w.fader)
	w.instant = false
	await frames(2)
	check(w.transition_kind(w.room.doors[2]) == "fade", "the East Gate's door into the Heartwood fades")
	Sfx.recent.clear()
	w.use_door(2)
	await frames(int((World.FADE_OUT + World.FADE_IN) * 60.0) + 10)
	check(w.room.id == "heartwood/entrance", "and leads into the Heartwood")
	check(Sfx.recent.count("door") == 1, "the door creaks once as the fade begins (%s)" % [Sfx.recent])
	check(not w.busy and is_equal_approx(w.fader.color.a, 0.0), "and the fade clears")


func test_arriving_through_a_door_clears_cracked_stone_in_the_way() -> void:
	# The Kettleforge Stair can be entered from its far side (a test, a later shortcut);
	# coming back must not leave the player inside Winch Hall's cracked wall.
	var w := make_world({}, "tower/kettleforge_stair")
	await frames(2)
	w.use_door(1)
	await frames(3)
	check(w.room.id == "tower/winch_hall", "door 1 leads back to Winch Hall")
	var body := w.player.body_rect().grow(-1.0)
	var blocking := 0
	var cleared := 0
	for c in w.room.get_children():
		if c is CrackedBlock:
			var r := Rect2(c.global_position - Vector2(8, 8), Vector2(16, 16))
			if c.visible and r.intersects(body):
				blocking += 1
			if not c.visible:
				cleared += 1
	check(blocking == 0 and cleared > 0, "the stone around the arrival gave way (%d cleared)" % cleared)
	await frames(20)
	var feet := w.player.global_position
	check(w.player.is_on_floor() and not w.room.is_solid_at(feet + Vector2(0, -4)), "and the player stands on the floor, not in it (%s)" % feet)


# --- The Haar's fog ------------------------------------------------------------------

func _fog_world(ghost := Vector2i(-1, -1)) -> World:
	var rows := grid_rows(40, 23)
	put_tiles(rows, 3, 19, "P")
	put_tiles(rows, 30, 19, "S")
	put_tiles(rows, 20, 4, "#", 1, 16)
	if ghost.x >= 0:
		put_tiles(rows, ghost.x, ghost.y, "A")
	return make_world({"test/a": room_text(["name: Fog", "zone: haar"], rows)}, "test/a")


## Pass 120: lights that matter to play (a hag's wisp, a boss's lanterns) are
## lit before the decor's lanterns, so a room crowded with lanterns can never
## leave a foe dark.
func test_play_lights_come_before_the_lanterns() -> void:
	var w := _fog_world()
	await frames(3)
	var fog := w.fog
	var decor := w.room.get_node("Decor") as Decor
	var p := w.player
	for i in Fog.MAX_LIGHTS + 10:
		decor.glows.append(p.global_position + Vector2(i * 4.0, -30.0))
	var wisp := MarshHag.HagWisp.new()
	w.room.add_child(wisp)
	wisp.global_position = p.global_position + Vector2(200, -40)
	fog._update()
	check(fog.lights.size() == Fog.MAX_LIGHTS, "the room is crowded with lanterns (%d lights)" % fog.lights.size())
	check(fog.lights.has(Vector3(wisp.global_position.x, wisp.global_position.y, wisp.light_radius)), "and the wisp is still lit")
	check(fog.clear_at(wisp.global_position) == 1.0, "so the fog clears around it")


func test_the_haar_fog_hides_all_but_the_light() -> void:
	var w := _fog_world()
	await frames(3)
	var fog := w.fog
	check(fog.visible and fog.density == Fog.ZONES.haar, "the Haar is fogged (%.2f)" % fog.density)
	var p := w.player
	check(fog.clear_at(p.global_position + Vector2(0, -14)) == 1.0, "the player sees around themself")
	check(fog.lights[0] == Vector3(p.global_position.x, p.global_position.y - 14.0, Fog.VISION), "the player carries the first light")
	check(fog.lights.size() > 1, "the room's lanterns and shrine are lights too (%d)" % fog.lights.size())
	var own := fog.lights[0]
	fog.lights = [own]
	check(fog.clear_at(p.global_position + Vector2(Fog.VISION + 20.0, -14)) == 0.0, "past their sight the fog is thick")
	check(fog.visibility_at(Vector2(16 * 25, 100)) < 0.2, "out in the murk little shows through (%.2f)" % fog.visibility_at(Vector2(16 * 25, 100)))
	await frames(1)
	check(fog.clear_at(cell_feet(30, 19) + Vector2(0, -8)) == 1.0, "a shrine's glow clears a pocket")
	GameState.set_flag(Fog.SPRING_FLAG)
	fog.set_room(w.room)
	await frames(1)
	check(is_equal_approx(fog.density, Fog.ZONES.haar * Fog.SPRING_DENSITY), "the restored spring thins the fog by half")
	check(fog.clear_at(p.global_position + Vector2(Fog.VISION + 20.0, -14)) > 0.0, "and the player sees further")
	w._enter("tower/foot")
	await frames(1)
	check(not w.fog.visible and w.fog.visibility_at(Vector2(100, 100)) == 1.0, "other zones have no fog")


## Bible 3.2: until the Haar Spring runs the fog is the Haar Wyrm's steam, warm
## and rising. Restored, it is a cool mist. The people of the Haar say it is hot
## and that nobody knows why.
func test_the_haar_fog_is_steam_until_the_spring_runs() -> void:
	var w := _fog_world()
	await frames(3)
	var fog := w.fog
	check(fog.steaming(), "the fog steams while the Haar Wyrm lives")
	check(float(fog._mat.get_shader_parameter("steam")) == 1.0, "and the shader is told to rise")
	var src := FileAccess.get_file_as_string("res://shaders/fog.gdshader")
	check(src.find("uniform float steam") >= 0 and src.find("warm_color") >= 0 and src.find("wisp") >= 0, "the shader has warm, rising wisps")
	GameState.set_flag(Fog.SPRING_FLAG)
	fog.set_room(w.room)
	await frames(1)
	check(not fog.steaming() and float(fog._mat.get_shader_parameter("steam")) == 0.0, "the restored spring stops the steam")
	w._enter("tower/foot")
	await frames(1)
	check(not w.fog.steaming(), "no steam where there is no fog")
	var nell := " ".join(GameData.npc("lampwick_lamplighter").lines)
	var brigid := " ".join(GameData.npc("polesend_barmaid").lines)
	check(nell.find("warm") >= 0 and nell.find("why") >= 0, "Nell says the fog is warm and nobody knows why")
	check(brigid.find("Hot fog") >= 0, "Brigid says the fog is hot")
	check(" ".join(GameData.npc("lampwick_lamplighter").lines_cleared).find("breath") >= 0, "and afterwards Nell knows whose breath it was")


## Bible 4.4: bound fog seals the shaft above Lantern Landing. It tells you what
## it needs, holds without the Lantern Key, and parts for good when the key's
## light comes near. The key is not used up.
func test_bound_fog_parts_for_the_lantern_key() -> void:
	var w := make_world({}, "haar/lantern_landing", cell_feet(30, 19))
	await frames(3)
	var curtains := runner.get_tree().get_nodes_in_group("haar_curtain")
	check(curtains.size() == 3, "three tiles of bound fog seal the shaft (%d)" % curtains.size())
	var said: Array[String] = []
	var listen := func(text: String) -> void: said.append(text)
	GameState.toast.connect(listen)
	var c := curtains[0] as MistCurtain
	w.player.teleport(c.global_position + Vector2(0, 30))
	await frames(3)
	check(not c.parted and said.size() == 1 and said[0].contains("lantern"), "without the key it holds and says what it needs: %s" % [said])
	w.player.teleport(cell_feet(37, 9))
	await frames(2)
	GameState.add_key("lantern")
	await frames(3)
	var all_parted := true
	for n in runner.get_tree().get_nodes_in_group("haar_curtain"):
		all_parted = all_parted and (n as MistCurtain).parted
	check(all_parted and GameState.flag("curtain:haar/lantern_landing"), "the key's light parts every tile and the room remembers")
	check(GameState.key_count("lantern") == 1, "the Lantern Key is kept")
	GameState.toast.disconnect(listen)
	await frames(1)
	w._enter("haar/lantern_landing")
	await frames(2)
	var again := runner.get_tree().get_nodes_in_group("haar_curtain")
	check(not again.is_empty() and (again[0] as MistCurtain).parted, "back in the room, the fog is still parted")


## Pass 358 (bible 13.3): a tablet read and a ward that turns you away each
## have their own sound. The tablets had borrowed the door's creak and the fog
## and the veil the spell-fail fizzle; a refusal is not a spell gone wrong.
func test_tablets_and_wards_sound_like_themselves() -> void:
	# The fog and the veil, refusing for real: once each, and never a fizzle.
	for stop: Array in [["haar/lantern_landing", "haar_curtain", Vector2(0, 30)], ["boughs/north_bough", "stride_veil", Vector2(0, 16)]]:
		var w := make_world({}, stop[0], cell_feet(2, 2))
		await frames(3)
		var walls := runner.get_tree().get_nodes_in_group(stop[1])
		check(not walls.is_empty(), "%s has its %s" % [stop[0], stop[1]])
		if walls.is_empty():
			w.queue_free()
			await frames(2)
			continue
		Sfx.recent.clear()
		w.player.teleport((walls[0] as Node2D).global_position + stop[2])
		await frames(4)
		check(Sfx.recent.count("ward_refuse") == 1 and not Sfx.recent.has("fizzle"), "the %s pushes back once, no fizzle (%s)" % [stop[1], Sfx.recent])
		w.queue_free()
		await frames(2)
	# A tablet read for real.
	var w2 := make_world({}, "haar/lantern_landing")
	await frames(2)
	var tablet: LoreTablet = null
	for c in w2.room.get_children():
		if c is LoreTablet:
			tablet = c
	check(tablet != null, "the landing has a tablet")
	if tablet != null:
		Sfx.recent.clear()
		tablet.interact(w2.player)
		check(Sfx.recent == ["tablet_read"], "reading a tablet is heard as stone and runes, not a door (%s)" % [Sfx.recent])
	w2.queue_free()
	await frames(2)
	# Each is its own: no other script borrows them, and these three play neither cue they left.
	var owners := {"tablet_read": ["lore_tablet.gd"], "ward_refuse": ["haar_curtain.gd", "stride_veil.gd"]}
	var plays := RegEx.create_from_string("Sfx\\.play\\(\"([a-z_]+)\"")
	var dirs: Array[String] = ["res://scripts"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
		for f: String in DirAccess.get_files_at(d):
			if not f.ends_with(".gd"):
				continue
			for m: RegExMatch in plays.search_all(FileAccess.get_file_as_string(d + "/" + f)):
				var cue := m.get_string(1)
				if owners.has(cue):
					check(f in owners[cue], "%s is played only by its own (%s)" % [cue, f])
				if f == "lore_tablet.gd":
					check(cue != "door", "a tablet does not creak like a door")
				if f in ["haar_curtain.gd", "stride_veil.gd"]:
					check(cue != "fizzle", "%s does not fizzle" % f)
	for cue: String in owners:
		check(FileAccess.file_exists("res://assets/sfx/%s.wav" % cue), "%s has a file" % cue)


## Bible 4.1 (A3): the Featherstep Boots lie on a perch in Feather Hollow. Taking them
## grants the double jump, and the game remembers it.
func test_featherstep_boots_grant_the_double_jump() -> void:
	var w := make_world({}, "haar/feather_hollow")
	await frames(3)
	var p := w.player
	check(not p.abilities.boots, "the run starts without the Featherstep Boots")
	var boots: ItemPickup = null
	for c in w.room.get_children():
		if c is ItemPickup and (c as ItemPickup).kind == "boots":
			boots = c
	check(boots != null, "the boots lie on the perch")
	if boots == null:
		return
	p.teleport(boots.global_position + Vector2(0, 12))
	await frames(3)
	check(p.abilities.boots and GameState.data.abilities.boots, "taking them grants the double jump and the save remembers it")
	w._enter("haar/feather_hollow")
	await frames(2)
	var again := false
	for c in w.room.get_children():
		again = again or (c is ItemPickup and (c as ItemPickup).kind == "boots")
	check(not again, "they don't come back")


## Bible 4.1 (A5): the Elven Stride in the Windloft grants the dash, which
## does nothing before it, and the game remembers it.
func test_elven_stride_grants_the_dash() -> void:
	var w := make_world({}, "boughs/windloft")
	await frames(3)
	var p := w.player
	check(not p.abilities.stride, "the run starts without the Elven Stride")
	p.input.dash_pressed = true
	await frames(1)
	check(not p.is_dashing, "Dash does nothing without it")
	var feather: ItemPickup = null
	for c in w.room.get_children():
		if c is ItemPickup and (c as ItemPickup).kind == "stride":
			feather = c
	check(feather != null, "the Stride rests on the plinth")
	if feather == null:
		return
	p.teleport(feather.global_position + Vector2(0, 12))
	await frames(3)
	check(p.abilities.stride and GameState.data.abilities.stride, "taking it grants the dash and the save remembers it")
	await frames(10)
	p.input.dash_pressed = true
	await frames(1)
	check(p.is_dashing, "and now Dash strides")
	w._enter("boughs/windloft")
	await frames(2)
	var again := false
	for c in w.room.get_children():
		again = again or (c is ItemPickup and (c as ItemPickup).kind == "stride")
	check(not again, "it doesn't come back")


## Bible 4.1 (A4) and 4.5: the Deluge scroll grants the spell, the fire seal
## burns whoever touches it, and one Deluge bolt douses the whole seal for good.
func test_torrent_douses_the_fire_seal_for_good() -> void:
	var w := make_world({}, "haar/marsh_road")
	await frames(3)
	var p := w.player
	p.max_hp = 9999
	p.hp = 9999
	var seals := runner.get_tree().get_nodes_in_group("fire_seal")
	check(seals.size() == 4, "four tiles of fire seal the road east (%d)" % seals.size())
	check(not p.abilities.torrent, "the run starts without Deluge")
	var scroll: ItemPickup = null
	for c in w.room.get_children():
		if c is ItemPickup and (c as ItemPickup).kind == "torrent":
			scroll = c
	check(scroll != null, "the scroll lies on the perch")
	if scroll == null:
		return
	p.teleport(scroll.global_position + Vector2(0, 12))
	await frames(3)
	check(p.abilities.torrent and GameState.data.abilities.torrent, "taking it grants Deluge and the save remembers")
	# Touching the flames burns.
	var hp := p.hp
	var seal := seals[1] as FireSeal
	p.teleport(seal.global_position + Vector2(-9, 24))
	await frames(4)
	check(p.hp < hp, "the flames burn on touch")
	# Back off, face the seal and cast.
	p.teleport(seal.global_position + Vector2(-80, 24))
	p.mp = p.max_mp
	await frames(30)
	p.facing = 1
	p.input.spell_pressed = true
	var out := false
	for i in 60:
		await frames(1)
		if seal.doused:
			out = true
			break
	var all_out := true
	for s in runner.get_tree().get_nodes_in_group("fire_seal"):
		all_out = all_out and (s as FireSeal).doused
	check(out and all_out and GameState.flag("seal:haar/marsh_road"), "one bolt douses every tile and the room remembers")
	w._enter("haar/marsh_road")
	await frames(2)
	var again := runner.get_tree().get_nodes_in_group("fire_seal")
	check(not again.is_empty() and (again[0] as FireSeal).doused, "back in the room the seal is still out")


## Bible 4.5: a Deluge bolt cast across a dry basin fills it, and a raft floats
## up to the water-line stain, standing as a one-way platform for good.
func test_drowned_boardwalks_rise_with_the_spring_of_haar() -> void:
	for id: String in ["haar/lampwick_causeway", "haar/fog_cut"]:
		var w := make_world({}, id)
		await frames(2)
		var cell := Vector2(17 * Room.TILE + 4, 20 * Room.TILE + 4)
		check(not w.room.is_one_way_at(cell) and not w.room.is_solid_at(cell), "%s: the boardwalk is under the water while the spring is dry" % id)
		GameState.set_flag("spring:haar")
		w._enter(id)
		await frames(2)
		check(w.room.is_one_way_at(cell), "%s: with the spring flowing it rises" % id)
		w.player.teleport(Vector2(cell.x, 20 * Room.TILE))
		await frames(20)
		check(w.player.is_on_floor() and absf(w.player.global_position.y - 20 * Room.TILE) < 2.0, "%s: and holds the player over the spikes" % id)
		w.queue_free()
		await frames(2)


func test_torrent_fills_the_dry_basin_and_floats_a_raft() -> void:
	var w := make_world({}, "haar/dry_cistern")
	await frames(3)
	var p := w.player
	p.max_hp = 9999
	p.hp = 9999
	p.abilities["torrent"] = true
	var basins := runner.get_tree().get_nodes_in_group("dry_basin")
	check(basins.size() == 1, "the cistern has one basin (%d)" % basins.size())
	if basins.is_empty():
		return
	var b := basins[0] as DryBasin
	var raft := Vector2((b.x0 + 8) * Room.TILE + 8, b.water_row * Room.TILE + 4)
	var surface := b.water_row * Room.TILE
	check(not w.room.is_one_way_at(raft), "dry, there is nothing to stand on at the stain")
	# From the west rim, cast across the tank.
	p.teleport(cell_feet(b.x0 - 1, b.water_row - 1))
	p.mp = p.max_mp
	await frames(20)
	p.facing = 1
	p.input.spell_pressed = true
	var full := false
	for i in 120:
		await frames(1)
		if b.filled and b.level >= 1.0:
			full = true
			break
	check(full and GameState.flag(b.flag_id), "the bolt fills the basin and the room remembers")
	check(w.room.is_one_way_at(raft), "the raft stands at the stain as a one-way platform")
	var left := 0
	for e in runner.get_tree().get_nodes_in_group("enemy"):
		if not (e as Enemy).dead and (e as Enemy).center().y > b.water_row * Room.TILE:
			left += 1
	check(left == 0, "the myconids in the tank drown (%d left)" % left)
	# Walk out onto the raft: it holds.
	p.teleport(raft + Vector2(0, -6))
	await frames(30)
	check(p.is_on_floor() and absf(p.global_position.y - b.water_row * Room.TILE) < 2.0, "the player stands on the raft (%.1f)" % p.global_position.y)
	w._enter("haar/dry_cistern")
	await frames(2)
	check(w.room.is_one_way_at(raft), "back in the room, the basin is still full")
	await frames(2)
	var back := 0
	for e in runner.get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.is_queued_for_deletion() and (e as Enemy).center().y > surface:
			back += 1
	check(back == 0, "and nothing lives in the water (%d)" % back)


## Bible 4.5: a bramble wall blocks like stone and shrugs off blades, but one
## fireball sets the whole knot alight; it burns to ash and stays burnt.
func test_fire_burns_the_bramble_for_good() -> void:
	var w := make_world({}, "spires/spires")
	await frames(3)
	var p := w.player
	var brambles := runner.get_tree().get_nodes_in_group("bramble")
	check(brambles.size() == 4, "four tiles of bramble choke the bell cellar (%d)" % brambles.size())
	if brambles.is_empty():
		return
	var first := brambles[0] as BrambleWall
	# A blade does nothing to it.
	p.teleport(first.global_position + Vector2(-20, 8 + 16 * 3))
	await frames(3)
	p.facing = 1
	p.input.attack_pressed = true
	await frames(12)
	check(brambles.all(func(b: BrambleWall) -> bool: return not b.burning and not b.burnt), "a blade only snags in it")
	# A fireball at its foot: the fire creeps through the whole knot.
	var ball := Fireball.new()
	w.room.add_child(ball)
	ball.global_position = (brambles[3] as BrambleWall).global_position + Vector2(-14, 0)
	ball.velocity = Vector2(200, 0)
	await frames(3)
	check((brambles[3] as BrambleWall).burning, "the fireball sets it alight")
	await frames(90)
	check(brambles.all(func(b: BrambleWall) -> bool: return b.burnt), "every tile burns to ash")
	check(GameState.is_collected((brambles[0] as BrambleWall).persist_id), "the save remembers")
	# Back again: it stays ash, and the cellar is open.
	w._enter("spires/spires")
	await frames(2)
	var again := runner.get_tree().get_nodes_in_group("bramble")
	var left := again.filter(func(b: BrambleWall) -> bool: return not b.burnt)
	check(again.size() == 4 and left.is_empty(), "it doesn't grow back (%d unburnt)" % left.size())


## Bible 4.1 (A6) and 4.5: the Tempest Lance scroll grants the spell; a bolt cast near
## a dead conduit leaps to it and wakes it, and when the room's last conduit
## wakes its gate slides open for good.
func test_thunder_wakes_the_conduit_and_opens_the_gate() -> void:
	var w := make_world({}, "spires/spire_foot")
	await frames(3)
	var p := w.player
	check(not p.abilities.thunder, "the run starts without Tempest Lance")
	var scroll: ItemPickup = null
	for c in w.room.get_children():
		if c is ItemPickup and (c as ItemPickup).kind == "thunder":
			scroll = c
	check(scroll != null, "the scroll lies on the lectern")
	if scroll == null:
		return
	p.teleport(scroll.global_position + Vector2(0, 12))
	await frames(3)
	check(p.abilities.thunder and GameState.data.abilities.thunder, "taking it grants Tempest Lance")
	check(p.equipped_spell == "thunder", "and, with no other spell, puts it on the Spell button")
	var conduits := runner.get_tree().get_nodes_in_group("conductor")
	var gates := runner.get_tree().get_nodes_in_group("conduit_gate")
	check(conduits.size() == 1 and gates.size() == 4, "one conduit and a gate four tiles tall (%d, %d)" % [conduits.size(), gates.size()])
	if conduits.is_empty() or gates.is_empty():
		return
	var conduit := conduits[0] as Conduit
	# Cast from four tiles short of it: the bolt leaps the rest.
	p.teleport(conduit.global_position + Vector2(-64, 0))
	p.mp = p.max_mp
	await frames(20)
	p.facing = 1
	p.input.spell_pressed = true
	for i in 30:
		await frames(1)
		if conduit.powered:
			break
	check(conduit.powered, "the bolt leaps to the conduit and wakes it")
	check(GameState.flag("conduits:spires/spire_foot"), "the room remembers")
	await frames(60)
	check(gates.all(func(g: ConduitGate) -> bool: return g.opened), "and the gate slides open")
	w._enter("spires/spire_foot")
	await frames(2)
	var again := runner.get_tree().get_nodes_in_group("conduit_gate")
	check(not again.is_empty() and again.all(func(g: ConduitGate) -> bool: return g.opened), "back in the room the gate stays open")
	check((runner.get_tree().get_nodes_in_group("conductor")[0] as Conduit).powered, "and the conduit stays awake")


## The Spire Stair's hatch needs both its conduits awake, not just one.
func test_the_spire_hatch_needs_every_conduit() -> void:
	var w := make_world({}, "spires/spire_stair")
	await frames(3)
	var conduits := runner.get_tree().get_nodes_in_group("conductor")
	var gates := runner.get_tree().get_nodes_in_group("conduit_gate")
	check(conduits.size() == 2 and gates.size() == 3, "two conduits and a hatch three tiles wide (%d, %d)" % [conduits.size(), gates.size()])
	if conduits.size() < 2:
		return
	(conduits[0] as Conduit).power()
	await frames(2)
	check(gates.all(func(g: ConduitGate) -> bool: return not g.opened), "one conduit is not enough")
	(conduits[1] as Conduit).power()
	await frames(2)
	check(gates.all(func(g: ConduitGate) -> bool: return g.opened), "the second opens the hatch")
	check(GameState.flag("conduits:spires/spire_stair"), "for good")



# --- The Sky Spring (bible 4.4, pass 62) -----------------------------------

func _spring_in(w: World) -> Spring:
	for c in w.room.get_children():
		if c is Spring:
			return c
	return null


func test_spring_of_sky_waits_for_the_roc_and_breaks_the_storm() -> void:
	var w := make_world({}, "spires/sky_spring", cell_feet(4, 19))
	GameState.set_flag("spring:heartwood")
	GameState.set_flag("spring:haar")
	await frames(3)
	var spring := _spring_in(w)
	check(spring != null and spring.spring_id == "sky", "the Sky Spring stands past the roost")
	check(not spring.is_in_group("interactable"), "it can't be cleared while Skyrend lives")
	var rain := w.sheet_rain.density()
	check(w.sheet_rain.active and rain > 0.9, "the storm rains hard (density %.2f)" % rain)
	GameState.set_flag("boss:skyrend")
	await frames(2)
	check(spring.is_in_group("interactable"), "once the roc falls it can")
	spring.interact(w.player)
	check(GameState.flag("spring:sky"), "clearing it restores the Sky Spring")
	check(Fountain.level() == 3, "and the Hearthroot fountain runs full")
	check(w.sheet_rain.density() < rain / 2, "the storm breaks: the rain thins to a drizzle (density %.2f)" % w.sheet_rain.density())


## The rain sheet (SheetRain, pass 498) is Carillon's alone: it falls in the spires
## and nowhere else, and a zone with its own motes keeps them.
func test_rain_sheet_is_carillons_alone() -> void:
	var w := make_world({}, "spires/sky_steps")
	await frames(2)
	check(w.sheet_rain.active, "the rain sheet falls in Carillon")
	check(w.sheet_rain._frames.size() == SheetRain.FRAMES, "cut into its %d frames" % SheetRain.FRAMES)
	check(w.motes.zone != "spires", "with the code streak field stood down")
	w._enter("boughs/crown_leaf")
	await frames(2)
	check(not w.sheet_rain.active, "no sheet rain in the High Boughs")
	check(w.motes.zone == "boughs", "which keeps its own motes")
	w.queue_free()
	await frames(2)


func test_hearthroot_holds_a_festival_for_the_last_spring() -> void:
	GameState.new_game()
	var names := func() -> Array:
		var room := Room.from_file("res://levels/hearthroot/plaza.room")
		arena.add_child(room)
		var out := []
		for c in room.get_children():
			if c is Npc:
				out.append((c as Npc).npc_id)
		room.queue_free()
		out.sort()
		return out
	var before: Array = names.call()
	check(before == ["townsfolk_well"], "before: Old Wena by the dry fountain (%s)" % [before])
	GameState.set_flag("spring:sky")
	var after: Array = names.call()
	check(after == ["festival_piper", "townsfolk_well_glad"], "after: a piper plays and Wena is glad (%s)" % [after])


func test_the_tree_blooms_once_the_everbloom_is_dead() -> void:
	var w := make_world({}, "hearthroot/plaza", cell_feet(10, 19))
	await frames(2)
	check(w.blossom.zone == "" and w.motes.count() > 0, "before the end: Hearthroot's dust, and no blossom")
	var dust := w.motes.count()
	GameState.set_flag("cleared")
	w.travel("heartwood/entrance", cell_feet(6, 19))
	await frames(3)
	check(w.blossom.zone == "heartwood" and w.blossom.count() == int(Motes.BLOSSOM[0]), "after it, blossom drifts through the Heartwood")
	check(w.blossom.get("_motes").size() == w.blossom.count(), "a petal for each count (%d)" % w.blossom.count())
	for z: String in ["hearthroot", "heartwood", "tower", "haar", "boughs", "spires"]:
		check(Motes.blossom_table().has(z), "%s is a living zone of the Tree: it blooms" % z)
	check(not Motes.blossom_table().has("evercrown") and not Motes.blossom_table().has("vorrhallow"), "the Everbloom and the drowned city don't")
	w.travel("evercrown/threshold", cell_feet(20, 19))
	await frames(3)
	check(w.blossom.get("_motes").is_empty(), "no blossom in the dead stillglass")
	check(w.motes.count() == roundi(int(Motes.ZONES.evercrown[0]) * 0.2), "and its spores have settled (%d)" % w.motes.count())
	check(dust > 0, "Hearthroot kept its dust (%d)" % dust)


func test_the_town_speaks_of_the_blooming_tree() -> void:
	var npcs: Dictionary = GameData.table("npcs")
	var talkers := 0
	for id: String in npcs:
		if String(npcs[id].get("role", "talk")) in ["talk", "king"]:
			talkers += 1
			check(npcs[id].has("lines_cleared") or not _stands_in_a_living_town(id), "%s has something to say once the Tree blooms" % id)
	check(talkers > 10, "the scan reads the talkers (%d)" % talkers)
	var king := GameData.npc("king")
	GameState.new_game()
	check(Npc.lines(king, "lines_after") == king.lines_after, "before the end the King says his piece")
	GameState.set_flag("cleared")
	check(Npc.lines(king, "lines_after") == king.lines_cleared and Npc.lines(king, "lines") == king.lines_cleared,
		"after it, he speaks of the blooming Tree")
	GameState.new_game()


## Lampwick (pass 145): a town in the fog is a string of warm pockets. Its lamp
## posts burn holes in the murk, its houses are lit from the first visit (its
## people never left), and the Feather Hollow's west shelf is the way in.
func test_victims_lamps_burn_pockets_in_the_fog() -> void:
	var w := make_world({}, "haar/lampwick", cell_feet(40, 19))
	await frames(3)
	var lamps: Array = []
	var houses := 0
	for c in w.room.get_children():
		if c is TownLamp:
			lamps.append(c)
		elif c is HouseFront:
			houses += 1
			check((c as HouseFront).style == "haar" and (c as HouseFront).lit(), "a boardwalk house is lit before any spring flows")
	check(lamps.size() >= 4 and houses >= 3, "Lampwick has its lamps (%d) and houses (%d)" % [lamps.size(), houses])
	check(w.fog.visible and w.fog.density > 0.0 and w.fog.density < Fog.ZONES["haar"], "the fog lies over the town, thinner than out in the marsh (%.2f)" % w.fog.density)
	var lamp := lamps[0] as TownLamp
	check(lamp.is_in_group("light"), "a lamp is a light")
	w.player.global_position = Vector2(lamp.global_position.x + 400, w.player.global_position.y)
	await frames(2)
	var seen := false
	for l: Vector3 in w.fog.lights:
		if is_equal_approx(l.x, lamp.global_position.x) and is_equal_approx(l.y, lamp.global_position.y):
			seen = l.z >= 80.0
	check(seen, "and the fog clears a pocket around its flame")
	check(w.fog.clear_at(lamp.global_position + Vector2(0, 20)) > 0.5, "so the street under it can be seen")
	check(w.fog.clear_at(lamp.global_position + Vector2(170, 0)) < 0.5, "while the dark between the lamps stays dark")
	# The door east is the Feather Hollow's west shelf.
	w._enter("haar/feather_hollow")
	await frames(2)
	check(w.room.doors.has(2) and String(w.room.doors[2].target) == "haar/lampwick", "the Feather Hollow's west door leads to Lampwick")


## Pass 146: coming up a shaft, you arrive inside the floor door of the room
## above, still rising. Fall back before you clear it and the door takes you
## back down; it used to be ignored, and you dropped out of the room's bottom.
func test_falling_back_down_a_shaft_takes_the_door_down() -> void:
	var w := make_world({}, "tower/mine_vault")
	await frames(3)
	w.use_door(1)
	while w.busy:
		await frames(1)
	check(w.room.id == "tower/rail_gallery", "the vault's shaft rises into the Rail Gallery")
	check(w.room.doors[2].edge == "bottom" and (w.room.doors[2].rect as Rect2).intersects(w.player.body_rect()), "arriving inside its floor door")
	# Stall at once, as a dash into the shaft's wall does, and fall.
	w.player.velocity = Vector2.ZERO
	var fell_out := false
	for i in 90:
		await frames(1)
		if w.room.id == "tower/rail_gallery" and w.player.global_position.y > w.room.pixel_rect().end.y + 8.0:
			fell_out = true
	check(not fell_out, "you never drop out of the bottom of the room")
	check(w.room.id == "tower/mine_vault", "the door takes you back down to the vault")


## Pass 151: the Polesend soak dropped down the Scorched Hall's floor shaft and met
## Polesend's spikes before it first landed. The hazard set it back at its last
## safe footing, which was still the Scorched Hall's, so it appeared inside
## Polesend's ground. A floor or ceiling door now makes its arrival the first safe spot.
func test_spikes_before_the_first_landing_set_you_back_in_the_new_room() -> void:
	var w := make_world({}, "haar/scorched_hall", cell_feet(4, 19))
	await frames(5)
	var old_safe := w.player.safe_position
	w.use_door(3)
	while w.busy:
		await frames(1)
	check(w.room.id == "haar/polesend", "the Scorched Hall's floor shaft drops into Polesend")
	var p := w.player
	check(p.safe_position != old_safe and w.room.pixel_rect().has_point(p.safe_position) and not w.room.is_solid_at(p.safe_position + Vector2(0, -8)),
		"the arrival under the shaft is the first safe spot (%s, was %s)" % [p.safe_position, old_safe])
	# Spikes before any landing: set back in Polesend, in the open.
	p._invuln_timer = 0.0
	p.take_damage(1, true)
	await frames(2)
	var body := p.body_rect().grow(-3.0)
	var embedded := false
	for corner in [body.position, Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), body.end, body.get_center()]:
		embedded = embedded or w.room.is_solid_at(corner)
	check(w.room.id == "haar/polesend" and not embedded, "and a hazard there sets you back in the open (%s)" % p.global_position)
	# The first landing takes over as the safe footing.
	for i in 60:
		await frames(1)
		if p.is_on_floor():
			break
	await frames(3)
	check(p.is_on_floor() and absf(p.safe_position.y - p.global_position.y) < 1.0, "landing makes the footing safe again (%s)" % p.safe_position)


## People a player meets once the Everbloom is dead: everyone but the Heartwood's
## widow and Old Wena before their springs, who are swapped for glad selves.
func _stands_in_a_living_town(id: String) -> bool:
	return not id in ["townsfolk_well", "amberlee_widow"]


func test_the_sky_key_opens_dartmoors_upper_gate() -> void:
	var w := make_world({}, "spires/sky_spring", cell_feet(30, 19))
	await frames(3)
	var gate: KeyDoor = null
	for c in w.room.get_children():
		if c is KeyDoor:
			gate = c
	check(gate != null and gate.kind == "sky", "a sky gate bars the way down")
	w.player.input.move_x = 1
	await frames(40)
	check(is_instance_valid(gate) and w.player.global_position.x < gate.global_position.x, "without the Sky Key it holds")
	GameState.add_key("sky")
	await frames(30)
	check(not is_instance_valid(gate) or gate.is_queued_for_deletion(), "with it, the gate opens")
	check(GameState.key_count("sky") == 0, "and the key stays in the lock")
	w.player.input.move_x = 0
	w._enter("spires/sky_spring")
	await frames(3)
	var again := 0
	for c in w.room.get_children():
		if c is KeyDoor:
			again += 1
	check(again == 0, "it stays open")



# --- Vorrhallow (bible zone 6, pass 63) -----------------------------------------

func test_the_upper_gate_drops_you_into_vorrhallow() -> void:
	var w := make_world({}, "spires/sky_spring", cell_feet(36, 19))
	await frames(3)
	for c in w.room.get_children():
		if c is KeyDoor:
			c.queue_free()
	var fell := false
	for i in 240:
		await frames(1)
		if w.room.id == "vorrhallow/upper_stair":
			fell = true
			break
	check(fell, "the shaft past the upper gate drops you into the Upper Stair (%s)" % w.room.id)
	await frames(60)
	check(w.player.is_on_floor() and w.player.global_position.y < 9 * Room.TILE, "onto the top landing (%s)" % w.player.global_position)
	check(w.room.zone == "vorrhallow" and Music.track == "vorrhallow" and Music.ambience_track == "amb_vorrhallow", "Vorrhallow has its own theme and ambience (%s, %s)" % [Music.track, Music.ambience_track])
	check(w.motes.zone == "vorrhallow" and w.motes._motes.size() > 0, "and crystal dust in the air")
	check(World.ZONES.has("vorrhallow"), "the map knows the zone")


func test_the_gate_hall_has_a_shrine() -> void:
	var w := make_world({}, "vorrhallow/gate_hall")
	await frames(3)
	var shrines := 0
	for c in w.room.get_children():
		if c is SaveShrine:
			shrines += 1
	check(shrines == 1, "the Upper Gate-Hall has a shrine to rest at")


## Old Hearthroot (design bible 11, pass 152): a hidden room behind the Temple of
## Rings, drawn as the NES drew it, with a four-voice chip tune.
func test_retro_rooms_keep_everything_inside_the_frame() -> void:
	# Playtest: Old Hearthroot's way out sat behind the 4:3 frame's black bar.
	var cols := RetroFilter.visible_columns()
	check(cols == Vector2i(5, 34), "a one-screen room shows columns 5 to 34 in the frame (%s)" % cols)
	var parsed := Room.parse(FileAccess.get_file_as_string("res://levels/hearthroot/old_hearthroot.room"))
	check(str(parsed.header.get("retro", "")) == "true", "Old Hearthroot is a retro room")
	var grid: Array[String] = parsed.grid
	var hidden := 0
	for y in grid.size():
		for x in grid[y].length():
			if (x < cols.x or x > cols.y) and grid[y][x] != "#":
				hidden += 1
	check(hidden == 0, "every column outside the frame is wall (%d open cells hidden)" % hidden)
	var doors := Room.scan_doors(grid)
	for n: int in doors:
		var r: Rect2i = doors[n].rect
		check(r.position.x - 1 >= cols.x and r.end.x <= cols.y, "door %d and its frame are in view (%s)" % [n, r])
	for key: String in ["sign", "chest", "prop"]:
		for spec: String in parsed.lists.get(key, []):
			var x := int(spec.split(",")[0])
			check(x >= cols.x and x <= cols.y, "%s at column %d is in view" % [key, x])


func test_hearthroot_of_old_hides_behind_the_temple() -> void:
	var w := make_world({}, "hearthroot/ringreader_temple", cell_feet(30, 19))
	await frames(5)
	check(not w.retro.visible and Music.track == "hearthroot", "the temple is drawn and scored as usual (%s)" % Music.track)
	check(not GameState.flag("secret:hearthroot/ringreader_temple"), "the chamber starts hidden")
	# Walk east into the stone: it is a fake wall, and the chamber behind is found.
	var p := w.player
	p.input.move_x = 1
	for i in 120:
		await frames(1)
		if p.global_position.x > 36.5 * Room.TILE:
			break
	p.input.move_x = 0
	check(p.global_position.x > 36.0 * Room.TILE, "the player walks through the temple's east wall (%s)" % p.global_position)
	check(GameState.flag("secret:hearthroot/ringreader_temple"), "and finds the hidden chamber")
	await frames(10)
	p.input.up_pressed = true
	p.input.up = true
	await frames(1)
	p.input.up_pressed = false
	p.input.up = false
	for i in 120:
		await frames(1)
		if not w.busy and w.room.id == "hearthroot/old_hearthroot":
			break
	check(w.room.id == "hearthroot/old_hearthroot", "Up at the chamber's door goes to Old Hearthroot (%s)" % w.room.id)
	check(w.retro.visible and RetroFilter.is_retro(w.room), "Old Hearthroot is drawn through the NES filter")
	check(w.retro.layer < 5, "under the game's UI layer, so the HUD is untouched")
	check(Music.track == "old_hearthroot", "and plays its chip tune (%s)" % Music.track)
	var stream := Music.stream_for("old_hearthroot")
	check(stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop, "the chip tune loads as a loop")
	check(w.room._chest_gold.values().has(1987), "its chest holds 1987 gold, the year of the source game")
	w.use_door(1)
	while w.busy:
		await frames(1)
	check(w.room.id == "hearthroot/ringreader_temple" and not w.retro.visible and Music.track == "hearthroot", "back in the temple the filter is off and the town theme returns")


## Pass 155: the NES filter's blocks are whole world pixels. The world view draws
## at GameCamera.DETAIL with a pixel of margin (1284 x 724), so the filter takes
## its detail from the view (2), not from the view's height over 360 (2.01).
func test_the_nes_filter_blocks_on_world_pixels() -> void:
	check(RetroFilter.detail_for(null) == 1.0, "no view: one render pixel a world pixel")
	var vp := SubViewport.new()
	vp.size = Vector2i(642, 362) * GameCamera.DETAIL
	arena.add_child(vp)
	check(RetroFilter.detail_for(vp) == float(GameCamera.DETAIL), "the game's world view: %d (%.2f)" % [GameCamera.DETAIL, RetroFilter.detail_for(vp)])
	vp.queue_free()
	check(RetroFilter.SHADER.code.contains("block * detail"), "and a block is block x detail render pixels")


## Pass 178: the mini-bosses' towns know them. A squire by Sylvarre's east door
## points to the Thorn Yard and speaks differently once the Captain falls; in
## the Drowned Market, woken by Thane Vorrund's fall, the old houndkeeper tells of
## the Alpha under the kennels and rests once it is wound down. Several room
## conditions, space-separated, must all hold.
func test_the_towns_know_their_mini_bosses() -> void:
	GameState.new_game()
	var ids := func(path: String) -> Array:
		var room := Room.from_file(path)
		arena.add_child(room)
		var out := room.get_children().filter(func(c: Node) -> bool: return c is Npc).map(func(c: Npc) -> String: return c.npc_id)
		room.free()
		return out
	const SYLVARRE := "res://levels/boughs/sylvarre.room"
	const MARKET := "res://levels/vorrhallow/drowned_market.room"
	const POLESEND := "res://levels/haar/polesend.room"
	var r: Array = ids.call(POLESEND)
	check(r.has("polesend_reedcutter") and not r.has("polesend_reedcutter_glad"), "in Polesend, the reedcutter warns of the Matriarch past the east door (pass 179)")
	check(" ".join(GameData.npc("polesend_reedcutter").lines).contains("east door"), "and names where she waits")
	GameState.set_flag("boss:hag_matriarch")
	r = ids.call(POLESEND)
	check(r.has("polesend_reedcutter_glad") and not r.has("polesend_reedcutter"), "and is glad once she sinks for good")
	var c: Array = ids.call(SYLVARRE)
	check(c.has("sylvarre_squire") and not c.has("sylvarre_squire_glad"), "before the Captain falls, the squire points to the Thorn Yard")
	var m: Array = ids.call(MARKET)
	check(not m.has("vorrhallow_houndkeeper") and not m.has("vorrhallow_houndkeeper_glad"), "the drowned market is empty while Vorrund reigns")
	GameState.set_flag("boss:clockwork_alpha")
	m = ids.call(MARKET)
	check(not m.has("vorrhallow_houndkeeper_glad"), "an Alpha beaten first changes nothing until the market wakes")
	GameState.set_flag("boss:clockwork_alpha", false)
	GameState.set_flag("boss:thane_vorrund")
	m = ids.call(MARKET)
	check(m.has("vorrhallow_houndkeeper") and not m.has("vorrhallow_houndkeeper_glad"), "with Vorrund gone, the houndkeeper tells of the Alpha")
	GameState.set_flag("boss:clockwork_alpha")
	GameState.set_flag("boss:bark_captain")
	m = ids.call(MARKET)
	c = ids.call(SYLVARRE)
	check(m.has("vorrhallow_houndkeeper_glad") and not m.has("vorrhallow_houndkeeper"), "and rests once the Alpha is wound down")
	check(c.has("sylvarre_squire_glad") and not c.has("sylvarre_squire"), "the squire speaks of the Captain's fall")
	var hint: Array = GameData.npc("sylvarre_squire").lines
	check(" ".join(hint).contains("Thorn Yard") and " ".join(GameData.npc("vorrhallow_houndkeeper").lines).contains("kennels"), "each hint names where the guardian waits")
	check(Room.flags_hold("boss:thane_vorrund boss:clockwork_alpha") and not Room.flags_hold("boss:thane_vorrund !boss:clockwork_alpha") and Room.flags_hold(""),
		"conditions all have to hold")
	GameState.new_game()


## Design bible 3 (pass 195): no room is more than SAVE_REACH rooms (doors
## walked) from a Meditation Shrine or a Ringreader, and where foes hit at double
## (CombatTuning.ZONE_THREAT, 5.5) no more than DEEP_SAVE_REACH.
const SAVE_REACH := 4
const DEEP_SAVE_REACH := 3


func test_no_room_is_far_from_a_rest() -> void:
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json"))
	var links := {}
	var zones := {}
	var rests: Array[String] = []
	for zone in DirAccess.get_directories_at("res://levels"):
		if zone == "gym" or zone == "trials":
			continue
		for f in DirAccess.get_files_at("res://levels/" + zone):
			if not f.ends_with(".room"):
				continue
			var id := zone + "/" + f.get_basename()
			var parsed := Room.parse(FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, f]))
			zones[id] = zone
			if not links.has(id):
				links[id] = {}
			for spec: String in parsed.lists.get("door", []):
				var to := spec.split(",")[1].strip_edges()
				links[id][to] = true
				if not links.has(to):
					links[to] = {}
				links[to][id] = true
			var rest := false
			for row: String in parsed.grid:
				rest = rest or row.contains("S")
			for spec: String in parsed.lists.get("npc", []):
				var who := spec.split(",")[2].strip_edges()
				rest = rest or str(npcs.get(who, {}).get("role", "")) == "ringreader"
			if rest:
				rests.append(id)
	check(rests.size() >= 25, "the world has its shrines and Ringreaders (%d)" % rests.size())
	var dist := {}
	var queue: Array[String] = []
	for id in rests:
		dist[id] = 0
		queue.append(id)
	while not queue.is_empty():
		var at: String = queue.pop_front()
		for to: String in links.get(at, {}):
			if not dist.has(to):
				dist[to] = dist[at] + 1
				queue.append(to)
	for id: String in zones:
		var deep := float(CombatTuning.ZONE_THREAT.get(zones[id], 1.0)) >= 2.0
		var reach := DEEP_SAVE_REACH if deep else SAVE_REACH
		check(dist.has(id) and int(dist[id]) <= reach, "%s is within %d rooms of a rest (%s)" % [id, reach, dist.get(id, "none")])


## Pass 477: a door's fade ran on game time, so at 70% Game speed it took 1.4
## times as long, and walking out of an arena in a guardian's slow motion
## (30%) more than three times as long. It is real time at every speed.
func test_a_door_fades_in_real_time_at_every_game_speed() -> void:
	for speed: float in [1.0, 0.7, 0.3]:
		var w := make_world({}, "hearthroot/east_gate")
		w.fader = ColorRect.new()
		w.fader.color = Color(0, 0, 0, 0)
		w.add_child(w.fader)
		w.instant = false
		await frames(2)
		Feel.set_game_speed(speed)
		w.use_door(2)
		var n := 0
		while w.busy and n < 300:
			await frames(1)
			n += 1
		Feel.set_game_speed(1.0)
		var whole := int((World.FADE_OUT + World.FADE_IN) * 60.0)
		check(w.room.id == "heartwood/entrance" and n <= whole + 4, "at %d%% the door's fade takes %d frames (at most %d)" % [roundi(speed * 100.0), n, whole + 4])
		w.queue_free()
		await frames(2)
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_a_door_fades_in_real_time_at_every_game_speed`"), "the bible names the test")


## Pass 479: bible 2 tells the story in turns, and the Story and world row of the
## rubric asks that each shows in the game. No test held them, and one did not
## show: Thane Vorrund was meant to weep at last as he gave up Severance, and no
## one saw it. Each turn is held here to the words the game speaks and to the
## room where they are spoken.
func test_every_turn_of_the_story_is_told_in_the_game() -> void:
	var says := func(id: String, room: String, words: Array) -> void:
		var lines := " ".join(PackedStringArray(GameData.npc(id).get("lines", [])))
		for w: String in words:
			check(lines.contains(w), "%s says \"%s\"" % [GameData.npc(id).get("name", id), w])
		var text := FileAccess.get_file_as_string("res://levels/%s.room" % room)
		var placed := false
		for line in text.split("\n"):
			if line.begins_with("npc:") and line.get_slice(",", 2).strip_edges() == id:
				placed = true
		check(placed, "and stands in %s" % room)
	# Act I: the Reeve's doubt, and the turn in Amberlee.
	says.call("king", "hearthroot/king_hall", ["strangers since the leaves stopped falling", "a stranger is one more mouth"])
	says.call("amberlee_miner", "heartwood/amberlee", ["We did. The Hollin. Our Thane gave the word"])
	# Act II: Carillon's oldest record, and the name it keeps.
	says.call("spires_mayor", "spires/spires", ["the year of the Withering", "Thane Vorrund, who planted the flower"])
	# Act III: beaten, Vorrund weeps at last and gives up Severance.
	var vorrund: Dictionary = BossArena.BOSSES.thane_vorrund
	check(vorrund.blade == "severance" and String(vorrund.text).contains("weeps at last") and String(vorrund.text).contains("grafting blade"),
		"Thane Vorrund weeps at last and gives up his blade (%s)" % vorrund.text)
	var kennels := FileAccess.get_file_as_string("res://levels/vorrhallow/kings_kennels.room")
	check(kennels.contains("[boss:thane_vorrund]") and kennels.get_slice("[boss:thane_vorrund]", 1).get_slice("\n", 0).contains("wept there at last"),
		"and the sign to his throne says so after him")
	# The ending: the leaves fall, and Hearthroot keeps the Leaffall.
	check(" ".join(PackedStringArray(EndingScreen.FAREWELL)).contains("Leaffall festival"), "the ending names the Leaffall festival")
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_every_turn_of_the_story_is_told_in_the_game`"), "the bible names the test")


## The spell gates by the real Spell button at the slowest Game speed (pass
## 489). The gates' tests cast with a scripted intent at full speed, or set a
## fireball down by hand. Here each spell is readied and cast with the real
## Spell button at 70%: Deluge douses the Marsh Road's seal and fills the Dry
## Cistern's basin, Tempest Lance wakes the Spire Foot's conduit, and Emberfall,
## thrown from the floor, sets the bell cellar's bramble alight.
func test_the_spell_gates_open_by_the_buttons_at_the_slowest_game_speed() -> void:
	Feel.set_game_speed(0.7)
	var cases := [
		["haar/marsh_road", "torrent", "fire_seal", Vector2(-80, 24)],
		["haar/dry_cistern", "torrent", "dry_basin", Vector2.ZERO],
		["spires/spire_foot", "thunder", "conductor", Vector2(-64, 0)],
		["spires/spires", "fire", "bramble", Vector2(-80, 8)],
	]
	for c: Array in cases:
		var room_id: String = c[0]
		var spell: String = c[1]
		var group: String = c[2]
		var w := make_world({}, room_id)
		await frames(3)
		var p := w.player
		p.max_hp = 9999
		p.hp = 9999
		p.abilities[spell] = true
		GameState.data.abilities[spell] = true
		p.equipped_spell = spell
		var targets := runner.get_tree().get_nodes_in_group(group)
		if not check(not targets.is_empty(), "%s: the gate is there" % room_id):
			w.queue_free()
			await frames(2)
			continue
		var t: Node2D = targets[0] if group != "bramble" else targets[targets.size() - 1]
		if group == "dry_basin":
			var b := t as DryBasin
			p.teleport(cell_feet(b.x0 - 1, b.water_row - 1))
		elif group == "fire_seal":
			p.teleport((targets[1] as Node2D).global_position + c[3])
		else:
			p.teleport(t.global_position + c[3])
		p.mp = p.max_mp
		await frames(30)
		p.facing = 1
		var mp0 := p.mp
		await press_for_real(p, ["spell"])
		release_for_real(["spell"])
		var opened := false
		for i in 240:
			await frames(1)
			match group:
				"fire_seal": opened = (t as FireSeal).doused
				"dry_basin": opened = (t as DryBasin).filled
				"conductor": opened = (t as Conduit).powered
				"bramble": opened = (t as BrambleWall).burning or (t as BrambleWall).burnt
			if opened:
				break
		check(p.mp < mp0 - 1.0, "%s: the Spell button casts %s at 70%% (%.0f -> %.0f MP)" % [room_id, Spells.DATA[spell].name, mp0, p.mp])
		check(opened, "%s: and %s opens the gate" % [room_id, Spells.DATA[spell].name])
		w.queue_free()
		await frames(2)
	Feel.set_game_speed(1.0)
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("test_the_spell_gates_open_by_the_buttons_at_the_slowest_game_speed"), "the bible names this test")

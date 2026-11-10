extends TestSuite
## Gnarlmaw and its arena (design bible 8 and 8.1), the Heartwood Spring and
## the world-state change it makes (4.4).

const ARENA_ROOM := "heartwood/root_chamber"


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await frames(1)
	return cond.call()


func _arena(w: World) -> BossArena:
	for c in w.room.get_children():
		if c is BossArena:
			return c
	return null


## A boss dropped straight into the Root Chamber, without the arena.
func _boss_world() -> Array:
	var w := make_world({}, ARENA_ROOM, cell_feet(4, 19))
	GameState.set_flag("boss:gnarlmaw")  # keep the arena from starting its own fight
	var boss := Gnarlmaw.new()
	boss.room = w.room
	w.room.add_child(boss)
	return [w, boss]


func _count(w: World, type: Variant) -> int:
	var n := 0
	for c in w.room.get_children():
		if is_instance_of(c, type) and not c.is_queued_for_deletion():
			n += 1
	return n


func test_arena_seals_the_doors_and_wakes_the_boss() -> void:
	var w := make_world({}, ARENA_ROOM)
	var p := w.player
	await frames(3)
	var arena := _arena(w)
	check(arena != null, "the Root Chamber has a boss arena")
	check(arena.entry_door == 1 and arena.seals.size() == 1 and arena.seals.has(2), "the exit is sealed, the way in is not (%s)" % [arena.seals.keys()])
	check(get_tree_boss() == null, "the boss waits until the player is inside")
	p.teleport(cell_feet(12, 19))
	var woke := await _until(func() -> bool: return arena.fighting, 20)
	check(woke and get_tree_boss() != null, "walking in wakes Gnarlmaw")
	check(arena.seals.size() == 2, "both doors are sealed during the fight")
	p.teleport(cell_feet(2, 19))
	p.input.move_x = -1
	await frames(40)
	check(w.room.id == ARENA_ROOM, "the sealed door can't be used")


func get_tree_boss() -> Node:
	return runner.get_tree().get_first_node_in_group("boss")


func test_telegraphs_are_fair() -> void:
	for tell: float in [Gnarlmaw.LUNGE_TELL, Gnarlmaw.PLUNGE_TELL, Gnarlmaw.DANGLE_TELL, SapClump.TELL]:
		check(tell >= Enemy.MIN_TELEGRAPH, "every wind-up is at least %.2f s (%.2f)" % [Enemy.MIN_TELEGRAPH, tell])


func test_tail_takes_full_damage_and_the_plates_a_quarter() -> void:
	var setup := _boss_world()
	var boss: Gnarlmaw = setup[1]
	await frames(2)
	boss.state = "stuck"
	var tail := boss.segments[Gnarlmaw.SEGMENTS - 1]
	var body := boss.segments[8]
	check(tail.is_tail and not body.is_tail, "the last segments are the tail")
	boss.hit_segment(tail, 20, Vector2.RIGHT)
	check(boss.hp == Gnarlmaw.MAX_HP - 20, "the tail takes full damage (hp %d)" % boss.hp)
	await frames(1)
	boss.hit_segment(body, 20, Vector2.RIGHT)
	check(boss.hp == Gnarlmaw.MAX_HP - 25, "the bark plates take a quarter (hp %d)" % boss.hp)
	await frames(1)
	var before := boss.hp
	boss.hit_segment(body, 20, Vector2.RIGHT)
	boss.hit_segment(tail, 20, Vector2.RIGHT)
	boss.hit_segment(boss.segments[Gnarlmaw.SEGMENTS - 2], 20, Vector2.RIGHT)
	check(before - boss.hp == 20, "one swing over several segments counts once, at the best rate (%d)" % (before - boss.hp))


func test_floor_lunge_misses_the_ledges() -> void:
	var setup := _boss_world()
	var w: World = setup[0]
	var boss: Gnarlmaw = setup[1]
	var p := w.player
	# On the low wall ledge, above the lunge.
	p.teleport(cell_feet(4, 13))
	await frames(5)
	check(p.is_on_floor(), "standing on the ledge")
	boss._start_lunge(Gnarlmaw.FLOOR_LANE, false)
	var done := await _until(func() -> bool: return boss.state == "rest", 400)
	check(done, "the lunge crosses the room and leaves (state %s)" % boss.state)
	check(p.hp == p.max_hp, "the ledge is safe from a floor lunge (hp %d)" % p.hp)
	# On the floor, it hits.
	p.teleport(cell_feet(20, 19))
	await frames(5)
	boss._start_lunge(Gnarlmaw.FLOOR_LANE, false)
	await _until(func() -> bool: return p.hp < p.max_hp, 300)
	check(p.hp < p.max_hp, "standing on the floor, the lunge hits")


func test_stuck_lunge_leaves_the_tail_by_the_entry_wall() -> void:
	var setup := _boss_world()
	var w: World = setup[0]
	var boss: Gnarlmaw = setup[1]
	w.player.teleport(cell_feet(4, 13))
	await frames(3)
	boss._start_lunge(Gnarlmaw.FLOOR_LANE, true)
	var stuck := await _until(func() -> bool: return boss.state == "stuck", 300)
	check(stuck, "the second kind of lunge bites into the far wall")
	# The player is on the left, so it came from the right wall.
	var tail := boss.tail_position()
	check(tail.x > Gnarlmaw.ARENA.end.x - 140.0 and tail.x < Gnarlmaw.ARENA.end.x, "the tail is near the wall it came from (x %.0f)" % tail.x)
	check(boss.segments[Gnarlmaw.SEGMENTS - 1].active, "the tail can be hit")
	check(boss.head_position().x < Gnarlmaw.ARENA.position.x + 4.0, "the head is in the far wall (x %.0f)" % boss.head_position().x)
	var free := await _until(func() -> bool: return boss.state == "rest", 400)
	check(free, "it pulls itself through and leaves")


func test_phases_follow_health() -> void:
	var setup := _boss_world()
	var w: World = setup[0]
	var boss: Gnarlmaw = setup[1]
	await frames(2)
	boss.hp = int(Gnarlmaw.MAX_HP * 0.61)
	boss._next_move()
	check(boss.phase == 1, "above 60 percent it stays in phase 1")
	boss.hp = int(Gnarlmaw.MAX_HP * 0.59)
	boss._next_move()
	check(boss.phase == 2 and boss.state == "roar", "below 60 percent it roars into phase 2")
	await _until(func() -> bool: return boss.state != "roar", 200)
	check(boss.state == "rain", "phase 2 opens with sap rain (%s)" % boss.state)
	boss.hp = int(Gnarlmaw.MAX_HP * 0.29)
	boss._next_move()
	check(boss.phase == 3, "below 30 percent it enters phase 3")
	var mid := Vector2(20 * Room.TILE + 8, Gnarlmaw.FLOOR_Y + 4)
	check(w.room.is_solid_at(mid), "the floor is whole before the tear")
	await _until(func() -> bool: return boss.state != "roar", 200)
	check(not w.room.is_solid_at(mid), "phase 3 tears the floor away")
	check(_count(w, Spikes) >= 20, "spikes line the pit (%d)" % _count(w, Spikes))
	check(w.room.is_solid_at(Vector2(3 * Room.TILE, Gnarlmaw.FLOOR_Y + 4)), "the floor by the walls stays")
	check(boss.state == "lunge_tell" and absf(boss._rail_from.y - Gnarlmaw.LOW_LANE) < 1.0, "phase 3 lunges along the ledges")


func test_sap_clump_hardens_into_a_platform() -> void:
	var setup := _boss_world()
	var w: World = setup[0]
	var p := w.player
	var clump := SapClump.new()
	clump.room = w.room
	clump.position = Vector2(300, 34)
	w.room.add_child(clump)
	var landed := await _until(func() -> bool: return _count(w, SapMound) > 0, 120)
	check(landed, "the clump lands and hardens")
	var mound: SapMound
	for c in w.room.get_children():
		if c is SapMound:
			mound = c
	check_near(mound.position.y, Gnarlmaw.FLOOR_Y, 0.5, "the mound sits on the floor")
	p.teleport(Vector2(300, Gnarlmaw.FLOOR_Y - SapMound.SIZE.y - 2))
	await frames(10)
	check(p.is_on_floor() and absf(p.global_position.y - (Gnarlmaw.FLOOR_Y - SapMound.SIZE.y)) < 1.5, "the player can stand on it (y %.1f)" % p.global_position.y)
	await frames(int(SapMound.LIFETIME * 60.0) + 5)
	check(_count(w, SapMound) == 0, "it crumbles after a while")


func test_sap_clump_hurts() -> void:
	var setup := _boss_world()
	var w: World = setup[0]
	var p := w.player
	p.teleport(cell_feet(20, 19))
	await frames(3)
	var clump := SapClump.new()
	clump.room = w.room
	clump.position = Vector2(p.global_position.x, 34)
	w.room.add_child(clump)
	await _until(func() -> bool: return p.hp < p.max_hp, 120)
	check(p.hp == p.max_hp - SapClump.DAMAGE, "a falling clump hurts (hp %d)" % p.hp)


## Pass 228: the Stillstone holds every hazard a foe looses, not only the ones
## that fly. Gnarlmaw's sap and the Haar Wyrm's steam breath (and a Puffcap's
## spores) went on falling, rolling and stinging in stopped time.
func test_the_stillstone_holds_every_loosed_hazard() -> void:
	var setup := _boss_world()
	var w: World = setup[0]
	var p := w.player
	p.teleport(cell_feet(20, 19))
	await frames(3)
	TimeStop.start()
	var clump := SapClump.new()
	clump.room = w.room
	clump.position = Vector2(p.global_position.x, 34)
	w.room.add_child(clump)
	var breath := SteamBreath.new()
	breath.ground_y = p.global_position.y
	breath.left = 0.0
	breath.right = 2000.0
	w.room.add_child(breath)
	breath.global_position = Vector2(p.global_position.x - 30.0, p.global_position.y)
	var cloud := SporeCloud.new()
	w.room.add_child(cloud)
	cloud.global_position = p.body_rect().get_center()
	var at := [clump.position, breath.global_position, cloud.global_position]
	await frames(90)
	check(p.hp == p.max_hp, "in stopped time nothing loosed hurts (hp %d)" % p.hp)
	check(clump.position == at[0], "the sap drip hangs on the ceiling")
	check(breath.global_position == at[1], "the steam breath stands still")
	check(cloud.global_position == at[2], "the spores hang in the air")
	TimeStop.reset()
	var hurt := await _until(func() -> bool: return p.hp < p.max_hp, 120)
	check(hurt, "when time runs again they do")
	# Every hazard a foe looses (anything outside the foes themselves that
	# strikes the player) must ask the glass.
	for dir in ["res://scripts/bosses/", "res://scripts/enemies/"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir + f)
			if src.contains("receive_attack(") and not src.contains("extends Enemy") and not src.contains("class_name Enemy\n") and not src.contains("TimeStop.active()"):
				check(false, "%s strikes the player but ignores the Stillstone" % f)


func test_defeat_gives_the_reward_once() -> void:
	var w := make_world({}, ARENA_ROOM)
	var p := w.player
	await frames(3)
	var arena := _arena(w)
	p.teleport(cell_feet(12, 19))
	await _until(func() -> bool: return arena.fighting, 20)
	var boss: Gnarlmaw = get_tree_boss()
	await frames(2)
	boss.state = "stuck"
	boss.hp = 1
	boss.hit_segment(boss.segments[Gnarlmaw.SEGMENTS - 1], 10, Vector2.RIGHT)
	check(boss.dead and boss.state == "dying", "the last hit starts the death")
	var gone := await _until(func() -> bool: return boss.state == "dead", 900)
	check(gone, "every segment shatters")
	check(GameState.data.rings.has("thaw"), "the Thaw Seed is won")
	check(GameState.flag("boss:gnarlmaw"), "the boss is marked beaten")
	check(int(GameState.data.xp) == Gnarlmaw.XP, "boss XP (%d)" % int(GameState.data.xp))
	var expected_points := 1 + int(GameState.data.rank)
	check(int(GameState.data.skill_points) == expected_points, "one skill point plus the rank-ups (%d)" % int(GameState.data.skill_points))
	# Slow motion runs on wall-clock time, so wait on the result, not a frame count.
	var opened := await _until(func() -> bool: return arena.seals.is_empty() and _count(w, ArenaSeal) == 0, 1200)
	check(opened, "the doors open again")
	w._enter(ARENA_ROOM)
	await frames(5)
	check(get_tree_boss() == null and _count(w, ArenaSeal) == 0, "it never comes back")


func test_spring_hardens_sap_and_fills_the_fountain() -> void:
	var rows := grid_rows(40, 23)
	put_tiles(rows, 3, 19, "P")
	put_tiles(rows, 20, 19, "~", 4, 2)
	put_tiles(rows, 20, 20, "#", 4, 1)
	put_tiles(rows, 20, 21, "#", 4, 1)
	put_tiles(rows, 20, 19, "~", 4, 1)
	var rooms := {"test/spring": room_text(["name: Spring", "zone: heartwood", "prop: 8, 19, spring_heartwood"], rows)}
	var w := make_world(rooms, "test/spring")
	var p := w.player
	var sap_at := Vector2(21 * Room.TILE + 8, 19 * Room.TILE + 8)
	check(w.room.is_sap_at(sap_at) and not w.room.is_solid_at(sap_at), "sap before the spring")
	check(Fountain.level() == 0, "the fountain starts dry")
	p.teleport(cell_feet(8, 19))
	await frames(3)
	p.input.up_pressed = true
	await frames(2)
	check(GameState.flag("spring:heartwood"), "pressing Up restores the spring")
	check(Fountain.level() == 1, "the fountain is a third full")
	check(Fountain.state() == "third", "and shows its third-full state")
	w._enter("test/spring")
	check(w.room.is_solid_at(sap_at) and not w.room.is_sap_at(sap_at), "the sap is solid amber now")


func test_a_spring_answers_the_real_controller() -> void:
	# Bible 4.4: the springs are the source game's fountains. Every spring test set
	# a scripted Up, which lasts one step; here the real Up is held for many.
	var rows := grid_rows(40, 23)
	put_tiles(rows, 3, 19, "P")
	var rooms := {"test/spring": room_text(["name: Spring", "zone: haar", "prop: 8, 19, spring_haar"], rows)}
	var w := make_world(rooms, "test/spring", cell_feet(8, 19))
	var p := w.player
	p.input = PlayerInput.new()
	await frames(3)
	var banners: Array[String] = []
	var hear := func(title: String, _text: String) -> void: banners.append(title)
	GameState.banner.connect(hear)
	Sfx.recent.clear()
	# the Haar Wyrm still coils around it: Up does nothing.
	Input.action_press("move_up")
	await frames(3)
	Input.action_release("move_up")
	await frames(2)
	check(not GameState.flag("spring:haar") and banners.is_empty() and not Sfx.recent.has("secret"),
		"Up at the Haar Spring while the Haar Wyrm lives does nothing (%s)" % [banners])
	GameState.set_flag("boss:haar_wyrm")
	await frames(2)
	# Up pressed in the air is no use, and held down to the landing it is not pressed again.
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await _until(func() -> bool: return not p.is_on_floor() and p.velocity.y > -60.0, 60)
	Input.action_press("move_up")
	await _until(func() -> bool: return p.is_on_floor(), 90)
	await frames(6)
	check(not GameState.flag("spring:haar") and banners.is_empty(),
		"Up pressed in the air and held to the landing does not restore it")
	Input.action_release("move_up")
	await frames(2)
	# On the ground, one real tap restores it: the flag, the fountain, the banner and the chime.
	Input.action_press("move_up")
	await frames(2)
	Input.action_release("move_up")
	await frames(2)
	check(GameState.flag("spring:haar") and Fountain.level() == 1, "a tap of Up on the ground restores it and fills a third of the fountain")
	check(banners == ["Haar Spring restored"] and Sfx.recent.has("secret"), "with one banner and the chime (%s, %s)" % [banners, Sfx.recent])
	Input.action_press("move_up")
	await frames(3)
	Input.action_release("move_up")
	await frames(2)
	GameState.banner.disconnect(hear)
	check(banners.size() == 1, "and Up again announces nothing more (%s)" % [banners])


func test_music_follows_rooms_and_bosses() -> void:
	for name: String in ["title", "hearthroot", "heartwood", "tower", "boss", "miniboss", "durgan", "kettleforge", "gloamweaver", "haar_wyrm", "amb_heartwood", "amb_hearthroot", "amb_tower", "amb_heights", "amb_mine", "haar", "amb_haar", "lampwick", "polesend", "boughs", "amb_boughs", "sylvarre", "snapcrown", "spires", "amb_spires", "spires_town", "skyrend", "vorrhallow", "amb_vorrhallow", "vorrund", "likeness", "evercrown", "amb_evercrown", "everbloom", "sunken", "amb_sunken", "warden"]:
		var stream := Music.stream_for(name)
		check(stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop, "%s is a looping track" % name)
	var w := make_world({}, "heartwood/boss_gate")
	check(Music.track == "heartwood" and Music.ambience_track == "amb_heartwood", "the Heartwood plays its theme and ambience (%s)" % Music.track)
	w.use_door(2)
	await frames(3)
	check(Music.track == "heartwood", "the arena keeps the zone theme until the fight")
	var arena := _arena(w)
	w.player.teleport(cell_feet(12, 19))
	await _until(func() -> bool: return arena.fighting, 20)
	check(Music.track == "boss", "the fight plays the boss theme")


func test_tower_rooms_pick_their_ambience_and_theme() -> void:
	# Bible 11: each part of the Tower has its own bed; Kettleforge has its own theme.
	var w := make_world({}, "tower/winch_hall")
	check(Music.track == "tower" and Music.ambience_track == "amb_tower", "the Tower's halls hum with machinery")
	GameState.set_flag("boss:durgan")
	for stop: Array in [["tower/old_flue", "tower", "amb_heights"], ["tower/rafters", "tower", "amb_heights"],
			["tower/kettleforge", "kettleforge", "amb_tower"], ["tower/mine_mouth", "tower", "amb_mine"], ["tower/smelter", "tower", "amb_mine"], ["haar/fog_cut", "haar", "amb_haar"], ["haar/lampwick", "lampwick", "amb_haar"], ["haar/polesend", "polesend", "amb_haar"], ["boughs/sunlit_bough", "boughs", "amb_boughs"], ["boughs/sylvarre", "sylvarre", "amb_boughs"]]:
		w._enter(stop[0])
		await frames(1)
		check(Music.track == stop[1] and Music.ambience_track == stop[2], "%s plays %s over %s (%s, %s)" % [stop[0], stop[1], stop[2], Music.track, Music.ambience_track])


func test_after_the_end_hearthroot_feasts_and_the_meteor_goes_still() -> void:
	for name: String in ["hearthroot_bloom", "evercrown_still", "amb_evercrown_still"]:
		var stream := Music.stream_for(name)
		check(stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop, "%s is a looping track" % name)
	var w := make_world({}, "hearthroot/plaza")
	check(Music.track == "hearthroot", "before the end, Hearthroot plays its theme (%s)" % Music.track)
	w._enter("evercrown/threshold")
	await frames(1)
	check(Music.track == "evercrown" and Music.ambience_track == "amb_evercrown", "and the Everbloom its heartbeat (%s, %s)" % [Music.track, Music.ambience_track])
	GameState.set_flag("cleared")
	w._enter("evercrown/heart_stair")
	await frames(1)
	check(Music.track == "evercrown_still" and Music.ambience_track == "amb_evercrown_still",
		"after it, the dead stillglass goes still (%s, %s)" % [Music.track, Music.ambience_track])
	w._enter("hearthroot/market")
	await frames(1)
	check(Music.track == "hearthroot_bloom" and Music.ambience_track == "amb_hearthroot", "and Hearthroot plays its festival (%s, %s)" % [Music.track, Music.ambience_track])
	w._enter("heartwood/entrance")
	await frames(1)
	check(Music.track == "heartwood", "other zones keep their own themes (%s)" % Music.track)
	check(Music.after_the_end("boss") == "boss", "and a fight still plays its fight")
	GameState.new_game()


## Bible 13.3 (pass 150): each spring's zone plays a restored variant of its
## music once the spring flows, and the storm's bed over Carillon becomes a
## drizzle. Restoring a spring turns the music then and there.
## Pass 214: a track Sean supplies as .mp3 or .wav plays in place of the
## generated .ogg placeholder of the same name, and a supplied .ogg (which
## replaces the placeholder's file) still plays.
func test_a_supplied_track_replaces_its_placeholder() -> void:
	var dir := Music.DIR
	var files := {dir + "haar.ogg": true, dir + "haar.mp3": true, dir + "tower.ogg": true, dir + "hearthroot.wav": true, dir + "hearthroot.ogg": true}
	var has := func(path: String) -> bool: return files.has(path)
	check(Music.path_for("haar", has) == dir + "haar.mp3", "a supplied .mp3 plays over the placeholder (%s)" % Music.path_for("haar", has))
	check(Music.path_for("hearthroot", has) == dir + "hearthroot.wav", "and so does a supplied .wav (%s)" % Music.path_for("hearthroot", has))
	check(Music.path_for("tower", has) == dir + "tower.ogg", "an .ogg alone plays (%s)" % Music.path_for("tower", has))
	check(Music.path_for("nowhere", has) == "", "a track with no file plays nothing")
	check(Music.path_for("haar") == dir + "haar.ogg" and Music.stream_for("haar") != null, "the real placeholder is found")


func test_restored_springs_change_their_zones_music() -> void:
	for name: String in ["heartwood_restored", "haar_restored", "spires_restored", "amb_spires_restored"]:
		var stream := Music.stream_for(name)
		check(stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop, "%s is a looping track" % name)
	var w := make_world({}, "heartwood/spring_of_heartwood")
	await frames(1)
	check(Music.track == "heartwood", "before the spring, the Heartwood plays its theme (%s)" % Music.track)
	var spring: Spring = null
	for c in w.room.get_children():
		if c is Spring:
			spring = c
	check(spring != null, "(the Heartwood Spring)")
	spring.interact(w.player)
	await frames(1)
	check(Music.track == "heartwood_restored", "restoring the spring turns the music at once (%s)" % Music.track)
	w._enter("haar/drowned_stair")
	await frames(1)
	check(Music.track == "haar" and Music.ambience_track == "amb_haar", "the Haar waits on its own spring (%s)" % Music.track)
	GameState.set_flag("spring:haar")
	w._enter("haar/dry_cistern")
	await frames(1)
	check(Music.track == "haar_restored" and Music.ambience_track == "amb_haar", "then plays through the thinner fog (%s, %s)" % [Music.track, Music.ambience_track])
	w._enter("spires/broken_shrine")
	await frames(1)
	check(Music.track == "spires" and Music.ambience_track == "amb_spires", "the storm rages over Carillon (%s, %s)" % [Music.track, Music.ambience_track])
	GameState.set_flag("spring:sky")
	w._enter("spires/fallen_bridge")
	await frames(1)
	check(Music.track == "spires_restored" and Music.ambience_track == "amb_spires_restored",
		"until the Sky Spring breaks it (%s, %s)" % [Music.track, Music.ambience_track])
	w._enter("haar/lampwick")
	await frames(1)
	check(Music.track == "lampwick", "a town keeps its own theme (%s)" % Music.track)
	check(Music.restored("boss") == "boss" and Music.restored("boughs") == "boughs", "and only the springs' zones change")
	GameState.new_game()


func test_reveal_bursts_out_and_withdraws() -> void:
	var setup := _boss_world()
	var boss: Gnarlmaw = setup[1]
	var cards: Array = []
	var on_banner := func(title: String, sub: String) -> void: cards.append(title + " " + sub)
	GameState.banner.connect(on_banner)
	await frames(2)
	boss.begin()
	GameState.banner.disconnect(on_banner)
	check(cards.size() == 1 and String(cards[0]).begins_with(Gnarlmaw.DISPLAY_NAME), "a name card announces him (%s)" % [cards])
	await frames(int((Gnarlmaw.INTRO_EMERGE + 0.3) * 60.0))
	var head := boss.head_position()
	check(Gnarlmaw.ARENA.has_point(head) and absf(head.x - 4 * 16) > 300.0, "the head bursts out of the far wall (%s)" % head)
	var hit_before := boss.hp
	boss.hit_segment(boss.segments[0], 50, Vector2.RIGHT)
	check(boss.hp == hit_before, "he can't be hurt during the reveal")
	var moved := await _until(func() -> bool: return boss.state != "intro", 200)
	check(moved and boss.state == "lunge_tell", "then the fight begins (%s)" % boss.state)


func test_tail_damage_staggers_him() -> void:
	var setup := _boss_world()
	var boss: Gnarlmaw = setup[1]
	await frames(2)
	boss._start_lunge(Gnarlmaw.FLOOR_LANE, true)
	var stuck := await _until(func() -> bool: return boss.state == "stuck", 400)
	check(stuck, "a stuck lunge")
	var tail := boss.segments[Gnarlmaw.SEGMENTS - 1]
	for i in 5:
		boss.hit_segment(tail, 8, Vector2.RIGHT)
		await frames(1)
	check(boss.stagger_left == 0.0, "40 tail damage is not enough")
	boss.hit_segment(tail, 8, Vector2.RIGHT)
	check(boss.stagger_left > 0.0, "48 tail damage in one window staggers him")
	check(boss.state_time < 0.0, "and pins him in the wall longer (state time %.2f)" % boss.state_time)
	await frames(1)
	var hp0 := boss.hp
	boss.hit_segment(boss.segments[8], 20, Vector2.RIGHT)
	check(boss.hp == hp0 - 20, "while staggered the plates take full damage (hp %d)" % boss.hp)
	var still := await _until(func() -> bool: return boss.stagger_left == 0.0, 200)
	await frames(1)
	var hp1 := boss.hp
	boss.hit_segment(boss.segments[8], 20, Vector2.RIGHT)
	check(still and boss.hp == hp1 - 5, "and back to a quarter when it passes (hp %d)" % boss.hp)


# --- The Foreman (Hollin Tower mini-boss) ------------------------------------------

const FOREMAN_ROOM := "tower/foreman_hall"


## The Foreman dropped into his hall without the arena, awake.
func _foreman_world(cell := Vector2i(30, 19)) -> Array:
	var w := make_world({}, FOREMAN_ROOM, cell_feet(4, 19))
	GameState.set_flag("boss:foreman")  # keep the arena from starting its own fight
	var f := Foreman.new()
	f.arena = Rect2(16, 64, 608, 256)
	f.position = cell_feet(cell.x, cell.y)
	w.room.add_child(f)
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(2)
	f.set_state("walk")
	return [w, f]


func _count_rubble(w: World, mode: String) -> int:
	var n := 0
	for c in w.room.get_children():
		if c is Rubble and c.mode == mode and not c.is_queued_for_deletion():
			n += 1
	return n


func test_foreman_hall_wakes_the_golem() -> void:
	var w := make_world({}, FOREMAN_ROOM)
	await frames(3)
	var arena := _arena(w)
	check(arena != null and arena.boss_id == "foreman", "the Foreman's Hall is a boss arena")
	w.player.teleport(cell_feet(10, 19))
	var woke := await _until(func() -> bool: return arena.fighting, 20)
	var f := get_tree_boss() as Foreman
	check(woke and f != null, "walking in wakes the Foreman")
	check(f != null and f.global_position.x > w.player.global_position.x + 200.0, "he stands at the far end of the hall")
	check(arena.seals.has(1), "the way in seals behind the player")


func test_foreman_telegraphs_are_fair() -> void:
	var f := Foreman.new()
	for ph in [1, 2]:
		f.phase = ph
		for t: float in [Foreman.POUND_TELL, Foreman.THROW_TELL, Foreman.CHARGE_TELL]:
			check(f.tell(t) >= Enemy.MIN_TELEGRAPH, "phase %d tell %.2f s is at least %.2f s" % [ph, f.tell(t), Enemy.MIN_TELEGRAPH])
	check(Rubble.TELL >= Enemy.MIN_TELEGRAPH, "a falling rock marks its spot for at least %.2f s" % Enemy.MIN_TELEGRAPH)
	f.free()


func test_foreman_charges_into_the_wall_and_is_stunned() -> void:
	var r := await _foreman_world(Vector2i(20, 19))
	var w: World = r[0]
	var f: Foreman = r[1]
	w.player.teleport(cell_feet(6, 19))
	await frames(1)
	f.facing = 1
	f.set_state("charge_tell")
	var tell_frames := [0]  # lambdas capture locals by value, so count in an array
	var stunned := await _until(func() -> bool:
		if f.state == "charge_tell":
			tell_frames[0] += 1
		return f.stunned(), 240)
	check(tell_frames[0] / 60.0 >= Enemy.MIN_TELEGRAPH, "he scrapes the floor for at least %.2f s first (%d frames)" % [Enemy.MIN_TELEGRAPH, tell_frames[0]])
	check(stunned and f.global_position.x > 34 * Room.TILE, "charged into the far wall and is stunned (x %.0f)" % f.global_position.x)
	check(_count_rubble(w, "fall") >= 3, "the impact shakes rocks loose from the ceiling (%d)" % _count_rubble(w, "fall"))
	var hp0 := f.hp
	f.take_hit(8, Vector2.LEFT)
	check(f.hp == hp0 - 8, "stunned, he takes a blow in full")


func test_foreman_rock_halves_blows_unless_from_above() -> void:
	var r := await _foreman_world()
	var f: Foreman = r[1]
	var hp0 := f.hp
	f.take_hit(8, Vector2.RIGHT)
	check(f.hp == hp0 - 4, "his rock halves a blow (%d)" % (hp0 - f.hp))
	f.take_hit(8, Vector2(0, 1))
	check(f.hp == hp0 - 12, "a blow from above lands in full")
	check(f.state == "walk", "blows don't interrupt him")


func test_foreman_pound_sends_a_shockwave_each_way() -> void:
	var r := await _foreman_world()
	var w: World = r[0]
	var f: Foreman = r[1]
	w.player.teleport(cell_feet(26, 19))
	f.facing = -1
	f.set_state("pound_tell")
	var dirs := {}
	await _until(func() -> bool:
		for c in w.room.get_children():
			if c is Shockwave:
				dirs[c.direction] = true
		return dirs.size() == 2, 120)
	check(dirs.has(-1) and dirs.has(1), "two shockwaves roll out, one each way (%s)" % [dirs.keys()])


func test_foreman_throws_a_boulder_at_the_player() -> void:
	var r := await _foreman_world()
	var w: World = r[0]
	var f: Foreman = r[1]
	w.player.teleport(cell_feet(22, 19))
	f.facing = -1
	f.set_state("throw_tell")
	var hp := w.player.hp
	var thrown := await _until(func() -> bool: return _count_rubble(w, "thrown") > 0, 90)
	check(thrown, "he lobs a boulder")
	var hit := await _until(func() -> bool: return w.player.hp < hp, 90)
	check(hit, "it lands on the player standing still")


func test_foreman_defeat_gives_the_delvers_pick() -> void:
	var w := make_world({}, FOREMAN_ROOM)
	var p := w.player
	await frames(3)
	check(not p.abilities.delvers_pick, "no Delver's Pick before the fight")
	var arena := _arena(w)
	p.teleport(cell_feet(10, 19))
	await _until(func() -> bool: return arena.fighting, 20)
	var f := get_tree_boss() as Foreman
	await frames(2)
	f.set_state("stunned")
	f.hp = 1
	f.take_hit(8, Vector2.RIGHT)
	check(f.state == "dying", "the last blow topples him")
	var gone := await _until(func() -> bool: return GameState.flag("boss:foreman"), 600)
	check(gone, "the Foreman is marked beaten")
	check(p.abilities.delvers_pick and bool(GameState.data.abilities.delvers_pick), "the Delver's Pick is the player's")
	var opened := await _until(func() -> bool: return arena.seals.is_empty() and _count(w, ArenaSeal) == 0, 1200)
	check(opened, "the way out opens")
	w._enter(FOREMAN_ROOM)
	await frames(5)
	check(get_tree_boss() == null, "he never comes back")


# --- Durgan (Hollin Tower boss) ---------------------------------------------------

const LIFT_ROOM := "tower/kettleforge_lift"


## Durgan dropped onto the lift without the arena, awake.
func _zora_world(cell := Vector2i(30, 19)) -> Array:
	var w := make_world({}, LIFT_ROOM, cell_feet(4, 19))
	GameState.set_flag("boss:durgan")  # keep the arena from starting its own fight
	await frames(1)
	var arena := _arena(w)
	for n: int in w.room.doors:
		arena._seal(n)  # as in the real fight: both doorways barred
	var z := Durgan.new()
	z.arena = Rect2(16, 64, 608, 256)
	z.position = cell_feet(cell.x, cell.y)
	w.room.add_child(z)
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(2)
	z.set_state("walk")
	return [w, z]


func test_kettleforge_lift_wakes_durgan() -> void:
	var w := make_world({}, LIFT_ROOM)
	await frames(3)
	var arena := _arena(w)
	check(arena != null and arena.boss_id == "durgan", "the Kettleforge Lift is a boss arena")
	w.player.teleport(cell_feet(10, 19))
	var woke := await _until(func() -> bool: return arena.fighting, 20)
	var z := get_tree_boss() as Durgan
	check(woke and z != null, "walking in wakes Durgan")
	check(z != null and z.global_position.x > w.player.global_position.x + 200.0, "the drill waits across the lift")
	check(_count(w, LiftShaft) == 1, "the shaft is drawn behind the fight")
	check(arena.seals.has(1), "the way in seals behind the player")


func test_durgan_telegraphs_are_fair() -> void:
	var z := Durgan.new()
	for ph in [1, 2, 3]:
		z.phase = ph
		for t: float in [Durgan.DRILL_TELL, Durgan.SLAM_TELL, Durgan.DIVE_TELL]:
			check(z.tell(t) >= Enemy.MIN_TELEGRAPH, "phase %d tell %.2f s is at least %.2f s" % [ph, z.tell(t), Enemy.MIN_TELEGRAPH])
	z.free()


func test_durgan_hull_shrugs_off_side_blows_but_not_the_vents() -> void:
	var r := await _zora_world()
	var z: Durgan = r[1]
	var hp0 := z.hp
	z.take_hit(8, Vector2.RIGHT)
	check(z.hp == hp0 - 2, "the hull lets a quarter through (%d)" % (hp0 - z.hp))
	z.take_hit(8, Vector2(0, 1))
	check(z.hp == hp0 - 10, "a down-strike on the vents lands in full")
	check(z.is_in_group("pogo"), "and the player bounces off it")


func test_durgan_drills_into_the_wall_and_sticks() -> void:
	var r := await _zora_world(Vector2i(20, 19))
	var w: World = r[0]
	var z: Durgan = r[1]
	w.player.teleport(cell_feet(4, 14))
	await frames(1)
	z.facing = 1
	z.set_state("drill_tell")
	var tell_frames := [0]
	var stuck := await _until(func() -> bool:
		if z.state == "drill_tell":
			tell_frames[0] += 1
		return z.stuck(), 240)
	check(tell_frames[0] / 60.0 >= Enemy.MIN_TELEGRAPH, "the drill spins up for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, tell_frames[0]])
	check(stuck and z.global_position.x > 32 * Room.TILE, "rammed the far wall and stuck fast (x %.0f)" % z.global_position.x)
	var hp0 := z.hp
	z.take_hit(8, Vector2.LEFT)
	check(z.hp == hp0 - 8, "stuck, it takes a side blow in full")


func test_durgan_drill_hurts_the_player_in_its_path() -> void:
	var r := await _zora_world(Vector2i(24, 19))
	var w: World = r[0]
	var z: Durgan = r[1]
	w.player.teleport(cell_feet(14, 19))
	await frames(1)
	z.facing = -1
	z.set_state("drill_tell")
	var hp := w.player.hp
	var hit := await _until(func() -> bool: return w.player.hp < hp, 120)
	check(hit, "the charge runs the player down")


func test_durgan_slam_sends_shockwaves() -> void:
	var r := await _zora_world()
	var w: World = r[0]
	var z: Durgan = r[1]
	w.player.teleport(cell_feet(24, 19))
	z.facing = -1
	z.set_state("slam_tell")
	var dirs := {}
	await _until(func() -> bool:
		for c in w.room.get_children():
			if c is Shockwave:
				dirs[c.direction] = true
		return dirs.size() == 2, 120)
	check(dirs.has(-1) and dirs.has(1), "a shockwave rolls each way (%s)" % [dirs.keys()])


func test_durgan_phase_two_raises_the_lift_and_climbs() -> void:
	var r := await _zora_world()
	var w: World = r[0]
	var z: Durgan = r[1]
	var shaft := LiftShaft.new()
	shaft.area = z.arena
	shaft.boss = z
	w.room.add_child(shaft)
	z.set_state("stuck")
	z.hp = int(Durgan.MAX_HP * Durgan.PHASES[0]) + 4
	z.take_hit(8, Vector2(0, 1))
	check(z.phase == 2 and z.rising, "below %d%% the lift starts to rise" % int(Durgan.PHASES[0] * 100))
	var rocks := await _until(func() -> bool: return _count_rubble(w, "fall") > 0, 120)
	check(rocks, "debris falls from the shaft")
	await frames(30)
	check(shaft.is_rising(), "the girders stream past")
	w.player.teleport(cell_feet(20, 19))
	z.global_position = cell_feet(22, 19)
	z._since_climb = 2
	z.set_state("walk")
	var dove := await _until(func() -> bool: return z.state == "dive_tell", 300)
	check(dove and z.global_position.y < 12 * Room.TILE, "it climbs the wall (y %.0f)" % z.global_position.y)
	check(absf(z.dive_target.x - w.player.global_position.x) < 48.0, "and marks the player's spot")
	var landed := await _until(func() -> bool: return z.stuck(), 180)
	check(landed and z.is_on_floor(), "then dives and buries the drill in the floor")


func test_durgan_phase_three_opens_the_cockpit() -> void:
	var r := await _zora_world()
	var z: Durgan = r[1]
	z.phase = 2
	z.rising = true
	z.set_state("stuck")
	z.hp = int(Durgan.MAX_HP * Durgan.PHASES[1]) + 4
	z.take_hit(8, Vector2(0, 1))
	check(z.phase == 3 and z.state == "opening", "below %d%% the cockpit bursts open" % int(Durgan.PHASES[1] * 100))
	await frames(roundi(Durgan.OPEN_TIME * 60.0) + 5)
	var hp0 := z.hp
	z.take_hit(8, Vector2.RIGHT)
	check(z.hp == hp0, "now side blows glance off")
	z.take_hit(8, Vector2(0, 1))
	check(z.hp == hp0 - 12, "but a strike on the harness from above lands hard (%d)" % (hp0 - z.hp))


func test_durgan_defeat_gives_the_sun_seed() -> void:
	var w := make_world({}, LIFT_ROOM)
	var p := w.player
	await frames(3)
	var arena := _arena(w)
	p.teleport(cell_feet(10, 19))
	await _until(func() -> bool: return arena.fighting, 20)
	var z := get_tree_boss() as Durgan
	await frames(2)
	z.set_state("stuck")
	z.hp = 1
	var points := int(GameState.data.skill_points)
	var rank := int(GameState.data.rank)
	z.take_hit(8, Vector2(0, 1))
	check(z.state == "dying", "the last blow shatters the harness")
	var gone := await _until(func() -> bool: return GameState.flag("boss:durgan"), 600)
	check(gone, "Durgan is marked beaten")
	check((GameState.data.rings as Array).has("sun"), "the Sun Seed is the player's")
	var ranks := int(GameState.data.rank) - rank
	check(int(GameState.data.skill_points) == points + 1 + ranks, "with a skill point (plus %d from rank-ups)" % ranks)
	var opened := await _until(func() -> bool: return arena.seals.is_empty() and _count(w, ArenaSeal) == 0, 1200)
	check(opened, "the way out opens")
	w._enter(LIFT_ROOM)
	await frames(5)
	check(get_tree_boss() == null, "it never comes back")


# --- Gloamweaver (the Haar's first boss) ------------------------------------------------

const CHAPEL_ROOM := "haar/sunken_chapel"


## The chapel with the arena awake: [world, arena, widow].
func _widow_world() -> Array:
	var w := make_world({}, CHAPEL_ROOM)
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(3)
	var arena := _arena(w)
	w.player.teleport(cell_feet(10, 19))
	await _until(func() -> bool: return arena.fighting, 30)
	var r := get_tree_boss() as Gloamweaver
	await frames(3)
	return [w, arena, r]


func test_sunken_chapel_wakes_the_lantern_widow() -> void:
	var setup := await _widow_world()
	var w: World = setup[0]
	var arena: BossArena = setup[1]
	var r: Gloamweaver = setup[2]
	check(arena.boss_id == "gloamweaver" and r != null, "walking into the chapel wakes Gloamweaver")
	check(r.global_position.x > w.player.global_position.x + 200.0, "she waits across the chapel")
	check(r.lanterns.size() == Gloamweaver.LANTERNS, "she carries %d lanterns" % Gloamweaver.LANTERNS)
	var lit := 0
	for l in r.lanterns:
		if l.is_in_group("light"):
			lit += 1
	check(lit == Gloamweaver.LANTERNS, "each lantern is a light in the fog")
	check(Music.track == "gloamweaver", "the fight plays her own theme (%s)" % Music.track)
	await _until(func() -> bool: return r.state == "stalk", 120)
	w.player.teleport(r.global_position + Vector2(-120, 18))
	await frames(3)
	check(w.fog.clear_at(r.lanterns[0].global_position) == 1.0, "her lanterns clear the fog around them")


func test_gloamweaver_telegraphs_are_fair() -> void:
	var r := Gloamweaver.new()
	for ph in [1, 2, 3]:
		r.phase = ph
		for t: float in [Gloamweaver.SWEEP_TELL, Gloamweaver.POUNCE_TELL, Gloamweaver.WEB_TELL, Gloamweaver.DROP_TELL]:
			check(r.tell(t) >= Enemy.MIN_TELEGRAPH, "phase %d tell %.2f s is at least %.2f s" % [ph, r.tell(t), Enemy.MIN_TELEGRAPH])
	r.free()


func test_breaking_her_lanterns_shows_more_of_her() -> void:
	var setup := await _widow_world()
	var r: Gloamweaver = setup[2]
	await _until(func() -> bool: return r.state == "stalk", 120)
	var hp0 := r.hp
	var floor0 := Gloamweaver.MIN_SEEN
	r.lanterns[0].take_hit(10, Vector2.RIGHT)
	await frames(1)
	check(r.lanterns[0].dead and not r.lanterns[0].is_in_group("light"), "a blow shatters a lantern and its light goes out")
	check(r.hp == hp0 - Gloamweaver.LANTERN_DAMAGE, "breaking it hurts her (%d)" % (hp0 - r.hp))
	check(r.seen >= floor0 + Gloamweaver.SEEN_PER_LANTERN - 0.001, "the freed soul makes her show more (%.2f)" % r.seen)
	for l in r.lanterns:
		l.take_hit(10, Vector2.RIGHT)
	await frames(1)
	check(r.phase == 3 and r.seen == 1.0, "with every lantern broken she is in plain sight, and desperate")


## Pass 252: her last lantern ends the fight's middle as surely as her health
## does. The break used to watch health alone, so going down for good that way
## rang nothing, lifted no music and drew no stagger; later her health crossed
## the marks she had already passed and rang for nothing.
func test_her_last_lantern_breaks_the_phase_as_her_health_would() -> void:
	var setup := await _widow_world()
	var arena: BossArena = setup[1]
	var r: Gloamweaver = setup[2]
	await _until(func() -> bool: return r.state == "stalk", 120)
	var breaks: Array[int] = []
	arena.phase_broken.connect(func(level: int) -> void: breaks.append(level))
	for l in r.lanterns:
		l.take_hit(10, Vector2.RIGHT)
	await frames(2)
	check(r.health_fraction() > Gloamweaver.PHASES[0], "four lanterns leave her above the first mark (%.2f)" % r.health_fraction())
	check(r.phase == 3 and breaks == [2] and arena.phases_passed == 2, "her last lantern is one phase break, to the third phase (%s)" % [breaks])
	check(Music.intensity == 2, "and the music rises to match (%d)" % Music.intensity)
	r.hp = roundi(r.max_hp * 0.5)
	await frames(2)
	r.hp = roundi(r.max_hp * 0.2)
	await frames(2)
	check(breaks == [2], "her health crossing the marks after it rings nothing more (%s)" % [breaks])


func test_gloamweaver_climbs_and_reels_you_in_on_a_web() -> void:
	var setup := await _widow_world()
	var w: World = setup[0]
	var r: Gloamweaver = setup[2]
	var p := w.player
	await _until(func() -> bool: return r.state == "stalk", 120)
	r.hp = roundi(r.max_hp * 0.6)
	r.take_hit(1, Vector2.RIGHT)
	check(r.phase == 2, "below two thirds she enters phase 2")
	var up := await _until(func() -> bool: return r.on_ceiling and r.state == "hang", 180)
	check(up and absf(r.global_position.y - r.ceiling_y()) < 1.0, "she climbs to the vault")
	r._next_hang = "web"
	# Stand within web range, off to one side of her.
	p.teleport(Vector2(r.global_position.x - 120.0, p.global_position.y))
	await frames(2)
	var x0 := p.global_position.x
	var reeled := await _until(func() -> bool: return r.state == "reel", 240)
	check(reeled, "a web line catches the player")
	var pulled := await _until(func() -> bool: return absf(p.global_position.x - x0) > 10.0, 50)
	check(pulled and signf(p.global_position.x - x0) == signf(r.global_position.x - x0), "and reels them toward her")



## Pass 236: her web was broken only by a dash, and the dash is the Elven
## Stride's, found a zone past her. With only what the player holds at her
## chapel (the Glove and the Delver's Pick), a slash cuts the strand.
func test_a_slash_cuts_ripasheikus_web() -> void:
	var setup := await _widow_world()
	var w: World = setup[0]
	var r: Gloamweaver = setup[2]
	var p := w.player
	for k: String in p.abilities:
		p.abilities[k] = k in ["glove", "delvers_pick"]
	check(not p.abilities.get("stride", false), "at her chapel the player has no Stride")
	await _until(func() -> bool: return r.state == "stalk", 120)
	r.hp = roundi(r.max_hp * 0.6)
	r.take_hit(1, Vector2.RIGHT)
	await _until(func() -> bool: return r.on_ceiling and r.state == "hang", 180)
	r._next_hang = "web"
	p.teleport(Vector2(r.global_position.x - 120.0, p.global_position.y))
	await frames(2)
	var reeled := await _until(func() -> bool: return r.state == "reel", 240)
	check(reeled, "a web line catches the player")
	p.input.dash_pressed = true
	await frames(2)
	check(r.state == "reel" and not p.is_dashing, "without the Stride a dash does nothing")
	p.input.attack_pressed = true
	var cut := await _until(func() -> bool: return r.state != "reel", 6)
	check(cut and r.state == "hang", "a slash cuts the strand (%s)" % r.state)
	var x := p.global_position.x
	await frames(20)
	check(absf(p.global_position.x - x) < 24.0, "and the pull stops (%.1f px)" % absf(p.global_position.x - x))

func test_gloamweaver_drops_and_lies_open() -> void:
	var setup := await _widow_world()
	var r: Gloamweaver = setup[2]
	await _until(func() -> bool: return r.state == "stalk", 120)
	r.hp = roundi(r.max_hp * 0.6)
	r.take_hit(1, Vector2.RIGHT)
	await _until(func() -> bool: return r.state == "hang", 180)
	r._next_hang = "drop"
	r.set_state("hang")
	r.state_time = Gloamweaver.HANG_TIME
	var tell_frames := 0
	var landed := false
	for i in 240:
		await frames(1)
		if r.state == "drop_tell":
			tell_frames += 1
		if r.state == "dropped":
			landed = true
			break
	check(tell_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "her shadow marks the drop for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, tell_frames])
	check(landed and absf(r.global_position.y - r.floor_y()) < 1.0, "she drops to the floor")
	var hp0 := r.hp
	r.take_hit(10, Vector2.RIGHT)
	check(hp0 - r.hp == roundi(10 * Gloamweaver.DROPPED_BONUS), "stunned where she lands she takes extra damage (%d)" % (hp0 - r.hp))


func test_gloamweaver_defeat_gives_the_lantern_key() -> void:
	var setup := await _widow_world()
	var w: World = setup[0]
	var arena: BossArena = setup[1]
	var r: Gloamweaver = setup[2]
	var mp0 := float(GameState.data.max_mp)
	await _until(func() -> bool: return r.state == "stalk", 120)
	r.hp = 1
	r.take_hit(5, Vector2.RIGHT)
	check(r.state == "dying", "the last blow ends her")
	var gone := await _until(func() -> bool: return GameState.flag("boss:gloamweaver"), 600)
	check(gone, "Gloamweaver is marked beaten")
	check(GameState.key_count("lantern") == 1, "the Lantern Key is the player's")
	check(float(GameState.data.max_mp) == mp0 + GameState.MANA_DEW_MP, "and the Mana Dew she guarded")
	var lamps := 0
	await frames(2)
	for c in w.room.get_children():
		if c is BossLantern and not c.is_queued_for_deletion():
			lamps += 1
	check(lamps == 0, "her lanterns go with her")
	var opened := await _until(func() -> bool: return arena.seals.is_empty() and _count(w, ArenaSeal) == 0, 1200)
	check(opened, "the way out opens")


const SPRING_ROOM := "haar/spring_of_haar"


## The Haar Spring with the hydra out and fighting: [world, arena, hydra].
func _hydra_world() -> Array:
	var w := make_world({}, SPRING_ROOM)
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(3)
	var arena := _arena(w)
	w.player.teleport(cell_feet(7, 19))
	await _until(func() -> bool: return arena.fighting, 30)
	var z := get_tree_boss() as HaarWyrm
	await frames(2)
	z.skip_intro()
	await _until(func() -> bool: return z.state == "fight", 240)
	return [w, arena, z]


func _intakes(w: World) -> Array:
	return w.room.get_children().filter(func(c: Node) -> bool: return c is HydraIntake)


## A Deluge bolt flown at `intake` from `side` (1 east of it, -1 west).
func _bolt_at(w: World, intake: HydraIntake, side: int) -> void:
	var bolt := TorrentBolt.new()
	bolt.velocity = Vector2(-side * 300.0, 0)
	w.room.add_child(bolt)
	bolt.global_position = intake.global_position + Vector2(side * 40.0, 0)
	await frames(12)


func test_spring_of_haar_wakes_the_hydra() -> void:
	var w := make_world({}, SPRING_ROOM)
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(3)
	var arena := _arena(w)
	w.player.teleport(cell_feet(7, 19))
	await _until(func() -> bool: return arena.fighting, 30)
	var z := get_tree_boss() as HaarWyrm
	await frames(3)
	check(arena.boss_id == "haar_wyrm" and z != null, "walking into the spring wakes the Haar Wyrm")
	check(Music.track == "haar_wyrm", "the fight plays his own theme (%s)" % Music.track)
	check(z.heads.size() == 3, "three heads (%d)" % z.heads.size())
	for h in z.heads:
		check(h.mode == "hidden" and not h.active, "each head waits in the dark tunnel, out of reach")
	check(z.cistern != null and z.cistern.level == 0, "the great cistern stands dry")
	var intakes := _intakes(w)
	check(intakes.size() == 3, "three intakes feed it (%d)" % intakes.size())
	var heights := {}
	for i: HydraIntake in intakes:
		heights[roundi(i.global_position.y)] = true
	check(heights.size() == 3, "at three heights (%s)" % [heights.keys()])
	var spring: Spring = null
	for c in w.room.get_children():
		if c is Spring:
			spring = c
	check(spring != null and spring.spring_id == "haar", "the Haar Spring rises in the cistern")
	check(not spring.is_in_group("interactable"), "and can't be cleared while he lives")


func test_the_hydra_shows_its_eyes_before_its_heads() -> void:
	var w := make_world({}, SPRING_ROOM)
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(3)
	var arena := _arena(w)
	w.player.teleport(cell_feet(7, 19))
	await _until(func() -> bool: return arena.fighting, 30)
	var z := get_tree_boss() as HaarWyrm
	check(z.state == "intro", "it begins with the intro")
	var out_before := false
	var frames_run := 0
	while z.state == "intro" and frames_run < 600:
		await frames(1)
		frames_run += 1
		if z._intro_t < HaarWyrm.EMERGE_AT[0] - 0.05:
			for h in z.heads:
				if h.mode != "hidden":
					out_before = true
	check(not out_before, "no head comes out before the three pairs of eyes and the breathing")
	check(HaarWyrm.EYES_AT[0] < HaarWyrm.EYES_AT[1] and HaarWyrm.EYES_AT[1] < HaarWyrm.EYES_AT[2] and HaarWyrm.EYES_AT[2] < HaarWyrm.SNORTS_AT[0], "the eyes open one pair at a time, then it breathes")
	check(HaarWyrm.EMERGE_AT[0] < HaarWyrm.EMERGE_AT[1] and HaarWyrm.EMERGE_AT[1] < HaarWyrm.EMERGE_AT[2], "the heads come out one after another")
	check(z.state == "fight" and frames_run / 60.0 >= HaarWyrm.INTRO_TIME - 0.1, "the fight begins after the whole reveal (%.1f s)" % (frames_run / 60.0))
	for h in z.heads:
		check(h.active and h.mode != "hidden", "every head is out and can be struck")
	check(GameState.flag(HaarWyrm.SEEN_FLAG), "a second try skips the darkness")


func test_haar_wyrm_telegraphs_are_fair() -> void:
	var z := HaarWyrm.new()
	for t: float in [HaarWyrm.PLUME_TELL, HaarWyrm.GEYSER_TELL, HaarWyrm.FOG_TELL]:
		check(z.tell(t) >= Enemy.MIN_TELEGRAPH, "tell %.2f s is at least %.2f s" % [z.tell(t), Enemy.MIN_TELEGRAPH])
	check(HaarWyrm.FOG_TELL >= 2.5, "the fog's wind-up is long, the time to get water in (%.1f s)" % HaarWyrm.FOG_TELL)
	check(HaarWyrm.GEYSER_TELL - HaarWyrm.GEYSER_LOCK >= Enemy.MIN_TELEGRAPH and HaarWyrm.GEYSER_LOCK >= Enemy.MIN_TELEGRAPH, "the geyser aims, then locks long enough to leave the line")
	z.free()


func test_each_round_ends_with_the_fog() -> void:
	var setup := await _hydra_world()
	var z: HaarWyrm = setup[2]
	var firsts := {}
	for s in 24:
		z.rng.seed = s
		z._new_round()
		check(z.order.size() == 3, "a round has a breath from each head")
		check(z.heads[z.order[2]].breath == HydraHead.FOG, "the fog always comes third")
		firsts[z.heads[z.order[0]].breath] = true
	check(firsts.has(HydraHead.PLUME) and firsts.has(HydraHead.GEYSER), "the plume and the geyser trade places at random (%s)" % [firsts.keys()])


func test_a_head_holds_at_half_until_doused() -> void:
	var setup := await _hydra_world()
	var z: HaarWyrm = setup[2]
	var h := z.head_for(HydraHead.PLUME)
	for i in 20:
		h.take_hit(12, Vector2.RIGHT)
	check(h.hp == HaarWyrm.HEAD_FLOOR, "its hot scales hold it at %d (%d)" % [HaarWyrm.HEAD_FLOOR, h.hp])
	check(z.hp == HaarWyrm.HEAD_HP * 2 + HaarWyrm.HEAD_FLOOR, "the bar is the three heads together (%d)" % z.hp)
	h.weak = true
	h.take_hit(12, Vector2.RIGHT)
	check(h.hp == HaarWyrm.HEAD_FLOOR - 12, "doused, it takes the blow (%d)" % h.hp)


func test_an_intake_takes_deluge_only_into_its_mouth() -> void:
	var setup := await _hydra_world()
	var w: World = setup[0]
	var z: HaarWyrm = setup[2]
	var intake: HydraIntake = _intakes(w)[0]
	await _bolt_at(w, intake, -intake.facing)
	check(z.cistern.level == 0, "a bolt into the back of the pipe only splashes")
	await _bolt_at(w, intake, intake.facing)
	check(z.cistern.level == 1 and intake.flowing, "a bolt into the mouth sends a third down (%d)" % z.cistern.level)
	await _bolt_at(w, intake, intake.facing)
	check(z.cistern.level == 1, "the same intake gives no more until its water is gone")


func test_a_full_cistern_douses_the_last_breather_then_the_rage_boils_it_dry() -> void:
	var setup := await _hydra_world()
	var w: World = setup[0]
	var z: HaarWyrm = setup[2]
	var geyser := z.head_for(HydraHead.GEYSER)
	geyser.hp = HaarWyrm.HEAD_FLOOR
	z.attacker = null
	z.last_breather = geyser
	z._to("gap")
	for i: HydraIntake in _intakes(w):
		i.douse()
	check(z.cistern.full(), "three intakes fill it")
	await frames(2)
	check(z.step == "weak" and geyser.weak, "the head that breathed last is doused and weak (%s)" % z.step)
	geyser.take_hit(20, Vector2.RIGHT)
	check(geyser.hp == HaarWyrm.HEAD_FLOOR - 20, "and falls below half (%d)" % geyser.hp)
	z.step_time = HaarWyrm.WEAK_TIME
	await frames(2)
	check(z.step == "rage" and not geyser.weak, "then the hydra rages")
	await _until(func() -> bool: return not z.cistern.boiling, 200)
	check(z.cistern.level == 0, "and boils the cistern dry")
	for i: HydraIntake in _intakes(w):
		check(not i.flowing, "every intake opens again")
	await _until(func() -> bool: return z.step == "gap", 200)
	check(z.order.size() == 3, "a new round begins")


func test_a_doused_head_dies_and_the_rest_quicken() -> void:
	var setup := await _hydra_world()
	var z: HaarWyrm = setup[2]
	var plume := z.head_for(HydraHead.PLUME)
	var before := z.tell(HaarWyrm.GEYSER_TELL)
	z.attacker = null
	z._weaken(plume)
	plume.hp = 5
	plume.take_hit(12, Vector2.RIGHT)
	check(plume.dead and plume.mode == "limp" and not plume.active, "the head dies and hangs limp")
	check(z.phase == 2, "the fight turns (phase %d)" % z.phase)
	check(z.tell(HaarWyrm.GEYSER_TELL) < before, "the others quicken")
	await _until(func() -> bool: return z.step == "gap", 400)
	check(not z.order.has(plume.index) and z.order.size() == 2, "and a dead head breathes no more (%s)" % [z.order])


## Forces head `breath_id` to wind up its breath now.
func _force(z: HaarWyrm, breath_id: String) -> HydraHead:
	var h := z.head_for(breath_id)
	z.attacker = null
	z.order = [h.index]
	z._to("gap")
	z.step_time = 99.0
	return h


func test_the_plume_rolls_the_floor_and_rides_the_rim() -> void:
	var setup := await _hydra_world()
	var w: World = setup[0]
	var z: HaarWyrm = setup[2]
	var h := _force(z, HydraHead.PLUME)
	var plume: SteamBreath = null
	var tell_frames := 0
	for i in 200:
		await frames(1)
		if h.mode == "tell":
			tell_frames += 1
		for c in w.room.get_children():
			if c is SteamBreath:
				plume = c
		if plume != null:
			break
	check(plume != null, "the plume head vents its cloud")
	check(tell_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "after a tell of at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, tell_frames])
	check(absf(plume.global_position.y - z.ground_at(plume.global_position.x)) < 1.0, "it lies on the ground")
	await frames(90)
	check(plume.rect().size.y < 72.0, "never taller than a jump clears (%.0f)" % plume.rect().size.y)
	var t := float(Room.TILE)
	check(z.ground_at((HaarWyrm.CISTERN_COLS.x + 4) * t) == HaarWyrm.CISTERN_ROWS.x * t, "and it rides over the cistern's rim")


func test_the_geyser_fires_a_locked_straight_line() -> void:
	var setup := await _hydra_world()
	var w: World = setup[0]
	var z: HaarWyrm = setup[2]
	var h := _force(z, HydraHead.GEYSER)
	await _until(func() -> bool: return h.mode == "tell" and h.mode_time >= z.tell(HaarWyrm.GEYSER_TELL) - HaarWyrm.GEYSER_LOCK + 0.05, 200)
	var locked := h.aim
	w.player.teleport(w.player.global_position + Vector2(200, 0))
	var jet: HydraGeyser = null
	for i in 60:
		await frames(1)
		for c in w.room.get_children():
			if c is HydraGeyser:
				jet = c
		if jet != null:
			break
	check(jet != null, "the geyser head fires its jet")
	if jet == null:
		return
	check(jet.dir.is_equal_approx(locked), "along the line it locked, not where you went")
	await frames(6)
	var l1 := jet.length()
	await frames(6)
	check(jet.length() >= l1, "it shoots out from the jaws rather than appearing whole")
	check(jet.touches(Rect2(jet.mouth + jet.dir * 20.0 - Vector2(2, 2), Vector2(4, 4))), "one width all along its line")
	var off := Rect2(jet.mouth + jet.dir.orthogonal() * 60.0, Vector2(4, 4))
	check(not jet.touches(off), "and a step out of the line is safe")


func test_the_thermal_fog_spares_only_the_water() -> void:
	var setup := await _hydra_world()
	var w: World = setup[0]
	var z: HaarWyrm = setup[2]
	# Hold the hydra's round still: only the fog acts.
	z.order.clear()
	z.attacker = null
	z.step = "hold"
	var p := w.player
	var fog := HydraFog.new()
	fog.bounds = z.arena
	fog.cistern = z.cistern
	w.room.add_child(fog)
	var hp0 := p.hp
	await frames(60)
	check(p.hp < hp0, "out of the water the fog burns you (%d)" % (hp0 - p.hp))
	fog.queue_free()
	_intakes(w)[0].douse()
	p.teleport(Vector2(z.cistern.inside.get_center().x, z.cistern.inside.end.y))
	await frames(4)
	check(z.cistern.shelters(p), "standing in a third of water shelters you")
	var fog2 := HydraFog.new()
	fog2.bounds = z.arena
	fog2.cistern = z.cistern
	w.room.add_child(fog2)
	var hp1 := p.hp
	await frames(roundi((HydraFog.FILL + HydraFog.BURN) * 60.0) + 6)
	check(p.hp == hp1, "and the heat never reaches you there")
	check(z.cistern.level == 0, "but it boils that third away")


func test_haar_wyrm_defeat_gives_the_fall_seed() -> void:
	var setup := await _hydra_world()
	var w: World = setup[0]
	var arena: BossArena = setup[1]
	var z: HaarWyrm = setup[2]
	for h in z.heads:
		h.hp = 1
		h.weak = true
	for h in z.heads:
		h.take_hit(5, Vector2.RIGHT)
	check(z.state == "dying", "the last head's death ends him")
	var gone := await _until(func() -> bool: return GameState.flag("boss:haar_wyrm"), 600)
	check(gone, "the Haar Wyrm is marked beaten")
	check((GameState.data.rings as Array).has("fall"), "the Fall Seed is the player's")
	await frames(2)
	var heads := 0
	for c in w.room.get_children():
		if c is HydraHead and not c.is_queued_for_deletion():
			heads += 1
	check(heads == 0, "his heads go with him")
	var opened := await _until(func() -> bool: return arena.seals.is_empty() and _count(w, ArenaSeal) == 0, 1200)
	check(opened, "the way out opens")
	var spring: Spring = null
	for c in w.room.get_children():
		if c is Spring:
			spring = c
	await frames(2)
	check(spring.is_in_group("interactable"), "the spring can be cleared now")
	spring.interact(w.player)
	check(GameState.flag("spring:haar"), "clearing it restores the Haar Spring")
	w._enter(SPRING_ROOM)
	await frames(3)
	var full := false
	for c in w.room.get_children():
		if c is HydraCistern:
			full = c.full()
	check(full, "the cistern stays full once he is beaten")


# --- Snapcrown, the Devouring Bloom (bible 8.5) ---------------------------------

func _bloom_world() -> Array:
	var w := make_world({}, "boughs/crown_leaf")
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(3)
	var arena := _arena(w)
	w.player.teleport(cell_feet(8, 19))
	await _until(func() -> bool: return arena.fighting, 30)
	var k := get_tree_boss() as Snapcrown
	await _until(func() -> bool: return k != null and k.state == "idle", 200)
	return [w, arena, k]


## Puts the player `dx` px from the root and waits for the move it provokes.
func _provoke(w: World, k: Snapcrown, dx: float, move: String) -> int:
	w.player.teleport(Vector2(k.global_position.x + dx, k.floor_y()))
	k.set_state("idle")
	k._last = ""
	var tell_frames := 0
	for i in 240:
		await frames(1)
		if k.state == move + "_tell":
			tell_frames += 1
		elif tell_frames > 0:
			break
	return tell_frames


func test_crown_leaf_wakes_snapcrown() -> void:
	var setup := await _bloom_world()
	var arena: BossArena = setup[1]
	var k: Snapcrown = setup[2]
	check(arena.boss_id == "snapcrown" and k != null, "walking onto the crown-leaf wakes the Bloom")
	check(Music.track == "snapcrown", "the fight plays its own theme (%s)" % Music.track)
	check(k.head != null and k.head.active, "its head is out and can be struck")
	check(k.collision_layer == 0, "the stem itself is scenery")


func test_snapcrown_telegraphs_are_fair() -> void:
	var k := Snapcrown.new()
	for ph in [1, 2, 3]:
		k.phase = ph
		for t: float in [Snapcrown.BITE_TELL, Snapcrown.WHIP_TELL, Snapcrown.SPIT_TELL, Snapcrown.BROOD_TELL]:
			check(k.tell(t) >= Enemy.MIN_TELEGRAPH, "phase %d tell %.2f s is at least %.2f s" % [ph, k.tell(t), Enemy.MIN_TELEGRAPH])
	k.free()


func test_snapcrown_shell_turns_blows_until_the_jaws_hang_open() -> void:
	var setup := await _bloom_world()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	var hp0 := k.hp
	k.head.take_hit(10, Vector2.RIGHT)
	check(hp0 - k.hp == 3, "the shut shell turns most of a blow (%d)" % (hp0 - k.hp))
	check(not k.head.punishable(), "shut, the head is no opening (Executioner)")
	var hp := w.player.hp
	var tell_frames := await _provoke(w, k, 60.0, "bite")
	check(tell_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "the head rears for at least %.2f s before it bites (%d frames)" % [Enemy.MIN_TELEGRAPH, tell_frames])
	var gaped := await _until(func() -> bool: return k.state == "gape", 30)
	check(gaped and w.player.hp < hp, "the bite lands on a player standing still, and the jaws hang open")
	check(absf(k.head.global_position.y - k.floor_y()) < 30.0, "the head lies low on the leaf")
	check(k.head.punishable(), "the open jaws are its opening, through the head's hitbox")
	hp0 = k.hp
	k.head.take_hit(10, Vector2.RIGHT)
	check(hp0 - k.hp == 10, "open, every blow lands in full (%d)" % (hp0 - k.hp))
	var back := await _until(func() -> bool: return k.state == "idle", 200)
	check(back, "then the head draws back")


func test_a_parried_bite_holds_the_jaws_open() -> void:
	var setup := await _bloom_world()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	var p := w.player
	p.has_shield = true
	p.teleport(Vector2(k.global_position.x + 50.0, k.floor_y()))
	k.set_state("idle")
	k._last = ""
	# Raise the guard just before the head comes down.
	await _until(func() -> bool: return k.state == "bite" and k.state_time >= 2.0 / 60.0, 240)
	p.facing = -1
	p.input.block_pressed = true
	p.input.block_held = true
	var hp := p.hp
	await _until(func() -> bool: return k.state == "gape", 30)
	p.input.block_pressed = false
	p.input.block_held = false
	check(p.hp == hp, "a parried bite does no damage")
	var frames_open := 0
	while k.state == "gape" and frames_open < 400:
		await frames(1)
		frames_open += 1
	check(frames_open / 60.0 > Snapcrown.GAPE_TIME + 0.5, "and the jaws hang open longer (%.2f s)" % (frames_open / 60.0))


func test_snapcrown_whip_lashes_along_the_leaf() -> void:
	var setup := await _bloom_world()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	var hp := w.player.hp
	var tell_frames := await _provoke(w, k, -150.0, "whip")
	check(tell_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "the vine coils for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, tell_frames])
	var r := k.whip_rect()
	check(r.end.y == k.floor_y() and r.end.x < k.global_position.x, "it lashes low along the leaf on the player's side")
	await _until(func() -> bool: return k.state == "idle", 60)
	check(w.player.hp < hp, "and catches a player standing on the leaf")


func test_snapcrown_spits_seeds_in_arcs() -> void:
	var setup := await _bloom_world()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	k._last = "whip"
	w.player.teleport(Vector2(k.global_position.x + 180.0, k.floor_y()))
	k.set_state("idle")
	await frames(1)
	k._last = "whip"
	var seeds := 0
	for i in 120:
		await frames(1)
		seeds = maxi(seeds, _count(w, SeedShot))
		if seeds > 0:
			break
	check(seeds == 3, "it spits three seeds (%d)" % seeds)


## Pass 257 (bible 8.5): as in the source game, the Bloom looses Mothlings three at
## a time, and only once those are struck down does it loose more. From phase
## 2, far off, the petals flare (a fair tell) and three fly out; while any of
## them flies it whips and spits instead; each Mothling screeches before it dives;
## and the brood dies with the Bloom.
func _watch_bloom(k: Snapcrown, frames_max: int) -> Array:
	var seen := {}
	var tell_frames := 0
	for i in frames_max:
		await frames(1)
		seen[k.state] = true
		if k.state == "brood_tell":
			tell_frames += 1
		elif tell_frames > 0:
			break
	return [seen, tell_frames]


func test_the_bloom_looses_its_liliths_three_at_a_time() -> void:
	var setup := await _bloom_world()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	# In phase 1 it never broods, however long you stand off.
	k._since_brood = 99
	w.player.teleport(Vector2(k.global_position.x + 180.0, k.floor_y()))
	k.set_state("idle")
	var calm: Array = await _watch_bloom(k, 300)
	check(not calm[0].has("brood_tell") and _count(w, Mothling) == 0, "a whole bloom keeps its brood (%s)" % [calm[0].keys()])
	# Below half, the first move from afar is a brood.
	k.phase = 2
	k.hp = roundi(k.max_hp * 0.45)
	k._since_brood = Snapcrown.BROOD_EVERY
	w.player.teleport(Vector2(k.global_position.x + 180.0, k.floor_y()))
	k.set_state("idle")
	var first: Array = await _watch_bloom(k, 240)
	check(first[1] / 60.0 >= Enemy.MIN_TELEGRAPH, "the petals flare for a fair tell first (%.2f s)" % (first[1] / 60.0))
	await frames(2)
	check(_count(w, Mothling) == Snapcrown.BROOD and k.brood_alive() == Snapcrown.BROOD, "and three Mothlings fly out (%d)" % _count(w, Mothling))
	# While any of them flies, no more come, however many moves go by.
	k._since_brood = 99
	k.set_state("idle")
	var held: Array = await _watch_bloom(k, 360)
	check(not held[0].has("brood_tell") and _count(w, Mothling) == Snapcrown.BROOD, "no more while the brood flies (%d)" % _count(w, Mothling))
	# A Mothling screeches before it dives.
	var l: Mothling = k.brood[0]
	var windup := 0
	var dove := false
	for i in 300:
		await frames(1)
		if not is_instance_valid(l):
			break
		if l.state == "windup":
			windup += 1
		elif l.state == "dive" and windup > 0:
			dove = true
			break
	check(dove and windup / 60.0 >= Enemy.MIN_TELEGRAPH, "a Mothling screeches %.2f s before it dives" % (windup / 60.0))
	# Strike them all down and it broods again.
	for b in k.brood:
		b.take_hit(b.hp, Vector2.RIGHT)
	await frames(30)
	check(k.brood_alive() == 0, "the brood is struck down")
	k._since_brood = Snapcrown.BROOD_EVERY
	w.player.teleport(Vector2(k.global_position.x + 180.0, k.floor_y()))
	k.set_state("idle")
	var again: Array = await _watch_bloom(k, 240)
	await frames(2)
	check(again[1] > 0 and k.brood_alive() == Snapcrown.BROOD, "then it looses three more (%d)" % k.brood_alive())
	# The brood dies with the Bloom.
	var last := k.brood.duplicate()
	k.hp = 1
	k.set_state("gape")
	k.head.take_hit(5, Vector2.RIGHT)
	await frames(2)
	check(last.all(func(b: Mothling) -> bool: return not is_instance_valid(b) or b.dead), "and the brood dies with it")


func test_phase_two_bites_tear_the_leaf() -> void:
	var setup := await _bloom_world()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	k.hp = roundi(k.max_hp * 0.52)
	k.head.take_hit(30, Vector2.RIGHT)
	check(k.phase == 2, "below half the Bloom enters phase 2 (%d hp)" % k.hp)
	k._bites = 1
	var x := k.global_position.x + 96.0
	await _provoke(w, k, 96.0, "bite")
	await _until(func() -> bool: return k.state == "gape", 30)
	check(k.gaps.size() == 1, "the bite tears a chunk out of the leaf")
	check(not w.room.is_solid_at(Vector2(x, k.floor_y() + 4)), "where the jaws came down, the leaf is gone")
	check(w.room.is_solid_at(Vector2(k.global_position.x, k.floor_y() + 4)), "the root's leaf stays whole")
	var spikes := 0
	for c in w.room.get_children():
		if c is Spikes:
			spikes += 1
	check(spikes >= Snapcrown.TEAR_WIDTH, "thorns line the gap (%d)" % spikes)


## Pass 292 (bible 6.13, 8.5): ground a guardian tears away is no place to be
## set back to. A spike sets you back where you last stood on tiles; when the
## Bloom's bite tore the leaf from under your feet, that spot was the gap, so
## its thorns set you back over themselves until you were dead.
func test_a_torn_floor_never_sets_you_back_over_the_gap() -> void:
	var setup := await _bloom_world()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	var p := w.player
	k.process_mode = Node.PROCESS_MODE_DISABLED
	p.max_hp = 100
	p.hp = 100
	for dx: float in [180.0, -200.0]:
		var x := k.global_position.x + dx
		p.teleport(Vector2(x, k.floor_y()))
		await frames(20)
		check(p.is_on_floor(), "standing on the leaf at %+d" % dx)
		var hp := p.hp
		var torn := k.gaps.size()
		k._tear_leaf(x)
		check(k.gaps.size() == torn + 1, "the bite tears the leaf under you (%d gaps)" % k.gaps.size())
		await frames(240)
		check(hp - p.hp == CombatTuning.new().hazard_damage, "the thorns cost one mask, not a run of them (%d)" % (hp - p.hp))
		check(p.is_on_floor() and w.room.is_solid_at(p.global_position + Vector2(0, 4)), "and set you back on the leaf beside the gap (%s)" % p.global_position)
		p.hp = 100


## Pass 293 (bible 5.4): the purse a death drops lies on ground you can come
## back to. It was left where you fell, so a blow that killed you in the Bloom's
## gap left it in the pit, and the leaf came back whole around it the next time
## the room loaded: the gold was buried in the floor for good.
func test_a_death_in_a_torn_pit_leaves_the_purse_beside_it() -> void:
	var setup := await _bloom_world()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	var p := w.player
	k.process_mode = Node.PROCESS_MODE_DISABLED
	p.max_hp = 100
	p.hp = 100
	p.gold = 500
	var x := k.global_position.x + 180.0
	p.teleport(Vector2(x, k.floor_y()))
	await frames(20)
	k._tear_leaf(x)
	await _until(func() -> bool: return p.global_position.y > k.floor_y() + 12.0, 60)
	check(p.global_position.y > k.floor_y() + 12.0, "you drop into the gap (%s)" % p.global_position)
	p.take_damage(9999)
	await frames(1)
	check(p.dead and is_instance_valid(p.purse), "a blow there kills you and drops a purse")
	if not is_instance_valid(p.purse):
		return
	var at := p.purse.global_position
	check(absf(at.y - k.floor_y()) < 1.0 and w.room.is_solid_at(at + Vector2(0, 4)), "the purse lies on the leaf, not in the pit (%s)" % at)
	var gap: Vector2i = k.gaps[0]
	check(at.x < gap.x * Room.TILE or at.x >= (gap.y + 1) * Room.TILE, "beside the gap, not over it (%s, gap %s)" % [at, gap])



## A purse left from a death earlier in the fight (bible 5.4, pass 300) lies on
## the leaf. When a bite tears the leaf away under it, it moves beside the gap
## with the set-back spot, so taking it back never means a drop onto the thorns.
func test_a_purse_on_torn_leaf_moves_beside_the_gap() -> void:
	var setup := await _bloom_world()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	var p := w.player
	k.process_mode = Node.PROCESS_MODE_DISABLED
	var x := k.global_position.x + 180.0
	p.teleport(Vector2(k.global_position.x - 120.0, k.floor_y()))
	var bag := GoldPurse.new()
	bag.value = 300
	w.room.add_child(bag)
	bag.position = Vector2(x, k.floor_y())
	GameState.data.purse = {"room": w.room.id, "x": bag.position.x, "y": bag.position.y, "value": bag.value}
	await frames(5)
	k._tear_leaf(x)
	await frames(5)
	check(not k.gaps.is_empty(), "the bite tears the leaf")
	if k.gaps.is_empty():
		GameState.data.purse = {}
		return
	var gap: Vector2i = k.gaps[0]
	var at := bag.position
	check(at.x < gap.x * Room.TILE or at.x >= (gap.y + 1) * Room.TILE, "the purse moves beside the gap, not over it (%s, gap %s)" % [at, gap])
	check(absf(at.y - k.floor_y()) < 1.0 and w.room.is_solid_at(at + Vector2(0, 4)), "onto the leaf (%s)" % at)
	check(is_equal_approx(float(GameState.data.purse.x), at.x), "and a reload puts it there too (%s)" % [GameState.data.purse])
	var gold := p.gold
	p.teleport(at)
	await frames(3)
	check(p.gold == gold + 300 and not is_instance_valid(bag), "standing there takes it back (%d)" % p.gold)
	check(p.hp == p.max_hp, "without a hurt (%d)" % p.hp)
	GameState.data.purse = {}

## Bible 8.5 (pass 308): a drop never rests on spikes. A Mothling struck down over
## a torn leaf dropped its bread or War Glove into the thorns, where taking it
## cost a blow. A drop that lands on spikes now moves to the leaf beside the pit,
## whether it lay there when the leaf tore or fell in after.
func test_a_drop_never_rests_in_the_thorns() -> void:
	var setup := await _bloom_world()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	var p := w.player
	k.process_mode = Node.PROCESS_MODE_DISABLED
	var x := k.global_position.x + 180.0
	p.teleport(Vector2(k.global_position.x - 120.0, k.floor_y()))
	var lying := Drop.make(w.room, Vector2(x, k.floor_y() - 4.0), "bread")
	await frames(20)
	k._tear_leaf(x)
	check(not k.gaps.is_empty(), "the bite tears the leaf")
	if k.gaps.is_empty():
		return
	var gap: Vector2i = k.gaps[0]
	var falling := Drop.make(w.room, Vector2((gap.x + gap.y + 1) * 0.5 * Room.TILE, k.floor_y() - 40.0), "glove")
	falling.velocity = Vector2.ZERO
	await frames(60)
	for d: Variant in [lying, falling]:
		if not check(is_instance_valid(d), "both drops are still there"):
			return
		var at: Vector2 = d.global_position
		check(at.x < gap.x * Room.TILE or at.x >= (gap.y + 1) * Room.TILE, "the %s rests beside the pit, not in it (%s, gap %s)" % [d.kind, at, gap])
		check(absf(at.y - k.floor_y()) < 1.0, "on the leaf (%s)" % at)
	var spots: Array[Vector2] = [lying.global_position, falling.global_position]
	for at in spots:
		p.teleport(at)
		await frames(3)
	check(not is_instance_valid(lying) and not is_instance_valid(falling), "both are taken")
	check(p.hp == p.max_hp, "without a blow (%d)" % p.hp)


func test_snapcrown_defeat_opens_the_crown_leaf() -> void:
	var setup := await _bloom_world()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	var points := int(GameState.data.skill_points)
	k.phase = 2
	k.hp = 1
	k.set_state("gape")
	k.head.take_hit(5, Vector2.RIGHT)
	check(k.state == "dying", "the last blow ends it")
	var gone := await _until(func() -> bool: return GameState.flag("boss:snapcrown"), 300)
	check(gone, "Snapcrown is marked beaten")
	check(int(GameState.data.skill_points) >= points + 1, "and gives a skill point")
	await frames(90)
	check(get_tree_boss() == null, "the Bloom is gone")
	w._enter("boughs/crown_leaf")
	await frames(10)
	check(get_tree_boss() == null, "and never returns")


func _leaf_fall(w: World) -> LeafFall:
	for c in w.room.get_children():
		if c is LeafFall and not c.is_queued_for_deletion():
			return c
	return null


## Drops the Bloom into phase 3 with a blow on its open jaws and waits for it to uproot.
func _uprooted_bloom() -> Array:
	var setup := await _bloom_world()
	var k: Snapcrown = setup[2]
	k.phase = 2
	k.hp = roundi(k.max_hp * Snapcrown.PHASES[1]) + 4
	k.set_state("gape")
	k.head.take_hit(10, Vector2.RIGHT)
	await _until(func() -> bool: return k.uprooted and k.state == "idle", 300)
	return setup


func test_snapcrown_uproots_below_a_quarter() -> void:
	var setup := await _bloom_world()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	k.phase = 2
	k.hp = roundi(k.max_hp * Snapcrown.PHASES[1]) + 4
	k.set_state("gape")
	k.head.take_hit(10, Vector2.RIGHT)
	check(k.phase == 3 and k.state == "gape", "below a quarter it enters phase 3, but the open jaws stay open (%s)" % k.state)
	var tore := await _until(func() -> bool: return k.state == "uproot", 200)
	check(tore, "once the head draws back, it wrenches its root out of the leaf")
	var uproot_frames := 0
	while k.state == "uproot" and uproot_frames < 200:
		await frames(1)
		uproot_frames += 1
	check(uproot_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "the uprooting is a tell of at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, uproot_frames])
	check(k.uprooted and _leaf_fall(w) != null, "then it is free and the leaf falls")
	for t: float in [Snapcrown.BITE_TELL, Snapcrown.WHIP_TELL, Snapcrown.SPIT_TELL]:
		check(k.tell(t) >= Enemy.MIN_TELEGRAPH, "phase 3 tell %.2f s is fair" % k.tell(t))


func test_the_uprooted_bloom_chases_you() -> void:
	var setup := await _uprooted_bloom()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	k.uprooted = true
	var x0 := k.global_position.x
	w.player.teleport(Vector2(k.arena.end.x - 64.0, k.floor_y()))
	k.set_state("idle")
	k._last = ""
	await frames(20)
	var moved := k.global_position.x - x0
	check(moved > Snapcrown.CHASE_SPEED * 0.2, "it scuttles after you on its roots (%.0f px)" % moved)
	check(moved < Snapcrown.CHASE_SPEED * 0.5, "at a walk, slower than your run")
	# Right up against a wall, it stops short of it.
	k.global_position.x = k.arena.end.x - 10.0
	k._chase(0.1)
	check(k.global_position.x <= k.arena.end.x - Snapcrown.WALL_MARGIN, "and keeps clear of the walls")


func test_the_uprooted_bloom_lunges_behind_its_bite() -> void:
	var setup := await _uprooted_bloom()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	var hp := w.player.hp
	var x0 := k.global_position.x
	var tell_frames := await _provoke(w, k, 100.0, "bite")
	check(tell_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "the head rears for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, tell_frames])
	var gaped := await _until(func() -> bool: return k.state == "gape", 30)
	var hopped := k.global_position.x - x0
	check(gaped and hopped > 20.0 and hopped <= Snapcrown.LUNGE + Snapcrown.CHASE_SPEED * 0.6, "the whole plant hops in behind the jaws (%.0f px)" % hopped)
	check(w.player.hp < hp, "and the bite lands on a player standing still")
	var hp0 := k.hp
	k.head.take_hit(10, Vector2.RIGHT)
	check(hp0 - k.hp == 10, "the jaws still hang open for full blows (%d)" % (hp0 - k.hp))


func test_the_falling_leaf_lightens_you() -> void:
	var setup := await _uprooted_bloom()
	var w: World = setup[0]
	var k: Snapcrown = setup[2]
	var lf := _leaf_fall(w)
	check(lf != null, "the leaf is falling")
	# Hold the Bloom still so nothing knocks the jump about.
	k.set_state("dormant")
	await frames(10)
	w.player.input.jump_pressed = true
	w.player.input.jump_held = true
	var top := w.player.global_position.y
	for i in 90:
		await frames(1)
		top = minf(top, w.player.global_position.y)
	w.player.input.jump_held = false
	var rise := k.floor_y() - top
	check(rise > MovementTuning.new().jump_height * 1.05, "a jump on the falling leaf carries higher (%.0f px)" % rise)
	k.hp = 1
	k.set_state("gape")
	k.head.take_hit(5, Vector2.RIGHT)
	check(not lf.falling, "when the Bloom dies the wind dies away")
	Feel.reset()
	var settled := await _until(func() -> bool: return _leaf_fall(w) == null, int(LeafFall.SETTLE_TIME * 60) * 3)
	check(settled, "and the leaf settles")


# --- Skyrend, the Storm Roc (bible 8.6) --------------------------------------

func _roc_world() -> Array:
	var w := make_world({}, "spires/roost")
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(3)
	var arena := _arena(w)
	w.player.teleport(cell_feet(8, 25))
	await _until(func() -> bool: return arena.fighting, 30)
	var b := get_tree_boss() as Skyrend
	await _until(func() -> bool: return b != null and b.state == "circle", 200)
	return [w, arena, b]


func _conduits(w: World) -> Array:
	var out := []
	for c in w.room.get_children():
		if c is Conduit:
			out.append(c)
	return out


## Makes it pick `move` next and counts the frames of its tell.
func _roc_provoke(b: Skyrend, move: String) -> int:
	b._last = "dive" if move == "volley" else "volley"
	b._last_move = b._last
	b._choose()
	var tell_frames := 0
	for i in 240:
		if b.state == move + "_tell":
			tell_frames += 1
		elif tell_frames > 0:
			break
		await frames(1)
	return tell_frames


func test_the_roost_wakes_skyrend() -> void:
	var setup := await _roc_world()
	var w: World = setup[0]
	var arena: BossArena = setup[1]
	var b: Skyrend = setup[2]
	check(arena.boss_id == "skyrend" and b != null and b.state == "circle", "walking into the roost brings the Storm Roc down")
	check(Music.track == "skyrend", "the fight plays its own theme (%s)" % Music.track)
	check(b.airborne() and b.global_position.y < b.floor_y() - 4 * Room.TILE, "it circles high over the islands")
	var cs := _conduits(w)
	check(cs.size() == 3 and cs.all(func(c: Conduit) -> bool: return c.flag_id == "" and not c.powered),
		"three dead conduits stand on the islands, part of the fight rather than the world")


func test_skyrend_telegraphs_are_fair() -> void:
	var b := Skyrend.new()
	for t: float in [Skyrend.VOLLEY_TELL, Skyrend.DIVE_TELL]:
		check(b.tell(t) >= Enemy.MIN_TELEGRAPH, "tell %.2f s is at least %.2f s" % [b.tell(t), Enemy.MIN_TELEGRAPH])
	b.free()


func test_skyrend_flings_a_fan_of_feathers() -> void:
	var setup := await _roc_world()
	var w: World = setup[0]
	var b: Skyrend = setup[2]
	var tell_frames := await _roc_provoke(b, "volley")
	check(tell_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "it throws its wings wide for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, tell_frames])
	await frames(1)
	var n := _count(w, HarpyFeather)
	check(n == Skyrend.VOLLEY_FEATHERS, "then flings %d storm feathers (%d)" % [Skyrend.VOLLEY_FEATHERS, n])


func test_skyrend_dives_through_where_you_stood() -> void:
	var setup := await _roc_world()
	var w: World = setup[0]
	var b: Skyrend = setup[2]
	var hp := w.player.hp
	var tell_frames := await _roc_provoke(b, "dive")
	check(tell_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "it fixes on you for at least %.2f s before it stoops (%d frames)" % [Enemy.MIN_TELEGRAPH, tell_frames])
	await _until(func() -> bool: return b.state == "climb", 60)
	check(w.player.hp <= hp - Skyrend.DIVE_DAMAGE / 2, "the dive hits a player standing still (%d)" % (hp - w.player.hp))
	var back := await _until(func() -> bool: return b.state == "circle", 90)
	check(back, "then it climbs back into the storm")


func test_conduits_ground_skyrend() -> void:
	var setup := await _roc_world()
	var w: World = setup[0]
	var b: Skyrend = setup[2]
	var hp0 := b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(hp0 - b.hp == 3, "in the air, its cloud turns most of a blow (%d)" % (hp0 - b.hp))
	var cs := _conduits(w)
	cs[0].power()
	cs[1].power()
	await frames(5)
	check(b.airborne(), "two conduits are not enough")
	cs[2].power()
	var down := await _until(func() -> bool: return b.grounded(), 60)
	check(down and absf(b.global_position.y + b.body_size.y * 0.5 - b.floor_y()) < 4.0, "the third grounds it on the floor (%s)" % b.state)
	check(not GameState.flag("conduits:spires/roost"), "and leaves no world flag behind")
	hp0 = b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(hp0 - b.hp == 10, "grounded, every blow lands in full (%d)" % (hp0 - b.hp))
	var up := await _until(func() -> bool: return b.state == "rise", int(Skyrend.GROUND_TIME * 60) + 30)
	check(up and cs.all(func(c: Conduit) -> bool: return not c.powered), "then it shakes the charge off and the conduits go dead")
	var flying := await _until(func() -> bool: return b.state == "circle", 90)
	check(flying, "and it climbs back into the sky")


func test_skyrend_defeat_gives_the_sky_key() -> void:
	var setup := await _roc_world()
	var w: World = setup[0]
	var b: Skyrend = setup[2]
	var points := int(GameState.data.skill_points)
	b.hp = 1
	b.take_hit(5, Vector2.RIGHT)
	check(b.state == "dying", "the last blow ends it")
	var gone := await _until(func() -> bool: return GameState.flag("boss:skyrend"), 600)
	check(gone, "Skyrend is marked beaten")
	check(GameState.key_count("sky") == 1, "it leaves the Sky Key")
	check(int(GameState.data.skill_points) >= points + 1, "and a skill point")
	await frames(90)
	check(get_tree_boss() == null, "the roc is gone")
	w._enter("spires/roost")
	await frames(10)
	check(get_tree_boss() == null, "and never returns")


func test_skyrend_storm_breaks_below_half() -> void:
	var setup := await _roc_world()
	var b: Skyrend = setup[2]
	check(b.phase == 1, "it starts in phase 1")
	b.hp = roundi(b.max_hp * Skyrend.PHASE_2) + 2
	b.take_hit(10, Vector2.RIGHT)
	check(b.phase == 2, "below half the storm breaks (%d hp)" % b.hp)
	check(StormStrike.TELL >= Enemy.MIN_TELEGRAPH, "a bolt marks its spot for at least %.2f s" % Enemy.MIN_TELEGRAPH)
	await _roc_provoke(b, "volley")
	await frames(1)
	var w: World = setup[0]
	check(_count(w, HarpyFeather) == Skyrend.VOLLEY_FEATHERS_2, "and the volley throws %d (%d)" % [Skyrend.VOLLEY_FEATHERS_2, _count(w, HarpyFeather)])


func _storm_bolt(w: World) -> StormStrike:
	for c in w.room.get_children():
		if c is StormStrike and not c.is_queued_for_deletion():
			return c
	return null


func test_the_storm_strikes_you_when_you_stand_high() -> void:
	var setup := await _roc_world()
	var w: World = setup[0]
	var b: Skyrend = setup[2]
	b.phase = 2
	b._storm = 999.0
	w.player.teleport(cell_feet(8, 19))
	await frames(5)
	b._call_storm()
	var bolt := _storm_bolt(w)
	check(bolt != null and absf(bolt.global_position.x - w.player.global_position.x) < 1.0, "up on an island, you are the tallest point")
	var hp := w.player.hp
	await frames(int(StormStrike.TELL * 60) - 6)
	check(w.player.hp == hp, "nothing lands during the tell")
	await frames(12)
	check(hp - w.player.hp >= StormStrike.DAMAGE, "then the bolt strikes you (%d)" % (hp - w.player.hp))


func test_the_storm_wakes_a_conduit_when_you_stay_low() -> void:
	var setup := await _roc_world()
	var w: World = setup[0]
	var b: Skyrend = setup[2]
	b.phase = 2
	b._storm = 999.0
	b._call_storm()
	var bolt := _storm_bolt(w)
	check(bolt != null and bolt.global_position.y < b.floor_y() - Skyrend.ELEVATED, "on the floor, the bolt goes for a conduit up on an island")
	await frames(int(StormStrike.TELL * 60) + 6)
	var awake := _conduits(w).filter(func(c: Conduit) -> bool: return c.powered).size()
	check(awake == 1, "and wakes it (%d awake)" % awake)


func test_a_lone_conduit_drains_in_the_storm() -> void:
	var setup := await _roc_world()
	var w: World = setup[0]
	var b: Skyrend = setup[2]
	var cs := _conduits(w)
	cs[0].power()
	await frames(int(Skyrend.DRAIN_TIME * 60) + 20)
	check(cs[0].powered, "in phase 1 a woken conduit holds its charge")
	b.phase = 2
	b._storm = 999.0
	await frames(int(Skyrend.DRAIN_TIME * 60) + 20)
	check(not cs[0].powered, "in the storm it drains unless all three wake together")


func _updraft(w: World) -> Updraft:
	for c in w.room.get_children():
		if c is Updraft and not c.is_queued_for_deletion():
			return c
	return null


## Phase 3 with the player on the floor under the left lane; the roc starts its gale.
func _roc_duel() -> Array:
	var setup := await _roc_world()
	var w: World = setup[0]
	var b: Skyrend = setup[2]
	b.phase = 3
	b._storm = 0.05
	var lane := b.gale_point(0.0)
	w.player.teleport(Vector2(lane.x, b.floor_y()))
	await frames(2)
	b._last = "volley"
	b._last_move = "volley"
	b._choose()
	return setup


func test_skyrend_duel_begins_below_a_quarter() -> void:
	var setup := await _roc_world()
	var b: Skyrend = setup[2]
	b.hp = roundi(b.max_hp * Skyrend.PHASE_2) + 2
	b.take_hit(10, Vector2.RIGHT)
	check(b.phase == 2, "the storm first")
	b.hp = roundi(b.max_hp * Skyrend.PHASE_3) + 2
	b.take_hit(10, Vector2.RIGHT)
	check(b.phase == 3, "below a quarter the duel begins (%d hp)" % b.hp)
	check(b.tell(Skyrend.GALE_TELL) >= Enemy.MIN_TELEGRAPH, "the gale's tell is fair")
	b._last = "volley"
	b._last_move = "volley"
	b._choose()
	check(b.state == "gale_tell", "its next move is the gale (%s)" % b.state)


func test_skyrend_holds_a_gale_over_an_open_lane() -> void:
	var setup := await _roc_duel()
	var w: World = setup[0]
	var b: Skyrend = setup[2]
	var u := _updraft(w)
	check(b.state == "gale_tell" and u != null and not u.active, "it beats its wings and the dust stirs where the wind will rise")
	var tell_frames := 0
	while b.state == "gale_tell" and tell_frames < 120:
		tell_frames += 1
		await frames(1)
	check(tell_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "the tell lasts at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, tell_frames])
	check(b.holding_gale() and u.active, "then it holds the gale over a column of rising wind")
	var lane := b.gale_point(w.player.global_position.x)
	check(b.global_position.distance_to(lane) < 2.0, "hovering over the open lane between the islands")
	check(u.column_rect().position.y < b.body_rect().position.y - 8.0, "the wind reaches above its head")
	check(b.contact_damage == 0, "it doesn't touch you while it beats")
	check(_storm_bolt(w) == null, "and the storm waits")
	var hp0 := b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(hp0 - b.hp == 3, "a blow from the side is still turned by its cloud (%d)" % (hp0 - b.hp))
	hp0 = b.hp
	b.take_hit(10, Vector2.DOWN)
	check(hp0 - b.hp == 10, "a blow from above lands in full (%d)" % (hp0 - b.hp))
	var climbed := await _until(func() -> bool: return b.state == "climb", int(Skyrend.GALE_TIME * 60) + 30)
	check(climbed and _updraft(w) == null, "then it climbs away and the wind dies")
	b._choose()
	check(b.state != "gale_tell", "it doesn't hold two gales in a row (%s)" % b.state)


func test_the_updraft_carries_you_up_to_pogo_its_head() -> void:
	var setup := await _roc_duel()
	var w: World = setup[0]
	var b: Skyrend = setup[2]
	var p := w.player
	p.abilities["delvers_pick"] = true
	await _until(func() -> bool: return b.holding_gale(), 90)
	var rose := await _until(func() -> bool: return p.body_rect().end.y < b.body_rect().position.y, 120)
	check(rose, "the wind carries you up past its head")
	check(p.has_double_jump, "and gives back your air moves")
	var hp0 := b.hp
	var bounced := false
	for i in 90:
		if p.velocity.y > 0.0 and not p.is_attacking:
			p.input.down = true
			p.input.attack_pressed = true
		await frames(1)
		if b.hp < hp0 and p.velocity.y < -200.0:
			bounced = true
			break
	p.input.down = false
	var full := roundi(p.slash_damage * p.melee_mult * p.down_strike_mult)
	check(bounced, "holding Down drops you onto its head, and the pogo bounces you back up")
	check(hp0 - b.hp == full, "the pogo lands in full (%d of %d)" % [hp0 - b.hp, full])


func test_holding_down_drops_out_of_the_updraft() -> void:
	var setup := await _roc_duel()
	var w: World = setup[0]
	var b: Skyrend = setup[2]
	var p := w.player
	await _until(func() -> bool: return b.holding_gale(), 90)
	p.input.down = true
	await frames(30)
	check(p.is_on_floor(), "with Down held the wind doesn't lift you")
	p.input.down = false
	await frames(30)
	check(not p.is_on_floor() and p.velocity.y < 0.0, "let go and it carries you up")


# --- Thane Vorrund, the Unweeping (bible 8.7) -----------------------------

func _king_world() -> Array:
	var w := make_world({}, "vorrhallow/throne_hall")
	w.player.max_hp = 9999
	w.player.hp = 9999
	w.player.abilities["stillstone"] = true
	w.player.abilities["delvers_pick"] = true
	await frames(3)
	var arena := _arena(w)
	w.player.teleport(cell_feet(10, 19))
	await _until(func() -> bool: return arena.fighting, 30)
	var b := get_tree_boss() as ThaneVorrund
	await _until(func() -> bool: return b != null and b.state == "walk", 200)
	return [w, arena, b]


func test_the_throne_hall_wakes_thane_vorrund() -> void:
	var setup := await _king_world()
	var arena: BossArena = setup[1]
	var b: ThaneVorrund = setup[2]
	check(arena.boss_id == "thane_vorrund" and b != null and b.state == "walk", "walking into the throne hall wakes the king")
	check(b.phase == 1 and absf(b.global_position.y - b.floor_y()) < 2.0, "he comes down off his throne to duel on the floor")
	check(Music.track == "vorrund", "the fight plays his own theme (%s)" % Music.track)


func test_thane_vorrund_telegraphs_are_fair() -> void:
	var b := ThaneVorrund.new()
	for p in [1, 2]:
		b.phase = p
		for t: float in [ThaneVorrund.CHOP_TELL, ThaneVorrund.SWEEP_TELL, ThaneVorrund.LEAP_TELL, ThaneVorrund.SUMMON_TELL]:
			check(b.tell(t) >= Enemy.MIN_TELEGRAPH, "phase %d tell %.2f s is at least %.2f s" % [p, b.tell(t), Enemy.MIN_TELEGRAPH])
	check(CrystalShard.GLOW >= Enemy.MIN_TELEGRAPH, "a shard glows in the floor for at least %.2f s" % Enemy.MIN_TELEGRAPH)
	b.free()


func test_thane_vorrund_chops_then_sweeps_and_a_parry_opens_him() -> void:
	var setup := await _king_world()
	var w: World = setup[0]
	var b: ThaneVorrund = setup[2]
	w.player.teleport(Vector2(b.global_position.x - 40.0, b.floor_y()))
	var hp := w.player.hp
	var chop := 0
	var sweep := 0
	for i in 200:
		await frames(1)
		if b.state == "chop_tell":
			chop += 1
		if b.state == "sweep_tell":
			sweep += 1
		if b.state == "recover":
			break
	check(chop / 60.0 >= Enemy.MIN_TELEGRAPH and sweep / 60.0 >= Enemy.MIN_TELEGRAPH, "both blows are telegraphed (%d and %d frames)" % [chop, sweep])
	check(w.player.hp < hp, "and the pair catches a player standing still (%d)" % (hp - w.player.hp))
	var hp0 := b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(hp0 - b.hp == 5, "his crystal half turns half a blow (%d)" % (hp0 - b.hp))
	b.set_state("chop")
	b.stagger()
	check(b.open(), "a parry leaves him reeling")
	hp0 = b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(hp0 - b.hp == 10, "and open to every blow (%d)" % (hp0 - b.hp))


## Pass 412 (bible 8): a guardian parried with the buttons. Every boss parry
## test called `stagger()` itself, so the path a player takes (Block pressed
## through `Input` in the moments before the axe falls, the blow caught in the
## parry window, the guardian thrown reeling) was never played. Thane Vorrund's
## chop is parried here with the real controller; Block pressed at the start
## of his wind-up, too early for the window, only guards the blow.
func _real_block_against_the_chop(frames_before: int) -> Array:
	var setup := await _king_world()
	var w: World = setup[0]
	var b: ThaneVorrund = setup[2]
	var p := w.player
	GameState.obtain_gear("small_shield", p)
	p.input = PlayerInput.new()
	p.teleport(Vector2(b.global_position.x - 40.0, b.floor_y()))
	p.facing = 1
	await frames(2)
	await _until(func() -> bool: return b.state == "chop_tell", 200)
	var press_at := b.tell(ThaneVorrund.CHOP_TELL) - frames_before / 60.0
	await _until(func() -> bool: return b.state != "chop_tell" or b.state_time >= press_at, 120)
	var hp := p.hp
	Sfx.recent.clear()
	Input.action_press("block")
	var opened := false
	for i in 40:
		await frames(1)
		if b.open():
			opened = true
			break
	var heard := Sfx.recent.has("parry")
	release_for_real(["block"])
	var took := hp - p.hp
	w.queue_free()
	await frames(1)
	return [opened, took, heard]


func test_thane_vorrund_is_parried_through_the_real_controller() -> void:
	var c := CombatTuning.new()
	var late: Array = await _real_block_against_the_chop(3)
	check(late[0] and late[2], "Block pressed just before the axe falls parries it, and he reels (%s)" % [late])
	check(late[1] == 0, "and the chop does no harm (%d)" % late[1])
	var early: Array = await _real_block_against_the_chop(int(ThaneVorrund.CHOP_TELL * 60.0) - 2)
	check(not early[0] and not early[2], "pressed at the start of the wind-up, past the %.2f s window by the blow, it does not parry (%s)" % [c.parry_window, early])
	check(early[1] > 0 and early[1] <= ceili(40 * (1.0 - c.guard_reduction)), "the shield still held up guards half the chop (%d)" % early[1])
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("`test_thane_vorrund_is_parried_through_the_real_controller`"), "bible 8 names the test")

## Pass 466 (bible 9): Executioner on a guardian, by the buttons. Its test cut a
## Rot Dwarf put in the "boss" group and staggered by a call. Here it is played
## as a player meets it: Thane Vorrund's chop parried with the real Block, then
## a real Attack tap into his reeling. With Executioner the cut lands for 35%
## more, with its own sound; without it, plain. Returns [opened, damage the cut
## did, the execute sound heard].
func _real_cut_into_vorrunds_opening(executioner: bool) -> Array:
	var setup := await _king_world()
	var w: World = setup[0]
	var b: ThaneVorrund = setup[2]
	var p := w.player
	GameState.obtain_gear("small_shield", p)
	GameState.data.skill_points = 40
	# The Blade branch to the Thrust either way, so both cuts share every
	# multiplier but Executioner.
	for id: String in ["keen_edge", "fourth_strike", "rising_cut", "delvers_pick_mastery", "riposte", "keener_edge", "bloodletting", "thrust"] + (["executioner"] if executioner else []):
		check(Skills.learn(id, p), "learned %s" % id)
	check(p.executioner == executioner, "Executioner is %s" % ("on" if executioner else "off"))
	b.max_hp = 99999
	b.hp = 99999
	p.input = PlayerInput.new()
	p.teleport(Vector2(b.global_position.x - 40.0, b.floor_y()))
	p.facing = 1
	await frames(2)
	await _until(func() -> bool: return b.state == "chop_tell", 200)
	var press_at := b.tell(ThaneVorrund.CHOP_TELL) - 3 / 60.0
	await _until(func() -> bool: return b.state != "chop_tell" or b.state_time >= press_at, 120)
	Input.action_press("block")
	var opened: bool = await _until(func() -> bool: return b.open(), 40)
	release_for_real(["block"])
	await frames(2)
	Input.action_press("move_right")
	await _until(func() -> bool: return b.global_position.x - p.global_position.x <= 30.0 or not b.open(), 60)
	Input.action_release("move_right")
	var hp0 := b.hp
	Sfx.recent.clear()
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(4)
	var out := [opened and b.open(), hp0 - b.hp, Sfx.recent.has("execute")]
	w.queue_free()
	await frames(1)
	return out


func test_executioner_cuts_into_a_parried_guardian_by_the_buttons() -> void:
	var plain: Array = await _real_cut_into_vorrunds_opening(false)
	var exe: Array = await _real_cut_into_vorrunds_opening(true)
	check(plain[0] and exe[0], "a real Block parries the chop and he reels for the cut (%s, %s)" % [plain, exe])
	check(plain[1] > 0 and not plain[2], "without Executioner a real cut into the opening lands plain (%d)" % plain[1])
	check(exe[1] == roundi(plain[1] * CombatTuning.new().executioner_mult) and exe[2], "with it, the same cut lands for 35%% more, with its sound (%d against %d)" % [exe[1], plain[1]])


## Pass 428 (bible 8): a guardian's blow dodged with the buttons. The parry
## above is the one boss defence ever played through `Input`; a jump over a
## low blow, the oldest dodge there is, never was. Thane Vorrund's combo is a
## tall chop (54 px) and then a low, wide sweep (64 px, 22 px high). Standing
## 62 px off, the chop falls short and the sweep finds you; Jump pressed for
## real during the sweep's wind-up carries you over it. Returns [the damage
## the chop did, the damage the sweep did]. `jump_left` is how many steps of
## the wind-up are left when Jump is pressed (-1 = never).
func _real_jump_over_the_sweep(jump_left: int) -> Array:
	var setup := await _king_world()
	var w: World = setup[0]
	var b: ThaneVorrund = setup[2]
	var p := w.player
	p.input = PlayerInput.new()
	p.teleport(Vector2(b.global_position.x - 62.0, b.floor_y()))
	await frames(2)
	await _until(func() -> bool: return b.state == "chop_tell", 200)
	var hp := p.hp
	await _until(func() -> bool: return b.state == "sweep_tell", 60)
	var chop := hp - p.hp
	hp = p.hp
	if jump_left >= 0:
		var press_at := b.tell(ThaneVorrund.SWEEP_TELL) - jump_left / 60.0
		await _until(func() -> bool: return b.state != "sweep_tell" or b.state_time >= press_at, 60)
		Input.action_press("jump")
	await _until(func() -> bool: return b.state != "sweep_tell" and b.state != "sweep", 60)
	release_for_real(["jump"])
	var sweep := hp - p.hp
	w.queue_free()
	await frames(1)
	return [chop, sweep]


func test_thane_vorrunds_sweep_is_jumped_through_the_real_controller() -> void:
	var still: Array = await _real_jump_over_the_sweep(-1)
	check(still[0] == 0, "62 px off, the chop falls short (%d)" % still[0])
	check(still[1] > 0, "and the low sweep finds a player standing still (%d)" % still[1])
	var jumped: Array = await _real_jump_over_the_sweep(6)
	check(jumped[0] == 0 and jumped[1] == 0, "Jump pressed in the sweep's wind-up carries you over it (%s)" % [jumped])
	var late: Array = await _real_jump_over_the_sweep(-12)
	check(late[1] == still[1], "pressed once the axe is already sweeping, it is too late (%d)" % late[1])
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("`test_thane_vorrunds_sweep_is_jumped_through_the_real_controller`"), "bible 8 names the test")


func test_thane_vorrund_takes_the_throne_below_half_and_falls_to_a_crown_blow() -> void:
	var setup := await _king_world()
	var w: World = setup[0]
	var b: ThaneVorrund = setup[2]
	w.player.teleport(cell_feet(8, 19))
	b.hp = roundi(b.max_hp * 0.5) + 2
	b.take_hit(10, Vector2.RIGHT)
	check(b.phase == 2, "below half the second phase begins")
	var warded := await _until(func() -> bool: return b.state == "ward", 90)
	check(warded and absf(b.global_position.y - b.dais.position.y) < 2.0, "he leaps up onto his dais and wards himself (%s at %s)" % [b.state, b.global_position])
	var hp0 := b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(b.hp == hp0, "warded, a blow from the side does nothing")
	b.take_hit(10, Vector2(0, 1))
	check(hp0 - b.hp == 10, "but a blow down on his crown lands (%d)" % (hp0 - b.hp))
	await frames(2)
	check(b.state == "fallen", "and throws him from the throne")
	var down := await _until(func() -> bool: return b.is_on_floor() and absf(b.global_position.y - b.floor_y()) < 2.0, 90)
	check(down and b.global_position.x < b.dais.position.x, "down onto the hall floor")
	hp0 = b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(hp0 - b.hp == 10, "where every blow lands (%d)" % (hp0 - b.hp))


func test_thane_vorrunds_shards_are_a_stair_while_time_stands_still() -> void:
	var setup := await _king_world()
	var w: World = setup[0]
	var b: ThaneVorrund = setup[2]
	w.player.teleport(cell_feet(4, 19))
	b._summon()
	check(_count(w, CrystalShard) == ThaneVorrund.SHARDS, "he calls up %d shards" % ThaneVorrund.SHARDS)
	var shards: Array = w.room.get_children().filter(func(c: Node) -> bool: return c is CrystalShard)
	await frames(int((CrystalShard.GLOW + ThaneVorrund.SHARD_STAGGER * (ThaneVorrund.SHARDS - 1)) * 60) + 20)
	var ys: Array = shards.map(func(s: CrystalShard) -> float: return s.global_position.y)
	check(ys[0] < ys[1] and ys[1] < ys[2] and ys[2] < ys[3], "rising, the shards nearest the throne are highest: a stair (%s)" % [ys])
	TimeStop.start()
	await frames(2)
	var s: CrystalShard = shards[2]
	var at := s.global_position
	check(s.held(), "the Stillstone holds them in the air")
	w.player.teleport(Vector2(at.x, at.y - CrystalShard.SIZE.y * 0.5 - 6.0))
	w.player.velocity = Vector2.ZERO
	await frames(30)
	check(s.global_position == at, "a held shard does not move")
	check(w.player.is_on_floor() and absf(w.player.global_position.y - (at.y - CrystalShard.SIZE.y * 0.5)) < 3.0, "and holds you up (%s vs %s)" % [w.player.global_position, at])
	TimeStop.reset()
	await frames(3)
	check(not is_instance_valid(s) or s.is_queued_for_deletion(), "when time runs again it cracks and falls to pieces")


## Pass 217: as in the source game, the Severance is the sword Thane Vorrund
## swallowed, so beating him gives it up, straight into your hand.
func test_thane_vorrund_defeat_gives_the_frost_seed_and_the_severance() -> void:
	var setup := await _king_world()
	var w: World = setup[0]
	var b: ThaneVorrund = setup[2]
	var points := int(GameState.data.skill_points)
	var banners: Array = []
	var said: Array = []
	var on_banner := func(title: String, text: String) -> void:
		banners.append(title)
		said.append(text)
	GameState.banner.connect(on_banner)
	check(not w.player.abilities.get("severance", false), "no one holds the Severance before him")
	b.hp = 1
	b.take_hit(5, Vector2.RIGHT)
	check(b.state == "dying", "the last blow ends it")
	var gone := await _until(func() -> bool: return GameState.flag("boss:thane_vorrund"), 600)
	check(gone, "Thane Vorrund is marked beaten")
	check(GameState.data.rings.has("frost"), "he leaves the Frost Seed")
	check(int(GameState.data.skill_points) >= points + 1, "and a skill point")
	GameState.banner.disconnect(on_banner)
	check(w.player.abilities.get("severance", false) and GameState.has_ability("severance"), "he gives up the Severance")
	check(GameState.data.equipment.blade == "severance" and Array(GameState.data.gear).has("severance"), "and it goes straight into your hand")
	check(w.player.slash_damage == int(GameData.item("severance").slash), "it cuts as the Severance (%d)" % w.player.slash_damage)
	check(banners.has("Severance"), "and the banner names it (%s)" % [banners])
	check(said.any(func(t: String) -> bool: return t.contains("weeps at last")), "and says he weeps at last (pass 479; %s)" % [said])
	await frames(90)
	w._enter("vorrhallow/throne_hall")
	await frames(10)
	check(get_tree_boss() == null, "and he never returns")


func test_a_guardians_fall_rings_a_fanfare_of_its_own() -> void:
	var item: AudioStreamWAV = load("res://assets/sfx/item.wav")
	var won: AudioStreamWAV = load("res://assets/sfx/" + BossArena.WIN_SOUND + ".wav")
	check(won != null, "the fanfare is on disk")
	if won == null:
		return
	check(won.get_length() >= 2.0 and won.get_length() > item.get_length() * 2.0,
		"and rings out long past a find's chime (%.2f s against %.2f s)" % [won.get_length(), item.get_length()])
	check(BossArena.WIN_FADE <= 0.5, "the boss theme drops away under it (%.1f s)" % BossArena.WIN_FADE)
	var setup := await _king_world()
	var b: ThaneVorrund = setup[2]
	b.hp = 1
	Sfx.recent.clear()
	b.take_hit(5, Vector2.RIGHT)
	await _until(func() -> bool: return GameState.flag("boss:thane_vorrund"), 600)
	check(Sfx.recent.has(BossArena.WIN_SOUND), "Thane Vorrund's fall rings it (%s)" % [Sfx.recent])
	check(Music.track == "", "and the fight's music stops for it (%s)" % Music.track)


func test_the_meteor_takes_thane_vorrund_below_a_fifth() -> void:
	var setup := await _king_world()
	var w: World = setup[0]
	var b: ThaneVorrund = setup[2]
	for t: float in [ThaneVorrund.CHOP_TELL, ThaneVorrund.SWEEP_TELL, ThaneVorrund.LEAP_TELL, ThaneVorrund.BURST_TELL]:
		b.phase = 3
		check(b.tell(t) >= Enemy.MIN_TELEGRAPH, "frantic, tell %.2f s is still at least %.2f s" % [b.tell(t), Enemy.MIN_TELEGRAPH])
	b.phase = 1
	w.player.teleport(cell_feet(8, 19))
	b.hp = roundi(b.max_hp * 0.5) + 2
	b.take_hit(10, Vector2.RIGHT)
	await _until(func() -> bool: return b.state == "ward", 90)
	b.hp = roundi(b.max_hp * ThaneVorrund.PHASES[1]) + 2
	b.take_hit(10, Vector2(0, 1))
	check(b.phase == 3 and b.state == "possessed", "below a fifth the Everbloom takes him (%d, %s)" % [b.phase, b.state])
	var hp0 := b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(b.hp == hp0, "untouchable while it does")
	var down := await _until(func() -> bool: return b.state == "walk", 150)
	check(down and absf(b.global_position.y - b.floor_y()) < 2.0 and b.global_position.x < b.dais.position.x, "then he comes down off the throne for good")
	hp0 = b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(hp0 - b.hp == 10, "cracked open, he turns no blow (%d)" % (hp0 - b.hp))
	# His combos now end with the axe driven into the floor and a line of spikes.
	w.player.teleport(Vector2(b.global_position.x - 50.0, b.floor_y()))
	var spikes := await _until(func() -> bool: return _count(w, CrystalSpike) > 0, 240)
	check(spikes, "his combo ends in a burst of crystal spikes toward you (%d)" % _count(w, CrystalSpike))


func test_the_water_clock_drains_with_the_king() -> void:
	var setup := await _king_world()
	var w: World = setup[0]
	var b: ThaneVorrund = setup[2]
	var clocks: Array = w.room.get_children().filter(func(c: Node) -> bool: return c is WaterClock)
	check(clocks.size() == 1, "the throne hall has its water-clock")
	var clock: WaterClock = clocks[0]
	check(clock.level > 0.99, "full at the start of the fight")
	b.hp = roundi(b.max_hp * 0.6)
	await frames(120)
	check(clock.level < 0.95 and clock.level >= 0.6 - 0.01, "it drains as he weakens (%.2f)" % clock.level)
	GameState.set_flag("boss:thane_vorrund")
	check(is_equal_approx(clock.target_level(), 0.0), "and stands empty once he is beaten")


func _likeness_world() -> Array:
	var w := make_world({}, "vorrhallow/evercrown_gate")
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(3)
	var arena := _arena(w)
	w.player.teleport(cell_feet(14, 19))
	await _until(func() -> bool: return arena.fighting, 30)
	var b := get_tree_boss() as Likeness
	await _until(func() -> bool: return b != null and b.state == "mirror", 200)
	return [w, arena, b]


## Pass 452 (bible 8): a fight lost in the room you rest in starts over.
## the Likeness's gate has a Meditation Shrine of its own. Rest there by the
## real Up, walk in by the real Right and wound her, then fall: until now the
## hero rose beside the shrine with the doors still sealed and the Likeness still up,
## her wounds kept and the fight's music still lifted. Now the room is built
## afresh: no guardian, the way in open, the zone's music as written, and the
## real Right wakes her again whole.
func test_a_fight_lost_beside_its_own_shrine_starts_over() -> void:
	var was := GameState.slot
	GameState.slot = 9
	var w := make_world({}, "vorrhallow/evercrown_gate")
	var p := w.player
	p.input = PlayerInput.new()
	await frames(3)
	var shrine: SaveShrine = null
	for c in w.room.get_children():
		if c is SaveShrine:
			shrine = c
	check(shrine != null, "the Crown Gate has a shrine of its own")
	var shrine_x := shrine.global_position.x
	p.teleport(shrine.global_position)
	await frames(2)
	Input.action_press("move_up")
	await frames(2)
	Input.action_release("move_up")
	await frames(2)
	check(GameState.data.save_room == "vorrhallow/evercrown_gate", "Up at it rests and saves there")
	var arena := _arena(w)
	Input.action_press("move_right")
	var woke := await _until(func() -> bool: return arena.fighting, 300)
	Input.action_release("move_right")
	var b := get_tree_boss()
	check(woke and b != null and arena.seals.size() == 2, "Right walks in, wakes the Likeness and seals both doors")
	b.hp = roundi(b.max_hp * 0.4)
	await frames(30)
	check(Music.intensity > 0, "wounded past her marks, the fight's music rises (%d)" % Music.intensity)
	p.take_damage(9999)
	await frames(int(p.combat.respawn_delay * 60.0) + 20)
	check(not p.dead and w.room.id == "vorrhallow/evercrown_gate" and absf(p.global_position.x - shrine_x) < 2.0, "he rises at the shrine")
	arena = _arena(w)
	check(get_tree_boss() == null and not arena.fighting, "and the fight is over: no Likeness waits beside him (%s)" % [get_tree_boss()])
	check(not arena.seals.has(1), "the way in is open again (%s)" % [arena.seals.keys()])
	check(Music.intensity == 0 and Music.track != "likeness", "and the music is the zone's again (%s, %d)" % [Music.track, Music.intensity])
	Input.action_press("move_right")
	woke = await _until(func() -> bool: return arena.fighting, 300)
	Input.action_release("move_right")
	b = get_tree_boss()
	check(woke and b != null and b.hp == b.max_hp, "Right wakes her again, whole (%d of %d)" % [(b.hp if b else -1), (b.max_hp if b else -1)])
	GameState.delete_save(9)
	GameState.slot = was
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n## 8. Bosses", 1).get_slice("\n### 8.1 ", 0)
	check(note.contains("`test_a_fight_lost_beside_its_own_shrine_starts_over`"), "bible 8 names the test")


## Pass 455 (bible 8): no rest while a guardian stands. The Crown Gate's
## shrine lies inside the Likeness's arena, and Up at it mid-fight made the
## hero whole, refilled his magic and saved with her still up. Now the real Up
## there mid-fight says no and changes nothing; before the fight, and once the
## doors open again, it rests as any shrine does.
func test_no_rest_while_a_guardian_stands() -> void:
	var was := GameState.slot
	GameState.slot = 9
	var w := make_world({}, "vorrhallow/evercrown_gate")
	var p := w.player
	p.input = PlayerInput.new()
	await frames(3)
	var shrine: SaveShrine = null
	for c in w.room.get_children():
		if c is SaveShrine:
			shrine = c
	var arena := _arena(w)
	p.teleport(shrine.global_position)
	await frames(2)
	p.hp = 10
	await _tap_up()
	check(p.hp == p.max_hp and GameState.data.save_room == "vorrhallow/evercrown_gate", "before the fight, Up at the shrine rests and saves")
	GameState.data.save_room = ""
	p.teleport(cell_feet(14, 19))
	var woke := await _until(func() -> bool: return arena.fighting, 60)
	check(woke and get_tree_boss() != null, "the Likeness wakes and the doors seal")
	p.hp = 10
	p.mp = 0
	p.teleport(shrine.global_position)
	await frames(2)
	var toasts: Array[String] = []
	var hear := func(text: String) -> void: toasts.append(text)
	GameState.toast.connect(hear)
	Sfx.recent.clear()
	await _tap_up()
	GameState.toast.disconnect(hear)
	check(p.hp == 10 and p.mp < 1.0, "mid-fight, Up at the shrine mends nothing (%d HP, %.0f MP)" % [p.hp, p.mp])
	check(GameState.data.save_room == "", "and saves nothing (%s)" % GameState.data.save_room)
	check(Sfx.recent.has("menu_refuse") and not Sfx.recent.has("save"), "heard as a refusal, not the save chime (%s)" % [Sfx.recent])
	check(toasts == [SaveShrine.NO_REST_IN_FIGHT], "and says why (%s)" % [toasts])
	arena._open_doors()
	await frames(2)
	await _tap_up()
	check(p.hp == p.max_hp and GameState.data.save_room == "vorrhallow/evercrown_gate", "once the doors open again, it rests and saves")
	GameState.delete_save(9)
	GameState.slot = was
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n## 8. Bosses", 1).get_slice("\n### 8.1 ", 0)
	check(note.contains("`test_no_rest_while_a_guardian_stands`"), "bible 8 names the test")


func _tap_up() -> void:
	Input.action_press("move_up")
	await frames(2)
	Input.action_release("move_up")
	await frames(2)


func test_likeness_waits_before_the_gate_as_your_reflection() -> void:
	var setup := await _likeness_world()
	var w: World = setup[0]
	var arena: BossArena = setup[1]
	var b: Likeness = setup[2]
	check(arena.boss_id == "likeness" and b != null and b.state == "mirror", "walking up to the gate wakes your shadow")
	check(absf(b.axis() - w.room.size_tiles.x * Room.TILE * 0.5) < 1.0, "the mirror runs down the middle of the hall")
	var p := w.player
	check(absf(b.global_position.x - b.mirrored(p.global_position).x) < 2.0 and b.facing == -p.facing, "it stands where you stand, across the glass (%s vs %s)" % [b.global_position, p.global_position])
	# Walk right: the shadow walks left, DELAY behind.
	var trail: Array[Vector2] = []
	p.input.move_x = 1
	for i in 50:
		await frames(1)
		trail.append(p.global_position)
	p.input.move_x = 0
	var then := trail[trail.size() - 1 - roundi(Likeness.DELAY * 60.0)]
	check(absf(b.global_position.x - b.mirrored(then).x) < 6.0, "it copies where you were %.1f s ago, mirrored (%.0f vs %.0f)" % [Likeness.DELAY, b.global_position.x, b.mirrored(then).x])
	check(b.global_position.x > b.mirrored(p.global_position).x + 20.0, "so it lags behind you")
	check(b.facing == -1, "facing back at you")
	# A clip the old sheet lacks (the Rune Dagger's flick) mirrors as its cast.
	p.abilities["rune_dagger"] = true
	p.throw_dagger()
	await frames(2)
	check(p.visual.anim == "throw" and b._history.back().anim == "cast", "a throw is reflected as the cast (%s, %s)" % [p.visual.anim, b._history.back().anim])


func test_likeness_echoes_your_swing_and_a_parry_breaks_it() -> void:
	check(Likeness.SWING_TELL >= Enemy.MIN_TELEGRAPH and Likeness.SWING_TELL <= Likeness.DELAY, "an echo glints at least %.2f s before it lands" % Enemy.MIN_TELEGRAPH)
	check(Likeness.RISE_TELL >= Enemy.MIN_TELEGRAPH, "and so does its cut from behind")
	var setup := await _likeness_world()
	var w: World = setup[0]
	var b: Likeness = setup[2]
	var p := w.player
	p.has_shield = true
	# At the mirror line, face to face with your reflection.
	p.teleport(Vector2(b.axis() - 10.0, 19 * Room.TILE))
	p.facing = 1
	await frames(int(Likeness.DELAY * 60.0) + 10)
	check(absf(b.global_position.x - (b.axis() + 10.0)) < 2.0, "it meets you at the glass")
	var hp0 := b.hp
	var php := p.hp
	p.input.attack_pressed = true
	await frames(10)
	check(b.hp < hp0, "you can strike it there (%d)" % (hp0 - b.hp))
	var told := 0
	for i in 60:
		await frames(1)
		if b.telling():
			told += 1
		if b.state == "echo":
			break
	check(b.state == "echo", "it swings your swing back at you")
	check(told / 60.0 >= Enemy.MIN_TELEGRAPH, "after its blade glints (%d frames)" % told)
	await frames(6)
	check(p.hp < php, "and the echo cuts you if you stand there (%d)" % (php - p.hp))
	# The echo of a swing, parried.
	await frames(40)
	p.teleport(Vector2(b.axis() - 10.0, 19 * Room.TILE))
	p.facing = 1
	await frames(int(Likeness.DELAY * 60.0) + 4)
	p.input.attack_pressed = true
	await _until(func() -> bool: return b.next_echo_in() <= 0.05, 60)
	p.input.block_pressed = true
	p.input.block_held = true
	var reeled := await _until(func() -> bool: return b.state == "stagger", 20)
	p.input.block_pressed = false
	p.input.block_held = false
	check(reeled and not b.mirroring(), "a parried echo leaves it reeling, out of the mirror (%s)" % b.state)
	var back := await _until(func() -> bool: return b.state == "mirror", 150)
	check(back, "then it slips back behind the glass")


func test_likeness_comes_through_the_mirror_if_you_hold_still() -> void:
	var setup := await _likeness_world()
	var w: World = setup[0]
	var b: Likeness = setup[2]
	var p := w.player
	p.teleport(cell_feet(20, 19))
	p.facing = 1
	var php := p.hp
	var sank := await _until(func() -> bool: return b.state == "sink", roundi(Likeness.STILL_TIME * 60.0) + 40)
	check(sank, "hold still and it sinks into the floor")
	var hp0 := b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(b.hp == hp0, "where no blow can reach it")
	var rose := await _until(func() -> bool: return b.state == "rise", 60)
	check(rose and b.global_position.x < p.global_position.x and absf(b.global_position.x - p.global_position.x) < Likeness.BEHIND + 2.0, "and rises right behind you (%s vs %s)" % [b.global_position, p.global_position])
	var cut := await _until(func() -> bool: return b.state == "cut", 60)
	check(cut and b.state_time < 0.1, "blade raised for %.2f s before it cuts" % Likeness.RISE_TELL)
	await frames(6)
	check(p.hp < php, "the cut lands on a player who stood still")
	var back := await _until(func() -> bool: return b.state == "mirror", 120)
	check(back and absf(b.global_position.x - b.mirrored(p.global_position).x) < 2.0, "then it returns to the glass")


func test_beating_likeness_breaks_the_mirror() -> void:
	var setup := await _likeness_world()
	var w: World = setup[0]
	var b: Likeness = setup[2]
	var points := int(GameState.data.skill_points)
	b.hp = 1
	b.take_hit(5, Vector2.RIGHT)
	check(b.state == "dying", "the last blow ends it")
	var gone := await _until(func() -> bool: return GameState.flag("boss:likeness"), 600)
	check(gone, "the Likeness is marked beaten")
	check(int(GameState.data.skill_points) >= points + 1, "for a skill point")
	await frames(90)
	w._enter("vorrhallow/evercrown_gate")
	await frames(10)
	check(get_tree_boss() == null, "and it never returns")


func _likeness_free(skills: Array) -> Array:
	GameState.new_game()
	var setup := await _likeness_world()
	var b: Likeness = setup[2]
	GameState.data.skills = skills
	b.hp = roundi(b.max_hp * 0.5) + 2
	b.take_hit(10, Vector2.RIGHT)
	return setup


func test_likeness_fights_with_your_strongest_branch() -> void:
	GameState.new_game()
	check(Likeness.strongest_branch() == "Blade", "with an empty tree it fights with the blade")
	GameState.data.skills = ["clear_mind", "siphon", "keen_edge"]
	check(Likeness.strongest_branch() == "Arcana", "it takes the branch you put the most into")
	GameState.data.skills = ["deep_pockets", "keen_edge"]
	check(Likeness.strongest_branch() == "Blade", "and the blade on a tie")
	for t: float in [Likeness.CUT_TELL, Likeness.HEAVY_TELL, Likeness.CAST_TELL, Likeness.DASH_TELL]:
		check(t >= Enemy.MIN_TELEGRAPH, "every phase 2 tell is at least %.2f s (%.2f)" % [Enemy.MIN_TELEGRAPH, t])
	GameState.new_game()


func test_likeness_breaks_the_mirror_at_half() -> void:
	var setup := await _likeness_free([])
	var w: World = setup[0]
	var b: Likeness = setup[2]
	check(b.phase == 2 and b.state == "shatter" and b.branch == "Blade", "below half the mirror shatters (%s, %s)" % [b.state, b.branch])
	check(Music.track == "likeness", "the fight plays its own theme (%s)" % Music.track)
	var hp0 := b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(b.hp == hp0, "untouchable while the glass breaks")
	var out := await _until(func() -> bool: return b.state == "stalk", 150)
	check(out and b.is_on_floor(), "then it steps out onto the floor (%s)" % b.state)
	# Blade: two cuts and a heavy, every one told first.
	w.player.teleport(b.global_position + Vector2(-30.0, 0.0))
	var php := w.player.hp
	var seen := {}
	var told := 0
	for i in 200:
		await frames(1)
		seen[b.state] = true
		if b.telling():
			told += 1
		if b.state == "f_recover":
			break
	check(seen.has("cut_tell") and seen.has("f_cut") and seen.has("heavy_tell") and seen.has("heavy"), "with the blade it cuts twice and lunges heavy (%s)" % [seen.keys()])
	check(w.player.hp < php, "and catches you standing in reach")
	check(told >= 3 * roundi(Enemy.MIN_TELEGRAPH * 60.0), "after its tells (%d frames)" % told)
	b.set_state("heavy")
	b.stagger()
	check(b.state == "stagger", "a parried blow leaves it reeling")
	var back := await _until(func() -> bool: return b.state == "stalk", 120)
	check(back, "until it comes on again")


func test_likeness_casts_your_arcana_back_at_you() -> void:
	var setup := await _likeness_free(["clear_mind", "siphon"])
	var w: World = setup[0]
	var b: Likeness = setup[2]
	var p := w.player
	p.has_shield = true
	check(b.branch == "Arcana", "it takes up your arcana")
	await _until(func() -> bool: return b.state == "stalk", 150)
	p.teleport(Vector2(b.global_position.x - 160.0, b.global_position.y))
	p.facing = 1
	var cast := await _until(func() -> bool: return b.state == "cast_tell", 120)
	check(cast, "from a distance it gathers a bolt")
	var bolt: ShadowBolt = null
	for i in 90:
		await frames(1)
		for c in w.room.get_children():
			if c is ShadowBolt:
				bolt = c
		if bolt != null:
			break
	check(bolt != null and bolt.direction == -1, "and casts it at you")
	if bolt == null:
		return
	await _until(func() -> bool: return absf(bolt.global_position.x - p.global_position.x) < 40.0, 120)
	p.input.block_pressed = true
	p.input.block_held = true
	var held: WeakRef = weakref(bolt)
	var turned := await _until(func() -> bool: return held.get_ref() == null or (held.get_ref() as ShadowBolt).reflected, 20)
	p.input.block_pressed = false
	p.input.block_held = false
	check(turned and is_instance_valid(bolt) and bolt.reflected, "a parry turns the bolt")
	var hp0 := b.hp
	b.set_state("f_recover")
	var hurt := await _until(func() -> bool: return b.hp < hp0, 120)
	check(hurt, "back into the shadow that cast it (%d)" % (hp0 - b.hp))


func test_likeness_wanders_dashes_and_drinks() -> void:
	var setup := await _likeness_free(["deep_pockets", "gold_sense"])
	var w: World = setup[0]
	var b: Likeness = setup[2]
	var p := w.player
	check(b.branch == "Wanderer", "it takes up your wandering")
	await _until(func() -> bool: return b.state == "stalk", 150)
	p.teleport(Vector2(b.global_position.x - 110.0, b.global_position.y))
	var php := p.hp
	var dash := await _until(func() -> bool: return b.state == "dash", 120)
	check(dash, "it air-dashes at you")
	await frames(30)
	check(p.hp < php, "through you")
	await _until(func() -> bool: return b.state == "stalk", 120)
	b.hp = roundi(b.max_hp * 0.2)
	p.teleport(Vector2(clampf(b.global_position.x - 140.0, 200.0, 700.0), b.global_position.y))
	if absf(p.global_position.x - b.global_position.x) < 100.0:
		p.teleport(Vector2(b.global_position.x + 140.0, b.global_position.y))
	var drink := await _until(func() -> bool: return b.state == "drink", 60)
	check(drink, "low on health it stops to drink")
	var hp0 := b.hp
	await _until(func() -> bool: return b.state != "drink", 90)
	check(b.hp > hp0, "and the draught heals it (%d -> %d)" % [hp0, b.hp])
	b._drunk = false
	b.hp = roundi(b.max_hp * 0.2)
	b.set_state("stalk")
	await _until(func() -> bool: return b.state == "drink", 60)
	hp0 = b.hp
	b.take_hit(5, Vector2.RIGHT)
	await frames(2)
	check(b.state != "drink" and b.hp == hp0 - 5, "a blow spills the draught")


func _likeness_split() -> Array:
	var setup := await _likeness_free([])
	var b: Likeness = setup[2]
	await _until(func() -> bool: return b.state == "stalk", 150)
	b.hp = roundi(b.max_hp * 0.2) + 2
	b.take_hit(10, Vector2.RIGHT)
	return setup


func test_likeness_splits_in_two_below_a_fifth() -> void:
	var setup := await _likeness_split()
	var w: World = setup[0]
	var b: Likeness = setup[2]
	check(b.phase == 3 and b.state == "split", "below a fifth it splits (%s)" % b.state)
	var shadows: Array = w.room.get_children().filter(func(c: Node) -> bool: return c is Likeness)
	check(shadows.size() == 2, "into two shadows (%d)" % shadows.size())
	var d := b.double
	check(d != null and d.decoy and not d.is_in_group("boss") and get_tree_boss() == b, "one of them false, and the boss bar follows the real one")
	check(b.reflects() and not d.reflects(), "only the real one casts a reflection")
	check(absf(d.global_position.x - b.global_position.x) >= 40.0, "they part (%.0f apart)" % absf(d.global_position.x - b.global_position.x))
	var hp0 := b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(b.hp == hp0, "untouchable while it splits")
	var out := await _until(func() -> bool: return b.state == "stalk" and d.state == "stalk", 120)
	check(out, "then both come on (%s, %s)" % [b.state, d.state])


func test_striking_the_false_shadow_makes_it_burst() -> void:
	check(Likeness.BURST_TELL >= Enemy.MIN_TELEGRAPH, "the false one swells for at least %.2f s before it bursts" % Enemy.MIN_TELEGRAPH)
	var setup := await _likeness_split()
	var w: World = setup[0]
	var b: Likeness = setup[2]
	var d := b.double
	await _until(func() -> bool: return d.state == "stalk", 120)
	var p := w.player
	var hp0 := b.hp
	d.take_hit(10, Vector2.RIGHT)
	check(d.state == "burst_tell", "struck, the false one swells")
	check(b.hp == hp0, "and the real one loses nothing")
	p.teleport(d.global_position + Vector2(20.0, 0.0))
	b.global_position = Vector2(b.arena.end.x - 30.0 if d.global_position.x < b.axis() else b.arena.position.x + 30.0, b.global_position.y)
	b.set_state("f_recover")
	var php := p.hp
	# A weak reference: a lambda that captures a node logs an error once it is freed.
	var dref: WeakRef = weakref(d)
	var gone := await _until(func() -> bool: return dref.get_ref() == null, 60)
	check(gone, "then bursts")
	check(p.hp < php, "hurting you if you stay beside it (%d)" % (php - p.hp))
	check(b.double == null, "the real one is alone")
	await frames(roundi(Likeness.RESPLIT * 60.0) + 90)
	var again := b.double != null and is_instance_valid(b.double)
	check(again, "until it splits again")


func test_beating_the_real_shadow_ends_the_false_one() -> void:
	var setup := await _likeness_split()
	var b: Likeness = setup[2]
	var d := b.double
	await _until(func() -> bool: return b.state == "stalk", 120)
	b.hp = 1
	b.take_hit(5, Vector2.RIGHT)
	await frames(2)
	check(not is_instance_valid(d), "the false one goes with the real one")
	var gone := await _until(func() -> bool: return GameState.flag("boss:likeness"), 600)
	check(gone, "and the fight is won")


# --- The Everbloom, phase 1: the Avatar on the Throne (bible 8.9) -----------------

func _avatar_world() -> Array:
	var w := make_world({}, "evercrown/throne")
	w.player.max_hp = 9999
	w.player.hp = 9999
	w.player.has_shield = true
	await frames(3)
	var arena := _arena(w)
	w.player.teleport(cell_feet(10, 19))
	await _until(func() -> bool: return arena.fighting, 30)
	var b := get_tree_boss() as EvilAvatar
	await _until(func() -> bool: return b != null and b.state == "walk", 200)
	return [w, arena, b]


func test_the_throne_wakes_the_everblooms_avatar() -> void:
	var setup := await _avatar_world()
	var arena: BossArena = setup[1]
	var b: EvilAvatar = setup[2]
	check(arena.boss_id == "everbloom_avatar" and b != null and b.state == "walk", "walking into the throne hall wakes the avatar")
	check(b.phase == 1 and absf(b.global_position.y - b.floor_y()) < 2.0, "it comes down to duel on the floor")
	check(Music.track == "everbloom", "the fight plays the Everbloom's theme (%s)" % Music.track)


func test_everbloom_avatar_telegraphs_are_fair() -> void:
	var b := EvilAvatar.new()
	for p in [1, 2]:
		b.phase = p
		for t: float in [EvilAvatar.CLEAVE_TELL, EvilAvatar.LUNGE_TELL, EvilAvatar.PULL_TELL, EvilAvatar.RAIN_TELL]:
			check(b.tell(t) >= Enemy.MIN_TELEGRAPH, "phase %d tell %.2f s is at least %.2f s" % [p, b.tell(t), Enemy.MIN_TELEGRAPH])
	b.free()


func test_everbloom_avatar_cleaves_and_a_parry_opens_its_plate() -> void:
	var setup := await _avatar_world()
	var w: World = setup[0]
	var b: EvilAvatar = setup[2]
	w.player.teleport(Vector2(b.global_position.x - 40.0, b.floor_y()))
	b.face_player()
	b.set_state("cleave_tell")
	var hp := w.player.hp
	var tell := 0
	for i in 90:
		await frames(1)
		if b.state == "cleave_tell":
			tell += 1
		if b.state == "recover":
			break
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH, "the cleave is telegraphed (%d frames)" % tell)
	check(w.player.hp < hp, "and catches a player standing in front (%d)" % (hp - w.player.hp))
	b.facing = 1
	var hp0 := b.hp
	b.take_hit(10, Vector2.LEFT)
	check(hp0 - b.hp == 5, "its plate halves a blow to its front (%d)" % (hp0 - b.hp))
	hp0 = b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(hp0 - b.hp == 10, "but its back is bare (%d)" % (hp0 - b.hp))
	b.set_state("cleave")
	b.stagger()
	check(b.open(), "a parry leaves it reeling")
	hp0 = b.hp
	b.take_hit(10, Vector2.LEFT)
	check(hp0 - b.hp == 10, "and open to every blow (%d)" % (hp0 - b.hp))


func test_everbloom_avatar_pulls_you_in_then_bursts() -> void:
	var setup := await _avatar_world()
	var w: World = setup[0]
	var b: EvilAvatar = setup[2]
	var p := w.player
	p.teleport(Vector2(b.global_position.x - 100.0, b.floor_y()))
	await frames(5)
	b.set_state("pull_tell")
	var x0 := p.global_position.x
	var tell := 0
	while b.state == "pull_tell" and tell < 120:
		tell += 1
		await frames(1)
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH, "it raises its palm first (%d frames)" % tell)
	var hp := p.hp
	await _until(func() -> bool: return b.state != "pull", 120)
	check(p.global_position.x > x0 + 50.0, "the wrong gravity drags you toward it (%d px)" % (p.global_position.x - x0))
	await frames(2)
	check(b.state == "burst" and p.hp < hp, "and the burst catches you close (%d)" % (hp - p.hp))


func test_everbloom_avatar_rains_crystal_in_a_line() -> void:
	var setup := await _avatar_world()
	var w: World = setup[0]
	var b: EvilAvatar = setup[2]
	w.player.teleport(cell_feet(8, 19))
	await frames(3)
	b.face_player()
	b.set_state("rain_tell")
	await _until(func() -> bool: return b.state == "rain", 90)
	await frames(1)
	var spikes := w.room.get_children().filter(func(c: Node) -> bool: return c is CrystalSpike)
	check(spikes.size() >= 4, "spikes erupt in a line toward you (%d)" % spikes.size())
	check(spikes.all(func(s: CrystalSpike) -> bool: return s.global_position.x < b.global_position.x), "on your side")


func test_everbloom_avatar_swings_twice_below_half() -> void:
	var setup := await _avatar_world()
	var w: World = setup[0]
	var b: EvilAvatar = setup[2]
	w.player.teleport(Vector2(b.global_position.x - 40.0, b.floor_y()))
	b.hp = roundi(b.max_hp * 0.5) + 2
	b.facing = -1
	b.take_hit(10, Vector2.LEFT)
	check(b.phase == 2, "below half the second phase begins")
	b.face_player()
	b.set_state("cleave_tell")
	var cleaves := 0
	var was := ""
	for i in 150:
		await frames(1)
		if b.state == "cleave" and was != "cleave":
			cleaves += 1
		was = b.state
		if b.state == "recover":
			break
	check(cleaves == 2, "and its cleave comes back for a second swing (%d)" % cleaves)


func test_everbloom_avatar_defeat_shatters_it_for_good() -> void:
	var setup := await _avatar_world()
	var w: World = setup[0]
	var b: EvilAvatar = setup[2]
	var points := int(GameState.data.skill_points)
	b.hp = 1
	b.facing = -1
	b.take_hit(5, Vector2.LEFT)
	check(b.state == "dying", "the last blow ends it")
	var gone := await _until(func() -> bool: return GameState.flag("boss:everbloom_avatar"), 600)
	check(gone, "the avatar is marked beaten")
	check(int(GameState.data.skill_points) >= points + 1, "with a skill point")
	await frames(90)
	w._enter("evercrown/throne")
	await frames(10)
	check(get_tree_boss() == null, "and it never returns")


# --- The Everbloom, phase 2: the Veins (bible 8.9) -------------------------------

func _veins_world() -> Array:
	var w := make_world({}, "evercrown/veins")
	w.player.max_hp = 9999
	w.player.hp = 9999
	w.player.abilities["stillstone"] = true
	await frames(3)
	var arena := _arena(w)
	w.player.teleport(cell_feet(8, 65))
	await _until(func() -> bool: return arena.fighting, 30)
	var c := get_tree_boss() as EvilCore
	await _until(func() -> bool: return c != null and c.state == "watch", 200)
	return [w, arena, c]


func _cut_veins(c: EvilCore, n: int) -> void:
	var cut := 0
	for v in c.veins:
		if cut >= n:
			return
		if not v.is_cut:
			v.take_hit(10, Vector2.RIGHT)
			cut += 1


func test_the_veins_wake_the_core() -> void:
	var setup := await _veins_world()
	var arena: BossArena = setup[1]
	var c: EvilCore = setup[2]
	check(arena.boss_id == "everbloom_veins" and c != null and c.state == "watch", "climbing into the Veins wakes the core")
	check(c.veins.size() == 6 and c.max_hp == 6 * EvilCore.VEIN_HP and c.hp == c.max_hp, "it feeds through six veins (%d)" % c.veins.size())
	check(Music.track == "everbloom", "to the Everbloom's theme (%s)" % Music.track)
	var hp := c.hp
	c.take_hit(50, Vector2.UP)
	check(c.hp == hp, "no blade reaches the core itself")


func test_the_cores_beams_are_telegraphed_and_burn_the_line() -> void:
	var setup := await _veins_world()
	var w: World = setup[0]
	var c: EvilCore = setup[2]
	for ph in [1, 2]:
		c.phase = ph
		check(c.tell() >= Enemy.MIN_TELEGRAPH, "phase %d beam tell %.2f s is at least %.2f s" % [ph, c.tell(), Enemy.MIN_TELEGRAPH])
	c.phase = 1
	# Hold its own volleys and clear any in flight, so only this beam counts.
	c._volley = 99.0
	for b in w.room.get_children():
		if b is CoreBeam:
			b.queue_free()
	await frames(30)
	var p := w.player
	var hp := p.hp
	c._fire()
	var beam: CoreBeam = w.room.get_children().filter(func(n: Node) -> bool: return n is CoreBeam)[0]
	var tell := 0
	while is_instance_valid(beam) and not beam.firing() and p.hp == hp and tell < 120:
		tell += 1
		await frames(1)
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH, "a beam's line flickers harmlessly first (%d frames)" % tell)
	await frames(10)
	check(p.hp < hp, "then burns whoever stands in it (%d)" % (hp - p.hp))


## Pass 244: the beam's strike is heard. The core's `zap` marks the line as it
## is drawn; the lance itself sears (`core_beam`) the moment it fires, and not
## before, so the dodge has a beat to the ear as well as the eye.
func test_a_cores_beam_sears_as_it_fires() -> void:
	var setup := await _veins_world()
	var w: World = setup[0]
	var c: EvilCore = setup[2]
	c._volley = 99.0
	for b in w.room.get_children():
		if b is CoreBeam:
			b.queue_free()
	await frames(30)
	c._fire()
	check("zap" in Sfx.recent, "the line is marked with the core's zap")
	Sfx.recent.clear()
	var beam: CoreBeam = w.room.get_children().filter(func(n: Node) -> bool: return n is CoreBeam and not n.is_queued_for_deletion())[0]
	var early := false
	while is_instance_valid(beam) and not beam.firing():
		early = early or CoreBeam.FIRE_SOUND in Sfx.recent
		await frames(1)
	check(not early, "the line flickers in silence after the zap")
	await frames(1)
	check(CoreBeam.FIRE_SOUND in Sfx.recent, "and the lance sears as it fires (%s)" % [Sfx.recent])


func test_the_stillstone_holds_the_cores_beams() -> void:
	var setup := await _veins_world()
	var w: World = setup[0]
	var c: EvilCore = setup[2]
	var p := w.player
	c._fire()
	TimeStop.start()
	var hp := p.hp
	await frames(90)
	var beams := w.room.get_children().filter(func(n: Node) -> bool: return n is CoreBeam)
	check(beams.size() == 1 and not beams[0].firing(), "the beam's line hangs, unfired, while time holds")
	check(p.hp == hp, "and hurts no one")
	TimeStop.reset()


func test_cutting_the_veins_starves_the_core() -> void:
	var setup := await _veins_world()
	var w: World = setup[0]
	var c: EvilCore = setup[2]
	var points := int(GameState.data.skill_points)
	_cut_veins(c, 3)
	check(c.hp == 3 * EvilCore.VEIN_HP and c.phase == 2, "each cut vein drains it; at half it grows desperate (%d, phase %d)" % [c.hp, c.phase])
	c._volleys = 1
	for b in w.room.get_children():
		if b is CoreBeam:
			b.queue_free()
	await frames(1)
	c._fire()
	check(w.room.get_children().filter(func(n: Node) -> bool: return n is CoreBeam and not n.is_queued_for_deletion()).size() == 2, "and fans its beams in pairs")
	_cut_veins(c, 3)
	check(c.state == "dying", "the last vein cut, its light gutters out")
	var gone := await _until(func() -> bool: return GameState.flag("boss:everbloom_veins"), 600)
	check(gone, "the Veins are marked beaten")
	check(int(GameState.data.skill_points) >= points + 1, "with a skill point")
	await frames(90)
	w._enter("evercrown/veins")
	await frames(10)
	check(get_tree_boss() == null, "the core never fights here again")
	check(w.room.get_children().filter(func(n: Node) -> bool: return n is LightVein).all(func(v: LightVein) -> bool: return v.is_cut), "and its veins stay dark")


func test_a_pogo_bounces_off_a_vein() -> void:
	var setup := await _veins_world()
	var w: World = setup[0]
	var c: EvilCore = setup[2]
	var v: LightVein = c.veins[0]
	var p := w.player
	p.abilities["delvers_pick"] = true
	p.teleport(v.global_position + Vector2(0, -40))
	var bounced := false
	for i in 60:
		if p.velocity.y > 0.0 and not p.is_attacking:
			p.input.down = true
			p.input.attack_pressed = true
		await frames(1)
		if p.velocity.y < -250.0:
			bounced = true
			break
	p.input.down = false
	check(bounced and v.is_cut, "a down-strike cuts a vein and bounces off it")


func _heart_world() -> Array:
	var w := make_world({}, "evercrown/heart")
	w.player.max_hp = 9999
	w.player.hp = 9999
	w.player.abilities["stillstone"] = true
	GameState.data.equipment["blade"] = "severance"
	await frames(3)
	var arena := _arena(w)
	w.player.teleport(cell_feet(14, 20))
	await _until(func() -> bool: return arena.fighting, 30)
	var h := get_tree_boss() as EvilHeart
	await _until(func() -> bool: return h != null and h.state == "float", 200)
	return [w, arena, h]


## Clears the heart's beams, seeds and spikes so a test sees only what it makes.
func _clear_heart_hazards(w: World) -> void:
	for n in w.room.get_children():
		if n is CoreBeam or n is MeteorSeed or n is CrystalSpike:
			n.queue_free()


## Holds the heart down as a root would, and swings the blade at it.
func _bind(h: EvilHeart) -> void:
	h._root = 99.0
	h._attack = 99.0
	h._on_root_struck()


func _slash(w: World, h: EvilHeart, damage: int) -> void:
	w.player._attack_timer = 0.2
	h.take_hit(damage, Vector2.RIGHT)
	w.player._attack_timer = 0.0


func test_the_heart_wakes_above_any_blade() -> void:
	var setup := await _heart_world()
	var arena: BossArena = setup[1]
	var h: EvilHeart = setup[2]
	check(arena.boss_id == "everbloom" and h != null and h.state == "float", "the heart of the Everbloom wakes in its chamber")
	check(h.lights.size() == 3 and h.lights_freed() == 0, "three springs' stolen light are caught in its vault")
	check(Music.track == "everbloom", "to the Everbloom's theme (%s)" % Music.track)
	check(h.floor_y() - h.global_position.y > 10 * Room.TILE, "it hangs far above the floor (%.0f px)" % (h.floor_y() - h.global_position.y))
	var hp := h.hp
	_slash(setup[0], h, 50)
	check(h.hp == hp, "while it floats free, even the Severance glances off")


func test_the_trees_roots_bind_the_heart_after_a_tell() -> void:
	var setup := await _heart_world()
	var w: World = setup[0]
	var h: EvilHeart = setup[2]
	check(TreeRoot.TELL >= Enemy.MIN_TELEGRAPH, "a root's glow lasts at least the minimum tell")
	h._attack = 99.0
	h._root = 0.0
	await frames(2)
	check(h.state == "snared", "the floor under it glows: the Tree is coming")
	var frames_held := 0
	while h.state == "snared" and frames_held < 120:
		frames_held += 1
		await frames(1)
	check(frames_held / 60.0 >= TreeRoot.TELL - 0.05 and h.bound(), "a root whips up and binds it (%d frames)" % frames_held)
	await frames(30)
	check(absf(h.global_position.y - (h.floor_y() - EvilHeart.SIZE.y * 0.5)) < 4.0, "and drags it down to the floor")
	await _until(func() -> bool: return h.state == "float", 400)
	check(h.state == "float" and h.binds == 1, "then lets it rise again")


func test_only_the_severance_cuts_the_bound_heart() -> void:
	var setup := await _heart_world()
	var w: World = setup[0]
	var h: EvilHeart = setup[2]
	_bind(h)
	await frames(2)
	var hp := h.hp
	GameState.data.equipment["blade"] = "long_sword"
	_slash(w, h, 20)
	check(h.hp == hp, "another blade glances off it, even held down")
	GameState.data.equipment["blade"] = "severance"
	h.take_hit(20, Vector2.RIGHT)
	check(h.hp == hp, "and so does magic")
	_slash(w, h, 20)
	check(h.hp == hp - 20, "the Severance cuts it (%d)" % (hp - h.hp))


func test_each_third_cut_frees_a_springs_light() -> void:
	var setup := await _heart_world()
	var w: World = setup[0]
	var h: EvilHeart = setup[2]
	var p := w.player
	p.max_hp = 200
	p.hp = 50
	_bind(h)
	await frames(2)
	_slash(w, h, h.hp - int(h.max_hp * 0.66) + 1)
	check(h.phase == 2 and h.lights_freed() == 1, "a third gone frees the first light (phase %d, %d lit)" % [h.phase, h.lights_freed()])
	check(p.hp == 50 + roundi(200 * EvilHeart.LIGHT_HEAL), "and its light heals you (%d)" % p.hp)
	_slash(w, h, h.hp - int(h.max_hp * 0.33) + 1)
	check(h.phase == 3 and h.lights_freed() == 2, "two thirds gone frees the second")
	check(EvilHeart.ROOT_EVERY[2] < EvilHeart.ROOT_EVERY[0], "and the Tree's roots come quicker")


func test_the_hearts_attacks_are_telegraphed() -> void:
	var setup := await _heart_world()
	var w: World = setup[0]
	var h: EvilHeart = setup[2]
	for ph in [1, 2, 3]:
		h.phase = ph
		check(h.tell() >= Enemy.MIN_TELEGRAPH, "phase %d tell %.2f s is at least the minimum" % [ph, h.tell()])
	check(MeteorSeed.TELL >= Enemy.MIN_TELEGRAPH and EvilHeart.BURST_TELL >= Enemy.MIN_TELEGRAPH, "its seeds and its burst warn first")
	h.phase = 2
	h._attack = 99.0
	h._root = 99.0
	_clear_heart_hazards(w)
	await frames(2)
	var p := w.player
	h.global_position.x = p.global_position.x + 60.0
	var hp := p.hp
	h.set_state("gather")
	var held := 0
	while h.state == "gather" and held < 120:
		held += 1
		await frames(1)
	check(held / 60.0 >= Enemy.MIN_TELEGRAPH and p.hp == hp, "crystal gathers under it before a wave (%d frames)" % held)
	await frames(40)
	check(p.hp < hp, "then spikes run out along the floor (%d)" % (hp - p.hp))
	# The seeds swell around you before they burst.
	_clear_heart_hazards(w)
	await frames(60)
	hp = p.hp
	h._seeds()
	var seeds := w.room.get_children().filter(func(n: Node) -> bool: return n is MeteorSeed)
	check(seeds.size() == 3, "it sows three seeds around you")
	await frames(30)
	check(p.hp == hp, "which only swell at first")
	await frames(30)
	check(p.hp < hp, "then burst")


func test_the_heart_bursts_as_the_root_lets_go_at_the_end() -> void:
	var setup := await _heart_world()
	var w: World = setup[0]
	var h: EvilHeart = setup[2]
	var p := w.player
	h.phase = 3
	_bind(h)
	await frames(30)
	p.teleport(Vector2(h.global_position.x + 30.0, h.floor_y()))
	var hp := p.hp
	await _until(func() -> bool: return h.bursting(), 200)
	check(h.bursting() and p.hp == hp, "it flashes before it bursts")
	await _until(func() -> bool: return h.state == "rise", 60)
	check(p.hp < hp, "then bursts as the root lets go (%d)" % (hp - p.hp))


func test_the_stillstone_holds_the_heart_and_its_roots() -> void:
	var setup := await _heart_world()
	var w: World = setup[0]
	var h: EvilHeart = setup[2]
	h._attack = 99.0
	h._root = 0.0
	await frames(2)
	TimeStop.start()
	await frames(90)
	var roots := w.room.get_children().filter(func(n: Node) -> bool: return n is TreeRoot)
	check(roots.size() == 1 and roots[0].telling() and h.state == "snared", "time holds the root and the heart alike")
	TimeStop.reset()


func test_the_heart_of_the_meteor_dies_for_good() -> void:
	var setup := await _heart_world()
	var w: World = setup[0]
	var h: EvilHeart = setup[2]
	var points := int(GameState.data.skill_points)
	_bind(h)
	await frames(2)
	_slash(w, h, h.hp)
	check(h.state == "dying" and h.lights_freed() == 3, "its last life cut, every light goes home")
	var gone := await _until(func() -> bool: return GameState.flag("boss:everbloom"), 600)
	check(gone, "the Everbloom is beaten")
	check(int(GameState.data.skill_points) >= points + 1, "with a skill point")
	var started := [false]
	var on_end := func() -> void: started[0] = true
	GameState.ending_started.connect(on_end)
	var ended := await _until(func() -> bool: return started[0], int(BossArena.ENDING_DELAY * 60) + 30)
	GameState.ending_started.disconnect(on_end)
	check(ended and GameState.flag("cleared") and int(GameState.data.clears) == 1, "and once its banner has shown, the ending begins and the save is marked cleared")
	w._enter("evercrown/heart")
	await frames(10)
	check(get_tree_boss() == null, "and its heart never fights again")



## Pass 247: the four seconds between the Everbloom's fall and the ending wait
## while the game is paused, and a world torn down in them never ends the game.
func test_the_ending_waits_out_a_pause_and_dies_with_its_world() -> void:
	var setup := await _heart_world()
	var w: World = setup[0]
	var h: EvilHeart = setup[2]
	_bind(h)
	await frames(2)
	_slash(w, h, h.hp)
	check(await _until(func() -> bool: return GameState.flag("boss:everbloom"), 600), "the Everbloom is beaten")
	var started := [false]
	var on_end := func() -> void: started[0] = true
	GameState.ending_started.connect(on_end)
	var tree := runner.get_tree()
	tree.paused = true
	await frames(int(BossArena.ENDING_DELAY * 60) + 60)
	check(not started[0] and not GameState.flag("cleared"), "paused, the ending waits")
	tree.paused = false
	var ended := await _until(func() -> bool: return started[0], int(BossArena.ENDING_DELAY * 60) + 30)
	check(ended and int(GameState.data.clears) == 1, "and comes once play goes on")
	# Again, but the world goes before the wait is out.
	w.queue_free()
	await frames(2)
	GameState.new_game()
	started[0] = false
	setup = await _heart_world()
	w = setup[0]
	h = setup[2]
	_bind(h)
	await frames(2)
	_slash(w, h, h.hp)
	check(await _until(func() -> bool: return GameState.flag("boss:everbloom"), 600), "beaten again")
	w.queue_free()
	await frames(int(BossArena.ENDING_DELAY * 60) + 60)
	GameState.ending_started.disconnect(on_end)
	check(not started[0] and not GameState.flag("cleared") and int(GameState.data.get("clears", 0)) == 0, "a world gone before the ending never ends the game")


# --- The Drowned Warden (bible 8.10) ----------------------------------------------

func _warden_world() -> Array:
	var w := make_world({}, "sunken/wellspring")
	w.player.max_hp = 9999
	w.player.hp = 9999
	w.player.has_shield = true
	for a: String in w.player.abilities:
		w.player.abilities[a] = true
	await frames(3)
	var arena := _arena(w)
	w.player.teleport(cell_feet(6, 14))
	await _until(func() -> bool: return arena.fighting, 30)
	var b := get_tree_boss() as DrownedWarden
	await _until(func() -> bool: return b != null and b.state == "wade", 200)
	return [w, arena, b]


func test_the_wellspring_wakes_the_drowned_warden() -> void:
	var setup := await _warden_world()
	var arena: BossArena = setup[1]
	var b: DrownedWarden = setup[2]
	check(arena.boss_id == "drowned_warden" and b != null and b.state == "wade", "walking into the Wellspring raises the Warden")
	check_near(b.surface_y, 20.0 * Room.TILE, 0.5, "it knows where the water's surface is")
	check(absf(b.global_position.y - (b.surface_y + DrownedWarden.WADE_DEPTH)) < 2.0, "and wades waist-deep in it")
	check(Music.track == "warden", "the fight plays the Warden's theme (%s)" % Music.track)


func test_drowned_warden_telegraphs_are_fair() -> void:
	var b := DrownedWarden.new()
	for p in [1, 2, 3]:
		b.phase = p
		for t: float in [DrownedWarden.THRUST_TELL, DrownedWarden.WAVE_TELL, DrownedWarden.GEYSER_TELL, DrownedWarden.UNDERTOW_TELL, DrownedWarden.SLAM_TELL]:
			check(b.tell(t) >= Enemy.MIN_TELEGRAPH, "phase %d tell %.2f s is at least %.2f s" % [p, b.tell(t), Enemy.MIN_TELEGRAPH])
	b.free()


func test_drowned_warden_thrusts_along_its_aim_and_a_parry_opens_it() -> void:
	var setup := await _warden_world()
	var w: World = setup[0]
	var b: DrownedWarden = setup[2]
	var p := w.player
	b.global_position.x = 30 * Room.TILE
	p.teleport(cell_feet(37, 19))
	await frames(4)
	b.set_state("thrust_tell")
	var hp := p.hp
	var tell := 0
	for i in 90:
		await frames(1)
		if b.state == "thrust_tell":
			tell += 1
		if b.state == "recover":
			break
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH, "the thrust is telegraphed (%d frames)" % tell)
	check(p.hp < hp, "and the trident reaches a player on the island (%d)" % (hp - p.hp))
	b.facing = 1
	var hp0 := b.hp
	b.take_hit(10, Vector2.LEFT)
	check(hp0 - b.hp == 5, "its stone turns half a blow to the front (%d)" % (hp0 - b.hp))
	hp0 = b.hp
	b.take_hit(10, Vector2.DOWN)
	check(hp0 - b.hp == 10, "but not one from above (%d)" % (hp0 - b.hp))
	b.set_state("thrust")
	b.stagger()
	hp0 = b.hp
	b.take_hit(10, Vector2.LEFT)
	check(b.state == "staggered" and hp0 - b.hp == 10, "a parry leaves it reeling and open (%d)" % (hp0 - b.hp))


func test_a_tidal_wave_catches_you_at_the_surface_but_not_deep_down() -> void:
	var setup := await _warden_world()
	var w: World = setup[0]
	var b: DrownedWarden = setup[2]
	var p := w.player
	b.set_state("recover")
	b.global_position.x = 44 * Room.TILE
	# Deep under the surface: the wave passes over.
	p.teleport(Vector2(26 * Room.TILE, b.surface_y + 110.0))
	var wave := TidalWave.new()
	wave.lane = Vector2(0, 60 * Room.TILE)
	w.room.add_child(wave)
	wave.global_position = Vector2(16 * Room.TILE, b.surface_y)
	var hp := p.hp
	for i in 60:
		p.input.down = true
		await frames(1)
	p.input.down = false
	check(wave.global_position.x > 30 * Room.TILE and p.hp == hp, "diving deep, the wave runs over you (%d)" % (hp - p.hp))
	# Standing on an island level with the surface, it knocks you down.
	p.teleport(cell_feet(37, 19))
	var w2 := TidalWave.new()
	w2.lane = Vector2(0, 60 * Room.TILE)
	w.room.add_child(w2)
	w2.global_position = Vector2(30 * Room.TILE, b.surface_y)
	hp = p.hp
	await frames(40)
	check(p.hp < hp, "but it catches a player standing in its path (%d)" % (hp - p.hp))


func test_drowned_warden_waves_from_its_tell() -> void:
	var setup := await _warden_world()
	var w: World = setup[0]
	var b: DrownedWarden = setup[2]
	b.set_state("wave_tell")
	var tell := 0
	while b.state == "wave_tell" and tell < 120:
		tell += 1
		await frames(1)
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH, "it raises its arms first (%d frames)" % tell)
	var waves := w.room.get_children().filter(func(c: Node) -> bool: return c is TidalWave)
	check(waves.size() == 1, "then one wave runs (%d)" % waves.size())
	b.phase = 3
	b.set_state("wave_tell")
	await _until(func() -> bool: return b.state == "wade", 240)
	await frames(1)
	var later := 0
	for c in w.room.get_children():
		if c is TidalWave:
			later += 1
	check(b.state == "wade", "in the third phase the waves keep coming (%d running)" % later)


func test_drowned_warden_geysers_up_under_you_then_hangs_open() -> void:
	var setup := await _warden_world()
	var w: World = setup[0]
	var b: DrownedWarden = setup[2]
	var p := w.player
	b.phase = 2
	b.global_position.x = 40 * Room.TILE
	p.teleport(Vector2(28 * Room.TILE, b.surface_y + 24.0))
	await frames(4)
	b.set_state("dive")
	var hp0 := b.hp
	await _until(func() -> bool: return b.state == "stalk", 60)
	b.take_hit(10, Vector2.DOWN)
	check(b.hp == hp0 and b.collision_layer == 0, "under the water it can't be touched")
	await _until(func() -> bool: return b.state == "geyser_tell", 120)
	check(absf(b.global_position.x - p.global_position.x) < 12.0, "it stalks you to your spot (%.0f px off)" % absf(b.global_position.x - p.global_position.x))
	var hp := p.hp
	var tell := 0
	while b.state == "geyser_tell" and tell < 120:
		tell += 1
		await frames(1)
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH, "the water boils first (%d frames)" % tell)
	await _until(func() -> bool: return b.state == "exposed", 60)
	check(p.hp < hp, "then the geyser throws you (%d)" % (hp - p.hp))
	b.facing = 1
	hp0 = b.hp
	b.take_hit(10, Vector2.LEFT)
	check(hp0 - b.hp == 10, "streaming, it hangs open to every blow (%d)" % (hp0 - b.hp))


func test_drowned_warden_undertow_drags_you_in_then_slams() -> void:
	var setup := await _warden_world()
	var w: World = setup[0]
	var b: DrownedWarden = setup[2]
	var p := w.player
	b.phase = 3
	b.global_position.x = 30 * Room.TILE
	p.teleport(cell_feet(38, 19))
	await frames(4)
	var x0 := p.global_position.x
	b.set_state("undertow_tell")
	var tell := 0
	while b.state == "undertow_tell" and tell < 120:
		tell += 1
		await frames(1)
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH, "its chest opens on the light first (%d frames)" % tell)
	await _until(func() -> bool: return b.state == "slam_tell", 120)
	check(p.global_position.x < x0 - 40.0, "the current drags you toward it (%d px)" % (x0 - p.global_position.x))
	var hp := p.hp
	await _until(func() -> bool: return b.state == "recover", 60)
	check(p.hp < hp, "and the slam lands around it (%d)" % (hp - p.hp))


func test_drowned_warden_roars_into_each_phase() -> void:
	var setup := await _warden_world()
	var b: DrownedWarden = setup[2]
	b.take_hit(int(b.max_hp * 0.36), Vector2.DOWN)
	check(b.phase == 2 and b.state == "roar", "at two-thirds of its life the second phase begins")
	var hp0 := b.hp
	b.take_hit(10, Vector2.DOWN)
	check(b.hp == hp0, "and it shrugs off blows while it roars")
	b.set_state("wade")
	b.take_hit(int(b.max_hp * 0.34), Vector2.DOWN)
	check(b.phase == 3, "at a third, the third")


func test_the_drowned_warden_gives_up_the_elven_plate() -> void:
	var setup := await _warden_world()
	var w: World = setup[0]
	var arena: BossArena = setup[1]
	var b: DrownedWarden = setup[2]
	var points := int(GameState.data.skill_points)
	b.phase = 3
	b.hp = 1
	b.set_state("wade")
	b.take_hit(5, Vector2.DOWN)
	await _until(func() -> bool: return GameState.flag("boss:drowned_warden"), 480)
	check(GameState.flag("boss:drowned_warden"), "the Warden falls")
	check(GameState.data.equipment.armor == "elven_plate" and absf(w.player.defense - 0.6) < 0.001, "and its Elven Plate goes straight on (%s, %.2f)" % [GameState.data.equipment.armor, w.player.defense])
	check(int(GameState.data.skill_points) >= points + 1, "with a skill point")
	await _until(func() -> bool: return not arena.fighting, 400)
	check(not arena.fighting, "and the way back opens")
	check(GameState.data.gear.has("elven_plate"), "and it is kept with your gear (pass 186)")


func test_every_boss_marks_its_phases_on_the_health_bar() -> void:
	# GameHud draws a tick per entry of PHASES; a boss without it broke the bar.
	var missing: Array[String] = []
	for f: String in DirAccess.get_files_at("res://scripts/bosses"):
		if not f.ends_with(".gd"):
			continue
		var consts := (load("res://scripts/bosses/" + f) as Script).get_script_constant_map()
		if consts.has("DISPLAY_NAME") and not consts.has("PHASES"):
			missing.append(f)
	check(missing.is_empty(), "every boss with a health bar lists its phases: missing %s" % [missing])


func test_a_phase_break_stings_and_lifts_the_music() -> void:
	var setup := await _roc_world()
	var arena: BossArena = setup[1]
	var b: Skyrend = setup[2]
	var breaks: Array[int] = []
	arena.phase_broken.connect(func(level: int) -> void: breaks.append(level))
	check(Music.track == "skyrend" and Music.intensity == 0, "the fight opens on its theme as written")
	b.hp = roundi(b.max_hp * 0.45)
	await frames(2)
	check(breaks == [1] and arena.phases_passed == 1, "crossing the first mark is a phase break (%s)" % [breaks])
	check(Music.intensity == 1, "and the music rises a step")
	check_near(Feel.last_hitstop, BossArena.PHASE_HITSTOP, 0.001, "the world holds 200 ms on the break")
	await frames(int(Music.PHASE_SHIFT_TIME * 60.0) + 5)
	var pitch: float = Music._players[Music._active].pitch_scale
	check_near(pitch, Music.PHASE_STEP, 0.001, "a semitone up, faster with it (%.4f)" % pitch)
	await frames(10)
	check(breaks == [1], "a break sounds once")
	b.hp = roundi(b.max_hp * 0.2)
	await frames(2)
	check(breaks == [1, 2] and Music.intensity == 2, "the second mark lifts it again (%s)" % [breaks])
	check_near(Music.pitch_for(2), pow(2.0, 2.0 / 12.0), 0.0005, "two semitones in all")
	Music.play("title", 0.01)
	await frames(2)
	check(Music.intensity == 0 and Music._players[Music._active].pitch_scale == 1.0, "a new track starts as written")


# --- The Clockwork Alpha (pass 169), Vorrhallow's mini-boss --------------------------

const ALPHA_ROOM := "vorrhallow/alpha_den"


## The Alpha dropped into its den without the arena, awake.
func _alpha_world(cell := Vector2i(30, 20)) -> Array:
	var w := make_world({}, ALPHA_ROOM, cell_feet(20, 20))
	GameState.set_flag("boss:clockwork_alpha")  # keep the arena from starting its own fight
	var a := ClockworkAlpha.new()
	a.arena = Rect2(16, 64, 608, 272)
	a.position = cell_feet(cell.x, cell.y)
	w.room.add_child(a)
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(2)
	a.set_state("trot")
	return [w, a]


func test_the_alpha_waits_in_a_den_under_the_kings_kennels() -> void:
	var kennels := Room.from_file(World.room_path("vorrhallow/kings_kennels"))
	check(kennels.doors.has(3) and String(kennels.doors[3].target) == ALPHA_ROOM, "a shaft in the kennels' floor drops to the den")
	kennels.free()
	var w := make_world({}, ALPHA_ROOM, cell_feet(8, 3))
	await frames(3)
	var arena := _arena(w)
	check(arena != null and arena.boss_id == "clockwork_alpha", "the den is a boss arena")
	check(BossArena.BOSSES.clockwork_alpha.music == "miniboss" and not BossArena.BOSSES.clockwork_alpha.has("skill_points"), "a mini-boss: its own theme, and no skill point")
	w.player.teleport(cell_feet(8, 20))
	var woke := await _until(func() -> bool: return arena.fighting, 30)
	var a := get_tree_boss() as ClockworkAlpha
	check(woke and a != null, "dropping into the den wakes the Alpha")
	check(a != null and a.global_position.x > w.player.global_position.x + 300.0, "it waits at the far end of the den")
	check(a != null and a.state == "intro", "with its name card and a ratchet")


func test_the_alphas_tells_are_fair() -> void:
	var a := ClockworkAlpha.new()
	for ph in [1, 2]:
		a.phase = ph
		for t: float in [ClockworkAlpha.POUNCE_TELL, ClockworkAlpha.CHARGE_TELL, ClockworkAlpha.HOWL_TELL]:
			check(a.tell(t) >= Enemy.MIN_TELEGRAPH, "phase %d tell %.2f s is at least %.2f s" % [ph, a.tell(t), Enemy.MIN_TELEGRAPH])
	a.free()


func test_the_alphas_plating_turns_blows_until_it_opens() -> void:
	var r := await _alpha_world()
	var a: ClockworkAlpha = r[1]
	var hp0 := a.hp
	a.take_hit(10, Vector2.RIGHT)
	check(a.hp == hp0 - 5 and not a.punishable(), "its plating halves a blow (%d)" % (hp0 - a.hp))
	check(a.state == "trot", "blows don't interrupt it")
	a.stagger()
	check(a.flipped() and a.punishable(), "a parried bite throws it on its back")
	hp0 = a.hp
	a.take_hit(10, Vector2.RIGHT)
	check(a.hp == hp0 - 10, "on its back a blow lands in full")
	await frames(int(ClockworkAlpha.FLIPPED * 60.0) + 10)
	check(not a.flipped() and a.state == "trot", "and it rights itself")


func test_the_stillstone_stops_the_alpha_dead() -> void:
	var r := await _alpha_world()
	var w: World = r[0]
	var a: ClockworkAlpha = r[1]
	w.player.teleport(cell_feet(24, 20))
	a.facing = -1
	a.set_state("charge")
	await frames(5)
	var x0 := a.global_position.x
	TimeStop.start()
	await frames(20)
	check(absf(a.global_position.x - x0) < 12.0 and a.stopped(), "mid-charge, the glass stops it where it runs (%.0f px)" % absf(a.global_position.x - x0))
	check(a.punishable(), "stopped, it is open")
	var hp0 := a.hp
	a.take_hit(10, Vector2.RIGHT)
	check(a.hp == hp0 - 10, "and a blow lands in full")
	TimeStop.reset()
	await frames(5)
	check(not a.stopped() and a.global_position.x < x0 - 4.0, "time runs on and so does it")


func test_the_alpha_charges_into_the_wall_and_jams() -> void:
	var r := await _alpha_world(Vector2i(20, 20))
	var w: World = r[0]
	var a: ClockworkAlpha = r[1]
	w.player.teleport(cell_feet(5, 13))
	a.facing = 1
	a.set_state("charge_tell")
	var tell_frames := [0]
	var jammed := await _until(func() -> bool:
		if a.state == "charge_tell":
			tell_frames[0] += 1
		return a.jammed(), 240)
	check(tell_frames[0] / 60.0 >= Enemy.MIN_TELEGRAPH, "its key screams for at least %.2f s first (%d frames)" % [Enemy.MIN_TELEGRAPH, tell_frames[0]])
	check(jammed and a.global_position.x > 34 * Room.TILE, "it runs into the far wall and its spring jams (x %.0f)" % a.global_position.x)
	check(a.punishable(), "jammed, it is open")


func test_the_alpha_pounces_on_the_player() -> void:
	var r := await _alpha_world(Vector2i(26, 20))
	var w: World = r[0]
	var a: ClockworkAlpha = r[1]
	w.player.teleport(cell_feet(20, 20))
	a.facing = -1
	a.set_state("pounce_tell")
	var hp := w.player.hp
	var bit := await _until(func() -> bool: return w.player.hp < hp, 120)
	check(bit, "it leaps onto a player standing still and bites")


func test_the_alpha_winds_pups_in_its_second_phase() -> void:
	var r := await _alpha_world()
	var w: World = r[0]
	var a: ClockworkAlpha = r[1]
	w.player.teleport(cell_feet(20, 20))
	a.stagger()
	a.take_hit(int(ClockworkAlpha.MAX_HP * 0.6), Vector2.RIGHT)
	check(a.phase == 2, "below half it turns to its second phase")
	for i in 3:
		a.set_state("howl_tell")
		await _until(func() -> bool: return a.state != "howl_tell", 120)
		await frames(2)
	var pups := w.room.get_children().filter(func(c: Node) -> bool: return c is ClockworkHound and not c.dead)
	check(pups.size() == ClockworkAlpha.MAX_PUPS, "its howls wind brass pups out of the grates, never more than %d (%d)" % [ClockworkAlpha.MAX_PUPS, pups.size()])
	a.die()
	await frames(2)
	pups = w.room.get_children().filter(func(c: Node) -> bool: return c is ClockworkHound and not c.dead)
	check(pups.is_empty(), "and they run down with it")


func test_the_alpha_gives_a_life_fruit() -> void:
	var w := make_world({}, ALPHA_ROOM, cell_feet(8, 3))
	var p := w.player
	await frames(3)
	var arena := _arena(w)
	p.teleport(cell_feet(8, 20))
	await _until(func() -> bool: return arena.fighting, 30)
	var a := get_tree_boss() as ClockworkAlpha
	await _until(func() -> bool: return a.state != "intro", 180)
	var hp0 := int(GameState.data.max_hp)
	var points := int(GameState.data.skill_points)
	var rank := int(GameState.data.rank)
	a.hp = 1
	a.stagger()
	a.take_hit(8, Vector2.RIGHT)
	check(a.state == "dying", "the last blow runs it down")
	var gone := await _until(func() -> bool: return GameState.flag("boss:clockwork_alpha"), 600)
	check(gone, "the Alpha is marked beaten")
	check(int(GameState.data.max_hp) == hp0 + GameState.LIFE_FRUIT_HP, "its Life Fruit grows your health (%d -> %d)" % [hp0, int(GameState.data.max_hp)])
	var ranks := int(GameState.data.rank) - rank
	check(int(GameState.data.skill_points) == points + ranks, "a mini-boss gives no skill point beyond its rank-ups (%d)" % ranks)


const CAPTAIN_ROOM := "boughs/thorn_yard"


## The Captain dropped into his yard without the arena, awake.
func _captain_world(cell := Vector2i(30, 19)) -> Array:
	var w := make_world({}, CAPTAIN_ROOM, cell_feet(10, 19))
	GameState.set_flag("boss:bark_captain")  # keep the arena from starting its own fight
	var c := BarkCaptain.new()
	c.arena = Rect2(16, 64, 608, 256)
	c.position = cell_feet(cell.x, cell.y)
	w.room.add_child(c)
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(2)
	c.set_state("walk")
	return [w, c]


func test_the_captain_keeps_the_thorn_yard_east_of_sylvarre() -> void:
	var town := Room.from_file(World.room_path("boughs/sylvarre"))
	check(town.doors.has(3) and String(town.doors[3].target) == CAPTAIN_ROOM, "Sylvarre's east gate opens on the Thorn Yard")
	town.free()
	var w := make_world({}, CAPTAIN_ROOM, cell_feet(2, 19))
	await frames(3)
	var arena := _arena(w)
	check(arena != null and arena.boss_id == "bark_captain", "the yard is a boss arena")
	check(BossArena.BOSSES.bark_captain.music == "miniboss" and not BossArena.BOSSES.bark_captain.has("skill_points"), "a mini-boss: its own theme, and no skill point")
	w.player.teleport(cell_feet(8, 19))
	var woke := await _until(func() -> bool: return arena.fighting, 30)
	var c := get_tree_boss() as BarkCaptain
	check(woke and c != null, "walking into the yard wakes the Captain")
	check(c != null and c.global_position.x > w.player.global_position.x + 300.0, "he keeps the far end")
	check(c != null and c.state == "intro", "with his name card")


func test_the_captains_tells_are_fair() -> void:
	var c := BarkCaptain.new()
	for ph in [1, 2]:
		c.phase = ph
		for t: float in [BarkCaptain.THRUST_TELL, BarkCaptain.VAULT_TELL]:
			check(c.tell(t) >= Enemy.MIN_TELEGRAPH, "phase %d tell %.2f s is at least %.2f s" % [ph, c.tell(t), Enemy.MIN_TELEGRAPH])
	c.free()


func test_the_captains_bark_chips_away_and_grows_back() -> void:
	var r := await _captain_world()
	var c: BarkCaptain = r[1]
	var hp0 := c.hp
	c.take_hit(12, Vector2.RIGHT)
	check(c.hp == hp0 - 3 and c.bark == BarkCaptain.BARK - 1, "a blow on the bark chips a plate and a quarter lands (%d)" % (hp0 - c.hp))
	for i in BarkCaptain.BARK - 1:
		c.take_hit(12, Vector2.RIGHT)
	check(c.bark == 0, "five blows strip him to the heartwood")
	hp0 = c.hp
	c.take_hit(12, Vector2.RIGHT)
	check(c.hp == hp0 - 12, "bare, he takes blows in full")
	c.set_state("rooted")
	await frames(int(BarkCaptain.ROOTED * 60.0) + 5)
	check(c.bark == 1 and c.state != "rooted", "pulling free of a root grows one plate back")


func test_the_captains_thrust_roots_into_a_bough_and_opens_him() -> void:
	var r := await _captain_world(Vector2i(26, 19))
	var w: World = r[0]
	var c: BarkCaptain = r[1]
	w.player.teleport(cell_feet(21, 19))
	var hp := w.player.hp
	var tell_frames := [0]
	var rooted := await _until(func() -> bool:
		if c.state == "thrust_tell":
			tell_frames[0] += 1
		return c.state == "rooted", 240)
	check(tell_frames[0] / 60.0 >= Enemy.MIN_TELEGRAPH, "he braces for at least %.2f s first (%d frames)" % [Enemy.MIN_TELEGRAPH, tell_frames[0]])
	check(rooted and w.player.hp < hp, "the lance reaches a player five tiles off")
	await frames(2)
	check(c.bough_solid() and c.punishable(), "rooted, the lance is a bough and he is open")
	var hp0 := c.hp
	var bark := c.bark
	c.take_hit(12, Vector2.RIGHT)
	check(c.hp == hp0 - 12 and c.bark == bark, "a blow while he roots lands in full and chips nothing")


## Pass 176: the rooted lance is footing (bible 8, the Captain; 6.6 pogo). You
## land and stand on it, Down + Jump drops through it, the Delver's Pick bounces off
## it, and when he pulls it free coyote time still lets you jump, and you come
## down on the floor, never caught inside it.
func test_the_captains_bough_holds_your_weight_until_he_pulls_free() -> void:
	var r := await _captain_world(Vector2i(26, 19))
	var w: World = r[0]
	var c: BarkCaptain = r[1]
	var p := w.player
	p.teleport(cell_feet(4, 19))
	await frames(2)
	c.facing = -1
	c.set_state("rooted")
	c._set_bough(true)
	await frames(2)
	var shape := c._bough_shape.shape as RectangleShape2D
	var top := c._bough.global_position.y - shape.size.y * 0.5
	var mid := c._bough.global_position.x
	var hold := func(n: int) -> void:
		for i in n:
			c.state_time = 0.0
			await frames(1)
	p.teleport(Vector2(mid, top - 40.0))
	await hold.call(40)
	check(p.is_on_floor() and absf(p.global_position.y - top) <= 2.0, "you land on the bough and stand there (feet %.1f, bough %.1f)" % [p.global_position.y, top])
	p.input.down = true
	p.input.jump_pressed = true
	await hold.call(40)
	p.input.down = false
	check(p.is_on_floor() and p.global_position.y > top + 20.0, "Down + Jump drops you through it to the floor (feet %.1f)" % p.global_position.y)
	p.abilities["delvers_pick"] = true
	p.teleport(Vector2(mid, top - 70.0))
	var bounced := false
	for i in 60:
		c.state_time = 0.0
		if p.velocity.y > 0.0 and p.global_position.y > top - 30.0 and not p.is_attacking:
			p.input.down = true
			p.input.attack_pressed = true
		await frames(1)
		if p.velocity.y < -300.0:
			bounced = true
			break
	p.input.down = false
	check(bounced, "the Delver's Pick pogoes off it")
	p.teleport(Vector2(mid, top - 20.0))
	p.velocity = Vector2.ZERO
	await hold.call(30)
	check(p.is_on_floor() and absf(p.global_position.y - top) <= 2.0, "back on the bough")
	var gone := await _until(func() -> bool: return not p.is_on_floor(), 120)
	check(gone and not c.bough_solid(), "he pulls it free from under you")
	await frames(3)
	p.input.jump_pressed = true
	p.input.jump_held = true
	await frames(1)
	check(p.velocity.y < -300.0, "and a jump 4 frames later still counts, as off a ledge (vy %.0f)" % p.velocity.y)
	p.input.jump_held = false
	await frames(90)
	var floor_y := cell_feet(0, 19).y
	check(not c.bough_solid() and p.is_on_floor() and absf(p.global_position.y - floor_y) <= 1.0,
		"he pulls it free and you drop to the floor, not caught in it (feet %.1f, floor %.1f)" % [p.global_position.y, floor_y])


## Pass 177: Emberfall burns the Captain's bark off whole, as it does his knights';
## a plate still grows back when he pulls his lance free.
func test_fire_burns_the_captains_bark_off_at_once() -> void:
	var r := await _captain_world()
	var w: World = r[0]
	var c: BarkCaptain = r[1]
	check(c.bark == BarkCaptain.BARK, "he stands in full bark")
	var hp0 := c.hp
	var f := Fireball.new()
	w.room.add_child(f)
	f.global_position = c.global_position + Vector2(0, -30)
	f.burst()
	check(c.bark == 0 and hp0 - c.hp == f.damage, "one fireball burns all %d plates off and lands in full (%d)" % [BarkCaptain.BARK, hp0 - c.hp])
	# A weak reference: a lambda that captures the freed fireball logs an engine error.
	var gone: WeakRef = weakref(f)
	await _until(func() -> bool: return gone.get_ref() == null, 10)
	c.set_state("rooted")
	c.state_time = BarkCaptain.ROOTED
	await _until(func() -> bool: return c.state != "rooted", 60)
	check(c.bark == 1, "pulling free, he grows a plate back (%d)" % c.bark)


func test_a_parried_thrust_staggers_the_captain() -> void:
	var r := await _captain_world()
	var c: BarkCaptain = r[1]
	c.set_state("thrust")
	c.stagger()
	check(c.is_staggered() and c.punishable() and not c.bough_solid(), "a parry throws him back, open, the lance drawn in")


func test_the_captain_vaults_onto_you_in_his_second_phase() -> void:
	var r := await _captain_world(Vector2i(32, 19))
	var w: World = r[0]
	var c: BarkCaptain = r[1]
	w.player.teleport(cell_feet(18, 19))
	c.take_hit(int(BarkCaptain.MAX_HP * 0.9), Vector2.RIGHT)
	check(c.phase == 1, "the bark holds the first phase off")
	c.set_state("rooted")
	c.take_hit(int(BarkCaptain.MAX_HP * 0.6), Vector2.RIGHT)
	check(c.phase == 2, "below half he turns to his second phase")
	c.set_state("vault_tell")
	var hp := w.player.hp
	var planted := await _until(func() -> bool: return c.state == "planted", 240)
	check(planted and w.player.hp < hp, "he vaults across the yard and comes down lance-first on you")
	check(absf(c.global_position.x - w.player.global_position.x) < 20.0, "where you stood (%.0f px off)" % absf(c.global_position.x - w.player.global_position.x))
	check(c.punishable(), "planted, he is open")


func test_the_captain_gives_mana_dew() -> void:
	var w := make_world({}, CAPTAIN_ROOM, cell_feet(2, 19))
	var p := w.player
	await frames(3)
	var arena := _arena(w)
	p.teleport(cell_feet(8, 19))
	await _until(func() -> bool: return arena.fighting, 30)
	var c := get_tree_boss() as BarkCaptain
	await _until(func() -> bool: return c.state != "intro", 180)
	var mp0 := float(GameState.data.max_mp)
	var points := int(GameState.data.skill_points)
	var rank := int(GameState.data.rank)
	c.hp = 1
	c.stagger()
	c.take_hit(8, Vector2.RIGHT)
	check(c.state == "dying", "the last blow fells him")
	var gone := await _until(func() -> bool: return GameState.flag("boss:bark_captain"), 600)
	check(gone, "the Captain is marked beaten")
	check(float(GameState.data.max_mp) == mp0 + GameState.MANA_DEW_MP, "his Mana Dew grows your magic (%.0f -> %.0f)" % [mp0, float(GameState.data.max_mp)])
	var ranks := int(GameState.data.rank) - rank
	check(int(GameState.data.skill_points) == points + ranks, "a mini-boss gives no skill point beyond its rank-ups (%d)" % ranks)


# --- The Marsh Hag Matriarch (pass 179), the Haar's mini-boss ---------------------

const MATRIARCH_ROOM := "haar/hag_mire"


## The Matriarch dropped into her mire without the arena, awake.
func _matriarch_world(cell := Vector2i(30, 16)) -> Array:
	var w := make_world({}, MATRIARCH_ROOM, cell_feet(20, 16))
	GameState.set_flag("boss:hag_matriarch")  # keep the arena from starting its own fight
	var m := HagMatriarch.new()
	m.arena = Rect2(16, 64, 608, 208)
	m.position = cell_feet(cell.x, cell.y)
	w.room.add_child(m)
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(2)
	m.set_state("cast")
	return [w, m]


func test_the_matriarch_keeps_a_mire_east_of_polesend() -> void:
	var polesend := Room.from_file(World.room_path("haar/polesend"))
	check(polesend.doors.has(2) and String(polesend.doors[2].target) == MATRIARCH_ROOM, "Polesend's east end opens on her mire")
	polesend.free()
	var w := make_world({}, MATRIARCH_ROOM, cell_feet(1, 16))
	await frames(3)
	var arena := _arena(w)
	check(arena != null and arena.boss_id == "hag_matriarch", "the mire is a boss arena")
	check(BossArena.BOSSES.hag_matriarch.music == "miniboss" and not BossArena.BOSSES.hag_matriarch.has("skill_points"), "a mini-boss: its own theme, and no skill point")
	w.player.teleport(cell_feet(8, 16))
	var woke := await _until(func() -> bool: return arena.fighting, 30)
	var m := get_tree_boss() as HagMatriarch
	check(woke and m != null, "walking into the mire wakes her")
	check(m != null and m.global_position.x > w.player.global_position.x + 300.0, "she waits at the far end")
	check(m != null and m.state == "intro", "with her name card and a cackle")
	check(Completion.GUARDIANS.any(func(g: Array) -> bool: return g[0] == "hag_matriarch"), "she counts among the guardians")


func test_the_matriarchs_tells_are_fair() -> void:
	var m := HagMatriarch.new()
	for ph in [1, 2]:
		m.phase = ph
		for t: float in [HagMatriarch.HEX_TELL, HagMatriarch.SINK_TELL, HagMatriarch.CALL_TELL]:
			check(m.tell(t) >= Enemy.MIN_TELEGRAPH, "phase %d tell %.2f s is at least %.2f s" % [ph, m.tell(t), Enemy.MIN_TELEGRAPH])
	m.free()


func test_the_matriarchs_hex_marks_the_floor_and_the_mud_bites() -> void:
	var r := await _matriarch_world()
	var w: World = r[0]
	var m: HagMatriarch = r[1]
	w.player.teleport(cell_feet(14, 16))
	await frames(2)
	check(m._begin_hex(), "she raises her staff")
	check(m.is_hexing() and m.marks().size() == HagMatriarch.MARKS, "three marks of bog light ring you (%d)" % m.marks().size())
	var xs := m.marks().map(func(k: MireGrasp) -> float: return k.global_position.x)
	check(xs.any(func(x: float) -> bool: return absf(x - w.player.global_position.x) < 2.0), "one right under your feet")
	var hp := w.player.hp
	var bit := await _until(func() -> bool: return w.player.hp < hp, 120)
	check(bit, "the mud hands burst up and bite a player who stands still")
	m.phase = 2
	m.set_state("walk")
	w.player.teleport(cell_feet(20, 16))
	await frames(2)
	m._begin_hex()
	check(m.marks().size() == HagMatriarch.MARKS_PHASE2, "below half the hex marks five (%d)" % m.marks().size())


func test_a_blow_mid_hex_breaks_the_spell_and_opens_her() -> void:
	var r := await _matriarch_world()
	var w: World = r[0]
	var m: HagMatriarch = r[1]
	var hp0 := m.hp
	m.take_hit(10, Vector2.RIGHT)
	check(m.hp == hp0 - 5 and not m.punishable(), "her reed shawl halves a blow (%d)" % (hp0 - m.hp))
	w.player.teleport(cell_feet(14, 16))
	await frames(2)
	m._begin_hex()
	var marks := m.marks()
	hp0 = m.hp
	m.take_hit(10, Vector2.RIGHT)
	check(m.hp == hp0 - 10, "a blow mid-hex lands in full")
	check(m.state == "fumble" and m.punishable(), "and she gropes for her staff, open")
	await frames(2)
	var hp := w.player.hp
	await frames(int(HagMatriarch.HEX_TELL * 60.0) + 20)
	check(w.player.hp == hp, "no hand bites (%d -> %d)" % [hp, w.player.hp])
	check(marks.all(func(k: Variant) -> bool: return not is_instance_valid(k)), "every mark fizzles away")
	await frames(int(HagMatriarch.FUMBLE * 60.0))
	check(not m.punishable(), "until she finds it again")


## Pass 188: the Rune Dagger is a sting, not a blow. It hurts a boss, but the
## things a blow does to a boss's guard stay the blade's (and fire's) to do.
func test_a_thrown_dagger_stings_the_captain_but_splits_no_bark() -> void:
	var r := await _captain_world()
	var w: World = r[0]
	var c: BarkCaptain = r[1]
	var hp0 := c.hp
	c.take_throw(RuneDagger.DAMAGE, Vector2.RIGHT)
	check(c.hp == hp0 - ceili(RuneDagger.DAMAGE * BarkCaptain.GUARD), "a dagger in the Captain's bark lands its quarter (%d)" % (hp0 - c.hp))
	check(c.bark == BarkCaptain.BARK, "but splits no plate (%d)" % c.bark)
	check(not c.thrown, "and the sting is over once it lands")
	c.take_hit(12, Vector2.RIGHT)
	check(c.bark == BarkCaptain.BARK - 1, "a blow still chips one")
	# Thrown for real: the flight calls take_throw.
	var p := w.player
	p.abilities["rune_dagger"] = true
	p.teleport(c.global_position + Vector2(-90, 0))
	p.facing = 1
	await frames(2)
	hp0 = c.hp
	p.input.throw_pressed = true
	await frames(1)
	var landed := await _until(func() -> bool: return c.hp < hp0, 40)
	check(landed and c.bark == BarkCaptain.BARK - 1, "a dagger thrown at him stings and chips nothing (bark %d)" % c.bark)


func test_a_thrown_dagger_does_not_break_the_matriarchs_hex() -> void:
	var r := await _matriarch_world()
	var w: World = r[0]
	var m: HagMatriarch = r[1]
	w.player.teleport(cell_feet(14, 16))
	await frames(2)
	m._begin_hex()
	var hp0 := m.hp
	m.take_throw(RuneDagger.DAMAGE, Vector2.RIGHT)
	check(m.hp == hp0 - ceili(RuneDagger.DAMAGE * HagMatriarch.GUARD), "a dagger mid-hex stings the Matriarch through her shawl (%d)" % (hp0 - m.hp))
	check(m.is_hexing() and not m.punishable(), "but the spell holds: it takes a blow to break it")
	m.take_hit(10, Vector2.RIGHT)
	check(m.state == "fumble", "and a blow still does")


func test_a_thrown_dagger_glances_off_the_bound_heart() -> void:
	var setup := await _heart_world()
	var w: World = setup[0]
	var h: EvilHeart = setup[2]
	_bind(h)
	await frames(2)
	GameState.data.equipment["blade"] = "severance"
	var hp := h.hp
	w.player._attack_timer = 0.2
	h.take_throw(RuneDagger.DAMAGE, Vector2.RIGHT)
	w.player._attack_timer = 0.0
	check(h.hp == hp, "a dagger glances off the bound Heart, even with the Severance swinging")


func test_crowd_the_matriarch_and_she_sinks_away() -> void:
	var r := await _matriarch_world(Vector2i(20, 16))
	var w: World = r[0]
	var m: HagMatriarch = r[1]
	w.player.teleport(cell_feet(17, 16))
	m.set_state("walk")
	var sank := await _until(func() -> bool: return m.is_sunk(), 120)
	check(sank, "stand at her elbow and she sinks into the bog")
	var hp0 := m.hp
	m.take_hit(10, Vector2.RIGHT)
	check(m.hp == hp0 and m.collision_layer == 0, "sunk, she is out of reach")
	var rose := await _until(func() -> bool: return m.state == "rise", 120)
	check(rose and absf(m.global_position.x - w.player.global_position.x) > 200.0, "she rises at the far end of the mire (%.0f px off)" % absf(m.global_position.x - w.player.global_position.x))


func test_the_matriarch_calls_one_daughter_at_a_time() -> void:
	var r := await _matriarch_world()
	var w: World = r[0]
	var m: HagMatriarch = r[1]
	w.player.teleport(cell_feet(14, 16))
	m.stagger()
	m.take_hit(int(HagMatriarch.MAX_HP * 0.6), Vector2.RIGHT)
	check(m.phase == 2, "below half she turns to her second phase")
	for i in 3:
		if m.daughter() == null:
			m.set_state("call_tell")
		else:
			m._choose()
		await _until(func() -> bool: return m.state == "walk", 180)
	var hags := w.room.get_children().filter(func(c: Node) -> bool: return c is MarshHag and not c.dead)
	check(hags.size() == 1 and m.daughter() != null, "she calls a daughter up out of the bog, never more than one (%d)" % hags.size())
	m.die()
	await frames(2)
	hags = w.room.get_children().filter(func(c: Node) -> bool: return c is MarshHag and not c.dead)
	check(hags.is_empty(), "and her daughter sinks with her")


func test_the_matriarch_gives_mana_dew() -> void:
	var w := make_world({}, MATRIARCH_ROOM, cell_feet(1, 16))
	var p := w.player
	await frames(3)
	var arena := _arena(w)
	p.teleport(cell_feet(8, 16))
	await _until(func() -> bool: return arena.fighting, 30)
	var m := get_tree_boss() as HagMatriarch
	await _until(func() -> bool: return m.state != "intro", 180)
	var mp0 := float(GameState.data.max_mp)
	var points := int(GameState.data.skill_points)
	var rank := int(GameState.data.rank)
	m.hp = 1
	m.stagger()
	m.take_hit(8, Vector2.RIGHT)
	check(m.state == "dying", "the last blow sinks her")
	var gone := await _until(func() -> bool: return GameState.flag("boss:hag_matriarch"), 600)
	check(gone, "the Matriarch is marked beaten")
	check(float(GameState.data.max_mp) == mp0 + GameState.MANA_DEW_MP, "her Mana Dew grows your magic (%.0f -> %.0f)" % [mp0, float(GameState.data.max_mp)])
	var ranks := int(GameState.data.rank) - rank
	check(int(GameState.data.skill_points) == points + ranks, "a mini-boss gives no skill point beyond its rank-ups (%d)" % ranks)


func test_a_guardians_win_cant_be_lost_while_it_falls() -> void:
	var setup := await _king_world()
	var w: World = setup[0]
	var arena: BossArena = setup[1]
	var b: ThaneVorrund = setup[2]
	var p := w.player
	p.max_hp = 40
	p.hp = 40
	check(not arena.falling(), "nothing is falling while the king still stands")
	p.receive_attack(5, b, false)
	check(p.hp < 40, "before the killing blow his blows land as usual (hp %d)" % p.hp)
	p.set("_invuln_timer", 0.0)
	b.hp = 1
	b.take_hit(500, Vector2.RIGHT)
	await frames(2)
	check(arena.falling(), "the killing blow lands and the king falls")
	var hp := p.hp
	p.set("_invuln_timer", 0.0)
	p.receive_attack(500, b, false)
	check(not p.dead and p.hp == hp, "a blow still in the air while he falls can't kill the hero (hp %d, dead %s)" % [p.hp, p.dead])
	await _until(func() -> bool: return not arena.fighting, 400)
	check(GameState.flag("boss:thane_vorrund"), "the win is kept")
	check("severance" in GameState.data.gear, "and so is the Severance")
	check(not arena.falling(), "once the doors open nothing is shielded any more")


## Pass 268 (bible 8.7): from the throne Thane Vorrund calls his household guard,
## as the bible always said he would. The first wave of shards from the throne
## calls a Shade Knight up out of the flood at the end of the hall farther from
## you; never a second while one stands, the next two waves after it falls, and
## no more than two in a fight. The guard will not serve the Everbloom: it goes
## down when the Everbloom takes him, and it pays nothing.
func test_thane_vorrund_calls_his_household_guard_from_the_throne() -> void:
	var setup := await _king_world()
	var w: World = setup[0]
	var b: ThaneVorrund = setup[2]
	w.player.teleport(cell_feet(8, 19))
	b.hp = roundi(b.max_hp * 0.5) + 2
	b.take_hit(10, Vector2.RIGHT)
	await _until(func() -> bool: return b.state == "ward", 90)
	check(_count(w, ShadeKnight) == 0, "no guard before the throne's first wave")
	var called := await _until(func() -> bool: return _count(w, ShadeKnight) == 1, int((ThaneVorrund.WAVE_GAP + ThaneVorrund.SUMMON_TELL) * 60) + 30)
	check(called and b.guards_called == 1, "the first wave from the throne calls a Shade Knight of his guard")
	var g := b.guard
	check(g != null and absf(g.global_position.x - w.player.global_position.x) >= 96.0 and absf(g.global_position.y - b.floor_y()) < 4.0, "on the hall floor, at the end away from you (%s vs %s)" % [g.global_position if g else Vector2.ZERO, w.player.global_position])
	for i in 2:
		b._summon()
	check(_count(w, ShadeKnight) == 1, "never a second while one stands")
	# Struck down from above, over his shield.
	g.take_hit(g.hp, Vector2(0, 1))
	await frames(2)
	check(g.dead, "his guard can be struck down")
	b._summon()
	check(_count(w, ShadeKnight) <= 1 and b.guards_called == 1, "struck down, the next does not come with the next wave")
	b._summon()
	check(b.guards_called == 2 and b.guard_stands(), "but with the one after")
	for c in w.room.get_children():
		if c is Coin or c is Drop:
			c.free()
	var xp: int = GameState.data.xp
	b.hp = roundi(b.max_hp * ThaneVorrund.PHASES[1]) + 2
	b.take_hit(10, Vector2(0, 1))
	check(b.phase == 3 and not b.guard_stands() and b.guard.perished, "when the Everbloom takes him, his guard goes down")
	await frames(2)
	check(GameState.data.xp == xp and w.room.get_children().filter(func(n: Node) -> bool: return n is Coin or n is Drop).is_empty(), "and pays nothing")
	b._summon()
	check(b.guards_called == 2, "and no more than %d come in a fight" % ThaneVorrund.GUARDS)


## Pass 276 (bible 8, the openings table): each guardian names its opening as
## punishable(), which Executioner and Bloodletting read, and the table says
## what it is. Nothing held the table to the fights: the Foreman's row said
## "or reeling from a parry", but its rock never reels, so that window never
## opened. Here each guardian whose row names a parry is started in its own
## arena and sent reeling as a parry would, and must stand open; the Foreman
## must not. Every row naming a parry is checked.
func test_every_opening_the_table_names_a_parry_for_opens_on_a_parry() -> void:
	const BY_NAME := {
		"The Bark Knight Captain": "bark_captain", "The Marsh Hag Matriarch": "hag_matriarch",
		"The Clockwork Alpha": "clockwork_alpha", "Thane Vorrund": "thane_vorrund", "The Likeness": "likeness",
		"The Everbloom, phase 1": "everbloom_avatar", "The Foreman": "foreman",
	}
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var at := bible.find("**The openings, as built (pass 163):**")
	check(at >= 0, "bible 8 has the openings table")
	var parried := {}
	var rows := 0
	for line: String in bible.substr(at, 2500).split("\n"):
		var cells := line.split("|")
		if cells.size() != 4 or not line.begins_with("| ") or line.begins_with("| Boss") or line.begins_with("| ---"):
			continue
		rows += 1
		var opening := cells[2].strip_edges()
		if opening.contains("parry"):
			parried[cells[1].strip_edges()] = not opening.begins_with("stunned against a wall")
	check(rows >= 15, "the table names every guardian's opening (%d rows)" % rows)
	check(parried.keys().all(func(n: String) -> bool: return BY_NAME.has(n)), "each row naming a parry is checked (%s)" % [parried.keys()])
	var rooms := {}
	var w0 := make_world({}, "hearthroot/west_gate")
	for id: String in w0.catalog:
		var b := String(w0.catalog[id].get("boss", ""))
		if b != "":
			rooms[b] = id
	w0.queue_free()
	await frames(2)
	for name: String in parried:
		var id: String = BY_NAME.get(name, "")
		if not rooms.has(id):
			check(false, "%s has an arena" % name)
			continue
		GameState.new_game()
		var w := make_world({}, rooms[id])
		w.player.max_hp = 99999
		w.player.hp = 99999
		await frames(5)
		var ar := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
		ar._start()
		await frames(2)
		var boss := ar.boss
		await _until(func() -> bool: return not (boss.state in ["intro", "dormant", "reveal"]), 400)
		await frames(30)
		var shut: bool = not boss.punishable()
		boss.stagger()
		await frames(1)
		if parried[name]:
			check(shut and boss.punishable(), "%s: on its guard it is shut, and a parry opens it (%s)" % [name, boss.state])
		else:
			check(not boss.punishable(), "%s: a parry does not open it, as its row says (%s)" % [name, boss.state])
		w.queue_free()
		await frames(2)


## Bible 8 (pass 314): with the Rune Dagger in the off hand (or a two-hander)
## there is no parry, so every guardian whose opening is a parry has another.
func test_every_guardian_opens_without_a_shield() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var at := bible.find("**The openings, as built (pass 163):**")
	var parry_only := []
	for line: String in bible.substr(at, 2500).split("\n"):
		var cells := line.split("|")
		if cells.size() != 4 or not line.begins_with("| ") or line.begins_with("| Boss") or line.begins_with("| ---"):
			continue
		var opening := cells[2].get_slice("(", 0).strip_edges()
		if opening.contains("parry") and not opening.contains(" or ") and not opening.contains(", or"):
			parry_only.append(cells[1].strip_edges())
	check(parry_only.is_empty(), "no guardian opens only on a parry (%s)" % [parry_only])
	var rooms := {}
	var w0 := make_world({}, "hearthroot/west_gate")
	for id: String in w0.catalog:
		var b := String(w0.catalog[id].get("boss", ""))
		if b != "":
			rooms[b] = id
	w0.queue_free()
	await frames(2)
	const SPENT := {"likeness": ["recover", "f_recover"], "everbloom_avatar": ["burst"]}
	for id: String in SPENT:
		GameState.new_game()
		var w := make_world({}, rooms[id])
		w.player.max_hp = 99999
		w.player.hp = 99999
		await frames(5)
		var ar := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
		ar._start()
		await frames(2)
		var boss := ar.boss
		await _until(func() -> bool: return not (boss.state in ["intro", "dormant", "reveal"]), 400)
		for st: String in SPENT[id]:
			boss.set_state(st)
			check(boss.punishable(), "%s is open while spent (%s), no parry needed" % [id, st])
		boss.set_state("walk" if id == "everbloom_avatar" else "mirror")
		check(not boss.punishable(), "%s is shut again once it moves on (%s)" % [id, boss.state])
		if id == "everbloom_avatar":
			boss.set_state("burst")
			check(boss._modify_damage(10, Vector2(-boss.facing, 0)) == 10, "the Everbloom's plate is bare while it is spent")
		w.queue_free()
		await frames(2)


## Bible 13.3 (pass 102): every boss telegraph is heard as it starts. The scan in
## test_enemies reads set_state("x_tell") calls, but most guardians pick a move and
## enter it as set_state(pick + "_tell"), which the scan cannot read. So each
## guardian is fought here for a while, and every tell it enters must sound in the
## frame it starts (or the two after).
## The tells a 25 s fight may not reach, by guardian: [method, fields to set
## first, arguments]. Each is how the fight itself enters that tell.
const DRIVEN_TELLS := {
	"foreman": [["_choose", {"_last": "", "_since_charge": 0}, [100.0]]],
	"drowned_warden": [["_choose", {"phase": 3, "_count": 3}, [300.0]]],
	"thane_vorrund": [["_open", {}, ["burst_tell", "burst"]]],
	"likeness": [["_tell", {}, ["cast_tell"]], ["_tell", {}, ["dash_tell"]]],
}


func test_every_guardian_tell_is_heard_as_it_starts() -> void:
	var tell_re := RegEx.create_from_string("windup|tell|^wind$|^coil$|^rev$|^unfold$|^gather$")
	var rooms := {}
	var w0 := make_world({}, "hearthroot/west_gate")
	for id: String in w0.catalog:
		var b := String(w0.catalog[id].get("boss", ""))
		if b != "":
			rooms[b] = id
	w0.queue_free()
	await frames(2)
	var silent: Array[String] = []
	var unheard: Array[String] = []
	var tells := {}
	for id: String in rooms:
		GameState.new_game()
		var w := make_world({}, rooms[id])
		w.player.max_hp = 99999
		w.player.hp = 99999
		await frames(5)
		var ar := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
		if ar == null:
			w.queue_free()
			await frames(2)
			continue
		ar._start()
		await frames(2)
		var boss := ar.boss
		var last := String(boss.state)
		var heard: Array[int] = []
		var opened := {}
		Sfx.recent.clear()
		for f in 1500:
			await frames(1)
			if not is_instance_valid(boss) or boss.dead:
				break
			w.player.hp = 99999
			if f == 600 and "max_hp" in boss:
				# Down past its phase marks, to hear the later tells too.
				boss.hp = maxi(2, ceili(boss.max_hp * 0.15) + 1)
				boss.take_hit(1, Vector2.RIGHT)
			var mine := Sfx.recent.filter(func(s: String) -> bool:
				return not (s.begins_with("step_") or s in ["hurt", "land", "guard_hit", "heal"]))
			Sfx.recent.clear()
			heard.append(1 if not mine.is_empty() else 0)
			var s := String(boss.state)
			if s != last and tell_re.search(s) != null:
				opened[s] = f
			last = s
			for t: String in opened.keys():
				var at: int = opened[t]
				if f - at >= 2:
					var ok := heard[at] + heard[at + 1] + heard[at + 2] > 0
					tells["%s:%s" % [id, t]] = true
					if not ok and not silent.has("%s:%s" % [id, t]):
						silent.append("%s:%s" % [id, t])
					opened.erase(t)
		# The rarer picks a 25 s fight may not reach (pass 284), entered as the
		# fight enters them: each must sound in the call that opens it.
		for entry: Array in DRIVEN_TELLS.get(id, []):
			if not is_instance_valid(boss) or boss.dead:
				break
			for k: String in entry[1]:
				boss.set(k, entry[1][k])
			Sfx.recent.clear()
			boss.callv(entry[0], entry[2])
			var t := String(boss.state)
			tells["%s:%s" % [id, t]] = true
			if tell_re.search(t) == null or Sfx.recent.is_empty():
				silent.append("%s:%s (driven, %s)" % [id, t, Sfx.recent])
			await frames(1)
		# Every tell its script names must be heard: in the fight, driven, or
		# entered only by name with a sound on the next lines (what the scan in
		# test_enemies reads). A tell entered any other way and never heard fails.
		if is_instance_valid(boss):
			var arm := RegEx.create_from_string("^\\t+((\"[a-z_0-9]+\", )*\"[a-z_0-9]+\"):\\s*$")
			var lines := FileAccess.get_file_as_string(boss.get_script().resource_path).split("\n")
			for line in lines:
				var m := arm.search(line)
				if m == null:
					continue
				for name: String in m.get_string(1).replace("\"", "").split(", "):
					var key := "%s:%s" % [id, name]
					if tell_re.search(name) == null or tells.has(key) or unheard.has(key):
						continue
					var named := 0
					var sounded := 0
					for i in lines.size():
						if lines[i].contains("state(\"%s\")" % name) or lines[i].contains("set_mode(\"%s\")" % name):
							named += 1
							if "\n".join(lines.slice(i, i + 4)).contains("Sfx.play("):
								sounded += 1
					if named == 0 or sounded < named:
						unheard.append(key)
		Sfx.recent.clear()
		w.queue_free()
		await frames(2)
	check(tells.size() >= 30, "the guardians show their tells (%d)" % tells.size())
	check(silent.is_empty(), "every tell sounds as it starts: %s" % [silent])
	check(unheard.is_empty(), "every tell a guardian's script names is heard, fought or driven: %s" % [unheard])


## Bible 8 (pass 188, held since pass 316): the Rune Dagger "reaches every boss
## that a blade does". With Sean's off hand it is a whole build's ranged tool, so
## each guardian of the rush is thrown at in its own arena until a throw stings it.
func test_the_rune_dagger_reaches_every_guardian() -> void:
	const SKIP := {"everbloom_veins": "the veins are cut where they run, not thrown at", "everbloom": "the bound Heart takes only the Severance"}
	var missed := []
	for pair: Array in BossRush.ORDER:
		var id: String = pair[0]
		if SKIP.has(id):
			continue
		GameState.new_game()
		var w := make_world({}, pair[1])
		var p := w.player
		p.max_hp = 99999
		p.hp = 99999
		p.abilities["rune_dagger"] = true
		GameState.data.equipment.shield = ""
		await frames(5)
		var ar := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
		ar._start()
		await frames(2)
		var boss: Variant = ar.boss
		await _until(func() -> bool: return not (boss.state in ["intro", "dormant", "reveal"]), 600)
		var floor_y := p.global_position.y
		var hp0: int = boss.hp
		var struck := false
		for attempt in 24:
			await frames(20)
			if boss.dead or boss.hp < hp0:
				struck = true
				break
			p.hp = 99999
			p._invuln_timer = 2.0
			if not p.dagger_ready():
				continue
			var target := _boss_target(boss, attempt)
			# Stand where you can: under it if it is high, else a step to one side,
			# and land before the throw.
			var high := target.y < floor_y - 70.0
			var side := -1.0 if attempt % 2 == 0 else 1.0
			# A guardian below you (in the Wellspring's pool) is thrown at from the
			# ground beside it every other pair of tries.
			var x := target.x + (0.0 if high else side * 70.0)
			var drop_y := floor_y
			if target.y > floor_y and attempt % 4 >= 2:
				drop_y = target.y - 40.0
				while drop_y < target.y + 120.0 and not w.room.is_solid_at(Vector2(x, drop_y + 1.0)):
					drop_y += 2.0
			p.global_position = Vector2(x, drop_y)
			p.velocity = Vector2.ZERO
			await _until(func() -> bool: return p.is_on_floor(), 60)
			target = _boss_target(boss, attempt)
			high = target.y < p.global_position.y - 70.0
			if high:
				p.global_position.x = target.x
			p.facing = 1 if target.x > p.global_position.x else -1
			p.input.up = high
			p.throw_dagger()
			p.input.up = false
		check(struck, "%s is stung by a thrown dagger (hp %d of %d)" % [id, boss.hp, hp0])
		if not struck:
			missed.append(id)
		w.queue_free()
		await frames(2)
	check(missed.is_empty(), "the dagger reaches every guardian a blade does (missed: %s)" % [missed])


func _boss_target(boss: Variant, attempt: int) -> Vector2:
	if boss.has_method("center"):
		return boss.center()
	if "segments" in boss and not boss.segments.is_empty():
		return boss.segments[attempt % boss.segments.size()].global_position
	return boss.global_position


## Pass 332: each guardian's Reward line in bible 8 (the Foreman's in 7) must
## name what `BossArena.BOSSES` gives: its ring, key, blade, armor, ability or
## stat item, and its skill point or "no skill point". Thane Vorrund's, Skyrend's,
## the Likeness's and the Everbloom's lines left out the skill point every one of
## them gives, which the banners have told since pass 220.
func test_every_guardians_reward_line_names_its_prize() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	const HEADINGS := {"gnarlmaw": "8.1", "durgan": "8.2", "gloamweaver": "8.3", "haar_wyrm": "8.4",
		"snapcrown": "8.5", "skyrend": "8.6", "thane_vorrund": "8.7", "likeness": "8.8",
		"everbloom_avatar": "8.9", "everbloom_veins": "8.9", "everbloom": "8.9", "drowned_warden": "8.10"}
	const PARAGRAPHS := {"bark_captain": "**The Bark Knight Captain (built pass 171).**",
		"hag_matriarch": "**The Marsh Hag Matriarch (built pass 179).**",
		"clockwork_alpha": "**The Clockwork Alpha (built pass 169).**",
		"foreman": "Rock Golem (mini-boss: the Foreman"}
	var seen := 0
	for id: String in BossArena.BOSSES:
		var spec: Dictionary = BossArena.BOSSES[id]
		var text := ""
		if HEADINGS.has(id):
			text = bible.get_slice("\n### %s " % HEADINGS[id], 1).get_slice("\n### ", 0)
		elif id == "foreman":
			text = bible.get_slice(PARAGRAPHS[id], 1).get_slice("\n", 0)
		elif PARAGRAPHS.has(id):
			text = bible.get_slice(PARAGRAPHS[id], 1).get_slice("\n\n**", 0).get_slice("\n---", 0)
		if not check(text.contains("Reward:"), "the bible gives %s a Reward line" % id):
			continue
		seen += 1
		var reward := text.get_slice("Reward:", 1).get_slice("\n", 0)
		var prizes := []
		if spec.has("ring_name"):
			prizes.append(spec.ring_name)
		for key: String in ["key", "blade", "armor", "stat_item", "ability"]:
			if spec.has(key):
				prizes.append(spec.title)
		if spec.get("mana_dew", false):
			prizes.append("Mana Dew")
		for prize: String in prizes:
			check(reward.contains(prize), "%s's Reward line names the %s (%s)" % [id, prize, reward.strip_edges()])
		if int(spec.get("skill_points", 0)) > 0:
			check(reward.contains("skill point") and not reward.contains("no skill point"), "%s's Reward line names its skill point (%s)" % [id, reward.strip_edges()])
		else:
			check(reward.contains("no skill point"), "%s's Reward line says it gives no skill point (%s)" % [id, reward.strip_edges()])
	check(seen == BossArena.BOSSES.size(), "every guardian's reward is read (%d of %d)" % [seen, BossArena.BOSSES.size()])


## Pass 340: bible 8 told each guardian in words, but Gnarlmaw's section
## gave none of his wind-ups, his health or his second phase's mark, and no
## test read a guardian's phase marks or wind-ups from the bible. Its numbers
## table now gives each guardian's health, phase marks and named wind-ups; this
## holds every row to the script, and every "Phase N (below ...)" line in a
## guardian's own section to the same mark.
func test_every_guardians_numbers_are_written_in_bible_8() -> void:
	const GUARDIANS := {"Gnarlmaw": "gnarlmaw", "Durgan": "durgan", "Gloamweaver": "gloamweaver",
		"The Haar Wyrm": "haar_wyrm", "Snapcrown": "snapcrown", "Skyrend": "skyrend", "Thane Vorrund": "thane_vorrund",
		"The Likeness": "likeness", "The Everbloom's avatar": "everbloom_avatar", "The Everbloom's veins": "everbloom_core",
		"The Everbloom's heart": "everbloom_heart", "The Foreman": "foreman", "The Marsh Hag Matriarch": "hag_matriarch",
		"The Bark Knight Captain": "bark_captain", "The Clockwork Alpha": "clockwork_alpha", "The Drowned Warden": "drowned_warden"}
	const SECTIONS := {"8.1": "gnarlmaw", "8.2": "durgan", "8.3": "gloamweaver", "8.4": "haar_wyrm",
		"8.5": "snapcrown", "8.6": "skyrend", "8.7": "thane_vorrund", "8.8": "likeness"}
	const WORDS := {"half": 50, "a quarter": 25, "a fifth": 20, "two thirds": 66, "a third": 33}
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var eight := bible.get_slice("\n## 8. Bosses", 1).get_slice("\n## 9. ", 0)
	var table := eight.get_slice("| Guardian | HP | Phases at | Wind-ups (s) | Gold | XP |", 1).get_slice("\n\n", 0)
	var consts := {}
	for name: String in GUARDIANS:
		consts[GUARDIANS[name]] = (load("res://scripts/bosses/%s.gd" % GUARDIANS[name]) as Script).get_script_constant_map()
	# Every guardian script with phases has its row.
	for f: String in DirAccess.get_files_at("res://scripts/bosses"):
		if f.ends_with(".gd") and (load("res://scripts/bosses/" + f) as Script).get_script_constant_map().has("PHASES"):
			check(f.trim_suffix(".gd") in GUARDIANS.values(), "bible 8's numbers table has a row for %s" % f)
	const OWN := ["foreman", "hag_matriarch", "bark_captain", "clockwork_alpha", "drowned_warden"]
	var purses := []
	var orig_xp := 0
	var own_xp := 0
	for name: String in GUARDIANS:
		var c: Dictionary = consts[GUARDIANS[name]]
		var cells := table.get_slice("\n| %s | " % name, 1).get_slice("\n", 0).trim_suffix(" |").split(" | ")
		check(cells.size() == 5, "bible 8's numbers table has a row for %s" % name)
		if cells.size() != 5:
			continue
		# What it pays (pass 380): its purse before the arena's threat, and its
		# experience. Gnarlmaw, a Node2D, keeps both as constants.
		var gold := ""
		var xp := 0
		if c.has("XP"):
			gold = str(c["GOLD"])
			xp = c["XP"]
			purses.append_array([c["GOLD"], c["GOLD"]])
		else:
			var e: Enemy = load("res://scripts/bosses/%s.gd" % GUARDIANS[name]).new()
			gold = "%d to %d" % [e.gold_min, e.gold_max]
			xp = e.xp
			purses.append_array([e.gold_min, e.gold_max])
			e.free()
		check(cells[3] == gold, "%s's gold: the bible says %s, the script %s" % [name, cells[3], gold])
		check(cells[4] == str(xp), "%s's experience: the bible says %s, the script %d" % [name, cells[4], xp])
		if GUARDIANS[name] in OWN:
			own_xp += xp
		else:
			orig_xp += xp
		var hp: String = str(c["MAX_HP"]) if c.has("MAX_HP") else "%d a vein" % c["VEIN_HP"]
		check(cells[0] == hp, "%s's health: the bible says %s, the script %s" % [name, cells[0], hp])
		var marks := []
		for p: float in c["PHASES"]:
			marks.append("%d%%" % roundi(p * 100.0))
		check(cells[1] == (", ".join(marks) if not marks.is_empty() else "none"), "%s's phase marks: the bible says %s, the script %s" % [name, cells[1], ", ".join(marks)])
		var tells := []
		for k: String in c:
			# TELL_SEEN is how much of her a tell shows; a _P2 or _P3 tell is a
			# phase's quickened one.
			if (k.contains("TELL") and k != "TELL_SEEN" and not k.right(3).begins_with("_P")) or k == "WINDUP":
				var v: float = c[k]
				check(v >= Enemy.MIN_TELEGRAPH, "%s's %s is fair (%s s)" % [name, k, v])
				if not String.num(v) in tells:
					tells.append(String.num(v))
		tells.sort_custom(func(a: String, b: String) -> bool: return float(a) < float(b))
		check(cells[2] == ", ".join(tells), "%s's wind-ups: the bible says %s, the script %s" % [name, cells[2], ", ".join(tells)])
	# Each guardian's own section names its phase marks as the script has them.
	var re := RegEx.create_from_string("Phase (\\d)[^\\n(]{0,40}\\((?:pass \\d+, )?below ([^,)]+)")
	var named := 0
	for sec: String in SECTIONS:
		var text := eight.get_slice("\n### %s " % sec, 1).get_slice("\n### ", 0)
		var phases: Array = consts[SECTIONS[sec]]["PHASES"]
		for m: RegExMatch in re.search_all(text):
			var n := int(m.get_string(1))
			var said := m.get_string(2).strip_edges()
			var pct: int = WORDS[said] if WORDS.has(said) else said.trim_suffix("%").to_int()
			named += 1
			check(n >= 2 and n - 2 < phases.size() and absi(pct - roundi(phases[n - 2] * 100.0)) <= 1,
				"%s says phase %d starts below %s, and the script at %s" % [sec, n, said, phases])
	# 12 since the Haar Wyrm turns by its heads, not by marks (8.4, 2026-11-09).
	check(named >= 12, "the guardians' sections name their phase marks (%d)" % named)
	# The totals the note gives, and 10.1's purse range.
	var note := eight.get_slice("**What a guardian pays (pass 380).**", 1).get_slice("\n\n", 0)
	var lord: int = GameState.RANK_XP[GameState.RANK_XP.size() - 1]
	var fmt := func(n: int) -> String: return String.num_int64(n) if n < 1000 else "%d,%03d" % [n / 1000, n % 1000]
	check(note.contains("nine guardians give %s XP" % fmt.call(orig_xp)), "the note gives the source game's nine guardians' experience (%d)" % orig_xp)
	check(note.contains("five give %s more: %s in all" % [fmt.call(own_xp), fmt.call(orig_xp + own_xp)]), "and the remake's five (%d), %d in all" % [own_xp, orig_xp + own_xp])
	check(note.contains("short of Ylden's Own's %s" % fmt.call(lord)) and orig_xp + own_xp < lord, "every guardian together falls short of Ylden's Own (%d of %d)" % [orig_xp + own_xp, lord])
	check(bible.contains("A boss's purse (%d to %d g)" % [purses.min(), purses.max()]), "10.1 gives the guardians' purses as %d to %d g" % [purses.min(), purses.max()])


## Pass 364 (bible 8): "Health bars show phase markers." No test had ever
## looked at the boss bar. In every guardian's own arena the HUD's bar must name
## it, fill to its health and put a gold tick at each mark where a phase begins,
## inside the bar. A blow drops the red at once while the pale trail catches up
## at BOSS_TRAIL_SPEED, and in the Likeness's third phase the bar follows the
## real one, never its false double.
func test_every_guardians_bar_shows_its_phase_marks() -> void:
	var rooms := {}
	var w0 := make_world({}, "hearthroot/west_gate")
	for id: String in w0.catalog:
		var b := String(w0.catalog[id].get("boss", ""))
		if b != "":
			rooms[b] = id
	w0.queue_free()
	await frames(2)
	for id: String in BossArena.BOSSES:
		if not check(rooms.has(id), "%s has an arena" % id):
			continue
		GameState.new_game()
		var w := make_world({}, rooms[id])
		w.player.max_hp = 99999
		w.player.hp = 99999
		var hud := GameHud.new()
		hud.player = w.player
		arena.add_child(hud)
		await frames(5)
		var ar := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
		ar._start()
		await frames(2)
		var boss := ar.boss
		await _until(func() -> bool: return not (String(boss.get("state")) in ["intro", "dormant", "reveal", "lurk", ""]), 600)
		await frames(3)
		var bar := hud.boss_bar()
		if not check(not bar.is_empty() and bar.boss == boss, "%s: the bar is up for it" % id):
			hud.queue_free()
			w.queue_free()
			await frames(2)
			continue
		check(bar.name == String(boss.DISPLAY_NAME) and bar.name != "", "%s: the bar names it (%s)" % [id, bar.name])
		check(is_equal_approx(float(bar.fill), float(boss.health_fraction())) and float(bar.fill) > 0.0, "%s: and fills to its health (%.2f)" % [id, bar.fill])
		var rect: Rect2 = bar.rect
		var marks: Array = boss.PHASES
		var ticks: Array = bar.ticks
		# The Haar Wyrm has no health marks: it turns as each head dies (8.4).
		var ok: bool = ticks.size() == marks.size() and (marks.size() >= 1 or id == "haar_wyrm")
		for i in mini(ticks.size(), marks.size()):
			ok = ok and float(marks[i]) > 0.0 and float(marks[i]) < 1.0 and is_equal_approx(float(ticks[i]), rect.position.x + roundf(rect.size.x * float(marks[i])))
			ok = ok and float(ticks[i]) > rect.position.x and float(ticks[i]) < rect.end.x
		check(ok, "%s: a tick at each phase mark, inside the bar (%s at %s)" % [id, ticks, marks])
		hud.queue_free()
		Feel.reset()
		w.queue_free()
		await frames(2)
	# The trail, on the Foreman: the red drops at once, the pale catches up.
	GameState.new_game()
	var fw := make_world({}, rooms["foreman"])
	fw.player.max_hp = 99999
	fw.player.hp = 99999
	var fh := GameHud.new()
	fh.player = fw.player
	arena.add_child(fh)
	await frames(5)
	var far := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
	far._start()
	await frames(2)
	var foreman := far.boss
	await _until(func() -> bool: return not (String(foreman.get("state")) in ["intro", "dormant", "reveal", "lurk", ""]), 600)
	await frames(3)
	foreman.hp = int(foreman.hp) - int(foreman.MAX_HP * 0.3)
	await frames(2)
	var hit := fh.boss_bar()
	check(float(hit.trail) > float(hit.fill) + 0.25, "a blow drops the red at once, the trail behind it (%.2f, %.2f)" % [hit.fill, hit.trail])
	await frames(int(0.3 / GameHud.BOSS_TRAIL_SPEED * 60.0) + 10)
	var later := fh.boss_bar()
	check(is_equal_approx(float(later.trail), float(later.fill)), "and the trail catches up at %s of the bar a second (%.2f, %.2f)" % [String.num(GameHud.BOSS_TRAIL_SPEED), later.fill, later.trail])
	fh.queue_free()
	fw.queue_free()
	await frames(2)
	# the Likeness's third phase: the bar follows the real one.
	GameState.new_game()
	var ew := make_world({}, rooms["likeness"])
	ew.player.max_hp = 99999
	ew.player.hp = 99999
	var eh := GameHud.new()
	eh.player = ew.player
	arena.add_child(eh)
	await frames(5)
	var ear := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
	ear._start()
	await frames(2)
	var likeness := ear.boss as Likeness
	await _until(func() -> bool: return not (likeness.state in ["intro", "dormant", "reveal", "lurk", ""]), 600)
	likeness.phase = 2
	likeness.hp = int(likeness.MAX_HP * 0.2) + 4
	var split := false
	for tries in 20:
		likeness.take_hit(10, Vector2.RIGHT)
		await frames(15)
		if is_instance_valid(likeness.double):
			split = true
			break
	check(split, "below a fifth the mirror splits")
	if split:
		await frames(5)
		check(eh.boss_bar().get("boss") == likeness and not likeness.double.is_in_group("boss"), "and the bar follows the real one, not its double")
	eh.queue_free()
	Feel.reset()
	ew.queue_free()
	await frames(2)


## Pass 348: bible 8 (pass 239) says a guardian dies in "a dying window of 1.2
## to 2.5 s" before its arena opens, but no test timed one; each script keeps
## its own `DYING_TIME` (Gnarlmaw none: his segments shatter one by one).
## This fells every guardian in its own arena and times, in game seconds, the
## span from the killing blow to the arena's `defeated`, and holds the bible's
## range to the shortest and the longest.
func test_every_guardian_falls_within_the_bibles_dying_window() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var said := bible.get_slice("**A won fight stays won (pass 239).**", 1).get_slice("\n", 0)
	var rooms := {}
	var w0 := make_world({}, "hearthroot/west_gate")
	for id: String in w0.catalog:
		var b := String(w0.catalog[id].get("boss", ""))
		if b != "":
			rooms[b] = id
	w0.queue_free()
	await frames(2)
	var times := {}
	for id: String in BossArena.BOSSES:
		if not check(rooms.has(id), "%s has an arena" % id):
			continue
		GameState.new_game()
		var w := make_world({}, rooms[id])
		w.player.max_hp = 99999
		w.player.hp = 99999
		await frames(5)
		var ar := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
		ar._start()
		await frames(2)
		var boss := ar.boss
		await _until(func() -> bool: return not (String(boss.get("state")) in ["intro", "dormant", "reveal", "lurk", ""]), 600)
		await frames(10)
		var done := [false]
		boss.connect("defeated", func() -> void: done[0] = true)
		# Pass 356: "a cinematic kill (slow-mo, white flash, shatter)": the
		# screen flashes white as each one falls.
		var flashed := [0.0]
		var on_flash := func(s: float) -> void: flashed[0] = maxf(flashed[0], s)
		GameState.flash.connect(on_flash)
		if boss.has_method("die"):
			boss.call("die")
		else:
			boss.call("_die")
		# Game seconds: each frame's delta, which the kill's slow motion
		# scales (the slow motion runs on the wall clock, which a headless
		# run outpaces, so frames are no measure of what the eye sees).
		var t := 0.0
		for f in 900:
			if done[0]:
				break
			await frames(1)
			t += runner.get_physics_process_delta_time()
		check(done[0], "%s falls and its arena hears it" % id)
		GameState.flash.disconnect(on_flash)
		check(flashed[0] >= Feel.BOSS_KILL_FLASH, "%s's kill flashes the screen white (%.2f)" % [id, flashed[0]])
		times[id] = snappedf(t, 0.01)
		Feel.reset()
		w.queue_free()
		await frames(2)
	var shortest := 99.0
	var longest := 0.0
	for id: String in times:
		shortest = minf(shortest, times[id])
		longest = maxf(longest, times[id])
	check(shortest >= 1.0 and longest <= 2.7, "every guardian falls in 1 to 2.7 s (%.2f to %.2f)" % [shortest, longest])
	check(said.contains("a dying window of %s to %s s" % [String.num(snappedf(shortest, 0.1)), String.num(snappedf(longest, 0.1))]), "8 gives the range as played, %.1f to %.1f s (%s)" % [shortest, longest, said.left(90)])


## Bible 8 (pass 372): every fight opens with its reveal. The guardian shows
## itself under its name card (its name and epithet, once), and for the
## reveal's length (the bible's 1.2 to 2.4 s) neither strikes the hero at the
## door nor can be struck: a blow on whatever the hero's blade could reach
## (the guardian, or its segments where those are its only hitbox) does nothing.
func test_every_guardian_opens_with_its_reveal() -> void:
	var rooms := {}
	var w0 := make_world({}, "hearthroot/west_gate")
	for id: String in w0.catalog:
		var b := String(w0.catalog[id].get("boss", ""))
		if b != "":
			rooms[b] = id
	w0.queue_free()
	await frames(2)
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("**The reveal, held (pass 372):**") and bible.contains("from 1.2 s (the Likeness) to 2.4 s (Gnarlmaw"), "bible 8 gives the reveal's length")
	var shortest := INF
	var longest := 0.0
	for id: String in BossArena.BOSSES:
		if not check(rooms.has(id), "%s has an arena" % id):
			continue
		GameState.new_game()
		var w := make_world({}, rooms[id])
		w.player.max_hp = 99999
		w.player.hp = 99999
		await frames(5)
		var cards: Array = []
		var listen := func(title: String, text: String) -> void: cards.append([title, text])
		GameState.banner.connect(listen)
		var ar := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
		ar._start()
		var boss := ar.boss
		check(String(boss.get("state")) == "intro", "%s: the fight opens on its reveal" % id)
		var hp0 := int(boss.get("hp"))
		var targets: Array = []
		for c in boss.find_children("*", "BossSegment", true, false):
			if (c as BossSegment).boss == boss:
				targets.append(c)
		if targets.is_empty():
			targets.append(boss)
		var n := 0
		while String(boss.get("state")) == "intro" and n < 600:
			if n % 20 == 10:
				for t: Node in targets:
					t.take_hit(10, Vector2.RIGHT)
			await frames(1)
			n += 1
		GameState.banner.disconnect(listen)
		var seconds := n / 60.0
		check(cards.size() >= 1 and cards[0] == [String(boss.DISPLAY_NAME), String(boss.EPITHET)], "%s: under its name card (%s)" % [id, cards])
		check(cards.size() == 1, "%s: shown once" % id)
		if id == "haar_wyrm":
			# The written exception (bible 8.4, Sean 2026-11-09): the hydra's first
			# sight is its whole reveal, eyes and all; a retry is the short one.
			check(absf(seconds - HaarWyrm.INTRO_TIME) <= 0.1, "%s: its first reveal is the whole %.1f s (%.2f s)" % [id, HaarWyrm.INTRO_TIME, seconds])
			check(HaarWyrm.INTRO_TIME - HaarWyrm.INTRO_SEEN_FROM <= 2.4 + 0.05, "%s: and a retry's is %.1f s" % [id, HaarWyrm.INTRO_TIME - HaarWyrm.INTRO_SEEN_FROM])
		else:
			shortest = minf(shortest, seconds)
			longest = maxf(longest, seconds)
			check(seconds >= 1.2 - 0.05 and seconds <= 2.4 + 0.05, "%s: a reveal of %.2f s" % [id, seconds])
		check(int(boss.get("hp")) == hp0, "%s: no blow lands during it (%d of %d)" % [id, int(boss.get("hp")), hp0])
		check(w.player.hp == 99999, "%s: and it strikes no one at the door" % id)
		Feel.reset()
		w.queue_free()
		await frames(2)
	check(shortest >= 1.15 and shortest <= 1.25, "the shortest reveal is 1.2 s (%.2f)" % shortest)
	check(longest >= 2.35 and longest <= 2.45, "the longest is 2.4 s (%.2f)" % longest)


## Pass 396 (bible 8): the walk from a rest to a fight is paid on every retry,
## so every guardian's arena is at most one door from a Meditation Shrine or a
## Ringreader's room. The Everbloom's veins and heart, the final climb past the
## throne's shrine, are the written exceptions.
func test_every_guardian_is_a_door_from_a_rest() -> void:
	const FAR := {"everbloom_veins": 2, "everbloom": 3}
	var doors := {}
	var rests: Array[String] = []
	var arenas := {}
	for zone: String in DirAccess.get_directories_at("res://levels"):
		for f: String in DirAccess.get_files_at("res://levels/" + zone):
			if not f.ends_with(".room"):
				continue
			var id := "%s/%s" % [zone, f.get_basename()]
			var text := FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, f])
			var head := text.get_slice("\n---\n", 0)
			doors[id] = []
			var rest := text.get_slice("\n---\n", 1).contains("S")
			for line: String in head.split("\n"):
				if line.begins_with("door:"):
					doors[id].append(line.get_slice(",", 1).strip_edges())
				elif line.begins_with("npc:") and line.get_slice(",", 2).strip_edges() == "ringreader":
					rest = true
				elif line.begins_with("boss:"):
					arenas[id] = line.trim_prefix("boss:").strip_edges()
			if rest:
				rests.append(id)
	var dist := {}
	var queue: Array[String] = []
	for r: String in rests:
		dist[r] = 0
		queue.append(r)
	while not queue.is_empty():
		var id: String = queue.pop_front()
		for to: String in doors[id]:
			if doors.has(to) and not dist.has(to):
				dist[to] = int(dist[id]) + 1
				queue.append(to)
			# Doors lead back, so the graph is walked both ways.
		for other: String in doors:
			if not dist.has(other) and id in doors[other]:
				dist[other] = int(dist[id]) + 1
				queue.append(other)
	check(arenas.size() == 16, "sixteen guardians have arenas (%d)" % arenas.size())
	for id: String in arenas:
		var boss: String = arenas[id]
		var limit := int(FAR.get(boss, 1))
		check(int(dist.get(id, 99)) <= limit, "%s's arena (%s) is %d doors from a rest, at most %d" % [boss, id, int(dist.get(id, 99)), limit])
	for boss: String in FAR:
		var id: String = arenas.find_key(boss)
		check(int(dist.get(id, 0)) == FAR[boss], "%s is the %d-door exception 8 names" % [boss, FAR[boss]])
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("**A rest at every guardian's door (pass 396).**", 1).get_slice("\n\n", 0)
	check(note.contains("`test_every_guardian_is_a_door_from_a_rest`") and note.contains("(2 and 3 doors)"), "bible 8 names the rule, its exceptions and the test")


## Pass 404 (bible 8): a guardian fought through the real controller. Every
## boss test scripts the hero's intent or calls the boss's own hit, so the
## path from a pad to a fight (walking in, the doors sealing behind, a door
## that will not let you leave, the blow that ends it, the doors opening and
## the ring) was never driven by the buttons a player presses. The Root
## Chamber, the first guardian, is fought here with `Input` alone.
func test_a_guardian_falls_to_the_real_controller() -> void:
	var was := GameState.slot
	GameState.slot = 9
	var w := make_world({}, ARENA_ROOM)
	var p := w.player
	p.input = PlayerInput.new()
	await frames(3)
	var arena := _arena(w)
	Input.action_press("move_right")
	var woke := await _until(func() -> bool: return arena.fighting, 240)
	Input.action_release("move_right")
	check(woke and arena.seals.size() == 2, "walking in holding Right wakes Gnarlmaw and seals both doors")
	var boss: Gnarlmaw = get_tree_boss()
	# Holding Left into the sealed way in does not leave the room.
	p.teleport(cell_feet(2, 19))
	Input.action_press("move_left")
	await frames(40)
	Input.action_release("move_left")
	check(w.room.id == ARENA_ROOM and p.global_position.x > 8.0, "Left into the sealed door goes nowhere (%s)" % w.room.id)
	# A stuck lunge leaves the tail by the wall; the last blow is a real swing.
	p.teleport(cell_feet(4, 13))
	await frames(2)
	boss._start_lunge(Gnarlmaw.FLOOR_LANE, true)
	var stuck := await _until(func() -> bool: return boss.state == "stuck", 300)
	check(stuck, "the lunge bites into the wall and leaves its tail out")
	boss.hp = 1
	var tail := boss.tail_position()
	p.teleport(Vector2(tail.x - 22.0, cell_feet(4, 19).y))
	Input.action_press("move_right")
	await frames(2)
	Input.action_release("move_right")
	await frames(2)
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	var fell := await _until(func() -> bool: return boss.dead, 30)
	check(fell, "an Attack pressed by the tail lands the last blow (hp %d, state %s)" % [boss.hp, boss.state])
	var gone := await _until(func() -> bool: return boss.state == "dead", 900)
	var opened := await _until(func() -> bool: return arena.seals.is_empty() and _count(w, ArenaSeal) == 0, 1200)
	check(gone and opened, "it shatters and the doors open again")
	check(GameState.data.rings.has("thaw") and GameState.flag("boss:gnarlmaw"), "the Thaw Seed is won")
	# And the way on, high in the east wall, is walked through with Right held.
	var exit: Rect2i = w.catalog[ARENA_ROOM].doors[2].rect
	p.teleport(cell_feet(exit.position.x - 1, exit.end.y - 1))
	Input.action_press("move_right")
	var left := await _until(func() -> bool: return w.room.id != ARENA_ROOM, 600)
	Input.action_release("move_right")
	check(left and w.room.id == "heartwood/spring_of_heartwood", "Right walks out through the opened door to the spring (%s)" % w.room.id)
	GameState.delete_save(9)
	GameState.slot = was
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n## 8. Bosses", 1).get_slice("\n### 8.1 ", 0)
	check(note.contains("`test_a_guardian_falls_to_the_real_controller`"), "bible 8 names the test")


## Pass 420: the Foreman's rock, by the buttons. Bible 4 and 8: its rock
## halves every blow except one from above. Until now the halving was held by
## calling `take_hit` with a direction, and no pogo had ever landed on a
## guardian's head through the real controller. Here an Attack pressed for
## real beside it is halved, and Down + Attack pressed for real as the hero
## falls onto its helm lands in full and bounces him back up.
func test_the_foremans_rock_answers_the_real_controller() -> void:
	# Mid-hall, clear of the two one-way ledges overhead.
	var r := await _foreman_world(Vector2i(20, 19))
	var w: World = r[0]
	var f: Foreman = r[1]
	var p := w.player
	p.input = PlayerInput.new()
	await frames(2)
	var full := roundi(p.slash_damage * p.melee_mult)
	var halved := maxi(1, roundi(full * Foreman.ARMOR))
	# Beside it, facing it, a slash pressed for real.
	p.teleport(Vector2(f.global_position.x - 30.0, f.global_position.y))
	p.facing = 1
	await frames(3)
	var hp0 := f.hp
	await press_for_real(p, ["attack"])
	release_for_real(["attack"])
	await frames(10)
	check(hp0 - f.hp == halved, "a slash pressed for real at its side is halved by the rock (%d of %d)" % [hp0 - f.hp, full])
	# Over its helm, Down + Attack pressed for real as the hero falls.
	await frames(int(p.tuning.attack_cooldown * 60.0) + 10)
	# The down-strike is the Delver's Pick's (it is won here, so a revisit has it).
	p.abilities["delvers_pick"] = true
	p.teleport(Vector2(f.global_position.x, f.global_position.y - 120.0))
	p.velocity = Vector2.ZERO
	hp0 = f.hp
	var pogo := roundi(p.slash_damage * p.melee_mult * p.down_strike_mult)
	# Down is held through the fall; Attack goes down as the helm comes near.
	Input.action_press("move_down")
	var pressed := false
	var bounced := false
	for i in 90:
		if not pressed and p.global_position.y > f.global_position.y - f.body_size.y - 40.0:
			Input.action_press("attack")
			pressed = true
		await frames(1)
		if f.hp < hp0 and p.velocity.y < -200.0:
			bounced = true
			break
	release_for_real(["move_down", "attack"])
	check(bounced, "Down + Attack pressed for real drops onto its helm and bounces the hero up")
	check(hp0 - f.hp == pogo, "and the pogo from above lands in full (%d of %d)" % [hp0 - f.hp, pogo])
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("The rock by the buttons (pass 420)"), "bible 8 says so")


func test_the_fountain_sheet_has_a_state_for_each_spring() -> void:
	# Sean's PixelLab fountain: dry, then one state per restored spring.
	check(Fountain.STATES.size() == Fountain.SPRINGS.size() + 1, "one state per spring, plus dry")
	check(Sheet.exists(Fountain.SHEET), "the fountain sheet is packed")
	for s: String in Fountain.STATES:
		check(Sheet.has_anim(Fountain.SHEET, s), "the sheet has the %s state" % s)
	check(Sheet.get_sheet(Fountain.SHEET).density == 2.0, "drawn at the hero's 2x density")
	check(Fountain.state() == "dry", "a new game starts dry")


## Pass 444 (bible 5.3, 8): pass 442 made a blade a guard turns push the hero
## back at `turned_blade_push`, through `Enemy._on_blocked`. Four guardians turn
## blows with guards of their own and never called it: Thane Vorrund warded on
## his throne, Durgan's open cockpit from the side, the Everbloom's core, and
## the Evil Heart without the Severance. A slash each turned was pushed
## back only as a landed cut is, so the guardian's guard read like a hit.
func test_a_guardians_guard_turns_the_blade_back() -> void:
	var c := CombatTuning.new()
	var rows := grid_rows(30, 12)
	for which: String in ["thane_vorrund", "durgan", "everbloom_core", "everbloom_heart"]:
		var room := make_room(rows)
		var p := make_player(room, Vector2i(6, 8))
		p.max_hp = 9999
		p.hp = 9999
		await frames(4)
		var b: Enemy
		match which:
			"thane_vorrund":
				b = ThaneVorrund.new()
			"durgan":
				b = Durgan.new()
			"everbloom_core":
				b = EvilCore.new()
			"everbloom_heart":
				b = EvilHeart.new()
		room.add_child(b)
		b.global_position = p.global_position + Vector2(30, -20 if b.body_centered else 0)
		await frames(1)
		b.set_physics_process(false)
		b.contact_damage = 0
		match which:
			"thane_vorrund":
				b.phase = 2
				b.state = "ward"
			"durgan":
				b.phase = 3
				b.state = "idle"
			"everbloom_heart":
				b.state = "bound"
		var hp0 := b.hp
		var hits0 := b.hits_taken
		p.input = PlayerInput.new()
		Sfx.recent.clear()
		await press_for_real(p, ["attack"])
		release_for_real(["attack"])
		var push := 0.0
		for i in 4:
			push = minf(push, p.velocity.x)
			await frames(1)
		# Pass 446: heard as a guard, not as a cut.
		var heard: Array = Sfx.recent.filter(func(n: String) -> bool: return n in ["hit", "guard"])
		check(heard == ["guard"], "%s's turned slash is heard by the guard's thud alone (%s)" % [which, heard])
		check(b.hits_taken == hits0 + 1 and b.hp == hp0,
			"%s's guard turns a slash pressed for real (%d hits, %d -> %d)" % [which, b.hits_taken - hits0, hp0, b.hp])
		check(push <= -c.turned_blade_push + 1.0, "and pushes the hero back at %.0f px/s, as an ordinary foe's guard does (%.0f)" % [c.turned_blade_push, push])
		room.free()
		await frames(1)
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 5.3 ", 1).get_slice("\n### 5.4 ", 0)
	check(note.contains("A guardian's guard, too (pass 444)"), "5.3 says so")


## Pass 474: a guardian's idle sway moved its hurtboxes by the wall clock, so in
## hitstop (the whole game frozen) the Snapcrown's head, the Haar Wyrm's heads and
## the Gloamweaver's lanterns kept drifting, and under a slower Game speed they
## swayed at full speed. They follow the foe's own game time now.
func _frozen_drift(nodes: Array) -> float:
	await frames(3)
	Engine.time_scale = 0.0
	await frames(1)
	var before: Array[Vector2] = []
	for n: Node2D in nodes:
		before.append(n.global_position)
	for i in 6:
		OS.delay_msec(70)
		await frames(1)
	Engine.time_scale = 1.0
	var most := 0.0
	for i in nodes.size():
		most = maxf(most, (nodes[i] as Node2D).global_position.distance_to(before[i]))
	return most


func test_a_guardian_stands_still_through_hitstop() -> void:
	var bloom := await _bloom_world()
	var k: Snapcrown = bloom[2]
	await _until(func() -> bool: return k.state == "idle", 180)
	check(k.state == "idle", "the Snapcrown sways at rest (%s)" % k.state)
	var drift := await _frozen_drift([k.head])
	check(drift < 0.01, "frozen, the Snapcrown's head stays put (%.2f px)" % drift)
	var t0 := k.game_time
	Feel.set_game_speed(0.7)
	await frames(60)
	Feel.set_game_speed(1.0)
	check(absf(k.game_time - t0 - 0.7) < 0.02, "at 70%% its sway clock runs 0.7 s a second (%.3f)" % (k.game_time - t0))
	bloom[0].queue_free()
	await frames(2)
	var hydra := await _hydra_world()
	var z: HaarWyrm = hydra[2]
	await _until(func() -> bool: return z.state == "fight", 180)
	var heads: Array = []
	for h in z.heads:
		if is_instance_valid(h) and h.mode == "idle":
			heads.append(h)
	check(not heads.is_empty(), "a head of the Haar Wyrm sways at rest")
	drift = await _frozen_drift(heads)
	check(drift < 0.01, "frozen, its heads stay put (%.2f px)" % drift)
	hydra[0].queue_free()
	await frames(2)
	var widow := await _widow_world()
	var r: Gloamweaver = widow[2]
	await _until(func() -> bool: return r.state == "stalk", 120)
	drift = await _frozen_drift(r.lanterns)
	check(drift < 0.01, "frozen, the Gloamweaver's lanterns stay put (%.2f px)" % drift)
	widow[0].queue_free()
	await frames(2)


## A guardian's reward banner, and a toast, are words to read: they last as
## long in real time at a slower Game speed or in a boss's slow motion as at
## full speed (pass 482).
func test_a_guardians_banner_reads_in_real_time_at_every_game_speed() -> void:
	for mode: String in ["full", "speed 0.7", "slowmo 0.3"]:
		var hud := GameHud.new()
		arena.add_child(hud)
		await frames(2)
		if mode == "speed 0.7":
			Feel.set_game_speed(0.7)
		elif mode == "slowmo 0.3":
			Feel.slowmo(0.3, 60.0)
		hud.show_banner("The Haar Wyrm", "The tide returns")
		hud.show_toast("Gold +40")
		await frames(int(GameHud.TOAST_TIME * 60.0) - 12)
		check(hud._toast_t > 0.0, "%s: the toast is still up near its end (%.2f s left)" % [mode, hud._toast_t])
		await frames(24)
		check(hud._toast_t == 0.0, "%s: and gone on time (%.2f s left)" % [mode, hud._toast_t])
		await frames(int((GameHud.BANNER_TIME - GameHud.TOAST_TIME) * 60.0) - 24)
		check(hud._banner_t > 0.0, "%s: the banner is still up near its end (%.2f s left)" % [mode, hud._banner_t])
		await frames(24)
		check(hud._banner_t == 0.0, "%s: and gone on time, %.1f s of real time (%.2f s left)" % [mode, GameHud.BANNER_TIME, hud._banner_t])
		Feel.reset()
		Feel.set_game_speed(1.0)
		hud.queue_free()
		await frames(2)
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("test_a_guardians_banner_reads_in_real_time_at_every_game_speed"), "the bible names this test")


# --- Pass 490: the spell guardians at the slowest Game speed ------------------

## Presses the real Spell button facing right and waits up to 4 s for `done`.
## Deluge cast by the real Spell button from in front of `intake`'s mouth.
func _cast_into(p: Player, intake: HydraIntake) -> bool:
	p.mp = p.max_mp
	p.teleport(intake.global_position + Vector2(intake.facing * 40.0, 24.0))
	p.facing = -intake.facing
	await press_for_real(p, ["spell"])
	release_for_real(["spell"])
	return await _until(func() -> bool: return intake.flowing, 60)


func _cast_until(p: Player, done: Callable) -> bool:
	p.mp = p.max_mp
	p.facing = 1
	await press_for_real(p, ["spell"])
	release_for_real(["spell"])
	return await _until(done, 240)


## The death blow at `game_speed`: a freeze, then slow motion easing back up to
## the Game speed, never past it, all in real time (hitstop runs on the wall
## clock, so the wait is real time too, pass 488).
func _watch_death_blow(label: String) -> void:
	var froze := false
	var lowest := 9.0
	var highest := 0.0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 2_500_000:
		await frames(1)
		var s := Engine.time_scale
		if s == 0.0:
			froze = true
		else:
			lowest = minf(lowest, s)
			highest = maxf(highest, s)
	check(froze, "%s: the death blow freezes the game" % label)
	check(lowest < 0.7 * Feel.BOSS_KILL_SLOWMO + 0.05, "%s: then slows it to 0.3 of 70%% (%.2f)" % [label, lowest])
	check(highest <= 0.7 + 0.001, "%s: and never runs faster than 70%% (%.2f)" % [label, highest])
	check(Engine.time_scale == 0.7, "%s: then the game is back at 70%% (%.2f)" % [label, Engine.time_scale])


func test_the_spell_guardians_fall_to_the_buttons_at_the_slowest_game_speed() -> void:
	Feel.set_game_speed(0.7)
	# The Haar Wyrm: Deluge into each of the cistern's three intakes douses a head.
	var setup := await _hydra_world()
	var w: World = setup[0]
	var z: HaarWyrm = setup[2]
	z.attacker = null
	z.order.clear()
	z.last_breather = z.head_for(HydraHead.GEYSER)
	z._to("gap")
	z.step_time = -999.0
	var p := w.player
	p.abilities.torrent = true
	GameState.data.abilities.torrent = true
	p.equipped_spell = "torrent"
	for i: HydraIntake in _intakes(w):
		# Past the 0.35 s cooldown, which is 0.5 s at 70% (a press inside it
		# casts nothing, bible 5.3, pass 442).
		await frames(40)
		var ran := await _cast_into(p, i)
		check(ran, "the Haar Wyrm: the Spell button sends Deluge into the intake at y %.0f at 70%%" % i.global_position.y)
	var g := z.head_for(HydraHead.GEYSER)
	var weak := await _until(func() -> bool: return z.step == "weak", 120)
	check(weak and g.weak, "the Haar Wyrm: the full cistern douses the head that breathed last at 70%")
	for h in z.heads:
		if h != g:
			h.kill()
	g.hp = 1
	Feel.hitstop_enabled = true
	g.take_hit(5, Vector2.RIGHT)
	check(z.state == "dying", "the Haar Wyrm: the last blow ends him")
	await _watch_death_blow("the Haar Wyrm")
	Feel.hitstop_enabled = false
	Feel.reset()
	w.queue_free()
	await frames(2)
	# Skyrend: Tempest Lance wakes the roost's three conduits and grounds it.
	setup = await _roc_world()
	w = setup[0]
	var b2: Skyrend = setup[2]
	p = w.player
	p.abilities.thunder = true
	GameState.data.abilities.thunder = true
	p.equipped_spell = "thunder"
	var cs := _conduits(w)
	check(cs.size() == 3, "Skyrend: three conduits in the roost")
	for c: Conduit in cs:
		p.teleport(c.global_position + Vector2(-48, 0))
		# Past the 0.35 s cooldown, which is 0.5 s at 70% (a press inside it
		# casts nothing, bible 5.3, pass 442).
		await frames(40)
		var lit := await _cast_until(p, func() -> bool: return c.powered or b2.grounded())
		check(lit, "Skyrend: the Spell button wakes the conduit at x %.0f with Tempest Lance at 70%%" % c.global_position.x)
	var down := await _until(func() -> bool: return b2.grounded(), 120)
	check(down, "Skyrend: the three conduits ground it at 70%% (%s)" % b2.state)
	b2.hp = 1
	Feel.hitstop_enabled = true
	b2.take_hit(5, Vector2.RIGHT)
	check(b2.state == "dying", "Skyrend: the last blow ends it")
	await _watch_death_blow("Skyrend")
	Feel.hitstop_enabled = false
	Feel.set_game_speed(1.0)
	Feel.reset()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("test_the_spell_guardians_fall_to_the_buttons_at_the_slowest_game_speed"), "the bible names this test")


## Pass 492 (bible 13.3): a guardian's death blow heard at the slowest Game
## speed. The roar goes off once, on the blow, inside the freeze; the win's
## chime once, as the dying ends, in the same game time as at full speed; and
## the guardian's theme is let go as the win sounds.
func test_a_guardians_death_blow_is_heard_at_every_game_speed() -> void:
	var game_times := {}
	for speed: float in [1.0, 0.7]:
		var label := "%d%%" % roundi(speed * 100.0)
		Feel.set_game_speed(speed)
		var setup := await _hydra_world()
		var w: World = setup[0]
		var z: HaarWyrm = setup[2]
		await _until(func() -> bool: return z.state == "fight", 300)
		for h in z.heads:
			if h.index > 0:
				h.kill()
		z.heads[0].hp = 1
		z.heads[0].weak = true
		Sfx.recent.clear()
		Feel.hitstop_enabled = true
		z.heads[0].take_hit(5, Vector2.RIGHT)
		check(Sfx.recent.count("hydra_roar") == 1 and Feel.is_frozen(), "%s: the roar goes off on the blow, inside the freeze (%s)" % [label, Sfx.recent])
		var heard: Array[String] = []
		heard.append_array(Sfx.recent)
		Sfx.recent.clear()
		var game_t := 0.0
		var start := Time.get_ticks_usec()
		var won := false
		while Time.get_ticks_usec() - start < 12_000_000:
			await frames(1)
			game_t += Engine.time_scale / 60.0
			heard.append_array(Sfx.recent)
			if Sfx.recent.has(BossArena.WIN_SOUND):
				won = true
				Sfx.recent.clear()
				break
			Sfx.recent.clear()
		check(won, "%s: the win's chime sounds" % label)
		check(Music.track == "", "%s: and the guardian's theme is let go with it (%s)" % [label, Music.track])
		game_times[speed] = game_t
		await frames(30)
		heard.append_array(Sfx.recent)
		check(heard.count("hydra_roar") == 1 and heard.count(BossArena.WIN_SOUND) == 1, "%s: each once (%d roars, %d chimes)" % [label, heard.count("hydra_roar"), heard.count(BossArena.WIN_SOUND)])
		Feel.hitstop_enabled = false
		Feel.set_game_speed(1.0)
		Feel.reset()
		w.queue_free()
		await frames(2)
	check(absf(float(game_times[0.7]) - float(game_times[1.0])) < 0.1, "the chime comes after the same game time at 70%% as at full speed (%.2f s, %.2f s)" % [game_times[0.7], game_times[1.0]])
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("test_a_guardians_death_blow_is_heard_at_every_game_speed"), "the bible names this test")

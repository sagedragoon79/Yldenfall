extends TestSuite
## Random-input soaks: catch the player escaping a room, getting embedded in
## solid tiles or producing invalid positions, and scenes that pile up nodes or
## blow the frame budget.

const RUNS := [1987, 2026, 42]
const FRAMES_PER_RUN := 900

const ACTIONS := ["jump", "attack", "dash", "spell", "heal", "block"]


func test_random_input_soak_in_gym() -> void:
	var problems: Array[String] = []
	for seed in RUNS:
		var room := Room.from_file("res://levels/gym/gym.room")
		arena.add_child(room)
		var p := Player.new()
		p.input.scripted = true
		p.position = room.spawn_position
		room.add_child(p)
		p.spawn_point = room.spawn_position
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
		var bounds := room.pixel_rect().grow(8.0)
		for f in FRAMES_PER_RUN:
			_mash(p, rng, hold)
			await frames(1)
			var pos := p.global_position
			if not (is_finite(pos.x) and is_finite(pos.y)):
				problems.append("seed %d frame %d: invalid position" % [seed, f])
				break
			if p.dead:
				continue
			if not bounds.has_point(pos):
				problems.append("seed %d frame %d: left the room at %s" % [seed, f, pos])
				break
			var body := p.body_rect().grow(-3.0)
			for corner in [body.position, Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), body.end, body.get_center()]:
				if room.is_solid_at(corner):
					problems.append("seed %d frame %d: embedded in a solid tile at %s" % [seed, f, pos])
					break
			if problems.size() > 0:
				break
		room.queue_free()
		await frames(1)
	check(problems.is_empty(), "soak found no problems: %s" % [problems])


## One frame of button-mashing: inputs persist for random spans, like a player.
## Drops a soaked boss's health onto a phase mark and lets it turn. Rounded
## down: 99,999 x 0.3 rounds to 30,000, a hair above the mark, and the Hydra
## soak reached its flood only if a mashed blow happened to land after the push
## (pass 223: 13 of 30 seeds never did).
func _push_to_mark(boss: Enemy, mark: float) -> void:
	boss.hp = floori(boss.max_hp * mark)
	boss.call("_check_phase")


func _mash(p: Player, rng: RandomNumberGenerator, hold: Dictionary) -> void:
	if hold.move <= 0:
		p.input.move_x = rng.randi_range(-1, 1)
		hold.move = rng.randi_range(5, 40)
	if hold.down <= 0:
		p.input.down = rng.randf() < 0.2
		hold.down = rng.randi_range(5, 30)
	if hold.up <= 0:
		p.input.up = rng.randf() < 0.15
		hold.up = rng.randi_range(5, 30)
	if hold.jump <= 0:
		p.input.jump_held = rng.randf() < 0.4
		p.input.jump_pressed = p.input.jump_held
		hold.jump = rng.randi_range(3, 30)
	if hold.block <= 0:
		# With a shield on, guard often enough that every shielded room is
		# sure to test the guard; how often the mash guarded used to ride on the
		# seed, which is the room's id (the ids were renamed in pass 462).
		var guard_rate := 0.25 if String(GameState.data.equipment.get("shield", "")) != "" else 0.1
		p.input.block_held = rng.randf() < guard_rate
		p.input.block_pressed = p.input.block_held
		hold.block = rng.randi_range(5, 40)
	# Attack is held for spans too (pass 151), most of them long enough to
	# charge a Thrust; letting go then thrusts if the skill is learned.
	if not hold.has("throw"):
		hold["throw"] = 0
	var was_held := p.input.attack_held
	if int(hold.get("attack", 0)) <= 0:
		p.input.attack_held = rng.randf() < 0.3
		hold["attack"] = rng.randi_range(4, 60)
	for k: String in hold:
		hold[k] -= 1
	p.input.attack_pressed = rng.randf() < 0.08 or (p.input.attack_held and not was_held)
	p.input.dash_pressed = rng.randf() < 0.03
	p.input.spell_pressed = rng.randf() < 0.01
	p.input.heal_pressed = rng.randf() < 0.005
	# The Rune Dagger (pass 191): thrown into walls, doors, water and foes,
	# every 25 frames. It draws nothing from `rng`, so each soak's mashing
	# stays the run it was before the dagger.
	p.input.throw_pressed = int(hold.throw) % 25 == 0


func _embedded(room: Room, p: Player) -> bool:
	var body := p.body_rect().grow(-3.0)
	for corner in [body.position, Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), body.end, body.get_center()]:
		if room.is_solid_at(corner):
			return true
	return false


const TOWER_FRAMES := 420
## Long enough for the Stillstone to be turned twice in each room.
const GLASS_FRAMES := 660
## Frames timed in each room once it has loaded (the room-load sweep, pass 166).
const SETTLE_FRAMES := 12
## Pass 335: three laps of every room; 1.5 GB is bible 14's budget, and a lap
## after the first may grow by less than 4 MB or 50 objects.
const MEMORY_LAPS := 3
const MEMORY_BUDGET := 1536 * 1048576
const MEMORY_DRIFT := 4 * 1048576
const OBJECT_DRIFT := 50


## Every Tower room, live (enemies, doors, gates), with every ability and a
## mashing player: no escapes, no embedding, and the room's node count settles.
func test_random_input_soak_in_every_tower_room() -> void:
	await _soak_zone("tower", "Tower")


## The same soak over every Hearthroot and Heartwood room, so the first two zones keep up
## with changes made for later ones.
func test_random_input_soak_in_every_hearthroot_and_heartwood_room() -> void:
	await _soak_zone("hearthroot", "Hearthroot")
	await _soak_zone("heartwood", "Heartwood")


## The Haar under its fog: the same soak, and the fog never runs out of lights.
func test_random_input_soak_in_every_haar_room() -> void:
	await _soak_zone("haar", "Haar")


## The High Boughs: the canopy's rooms, bounce-pods and all.
func test_random_input_soak_in_every_boughs_room() -> void:
	await _soak_zone("boughs", "High Boughs")


## Carillon: storm rain, sky islands and crystal-thorned cliffs.
func test_random_input_soak_in_every_spires_room() -> void:
	await _soak_zone("spires", "Carillon")


## Vorrhallow, with the Stillstone turned whenever it is ready: frozen water,
## projectiles held in the air, and time running on again, room after room.
func test_random_input_soak_in_every_vorrhallow_room() -> void:
	await _soak_zone("vorrhallow", "Vorrhallow", true)


## the Evercrown: spores, flesh and the Everbloom's light, room after room.
func test_random_input_soak_in_every_evercrown_room() -> void:
	await _soak_zone("evercrown", "The Evercrown")


## The Sunken Spring: swimming, eels and the water drawn over everything.
func test_random_input_soak_in_every_sunken_spring_room() -> void:
	await _soak_zone("sunken", "Sunken Spring")


## The Inner Rings' inner rings (pass 113), off the map but built like any zone.
## Each room is soaked as a live run with the Stillstone turned whenever it is
## ready (pass 166): hazards set you back instead of hurting, Stillness's water
## freezes and runs on, and a rung bell carries you back to the temple.
func test_random_input_soak_in_every_trial_room() -> void:
	await _soak_zone("trials", "Trials", true)
	check(not Trials.active(), "no trial run is left open after the soak")


## Carillon's storm: the PixelLab rain sheet (SheetRain, pass 498) tiled screen-wide
## in two parallax layers over the lightning backdrop, the player running and dashing
## about. The sheet keeps falling and the frame stays well inside budget.
func test_spires_rain_stays_cheap() -> void:
	var w := make_world({}, "spires/sky_steps")
	var p := w.player
	p.abilities["stride"] = true
	await frames(2)
	check(w.sheet_rain.active and w.sheet_rain._frames.size() == SheetRain.FRAMES, "the rain sheet is falling (%d frames)" % w.sheet_rain._frames.size())
	check(w.motes.zone != "spires", "and the code streak field is off while the sheet rains")
	var total_usec := 0
	var worst := 0
	const RAIN_FRAMES := 600
	for f in RAIN_FRAMES:
		p.input.move_x = 1 if (f / 90) % 2 == 0 else -1
		p.input.jump_pressed = f % 40 == 0
		p.input.jump_held = f % 40 < 12
		p.input.dash_pressed = f % 40 == 14
		var t0 := Time.get_ticks_usec()
		await frames(1)
		var dt := Time.get_ticks_usec() - t0
		total_usec += dt
		worst = maxi(worst, dt)
	var avg_ms := total_usec / 1000.0 / RAIN_FRAMES
	print("  Carillon rain: %.2f ms a frame on average, %.2f ms at worst" % [avg_ms, worst / 1000.0])
	check(w.sheet_rain.active and w.sheet_rain.density() > 0.9, "the sheet rains hard the whole storm (density %.2f)" % w.sheet_rain.density())
	check(avg_ms < 8.0, "a storm frame averages well under budget (%.2f ms)" % avg_ms)
	w._enter("boughs/crown_leaf")
	await frames(2)
	check(not w.sheet_rain.active, "back in the High Boughs the rain stops")
	w.queue_free()
	await frames(2)


## The fog's CPU side in every Haar room: the player walked across the room,
## the light list rebuilt each frame. It must stay cheap and never hit
## Fog.MAX_LIGHTS (the shader would drop lanterns).
func test_fog_stays_cheap_in_every_haar_room() -> void:
	var dir := DirAccess.open("res://levels/haar")
	var problems: Array[String] = []
	var report: Array[String] = []
	for f in dir.get_files():
		if not f.ends_with(".room"):
			continue
		var id := "haar/" + f.trim_suffix(".room")
		var w := make_world({}, id)
		await frames(2)
		var fog := w.fog
		var rect := w.room.pixel_rect()
		var most := 0
		var total_usec := 0
		const STEPS := 120
		for i in STEPS:
			# Sweep the player (and so the camera) across the room, row by row.
			var at := Vector2(rect.position.x + rect.size.x * fmod(i * 0.083, 1.0), rect.position.y + rect.size.y * (0.2 + 0.6 * float(i) / STEPS))
			w.player.global_position = at
			await frames(1)
			var t0 := Time.get_ticks_usec()
			fog._update()
			total_usec += Time.get_ticks_usec() - t0
			most = maxi(most, fog.lights.size())
		var avg_ms := total_usec / 1000.0 / STEPS
		report.append("%s %.3f ms, %d lights" % [id, avg_ms, most])
		if most >= Fog.MAX_LIGHTS:
			problems.append("%s: the fog ran out of lights (%d)" % [id, most])
		if avg_ms > 0.5:
			problems.append("%s: the fog update takes %.3f ms" % [id, avg_ms])
		w.queue_free()
		await frames(2)
	print("  Fog: " + ", ".join(report))
	check(problems.is_empty(), "the fog is cheap and never short of lights: %s" % [problems])


## Gloamweaver at full tilt for 30 seconds against a mashing player who can't
## die: under the fog, with her lanterns as lights. Effects clean up after
## themselves and a frame stays well inside the 60 fps budget.
func test_widow_fight_soak_stays_lean() -> void:
	var w := make_world({}, "haar/sunken_chapel", cell_feet(10, 19))
	w.player.max_hp = 99999
	w.player.hp = 99999
	await frames(30)
	var boss := runner.get_tree().get_first_node_in_group("boss") as Gloamweaver
	check(boss != null, "Gloamweaver wakes")
	if boss == null:
		return
	boss.max_hp = 99999
	boss.hp = 99999
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
	var start_nodes := _count_nodes(w)
	var peak := start_nodes
	var total_usec := 0
	var slowest := 0
	var states := {}
	const FIGHT_FRAMES := 1800
	for f in FIGHT_FRAMES:
		_mash(w.player, rng, hold)
		# Force phase 2 halfway through, so the vault, webs and drops are soaked too.
		if f == FIGHT_FRAMES / 2 and boss.phase == 1:
			_push_to_mark(boss, 0.6)
		var t0 := Time.get_ticks_usec()
		await frames(1)
		var dt := Time.get_ticks_usec() - t0
		total_usec += dt
		slowest = maxi(slowest, dt)
		states[boss.state] = true
		peak = maxi(peak, _count_nodes(w))
		if not boss.arena.grow(32.0).has_point(boss.global_position):
			check(false, "she left the chapel at %s (%s)" % [boss.global_position, boss.state])
			break
	var avg_ms := total_usec / 1000.0 / FIGHT_FRAMES
	print("  Widow soak: %.2f ms a frame on average, slowest %.1f ms, nodes %d -> %d, states %s" % [avg_ms, slowest / 1000.0, start_nodes, peak, states.keys()])
	check(peak < start_nodes + 60, "effects never pile up (%d -> %d nodes)" % [start_nodes, peak])
	check(avg_ms < 16.6, "a frame averages under the 60 fps budget (%.2f ms)" % avg_ms)
	check(states.has("hang") or states.has("climb"), "the soak reached her vault phase")
	check(is_instance_valid(boss) and boss.state != "dead", "the fight ran its course")
	w.player.pull = Vector2.ZERO
	w.queue_free()
	await frames(2)


## the Haar Wyrm, 30 seconds against a mashing player who can't die: the plume,
## the geyser, the thermal fog, a full cistern and the rage that boils it dry
## clean up after themselves, and a frame stays well inside the 60 fps budget.
func test_hydra_fight_soak_stays_lean() -> void:
	var w := make_world({}, "haar/spring_of_haar", cell_feet(7, 19))
	w.player.max_hp = 99999
	w.player.hp = 99999
	await frames(30)
	var boss := runner.get_tree().get_first_node_in_group("boss") as HaarWyrm
	check(boss != null, "the Haar Wyrm wakes")
	if boss == null:
		return
	boss.skip_intro()
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
	var start_nodes := _count_nodes(w)
	var peak := start_nodes
	var total_usec := 0
	var slowest := 0
	var modes := {}
	var steps := {}
	const FIGHT_FRAMES := 1800
	for f in FIGHT_FRAMES:
		_mash(w.player, rng, hold)
		# From halfway in, the cistern is kept filling until a head is doused and
		# the hydra rages (the fog may boil a third away first).
		if f >= FIGHT_FRAMES / 2 and not steps.has("rage"):
			for c in w.room.get_children():
				if c is HydraIntake and not c.flowing:
					c.douse()
		# The mashing blade never ends it: each head heals before it can die.
		for h in boss.heads:
			if h.hp < HaarWyrm.HEAD_FLOOR - 20:
				h.hp = HaarWyrm.HEAD_HP
		var t0 := Time.get_ticks_usec()
		await frames(1)
		var dt := Time.get_ticks_usec() - t0
		total_usec += dt
		slowest = maxi(slowest, dt)
		for h in boss.heads:
			modes[h.mode] = true
		steps[boss.step] = true
		peak = maxi(peak, _count_nodes(w))
	var avg_ms := total_usec / 1000.0 / FIGHT_FRAMES
	print("  Hydra soak: %.2f ms a frame on average, slowest %.1f ms, nodes %d -> %d, modes %s" % [avg_ms, slowest / 1000.0, start_nodes, peak, modes.keys()])
	check(peak < start_nodes + 60, "effects never pile up (%d -> %d nodes)" % [start_nodes, peak])
	check(avg_ms < 16.6, "a frame averages under the 60 fps budget (%.2f ms)" % avg_ms)
	check(modes.has("breathe") and modes.has("sag"), "every head breathed and sagged (%s)" % [modes.keys()])
	check(steps.has("weak") and steps.has("rage"), "the full cistern doused a head and the hydra raged (%s)" % [steps.keys()])
	w.queue_free()
	await frames(2)


## The shield the soak's shielded rooms wear: the one that does the most.
const SOAK_SHIELD := "magic_shield"


func _soak_zone(zone: String, label: String, glass := false) -> void:
	var problems: Array[String] = []
	var turns := 0
	var total_usec := 0
	var counted := 0
	var thrusts := 0
	var throws := 0
	var guarded := 0
	var shield_rooms := 0
	var dir := DirAccess.open("res://levels/" + zone)
	var ids: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".room"):
			ids.append(zone + "/" + f.trim_suffix(".room"))
	ids.sort()
	if OS.get_environment("SOAK_ONLY") != "":
		ids = ids.filter(func(i: String) -> bool: return i in OS.get_environment("SOAK_ONLY").split(","))
	for id in ids:
		var w := make_world({}, id)
		var trial := _trial_for(id)
		if not trial.is_empty():
			Trials.begin(trial.id, Trials.TEMPLE, Vector2.ZERO)
		for k: String in GameState.data.abilities:
			GameState.data.abilities[k] = true
			w.player.abilities[k] = true
		_learn_the_blade(w)
		# The off hand (Sean, 2026-10-31) holds a shield or the Rune Dagger, so
		# every other room is mashed with the Warding Shield on (guard, parry, the
		# reflect and the ward) and the rest with the hand free to throw (pass 319).
		var shielded := ids.find(id) % 2 == 1
		if shielded:
			shield_rooms += 1
			GameState.data.gear.append(SOAK_SHIELD)
			GameState.wear(SOAK_SHIELD, w.player)
		w.player.max_hp = 99999
		w.player.hp = 99999
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
		await frames(2)
		var start_nodes := _count_nodes(w)
		var peak := start_nodes
		for f in (GLASS_FRAMES if glass else TOWER_FRAMES):
			_mash(w.player, rng, hold)
			if glass and f % 45 == 0 and TimeStop.ready_to_turn():
				w.player.input.stillstone_pressed = true
				turns += 1
			var t0 := Time.get_ticks_usec()
			await frames(1)
			total_usec += Time.get_ticks_usec() - t0
			counted += 1
			var p := w.player
			if p.dead or w.room == null:
				continue
			var pos := p.global_position
			if not (is_finite(pos.x) and is_finite(pos.y)):
				problems.append("%s frame %d: invalid position" % [id, f])
				break
			if not w.room.pixel_rect().grow(24.0).has_point(pos):
				problems.append("%s frame %d: left %s at %s" % [id, f, w.room.id, pos])
				break
			if _embedded(w.room, p):
				var vel := p.velocity
				await frames(3)
				if _embedded(w.room, w.player):
					problems.append("%s frame %d: embedded in %s at %s (vel %s), still at %s" % [id, f, w.room.id, pos, vel, w.player.global_position])
					break
				print("  transient overlap: %s frame %d in %s at %s vel %s" % [id, f, w.room.id, pos, vel])
			if p.is_blocking:
				guarded += 1
			peak = maxi(peak, _count_nodes(w))
		if peak > start_nodes + 400:
			problems.append("%s: nodes grew from %d to %d" % [id, start_nodes, peak])
		thrusts += w.player.thrusts
		throws += w.player.throws
		Trials.abandon()
		w.queue_free()
		await frames(2)
	check(problems.is_empty(), "%d %s rooms soaked with no problems: %s" % [ids.size(), label, problems])
	var avg_ms := total_usec / 1000.0 / maxi(counted, 1)
	print("  %s soak: %.2f ms a frame on average" % [label, avg_ms])
	check(avg_ms < 16.6, "a %s frame averages under the 60 fps budget (%.2f ms)" % [label, avg_ms])
	print("  %s soak: %d thrusts, %d daggers thrown" % [label, thrusts, throws])
	if zone != "sunken":
		# (Underwater a charge is spent: the Sunken Spring is all swimming.)
		check(thrusts > 0, "the mashing player thrust %d times across %d %s rooms" % [thrusts, ids.size(), label])
	check(throws >= ids.size() - shield_rooms, "the mashing player threw the Rune Dagger %d times across %d %s rooms with the hand free" % [throws, ids.size() - shield_rooms, label])
	if shield_rooms > 0:
		print("  %s soak: %d frames guarded across %d shielded rooms" % [label, guarded, shield_rooms])
		check(guarded >= shield_rooms * 10, "and guarded %d frames across %d rooms with the Warding Shield on" % [guarded, shield_rooms])
	if glass:
		check(turns >= ids.size() * 2, "the Stillstone was turned %d times along the way" % turns)
		TimeStop.reset()


## The Ringreader Trial built in room `id`, or {} if none is.
func _trial_for(id: String) -> Dictionary:
	for t: Dictionary in Trials.LIST:
		if String(t.get("room", "")) == id:
			return t
	return {}


## The Foreman fight at full tilt: a mashing player who can't die, 30 seconds.
## Shockwaves, boulders and falling rocks must clean up after themselves, and a
## frame must stay well inside the 60 fps budget.
func test_foreman_fight_soak_stays_lean() -> void:
	var w := make_world({}, "tower/foreman_hall", cell_feet(10, 19))
	w.player.max_hp = 99999
	w.player.hp = 99999
	await frames(30)
	var boss := runner.get_tree().get_first_node_in_group("boss") as Foreman
	check(boss != null, "the Foreman wakes")
	if boss == null:
		return
	boss.max_hp = 99999
	boss.hp = 99999
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
	var transient := 0
	var worst := 0
	var total_usec := 0
	var slowest := 0
	const FIGHT_FRAMES := 1800
	for f in FIGHT_FRAMES:
		_mash(w.player, rng, hold)
		var t0 := Time.get_ticks_usec()
		await frames(1)
		var dt := Time.get_ticks_usec() - t0
		total_usec += dt
		slowest = maxi(slowest, dt)
		transient = 0
		for c in w.room.get_children():
			if c is Shockwave or c is Rubble or c is Dust:
				transient += 1
		worst = maxi(worst, transient)
	var avg_ms := total_usec / 1000.0 / FIGHT_FRAMES
	print("  Foreman soak: %.2f ms a frame on average, slowest %.1f ms, at most %d effects live" % [avg_ms, slowest / 1000.0, worst])
	check(worst < 60, "effects never pile up (at most %d live)" % worst)
	check(avg_ms < 16.6, "a frame averages under the 60 fps budget (%.2f ms)" % avg_ms)
	check(boss.state != "dead" and is_instance_valid(boss), "the fight ran its course")
	w.queue_free()
	await frames(2)


## The HUD redraws every frame: health draining and refilling through every
## part-filled mask, poisoned half the time, a Life Fruit's half mask, the
## magic bar and the flasks changing. It must draw each frame and stay cheap.
func test_hud_soak_draws_every_frame_and_stays_lean() -> void:
	var w := make_world({}, "tower/winch_hall")
	var hud := GameHud.new()
	hud.player = w.player
	arena.add_child(hud)
	w.player.max_hp = 110
	w.player.abilities["stillstone"] = true
	await frames(2)
	var start := hud.draws
	var total_usec := 0
	const HUD_FRAMES := 600
	for f in HUD_FRAMES:
		w.player.hp = int(absf(sin(f * 0.05)) * w.player.max_hp)
		w.player.mp = fmod(f * 3.0, w.player.max_mp + 1.0)
		w.player.poison_left = 1.0 if (f / 60) % 2 == 1 else 0.0
		w.player.flask_charges = f % (w.player.flask_max + 1)
		if f % 200 == 0:
			TimeStop.reset()
			TimeStop.start()
		var t0 := Time.get_ticks_usec()
		await frames(1)
		total_usec += Time.get_ticks_usec() - t0
	var drawn := hud.draws - start
	var avg_ms := total_usec / 1000.0 / HUD_FRAMES
	print("  HUD soak: %.2f ms a frame on average, %d draws" % [avg_ms, drawn])
	check(drawn >= HUD_FRAMES - 2, "the HUD redraws every frame (%d of %d)" % [drawn, HUD_FRAMES])
	check(avg_ms < 16.6, "a frame with the HUD averages under the 60 fps budget (%.2f ms)" % avg_ms)
	w.player.poison_left = 0.0
	hud.queue_free()
	w.queue_free()
	await frames(2)


func _count_nodes(w: World) -> int:
	return w.room.get_child_count() if w.room != null else 0


## Grain Road hops and lift rides, back and forth, with mashing in between:
## every arrival is in the right room, on open floor.
func test_grain_road_and_lift_travel_soak() -> void:
	var w := make_world({}, "tower/kettleforge")
	await frames(2)
	var menu := ListMenu.new()
	arena.add_child(menu)
	GameState.set_flag("spring:heartwood")
	GameState.set_flag("boss:durgan")
	for stop: Array in [["hearthroot/ringreader_temple", 22], ["heartwood/amberlee", 12], ["tower/kettleforge", 10]]:
		GameState.meet_ringreader(stop[0], Vector2(int(stop[1]) * Room.TILE + 8, 20 * Room.TILE))
	var problems: Array[String] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
	w.player.input.scripted = true
	for hop in 9:
		var stops := GameState.grain_stops(w.room.id)
		Menus.open_grain_road(arena.get_tree(), w.player)
		menu.cursor = hop % stops.size()
		var to: String = stops[menu.cursor]
		menu.confirm()
		await frames(3)
		if w.room.id != to:
			problems.append("hop %d: in %s, not %s" % [hop, w.room.id, to])
			break
		if _embedded(w.room, w.player) or not w.room.pixel_rect().has_point(w.player.global_position):
			problems.append("hop %d: bad arrival in %s at %s" % [hop, to, w.player.global_position])
		for f in 40:
			_mash(w.player, rng, hold)
			await frames(1)
		w.player.input.move_x = 0
	# The lift, down and up three times, picking the stop from its menu.
	w.travel("tower/kettleforge", Vector2(71 * Room.TILE + 8, 20 * Room.TILE))
	await frames(3)
	for ride in 6:
		var cage: LiftCage = null
		for c in w.room.get_children():
			if c is LiftCage:
				cage = c
		var to: String = cage.destination()[0]
		cage.interact(w.player)
		await frames(1)
		# The cage asks for a stop: pick its usual one.
		menu.cursor = cage.other_stops().map(func(st: Array) -> String: return st[0]).find(to)
		menu.confirm()
		await frames(3)
		if w.room.id != to or _embedded(w.room, w.player):
			problems.append("ride %d: in %s at %s" % [ride, w.room.id, w.player.global_position])
			break
	check(problems.is_empty(), "travel soak found no problems: %s" % [problems])
	menu.queue_free()


func test_bloom_fight_soak_stays_lean() -> void:
	var w := make_world({}, "boughs/crown_leaf", cell_feet(9, 19))
	w.player.max_hp = 99999
	w.player.hp = 99999
	w.player.abilities["stride"] = true
	await frames(30)
	var boss := runner.get_tree().get_first_node_in_group("boss") as Snapcrown
	check(boss != null, "Snapcrown wakes")
	if boss == null:
		return
	boss.max_hp = 99999
	boss.hp = 99999
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
	var start_nodes := _count_nodes(w)
	var peak := start_nodes
	var total_usec := 0
	var slowest := 0
	var states := {}
	var most_brood := 0
	var bites: Array[String] = []  # phase 2 bites: count@jaws x/root x
	var last_state := ""
	var leaf_y := w.player.global_position.y
	const FIGHT_FRAMES := 1800
	var ran := 0
	# Up to 20 s more in phase 2 if the leaf has not been torn yet: where the
	# jaws come down rides on the mashing and the uprooted lunges.
	for f in FIGHT_FRAMES + 1200:
		if f >= FIGHT_FRAMES and boss.gaps.size() >= 1:
			break
		ran += 1
		_mash(w.player, rng, hold)
		if f % 300 == 60 and boss.phase == 1 and w.player.is_on_floor() and not w.player.dead:
			# Into biting range now and then: the mashing alone may keep its
			# distance for the whole fight, and then the bite is never soaked.
			var side := -1.0 if w.player.global_position.x < boss.global_position.x else 1.0
			w.player.teleport(Vector2(boss.global_position.x + side * Snapcrown.BITE_RANGE * 0.5, w.player.global_position.y))
		elif boss.phase >= 2 and boss.state in ["idle", "bite_tell"]:
			# Phase 2: while the jaws choose and aim, the player stands far
			# enough out on the leaf for them to tear it, over its wider
			# stretch (pass 263: a bite close to the root or a wall never
			# tears, and the mashing walked back under the root, so the
			# floor's tearing had gone unsoaked).
			var side := 1.0 if boss.arena.end.x - boss.global_position.x > boss.global_position.x - boss.arena.position.x else -1.0
			w.player.teleport(Vector2(boss.global_position.x + side * Snapcrown.BITE_RANGE * 0.9, leaf_y))
		# Phase 2 halfway through, so the leaf gets torn too.
		if f == FIGHT_FRAMES / 2 and boss.phase == 1:
			boss.phase = 2
		var t0 := Time.get_ticks_usec()
		await frames(1)
		var dt := Time.get_ticks_usec() - t0
		total_usec += dt
		slowest = maxi(slowest, dt)
		if boss.state == "gape" and last_state != "gape" and boss.phase >= 2:
			bites.append("%d@%d/%d" % [int(boss.get("_bites")), int(boss.get("_to").x), int(boss.global_position.x)])
		last_state = boss.state
		states[boss.state] = true
		peak = maxi(peak, _count_nodes(w))
		most_brood = maxi(most_brood, boss.brood_alive())
	var avg_ms := total_usec / 1000.0 / ran
	print("  Bloom soak: %d frames, %.2f ms a frame on average, slowest %.1f ms, nodes %d -> %d, gaps %d, states %s, bites %s" % [ran, avg_ms, slowest / 1000.0, start_nodes, peak, boss.gaps.size(), states.keys(), bites])
	check(peak < start_nodes + 60, "effects never pile up (%d -> %d nodes)" % [start_nodes, peak])
	check(avg_ms < 16.6, "a frame averages under the 60 fps budget (%.2f ms)" % avg_ms)
	check(states.has("gape") and states.has("whip"), "bites and lashes were soaked")
	check(boss.gaps.size() >= 1 and boss.gaps.size() <= Snapcrown.MAX_GAPS, "the leaf was torn, never past %d gaps (%d; bites %s, arena %s)" % [Snapcrown.MAX_GAPS, boss.gaps.size(), bites, boss.arena])
	check(states.has("brood_tell") and most_brood >= 1 and most_brood <= Snapcrown.BROOD, "the brood was loosed, never more than %d at once (%d)" % [Snapcrown.BROOD, most_brood])
	# Struck down with its brood in the air, the Bloom takes every Mothling with
	# it: none is left flying, and none outlives the room's settling.
	if boss.brood_alive() == 0:
		boss.phase = 2
		boss.call("_loose_brood")
		await frames(40)
	check(boss.brood_alive() >= 1, "a brood is flying when the Bloom falls")
	boss.hp = 1
	boss.take_hit(1, Vector2.UP)
	var left := 0
	for i in 240:
		await frames(1)
		left = w.room.get_children().filter(func(n: Node) -> bool: return n is Mothling).size()
		if left == 0:
			break
	check(boss.brood_alive() == 0 and left == 0, "no Mothling outlives the Bloom (%d left)" % left)
	w.queue_free()
	await frames(2)


## The Storm Roc fight at full tilt: a mashing player who can't die, 30 seconds,
## with the conduits woken every ten seconds so it is grounded and rises again.
func test_roc_fight_soak_stays_lean() -> void:
	var w := make_world({}, "spires/roost", cell_feet(9, 25))
	w.player.max_hp = 99999
	w.player.hp = 99999
	w.player.abilities["stride"] = true
	await frames(30)
	var boss := runner.get_tree().get_first_node_in_group("boss") as Skyrend
	check(boss != null, "Skyrend wakes")
	if boss == null:
		return
	boss.max_hp = 99999
	boss.hp = 99999
	var rng := RandomNumberGenerator.new()
	rng.seed = 37
	var bolts := 0
	var seen := {}
	var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
	var start_nodes := _count_nodes(w)
	var peak := start_nodes
	var total_usec := 0
	var slowest := 0
	var states := {}
	const FIGHT_FRAMES := 1800
	for f in FIGHT_FRAMES:
		_mash(w.player, rng, hold)
		if f % 600 == 450:
			for c in runner.get_tree().get_nodes_in_group("conductor"):
				(c as Conduit).power()
		# The storm breaks halfway through, so its bolts are soaked too.
		if f == FIGHT_FRAMES / 2:
			boss.phase = 2
		var t0 := Time.get_ticks_usec()
		await frames(1)
		var dt := Time.get_ticks_usec() - t0
		total_usec += dt
		slowest = maxi(slowest, dt)
		states[boss.state] = true
		peak = maxi(peak, _count_nodes(w))
		for c in w.room.get_children():
			if c is StormStrike and not seen.has(c.get_instance_id()):
				seen[c.get_instance_id()] = true
				bolts += 1
	var avg_ms := total_usec / 1000.0 / FIGHT_FRAMES
	print("  Roc soak: %.2f ms a frame on average, slowest %.1f ms, nodes %d -> %d, states %s" % [avg_ms, slowest / 1000.0, start_nodes, peak, states.keys()])
	check(peak < start_nodes + 60, "effects never pile up (%d -> %d nodes)" % [start_nodes, peak])
	check(avg_ms < 16.6, "a frame averages under the 60 fps budget (%.2f ms)" % avg_ms)
	check(states.has("dive") and states.has("volley_tell") and states.has("grounded") and states.has("rise"), "dives, volleys and groundings were soaked")
	check(bolts > 0, "and storm bolts (%d)" % bolts)
	check(boss.state != "dead" and is_instance_valid(boss), "the fight ran its course")
	w.queue_free()
	await frames(2)


## The Waterfall Stair's two falls, flowing and frozen in turn: their streaks
## are two scrolled textures each, so a frame stays cheap.
func test_waterfalls_stay_cheap() -> void:
	var w := make_world({}, "vorrhallow/waterfall_stair")
	w.player.abilities["stillstone"] = true
	await frames(2)
	var falls: Array = w.room.get_children().filter(func(c: Node) -> bool: return c is Waterfall)
	check(falls.size() == 2 and falls.all(func(f: Waterfall) -> bool: return f._streaks.size() == 2), "each fall draws from two streak textures")
	var total_usec := 0
	const FALL_FRAMES := 600
	for f in FALL_FRAMES:
		if f % 300 == 0:
			TimeStop.reset()
			TimeStop.start()
		var t0 := Time.get_ticks_usec()
		await frames(1)
		total_usec += Time.get_ticks_usec() - t0
	var avg_ms := total_usec / 1000.0 / FALL_FRAMES
	print("  Waterfall Stair: %.2f ms a frame on average" % avg_ms)
	check(avg_ms < 8.0, "a frame by the falls averages well under budget (%.2f ms)" % avg_ms)
	TimeStop.reset()
	w.queue_free()
	await frames(2)


## Thane Vorrund's fight at full tilt: a mashing player who can't die, 30 seconds,
## the second half on his throne with the Stillstone turned whenever it is ready.
func test_thane_vorrund_fight_soak_stays_lean() -> void:
	var w := make_world({}, "vorrhallow/throne_hall", cell_feet(10, 19))
	w.player.max_hp = 99999
	w.player.hp = 99999
	w.player.abilities["stillstone"] = true
	await frames(30)
	var boss := runner.get_tree().get_first_node_in_group("boss") as ThaneVorrund
	check(boss != null, "Thane Vorrund wakes")
	if boss == null:
		return
	boss.max_hp = 99999
	boss.hp = 99999
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
	var start_nodes := _count_nodes(w)
	var peak := start_nodes
	var total_usec := 0
	var slowest := 0
	var states := {}
	var shards := 0
	var seen := {}
	var guards := {}
	var most_guards := 0
	const FIGHT_FRAMES := 1800
	for f in FIGHT_FRAMES:
		_mash(w.player, rng, hold)
		if f == FIGHT_FRAMES / 3:
			boss.phase = 2
			boss._to_throne()
		if boss.phase == 2 and TimeStop.ready_to_turn() and f % 120 == 0:
			TimeStop.start()
		var t0 := Time.get_ticks_usec()
		await frames(1)
		var dt := Time.get_ticks_usec() - t0
		total_usec += dt
		slowest = maxi(slowest, dt)
		states[boss.state] = true
		peak = maxi(peak, _count_nodes(w))
		for c in w.room.get_children():
			if c is CrystalShard and not seen.has(c.get_instance_id()):
				seen[c.get_instance_id()] = true
				shards += 1
		# His household guard (pass 268): one knight at a time, never more than
		# GUARDS in the fight (pass 271).
		var standing := 0
		for c in w.room.get_children():
			if c is ShadeKnight and not c.dead:
				standing += 1
				guards[c.get_instance_id()] = true
		most_guards = maxi(most_guards, standing)
	TimeStop.reset()
	var avg_ms := total_usec / 1000.0 / FIGHT_FRAMES
	print("  King soak: %.2f ms a frame on average, slowest %.1f ms, nodes %d -> %d, states %s, guards %d (most at once %d)" % [avg_ms, slowest / 1000.0, start_nodes, peak, states.keys(), guards.size(), most_guards])
	check(peak < start_nodes + 60, "effects never pile up (%d -> %d nodes)" % [start_nodes, peak])
	check(avg_ms < 16.6, "a frame averages under the 60 fps budget (%.2f ms)" % avg_ms)
	check(states.has("chop_tell") and states.has("ward") and states.has("summon_tell"), "duels and the throne were soaked")
	check(shards > 0, "and shard waves (%d)" % shards)
	check(guards.size() >= 1 and guards.size() == boss.guards_called, "and his household guard came (%d called, %d seen)" % [boss.guards_called, guards.size()])
	check(most_guards <= 1 and boss.guards_called <= ThaneVorrund.GUARDS, "one knight at a time, %d at most (%d at once, %d called)" % [ThaneVorrund.GUARDS, most_guards, boss.guards_called])
	check(boss.state != "dead" and is_instance_valid(boss), "the fight ran its course")
	# Felled mid-soak, with whatever guard stands (his ward and armour turn a
	# test's blow, so the fall is called straight): none outlives him, and the
	# hall settles back to what it held before the fight.
	var stood := boss.guard_stands()
	boss.hp = 0
	boss.die()
	Feel.reset()  # the fall's slow motion runs on the wall clock, which a headless run outpaces
	await frames(240)
	var left := 0
	for c in w.room.get_children():
		if c is ShadeKnight and not c.dead:
			left += 1
	check(stood, "a knight of his guard still stood when he fell")
	check(left == 0, "no knight of his guard outlives him (%d, one stood at his fall: %s)" % [left, stood])
	# What is left besides dust (which a slow CI machine may still have in
	# the air) and his gold: the hall's own nodes, no shard or knight.
	var kinds := {}
	var settled := 0
	for c in w.room.get_children():
		if c is Dust or c is Coin:
			continue
		settled += 1
		var k: String = c.get_script().get_global_name() if c.get_script() else c.get_class()
		kinds[k] = int(kinds.get(k, 0)) + 1
	check(settled <= start_nodes, "the hall settles after the fall (%d -> %d nodes, dust and gold aside: %s)" % [start_nodes, settled, kinds])


func test_likeness_fight_soak_stays_lean() -> void:
	var w := make_world({}, "vorrhallow/evercrown_gate", cell_feet(14, 19))
	w.player.max_hp = 99999
	w.player.hp = 99999
	w.player.has_shield = true
	await frames(30)
	var boss := runner.get_tree().get_first_node_in_group("boss") as Likeness
	check(boss != null, "the Likeness wakes")
	if boss == null:
		return
	boss.max_hp = 99999
	boss.hp = 99999
	var rng := RandomNumberGenerator.new()
	rng.seed = 74
	var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
	var start_nodes := _count_nodes(w)
	var peak := start_nodes
	var total_usec := 0
	var slowest := 0
	var states := {}
	const FIGHT_FRAMES := 3000
	var doubles := 0
	for f in FIGHT_FRAMES:
		# Mash for a while, then stand still so it comes through the mirror.
		# Halfway the mirror breaks and it fights on its own, with arcana.
		if f == 1200:
			GameState.data.skills = ["clear_mind"]
			boss._break_free()
		if f == 2000:
			# The last fifth: it splits in two (the soak's mashing bursts the false one).
			boss.phase = 3
			boss._split()
		if is_instance_valid(boss.double):
			doubles += 1
		if f >= 1200 or f % 500 < 330:
			_mash(w.player, rng, hold)
		else:
			w.player.input.clear()
		var t0 := Time.get_ticks_usec()
		await frames(1)
		var dt := Time.get_ticks_usec() - t0
		total_usec += dt
		slowest = maxi(slowest, dt)
		states[boss.state] = true
		peak = maxi(peak, _count_nodes(w))
	var avg_ms := total_usec / 1000.0 / FIGHT_FRAMES
	print("  Likeness soak: %.2f ms a frame on average, slowest %.1f ms, nodes %d -> %d, states %s" % [avg_ms, slowest / 1000.0, start_nodes, peak, states.keys()])
	check(peak < start_nodes + 60, "effects never pile up (%d -> %d nodes)" % [start_nodes, peak])
	check(avg_ms < 16.6, "a frame averages under the 60 fps budget (%.2f ms)" % avg_ms)
	check(states.has("echo") and states.has("rise"), "the soak saw it echo your swings and come through the mirror (%s)" % [states.keys()])
	check(states.has("stalk") and states.has("cast_tell"), "and fight on its own, casting (%s)" % [states.keys()])
	check(states.has("split") and doubles > 0, "and split in two (%d frames with a double)" % doubles)
	GameState.data.skills = []
	check(boss._history.size() < 60, "its memory of you stays short (%d frames)" % boss._history.size())


func test_everbloom_avatar_fight_soak_stays_lean() -> void:
	var w := make_world({}, "evercrown/throne", cell_feet(10, 19))
	w.player.max_hp = 99999
	w.player.hp = 99999
	w.player.has_shield = true
	await frames(30)
	var boss := runner.get_tree().get_first_node_in_group("boss") as EvilAvatar
	check(boss != null, "the Everbloom's avatar wakes")
	if boss == null:
		return
	boss.max_hp = 99999
	boss.hp = 99999
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
	var start_nodes := _count_nodes(w)
	var peak := start_nodes
	var total_usec := 0
	var slowest := 0
	var states := {}
	const FIGHT_FRAMES := 2400
	for f in FIGHT_FRAMES:
		if f == FIGHT_FRAMES / 2:
			boss.phase = 2
		_mash(w.player, rng, hold)
		var t0 := Time.get_ticks_usec()
		await frames(1)
		var dt := Time.get_ticks_usec() - t0
		total_usec += dt
		slowest = maxi(slowest, dt)
		states[boss.state] = true
		peak = maxi(peak, _count_nodes(w))
	var avg_ms := total_usec / 1000.0 / FIGHT_FRAMES
	print("  Avatar soak: %.2f ms a frame on average, slowest %.1f ms, nodes %d -> %d, states %s" % [avg_ms, slowest / 1000.0, start_nodes, peak, states.keys()])
	check(peak < start_nodes + 60, "effects never pile up (%d -> %d nodes)" % [start_nodes, peak])
	check(avg_ms < 16.6, "a frame averages under the 60 fps budget (%.2f ms)" % avg_ms)
	check(states.has("cleave_tell") and states.has("pull") and (states.has("lunge_tell") or states.has("rain_tell")), "its attacks were soaked (%s)" % [states.keys()])
	check(boss.state != "dead" and is_instance_valid(boss), "the fight ran its course")


func test_everbloom_core_fight_soak_stays_lean() -> void:
	var w := make_world({}, "evercrown/veins", cell_feet(8, 65))
	w.player.max_hp = 99999
	w.player.hp = 99999
	w.player.abilities["stillstone"] = true
	await frames(30)
	var boss := runner.get_tree().get_first_node_in_group("boss") as EvilCore
	check(boss != null, "the core wakes")
	if boss == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 82
	var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
	var start_nodes := _count_nodes(w)
	var peak := start_nodes
	var total_usec := 0
	var states := {}
	var beams := 0
	var seen := {}
	const FIGHT_FRAMES := 2400
	for f in FIGHT_FRAMES:
		if f == FIGHT_FRAMES / 2:
			boss.phase = 2
		if f % 400 == 200 and TimeStop.ready_to_turn():
			TimeStop.start()
		_mash(w.player, rng, hold)
		var t0 := Time.get_ticks_usec()
		await frames(1)
		total_usec += Time.get_ticks_usec() - t0
		states[boss.state] = true
		peak = maxi(peak, _count_nodes(w))
		for c in w.room.get_children():
			if c is CoreBeam and not seen.has(c.get_instance_id()):
				seen[c.get_instance_id()] = true
				beams += 1
	TimeStop.reset()
	var avg_ms := total_usec / 1000.0 / FIGHT_FRAMES
	print("  Core soak: %.2f ms a frame on average, nodes %d -> %d, %d beams" % [avg_ms, start_nodes, peak, beams])
	check(peak < start_nodes + 60, "effects never pile up (%d -> %d nodes)" % [start_nodes, peak])
	check(avg_ms < 16.6, "a frame averages under the 60 fps budget (%.2f ms)" % avg_ms)
	check(beams > 10, "it fired beams all the while (%d)" % beams)


func test_everbloom_heart_fight_soak_stays_lean() -> void:
	GameState.new_game()
	GameState.data.equipment["blade"] = "severance"
	var w := make_world({}, "evercrown/heart", cell_feet(14, 20))
	w.player.max_hp = 99999
	w.player.hp = 99999
	w.player.abilities["stillstone"] = true
	GameState.data.equipment["blade"] = "severance"
	await frames(30)
	var boss := runner.get_tree().get_first_node_in_group("boss") as EvilHeart
	check(boss != null, "the heart wakes")
	if boss == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 83
	var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
	var start_nodes := _count_nodes(w)
	var peak := start_nodes
	var total_usec := 0
	var states := {}
	const FIGHT_FRAMES := 2400
	for f in FIGHT_FRAMES:
		if f == FIGHT_FRAMES / 3:
			boss.phase = 2
		if f == FIGHT_FRAMES * 2 / 3:
			boss.phase = 3
		if f % 400 == 200 and TimeStop.ready_to_turn():
			TimeStop.start()
		_mash(w.player, rng, hold)
		var t0 := Time.get_ticks_usec()
		await frames(1)
		total_usec += Time.get_ticks_usec() - t0
		if is_instance_valid(boss):
			states[boss.state] = true
		peak = maxi(peak, _count_nodes(w))
	TimeStop.reset()
	var avg_ms := total_usec / 1000.0 / FIGHT_FRAMES
	print("  Heart soak: %.2f ms a frame on average, nodes %d -> %d, states %s" % [avg_ms, start_nodes, peak, states.keys()])
	check(peak < start_nodes + 80, "effects never pile up (%d -> %d nodes)" % [start_nodes, peak])
	check(avg_ms < 16.6, "a frame averages under the 60 fps budget (%.2f ms)" % avg_ms)
	check(states.has("bound") and states.has("float"), "the roots bound it and let it go again")



## The guardians with no fight soak of their own (pass 279): each fought for 20
## seconds against a mashing player who can't die, pushed past its phase marks
## halfway so its later moves come too. Effects must not pile up, the room must
## settle back once the mashing stops, and a frame must stay inside the budget.
func test_every_other_guardian_fight_soak_stays_lean() -> void:
	const GUARDIANS := ["gnarlmaw", "clockwork_alpha", "bark_captain", "hag_matriarch", "durgan", "drowned_warden"]
	const FIGHT_FRAMES := 1200
	var rooms := {}
	var w0 := make_world({}, "hearthroot/west_gate")
	for id: String in w0.catalog:
		var b := String(w0.catalog[id].get("boss", ""))
		if b != "":
			rooms[b] = id
	w0.queue_free()
	await frames(2)
	for id: String in GUARDIANS:
		check(rooms.has(id), "%s has an arena" % id)
		if not rooms.has(id):
			continue
		GameState.new_game()
		var w := make_world({}, rooms[id])
		w.player.max_hp = 99999
		w.player.hp = 99999
		await frames(5)
		var ar := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
		ar._start()
		await frames(2)
		var boss: Node2D = ar.boss
		var full: int = boss.hp
		# Down on the arena floor, away from the door it came in by.
		if "arena" in boss:
			var a: Rect2 = boss.arena
			w.player.teleport(Vector2(a.get_center().x, a.end.y - 1.0))
		var room := w.room
		var floor_hp := ceili(full * 0.9)
		var rng := RandomNumberGenerator.new()
		rng.seed = 279
		var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
		var start_nodes := _count_nodes(w)
		var peak := start_nodes
		var total_usec := 0
		var phases := {}
		for f in FIGHT_FRAMES:
			if f == FIGHT_FRAMES / 2:
				floor_hp = ceili(full * 0.15)
				boss.hp = floor_hp + 1
				# A blow lands the phase change on those that check it as they are hit.
				if boss.has_method("take_hit"):
					boss.take_hit(1, Vector2.RIGHT)
			# It can't fall: the soak is of the fight, not of its end.
			boss.hp = maxi(boss.hp, floor_hp)
			w.player.hp = 99999
			_mash(w.player, rng, hold)
			var t0 := Time.get_ticks_usec()
			await frames(1)
			total_usec += Time.get_ticks_usec() - t0
			peak = maxi(peak, _count_nodes(w))
			if w.room != room or not is_instance_valid(boss) or boss.dead:
				break
			phases[boss.phase] = true
		check(w.room == room and is_instance_valid(boss) and not boss.dead, "%s: the fight ran its course" % id)
		if w.room != room or not is_instance_valid(boss):
			w.queue_free()
			await frames(2)
			continue
		# Hands off: what the fight threw must clear away again.
		w.player.input.clear()
		var settled := 0
		for f in 240:
			await frames(1)
			w.player.hp = 99999
			boss.hp = maxi(boss.hp, floor_hp)
		var kinds := {}
		var spikes := 0
		for c in w.room.get_children():
			if c is Spikes:
				spikes += 1
			# (Gnarlmaw's torn floor and its spikes are meant to stay.)
			if not (c is Dust or c is Coin or c is Spikes):
				settled += 1
				var k := String(c.get_script().get_global_name()) if c.get_script() else c.get_class()
				kinds[k] = kinds.get(k, 0) + 1
		var avg_ms := total_usec / 1000.0 / FIGHT_FRAMES
		print("  %s soak: %.2f ms a frame on average, nodes %d -> peak %d, settled %d, phases %s" % [id, avg_ms, start_nodes, peak, settled, phases.keys()])
		check(peak < start_nodes + 60, "%s: effects never pile up (%d -> %d nodes)" % [id, start_nodes, peak])
		check(settled <= start_nodes + 6, "%s: the room settles once the mashing stops (%d -> %d nodes: %s)" % [id, start_nodes, settled, kinds])
		# The floor tears once: one spike per torn column (26), not a new row each roar.
		check(spikes <= 26, "%s: spikes never stack (%d)" % [id, spikes])
		check(phases.size() >= 2, "%s: the soak reached its later phase (%s)" % [id, phases.keys()])
		check(avg_ms < 16.6, "%s: a frame averages under the 60 fps budget (%.2f ms)" % [id, avg_ms])
		w.queue_free()
		await frames(2)


## Every room id in the game (not the gym), in a fixed order.
func _all_room_ids(w: World) -> Array:
	var ids := w.catalog.keys()
	ids.sort()
	return ids


## Clears foes from the room so an arrival is judged on the room, not on a fight.
func _clear_foes(w: World) -> void:
	for c in w.room.get_children():
		if c is Enemy:
			c.queue_free()


## Walks through every door of every room, one at a time, starting fresh in its
## room each time: the far side must load, put the player in its matching door
## inside the room and out of the walls, standing (side doors) and unhurt, and a
## lap of the whole game must leave no nodes behind.
func test_every_door_in_the_game_lands_you_safely() -> void:
	var w := make_world({}, "hearthroot/west_gate")
	w.player.max_hp = 99999
	w.player.hp = 99999
	for a: String in w.player.abilities:
		w.player.abilities[a] = true
	# The gate of the Evercrown stands open for whoever reaches the far side of it.
	GameState.data.rings = CrownGate.RINGS.duplicate()
	GameState.set_flag(CrownGate.FLAG)
	await frames(5)
	var start_count := runner.get_tree().get_node_count()
	var problems: Array[String] = []
	var walked := 0
	for id: String in _all_room_ids(w):
		w.start(id)
		var doors: Dictionary = w.room.doors.duplicate()
		for n: int in doors:
			var d: Dictionary = doors[n]
			w.start(id)
			_clear_foes(w)
			await frames(1)
			var hp := w.player.hp
			w.use_door(n)
			await frames(1)
			_clear_foes(w)
			await frames(20)
			walked += 1
			var p := w.player
			var where := "%s door %d -> %s" % [id, n, w.room.id]
			if w.room.id == id:
				problems.append(where + ": never left")
			elif p.dead or p.hp < hp:
				problems.append(where + ": hurt on arrival")
			elif _embedded(w.room, p) or not w.room.pixel_rect().has_point(p.global_position):
				problems.append(where + ": inside a wall at %s" % p.global_position)
			elif String(d.edge) in ["left", "right"] and not p.is_on_floor() and not p.swimming:
				problems.append(where + ": not standing at %s" % p.global_position)
	w.start("hearthroot/west_gate")
	await frames(10)
	var end_count := runner.get_tree().get_node_count()
	print("  Door walk: %d doors, nodes %d -> %d" % [walked, start_count, end_count])
	check(walked > 150, "walked every door in the game (%d)" % walked)
	check(problems.is_empty(), "every door lands you safely: %s" % [problems])
	check(end_count - start_count < 40, "and a lap of the whole game leaves nothing behind (%d -> %d nodes)" % [start_count, end_count])



## Every floor and ceiling door, played with the real controller and no abilities
## (bible 4, pass 299). Down through a floor door you fall onto footing the
## spike set-back keeps (bible 6.13): on tiles, unhurt, no hazard beside it. Up
## through a ceiling door you pop out of the floor door on the far side and,
## steering one way or the other, land beside it instead of dropping back in,
## even with the steer begun a quarter second after you arrive (pass 304), a
## player's time to see the new room and react.
## Its gates stand open, as they do whenever the far side can be reached.
func test_every_door_up_or_down_lands_you_on_footing() -> void:
	var w := make_world({}, "hearthroot/west_gate")
	w.player.max_hp = 99999
	w.player.hp = 99999
	for a: String in w.player.abilities:
		w.player.abilities[a] = false
	GameState.data.rings = CrownGate.RINGS.duplicate()
	GameState.set_flag(CrownGate.FLAG)
	# The flue damper (Durgan) and the bound fog over the Veiled Rise (the
	# Lantern Key) stand open before you can reach the rooms above them.
	GameState.set_flag(FlueDamper.FLAG)
	GameState.set_flag("curtain:haar/lantern_landing")
	w.player.input.scripted = true
	await frames(5)
	var problems: Array[String] = []
	var downs := 0
	var ups := 0
	for id: String in _all_room_ids(w):
		w.start(id)
		var doors: Dictionary = w.room.doors.duplicate()
		for n: int in doors:
			var d: Dictionary = doors[n]
			if not String(d.edge) in ["top", "bottom"]:
				continue
			var where := "%s door %d -> %s" % [id, n, d.target]
			var landed := ""
			for side: int in ([0] if d.edge == "bottom" else [-1, 1]):
				landed = await _ride_door(w, id, n, side, 0 if d.edge == "bottom" else REACT_FRAMES)
				if landed == "":
					break
			if d.edge == "bottom":
				downs += 1
			else:
				ups += 1
			if landed != "":
				problems.append("%s: %s" % [where, landed])
	w.player.input.move_x = 0
	w.player.input.scripted = false
	print("  Up and down: %d floor doors, %d ceiling doors" % [downs, ups])
	check(downs > 20 and ups > 20, "rode every floor and ceiling door (%d down, %d up)" % [downs, ups])
	check(problems.is_empty(), "every door up or down lands you on footing: %s" % [problems])


## Frames a player takes to see the room a ceiling door brought them to and
## steer (pass 304): a quarter second.
const REACT_FRAMES := 15


## Takes door `n` of room `id`, steering `side` from `wait` frames after
## arriving on the far side, and waits for the player to come to rest there. Returns "" when they stand (or swim)
## on footing the set-back keeps, else what went wrong.
func _ride_door(w: World, id: String, n: int, side: int, wait := 0) -> String:
	w.start(id)
	_clear_foes(w)
	w.player.input.move_x = 0
	await frames(1)
	var hp := w.player.hp
	w.use_door(n)
	var target := ""
	var arrived := 0
	for f in 240:
		await frames(1)
		if w.busy:
			continue
		var p := w.player
		if target == "":
			if w.room.id == id:
				continue
			target = w.room.id
			arrived = f
			_clear_foes(w)
		p.input.move_x = side if f - arrived >= wait else 0
		if w.room.id != target:
			p.input.move_x = 0
			return "fell back to %s" % w.room.id
		if p.dead or p.hp < hp:
			p.input.move_x = 0
			return "hurt at %s" % p.global_position
		if p.swimming:
			p.input.move_x = 0
			return ""
		if p.is_on_floor():
			p.input.move_x = 0
			await frames(2)
			if p._hazard_near():
				return "landed by a hazard at %s" % p.global_position
			if p.safe_position.distance_to(p.global_position) > 2.0:
				return "the set-back would not keep %s (it holds %s)" % [p.global_position, p.safe_position]
			return ""
	w.player.input.move_x = 0
	return "never landed (at %s in %s)" % [w.player.global_position, w.room.id]

## Rests at every shrine in the game, then loads that save into a fresh world
## the way Continue does: you wake in the shrine's room, standing, out of the walls.
func test_every_shrine_saves_and_continues_where_you_rested() -> void:
	var slot_was := GameState.slot
	var w := make_world({}, "hearthroot/west_gate")
	await frames(2)
	const SLOT := 9
	GameState.slot = SLOT
	var problems: Array[String] = []
	var shrines := 0
	for id: String in _all_room_ids(w):
		w.start(id)
		var found: Array = w.room.get_children().filter(func(c: Node) -> bool: return c is SaveShrine)
		if found.is_empty():
			continue
		for shrine: SaveShrine in found:
			shrines += 1
			w.player.teleport(shrine.global_position)
			shrine.interact(w.player)
			GameState.data.save_room = ""
			if not GameState.load_game(SLOT) or GameState.data.save_room != id:
				problems.append("%s: the save did not come back" % id)
				continue
			var w2 := World.new()
			w2.instant = true
			arena.add_child(w2)
			w2.start(String(GameState.data.save_room), Vector2(float(GameState.data.save_pos[0]), float(GameState.data.save_pos[1])))
			w2.player.input.scripted = true
			await frames(20)
			var p := w2.player
			if w2.room.id != id or p.dead or not p.is_on_floor() or _embedded(w2.room, p):
				problems.append("%s: woke at %s (on floor %s)" % [w2.room.id, p.global_position, p.is_on_floor()])
			w2.queue_free()
			await frames(1)
	GameState.delete_save(SLOT)
	check(shrines >= 15, "rested at every shrine (%d)" % shrines)
	check(problems.is_empty(), "every shrine's save continues where you rested: %s" % [problems])
	GameState.slot = slot_was




const JOURNEY_DOORS := 160
const JOURNEY_SAVE_EVERY := 20
const JOURNEY_SLOT := 8
## Doors walked per lap of the post-game journey (pass 144).
const POSTGAME_DOORS := 100

## A long run through the whole game the way a player strings it together: a
## walk from door to door (leaning toward rooms not seen yet) with real play
## between (mashing, foes left in), a rest and a Continue into a fresh world every
## few rooms, and the pause and skills screens opened and shut on the way. It runs
## twice: the first lap may fill caches, the second must leave nothing behind
## (live objects, orphan nodes), and no frame of play may spike far past budget.
func test_a_long_journey_through_the_whole_game_stays_lean() -> void:
	var slot_was := GameState.slot
	GameState.slot = JOURNEY_SLOT
	var first: Dictionary = await _journey(1987)
	var obj0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var orphans0 := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var nodes0 := runner.get_tree().get_node_count()
	var second: Dictionary = await _journey(2026)
	var obj1 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var orphans1 := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var nodes1 := runner.get_tree().get_node_count()
	GameState.delete_save(JOURNEY_SLOT)
	for r: Dictionary in [first, second]:
		print("  Journey: %d rooms, %d reloads, worst frame %.1f ms (%s), %d over 33 ms, host paused %d" % [r.rooms, r.reloads, r.worst / 1000.0, r.where, r.spikes, r.paused])
	print("  Second lap: objects %d -> %d, orphans %d -> %d, nodes %d -> %d" % [obj0, obj1, orphans0, orphans1, nodes0, nodes1])
	for r: Dictionary in [first, second]:
		check(r.problems.is_empty(), "every rest continues where it was taken: %s" % [r.problems])
		check(r.rooms >= 30, "the walk saw much of the world (%d rooms)" % r.rooms)
		check(r.reloads >= JOURNEY_DOORS / JOURNEY_SAVE_EVERY - 1, "and rested and continued along the way (%d)" % r.reloads)
	check(orphans1 <= orphans0, "no orphan nodes left behind (%d -> %d)" % [orphans0, orphans1])
	check(obj1 - obj0 < 50, "a second lap leaves no live objects behind (%d -> %d)" % [obj0, obj1])
	check(nodes1 <= nodes0, "and the tree is no bigger (%d -> %d)" % [nodes0, nodes1])
	for r: Dictionary in [first, second]:
		_check_frames(r)
	GameState.slot = slot_was



## The same journey on a save that has seen the ending (pass 144): every boss
## beaten, the Tree in bloom (its blossom layer and the post-game music) and
## Wanderer's Grace feeding the air dashes on every kill. Two laps: the second must leave nothing behind and log no errors.
func test_a_journey_after_the_end_stays_lean() -> void:
	var slot_was := GameState.slot
	GameState.slot = JOURNEY_SLOT
	var errors := ErrorCatcher.start()
	# Each lap walks out of Hearthroot and, separately, out of the dead stillglass.
	var first: Dictionary = _merge(await _journey(1987, true, POSTGAME_DOORS), await _journey(1987, true, POSTGAME_DOORS / 2, "evercrown/threshold"))
	var obj0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var orphans0 := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var nodes0 := runner.get_tree().get_node_count()
	var second: Dictionary = _merge(await _journey(2026, true, POSTGAME_DOORS), await _journey(2026, true, POSTGAME_DOORS / 2, "evercrown/threshold"))
	# The second lap walks new ground, and the first sight of a zone's music,
	# sheets and tiles is cached for good. So the leak check walks it again:
	# the same lap, retraced, must leave nothing behind (pass 151).
	obj0 = Performance.get_monitor(Performance.OBJECT_COUNT)
	orphans0 = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	nodes0 = runner.get_tree().get_node_count()
	await _journey(2026, true, POSTGAME_DOORS)
	await _journey(2026, true, POSTGAME_DOORS / 2, "evercrown/threshold")
	var obj1 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var orphans1 := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var nodes1 := runner.get_tree().get_node_count()
	var caught := errors.stop()
	GameState.delete_save(JOURNEY_SLOT)
	for r: Dictionary in [first, second]:
		print("  After the end: %d rooms, %d reloads, worst frame %.1f ms (%s), bloom in %d room stays, still stillglass %d, festival %d, host paused %d" % [
			r.rooms, r.reloads, r.worst / 1000.0, r.where, r.bloomed, r.still, r.festival, r.paused])
	print("  Retraced lap: objects %d -> %d, orphans %d -> %d, nodes %d -> %d" % [obj0, obj1, orphans0, orphans1, nodes0, nodes1])
	check(caught.is_empty(), "no engine or script errors on the way: %s" % [caught.slice(0, 3)])
	for r: Dictionary in [first, second]:
		check(r.problems.is_empty(), "every rest continues where it was taken, still cleared: %s" % [r.problems])
		check(r.rooms >= 20, "the walk saw much of the world (%d rooms)" % r.rooms)
		check(r.bloomed > 0, "blossom drifted through the living Tree (%d room stays)" % r.bloomed)
		check(r.still > 0 and r.festival > 0, "the Evercrown played still and Hearthroot its festival (%d, %d room stays)" % [r.still, r.festival])
		_check_frames(r)
	check(orphans1 <= orphans0, "no orphan nodes left behind (%d -> %d)" % [orphans0, orphans1])
	check(obj1 - obj0 < 50, "a retraced lap leaves no live objects behind (%d -> %d)" % [obj0, obj1])
	check(nodes1 <= nodes0, "and the tree is no bigger (%d -> %d)" % [nodes0, nodes1])
	GameState.new_game()
	GameState.slot = slot_was



## A boss fight starts mid-play, so its arena loads the boss's sheet and music
## while the room loads (pass 99): the fight's first frame must not hitch.
func test_a_boss_arena_loads_the_fight_before_it_starts() -> void:
	Sheet._cache.erase("durgan")
	Music._streams.erase("durgan")
	var w := make_world({}, "tower/kettleforge_lift")
	await frames(2)
	var a := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
	check(a != null and a.warmed, "the arena warmed up with the room")
	check(Sheet._cache.has("durgan") and Music._streams.has("durgan"), "the drill's sheet and theme are loaded before the fight")
	w.player.input.move_x = 1
	var worst := 0
	var started := false
	for i in 90:
		var t0 := Time.get_ticks_usec()
		await frames(1)
		worst = maxi(worst, Time.get_ticks_usec() - t0)
		started = started or a.fighting
	check(started, "the fight began as the player walked in")
	check(worst < 33_000, "and no frame of the walk in hitched (worst %.1f ms)" % (worst / 1000.0))
	w.queue_free()
	await frames(2)


func _journey(seed: int, postgame := false, doors := JOURNEY_DOORS, start := "hearthroot/west_gate") -> Dictionary:
	var w := make_world({}, start)
	GameState.data.rings = CrownGate.RINGS.duplicate()
	GameState.set_flag(CrownGate.FLAG)
	if postgame:
		_clear_the_game(w)
		# Enter the first room again as the cleared save would, bloom and all.
		w._enter(start)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# The hand mashes on its own dice, so the doors the walk picks don't
	# hang on how the mashing draws (pass 151).
	var hand := RandomNumberGenerator.new()
	hand.seed = seed * 31 + 7
	var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
	var menus := ListMenu.new()
	arena.add_child(menus)
	_journey_buff(w)
	await frames(10)
	var r := {"rooms": 0, "reloads": 0, "worst": 0, "second": 0, "where": "", "spikes": 0, "paused": 0, "problems": [],
		"bloomed": 0, "still": 0, "festival": 0, "loads": []}
	var visited := {w.room.id: true}
	if postgame:
		_tally_bloom(w, r)
	for i in doors:
		var exits: Array = w.room.doors.keys()
		if exits.is_empty():
			break
		var fresh := exits.filter(func(k: int) -> bool: return not visited.has(String(w.room.doors[k].target)))
		var pick: Array = fresh if not fresh.is_empty() and rng.randf() < 0.8 else exits
		var n: int = pick[rng.randi() % pick.size()]
		w.use_door(n)
		visited[w.room.id] = true
		var entered := 0
		for f in 40:
			_mash(w.player, hand, hold)
			var before := w.room
			var t0 := Time.get_ticks_usec()
			var sheets0 := Sheet._cache.size()
			var sounds0 := Sfx.loads
			var cpu0 := _cpu_usec()
			var steal0 := _steal_usec()
			await frames(1)
			var dt := Time.get_ticks_usec() - t0
			var cpu := _cpu_usec() - cpu0
			var steal := _steal_usec() - steal0
			# Play loads nothing from disk (pass 303): a sheet or sound first
			# loaded mid-room is a hitch waiting to happen on a slower disk.
			if w.room == before and f >= entered + 3 and (Sheet._cache.size() != sheets0 or Sfx.loads != sounds0):
				r.loads.append("%s frame %d: sheets %s, sounds %d" % [w.room.id, f, Sheet._cache.keys().slice(sheets0), Sfx.loads - sounds0])
			if w.room != before:
				# Mashing walked out through an edge door: a load, not play.
				entered = f
				visited[w.room.id] = true
			# The first frames in a room build it; judge play, not loading.
			# A frame the host took the machine for is not the game's (pass 367).
			if f >= entered + 3 and dt >= FRAME_BUDGET and _host_paused(dt, cpu, steal):
				r.paused += 1
				print("    host paused %.1f ms in %s frame %d (main thread on CPU %.0f ms, host took %.0f ms)" % [
					dt / 1000.0, w.room.id, f, cpu / 1000.0, steal / 1000.0])
			elif f >= entered + 3:
				if dt > r.worst:
					r.second = r.worst
					r.worst = dt
					r.where = "%s frame %d" % [w.room.id, f]
				elif dt > r.second:
					r.second = dt
				if dt > 33_000:
					r.spikes += 1
					print("    spike %.1f ms in %s frame %d (main thread on CPU %.0f ms)" % [dt / 1000.0, w.room.id, f, cpu / 1000.0])
		if postgame:
			_tally_bloom(w, r)
		if w.player.dead:
			await frames(int(w.player.combat.respawn_delay * 60.0) + 30)
			_journey_buff(w)
		if i % 7 == 3:
			Menus.open_pause(runner.get_tree(), w.player, func() -> void: pass)
			await frames(3)
			_close_menus()
			Menus.open_skills(runner.get_tree(), w.player)
			await frames(3)
			_close_menus()
		if i % JOURNEY_SAVE_EVERY == JOURNEY_SAVE_EVERY - 1:
			# Rest, then Continue into a brand-new world, as after quitting.
			var room_id := w.room.id
			w.save_at(w.player.global_position)
			w.queue_free()
			await frames(2)
			if not GameState.load_game(JOURNEY_SLOT):
				r.problems.append("the save at %s did not load" % room_id)
				break
			w = World.new()
			w.instant = true
			arena.add_child(w)
			w.build_catalog()
			w.start(String(GameState.data.save_room), Vector2(float(GameState.data.save_pos[0]), float(GameState.data.save_pos[1])))
			w.player.input.scripted = true
			_journey_buff(w)
			r.reloads += 1
			if postgame and not GameState.flag("cleared"):
				r.problems.append("the save at %s forgot the ending" % room_id)
			await frames(5)
			if w.room.id != room_id:
				r.problems.append("continued in %s, not %s" % [w.room.id, room_id])
	r.rooms = visited.size()
	w.queue_free()
	menus.queue_free()
	await frames(10)
	return r


## The frame budget of a journey lap (pass 182). Play frames run about 1 ms
## headless, and a real hitch (a load, a leak, a slow room) comes back every
## time its room is entered, so it shows up as several slow frames. A lone frame
## of 50 to 60 ms came only in full runs, never with the test run alone (passes
## 174, 178, 179), and a frame-by-frame trace of a lap shows play frames past
## the third after entry at 1 ms (median) and under 5 ms (max):
## the host pausing the process, not the game. So one frame per lap may pass
## 50 ms if it stays under 100 ms, and every other frame must stay under 50 ms.
## Pass 367 caught the host at it: bursts of two or three frames of 50 to 100 ms
## (passes 359 and 363) had the main thread off the CPU, and an empty loop
## with no game in it met a 54.5 ms frame the same way while the VM's steal
## counter ran. A frame over budget is set aside only on that evidence
## (`_host_paused`); every other slow frame is judged as before.
const FRAME_BUDGET := 50_000
const LONE_FRAME_LIMIT := 100_000


func _check_frames(r: Dictionary) -> void:
	check(r.get("loads", []).is_empty(), "no sheet or sound is first loaded in play, after a room is built: %s" % [r.get("loads", [])])
	check(int(r.second) < FRAME_BUDGET, "no two frames of play spike past 50 ms (second worst %.1f ms)" % (int(r.second) / 1000.0))
	check(int(r.worst) < LONE_FRAME_LIMIT, "and not even a lone frame passes 100 ms (%.1f ms, %s)" % [int(r.worst) / 1000.0, r.where])
	if int(r.worst) >= FRAME_BUDGET:
		print("    lone frame %.1f ms (%s): allowed once a lap" % [int(r.worst) / 1000.0, r.where])


## Pass 182: two laps' tallies keep their worst and second-worst frames, so the
## budget forgives one lone frame but not two.
func test_the_journey_frame_budget_forgives_one_lone_frame() -> void:
	var a := {"rooms": 1, "reloads": 0, "spikes": 0, "bloomed": 0, "still": 0, "festival": 0, "problems": [], "worst": 52_000, "second": 3_000, "where": "a"}
	var b := {"rooms": 1, "reloads": 0, "spikes": 0, "bloomed": 0, "still": 0, "festival": 0, "problems": [], "worst": 4_000, "second": 2_000, "where": "b"}
	var m := _merge(a, b)
	check(int(m.worst) == 52_000 and int(m.second) == 4_000 and m.where == "a", "one lone frame is the worst, and the next is the second (%d, %d)" % [m.worst, m.second])
	b.worst = 51_000
	m = _merge(a, b)
	check(int(m.second) == 51_000, "two slow frames, one in each half, make the second worst slow too (%d)" % m.second)
	check(int(m.second) >= FRAME_BUDGET and int(m.worst) < LONE_FRAME_LIMIT, "so the budget fails two where it forgives one")


## Counts what the room shows of the post-game: blossom, the still stillglass, the festival.
func _tally_bloom(w: World, r: Dictionary) -> void:
	if not w.blossom.get("_motes").is_empty():
		r.bloomed += 1
	if Music.track == "evercrown_still":
		r.still += 1
	if Music.track == "hearthroot_bloom":
		r.festival += 1


## Two journeys' tallies as one.
func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for k: String in ["rooms", "reloads", "spikes", "bloomed", "still", "festival"]:
		out[k] = int(a[k]) + int(b[k])
	out.paused = int(a.get("paused", 0)) + int(b.get("paused", 0))
	if int(b.worst) > int(a.worst):
		out.worst = b.worst
		out.where = b.where
	# The second-worst of the two: the larger of the losing worst and both seconds.
	out.second = maxi(mini(int(a.worst), int(b.worst)), maxi(int(a.second), int(b.second)))
	out.problems = a.problems + b.problems
	out.loads = a.get("loads", []) + b.get("loads", [])
	return out


## A save that has seen the ending: every boss beaten, every spring running, the
## Tree in bloom, and Wanderer's Grace learned so kills feed the air dashes.
func _clear_the_game(w: World) -> void:
	for id: String in BossArena.BOSSES:
		GameState.set_flag("boss:" + id)
	for spring: String in ["heartwood", "haar", "sky"]:
		GameState.set_flag("spring:" + spring)
	GameState.set_flag("cleared")
	var skills: Array = GameState.data.skills
	for id: String in ["deep_pockets", "gold_sense", "quick_draught", "second_stride", "feather_fall", "treasure_sense",
			"resilience", "last_stand", "second_wind", "wanderers_grace"]:
		if not skills.has(id):
			skills.append(id)
	GameState.refresh_stats(w.player)


func _journey_buff(w: World) -> void:
	for k: String in GameState.data.abilities:
		GameState.data.abilities[k] = true
		w.player.abilities[k] = true
	_learn_the_blade(w)
	w.player.max_hp = 99999
	w.player.hp = 99999


## The whole Blade branch, Thrust included (pass 151): the soaks mash every
## melee skill, Riposte's counter and Rising Cut's launch with them.
func _learn_the_blade(w: World) -> void:
	var skills: Array = GameState.data.skills
	for n: Dictionary in Skills.nodes():
		if String(n.branch) == "Blade" and not skills.has(n.id):
			skills.append(String(n.id))
	GameState.refresh_stats(w.player)


func _close_menus() -> void:
	for m in runner.get_tree().get_nodes_in_group("list_menu"):
		m.close()
	runner.get_tree().paused = false


## Every boss fight, mashed for 15 s with the boss knocked down a phase every
## 5 s, holds the frame budget (bible 15.3) and loads nothing from disk once it
## has begun: the boss's sheet comes with the arena (`BossArena.warm`) and every
## sound with the game (`Sfx.load_all`). The arenas are read from the rooms
## (pass 174): a hand-kept list had missed both mini-bosses of passes 169 and 171.
func _boss_rooms() -> Dictionary:
	var w := make_world({}, "hearthroot/west_gate")
	var out := {}
	for id: String in _all_room_ids(w):
		var boss := String(w.catalog[id].get("boss", ""))
		if boss != "":
			out[id] = boss
	w.queue_free()
	return out


const BOSS_AUDIT_FRAMES := 900
## A fight's 99th-percentile frame budget, in microseconds (bible 15.3's 60 fps).
const BOSS_FRAME_BUDGET := 16_600


func test_every_boss_fight_holds_the_frame_budget() -> void:
	var report: Array[String] = []
	var problems: Array[String] = []
	var paused := 0
	var wavs := Array(DirAccess.get_files_at(Sfx.SFX_DIR)).filter(func(f: String) -> bool: return f.ends_with(".wav"))
	check(Sfx.loads >= wavs.size() and wavs.size() > 80, "every sound loaded with the game (%d of %d)" % [Sfx.loads, wavs.size()])
	var rooms := _boss_rooms()
	await frames(1)
	for id: String in rooms:
		GameState.new_game()
		Sheet._cache.clear()
		var w := make_world({}, id)
		w.player.max_hp = 99999
		w.player.hp = 99999
		w.player.has_shield = true
		await frames(5)
		var ar := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
		if not check(ar != null, "%s has a boss arena" % id):
			continue
		ar._start()
		await frames(2)
		var boss := ar.boss
		var rng := RandomNumberGenerator.new()
		rng.seed = 103
		var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
		var sheets := Sheet._cache.size()
		var loads := Sfx.loads
		var start_nodes := _count_nodes(w)
		var peak := start_nodes
		var times: Array[int] = []
		var total := 0
		for f in BOSS_AUDIT_FRAMES:
			_mash(w.player, rng, hold)
			w.player.hp = 99999
			if f % 300 == 299 and is_instance_valid(boss) and boss.has_method("take_hit") and boss.hp > 50:
				boss.take_hit(int(boss.max_hp * 0.2), Vector2.RIGHT)
			var t0 := Time.get_ticks_usec()
			var cpu0 := _cpu_usec()
			var steal0 := _steal_usec()
			await frames(1)
			var dt := Time.get_ticks_usec() - t0
			peak = maxi(peak, _count_nodes(w))
			# A frame the host took the machine for is not the fight's (pass 384,
			# as the journeys' since pass 367).
			if dt >= BOSS_FRAME_BUDGET and _host_paused(dt, _cpu_usec() - cpu0, _steal_usec() - steal0):
				paused += 1
				continue
			times.append(dt)
			total += dt
		times.sort()
		var avg := total / 1000.0 / maxi(times.size(), 1)
		var p99 := times[int(times.size() * 0.99)] / 1000.0
		report.append("%s %.2f/%.2f ms" % [id.get_file(), avg, p99])
		if avg > 8.0 or p99 > BOSS_FRAME_BUDGET / 1000.0:
			problems.append("%s: average %.2f ms, 99th percentile %.2f ms" % [id, avg, p99])
		if times.size() < BOSS_AUDIT_FRAMES * 0.9:
			problems.append("%s: the host took %d of %d frames, too many to judge the fight" % [id, BOSS_AUDIT_FRAMES - times.size(), BOSS_AUDIT_FRAMES])
		if Sheet._cache.size() != sheets or Sfx.loads != loads:
			problems.append("%s: loaded %d sheets and %d sounds mid-fight" % [id, Sheet._cache.size() - sheets, Sfx.loads - loads])
		if peak >= start_nodes + 40:
			problems.append("%s: nodes piled up (%d -> %d)" % [id, start_nodes, peak])
		w.queue_free()
		await frames(2)
	TimeStop.reset()
	print("  Boss frames (average/99th): %s; %d frames the host paused set aside" % [", ".join(report), paused])
	check(report.size() == rooms.size() and rooms.size() == BossArena.BOSSES.size(), "every boss fight ran (%d of %d arenas)" % [report.size(), rooms.size()])
	check(problems.is_empty(), "every fight holds the budget and loads nothing mid-fight: %s" % [problems])


## Pass 174: every guardian, beaten and saved, stays beaten. Each arena's fight
## is won outright, the game saved and continued into a fresh world in the same
## room: the doors stand open, no fight starts, and its prize isn't given twice.
## Every guardian the arena knows has exactly one room, so none is unreachable.
func test_every_beaten_guardian_stays_beaten_through_a_save() -> void:
	var slot_was := GameState.slot
	var rooms := _boss_rooms()
	await frames(1)
	var homes := {}
	for id: String in rooms:
		homes[rooms[id]] = homes.get(rooms[id], 0) + 1
	var lost := BossArena.BOSSES.keys().filter(func(b: String) -> bool: return homes.get(b, 0) != 1)
	var stray := homes.keys().filter(func(b: String) -> bool: return not BossArena.BOSSES.has(b))
	check(lost.is_empty() and stray.is_empty(), "every guardian has one arena, and every arena a known guardian (lost %s, stray %s)" % [lost, stray])
	const SLOT := 9
	var problems: Array[String] = []
	var won := 0
	for id: String in rooms:
		var boss_id: String = rooms[id]
		if boss_id == "everbloom":
			continue  # its win starts the ending; the ending's own tests cover it
		var w := make_world({}, id)
		GameState.slot = SLOT
		w.player.max_hp = 99999
		w.player.hp = 99999
		await frames(3)
		var ar := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
		if ar == null:
			problems.append("%s: no arena" % id)
			w.queue_free()
			await frames(1)
			continue
		ar._start()
		await frames(2)
		ar._on_defeated()
		if is_instance_valid(ar.boss):
			ar.boss.queue_free()
		await frames(int(BossArena.OPEN_DELAY * 60) + 10)
		var prize := _prize(boss_id)
		if not GameState.flag("boss:" + boss_id) or ar.fighting or not ar.seals.is_empty():
			problems.append("%s: the win left the arena shut" % id)
		GameState.save_game()
		w.queue_free()
		await frames(1)
		if not GameState.load_game(SLOT):
			problems.append("%s: the save did not come back" % id)
			continue
		var w2 := World.new()
		w2.instant = true
		arena.add_child(w2)
		w2.start(id)
		w2.player.input.scripted = true
		w2.player.input.move_x = 1
		await frames(90)
		var ar2 := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
		var seals := w2.room.get_children().filter(func(c: Node) -> bool: return c is ArenaSeal)
		if ar2 == null or ar2.fighting or ar2.boss != null or not seals.is_empty():
			problems.append("%s: %s rose again after the continue" % [id, boss_id])
		if _prize(boss_id) != prize:
			problems.append("%s: the prize changed on the way back (%s -> %s)" % [id, prize, _prize(boss_id)])
		won += 1
		w2.queue_free()
		await frames(1)
	GameState.delete_save(SLOT)
	GameState.new_game()
	check(won == rooms.size() - 1, "won and continued in every arena but the last (%d)" % won)
	check(problems.is_empty(), "every beaten guardian stays beaten and pays once: %s" % [problems])
	GameState.slot = slot_was



## What a guardian's win leaves on the save.
func _prize(boss_id: String) -> Dictionary:
	var d := GameState.data
	return {"flag": GameState.flag("boss:" + boss_id), "hp": int(d.max_hp), "mp": float(d.max_mp),
		"points": int(d.skill_points), "rings": (d.rings as Array).size(), "keys": str(d.keys),
		"abilities": str(d.abilities), "armor": String(d.equipment.armor)}


## Pass 158: the boss rush moves through thirteen arenas back to back, so each
## must load quickly behind its fade; and a flurry of damage numbers frees itself
## and keeps the frame inside budget.
func test_the_boss_rush_and_damage_numbers_stay_lean() -> void:
	var w := make_world({}, "hearthroot/ringreader_temple")
	await frames(5)
	for pair: Array in BossRush.ORDER:
		GameState.set_flag("boss:" + String(pair[0]))
	BossRush.begin("hearthroot/ringreader_temple", w.player.global_position)
	var worst := 0.0
	var worst_room := ""
	var lines: Array[String] = []
	for i in BossRush.ORDER.size():
		BossRush.run.index = i
		var t0 := Time.get_ticks_usec()
		BossRush.go(w)
		await frames(1)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		lines.append("%s %.1f ms" % [BossRush.ORDER[i][1], ms])
		if ms > worst:
			worst = ms
			worst_room = String(BossRush.ORDER[i][1])
		await frames(4)
	print("  rush arenas: " + ", ".join(lines))
	# The load happens behind the fade to black; the first room of a zone pays
	# for its tileset (about 190 ms here), later ones about 30 ms. CI is slower.
	check(worst < 500.0, "every rush arena loads behind the fade in under 500 ms (worst %s, %.1f ms)" % [worst_room, worst])
	BossRush.abandon()
	# A flurry: ten numbers a frame for two seconds.
	var was := Settings.damage_numbers
	Settings.damage_numbers = true
	var base := w.room.get_child_count()
	var total := 0
	for f in 120:
		var t0 := Time.get_ticks_usec()
		for k in 10:
			DamageNumber.spawn(w.room, w.player.global_position + Vector2(k * 6, -40), 3 + k, "heavy" if k == 0 else "hit")
		await frames(1)
		total += Time.get_ticks_usec() - t0
	var peak := w.room.get_child_count() - base
	check(peak <= 10 * int(ceilf(DamageNumber.LIFE * 60.0)) + 10, "numbers free themselves as they go (%d live)" % peak)
	await frames(int(DamageNumber.LIFE * 60.0) + 5)
	check(w.room.get_child_count() == base, "and none are left after (%d)" % (w.room.get_child_count() - base))
	var avg_ms := total / 120.0 / 1000.0
	check(avg_ms < 16.6, "a frame of numbers averages under the 60 fps budget (%.2f ms)" % avg_ms)
	Settings.damage_numbers = was
	w.queue_free()


## Every room in the game, entered one after another in a single world (pass
## 166): each loads behind the fade in under half a second (the first room of a
## zone pays for its tileset), and once loaded its frames, foes and all, stay
## well inside the 60 fps budget while the player stands in it.
func test_every_room_loads_and_settles_inside_the_budget() -> void:
	var w := make_world({}, Trials.TEMPLE)
	await frames(3)
	var ids: Array[String] = []
	for zone: String in DirAccess.get_directories_at("res://levels"):
		for file: String in DirAccess.get_files_at("res://levels/" + zone):
			if file.ends_with(".room"):
				ids.append(zone + "/" + file.trim_suffix(".room"))
	ids.sort()
	var lines: Array[String] = []
	var slow: Array[String] = []
	var heavy: Array[String] = []
	for id in ids:
		var t0 := Time.get_ticks_usec()
		w.start(id)
		await frames(1)
		var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
		await frames(2)
		var t1 := Time.get_ticks_usec()
		await frames(SETTLE_FRAMES)
		var frame_ms := (Time.get_ticks_usec() - t1) / 1000.0 / SETTLE_FRAMES
		lines.append("%-28s load %6.1f ms   frame %5.2f ms" % [id, load_ms, frame_ms])
		if load_ms > 500.0:
			slow.append("%s %.0f ms" % [id, load_ms])
		if frame_ms > 8.0:
			heavy.append("%s %.2f ms" % [id, frame_ms])
	if OS.get_environment("ROOM_REPORT") != "":
		var f := FileAccess.open(OS.get_environment("ROOM_REPORT"), FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(lines) + "\n")
	check(ids.size() >= 120, "every room was entered (%d)" % ids.size())
	check(slow.is_empty(), "every room loads behind the fade in under 500 ms: %s" % [slow])
	check(heavy.is_empty(), "every settled room averages under 8 ms a frame: %s" % [heavy])


## Pass 287: no foe's spoils ever leave its room. Passes 283 and 285 kept a
## drop and a coin in the room (`Drop.keep_in_room`), tested in the two Silt Adder
## rooms. Here every foe in every room dies at once, each leaving a loaf and
## three coins, and every one of them must come to rest on a floor inside the
## room, within its life, while the room keeps its frame budget. The hero is
## frozen and counted out (dead), so nothing is taken before it is judged.
func test_every_foes_spoils_rest_in_its_room() -> void:
	var w := make_world({}, Trials.TEMPLE)
	await frames(3)
	var ids: Array[String] = []
	for zone: String in DirAccess.get_directories_at("res://levels"):
		for file: String in DirAccess.get_files_at("res://levels/" + zone):
			if file.ends_with(".room"):
				ids.append(zone + "/" + file.trim_suffix(".room"))
	ids.sort()
	var lost: Array[String] = []
	var heavy: Array[String] = []
	var dropped := 0
	var rooms := 0
	for id in ids:
		w.start(id)
		await frames(2)
		var p := w.player
		p.frozen = true
		p.dead = true
		var bounds := Rect2(Vector2.ZERO, Vector2(w.room.size_tiles) * Room.TILE)
		var spoils: Array[CharacterBody2D] = []
		var k := 0
		for e in w.room.get_children():
			if not e is Enemy:
				continue
			var at := (e as Enemy).global_position + Vector2(0, -12)
			var d := Drop.make(w.room, at, "loaf")
			d.velocity = Vector2(40.0 if k % 2 == 0 else -40.0, -200)
			spoils.append(d)
			for vx in [-80.0, 0.0, 80.0]:
				var c := Coin.new()
				c.value = 5
				c.velocity = Vector2(vx, -200)
				w.room.add_child(c)
				c.global_position = at
				spoils.append(c)
			k += 1
		if spoils.is_empty():
			p.dead = false
			p.frozen = false
			continue
		rooms += 1
		dropped += spoils.size()
		var t0 := Time.get_ticks_usec()
		await frames(300)
		var frame_ms := (Time.get_ticks_usec() - t0) / 1000.0 / 300.0
		if frame_ms > 8.0:
			heavy.append("%s %.2f ms" % [id, frame_ms])
		for b in spoils:
			if not is_instance_valid(b) or b.is_queued_for_deletion():
				lost.append("%s: gone" % id)
			elif not b.is_on_floor() or not bounds.has_point(b.global_position):
				lost.append("%s: %s at %s" % [id, "loaf" if b is Drop else "coin", b.global_position])
			if is_instance_valid(b):
				b.free()
		p.dead = false
		p.frozen = false
	check(rooms >= 80, "foes stood in most rooms (%d rooms, %d spoils)" % [rooms, dropped])
	check(lost.is_empty(), "every foe's loaf and coins rest on a floor in its room (%d of %d lost: %s)" % [lost.size(), dropped, lost.slice(0, 24)])
	check(heavy.is_empty(), "and each room keeps its frame budget meanwhile: %s" % [heavy])


## Pass 220: every guardian's win says what it gave. A boss with a line of its
## own (the Likeness, the Everbloom's avatar and veins) shows that line, which until
## pass 220 was written but never shown, and a skill point it gives is always
## told: in the banner, or in a toast when the banner tells the story. Every
## line fits the screen, the Everbloom's last one too.
func test_every_guardians_win_says_what_it_gave() -> void:
	for boss_id: String in BossArena.BOSSES:
		var reward: Dictionary = BossArena.BOSSES[boss_id]
		if reward.has("text"):
			check(PixelFont.width(String(reward.text), 10) <= 620.0, "%s's line fits the banner (%d px)" % [boss_id, PixelFont.width(String(reward.text), 10)])
	var rooms := _boss_rooms()
	await frames(1)
	var untold: Array[String] = []
	var told := 0
	for id: String in rooms:
		var boss_id: String = rooms[id]
		if boss_id == "everbloom":
			continue  # its win starts the ending; its line is held by the width check above
		var reward: Dictionary = BossArena.BOSSES[boss_id]
		var w := make_world({}, id)
		w.player.max_hp = 99999
		w.player.hp = 99999
		await frames(3)
		var ar := runner.get_tree().get_first_node_in_group("boss_arena") as BossArena
		var said: Array[String] = []
		var on_banner := func(title: String, sub: String) -> void: said.append(title + "|" + sub)
		var on_toast := func(text: String) -> void: said.append("|" + text)
		ar._start()
		await frames(2)
		GameState.banner.connect(on_banner)
		GameState.toast.connect(on_toast)
		Sfx.recent.clear()
		ar._on_defeated()
		if not Sfx.recent.has(BossArena.WIN_SOUND):
			untold.append("%s: its fanfare (%s)" % [boss_id, Sfx.recent])
		GameState.banner.disconnect(on_banner)
		GameState.toast.disconnect(on_toast)
		if is_instance_valid(ar.boss):
			ar.boss.queue_free()
		var all := "\n".join(said)
		if reward.has("text") and not all.contains("|" + String(reward.text)):
			untold.append("%s: its line (%s)" % [boss_id, all])
		var points := int(reward.get("skill_points", 0))
		if points > 0 and not all.contains("|" + BossArena.point_line(points)):
			untold.append("%s: its skill point (%s)" % [boss_id, all])
		told += 1
		w.queue_free()
		await frames(1)
	check(told >= 14, "every arena's win was heard (%d)" % told)
	check(untold.is_empty(), "every win says what it gave, to a fanfare: %s" % [untold])


## Pass 295 (bible 6.13): the room's own floor always counts as footing. Pass
## 292 made a tile that is gone no footing, read from the cell under the floor
## contact. On a ledge's corner the contact lies on the line between two cells,
## and the empty one to its right was read, so standing there never kept a safe
## spot (150 of 63,792 floor frames walking these rooms both ways). Both cells
## beside the line are read now.
const CORNER_ROOMS := ["tower/winch_hall", "heartwood/deep_roots", "heartwood/taproot_vault", "haar/polesend", "vorrhallow/alpha_den"]


func test_a_ledge_corner_is_footing_for_the_set_back() -> void:
	var floors := 0
	var gone: Array[String] = []
	for id: String in CORNER_ROOMS:
		var room := Room.from_file("res://levels/%s.room" % id)
		arena.add_child(room)
		var p := Player.new()
		p.input.scripted = true
		p.position = room.spawn_position
		room.add_child(p)
		p.max_hp = 99999
		p.hp = 99999
		for dir: int in [1, -1]:
			p.input.move_x = dir
			for i in 120:
				await frames(1)
				var on_tiles := false
				for j in p.get_slide_collision_count():
					var k := p.get_slide_collision(j)
					on_tiles = on_tiles or (k.get_normal().y < -0.5 and k.get_collider() is TileMapLayer)
				if on_tiles:
					floors += 1
					if p._on_fleeting_ground() and gone.size() < 10:
						gone.append("%s at %s" % [id, p.global_position])
		p.input.move_x = 0
		room.queue_free()
		await frames(1)
	check(floors > 500, "the walk stands on tiles (%d frames)" % floors)
	check(gone.is_empty(), "no tile floor reads as gone: %s" % [gone])



## Pass 335: bible 14's budget says "under 1.5 GB RAM", and nothing measured
## it, or whether walking the world leaks. This enters every room three times.
## The first lap fills the caches; the next two must hold the same memory and
## the same number of live objects, so a room change that leaves anything
## behind (a node, a tween, a sound) grows them lap on lap. Headless, the
## memory is the engine's own (scripts, resources, nodes); textures on the GPU
## are not in it.
func test_walking_the_world_holds_its_memory() -> void:
	var w := make_world({}, Trials.TEMPLE)
	await frames(3)
	var ids: Array[String] = []
	for zone: String in DirAccess.get_directories_at("res://levels"):
		for file: String in DirAccess.get_files_at("res://levels/" + zone):
			if file.ends_with(".room"):
				ids.append(zone + "/" + file.trim_suffix(".room"))
	ids.sort()
	var peaks: Array[int] = []
	var objects: Array[int] = []
	for lap in MEMORY_LAPS:
		var peak := 0
		for id in ids:
			w.start(id)
			await frames(3)
			peak = maxi(peak, OS.get_static_memory_usage())
		peaks.append(peak)
		objects.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	var mb := func(b: int) -> float: return b / 1048576.0
	check(peaks.max() < MEMORY_BUDGET, "the world stays under bible 14's 1.5 GB (peak %.0f MB)" % mb.call(peaks.max()))
	check(peaks[2] - peaks[1] < MEMORY_DRIFT, "a third lap of every room needs no more memory than the second (%.1f MB, %.1f MB)" % [mb.call(peaks[1]), mb.call(peaks[2])])
	check(absi(objects[2] - objects[1]) <= OBJECT_DRIFT, "and leaves as many live objects (%d, %d)" % [objects[1], objects[2]])


## The main thread's own CPU time in microseconds (user + system), read from
## /proc at the kernel's 10 ms tick; -1 where there is no /proc.
static func _cpu_usec() -> int:
	var f := FileAccess.open("/proc/self/task/%d/stat" % OS.get_process_id(), FileAccess.READ)
	if f == null:
		return -1
	var line := f.get_line()
	var rest := line.substr(line.rfind(")") + 2).split(" ")
	if rest.size() < 13:
		return -1
	return (int(rest[11]) + int(rest[12])) * 10_000


## CPU time the host took from this machine's virtual CPUs (all of them, the
## "steal" column of /proc/stat) in microseconds; -1 where there is no /proc.
static func _steal_usec() -> int:
	var f := FileAccess.open("/proc/stat", FileAccess.READ)
	if f == null:
		return -1
	var cols := f.get_line().split(" ", false)
	if cols.size() < 9 or cols[0] != "cpu":
		return -1
	return int(cols[8]) * 10_000


## Whether a frame of `dt` us was the host's pause and not the game's work
## (pass 367): the main thread was on the CPU for under half of it, and the
## host took CPU time from the VM while it ran. Without /proc (-1) nothing is
## set aside, and a frame the game spent on the CPU is always judged.
static func _host_paused(dt: int, cpu: int, steal: int) -> bool:
	return cpu >= 0 and steal > 0 and cpu * 2 < dt


## Pass 367: the soak's bursts of slow frames in full runs were the host
## taking the VM. The test that sets them aside must tell a host pause from
## a hitch, and the clocks it reads must be real.
func test_a_host_pause_is_told_from_a_hitch() -> void:
	check(_host_paused(60_000, 0, 30_000), "off the CPU while the host took time: the host's pause")
	check(_host_paused(101_000, 10_000, 10_000), "a 101 ms frame with 10 ms on the CPU and the host stealing: the host's")
	check(not _host_paused(60_000, 50_000, 30_000), "a frame the game spent on the CPU is the game's, steal or not")
	check(not _host_paused(60_000, 30_000, 30_000), "half of it on the CPU is still the game's")
	check(not _host_paused(60_000, 0, 0), "off the CPU with nothing stolen is a wait the game may own (a lock, a disk)")
	check(not _host_paused(60_000, -1, -1) and not _host_paused(60_000, -1, 30_000), "without /proc nothing is set aside")
	if OS.get_name() != "Linux":
		return
	var c0 := _cpu_usec()
	var s0 := _steal_usec()
	check(c0 >= 0 and s0 >= 0, "the main thread's CPU time and the host's steal read on Linux (%d, %d)" % [c0, s0])
	var t0 := Time.get_ticks_usec()
	var x := 0.0
	while Time.get_ticks_usec() - t0 < 60_000:
		x += sin(x + 1.0)
	var busy := _cpu_usec() - c0
	check(busy >= 30_000, "60 ms of work shows on the main thread's clock (%d us)" % busy)
	check(_steal_usec() >= s0, "and steal only ever counts up")
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("**The host's pause, told from a hitch (pass 367):**"), "bible 15.3 tells it")


## Pass 375: the minimap on a full map. With every room walked and every zone
## charted it still costs little a frame: the rooms in view are kept until you
## change rooms, walk a new one or buy a chart, and only the dot moves each
## frame. A kept layout must be the same as a fresh one.
func test_the_minimap_stays_cheap_on_a_full_map() -> void:
	var w := make_world({}, "tower/winch_hall")
	await frames(2)
	for id: String in w.catalog:
		if id != "tower/smelter":
			GameState.visit(id)
		GameState.data.charts[String(w.catalog[id].zone)] = true
	var first := Minimap.layout(w)
	check(not first.cached and first.rooms.size() >= 6, "a full map fills the window (%d rooms)" % first.rooms.size())
	var again := Minimap.layout(w)
	check(again.cached, "the next frame keeps it")
	var ids := func(lay: Dictionary) -> Array: return lay.rooms.map(func(r: Dictionary) -> String: return "%s:%s:%s" % [r.id, r.how, r.rect])
	w.remove_meta(Minimap.CACHE)
	check(ids.call(again) == ids.call(Minimap.layout(w)), "and what it keeps is what a fresh look shows")
	var dot: Vector2 = again.player
	w.player.global_position.x += 10 * Room.TILE
	var moved := Minimap.layout(w)
	check(moved.cached and moved.player.x > dot.x, "the dot still moves every frame")
	GameState.visit("tower/smelter")
	check(not Minimap.layout(w).cached, "walking a new room looks again")
	GameState.data.charts["test"] = true
	check(not Minimap.layout(w).cached, "so does a chart")
	GameState.data.charts.erase("test")
	w.travel("tower/kettleforge", cell_feet(30, 19))
	await frames(2)
	var there := Minimap.layout(w)
	check(not there.cached and there.rooms.any(func(r: Dictionary) -> bool: return r.id == "tower/kettleforge" and r.how == "here"), "and so does going through a door")
	# The cost: a frame's minimap on a full map, as the HUD asks for it.
	const FRAMES := 600
	var t0 := Time.get_ticks_usec()
	for i in FRAMES:
		Minimap.layout(w)
	var kept_us := float(Time.get_ticks_usec() - t0) / FRAMES
	t0 = Time.get_ticks_usec()
	for i in 60:
		w.remove_meta(Minimap.CACHE)
		Minimap.layout(w)
	var fresh_us := float(Time.get_ticks_usec() - t0) / 60
	print("  Minimap on a full map: %.1f us a frame kept, %.1f us looked afresh" % [kept_us, fresh_us])
	check(kept_us < fresh_us * 0.5, "keeping the layout costs well under half a fresh look (%.1f against %.1f us)" % [kept_us, fresh_us])
	check(kept_us < 100.0, "and under 0.1 ms a frame (%.1f us)" % kept_us)
	w.queue_free()
	await frames(2)


## Pass 383 (bible 15.3): the rubric's Stability row asks for a 2-hour soak, and
## nothing had counted how much play the soaks give. The runner now counts it
## (about 50 minutes a full run) and fails an unfiltered run under its floor;
## this holds the floor to the bible's line.
func test_the_soak_floor_is_the_one_the_bible_gives() -> void:
	var floor_minutes: int = (load("res://tests/test_runner.gd") as Script).get_script_constant_map()["SOAK_FLOOR_MINUTES"]
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var note := bible.get_slice("**How long the soaks play (pass 383", 1).get_slice("\n\n", 0)
	check(note.contains("less than `SOAK_FLOOR_MINUTES` (%d) fails" % floor_minutes), "15.3 gives the soaks' floor (%d minutes)" % floor_minutes)
	check(floor_minutes >= 30, "the floor keeps the soaks at half an hour or more (%d)" % floor_minutes)
	var soaks := 0
	for m: Dictionary in get_method_list():
		if String(m.name).begins_with("test_"):
			soaks += 1
	check(note.contains("A full run's %d soaks" % soaks), "15.3 counts the soaks (%d)" % soaks)


## The gym soak at the slowest Game speed (70%), with a boss's slow motion and
## hitstop dropped in as the mash goes (pass 485). Every soak above runs at
## full speed, and a slower game takes shorter physics steps: no escapes, no
## embedding and no invalid position at 70% either, and Feel comes back to
## the Game speed when each burst ends.
func test_random_input_soak_at_the_slowest_game_speed() -> void:
	var problems: Array[String] = []
	var bursts := 0
	Feel.set_game_speed(0.7)
	for seed in RUNS:
		var room := Room.from_file("res://levels/gym/gym.room")
		arena.add_child(room)
		var p := Player.new()
		p.input.scripted = true
		p.position = room.spawn_position
		room.add_child(p)
		p.spawn_point = room.spawn_position
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var hold := {"move": 0, "down": 0, "up": 0, "jump": 0, "block": 0}
		var bounds := room.pixel_rect().grow(8.0)
		for f in FRAMES_PER_RUN:
			_mash(p, rng, hold)
			if f % 150 == 75:
				Feel.slowmo(0.3, 0.25)
				bursts += 1
			elif f % 150 == 0 and f > 0:
				Feel.hitstop(0.06)
				bursts += 1
			await frames(1)
			var pos := p.global_position
			if not (is_finite(pos.x) and is_finite(pos.y)):
				problems.append("seed %d frame %d: invalid position" % [seed, f])
				break
			if p.dead:
				continue
			if not bounds.has_point(pos):
				problems.append("seed %d frame %d: left the room at %s" % [seed, f, pos])
				break
			if _embedded(room, p):
				await frames(3)
				if _embedded(room, p):
					problems.append("seed %d frame %d: embedded at %s" % [seed, f, p.global_position])
					break
		room.queue_free()
		await frames(1)
	# Every burst ends on its own and gives the game back its 70%.
	await _until_real(0.4)
	check(is_equal_approx(Engine.time_scale, 0.7), "after the bursts the game runs at 70%% again (%.2f)" % Engine.time_scale)
	Feel.reset()
	Feel.set_game_speed(1.0)
	check(bursts >= 30, "slow motion and hitstop dropped in %d times" % bursts)
	check(problems.is_empty(), "the 70%% soak found no problems: %s" % [problems])
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("test_random_input_soak_at_the_slowest_game_speed"), "the bible names this test")


func _until_real(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await frames(1)

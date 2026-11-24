extends TestSuite
## Boss practice (BossPractice; Sean, 2026-11-24): any guardian, at its door,
## with the kit of its place on the critical path; a report and a log line when
## the fight ends; nothing saved.

const LOG := "user://test_practice_log.csv"
const FOREMAN := 1


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await frames(1)
	return cond.call()


## Guardian `index`'s arena, dressed in its kit, the practice begun and its
## report caught in `got`.
func _practice(index: int, got: Array) -> World:
	var w := make_world({}, BossPractice.arena_at(index))
	BossPractice.running = true
	BossPractice.dress(index)
	GameState.apply(w.player)
	w.place_at_door(BossRush.ENTRY_DOOR)
	BossPractice.log_path = LOG
	BossPractice.begin(index)
	BossPractice.on_end = func(s: Dictionary) -> void: got.append(s)
	return w


func _done() -> void:
	BossPractice.abandon()
	BossPractice.running = false
	BossPractice.on_end = Callable()
	BossPractice.log_path = BossPractice.LOG_PATH
	BossPractice.seen = {}
	if FileAccess.file_exists(LOG):
		DirAccess.remove_absolute(LOG)


func test_practice_every_guardian_of_the_rush_has_a_kit() -> void:
	for i in BossRush.ORDER.size():
		var id := BossPractice.boss_at(i)
		check(BossPractice.KITS.has(id) and BossPractice.NAMES.has(id), "%s has a kit and a name" % id)
	check(BossPractice.KITS.size() == BossRush.ORDER.size(), "and nothing else does")


## Each kit is the damage sheet's par gear (5.5) with the abilities of its
## place, and later guardians never have less.
func test_practice_the_kit_is_the_critical_paths() -> void:
	var last := {}
	for i in BossRush.ORDER.size():
		GameState.new_game()
		BossPractice.dress(i)
		var id := BossPractice.boss_at(i)
		var gear := BossPractice.gear_for(i)
		var eq: Dictionary = GameState.data.equipment
		check(eq.blade == gear[0] and eq.armor == gear[2] and eq.shield == gear[3], "%s: the par blade, armor and shield are worn (%s)" % [id, eq])
		check(GameState.temper_level(gear[0]) == int(gear[1]), "%s: the blade tempered %d times" % [id, gear[1]])
		var kit: Dictionary = BossPractice.KITS[id]
		check(int(GameState.data.max_hp) == 100 + GameState.LIFE_FRUIT_HP * int(kit.life), "%s: health from its Life Fruits" % id)
		for a: String in kit.abilities:
			check(GameState.has_ability(a), "%s: %s held" % [id, a])
		for a: String in last:
			if a not in ["life", "dew"]:
				check(kit.abilities.has(a), "%s keeps %s from the guardian before" % [id, a])
		check(int(kit.life) >= int(last.get("life", 0)) and int(kit.dew) >= int(last.get("dew", 0)), "%s: no fewer finds than before" % id)
		last = {"life": kit.life, "dew": kit.dew}
		for a: String in kit.abilities:
			last[a] = true
		for j in i:
			check(GameState.flag("boss:" + BossPractice.boss_at(j)), "%s: %s already beaten" % [id, BossPractice.boss_at(j)])
	check(BossPractice.gear_for(BossRush.ORDER.find(["likeness", "vorrhallow/evercrown_gate"]))[0] == "severance", "past Thane Vorrund, the Severance")
	check(BossPractice.KITS.thane_vorrund.abilities.has("stillstone") and not BossPractice.KITS.skyrend.abilities.has("stillstone"), "the Stillstone comes between Skyrend and the Thane")


func test_practice_starts_at_the_door_and_wakes_the_guardian() -> void:
	var got := []
	var w := _practice(FOREMAN, got)
	await frames(3)
	var door: Dictionary = w.room.doors[BossRush.ENTRY_DOOR]
	check(w.player.global_position.distance_to(w.door_arrival(door)) < 4.0, "you wake at the arena's door")
	check(w.player.abilities.get("glove", false) and not w.player.abilities.get("delvers_pick", false), "with the Glove and not yet the Pick")
	var arena := BossPractice.arena(w.get_tree())
	check(arena != null and not arena.defeated_before(), "the guardian will fight")
	w.player.input.move_x = -1 if door.edge == "right" else 1
	check(await _until(func() -> bool: return arena.fighting, 240), "walking in wakes it")
	w.player.input.move_x = 0
	await frames(30)
	check(float(BossPractice.stats.time) > 0.3, "and the clock runs (%.2f)" % float(BossPractice.stats.time))
	_done()


func test_practice_a_win_is_reported_and_logged() -> void:
	var got := []
	var w := _practice(FOREMAN, got)
	await frames(3)
	var arena := BossPractice.arena(w.get_tree())
	arena._start()
	var f := arena.boss as Foreman
	w.player.teleport(w.player.global_position + Vector2(0, -400))
	w.player.frozen = true
	await _until(func() -> bool: return f.state != "intro", 300)
	f.take_hit(10, Vector2.DOWN * 2.0)
	check(int(BossPractice.stats.dealt) > 0 and int(BossPractice.stats.landed) == 1, "the blow is counted (%d)" % int(BossPractice.stats.dealt))
	f.hp = 1
	f.take_hit(10, Vector2.DOWN * 2.0)
	check(await _until(func() -> bool: return not got.is_empty(), 600), "its fall ends the practice")
	var s: Dictionary = got[0]
	check(s.result == "won" and float(s.boss_left) == 0.0, "won")
	check(not GameState.flag("boss:foreman") and not GameState.has_ability("delvers_pick"), "and nothing is won again")
	var rows := BossPractice.report_rows(s)
	check(rows[0].label == "Result" and rows[0].right == "Won", "the report leads with the result")
	var labels := rows.map(func(r: Dictionary) -> String: return String(r.label))
	for l: String in ["Time", "Damage dealt", "Damage taken", "Potions drunk", "Magic spent", "Parries", "Dodges", "Again", "Back to the list"]:
		check(labels.has(l), "the report shows %s" % l)
	var text := FileAccess.get_file_as_string(LOG).strip_edges().split("\n")
	check(text.size() == 2 and text[0] == BossPractice.LOG_HEAD, "the log has its head and one line")
	check(text[1].split(",")[1] == "foreman" and text[1].split(",")[2] == "won", "the line names the guardian and the result: %s" % text[1])
	_done()


## The blow that would kill you ends the practice instead, by the attack that
## landed it, and nothing after it can hurt you.
func test_practice_a_killing_blow_ends_the_practice_and_spares_you() -> void:
	var got := []
	var w := _practice(FOREMAN, got)
	await frames(3)
	var arena := BossPractice.arena(w.get_tree())
	arena._start()
	var f := arena.boss as Foreman
	f.state = "pound"
	w.player.hp = 10
	w.player.facing = -int(signf(f.global_position.x - w.player.global_position.x))
	w.player.receive_attack(40, f)
	check(got.size() == 1 and got[0].result == "lost", "you fall: the practice is lost")
	check(not w.player.dead and w.player.hp == 10, "but you never die")
	check(BossPractice.words("HydraGeyser") == "Hydra geyser", "class names read as words")
	check(got[0].by_attack.has("Foreman: pound") and int(got[0].hits_taken) == 1, "the blow is put down to its move: %s" % [got[0].by_attack])
	check(int(got[0].taken) > 0, "with its damage (%d)" % int(got[0].taken))
	w.player.take_damage(50)
	check(w.player.hp == 10, "after it, nothing lands")
	check(float(got[0].boss_left) > 0.9, "the guardian's health is reported (%.2f)" % float(got[0].boss_left))
	_done()


func test_practice_parries_potions_spells_and_dashes_are_counted() -> void:
	var got := []
	var w := _practice(4, got)
	await frames(3)
	var p := w.player
	var shot := Node2D.new()
	w.room.add_child(shot)
	shot.global_position = p.global_position + Vector2(p.facing * 20, -10)
	p._parry_timer = 0.2
	check(p.receive_attack(10, shot) == "parried", "a parry")
	check(int(BossPractice.stats.parries) == 1 and int(BossPractice.stats.hits_taken) == 0, "counts as a parry, not a hit")
	shot.free()
	BossPractice.note("flasks")
	p.input.spell_pressed = true
	p.mp = p.max_mp
	p._try_cast()
	p.input.spell_pressed = false
	check(int(BossPractice.stats.spells) == 1 and float(BossPractice.stats.mp) > 0.0, "a spell and its magic (%.0f)" % float(BossPractice.stats.mp))
	check(int(BossPractice.stats.flasks) == 1, "a potion")
	_done()


func test_practice_saves_nothing() -> void:
	BossPractice.running = true
	check(not GameState.save_game(), "no flask is written")
	BossPractice.running = false


## The list says what each guardian is fought with.
func test_practice_the_list_names_each_kit() -> void:
	for i in BossRush.ORDER.size():
		var line := BossPractice.kit_line(i)
		check(line.contains("HP") and line.contains(String(GameData.item(BossPractice.gear_for(i)[0]).name)), "%s: %s" % [BossPractice.boss_at(i), line])

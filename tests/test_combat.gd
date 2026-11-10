extends TestSuite
## Melee combo, shield, potion, spells, MP, gold and death (design bible section 5).

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


func _arena_with(ch: String, cell: Vector2i) -> Room:
	var rows := ARENA.duplicate()
	var row: String = rows[cell.y]
	rows[cell.y] = row.substr(0, cell.x) + ch + row.substr(cell.x + 1)
	return make_room(rows)


func _find(room: Room, type: Variant) -> Node:
	for c in room.get_children():
		if is_instance_of(c, type):
			return c
	return null


func test_three_hit_ground_combo() -> void:
	var room := _arena_with("E", Vector2i(5, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	var dummy: TrainingDummy = _find(room, TrainingDummy)
	var c := p.combat
	var seen: Array[int] = []
	for i in 3:
		p.input.attack_pressed = true
		await frames(1)
		seen.append(p.combo_index)
		await frames(int(c.combo_cooldowns[i] * 60.0) + 1)
	check(seen == [1, 2, 3], "combo indices %s" % [seen])
	check(dummy.hp == TrainingDummy.HP - c.slash_damage * 2 - c.heavy_damage, "two light hits and one heavy (dummy hp %d)" % dummy.hp)


func test_combo_resets_after_window() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.input.attack_pressed = true
	await frames(1)
	await frames(int(p.combat.combo_window * 60.0) + 5)
	p.input.attack_pressed = true
	await frames(1)
	check(p.combo_index == 1, "combo restarts after the window (index %d)" % p.combo_index)


func test_air_combo_is_two_hits() -> void:
	var rows := ARENA.duplicate()
	for i in 12:
		rows.insert(1, "#..................#")
	var room := make_room(rows)
	var p := make_player(room, Vector2i(9, 1), {"glove": false})
	var seen: Array[int] = []
	for i in 3:
		p.input.attack_pressed = true
		await frames(1)
		seen.append(p.combo_index)
		await frames(13)
	check(seen == [1, 2, 1], "air combo cycles after two hits %s" % [seen])


func test_attack_press_is_buffered() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.input.attack_pressed = true
	await frames(4)
	# Pressed during the cooldown; it should fire as soon as the cooldown ends.
	p.input.attack_pressed = true
	await frames(int(p.combat.combo_cooldowns[0] * 60.0))
	check(p.combo_index == 2, "buffered press continued the combo (index %d)" % p.combo_index)


func _dwarf_arena() -> Array:
	var room := _arena_with("D", Vector2i(6, 6))
	var p := make_player(room, Vector2i(3, 6))
	var dwarf: RotDwarf = _find(room, RotDwarf)
	return [room, p, dwarf]


## Waits until the swing is `frames_before` frames away (1 = it lands next frame).
func _wait_for_swing(dwarf: RotDwarf, frames_before: int) -> void:
	for i in 120:
		if dwarf.state == "windup" and dwarf.state_time >= RotDwarf.WINDUP - frames_before / 60.0:
			return
		await frames(1)


func test_parry_staggers_and_prevents_damage() -> void:
	var a := _dwarf_arena()
	var p: Player = a[1]
	var dwarf: RotDwarf = a[2]
	await _wait_for_swing(dwarf, 3)
	p.input.block_pressed = true
	p.input.block_held = true
	await frames(6)
	check(p.hp == p.max_hp, "parried swing does no damage (hp %d)" % p.hp)
	check(dwarf.is_staggered(), "parry staggers the Rot Dwarf")


func test_guard_halves_damage_and_costs_mp() -> void:
	var a := _dwarf_arena()
	var p: Player = a[1]
	var dwarf: RotDwarf = a[2]
	p.input.block_held = true
	await _wait_for_swing(dwarf, 1)
	var mp_before := p.mp
	await frames(4)
	var expected := p.max_hp - int(round(RotDwarf.SWING_DAMAGE * (1.0 - p.combat.guard_reduction)))
	check(p.hp == expected, "guarded hit takes reduced damage (hp %d, want %d)" % [p.hp, expected])
	check(p.mp < mp_before - p.combat.guard_mp_cost + 1.0, "guarding costs MP")


## A guard break (pass 242): a guard held with too little MP to pay for the
## blow breaks with its own sound, the blow lands whole, and the shield stays
## down until Block is let go and raised again.
func test_a_guard_with_no_mp_breaks_and_drops() -> void:
	var a := _dwarf_arena()
	var p: Player = a[1]
	var dwarf: RotDwarf = a[2]
	p.input.block_held = true
	await frames(2)
	p.mp = p.combat.guard_mp_cost - 1.0
	check(p.is_blocking, "the guard is up")
	await _wait_for_swing(dwarf, 1)
	Sfx.recent.clear()
	await frames(4)
	check(p.hp == p.max_hp - RotDwarf.SWING_DAMAGE, "with too little MP the blow lands whole (hp %d)" % p.hp)
	check(Player.GUARD_BREAK_SOUND in Sfx.recent and not ("guard" in Sfx.recent), "the guard breaks with its own sound, not the held guard's (%s)" % [Sfx.recent])
	check(p.guard_broken and not p.is_blocking, "and the shield drops")
	await frames(10)
	check(not p.is_blocking, "it stays down while Block is still held")
	p.input.block_held = false
	await frames(1)
	p.input.block_held = true
	await frames(1)
	check(p.is_blocking and not p.guard_broken, "let go and raise it again and it is back")
	p.input.block_held = false


func test_clean_hit_knocks_back() -> void:
	var a := _dwarf_arena()
	var p: Player = a[1]
	var dwarf: RotDwarf = a[2]
	await _wait_for_swing(dwarf, 1)
	await frames(3)
	check(p.hp == p.max_hp - RotDwarf.SWING_DAMAGE, "full damage without the shield (hp %d)" % p.hp)
	check(p.velocity.x < 0.0 and p.invulnerable, "knocked away and briefly invulnerable")


func test_red_potion_heals_over_drink_time() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.hp = 50
	var x0 := p.global_position.x
	p.input.heal_pressed = true
	p.input.move_x = 1
	await frames(int(p.combat.drink_time * 60.0) - 5)
	check(p.hp == 50 and p.is_drinking, "still drinking before the drink time ends")
	check(absf(p.global_position.x - x0) < 0.5, "can't walk while drinking")
	await frames(8)
	check(p.hp == 50 + p.combat.flask_heal, "healed %d (hp %d)" % [p.combat.flask_heal, p.hp])
	check(p.flask_charges == p.combat.flask_charges - 1, "one charge used")


func test_potion_interrupted_keeps_charge() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.hp = 50
	p.input.heal_pressed = true
	await frames(10)
	p.take_damage(10)
	await frames(40)
	check(p.hp == 40, "no heal after being hit mid-drink (hp %d)" % p.hp)
	check(p.flask_charges == p.combat.flask_charges, "interrupted drink keeps the charge")


func test_torrent_costs_mp_and_hits() -> void:
	var room := _arena_with("E", Vector2i(12, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	var dummy: TrainingDummy = _find(room, TrainingDummy)
	var mp0 := p.mp
	p.input.spell_pressed = true
	await frames(1)
	check(p.mp < mp0 - Spells.cost("torrent") + 0.5, "Deluge costs %.0f MP" % Spells.cost("torrent"))
	await frames(40)
	check(dummy.hits_taken == 1, "water bolt hits the dummy")


func test_torrent_needs_mp_and_ability() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.mp = 5.0
	p.input.spell_pressed = true
	await frames(1)
	check(runner.get_tree().get_nodes_in_group("projectile").is_empty(), "no cast without enough MP")
	p.mp = p.combat.max_mp
	p.abilities["torrent"] = false
	p.input.spell_pressed = true
	await frames(1)
	check(runner.get_tree().get_nodes_in_group("projectile").is_empty(), "no cast without the spell")


func test_melee_hit_restores_mp() -> void:
	var room := _arena_with("E", Vector2i(5, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.mp = 20.0
	p.input.attack_pressed = true
	await frames(3)
	check(p.mp >= 20.0 + p.combat.mp_per_melee_hit, "MP from a melee hit (mp %.1f)" % p.mp)


func test_enemy_drops_gold_that_flies_to_player() -> void:
	var room := _arena_with("M", Vector2i(6, 6))
	var p := make_player(room, Vector2i(3, 6))
	var m: Blinkhop = _find(room, Blinkhop)
	m.gold_min = 7
	m.gold_max = 7
	m.contact_damage = 0
	await frames(2)
	m.take_hit(999, Vector2(1, 0))
	await frames(150)
	check(p.gold == 7, "collected all 7 gold (got %d)" % p.gold)


func test_death_drops_purse_and_respawns() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.spawn_point = p.global_position
	p.gold = 100
	p.teleport(p.global_position + Vector2(160, 0))
	await frames(3)
	var death_x := p.global_position.x
	p.take_damage(999)
	check(p.dead, "player died")
	check(p.gold == 40 and p.purse != null and p.purse.value == 60, "60% of gold dropped in a purse")
	await frames(int(p.combat.respawn_delay * 60.0) + 2)
	check(not p.dead and p.hp == p.max_hp, "respawned with full health")
	check(absf(p.global_position.x - p.spawn_point.x) < 2.0, "respawned at the spawn point")
	# Walk back to the purse.
	for i in 120:
		p.input.move_x = 1
		await frames(1)
		if p.global_position.x > death_x:
			break
	p.input.move_x = 0
	await frames(2)
	check(p.gold == 100, "recovered the purse (gold %d)" % p.gold)


func test_second_death_loses_the_purse() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.gold = 100
	p.teleport(p.global_position + Vector2(160, 0))
	await frames(2)
	p.take_damage(999)
	var first := p.purse
	await frames(int(p.combat.respawn_delay * 60.0) + 70)
	p.take_damage(999)
	await frames(1)
	check(not is_instance_valid(first), "the first purse is gone")
	check(p.purse != null and p.purse.value == 24, "new purse holds 60%% of the remaining 40 (got %s)" % [p.purse.value if p.purse else -1])


func test_contact_damage() -> void:
	var room := _arena_with("M", Vector2i(3, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(3)
	check(p.hp == p.max_hp - 20, "touching an enemy hurts (hp %d)" % p.hp)


func test_camera_subpixel_and_bounds() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	var cam := GameCamera.new()
	cam.target = p
	cam.view_size = Vector2(160, 90)
	cam.set_room_limits(room.pixel_rect())
	arena.add_child(cam)
	var ok := true
	for i in 60:
		p.input.move_x = 1
		await frames(1)
		# Whole render pixels: GameCamera.DETAIL of them per world pixel.
		var scaled := cam.global_position * GameCamera.DETAIL
		var whole := scaled == scaled.floor()
		var step := 1.0 / GameCamera.DETAIL
		var frac_ok := cam.subpixel.x >= 0.0 and cam.subpixel.x < step and cam.subpixel.y >= 0.0 and cam.subpixel.y < step
		var inside := cam.exact_position.x >= 80.0 - 0.01 and cam.exact_position.x <= room.pixel_rect().end.x - 80.0 + 0.01
		ok = ok and whole and frac_ok and inside
	check(ok, "camera stays on whole render pixels, sub-pixel remainder under one, inside room bounds")


func test_camera_renders_at_detail() -> void:
	var cam := GameCamera.new()
	arena.add_child(cam)
	await frames(1)
	check(cam.zoom == Vector2(GameCamera.DETAIL, GameCamera.DETAIL), "the camera zooms the world to its render density (%s)" % cam.zoom)
	cam.queue_free()


func test_fire_arcs_bursts_and_scorches_foes_in_reach() -> void:
	# Bible 4.1: Emberfall is thrown in an arc and bursts on what it meets.
	var room := _arena_with("E", Vector2i(10, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	var dummy: TrainingDummy = _find(room, TrainingDummy)
	p.equipped_spell = "fire"
	var mp0 := p.mp
	p.input.spell_pressed = true
	await frames(1)
	check(absf(p.mp - (mp0 - Spells.cost("fire"))) < 0.5, "Emberfall costs %.0f MP" % Spells.cost("fire"))
	var balls := runner.get_tree().get_nodes_in_group("projectile")
	check(balls.size() == 1 and balls[0] is Fireball, "a fireball is thrown")
	if balls.is_empty():
		return
	var ball := balls[0] as Fireball
	var y0 := ball.global_position.y
	await frames(6)
	check(ball.global_position.y < y0 - 4.0, "it rises first (%.1f -> %.1f)" % [y0, ball.global_position.y])
	await frames(70)
	check(dummy.hits_taken == 1, "it bursts on the dummy (%d hits)" % dummy.hits_taken)
	check(runner.get_tree().get_nodes_in_group("projectile").is_empty(), "and is gone")


func test_next_spell_cycles_only_through_spells_you_own() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.abilities["fire"] = false
	p.abilities["thunder"] = false
	p.abilities["wisplight"] = false
	p.equipped_spell = "torrent"
	p.input.spell_next_pressed = true
	await frames(1)
	check(p.equipped_spell == "torrent", "with only Deluge, Next Spell keeps it")
	p.abilities["fire"] = true
	p.input.spell_next_pressed = true
	await frames(1)
	check(p.equipped_spell == "fire", "with Emberfall owned it switches to Emberfall")
	p.input.spell_next_pressed = true
	await frames(1)
	check(p.equipped_spell == "torrent", "and back round to Deluge")
	p.abilities["torrent"] = false
	p.input.spell_next_pressed = true
	await frames(1)
	check(p.equipped_spell == "fire", "it skips a spell you don't own")


func test_thunder_bolt_strikes_a_foe() -> void:
	var room := _arena_with("E", Vector2i(12, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	var dummy: TrainingDummy = _find(room, TrainingDummy)
	p.equipped_spell = "thunder"
	var mp0 := p.mp
	p.input.spell_pressed = true
	await frames(1)
	check(absf(p.mp - (mp0 - Spells.cost("thunder"))) < 0.5, "Tempest Lance costs %.0f MP" % Spells.cost("thunder"))
	var bolts := runner.get_tree().get_nodes_in_group("projectile")
	check(bolts.size() == 1 and bolts[0] is ThunderBolt, "a bolt flies")
	await frames(20)
	check(dummy.hits_taken == 1, "and strikes the dummy (%d hits)" % dummy.hits_taken)



## Pass 362 (bible 5.3, Swing reach): how far a swing reaches was in no line
## of the bible, and only the Broad Sword's growth was tested. Each blade's
## reach and arc are held to 5.2, every swing's box to 5.3's row, measured from
## the real swing, and a dummy at the edge of the Short Sword's reach is struck
## while one a few px past it is missed.
func test_every_swing_reaches_as_far_as_5_3_says() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var row := bible.get_slice("| Swing reach (pass 362) |", 1).get_slice("\n", 0)
	check(row != "", "5.3 has its Swing reach row")
	var blades_row := bible.get_slice("### 5.2 ", 1).get_slice("\n| Blade |", 1).get_slice("\n", 0)
	var items := GameData.table("items")
	for id: String in ["short_sword", "long_sword", "dwarvish_broad_sword", "severance"]:
		var cell := blades_row.get_slice("|", ["short_sword", "long_sword", "dwarvish_broad_sword", "severance"].find(id))
		var reach := int(items[id].get("reach", 0))
		var arc := int(items[id].get("arc", 0))
		check(cell.contains("reach %d" % reach) and (arc == 0 or cell.contains("arc %d" % arc)), "5.2 gives the %s's reach %d%s (%s)" % [id, reach, " and arc %d" % arc if arc else "", cell.strip_edges().left(80)])
	var room := _arena_with(".", Vector2i(3, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	var front := Player.BODY_SIZE.x * 0.5
	for id: String in ["short_sword", "long_sword", "dwarvish_broad_sword", "severance"]:
		GameState.data.equipment.blade = id
		GameState.data.equipment.offhand = ""
		GameState.refresh_stats(p)
		var reach := float(items[id].get("reach", 0))
		var arc := float(items[id].get("arc", 0))
		for kind: String in ["side", "up", "thrust"]:
			p.attack_kind = kind
			var r := p._attack_rect()
			var x0 := r.position.x - p.global_position.x
			var feet := p.global_position.y
			match kind:
				"side":
					check(x0 < front and is_equal_approx(r.end.x - p.global_position.x - front, 34.0 + reach) and is_equal_approx(r.size.y, 26.0 + arc), "%s: a slash cuts from inside the body to %s px past it, %s px tall (%s)" % [id, String.num(34.0 + reach), String.num(26.0 + arc), r])
				"up":
					check(r.size.is_equal_approx(Vector2(34, 36)) and is_equal_approx(feet - r.position.y - Player.BODY_SIZE.y, 32.0), "%s: an up-slash is 34 by 36 and reaches 32 px over the head (%s)" % [id, r])
				"thrust":
					check(is_equal_approx(x0, front) and is_equal_approx(r.size.x, 52.0 + reach) and is_equal_approx(r.size.y, 13.0 + arc * 0.5), "%s: a Thrust runs %s px from the body's edge, %s px tall (%s)" % [id, String.num(52.0 + reach), String.num(13.0 + arc * 0.5), r])
	for n: float in [36, 26, 34, 32, 52, 13]:
		check(written_exactly_in(row, n), "the row writes %s" % String.num(n))
	check(row.contains("28x24") and bible.get_slice("### 6.6 ", 1).get_slice("\n### ", 0).contains("28x24") and Player.DOWN_STRIKE_SIZE == Vector2(28, 24), "and the down-strike is 6.6's 28x24")
	# For real: the Short Sword strikes a dummy at the edge of its reach and
	# misses one just past it.
	GameState.data.equipment.blade = "short_sword"
	GameState.refresh_stats(p)
	for past: float in [-2.0, 2.0]:
		var dummy := TrainingDummy.new()
		room.add_child(dummy)
		dummy.global_position = Vector2(p.global_position.x + front + 34.0 + 9.0 + past, p.global_position.y)
		await frames(2)
		p.facing = 1
		p.input.attack_pressed = true
		await frames(1)
		p.input.attack_pressed = false
		await frames(12)
		var struck := dummy.hits_taken > 0
		check(struck == (past < 0.0), "a dummy %s px %s the reach is %s" % [String.num(absf(past)), "inside" if past < 0.0 else "past", "struck" if struck else "missed"])
		dummy.free()
		await frames(30)


func test_the_dwarvish_broad_sword_sweeps_wide_but_swings_slow() -> void:
	var room := _arena_with("E", Vector2i(6, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	var dummy: TrainingDummy = _find(room, TrainingDummy)
	var plain := p._attack_rect().size
	GameState.data.equipment.blade = "dwarvish_broad_sword"
	GameState.refresh_stats(p)
	check(p.slash_damage == 17 and p.heavy_damage == 32, "it cuts for 17 and 32 (%d, %d)" % [p.slash_damage, p.heavy_damage])
	p.input.attack_pressed = true
	await frames(1)
	var big := p._attack_rect().size
	check(big == plain + Vector2(16, 20), "its slash reaches 16 px further and sweeps 20 px taller (%s from %s)" % [big, plain])
	var wait := p.combat.combo_cooldowns[0] * 1.3
	check_near(p._attack_cooldown, wait - 1.0 / 60.0, 0.02, "and the swing takes 30% longer to recover")
	await frames(3)
	check(dummy.hp == TrainingDummy.HP - 17, "it strikes the dummy two tiles away (hp %d)" % dummy.hp)
	GameState.data.equipment.blade = "long_sword"
	GameState.refresh_stats(p)
	check(p.arc_bonus == 0.0 and p.swing_mult == 1.0, "other blades keep the plain arc and pace")


func test_a_wide_room_eases_the_camera_out() -> void:
	# Bible 6.7: a room with `camera: wide` frames 25% more each way, easing out.
	var rows := ARENA.duplicate()
	for i in 30:
		rows.insert(1, "#..................#")
	var room := make_room(rows)
	var p := make_player(room, Vector2i(3, 36))
	var cam := GameCamera.new()
	cam.target = p
	cam.view_size = Vector2(160, 90)
	cam.set_room_limits(room.pixel_rect(), true)
	arena.add_child(cam)
	check(cam.frame_goal == GameCamera.WIDE and cam.frame_scale == 1.0, "it starts at the normal framing and aims wide")
	await frames(6)
	var mid := cam.frame_scale
	check(mid < 1.0 and mid > GameCamera.WIDE, "it eases out, not in one jump (%.3f)" % mid)
	await frames(int(GameCamera.ZOOM_EASE * 60.0 * 3.0))
	check_near(cam.frame_scale, GameCamera.WIDE, 0.002, "and settles wide")
	check(cam.zoom.is_equal_approx(Vector2.ONE * GameCamera.DETAIL * GameCamera.WIDE), "the zoom follows (%s)" % cam.zoom)
	check(cam.visible_size().is_equal_approx(Vector2(200, 112.5)), "showing 25%% more each way (%s)" % cam.visible_size())
	var half := cam.visible_size() * 0.5
	var r := room.pixel_rect()
	var e := cam.exact_position
	check(e.x >= r.position.x + half.x - 0.01 and e.y <= r.end.y - half.y + 0.01, "the wider view still stays inside the room (%s)" % e)
	var step := 1.0 / GameCamera.DETAIL
	check(cam.subpixel.x >= 0.0 and cam.subpixel.x < step and cam.subpixel.y < step, "the sub-pixel shift stays under one render pixel (%s)" % cam.subpixel)
	cam.set_room_limits(r)
	check(cam.frame_scale == 1.0 and cam.frame_goal == 1.0, "a normal room snaps back at once, so the view never shows past its edges")
	cam.queue_free()


func test_the_wide_camera_never_shows_past_a_small_room() -> void:
	var room := make_room(ARENA)  # 320 x 128 px
	var cam := GameCamera.new()
	cam.view_size = Vector2(160, 90)
	cam.set_room_limits(room.pixel_rect(), true)
	check(cam.visible_size().y <= 128.0 and cam.frame_goal >= 90.0 / 128.0 - 0.001, "the framing stops where the room's height runs out (%.3f)" % cam.frame_goal)
	cam.set_room_limits(Rect2(0, 0, 170, 200), true)
	check_near(cam.frame_goal, 160.0 / 170.0, 0.001, "and where its width runs out")
	cam.set_room_limits(Rect2(0, 0, 150, 80), true)
	check(cam.frame_goal == 1.0, "a room smaller than the screen is never zoomed in")
	cam.free()


func test_the_roost_frames_the_storm_wide() -> void:
	var w := make_world({}, "spires/roost")
	await frames(3)
	check(w.room.wide_camera(), "the Roost asks for the wide camera")
	check_near(w.camera.frame_goal, GameCamera.WIDE, 0.001, "and has the sky to frame it (%.3f)" % w.camera.frame_goal)
	check(w.room.pixel_rect().size.y >= w.camera.view_size.y / GameCamera.WIDE, "it is tall enough for the wide view")


func test_wisplight_wakes_then_seeks_the_nearest_foe() -> void:
	# Bible 4.1: Wisplight is a homing spirit orb.
	var room := _arena_with("E", Vector2i(12, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	var dummy: TrainingDummy = _find(room, TrainingDummy)
	p.equipped_spell = "wisplight"
	var mp0 := p.mp
	p.input.spell_pressed = true
	await frames(1)
	check(absf(p.mp - (mp0 - Spells.cost("wisplight"))) < 0.5, "Wisplight costs %.0f MP" % Spells.cost("wisplight"))
	var orbs := runner.get_tree().get_nodes_in_group("projectile")
	check(orbs.size() == 1 and orbs[0] is WispOrb, "one spirit orb leaves the hand")
	if orbs.is_empty():
		return
	var orb := orbs[0] as WispOrb
	await frames(int(WispOrb.WAKE * 60.0) - 2)
	check(orb.velocity.length() < WispOrb.DRIFT, "it hangs while it wakes, the tell (%.0f px/s)" % orb.velocity.length())
	await frames(4)
	check(orb.target == dummy, "then it chooses the dummy")
	await _until(func() -> bool: return dummy.hits_taken > 0, 90)
	check(dummy.hits_taken == 1 and dummy.hp == TrainingDummy.HP - 14, "and strikes it for 14 (hp %d)" % dummy.hp)


func test_wisplight_turns_back_for_a_foe_behind() -> void:
	var rows := ARENA.duplicate()
	for i in 4:
		rows.insert(1, "#..................#")
	rows[10] = "#.E................#"
	var room := make_room(rows)
	var p := make_player(room, Vector2i(9, 10))
	await frames(6)
	var dummy: TrainingDummy = _find(room, TrainingDummy)
	p.facing = 1
	p.equipped_spell = "wisplight"
	p.input.spell_pressed = true
	await frames(1)
	var hit := await _until(func() -> bool: return dummy.hits_taken > 0, 120)
	check(hit, "an orb cast away from the only foe wheels round and finds it")


func test_wisplight_swarm_fans_three_orbs() -> void:
	var room := _arena_with("E", Vector2i(12, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	var dummy: TrainingDummy = _find(room, TrainingDummy)
	p.wisplight_swarm = true
	p.equipped_spell = "wisplight"
	var mp0 := p.mp
	p.input.spell_pressed = true
	await frames(1)
	var orbs := runner.get_tree().get_nodes_in_group("projectile")
	check(orbs.size() == 3, "Wisp Swarm throws three orbs (%d)" % orbs.size())
	check(absf(p.mp - (mp0 - Spells.cost("wisplight"))) < 0.5, "for the cost of one")
	if orbs.size() == 3:
		var a := [(orbs[0] as WispOrb).heading.angle(), (orbs[1] as WispOrb).heading.angle(), (orbs[2] as WispOrb).heading.angle()]
		a.sort()
		check(a[1] - a[0] > 0.4 and a[2] - a[1] > 0.4, "in a fan (%s)" % [a])
	await _until(func() -> bool: return dummy.hits_taken >= 3, 150)
	check(dummy.hp == TrainingDummy.HP - 30, "each strikes for 10 (hp %d)" % dummy.hp)


## Witherbloom (bible 4.1, pass 132): a ring of blight strikes every foe around
## you once, through walls; bosses take half.
func test_death_strikes_every_foe_around_through_walls() -> void:
	var rows := ARENA.duplicate()
	for y in range(1, 7):
		rows[y] = rows[y].substr(0, 9) + "#" + rows[y].substr(10)
	rows[6] = "#.E......#..E......#"
	var room := make_room(rows)
	var p := make_player(room, Vector2i(5, 6))
	await frames(6)
	var dummies: Array[TrainingDummy] = []
	for c in room.get_children():
		if c is TrainingDummy:
			dummies.append(c)
	check(dummies.size() == 2, "two dummies, one beyond a wall")
	if dummies.size() != 2:
		return
	var far := dummies[0] if dummies[0].global_position.x > dummies[1].global_position.x else dummies[1]
	far.add_to_group("boss")
	p.abilities["death"] = true
	p.max_mp = 60.0
	p.mp = 60.0
	p.equipped_spell = "death"
	Sfx.recent.clear()
	p.input.spell_pressed = true
	await frames(1)
	p.input.spell_pressed = false
	check(absf(p.mp - (60.0 - Spells.cost("death"))) < 0.5, "Witherbloom costs %.0f MP" % Spells.cost("death"))
	check(Spells.cost("death") >= 40.0 and Spells.ORDER.has("death"), "the dearest spell, on the Next Spell cycle")
	check(Sfx.recent.has("death_wave"), "it tolls (%s)" % [Sfx.recent])
	await frames(int(DeathWave.DURATION * 60.0) + 4)
	var near := dummies[0] if far == dummies[1] else dummies[1]
	check(near.hits_taken == 1 and near.hp == TrainingDummy.HP - 36, "the foe beside you takes 36, once (hp %d, hits %d)" % [near.hp, near.hits_taken])
	check(far.hits_taken == 1 and far.hp == TrainingDummy.HP - 18, "a boss beyond the wall takes half, 18 (hp %d)" % far.hp)
	await frames(20)
	check(runner.get_tree().get_nodes_in_group("projectile").is_empty(), "then the ring is gone")
	p.input.spell_pressed = true
	await frames(1)
	check(p.mp < Spells.cost("death") and runner.get_tree().get_nodes_in_group("projectile").is_empty(), "and there is not enough MP left for a second")
	p.input.spell_pressed = false
	far.remove_from_group("boss")


## Lithic Fracture (Sean's spell, pass 497): a bare foe on the floor, its hp set
## before it enters the tree, so a strike can be read off its health.
func _lithic_foe(room: Room, pos: Vector2, hp := 50) -> Enemy:
	var e := Enemy.new()
	e.max_hp = hp
	e.position = pos
	room.add_child(e)
	return e


## The wave is planned in tiles: six columns 32 px apart along the floor, stepping
## down a ledge, stopping at a wall across the floor and at the edge of a pit.
func test_lithic_fracture_cascades_along_the_floor() -> void:
	var flat := make_room(ARENA)
	await frames(4)
	var origin := cell_feet(3, 6)
	var plan := LithicWave.plan_columns(flat.get_world_2d().direct_space_state, origin, 1)
	var cols: Array = plan.positions
	check(cols.size() == LithicWave.COLUMNS, "six columns erupt over flat floor (%d)" % cols.size())
	if cols.size() == LithicWave.COLUMNS:
		check(absf(cols[0].x - (origin.x + LithicWave.FIRST)) < 0.5, "the first stands about 32 px ahead (%.0f)" % (cols[0].x - origin.x))
		var even := true
		for i in range(1, cols.size()):
			if absf((cols[i].x - cols[i - 1].x) - LithicWave.STEP) > 0.5 or absf(cols[i].y - cols[0].y) > 0.5:
				even = false
		check(even, "each is 32 px on from the last, along the one floor")
	# A wall across the floor stops the wave.
	var walled := ARENA.duplicate()
	walled[6] = "#........#.........#"
	var wall_room := make_room(walled)
	await frames(4)
	check(LithicWave.plan_columns(wall_room.get_world_2d().direct_space_state, cell_feet(3, 6), 1).positions.size() == 2,
		"a wall at cell 9 stops the wave after two columns")
	# A gap in the floor stops the wave at the pit's edge.
	var holed := ARENA.duplicate()
	holed[7] = "#########.##########"
	var pit_room := make_room(holed)
	await frames(4)
	check(LithicWave.plan_columns(pit_room.get_world_2d().direct_space_state, cell_feet(3, 6), 1).positions.size() == 2,
		"a pit at cell 9 stops the wave at its edge")
	# A ledge down: the wave follows the floor as it drops.
	var ledge := make_room([
		"####################", "#..................#", "#..................#", "#..................#",
		"#..................#", "########...........#", "########...........#",
		"####################", "####################"])
	await frames(4)
	var lcols: Array = LithicWave.plan_columns(ledge.get_world_2d().direct_space_state, cell_feet(3, 4), 1).positions
	check(lcols.size() == LithicWave.COLUMNS, "six columns step down the ledge (%d)" % lcols.size())
	if lcols.size() == LithicWave.COLUMNS:
		check(lcols[0].y < lcols[5].y and lcols[5].y - lcols[0].y == 2 * Room.TILE, "they step down two tiles to follow the lower floor")


func test_a_lithic_wave_staggers_and_slows_what_it_strikes() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6), {"fracture": true})
	p.equipped_spell = "fracture"
	p.max_mp = 60.0
	p.mp = 60.0
	await frames(4)
	var hit := _lithic_foe(room, cell_feet(7, 6), 50)  # on the second column
	var miss := _lithic_foe(room, cell_feet(2, 6), 50)  # behind the caster, never reached
	await frames(2)
	var mp0 := p.mp
	p.input.spell_pressed = true
	await frames(1)
	p.input.spell_pressed = false
	check(absf(p.mp - (mp0 - 24.0)) < 0.5, "a cast costs 24 MP (%.1f)" % (mp0 - p.mp))
	await frames(24)
	check(hit.hp == 50 - 6, "the wave strikes a foe for its 6 (hp %d)" % hit.hp)
	check(hit.hits_taken == 1, "struck once per cast (%d)" % hit.hits_taken)
	check(hit.is_staggered(), "and staggers it")
	check(hit.is_slowed(), "and slows it")
	check(miss.hp == 50 and miss.hits_taken == 0, "a foe the wave never reaches is untouched (hp %d)" % miss.hp)


func test_a_boss_is_slowed_by_lithic_fracture_but_not_staggered() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6), {"fracture": true})
	p.equipped_spell = "fracture"
	p.max_mp = 60.0
	p.mp = 60.0
	await frames(4)
	var boss := _lithic_foe(room, cell_feet(7, 6), 80)
	boss.add_to_group("boss")
	await frames(2)
	p.input.spell_pressed = true
	await frames(1)
	p.input.spell_pressed = false
	await frames(24)
	check(boss.hp == 80 - 6, "a boss takes the 6 (hp %d)" % boss.hp)
	check(boss.is_slowed(), "and is slowed")
	check(not boss.is_staggered(), "but a boss is never staggered")


## The slow runs a foe's clock at half, so a windup keyed to it can only lengthen:
## no telegraph can drop below Enemy.MIN_TELEGRAPH while slowed.
func test_a_slowed_foes_tell_never_drops_below_the_floor() -> void:
	var room := make_room(ARENA)
	var foe := _lithic_foe(room, cell_feet(7, 6), 50)
	await frames(2)
	foe.slow()
	check(foe.is_slowed(), "the slow takes hold")
	var t0 := foe.game_time
	await frames(30)
	check(absf((foe.game_time - t0) - 0.25) < 0.05, "a slowed foe's clock runs at half (%.2f s in 0.5 s)" % (foe.game_time - t0))
	check(Enemy.SLOW_FACTOR < 1.0 and Enemy.MIN_TELEGRAPH / Enemy.SLOW_FACTOR >= Enemy.MIN_TELEGRAPH,
		"so a tell at the %.2f s floor only stretches when slowed" % Enemy.MIN_TELEGRAPH)
	await frames(170)
	check(not foe.is_slowed(), "and the slow ends after its three seconds")


func test_cracked_stone_seals_open_only_to_lithic_fracture() -> void:
	var rows := ARENA.duplicate()
	rows[6] = rows[6].substr(0, 5) + "[" + rows[6].substr(6)  # a seal two tiles ahead of the caster
	var room := make_room(rows)
	var p := make_player(room, Vector2i(3, 6), {"fracture": true, "torrent": true})
	p.max_mp = 60.0
	p.mp = 60.0
	await frames(4)
	var seal: StoneSeal = _find(room, StoneSeal)
	check(seal != null, "the seal stands as a wall")
	# A Deluge bolt leaves it whole.
	p.equipped_spell = "torrent"
	p.input.spell_pressed = true
	await frames(1)
	p.input.spell_pressed = false
	await frames(30)
	check(is_instance_valid(seal) and not seal.is_broken(), "a Deluge bolt does not break it")
	# A Lithic Fracture column shatters it.
	p.equipped_spell = "fracture"
	p.mp = 60.0
	p.input.spell_pressed = true
	await frames(1)
	p.input.spell_pressed = false
	await frames(20)
	check(seal.is_broken(), "only a Lithic Fracture cast shatters the seal")
	check("fracture" == ItemPickup.KIND_BY_CHAR.get(":", ""), "legend : is the Lithic Fracture scroll")


func test_the_death_scroll_is_a_late_secret() -> void:
	check(ItemPickup.KIND_BY_CHAR.get("{", "") == "death" and "death" in ItemPickup.ABILITIES, "legend { is the Witherbloom scroll")
	var text := FileAccess.get_file_as_string("res://levels/vorrhallow/kings_kennels.room")
	check(text.contains("{"), "it lies in the Thane's Kennels' loft, up the hidden planks")
	GameState.new_game()
	check(GameState.data.abilities.has("death") and not GameState.data.abilities.death, "a new game starts without it")


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await frames(1)
	return cond.call()


func test_a_hit_sparks_where_the_blade_meets_the_foe() -> void:
	var room := _arena_with("E", Vector2i(5, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	var dummy: TrainingDummy = _find(room, TrainingDummy)
	p.input.attack_pressed = true
	await frames(2)
	var spark: HitSpark = _find(room, HitSpark)
	if not check(spark != null, "a hit throws a spark"):
		return
	check(spark.dir.x > 0.0 and spark.size == 1.0, "along the swing, light-sized")
	var swing := p._attack_rect().grow(1.0)
	check(swing.has_point(spark.global_position), "inside the swing, where it meets the foe (%s)" % spark.global_position)
	check(spark.global_position.x <= dummy.global_position.x + 0.5, "on the near side of the foe")
	# Pass 530: on the foe's near edge, where the blade bites, not over its middle (the
	# dummy's box is 18 wide), unless the swing's reach stops short of that edge.
	var edge := maxf(dummy.global_position.x - 9.0, swing.position.x + 1.0)
	check(absf(spark.global_position.x - edge) <= 1.5, "on the foe's near edge (%s, edge %s)" % [spark.global_position.x, edge])
	await frames(int(spark.life * 60.0) + 4)
	check(_find(room, HitSpark) == null, "and is gone in a blink")
	# The third hit of the combo is the heavy one: a bigger spark.
	await frames(30)
	for i in 3:
		p.input.attack_pressed = true
		await frames(1)
		if i < 2:
			await frames(int(p.combat.combo_cooldowns[i] * 60.0) + 1)
	var big: HitSpark = null
	for c in room.get_children():
		if c is HitSpark:
			big = c
	check(p.is_heavy_swing and big != null and big.size == Player.HEAVY_SPARK, "the heavy finisher sparks bigger")
	await frames(3)
	# The second cut's spark may still be falling; the heavy swing throws one of its own.
	var count := room.get_children().filter(func(c: Node) -> bool:
		return c is HitSpark and c.size == Player.HEAVY_SPARK).size()
	check(count == 1, "one spark per foe per swing (%d)" % count)


func test_the_hit_spark_plays_the_vfx_sheet() -> void:
	# Pass 529: the kept look is the PixelLab VFX-tool sheet, light and heavy, drawn at
	# the game's detail and turned with the swing without breaking a pixel.
	check(HitSpark.SHEET_SHIPPED and HitSpark.uses_sheet(), "the sheet is the shipped look")
	var room := make_room(ARENA)
	await frames(2)
	var light := HitSpark.spawn(room, Vector2(80, 80), Vector2.RIGHT)
	var heavy := HitSpark.spawn(room, Vector2(80, 80), Vector2.LEFT, Player.HEAVY_SPARK)
	var sheet := HitSpark.load_sheet(HitSpark.SHEET)
	var big := HitSpark.load_sheet(HitSpark.HEAVY_SHEET)
	check(sheet.frames.size() == 7 and big.frames.size() == 7, "seven frames each")
	check(is_equal_approx(float(sheet.fps), 24.0), "at 24 fps (%s)" % sheet.fps)
	check(light._sheet.frames == sheet.frames and heavy._sheet.frames == big.frames,
			"a light hit plays the light sheet, the heavy finisher the heavy one")
	var span: Vector2 = (sheet.frames[0] as Texture2D).get_size() / HitSpark.DENSITY
	check(span.x >= 40.0 and span.x <= 64.0, "the light sheet spans a hit's width in world pixels (%s)" % span)
	check(HitSpark.DENSITY == float(GameCamera.DETAIL), "drawn at the game's detail")
	check(is_equal_approx(light.life, 7.0 / 24.0), "it lives one run of the sheet (%s)" % light.life)
	check(light.frame() == 0, "it opens on the flash")
	# Pass 530: the flash is a small hot star at the blade tip, not a disc over the foe.
	for pair: Array in [[sheet, 16.0, 120], [big, 24.0, 220]]:
		var img := (pair[0].frames[0] as Texture2D).get_image()
		var used := img.get_used_rect().size / HitSpark.DENSITY
		var solid := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.8:
					solid += 1
		check(maxf(used.x, used.y) <= pair[1] and solid / (HitSpark.DENSITY * HitSpark.DENSITY) <= pair[2],
				"the opening flash stays small (%s across, %d solid world pixels)" % [used, solid / 4])
	await frames(9)
	check(light.frame() >= 3 and light.frame() <= 4, "and opens into the ring and the spray (%d)" % light.frame())
	await frames(int(light.life * 60.0))
	check(not is_instance_valid(light) and not is_instance_valid(heavy), "then both are gone")
	# The code look stays as the fallback.
	HitSpark.trial = "code"
	var code := HitSpark.spawn(room, Vector2(80, 80), Vector2.RIGHT)
	check(code._sheet.is_empty() and code.life == HitSpark.LIFE and code.frame() == -1, "the code look is the fallback")
	HitSpark.trial = ""
	code.queue_free()


func test_a_miss_throws_no_spark() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.input.attack_pressed = true
	await frames(3)
	check(_find(room, HitSpark) == null, "a swing at the air sparks nothing")


func test_being_hurt_flashes_the_screen_edge_red() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	var hud := GameHud.new()
	hud.player = p
	arena.add_child(hud)
	await frames(2)
	check(hud.edge_strength() == 0.0, "no glow at full health")
	p.take_damage(30)
	await frames(2)
	check(hud.hurt > 0.8 and hud.edge_strength() > 0.4, "a hit flashes the edge (%.2f)" % hud.edge_strength())
	await frames(40)
	check(hud.edge_strength() < 0.05, "and it fades in well under a second (%.2f)" % hud.edge_strength())
	Feel.flash_scale = 0.0
	p._invuln_timer = 0.0
	p.take_damage(10)
	await frames(2)
	check(hud.edge_strength() == 0.0, "the Flashes option turns it off")
	Feel.flash_scale = 1.0
	p._invuln_timer = 0.0
	p.hp = 50
	await frames(2)
	p.take_damage(5)
	await frames(1)
	var healed := p.hp
	p.hp = healed + 20
	await frames(2)
	check(hud.hurt < 1.0, "healing doesn't flash")


func test_low_health_beats_and_pulses() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	var hud := GameHud.new()
	hud.player = p
	arena.add_child(hud)
	await frames(30)
	check(p.heartbeats == 0 and hud.edge_strength() == 0.0, "no heartbeat at full health")
	p.hp = p.combat.low_health
	await frames(2)
	check(p.is_low_health() and p.heartbeats == 1, "down to one mask, the heart beats at once")
	var lo := 1.0
	var hi := 0.0
	for i in int(p.combat.heartbeat_interval * 60.0) + 2:
		await frames(1)
		lo = minf(lo, hud.edge_strength())
		hi = maxf(hi, hud.edge_strength())
	check(p.heartbeats == 2, "and again each %.2f s (%d)" % [p.combat.heartbeat_interval, p.heartbeats])
	check(lo > 0.0 and hi - lo > 0.08, "the edge pulses with it (%.2f to %.2f)" % [lo, hi])
	p.hp = p.combat.low_health + 1
	await frames(60)
	check(p.heartbeats == 2 and hud.edge_strength() == 0.0, "healed above a mask, it stops")


# --- Combat audit (pass 105, design bible 5.3) -----------------------------------

func test_a_slash_that_lands_pushes_you_back_a_few_pixels() -> void:
	var room := _arena_with("E", Vector2i(5, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	var x0 := p.global_position.x
	p.input.attack_pressed = true
	await frames(1)
	var least := x0
	for i in 20:
		await frames(1)
		least = minf(least, p.global_position.x)
	check(x0 - least >= 3.0 and x0 - least <= 6.0, "a landed slash pushes you back about 4 px (%.1f)" % (x0 - least))


func test_the_parry_window_is_0_12_s_and_pays_6_mp() -> void:
	var a := _dwarf_arena()
	var p: Player = a[1]
	var dwarf: RotDwarf = a[2]
	p.mp = 20.0
	p.has_shield = true
	# Pressed 5 frames (0.083 s) before the blade lands: a parry.
	await _wait_for_swing(dwarf, 5)
	p.input.block_pressed = true
	await frames(1)
	p.input.block_pressed = false
	await frames(6)
	check(p.hp == p.max_hp and dwarf.is_staggered(), "inside the window it parries (hp %d)" % p.hp)
	check(p.mp >= 20.0 + p.combat.parry_mp_gain - 0.01, "a parry pays %d MP (%.1f)" % [p.combat.parry_mp_gain, p.mp])
	check(Feel.last_hitstop == p.combat.parry_hitstop, "with a 140 ms hit-stop")
	await frames(50)
	check(dwarf.is_staggered(), "the foe still reels after 0.9 s")
	await frames(10)
	check(not dwarf.is_staggered(), "and recovers by 1.1 s")
	# Pressed 10 frames (0.167 s) early: too soon, the blow lands.
	(a[0] as Node).queue_free()
	await frames(2)
	var b := _dwarf_arena()
	var p2: Player = b[1]
	var dwarf2: RotDwarf = b[2]
	p2.has_shield = true
	await _wait_for_swing(dwarf2, 10)
	p2.input.block_pressed = true
	await frames(1)
	p2.input.block_pressed = false
	await frames(12)
	check(p2.hp < p2.max_hp and not dwarf2.is_staggered(), "outside the window it doesn't (hp %d)" % p2.hp)


## Pass 210: a foe's fall and your own hold the world for the bible's times
## (6.7), read from CombatTuning; until then both were bare numbers in code.
func test_a_kill_and_a_fall_hold_their_hit_stops() -> void:
	var a := _dwarf_arena()
	var p: Player = a[1]
	var dwarf: RotDwarf = a[2]
	await frames(2)
	Feel.last_hitstop = 0.0
	dwarf.die()
	check_near(Feel.last_hitstop, p.combat.kill_hitstop, 0.0001, "a kill holds %d ms" % roundi(p.combat.kill_hitstop * 1000.0))
	await frames(2)
	Feel.last_hitstop = 0.0
	p.take_damage(p.hp + 50)
	check(p.dead, "a blow past your health fells you")
	check_near(Feel.last_hitstop, p.combat.death_hitstop, 0.0001, "and your fall holds %d ms" % roundi(p.combat.death_hitstop * 1000.0))


func test_being_hit_matches_the_bible() -> void:
	var a := _dwarf_arena()
	var p: Player = a[1]
	var dwarf: RotDwarf = a[2]
	await _wait_for_swing(dwarf, 1)
	var hit_at := -1
	for i in 6:
		await frames(1)
		if p.hp < p.max_hp:
			hit_at = i
			break
	check(hit_at >= 0, "the swing lands")
	check(Feel.last_hitstop == p.combat.hurt_hitstop, "being hit holds 150 ms (%.2f)" % Feel.last_hitstop)
	check(p.velocity.x < 0.0 and absf(p.velocity.x) <= p.combat.hurt_knockback.x + 0.1, "knocked back at up to 160 px/s (%.0f)" % p.velocity.x)
	check(p._control_lock_timer > 0.0 and p._control_lock_timer <= p.combat.hurt_control_lock, "control locked for 0.18 s")
	check(p.invulnerable, "and invulnerable")
	dwarf.set_physics_process(false)
	await frames(44)
	check(p._invuln_timer > 0.0, "still safe at 0.75 s")
	await frames(6)
	check(p._invuln_timer <= 0.0, "and open again by 0.85 s (0.8 s of i-frames)")


## Pass 426: being hit, through the real controller. The test above takes the
## blow standing still; a player is usually holding a direction and often
## mid-drink. Here Heal is pressed for real, Right is held toward the dwarf,
## and his swing lands: the drink is spoiled with its charge kept, the blow
## knocks you back against the held Right for the whole control lock, and the
## same held Right (never pressed again) steers you once the lock is over.
func test_being_hit_answers_the_real_controller() -> void:
	var a := _dwarf_arena()
	var room: Room = a[0]
	var p: Player = a[1]
	var dwarf: RotDwarf = a[2]
	p.input = PlayerInput.new()
	p.hp = 50
	var charges := p.flask_charges
	await _wait_for_swing(dwarf, 10)
	Input.action_press("heal")
	await frames(2)
	Input.action_release("heal")
	check(p.is_drinking, "Heal starts the drink")
	Input.action_press("move_right")
	var hit := false
	for i in 20:
		await frames(1)
		if p.hp < 50:
			hit = true
			break
	check(hit, "the swing lands while Right is held")
	check(not p.is_drinking and p.flask_charges == charges and p.hp < 50,
		"the blow spoils the drink and keeps its charge (%d of %d, hp %d)" % [p.flask_charges, charges, p.hp])
	check(p.velocity.x < 0.0, "and knocks you back against the held Right (%.0f)" % p.velocity.x)
	var held_back := true
	var steps := 0
	while p._control_lock_timer > 0.0 and steps < 60:
		if p.velocity.x >= 0.0:
			held_back = false
		await frames(1)
		steps += 1
	check(held_back and steps >= 8, "Right can't turn the knockback for the whole lock (%d steps)" % steps)
	var steered := false
	for i in 40:
		await frames(1)
		if p.velocity.x > 0.0:
			steered = true
			break
	check(steered, "and once the lock is over the same held Right steers you again, never pressed twice")
	check(p.invulnerable, "while the i-frames still run")
	release_for_real(["move_right"])
	room.free()


## Pass 433 (bible 5.2): the source game's Amber Draught, in a real fight. The Amber Draught
## test lands its fatal blow with `take_damage` on a hero standing still; here
## the hero walks into the Rot Dwarf with Right held on the real controller,
## near death, and his swing is the fatal blow. The Amber Draught is drunk by the hit
## itself: the hero rises at full health and magic with the burn's words, its
## doubled grace outlasts the dwarf's next swing, and with no Amber Draught left the
## same swing, met the same way, fells them.
func test_the_elixir_saves_a_real_fight() -> void:
	var a := _dwarf_arena()
	var room: Room = a[0]
	var p: Player = a[1]
	var dwarf: RotDwarf = a[2]
	p.input = PlayerInput.new()
	p.elixirs = 1
	p.mp = 0.0
	p.hp = 5
	var toasts: Array[String] = []
	var hear := func(text: String) -> void: toasts.append(text)
	GameState.toast.connect(hear)
	await _wait_for_swing(dwarf, 10)
	Input.action_press("move_right")
	var hit := false
	for i in 20:
		await frames(1)
		if p.hp != 5:
			hit = true
			break
	check(hit and not p.dead and p.hp == p.max_hp and p.elixirs == 0, "the fatal swing drinks the Amber Draught: up again at full health (%d of %d)" % [p.hp, p.max_hp])
	check(is_equal_approx(p.mp, p.max_mp) and p.velocity.y < 0.0, "full magic, and rising (%.0f mp, %.0f)" % [p.mp, p.velocity.y])
	check(toasts.has("The Amber Draught burns. You rise again."), "with the burn's words (%s)" % [toasts])
	var taken := false
	for i in 90:
		await frames(1)
		if p.hp < p.max_hp:
			taken = true
	check(not taken and p.global_position.x > dwarf.global_position.x,
		"its grace carries the hero, Right still held, past the dwarf untouched (%.0f, dwarf %.0f)" % [p.global_position.x, dwarf.global_position.x])
	Input.action_release("move_right")
	GameState.toast.disconnect(hear)
	room.free()
	Feel.reset()
	# No Amber Draught: the same swing, met the same way, fells the hero.
	a = _dwarf_arena()
	room = a[0]
	p = a[1]
	dwarf = a[2]
	p.input = PlayerInput.new()
	p.hp = 5
	await _wait_for_swing(dwarf, 10)
	Input.action_press("move_right")
	var fell := false
	for i in 20:
		await frames(1)
		if p.dead:
			fell = true
			break
	Input.action_release("move_right")
	check(fell and p.elixirs == 0, "with no Amber Draught, the same swing fells the hero")
	room.free()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("`test_the_elixir_saves_a_real_fight`"), "5.2 names the test")


## Pass 202: bible 5.3's "Starting combat values" table says tests assert it,
## but a third of its rows were only read back from the tuning by the play
## tests (or by none), so a changed number moved its test with it. This holds
## every row to the bible's text; the test after it plays the two rows no test did.
func test_the_starting_combat_values_match_bible_5_3() -> void:
	var c := CombatTuning.new()
	check(c.slash_damage == 8 and c.heavy_damage == 14, "light 8, heavy third hit 14")
	check_near(c.combo_window, 0.40, 0.0001, "0.40 s to chain")
	check(c.combo_cooldowns == [0.20, 0.20, 0.38], "cooldowns 0.20, 0.20, 0.38 after hits 1 to 3")
	check(c.ground_combo_length == 3 and c.air_combo_length == 2, "3-hit ground combo, 2-hit air combo")
	check_near(c.attack_buffer, 0.15, 0.0001, "attack buffer 0.15 s")
	check_near(c.throw_buffer, 0.15, 0.0001, "throw buffer 0.15 s")
	check_near(c.hit_hitstop, 0.05, 0.0001, "50 ms on a hit (6.7)")
	check_near(c.heavy_hitstop, 0.09, 0.0001, "90 ms on a heavy hit (6.7)")
	check_near(c.kill_hitstop, 0.08, 0.0001, "80 ms on a kill (6.7, pass 210)")
	check_near(c.hurt_hitstop, 0.15, 0.0001, "150 ms when you are hit (5.3)")
	check_near(c.death_hitstop, 0.35, 0.0001, "350 ms when you fall (6.7, pass 210)")
	check_near(c.parry_window, 0.12, 0.0001, "parry window 0.12 s")
	check_near(c.parry_hitstop, 0.14, 0.0001, "parry hit-stop 140 ms")
	check_near(c.parry_mp_gain, 6.0, 0.0001, "a parry gives 6 MP")
	check_near(c.guard_reduction, 0.5, 0.0001, "the Buckler's guard halves damage")
	check_near(c.guard_mp_cost, 8.0, 0.0001, "8 MP per blocked hit")
	check_near(c.guard_move_multiplier, 0.4, 0.0001, "40% walk speed on guard")
	check(c.hurt_knockback == Vector2(160, 220), "knocked 160 px/s back, 220 px/s up")
	check_near(c.hurt_control_lock, 0.18, 0.0001, "0.18 s control lock")
	check(c.low_health == 20 and c.low_health == GameHud.MASK_HP, "low health is one mask, 20 HP")
	check_near(c.heartbeat_interval, 0.85, 0.0001, "a heartbeat every 0.85 s")
	check_near(c.max_mp, 60.0, 0.0001, "60 MP")
	check_near(c.mp_regen_per_second, 2.0, 0.0001, "+2 MP a second")
	check_near(c.mp_per_melee_hit, 4.0, 0.0001, "+4 MP per melee hit")
	check(c.flask_charges == 2 and c.flask_heal == 40, "Sapflask: 2 charges of 40")
	check_near(c.drink_time, 0.7, 0.0001, "0.7 s to drink")
	var torrent: Dictionary = Spells.DATA.torrent
	check(torrent.cost == 15.0 and torrent.damage == 12 and torrent.speed == 300.0, "Deluge: 15 MP, 12 damage, 300 px/s")
	check(c.war_glove_mult == 1.5 and c.war_glove_time == 15.0, "War Glove: x1.5 for 15 s")
	check_near(c.thrust_charge, 0.4, 0.0001, "Thrust: hold 0.4 s")
	check_near(c.thrust_mult, 1.5, 0.0001, "Thrust: heavy hit x1.5")
	check(c.thrust_speed == 320.0 and c.thrust_time == 0.16 and c.thrust_cooldown == 0.35, "Thrust: 320 px/s for 0.16 s, 0.35 s cooldown")
	check(c.pendant_mult == 1.1 and c.rod_torrent_mult == 1.5, "relics: the Acorn Charm x1.1, the Briar Wand's Deluge x1.5")
	check(Coin.MAGNET_DELAY == 0.4 and Coin.MAGNET_RANGE == 100.0, "coins: magnet after 0.4 s within 100 px")
	check_near(c.death_gold_fraction, 0.6, 0.0001, "death drops 60% of the purse (5.4)")
	check(c.hazard_damage == 20 and c.hazard_damage == GameHud.MASK_HP, "spikes and thorns cost a mask, 20 (pass 282)")
	check_near(c.cast_cooldown, 0.35, 0.0001, "0.35 s between casts (pass 282)")
	check(Drop.BREAD_HEAL == 15 and Drop.LOAF_HEAL == 40, "bread +15, the Silt Adder's great loaf +40 (pass 282)")
	check(Drop.BREAD_CHANCE == 0.08 and Drop.MANA_CHANCE == 0.1 and Drop.POISON_CHANCE == 0.07 and Drop.RARE_CHANCE == 0.025, "drops: bread 8%, mana 10%, poison 7%, rare 2.5% (pass 290)")
	check(Drop.MANA_GAIN == 12.0 and Drop.GLOVE_SHARE == 0.6, "a mana orb gives 12 MP; a rare drop is the War Glove 60% of the time (pass 290)")


## Pass 330: the test above copies each number, so a tuning change made in
## both the tuning and that test passed with the bible left behind, and four of
## the five spells (Tempest Lance, Emberfall, Wisplight, Witherbloom) were only read back from
## `Spells.DATA`. These read the bible: every combat number is written in 5.3,
## and each spell's row names its own cost, damage and speed.
## Pass 370 (bible 5.3): every spell's row gave its cost, damage and speed,
## but not how far it carries: a bolt's life was a constant in its own class,
## and Tempest Lance (0.7 s) reaches only about two thirds as far as Deluge (1.2 s).
## Each is cast by the real player across an empty hall and measured.
func test_every_spell_carries_as_far_as_5_3_says() -> void:
	var rows := ["#".repeat(60)]
	for y in 10:
		rows.append("#" + ".".repeat(58) + "#")
	rows.append("#".repeat(60))
	var room := make_room(rows)
	var p := make_player(room, Vector2i(3, 9))
	await frames(6)
	var flown := {}
	for id: String in ["torrent", "thunder", "fire", "wisplight"]:
		p.abilities[id] = true
		p.equipped_spell = id
		p.mp = p.combat.max_mp
		p.input.spell_pressed = true
		await frames(1)
		var shots := runner.get_tree().get_nodes_in_group("projectile")
		if not check(shots.size() == 1, "%s leaves the hand" % id):
			continue
		var shot: Node2D = shots[0]
		var start := shot.global_position
		var far := 0.0
		var t := 0
		while is_instance_valid(shot) and t < 400:
			far = maxf(far, absf(shot.global_position.x - start.x))
			await frames(1)
			t += 1
		flown[id] = [far, t / 60.0]
		await frames(20)
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var sec := bible.get_slice("### 5.3 Combat moves", 1).get_slice("\n### 5.4 ", 0)
	var row := sec.get_slice("| Spell reach (pass 370) |", 1).get_slice("\n", 0)
	if not check(row != "", "5.3 has the row"):
		return
	# What the row says each one does, measured.
	for said: Array in [["torrent", 355.0, TorrentBolt.LIFE], ["thunder", 260.0, ThunderBolt.LIFE], ["fire", 113.0, -1.0]]:
		var got: Array = flown.get(said[0], [0.0, 0.0])
		check(absf(float(got[0]) - float(said[1])) <= 8.0, "%s carries about %d px (%.0f)" % [said[0], said[1], got[0]])
		if float(said[2]) > 0.0:
			check(absf(float(got[1]) - float(said[2])) <= 0.05, "for its %.1f s (%.2f)" % [said[2], got[1]])
		check(written_exactly_in(row, float(said[1])), "the row writes %s's %d px" % [said[0], said[1]])
	check(float(flown.thunder[0]) < float(flown.torrent[0]) * 0.8, "Tempest Lance pays for its speed in reach")
	# The numbers the classes keep.
	var kept := {"Deluge's life": TorrentBolt.LIFE, "Tempest Lance's life": ThunderBolt.LIFE, "a conduit's leap": ThunderBolt.ARC,
		"Emberfall's burst": Fireball.BURST, "Emberfall's life": Fireball.LIFE, "Wisplight's life": WispOrb.LIFE, "Wisplight's speed": WispOrb.SPEED,
		"Wisplight's seek": WispOrb.SEEK, "Witherbloom's ring": DeathWave.RADIUS, "Witherbloom's roll": DeathWave.DURATION,
		"the dagger's range": RuneDagger.RANGE, "the dagger's speed": RuneDagger.SPEED}
	for what: String in kept:
		check(written_exactly_in(row, float(kept[what])), "the row writes %s, %s" % [what, String.num(float(kept[what]))])


func test_every_combat_number_is_written_in_bible_5_3() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var sec := bible.get_slice("### 5.3 Combat moves", 1).get_slice("\n### 5.4 ", 0)
	var c := CombatTuning.new()
	var unwritten := []
	var count := 0
	for prop: Dictionary in c.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v: Variant = c.get(prop.name)
		var nums: Array = []
		match typeof(v):
			TYPE_INT, TYPE_FLOAT:
				nums = [v]
			TYPE_ARRAY:
				nums = v
			TYPE_VECTOR2:
				nums = [v.x, v.y]
			_:
				continue
		for n: Variant in nums:
			count += 1
			if not written_exactly_in(sec, float(n)):
				unwritten.append("%s %s" % [prop.name, String.num(float(n))])
	check(count >= 45, "every exported combat number is read (%d)" % count)
	check(unwritten.is_empty(), "every combat number is written in bible 5.3 (not: %s)" % [unwritten])
	var rows := 0
	for id: String in Spells.ORDER:
		var spell: Dictionary = Spells.DATA[id]
		var at := sec.find("\n| %s |" % spell.name)
		if not check(at >= 0, "5.3 has a row for %s" % spell.name):
			continue
		rows += 1
		var row := sec.substr(at + 1).get_slice("\n", 0)
		for key: String in ["cost", "damage", "speed", "lift", "swarm_damage", "boss_damage"]:
			if spell.has(key):
				check(written_exactly_in(row, float(spell[key])), "%s's row writes its %s, %s (%s)" % [spell.name, key, String.num(float(spell[key])), row])
	check(rows == Spells.ORDER.size() and rows == Spells.DATA.size(), "a row for every spell (%d)" % rows)



## Pass 346: the test above finds a number anywhere in 5.3, and rounds any
## number under 100 to a whole one, so 1.35 passed on any "1" and the five
## hit-stops on any "0": six numbers (the hit-stops, Executioner's 1.35, the
## 1.2 s before you rise) were written nowhere in 5.3 and passed anyway. This
## holds each number to its own row (or move) and to its exact form.
func test_every_combat_number_is_written_in_its_own_row() -> void:
	const HOME := {
		"- **Slash:**": ["ground_combo_length", "air_combo_length", "turned_blade_push"],
		"- **Up-slash:**": ["up_slash_pop"],
		"| Light hit / heavy third hit |": ["slash_damage", "heavy_damage"],
		"| Combo window, cooldowns |": ["combo_window", "combo_cooldowns"],
		"| Attack buffer |": ["attack_buffer"],
		"| Throw buffer": ["throw_buffer"],
		"| Hit-stop (6.7) |": ["hit_hitstop", "heavy_hitstop", "kill_hitstop", "hurt_hitstop", "death_hitstop"],
		"| Parry window |": ["parry_window", "parry_hitstop", "parry_mp_gain"],
		"| Guard (Buckler) |": ["guard_reduction", "guard_mp_cost", "guard_move_multiplier"],
		"| Knockback when hit |": ["hurt_knockback", "hurt_control_lock"],
		"| Low health |": ["low_health", "heartbeat_interval"],
		"| MP |": ["max_mp", "mp_regen_per_second", "mp_per_melee_hit"],
		"| Sapflask |": ["flask_charges", "flask_heal", "drink_time"],
		"| War Glove": ["war_glove_mult", "war_glove_time"],
		"| Thrust (skill, 9) |": ["thrust_charge", "thrust_mult", "thrust_speed", "thrust_time", "thrust_cooldown"],
		"| Executioner (skill, 9) |": ["executioner_mult"],
		"| Relics": ["pendant_mult", "rod_torrent_mult"],
		"| Death (5.4) |": ["death_gold_fraction", "respawn_delay"],
		"| Spikes and thorns": ["hazard_damage"],
		"| Casting": ["cast_cooldown"],
	}
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var sec := bible.get_slice("### 5.3 Combat moves", 1).get_slice("\n### 5.4 ", 0)
	var c := CombatTuning.new()
	var homed := {}
	var astray := []
	for label: String in HOME:
		var at := sec.find("\n" + label)
		if not check(at >= 0, "5.3 has its line %s" % label):
			continue
		var line := sec.substr(at + 1).get_slice("\n", 0)
		for prop: String in HOME[label]:
			homed[prop] = true
			var v: Variant = c.get(prop)
			var nums: Array = v if typeof(v) == TYPE_ARRAY else ([v.x, v.y] if typeof(v) == TYPE_VECTOR2 else [v])
			for n: Variant in nums:
				if not written_exactly_in(line, float(n)):
					astray.append("%s %s not in %s" % [prop, String.num(float(n)), label])
	check(astray.is_empty(), "every combat number is written in its own row of 5.3 (%s)" % [astray])
	var unhomed := []
	for prop: Dictionary in c.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.type in [TYPE_FLOAT, TYPE_INT, TYPE_ARRAY, TYPE_VECTOR2] and not homed.has(prop.name):
			unhomed.append(prop.name)
	check(unhomed.is_empty(), "every combat number has a home row (%s)" % [unhomed])
	check(not written_exactly_in("x1 and 0 s", 1.35) and written_exactly_in("x1.35", 1.35) and written_exactly_in("90 ms", 0.09), "and the strict reading takes no rounded form")

## Bible 5.3 (pass 282): spikes cost a mask (20) through no armor and set
## you back on safe ground; a spell can't be cast again within 0.35 s, and the
## press made too soon is spent, not saved.
func test_spikes_cost_a_mask_and_casts_wait_their_cooldown() -> void:
	var rows: Array = ARENA.duplicate()
	rows[6] = "#.........^^^......#"
	var room := make_room(rows)
	var p := make_player(room, Vector2i(3, 6))
	p.max_hp = 100
	p.hp = 100
	await frames(4)
	var safe := p.global_position
	p.teleport(cell_feet(11, 6))
	await frames(2)
	check(p.hp == 100 - CombatTuning.new().hazard_damage, "a spike costs a whole mask (%d)" % (100 - p.hp))
	await frames(2)
	check(p.global_position.distance_to(safe) < 2.0, "and sets you back where you last stood safe (%s)" % p.global_position)
	await frames(60)
	# Casting: a second press inside 0.35 s casts nothing; after it, it casts.
	p.mp = 60.0
	var cost := p.spell_cost(p.equipped_spell)
	p.input.spell_pressed = true
	await frames(1)
	check_near(p.mp, 60.0 - cost, 0.2, "a cast spends its MP (%.1f)" % p.mp)
	var after_one := p.mp
	await frames(int(CombatTuning.new().cast_cooldown * 60.0) - 6)
	p.input.spell_pressed = true
	await frames(1)
	check(p.mp > after_one - cost * 0.5, "pressed again inside the cooldown, nothing is cast (%.1f)" % p.mp)
	await frames(10)
	check(p.mp > after_one - cost * 0.5, "and the early press is not saved for later (%.1f)" % p.mp)
	p.input.spell_pressed = true
	await frames(1)
	check(p.mp < after_one - cost * 0.5, "once the cooldown is over, it casts again (%.1f)" % p.mp)
	room.free()


## Pass 288 (bible 6): a spike sets you back on ground that lasts. Footing that
## can go (a cracked block you broke, a Bark Knight's rooted lance, a held
## crystal) is never kept as the safe spot, or a fall onto the spikes it hid
## would set you back into the air above them, again and again.
func test_a_spike_never_sets_you_back_onto_footing_that_is_gone() -> void:
	var rows: Array = ARENA.duplicate()
	rows[5] = "#..........C.......#"
	rows[6] = "#.........^^^......#"
	var room := make_room(rows)
	var p := make_player(room, Vector2i(3, 6))
	p.max_hp = 100
	p.hp = 100
	await frames(4)
	var block: CrackedBlock = null
	for c in room.get_children():
		if c is CrackedBlock:
			block = c
	check(block != null, "the arena has its cracked block")
	if block == null:
		room.free()
		return
	block.respawns = false
	var ground := p.global_position
	# Stand on the block a while, then it breaks under you.
	p.teleport(block.global_position + Vector2(0, -8))
	await frames(20)
	check(p.is_on_floor(), "standing on the cracked block")
	block.break_block(true)
	await frames(180)
	check(p.hp == 100 - CombatTuning.new().hazard_damage, "the spikes cost one mask, not a run of them (%d)" % (100 - p.hp))
	check(p.is_on_floor() and p.global_position.distance_to(ground) < 2.0, "and set you back on the floor you stood on before the block (%s, floor %s)" % [p.global_position, ground])
	room.free()


## Pass 296 (bible 6.13): a set-back is a fresh start. A jump or dash pressed
## as you fell onto the spikes was still buffered when the spikes set you
## back, so it fired on arrival: you hopped (or dashed) off the safe spot with
## no press of your own, often straight back toward the spikes.
func test_a_set_back_drops_the_presses_buffered_on_the_way_down() -> void:
	var rows: Array = ARENA.duplicate()
	rows[6] = "#.........^^^......#"
	var room := make_room(rows)
	var p := make_player(room, Vector2i(3, 6), {"stride": true})
	p.max_hp = 100
	p.hp = 100
	await frames(4)
	var ground := p.global_position
	for press: String in ["jump", "dash"]:
		p.facing = 1
		# Dropped from high over the spikes; the press comes just before they bite.
		p.teleport(Vector2(11.5 * Room.TILE, 2 * Room.TILE))
		await _until(func() -> bool: return p.global_position.y > 6 * Room.TILE + 2.0, 60)
		p.air_dash_charges = 0
		if press == "jump":
			p.input.jump_pressed = true
			p.input.jump_held = true
		else:
			p.input.dash_pressed = true
		await frames(1)
		p.input.jump_pressed = false
		p.input.dash_pressed = false
		await _until(func() -> bool: return p.hp < 100, 30)
		check(p.hp < 100 and p.global_position.distance_to(ground) < 2.0, "the spikes set you back (%s, %s)" % [press, p.global_position])
		var moved := 0.0
		var rose := 0.0
		for i in 30:
			await frames(1)
			moved = maxf(moved, absf(p.global_position.x - ground.x))
			rose = maxf(rose, ground.y - p.global_position.y)
		p.input.jump_held = false
		check(rose < 1.0 and moved < 1.0, "and the %s pressed on the way down does not fire there (rose %.1f, moved %.1f)" % [press, rose, moved])
		check(p.facing == 1, "you still face the way you were")
		p.hp = 100
		await frames(70)
	room.free()


## Pass 298 (bible 7, 5.3): a foe that falls out of its room is a kill, and
## pays like one, but no blow lands as it dies below the screen, a moment after
## the blow that sent it. A kill's freeze and shake there only hitched the game.
func test_a_foe_that_falls_out_pays_without_a_kills_freeze() -> void:
	var rows: Array = ARENA.duplicate()
	rows[2] = "#.........M........#"
	rows[7] = "#########....#######"
	var room := make_room(rows)
	var p := make_player(room, Vector2i(3, 6))
	await frames(4)
	var foe: Enemy = null
	for c in room.get_children():
		if c is Blinkhop:
			foe = c
	check(foe != null, "a Blinkhop hangs over the gap")
	if foe == null:
		room.free()
		return
	foe.gold_min = 5
	foe.gold_max = 5
	var gone: Array = []
	foe.died.connect(func(e: Enemy) -> void: gone.append(e))
	Feel.last_hitstop = 0.0
	Feel.trauma = 0.0
	await _until(func() -> bool: return not gone.is_empty(), 120)
	check(not gone.is_empty() and foe.fell, "it falls out of the room and dies")
	check(Feel.last_hitstop == 0.0 and Feel.trauma < 0.01, "with no kill's freeze or shake (hitstop %.2f, trauma %.2f)" % [Feel.last_hitstop, Feel.trauma])
	var coins := 0
	for c in room.get_children():
		if c is Coin:
			coins += 1
	check(coins > 0, "but it still pays its gold (%d coins)" % coins)
	room.free()


## Pass 286 (bible 13.3): a press that does nothing is heard when there is a
## reason to tell you. An empty flask clinks; a spell short of MP and a glass
## still running back fizzle; each once per press, spending nothing. A cast
## pressed inside its cooldown stays silent: the cast just sounded.
func test_a_refused_drink_cast_or_glass_is_heard_once() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6), {"stillstone": true})
	p.max_hp = 100
	p.hp = 50
	await frames(4)
	# The empty flask.
	p.flask_charges = 0
	Sfx.recent.clear()
	p.input.heal_pressed = true
	await frames(1)
	p.input.heal_pressed = false
	await frames(30)
	check(Sfx.recent == ["flask_empty"], "an empty flask clinks, once (%s)" % [Sfx.recent])
	check(p.hp == 50 and not p.is_drinking, "and nothing is drunk (%d)" % p.hp)
	check(ResourceLoader.exists("res://assets/sfx/flask_empty.wav"), "flask_empty is rendered")
	# A full flask at full health: nothing to drink for, nothing heard.
	p.flask_charges = 2
	p.hp = 100
	Sfx.recent.clear()
	p.input.heal_pressed = true
	await frames(1)
	await frames(30)
	check(Sfx.recent.is_empty() and p.flask_charges == 2, "at full health a press is quiet and spends nothing (%s)" % [Sfx.recent])
	# A spell short of MP.
	p.mp = p.spell_cost(p.equipped_spell) - 1.0
	var mp := p.mp
	Sfx.recent.clear()
	p.input.spell_pressed = true
	await frames(1)
	check(Sfx.recent.count("fizzle") == 1 and not Sfx.recent.has("cast"), "a spell short of MP fizzles, once (%s)" % [Sfx.recent])
	check(p.mp <= mp + 0.1, "and spends nothing (%.1f)" % p.mp)
	# A cast, then a press inside the cooldown: silent.
	p.mp = 60.0
	p.input.spell_pressed = true
	await frames(1)
	Sfx.recent.clear()
	await frames(6)
	p.input.spell_pressed = true
	await frames(1)
	check(not Sfx.recent.has("fizzle") and not Sfx.recent.has("cast"), "a press inside the cooldown is silent (%s)" % [Sfx.recent])
	# The glass, turned while it runs back.
	p.input.stillstone_pressed = true
	await frames(2)
	check(TimeStop.active(), "the glass turns")
	Sfx.recent.clear()
	p.input.stillstone_pressed = true
	await frames(1)
	check(Sfx.recent.count("fizzle") == 1 and not Sfx.recent.has("stillstone"), "turned again while it runs back, it fizzles, once (%s)" % [Sfx.recent])
	TimeStop.reset()
	room.free()


## Pass 290 (bible 5.3, Drops): a kill's roll gives each drop at its share.
## 40,000 seeded rolls, with and without poison, each within a point of the
## table; a foe without `poison_drops` never leaves poison.
func test_a_kills_drop_comes_at_the_tables_odds() -> void:
	var parent := Node2D.new()
	arena.add_child(parent)
	# The runner turns drops off for every test; turn on the game's own odds.
	Drop.bread_chance = Drop.BREAD_CHANCE
	Drop.mana_chance = Drop.MANA_CHANCE
	Drop.poison_chance = Drop.POISON_CHANCE
	Drop.rare_chance = Drop.RARE_CHANCE
	seed(290)
	for can_poison: bool in [false, true]:
		var counts := {"": 0, "bread": 0, "mana": 0, "poison": 0, "glove": 0, "ointment": 0}
		var n := 20000
		for i in n:
			var d := Drop.roll(parent, Vector2.ZERO, can_poison)
			counts[d.kind if d != null else ""] += 1
			if d != null:
				d.free()
		var share := func(k: String) -> float: return float(counts[k]) / n
		var rare: float = share.call("glove") + share.call("ointment")
		check(absf(share.call("bread") - Drop.BREAD_CHANCE) < 0.01, "bread at %.1f%% (%.1f%%)" % [Drop.BREAD_CHANCE * 100, share.call("bread") * 100])
		check(absf(share.call("mana") - Drop.MANA_CHANCE) < 0.01, "a mana orb at %.1f%% (%.1f%%)" % [Drop.MANA_CHANCE * 100, share.call("mana") * 100])
		check(absf(share.call("poison") - (Drop.POISON_CHANCE if can_poison else 0.0)) < 0.01, "poison at %.1f%% %s (%.1f%%)" % [Drop.POISON_CHANCE * 100 if can_poison else 0.0, "from a Tower foe" if can_poison else "from any other", share.call("poison") * 100])
		check(absf(rare - Drop.RARE_CHANCE) < 0.01, "a rare item at %.1f%% (%.1f%%)" % [Drop.RARE_CHANCE * 100, rare * 100])
		check(absf(float(counts["glove"]) / maxf(1.0, counts["glove"] + counts["ointment"]) - Drop.GLOVE_SHARE) < 0.08, "of them the War Glove %.0f%% (%d of %d)" % [Drop.GLOVE_SHARE * 100, counts["glove"], counts["glove"] + counts["ointment"]])
	randomize()
	Drop.bread_chance = 0.0
	Drop.mana_chance = 0.0
	Drop.poison_chance = 0.0
	Drop.rare_chance = 0.0
	parent.free()


## Bible 5.3: guarding you walk at 40% of a run; MP comes back at 2 a second.
func test_a_guard_walks_slow_and_mp_comes_back_slowly() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(4)
	p.input.block_held = true
	p.input.move_x = 1
	await frames(20)
	check(p.is_blocking, "holding Block guards")
	check_near(p.velocity.x, p.tuning.run_speed * 0.4, 0.5, "guarding, you walk at 40%% of a run (%.1f)" % p.velocity.x)
	p.input.block_held = false
	p.input.move_x = 0
	p.mp = 0.0
	await frames(60)
	check_near(p.mp, 2.0, 0.1, "a second later 2 MP has come back (%.2f)" % p.mp)
	room.free()


func test_the_heavy_finisher_drives_a_foe_back_and_holds_it_longer() -> void:
	var room := _arena_with("D", Vector2i(10, 6))
	var dwarf: RotDwarf = _find(room, RotDwarf)
	await frames(4)
	# From behind (it faces left; its shield guards the front).
	dwarf.take_hit(1, Vector2(-1, 0))
	check_near(dwarf._hitstun, Enemy.HITSTUN, 0.001, "a light hit stops it 0.18 s")
	var light := dwarf.velocity.x
	await frames(30)
	dwarf.take_hit(1, Vector2(-1.8, 0))
	check_near(dwarf._hitstun, Enemy.HITSTUN * 1.8, 0.001, "the heavy finisher holds it 0.32 s")
	check_near(dwarf.velocity.x, light * 1.8, 0.5, "and drives it back 1.8x as hard")


func test_a_midair_up_slash_that_lands_holds_you_up() -> void:
	var rows := ARENA.duplicate()
	for i in 8:
		rows.insert(1, "#..................#")
	var room := make_room(rows)
	var p := make_player(room, Vector2i(9, 8))
	var foe := Hornet.new()
	room.add_child(foe)
	foe.set_physics_process(false)
	for i in 3:
		foe.global_position = p.global_position + Vector2(0, -p.BODY_SIZE.y - 10)
		await frames(1)
	check(not p.is_on_floor(), "falling past a hornet")
	p.velocity.y = 120.0
	p.input.up = true
	p.input.attack_pressed = true
	await frames(1)
	p.input.attack_pressed = false
	check(foe.hits_taken == 1, "the up-slash hits the hornet above")
	check(p.velocity.y < -p.combat.up_slash_pop + 40.0, "and turns the fall into a little rise (%.0f)" % p.velocity.y)
	p.velocity.y = 120.0
	await frames(2)
	check(p.velocity.y > 0.0, "once per swing (%.0f)" % p.velocity.y)
	p.input.up = false


## The Rune Dagger (pass 184, bible 5.2): thrown, it strikes the first foe in
## its path, breaks into rune light, and reforms at your hip RETURN later; only
## one flies at a time, it costs no magic, and Up throws it straight up.
func test_the_off_hand_holds_a_shield_or_the_rune_dagger() -> void:
	# Sean (2026-10-31): the dagger is thrown from the left hand, the shield's arm,
	# so the off hand holds one or the other: a shield guards, the dagger flies.
	var room := _arena_with("E", Vector2i(10, 6))
	var p := make_player(room, Vector2i(3, 6))
	p.abilities["rune_dagger"] = true
	GameState.data.gear.append("small_shield")
	GameState.wear("small_shield", p)
	await frames(6)
	check(p.has_shield, "the Buckler is on the off hand")
	p.input.throw_pressed = true
	await frames(2)
	p.input.throw_pressed = false
	check(p.rune_dagger == null, "so the Rune Dagger stays put")
	GameState.capture(p)
	var rows := Menus.equipment_rows()
	var labels: Array = rows.map(func(r: Dictionary) -> String: return String(r.label))
	var at := labels.find("Off Hand")
	check(at >= 0 and labels.find("Rune Dagger") == at + 1, "the Equipment page offers the dagger first under the Off Hand (%s)" % [labels])
	Menus.choose_equipment(Menus.OFFHAND_DAGGER, p)
	check(GameState.offhand_free() and not p.has_shield, "choosing it takes the shield off")
	var dagger_row: Dictionary = Menus.equipment_rows().filter(func(r: Dictionary) -> bool: return String(r.label) == "Rune Dagger")[0]
	check(dagger_row.right == "Worn", "and the dagger reads as worn")
	await frames(1)
	p.input.throw_pressed = true
	await frames(2)
	p.input.throw_pressed = false
	check(p.rune_dagger != null, "now Throw flicks it")
	p.input.block_held = true
	await frames(2)
	p.input.block_held = false
	check(not p.is_blocking, "and there is no guard")
	for d in runner.get_tree().get_nodes_in_group("projectile"):
		d.free()
	GameState.data.gear.erase("small_shield")
	GameState.data.abilities.rune_dagger = false


func test_the_rune_dagger_flies_strikes_and_reforms_at_your_hip() -> void:
	var room := _arena_with("E", Vector2i(10, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	var dummy: TrainingDummy = _find(room, TrainingDummy)
	p.input.throw_pressed = true
	await frames(1)
	check(p.rune_dagger == null, "no throw without the Rune Dagger")
	p.rune_dagger = null
	for d in runner.get_tree().get_nodes_in_group("projectile"):
		d.free()
	p.abilities["rune_dagger"] = true
	await frames(1)
	var mp0 := p.mp
	p.input.throw_pressed = true
	await frames(1)
	var dagger := p.rune_dagger
	check(dagger != null and dagger.dir == Vector2.RIGHT, "the Throw button hurls it the way you face")
	check(not p.dagger_ready(), "one dagger at a time")
	p.input.throw_pressed = true
	await frames(1)
	check(runner.get_tree().get_nodes_in_group("projectile").size() == 1, "a second press while it flies does nothing")
	await frames(20)
	check(dummy.hits_taken == 1, "it strikes the dummy (%d hits)" % dummy.hits_taken)
	check(dummy.hp == TrainingDummy.HP - RuneDagger.DAMAGE, "for %d damage (dummy hp %d)" % [RuneDagger.DAMAGE, dummy.hp])
	check(not is_instance_valid(dagger), "it breaks on the blow")
	check(is_equal_approx(p.mp, mp0), "it costs no magic")
	check(not p.dagger_ready(), "it is not back at once")
	await frames(int(RuneDagger.RETURN * 60.0) + 2)
	check(p.dagger_ready(), "it reforms at your hip after %.1f s" % RuneDagger.RETURN)
	p.input.up = true
	p.input.throw_pressed = true
	await frames(1)
	check(p.rune_dagger != null and p.rune_dagger.dir == Vector2.UP, "Up throws it straight up")
	p.input.up = false


## Pass 326: a dagger that strikes a wall pings with its own voice. It
## borrowed the shield's `guard` clank, so a throw at stone sounded like a block.
func test_a_dagger_on_stone_pings_and_never_clanks_like_a_shield() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(14, 6))
	await frames(6)
	p.abilities["rune_dagger"] = true
	Sfx.recent.clear()
	p.input.throw_pressed = true
	await frames(30)
	check(Sfx.recent.has(RuneDagger.WALL_SOUND) and not Sfx.recent.has("guard"), "a dagger on stone pings, never the shield's clank (%s)" % [Sfx.recent])
	check(FileAccess.file_exists("res://assets/sfx/%s.wav" % RuneDagger.WALL_SOUND), "%s.wav exists" % RuneDagger.WALL_SOUND)


## Pass 190: gear is heard. A dagger that lands bites, the two-handed Broad
## Sword swings with a heavier voice, and the Equipment page sheathes a blade,
## buckles on gear and swishes a dye.
func test_the_dagger_the_broad_sword_and_the_equipment_page_have_voices() -> void:
	var room := _arena_with("E", Vector2i(10, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.abilities["rune_dagger"] = true
	Sfx.recent.clear()
	p.input.throw_pressed = true
	await frames(20)
	check(Sfx.recent.has("dagger_throw") and Sfx.recent.has("dagger_hit"), "a dagger that lands bites (%s)" % [Sfx.recent])
	await frames(int(RuneDagger.RETURN * 60.0) + 4)
	Sfx.recent.clear()
	p.input.attack_pressed = true
	await frames(2)
	check(Sfx.recent.has("slash") and not Sfx.recent.has("broad_slash"), "the Short Sword cuts with the plain slash (%s)" % [Sfx.recent])
	GameState.obtain_gear("dwarvish_broad_sword", p)
	await frames(40)
	Sfx.recent.clear()
	p.input.attack_pressed = true
	await frames(2)
	check(Sfx.recent.has("broad_slash") and not Sfx.recent.has("slash"), "the Broad Sword's cut is its own (%s)" % [Sfx.recent])
	# Its heavy cut, the combo's last on the ground, is heard for real (pass 390).
	await frames(40)
	Sfx.recent.clear()
	var heard := false
	for i in 120:
		p.input.attack_pressed = true
		await frames(1)
		heard = heard or Sfx.recent.has("broad_heavy")
	p.input.attack_pressed = false
	check(heard, "and so is its heavy cut, swung (%s)" % [Sfx.recent])
	for sound: String in ["dagger_hit", "broad_slash", "broad_heavy", "sheathe", "gear_on"]:
		check(FileAccess.file_exists("res://assets/sfx/%s.wav" % sound), "%s.wav exists" % sound)
	check(Menus.equipment_sound("long_sword") == "sheathe", "a blade taken in hand slides from its sheath")
	for id: String in ["leather_armor", "small_shield", "elven_helm"]:
		check(Menus.equipment_sound(id) == "gear_on", "%s buckles on" % id)
	check(Menus.equipment_sound("tide_dye") == "cloth", "and a dye is cloth")
	Sfx.recent.clear()
	Menus.choose_equipment("short_sword", p)
	check(Sfx.recent == ["sheathe"] and GameState.data.equipment.blade == "short_sword", "choosing a blade plays it (%s)" % [Sfx.recent])


## Pass 192: Throw is buffered like Attack. A press in the last moments of a
## swing, a dash or the dagger's return goes the first frame it can; one
## pressed long before is dropped.
func test_a_throw_pressed_a_moment_early_still_goes() -> void:
	var room := _arena_with("E", Vector2i(30, 6))
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.abilities["rune_dagger"] = true
	check(is_equal_approx(p.combat.throw_buffer, 0.15) and is_equal_approx(p.combat.throw_buffer, p.combat.attack_buffer), "Throw is buffered 0.15 s, as Attack is")
	p.input.attack_pressed = true
	await frames(1)
	check(p.is_attacking, "mid-swing")
	p.input.throw_pressed = true
	await frames(1)
	check(p.rune_dagger == null, "no throw while the swing is out")
	var waited := 0
	while p.is_attacking and waited < 30:
		await frames(1)
		waited += 1
	await frames(1)
	check(waited <= 9 and p.rune_dagger != null, "the press goes as the swing ends (%d frames later)" % waited)
	# Pressed while it reforms, a moment before it is whole.
	while is_instance_valid(p.rune_dagger):
		await frames(1)
	await frames(int((RuneDagger.RETURN - 0.1) * 60.0))
	p.input.throw_pressed = true
	await frames(1)
	check(not is_instance_valid(p.rune_dagger), "not while it reforms")
	await frames(8)
	check(is_instance_valid(p.rune_dagger), "but the press goes the frame it is whole")
	# Pressed too early, it is dropped.
	while is_instance_valid(p.rune_dagger):
		await frames(1)
	p.input.throw_pressed = true
	await frames(1)
	await frames(int(RuneDagger.RETURN * 60.0) + 4)
	check(not is_instance_valid(p.rune_dagger), "a press long before it is whole is dropped")


## Pass 410 (bible 5.3): the Rune Dagger by the buttons. Pass 386 found that
## Throw lets it fly on its frame, but its aim (Up held throws it straight up),
## its buffer (a press in the last moments of a swing goes as the swing ends)
## and Sean's off-hand rule (a shield on the arm leaves nothing to throw) were
## only ever scripted. Each is played here with the real controller.
func test_the_rune_dagger_answers_the_real_controller() -> void:
	var c := CombatTuning.new()
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6), {"rune_dagger": true})
	p.input = PlayerInput.new()
	var shield_was := String(GameState.data.equipment.get("shield", ""))
	GameState.data.equipment.shield = ""
	await frames(6)
	await press_for_real(p, ["throw"])
	check(is_instance_valid(p.rune_dagger) and p.rune_dagger.dir == Vector2.RIGHT, "Throw hurls it the way you face")
	release_for_real(["throw"])
	while not p.dagger_ready():
		await frames(1)
	# Up held: straight up.
	await press_for_real(p, ["move_up", "throw"])
	check(is_instance_valid(p.rune_dagger) and p.rune_dagger.dir == Vector2.UP, "with Up held it goes straight up")
	release_for_real(["move_up", "throw"])
	while not p.dagger_ready():
		await frames(1)
	# Pressed in the last moments of a swing, it goes as the swing ends.
	await press_for_real(p, ["attack"])
	release_for_real(["attack"])
	check(p.is_attacking and p._attack_timer < c.throw_buffer, "mid-swing, inside its last %.2f s" % c.throw_buffer)
	await press_for_real(p, ["throw"])
	release_for_real(["throw"])
	check(p.is_attacking and not is_instance_valid(p.rune_dagger), "no throw while the swing is still out")
	var waited := 0
	while not is_instance_valid(p.rune_dagger) and waited < 20:
		await frames(1)
		waited += 1
	check(is_instance_valid(p.rune_dagger), "the buffered press goes as the swing ends (%d frames later)" % waited)
	while not p.dagger_ready():
		await frames(1)
	# A shield on the arm: Throw does nothing (Sean's rule, pass 313).
	GameState.data.equipment.shield = "small_shield"
	await press_for_real(p, ["throw"])
	release_for_real(["throw"])
	await frames(4)
	check(not is_instance_valid(p.rune_dagger) and runner.get_tree().get_nodes_in_group("projectile").is_empty(), "with a shield on the arm, Throw does nothing")
	GameState.data.equipment.shield = shield_was
	room.free()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 5.3 ", 1).get_slice("\n### 5.4 ", 0)
	check(note.contains("`test_the_rune_dagger_answers_the_real_controller`"), "5.3 names the test")


## Pass 414 (bible 13.3): the two ready chimes, heard on time. The Thrust
## plays `thrust_ready` the moment Attack held fills its charge, and the Rune
## Dagger plays `dagger_return` as it reforms at your hip. Each tells a player
## a move is ready again without looking, and neither was ever listened for:
## a chime early, late, twice or not at all would have passed every test.
## Both are played here through the real controller.
func test_the_ready_chimes_ring_when_the_move_is_ready() -> void:
	var c := CombatTuning.new()
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(9, 6), {"rune_dagger": true})
	p.thrust = true
	p.input = PlayerInput.new()
	await frames(6)
	Sfx.recent.clear()
	await press_for_real(p, ["attack"])
	var rang_at := -1.0
	var rings := 0
	for i in int(c.thrust_charge * 60.0) + 30:
		await frames(1)
		if Sfx.recent.has("thrust_ready"):
			rings += Sfx.recent.count("thrust_ready")
			if rang_at < 0.0:
				rang_at = p._thrust_charge
			Sfx.recent.clear()
	check(rings == 1, "Attack held past the charge chimes once (%d)" % rings)
	check(rang_at >= c.thrust_charge and rang_at < c.thrust_charge + 0.02 and p.thrust_ready(), "on the frame the charge fills (%.3f s of %.2f)" % [rang_at, c.thrust_charge])
	release_for_real(["attack"])
	await frames(40)
	# The dagger: thrown at the wall, it chimes as it reforms, once.
	Sfx.recent.clear()
	await press_for_real(p, ["throw"])
	release_for_real(["throw"])
	var back_ready := false
	rings = 0
	for i in 120:
		await frames(1)
		if Sfx.recent.has("dagger_return"):
			rings += Sfx.recent.count("dagger_return")
			back_ready = back_ready or p.dagger_ready()
			Sfx.recent.clear()
	check(rings == 1 and back_ready, "the Rune Dagger chimes once, as it is back at your hip (%d)" % rings)
	check(FileAccess.file_exists("res://assets/sfx/thrust_ready.wav") and FileAccess.file_exists("res://assets/sfx/dagger_return.wav"), "both chimes have files")
	room.free()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 13.3 ", 1).get_slice("\n### 13.4 ", 0)
	check(note.contains("`test_the_ready_chimes_ring_when_the_move_is_ready`"), "13.3 names the test")


func test_the_rune_dagger_breaks_on_walls_and_at_the_end_of_its_reach() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6), {"rune_dagger": true})
	await frames(6)
	var x0 := p.global_position.x
	p.input.throw_pressed = true
	await frames(1)
	var dagger := p.rune_dagger
	var far := 0.0
	while is_instance_valid(dagger):
		far = dagger.global_position.x - x0
		await frames(1)
	check(far <= RuneDagger.RANGE + 20.0 and far >= RuneDagger.RANGE - 20.0, "it flies about %d px and no farther (%.0f)" % [RuneDagger.RANGE, far])
	await frames(int(RuneDagger.RETURN * 60.0) + 2)
	p.facing = -1
	p.input.throw_pressed = true
	await frames(1)
	dagger = p.rune_dagger
	await frames(12)
	check(not is_instance_valid(dagger), "it breaks on the wall behind you")
	check(not p.dagger_ready(), "and comes home from there too")
	await frames(int(RuneDagger.RETURN * 60.0) + 2)
	check(p.dagger_ready(), "ready again")


## The damage balance sheet (design bible 5.5, pass 194): the kit the critical
## path has put in your hands by each zone, as [blade, tempers, armor, shield].
## The shield joined in pass 226: since pass 225 it wards a foe's sorcery.
const PAR_KIT := {
	"heartwood": ["long_sword", 0, "leather_armor", "small_shield"],
	"tower": ["long_sword", 0, "leather_armor", "small_shield"],
	"haar": ["long_sword", 1, "riveted_coat", "large_shield"],
	"boughs": ["long_sword", 1, "riveted_coat", "large_shield"],
	"spires": ["long_sword", 2, "riveted_coat", "large_shield"],
	"vorrhallow": ["long_sword", 2, "full_plate", "magic_shield"],
	"sunken": ["severance", 0, "full_plate", "magic_shield"],
	"evercrown": ["severance", 0, "full_plate", "magic_shield"],
}
## Pass 218: Thane Vorrund gives up the Severance (pass 217), so everything
## past his throne is fought with it: the Glass Rise, the Crown Gate and its
## mirror, and the Sunken Spring below the Rise.
const PAST_VORRUND_KIT := ["severance", 0, "full_plate", "magic_shield"]
const PAST_VORRUND_ROOMS := ["vorrhallow/meteor_rise", "vorrhallow/evercrown_gate"]
const PAST_VORRUND_BOSSES := ["Likeness"]
## Each room legend's foe, and the shot it fires (null for none).
var sheet_foes := {
	"M": [Blinkhop, null], "H": [Hornet, null], "D": [RotDwarf, null],
	"T": [SapSpitter, SapGlob], "U": [GrubLump, null], "I": [IronDwarf, Shockwave],
	"B": [GearBat, GearBlade], "K": [MinecartRider, null], "A": [LanternGhost, null],
	"V": [BogPuffcap, SporeCloud], "p": [DrownedDwarf, null], "m": [LeafMantis, null],
	"!": [BarkKnight, null], ";": [SeedBomber, BomberSeed], "?": [MarshHag, MireGrasp],
	"t": [ThunderBeetle, null], "y": [StormHarpy, HarpyFeather], "]": [SpireSentinel, null],
	"q": [CrystalDwarf, CrystalSpike], "e": [ShadeKnight, null], "j": [ClockworkHound, null],
	"s": [GlassSlug, MeteorGlob], "l": [SpringEel, null], ")": [SiltAdder, null],
}


## A script's blows on the player: its *DAMAGE and *CONTACT constants, leaving
## out the damage a returned shot does to its thrower.
func _blows(script: Script) -> Array[int]:
	var out: Array[int] = []
	var consts := script.get_script_constant_map()
	for k: String in consts:
		if ("DAMAGE" in k or "CONTACT" in k) and not "REFLECT" in k and not "RETURN" in k and consts[k] is int:
			out.append(int(consts[k]))
	return out


## A blow of `b` as it lands through a zone's par kit, the way
## Player.receive_attack takes it: the zone's threat, the shield's ward if the
## blow is sorcery (pass 225), then the armor.
func _through_par(b: int, zone: String, script: Script) -> int:
	var kit: Array = PAR_KIT[zone]
	var d := roundi(b * float(CombatTuning.ZONE_THREAT[zone]))
	if _is_sorcery(script):
		d = maxi(roundi(d * (1.0 - float(GameData.item(kit[3]).get("ward", 0.0)))), 1)
	return maxi(1, roundi(d * (1.0 - float(GameData.item(kit[2]).defense))))


## A script whose nodes join Player.MAGIC: a hex, a bolt, a shard, a beam.
func _is_sorcery(script: Script) -> bool:
	return script != null and script.source_code.contains("add_to_group(Player.MAGIC)")


## Every foe placed in a zone, by legend character.
func _zone_foes(zone: String) -> Dictionary:
	var found := {}
	var dir := DirAccess.open("res://levels/" + zone)
	for f in dir.get_files():
		if not f.ends_with(".room"):
			continue
		var grid: Array = Room.parse(FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, f])).grid
		for row: String in grid:
			for ch in row:
				if sheet_foes.has(ch):
					found[ch] = true
	return found


func test_the_damage_balance_sheet_stays_within_its_targets() -> void:
	var order := ["heartwood", "tower", "haar", "boughs", "spires", "vorrhallow", "evercrown"]
	var last := 0.0
	for zone: String in order:
		var t := float(CombatTuning.ZONE_THREAT[zone])
		check(t >= last, "%s is no softer than the zone before it (%.1f)" % [zone, t])
		last = t
	check(CombatTuning.ZONE_THREAT.heartwood == 1.0 and CombatTuning.ZONE_THREAT.tower == 1.0, "the first two zones hit as written")
	var checked := 0
	for zone: String in PAR_KIT:
		var kit: Array = PAR_KIT[zone]
		var cut := roundi(int(GameData.item(kit[0]).slash) * (1.0 + GameState.TEMPER_BONUS * int(kit[1])))
		var armor := float(GameData.item(kit[2]).defense)
		var threat := float(CombatTuning.ZONE_THREAT[zone])
		var foes := _zone_foes(zone)
		check(not foes.is_empty(), "%s has foes" % zone)
		var zone_hardest := 0
		for ch: String in foes:
			var pair: Array = sheet_foes[ch]
			var foe: Enemy = pair[0].new()
			var hp := foe.max_hp
			if zone == "evercrown":
				hp = ceili(hp * Enemy.CORRUPT_HP)
			var blows := _blows(foe.get_script())
			if foe.contact_damage > 0:
				blows.append(foe.contact_damage)
			var name := (foe.get_script() as Script).get_global_name()
			var hardest := 0
			for b in blows:
				hardest = maxi(hardest, _through_par(b, zone, foe.get_script()))
			foe.free()
			if pair[1] != null:
				for b in _blows(pair[1]):
					hardest = maxi(hardest, _through_par(b, zone, pair[1]))
			var slashes := ceili(float(hp) / cut)
			check(slashes >= 2 and slashes <= 7, "%s in %s falls in 2 to 7 slashes of the par blade (%d)" % [name, zone, slashes])
			check(hardest <= 28, "%s in %s hits for at most 1.4 masks through par armor (%d)" % [name, zone, hardest])
			zone_hardest = maxi(zone_hardest, hardest)
			checked += 1
		check(zone_hardest >= 15 and zone_hardest <= 28, "%s's hardest blow costs 0.75 to 1.4 masks through par armor (%d)" % [zone, zone_hardest])
	check(checked >= 40, "the sheet covers every zone's foes (%d rows)" % checked)
	# Past Thane Vorrund the Severance is in hand: the Rise's foes still take
	# two slashes or more (pass 218).
	var slayer := int(GameData.item(PAST_VORRUND_KIT[0]).slash)
	for id: String in PAST_VORRUND_ROOMS:
		for row: String in Room.parse(FileAccess.get_file_as_string("res://levels/%s.room" % id)).grid:
			for ch in row:
				if sheet_foes.has(ch):
					var foe: Enemy = sheet_foes[ch][0].new()
					var slashes := ceili(float(foe.max_hp) / slayer)
					check(slashes >= 2 and slashes <= 7, "%s past Thane Vorrund falls in 2 to 7 Severance slashes (%d)" % [(foe.get_script() as Script).get_global_name(), slashes])
					foe.free()


## Pass 258: a foe a guardian calls into its fight is a foe like any other,
## so it answers to the same sheet. The Matriarch's daughter (a Marsh Hag) and
## the Alpha's pack (Clockwork Hounds) stand in rooms too, so the sheet already
## held them; Snapcrown's Mothlings (pass 257) stand nowhere else, and fell to a
## single slash of the High Boughs' par blade. Every Enemy a guardian's script
## makes must be a room foe on the sheet or listed here with its zone.
const SUMMONED := {"Mothling": "boughs"}

func test_a_guardians_brood_answers_to_the_sheet() -> void:
	var classes := {}
	for c: Dictionary in ProjectSettings.get_global_class_list():
		classes[String(c["class"])] = String(c["path"])
	var bosses := {}
	for row: Array in sheet_bosses:
		bosses[(row[0] as Script).get_global_name()] = true
		# A guardian's shots are on its own row of the sheet.
		for shot: Script in row[2]:
			bosses[shot.get_global_name()] = true
	var placed := {}
	for ch: String in sheet_foes:
		placed[(sheet_foes[ch][0] as Script).get_global_name()] = true
	var made := RegEx.create_from_string("\\b([A-Z][A-Za-z]+)\\.new\\(\\)")
	var found := {}
	for f in DirAccess.get_files_at("res://scripts/bosses/"):
		if not f.ends_with(".gd") or f == "boss_arena.gd":
			continue
		for m in made.search_all(FileAccess.get_file_as_string("res://scripts/bosses/" + f)):
			var name := m.get_string(1)
			if not classes.has(name) or bosses.has(name):
				continue
			var script := load(classes[name]) as Script
			var base := script
			while base != null and base.resource_path != "res://scripts/enemies/enemy.gd":
				base = base.get_base_script()
			if base != null:
				found[name] = f
	check(found.has("Mothling") and found.has("MarshHag") and found.has("ClockworkHound"), "found the guardians' broods (%s)" % [found])
	for name: String in found:
		check(placed.has(name) or SUMMONED.has(name), "%s (called by %s) is on the sheet" % [name, found[name]])
	for name: String in SUMMONED:
		var zone: String = SUMMONED[name]
		var kit: Array = PAR_KIT[zone]
		var cut := roundi(int(GameData.item(kit[0]).slash) * (1.0 + GameState.TEMPER_BONUS * int(kit[1])))
		var script := load(classes[name]) as Script
		var foe: Enemy = script.new()
		var slashes := ceili(float(foe.max_hp) / cut)
		var blows := _blows(script)
		if foe.contact_damage > 0:
			blows.append(foe.contact_damage)
		foe.free()
		var hardest := 0
		for b in blows:
			hardest = maxi(hardest, _through_par(b, zone, script))
		check(slashes >= 2 and slashes <= 7, "%s in %s falls in 2 to 7 slashes of the par blade (%d)" % [name, zone, slashes])
		check(hardest >= 1 and hardest <= 28, "%s in %s hits for at most 1.4 masks through par armor (%d)" % [name, zone, hardest])


## Pass 218: the sheet's kit past Thane Vorrund is the one the game gives there.
func test_the_sheet_past_thane_vorrund_holds_the_severance() -> void:
	check(String(BossArena.BOSSES.thane_vorrund.get("blade", "")) == PAST_VORRUND_KIT[0], "Thane Vorrund gives the blade the sheet expects past him")
	check(PAR_KIT.sunken == PAST_VORRUND_KIT and PAR_KIT.evercrown == PAST_VORRUND_KIT, "the Sunken Spring and the Evercrown are fought with it")
	var rise: Dictionary = Room.parse(FileAccess.get_file_as_string("res://levels/vorrhallow/throne_hall.room"))
	var past := []
	for spec: String in rise.lists.get("door", []):
		past.append(spec.get_slice(",", 1).strip_edges())
	check(past.has("vorrhallow/meteor_rise"), "the Glass Rise lies behind his throne (%s)" % [past])
	var rooms := {}
	for id: String in PAST_VORRUND_ROOMS:
		rooms[id] = Room.parse(FileAccess.get_file_as_string("res://levels/%s.room" % id))
	check(String(rooms["vorrhallow/evercrown_gate"].header.get("boss", "")) == "likeness", "and the Likeness waits past it, at the Crown Gate")
	var down := []
	for spec: String in rooms["vorrhallow/meteor_rise"].lists.get("door", []):
		down.append(spec.get_slice(",", 1).strip_edges())
	check(down.has("sunken/spring_gate") and down.has("vorrhallow/evercrown_gate"), "the Rise leads on to the Crown Gate and down to the Sunken Spring (%s)" % [down])


func test_a_foe_hits_as_hard_as_its_zone_is_deep() -> void:
	var rows := ARENA.duplicate()
	var room := Room.from_text("zone: vorrhallow\n---\n" + "\n".join(PackedStringArray(rows)))
	arena.add_child(room)
	var p := make_player(room, Vector2i(3, 6))
	var foe := Blinkhop.new()
	foe.position = cell_feet(8, 6)
	room.add_child(foe)
	await frames(2)
	p.defense = 0.0
	var before := p.hp
	p.receive_attack(10, foe, false)
	check(before - p.hp == 20, "a Vorrhallow foe's 10 lands for 20 (took %d)" % (before - p.hp))
	# A fire seal is the world, not a foe: it burns as written.
	p.hp = p.max_hp
	p._invuln_timer = 0.0
	var seal := FireSeal.new()
	room.add_child(seal)
	p.receive_attack(10, seal, false)
	check(p.max_hp - p.hp == 10, "a fire seal burns for 10 anywhere (took %d)" % (p.max_hp - p.hp))
	# A boss's arena is as deep as its zone (pass 196).
	room.header["boss"] = "test"
	check(room.threat() == 2.0, "a Vorrhallow arena's threat is its zone's")
	room.header.erase("boss")
	room.zone = "heartwood"
	check(room.threat() == 1.0, "the Heartwood hits as written")
	room.zone = "hearthroot"
	check(room.threat() == 1.0, "a zone off the sheet hits as written")


## The guardians' sheet (design bible 5.5, pass 196): each boss, its zone, and
## the shots it fires.
var sheet_bosses := [
	[Gnarlmaw, "heartwood", [SapClump]], [Durgan, "tower", [Rubble]],
	[Foreman, "tower", [Rubble]], [Gloamweaver, "haar", []],
	[HagMatriarch, "haar", [MireGrasp]], [HaarWyrm, "haar", [SteamBreath, HydraGeyser]],
	[Snapcrown, "boughs", [SeedShot]], [BarkCaptain, "boughs", []],
	[Skyrend, "spires", [StormStrike, HarpyFeather]],
	[ThaneVorrund, "vorrhallow", [CrystalShard, Shockwave, CrystalSpike]],
	[ClockworkAlpha, "vorrhallow", []], [Likeness, "vorrhallow", [ShadowBolt]],
	[DrownedWarden, "sunken", [TidalWave]], [EvilAvatar, "evercrown", [CrystalSpike]],
	[EvilCore, "evercrown", [CoreBeam]], [EvilHeart, "evercrown", [CoreBeam, CrystalSpike, MeteorSeed]],
]


func test_the_guardians_hit_as_hard_as_their_zone() -> void:
	var by_zone := {}
	for row: Array in sheet_bosses:
		var script: Script = row[0]
		var zone: String = row[1]
		var kit: Array = PAR_KIT[zone]
		var armor := float(GameData.item(kit[2]).defense)
		var threat := float(CombatTuning.ZONE_THREAT[zone])
		var hardest := 0
		for b in _blows(script):
			hardest = maxi(hardest, _through_par(b, zone, script))
		for shot: Script in row[2]:
			for b in _blows(shot):
				hardest = maxi(hardest, _through_par(b, zone, shot))
		var name := script.get_global_name()
		check(hardest >= 10 and hardest <= 30, "%s's hardest blow costs 0.5 to 1.5 masks through %s's par armor (%d)" % [name, zone, hardest])
		by_zone[zone] = maxi(int(by_zone.get(zone, 0)), hardest)
	# Each zone's guardians hit at least as hard as its foes' sheet floor (15),
	# so no boss is softer than the corridor that leads to it.
	for zone: String in by_zone:
		check(by_zone[zone] >= 15, "%s's guardians strike for at least 0.75 masks (%d)" % [zone, by_zone[zone]])


## Pass 204: the rubric's "balanced HP" (15.3) had no sheet. Each guardian's
## health in slashes of its zone's par blade (5.5): every one 15 to 40, a
## mini-boss never outlasting its zone's guardians, and the Everbloom (avatar
## and heart) the longest fight of the critical path. Gnarlmaw's 600 is
## spread over a plated body and a soft tail, and the Everbloom's veins are a
## climb, not a health bar, so they stay off the sheet.
const MINI_BOSSES := ["Foreman", "HagMatriarch", "BarkCaptain", "ClockworkAlpha"]
const OPTIONAL_BOSSES := ["DrownedWarden"]

func test_the_guardians_last_as_long_as_their_place() -> void:
	var slashes := {}
	var zone_of := {}
	for row: Array in sheet_bosses:
		var script: Script = row[0]
		var name := script.get_global_name()
		if name in ["Gnarlmaw", "EvilCore"]:
			continue
		var kit: Array = PAST_VORRUND_KIT if name in PAST_VORRUND_BOSSES else PAR_KIT[row[1]]
		var cut := roundi(int(GameData.item(kit[0]).slash) * (1.0 + GameState.TEMPER_BONUS * int(kit[1])))
		var boss: Enemy = script.new()
		slashes[name] = ceili(float(boss.max_hp) / cut)
		zone_of[name] = row[1]
		boss.free()
		check(slashes[name] >= 15 and slashes[name] <= 40, "%s falls in 15 to 40 par slashes (%d)" % [name, slashes[name]])
	for mini: String in MINI_BOSSES:
		var longest := 0
		for name: String in slashes:
			if zone_of[name] == zone_of[mini] and not name in MINI_BOSSES:
				longest = maxi(longest, slashes[name])
		check(slashes[mini] <= 25 and slashes[mini] <= longest, "%s (a mini-boss, %d) is no longer than %s's guardians (%d)" % [mini, slashes[mini], zone_of[mini], longest])
	# Pass 324: the bible's table (5.5) names each guardian's count, and every
	# `(ClassName, N HP` the bible names is the boss's MAX_HP.
	const NAMED := {"Durgan": "Durgan", "Foreman": "the Foreman", "HaarWyrm": "the Haar Wyrm", "Gloamweaver": "Gloamweaver",
		"HagMatriarch": "the Marsh Hag Matriarch", "Snapcrown": "Snapcrown", "BarkCaptain": "the Bark Knight Captain",
		"Skyrend": "Skyrend", "ThaneVorrund": "Thane Vorrund", "ClockworkAlpha": "the Clockwork Alpha", "Likeness": "the Likeness",
		"DrownedWarden": "the Drowned Warden", "EvilAvatar": "its avatar", "EvilHeart": "then its heart"}
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var table := bible.get_slice("**The guardians' health (pass 204).**", 1).get_slice("\n\n`test_", 0)
	var hp_named := []
	for name: String in slashes:
		var said := table.get_slice(String(NAMED.get(name, name)) + " ", 1).get_slice(" ", 0).to_int()
		check(said == slashes[name], "5.5's table gives %s %d par slashes, and the code %d" % [name, said, slashes[name]])
		var boss: Enemy = (load("res://scripts/bosses/%s.gd" % name.to_snake_case()) as Script).new() if ResourceLoader.exists("res://scripts/bosses/%s.gd" % name.to_snake_case()) else null
		if boss == null:
			continue
		var at := 0
		while true:
			at = bible.find("`%s`, " % name, at)
			if at < 0:
				break
			at += name.length() + 4
			var num := bible.substr(at, 12).get_slice(" ", 0).to_int()
			if bible.substr(at, 12).get_slice(" ", 1).begins_with("HP") and num != boss.max_hp:
				hp_named.append("%s says %d, MAX_HP %d" % [name, num, boss.max_hp])
		boss.free()
	check(hp_named.is_empty(), "every guardian's HP the bible names is its MAX_HP (%s)" % [hp_named])
	var finale: int = slashes["EvilAvatar"] + slashes["EvilHeart"]
	for name: String in slashes:
		if not name in ["EvilAvatar", "EvilHeart"] and not name in OPTIONAL_BOSSES:
			check(finale >= slashes[name], "the Everbloom (%d) lasts longer than %s (%d)" % [finale, name, slashes[name]])
	# Pass 212: no guardian outlasts every later zone's longest by more than two
	# slashes, so the fights grow (or hold) as the game goes on.
	var zones := PAR_KIT.keys()
	for name: String in slashes:
		if name in MINI_BOSSES or name in OPTIONAL_BOSSES or zone_of[name] == "evercrown":
			continue
		var later := 0
		for other: String in slashes:
			var z: String = zone_of[other]
			if zones.find(z) > zones.find(zone_of[name]) and z != "evercrown" and not other in MINI_BOSSES and not other in OPTIONAL_BOSSES:
				later = maxi(later, slashes[other])
		if later > 0:
			check(slashes[name] <= later + 2, "%s (%d) is no longer than a later zone's longest guardian (%d) by more than two" % [name, slashes[name], later])


## Design bible 5.3 (pass 198): a blow that costs a whole mask lands with a body
## thud under the yelp; a lighter one does not.
func test_a_blow_that_costs_a_mask_sounds_heavier() -> void:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	var foe := Blinkhop.new()
	foe.position = cell_feet(12, 6)
	room.add_child(foe)
	await frames(3)
	p.defense = 0.0
	Sfx.recent.clear()
	p.receive_attack(GameHud.MASK_HP - 1, foe, false)
	check(Sfx.recent.has("hurt") and not Sfx.recent.has("hurt_heavy"), "a blow under a mask only yelps (%s)" % [Sfx.recent])
	p._invuln_timer = 0.0
	Sfx.recent.clear()
	p.receive_attack(GameHud.MASK_HP, foe, false)
	check(Sfx.recent.has("hurt") and Sfx.recent.has("hurt_heavy"), "a blow of a whole mask thuds too (%s)" % [Sfx.recent])
	check(FileAccess.file_exists("res://assets/sfx/hurt_heavy.wav"), "hurt_heavy.wav exists")


## Pass 266 (bible 5.5): a guardian's brood goes down with its guardian, and
## no blow felled it. The Bloom, the Matriarch and the Clockwork Alpha had
## struck their brood down as if the player had: each Mothling, daughter or hound
## sprayed gold, rolled a drop, gave experience, counted as a kill for
## Wanderer's Grace, and piled a kill's hitstop and shake onto the guardian's
## own death. `Enemy.perish` dissolves a foe with none of that; a real kill
## still pays it all, and no guardian kills its brood any other way.
func test_a_brood_that_dies_with_its_guardian_pays_nothing() -> void:
	var room := Room.from_text("zone: trunk\n---\n" + "\n".join(PackedStringArray(ARENA)))
	arena.add_child(room)
	var p := make_player(room, Vector2i(3, 6))
	p.abilities["stride"] = true
	p.wanderers_grace = true
	var bread := Drop.bread_chance
	Drop.bread_chance = 1.0
	var paid := func(foe: Enemy, by_blow: bool) -> Array:
		foe.position = cell_feet(10, 6)
		room.add_child(foe)
		await frames(2)
		var xp: int = GameState.data.xp
		p.air_dash_charges = 0
		if by_blow:
			foe.take_hit(foe.hp, Vector2.RIGHT)
		else:
			foe.perish()
		var regained := p.air_dash_charges > 0
		await frames(2)
		var coins := room.get_children().filter(func(n: Node) -> bool: return n is Coin or n is Drop).size()
		for n in room.get_children():
			if n is Coin or n is Drop:
				n.free()
		return [GameState.data.xp - xp, coins, regained, foe.dead]
	var died: Array = await paid.call(Blinkhop.new(), false)
	check(died[3] and died[0] == 0 and died[1] == 0 and not died[2], "a foe that perishes pays no experience, gold or drop, and is no kill (%s)" % [died])
	var killed: Array = await paid.call(Blinkhop.new(), true)
	check(killed[3] and killed[0] > 0 and killed[1] > 0 and killed[2], "one struck down pays them all, and counts (%s)" % [killed])
	Drop.bread_chance = bread
	# No guardian kills its brood with a blow or a bare death any more.
	var strikes := RegEx.create_from_string("take_hit\\(\\s*\\w+\\.hp\\b|(?<![\\w.])(?!super\\b|self\\b)\\w+\\.die\\(\\)")
	var found := []
	for f in DirAccess.get_files_at("res://scripts/bosses/"):
		if f.ends_with(".gd"):
			for m in strikes.search_all(FileAccess.get_file_as_string("res://scripts/bosses/" + f)):
				found.append("%s: %s" % [f, m.get_string()])
	check(found.is_empty(), "every guardian's brood perishes with it (%s)" % [found])
	for f in ["snapcrown", "hag_matriarch", "clockwork_alpha"]:
		check(FileAccess.get_file_as_string("res://scripts/bosses/%s.gd" % f).contains(".perish()"), "%s's brood perishes with it" % f)


## Pass 386 (bible 5.3; 6.7's Input line): pass 384 timed the moves through the
## real controller, but the fight's own buttons were still only ever scripted.
## Each is pressed through `Input` here and must answer on the first physics
## step that sees it: Block raises the guard and opens the parry window, Spell
## casts, Next Spell turns to the next spell, Sapflask starts the drink, the
## Stillstone stops time, Throw lets the Rune Dagger fly, and letting go of an
## Attack held past the charge lunges into a Thrust.
## Pass 394: the guard, held and let go through the real controller. Pass 386
## timed the press of Block (the parry window opening), but the guard itself is
## read from Block held (`block_held`): it stands for as long as the button is
## down, at guard speed, drops in the step it is let go, and a broken guard
## stays down until the button is let go and pressed again (5.3, pass 242).
func test_the_guard_stands_while_block_is_held() -> void:
	var c := CombatTuning.new()
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(9, 6))
	await frames(6)
	check(p.has_shield, "the hero carries a shield")
	await press_for_real(p, ["block"])
	await frames(int(c.parry_window * 60.0) + 30)
	check(p.is_blocking and p._parry_timer <= 0.0, "held past the parry window, the guard still stands")
	release_for_real(["block"])
	await frames(1)
	check(not p.is_blocking, "let go, the guard drops in the step the release lands in")
	await press_for_real(p, ["block"])
	check(p.is_blocking, "pressed again, it is back up")
	p.guard_broken = true
	await frames(10)
	check(not p.is_blocking, "a broken guard stays down while Block is still held")
	release_for_real(["block"])
	await frames(1)
	check(not p.guard_broken, "letting go mends it")
	await press_for_real(p, ["block"])
	check(p.is_blocking, "and the next press raises the shield again")
	release_for_real(["block"])
	room.free()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 5.3 ", 1).get_slice("\n### 5.4 ", 0)
	check(note.contains("`test_the_guard_stands_while_block_is_held`"), "5.3 names the test")


func test_every_combat_button_answers_on_its_frame() -> void:
	var c := CombatTuning.new()
	for button: String in ["block", "spell", "spell_next", "heal", "stillstone", "throw"]:
		var room := make_room(ARENA)
		var p := make_player(room, Vector2i(9, 6))
		p.abilities["rune_dagger"] = true
		p.hp = 50
		await frames(6)
		var mp0 := p.mp
		await press_for_real(p, [button])
		match button:
			"block":
				check(p.is_blocking and p._parry_timer > c.parry_window - 0.02, "Block guards and opens the parry window on its frame (%.2f s)" % p._parry_timer)
			"spell":
				check(mp0 - p.mp > p.spell_cost("torrent") - 0.5 and _find(room, TorrentBolt) != null,
					"Spell casts on its frame (MP %.1f -> %.1f)" % [mp0, p.mp])
			"spell_next":
				check(p.equipped_spell == "thunder", "Next Spell turns from Deluge to Tempest Lance on its frame (%s)" % p.equipped_spell)
			"heal":
				check(p.is_drinking, "Sapflask starts the drink on its frame")
			"stillstone":
				check(TimeStop.active(), "the Stillstone stops time on its frame")
			"throw":
				check(is_instance_valid(p.rune_dagger), "Throw lets the Rune Dagger fly on its frame")
		release_for_real([button])
		TimeStop.reset()
		room.free()
	# The Thrust: Attack held past the charge, then let go.
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(9, 6))
	p.thrust = true
	await frames(6)
	await press_for_real(p, ["attack"])
	await frames(int(c.thrust_charge * 60.0) + 30)
	check(p.thrust_ready() and p.attack_kind != "thrust", "held past %.1f s the charge is full, and nothing lunges yet" % c.thrust_charge)
	# A held button is read as held or not (`attack_held`), not as just
	# pressed, so a release made inside step f is seen by step f itself.
	Input.action_release("attack")
	await frames(1)
	check(p.attack_kind == "thrust", "letting go lunges in the step the release lands in (%s)" % p.attack_kind)
	room.free()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 5.3 ", 1).get_slice("\n### 5.4 ", 0)
	check(note.contains("`test_every_combat_button_answers_on_its_frame`"), "5.3 names the test")


## Pass 434: a Thrust's charge across a pause or a hold. Pass 386 let go of a
## charged Attack in play, but a player often opens the pause menu, takes a
## door or reads a sign with the charge full. The Attack let go meanwhile was
## seen as a release as play went on, and the hero lunged out of the menu, out
## of the door's scroll or out of the dialog. `how` is "pause" (the tree is
## paused, as by a menu), "hold" (the hero is frozen, as by a door or a dialog)
## or "held" (paused with Attack kept down, then let go in play). Returns
## whether the hero thrust in the 6 steps after play went on.
func _thrust_across(how: String) -> bool:
	var c := CombatTuning.new()
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(9, 6))
	p.thrust = true
	await frames(6)
	await press_for_real(p, ["attack"])
	await frames(int(c.thrust_charge * 60.0) + 30)
	check(p.thrust_ready() and p.attack_kind != "thrust", "%s: the charge is full and nothing lunges yet" % how)
	if how == "hold":
		p.frozen = true
	else:
		runner.get_tree().paused = true
	# Let go in the frame after the game stops, as a player does.
	await runner.get_tree().process_frame
	if how != "held":
		Input.action_release("attack")
	for i in 10:
		await runner.get_tree().process_frame
	if how == "hold":
		p.frozen = false
	else:
		runner.get_tree().paused = false
	if how == "held":
		await frames(2)
		Input.action_release("attack")
	var thrust := false
	for i in 6:
		await frames(1)
		thrust = thrust or p.attack_kind == "thrust"
	Input.action_release("attack")
	room.free()
	return thrust


func test_a_thrust_is_not_let_go_by_a_pause_or_a_hold() -> void:
	check(not await _thrust_across("pause"), "Attack let go in the pause menu does not lunge as play goes on")
	check(not await _thrust_across("hold"), "Attack let go through a door's scroll or a dialog does not lunge after it")
	check(await _thrust_across("held"), "Attack held through the pause keeps the charge, and letting go in play lunges")
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 5.3 ", 1).get_slice("\n### 5.4 ", 0)
	check(note.contains("`test_a_thrust_is_not_let_go_by_a_pause_or_a_hold`"), "5.3 names the test")



## Pass 402: the fight's timing windows, through the real controller. Pass 386
## pressed each combat button through `Input`, but the two windows that decide
## whether a second swing chains (the attack buffer, 0.15 s, and the combo
## window, 0.40 s) were only ever held with a scripted intent. Swings once for
## real, then presses Attack again `after` steps later (counted from the first
## step that shows the swing). Returns [the highest combo index reached, the
## step the second swing came on, counted from the same start, or -1].
func _real_second_press(after: int) -> Array:
	var room := make_room(ARENA)
	var p := make_player(room, Vector2i(3, 6))
	await frames(6)
	p.input = PlayerInput.new()
	Input.action_press("attack")
	var start := -1
	for i in 10:
		await frames(1)
		if p.combo_index == 1:
			start = Engine.get_physics_frames()
			break
	Input.action_release("attack")
	while Engine.get_physics_frames() < start + after - 1:
		await frames(1)
	Input.action_press("attack")
	var best := 1
	var came := -1
	for i in 40:
		await frames(1)
		if i == 1:
			Input.action_release("attack")
		if p.combo_index == 2 and came < 0:
			came = Engine.get_physics_frames() - start
		best = maxi(best, p.combo_index)
	release_for_real(["attack"])
	room.free()
	return [best, came]


func test_the_combo_windows_hold_through_the_real_controller() -> void:
	var c := CombatTuning.new()
	var cool := int(roundf(c.combo_cooldowns[0] * 60.0))
	var buffer := int(roundf(c.attack_buffer * 60.0))
	var window := int(roundf(c.combo_window * 60.0))
	# The buffer: a press inside the last 0.15 s of the cooldown is held and
	# swings on the step the cooldown ends; one before that is dropped.
	var edge := cool - buffer
	var lands: Array[int] = []
	for k in range(edge, cool):
		var got: Array = await _real_second_press(k)
		check(got[0] == 2, "pressed %d steps into the 12-step cooldown, it is buffered (%s)" % [k, got])
		lands.append(got[1])
	check(lands.all(func(f: int) -> bool: return f == lands[0]), "and every buffered press swings on the same step, the one the cooldown ends (%s)" % [lands])
	var early: Array = await _real_second_press(edge - 1)
	check(early[0] == 1, "pressed %d steps in, before the buffer opens, it is dropped (%s)" % [edge - 1, early])
	# The combo window: a press up to 0.40 s after the swing chains; later restarts.
	var late_in: Array = await _real_second_press(window - 1)
	check(late_in[0] == 2, "pressed %d steps after the swing, inside 0.40 s, it chains (%s)" % [window - 1, late_in])
	var too_late: Array = await _real_second_press(window)
	check(too_late[0] == 1, "pressed %d steps after, it starts the combo over (%s)" % [window, too_late])
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 5.3 ", 1).get_slice("\n### 5.4 ", 0)
	check(note.contains("The combo's windows, pressed (pass 402)"), "bible 5.3 says so")


## Pass 418: an ordinary foe parried through the real controller. Pass 412
## parried Thane Vorrund by the buttons, and 386 and 394 pressed and held Block
## on an empty floor, but the parry window against an ordinary foe (0.12 s,
## 6 MP, the stagger) and the held guard's halved blow were only ever scripted.
## Block goes down for real so that the game sees it `frames_before` steps
## before the Rot Dwarf's blade lands. Returns [staggered, hp lost, mp gained].
## Pass 422: the fourth entry is what the fight sounded like from the press on.
func _real_block_against_the_dwarf(frames_before: int, hold: bool, mp := 20.0) -> Array:
	var a := _dwarf_arena()
	var p: Player = a[1]
	var dwarf: RotDwarf = a[2]
	p.input = PlayerInput.new()
	p.has_shield = true
	# Input pressed in step f is first seen in step f + 1. MP is set as the
	# button goes down, so the wait's regeneration cannot top it up.
	await _wait_for_swing(dwarf, frames_before + 1)
	p.mp = mp
	Sfx.recent.clear()
	Input.action_press("block")
	await frames(1)
	if not hold:
		await frames(1)
		Input.action_release("block")
	var staggered := false
	for i in frames_before + 10:
		await frames(1)
		staggered = staggered or dwarf.is_staggered()
	var heard: Array[String] = []
	for sound: String in Sfx.recent:
		if sound in ["parry", "guard", Player.GUARD_BREAK_SOUND, "hurt"]:
			heard.append(sound)
	var out := [staggered, p.max_hp - p.hp, p.mp - mp, heard]
	release_for_real(["block"])
	(a[0] as Node).queue_free()
	await frames(2)
	return out



func test_an_ordinary_foe_is_parried_through_the_real_controller() -> void:
	var c := CombatTuning.new()
	var last := 0
	var at_edge: Array = []
	var too_soon: Array = []
	for fb in range(5, 11):
		var r: Array = await _real_block_against_the_dwarf(fb, false)
		if r[0]:
			last = fb
			at_edge = r
		elif too_soon.is_empty():
			too_soon = r
	var window := floori(c.parry_window * 60.0)
	check(last == window, "pressed for real, the last step a parry counts is the %dth before the blow, %.2f s (got %d)" % [window, c.parry_window, last])
	check(not at_edge.is_empty() and at_edge[1] == 0 and at_edge[2] >= c.parry_mp_gain,
		"there the Rot Dwarf reels, the blow does nothing and the parry pays %d MP (%s)" % [c.parry_mp_gain, at_edge])
	check(not too_soon.is_empty() and too_soon[1] == RotDwarf.SWING_DAMAGE,
		"a step sooner the whole blow lands (%s)" % [too_soon])
	var held: Array = await _real_block_against_the_dwarf(20, true)
	var guarded := int(round(RotDwarf.SWING_DAMAGE * (1.0 - c.guard_reduction)))
	check(not held[0] and held[1] == guarded and held[2] < 0.0,
		"Block held from long before guards: no reel, the blow halved to %d, and MP paid (%s)" % [guarded, held])
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 5.3 ", 1).get_slice("\n### 5.4 ", 0)
	check(note.contains("An ordinary foe parried with the buttons (pass 418)"), "5.3 says so")



## Pass 422: the fight, heard through the buttons (bible 13.3). Pass 418 pressed
## Block for real against the Rot Dwarf and read the blow's outcome; each
## outcome has its own sound, and those were only heard with a scripted guard.
## Here each is heard once and alone: a parry rings, a press a step too soon
## lets the blow land with the hurt cry, a held guard thuds, and a held guard
## with too little MP breaks with its own crack and the blow lands whole.
func test_the_fight_is_heard_through_the_buttons() -> void:
	var c := CombatTuning.new()
	var window := floori(c.parry_window * 60.0)
	var parried: Array = await _real_block_against_the_dwarf(window, false)
	check(parried[3] == ["parry"], "a parry pressed for real rings once, and nothing else is heard (%s)" % [parried[3]])
	var soon: Array = await _real_block_against_the_dwarf(window + 1, false)
	check(soon[3] == ["hurt"], "a step too soon, the blow lands with the hurt cry alone (%s)" % [soon[3]])
	var held: Array = await _real_block_against_the_dwarf(20, true)
	check(held[3] == ["guard", "hurt"], "Block held guards with its thud, then the halved blow's cry (%s)" % [held[3]])
	var broke: Array = await _real_block_against_the_dwarf(20, true, c.guard_mp_cost - 1.0)
	check(broke[3] == [Player.GUARD_BREAK_SOUND, "hurt"] and broke[1] == RotDwarf.SWING_DAMAGE,
		"held with too little MP, the guard cracks and the whole blow lands (%s, %d)" % [broke[3], broke[1]])
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("The fight, heard through the buttons (pass 422)"), "bible 13.3 says so")


## Pass 442 (bible 5.3): spells, by the buttons, at a real foe. Pass 386 found
## Spell answered on its frame (the MP spent, a bolt out), but no bolt cast
## through `Input` was ever seen to meet a foe, Next Spell was never followed
## by a cast, and casting's rules (not while guarding; a press inside the
## 0.35 s cooldown casts nothing and is not saved) were only ever scripted.
## Cast at the Rot Dwarf, the bolt met his shield, and the shield's push meant
## for a blade at arm's length shoved the hero back from across the room.
func test_spells_answer_the_real_controller_at_a_real_foe() -> void:
	var c := CombatTuning.new()
	var room := _arena_with("D", Vector2i(16, 6))
	var p := make_player(room, Vector2i(3, 6), {"thunder": true})
	p.has_shield = true
	var dwarf: RotDwarf = _find(room, RotDwarf)
	await frames(6)
	# Deluge, pressed for real, meets the dwarf's shield across the room.
	var hp0 := dwarf.hp
	var mp0 := p.mp
	var x0 := p.global_position.x
	Sfx.recent.clear()
	await press_for_real(p, ["spell"])
	release_for_real(["spell"])
	var bolt: TorrentBolt = _find(room, TorrentBolt)
	check(bolt != null and absf(mp0 - p.mp - p.spell_cost("torrent")) < 0.5,
		"Spell casts the Deluge and pays %.0f MP (%.1f -> %.1f)" % [p.spell_cost("torrent"), mp0, p.mp])
	var dmg := bolt.damage if bolt != null else -1
	var most := 0.0
	for i in 60:
		await frames(1)
		most = maxf(most, absf(p.global_position.x - x0))
	check(dwarf.hits_taken == 1 and dwarf.hp == hp0 and Sfx.recent.has("guard"),
		"the bolt meets the Rot Dwarf's shield with its thud, and does nothing (%d hits, %d -> %d)" % [dwarf.hits_taken, hp0, dwarf.hp])
	check(most < 0.5, "and the hero, %d px away, is not pushed back (moved %.1f px)" % [roundi(dwarf.global_position.x - x0), most])
	# Cast as his axe goes up, his shield is down and the bolt lands.
	for i in 400:
		if dwarf.state == "windup":
			break
		await frames(1)
	check(dwarf.state == "windup", "the dwarf comes and raises his axe")
	hp0 = dwarf.hp
	await press_for_real(p, ["spell"])
	release_for_real(["spell"])
	for i in 20:
		await frames(1)
		if dwarf.hp < hp0:
			break
	check(hp0 - dwarf.hp == dmg, "cast then, the Deluge strikes him for its %d (%d -> %d)" % [dmg, hp0, dwarf.hp])
	room.free()
	# Next Spell turns to Tempest Lance; Spell then casts it, and a press inside
	# the cooldown casts nothing, then or once the cooldown is over.
	room = make_room(ARENA)
	p = make_player(room, Vector2i(3, 6), {"thunder": true})
	p.has_shield = true
	await frames(6)
	await press_for_real(p, ["spell_next"])
	release_for_real(["spell_next"])
	check(p.equipped_spell == "thunder", "Next Spell readies Tempest Lance (%s)" % p.equipped_spell)
	mp0 = p.mp
	await press_for_real(p, ["spell"])
	release_for_real(["spell"])
	check(_find(room, ThunderBolt) != null and absf(mp0 - p.mp - p.spell_cost("thunder")) < 0.5,
		"Spell now casts Tempest Lance for %.0f MP (%.1f -> %.1f)" % [p.spell_cost("thunder"), mp0, p.mp])
	await frames(4)
	var mp1 := p.mp
	await press_for_real(p, ["spell"])
	release_for_real(["spell"])
	await frames(int(c.cast_cooldown * 60.0) + 10)
	check(p.mp >= mp1 - 0.5,
		"a press inside the %.2f s cooldown casts nothing, then or after (MP %.1f -> %.1f)" % [c.cast_cooldown, mp1, p.mp])
	# Block held: Spell casts nothing and spends nothing.
	await press_for_real(p, ["block"])
	check(p.is_blocking, "Block held raises the guard")
	mp1 = p.mp
	await press_for_real(p, ["spell"])
	release_for_real(["spell"])
	await frames(2)
	check(p.mp >= mp1 - 0.5, "behind the guard, Spell casts nothing (MP %.1f -> %.1f)" % [mp1, p.mp])
	release_for_real(["block"])
	await frames(2)
	await press_for_real(p, ["spell"])
	release_for_real(["spell"])
	check(p.mp < mp1 - p.spell_cost("thunder") + 1.0, "and the guard lowered, the next press casts (MP %.1f)" % p.mp)
	room.free()
	# The blade, turned by the same shield at arm's length, still pushes back.
	room = _arena_with("D", Vector2i(5, 6))
	p = make_player(room, Vector2i(3, 6))
	dwarf = _find(room, RotDwarf)
	await frames(4)
	# Held on patrol facing the hero, shield up (this close he would raise
	# his axe and lower it).
	dwarf.set_physics_process(false)
	dwarf.state = "patrol"
	dwarf.facing = -1
	hp0 = dwarf.hp
	await press_for_real(p, ["attack"])
	release_for_real(["attack"])
	var shove := 0.0
	for i in 6:
		shove = minf(shove, p.velocity.x)
		await frames(1)
	check(dwarf.hp == hp0 and dwarf.hits_taken == 1 and shove <= -c.turned_blade_push + 1.0,
		"a slash his shield turns pushes the hero back at %.0f px/s, harder than a cut that lands (%.0f px/s, %d -> %d)" % [c.turned_blade_push, shove, hp0, dwarf.hp])
	room.free()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 5.3 ", 1).get_slice("\n### 5.4 ", 0)
	check(note.contains("Spells by the buttons (pass 442)"), "5.3 says so")



## Pass 450 (bible 5.3): the Thrust, held and let go with the real Attack, at a
## shielded foe. Into his shield it is turned like a cut: no harm, the guard's
## thud and no cut, the lunge stopped and the hero pushed back at the turned
## blade's 200 px/s. Into his back it bites for the heavy hit times 1.5, is
## heard as a cut, and the lunge stops at him instead of carrying the hero in.
func _real_thrust_at_dwarf(dwarf_faces: int) -> Dictionary:
	var room := _arena_with("D", Vector2i(8, 6))
	var p := make_player(room, Vector2i(3, 6))
	p.thrust = true
	var dwarf: RotDwarf = _find(room, RotDwarf)
	await frames(4)
	dwarf.set_physics_process(false)
	dwarf.state = "patrol"
	dwarf.facing = dwarf_faces
	p.facing = 1
	var hp0 := dwarf.hp
	Sfx.recent.clear()
	await press_for_real(p, ["attack"])
	var cut_hits := dwarf.hits_taken
	for i in int(p.combat.thrust_charge * 60.0) + 4:
		await frames(1)
	var ready := p.thrust_ready()
	Sfx.recent.clear()
	release_for_real(["attack"])
	var shove := 0.0
	var nearest := INF
	var met := -1
	for i in 30:
		await frames(1)
		shove = minf(shove, p.velocity.x)
		nearest = minf(nearest, dwarf.global_position.x - p.global_position.x)
		if met < 0 and dwarf.hits_taken > cut_hits:
			met = i
	var out := {"ready": ready, "cut_hits": cut_hits, "thrusts": p.thrusts, "hits": dwarf.hits_taken - cut_hits,
		"harm": hp0 - dwarf.hp, "want": roundi(p.heavy_damage * p.combat.thrust_mult * p.blade_mult()),
		"guard": Sfx.recent.has("guard"), "hit": Sfx.recent.has("hit"), "shove": shove, "nearest": nearest,
		"lunging": p._thrust_lunge, "met": met}
	release_for_real(["attack"])
	room.free()
	return out


func test_the_thrust_answers_the_real_controller_at_a_shield() -> void:
	var c := CombatTuning.new()
	var front: Dictionary = await _real_thrust_at_dwarf(-1)
	check(front.ready and front.cut_hits == 0, "Attack held charges the Thrust, and the first cut falls short of him (%s)" % [front])
	check(front.thrusts == 1 and front.hits == 1 and front.met >= 0, "let go, the Thrust lunges and meets his shield (%d hits)" % front.hits)
	check(front.harm == 0, "his shield turns it: no harm (%d)" % front.harm)
	check(front.guard and not front.hit, "heard as the guard's thud, never a cut")
	check(front.shove <= -c.turned_blade_push + 1.0, "and the hero is pushed back at %.0f px/s (%.0f)" % [c.turned_blade_push, front.shove])
	check(not front.lunging, "the lunge stops at the shield")
	var back: Dictionary = await _real_thrust_at_dwarf(1)
	check(back.thrusts == 1 and back.hits == 1, "into his back the Thrust lands once (%d)" % back.hits)
	check(back.harm == back.want, "for the heavy hit times %.1f (%d, want %d)" % [c.thrust_mult, back.harm, back.want])
	check(back.hit and not back.guard, "heard as a cut, with no thud")
	check(back.nearest > 8.0 and not back.lunging, "and the lunge stops at him, never carrying the hero into his body (%.0f px apart at most)" % back.nearest)
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 5.3 ", 1).get_slice("\n### 5.4 ", 0)
	check(note.contains("`test_the_thrust_answers_the_real_controller_at_a_shield`"), "5.3 names the test")


## Pass 446 (bible 13.3): a slash a guard turns is heard as a guard. Since pass
## 442 it pushes back as a clang, but every swing that met a foe still played
## the cut's `hit` over the shield's `guard`, so a turned blade sounded like a
## blade that landed. A swing that only meets guards is heard by the guard's
## thud alone; one that lands is heard as a cut, with no thud.
func test_a_turned_blade_is_heard_as_a_guard() -> void:
	var room := _arena_with("D", Vector2i(5, 6))
	var p := make_player(room, Vector2i(3, 6))
	var dwarf: RotDwarf = _find(room, RotDwarf)
	await frames(4)
	# Held on patrol facing the hero, shield up.
	dwarf.set_physics_process(false)
	dwarf.state = "patrol"
	dwarf.facing = -1
	var heard := func() -> Array:
		Sfx.recent.clear()
		await press_for_real(p, ["attack"])
		release_for_real(["attack"])
		await frames(6)
		return Sfx.recent.filter(func(n: String) -> bool: return n in ["hit", "guard"])
	var hp0 := dwarf.hp
	var turned: Array = await heard.call()
	check(dwarf.hp == hp0 and turned == ["guard"], "a slash his shield turns is heard by its thud alone (%s)" % [turned])
	# Turned away, his back is bare.
	dwarf.facing = 1
	await frames(30)
	var landed: Array = await heard.call()
	check(dwarf.hp < hp0 and landed == ["hit"], "a slash that lands is heard as a cut, with no thud (%s)" % [landed])
	room.free()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_a_turned_blade_is_heard_as_a_guard`"), "the bible names the test")


## Pass 472: combat under the Game speed option, by the real controller.
## Pass 470 found the dash's timer cut its stride at 70%. Combat's timers were
## never run at any speed but 100%. Game speed is an assist, so slowing the
## game must never make a window tighter to hit: counted in frames on screen,
## the parry window and a slash's cutting time only grow as the game slows,
## each stays within a step of its game time, and the Thrust's lunge carries
## at least its stated reach at every speed.
func test_combat_windows_only_widen_as_the_game_slows() -> void:
	var c := CombatTuning.new()
	var t := MovementTuning.new()
	var last_parry := 0
	var last_slash := 0
	for speed: float in Settings.SPEED_STEPS:
		Feel.set_game_speed(speed)
		var step := speed / 60.0
		var pct := roundi(speed * 100.0)
		var room := _arena_with(".", Vector2i(30, 6))
		var p := make_player(room, Vector2i(3, 6))
		p.has_shield = true
		p.thrust = true
		await frames(6)
		p.facing = 1
		p.input = PlayerInput.new()
		var count := func(action: String, live: Callable) -> int:
			Input.action_press(action)
			var n := 0
			for i in 40:
				await frames(1)
				if live.call():
					n += 1
			Input.action_release(action)
			await frames(20)
			return n
		var parry: int = await count.call("block", func() -> bool: return p._parry_timer > 0.0)
		var slash: int = await count.call("attack", func() -> bool: return p.is_attacking and p.attack_kind != "thrust")
		check(parry >= last_parry and slash >= last_slash,
			"at %d%%, the parry (%d frames) and a slash (%d frames) are no tighter than at a faster speed (%d, %d)" % [pct, parry, slash, last_parry, last_slash])
		check(absf(parry * step - c.parry_window) <= step + 0.0001 and absf(slash * step - t.slash_active) <= step + 0.0001,
			"at %d%%, each holds its game time within a step (parry %.3f s of %.2f, slash %.3f s of %.2f)" % [pct, parry * step, c.parry_window, slash * step, t.slash_active])
		last_parry = parry
		last_slash = slash
		# The Thrust: Attack held to charge, let go to lunge.
		Input.action_press("attack")
		for i in ceili(c.thrust_charge / step) + 4:
			await frames(1)
		var x0 := p.global_position.x
		Input.action_release("attack")
		var lunged := false
		var reach := -1.0
		for i in 40:
			await frames(1)
			if p.is_attacking and p.attack_kind == "thrust":
				lunged = true
			elif lunged and reach < 0.0:
				reach = p.global_position.x - x0
		var stated := c.thrust_speed * c.thrust_time
		check(lunged and reach >= stated - 0.01 and reach <= stated + c.thrust_speed * step + 0.01,
			"at %d%%, a real Thrust lunges its %.0f px (%.1f px)" % [pct, stated, reach])
		room.free()
	Feel.set_game_speed(1.0)
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 5.3 ", 1).get_slice("\n### 5.4 ", 0)
	check(note.contains("Combat at every game speed (pass 472)"), "5.3 says so")


## Pass 480: passes 470 and 472 ran the dash and the blade at every game speed;
## the Rune Dagger and the spells were only thrown and cast at full speed. Their
## reach is a distance in the world, so it must not change with the Game speed
## option (14), and their cooldowns run on game time, so a slower game is never
## a faster one. Thrown and cast with the real buttons at 100 and 70%.
func _reach_at(speed: float, id: String) -> Array:
	Feel.set_game_speed(speed)
	var rows := ["#".repeat(60)]
	for y in 10:
		rows.append("#" + ".".repeat(58) + "#")
	rows.append("#".repeat(60))
	var room := make_room(rows)
	var p := make_player(room, Vector2i(3, 9), {"rune_dagger": id == "dagger", id: true})
	p.input = PlayerInput.new()
	await frames(6)
	var shield_was := String(GameState.data.equipment.get("shield", ""))
	if id == "dagger":
		GameState.data.equipment.shield = ""
	else:
		p.equipped_spell = id
		p.mp = p.combat.max_mp
	await press_for_real(p, ["throw" if id == "dagger" else "spell"])
	release_for_real(["throw", "spell"])
	var shots := runner.get_tree().get_nodes_in_group("projectile")
	var shot: Node2D = p.rune_dagger if id == "dagger" else (shots[0] if shots.size() == 1 else null)
	var far := 0.0
	var start := shot.global_position if shot != null else Vector2.ZERO
	var n := 0
	while shot != null and is_instance_valid(shot) and n < 600:
		far = maxf(far, absf(shot.global_position.x - start.x))
		await frames(1)
		n += 1
	var back := 0
	if id == "dagger":
		while not p.dagger_ready() and back < 600:
			await frames(1)
			back += 1
	GameState.data.equipment.shield = shield_was
	Feel.set_game_speed(1.0)
	room.free()
	return [far, back]


func test_thrown_and_cast_reach_holds_at_every_game_speed() -> void:
	for id: String in ["dagger", "torrent", "thunder", "fire"]:
		var full: Array = await _reach_at(1.0, id)
		var slow: Array = await _reach_at(0.7, id)
		check(full[0] > 40.0 and absf(float(slow[0]) - float(full[0])) <= 8.0,
			"%s carries as far at 70%% as at full speed (%.0f px, %.0f px)" % [id, full[0], slow[0]])
		if id == "dagger":
			check(int(slow[1]) >= int(full[1]), "and comes home no sooner on screen (%d frames, %d)" % [full[1], slow[1]])
	var sec := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("### 5.3 Combat moves", 1).get_slice("\n### 5.4 ", 0)
	check(sec.contains("Thrown and cast at every game speed (pass 480)"), "bible 5.3 says so")


## The red edge swells on the heartbeat itself (pass 484): brightest in the
## frame the beat sounds, at every game speed, however long the HUD had been up.
func test_the_red_edge_swells_on_the_heartbeat_at_every_game_speed() -> void:
	for speed: float in [1.0, 0.7]:
		Feel.set_game_speed(speed)
		var room := make_room(ARENA)
		var p := make_player(room, Vector2i(3, 6))
		var hud := GameHud.new()
		hud.player = p
		arena.add_child(hud)
		# An odd wait first, so a clock of the HUD's own would be out of step.
		await frames(17)
		p.hp = p.combat.low_health
		# Past the hurt flash the drop in health shows, to the pulse alone.
		await frames(int(1.0 / speed * 60.0))
		var beats := p.heartbeats
		var on_beat: Array[float] = []
		var most := 0.0
		var least := 1.0
		for i in int(p.combat.heartbeat_interval / speed * 60.0 * 3.0) + 4:
			await frames(1)
			var s := hud.edge_strength()
			most = maxf(most, s)
			least = minf(least, s)
			if p.heartbeats != beats:
				beats = p.heartbeats
				on_beat.append(s)
		check(on_beat.size() >= 3, "%d%%: the heart beats (%d)" % [int(speed * 100), on_beat.size()])
		var ok := most - least > 0.08
		for s: float in on_beat:
			ok = ok and s >= most - 0.01
		check(ok, "%d%%: the edge is at its brightest as each beat sounds (%s, %.2f to %.2f)" % [int(speed * 100), on_beat, least, most])
		hud.queue_free()
		room.queue_free()
		Feel.set_game_speed(1.0)
		await frames(2)
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("test_the_red_edge_swells_on_the_heartbeat_at_every_game_speed"), "the bible names this test")


## A blow throws you as far at every game speed, through its own freeze
## (pass 488). Being hurt sets the knockback (160 px/s back, 220 up) and
## freezes the game for 0.15 s; the hurt pose lets go after 0.25 s of game
## time. With hitstop on (the runner turns it off), the throw is measured at
## 100, 85 and 70% Game speed: as far back and as high each time, within a step.
func test_a_blow_throws_you_as_far_at_every_game_speed() -> void:
	var throws := {}
	for speed: float in [1.0, 0.85, 0.7]:
		Feel.set_game_speed(speed)
		var room := make_room(ARENA)
		var p := make_player(room, Vector2i(6, 6))
		p.max_hp = 999
		p.hp = 999
		for i in 20:
			await frames(1)
		var x0 := p.global_position.x
		var y0 := p.global_position.y
		Feel.hitstop_enabled = true
		p.take_damage(10, false, -1)
		Feel.hitstop_enabled = false
		var frozen := Feel.is_frozen()
		# The freeze ends on the wall clock (0.15 s), which a fast machine can
		# take hundreds of frames to reach: wait it out in real time first.
		var until := Time.get_ticks_msec() + 2000
		while Feel.is_frozen() and Time.get_ticks_msec() < until:
			await frames(1)
		var high := 0.0
		var landed := false
		var flew := false
		for i in 600:
			await frames(1)
			high = maxf(high, y0 - p.global_position.y)
			# Off the ground for real: a frozen step (no game time) can read as
			# off the floor, so the throw must have lifted the hero first.
			flew = flew or (not p.is_on_floor() and high > 6.0 and not Feel.is_frozen())
			if flew and p.is_on_floor():
				landed = true
				break
		throws[speed] = Vector2(x0 - p.global_position.x, high)
		check(frozen and landed, "%d%%: the blow freezes the game, then you land (%s)" % [int(speed * 100), throws[speed]])
		Feel.reset()
		Feel.set_game_speed(1.0)
		room.queue_free()
		await frames(2)
	var full: Vector2 = throws[1.0]
	check(full.x > 20.0 and full.y > 12.0, "a blow throws you back and up (%s)" % full)
	for speed: float in [0.85, 0.7]:
		var got: Vector2 = throws[speed]
		check(absf(got.x - full.x) <= 4.0 and absf(got.y - full.y) <= 4.0, "%d%%: as far back and as high (%s, at full speed %s)" % [int(speed * 100), got, full])
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("test_a_blow_throws_you_as_far_at_every_game_speed"), "the bible names this test")

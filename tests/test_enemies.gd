extends TestSuite
## Enemy behavior: telegraphs, movement toward the player, shields, respawn.

const WIDE := [
	"##############################",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"##############################",
]


func _room_with(spots: Dictionary) -> Room:
	var rows := WIDE.duplicate()
	for cell: Vector2i in spots:
		var row: String = rows[cell.y]
		rows[cell.y] = row.substr(0, cell.x) + spots[cell] + row.substr(cell.x + 1)
	return make_room(rows)


func _find(room: Room, type: Variant) -> Node:
	for c in room.get_children():
		if is_instance_of(c, type):
			return c
	return null


func test_blinkhop_telegraphs_then_hops_toward_player() -> void:
	var room := _room_with({Vector2i(12, 6): "M"})
	var p := make_player(room, Vector2i(5, 6))
	p.max_hp = 9999
	p.hp = 9999
	var m: Blinkhop = _find(room, Blinkhop)
	var x0 := m.global_position.x
	var windup_frames := 0
	var hopped := false
	for i in 90:
		await frames(1)
		if m.state == "windup":
			windup_frames += 1
		if m.state == "hop":
			hopped = true
	check(windup_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "telegraph lasts at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, windup_frames])
	check(hopped and m.global_position.x < x0 - 20.0, "hopped toward the player (moved %.1f)" % (m.global_position.x - x0))


func test_hornet_swoops_at_player() -> void:
	var room := _room_with({Vector2i(12, 3): "H"})
	var p := make_player(room, Vector2i(6, 6))
	p.max_hp = 9999
	p.hp = 9999
	var h: Hornet = _find(room, Hornet)
	var start := h.center().distance_to(p.global_position + Vector2(0, -20))
	var closest := start
	var windup_frames := 0
	for i in 120:
		await frames(1)
		if h.state == "windup":
			windup_frames += 1
		closest = minf(closest, h.center().distance_to(p.global_position + Vector2(0, -20)))
	check(windup_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "buzz telegraph lasts at least %.2f s" % Enemy.MIN_TELEGRAPH)
	check(closest < start - 40.0, "swooped at the player (closest %.1f from %.1f)" % [closest, start])


func test_sap_spitter_telegraphs_and_lobs_a_glob_that_leaves_sap() -> void:
	var room := _room_with({Vector2i(20, 6): "T"})
	var p := make_player(room, Vector2i(9, 6))
	p.max_hp = 9999
	p.hp = 9999
	var t: SapSpitter = _find(room, SapSpitter)
	var windup_frames := 0
	var glob: SapGlob = null
	for i in 90:
		await frames(1)
		if t.state == "windup":
			windup_frames += 1
		if glob == null:
			glob = _find(room, SapGlob)
		if glob != null:
			break
	check(windup_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "the sac swells for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, windup_frames])
	check(glob != null and glob.velocity.x < 0.0 and glob.velocity.y < 0.0, "then it lobs a glob up and toward the player")
	var hp := p.hp
	for i in 80:
		await frames(1)
		if p.hp < hp:
			break
	check(p.hp < hp, "the glob lands on the player and hurts")
	# A miss leaves a puddle that slows.
	p.teleport(cell_feet(3, 6))
	await frames(1)
	var spot := cell_feet(9, 6)
	var target_x := spot.x
	var from := t.mouth()
	var miss := SapGlob.new()
	miss.velocity = SapGlob.launch(from, Vector2(target_x, spot.y - 2), SapSpitter.FLIGHT)
	miss.room = room
	room.add_child(miss)
	miss.global_position = from
	await frames(60)
	check(room.is_sap_at(spot + Vector2(0, -6)), "a glob that hits the floor leaves sap")
	await frames(roundi(SapGlob.PUDDLE_TIME * 60.0) + 5)
	check(not room.is_sap_at(spot + Vector2(0, -6)), "and the puddle dries")


func test_grub_lump_crawls_up_walls_and_over_the_ceiling() -> void:
	var room := _room_with({Vector2i(3, 6): "U"})
	var g: GrubLump = _find(room, GrubLump)
	check(g.clinging_side() == Vector2i(0, 1), "it starts on the floor")
	var sides := {}
	var inside := true
	var inner := Rect2(Vector2(16, 16), Vector2(28 * 16, 6 * 16))
	for i in 420:
		await frames(1)
		sides[g.clinging_side()] = true
		inside = inside and inner.has_point(g.global_position)
	check(sides.has(Vector2i(-1, 0)), "it climbed the left wall")
	check(sides.has(Vector2i(0, -1)), "and crossed onto the ceiling")
	check(inside, "without leaving the open space")


func test_grub_lump_telegraphs_and_drops_from_the_ceiling() -> void:
	var room := _room_with({Vector2i(12, 1): "U"})
	var g: GrubLump = _find(room, GrubLump)
	check(g.on_ceiling(), "placed under a ceiling, it clings to it")
	var p := make_player(room, Vector2i(12, 6))
	p.max_hp = 9999
	p.hp = 9999
	var hp := p.hp
	var windup_frames := 0
	var landed := false
	for i in 120:
		await frames(1)
		if g.state == "windup":
			windup_frames += 1
		if g.state == "land":
			landed = true
			break
	check(windup_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "it rears for at least %.2f s before dropping (%d frames)" % [Enemy.MIN_TELEGRAPH, windup_frames])
	check(p.hp < hp, "the drop hurts the player below")
	check(landed and g.clinging_side() == Vector2i(0, 1), "it lands on the floor")
	p.teleport(cell_feet(24, 6))
	await frames(roundi(GrubLump.LAND_TIME * 60.0) + 30)
	check(g.state == "crawl", "and crawls on")


func test_iron_dwarf_telegraphs_then_slams_a_shockwave() -> void:
	var room := _room_with({Vector2i(18, 6): "I"})
	var d: IronDwarf = _find(room, IronDwarf)
	d.facing = -1
	var p := make_player(room, Vector2i(12, 6))
	p.max_hp = 9999
	p.hp = 9999
	var hp := p.hp
	var windup_frames := 0
	var wave_seen := false
	for i in 150:
		await frames(1)
		if d.state == "windup":
			windup_frames += 1
		for c in room.get_children():
			if c is Shockwave:
				wave_seen = true
		if d.state == "stuck" and p.hp < hp:
			break
	check(windup_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "the hammer goes up for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, windup_frames])
	check(not d.slam_rect().intersects(p.body_rect()), "the player stood out of the hammer's reach")
	check(wave_seen and p.hp < hp, "yet the shockwave rolled along the floor and hit (hp %d)" % p.hp)
	check(d.state == "stuck", "the hammer sticks in the floor")


func test_iron_dwarf_plate_turns_blows_until_the_hammer_sticks() -> void:
	var room := _room_with({Vector2i(12, 6): "I"})
	var d: IronDwarf = _find(room, IronDwarf)
	await frames(2)
	d.set_state("patrol")
	var hp0 := d.hp
	d.take_hit(10, Vector2(1, 0))
	check(d.hp == hp0 - 5, "his plate halves a blow (%d)" % (hp0 - d.hp))
	d.set_state("stuck")
	d.take_hit(10, Vector2(-1, 0))
	check(d.hp == hp0 - 15, "with the hammer stuck, a blow lands in full")
	d.set_state("patrol")
	d.take_hit(10, Vector2(0, 1))
	check(d.hp == hp0 - 25, "a pogo from above lands in full")


func test_minecart_rider_revs_charges_and_crashes_into_the_wall() -> void:
	var room := _room_with({Vector2i(22, 6): "K"})
	var m: MinecartRider = _find(room, MinecartRider)
	var p := make_player(room, Vector2i(13, 6))
	p.max_hp = 9999
	p.hp = 9999
	var hp := p.hp
	var rev_frames := 0
	var top_speed := 0.0
	for i in 240:
		await frames(1)
		if m.state == "rev":
			rev_frames += 1
		top_speed = maxf(top_speed, absf(m.velocity.x))
		if m.state == "crash":
			break
	check(rev_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "the brakes shriek for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, rev_frames])
	check(top_speed > 150.0, "then the cart charges (%.0f px/s)" % top_speed)
	check(p.hp < hp, "and runs down a player who stays on the floor")
	check(m.state == "crash" and m.global_position.x < 4 * Room.TILE, "it stops dead at the far wall and tips over")
	m.queue_free()


func test_minecart_tub_turns_blows_until_it_crashes() -> void:
	var room := _room_with({Vector2i(12, 6): "K"})
	var m: MinecartRider = _find(room, MinecartRider)
	await frames(2)
	m.set_state("roll")
	var hp0 := m.hp
	m.take_hit(10, Vector2(1, 0))
	check(m.hp == hp0 - 4, "the iron tub turns most of a blow (%d)" % (hp0 - m.hp))
	m.take_hit(10, Vector2(0, 1))
	check(m.hp == hp0 - 14, "a pogo on the rider lands in full")
	m.set_state("crash")
	m.take_hit(10, Vector2(-1, 0))
	check(m.hp == hp0 - 24, "tipped over, he takes every blow")


func test_shockwave_hugs_the_floor_and_breaks_at_a_wall() -> void:
	var room := _room_with({})
	var w := Shockwave.new()
	w.room = room
	w.direction = 1
	room.add_child(w)
	w.global_position = cell_feet(20, 6)
	var body := Rect2(w.global_position + Vector2(-6, -40), Vector2(12, 40))
	check(w.hit_rect().intersects(body), "it hits a body standing on the floor")
	check(not w.hit_rect().intersects(Rect2(body.position - Vector2(0, 14), body.size)), "a small hop clears it")
	await frames(60)
	check(not is_instance_valid(w), "it breaks up at the wall")


func test_gear_bat_roosts_then_flings_a_gear_that_comes_back() -> void:
	var room := _room_with({Vector2i(16, 1): "B"})
	var b: GearBat = _find(room, GearBat)
	var p := make_player(room, Vector2i(26, 6))
	p.max_hp = 9999
	p.hp = 9999
	await frames(30)
	check(b.state == "roost", "it stays on its roost while the player is far off")
	p.teleport(cell_feet(10, 6))
	var hp := p.hp
	var windup_frames := 0
	var thrown := false
	var caught := false
	for i in 360:
		await frames(1)
		if b.state == "windup":
			windup_frames += 1
		if b.blade != null:
			thrown = true
		elif thrown:
			caught = true
			break
	check(windup_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "the gear whirs for at least %.2f s before the throw (%d frames)" % [Enemy.MIN_TELEGRAPH, windup_frames])
	check(thrown and p.hp < hp, "the thrown gear cut the player (hp %d)" % p.hp)
	check(caught and b.has_gear(), "and flew back onto the bat's back")


func test_parried_gear_flies_home_and_staggers_its_bat() -> void:
	var room := _room_with({Vector2i(8, 3): "B"})
	var b: GearBat = _find(room, GearBat)
	await frames(2)
	b.set_state("bare")
	var g := GearBlade.new()
	g.owner_bat = b
	g.room = room
	g.direction = Vector2.RIGHT
	b.blade = g
	room.add_child(g)
	g.global_position = cell_center(20, 3)
	var hp0 := b.hp
	g.stagger()
	for i in 60:
		await frames(1)
		if b.is_staggered():
			break
	check(b.hp == hp0 - GearBlade.REFLECT_DAMAGE, "the parried gear hit its bat (%d)" % (hp0 - b.hp))
	check(b.is_staggered(), "and staggered it")
	check(b.has_gear(), "and the bat has its gear back")


func test_gear_turns_back_at_a_wall() -> void:
	var room := _room_with({Vector2i(8, 3): "B"})
	var b: GearBat = _find(room, GearBat)
	await frames(2)
	var g := GearBlade.new()
	g.owner_bat = b
	g.room = room
	g.direction = Vector2.RIGHT
	b.blade = g
	room.add_child(g)
	g.global_position = cell_center(27, 3)
	await frames(10)
	check(is_instance_valid(g) and g.phase == "back", "it rang off the wall and turned for home")
	check(g.global_position.x < 29 * Room.TILE, "without passing into the wall")


func test_rot_dwarf_shield_blocks_only_the_front() -> void:
	var room := _room_with({Vector2i(12, 6): "D"})
	var d: RotDwarf = _find(room, RotDwarf)
	await frames(2)
	d.facing = -1
	d.set_state("patrol")
	var hp0 := d.hp
	d.take_hit(8, Vector2(1, 0))  # player on his left, swinging right: front
	check(d.hp == hp0, "front hit blocked by the shield")
	d.take_hit(8, Vector2(-1, 0))  # from behind
	check(d.hp == hp0 - 8, "hit from behind lands")
	d.set_state("patrol")
	d.take_hit(8, Vector2(0, 1))  # pogo from above
	check(d.hp == hp0 - 16, "pogo from above lands")


func test_rot_dwarf_turns_to_face_player_behind() -> void:
	var room := _room_with({Vector2i(12, 6): "D"})
	var d: RotDwarf = _find(room, RotDwarf)
	d.facing = 1
	var p := make_player(room, Vector2i(10, 6))
	p.max_hp = 9999
	p.hp = 9999
	for i in 60:
		await frames(1)
		if d.facing == -1:
			break
	check(d.facing == -1, "turned around toward the player")


func test_enemies_respawn_when_configured() -> void:
	var room := _room_with({Vector2i(12, 6): "M"})
	var m: Blinkhop = _find(room, Blinkhop)
	m.respawn_time = 0.5
	await frames(2)
	m.take_hit(999, Vector2(1, 0))
	check(m.dead and m.dissolving(), "defeated, it breaks up")
	await frames(28)
	check(m.dead and not m.visible, "and is gone")
	await frames(12)
	check(not m.dead and m.hp == m.max_hp and m.visible, "respawned at home")


func test_lantern_ghost_shows_only_near_light_and_lunges_through_walls() -> void:
	var rows := grid_rows(40, 23)
	put_tiles(rows, 6, 19, "P")
	put_tiles(rows, 14, 4, "#", 1, 16)
	put_tiles(rows, 16, 16, "A")
	var w := make_world({"test/a": room_text(["name: Fog", "zone: haar"], rows)}, "test/a")
	var p := w.player
	p.max_hp = 9999
	p.hp = 9999
	await frames(3)
	var g: LanternGhost = _find(w.room, LanternGhost)
	# Out in the murk, away from every light, it is all but invisible.
	var start := g.global_position
	var murk := Vector2.INF
	for y in range(80, 300, 16):
		for x in range(300, 620, 16):
			if murk == Vector2.INF and w.fog.clear_at(Vector2(x, y)) == 0.0 and w.fog.clear_at(Vector2(x, y) + Vector2(12, 12)) == 0.0:
				murk = Vector2(x, y)
	g.global_position = murk
	await frames(1)
	check(murk != Vector2.INF and g.seen < 0.15, "out in the fog the ghost is all but invisible (%.2f at %s)" % [g.seen, murk])
	g.global_position = start
	var windup_frames := 0
	var bright := true
	var hurt := false
	for i in 600:
		await frames(1)
		if g.state == "windup":
			windup_frames += 1
			bright = bright and g.seen >= LanternGhost.WINDUP_ALPHA
		if p.hp < p.max_hp:
			hurt = true
			break
	check(g.global_position.x < 16 * 14, "it drifted through the wall to the player")
	check(windup_frames / 60.0 >= Enemy.MIN_TELEGRAPH and bright, "its eyes flare for at least %.2f s, even in the fog (%d frames)" % [Enemy.MIN_TELEGRAPH, windup_frames])
	check(hurt, "and its lunge lands")
	check(g.seen > 0.8 or g.state == "fade", "near the player it shows (%.2f, %s)" % [g.seen, g.state])


## Bible 7: the Bog Puffcap swells with glowing gills (a telegraph that lights
## the fog), bursts into a spore cloud that stings and can't be parried, and is soft
## while spent.
func test_bog_puffcap_swells_bursts_spores_and_is_soft_when_spent() -> void:
	var room := _room_with({Vector2i(20, 6): "V"})
	var p := make_player(room, Vector2i(18, 6))
	p.max_hp = 9999
	p.hp = 9999
	var m: BogPuffcap = _find(room, BogPuffcap)
	var windup_frames := 0
	var lit := true
	var cloud: SporeCloud = null
	for i in 120:
		await frames(1)
		if m.state == "windup":
			windup_frames += 1
			lit = lit and m.is_in_group("light") and m.light_radius > 0.0
		cloud = _find(room, SporeCloud)
		if cloud != null:
			break
	check(windup_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "the cap swells for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, windup_frames])
	check(windup_frames > 0 and lit, "its gills glow through the fog while it swells")
	check(cloud != null and not m.is_in_group("light"), "then it bursts into a spore cloud and the glow goes out")
	# The cloud reaches the player two tiles away and stings.
	var hp := p.hp
	var hurt_frames := 0
	for i in 60:
		await frames(1)
		if p.hp < hp:
			hurt_frames += 1
			hp = p.hp
	check(hurt_frames >= 1 and hurt_frames <= 2, "the spores sting on arrival and on the tick, not every frame (%d)" % hurt_frames)
	# Spent, it takes half again the damage.
	check(m.state == "spent" or m.state == "burst", "after the burst its cap sags open (%s)" % m.state)
	var before := m.hp
	m.take_hit(10, Vector2.RIGHT)
	check(before - m.hp == 15, "spent, a 10 hit deals 15 (%d)" % (before - m.hp))
	var firm := false
	for i in 160:
		await frames(1)
		firm = firm or m.state == "idle"
		if not is_instance_valid(cloud):
			break
	check(not is_instance_valid(cloud), "the cloud thins away")
	check(firm, "and the puffcap firms up again")
	m.set_state("idle")
	before = m.hp
	m.take_hit(10, Vector2.RIGHT)
	check(before - m.hp == 10, "firm, it takes normal damage (%d)" % (before - m.hp))


## Bible 7: the Leaf Mantis hides as a leaf cluster (harmless to touch), unfolds
## for a fair telegraph when you come near, lunges with its scythes, then is left
## overreached and soft.
func test_leaf_mantis_hides_unfolds_lunges_and_is_soft_when_overreached() -> void:
	var room := _room_with({Vector2i(24, 6): "m"})
	var p := make_player(room, Vector2i(4, 6))
	p.max_hp = 9999
	p.hp = 9999
	var m: LeafMantis = _find(room, LeafMantis)
	await frames(30)
	check(m.state == "hide" and m.contact_damage == 0, "far off, it stays folded and harmless (%s)" % m.state)
	p.global_position = Vector2(19 * 16 + 8, 7 * 16)
	p.reset_physics_interpolation()
	var unfold_frames := 0
	var hp := p.hp
	var hurt := false
	var lunged := false
	for i in 90:
		await frames(1)
		if m.state == "unfold":
			unfold_frames += 1
		lunged = lunged or m.state == "lunge"
		if p.hp < hp:
			hurt = true
		if m.state == "recover":
			break
	check(unfold_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "it unfolds for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, unfold_frames])
	check(lunged and hurt, "then lunges and its scythes land")
	check(hp - p.hp <= LeafMantis.SLASH_DAMAGE + 1, "once per lunge (%d)" % (hp - p.hp))
	check(m.state == "recover", "and it is left overreached (%s)" % m.state)
	var before := m.hp
	m.take_hit(10, Vector2.RIGHT)
	check(before - m.hp == 15, "overreached, a 10 hit deals 15 (%d)" % (before - m.hp))


## Striking a hidden mantis springs it open; its slash can be parried.
func test_leaf_mantis_springs_open_when_struck_and_can_be_parried() -> void:
	var room := _room_with({Vector2i(20, 6): "m"})
	var p := make_player(room, Vector2i(4, 6))
	p.max_hp = 9999
	p.hp = 9999
	var m: LeafMantis = _find(room, LeafMantis)
	await frames(10)
	m.take_hit(5, Vector2.RIGHT)
	check(m.state == "unfold", "struck while folded, it springs open (%s)" % m.state)
	await frames(40)
	# Now meet its next lunge with a parry.
	p.global_position = Vector2(m.global_position.x - 40.0, 7 * 16)
	p.reset_physics_interpolation()
	p.facing = 1
	for i in 120:
		await frames(1)
		if m.state == "unfold" and m.state_time >= LeafMantis.UNFOLD - 3.0 / 60.0:
			break
	var hp := p.hp
	p.input.block_pressed = true
	p.input.block_held = true
	await frames(10)
	check(p.hp == hp, "a parried slash does no damage (%d)" % (hp - p.hp))
	check(m.is_staggered(), "and staggers the mantis")


## Bible 7: the Thunder Beetle walks, crackles when you come near (the
## telegraph), then discharges a ring of lightning that a guard can't parry.
## Spent, it takes full damage.
func test_thunder_beetle_crackles_then_discharges_a_ring() -> void:
	var room := _room_with({Vector2i(20, 6): "t"})
	var p := make_player(room, Vector2i(3, 6))
	p.max_hp = 9999
	p.hp = 9999
	p.has_shield = true
	var b: ThunderBeetle = _find(room, ThunderBeetle)
	var x0 := b.global_position.x
	await frames(30)
	check(b.state == "walk" and absf(b.global_position.x - x0) > 4.0, "far off, it trundles along (%s)" % b.state)
	p.teleport(Vector2(b.global_position.x - 40.0, 7 * 16))
	p.facing = 1
	var charge_frames := 0
	var hp := p.hp
	for i in 90:
		p.input.block_held = true
		await frames(1)
		if b.state == "charge":
			charge_frames += 1
		if b.state == "spent":
			break
	check(charge_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "it crackles for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, charge_frames])
	check(p.hp < hp, "the discharge gets through a raised guard")
	check(hp - p.hp <= ThunderBeetle.DISCHARGE_DAMAGE, "once per discharge (%d)" % (hp - p.hp))
	check(b.state == "spent", "and it is left spent (%s)" % b.state)
	var before := b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(before - b.hp == 10, "spent, a side blow lands in full (%d)" % (before - b.hp))


## The shell turns blows from the side, but a pogo from above lands in full,
## and the lightning reaches above the shell as well as beside it.
func test_thunder_beetle_shell_and_the_ring_above_it() -> void:
	var room := _room_with({Vector2i(20, 6): "t"})
	var p := make_player(room, Vector2i(3, 6))
	var b: ThunderBeetle = _find(room, ThunderBeetle)
	await frames(5)
	var hp0 := b.hp
	b.take_hit(10, Vector2.RIGHT)
	check(hp0 - b.hp == 3, "the shell turns most of a side blow (%d)" % (hp0 - b.hp))
	hp0 = b.hp
	b.take_hit(10, Vector2(0, 1))
	check(hp0 - b.hp == 10, "a pogo from above lands in full (%d)" % (hp0 - b.hp))
	p.global_position = b.center() + Vector2(0, -24)
	check(b._player_in_ring(), "the ring reaches someone bouncing on the shell")
	p.global_position = b.center() + Vector2(90, 20)
	check(not b._player_in_ring(), "but not someone well clear")
	check(b.is_in_group("pogo"), "the shell is a pogo target")


const TALL := [
	"##############################",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"##############################",
]


## Bible 7: the Storm Harpy hangs above and beside you, rears back with a
## screech (the tell), flings a fan of three feathers, then sags, winded.
func test_storm_harpy_rears_then_flings_a_fan() -> void:
	var rows := TALL.duplicate()
	rows[4] = "#....................y.......#"
	var room := make_room(rows)
	var p := make_player(room, Vector2i(8, 12))
	p.max_hp = 9999
	p.hp = 9999
	var h: StormHarpy = _find(room, StormHarpy)
	var windup := 0
	var feathers := 0
	for i in 180:
		await frames(1)
		if h.state == "windup":
			windup += 1
		if h.state == "throw":
			feathers = runner.get_tree().get_nodes_in_group("enemy_projectile").size()
			break
	check(windup / 60.0 >= Enemy.MIN_TELEGRAPH, "she rears for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, windup])
	check(feathers == 3, "then flings three feathers (%d)" % feathers)
	check(h.center().y < p.global_position.y - 40.0, "from above you (%.0f vs %.0f)" % [h.center().y, p.global_position.y])
	var hp := p.hp
	var y0 := h.center().y
	for i in 60:
		await frames(1)
	check(p.hp < hp, "a feather finds you (%d)" % (hp - p.hp))
	check(h.state == "recover" or h.center().y > y0 + 10.0, "and she sags, winded (%s, %.0f -> %.0f)" % [h.state, y0, h.center().y])


## A parried feather turns and flies back into its harpy.
func test_a_parried_harpy_feather_flies_back() -> void:
	var rows := TALL.duplicate()
	rows[9] = "#....................y.......#"
	var room := make_room(rows)
	var p := make_player(room, Vector2i(8, 12))
	p.has_shield = true
	var h: StormHarpy = _find(room, StormHarpy)
	await frames(3)
	h.set_physics_process(false)
	p.facing = 1
	var f := HarpyFeather.new()
	f.thrower = h
	room.add_child(f)
	f.global_position = p.global_position + Vector2(40, -20)
	f.velocity = Vector2(-200, 0)
	var hp := p.hp
	var flew_back := false
	for i in 20:
		if is_instance_valid(f) and absf(f.global_position.x - p.global_position.x) < 26.0 and not f.reflected:
			p.input.block_pressed = true
		await frames(1)
		if is_instance_valid(f) and f.reflected:
			flew_back = true
			break
	check(flew_back and p.hp == hp, "the parry turns the feather unhurt")
	h.set_physics_process(true)
	var harpy_hp := h.hp
	for i in 60:
		await frames(1)
		if h.hp < harpy_hp:
			break
	check(harpy_hp - h.hp == HarpyFeather.REFLECT_DAMAGE, "and it strikes her for %d (%d)" % [HarpyFeather.REFLECT_DAMAGE, harpy_hp - h.hp])


## Lobs `shot` at the player from 40 px in front and taps Block as it closes.
## Returns the player's health lost.
func _parry_shot(p: Player, room: Room, shot: Node2D) -> int:
	room.add_child(shot)
	shot.global_position = p.global_position + Vector2(40, -20)
	shot.set("velocity", Vector2(-200, 0))
	var hp := p.hp
	for i in 20:
		if is_instance_valid(shot) and absf(shot.global_position.x - p.global_position.x) < 26.0:
			p.input.block_pressed = true
		await frames(1)
		if not is_instance_valid(shot):
			break
	return hp - p.hp


func _reflected(room: Room) -> ReflectedShot:
	return _find(room, ReflectedShot) as ReflectedShot


func test_the_magic_shield_flings_a_sap_glob_back() -> void:
	var rows := TALL.duplicate()
	rows[12] = "#...................T........#"
	var room := make_room(rows)
	var p := make_player(room, Vector2i(8, 12))
	p.has_shield = true
	p.reflects = true
	p.facing = 1
	var t: SapSpitter = _find(room, SapSpitter)
	await frames(3)
	t.set_physics_process(false)
	var g := SapGlob.new()
	g.room = room
	var lost := await _parry_shot(p, room, g)
	check(lost == 0 and not is_instance_valid(g), "the Warding Shield catches a sap glob, which no other shield can parry")
	var shot := _reflected(room)
	check(shot != null and shot.velocity.x > 0.0, "and flings it back the way you face")
	var hp := t.hp
	for i in 60:
		await frames(1)
		if t.hp < hp or t.dead:
			break
	check(t.dead or hp - t.hp == ReflectedShot.DAMAGE, "it strikes the spitter for %d (%d)" % [ReflectedShot.DAMAGE, hp - t.hp])
	check(room._sap_cells.is_empty(), "a caught glob leaves no puddle")


func test_other_shields_cannot_catch_a_sap_glob() -> void:
	var room := make_room(TALL)
	var p := make_player(room, Vector2i(8, 12))
	p.has_shield = true
	p.facing = 1
	await frames(3)
	var lost := await _parry_shot(p, room, SapGlob.new())
	check(lost > 0, "without the Warding Shield, a parry can't stop sap (%d lost)" % lost)
	check(_reflected(room) == null, "and nothing flies back")


func test_the_magic_shield_turns_seeds_into_shots() -> void:
	var room := make_room(TALL)
	var p := make_player(room, Vector2i(8, 12))
	p.has_shield = true
	p.facing = 1
	await frames(3)
	var lost := await _parry_shot(p, room, SeedShot.new())
	check(lost == 0 and _reflected(room) == null, "a plain shield parries a seed, and it just bursts")
	p.reflects = true
	lost = await _parry_shot(p, room, SeedShot.new())
	var shot := _reflected(room)
	check(lost == 0 and shot != null, "the Warding Shield sends it back as a shot of light")
	check(shot != null and shot.tint == Color("7cbf52"), "glowing with the seed's green")


func test_a_reflected_shot_seeks_the_nearest_foe_ahead() -> void:
	var rows := TALL.duplicate()
	rows[5] = "#..................H.........#"
	var room := make_room(rows)
	var p := make_player(room, Vector2i(8, 12))
	p.facing = 1
	await frames(3)
	var h := _find(room, Enemy) as Enemy
	h.set_physics_process(false)
	var src := Node2D.new()
	room.add_child(src)
	src.global_position = p.global_position + Vector2(20, -20)
	var shot := ReflectedShot.spawn(p, src)
	var aim := (h.center() - src.global_position).normalized()
	check(shot.velocity.normalized().dot(aim) > 0.99, "it flies at the foe in front of you, up in the air")
	p.facing = -1
	var back := ReflectedShot.spawn(p, src)
	check(back.velocity.x < 0.0 and absf(back.velocity.y) < 0.01, "with no foe that way, it flies straight ahead")


func test_crystal_dwarf_raises_his_fist_then_erupts_spikes() -> void:
	var room := _room_with({Vector2i(22, 6): "q"})
	var p := make_player(room, Vector2i(3, 6))
	p.max_hp = 9999
	p.hp = 9999
	var d: CrystalDwarf = _find(room, CrystalDwarf)
	var x0 := d.global_position.x
	await frames(30)
	check(d.state == "walk" and absf(d.global_position.x - x0) > 4.0, "far off, he trudges along (%s)" % d.state)
	d.facing = -1
	p.teleport(Vector2(d.global_position.x - 84.0, 7 * 16))
	var windup_frames := 0
	var hp := p.hp
	var spikes := 0
	for i in 120:
		await frames(1)
		if d.state == "windup":
			windup_frames += 1
		spikes = maxi(spikes, room.get_children().filter(func(c: Node) -> bool: return c is CrystalSpike and not c.is_queued_for_deletion()).size())
		if d.state == "recover":
			break
	check(windup_frames / 60.0 >= Enemy.MIN_TELEGRAPH, "he raises the crystal fist for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, windup_frames])
	check(spikes >= 4, "then a chain of crystal spikes erupts along the floor (%d)" % spikes)
	check(p.hp < hp, "and catches a player standing in its path")


## Bible 7 (pass 246): each spike of an eruption cracks up through the floor with
## a glassy stab as it rises, not while its mark glows, and two that rise on
## the same frame sound once.
func test_a_crystal_spike_stabs_up_with_a_sound() -> void:
	var room := _room_with({})
	make_player(room, Vector2i(30, 6))
	await frames(2)
	var s := CrystalSpike.new()
	s.delay = 0.1
	room.add_child(s)
	s.global_position = Vector2(10 * 16, 7 * 16)
	Sfx.recent.clear()
	var early := false
	while is_instance_valid(s) and s.rise() <= 0.0:
		early = early or CrystalSpike.STAB_SOUND in Sfx.recent
		await frames(1)
	check(not early, "the spike's mark glows in silence")
	check(CrystalSpike.STAB_SOUND in Sfx.recent, "and it stabs up with a crack of crystal (%s)" % [Sfx.recent])
	await frames(40)
	check(Sfx.recent.count(CrystalSpike.STAB_SOUND) == 1, "once (%d)" % Sfx.recent.count(CrystalSpike.STAB_SOUND))
	# A pair rising together, as the Evil Heart's wave runs both ways, sounds once.
	Sfx.recent.clear()
	for x in [6, 14]:
		var t := CrystalSpike.new()
		room.add_child(t)
		t.global_position = Vector2(x * 16, 7 * 16)
	await frames(30)
	check(Sfx.recent.count(CrystalSpike.STAB_SOUND) == 1, "two on one frame sound once (%d)" % Sfx.recent.count(CrystalSpike.STAB_SOUND))
	check(FileAccess.file_exists("res://assets/sfx/%s.wav" % CrystalSpike.STAB_SOUND), "the sound is on disk")


func test_crystal_spikes_hug_the_floor() -> void:
	var room := _room_with({})
	var p := make_player(room, Vector2i(10, 6))
	p.max_hp = 9999
	p.hp = 9999
	var s := CrystalSpike.new()
	room.add_child(s)
	s.global_position = Vector2(20 * 16 + 8, 7 * 16)
	p.teleport(Vector2(s.global_position.x, s.global_position.y - 40.0))
	p.velocity = Vector2.ZERO
	var hp := p.hp
	await frames(int((CrystalSpike.WARN + 0.15) * 60))
	check(s.rise() > 0.5, "the spike stands up after its warning")
	var over := Vector2(s.global_position.x, s.global_position.y - CrystalSpike.HEIGHT - 4.0)
	check(not s.hit_rect().has_point(over), "and a jump over it clears it")
	p.teleport(s.global_position)
	await frames(3)
	check(p.hp < hp, "but it stabs a player standing on it")


func test_crystal_dwarf_back_turns_blows_until_his_fist_is_rooted() -> void:
	var room := _room_with({Vector2i(20, 6): "q"})
	make_player(room, Vector2i(3, 6))
	var d: CrystalDwarf = _find(room, CrystalDwarf)
	await frames(3)
	d.facing = -1
	var hp0 := d.hp
	d.take_hit(10, Vector2(-1, 0))
	check(d.hp == hp0, "a blow from behind breaks on the crystal on his back")
	d.take_hit(10, Vector2(1, 0))
	check(hp0 - d.hp == 10, "a blow to his face lands (%d)" % (hp0 - d.hp))
	hp0 = d.hp
	d.take_hit(10, Vector2(0, 1))
	check(hp0 - d.hp == 10, "so does a pogo from above (%d)" % (hp0 - d.hp))
	d.set_state("rooted")
	d._struck = true
	hp0 = d.hp
	d.take_hit(10, Vector2(-1, 0))
	check(hp0 - d.hp == 10, "rooted, even his back gives (%d)" % (hp0 - d.hp))


## Bible 7: the Shade Knight's tower shield turns blows from the front; from
## behind, from above, winded or reeling, they land.
func test_shade_knight_shield_turns_blows_from_the_front() -> void:
	var room := _room_with({Vector2i(20, 6): "e"})
	make_player(room, Vector2i(3, 6))
	var k: ShadeKnight = _find(room, ShadeKnight)
	await frames(3)
	k.facing = -1
	k.set_state("walk")
	var hp0 := k.hp
	k.take_hit(10, Vector2(1, 0))
	check(k.hp == hp0, "a blow to his shield does nothing")
	k.take_hit(10, Vector2(-1, 0))
	check(hp0 - k.hp == 10, "a blow to his back lands (%d)" % (hp0 - k.hp))
	hp0 = k.hp
	k.take_hit(10, Vector2(0, 1))
	check(hp0 - k.hp == 10, "so does a pogo from above (%d)" % (hp0 - k.hp))
	k.set_state("winded")
	hp0 = k.hp
	k.take_hit(10, Vector2(1, 0))
	check(hp0 - k.hp == 10, "winded, his shield hangs low (%d)" % (hp0 - k.hp))
	k.stagger()
	hp0 = k.hp
	k.take_hit(10, Vector2(1, 0))
	check(hp0 - k.hp == 10, "reeling from a parry, he is open (%d)" % (hp0 - k.hp))


## The art loop (docs/art/enemy-style-guide.md 4): every state the Shade Knight
## takes plays an animation of his sheet that fits it: hurt while a blow stuns him,
## stagger while he reels, and his collapse once he dies.
func test_shade_knight_plays_an_animation_for_every_state() -> void:
	var room := _room_with({Vector2i(20, 6): "e"})
	make_player(room, Vector2i(3, 6))
	var k: ShadeKnight = _find(room, ShadeKnight)
	await frames(3)
	check(Sheet.exists("shade_knight"), "his sheet is in the game")
	for s: String in ["idle", "walk", "thrust_tell", "cut_tell", "riposte_tell", "thrust", "cut", "winded"]:
		k.set_state(s)
		var a: String = k.anim_now()[0]
		check(Sheet.has_anim("shade_knight", a), "%s plays %s, which the sheet has" % [s, a])
	k.set_state("thrust_tell")
	check(k.anim_now()[0] == "thrust_tell", "the thrust's tell is its own pose, not the idle")
	k.set_state("riposte_tell")
	check(k.anim_now()[0] == "thrust_tell", "the riposte draws back as the thrust does")
	k.set_state("walk")
	k.take_hit(1, Vector2(-1, 0))
	check(k.anim_now()[0] == "hurt" and Sheet.has_anim("shade_knight", "hurt"), "a blow that lands makes him flinch")
	k._hitstun = 0.0
	k.stagger()
	check(k.anim_now()[0] == "stagger" and Sheet.has_anim("shade_knight", "stagger"), "a parry sends him reeling")
	k.die()
	check(k.anim_now()[0] == "death" and Sheet.has_anim("shade_knight", "death"), "he collapses as he dissolves")


## The art loop, batch 4 (docs/art/enemy-style-guide.md 4): a Carillon foe plays an
## animation of its own sheet for every state it takes, a tell that is not its idle, a
## flinch while a blow stuns it, and its collapse once it dies.
func _plays_its_sheet(legend: String, sheet: String, type: Variant, states: Array, tell: String) -> void:
	var room := _room_with({Vector2i(20, 6): legend})
	make_player(room, Vector2i(3, 6))
	var e: Enemy = _find(room, type)
	await frames(3)
	e.set_physics_process(false)
	check(Sheet.exists(sheet), "the %s's sheet is in the game" % sheet)
	for s: String in states:
		e.set_state(s)
		var a: String = e.call("anim_now")[0]
		check(Sheet.has_anim(sheet, a), "%s: %s plays %s, which the sheet has" % [sheet, s, a])
	e.set_state(tell)
	var told: String = e.call("anim_now")[0]
	check(told not in ["idle", "walk", "hover"], "%s: the %s is its own pose (%s)" % [sheet, tell, told])
	e.set_state(states[0])
	e._hitstun = Enemy.HITSTUN
	check(e.call("anim_now")[0] == "hurt" and Sheet.has_anim(sheet, "hurt"), "%s: a blow that lands makes it flinch" % sheet)
	e._hitstun = 0.0
	e.stagger()
	var reel: String = e.call("anim_now")[0]
	check(Sheet.has_anim(sheet, reel), "%s: reeling plays %s" % [sheet, reel])
	e.die()
	check(e.call("anim_now")[0] == "death" and Sheet.has_anim(sheet, "death"), "%s: it collapses as it dissolves" % sheet)


func test_thunder_beetle_plays_an_animation_for_every_state() -> void:
	await _plays_its_sheet("t", "thunder_beetle", ThunderBeetle, ["walk", "charge", "discharge", "spent"], "charge")


func test_storm_harpy_plays_an_animation_for_every_state() -> void:
	await _plays_its_sheet("y", "storm_harpy", StormHarpy, ["hover", "windup", "throw", "recover"], "windup")


func test_spire_sentinel_plays_an_animation_for_every_state() -> void:
	await _plays_its_sheet("]", "spire_sentinel", SpireSentinel, ["stone", "stalk", "raise", "slam", "spent"], "raise")
	# Guide 5: the slam's art reaches HEAD_X; the stone shock drawn along the floor carries
	# it to the far edge of slam_rect, so no part of the blow lands where nothing is drawn.
	var room := _room_with({Vector2i(20, 6): "]"})
	make_player(room, Vector2i(3, 6))
	var s: SpireSentinel = _find(room, SpireSentinel)
	await frames(2)
	check(SpireSentinel.HEAD_X < s.slam_rect().size.x, "the shock starts at the halberd's head, inside the slam")
	check(s.shock_reach() >= s.slam_rect().size.x, "the shock reaches the end of slam_rect (%.0f of %.0f)" % [s.shock_reach(), s.slam_rect().size.x])
	check(SpireSentinel.SHOCK_FADE >= SpireSentinel.SLAM, "the shock lasts as long as the blow is live")


## Art loop pass 3 (docs/art/enemy-style-guide.md 4): the Haar's four foes, remade in
## PixelLab, play an animation from their sheet in every state, with a tell that is
## its own pose, a flinch, and a collapse under the dissolve.
func test_the_haars_foes_play_an_animation_for_every_state() -> void:
	var foes := {
		"lantern_ghost": [LanternGhost, "A", ["idle", "drift", "return", "windup", "lunge", "fade"], "windup", "lunge_tell"],
		"bog_puffcap": [BogPuffcap, "V", ["idle", "windup", "burst", "spent"], "windup", "windup"],
		"drowned_dwarf": [DrownedDwarf, "p", ["sunk", "rise", "walk", "windup", "slam", "mired", "sink"], "windup", "heave"],
		"marsh_hag": [MarshHag, "?", ["idle", "walk", "withdraw", "windup", "cast", "fumble"], "windup", "hex"],
	}
	for sheet: String in foes:
		var f: Array = foes[sheet]
		var room := _room_with({Vector2i(20, 6): f[1]})
		make_player(room, Vector2i(3, 6))
		var e: Enemy = _find(room, f[0])
		await frames(2)
		check(Sheet.exists(sheet) and Sheet.get_sheet(sheet).get("own_palette", false), "%s has its own HD sheet" % sheet)
		for st: String in f[2]:
			e.set_state(st)
			var a: String = e.anim_now()[0]
			check(Sheet.has_anim(sheet, a), "%s in %s plays %s, which the sheet has" % [sheet, st, a])
		e.set_state(f[3])
		check(e.anim_now()[0] == f[4] and f[4] != "idle", "%s's tell is its own pose (%s)" % [sheet, f[4]])
		if sheet != "drowned_dwarf":
			e.set_state("idle")
		else:
			e.set_state("walk")
		e._hitstun = Enemy.HITSTUN
		check(e.anim_now()[0] == "hurt" and Sheet.has_anim(sheet, "hurt"), "a blow makes %s flinch" % sheet)
		e._hitstun = 0.0
		e.die()
		check(e.anim_now()[0] == "death" and Sheet.has_anim(sheet, "death"), "%s collapses as it dissolves" % sheet)
		room.queue_free()
		await frames(1)


## The art loop, pass 6 (docs/art/enemy-style-guide.md 4): each foe of Vorrhallow and the
## Sunken Spring plays an animation of its PixelLab sheet in every state it takes, its tell a
## pose of its own, a flinch while a blow stuns it, its stagger when parried, and its death.
func _plays_its_own_sheet(k: Enemy, sheet: String, states: Array, tell: String, tell_anim: String) -> void:
	check(Sheet.exists(sheet), "%s's sheet is in the game" % sheet)
	for s: String in states:
		k.set_state(s)
		var a: String = k.call("anim_now")[0]
		check(Sheet.has_anim(sheet, a), "%s: %s plays %s, which the sheet has" % [sheet, s, a])
	k.set_state(tell)
	check(k.call("anim_now")[0] == tell_anim, "%s: the tell is its own pose, not the idle" % sheet)
	k.set_state(states[0])
	k.take_hit(1, Vector2(-k.facing, 0))
	check(k.call("anim_now")[0] == "hurt" and Sheet.has_anim(sheet, "hurt"), "%s: a blow that lands makes it flinch" % sheet)
	k._hitstun = 0.0
	k.stagger()
	check(k.call("anim_now")[0] == "stagger" and Sheet.has_anim(sheet, "stagger"), "%s: a parry sends it reeling" % sheet)
	k._stagger = 0.0
	k.die()
	check(k.call("anim_now")[0] == "death" and Sheet.has_anim(sheet, "death"), "%s: it collapses as it dissolves" % sheet)


func test_vorrhallow_foes_play_an_animation_for_every_state() -> void:
	var room := _room_with({Vector2i(12, 6): "j", Vector2i(18, 6): "q", Vector2i(25, 6): "s"})
	make_player(room, Vector2i(3, 6))
	await frames(3)
	_plays_its_own_sheet(_find(room, ClockworkHound), "clockwork_hound", ["idle", "trot", "wind", "pounce", "skid"], "wind", "wind")
	_plays_its_own_sheet(_find(room, CrystalDwarf), "crystal_dwarf", ["idle", "walk", "windup", "rooted", "recover"], "windup", "windup")
	_plays_its_own_sheet(_find(room, GlassSlug), "meteor_slug", ["idle", "crawl", "swell", "recover"], "swell", "swell")


func test_spring_eel_plays_an_animation_for_every_state() -> void:
	var room := _eel_pool(Vector2i(14, 8))
	make_player(room, Vector2i(3, 10))
	await frames(3)
	_plays_its_own_sheet(_find(room, SpringEel), "spring_eel", ["swim", "coil", "dart", "slack"], "coil", "coil")


func test_shade_knight_ripostes_when_you_batter_his_shield() -> void:
	var room := _room_with({Vector2i(20, 6): "e"})
	make_player(room, Vector2i(3, 6))
	var k: ShadeKnight = _find(room, ShadeKnight)
	await frames(3)
	k.facing = -1
	k.set_state("walk")
	k.take_hit(10, Vector2(1, 0))
	check(k.state == "walk", "one blow on the shield, he holds")
	k.take_hit(10, Vector2(1, 0))
	check(k.state == "riposte_tell", "a second and he draws for a riposte (%s)" % k.state)
	check(ShadeKnight.RIPOSTE_TELL >= Enemy.MIN_TELEGRAPH, "even his riposte is telegraphed")


func test_shade_knight_thrusts_then_cuts_and_a_parry_breaks_him() -> void:
	var room := _room_with({Vector2i(22, 6): "e"})
	var p := make_player(room, Vector2i(3, 6))
	p.max_hp = 9999
	p.hp = 9999
	var k: ShadeKnight = _find(room, ShadeKnight)
	await frames(3)
	p.teleport(Vector2(k.global_position.x - 40.0, 7 * 16))
	var tell := 0
	var cut_tell := 0
	var hp := p.hp
	for i in 150:
		await frames(1)
		if k.state == "thrust_tell":
			tell += 1
		if k.state == "cut_tell":
			cut_tell += 1
		if k.state == "winded":
			break
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH and cut_tell / 60.0 >= Enemy.MIN_TELEGRAPH,
		"both blows are telegraphed (%d and %d frames)" % [tell, cut_tell])
	check(p.hp < hp, "and the pair catches a player standing still")
	# The next time, meet the thrust with a parry.
	for i in 200:
		await frames(1)
		if k.state == "thrust_tell" and k.state_time >= ShadeKnight.THRUST_TELL - 3.0 / 60.0:
			break
	p.teleport(Vector2(k.global_position.x - 36.0, 7 * 16))
	p.facing = 1
	hp = p.hp
	p.input.block_pressed = true
	p.input.block_held = true
	await frames(10)
	check(p.hp == hp, "a parried thrust does no damage (%d)" % (hp - p.hp))
	check(k.is_staggered() and not k.guarding(), "and he reels, shield wide")


## Bible 7: the Glass Slug swells (the tell), then heaves three burning globs.
func test_meteor_slug_swells_then_heaves_three_globs() -> void:
	var room := _room_with({Vector2i(20, 6): "s"})
	var p := make_player(room, Vector2i(10, 6))
	p.max_hp = 9999
	p.hp = 9999
	var s: GlassSlug = _find(room, GlassSlug)
	var swell := 0
	var globs := 0
	for i in 150:
		await frames(1)
		if s.state == "swell":
			swell += 1
		globs = room.get_children().filter(func(c: Node) -> bool: return c is MeteorGlob).size()
		if globs > 0:
			break
	check(swell / 60.0 >= Enemy.MIN_TELEGRAPH, "the swell is telegraphed (%d frames)" % swell)
	check(globs == GlassSlug.GLOBS, "then three globs fly (%d)" % globs)
	var hp := p.hp
	var embers := false
	for i in 90:
		await frames(1)
		if room.get_children().any(func(c: Node) -> bool: return c is MeteorEmbers):
			embers = true
	check(embers, "and where they land they leave embers")
	check(p.hp < hp, "and a player standing still is burned (%d)" % (hp - p.hp))


func test_meteor_slug_shell_turns_blows_from_above() -> void:
	var room := _room_with({Vector2i(20, 6): "s"})
	make_player(room, Vector2i(3, 6))
	var s: GlassSlug = _find(room, GlassSlug)
	await frames(3)
	var hp0 := s.hp
	s.take_hit(10, Vector2(0, 1))
	check(s.hp == hp0, "a pogo glances off the Everbloom shell")
	s.take_hit(10, Vector2(1, 0))
	check(hp0 - s.hp == 10, "a blow to its soft side lands (%d)" % (hp0 - s.hp))
	s.set_state("recover")
	hp0 = s.hp
	s.take_hit(10, Vector2(0, 1))
	check(hp0 - s.hp == 10, "spent after a heave, its shell cracks open to a pogo (%d)" % (hp0 - s.hp))


func test_meteor_globs_and_embers_hold_still_in_stopped_time() -> void:
	var room := _room_with({})
	var p := make_player(room, Vector2i(3, 6))
	var g := MeteorGlob.new()
	g.room = room
	g.velocity = Vector2(100, -100)
	room.add_child(g)
	g.position = Vector2(200, 40)
	var e := MeteorEmbers.new()
	room.add_child(e)
	e.position = Vector2(p.global_position.x, 7 * 16)
	TimeStop.start()
	var hp := p.hp
	await frames(20)
	check(g.position == Vector2(200, 40), "a glob hangs in the air (%s)" % g.position)
	check(p.hp == hp, "and embers under your feet don't burn while time holds")
	TimeStop.reset()
	await frames(5)
	check(g.position.x > 200.0, "the glob flies on when time runs")
	check(p.hp < hp, "and the embers burn (%d)" % (hp - p.hp))


## Bible 7: the Clockwork Hound winds up (the tell), then pounces and bites.
func test_clockwork_hound_winds_up_then_pounces() -> void:
	var room := _room_with({Vector2i(16, 6): "j"})
	var p := make_player(room, Vector2i(8, 6))
	p.max_hp = 9999
	p.hp = 9999
	var h: ClockworkHound = _find(room, ClockworkHound)
	var wind := 0
	var hp := p.hp
	var pounced := false
	for i in 150:
		await frames(1)
		if h.state == "wind":
			wind += 1
		if h.state == "pounce":
			pounced = true
		if pounced and h.state == "skid":
			break
	check(wind / 60.0 >= Enemy.MIN_TELEGRAPH, "the wind-up is telegraphed (%d frames)" % wind)
	check(pounced, "then it pounces")
	check(p.hp < hp, "and bites a player standing still (%d)" % (hp - p.hp))


func test_clockwork_hound_plating_and_a_parry_flips_it() -> void:
	var room := _room_with({Vector2i(20, 6): "j"})
	make_player(room, Vector2i(3, 6))
	var h: ClockworkHound = _find(room, ClockworkHound)
	await frames(3)
	var hp0 := h.hp
	h.take_hit(10, Vector2(1, 0))
	check(hp0 - h.hp == 5, "its brass plating turns half a blow (%d)" % (hp0 - h.hp))
	h.stagger()
	check(h.flipped(), "a parry throws it on its back")
	hp0 = h.hp
	h.take_hit(10, Vector2(1, 0))
	check(hp0 - h.hp == 10, "where every blow lands (%d)" % (hp0 - h.hp))
	await frames(int(ClockworkHound.FLIPPED * 60) + 5)
	check(not h.flipped(), "until it rights itself")


func test_clockwork_hound_stops_dead_in_stopped_time() -> void:
	var room := _room_with({Vector2i(20, 6): "j"})
	make_player(room, Vector2i(3, 6))
	var h: ClockworkHound = _find(room, ClockworkHound)
	await frames(3)
	h.set_state("pounce")
	h.velocity = Vector2(-200, -200)
	await frames(4)
	TimeStop.start()
	await frames(1)
	var at := h.global_position
	await frames(30)
	check(h.global_position == at, "it hangs mid-leap while time holds (%s vs %s)" % [h.global_position, at])
	check(h.state == "pounce", "its spring holds too")
	TimeStop.reset()
	await frames(5)
	check(h.global_position != at, "and leaps on when time runs")


## Bible 8.9: everything in the Evercrown is a corrupted remix: tougher, richer, crystal grown through it.
func test_evercrown_foes_are_corrupted_with_meteor_crystal() -> void:
	var rows := _room_rows({Vector2i(5, 6): "s", Vector2i(12, 6): "q", Vector2i(20, 6): "e"})
	var plain := Room.from_text("\n".join(PackedStringArray(rows)))
	arena.add_child(plain)
	var slug: GlassSlug = _find(plain, GlassSlug)
	check(not slug.corrupted, "outside the Evercrown a slug is only a slug")
	var base_hp := slug.max_hp
	plain.queue_free()
	await frames(1)
	var room := Room.from_text("zone: evercrown\n---\n" + "\n".join(PackedStringArray(rows)))
	arena.add_child(room)
	var foes := room.get_children().filter(func(c: Node) -> bool: return c is Enemy)
	check(foes.size() == 3 and foes.all(func(e: Enemy) -> bool: return e.corrupted), "in the Evercrown every foe is corrupted")
	var cslug: GlassSlug = _find(room, GlassSlug)
	check(cslug.max_hp == ceili(base_hp * Enemy.CORRUPT_HP) and cslug.hp == cslug.max_hp, "and tougher (%d vs %d)" % [cslug.max_hp, base_hp])
	check(cslug.get_children().any(func(c: Node) -> bool: return c is CorruptionGrowth), "with the Everbloom's crystal grown through it")
	var off := Room.from_text("zone: evercrown\ncorrupted: false\n---\n" + "\n".join(PackedStringArray(rows)))
	arena.add_child(off)
	check(not (_find(off, GlassSlug) as Enemy).corrupted, "a room can say otherwise")
	await frames(30)
	check(not cslug.dead, "and the corrupted foes live and move (%s)" % cslug.state)


## Pass 494 (workbench note): the cyan stillglass shards on a corrupted foe cast the
## glass's own light onto its body and sink into a dark socket, so they read as glass
## grown through the foe, not a flat decal stamped over its silhouette.
func test_corrupted_shards_lift_off_the_foe_silhouette() -> void:
	var growth := CorruptionGrowth.new()
	var sh := growth.shards(Vector2(24, 20), 1.0, Vector2.ZERO)
	check(sh.size() == 3, "a corrupted foe grows three back-shards (%d)" % sh.size())
	for s in sh:
		check(s["glow_radius"] > s["half_width"] + 0.5,
			"the cast light reaches past the shard's own width, lifting it off the foe (r=%.1f w=%.1f)" % [s["glow_radius"], s["half_width"]])
		check(s["glow_center"].y < s["base"].y and s["glow_center"].y > s["tip"].y,
			"the light falls along the shard, between its base and tip")
	check(CorruptionGrowth.GLOW_MARGIN > 0.0, "the separation margin is real")
	check(CorruptionGrowth.GLOW_ALPHA > 0.0 and CorruptionGrowth.GLOW_ALPHA < 1.0,
		"the cast light is translucent, not an opaque cyan patch")
	check(CorruptionGrowth.SOCKET_ALPHA > 0.0, "a dark socket marks where the shard breaks the skin")
	growth.free()


## Bible 8.9: a corrupted foe leaves a seed of crystal that tells, then bursts.
func test_a_corrupted_foe_leaves_a_seed_that_bursts() -> void:
	var room := Room.from_text("corrupted: true\n---\n" + "\n".join(PackedStringArray(_room_rows({Vector2i(14, 6): "M"}))))
	arena.add_child(room)
	# Close enough for the burst to reach, too far for the Blinkhop to touch first.
	var p := make_player(room, Vector2i(16, 6))
	p.max_hp = 9999
	p.hp = 9999
	var m: Blinkhop = _find(room, Blinkhop)
	await frames(2)
	m.take_hit(999, Vector2(1, 0))
	await frames(2)
	var seed: MeteorSeed = _find(room, MeteorSeed)
	if not check(seed != null, "the crystal is left hanging where it died"):
		return
	var hp := p.hp
	var tell := 0
	while is_instance_valid(seed) and seed.state == "tell" and tell < 120:
		tell += 1
		await frames(1)
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH, "it swells first (%d frames)" % tell)
	check(p.hp == hp, "and does nothing while it swells")
	await frames(15)
	check(p.hp < hp, "then bursts and hurts whoever stands by it (%d)" % (hp - p.hp))
	check(not is_instance_valid(seed), "and is gone")


## Striking the seed before it bursts cracks it harmlessly, so pressing on is safe.
func test_a_struck_seed_cracks_without_bursting() -> void:
	var room := _room_with({})
	var p := make_player(room, Vector2i(14, 6))
	var seed := MeteorSeed.new()
	room.add_child(seed)
	seed.global_position = p.global_position + Vector2(0, -20)
	await frames(10)
	var hp := p.hp
	seed.take_hit(5, Vector2(0, 1))
	check(seed.cracked and seed.dead, "a blow cracks it")
	await frames(60)
	check(p.hp == hp, "and it never bursts (%d)" % (hp - p.hp))
	check(room.get_children().filter(func(c: Node) -> bool: return c is Coin).is_empty(), "nor leaves gold")


func test_a_seed_holds_in_stopped_time() -> void:
	var room := _room_with({})
	var p := make_player(room, Vector2i(14, 6))
	var seed := MeteorSeed.new()
	room.add_child(seed)
	seed.global_position = p.global_position + Vector2(0, -20)
	TimeStop.start()
	var hp := p.hp
	await frames(90)
	check(is_instance_valid(seed) and seed.state == "tell", "the seed waits while time holds")
	check(p.hp == hp, "and hurts no one")
	TimeStop.reset()
	await frames(60)
	check(p.hp < hp, "then bursts when time runs (%d)" % (hp - p.hp))


func _room_rows(spots: Dictionary) -> Array:
	var rows := WIDE.duplicate()
	for cell: Vector2i in spots:
		var row: String = rows[cell.y]
		rows[cell.y] = row.substr(0, cell.x) + spots[cell] + row.substr(cell.x + 1)
	return rows


## A pool (rows 4-11, cols 1-20) with a dry bank to its right, level with the surface.
func _eel_pool(eel_at: Vector2i) -> Room:
	var rows := ["##############################"]
	for y in range(1, 4):
		rows.append("#............................#")
	for y in range(4, 12):
		var row := "#" + "a".repeat(20) + "#".repeat(9)
		if y == eel_at.y:
			row = row.substr(0, eel_at.x) + "l" + row.substr(eel_at.x + 1)
		rows.append(row)
	rows.append("##############################")
	return make_room(rows)


func test_spring_eel_coils_then_darts_and_never_leaves_the_water() -> void:
	var room := _eel_pool(Vector2i(14, 8))
	var p := make_player(room, Vector2i(8, 10))
	p.max_hp = 9999
	p.hp = 9999
	var e: SpringEel = _find(room, SpringEel)
	var water: SwimWater = _find(room, SwimWater)
	var coil := 0
	var darted := false
	var dry := 0
	var hp := p.hp
	for i in 180:
		# Hold the player still on the pool floor.
		p.input.down = true
		await frames(1)
		if e.state == "coil":
			coil += 1
		if e.state == "dart":
			darted = true
		if not water.has_point(e.global_position - water.global_position):
			dry += 1
	check(coil / 60.0 >= Enemy.MIN_TELEGRAPH, "it coils before it darts (%d frames)" % coil)
	check(darted and p.hp < hp, "then darts and bites (%d)" % (hp - p.hp))
	check(dry == 0, "and never leaves the water (%d frames out)" % dry)


func test_spring_eel_cannot_reach_the_bank() -> void:
	var room := _eel_pool(Vector2i(18, 5))
	var p := make_player(room, Vector2i(23, 3))
	p.max_hp = 9999
	p.hp = 9999
	var e: SpringEel = _find(room, SpringEel)
	var hp := p.hp
	var darts := 0
	for i in 240:
		await frames(1)
		if e.state == "dart" and e.state_time < 0.02:
			darts += 1
	check(darts > 0, "it darts at a player on the bank")
	check(p.hp == hp, "but stops dead at the water's edge (%d)" % (hp - p.hp))
	e.set_state("slack")
	var hp0 := e.hp
	e.take_hit(10, Vector2(1, 0))
	check(hp0 - e.hp == 15, "spent, it takes every blow at half again (%d)" % (hp0 - e.hp))


## Every attack is heard as well as seen (bible 7 and 13.3). Scans the enemy and boss
## scripts: entering a telegraph state (windup, *_tell, coil, rev...) must play a
## sound right there, and every other attack state must play one where it is
## entered or while it runs. Calm states (walking, recovering, intros) are exempt.
func test_every_attack_tell_and_strike_has_a_sound() -> void:
	var tell_re := RegEx.create_from_string("windup|tell|^wind$|^coil$|^rev$|^unfold$|^gather$")
	var set_re := RegEx.create_from_string("set_state\\(\"([a-z_0-9]+)\"\\)")
	var call_re := RegEx.create_from_string("\\b(_[a-z_0-9]+)\\(")
	var func_re := RegEx.create_from_string("^func ([a-z_0-9]+)\\(")
	var calm := ("idle walk patrol recover dying dead intro stalk hover crawl drift return rest trot "
		+ "circle climb grounded wade swim slack hide spent bare wake f_recover fallen to_throne fight "
		+ "float watch retract withdraw stuck staggered stunned flinch winded skid stagger opening "
		+ "dropped exposed hang possessed roll fade mirror echo dormant sink sunk dangle dangle_up "
		+ "plunge_hold plunge_up downed rise").split(" ")
	var gaps: Array[String] = []
	var tells := 0
	var strikes := 0
	for dir: String in ["res://scripts/enemies", "res://scripts/bosses"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var lines := FileAccess.get_file_as_string(dir + "/" + f).split("\n")
			# Functions that play a sound, directly or through one helper.
			var bodies := {}
			var cur := ""
			for l in lines:
				var m := func_re.search(l)
				if m != null:
					cur = m.get_string(1)
					bodies[cur] = ""
				elif cur != "":
					bodies[cur] += l + "\n"
			var sounding := {}
			for _pass in 2:
				for fn: String in bodies:
					var b: String = bodies[fn]
					if b.contains("Sfx.play(") or b.contains("_sound("):
						sounding[fn] = true
						continue
					for c in call_re.search_all(b):
						if sounding.has(c.get_string(1)):
							sounding[fn] = true
			var sounds_in := func(text: String, strict: bool) -> bool:
				if text.contains("Sfx.play(") or text.contains("_sound("):
					return true
				if strict:
					return false
				for c in call_re.search_all(text):
					if sounding.has(c.get_string(1)):
						return true
				return false
			var heard := {}
			for i in lines.size():
				for m in set_re.search_all(lines[i]):
					var s := m.get_string(1)
					if s in calm:
						continue
					var window := "\n".join(lines.slice(maxi(0, i - 3), i + 4))
					var tell := tell_re.search(s) != null
					var ok: bool = sounds_in.call(window, tell)
					if tell and not ok:
						gaps.append("%s:%d %s plays nothing as it starts" % [f, i + 1, s])
					heard[s] = heard.get(s, false) or ok
			for s: String in heard:
				if tell_re.search(s) != null:
					tells += 1
					continue
				strikes += 1
				if heard[s]:
					continue
				# Not heard where it starts: look for a sound while the state runs.
				var arm := RegEx.create_from_string("^(\\t+)(\"[a-z_0-9]+\", )*\"%s\"(, \"[a-z_0-9]+\")*:\\s*$" % s)
				var found := false
				for i in lines.size():
					var a := arm.search(lines[i])
					if a == null:
						continue
					var depth := a.get_string(1).length()
					var body := ""
					for j in range(i + 1, lines.size()):
						var l := lines[j]
						if l.strip_edges() != "" and l.length() - l.lstrip("\t").length() <= depth:
							break
						body += l + "\n"
					found = found or sounds_in.call(body, false)
				if not found:
					gaps.append("%s: %s makes no sound" % [f, s])
	check(tells > 25 and strikes > 60, "the scan finds the telegraphs (%d) and attacks (%d)" % [tells, strikes])
	check(gaps.is_empty(), "every attack has a sound: %s" % [gaps])


## Bible 7: the Drowned Dwarf lies sunk in the mire, out of reach, and hauls
## himself out when you come near; rising, he is soft.
func test_drowned_dwarf_lies_sunk_then_rises_when_you_come_near() -> void:
	var room := _room_with({Vector2i(22, 6): "p"})
	var p := make_player(room, Vector2i(3, 6))
	var d: DrownedDwarf = _find(room, DrownedDwarf)
	await frames(30)
	check(d.is_sunk(), "far off, he stays sunk (%s)" % d.state)
	check(d.collision_layer == 0 and d.contact_damage == 0, "sunk, nothing can hit him and he hurts nothing")
	p.teleport(Vector2(d.global_position.x - 64.0, 7 * 16))
	var rise := 0
	var soft := -1
	for i in 90:
		await frames(1)
		if d.state == "rise":
			rise += 1
			if soft < 0 and rise == 10:
				var before := d.hp
				d.take_hit(10, Vector2.RIGHT)
				soft = before - d.hp
		elif rise > 0:
			break
	check(absf(rise / 60.0 - DrownedDwarf.RISE) < 0.05, "four tiles off, he rises over 0.7 s (%d frames)" % rise)
	check(soft == 15, "half out of the mud, a 10 hit deals 15 (%d)" % soft)
	check(d.collision_layer == Player.LAYER_ENEMY and d.contact_damage > 0, "risen, he can be hit and hurts to touch")
	var x0 := d.global_position.x
	await frames(30)
	check(d.global_position.x < x0 - 5.0, "then he shambles toward you")


## Bible 7: close in, he heaves his anchor overhead (the tell), slams it down in
## front of him, and is soft while it is buried. The slam can be parried.
func test_drowned_dwarf_heaves_then_slams_and_the_slam_can_be_parried() -> void:
	var room := _room_with({Vector2i(22, 6): "p"})
	var p := make_player(room, Vector2i(3, 6))
	p.max_hp = 9999
	p.hp = 9999
	var d: DrownedDwarf = _find(room, DrownedDwarf)
	await frames(3)
	p.teleport(Vector2(d.global_position.x - 30.0, 7 * 16))
	var tell := 0
	var lit := false
	var hp := p.hp
	for i in 150:
		await frames(1)
		if d.state == "windup":
			tell += 1
			lit = lit or d.telegraph_pulse()
		if d.state == "mired":
			break
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH, "the heave lasts at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, tell])
	check(lit, "and he flashes as he heaves")
	check(hp - p.hp >= DrownedDwarf.SLAM_DAMAGE, "the slam catches a player standing still (%d)" % (hp - p.hp))
	var before := d.hp
	d.take_hit(10, Vector2.RIGHT)
	check(before - d.hp == 15, "with the anchor buried, a 10 hit deals 15 (%d)" % (before - d.hp))
	# The next heave, meet the slam with a parry.
	for i in 200:
		await frames(1)
		if d.state == "windup" and d.state_time >= DrownedDwarf.HEAVE - 3.0 / 60.0:
			break
	p.teleport(Vector2(d.global_position.x - 30.0, 7 * 16))
	p.facing = 1
	hp = p.hp
	p.input.block_pressed = true
	p.input.block_held = true
	await frames(10)
	check(p.hp == hp, "a parried slam does no damage (%d)" % (hp - p.hp))
	check(d.is_staggered(), "and he reels")


## Bible 7: lose him and he sinks back into the mire to wait.
func test_drowned_dwarf_sinks_back_once_he_loses_you() -> void:
	var room := _room_with({Vector2i(22, 6): "p"})
	var p := make_player(room, Vector2i(3, 6))
	var d: DrownedDwarf = _find(room, DrownedDwarf)
	await frames(3)
	p.teleport(Vector2(d.global_position.x - 64.0, 7 * 16))
	for i in 60:
		await frames(1)
		if d.state == "walk":
			break
	check(d.state == "walk", "he rose")
	p.teleport(Vector2(2.5 * 16, 7 * 16))
	d.global_position.x = 26 * 16
	var sank := 0
	for i in 300:
		await frames(1)
		if d.is_sunk():
			sank = i
			break
	check(sank > 0, "out of sight, he sinks again")
	check(sank / 60.0 >= DrownedDwarf.LOSE_TIME, "but only after 3 s (%.2f s)" % (sank / 60.0))
	check(d.collision_layer == 0, "and is out of reach once more")


## Bible 7: the Bark Knight braces (the telegraph), then thrusts his lance far
## out in front of him. The thrust can be parried.
func test_bark_knight_braces_then_thrusts_his_lance_and_the_thrust_can_be_parried() -> void:
	var room := _room_with({Vector2i(22, 6): "!"})
	var p := make_player(room, Vector2i(3, 6))
	p.max_hp = 9999
	p.hp = 9999
	var k: BarkKnight = _find(room, BarkKnight)
	await frames(3)
	# Well out of a Rot Dwarf's reach, but inside the lance's.
	p.teleport(Vector2(k.global_position.x - 56.0, 7 * 16))
	var tell := 0
	var lit := false
	var hp := p.hp
	for i in 150:
		await frames(1)
		k.global_position.x = 22.5 * 16
		if k.state == "windup":
			tell += 1
			lit = lit or k.telegraph_pulse()
		if k.state == "rooted":
			break
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH, "the brace lasts at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, tell])
	check(lit, "and he flashes as he braces")
	check(hp - p.hp >= BarkKnight.THRUST_DAMAGE, "the thrust reaches a player 3.5 tiles off (%d)" % (hp - p.hp))
	check(k.lance_rect().size.x >= 56.0, "the lance reaches at least 3.5 tiles (%.0f px)" % k.lance_rect().size.x)
	# The next brace, meet the thrust with a parry.
	for i in 300:
		await frames(1)
		if k.state == "windup" and k.state_time >= BarkKnight.BRACE - 3.0 / 60.0:
			break
	check(k.state == "windup", "he braces again")
	p.teleport(Vector2(k.global_position.x - 56.0, 7 * 16))
	p.facing = 1
	hp = p.hp
	p.input.block_pressed = true
	p.input.block_held = true
	await frames(10)
	check(p.hp == hp, "a parried thrust does no damage (%d)" % (hp - p.hp))
	check(k.is_staggered(), "and he reels")


## Bible 7: his bark is a guard that blows chip away; bare, or rooted, he takes
## full damage, and a plate grows back as he pulls his roots free.
func test_bark_knight_bark_guards_until_stripped_and_regrows_as_he_uproots() -> void:
	var room := _room_with({Vector2i(22, 6): "!"})
	var p := make_player(room, Vector2i(3, 6))
	var k: BarkKnight = _find(room, BarkKnight)
	await frames(3)
	var before := k.hp
	k.take_hit(10, Vector2.RIGHT)
	check(before - k.hp == 3, "in bark, a 10 hit only chips for 3 (%d)" % (before - k.hp))
	check(k.bark == BarkKnight.BARK - 1, "and knocks off a plate")
	k.take_hit(10, Vector2.RIGHT)
	k.take_hit(10, Vector2.RIGHT)
	check(k.bark == 0, "three blows strip him bare")
	before = k.hp
	k.take_hit(10, Vector2.RIGHT)
	check(before - k.hp == 10, "bare, a 10 hit deals 10 (%d)" % (before - k.hp))
	# Bark him up again and catch him rooted.
	k.bark = BarkKnight.BARK - 1
	p.max_hp = 9999
	p.hp = 9999
	p.teleport(Vector2(k.global_position.x - 56.0, 7 * 16))
	for i in 200:
		await frames(1)
		if k.is_rooted():
			break
	check(k.is_rooted(), "he roots after a thrust")
	before = k.hp
	k.take_hit(10, Vector2.RIGHT)
	check(before - k.hp == 10, "rooted, the bark doesn't guard him (%d)" % (before - k.hp))
	check(k.bark == BarkKnight.BARK - 1, "and a blow then takes no plate")
	for i in 120:
		await frames(1)
		if not k.is_rooted():
			break
	check(k.bark == BarkKnight.BARK, "a plate grows back as he pulls free (%d)" % k.bark)


## Pass 177: Emberfall catches living bark. A fireball's burst burns the whole coat
## off at once and lands in full on the heartwood beneath.
func test_a_thrown_dagger_splits_no_bark_and_breaks_no_hex() -> void:
	var room := _room_with({Vector2i(22, 6): "!"})
	make_player(room, Vector2i(3, 6))
	var k: BarkKnight = _find(room, BarkKnight)
	await frames(3)
	var before := k.hp
	k.take_throw(RuneDagger.DAMAGE, Vector2.RIGHT)
	check(before - k.hp == ceili(RuneDagger.DAMAGE * BarkKnight.GUARD) and k.bark == BarkKnight.BARK, "a dagger in a Bark Knight's bark lands its quarter and splits no plate")
	room.free()
	room = _hag_room({Vector2i(30, 8): "?"})
	var p := make_player(room, Vector2i(20, 8))
	p.max_hp = 9999
	p.hp = 9999
	var h: MarshHag = _find(room, MarshHag)
	for i in 240:
		await frames(1)
		if h.is_hexing() and h.state_time > 0.2:
			break
	check(h.is_hexing(), "she is hexing")
	before = h.hp
	h.take_throw(RuneDagger.DAMAGE, Vector2.RIGHT)
	check(before - h.hp == RuneDagger.DAMAGE and h.is_hexing(), "a dagger stings a Marsh Hag mid-hex but the spell holds")
	room.free()


func test_fire_burns_a_bark_knights_bark_off_at_once() -> void:
	var room := _room_with({Vector2i(22, 6): "!"})
	make_player(room, Vector2i(3, 6))
	var k: BarkKnight = _find(room, BarkKnight)
	await frames(3)
	check(k.bark == BarkKnight.BARK, "he starts in full bark")
	var before := k.hp
	var f := Fireball.new()
	room.add_child(f)
	f.global_position = k.center()
	f.burst()
	check(k.bark == 0, "the burst burns every plate off (%d left)" % k.bark)
	check(before - k.hp == f.damage, "and the flame lands in full, %d (%d)" % [f.damage, before - k.hp])
	before = k.hp
	k.take_hit(10, Vector2.RIGHT)
	check(before - k.hp == 10, "bare, the next blow lands in full too")


## Bible 7: rooted, his lance is a bough you can stand on; it goes when he moves.
func test_bark_knight_rooted_lance_is_a_ledge() -> void:
	var room := _room_with({Vector2i(14, 6): "!"})
	var p := make_player(room, Vector2i(3, 6))
	p.max_hp = 9999
	p.hp = 9999
	var k: BarkKnight = _find(room, BarkKnight)
	await frames(3)
	check(not k.bough_solid(), "walking, the lance is no ledge")
	p.teleport(Vector2(k.global_position.x - 56.0, 7 * 16))
	for i in 200:
		await frames(1)
		if k.is_rooted():
			break
	await frames(2)
	check(k.bough_solid(), "rooted, it is")
	# Drop onto the lance from above.
	var lance := k.lance_rect()
	p.teleport(Vector2(lance.get_center().x, lance.position.y - 20.0))
	p.velocity = Vector2.ZERO
	var stood := false
	for i in 30:
		await frames(1)
		if p.is_on_floor() and p.global_position.y < 7 * 16 - 8:
			stood = true
			break
	check(stood, "you can stand on the rooted lance (y %.0f)" % p.global_position.y)
	for i in 120:
		await frames(1)
		if not k.is_rooted():
			break
	await frames(20)
	check(not k.bough_solid(), "it goes when he pulls free")
	check(p.global_position.y >= 7 * 16 - 1, "and you drop to the floor (y %.0f)" % p.global_position.y)


## Bible 6.2 on the Bark Knight's lance (pass 111): Down + Jump drops through it
## like any one-way, and when it goes from under you, coyote time still holds.
func test_the_bark_knights_lance_drops_through_and_gives_coyote_time() -> void:
	for mode in ["drop", "coyote"]:
		var room := _room_with({Vector2i(14, 6): "!"})
		var p := make_player(room, Vector2i(3, 6), {"boots": false})
		p.max_hp = 9999
		p.hp = 9999
		var k: BarkKnight = _find(room, BarkKnight)
		await frames(3)
		p.teleport(Vector2(k.global_position.x - 56.0, 7 * 16))
		for i in 200:
			await frames(1)
			if k.is_rooted():
				break
		await frames(2)
		var lance := k.lance_rect()
		p.teleport(Vector2(lance.get_center().x, lance.position.y - 20.0))
		p.velocity = Vector2.ZERO
		for i in 20:
			await frames(1)
			if p.is_on_floor():
				break
		check(p.is_on_floor() and p.global_position.y < 7 * 16 - 8, "%s: standing on the lance" % mode)
		if mode == "drop":
			p.input.down = true
			p.input.jump_pressed = true
			await frames(1)
			p.input.down = false
			await frames(20)
			check(p.global_position.y >= 7 * 16 - 1, "Down + Jump drops through the lance (y %.0f)" % p.global_position.y)
		else:
			var gone := 0
			for i in 120:
				await frames(1)
				if not p.is_on_floor():
					gone = i
					break
			check(gone > 0, "the lance goes from under you")
			await frames(3)
			p.input.jump_pressed = true
			p.input.jump_held = true
			await frames(1)
			check(p.velocity.y < -300.0, "and a jump 4 frames later still counts (vy %.0f)" % p.velocity.y)
		room.free()


## A tall room for the Seed Bomber, which keeps about five tiles over your head.
func _sky_room(spots: Dictionary) -> Room:
	var rows: Array = ["##############################"]
	for i in 12:
		rows.append("#............................#")
	rows.append("##############################")
	for cell: Vector2i in spots:
		var row: String = rows[cell.y]
		rows[cell.y] = row.substr(0, cell.x) + spots[cell] + row.substr(cell.x + 1)
	return make_room(rows)


func _seeds(room: Room) -> Array:
	return room.get_children().filter(func(c: Node) -> bool: return c is BomberSeed and not c.is_queued_for_deletion())


## Bible 7 (pass 114): the Seed Bomber hangs over your head, squeezes its husk
## (the telegraph), and drops a seed that stings whoever it lands on.
func test_seed_bomber_hangs_over_you_then_squeezes_and_drops_a_seed() -> void:
	var room := _sky_room({Vector2i(20, 3): ";"})
	var p := make_player(room, Vector2i(8, 12))
	p.max_hp = 9999
	p.hp = 9999
	var b: SeedBomber = _find(room, SeedBomber)
	var tell := 0
	var lit := false
	var over := false
	var seed: BomberSeed = null
	for i in 400:
		await frames(1)
		if b.state == "windup":
			tell += 1
			lit = lit or b.telegraph_pulse()
			over = absf(b.center().x - p.global_position.x) < SeedBomber.OVER + 2.0 \
				and p.global_position.y - b.center().y > SeedBomber.HOVER * 0.75
		if not _seeds(room).is_empty():
			seed = _seeds(room)[0]
			break
	check(over, "it squeezes from right over your head, out of a slash's reach")
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH, "the squeeze lasts at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, tell])
	check(lit, "and it flashes as it squeezes")
	check(seed != null and seed.phase == "fall", "then it drops a seed")
	var hp := p.hp
	for i in 90:
		await frames(1)
		if p.hp < hp:
			break
	check(hp - p.hp >= BomberSeed.DAMAGE, "the seed stings the player it lands on (%d)" % (hp - p.hp))
	room.free()


## A seed that lands sputters (its own telegraph), then bursts in thorns that
## can't be parried.
func test_a_seed_on_the_branch_sputters_then_bursts_in_thorns() -> void:
	var room := _sky_room({})
	var p := make_player(room, Vector2i(8, 12))
	p.max_hp = 9999
	p.hp = 9999
	var s := BomberSeed.new()
	room.add_child(s)
	s.global_position = Vector2(8.5 * 16 + 22.0, 8 * 16)
	var fuse := 0
	for i in 120:
		await frames(1)
		if not is_instance_valid(s) or s.is_queued_for_deletion():
			break
		if s.phase == "fuse":
			fuse += 1
			if fuse == 1:
				check(absf(s.global_position.y + BomberSeed.RADIUS - 13 * 16) < 1.5, "it sticks on the floor (y %.1f)" % s.global_position.y)
				p.facing = 1
			if fuse == int(BomberSeed.FUSE * 60.0) - 4:
				var hp := p.hp
				# A parry tap, not a held guard.
				p.input.block_pressed = true
				await frames(1)
				p.input.block_pressed = false
				await frames(7)
				check(hp - p.hp >= BomberSeed.BURST_DAMAGE, "the burst reaches 22 px and a parry can't turn it (%d)" % (hp - p.hp))
				break
	check(fuse / 60.0 >= Enemy.MIN_TELEGRAPH, "it sputters at least %.2f s first (%d frames)" % [Enemy.MIN_TELEGRAPH, fuse])
	check(_seeds(room).is_empty(), "and it is spent")
	room.free()


## Strike the seed and it flies back into its bird: the burst knocks the bird
## down, dazed and taking blows at half again, until it climbs back up.
func test_a_struck_seed_flies_back_and_knocks_the_bomber_down() -> void:
	var room := _sky_room({Vector2i(14, 4): ";"})
	var p := make_player(room, Vector2i(4, 12))
	p.max_hp = 9999
	p.hp = 9999
	var b: SeedBomber = _find(room, SeedBomber)
	await frames(2)
	b.set_physics_process(false)
	# A seed on the floor right in front of the player; slash it.
	var s := BomberSeed.new()
	s.bomber = b
	room.add_child(s)
	s.global_position = Vector2(p.global_position.x + 22.0, 13 * 16 - BomberSeed.RADIUS - 1.0)
	await frames(2)
	p.facing = 1
	p.input.attack_pressed = true
	await frames(1)
	p.input.attack_pressed = false
	await frames(4)
	check(is_instance_valid(s) and s.phase == "return", "a slash sends the seed back up")
	b.set_physics_process(true)
	var hp := b.hp
	for i in 90:
		await frames(1)
		if b.state == "downed":
			break
	check(hp - b.hp == BomberSeed.RETURN_DAMAGE, "it bursts on the bird for %d (%d)" % [BomberSeed.RETURN_DAMAGE, hp - b.hp])
	check(b.is_downed(), "and knocks it out of the sky")
	for i in 120:
		await frames(1)
		if b.is_on_floor():
			break
	check(b.is_on_floor(), "it falls to the floor")
	hp = b.hp
	b.take_hit(4, Vector2.RIGHT)
	check(hp - b.hp == 6, "downed, it takes blows at half again (%d)" % (hp - b.hp))
	var down := 0
	for i in 200:
		await frames(1)
		if b.state != "downed":
			break
		down += 1
	check(down / 60.0 >= SeedBomber.DAZED - 0.3, "it lies dazed about %.1f s (%d frames)" % [SeedBomber.DAZED, down])
	var y := b.global_position.y
	await frames(30)
	check(b.global_position.y < y - 16.0 and not b.uses_gravity, "then it climbs back into the air")
	room.free()


## A seed parried as it falls flies back up too, and the player takes nothing.
func test_a_parried_seed_flies_back_at_its_bird() -> void:
	var room := _sky_room({Vector2i(14, 4): ";"})
	var p := make_player(room, Vector2i(8, 12))
	p.max_hp = 9999
	p.hp = 9999
	var b: SeedBomber = _find(room, SeedBomber)
	await frames(2)
	b.set_physics_process(false)
	var s := BomberSeed.new()
	s.bomber = b
	room.add_child(s)
	s.global_position = p.global_position + Vector2(3, -60)
	s.velocity = Vector2(0, 200)
	var hp := p.hp
	for i in 30:
		await frames(1)
		if s.global_position.y > p.global_position.y - 52.0:
			break
	p.input.block_pressed = true
	p.input.block_held = true
	await frames(8)
	check(p.hp == hp, "a parried seed does no damage (%d)" % (hp - p.hp))
	check(is_instance_valid(s) and s.phase == "return", "and flies back up")
	room.free()


## A wide flat floor for the Marsh Hag (floor row 9).
func _hag_room(spots: Dictionary) -> Room:
	var rows: Array = ["########################################"]
	for i in 8:
		rows.append("#......................................#")
	rows.append("########################################")
	for cell: Vector2i in spots:
		var row: String = rows[cell.y]
		rows[cell.y] = row.substr(0, cell.x) + spots[cell] + row.substr(cell.x + 1)
	return make_room(rows)


func _hag_marks(room: Room) -> Array:
	return room.get_children().filter(func(c: Node) -> bool: return c is MireGrasp and not c.is_queued_for_deletion())


## Bible 7 (pass 119): from a distance the Marsh Hag hexes the mire under your
## feet. The mark is the telegraph; then a mud hand bursts up for 12 that can't
## be parried. Step off the mark and it misses.
func test_marsh_hag_hexes_the_mire_under_your_feet() -> void:
	var room := _hag_room({Vector2i(30, 8): "?"})
	var p := make_player(room, Vector2i(20, 8))
	p.max_hp = 9999
	p.hp = 9999
	var h: MarshHag = _find(room, MarshHag)
	check(h._wisp != null and h._wisp.is_in_group("light"), "her wisp lights the fog")
	var tell := 0
	var lit := false
	var mark: MireGrasp = null
	for i in 240:
		await frames(1)
		if h.is_hexing():
			tell += 1
			lit = lit or h.telegraph_pulse()
			if mark == null:
				mark = h.mark()
		elif tell > 0:
			break
	check(mark != null, "she marks the ground")
	check(mark != null and absf(mark.global_position.x - p.global_position.x) < 2.0 and absf(mark.global_position.y - 9 * 16) < 1.0,
		"under your feet, on the floor")
	check(tell / 60.0 >= Enemy.MIN_TELEGRAPH and lit, "the hex lasts at least %.2f s and she flashes (%d frames)" % [Enemy.MIN_TELEGRAPH, tell])
	await frames(10)
	check(9999 - p.hp == MireGrasp.DAMAGE, "the mud hand bursts up for %d (%d)" % [MireGrasp.DAMAGE, 9999 - p.hp])
	# The next hex: step well off the mark before it erupts.
	var hp := p.hp
	for i in 240:
		await frames(1)
		if h.is_hexing():
			break
	check(h.is_hexing(), "she hexes again after her cooldown")
	p.input.move_x = -1
	await frames(30)
	p.input.move_x = 0
	await frames(30)
	check(p.hp == hp, "stepping off the mark dodges it (%d)" % (hp - p.hp))
	# The hand can't be parried.
	var r := MireGrasp.new()
	r.hag = h
	room.add_child(r)
	r.global_position = Vector2(p.global_position.x, 9 * 16)
	p.facing = 1
	p.input.block_pressed = true
	await frames(1)
	p.input.block_pressed = false
	r.erupt()
	await frames(4)
	check(hp - p.hp == MireGrasp.DAMAGE, "and a parry doesn't turn it (%d)" % (hp - p.hp))
	room.free()


## Strike her while she hexes and the spell breaks: the mark fizzles, and she
## fumbles her staff, taking blows at half again.
func test_striking_the_marsh_hag_mid_hex_breaks_the_spell() -> void:
	var room := _hag_room({Vector2i(30, 8): "?"})
	var p := make_player(room, Vector2i(20, 8))
	p.max_hp = 9999
	p.hp = 9999
	var h: MarshHag = _find(room, MarshHag)
	for i in 240:
		await frames(1)
		if h.is_hexing() and h.state_time > 0.2:
			break
	check(h.is_hexing(), "she is hexing")
	var mark := h.mark()
	var hp := h.hp
	h.take_hit(4, Vector2.RIGHT)
	check(hp - h.hp == 6, "a blow mid-hex lands at half again (%d)" % (hp - h.hp))
	check(h.is_fumbling(), "she fumbles her staff")
	check(mark != null and mark.phase == "fizzle", "the mark fizzles")
	await frames(30)
	check(p.hp == 9999 and _hag_marks(room).is_empty(), "no hand comes up")
	hp = h.hp
	h._hitstun = 0.0
	h.take_hit(4, Vector2.RIGHT)
	check(hp - h.hp == 6, "fumbling, she takes blows at half again (%d)" % (hp - h.hp))
	var fumble := 0
	for i in 120:
		await frames(1)
		if not h.is_fumbling():
			break
		fumble += 1
	check(fumble / 60.0 >= MarshHag.FUMBLE - 0.6, "she gropes for the staff about %.1f s (%d frames after the blows)" % [MarshHag.FUMBLE, fumble])
	room.free()


## Close in and she hobbles away from you, but only so far: then she hexes anyway.
func test_the_marsh_hag_backs_away_when_you_close_in() -> void:
	var room := _hag_room({Vector2i(20, 8): "?"})
	var p := make_player(room, Vector2i(17, 8))
	p.max_hp = 9999
	p.hp = 9999
	var h: MarshHag = _find(room, MarshHag)
	var x0 := h.global_position.x
	var backed := false
	var hexed := false
	for i in 200:
		await frames(1)
		backed = backed or h.state == "withdraw"
		if h.is_hexing():
			hexed = true
			break
	check(backed, "she backs away")
	check(h.global_position.x > x0 + 16.0, "away from you (%.0f px)" % (h.global_position.x - x0))
	check(h.facing == -1, "still facing you")
	check(hexed, "then she hexes anyway")
	room.free()


## Pass 120: every enemy shot and ground hazard the Stillstone should hold
## checks it, the Marsh Hag's hex among them (it was missed in pass 119).
func test_every_enemy_shot_honours_the_stillstone() -> void:
	var missing: Array[String] = []
	var shots := 0
	for dir in ["res://scripts/enemies", "res://scripts/bosses"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir + "/" + f)
			if text.contains("add_to_group(\"enemy_projectile\")"):
				shots += 1
				if not text.contains("TimeStop.active()"):
					missing.append(f)
	check(shots >= 8, "found the enemy shots (%d)" % shots)
	check(missing.is_empty(), "each one stops for the Stillstone: %s" % [missing])
	# And the hex itself: a hand that rises while time is stopped waits for it.
	var room := _hag_room({Vector2i(30, 8): "?"})
	var p := make_player(room, Vector2i(20, 8))
	p.max_hp = 9999
	p.hp = 9999
	var h: MarshHag = _find(room, MarshHag)
	h.set_physics_process(false)
	var r := MireGrasp.new()
	r.hag = h
	room.add_child(r)
	r.global_position = Vector2(p.global_position.x, 9 * 16)
	TimeStop.start(1.0)
	r.erupt()
	await frames(20)
	check(p.hp == 9999 and r.phase == "grasp", "held by the glass, the hand doesn't strike")
	TimeStop.reset()
	await frames(4)
	check(9999 - p.hp == MireGrasp.DAMAGE, "and it does when time runs on (%d)" % (9999 - p.hp))
	room.free()


## A Marsh Hag that comes back (rooms with `enemy_respawn`) comes back whole:
## no half-cast hex left over, and she backs away again as if new.
func test_a_respawned_marsh_hag_starts_fresh() -> void:
	var room := _hag_room({Vector2i(30, 8): "?"})
	var p := make_player(room, Vector2i(20, 8))
	p.max_hp = 9999
	p.hp = 9999
	var h: MarshHag = _find(room, MarshHag)
	h.respawn_time = 0.5
	for i in 240:
		await frames(1)
		if h.is_hexing():
			break
	var mark := h.mark()
	check(mark != null, "she is mid-hex")
	h._backed = MarshHag.BACK_TIME
	h.take_hit(999, Vector2.RIGHT)
	check(h.dead, "she dies")
	check(mark.phase == "fizzle", "her hex dies with her")
	await frames(45)
	check(not h.dead and h.state in ["idle", "walk"], "she comes back (%s)" % h.state)
	check(h.mark() == null and h._backed == 0.0 and h.hp == h.max_hp, "with nothing left over")
	await frames(30)
	check(_hag_marks(room).is_empty() or h.is_hexing(), "and no stray mark lies about")
	TimeStop.reset()
	room.free()


## Bible 7 (pass 123): the Spire Sentinel is stone while you face it. It
## never moves and blows clink off; turn your back and it grinds after you, and
## it stops dead when you turn round.
func test_spire_sentinel_moves_only_behind_your_back() -> void:
	var room := _room_with({Vector2i(22, 6): "]"})
	var p := make_player(room, Vector2i(10, 6))
	var s: SpireSentinel = _find(room, SpireSentinel)
	var x0 := s.global_position.x
	p.facing = 1
	await frames(40)
	check(s.state == "stone" and absf(s.global_position.x - x0) < 0.5, "watched, it stands as stone (%s, moved %.1f)" % [s.state, s.global_position.x - x0])
	var hp0 := s.hp
	s.take_hit(10, Vector2.RIGHT)
	check(s.hp == hp0, "a blow clinks off the stone (%d)" % (hp0 - s.hp))
	p.facing = -1
	var stalked := 0
	for i in 40:
		await frames(1)
		if s.is_stalking():
			stalked += 1
	check(stalked > 20 and s.global_position.x < x0 - 16.0, "back turned, it grinds after you (%d frames, %.0f px)" % [stalked, x0 - s.global_position.x])
	check("sentinel_grind" in Sfx.recent, "you hear it grind")
	p.facing = 1
	await frames(2)
	var x1 := s.global_position.x
	check(s.state == "stone", "turn round and it stops dead (%s)" % s.state)
	await frames(30)
	check(absf(s.global_position.x - x1) < 0.5, "and stays put while you watch")
	hp0 = s.hp
	s.take_hit(10, Vector2.RIGHT)
	check(s.hp == hp0, "still stone, still no harm done")
	room.free()


## In reach it raises the halberd (the telegraph), slams for 16 and is left
## with its blade buried: cracked open, every blow lands. A parried slam
## staggers it, cracked open the same way.
func test_spire_sentinel_slams_and_cracks_open() -> void:
	var room := _room_with({Vector2i(22, 6): "]"})
	var p := make_player(room, Vector2i(10, 6))
	p.max_hp = 9999
	p.hp = 9999
	var s: SpireSentinel = _find(room, SpireSentinel)
	await frames(5)
	p.global_position = Vector2(s.global_position.x - 30.0, 7 * 16)
	p.reset_physics_interpolation()
	p.facing = 1
	var raise := 0
	var hp := p.hp
	for i in 120:
		await frames(1)
		if s.state == "raise":
			raise += 1
		if s.state == "spent":
			break
	check(raise / 60.0 >= Enemy.MIN_TELEGRAPH, "it raises the halberd for at least %.2f s (%d frames)" % [Enemy.MIN_TELEGRAPH, raise])
	check(hp - p.hp == SpireSentinel.SLAM_DAMAGE, "the slam does %d (%d)" % [SpireSentinel.SLAM_DAMAGE, hp - p.hp])
	check(s.exposed(), "its blade buried, the stone cracks open (%s)" % s.state)
	var hp0 := s.hp
	s.take_hit(10, Vector2.RIGHT)
	check(hp0 - s.hp == 10, "and a blow lands in full (%d)" % (hp0 - s.hp))
	for i in 120:
		await frames(1)
		if s.state == "stone":
			break
	check(s.state == "stone" and not s.exposed(), "then it is stone again (%s)" % s.state)
	# Its next slam, met with a parry. The first knocked you back out of its
	# reach, and it won't come to you while you face it: step back in.
	p.has_shield = true
	p.global_position = Vector2(s.global_position.x - 30.0, 7 * 16)
	p.reset_physics_interpolation()
	p.facing = 1
	for i in 180:
		await frames(1)
		if s.state == "raise" and s.state_time >= SpireSentinel.RAISE - 3.0 / 60.0:
			break
	hp = p.hp
	p.input.block_pressed = true
	p.input.block_held = true
	await frames(8)
	p.input.block_pressed = false
	check(p.hp == hp, "a parried slam does no harm (%d)" % (hp - p.hp))
	check(s.is_staggered() and s.exposed(), "and staggers it, cracked open")
	hp0 = s.hp
	s.take_hit(10, Vector2.RIGHT)
	check(hp0 - s.hp == 10, "a blow on the staggered stone lands (%d)" % (hp0 - s.hp))
	room.free()


## Bible 7 (pass 126): every enemy dies with a dissolve. Its body stays a
## moment, flashes white and breaks up into glowing motes (the dissolve shader),
## harmless and untouchable, then is gone.
func test_a_defeated_enemy_dissolves_then_is_gone() -> void:
	var room := _room_with({Vector2i(12, 6): "M"})
	var p := make_player(room, Vector2i(5, 6))
	var m: Blinkhop = _find(room, Blinkhop)
	await frames(2)
	m.take_hit(999, Vector2(1, 0))
	check(m.dead and m.dissolving() and m.visible, "it is still there, breaking up")
	var mat := m.material as ShaderMaterial
	check(mat != null and mat.shader == Enemy.DISSOLVE_SHADER, "with the dissolve shader")
	check(m.collision_layer == 0, "and can't be struck or touched")
	await frames(12)
	var mid: float = mat.get_shader_parameter("progress")
	check(mid > 0.2 and mid < 0.9, "partway through (progress %.2f)" % mid)
	await frames(int(Enemy.DISSOLVE * 60.0))
	check(not is_instance_valid(m) or m.is_queued_for_deletion(), "after %.2f s it is gone" % Enemy.DISSOLVE)
	check(p.hp == p.max_hp, "the dissolving body never hurt anyone")
	room.free()


## Pass 112: the foes built after the pass-102 sound pass have voices of their
## own. Each of these sounds exists, its foe plays it, and nothing else does, so
## a tell can be told apart by ear.
func test_the_newer_foes_have_voices_of_their_own() -> void:
	var own := {
		"bark_knight": ["bark_creak", "lance_thrust", "root_grip", "bark_chip"],
		"drowned_dwarf": ["anchor_heave", "anchor_slam"],
		"leaf_mantis": ["mantis_unfold", "scythe"],
		"seed_bomber": ["seed_rattle", "seed_drop"],
		"bomber_seed": ["seed_fuse", "seed_burst"],
		"marsh_hag": ["hag_hex", "mire_grasp", "hag_fumble"],
		"spire_sentinel": ["sentinel_grind", "sentinel_raise", "sentinel_slam"],
		# The mini-bosses (pass 173).
		"clockwork_alpha": ["key_wind", "spring_jam"],
		"bark_captain": ["bough_vault", "lance_plant"],
		"hag_matriarch": ["matriarch_cackle", "bog_sink", "bog_rise"],
		# The Bloom and its brood (pass 262).
		"mothling": ["mothling_screech", "mothling_dive"],
		"snapcrown": ["bloom_brood", "brood_loose"],
		# The source game's Silt Adder (pass 273).
		"silt_adder": ["silt_adder_hiss", "silt_adder_strike"],
	}
	# A family's mini-boss speaks with its kin's voice, only louder (pass 171).
	var kin := {"bark_knight": ["bark_captain"], "marsh_hag": ["hag_matriarch"]}
	var played := {}  # sound -> scripts that play it
	for dir in ["res://scripts/enemies/", "res://scripts/bosses/", "res://scripts/world/", "res://scripts/player/"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir + f)
			var re := RegEx.create_from_string("Sfx\\.play\\(\"([a-z_0-9]+)\"")
			for m in re.search_all(src):
				var name := m.get_string(1)
				if not played.has(name):
					played[name] = []
				if not (f.get_basename() in played[name]):
					played[name].append(f.get_basename())
	for foe: String in own:
		for sound: String in own[foe]:
			check(FileAccess.file_exists("res://assets/sfx/%s.wav" % sound), "%s.wav exists" % sound)
			var who: Array = played.get(sound, []).filter(func(n: String) -> bool: return not kin.get(foe, []).has(n))
			check(who == [foe], "%s is played by the %s alone, or its kin (%s)" % [sound, foe, played.get(sound, [])])


## Pass 161 (bible 7, "the Evercrown: remixes of every family"): the Everbloom holds a
## corrupted remix of foes from every zone of the climb, not only Vorrhallow's.
## Each the Evercrown room is loaded for real: every foe in it is corrupted, and the
## families found cover the Heartwood, the Tower, the Haar, the High Boughs, Carillon
## and Vorrhallow.
func test_evercrown_holds_a_remix_of_every_zones_foes() -> void:
	var homes := {
		"heartwood": ["RotDwarf", "Blinkhop", "GrubLump", "SapSpitter"],
		"tower": ["IronDwarf", "GearBat", "MinecartRider"],
		"haar": ["LanternGhost", "BogPuffcap", "DrownedDwarf", "MarshHag"],
		"boughs": ["LeafMantis", "BarkKnight", "SeedBomber"],
		"spires": ["StormHarpy", "ThunderBeetle", "SpireSentinel"],
		"vorrhallow": ["CrystalDwarf", "ClockworkHound", "ShadeKnight", "GlassSlug"],
	}
	var found := {}
	var total := 0
	for id: String in ["evercrown/threshold", "evercrown/heart_stair", "evercrown/drift_well", "evercrown/heart_gate"]:
		GameState.new_game()
		var room := Room.from_text(FileAccess.get_file_as_string(World.room_path(id)), id)
		arena.add_child(room)
		for c in room.get_children():
			if c is Enemy and not c is MeteorSeed:
				total += 1
				check((c as Enemy).corrupted, "%s: the %s is corrupted" % [id, c.get_script().get_global_name()])
				found[String(c.get_script().get_global_name())] = true
		room.queue_free()
	await frames(1)
	for zone: String in homes:
		var hit: Array = homes[zone].filter(func(n: String) -> bool: return found.has(n))
		check(not hit.is_empty(), "the Evercrown remixes the %s's foes (%s)" % [zone, hit])
	check(found.size() >= 12, "a dozen families or more in the Everbloom (%d: %s)" % [found.size(), found.keys()])


## The hurt flash and the tells wash a code-drawn foe's own silhouette white
## (bible 7), never a white box around it, and the wash leaves the dissolve alone.
func test_a_flash_whitens_the_foe_not_a_box() -> void:
	var rows := TALL.duplicate()
	rows[9] = "#....................y.......#"
	var room := make_room(rows)
	make_player(room, Vector2i(8, 12))
	var h: StormHarpy = _find(room, StormHarpy)
	# She is drawn from her sheet (art pass 5): her flash is her own sprite drawn white.
	await frames(2)
	check(not h.drawn_white(), "a harpy at rest is drawn in her own colours")
	h.take_hit(1, Vector2(1, 0))
	await frames(1)
	check(h.drawn_white(), "a hit washes her white")
	await frames(10)
	check(not h.drawn_white(), "and the wash fades with the flash")
	h.set_state("windup")
	var pulsed := false
	for i in 12:
		await frames(1)
		pulsed = pulsed or h.drawn_white()
	check(pulsed, "her screech tell pulses white")
	h.take_hit(999, Vector2(1, 0))
	await frames(2)
	check(not h.washed() and h.material != null, "a death keeps its dissolve")
	# No code-drawn foe or boss lays a white box or disc over itself any more.
	var box := RegEx.create_from_string("\\n\\tif (white|flashing\\(\\))[^\\n]*:\\n\\t\\t(_px|_rect|draw_rect|draw_circle)\\([^\\n]*Color\\(1, 1, 1")
	for dir: String in ["res://scripts/enemies/", "res://scripts/bosses/"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				var src := FileAccess.get_file_as_string(dir + file)
				var m := box.search(src)
				check(m == null, "%s washes its silhouette (%s)" % [file, "" if m == null else m.get_string().strip_edges()])


## Pass 234: the telegraph rule (CLAUDE.md, bible 7) held as a whole. Every
## wind-up a foe or guardian names (a *TELL, a WINDUP, a WARN) lasts at least
## Enemy.MIN_TELEGRAPH, and every guardian that quickens its tells by phase
## clamps them to it. The one exception is a crystal spike's own floor glow: it
## only says where, after its caster's full tell has said when, so each caster
## must wind up for at least MIN_TELEGRAPH before it erupts.
const FOLLOW_ON_TELLS := {"crystal_spike.gd:WARN": "CrystalSpike.new()"}
func test_every_wind_up_in_the_game_is_fair() -> void:
	var short: Array[String] = []
	var unclamped: Array[String] = []
	var spawners: Array[String] = []
	var seen := 0
	for dir in ["res://scripts/enemies", "res://scripts/bosses"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var script := load(dir + "/" + f) as Script
			var consts := script.get_script_constant_map()
			for k: String in consts:
				if not (k.contains("TELL") or k.begins_with("WINDUP") or k == "WARN") or not consts[k] is float or k.ends_with("_ALPHA"):
					continue
				seen += 1
				if consts[k] < Enemy.MIN_TELEGRAPH and not FOLLOW_ON_TELLS.has(f + ":" + k):
					short.append("%s:%s %.2f" % [f, k, consts[k]])
			var text := script.source_code
			var at := text.find("\nfunc tell(")
			if at >= 0 and not text.substr(at, text.find("\n\n", at) - at).contains("maxf(Enemy.MIN_TELEGRAPH"):
				unclamped.append(f)
			if text.contains(String(FOLLOW_ON_TELLS["crystal_spike.gd:WARN"])):
				spawners.append(f)
	check(seen >= 70, "found the wind-ups (%d)" % seen)
	check(short.is_empty(), "each lasts at least %.2f s: %s" % [Enemy.MIN_TELEGRAPH, short])
	check(unclamped.is_empty(), "each quickened tell is clamped to it: %s" % [unclamped])
	spawners.sort()
	check(spawners == ["crystal_dwarf.gd", "everbloom_avatar.gd", "everbloom_heart.gd", "thane_vorrund.gd"], "the crystal spikes have four casters (%s)" % [spawners])
	# Each caster's tell before an eruption, at its quickest phase.
	check(CrystalDwarf.WINDUP >= Enemy.MIN_TELEGRAPH, "the Crystal Dwarf winds up first")
	var avatar := EvilAvatar.new()
	avatar.phase = 2
	var heart := EvilHeart.new()
	heart.phase = 3
	var king := ThaneVorrund.new()
	king.phase = 3
	check(avatar.tell(EvilAvatar.RAIN_TELL) >= Enemy.MIN_TELEGRAPH, "the Avatar raises its arm first (%.2f s)" % avatar.tell(EvilAvatar.RAIN_TELL))
	check(heart.tell() >= Enemy.MIN_TELEGRAPH, "crystal gathers under the Heart first (%.2f s)" % heart.tell())
	check(king.tell(ThaneVorrund.BURST_TELL) >= Enemy.MIN_TELEGRAPH, "Thane Vorrund raises the axe first (%.2f s)" % king.tell(ThaneVorrund.BURST_TELL))
	for n: Node in [avatar, heart, king]:
		n.free()


## Pass 273 (bible 7): the source game's Silt Adder, a serpent that floats up and down,
## most often over the ladders. It keeps its column while it swings; level
## with it and in front, it hoods and hisses for at least the telegraph, then
## strikes straight out along that level, and glides back to its column.
func test_the_silt_adder_floats_its_column_and_strikes_level() -> void:
	var rows: Array = ["##############################"]
	for i in 12:
		rows.append("#............................#")
	rows.append("##############################")
	var row: String = rows[6]
	rows[6] = row.substr(0, 22) + ")" + row.substr(23)
	var room := make_room(rows)
	var n: SiltAdder = _find(room, SiltAdder)
	check(n != null, "the legend ) lays a Silt Adder")
	if n == null:
		return
	# Far off, out of its sight: it floats its swing and keeps its column.
	var p := make_player(room, Vector2i(2, 12))
	p.max_hp = 9999
	p.hp = 9999
	var top := INF
	var low := -INF
	var drift := 0.0
	var coiled := false
	for i in int(SiltAdder.SWING_TIME * 60.0) + 10:
		await frames(1)
		top = minf(top, n.global_position.y)
		low = maxf(low, n.global_position.y)
		drift = maxf(drift, absf(n.global_position.x - n.home.x))
		coiled = coiled or n.state == "coil"
	check(low - top >= SiltAdder.SWING * 1.5, "it floats up and down its column (%.0f px)" % (low - top))
	check(drift < 1.0 and not coiled, "and keeps to it with no one level in sight (drift %.1f)" % drift)
	# Level with it and in front, six tiles off: it hoods, hisses, strikes along that level.
	p.teleport(Vector2(16 * Room.TILE + 8, 13 * Room.TILE))
	n.global_position = n.home
	n._cooldown = 0.0
	var coil := 0
	var struck_y := []
	var hp := p.hp
	Sfx.recent.clear()
	for i in 240:
		# Hold the player level with its head, wherever its swing has it.
		p.global_position.y = n.center().y + 20.0
		p.velocity = Vector2.ZERO
		await frames(1)
		if n.state == "coil":
			coil += 1
		if n.state == "strike":
			struck_y.append(n.global_position.y)
		if p.hp < hp and n.state != "strike" and not struck_y.is_empty():
			break
	check(coil / 60.0 >= Enemy.MIN_TELEGRAPH, "it hoods before it strikes (%d frames)" % coil)
	check(Sfx.recent.has("silt_adder_hiss") and Sfx.recent.has("silt_adder_strike"), "with a hiss, then the strike (%s)" % [Sfx.recent])
	check(not struck_y.is_empty() and (struck_y.max() - struck_y.min()) < 1.0, "the strike runs straight along its level")
	check(p.hp < hp, "and bites (%d)" % (hp - p.hp))
	# Out of line, above its swing, it only floats; and it glides back to its column.
	p.teleport(Vector2(16 * Room.TILE + 8, 2 * Room.TILE))
	var back := false
	coiled = false
	for i in 240:
		p.global_position = Vector2(16 * Room.TILE + 8, 2 * Room.TILE)
		p.velocity = Vector2.ZERO
		await frames(1)
		if n.state == "float" and absf(n.global_position.x - n.home.x) < 4.0:
			back = true
		if back and n.state == "coil":
			coiled = true
	check(back, "it glides back to its column")
	check(not coiled, "and never strikes at one above its swing")


## Pass 274 (bible 5.3, "Parry: enemy staggered"): the Silt Adder's strike was its
## body's touch, which no shield can meet, while every other telegraphed bite
## and slash in the game (the Spring Eel's, the Hound's, the Mantis's) is a
## blow a parry turns. Now the strike is a bite: a parry takes no harm and
## sets the serpent reeling, and an unmet bite lands whole. Its floating body
## only scrapes. The hero stands on the floor here, as in the rooms: the first
## cut ended a strike on any touch of its long body with the floor, so a Silt Adder
## level with a hero on the ground never reached them.
## Bible 7 (pass 281): as in the source game, a slain Silt Adder always leaves the
## largest bread there is, a great loaf, and eating it heals LOAF_HEAL.
func test_a_slain_silt_adder_leaves_a_great_loaf() -> void:
	var rows: Array = ["##############################"]
	for i in 12:
		rows.append("#............................#")
	rows.append("##############################")
	var room := make_room(rows)
	var p := make_player(room, Vector2i(4, 12))
	await frames(5)
	var chances := [Drop.bread_chance, Drop.mana_chance, Drop.rare_chance]
	Drop.bread_chance = 0.0
	Drop.mana_chance = 0.0
	Drop.rare_chance = 0.0
	var n := SiltAdder.new()
	room.add_child(n)
	n.global_position = cell_feet(20, 9)
	n.home = n.global_position
	await frames(2)
	n.take_hit(999, Vector2.RIGHT)
	Drop.bread_chance = chances[0]
	Drop.mana_chance = chances[1]
	Drop.rare_chance = chances[2]
	var loaves := room.get_children().filter(func(c: Node) -> bool: return c is Drop)
	check(loaves.size() == 1 and loaves[0].kind == "loaf", "it leaves a great loaf, though no drop was rolled (%s)" % [loaves.map(func(d: Drop) -> String: return d.kind)])
	check(Drop.LOAF_HEAL > Drop.BREAD_HEAL, "the largest bread there is (%d against %d)" % [Drop.LOAF_HEAL, Drop.BREAD_HEAL])
	if loaves.is_empty():
		room.free()
		return
	var loaf: Drop = loaves[0]
	await frames(60)
	check(loaf.is_on_floor(), "it falls to the floor")
	p.hp = 20
	p.teleport(loaf.global_position)
	await frames(3)
	check(p.hp == 20 + Drop.LOAF_HEAL and not is_instance_valid(loaf), "eaten, it heals %d (%d)" % [Drop.LOAF_HEAL, p.hp])
	room.free()


## Pass 289: as in the source game, a slain Puffcap always leaves bread, even
## with every drop chance at zero, and eating it heals a bread's worth.
func test_a_slain_puffcap_leaves_bread() -> void:
	var room := make_room(["##############################", "#............................#", "#............................#", "#............................#", "#............................#", "##############################"])
	var p := make_player(room, Vector2i(3, 4))
	await frames(5)
	var chances := [Drop.bread_chance, Drop.mana_chance, Drop.rare_chance]
	Drop.bread_chance = 0.0
	Drop.mana_chance = 0.0
	Drop.rare_chance = 0.0
	var m := BogPuffcap.new()
	room.add_child(m)
	m.global_position = cell_feet(20, 4)
	await frames(2)
	m.take_hit(999, Vector2.RIGHT)
	Drop.bread_chance = chances[0]
	Drop.mana_chance = chances[1]
	Drop.rare_chance = chances[2]
	var drops := room.get_children().filter(func(c: Node) -> bool: return c is Drop)
	check(drops.size() == 1 and drops[0].kind == "bread", "it leaves bread, though no drop was rolled (%s)" % [drops.map(func(d: Drop) -> String: return d.kind)])
	if drops.is_empty():
		room.free()
		return
	var bread: Drop = drops[0]
	await frames(60)
	check(bread.is_on_floor(), "it falls to the floor")
	p.hp = 20
	p.teleport(bread.global_position)
	await frames(3)
	check(p.hp == 20 + Drop.BREAD_HEAL and not is_instance_valid(bread), "eaten, it heals %d (%d)" % [Drop.BREAD_HEAL, p.hp])
	room.free()


func test_the_silt_adders_bite_can_be_parried() -> void:
	var rows: Array = ["##############################"]
	for i in 12:
		rows.append("#............................#")
	rows.append("##############################")
	var room := make_room(rows)
	var p := make_player(room, Vector2i(10, 12))
	p.max_hp = 9999
	p.hp = 9999
	p.has_shield = true
	await frames(10)
	var feet := p.global_position
	var n := SiltAdder.new()
	room.add_child(n)
	n.global_position = feet + Vector2(44, -20)
	n.home = n.global_position
	check(n.contact_damage == SiltAdder.TOUCH_DAMAGE and SiltAdder.TOUCH_DAMAGE < SiltAdder.BITE_DAMAGE, "its body only scrapes (%d), the bite is the harm (%d)" % [SiltAdder.TOUCH_DAMAGE, SiltAdder.BITE_DAMAGE])
	var meet := func(parry: bool) -> int:
		p.global_position = feet
		p.facing = 1
		n.global_position = n.home
		n.set_state("float")
		n._cooldown = 0.0
		n.velocity = Vector2.ZERO
		var hp := p.hp
		for i in 90:
			await frames(1)
			if n.state == "strike":
				break
		if parry:
			p.input.block_pressed = true
			p.input.block_held = true
		for i in 20:
			await frames(1)
			p.input.block_pressed = false
		p.input.block_held = false
		return hp - p.hp
	var took: int = await meet.call(true)
	check(took == 0, "a parried bite does no harm (%d)" % took)
	check(n.is_staggered(), "and sets the serpent reeling (%s)" % n.state)
	await frames(90)
	check(not n.is_staggered() and n.state != "stagger", "then it gathers itself (%s)" % n.state)
	took = await meet.call(false)
	check(took == SiltAdder.BITE_DAMAGE, "unmet, the bite lands whole (%d)" % took)


## Pass 337 (bible 4.1, the Stillstone deviation): the source game's glass "can
## stop the movement of the enemy for a fixed period of time". The remake's
## stops what foes loose and time-locked water, and only clockwork foes stop
## dead; the rest go on, so a turn of the glass is a tool, not a pause.
func test_the_stillstone_stops_clockwork_and_lets_other_foes_go_on() -> void:
	var room := _room_with({Vector2i(14, 6): "D", Vector2i(24, 6): "j"})
	var p := make_player(room, Vector2i(3, 6))
	await frames(30)
	var dwarf: Node2D = _find(room, RotDwarf)
	var hound: Node2D = _find(room, ClockworkHound)
	if not check(dwarf != null and hound != null, "a Rot Dwarf and a Clockwork Hound stand in the hall"):
		return
	TimeStop.start()
	var d0 := dwarf.global_position
	var h0 := hound.global_position
	await frames(90)
	check(dwarf.global_position.distance_to(d0) > 4.0, "the dwarf walks on through stopped time (%.0f px)" % dwarf.global_position.distance_to(d0))
	check(hound.global_position.distance_to(h0) < 0.5, "the clockwork hound stops dead (%.1f px)" % hound.global_position.distance_to(h0))
	TimeStop.reset()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("**The Stillstone (deviation, pass 337):**") and p.hp > 0, "bible 4.1 says why the Stillstone lets foes go on")


## Pass 338: bible 7's zone table gave a wind-up for 21 of the 25 foes and a
## health for 12, and no test read any of it. Its numbers table now gives each
## foe's health, touch, first wind-up and main blow; this holds every row to
## the script, and every wind-up, health and touch the zone table's words
## name to the same script.
func test_every_foes_numbers_are_written_in_bible_7() -> void:
	# Foe: [script, wind-up constant, blow: [script, constant] or "contact"].
	const FOES := {
		"Blinkhop": ["blinkhop", "WINDUP", "contact"],
		"Hornet": ["hornet", "WINDUP", "contact"],
		"Rot Dwarf": ["rot_dwarf", "WINDUP", ["rot_dwarf", "SWING_DAMAGE"]],
		"Grub Lump": ["grub_lump", "WINDUP", ["grub_lump", "DROP_DAMAGE"]],
		"Sap Spitter": ["sap_spitter", "WINDUP", ["sap_glob", "DAMAGE"]],
		"Iron Dwarf": ["iron_dwarf", "WINDUP", ["iron_dwarf", "SLAM_DAMAGE"]],
		"Minecart Rider": ["minecart_rider", "REV", ["minecart_rider", "CHARGE_CONTACT"]],
		"Gear Bat": ["gear_bat", "WINDUP", ["gear_blade", "DAMAGE"]],
		"Silt Adder": ["silt_adder", "WINDUP", ["silt_adder", "BITE_DAMAGE"]],
		"Lantern Ghost": ["lantern_ghost", "WINDUP", ["lantern_ghost", "LUNGE_DAMAGE"]],
		"Bog Puffcap": ["bog_puffcap", "WINDUP", ["spore_cloud", "DAMAGE"]],
		"Drowned Dwarf": ["drowned_dwarf", "HEAVE", ["drowned_dwarf", "SLAM_DAMAGE"]],
		"Marsh Hag": ["marsh_hag", "HEX", ["mire_grasp", "DAMAGE"]],
		"Leaf Mantis": ["leaf_mantis", "UNFOLD", ["leaf_mantis", "SLASH_DAMAGE"]],
		"Bark Knight": ["bark_knight", "BRACE", ["bark_knight", "THRUST_DAMAGE"]],
		"Seed Bomber": ["seed_bomber", "WINDUP", ["bomber_seed", "DAMAGE"]],
		"Mothling": ["mothling", "WINDUP", ["mothling", "TOUCH_DAMAGE"]],
		"Storm Harpy": ["storm_harpy", "WINDUP", ["harpy_feather", "DAMAGE"]],
		"Thunder Beetle": ["thunder_beetle", "CHARGE", ["thunder_beetle", "DISCHARGE_DAMAGE"]],
		"Spire Sentinel": ["spire_sentinel", "RAISE", ["spire_sentinel", "SLAM_DAMAGE"]],
		"Crystal Dwarf": ["crystal_dwarf", "WINDUP", ["crystal_dwarf", "FIST_DAMAGE"]],
		"Shade Knight": ["shade_knight", "THRUST_TELL", ["shade_knight", "THRUST_DAMAGE"]],
		"Clockwork Hound": ["clockwork_hound", "WIND", ["clockwork_hound", "BITE_DAMAGE"]],
		"Glass Slug": ["meteor_slug", "SWELL", ["meteor_glob", "DAMAGE"]],
		"Spring Eel": ["spring_eel", "COIL", ["spring_eel", "BITE"]],
	}
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var seven := bible.get_slice("\n## 7. Enemies", 1).get_slice("\n## 8. ", 0)
	var zones := seven.get_slice("| Zone | Enemies |", 1).get_slice("\n\n", 0)
	var table := seven.get_slice("| Foe | HP | Touch | Wind-up (s) | Blow | Gold | XP |", 1).get_slice("\n\n", 0)
	# Every foe in scripts/enemies has a row (the Stillglass Seed is a dying foe's
	# burst, 8.9, not a foe).
	for f: String in DirAccess.get_files_at("res://scripts/enemies"):
		if not f.ends_with(".gd") or f in ["enemy.gd", "meteor_seed.gd"]:
			continue
		var s: Script = load("res://scripts/enemies/" + f)
		if s.get_base_script() == Enemy:
			check(FOES.values().any(func(v: Array) -> bool: return v[0] + ".gd" == f), "bible 7's numbers table has a row for %s" % f)
	for foe: String in FOES:
		var spec: Array = FOES[foe]
		var script: Script = load("res://scripts/enemies/%s.gd" % spec[0])
		var consts := script.get_script_constant_map()
		var e: Enemy = script.new()
		var tell: float = consts[spec[1]]
		var blow: int = e.contact_damage if spec[2] is String else load("res://scripts/enemies/%s.gd" % spec[2][0]).get_script_constant_map()[spec[2][1]]
		# A foe that lies hidden (a sunk dwarf, a folded mantis, a rising imp)
		# touches for nothing until it shows itself.
		var touch: int = e.contact_damage if e.contact_damage > 0 else consts.get("CONTACT", consts.get("TOUCH_DAMAGE", 0))
		var row := table.get_slice("\n| %s | " % foe, 1).get_slice("\n", 0)
		var cells := row.split(" | ")
		check(cells.size() == 6, "bible 7's numbers table has a row for the %s" % foe)
		if cells.size() == 6:
			check(int(cells[0]) == e.max_hp, "%s's health: the bible says %s, the script %d" % [foe, cells[0], e.max_hp])
			check(int(cells[1]) == touch, "%s's touch: the bible says %s, the script %d" % [foe, cells[1], touch])
			check(is_equal_approx(float(cells[2]), tell), "%s's wind-up: the bible says %s, the script %s" % [foe, cells[2], tell])
			check(cells[3].begins_with("%d (" % blow), "%s's blow: the bible says %s, the script %d" % [foe, cells[3], blow])
			# What it pays (pass 378): its purse before the zone's threat, and
			# its experience, which no threat scales.
			check(cells[4] == "%d to %d" % [e.gold_min, e.gold_max], "%s's gold: the bible says %s, the script %d to %d" % [foe, cells[4], e.gold_min, e.gold_max])
			check(int(cells[5]) == e.xp and e.xp > 0, "%s's experience: the bible says %s, the script %d" % [foe, cells[5], e.xp])
		check(tell >= Enemy.MIN_TELEGRAPH, "%s's wind-up is fair" % foe)
		# The zone table's own words, between the foe's name and its closing
		# bracket, name the same wind-up and any health or touch they give.
		var words := _bracketed(zones, foe + " (")
		check(words != "", "bible 7's zone table describes the %s" % foe)
		check(words.contains("%s s" % String.num(tell)), "the zone table gives the %s's wind-up (%s s)" % [foe, tell])
		var re := RegEx.create_from_string("(\\d+) HP|HP (\\d+)")
		for m: RegExMatch in re.search_all(words):
			var hp := int(m.get_string(1) if m.get_string(1) != "" else m.get_string(2))
			check(hp == e.max_hp, "the zone table gives the %s %d HP, the script %d" % [foe, hp, e.max_hp])
		re = RegEx.create_from_string("(?:contact|touch) (\\d+)")
		for m: RegExMatch in re.search_all(words):
			check(int(m.get_string(1)) == touch, "the zone table gives the %s a touch of %s, the script %d" % [foe, m.get_string(1), touch])
		e.free()
	# Bible 9's word on the first foes' experience is the scripts'.
	var mono := Blinkhop.new()
	var rot := RotDwarf.new()
	check(bible.contains("Starting enemies give %d XP (Rot Dwarf %d)" % [mono.xp, rot.xp]), "bible 9 gives the first foes' experience (%d, Rot Dwarf %d)" % [mono.xp, rot.xp])
	mono.free()
	rot.free()
	# A real kill pays what the row says: its experience as written, and its
	# gold times its room's threat (a Vorrhallow room, threat 2).
	var room := Room.from_text("zone: vorrhallow\n---\n" + "\n".join(PackedStringArray(WIDE)))
	arena.add_child(room)
	var p := make_player(room, Vector2i(3, 6))
	p.max_hp = 9999
	p.hp = 9999
	check(room.threat() == 2.0, "a Vorrhallow room's threat is 2")
	var rare := Drop.rare_chance
	Drop.rare_chance = 0.0
	for i in 6:
		var foe := Blinkhop.new()
		foe.position = cell_feet(20, 6)
		room.add_child(foe)
		await frames(2)
		var xp: int = GameState.data.xp
		foe.take_hit(foe.hp, Vector2.RIGHT)
		await frames(2)
		var gold := 0
		for n in room.get_children():
			if n is Coin:
				gold += (n as Coin).value
				n.free()
		check(int(GameState.data.xp) - xp == foe.xp, "a slain Blinkhop pays its %d XP, unscaled (got %d)" % [foe.xp, int(GameState.data.xp) - xp])
		check(gold >= foe.gold_min * 2 and gold <= foe.gold_max * 2, "and %d to %d gold at threat 2 (got %d)" % [foe.gold_min * 2, foe.gold_max * 2, gold])
	Drop.rare_chance = rare


## The text after `opening` up to its matching closing bracket (brackets in
## `code`, such as a legend, don't count), or "".
func _bracketed(text: String, opening: String) -> String:
	var at := text.find(opening)
	if at < 0:
		return ""
	var depth := 1
	var code := false
	var i := at + opening.length()
	while i < text.length():
		var c := text[i]
		if c == "`":
			code = not code
		elif code:
			pass
		elif c == "(":
			depth += 1
		elif c == ")":
			depth -= 1
			if depth == 0:
				return text.substr(at + opening.length(), i - at - opening.length())
		i += 1
	return ""


## Pass 354 (bible 6.7 Flash, 7): a tell is a pose, a flash and a sound, and
## since pass 161 the flash washes the foe's own silhouette white in pulses.
## The Clockwork Hound, the Shade Knight, the Glass Slug and the Spring Eel lit
## only a part (eyes, blade point, cracks, lamp), so their tells never flashed
## the way every other foe's did. Every foe's every tell now pulses white.
func test_every_foes_tell_flashes_it_white() -> void:
	var tell_re := RegEx.create_from_string("windup|tell|^wind$|^coil$|^rev$|^unfold$|^gather$|^swell$|^raise$|^charge$")
	# A state set by name, or a Shade Knight's tell opened by `_open`.
	var set_re := RegEx.create_from_string("(?:set_state|_open)\\(\"([a-z_0-9]+)\"")
	var room := make_room(grid_rows(30, 14).map(func(r: Array) -> String: return "".join(PackedStringArray(r))))
	var p := make_player(room, Vector2i(4, 10))
	await frames(2)
	var dark: Array[String] = []
	var named: Array[String] = []
	var seen := 0
	for f in DirAccess.get_files_at("res://scripts/enemies"):
		if not f.ends_with(".gd"):
			continue
		var script := load("res://scripts/enemies/" + f) as GDScript
		if not script.can_instantiate():
			continue
		var probe: Object = script.new()
		var foe := probe is Enemy
		if probe is Node:
			(probe as Node).free()
		# A Stillglass Seed is a crystal shard, not a body: its flicker is the
		# shard itself going light and dark.
		if not foe or f == "meteor_seed.gd":
			continue
		var tells := {}
		for m in set_re.search_all(script.source_code):
			# The Minecart Rider's charge is its run; its tell is the rev.
			if tell_re.search(m.get_string(1)) != null and not (f == "minecart_rider.gd" and m.get_string(1) == "charge"):
				tells[m.get_string(1)] = true
		if tells.is_empty():
			continue
		for tell: String in tells:
			var e: Enemy = script.new()
			e.position = Vector2(16 * 16, 11 * 16)
			room.add_child(e)
			await frames(1)
			e.set_physics_process(false)
			e.set_state(tell)
			e.state_time = 0.01
			e.queue_redraw()
			await frames(1)
			seen += 1
			named.append("%s %s" % [f.get_basename(), tell])
			if not e.drawn_white():
				dark.append("%s %s" % [f.get_basename(), tell])
			e.free()
	check(seen >= 27, "found the foes' tells (%d: %s)" % [seen, named])
	check(dark.is_empty(), "every foe's tell washes it white (%s)" % [dark])
	p.queue_free()


## Art pass 2 (docs/art/enemy-style-guide.md 4): the Heartwood and Hollin Tower foes remade in
## PixelLab play an animation of their own sheet for every state, flinch when hit, reel when
## staggered and collapse under the dissolve.
func test_batch_one_foes_play_an_animation_for_every_state() -> void:
	var foes := [
		[SapSpitter, "T", Vector2i(20, 6), "sap_spitter", ["idle", "windup", "spit"], {"windup": "windup", "spit": "spit"}],
		[GrubLump, "U", Vector2i(20, 6), "grub_lump", ["crawl", "windup", "drop", "land"], {"windup": "windup", "drop": "drop", "land": "land"}],
		[GearBat, "B", Vector2i(20, 1), "gear_bat", ["roost", "wake", "hover", "windup", "bare"], {"roost": "roost", "windup": "windup", "hover": "fly"}],
		[MinecartRider, "K", Vector2i(20, 6), "minecart_rider", ["roll", "rev", "charge", "crash", "recover"], {"rev": "rev", "charge": "charge", "crash": "crash"}],
		[SiltAdder, ")", Vector2i(20, 4), "silt_adder", ["float", "coil", "strike", "return"], {"coil": "coil", "strike": "strike", "float": "float"}],
	]
	for f: Array in foes:
		var room := _room_with({f[2]: f[1]})
		make_player(room, Vector2i(3, 6))
		var e: Enemy = _find(room, f[0])
		await frames(3)
		var sheet: String = f[3]
		check(Sheet.exists(sheet), "%s: its sheet is in the game" % sheet)
		for s: String in f[4]:
			e.set_state(s)
			var a: String = e.anim_now()[0]
			check(Sheet.has_anim(sheet, a), "%s: %s plays %s, which the sheet has" % [sheet, s, a])
			if f[5].has(s):
				check(a == f[5][s], "%s: %s plays its own pose, %s (got %s)" % [sheet, s, f[5][s], a])
		e.set_state(f[4][0])
		e.take_hit(1, Vector2(-1, 0))
		check(Sheet.has_anim(sheet, e.anim_now()[0]) and e.anim_now()[0] == "hurt", "%s: a blow makes it flinch" % sheet)
		e._hitstun = 0.0
		e.die()
		check(e.anim_now()[0] == "death" and Sheet.has_anim(sheet, "death"), "%s: it collapses as it dissolves" % sheet)
		room.queue_free()
		await frames(1)


## Art loop pass 4 (docs/art/enemy-style-guide.md 4): `foe` plays an animation its sheet has
## in each of `states`, the tell's pose is not the idle's, and a blow, a parry and death
## each show their own.
func _plays_every_state(foe: Enemy, sheet: String, states: Array, tell: String, idle: String) -> void:
	check(Sheet.exists(sheet), "%s's sheet is in the game" % sheet)
	for s: String in states:
		foe.set_state(s)
		var a: String = foe.anim_now()[0]
		check(Sheet.has_anim(sheet, a), "%s: %s plays %s, which the sheet has" % [sheet, s, a])
	foe.set_state(tell)
	check(foe.anim_now()[0] != idle, "%s: the tell (%s) is its own pose, not the %s" % [sheet, tell, idle])
	foe.set_state(states[0])
	foe.take_hit(1, Vector2(-1, 0))
	var hurt: String = foe.anim_now()[0]
	check(hurt.ends_with("hurt") and Sheet.has_anim(sheet, hurt), "%s flinches from a blow (%s)" % [sheet, hurt])
	foe._hitstun = 0.0
	foe.stagger()
	var reel: String = foe.anim_now()[0]
	check(Sheet.has_anim(sheet, reel) and reel != idle, "%s reels when parried (%s)" % [sheet, reel])
	foe.die()
	var death: String = foe.anim_now()[0]
	check(death.ends_with("death") and Sheet.has_anim(sheet, death), "%s collapses as it dissolves" % sheet)


func test_leaf_mantis_plays_an_animation_for_every_state() -> void:
	var room := _room_with({Vector2i(20, 6): "m"})
	make_player(room, Vector2i(3, 6))
	var m: LeafMantis = _find(room, LeafMantis)
	await frames(3)
	_plays_every_state(m, "leaf_mantis", ["stalk", "hide", "unfold", "lunge", "recover"], "unfold", "idle")
	m.set_state("hide")


func test_bark_knight_plays_an_animation_for_every_state_in_bark_and_bare() -> void:
	var room := _room_with({Vector2i(20, 6): "!"})
	make_player(room, Vector2i(3, 6))
	var k: BarkKnight = _find(room, BarkKnight)
	await frames(3)
	var states := ["walk", "windup", "thrust", "rooted"]
	for s: String in states:
		k.set_state(s)
		check(Sheet.has_anim("bark_knight", k.anim_now()[0]), "in bark, %s plays %s" % [s, k.anim_now()[0]])
	k.bark = 0
	for s: String in states:
		k.set_state(s)
		var a: String = k.anim_now()[0]
		check(a.begins_with("bare_") and Sheet.has_anim("bark_knight", a), "bare, %s plays %s" % [s, a])
	k.set_state("windup")
	check(k.anim_now()[0] == "bare_brace", "bare, he still braces before the thrust")
	k.bark = BarkKnight.BARK
	_plays_every_state(k, "bark_knight", states, "windup", "idle")


func test_seed_bomber_plays_an_animation_for_every_state() -> void:
	var room := _room_with({Vector2i(20, 3): ";"})
	make_player(room, Vector2i(3, 6))
	var b: SeedBomber = _find(room, SeedBomber)
	await frames(3)
	_plays_every_state(b, "seed_bomber", ["hover", "windup", "drop", "rise"], "windup", "fly")
	var b2 := SeedBomber.new()
	room.add_child(b2)
	b2.global_position = Vector2(200, 40)
	b2.set_state("downed")
	check(b2.anim_now()[0] == "fall", "knocked out of the sky, it tumbles")
	b2._landed = true
	check(b2.anim_now()[0] == "downed", "landed, it lies dazed on its back")


func test_mothling_plays_an_animation_for_every_state() -> void:
	var room := _room_with({})
	make_player(room, Vector2i(3, 6))
	var m := Mothling.new()
	room.add_child(m)
	m.global_position = Vector2(200, 40)
	await frames(3)
	_plays_every_state(m, "mothling", ["rise", "hover", "windup", "dive"], "windup", "fly")


## Bible 6.15: the Shade Knight's combo is a thrust at the chest, then a high
## cut at the head. A crouch ducks the cut but not the thrust; standing, both land.
func test_a_crouch_ducks_the_shade_knights_high_cut_but_not_his_thrust() -> void:
	for crouched: bool in [true, false]:
		var room := _room_with({Vector2i(22, 6): "e"})
		var p := make_player(room, Vector2i(3, 6))
		p.max_hp = 9999
		p.hp = 9999
		var k: ShadeKnight = _find(room, ShadeKnight)
		await frames(3)
		p.teleport(Vector2(k.global_position.x - 40.0, 7 * 16))
		p.input.down = crouched
		var hp := p.hp
		var after_thrust := -1
		var high_rect := Rect2()
		for i in 200:
			await frames(1)
			if k.state == "cut_tell" and after_thrust < 0:
				after_thrust = p.hp
				# Fresh from the thrust's blow, and back in his reach.
				p._invuln_timer = 0.0
				p.teleport(Vector2(k.global_position.x + k.facing * 40.0, 7 * 16))
			if k.state == "cut":
				high_rect = k.blade_rect()
			if k.state == "winded":
				break
		var who := "crouched" if crouched else "standing"
		check(after_thrust >= 0 and after_thrust < hp, "%s, the thrust lands (%d)" % [who, hp - after_thrust])
		if crouched:
			check(p.crouching, "still crouched")
			check(p.hp == after_thrust, "and the high cut passes over the crouch (%d)" % (after_thrust - p.hp))
			check(high_rect.end.y < p.global_position.y - MovementTuning.new().crouch_height, "the cut's blade runs above a crouched head")
		else:
			check(p.hp < after_thrust, "and the high cut lands on a standing hero (%d)" % (after_thrust - p.hp))
		room.free()
		await frames(1)


## Bible 6.15: a Silt Adder draws its head level with yours, so its strike along
## that level goes over a hero crouched on the ground, and glides back harmless.
## Standing, the same strike bites.
func test_a_crouch_ducks_the_silt_adders_strike() -> void:
	for crouched: bool in [true, false]:
		var room := make_room(WIDE)
		var p := make_player(room, Vector2i(6, 6))
		p.max_hp = 9999
		p.hp = 9999
		p.has_shield = false
		p.input.down = crouched
		await frames(10)
		var feet := p.global_position
		var n := SiltAdder.new()
		room.add_child(n)
		n.global_position = feet + Vector2(64, -Enemy.HEAD_HEIGHT)
		n.home = n.global_position
		n._phase = 0.0
		var hp := p.hp
		var struck := false
		var lowest := -INF
		for i in 300:
			p.global_position.x = feet.x
			await frames(1)
			if n.state == "strike":
				struck = true
				lowest = maxf(lowest, n.bite_rect().end.y)
			if struck and n.state == "float":
				break
		var who := "crouched" if crouched else "standing"
		check(struck, "%s: it strikes" % who)
		if crouched:
			check(p.crouching, "the hero stayed crouched")
			check(p.hp == hp, "and the strike and the glide back pass over the crouch (%d)" % (hp - p.hp))
			check(lowest < feet.y - MovementTuning.new().crouch_height, "the bite runs above a crouched head (%.1f)" % (feet.y - lowest))
		else:
			check(p.hp < hp, "and it bites a standing hero (%d)" % (hp - p.hp))
		room.free()
		await frames(1)

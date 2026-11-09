extends TestSuite
## RoomLight: the drawn emissive light pools fixed scenery casts onto the floor and
## walls (design bible 12.10). The pure gradient maths and the once-per-room collect
## are tested here, so the on-screen pools are backed by tested logic and stay inside
## the combat-readability cap.

const RUNE := Color("7ee0d6") ## the save shrine's rune colour


func test_roomlight_falloff_fades_from_centre_to_edge() -> void:
	# A pool is one radial sprite whose brightness is `falloff` of the distance from
	# the centre: full at the centre, nothing at the rim, and strictly fading between,
	# so it reads as a soft bloom with no hard edge or banding.
	check_near(RoomLight.falloff(0.0), 1.0, 0.0001, "full brightness at the centre")
	check_near(RoomLight.falloff(1.0), 0.0, 0.0001, "nothing at the rim")
	var last := INF
	for i in 11:
		var t := float(i) / 10.0
		var v := RoomLight.falloff(t)
		check(v <= last + 0.0001, "the pool only ever fades outward")
		check(v >= -0.0001 and v <= 1.0001, "brightness stays within 0..1")
		last = v
	check(RoomLight.falloff(0.5) < 1.0 and RoomLight.falloff(0.5) > 0.0, "the pool is partway lit at its half radius")


func test_roomlight_pool_peaks_at_its_source() -> void:
	# The shaped pool is still full brightness at the source (nx = ny = 0), so the
	# centre adds exactly colour * peak and the readability cap (12.10) is unchanged
	# — the shaping bends where the light falls, not how bright the source is.
	check_near(RoomLight.shaped_alpha(0.0, 0.0), 1.0, 0.0001, "full brightness at the source")


func test_roomlight_pool_casts_down_not_up() -> void:
	# A lantern or glow-mushroom casts its pool onto the ground below, not up into the
	# empty air above: at the same distance the pool is brighter below the source than
	# above it, so it reads as light hitting a surface, not a floating disc.
	for d: float in [0.3, 0.5, 0.7]:
		var below := RoomLight.shaped_alpha(0.0, d)
		var above := RoomLight.shaped_alpha(0.0, -d)
		check(below > above + 0.01, "the pool is brighter below the source than above (%.1f)" % d)


func test_roomlight_pool_tightens_above_the_source() -> void:
	# Above the source the glow reaches far less far than a plain symmetric disc would,
	# so it stops reading as a blob glowing equally in every direction.
	for d: float in [0.3, 0.4, 0.6]:
		check(RoomLight.shaped_alpha(0.0, -d) < RoomLight.falloff(d) - 0.01,
			"the upward reach is tighter than a plain circle (%.1f)" % d)


func test_roomlight_pool_widens_across_the_floor() -> void:
	# Where the pool lands it spreads sideways: at equal distance from the source, a
	# point out across the floor stays lit where a point straight down has faded, so
	# the cast pool reads as wider than it is deep (the ground spread). Mutation-
	# checked: with no ground spread the sideways point is the dimmer of the two.
	var across := RoomLight.shaped_alpha(0.6, 0.3) ## out across the floor
	var down := RoomLight.shaped_alpha(0.0, 0.67) ## straight down, same distance
	check(across > down + 0.01, "the pool spreads wider across the floor than straight down")


func test_roomlight_no_pool_blows_out() -> void:
	# Both pool brightnesses (a group source at the cap, a decor glow below it) stay
	# at or under the readability cap, so a pool only ever tints the scene.
	check(RoomLight.READABLE_CAP <= 0.16, "the cap stays gentle")
	check(RoomLight.DECOR_PEAK <= RoomLight.READABLE_CAP, "a decor glow is no brighter than the cap")


func test_roomlight_source_glow_reads_then_falls_back() -> void:
	# A source's colour and reach come off the node; a node without them still lights
	# with warm defaults, so a source that joins the group but forgets a field is safe.
	var shrine := SaveShrine.new()
	var g := RoomLight.source_glow(shrine)
	check((g.color as Color).is_equal_approx(RUNE), "the shrine's own rune colour is read")
	check_near(g.radius, 96.0, 0.01, "the shrine's own reach is read")
	shrine.free()
	var bare := Node2D.new()
	var d := RoomLight.source_glow(bare)
	check((d.color as Color).is_equal_approx(RoomLight.DEFAULT_COLOR), "a bare node falls back to the default colour")
	check_near(d.radius, RoomLight.DEFAULT_RADIUS, 0.01, "a bare node falls back to the default reach")
	bare.free()


func test_roomlight_room_pools_its_shrine() -> void:
	# A room with a save shrine builds a RoomLight that pools the shrine's rune light.
	var rows := grid_rows(14, 9)
	put_tiles(rows, 5, 5, "S")
	var room := Room.from_text("\n".join(PackedStringArray(_lines(rows))))
	arena.add_child(room)
	await frames(2)
	var rl := room.get_node_or_null("RoomLight") as RoomLight
	check(rl != null, "the room built a RoomLight overlay")
	if rl == null:
		return
	check(rl._pools.size() >= 1, "it gathered at least one light pool")
	var found := false
	for pool: Array in rl._pools:
		if (pool[1] as Color).is_equal_approx(RUNE):
			found = true
			check(pool[3] <= RoomLight.READABLE_CAP, "the shrine pool stays under the readability cap")
	check(found, "the shrine casts a rune-coloured pool")


func test_roomlight_pool_sits_under_actors() -> void:
	# The overlay is added before the room's sources and decor, so by tree order it
	# draws under every actor: a pool lights the ground a foe stands on, not the foe.
	var rows := grid_rows(14, 9)
	put_tiles(rows, 5, 5, "S")
	var room := Room.from_text("\n".join(PackedStringArray(_lines(rows))))
	arena.add_child(room)
	await frames(2)
	var rl := room.get_node_or_null("RoomLight")
	var shrine: Node = null
	for c in room.get_children():
		if c is SaveShrine:
			shrine = c
	check(shrine != null, "the shrine was placed")
	if rl != null and shrine != null:
		var kids := room.get_children()
		check(kids.find(rl) < kids.find(shrine), "the light overlay draws before (under) the actors")


func test_roomlight_projectile_not_lit() -> void:
	# Dynamic lights live in the fog's "light" group, not "room_light": a fireball
	# thrown through a room must never drag a pool across the floor.
	var rows := grid_rows(14, 9)
	put_tiles(rows, 5, 5, "S")
	var room := Room.from_text("\n".join(PackedStringArray(_lines(rows))))
	arena.add_child(room)
	await frames(2)
	var rl := room.get_node_or_null("RoomLight") as RoomLight
	check(rl != null, "the room built a RoomLight overlay")
	if rl == null:
		return
	var before := rl._pools.size()
	var fireball := Fireball.new()
	fireball.position = Vector2(100, 60)
	room.add_child(fireball)
	await frames(1)
	rl._collect()
	check(rl._pools.size() == before, "the fireball added no light pool")


## Grid rows (arrays of cells) to room-text lines.
func _lines(rows: Array) -> Array:
	var out := []
	for row: Array in rows:
		out.append("".join(PackedStringArray(row)))
	return out

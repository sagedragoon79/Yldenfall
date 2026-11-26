extends TestSuite
## Pass 550: what wades in Vorrhallow's standing water breaks its surface (design
## bible 4.4). A waterline crosses the body, ripples spread from it (more often
## while it moves), and the water darkens toward the floor in dithered steps.


func _hall(at := Vector2i(10, 19)) -> World:
	var w := make_world({}, "vorrhallow/flooded_hall", cell_feet(at.x, at.y))
	for c in w.room.get_children():
		if c is Enemy:
			c.queue_free()
	return w


func test_ripples_spread_and_fade() -> void:
	var prev := -1.0
	var spreading := true
	var fading := true
	var prev_a := 2.0
	for i in 11:
		var age := Tide.RING_LIFE * float(i) / 10.0
		var r := Tide.ring_reach(8.0, age)
		var a := Tide.ring_alpha(age)
		spreading = spreading and r > prev
		fading = fading and a < prev_a
		prev = r
		prev_a = a
	check(spreading, "a ripple only spreads outward")
	check(fading, "and only fades")
	check(Tide.ring_reach(8.0, 0.0) > 8.0, "it starts just past the body's edge")
	check(Tide.ring_alpha(Tide.RING_LIFE) == 0.0, "and is gone at the end of its life")
	check(Tide.wades(Rect2(0, 10, 10, 40), 30.0), "a box across the surface wades")
	check(not Tide.wades(Rect2(0, -40, 10, 40), 30.0), "one above it does not")
	check(not Tide.wades(Rect2(0, 31, 10, 40), 30.0), "nor one under it")


func test_water_lightens_under_the_surface_and_darkens_to_the_floor() -> void:
	var top := Tide.level_color(Tide.depth_level(0, 0))
	var bottom := Tide.level_color(Tide.depth_level(0, Room.TILE - 1))
	check(Tide.depth_level(0, 0) == 0 and Tide.depth_level(0, Room.TILE - 1) == Tide.LEVELS - 1, "shallowest at the surface, deepest at the floor")
	check(bottom.v < top.v and bottom.a > top.a, "the floor end is darker and denser")
	var mixed := 0
	var jumps := 0
	for d in range(2, Room.TILE - 2):
		for x in range(0, 4, Tide.GRAIN):
			var a := Tide.depth_level(x, d)
			var b := Tide.depth_level(x + Tide.GRAIN, d)
			mixed += 1 if a != b else 0
			jumps += 1 if absi(a - b) > 1 else 0
	check(mixed > 4, "the steps are dithered (%d mixed neighbours)" % mixed)
	check(jumps == 0, "neighbouring blocks differ by one step at most")
	var strip := Tide.body_strip()
	check(strip.get_height() == Room.TILE, "the strip is one tile deep")


func test_the_hero_wading_breaks_the_surface() -> void:
	var w := _hall()
	await frames(10)
	var tide: Tide = w.room.tide
	var p := w.player
	check(w.room.surface_at(p.global_position + Vector2(0, 2)) == "wade", "the hero stands in the water")
	var x := tide.to_local(p.global_position).x
	var line := false
	for wake: Array in tide.wakes:
		line = line or absf(float(wake[0]) - x) < 4.0
	check(line, "a waterline crosses the hero (%s)" % [tide.wakes])
	var near := 0
	for ring: Array in tide.rings:
		near += 1 if absf(float(ring[0]) - x) < 4.0 else 0
	check(near >= 1, "and a ripple has left the hero (%d)" % near)
	# Standing, one ripple a WAKE_STILL; running, one a WAKE_MOVING.
	tide.rings.clear()
	await frames(int(Tide.RING_LIFE * 60.0))
	var still := tide.rings.size()
	tide.rings.clear()
	p.input.move_x = 1
	await frames(int(Tide.RING_LIFE * 60.0))
	p.input.move_x = 0
	var moving := tide.rings.size()
	check(moving > still, "running sends ripples out faster than standing (%d against %d)" % [moving, still])


func test_nothing_out_of_the_water_makes_a_wake() -> void:
	var w := _hall()
	await frames(6)
	var tide: Tide = w.room.tide
	w.player.teleport(w.player.global_position - Vector2(0, Room.TILE * 6))
	w.player.velocity = Vector2.ZERO
	await frames(2)
	tide.rings.clear()
	await frames(2)
	check(tide.wakes.is_empty(), "a hero in the air above the water draws no waterline")
	check(tide.rings.is_empty(), "and sends no ripples")


func test_a_foe_wading_breaks_the_surface_too() -> void:
	var w := make_world({}, "vorrhallow/flooded_hall", cell_feet(4, 15))
	await frames(10)
	var tide: Tide = w.room.tide
	var foe: Enemy = null
	for c in w.room.get_children():
		if c is Enemy and tide.has_point((c as Enemy).global_position + Vector2(0, -4)):
			foe = c
	check(foe != null, "a foe stands in the hall's water")
	if foe == null:
		return
	var x := tide.to_local(foe.global_position).x
	var line := false
	for wake: Array in tide.wakes:
		line = line or absf(float(wake[0]) - x) < 8.0
	check(line, "a waterline crosses it")


func test_the_drained_hall_has_no_wake() -> void:
	var w := _hall()
	GameState.set_flag(Tide.DRAIN_FLAG)
	await frames(10)
	var tide: Tide = w.room.tide
	check(tide.wakes.is_empty() and tide.rings.is_empty(), "drained, nothing wades")
	GameState.data.flags.erase(Tide.DRAIN_FLAG)


## Pass 559 (bible 12.49): the water is drawn in front of the spikes in its pits and
## dimmed their steel rim. It draws the rim again over itself, so what hurts shows.
func test_spikes_under_the_water_keep_their_rim() -> void:
	var w := _hall()
	await frames(3)
	var tide: Tide = w.room.tide
	var in_pit := 0
	for c in w.room.get_children():
		if c is Spikes and tide.has_point((c as Spikes).global_position + Vector2(0, -4)):
			in_pit += 1
	var sunk := tide.sunk_spikes()
	check(in_pit >= 4, "the hall's pit holds spikes under water (%d)" % in_pit)
	check(sunk.size() == in_pit, "the water knows each of them (%d of %d)" % [sunk.size(), in_pit])
	for at: Vector2 in sunk:
		check(tide.has_point(tide.to_global(at) + Vector2(0, -4)), "and each one it knows stands in it")
	# A cluster out of the water is the spikes' own business.
	var dry := Spikes.new()
	w.room.add_child(dry)
	dry.global_position = Vector2(cell_feet(10, 10))
	await frames(2)
	check(tide.sunk_spikes().size() == in_pit, "a cluster above the water is not the water's to draw")
	# One set down in the water later (a pit that opens) is found.
	var late := Spikes.new()
	w.room.add_child(late)
	late.global_position = tide.to_global(Vector2(12.5 * Room.TILE, (tide.row + 1) * Room.TILE))
	await frames(2)
	check(tide.sunk_spikes().size() == in_pit + 1, "one that comes to stand in it later is found")
	# The rim through the water is near the steel's own value, far from the pit's.
	var pit := Tide.pit_color()
	var dimmed := Spikes.RIM.lerp(Color(pit, 1.0), pit.a)
	var shown := Tide.sunk_rim_color()
	check(Tide.SUNK_RIM >= 0.8, "the rim is drawn again nearly whole")
	check(shown.get_luminance() >= 0.8, "it shows near white (%.2f)" % shown.get_luminance())
	check(shown.get_luminance() - dimmed.get_luminance() >= 0.25, "well above the rim the water dimmed (%.2f over %.2f)" % [shown.get_luminance(), dimmed.get_luminance()])
	GameState.set_flag(Tide.DRAIN_FLAG)
	await frames(2)
	check(tide.sunk_spikes().is_empty(), "drained, the spikes stand dry and draw their own rim")
	GameState.data.flags.erase(Tide.DRAIN_FLAG)


## Pass 639 (bible 12.115): the pass 635 grade saw the flooded hall's water as a flat
## band with no reflection. The still water mirrors what stands over it: the world
## above the surface, upside down, dimmed toward the water's tone, laid over each run
## of the surface row, strongest just under the line and gone at the row's floor.
func test_the_still_water_mirrors_what_stands_over_it() -> void:
	var w := _hall()
	await frames(3)
	var tide: Tide = w.room.tide
	var runs := tide.surface_runs()
	check(runs.size() >= 2, "the hall's surface comes in runs between its stone (%d)" % runs.size())
	check(tide.reflections.size() == runs.size(), "one mirror to each run (%d of %d)" % [tide.reflections.size(), runs.size()])
	var covered := 0
	for i in mini(runs.size(), tide.reflections.size()):
		var run: Array = runs[i]
		var r: ColorRect = tide.reflections[i]
		var y := tide.surface_y()
		check(r.position.x == int(run[0]) * Room.TILE and r.size.x == (int(run[1]) - int(run[0]) + 1) * Room.TILE, "a mirror spans its run exactly")
		check(r.position.y == y + Tide.REFLECT_FROM and r.position.y + r.size.y == y + Room.TILE, "and lies under the surface line, down to the row's floor")
		covered += int(run[1]) - int(run[0]) + 1
		var mat := r.material as ShaderMaterial
		check(mat != null and "hint_screen_texture" in mat.shader.code, "it shows the world behind the water")
		check("2.0 * k + 1.0" in mat.shader.code, "mirrored about the surface line")
		check(is_equal_approx(float(mat.get_shader_parameter("alpha")), Tide.REFLECT_ALPHA), "at the mirror's strength")
	var cols := 0
	for c: Vector2i in tide.cells:
		cols += 1 if c.y == tide.row else 0
	check(covered == cols, "the mirrors cover the whole surface row and nothing else (%d of %d)" % [covered, cols])
	# Strongest just under the line, fading to nothing at the row's floor.
	check(Tide.reflect_alpha(0) == 0.0 and Tide.reflect_alpha(Tide.REFLECT_FROM - 1) == 0.0, "the line and its glints stay clear")
	check(is_equal_approx(Tide.reflect_alpha(Tide.REFLECT_FROM), Tide.REFLECT_ALPHA), "the mirror is strongest just under them")
	var fading := true
	for k in range(Tide.REFLECT_FROM + 1, Room.TILE):
		fading = fading and Tide.reflect_alpha(k) < Tide.reflect_alpha(k - 1)
	check(fading, "and only fades with depth")
	check(Tide.reflect_alpha(Room.TILE) <= 0.001, "gone at the row's floor")
	check(Tide.REFLECT_ALPHA < 0.75, "a dim mirror: the water stays water")
	# It moves with the tide's clock.
	var t0 := float((tide.reflections[0].material as ShaderMaterial).get_shader_parameter("time"))
	await frames(5)
	var t1 := float((tide.reflections[0].material as ShaderMaterial).get_shader_parameter("time"))
	check(t1 > t0, "its sway runs on the tide's clock")
	# Drained, there is nothing to mirror.
	GameState.set_flag(Tide.DRAIN_FLAG)
	await frames(3)
	check(tide.reflections.is_empty(), "the drained hall mirrors nothing")
	GameState.data.flags.erase(Tide.DRAIN_FLAG)


## Pass 658 (bible 12.134): the pass 655 grade saw a foe half under the flooded hall's
## cyan band. The water clears over whatever wades in it, body and mirror, so the legs
## show through; a column either side is half way back, and the rest stays water.
func test_the_water_clears_over_a_wader() -> void:
	var s := Tide.clear_span(50.0, 6.0)
	check(s.x <= 50.0 - 6.0 - Tide.CLEAR_PAD and s.y >= 50.0 + 6.0 + Tide.CLEAR_PAD, "the span covers the body and a little past it (%s)" % s)
	check(int(s.x) % Tide.CHUNK == 0 and int(s.y) % Tide.CHUNK == 0, "in whole columns of the dither")
	var spans: Array[Vector2] = [s]
	check(is_equal_approx(Tide.clarity_at(50.0, spans), Tide.CLEAR), "over the body the water is cleared")
	check(Tide.CLEAR <= 0.5, "to half its strength or less")
	var edge := Tide.clarity_at(s.y + Tide.CHUNK * 0.5, spans)
	check(edge > Tide.CLEAR and edge < 1.0, "a column beside it is half way back (%.2f)" % edge)
	check(Tide.clarity_at(s.y + Tide.CHUNK * 1.5, spans) == 1.0, "and past that the water is whole")
	check(Tide.clarity_at(50.0, [] as Array[Vector2]) == 1.0, "with nobody in it the water is whole")
	var w := _hall()
	await frames(10)
	var tide: Tide = w.room.tide
	var x := tide.to_local(w.player.global_position).x
	var over := false
	for c in tide.clear_spans:
		over = over or (c.x < x and c.y > x)
	check(over, "the water clears over the hero wading")
	check(tide.clear_spans.size() == tide.wakes.size(), "one clearing to each wader")
	var mat := tide.reflections[0].material as ShaderMaterial
	check(int(mat.get_shader_parameter("clear_n")) == tide.clear_spans.size(), "and the mirror clears there too")
	check("clear_k" in mat.shader.code and is_equal_approx(float(mat.get_shader_parameter("clear_k")), Tide.CLEAR), "by as much")
	GameState.set_flag(Tide.DRAIN_FLAG)
	await frames(3)
	check(tide.clear_spans.is_empty(), "drained, there is nothing to clear")
	GameState.data.flags.erase(Tide.DRAIN_FLAG)


## Pass 666 (bible 12.143): the pass 665 grade saw the flooded hall's band with nothing
## round the feet. The water climbs a wader's legs, a moving one pushes a bow wave and
## stirs silt behind it, and its spray is single drops, not a square on its hip.
func test_the_water_climbs_round_a_wader() -> void:
	var still := Tide.collar(50.0, 6.0, 100.0, 0.0)
	check(still.size() == 2 * Tide.COLLAR, "standing: a meniscus each side, %d rows high (%d pieces)" % [Tide.COLLAR, still.size()])
	var left_ok := true
	var right_ok := true
	var narrowing := true
	for piece: Array in still:
		var r: Rect2 = piece[0]
		check(r.end.y <= 100.0 and r.position.y >= 100.0 - Tide.COLLAR, "on the line, never under it (%s)" % r)
		if r.end.x <= 44.0:
			left_ok = left_ok and r.end.x == 44.0
		else:
			right_ok = right_ok and r.position.x == 56.0
		var k := int(100.0 - 1.0 - r.position.y)
		narrowing = narrowing and r.size.x == float(Tide.COLLAR_FOOT - k)
	check(left_ok and right_ok, "against the body's edges")
	check(narrowing, "narrowing a pixel a row up")
	var right := Tide.collar(50.0, 6.0, 100.0, 80.0)
	var left := Tide.collar(50.0, 6.0, 100.0, -80.0)
	check(right.size() > still.size() and left.size() == right.size(), "moving, a bow wave joins it")
	var ahead := true
	for piece: Array in right.slice(still.size()):
		ahead = ahead and (piece[0] as Rect2).position.x >= 56.0
	for piece: Array in left.slice(still.size()):
		ahead = ahead and (piece[0] as Rect2).end.x <= 44.0
	check(ahead, "in front of the wader, whichever way it goes")
	var fading := right.size() > still.size() + 1 and float((right[still.size()] as Array)[1]) > float((right[-1] as Array)[1])
	check(fading, "thinning out ahead")
	check(Tide.collar(50.0, 6.0, 100.0, Tide.MOVING_SPEED * 0.5).size() == still.size(), "a slow drift pushes none")
	# The silt rises off the floor and drifts back, fading.
	var start := Vector2(40, 110)
	var mid := Tide.silt_at(start, -1.0, Tide.SILT_LIFE * 0.5)
	var end := Tide.silt_at(start, -1.0, Tide.SILT_LIFE)
	check(mid.y < start.y and end.y <= mid.y and end.x < mid.x and mid.x <= start.x, "silt rises and drifts back (%s, %s)" % [mid, end])
	check(Tide.silt_alpha(0.0) > Tide.silt_alpha(Tide.SILT_LIFE * 0.5) and Tide.silt_alpha(Tide.SILT_LIFE) == 0.0, "and fades away")
	# In the hall: standing stirs none; running stirs it behind the hero.
	var w := _hall()
	await frames(10)
	var tide: Tide = w.room.tide
	check(tide.silt.is_empty(), "standing, the hero stirs no silt")
	var p := w.player
	p.input.scripted = true
	p.input.move_x = 1
	await frames(20)
	var x := tide.to_local(p.global_position).x
	var behind := 0
	for puff: Array in tide.silt:
		behind += 1 if float(puff[1]) < 0.0 and (puff[0] as Vector2).x < x + 2.0 else 0
	check(behind >= 1, "running right, silt is stirred behind (to the left of) the hero (%d of %d)" % [behind, tide.silt.size()])
	var bow := false
	for wake: Array in tide.wakes:
		bow = bow or Tide.collar(float(wake[0]), float(wake[1]), tide.surface_y(), float(wake[2])).size() > 2 * Tide.COLLAR
	check(bow, "and its wake carries the speed for the bow wave")
	p.input.move_x = 0
	# Spray off the water is single drops, strung along the line.
	var d := Dust.new()
	d.setup("run", 1, "wade")
	var xs := {}
	for q: Array in d._particles:
		xs[(q[0] as Vector2).x] = true
	check(d._size == Dust.WADE_DROP and Dust.WADE_DROP == 1, "spray drops are a pixel across")
	check(xs.size() >= 4, "and do not start piled on one point (%d starts)" % xs.size())
	d.free()
	var dry := Dust.new()
	dry.setup("run", 1, "stone")
	check(dry._size == 2, "dust off dry ground is as it was")
	dry.free()

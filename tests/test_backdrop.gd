extends TestSuite
## Backdrop: atmospheric perspective on the parallax back layers (design bible
## 12.5). These cover the pure colour maths that the atmosphere shader runs, and
## the per-layer depth ordering, so the GPU effect is driven by tested logic.

const BRIGHT := Color(0.42, 0.72, 0.30)  # a saturated leaf green, like a lit backdrop


func _haze_dist(a: Color) -> float:
	var h := Backdrop.HAZE
	return absf(a.r - h.r) + absf(a.g - h.g) + absf(a.b - h.b)


func test_no_atmosphere_leaves_a_pixel_untouched() -> void:
	var out := Backdrop.haze_color(BRIGHT, 0.0, 0.0, Backdrop.HAZE)
	check(out.is_equal_approx(BRIGHT), "desat 0, fade 0 returns the source colour")


func test_full_fade_reaches_the_haze() -> void:
	var out := Backdrop.haze_color(BRIGHT, 0.0, 1.0, Backdrop.HAZE)
	check(out.is_equal_approx(Color(Backdrop.HAZE.r, Backdrop.HAZE.g, Backdrop.HAZE.b, BRIGHT.a)),
		"fade 1 lands on the haze colour")


func test_desaturation_lowers_saturation() -> void:
	var out := Backdrop.haze_color(BRIGHT, 0.5, 0.0, Backdrop.HAZE)
	check(out.s < BRIGHT.s, "pulling toward grey lowers saturation")
	var lum_before := BRIGHT.r * 0.299 + BRIGHT.g * 0.587 + BRIGHT.b * 0.114
	var lum_after := out.r * 0.299 + out.g * 0.587 + out.b * 0.114
	check_near(lum_after, lum_before, 0.01, "pulling toward luminance keeps perceived brightness")


func test_fade_pulls_a_bright_pixel_toward_the_dark_haze() -> void:
	var out := Backdrop.haze_color(BRIGHT, 0.0, 0.5, Backdrop.HAZE)
	check(_haze_dist(out) < _haze_dist(BRIGHT), "fading moves a bright pixel toward the haze")
	check(out.v < BRIGHT.v, "the haze is darker than a lit backdrop, so fading darkens it")


func test_far_recedes_further_than_mid() -> void:
	var far: Dictionary = Backdrop.ATMOS["far"]
	var mid: Dictionary = Backdrop.ATMOS["mid"]
	check(far["desat"] > mid["desat"], "the far layer is desaturated more than the mid layer")
	check(far["fade"] > mid["fade"], "the far layer is faded more than the mid layer")
	check(mid["desat"] > 0.0 and mid["fade"] > 0.0, "both layers get some atmosphere")
	check(far["desat"] <= 1.0 and far["fade"] <= 1.0, "the knobs stay in range")

	var far_out := Backdrop.haze_color(BRIGHT, far["desat"], far["fade"], Backdrop.HAZE)
	var mid_out := Backdrop.haze_color(BRIGHT, mid["desat"], mid["fade"], Backdrop.HAZE)
	check(far_out.s < mid_out.s, "a bright pixel ends up less saturated on the far layer")
	check(_haze_dist(far_out) < _haze_dist(mid_out), "and closer to the haze on the far layer")


func test_the_layers_are_ordered_back_to_front() -> void:
	# Insertion order in LAYERS is draw order: far furthest back, the ridge between
	# (design bible 12.12), mid nearest. Backdrop iterates LAYERS, so a child added
	# earlier draws further back.
	var order := Backdrop.LAYERS.keys()
	check(order == ["far", "ridge", "mid"], "the back layers run far -> ridge -> mid, got %s" % [order])


func test_the_ridge_scrolls_between_far_and_mid() -> void:
	# The distant ridge (design bible 12.12) parallaxes as a mid-distance: slower
	# than the near mid layer, faster than the far backdrop, on both axes.
	var far: Vector2 = Backdrop.LAYERS["far"]
	var ridge: Vector2 = Backdrop.LAYERS["ridge"]
	var mid: Vector2 = Backdrop.LAYERS["mid"]
	check(far.x < ridge.x and ridge.x < mid.x, "the ridge scrolls between far and mid horizontally")
	check(far.y < ridge.y and ridge.y < mid.y, "the ridge scrolls between far and mid vertically")


func test_the_ridge_recedes_between_far_and_mid() -> void:
	# Atmospheric perspective steps down with depth (design bible 12.5): the ridge
	# is desaturated and faded harder than the near mid layer and lighter than the
	# far backdrop, so the three layers recede in order.
	var far: Dictionary = Backdrop.ATMOS["far"]
	var ridge: Dictionary = Backdrop.ATMOS["ridge"]
	var mid: Dictionary = Backdrop.ATMOS["mid"]
	check(far["desat"] > ridge["desat"] and ridge["desat"] > mid["desat"],
		"the ridge is desaturated between far and mid")
	check(far["fade"] > ridge["fade"] and ridge["fade"] > mid["fade"],
		"the ridge is faded between far and mid")

	var far_out := Backdrop.haze_color(BRIGHT, far["desat"], far["fade"], Backdrop.HAZE)
	var ridge_out := Backdrop.haze_color(BRIGHT, ridge["desat"], ridge["fade"], Backdrop.HAZE)
	var mid_out := Backdrop.haze_color(BRIGHT, mid["desat"], mid["fade"], Backdrop.HAZE)
	check(far_out.s < ridge_out.s and ridge_out.s < mid_out.s,
		"a bright pixel ends up least saturated on far, most on mid, ridge between")
	check(_haze_dist(far_out) < _haze_dist(ridge_out) and _haze_dist(ridge_out) < _haze_dist(mid_out),
		"and closest to the haze on far, furthest on mid, ridge between")


func test_atmos_material_carries_the_ridge_parameters() -> void:
	var mat := Backdrop.atmos_material("ridge")
	check(mat != null, "the ridge layer gets an atmosphere material")
	check(is_equal_approx(mat.get_shader_parameter("desat"), Backdrop.ATMOS["ridge"]["desat"]),
		"its desat uniform matches the ridge config")
	check(is_equal_approx(mat.get_shader_parameter("fade"), Backdrop.ATMOS["ridge"]["fade"]),
		"its fade uniform matches the ridge config")


func test_the_haze_is_a_dark_tone() -> void:
	check(Backdrop.HAZE.v < 0.3, "the haze is dark, so atmosphere means receding into shadow")


func test_atmos_material_carries_the_layer_parameters() -> void:
	var mat := Backdrop.atmos_material("far")
	check(mat != null, "the far layer gets an atmosphere material")
	check(mat.shader == Backdrop.ATMOS_SHADER, "it uses the atmosphere shader")
	check(is_equal_approx(mat.get_shader_parameter("desat"), Backdrop.ATMOS["far"]["desat"]),
		"its desat uniform matches the far config")
	check(is_equal_approx(mat.get_shader_parameter("fade"), Backdrop.ATMOS["far"]["fade"]),
		"its fade uniform matches the far config")
	check((mat.get_shader_parameter("haze") as Color).is_equal_approx(Backdrop.HAZE),
		"its haze uniform defaults to the shared night haze")
	check(Backdrop.atmos_material("unknown") == null, "a layer with no atmosphere config gets no material")


func test_atmos_material_carries_the_zone_haze() -> void:
	var haze := Backdrop.haze_for("haar")
	var mat := Backdrop.atmos_material("far", haze)
	check((mat.get_shader_parameter("haze") as Color).is_equal_approx(haze),
		"a layer's haze uniform is the zone's distance-fog colour, not the default")


func test_haze_for_falls_back_to_the_default() -> void:
	check(Backdrop.haze_for("hearthroot").is_equal_approx(Backdrop.ZONE_HAZE["hearthroot"]),
		"a zone with an entry gets its own haze")
	check(Backdrop.haze_for("gym").is_equal_approx(Backdrop.HAZE),
		"a zone with no entry falls back to the shared night haze")


func test_every_shipped_zone_has_its_own_fog_colour() -> void:
	# Every playable zone (a levels/ folder that is not the gym or the test rings)
	# should recede into a fog colour of its own, so no zone shares the flat global
	# haze. gym and trials are fixtures; the rest are the shipped world.
	var shipped := ["hearthroot", "heartwood", "tower", "haar", "boughs",
		"vorrhallow", "evercrown", "sunken", "spires"]
	for z: String in shipped:
		check(Backdrop.ZONE_HAZE.has(z), "%s has a distance-fog colour" % z)


func test_every_zone_haze_is_a_dark_tone() -> void:
	# A fog colour must stay dark, or fading into it would brighten the backdrop
	# instead of receding it (design bible 12.5).
	for z: String in Backdrop.ZONE_HAZE:
		check((Backdrop.ZONE_HAZE[z] as Color).v < 0.4,
			"%s fog colour is dark enough to recede into" % z)


func test_the_crystal_halls_recede_deep_each_in_its_own_hue() -> void:
	# Vorrhallow and the Evercrown shared one crystal violet, the hue and the value
	# of their own play tiles, so the frame read as one purple (the independent
	# grade, pass 555). Each hall's haze is now deep and in the hue of its place on
	# the map: Vorrhallow's drowned blue, the Evercrown's wine (design bible 12.48).
	# Fails if either goes back to the shared violet.
	var v := Backdrop.ZONE_HAZE["vorrhallow"] as Color
	var e := Backdrop.ZONE_HAZE["evercrown"] as Color
	for c: Color in [v, e]:
		var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
		check(lum < 0.14, "a crystal hall's haze sits deep (%.3f)" % lum)
	check(v.b > v.g and v.g > v.r, "Vorrhallow's haze is a drowned blue")
	check(e.r > e.g * 1.8 and e.b > e.g * 1.8, "the Evercrown's haze is wine")
	var apart := absf(v.h - e.h)
	apart = minf(apart, 1.0 - apart) * 360.0
	check(apart >= 60.0, "the two halls' hazes are %d degrees of hue apart" % int(apart))
	# The play tiles of both are violet (stone and night ramps, hue about 255):
	# each haze stands at least 25 degrees off it.
	for c: Color in [v, e]:
		check(absf(c.h * 360.0 - 255.0) >= 25.0, "a hall's haze is off its tiles' violet (%d)" % int(c.h * 360.0))


func test_the_evercrowns_tiles_stand_off_its_wine_haze() -> void:
	# The Evercrown's tiles were violet (the night ramp, lit rim and all) on a wine
	# backdrop: a smaller hue step than Vorrhallow's (the pass 555 grade's leftover).
	# The cells' lit rim and cool seams are now on the sky ramp, the cyan pores'
	# light, over the same black-violet body (design bible 12.50). Measured on the
	# committed atlas: the mean hue of its opaque pixels went from 261 to 246, so it
	# stands 49 degrees off the haze where it stood 34. Fails if the rim goes back
	# to night-3, or the haze moves toward the tiles.
	var img := (load("res://assets/tiles/evercrown.png") as Texture2D).get_image()
	var rim := Color("3677aa")       # sky-3
	var old_rim := Color("5d4997")   # night-3
	var sum := Vector3.ZERO
	var n := 0
	var cool := 0
	var violet := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 1.0:
				continue
			sum += Vector3(c.r, c.g, c.b)
			n += 1
			if c.is_equal_approx(rim):
				cool += 1
			elif c.is_equal_approx(old_rim):
				violet += 1
	check(n > 0, "the Evercrown's atlas has opaque pixels")
	var mean := Color(sum.x / n, sum.y / n, sum.z / n)
	var haze := Backdrop.ZONE_HAZE["evercrown"] as Color
	var apart := absf(mean.h - haze.h)
	apart = minf(apart, 1.0 - apart) * 360.0
	check(apart >= 42.0, "the tiles stand %d degrees of hue off the haze" % int(apart))
	check(mean.b > mean.r and mean.r > mean.g, "the tiles are still a blue-violet, not a blue")
	check(float(cool) / n >= 0.04, "the cells' rim is the pores' blue (%d of %d)" % [cool, n])
	check(float(violet) / n < 0.01, "almost no violet rim is left (%d of %d)" % [violet, n])
	var lum := mean.r * 0.299 + mean.g * 0.587 + mean.b * 0.114
	var haze_lum := haze.r * 0.299 + haze.g * 0.587 + haze.b * 0.114
	check(lum > haze_lum * 1.5, "the tiles stay lighter than the haze")


func test_the_murkiest_zones_are_eased_toward_neutral() -> void:
	# The two murkiest zones — the Haar and the Sunken Spring, the darkest fogs — read
	# as a low-contrast grey-green / grey-teal where the play field merged into the
	# backdrop (the independent grade). Their haze is desaturated toward neutral so the
	# dark backdrop recedes as a paler mist and separates from the play field, while
	# staying under the dark-tone cap and keeping its cool-blue lean (design bible 12.5,
	# pass 513). Fails if either reverts to its old saturated dark murk.
	for z: String in ["haar", "sunken"]:
		var c := Backdrop.ZONE_HAZE[z] as Color
		check(c.s < 0.38, "%s haze is eased toward neutral, not a saturated murk" % z)
		check(c.v < 0.4, "%s haze stays under the dark-tone cap" % z)
		var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
		check(lum > 0.22, "%s haze is lifted to a paler mist, not a dark merge" % z)
		check(c.b >= c.r and c.b >= c.g, "%s haze keeps its cool-blue lean" % z)


func test_fore_scroll_reads_as_near_and_in_front() -> void:
	# The foreground silhouette (design bible 12.11) scrolls faster than the camera
	# horizontally, so it reads as near and slides past; it is locked to the camera
	# vertically. On a Parallax2D axis with no repeat, scale 0 is the camera lock
	# (scale 1 pins the layer to the world, the pass 528 band). Its z sits above the
	# atmosphere overlays (fog/motes/rain at 4) and every actor (<= 3), so it is the
	# nearest thing on screen.
	check(Backdrop.FORE_SCROLL.x > 1.0, "the foreground scrolls faster than the camera (near, in front)")
	check(is_zero_approx(Backdrop.FORE_SCROLL.y), "it is locked to the camera vertically (scale 0, not 1)")
	check(Backdrop.FORE_Z > 4, "it draws in front of the fog, motes and rain overlays")
	check(Backdrop.FORE_Z > 3, "it draws in front of every actor and projectile")


func test_fore_ground_band_stays_off_screen_at_any_camera_height() -> void:
	# Sean's note (pass 528): "a dark band of nearly opaque black across the top and
	# bottom of the screen, even when you travel up and down from screen to screen".
	# The foreground's solid ground band was pinned to world y 344..480, so it lay
	# across every room taller than a screen, in front of its platforms. Wherever the
	# camera is and however it is framed, the band's top must now sit on the bottom
	# edge of the view (the silhouettes rise from the edge; the band stays below it).
	var vp := arena.get_viewport()
	var before := vp.canvas_transform
	var backdrop := Backdrop.new()
	arena.add_child(backdrop)
	backdrop.set_zone("haar")
	# The fringe, not the hanging frame that shares its z since pass 645 (12.121).
	var fore: Parallax2D = backdrop._fore
	var hang: Parallax2D = backdrop._hang
	check(fore != null, "the haar backdrop has a foreground layer")
	check(hang != null, "and a hanging frame")
	if fore != null:
		var sprite := fore.get_child(0) as Sprite2D
		# The normal framing (zoom 2) and a wide room's (zoom 1.6), at the top of a
		# room, one screen down, and deep in a tall shaft.
		for zoom: float in [2.0, 1.6]:
			for cam_top: float in [0.0, 8.0, 360.0, 1234.0]:
				vp.canvas_transform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, Vector2(-96.0, -cam_top) * zoom)
				backdrop._process(0.0)
				var view_height := vp.get_visible_rect().size.y / zoom
				var band_top := fore.global_position.y + sprite.position.y + Backdrop.FORE_GROUND
				check_near(band_top - cam_top, view_height, 0.01,
					"zoom %.1f, camera top %d: the ground band starts at the view's bottom edge" % [zoom, cam_top])
				if hang != null:
					var hang_top := hang.global_position.y + (hang.get_child(0) as Sprite2D).position.y
					check_near(hang_top, cam_top, 0.01,
						"zoom %.1f, camera top %d: the hanging frame starts at the view's top edge" % [zoom, cam_top])
	vp.canvas_transform = before
	backdrop.queue_free()


func test_fore_ground_line_matches_the_painted_art() -> void:
	# FORE_GROUND mirrors tools/art/tilegen.py (FORE_FLOOR - FORE_BAND): the first
	# fully solid row of every zone's foreground art, in world pixels.
	for zone: String in ["haar", "heartwood", "spires", "evercrown", "tower"]:
		var tex := load(Backdrop.DIR + "%s_fore.png" % zone) as Texture2D
		var img := tex.get_image()
		var per_world := float(img.get_height()) / Backdrop.SIZE.y
		var first_solid := -1
		for y in img.get_height():
			var solid := true
			for x in range(0, img.get_width(), 16):
				if img.get_pixel(x, y).a < 0.8:
					solid = false
					break
			if solid:
				first_solid = y
				break
		check_near(first_solid / per_world, Backdrop.FORE_GROUND, 0.5, "%s: the solid band starts at FORE_GROUND" % zone)


func test_fore_silhouettes_stay_a_low_fringe() -> void:
	# The grade of pass 535: posts, reeds and thorn stalks up to 128 px tall stood
	# over the play layer as vertical black bars. Every zone's foreground now rises
	# at most FORE_MAX_RISE above its ground line (design bible 12.29).
	for zone: String in Backdrop.ZONE_HAZE:
		var path := Backdrop.DIR + "%s_fore.png" % zone
		if not ResourceLoader.exists(path):
			continue
		var img := (load(path) as Texture2D).get_image()
		var per_world := float(img.get_height()) / Backdrop.SIZE.y
		var top := -1
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.05:
					top = y
					break
			if top >= 0:
				break
		check(top >= 0, "%s: the foreground art is not empty" % zone)
		var rise := Backdrop.FORE_GROUND - top / per_world
		check(rise <= Backdrop.FORE_MAX_RISE + 0.5,
			"%s: the silhouettes rise %.1f px, no more than FORE_MAX_RISE" % [zone, rise])


func test_fore_leans_toward_the_zone_fog() -> void:
	# The silhouettes lean toward the zone's own fog colour (12.29), so the nearest
	# layer reads as near air in the zone's tint instead of flat black.
	check(Backdrop.FORE_TINT > 0.0 and Backdrop.FORE_TINT < 1.0, "the tint is partial")
	for zone: String in ["haar", "spires", "evercrown"]:
		var fl := Backdrop.fore_layer(zone)
		var mat := (fl.get_child(0) as Sprite2D).material as ShaderMaterial
		check(mat.get_shader_parameter("haze") == Backdrop.haze_for(zone), "%s: the shader gets the zone's fog" % zone)
		check_near(float(mat.get_shader_parameter("tint")), Backdrop.FORE_TINT, 0.0001, "%s: and the tint" % zone)
		fl.free()
	var black := Color(0.06, 0.05, 0.1, 0.7)
	var haze := Backdrop.haze_for("haar")
	var out := Backdrop.fore_color(black, haze)
	check_near(out.a, black.a, 0.0001, "the tint keeps the art's alpha")
	var d_before := Vector3(black.r - haze.r, black.g - haze.g, black.b - haze.b).length()
	var d_after := Vector3(out.r - haze.r, out.g - haze.g, out.b - haze.b).length()
	check_near(d_after, d_before * (1.0 - Backdrop.FORE_TINT), 0.0001, "it moves the colour FORE_TINT of the way to the fog")


func test_fore_layer_builds_in_front_for_a_zone_with_art() -> void:
	# A zone with a <zone>_fore.png gets a foreground Parallax2D: absolute high z
	# (z_as_relative false, so the backdrop's own z_index -50 doesn't drag it back),
	# the fast/locked scroll, and the zone's silhouette sprite.
	var fl := Backdrop.fore_layer("haar")
	check(fl != null, "the haar zone builds a foreground layer")
	if fl == null:
		return
	check(not fl.z_as_relative, "its z is absolute, not relative to the backdrop node")
	check(fl.z_index == Backdrop.FORE_Z, "it draws at the foreground z")
	check(fl.scroll_scale.is_equal_approx(Backdrop.FORE_SCROLL), "it carries the foreground scroll")
	check(fl.ignore_camera_scroll, "it takes its offset from Backdrop, like the back layers")
	var sprite := fl.get_child(0) as Sprite2D
	check(sprite != null and sprite.texture != null, "it shows the zone's silhouette art")
	var mat := sprite.material as ShaderMaterial
	check(mat != null and mat.shader == Backdrop.FORE_SHADER,
		"it carries the reveal shader (12.26), not the haze of the receding back layers")
	fl.free()


func test_the_reveal_mask_thins_only_around_an_actor() -> void:
	# The grade (pass 529): near-black foreground posts sliced through the market's
	# shopkeepers and the hero. The foreground thins in a soft box around each actor
	# (design bible 12.26); the mask mirrors shaders/fore_reveal.gdshader.
	var holes: Array[Vector4] = [Vector4(0.5, 0.5, 10.0, 20.0)]
	var px := Vector2(1.0, 1.0) / Backdrop.SIZE  # one world pixel in UV
	check_near(Backdrop.reveal_mask(Vector2(0.5, 0.5), holes), 1.0, 0.001, "full at the actor's centre")
	check_near(Backdrop.reveal_mask(Vector2(0.5, 0.5) + Vector2(9.5, 19.5) * px, holes), 1.0, 0.001,
		"full anywhere inside the box")
	var mid := Backdrop.reveal_mask(Vector2(0.5, 0.5) + Vector2(10.0 + Backdrop.REVEAL_SOFT * 0.5, 0.0) * px, holes)
	check(mid > 0.05 and mid < 0.95, "it fades out over the soft edge, not at a hard line")
	check_near(Backdrop.reveal_mask(Vector2(0.5, 0.5) + Vector2(10.0 + Backdrop.REVEAL_SOFT + 1.0, 0.0) * px, holes),
		0.0, 0.001, "untouched beyond the soft edge")
	check_near(Backdrop.reveal_mask(Vector2(0.5, 0.1), holes), 0.0, 0.001, "untouched above the actor")
	check_near(Backdrop.reveal_mask(Vector2(0.5, 0.5), [] as Array[Vector4]), 0.0, 0.001, "no actors, no holes")
	# The layer repeats sideways every SIZE.x, so a hole near one edge of the art
	# thins the other edge of the next copy too.
	var seam: Array[Vector4] = [Vector4(2.0 * px.x, 0.5, 10.0, 20.0)]
	check_near(Backdrop.reveal_mask(Vector2(1.0 - 4.0 * px.x, 0.5), seam), 1.0, 0.001, "the hole wraps across the seam")
	check(Backdrop.REVEAL_KEEP > 0.0 and Backdrop.REVEAL_KEEP <= 0.3,
		"a ghost of the silhouette is left in front of an actor, faint enough to see the actor through")


func test_actor_box_measures_the_collision_shape_or_a_person() -> void:
	var foe := Node2D.new()
	foe.position = Vector2(100, 200)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 30)
	cs.shape = rect
	cs.position = Vector2(0, -15)
	foe.add_child(cs)
	arena.add_child(foe)
	var b := Backdrop.actor_box(foe)
	check(b.is_equal_approx(Rect2(90, 170, 20, 30).grow(Backdrop.REVEAL_PAD)), "a foe's box is its shape, padded")
	var person := Node2D.new()
	person.position = Vector2(300, 304)
	arena.add_child(person)
	var pb := Backdrop.actor_box(person)
	check(pb.is_equal_approx(Rect2(Vector2(300, 304) + Backdrop.PERSON_BOX.position, Backdrop.PERSON_BOX.size).grow(Backdrop.REVEAL_PAD)),
		"a townsperson's box stands on its feet")
	check(pb.end.y > 304.0 and pb.position.y < 304.0 - 40.0, "it covers the person from the feet to the head")


func test_the_foreground_thins_in_front_of_actors_in_view() -> void:
	# Wired end to end: Backdrop._process finds the actors in view and the shader's
	# holes land on them wherever the parallax has slid the repeating art.
	var vp := arena.get_viewport()
	var before := vp.canvas_transform
	var backdrop := Backdrop.new()
	arena.add_child(backdrop)
	backdrop.set_zone("hearthroot")
	var keeper := Node2D.new()
	keeper.add_to_group("npc")
	arena.add_child(keeper)
	var far_foe := Node2D.new()
	far_foe.add_to_group("enemy")
	arena.add_child(far_foe)
	var sprite := backdrop._fore.get_child(0) as Sprite2D
	var mat := sprite.material as ShaderMaterial
	for cam_left: float in [0.0, 333.0, 1500.0]:
		keeper.position = Vector2(cam_left + 200.0, 300.0)
		far_foe.position = Vector2(cam_left + 2000.0, 300.0)  # well outside the view
		vp.canvas_transform = Transform2D(0.0, Vector2(2, 2), 0.0, Vector2(-cam_left, -200.0) * 2.0)  # view y 200..380
		# Count against the actors already in the tree (a hidden actor is skipped).
		keeper.visible = false
		backdrop._process(0.0)
		var baseline := int(mat.get_shader_parameter("hole_count"))
		keeper.visible = true
		backdrop._process(0.0)
		var count := int(mat.get_shader_parameter("hole_count"))
		check(count == mini(baseline + 1, Backdrop.MAX_HOLES),
			"camera at %d: one more hole, for the townsperson in view (not the foe off screen)" % cam_left)
		var holes: Array[Vector4] = []
		for h: Vector4 in mat.get_shader_parameter("holes"):
			holes.append(h)
		holes.resize(count)
		# Where the townsperson's chest falls on the art, measured independently of
		# holes_for: its offset from the sprite's origin in world pixels, over SIZE.
		var chest := keeper.global_position + Vector2(0, -24)
		var uv := (chest - sprite.global_position) / Backdrop.SIZE
		check_near(Backdrop.reveal_mask(uv, holes), 1.0, 0.001,
			"camera at %d: the silhouettes are thinned over the townsperson" % cam_left)
		var foe_uv := (far_foe.global_position + Vector2(0, -24) - sprite.global_position) / Backdrop.SIZE
		check_near(Backdrop.reveal_mask(foe_uv, holes), 0.0, 0.001,
			"camera at %d: the foe off screen opens no hole (its spot on the repeating art stays whole)" % cam_left)
		if baseline == 0:
			check_near(Backdrop.reveal_mask(uv + Vector2(0.25, 0.0), holes), 0.0, 0.001,
				"camera at %d: and left whole a quarter screen away" % cam_left)
	# More actors than holes: the nearest to the view's centre win.
	for i in Backdrop.MAX_HOLES + 4:
		var n := Node2D.new()
		n.add_to_group("enemy")
		n.position = Vector2(1500.0 + 10.0 * i, 300.0)
		arena.add_child(n)
	backdrop._process(0.0)
	check(int(mat.get_shader_parameter("hole_count")) == Backdrop.MAX_HOLES, "the holes are capped at MAX_HOLES")
	vp.canvas_transform = before
	backdrop.queue_free()


func test_townspeople_join_the_npc_group() -> void:
	var n := Npc.new()
	n.npc_id = "merchant"
	arena.add_child(n)
	check(n.is_in_group("npc"), "a townsperson is in the npc group, so the foreground reveals it")


func test_fore_layer_absent_without_art() -> void:
	# The gym and any new zone has no foreground art, so no layer is built — the
	# game just draws the back layers, no error.
	check(Backdrop.fore_layer("gym") == null, "the gym has no foreground layer")
	check(Backdrop.fore_layer("not_a_zone") == null, "an unknown zone has no foreground layer")


func test_zones_differ_in_fog_colour() -> void:
	# The point of the pass: a warm hearth and a cold spring must not share one
	# haze. Sample one zone per family and confirm they are visibly apart.
	var warm := Backdrop.haze_for("hearthroot")
	var cold := Backdrop.haze_for("sunken")
	var green := Backdrop.haze_for("boughs")
	check(warm.r > cold.r, "the warm hearth fog is redder than the cold spring fog")
	check(green.g > warm.g and green.g > cold.g, "the canopy fog is the greenest")


func test_a_sunlit_zones_woods_recede_into_light() -> void:
	# Design bible 12.112 (pass 636): the pass 635 grade saw the canopy bridge's
	# foes "small and low-contrast against the foliage". The Boughs' woods faded
	# toward the same dark green the foes' bodies sit at. A sunlit zone's nearer
	# layers now recede into the pale air of its sky.
	check(Backdrop.ZONE_AIR.has("boughs"), "the Boughs have day air")
	for zone: String in Backdrop.ZONE_AIR:
		var air: Color = Backdrop.ZONE_AIR[zone]
		check(FoeLight.luma(air) > FoeLight.luma(Backdrop.haze_for(zone)) + 0.2, "%s: its air is light, not a haze" % zone)
		for suffix: String in Backdrop.AIR_FADE:
			check(Backdrop.layer_haze(zone, suffix) == air, "%s %s: recedes into the air" % [zone, suffix])
			var mat := Backdrop.layer_material(zone, suffix)
			check_near(float(mat.get_shader_parameter("fade")), Backdrop.AIR_FADE[suffix], 0.0001, "%s %s: at its own fade" % [zone, suffix])
			check_near(float(mat.get_shader_parameter("mist")), Backdrop.AIR_MIST[suffix], 0.0001, "%s %s: and its mist" % [zone, suffix])
			check(Backdrop.AIR_MIST[suffix] > Backdrop.AIR_FADE[suffix], "%s %s: the mist is deeper at the foot" % [zone, suffix])
		check(Backdrop.layer_haze(zone, "far") == Backdrop.haze_for(zone), "%s: the sky keeps the haze" % zone)
	check(Backdrop.layer_haze("heartwood", "ridge") == Backdrop.haze_for("heartwood"), "a zone under a roof keeps its haze")
	check(Backdrop.layer_material("heartwood", "ridge").get_shader_parameter("fade") == Backdrop.ATMOS["ridge"]["fade"],
		"at the haze's fade")
	check(Backdrop.AIR_FADE["ridge"] > Backdrop.AIR_FADE["mid"] and Backdrop.AIR_MIST["ridge"] > Backdrop.AIR_MIST["mid"],
		"the ridge recedes further than the mid")
	check(Backdrop.layer_material("heartwood", "ridge").get_shader_parameter("mist") == null,
		"a haze sets no mist (the shader's default keeps one fade)")
	# The mist: the fade at the top, deepening down the layer, the mist at the foot.
	check_near(Backdrop.fade_at(0.4, 0.8, 0.0), 0.4, 0.0001, "the top takes the fade")
	check_near(Backdrop.fade_at(0.4, 0.8, Backdrop.MIST_FROM), 0.4, 0.0001, "down to MIST_FROM")
	check_near(Backdrop.fade_at(0.4, 0.8, 1.0), 0.8, 0.0001, "the foot takes the mist")
	check(Backdrop.fade_at(0.4, 0.8, 0.55) > 0.4 and Backdrop.fade_at(0.4, 0.8, 0.55) < 0.8, "and it rises between")
	check_near(Backdrop.fade_at(0.4, -1.0, 1.0), 0.4, 0.0001, "no mist leaves the fade")

	# Measured: the lower half of the Boughs' woods, where a foe stands in front of
	# them, against the middle of the Bark Knight's and the Leaf Mantis's lit bodies.
	var img := (load(Backdrop.DIR + "boughs_ridge.png") as Texture2D).get_image()
	var mat_r := Backdrop.layer_material("boughs", "ridge")
	var haze_r: Color = mat_r.get_shader_parameter("haze")
	var desat_r := float(mat_r.get_shader_parameter("desat"))
	var fade_r := float(mat_r.get_shader_parameter("fade"))
	var mist_r := float(mat_r.get_shader_parameter("mist"))
	var woods: Array[float] = []
	var woods_sat: Array[float] = []
	for y in range(img.get_height() / 2, img.get_height(), 2):
		var f := Backdrop.fade_at(fade_r, mist_r, float(y) / img.get_height())
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.a > 0.9:
				var seen_c := Backdrop.haze_color(c, desat_r, f, haze_r)
				woods.append(FoeLight.luma(seen_c))
				woods_sat.append(seen_c.s)
	woods.sort()
	woods_sat.sort()
	var behind := woods[woods.size() / 2]
	var behind_sat := woods_sat[woods_sat.size() / 2]
	for id: String in ["bark_knight", "leaf_mantis"]:
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s.json" % id))
		var cell: Array = meta["cell"]
		var sheet: Image = (load("res://assets/sprites/%s.png" % id) as Texture2D).get_image()
		var body: Array[float] = []
		var body_sat: Array[float] = []
		for y in int(cell[1]):
			for x in int(cell[0]):
				var p := sheet.get_pixel(x, y)
				if p.a > 0.8:
					var lit_p := FoeLight.lit(p, "boughs", id)
					body.append(FoeLight.luma(lit_p))
					body_sat.append(lit_p.s)
		body.sort()
		body_sat.sort()
		var mid := body[body.size() / 2]
		var mid_sat := body_sat[body_sat.size() / 2]
		# A step in value, or in colour: a leaf-green mantis is as light as the
		# misted woods but far more saturated than their grey-green air.
		check(absf(behind - mid) > 0.08 or mid_sat - behind_sat > 0.15,
			"%s: its body (value %.2f, saturation %.2f) is a step off the woods behind it (%.2f, %.2f)" % [id, mid, mid_sat, behind, behind_sat])
		check(behind - body[0] > 0.25, "%s: and its outline is dark against them (%.2f)" % [id, body[0]])


func _hang_rows(zone: String) -> Vector2i:
	## The first and last rows (in world pixels) the zone's hanging art covers, or (-1, -1).
	var img := (load(Backdrop.DIR + "%s_hang.png" % zone) as Texture2D).get_image()
	var per_world := float(img.get_height()) / Backdrop.SIZE.y
	var first := -1
	var last := -1
	for y in img.get_height():
		for x in range(0, img.get_width(), 1):
			if img.get_pixel(x, y).a > 0.05:
				if first < 0:
					first = y
				last = y
				break
	if first < 0:
		return Vector2i(-1, -1)
	return Vector2i(int(first / per_world), int(ceil((last + 1) / per_world)))


func test_the_hanging_frame_hangs_into_the_top_of_the_view() -> void:
	# The grade of pass 640: no foreground layer frames the rooms. Every zone with a
	# low fringe (12.11) also has a frame hanging from the view's top edge (12.121):
	# it starts at the very top and drops no deeper than HANG_MAX_DROP.
	for zone: String in Backdrop.ZONE_HAZE:
		if not ResourceLoader.exists(Backdrop.DIR + "%s_fore.png" % zone):
			continue
		check(ResourceLoader.exists(Backdrop.DIR + "%s_hang.png" % zone), "%s: has a hanging frame" % zone)
		if not ResourceLoader.exists(Backdrop.DIR + "%s_hang.png" % zone):
			continue
		var rows := _hang_rows(zone)
		check(rows.x == 0, "%s: the frame hangs from the very top edge (first row %d)" % [zone, rows.x])
		check(rows.y > 20 and rows.y <= int(Backdrop.HANG_MAX_DROP),
			"%s: it drops %d px, more than a sliver and no more than HANG_MAX_DROP" % [zone, rows.y])


func test_the_hanging_frame_is_locked_to_the_top_and_near() -> void:
	# Seated on the view's top edge at any camera height (scroll y 0), sliding past
	# faster than the camera but not with the fringe, in front of everything, and
	# darker than the fringe (a frame washed into the fog read as pale ghosts).
	var hl := Backdrop.hang_layer("boughs")
	check(hl != null, "the boughs build a hanging frame")
	if hl == null:
		return
	check(hl.scroll_scale.is_equal_approx(Backdrop.HANG_SCROLL), "it carries the frame's scroll")
	check(Backdrop.HANG_SCROLL.y == 0.0, "locked to the camera vertically")
	check(Backdrop.HANG_SCROLL.x > 1.0 and not is_equal_approx(Backdrop.HANG_SCROLL.x, Backdrop.FORE_SCROLL.x),
		"near, and shearing against the fringe")
	check(not hl.z_as_relative and hl.z_index == Backdrop.FORE_Z, "drawn in front at the foreground z")
	var sprite := hl.get_child(0) as Sprite2D
	check(sprite.position == Vector2.ZERO and not sprite.centered, "its top row is the view's top edge")
	var mat := sprite.material as ShaderMaterial
	check(mat != null and mat.shader == Backdrop.FORE_SHADER, "it thins in front of actors like the fringe")
	check_near(float(mat.get_shader_parameter("tint")), Backdrop.HANG_TINT, 0.0001, "it leans toward the fog by HANG_TINT")
	check(Backdrop.HANG_TINT < Backdrop.FORE_TINT, "less than the fringe, so it stays dark")
	hl.free()
	check(Backdrop.hang_layer("gym") == null, "a zone with no art gets no frame")


func test_the_hanging_frame_thins_over_a_hazard_in_view() -> void:
	# The frame covers the top of the view, where ceiling spikes and pickups sit; a
	# hazard in view opens a hole in it as a foe does (REVEAL_GROUPS).
	var vp := arena.get_viewport()
	var before := vp.canvas_transform
	var backdrop := Backdrop.new()
	arena.add_child(backdrop)
	backdrop.set_zone("tower")
	check(backdrop._hang != null, "the tower's backdrop has its frame")
	var spike := Node2D.new()
	spike.add_to_group("hazard")
	arena.add_child(spike)
	spike.position = Vector2(200.0, 230.0)
	vp.canvas_transform = Transform2D(0.0, Vector2(2, 2), 0.0, Vector2(0.0, -200.0) * 2.0)  # view y 200..380
	var sprite := backdrop._hang.get_child(0) as Sprite2D
	var mat := sprite.material as ShaderMaterial
	spike.visible = false
	backdrop._process(0.0)
	var baseline := int(mat.get_shader_parameter("hole_count"))
	spike.visible = true
	backdrop._process(0.0)
	check(int(mat.get_shader_parameter("hole_count")) == mini(baseline + 1, Backdrop.MAX_HOLES), "the spike opens a hole")
	var holes: Array[Vector4] = []
	for h: Vector4 in mat.get_shader_parameter("holes"):
		holes.append(h)
	holes.resize(int(mat.get_shader_parameter("hole_count")))
	var uv := (spike.global_position + Vector2(0, -24) - sprite.global_position) / Backdrop.SIZE
	check_near(Backdrop.reveal_mask(uv, holes), 1.0, 0.001, "the frame is thinned over it")
	for g: String in ["hazard", "enemy_projectile", "interactable", "pickup"]:
		check(g in Backdrop.REVEAL_GROUPS, "%s joins the groups the near layers thin for" % g)
	vp.canvas_transform = before
	backdrop.queue_free()
	spike.queue_free()

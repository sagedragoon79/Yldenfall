extends TestSuite
## Pass 632 (bible 12.108): the pass 630 grade read the High Boughs' wind as
## "white dash clusters in the canopy sky". A current is drawn as gusts that
## thin out behind their heads over a wash with no ruled border.


func test_wind_look_a_gust_thins_out_behind_its_head() -> void:
	var w := 480.0
	var h := 96.0
	var whole := 0
	for i in WindCurrent.gust_count(w):
		for d: float in [1.0, -1.0]:
			var pieces := WindCurrent.gust(i, w, h, 0.9, d)
			if pieces.size() < WindCurrent.GUST_PARTS:
				continue
			whole += 1
			var rising := true
			var joined := true
			for k in range(1, pieces.size()):
				var prev: Rect2 = pieces[k - 1][0]
				var here: Rect2 = pieces[k][0]
				rising = rising and pieces[k][1] > pieces[k - 1][1]
				# Tail to head runs downwind, each piece meeting the last.
				joined = joined and (is_equal_approx(here.position.x, prev.end.x) if d > 0.0 else is_equal_approx(here.end.x, prev.position.x))
			check(rising, "gust %d blowing %d brightens from tail to head" % [i, int(d)])
			check(joined, "gust %d blowing %d is one line with its head downwind" % [i, int(d)])
			check(pieces[0][1] <= WindCurrent.GUST_ALPHA * 0.2, "its tail is faint (%.2f)" % pieces[0][1])
			check(is_equal_approx(pieces[-1][1], WindCurrent.GUST_ALPHA), "its head is the brightest it gets")
	check(whole >= 8, "gusts cross the band (%d whole)" % whole)


func test_wind_look_gusts_are_soft_thin_and_inside_the_band() -> void:
	# Weather stays under a foe's accent and a tell (bible 12.71).
	check(WindCurrent.GUST_ALPHA <= 0.65, "a gust's head is not a white dash (%.2f)" % WindCurrent.GUST_ALPHA)
	var w := 352.0
	var h := 64.0
	var box := Rect2(0, 0, w, h)
	var inside := true
	var thin := true
	var rows := {}
	for step in 40:
		var t := step * 0.137
		for i in WindCurrent.gust_count(w):
			for piece: Array in WindCurrent.gust(i, w, h, t, -1.0):
				var r: Rect2 = piece[0]
				inside = inside and box.encloses(r)
				thin = thin and r.size.y == 1.0 and r.size.x >= 1.0
				rows[int(r.position.y)] = true
	check(inside, "no gust leaves its band")
	check(thin, "a gust is a pixel thick")
	check(rows.size() >= 10, "gusts are spread over the band's height (%d rows)" % rows.size())
	check(WindCurrent.gust_count(w) <= int(w / 20.0) + 4, "and are few: %d on %d px" % [WindCurrent.gust_count(w), int(w)])
	# A gust bows: not every piece of it is on one row.
	var bowed := 0
	for i in WindCurrent.gust_count(w):
		var ys := {}
		for piece: Array in WindCurrent.gust(i, 2000.0, h, 3.0, 1.0):
			ys[piece[0].position.y] = true
		if ys.size() > 1:
			bowed += 1
	check(bowed >= WindCurrent.gust_count(w) / 2, "most gusts bow (%d)" % bowed)


func test_wind_look_the_wash_has_no_ruled_border() -> void:
	var w := 320.0
	var h := 96.0
	var boxes := WindCurrent.wash(w, h)
	check(boxes.size() == WindCurrent.WASH_STEPS, "the wash is %d nested boxes" % WindCurrent.WASH_STEPS)
	var total := 0.0
	var nested := true
	for k in boxes.size():
		total += boxes[k][1]
		if k > 0:
			var outer: Rect2 = boxes[k - 1][0]
			var inner: Rect2 = boxes[k][0]
			nested = nested and outer.encloses(inner) and inner.position.x > outer.position.x and inner.position.y > outer.position.y
	check(nested, "each inside the last, so the edge steps down")
	check(is_equal_approx(total, WindCurrent.WASH) and WindCurrent.WASH <= 0.06, "faint at its middle (%.3f)" % total)
	check(boxes[0][1] <= 0.015, "and its outer edge is a step no eye rules a line on (%.4f)" % boxes[0][1])
	check(boxes[0][0] == Rect2(0, 0, w, h), "it still covers the whole current")
	# A band one cell high keeps its boxes right side out.
	var small := true
	for b: Array in WindCurrent.wash(64.0, 16.0):
		small = small and b[0].size.x > 0.0 and b[0].size.y > 0.0
	check(small, "a thin band's wash is never inside out")


func test_wind_look_a_boughs_room_draws_its_current() -> void:
	var w := make_world({}, "boughs/canopy_bridge")
	await frames(3)
	var winds := w.room.get_children().filter(func(c: Node) -> bool: return c is WindCurrent)
	check(not winds.is_empty(), "the canopy bridge has a current")
	for c: WindCurrent in winds:
		var size := c.pixel_rect().size
		var drawn := 0
		for i in WindCurrent.gust_count(size.x):
			drawn += WindCurrent.gust(i, size.x, size.y, 1.0, float(c.dir())).size()
		check(drawn > 0, "and gusts run along it (%d pieces)" % drawn)

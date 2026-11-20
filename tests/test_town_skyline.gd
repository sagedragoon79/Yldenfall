extends TestSuite
## The town's far skyline is a row of houses (design bible 12.94, pass 617). The
## independent grades after passes 610 and 615 read Hearthroot's ridge as gridded
## windows on flat one-value silhouettes: every house was a flat-topped block set with
## one lattice of windows. A house now has a pitched roof, a wall tone of its own and a
## few windows of its own.

const RIDGE := "res://assets/bg/hearthroot_ridge.png"
## The old lattice: a window every 16 px along a wall and every 24 px down it.
const LATTICE := [Vector2i(16, 0), Vector2i(-16, 0), Vector2i(0, 24), Vector2i(0, -24)]


func _image() -> Image:
	return (load(RIDGE) as Texture2D).get_image()


## A lit window's pixel: warm and bright against the ridge's cold stone.
func _warm(img: Image, x: int, y: int) -> bool:
	if y < 0:
		return false
	var p := img.get_pixel(posmod(x, img.get_width()), y)
	return p.a > 0.0 and p.r > 0.43 and p.r > p.b * 1.6


func test_the_roofline_is_pitched() -> void:
	var img := _image()
	var w := img.get_width()
	var crest: Array[int] = []
	for x in w:
		var y := 0
		while y < img.get_height() and img.get_pixel(x, y).a == 0.0:
			y += 1
		crest.append(y)
	var sloped := 0
	var level := 0
	for x in w:
		var step := absi(crest[x] - crest[posmod(x - 1, w)])
		if step == 0:
			level += 1
		elif step <= 3:
			sloped += 1
	# Flat-topped blocks left 2 percent of the crest on a slope and 95 percent level.
	check(sloped > w * 0.3, "at least three columns in ten of the crest are a roof's slope (%d of %d)" % [sloped, w])
	check(level < w * 0.7, "and under seven in ten are level (%d of %d)" % [level, w])


func test_no_lattice_of_windows_runs_through_the_row() -> void:
	var img := _image()
	var w := img.get_width()
	var lit := {}
	for y in img.get_height():
		for x in w:
			# The top left pixel of each lit window (its glow is too faint to count).
			if _warm(img, x, y) and not _warm(img, x - 1, y) and not _warm(img, x, y - 1) and not _warm(img, x + 1, y - 1):
				lit[Vector2i(x, y)] = true
	var on_lattice := 0
	for at: Vector2i in lit:
		for step: Vector2i in LATTICE:
			if lit.has(Vector2i(posmod(at.x + step.x, w), at.y + step.y)):
				on_lattice += 1
				break
	# The lattice had 80 lit windows, 45 of them a step from another.
	check(lit.size() >= 12, "the town still shows its lights (%d lit windows)" % lit.size())
	check(lit.size() <= 70, "and they stay few (%d lit windows)" % lit.size())
	check(on_lattice * 10 < lit.size(), "under one lit window in ten sits a lattice step from another (%d of %d)" % [on_lattice, lit.size()])


func test_the_far_plane_is_more_than_one_value() -> void:
	var img := _image()
	var count := {}
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.0:
				var key := p.to_rgba32()
				count[key] = int(count.get(key, 0)) + 1
	# The nearer plane is the one flat fill that covers most of the layer: leave it out.
	var near := 0
	var total := 0
	for key: int in count:
		total += count[key]
		near = maxi(near, count[key])
	var rest := total - near
	var most := 0
	var tones := 0
	for key: int in count:
		if count[key] == near:
			continue
		most = maxi(most, count[key])
		if count[key] * 20 >= rest:
			tones += 1
	# One body colour held 73 percent of the far plane.
	check(most * 10 < rest * 4, "no one colour holds four tenths of the far plane (%d of %d)" % [most, rest])
	check(tones >= 4, "at least four tones each hold a twentieth of it (%d)" % tones)

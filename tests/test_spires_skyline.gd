extends TestSuite
## The Spires' far skyline is a ruined city on a terraced hill (design bible 12.98,
## pass 622). The independent grade after pass 615 read the storm ledge's skyline as a
## flat one-value silhouette: every spire was one pole in one tone, standing through
## a hill of one tone (one colour held 73 percent of the far plane), and in the room
## the row read as fence posts. A spire now has a form and a wall tone of its own,
## the hill steps down in terraces, and bridges join some spires.

const RIDGE := "res://assets/bg/spires_ridge.png"
## The horizon the ridge rests on (tilegen's RIDGE_BASE), and how far above it a
## crest counts as a spire's and not the hill's.
const HORIZON := 0.56
const TALL := 56


func _image() -> Image:
	return (load(RIDGE) as Texture2D).get_image()


## The crest: the first pixel of each column that is not sky.
func _crest(img: Image) -> Array[int]:
	var crest: Array[int] = []
	for x in img.get_width():
		var y := 0
		while y < img.get_height() and img.get_pixel(x, y).a == 0.0:
			y += 1
		crest.append(y)
	return crest


func test_the_spires_far_plane_is_more_than_one_value() -> void:
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
	# One body colour held 73 percent of the far plane, and two tones a twentieth each.
	check(most * 10 < rest * 3, "no one colour holds three tenths of the far plane (%d of %d)" % [most, rest])
	check(tones >= 4, "at least four tones each hold a twentieth of it (%d)" % tones)


func test_the_spires_are_not_one_pole() -> void:
	var img := _image()
	var w := img.get_width()
	var crest := _crest(img)
	var line := int(img.get_height() * HORIZON) - TALL
	# Each run of columns that stands well above the horizon is a spire, or two that
	# a bridge joins.
	var widths: Array[int] = []
	var run := 0
	for x in w + 1:
		if x < w and crest[x] < line:
			run += 1
		elif run > 0:
			widths.append(run)
			run = 0
	var narrow := 0
	var broad := 0
	for width in widths:
		if width >= 5 and width <= 14:
			narrow += 1
		elif width >= 26:
			broad += 1
	# The poles were 17 to 25 px wide, every one (a point's tip apart, under 5 px).
	check(narrow >= 4, "needles and broken tips stand in the row (%d runs of 5 to 14 px)" % narrow)
	check(broad >= 3, "and keeps and bridged pairs (%d runs of 26 px or over)" % broad)
	# A tower sheared off at a slant leaves ragged steps in its crest: the poles'
	# crests stepped by 4 px or under (a point, a crown) or by a whole wall.
	var ragged := 0
	for x in w:
		var step := absi(crest[x] - crest[posmod(x - 1, w)])
		if step >= 5 and step <= 11:
			ragged += 1
	check(ragged >= 12, "some spires are sheared off in ragged steps (%d steps of 5 to 11 px)" % ragged)


func test_the_spires_bridges_stand_over_open_sky() -> void:
	var img := _image()
	var under := 0
	for x in img.get_width():
		var y := 0
		while y < img.get_height() and img.get_pixel(x, y).a == 0.0:
			y += 1
		# Below the crest and above the opaque nearer plane: sky again is a bridge's arch.
		var gap := 0
		while y < img.get_height() and img.get_pixel(x, y).a < 1.0:
			if img.get_pixel(x, y).a == 0.0:
				gap += 1
			y += 1
		if gap >= 4:
			under += 1
	# The poles stood apart: no column had sky under masonry.
	check(under >= 60, "bridges span open sky (%d columns)" % under)
	check(under <= 400, "and the row is not all bridge (%d columns)" % under)


func test_the_spires_slit_windows_stay_few() -> void:
	var img := _image()
	var warm := 0
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.0 and p.r > 0.43 and p.r > p.b * 1.6:
				warm += 1
	# A slit is 2 by 10 px: a handful are lit, never the town's rows of windows.
	check(warm >= 60, "some slits are lit (%d px)" % warm)
	check(warm <= 400, "and they stay few (%d px)" % warm)

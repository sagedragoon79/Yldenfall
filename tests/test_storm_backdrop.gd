extends TestSuite
## Carillon's storm stands behind the fight (design bible 12.71, pass 584). The
## independent grade (pass 580) read the Spires fight frame as noisy: a screen of
## white rain over the figures, and three white bolts baked into the far sky that
## never went out. The rain is now thin enough to be weather, and the far layer
## holds nothing as bright as a foe's accent or a tell.

const FAR := "res://assets/bg/spires_far.png"
## The brightest a pixel of the far layer may be (the bolts were 0.94), and the
## most the whole layer may average (it was 0.215).
const BRIGHTEST := 0.6
const MEAN := 0.15


func test_the_rain_is_thin_enough_to_see_the_fight_through() -> void:
	check(SheetRain.MAX_ALPHA <= 0.5, "no rain layer may cover half of what is behind it (%.2f)" % SheetRain.MAX_ALPHA)
	var far: Array = SheetRain.LAYERS[0]
	var near: Array = SheetRain.LAYERS[1]
	for layer: Array in SheetRain.LAYERS:
		var a: float = layer[3]
		check(a > 0.15 and a <= SheetRain.MAX_ALPHA, "a layer at %.2f still shows and stays under %.2f" % [a, SheetRain.MAX_ALPHA])
	check(float(far[3]) < float(near[3]), "the far layer is the fainter one (%.2f under %.2f)" % [far[3], near[3]])
	# What the layers cover together, at the storm's height.
	var both := 1.0 - (1.0 - float(far[3])) * (1.0 - float(near[3]))
	check(both < 0.65, "where two drops cross they cover %.2f of a figure, under 0.65" % both)


func test_the_far_sky_holds_no_bright_bolt() -> void:
	var img := (load(FAR) as Texture2D).get_image()
	var top := 0.0
	var sum := 0.0
	var bright := 0
	for y in img.get_height():
		for x in img.get_width():
			var l := img.get_pixel(x, y).get_luminance()
			top = maxf(top, l)
			sum += l
			if l > 0.5:
				bright += 1
	var mean := sum / float(img.get_width() * img.get_height())
	check(top < BRIGHTEST, "the brightest pixel of the far sky is %.2f, under %.2f" % [top, BRIGHTEST])
	check(mean < MEAN, "the far sky averages %.3f, under %.2f" % [mean, MEAN])
	check(bright < 400, "%d pixels of the far sky are brighter than 0.5 (a few motes; a bolt is thousands)" % bright)

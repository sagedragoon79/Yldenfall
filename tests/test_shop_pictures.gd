extends TestSuite
## The shop shows what it sells (pass 554, bible 12.44). The pass 550 and 540
## grades saw a shop that is "a plain box with no item icons or portrait": every
## item has an icon that leads its row, and the keeper's portrait heads the menu.


## How many texels of `region` in `img` are solid, and how many colors they use.
func _ink(img: Image, region: Rect2) -> Vector2i:
	var solid := 0
	var colors := {}
	for y in range(int(region.position.y), int(region.end.y)):
		for x in range(int(region.position.x), int(region.end.x)):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				solid += 1
				colors[c.to_html(false)] = true
	return Vector2i(solid, colors.size())


func _same(img: Image, a: Rect2, b: Rect2) -> bool:
	for y in int(a.size.y):
		for x in int(a.size.x):
			if img.get_pixel(int(a.position.x) + x, int(a.position.y) + y) != img.get_pixel(int(b.position.x) + x, int(b.position.y) + y):
				return false
	return true


func test_the_shop_shows_what_it_sells() -> void:
	# Every item has an icon of its own, drawn at twice the UI's density.
	var items: Dictionary = GameData.table("items")
	var icons := UiArt.icon_texture()
	check(icons != null, "the item icons are there")
	if icons == null:
		return
	var img := icons.get_image()
	var bounds := Rect2(Vector2.ZERO, img.get_size())
	var seen := {}
	for id: String in items:
		if not check(UiArt.has_icon(id), "%s has an icon" % id):
			continue
		var r := UiArt.icon_region(id)
		check(r.size == Vector2.ONE * UiArt.ICON_SIZE * 2.0 and bounds.encloses(r), "%s's icon is one 2x cell inside the sheet (%s)" % [id, r])
		check(not seen.has(r.position), "%s's icon is its own cell" % id)
		seen[r.position] = id
		var ink := _ink(img, r)
		check(ink.x >= 120 and ink.y >= 4, "%s's icon is a shaded picture, not a blank or a blot (%d texels, %d colors)" % [id, ink.x, ink.y])
	check(not UiArt.has_icon("no_such_item") and UiArt.icon_region("no_such_item") == Rect2(), "an item nobody drew has none")
	# Goods that differ only by a color or a tier are still told apart.
	for pair: Array in [["copper_key", "silver_key"], ["gold_key", "thorn_key"], ["ember_dye", "tide_dye"], ["warden_dye", "jade_dye"],
			["short_sword", "long_sword"], ["temper_1", "temper_2"], ["chart_haar", "chart_spires"], ["fire_scroll", "fracture_scroll"],
			["leather_armor", "riveted_coat"], ["large_shield", "magic_shield"]]:
		check(not _same(img, UiArt.icon_region(pair[0]), UiArt.icon_region(pair[1])), "%s and %s look different" % pair)

	# Every shop has a keeper, and every keeper a portrait.
	var faces := UiArt.portrait_texture()
	check(faces != null, "the portraits are there")
	if faces == null:
		return
	var face_img := faces.get_image()
	var people: Dictionary = GameData.table("npcs")
	for shop_id: String in GameData.table("shops"):
		var who := Menus.keeper(shop_id)
		if not check(who != "" and String(people[who].shop) == shop_id, "%s has a keeper (%s)" % [shop_id, who]):
			continue
		check(UiArt.has_portrait(who), "%s has a portrait" % who)
		var r := UiArt.portrait_region(who)
		var ink := _ink(face_img, r)
		check(r.size == Vector2.ONE * UiArt.PORTRAIT_SIZE * 2.0 and ink.x >= 1200 and ink.y >= 8,
			"%s's portrait is a 2x picture of a person (%s, %d texels, %d colors)" % [who, r.size, ink.x, ink.y])
	check(Menus.keeper("no_such_shop") == "" and not UiArt.has_portrait(""), "a shop nobody keeps has no keeper and no portrait")
	check(not _same(face_img, UiArt.portrait_region("arms_dealer"), UiArt.portrait_region("merchant")), "two keepers are two faces")

	# Each row of a shop leads with the icon of what it sells.
	var room := make_room(grid_rows(12, 8))
	var p := make_player(room, Vector2i(4, 6))
	p.gold = 350
	for shop_id: String in GameData.table("shops"):
		var shelf := Shop.shelf(shop_id)
		var rows := Menus.shop_rows(shop_id, p)
		for i in rows.size():
			var want := String(GameData.shop(shop_id).stock[shelf[i]].item)
			check(String(rows[i].get("icon", "")) == want and UiArt.has_icon(want), "%s row %d shows %s" % [shop_id, i, want])

	# In the menu: the portrait in the corner, the words clear of it, the icons in a column.
	var menu := ListMenu.new()
	arena.add_child(menu)
	await frames(2)
	check(Menus.open_shop(arena.get_tree(), "hearthroot_arms", p), "the arms shop opens")
	check(menu.portrait == "arms_dealer" and menu.shows_portrait(), "with its keeper's portrait (%s)" % menu.portrait)
	var frame := menu.portrait_frame()
	check(menu.panel.encloses(frame.grow(1)) and frame.size.x == UiArt.PORTRAIT_SIZE + ListMenu.PORTRAIT_PAD * 2.0, "framed inside the panel's corner (%s)" % frame)
	check(menu.panel.position.x + 14.0 + menu.subtitle_width() <= frame.position.x - 4.0, "the greeting wraps before the portrait (%.0f wide)" % menu.subtitle_width())
	check(menu.has_icons(), "its rows carry icons")
	var top := 100.0
	for i in menu.rows.size():
		var at := menu.icon_pos(i, top)
		check(at.x >= menu.panel.position.x + 12.0 and at.x + UiArt.ICON_SIZE <= menu.panel.position.x + 14.0 + ListMenu.ICON_INSET
			and at.y >= top + i * ListMenu.ROW_H and at.y + UiArt.ICON_SIZE <= top + (i + 1) * ListMenu.ROW_H,
			"row %d's icon sits in its row, left of its name (%s)" % [i, at])
	await frames(2)
	check(not menu.rows[0].enabled and menu.rows[1].enabled, "350 gold: the sword is out of reach and the jerkin is not, and both are drawn")
	menu.close()
	# Another menu on the same panel starts clean.
	var plain := func() -> Array: return [{"label": "Rest"}, {"label": "Leave"}]
	menu.open("Ringreader", "Sit a while.", plain, func(_i: int) -> void: pass)
	check(menu.portrait == "" and not menu.shows_portrait() and not menu.has_icons(), "a menu with no keeper and no goods has neither picture")
	check(menu.subtitle_width() == menu.panel.size.x - 28.0, "and its words run the panel's width")
	await frames(2)
	menu.portrait = "nobody_at_all"
	check(not menu.shows_portrait(), "someone with no portrait leaves the corner empty")
	await frames(2)
	menu.close()
	menu.queue_free()

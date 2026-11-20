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


## The panel names its controls by the key or button you press and what it does
## there (pass 594, bible 12.79). The pass 590 grade called the shop's "Jump:
## choose / Dash: leave" odd: it named the hero's moves, not the keys, and
## "choose" is not what a shop does.
func test_a_menu_names_its_keys_and_what_they_do() -> void:
	var room := make_room(grid_rows(12, 8))
	var p := make_player(room, Vector2i(4, 6))
	p.gold = 350
	var menu := ListMenu.new()
	arena.add_child(menu)
	await frames(2)
	var pad := not Input.get_connected_joypads().is_empty()
	check(ListMenu.cap_name("jump") == (Controls.button_name("jump") if pad else Controls.key_name("jump")),
		"a cap shows the bound %s (%s)" % ["button" if pad else "key", ListMenu.cap_name("jump")])
	check(Menus.open_shop(arena.get_tree(), "hearthroot_arms", p), "the arms shop opens")
	var want := [{"cap": ListMenu.cap_name("jump"), "verb": "Buy"}, {"cap": ListMenu.cap_name("dash"), "verb": "Leave"}]
	check(menu.prompts() == want, "the shop says Buy and Leave on their keys (%s)" % [menu.prompts()])
	for pr: Dictionary in menu.prompts():
		var words := (String(pr.cap) + " " + String(pr.verb)).to_lower()
		check(not words.contains("jump") and not words.contains("dash") and not words.contains(":"),
			"no prompt names the hero's moves (%s)" % words)
		check(String(pr.cap) not in ["", "-"], "every prompt has a key to press (%s)" % pr.verb)
	# Every cap and word fits on the panel's last line, right of the gold.
	var right := menu.panel.end.x - 14.0
	var w := menu.prompts_width()
	check(w > 40.0 and right - w > menu.panel.position.x + 14.0 + PixelFont.width("Gold 99999", 9) + 8.0,
		"the prompts sit right of the gold (%.0f px wide)" % w)
	var base := menu.panel.end.y - 9.0
	var cap := ListMenu.cap_rect_at(right - w, base, PixelFont.width("A", 8) + ListMenu.CAP_PAD * 2.0)
	check(cap.position.y <= base - ListMenu.CAP_ASCENT - 1.0 and cap.end.y >= base + ListMenu.CAP_DESCENT + 1.0,
		"a cap's frame clears a capital's top and a p's tail (%s)" % cap)
	check(cap.end.y + 1.0 < menu.panel.end.y, "and sits inside the panel")
	await frames(2)
	menu.close()
	# The other menus say what they do; the defaults come back on each open.
	var plain := func() -> Array: return [{"label": "Rest"}, {"label": "Leave"}]
	menu.open("Ringreader", "", plain, func(_i: int) -> void: pass)
	check(menu.prompts()[0].verb == ListMenu.CONFIRM_VERB and menu.prompts()[1].verb == ListMenu.CLOSE_VERB,
		"a plain menu chooses and closes (%s)" % [menu.prompts()])
	menu.on_back = func() -> void: pass
	check(menu.prompts()[1].verb == ListMenu.BACK_VERB, "a sub menu goes back")
	menu.confirm_verb = ""
	check(menu.prompts().size() == 1, "a page you only read names no confirm")
	menu.close()
	check(Menus.open_skills(arena.get_tree(), p) and menu.prompts()[0].verb == "Learn", "the skill tree learns")
	menu.close()
	check(Menus.open_pause(arena.get_tree(), p, func() -> void: pass) and menu.prompts()[-1].verb == "Resume", "the pause menu resumes")
	menu.close()
	check(Menus.open_options(arena.get_tree(), func() -> void: menu.close()), "Options opens")
	var change: Dictionary = menu.prompts()[0]
	check(change.verb == "Change" and String(change.cap).contains("/") and menu.prompts()[1].verb == ListMenu.BACK_VERB,
		"options change a value with Left and Right (%s)" % [menu.prompts()])
	check(not String(change.cap).to_lower().contains("left"), "drawn as arrows, short enough for a cap (%s)" % change.cap)
	menu.close()
	# Rebinding waits for a key and names the one that cancels.
	check(Menus.open_controls(arena.get_tree(), func() -> void: menu.close()), "Controls opens")
	menu.cursor = 4
	menu.confirm()
	check(menu.capture.is_valid() and menu.prompts()[0].cap == "" and menu.prompts()[1].verb == "Cancel"
		and menu.prompts()[1].cap == ListMenu.cap_name("pause"), "while it listens: press a key, or Esc or Start cancels (%s)" % [menu.prompts()])
	menu.capture = Callable()
	menu.close()


## Pass 616 (bible 12.93): the pass 610 and 615 grades saw "a large dead area" on
## the shop's panel and "no comparison with equipped gear". The chosen ware stands
## to one side of the counter, and the rest holds what you have against what it
## gives: gear against what you wear in its place, a temper against your blade,
## a thing you carry several of against how many you carry.
func test_a_ware_is_weighed_against_what_you_wear() -> void:
	var room := make_room(grid_rows(12, 8))
	var p := make_player(room, Vector2i(4, 6))
	p.gold = 9000
	# The numbers, from the data: a starting kit against the arms shop's shelf.
	var sword := Menus.compare("long_sword", p)
	var short := GameData.item("short_sword")
	var long := GameData.item("long_sword")
	check(String(sword.caption) == "Yours: %s" % short.name, "a blade is set against the one in your hand (%s)" % sword.caption)
	check(sword.rows[0] == {"label": "Cut", "was": "%d" % int(short.slash), "now": "%d" % int(long.slash), "dir": 1},
		"its cut, yours then its own, and better (%s)" % [sword.rows[0]])
	check(sword.rows.all(func(r: Dictionary) -> bool: return int(r.dir) == 1) and sword.rows.size() == 3, "cut, heavy and reach all gain (%s)" % [sword.rows])
	var jerkin := Menus.compare("leather_armor", p)
	check(String(jerkin.caption) == "Nothing worn there." and jerkin.rows == [{"label": "Armor", "was": "", "now": "15%", "dir": 1}],
		"armor on a bare back has nothing to stand against (%s)" % [jerkin])
	# A worse thing says so, and a cost counts against a gain.
	GameState.obtain_gear("large_shield", p)
	var buckler := Menus.compare("small_shield", p)
	check(buckler.rows.size() == 2 and buckler.rows.all(func(r: Dictionary) -> bool: return int(r.dir) == -1),
		"a Buckler against a Kite Shield guards and wards less (%s)" % [buckler.rows])
	var broad := Menus.compare("dwarvish_broad_sword", p)
	var by_label := {}
	for r: Dictionary in broad.rows:
		by_label[r.label] = r
	check(int(by_label["Cut"].dir) == 1 and int(by_label["Swing time"].dir) == -1 and String(by_label["Swing time"].now) == "+30%",
		"the Broad Sword cuts harder and swings slower, and the slower swing is marked worse (%s)" % [by_label["Swing time"]])
	check(int(by_label["Two hands"].dir) == 0 and String(by_label["Two hands"].now) == "Yes", "its second hand is told, as neither")
	check(broad.rows.find(by_label["Swing time"]) < broad.rows.find(by_label["Sweep"]), "its costs stand before its sweep, which a short counter drops")
	# What you wear is shown as it is, with nothing to gain.
	var worn := Menus.compare("large_shield", p)
	check(String(worn.caption) == "You wear this." and worn.rows.all(func(r: Dictionary) -> bool: return String(r.was) == "" and int(r.dir) == 0),
		"what you wear shows its own numbers and no arrow (%s)" % [worn])
	# A temper is weighed on your own blade; a tempered blade is weighed tempered.
	var temper := Menus.compare("temper_1", p)
	var hot := roundi(int(short.slash) * (1.0 + GameState.TEMPER_BONUS))
	check(String(temper.caption) == "Your %s" % short.name and temper.rows[0] == {"label": "Cut", "was": "%d" % int(short.slash), "now": "%d" % hot, "dir": 1},
		"a temper shows your blade's cut before and after (%s)" % [temper.rows[0]])
	GameState.data.tempers = {"short_sword": 1}
	check(String(Menus.compare("long_sword", p).rows[0].was) == "%d" % hot, "and a tempered blade is weighed with its temper in")
	check(String(Menus.compare("temper_1", p, "owned").rows[0].was) == "", "a temper you have shows the blade as it is")
	GameState.data.tempers = {}
	# Things you carry: how many now, and how many after.
	p.ointments = 1
	check(Menus.compare("ointment", p).rows == [{"label": "Carried", "was": "1", "now": "2", "dir": 1}], "a Barkbalm: one carried, two after")
	p.ointments = Shop.OINTMENT_MAX
	check(Menus.compare("ointment", p, "full").rows == [{"label": "Carried", "was": "", "now": "%d" % Shop.OINTMENT_MAX, "dir": 0}], "a full belt gains nothing")
	p.ointments = 0
	check(Menus.compare("copper_key", p).rows[0].now == "%d" % (GameState.key_count("copper") + 1), "a key adds one")
	check(Menus.compare("chart_hearthroot", p).is_empty() and Menus.compare("fire_scroll", p).is_empty(), "a chart or a scroll has nothing to weigh")
	# Every ware of every shop: gear and belt things are weighed, in words that fit the counter.
	var table_w := ListMenu.PANEL.size.x - 16.0
	table_w = table_w - roundf(table_w * ListMenu.COMPARE_FROM) - ListMenu.COMPARE_MARGIN
	for shop_id: String in GameData.table("shops"):
		for entry: Dictionary in GameData.shop(shop_id).stock:
			var kind := String(GameData.item(entry.item).kind)
			var against := Menus.compare(String(entry.item), p)
			if GameState.GEAR_KINDS.has(kind) or ["temper", "key", "ointment", "tonic", "elixir", "projectile"].has(kind):
				check(not against.is_empty() and not Array(against.rows).is_empty(), "%s is weighed" % entry.item)
			for other: String in GameData.items_of_kind(kind) if GameState.GEAR_KINDS.has(kind) else []:
				check(PixelFont.width("Yours: %s" % GameData.item(other).name, 9) <= table_w, "the caption for %s fits the table" % other)
			for r: Dictionary in against.get("rows", []):
				var need := PixelFont.width(String(r.label), 9) + 8.0 + PixelFont.width(String(r.was), 9) + 17.0 + PixelFont.width(String(r.now), 9) + ListMenu.COMPARE_MARK
				check(need <= table_w, "%s's %s fits its line (%.0f of %.0f)" % [entry.item, r.label, need, table_w])
	# On the counter: the ware to one side, the table beside it, inside the counter.
	var menu := ListMenu.new()
	arena.add_child(menu)
	await frames(2)
	check(Menus.open_shop(arena.get_tree(), "hearthroot_arms", p), "the arms shop opens")
	await frames(2)
	var counter := menu.counter_rect()
	check(menu.compare_shown() == menu.rows[menu.cursor].compare and not menu.compare_shown().is_empty(), "the chosen ware's comparison is on the counter")
	var side := UiArt.ICON_SIZE * ListMenu.COUNTER_SCALE
	var table := menu.compare_rect(counter)
	check(menu.counter_center(counter).x + side * 0.5 < table.position.x and counter.encloses(table), "the ware stands left of its table (%s, %s)" % [menu.counter_center(counter), table])
	var lay := menu.compare_layout(table)
	check(lay.lines.size() == 1 + menu.compare_shown().rows.size() and lay.lines[0].has("caption"), "a caption, then a line for each number (%d)" % lay.lines.size())
	for line: Dictionary in lay.lines:
		check(line.y - 9.0 >= counter.position.y and line.y + 2.0 <= counter.end.y, "each line is on the counter (%.0f)" % line.y)
	check(lay.was_x < lay.arrow_x and lay.arrow_x + 7.0 < lay.now_x - PixelFont.width("11", 9) + 1.0 and lay.now_x < lay.mark_x - 3.0 and lay.mark_x + 3.0 <= table.end.x,
		"yours, an arrow, the ware's, and a mark, left to right (%s)" % [[lay.was_x, lay.arrow_x, lay.now_x, lay.mark_x]])
	check(ListMenu.BETTER != ListMenu.WORSE and ListMenu.BETTER.g > ListMenu.BETTER.r and ListMenu.WORSE.r > ListMenu.WORSE.g, "better is green and worse is red, and each has a mark of its own shape")
	# The longest comparison in the game still leaves every line on the counter.
	GameState.set_flag("spring:sky")
	menu.refresh()
	menu.cursor = menu.rows.size() - 1
	var long_lay := menu.compare_layout(menu.compare_rect(menu.counter_rect()))
	var labels: Array = long_lay.lines.map(func(l: Dictionary) -> String: return String(l.get("label", "")))
	check(String(menu.rows[menu.cursor].icon) == "dwarvish_broad_sword" and labels.has("Swing time") and labels.has("Two hands"),
		"the Broad Sword's costs are among the lines that fit (%s)" % [labels])
	for line: Dictionary in long_lay.lines:
		check(line.y - 9.0 >= menu.counter_rect().position.y and line.y + 2.0 <= menu.counter_rect().end.y, "and none runs off the counter (%.0f)" % line.y)
	menu.close()
	# A ware with nothing to weigh keeps the middle of the counter.
	check(Menus.open_shop(arena.get_tree(), "hearthroot_charts", p), "the chart shop opens")
	await frames(2)
	check(menu.compare_shown().is_empty() and menu.counter_center(menu.counter_rect()) == menu.counter_rect().get_center(), "a chart stands in the middle, alone")
	menu.close()
	menu.queue_free()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("### 12.93") and bible.contains("`test_a_ware_is_weighed_against_what_you_wear`"), "the bible names the test")

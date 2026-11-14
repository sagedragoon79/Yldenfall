extends TestSuite
## Options, key rebinding, the pause menu and the Barkbalm (design bible 10.2, 14).

const TEMP_SETTINGS := "user://test_settings.cfg"


func _town() -> Dictionary:
	var a := grid_rows(40, 23)
	put_tiles(a, 5, 19, "P")
	return {"test/town": room_text(["name: Town", "zone: test"], a)}


## Back to the defaults the rest of the suite runs on.
func _restore() -> void:
	Settings.reset()
	Settings.apply()
	Settings.path = SETTINGS_PATH
	Feel.rumble_enabled = false
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SETTINGS + suffix))



## Pass 231: every test starts from the same clean slate, whatever the one
## before it did, and the options point at a file of their own, never the
## player's user://settings.cfg.
func test_every_test_starts_from_a_clean_slate() -> void:
	check(Settings.path == SETTINGS_PATH and Settings.path != Settings.PATH, "the options file is the tests' own (%s)" % Settings.path)
	check((runner.call("_leaks") as Array).is_empty(), "nothing the last test changed is left (%s)" % [runner.call("_leaks")])
	Settings.damage_numbers = true
	TimeStop.start()
	var leaks: Array = runner.call("_leaks")
	check(leaks.has("settings changed") and leaks.has("time stopped"), "a changed option and stopped time count as leaks (%s)" % [leaks])
	# A button left down through the real controller is a leak too (pass 391).
	Input.action_press("jump")
	Input.action_press("attack")
	leaks = runner.call("_leaks")
	check(leaks.has("buttons held (jump, attack)") or leaks.has("buttons held (attack, jump)"), "a button left held counts as a leak (%s)" % [leaks])
	runner.call("_clean_slate")
	check((runner.call("_leaks") as Array).is_empty(), "and the slate wipes them")
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("attack"), "the buttons are let go")
	# A save a test leaves behind, or a game it leaves paused, is a leak too (pass 399).
	const SLOT := 96
	GameState.delete_save(SLOT)
	runner.call("_clean_slate")
	var was := GameState.slot
	check(GameState.save_game(SLOT), "a test may write a save of its own")
	GameState.slot = was
	leaks = runner.call("_leaks")
	check(leaks.has("saves changed (save_%d.json)" % SLOT), "a save left on disk counts as a leak (%s)" % [leaks])
	GameState.delete_save(SLOT)
	check((runner.call("_leaks") as Array).is_empty(), "and pouring it out again puts things back")
	arena.get_tree().paused = true
	leaks = runner.call("_leaks")
	arena.get_tree().paused = false
	check(leaks.has("the game left paused"), "a game left paused counts as a leak (%s)" % [leaks])
	arena.get_tree().paused = true
	runner.call("_clean_slate")
	check(not arena.get_tree().paused, "and the slate unpauses it")
	# Pass 407: a test slot left chosen is a leak too. Later tests would save
	# there, past the check that guards the player's flasks.
	var slot_was := GameState.slot
	GameState.slot = 9
	leaks = runner.call("_leaks")
	check(leaks.has("save slot left on 9"), "a save slot left changed counts as a leak (%s)" % [leaks])
	runner.call("_clean_slate")
	check(GameState.slot == 1 and (runner.call("_leaks") as Array).is_empty(), "and the slate puts the first flask back")
	GameState.slot = slot_was
	# Pass 415: the journey itself starts fresh. A shield, a blade, gold or a
	# key one test obtained must not reach the next test's bare hero.
	GameState.obtain_gear("small_shield", null)
	GameState.data.gold = 777
	GameState.active = false
	leaks = runner.call("_leaks")
	check(leaks.has("the gym's no-record mode left on"), "the gym's no-record mode left on counts as a leak (%s)" % [leaks])
	runner.call("_clean_slate")
	check(GameState.data == GameState.fresh(), "and the slate starts a fresh journey (gold %s, gear %s)" % [GameState.data.gold, GameState.data.gear])
	check(GameState.active and (runner.call("_leaks") as Array).is_empty(), "with kills recorded again")
	# Pass 423: and in silence. A track left playing would make the next
	# test's "plays its music" check pass with no play at all.
	Music.play("boss", 0.0)
	Music.ambience("amb_heartwood", 0.0)
	Music.intensify(2)
	runner.call("_clean_slate")
	check(Music.track == "" and Music.ambience_track == "" and Music.intensity == 0,
		"and the slate hushes the music (%s, %s, %d)" % [Music.track, Music.ambience_track, Music.intensity])
	Music.play("boss", 0.0)
	check(Music.track == "boss", "so the next play of a track is a real change")
	runner.call("_clean_slate")
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("A journey left behind (pass 415)"), "bible 15.3 names the fresh journey")
	check(note.contains("Music left playing (pass 423)"), "and the silence (pass 423)")
	check(note.contains("Saves and pauses left behind (pass 399)"), "bible 15.3 says so")
	check(note.contains("A save slot left behind (pass 407)"), "and the slot (pass 407)")

func test_settings_save_load_and_apply() -> void:
	Settings.path = TEMP_SETTINGS
	Settings.reset()
	Settings.adjust("shake", 1)
	Settings.adjust("flashes", 2)
	Settings.adjust("music", -3)
	Settings.adjust("sound", 5)
	Settings.adjust("rumble", 1)
	check(Feel.shake_scale == 0.5 and Feel.flash_scale == 0.0 and not Feel.rumble_enabled, "shake, flashes and rumble reach Feel")
	check(Settings.sound_volume == Settings.VOLUME_MAX, "volume clamps at the top (%d)" % Settings.sound_volume)
	var music := AudioServer.get_bus_index("Music")
	check(music != -1 and is_equal_approx(AudioServer.get_bus_volume_db(music), -15.0), "music volume sets its bus")
	Settings.adjust("shake", 2)
	check(Settings.shake == 0, "lists wrap around")
	Settings.reset()
	check(Settings.music_volume == 8, "reset to defaults")
	Settings.load_settings()
	check(Settings.flashes == 2 and Settings.music_volume == 5 and not Settings.rumble, "settings survive a save and load")
	_restore()


func test_flashes_option_dims_the_screen_flash() -> void:
	var hud := GameHud.new()
	arena.add_child(hud)
	Feel.flash_scale = 0.35
	GameState.flash.emit(1.0)
	check(is_equal_approx(hud.get("_flash"), 0.35), "a reduced flash is 35%% as bright (%.2f)" % hud.get("_flash"))
	Feel.flash_scale = 1.0


func test_game_speed_slows_everything_evenly() -> void:
	Settings.speed = 3
	Settings.apply()
	check(is_equal_approx(Engine.time_scale, 0.7), "70%% speed (%.2f)" % Engine.time_scale)
	Feel.reset()
	check(is_equal_approx(Engine.time_scale, 0.7), "resets keep the chosen speed")
	Feel.slowmo(0.5, 0.2)
	check(is_equal_approx(Engine.time_scale, 0.35), "slow motion is relative to it (%.2f)" % Engine.time_scale)
	_restore()
	Feel.reset()
	check(is_equal_approx(Engine.time_scale, 1.0), "back to full speed")


func test_rebinding_swaps_and_resets() -> void:
	Settings.path = TEMP_SETTINGS
	var jump := Controls.primary_key("jump")
	var attack := Controls.primary_key("attack")
	Settings.bind_key("jump", KEY_N)
	check(Controls.primary_key("jump") == KEY_N, "jump is on N")
	check(_has_key("jump", KEY_Z), "jump keeps its other keys")
	Settings.bind_key("attack", KEY_N)
	check(Controls.primary_key("attack") == KEY_N and Controls.primary_key("jump") == attack, "taking another action's key swaps them")
	check(not _has_key("jump", KEY_N), "N now does only one thing")
	Settings.bind_key("dash", KEY_K)
	check(not _has_key("jump", KEY_K) and _has_key("dash", KEY_K), "a key taken from another action's spares leaves it")
	Settings.load_settings()
	Settings.apply()
	check(Controls.primary_key("attack") == KEY_N, "bindings survive a save and load")
	Settings.reset_keys()
	check(Controls.primary_key("jump") == jump and Controls.primary_key("attack") == attack, "reset puts the defaults back")
	_restore()


## Pass 365: bible 14 promises full remapping, and the pad had none; a player
## on a gamepad was held to its layout. Each listed action now takes a pad
## button as well as a key, and the real input then follows it.
func test_the_pad_can_be_rebound() -> void:
	Settings.path = TEMP_SETTINGS
	check(Controls.button_name("jump") == "A" and Controls.button_name("attack") == "X" and Controls.button_name("heal") == "LT",
		"the pad's defaults: Jump on A, Attack on X, the potion on the left trigger")
	var jump_key := Controls.primary_key("jump")
	check(Settings.bind_button("jump", JOY_BUTTON_Y), "Jump takes Y")
	check(Controls.primary_button("jump") == JOY_BUTTON_Y and Controls.primary_button("spell") == JOY_BUTTON_A,
		"and the spell, which had Y, swaps onto A")
	check(Controls.primary_key("jump") == jump_key and Controls.key_name("jump") != "-", "Jump keeps its keys")
	_press_pad(JOY_BUTTON_Y, true)
	check(Input.is_action_pressed("jump") and not Input.is_action_pressed("spell"), "Y now jumps, and only jumps")
	_press_pad(JOY_BUTTON_Y, false)
	_press_pad(JOY_BUTTON_A, true)
	check(Input.is_action_pressed("spell") and not Input.is_action_pressed("jump"), "A now casts")
	_press_pad(JOY_BUTTON_A, false)
	check(not Settings.bind_button("heal", JOY_BUTTON_A), "the potion, on a trigger, can't take a button another action needs")
	check(Controls.primary_button("spell") == JOY_BUTTON_A and Controls.primary_button("heal") == -1, "and nothing moves")
	check(Settings.bind_button("heal", JOY_BUTTON_PADDLE1) and Controls.button_name("heal") == "P1", "but it can take a free one")
	for b: int in [JOY_BUTTON_START, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK]:
		check(not Settings.bind_button("attack", b), "%s stays with the action the page doesn't list" % Controls.PAD_NAMES[b])
	check(Controls.primary_button("pause") == JOY_BUTTON_START and Controls.primary_button("attack") == JOY_BUTTON_X, "Start still pauses")
	Settings.load_settings()
	Settings.apply()
	check(Controls.primary_button("jump") == JOY_BUTTON_Y and Controls.primary_button("heal") == JOY_BUTTON_PADDLE1, "buttons survive a save and load")
	var cfg := ConfigFile.new()
	cfg.set_value("buttons", "jump", "yes")
	cfg.set_value("buttons", "dash", 999)
	cfg.set_value("buttons", "attack", JOY_BUTTON_Y)
	GameState.write_safely(TEMP_SETTINGS, cfg.encode_to_text())
	Settings.load_settings()
	check(not Settings.buttons.has("jump") and not Settings.buttons.has("dash") and Settings.buttons.get("attack", -1) == JOY_BUTTON_Y,
		"only a real button is read from the file")
	Settings.reset_keys()
	check(Controls.primary_button("jump") == JOY_BUTTON_A and Controls.primary_button("spell") == JOY_BUTTON_Y
		and Controls.button_name("heal") == "LT", "reset puts the pad back")
	# The Controls page, pressed from the pad.
	var menu := ListMenu.new()
	arena.add_child(menu)
	check(Menus.open_controls(arena.get_tree(), func() -> void: menu.close()), "Controls opens")
	check(menu.rows[0].right.ends_with(Controls.button_name("move_left")) and menu.rows[4].right.ends_with("A"), "each row shows its key and its button")
	menu.cursor = 4
	menu.confirm()
	_menu_pad(menu, JOY_BUTTON_START)
	check(Controls.primary_button("jump") == JOY_BUTTON_A and not menu.capture.is_valid(), "Start cancels and changes nothing")
	menu.confirm()
	_menu_pad(menu, JOY_BUTTON_RIGHT_SHOULDER)
	check(Controls.primary_button("jump") == JOY_BUTTON_RIGHT_SHOULDER and Controls.primary_button("throw") == JOY_BUTTON_A,
		"a pad button pressed on the page rebinds it")
	check(menu.rows[4].right.ends_with("RB"), "and the row says so")
	menu.close()
	menu.free()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("**The pad, rebound (pass 365):**"), "bible 14 tells the pad's rebinding")
	_restore()


## Sean, 2026-11-09: his controller did nothing in play. Pad bindings made in
## code belonged to device 0 alone, and on his PC a Razer keypad that reports
## itself as a joystick holds device 0, so the real pad came in as device 1.
## Every pad binding now answers any pad, the defaults and a rebind alike.
func test_a_second_pad_is_heard() -> void:
	Settings.path = TEMP_SETTINGS
	for action: String in Controls.BINDINGS:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				check(ev.device == Controls.ANY_PAD, "%s's pad binding answers every pad" % action)
	for device: int in [1, 3]:
		_press_pad(JOY_BUTTON_A, true, device)
		check(Input.is_action_pressed("jump"), "A on pad %d jumps" % device)
		_press_pad(JOY_BUTTON_A, false, device)
		check(not Input.is_action_pressed("jump"), "and letting go of it lands")
		_move_axis(JOY_AXIS_LEFT_X, 1.0, device)
		check(Input.is_action_pressed("move_right"), "pad %d's stick walks right" % device)
		_move_axis(JOY_AXIS_LEFT_X, 0.0, device)
		_move_axis(JOY_AXIS_TRIGGER_LEFT, 1.0, device)
		check(Input.is_action_pressed("heal"), "pad %d's left trigger drinks" % device)
		_move_axis(JOY_AXIS_TRIGGER_LEFT, 0.0, device)
	check(Settings.bind_button("jump", JOY_BUTTON_RIGHT_SHOULDER), "Jump takes RB")
	_press_pad(JOY_BUTTON_RIGHT_SHOULDER, true, 1)
	check(Input.is_action_pressed("jump"), "a rebound button answers pad 1 too")
	_press_pad(JOY_BUTTON_RIGHT_SHOULDER, false, 1)
	Settings.reset_keys()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("**Any pad (2026-11-09):**"), "bible 14 tells it")
	_restore()


## Pass 366: a menu's refusal had borrowed the spell-fail fizzle, so a ware
## you couldn't afford sounded like a cast short of MP. A menu now says no in
## its own voice, and the fizzle is left to the spells and the Stillstone.
func test_a_menu_says_no_in_its_own_voice() -> void:
	Settings.path = TEMP_SETTINGS
	check(FileAccess.file_exists("res://assets/sfx/menu_refuse.wav"), "the refusal has a file")
	var menu := ListMenu.new()
	arena.add_child(menu)
	var chosen := [false]
	menu.open("Shop", "", func() -> Array: return [{"label": "Too dear", "enabled": false}, {"label": "Leave"}],
		func(_i: int) -> void: chosen[0] = true)
	Sfx.recent.clear()
	menu.cursor = 0
	menu.confirm()
	check(not chosen[0] and Sfx.recent == ["menu_refuse"], "a row you can't choose says no, no fizzle (%s)" % [Sfx.recent])
	menu.close()
	check(Menus.open_controls(arena.get_tree(), func() -> void: menu.close()), "Controls opens")
	menu.cursor = 0
	menu.confirm()
	Sfx.recent.clear()
	_menu_pad(menu, JOY_BUTTON_LEFT_STICK)
	check(Sfx.recent == ["menu_refuse"] and Controls.primary_button("stillstone") == JOY_BUTTON_LEFT_STICK,
		"a pad button the page keeps says no as well (%s)" % [Sfx.recent])
	menu.close()
	menu.free()
	# Who still fizzles: the hero's spells and the Stillstone, and no menu.
	var dirs: Array[String] = ["res://scripts"]
	var fizzlers: Array[String] = []
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
		for f: String in DirAccess.get_files_at(d):
			if f.ends_with(".gd") and FileAccess.get_file_as_string(d + "/" + f).contains("Sfx.play(\"fizzle\""):
				fizzlers.append(f)
	check(fizzlers == ["player.gd"], "only the hero's spells and glass fizzle (%s)" % [fizzlers])
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("**A menu that says no (pass 366):**") and bible.contains("`menu_refuse`"), "bible 13.3 tells it")
	_restore()


func _press_pad(button: int, down: bool, device := 0) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button as JoyButton
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _move_axis(axis: JoyAxis, value: float, device: int) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _menu_pad(menu: ListMenu, button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button as JoyButton
	ev.pressed = true
	menu._input(ev)


func _has_key(action: String, key: Key) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == key:
			return true
	return false


func test_fullscreen_toggle_keys() -> void:
	var game := preload("res://scripts/game.gd")
	var key := func(code: Key, alt := false, pressed := true) -> InputEventKey:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.alt_pressed = alt
		ev.pressed = pressed
		return ev
	check(game.is_fullscreen_toggle(key.call(KEY_F11)), "F11 toggles fullscreen")
	check(game.is_fullscreen_toggle(key.call(KEY_ENTER, true)), "Alt+Enter toggles fullscreen")
	check(not game.is_fullscreen_toggle(key.call(KEY_ENTER)), "plain Enter does not")
	check(not game.is_fullscreen_toggle(key.call(KEY_F11, false, false)), "releasing F11 does not")


func test_ointment_is_bought_used_and_wears_off() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	p.gold = 2000
	var shop := "hearthroot_items"
	var index := 3
	check(GameData.item(GameData.shop(shop).stock[index].item).kind == "ointment", "Hearthroot sells Barkbalm")
	for i in Shop.OINTMENT_MAX:
		Shop.buy(shop, index, p)
	check(p.ointments == Shop.OINTMENT_MAX and Shop.status(shop, index, p) == "full", "you can carry %d" % Shop.OINTMENT_MAX)
	check(int(GameState.data.ointments) == Shop.OINTMENT_MAX, "Barkbalms are saved")
	check(p.use_ointment() and p.ointments == Shop.OINTMENT_MAX - 1, "rubbing one on uses it")
	check(not p.use_ointment(), "only one at a time")
	var hp := p.hp
	p.take_damage(30)
	check(p.hp == hp and p.invulnerable, "nothing hurts while it lasts")
	await frames(roundi(Player.OINTMENT_TIME * 60.0) + 10)
	check(p.ointment_left == 0.0 and not p.invulnerable, "it wears off after %d s" % int(Player.OINTMENT_TIME))
	p.take_damage(30)
	check(p.hp < hp, "and then hits land again")


func test_pause_menu_and_its_sub_menus() -> void:
	Settings.path = TEMP_SETTINGS
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(2)
	var menu := ListMenu.new()
	arena.add_child(menu)
	var quit := [false]
	check(Menus.open_pause(arena.get_tree(), p, func() -> void: quit[0] = true), "the pause menu opens")
	check(menu.title == "Paused" and arena.get_tree().paused, "and pauses the game")
	check(not menu.rows[1].enabled, "no Barkbalm to use yet")
	menu.cursor = 2
	menu.confirm()
	check(menu.title == "Equipment" and menu.rows[0].get("header", false) and menu.rows[1].label == "Short Sword", "Equipment lists your gear by slot")
	menu.back()
	menu.cursor = 3
	menu.confirm()
	check(menu.title == "Inventory" and menu.rows[0].label == "Nothing yet", "Inventory opens, empty at the start")
	menu.back()
	menu.cursor = 4
	menu.confirm()
	check(menu.title == "Options" and menu.is_open, "Options opens in place")
	var before := Settings.shake
	menu.cursor = 0
	menu.adjust(1)
	check(Settings.shake != before, "Left/Right changes the selected option")
	menu.back()
	check(menu.title == "Paused", "backing out returns to the pause menu")
	menu.cursor = 5
	menu.confirm()
	check(menu.title == "Controls" and menu.rows.size() == Settings.REBINDABLE.size() + 2, "Controls lists the rebindable actions")
	menu.cursor = 0
	menu.confirm()
	check(menu.capture.is_valid() and menu.rows[0].right == "...", "choosing one waits for a key")
	menu.back()
	menu.cursor = 6
	menu.confirm()
	check(menu.title == "Journey" and menu.is_open, "Journey opens in place")
	menu.back()
	check(menu.title == "Paused", "and backs out to the pause menu")
	menu.cursor = 7
	menu.confirm()
	check(quit[0] and not menu.is_open and not arena.get_tree().paused, "Quit closes the menu and quits")
	_restore()



## The Inventory page (pass 205, bible 10.3): every found ability, spell,
## relic, ring, key and shard is listed with what it does, under its group,
## in a fixed order; nothing you lack is shown.
func test_the_inventory_page_lists_what_you_have_found() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(2)
	var labels := func() -> Array: return Menus.inventory_rows(p).map(func(r: Dictionary) -> String: return r.label)
	check(labels.call() == ["Nothing yet"], "a new game has nothing to list (%s)" % [labels.call()])
	p.abilities.glove = true
	p.abilities.delvers_pick = true
	p.abilities.torrent = true
	p.abilities.fire = true
	p.equipped_spell = "fire"
	p.abilities.pendant = true
	GameState.data.rings = ["fall", "thaw"]
	GameState.add_key("copper", 2)
	GameState.add_key("lantern")
	GameState.data.potion_shards = 4
	GameState.data.meteor_shards = 1
	var rows := Menus.inventory_rows(p)
	check(labels.call() == ["Abilities", "Climbing Glove", "Delver's Pick", "Spells", "Deluge", "Emberfall", "Relics", "Acorn Charm",
		"Rings, 2 of 4", "Thaw Seed", "Fall Seed", "Keys", "Copper Key", "Lantern Key", "Shards", "Potion Shards", "Stillglass Shards"],
		"each find under its group, in order (%s)" % [labels.call()])
	var by := {}
	for r: Dictionary in rows:
		by[r.label] = r
	check(by["Emberfall"].right == "Ready" and by["Deluge"].right == "", "the readied spell is marked")
	check(String(by["Emberfall"].detail).begins_with("An ember"), "a spell learned from a scroll says what it does (%s)" % by["Emberfall"].detail)
	check(by["Copper Key"].right == "x2" and by["Lantern Key"].right == "x1", "keys show how many you carry")
	check(by["Potion Shards"].right == "1 of 3", "shards count toward their next whole")
	var blank := rows.filter(func(r: Dictionary) -> bool: return not r.get("header", false) and String(r.get("detail", "")) == "")
	check(blank.is_empty(), "every find says what it does (%s)" % [blank])
	for id: String in ItemPickup.ABILITIES + ["delvers_pick", "fire", "wisplight"]:
		var listed := Menus.INVENTORY_GROUPS.any(func(g: Array) -> bool: return Array(g[1]).has(id))
		check(listed and Menus.ability_info(id)[1] != "", "%s has a place and a line on the page" % id)
	# With everything found, every line still fits the menu's three-line box.
	for g: Array in Menus.INVENTORY_GROUPS:
		for id: String in g[1]:
			p.abilities[id] = true
	GameState.data.rings = Array(CrownGate.RINGS)
	for k: String in Menus.KEY_ORDER:
		GameState.add_key(k)
	GameState.data.grain_shards = 2
	var width := ListMenu.PANEL.size.x - 28
	var long := []
	for row: Dictionary in Menus.inventory_rows(p):
		var n := PixelFont.wrap_lines(String(row.get("detail", "")), width, 9).size()
		if n > 3:
			long.append("%s: %d lines" % [row.label, n])
	check(long.is_empty(), "every line fits in three lines: %s" % [long])
	check(Menus.inventory_rows(p).size() == 7 + 6 + 2 + 4 + 7 + 3 + 6, "and all of it is listed")
	_restore()

## The pixel font (bible 12): every printable ASCII character has a glyph, and
## text only ever scales by whole numbers, so it stays on the pixel grid.
func test_pixel_font_covers_ascii_and_scales_by_whole_numbers() -> void:
	var f := PixelFont.font()
	var h := PixelFont.height()
	check(f != null and f.fixed_size == h, "the font builds at its native height (%d)" % h)
	var missing := ""
	for code in range(33, 127):
		if not f.has_char(code) or f.get_string_size(char(code), HORIZONTAL_ALIGNMENT_LEFT, -1, h).x <= 0.0:
			missing += char(code)
	check(missing == "", "every printable character has a glyph (missing: %s)" % missing)
	var one := f.get_string_size("Lantern Key", HORIZONTAL_ALIGNMENT_LEFT, -1, h)
	var two := f.get_string_size("Lantern Key", HORIZONTAL_ALIGNMENT_LEFT, -1, h * 2)
	check(one.x == roundf(one.x) and two.x == one.x * 2.0, "2x text is exactly twice as wide (%s, %s)" % [one.x, two.x])
	check(f.get_height(h * 3) == h * 3, "and three times as tall at 3x")
	var scales := [8, 10, 12, 14, 18, 22, 44].map(func(s: int) -> int: return PixelFont.scale_for(s))
	check(scales == [1, 1, 1, 1, 2, 2, 4], "requested sizes snap to whole scales (%s)" % [scales])
	var lines := PixelFont.wrap_lines("The Haar Spring has dried, and the dwarves of Kettleforge quake.", 120.0, 10)
	var widest := 0.0
	for l in lines:
		widest = maxf(widest, PixelFont.width(l, 10))
	check(lines.size() > 1 and widest <= 120.0, "wrapping keeps lines inside the box (%d lines, %.0f px)" % [lines.size(), widest])


## With the pixel font, every page anyone says still fits the dialog box.
func test_every_npc_line_fits_the_dialog_box() -> void:
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json"))
	var width := DialogBox.BOX.size.x - 24
	var too_long: Array[String] = []
	var pages := 0
	for id: String in npcs:
		var info: Dictionary = npcs[id]
		var said: Array = []
		for key: String in info:
			var v: Variant = info[key]
			if v is String and key.begins_with("greeting"):
				said.append(v)
			elif v is Array and key.contains("lines"):
				said.append_array(v)
		for line: Variant in said:
			if not line is String:
				continue
			pages += 1
			var n := PixelFont.wrap_lines(line, width, 11).size()
			if n > DialogBox.MAX_LINES:
				too_long.append("%s: %d lines: %s" % [id, n, String(line).left(40)])
	check(pages > 20, "the scan reads the cast's lines (%d pages)" % pages)
	check(too_long.is_empty(), "every page fits in %d lines: %s" % [DialogBox.MAX_LINES, too_long])


func test_no_sound_starts_without_a_sound_device() -> void:
	# Headless runs use the Dummy driver, which never mixes: a started playback
	# would sit in the audio server until exit and be reported as a leak.
	check(Sfx.silent and Music.silent, "the test run has no sound device, and Sfx and Music know it")
	Sfx.play("blip")
	var playing := Sfx.get_children().any(func(p: Node) -> bool: return (p as AudioStreamPlayer).playing)
	check(not playing, "so a sound is never started")


func test_the_ending_tells_climbs_and_thanks() -> void:
	var e := EndingScreen.new()
	arena.add_child(e)
	e.start("Heartwood", 3725.0)
	check(e.phase == "epilogue" and e.card == 0, "the ending opens on its first card")
	e.tick(EndingScreen.CARD_TIME + 0.1)
	check(e.card == 1, "the cards turn on their own")
	e.advance()
	e.tick(0.01)
	check(e.card == 2, "and a press turns one sooner")
	e.tick(EndingScreen.CARD_TIME * (e.cards().size() - 2))
	check(e.phase == "credits", "then the climb up the Tree begins")
	e.tick(10.0)
	check(e.climb > 0.0 and e.climb < EndingScreen.CLIMB, "climbing at its own pace (%.0f px)" % e.climb)
	var slow := e.climb
	e.fast = true
	e.tick(1.0)
	check(e.climb - slow > EndingScreen.SPEED * 3.0, "faster while a button is held")
	e.fast = false
	e.tick(EndingScreen.CLIMB / EndingScreen.SPEED)
	check(e.phase == "thanks", "the credits end on the thanks card")
	var done := [false]
	e.finished.connect(func() -> void: done[0] = true)
	e.advance()
	check(not done[0], "a press held over from the credits does not skip it")
	e.tick(EndingScreen.THANKS_GRACE)
	e.advance()
	check(done[0] and not e.visible, "a press after a moment ends it")
	e.queue_free()


## Yldenfall's ending (pass 167): the town would thank you, and the wanderer
## walks on. The last two cards say so while the hero walks off east.
func test_the_ending_closes_on_the_wanderer_walking_on() -> void:
	var e := EndingScreen.new()
	arena.add_child(e)
	for secret: bool in [false, true]:
		e.start("Heartwood", 0.0, secret, 0)
		var n := e.cards().size()
		check(e.cards().slice(n - 2) == EndingScreen.FAREWELL, "the farewell closes the epilogue (secret %s)" % secret)
		check(String(EndingScreen.FAREWELL[0]).contains("Leaffall") and String(EndingScreen.FAREWELL[1]).contains("east road"), "the Leaffall's thanks, then the road")
		e.tick(e.farewell_start() - 0.5)
		check(e.wanderer_x() < 0.0, "no one walks before the farewell")
		e.tick(0.6)
		var x0 := e.wanderer_x()
		check(x0 >= 320.0 and x0 < 350.0, "the wanderer sets out from the foot of the Tree (%.0f)" % x0)
		e.tick(EndingScreen.CARD_TIME * 2.0 - 0.2)
		check(e.phase == "epilogue" and e.wanderer_x() > 640.0, "and is off the east edge before the climb (%.0f)" % e.wanderer_x())
		e.tick(0.2)
		check(e.phase == "credits", "then the credits climb")
	check(Sheet.has_anim(PlayerVisual.SHEET_NAME, "run"), "the walk is the hero's own")
	for line: String in EndingScreen.FAREWELL:
		check(PixelFont.width(line, 12) < 600.0, "the card fits the screen: %s" % line)
	e.queue_free()


func test_pause_skips_the_ending_to_the_thanks_card() -> void:
	var e := EndingScreen.new()
	arena.add_child(e)
	e.start("Heartwood", 0.0)
	e.tick(1.0)
	e.skip()
	check(e.phase == "thanks", "from the epilogue")
	e.start("Heartwood", 0.0)
	e.tick(e.cards().size() * EndingScreen.CARD_TIME + 1.0)
	check(e.phase == "credits", "the climb has begun")
	e.skip()
	check(e.phase == "thanks", "and from the climb")
	e.queue_free()


func test_the_game_plays_the_ending_then_returns_to_the_title() -> void:
	Settings.path = TEMP_SETTINGS
	GameState.new_game()
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.menu.close()
	g.title_screen.visible = false
	g._start("evercrown/heart")
	# A test must not write the real save.
	g.world.use_game_state = false
	await frames(5)
	GameState.begin_ending()
	await frames(2)
	check(g.ending.visible and g.ending.phase == "epilogue", "the Everbloom's death plays the ending")
	check(runner.get_tree().paused, "over a frozen world")
	check(Music.track == "ending", "to its own music (%s)" % Music.track)
	check(Music.ambience_track == "", "and the Everbloom's heartbeat fades out under it (pass 468: %s)" % Music.ambience_track)
	g.ending.skip()
	g.ending.tick(EndingScreen.THANKS_GRACE)
	g.ending.advance()
	await frames(3)
	check(g.world == null and g.title_screen.visible and g.menu.is_open, "then the game goes back to the title")
	check(not g.ending.visible and g.hud.visible, "with the ending gone and the HUD back for the next game")
	check(Music.track == "title" and Music.ambience_track == "", "the title plays its own theme over no bed (%s, %s)" % [Music.track, Music.ambience_track])
	g.menu.close()
	g.queue_free()
	await frames(2)
	_restore()



## Pass 469: the whole game, played to its end and begun again in one run, by
## the buttons. The ending had only been driven with `skip`, `tick` and
## `advance`, and no test took a new journey up after it. Here Jump turns the
## epilogue's cards, Pause skips to the thanks card without opening the pause
## menu, Jump inside the thanks card's grace does nothing and after it goes to
## the title; the title does not take that Jump, and Jump, Jump takes a new
## journey up from an empty flask, where the hero walks with a real Right.
func test_the_game_is_ended_and_begun_again_with_the_buttons() -> void:
	Settings.path = TEMP_SETTINGS
	var slot_was := GameState.slot
	for slot: int in [97, 98, 99]:
		GameState.delete_save(slot)
	GameState.new_game()
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.picker.slots = [97, 98, 99]
	g.menu.close()
	g.title_screen.visible = false
	g._start("evercrown/heart")
	g.world.use_game_state = false
	await frames(5)
	GameState.begin_ending()
	await frames(2)
	var e: EndingScreen = g.ending
	check(e.visible and e.phase == "epilogue" and e.card == 0, "the ending opens on its first card")
	await _tap("jump")
	check(e.card == 1, "Jump turns to the next card (%d)" % e.card)
	await _tap("attack")
	check(e.card == 2, "and so does Attack (%d)" % e.card)
	await _tap("pause")
	check(e.phase == "thanks" and not g.menu.is_open, "Pause skips to the thanks card, and opens no pause menu")
	await _tap("jump")
	check(e.visible and e.phase == "thanks", "Jump inside the card's grace does nothing")
	await frames(int(EndingScreen.THANKS_GRACE * 60.0) + 2)
	check(e.visible and e.phase == "thanks", "the card waits for a press")
	await _tap("jump")
	await frames(2)
	check(not e.visible and g.world == null and g.title_screen.visible, "Jump after it goes back to the title")
	check(g.menu.is_open and g.menu.title == "A wanderer returns" and not g.picker.is_open,
		"where the title's menu is up, and the Jump that closed the ending did not open the flasks")
	check(Music.track == "title" and Music.ambience_track == "", "to the title's theme (%s, %s)" % [Music.track, Music.ambience_track])
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap("jump")
	check(g.picker.is_open and not g.menu.is_open, "Jump on Journeys opens the shelf")
	await frames(int(SlotPicker.INPUT_GRACE * 60.0) + 2)
	await _tap("jump")
	await frames(5)
	check(g.world != null and g.world.room.id == "hearthroot/west_gate" and GameState.slot == 97 and not arena.get_tree().paused,
		"Jump uncorks the first empty flask and a new journey begins at the West Gate")
	check(not GameState.flag("cleared") and g.hud.visible and g.hud.player == g.player and not e.visible,
		"a fresh one, with the HUD on its own hero and the ending gone")
	check(Music.track == "hearthroot" and Music.ambience_track == "amb_hearthroot", "under Hearthroot's theme and bed (%s, %s)" % [Music.track, Music.ambience_track])
	await frames(30)
	var x0: float = g.player.global_position.x
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	await frames(2)
	check(g.player.global_position.x - x0 > 40.0, "and the hero walks on with a real Right (%.0f px)" % (g.player.global_position.x - x0))
	g.queue_free()
	await frames(2)
	for slot: int in [97, 98, 99]:
		GameState.delete_save(slot)
	GameState.slot = slot_was
	GameState.new_game()
	_restore()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("Ended and begun again, by the buttons (pass 469)"), "the bible says so")

## Bible 11: the secret ending counts every death of the run.
func test_deaths_are_counted_and_kept_in_the_save() -> void:
	var slot_was := GameState.slot
	var w := make_world({}, "hearthroot/west_gate")
	await frames(3)
	check(int(GameState.data.deaths) == 0, "a new game starts with no deaths")
	w.player._die(w.player.global_position)
	await frames(2)
	check(int(GameState.data.deaths) == 1, "falling counts one (%d)" % int(GameState.data.deaths))
	const SLOT := 9
	GameState.slot = SLOT
	GameState.save_game()
	GameState.new_game()
	check(int(GameState.data.deaths) == 0, "a new game clears the count")
	GameState.load_game(SLOT)
	check(int(GameState.data.deaths) == 1, "and loading the save brings it back")
	GameState.delete_save(SLOT)
	GameState.slot = slot_was



func test_the_secret_ending_needs_no_deaths_and_the_elven_plate() -> void:
	GameState.new_game()
	check(not GameState.secret_ending(), "no deaths alone is not enough")
	GameState.data.equipment.armor = "elven_plate"
	check(GameState.secret_ending(), "no deaths in the Elven Plate is the secret ending")
	GameState.data.deaths = 1
	check(not GameState.secret_ending(), "one death and it is gone")
	GameState.data.deaths = 0
	GameState.begin_ending()
	check(GameState.flag("cleared") and GameState.flag("cleared_secret"), "a secret clear is marked in the save")
	GameState.new_game()


func test_the_secret_ending_adds_the_sources_cards() -> void:
	var e := EndingScreen.new()
	arena.add_child(e)
	e.start("Ylden's Own", 0.0, false, 3)
	e.tick((EndingScreen.EPILOGUE.size() + EndingScreen.FAREWELL.size()) * EndingScreen.CARD_TIME + 0.1)
	check(e.phase == "credits", "the plain ending climbs after its four cards and the farewell")
	e.start("Ylden's Own", 0.0, true, 0)
	check(e.cards().size() == EndingScreen.EPILOGUE.size() + EndingScreen.SECRET_EPILOGUE.size() + EndingScreen.FAREWELL.size(), "the secret ending has more cards")
	e.tick(EndingScreen.EPILOGUE.size() * EndingScreen.CARD_TIME + 0.1)
	check(e.phase == "epilogue" and e.cards()[e.card] == EndingScreen.SECRET_EPILOGUE[0], "after the four, the Sunken Spring wakes")
	e.tick(EndingScreen.SECRET_EPILOGUE.size() * EndingScreen.CARD_TIME)
	check(e.phase == "epilogue" and e.cards()[e.card] == EndingScreen.FAREWELL[0], "the farewell still comes last")
	e.tick(EndingScreen.FAREWELL.size() * EndingScreen.CARD_TIME)
	check(e.phase == "credits", "then the climb")
	e.queue_free()


func test_the_game_plays_the_secret_ending_for_a_flawless_run() -> void:
	Settings.path = TEMP_SETTINGS
	GameState.new_game()
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.menu.close()
	g.title_screen.visible = false
	g._start("evercrown/heart")
	g.world.use_game_state = false
	await frames(5)
	GameState.data.equipment.armor = "elven_plate"
	GameState.begin_ending()
	await frames(2)
	check(g.ending.visible and g.ending.secret and g.ending.deaths == 0, "no deaths in the Elven Plate plays the secret ending")
	g.ending.skip()
	g.ending.tick(EndingScreen.THANKS_GRACE)
	g.ending.advance()
	await frames(3)
	g.menu.close()
	GameState.new_game()
	_restore()  # the game loaded and applied the options (pass 231)


## Every field of the save, set away from its new-game value, must come back
## exactly through save_game and load_game (JSON makes whole numbers floats, so
## numbers compare by value), and a fresh world must hand it to the player.
func test_every_save_field_survives_a_round_trip() -> void:
	var slot_was := GameState.slot
	const ROUND_SLOT := 7
	GameState.new_game()
	var d := GameState.data
	var fresh := GameState.fresh()
	for k: String in d.abilities:
		d.abilities[k] = true
	d.spell = "wisplight"
	d.max_hp = 150
	d.max_mp = 90.0
	d.flask_max = 4
	d.gold = 4321
	d.xp = 2600
	d.rank = 7
	d.named_rank = 6
	d.skill_points = 3
	d.skills = ["keen_edge", "torrent_pierce", "wisplight_swarm"]
	d.respecs = 2
	d.equipment = {"blade": "severance", "armor": "full_plate", "shield": "magic_shield", "helmet": "elven_helm", "neck": "dewcatch_torc", "ring1": "whetstone_ring", "ring2": "amber_band", "relic": "stride_knot"}
	d.gear = ["short_sword", "dwarvish_broad_sword", "severance", "full_plate", "magic_shield", "elven_helm", "dewcatch_torc", "whetstone_ring", "amber_band", "stride_knot"]
	d.tempers = {"dwarvish_broad_sword": 2, "long_sword": 1}
	d.keys = {"copper": true, "lantern": true}
	d.rings = ["thaw", "sun"]
	d.potion_shards = 5
	d.grain_shards = 3
	d.meteor_shards = 2
	d.elixirs = 1
	d.ointments = 2
	d.tonics = 3
	d.belt = ["elixir", "tonic", "ointment"]
	d.belt_at = 2
	d.collected = {"hearthroot/plaza:12,30": true}
	d.visited = {"hearthroot/plaza": true, "heartwood/entrance": true}
	d.ringreaders = {"hearthroot/ringreader_hall": [120, 304]}
	d.charts = {"heartwood": true}
	d.pins = [["heartwood/entrance", 64, 96], ["haar/fog_gate", 200, 40]]
	d.flags = {"spring:heartwood": true, "boss:gnarlmaw": true}
	d.purse = {"room": "heartwood/sap_tunnel", "x": 100.0, "y": 200.0, "value": 77}  # the shape World writes (pass 250)
	d.save_room = "hearthroot/ringreader_hall"
	d.save_pos = [120, 304]
	d.play_time = 3725.5
	d.clears = 1
	d.deaths = 4
	d.trials = {"walls": 41.27}
	d.dyes = ["tide_dye"]
	d.dye = "tide_dye"
	d.hair = "copper"
	var unset: Array[String] = []
	for k: String in fresh:
		if k != "version" and _same(d[k], fresh[k]):
			unset.append(k)
	check(unset.is_empty(), "the test sets every field of the save (missing: %s)" % [unset])
	var before := d.duplicate(true)
	GameState.save_game(ROUND_SLOT)
	GameState.new_game()
	check(GameState.load_game(ROUND_SLOT), "the save loads")
	var lost: Array[String] = []
	for k: String in before:
		if not _same(GameState.data[k], before[k]):
			lost.append("%s: %s became %s" % [k, before[k], GameState.data[k]])
	check(lost.is_empty(), "every field comes back as it was saved: %s" % [lost])
	# A fresh world hands it all to the player.
	var w := World.new()
	w.instant = true
	arena.add_child(w)
	w.build_catalog()
	w.start(String(GameState.data.save_room), Vector2(120, 304))
	w.player.input.scripted = true
	await frames(2)
	var p := w.player
	check(p.gold == 4321 and p.elixirs == 1 and p.ointments == 2 and p.equipped_spell == "wisplight", "gold, elixirs, ointments and the spell reach the player")
	check(p.max_hp == 170 and p.flask_max == 4 and p.wisplight_swarm and p.spell_pierce and p.reflects, "and the stats, skills and gear behind them (150 and the helmet's mask)")
	check(p.abilities.values().all(func(v: bool) -> bool: return v), "and every ability")
	w.queue_free()
	await frames(1)
	GameState.delete_save(ROUND_SLOT)
	GameState.new_game()
	GameState.slot = slot_was



## Equal by value: numbers ignore int and float, containers compare deeply.
func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k: Variant in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


## A save from an older build lacks keys added since: loading it fills them
## with their new-game values and keeps what it has.
func test_an_old_save_gains_the_new_keys() -> void:
	var slot_was := GameState.slot
	const OLD_SLOT := 6
	var old := {"version": 1, "gold": 300, "abilities": {"glove": true}, "save_room": "hearthroot/plaza", "save_pos": [100, 200]}
	var f := FileAccess.open(GameState.SAVE_PATH % OLD_SLOT, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	check(GameState.load_game(OLD_SLOT), "the old save loads")
	var d := GameState.data
	check(int(d.gold) == 300 and bool(d.abilities.glove), "what it had is kept")
	check(d.abilities.has("stillstone") and not bool(d.abilities.stillstone), "abilities added since start off")
	var missing: Array[String] = []
	for k: String in GameState.fresh():
		if not d.has(k):
			missing.append(k)
	check(missing.is_empty() and d.pins == [] and int(d.deaths) == 0, "every newer key is there, at its new-game value (missing %s)" % [missing])
	GameState.delete_save(OLD_SLOT)
	GameState.new_game()
	GameState.slot = slot_was



## Bible 15 (pass 317): a save from before the off hand (Sean, 2026-10-31) that
## found the Rune Dagger and wears a shield would press Throw to nothing. The
## next Continue says why, once; a newer save, or one with the hand free, is not told.
func test_an_old_save_with_shield_and_dagger_is_told_of_the_off_hand() -> void:
	var base := {"gold": 0, "save_room": "hearthroot/plaza", "save_pos": [100, 200]}
	var told := func(version: int, shield: String) -> Array:
		var src := base.duplicate(true)
		src.version = version
		src.abilities = {"rune_dagger": true}
		src.equipment = {"blade": "short_sword", "shield": shield}
		src.gear = ["short_sword", shield] if shield != "" else ["short_sword"]
		GameState.data = GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
		return GameState.take_load_notice()
	var notice: Array = told.call(1, "small_shield")
	check(notice.size() == 2 and String(notice[1]).contains("Rune Dagger under Off Hand (Equipment)"), "an old save with a shield and the dagger is told where to free the hand (%s)" % [notice])
	check(GameState.take_load_notice().is_empty() and not GameState.flag(GameState.OFFHAND_NOTICE), "once: taking the notice clears it")
	check(String(GameState.data.equipment.shield) == "small_shield", "and the shield stays on: the choice is the player's")
	check((told.call(1, "") as Array).is_empty(), "an old save with the hand already free is not told")
	check((told.call(GameState.OFFHAND_VERSION, "small_shield") as Array).is_empty(), "nor a save written under the off-hand rule")
	check(int(GameState.data.version) == GameState.VERSION, "and the save is brought up to this version")
	var game := FileAccess.get_file_as_string("res://scripts/game.gd")
	check(game.contains("GameState.take_load_notice()"), "Continue shows the notice")
	GameState.new_game()


# --- Damaged saves and settings (pass 109) -----------------------------------------

const BAD_SLOT := 8


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_a_damaged_save_is_refused_and_leaves_the_game_alone() -> void:
	GameState.delete_save(BAD_SLOT)
	GameState.new_game()
	GameState.data.gold = 777
	var path := GameState.SAVE_PATH % BAD_SLOT
	for text: String in ["", "{\"gold\": 5, \"save_ro", "not a save at all", "[1, 2, 3]", "42", "{\"gold\": 5}"]:
		_write_raw(path, text)
		check(not GameState.load_game(BAD_SLOT), "%s is refused" % JSON.stringify(text))
		check(int(GameState.data.gold) == 777 and GameState.data.has("abilities"), "and the game in play is untouched")
	GameState.delete_save(BAD_SLOT)
	GameState.new_game()


func test_wrong_types_in_a_save_fall_back_to_their_defaults() -> void:
	var slot_was := GameState.slot
	GameState.delete_save(BAD_SLOT)
	var bad := {"save_room": "hearthroot/plaza", "abilities": ["glove"], "gold": "lots", "max_hp": -5, "xp": INF,
		"equipment": {"blade": 3, "armor": "leather_armor"}, "skills": ["keen_edge", 7], "rings": "thaw",
		"pins": [["haar/fog_cut", 10, 20], "x", [1]], "save_pos": "here", "ringreaders": {"a/b": [1], "c/d": [3, 4]},
		"purse": {"room": 5}, "flags": "all", "deaths": -3, "future_key": 12}
	_write_raw(GameState.SAVE_PATH % BAD_SLOT, JSON.stringify(bad))
	check(GameState.load_game(BAD_SLOT), "a save with wrong types still loads")
	var d := GameState.data
	var f := GameState.fresh()
	check(d.abilities is Dictionary and d.abilities.size() == f.abilities.size(), "abilities of the wrong type start over")
	check(d.gold == 0 and d.xp == 0 and d.deaths == 0, "a word, infinity or a negative becomes 0 (%s, %s, %s)" % [d.gold, d.xp, d.deaths])
	check(d.max_hp == f.max_hp, "health never falls below a new game's (%s)" % d.max_hp)
	check(d.equipment.blade == f.equipment.blade and d.equipment.armor == "leather_armor", "a bad blade id falls back, a good armor id stays")
	check(d.skills == ["keen_edge"] and d.rings == [], "lists keep only well-formed entries")
	check(_same(d.pins, [["haar/fog_cut", 10, 20]]), "and only whole pins (%s)" % [d.pins])
	check(d.save_pos == [0, 0] and d.ringreaders.keys() == ["c/d"] and d.purse == {}, "points and the purse must be whole")
	check(d.flags is Dictionary and d.flags.is_empty(), "flags of the wrong type start over")
	check(int(d.get("future_key", 0)) == 12 and int(d.version) == GameState.VERSION, "a newer build's keys are kept")
	GameState.delete_save(BAD_SLOT)
	GameState.new_game()
	GameState.slot = slot_was



func test_a_damaged_save_falls_back_to_its_backup() -> void:
	var slot_was := GameState.slot
	GameState.delete_save(BAD_SLOT)
	GameState.new_game()
	GameState.data.save_room = "hearthroot/plaza"
	GameState.data.gold = 100
	check(GameState.save_game(BAD_SLOT), "the first save writes")
	GameState.data.gold = 200
	check(GameState.save_game(BAD_SLOT), "the second save writes")
	var path := GameState.SAVE_PATH % BAD_SLOT
	check(FileAccess.file_exists(path + ".bak") and not FileAccess.file_exists(path + ".tmp"), "the last save is kept as a backup, no temp file left")
	_write_raw(path, "{\"gold\": 2")
	GameState.new_game()
	check(GameState.load_game(BAD_SLOT) and int(GameState.data.gold) == 100, "a damaged save loads its backup (gold %s)" % GameState.data.gold)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(GameState.has_save(BAD_SLOT), "a backup alone still counts as a save")
	GameState.delete_save(BAD_SLOT)
	check(not GameState.has_save(BAD_SLOT) and not FileAccess.file_exists(path + ".bak"), "deleting a save takes its backup too")
	GameState.new_game()
	GameState.slot = slot_was



func test_a_failed_write_keeps_the_last_good_save() -> void:
	var slot_was := GameState.slot
	GameState.delete_save(BAD_SLOT)
	GameState.new_game()
	GameState.data.save_room = "hearthroot/plaza"
	GameState.data.gold = 100
	GameState.save_game(BAD_SLOT)
	var path := GameState.SAVE_PATH % BAD_SLOT
	var good := FileAccess.get_file_as_string(path)
	# A directory where the temp file goes: the write can't open it.
	var tmp := ProjectSettings.globalize_path(path + ".tmp")
	DirAccess.make_dir_absolute(tmp)
	GameState.data.gold = 999
	check(not GameState.save_game(BAD_SLOT), "a write that fails says so")
	check(FileAccess.get_file_as_string(path) == good, "and the last good save is untouched")
	DirAccess.remove_absolute(tmp)
	GameState.delete_save(BAD_SLOT)
	GameState.new_game()
	GameState.slot = slot_was



## Pass 255: a rest that can't write its save (a full or read-only disk)
## said "Progress saved." all the same, so a player could quit trusting a save
## that never happened. A shrine and a Ringreader now say so when the write fails.
func test_a_rest_that_cannot_save_says_so() -> void:
	GameState.delete_save(BAD_SLOT)
	var w := make_world({}, "hearthroot/ringreader_temple")
	await frames(2)
	var old_slot := GameState.slot
	GameState.slot = BAD_SLOT
	var shrine := SaveShrine.new()
	w.room.add_child(shrine)
	shrine.global_position = w.player.global_position
	var toasts: Array[String] = []
	var listen := func(text: String) -> void: toasts.append(text)
	GameState.toast.connect(listen)
	shrine.interact(w.player)
	check(toasts == ["Rested. Progress saved."] and GameState.has_save(BAD_SLOT), "a rest that writes says it saved (%s)" % [toasts])
	var tmp := ProjectSettings.globalize_path(GameState.SAVE_PATH % BAD_SLOT + ".tmp")
	DirAccess.make_dir_absolute(tmp)
	toasts.clear()
	shrine.interact(w.player)
	check(toasts == [SaveShrine.NOT_SAVED], "one that can't write says the journey could not be saved (%s)" % [toasts])
	var ringreader := Npc.new()
	ringreader.npc_id = "ringreader"
	w.room.add_child(ringreader)
	toasts.clear()
	ringreader.rest(w.player)
	check(toasts == [SaveShrine.NOT_SAVED], "and so does a Ringreader's rest (%s)" % [toasts])
	DirAccess.remove_absolute(tmp)
	toasts.clear()
	ringreader.rest(w.player)
	check(toasts.size() == 1 and toasts[0].begins_with("Rested. Your mark in the wood: "), "once the disk takes it again, the Ringreader names your ring (%s)" % [toasts])
	GameState.toast.disconnect(listen)
	GameState.slot = old_slot
	GameState.delete_save(BAD_SLOT)
	GameState.new_game()


func test_damaged_settings_fall_back_to_defaults_or_their_backup() -> void:
	# Godot's ConfigFile logs its own parse error for the damaged file.
	expect_engine_errors()
	Settings.path = TEMP_SETTINGS
	_write_raw(TEMP_SETTINGS, "[feel\nshake = ]]]")
	Settings.shake = 2
	Settings.load_settings()
	check(Settings.shake == 0 and Settings.music_volume == 8 and Settings.keys.is_empty(), "an unreadable file gives the defaults")
	_write_raw(TEMP_SETTINGS, "[feel]\nshake=\"strong\"\nrumble=5\nspeed=-4\n[audio]\nmusic=99\nsound=[1]\n[keys]\njump=\"space\"\ndash=4194326\n")
	Settings.load_settings()
	check(Settings.shake == 0 and Settings.rumble and Settings.speed == 0, "wrong types fall back and a negative clamps (%d, %s, %d)" % [Settings.shake, Settings.rumble, Settings.speed])
	check(Settings.music_volume == Settings.VOLUME_MAX and Settings.sound_volume == 8, "an out-of-range volume clamps, a list falls back")
	check(not Settings.keys.has("jump") and Settings.keys.get("dash", 0) == 4194326, "only a real keycode is bound")
	# Save twice, damage the file: the backup comes back.
	Settings.reset()
	Settings.shake = 1
	Settings.save()
	Settings.shake = 2
	Settings.save()
	_write_raw(TEMP_SETTINGS, "[feel")
	Settings.load_settings()
	check(Settings.shake == 1, "a damaged settings file loads its backup (%d)" % Settings.shake)
	_restore()


## A settings file from an older build has no line for the actions added since.
func test_older_settings_load_without_errors() -> void:
	# Only the probe at the end, which proves the catcher hears errors.
	expect_engine_errors()
	Settings.path = TEMP_SETTINGS
	_write_raw(TEMP_SETTINGS, "[feel]\nshake=1\n[keys]\njump=4194326\n")
	var errors := ErrorCatcher.start()
	Settings.load_settings()
	var caught := errors.stop()
	check(caught.is_empty(), "the missing actions log no errors (%s)" % [caught])
	check(Settings.shake == 1 and Settings.keys.get("jump", 0) == 4194326, "what the file holds still loads")
	check(not Settings.keys.has("map") and not Settings.keys.has("heal"), "and the newer actions keep their default keys")
	# The catcher itself must see an engine error, or the check above proves nothing.
	var probe := ErrorCatcher.start()
	ConfigFile.new().get_value("keys", "map")
	check(not probe.stop().is_empty(), "the catcher hears an engine error")
	_restore()


## Pass 327: the runner's leak check compares every option, not a list kept
## by hand (which the mercy assist of pass 325 had to be added to). Each static
## var Settings keeps is in its snapshot, so a new option can't slip past it,
## and a left-on option of any kind counts as a leak. A file from before the
## [assist] section, or with a damaged value there, loads mercy off.
func test_every_option_is_in_the_snapshot() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/data/settings.gd")
	var snap := Settings.snapshot()
	var missing := []
	for line: String in src.split("\n"):
		if line.begins_with("static var "):
			var name := line.trim_prefix("static var ").get_slice(" ", 0).get_slice(":", 0)
			if name != "path" and not snap.has(name):
				missing.append(name)
	check(missing.is_empty() and snap.size() >= 9, "every option is in Settings.snapshot() (missing: %s)" % [missing])
	var script: GDScript = load("res://scripts/data/settings.gd")
	for name: String in snap:
		var was: Variant = script.get(name)
		match typeof(was):
			TYPE_BOOL: script.set(name, not was)
			TYPE_INT: script.set(name, was + 1)
			TYPE_DICTIONARY: script.set(name, {"jump": 4194326})
		check((runner.call("_leaks") as Array).has("settings changed"), "a changed %s counts as a leak" % name)
		script.set(name, was)
	check((runner.call("_leaks") as Array).is_empty(), "and put back, nothing leaks")
	expect_engine_errors()
	Settings.path = TEMP_SETTINGS
	var errors := ErrorCatcher.start()
	_write_raw(TEMP_SETTINGS, "[feel]\nshake=1\n")
	Settings.load_settings()
	check(errors.stop().is_empty() and not Settings.mercy and Settings.shake == 1, "a file from before [assist] loads mercy off, with no error")
	_write_raw(TEMP_SETTINGS, "[assist]\nmercy=5\n")
	Settings.load_settings()
	check(not Settings.mercy, "and a damaged mercy falls back to off")
	_restore()


## Pass 138: a save from an older or newer build can name things this build
## doesn't have: a renamed skill node, a blade, a ring, a dye. Loading it,
## dressing the player, learning, unlearning and the dyer must all go on
## without an engine error, and a skill listed twice can't be refunded twice.
func test_a_save_naming_things_this_build_lacks_plays_on() -> void:
	var w := make_world({}, "hearthroot/market")
	await frames(3)
	var p := w.player
	var src := GameState.fresh()
	src.save_room = "hearthroot/market"
	src.skills = ["keen_edge", "ghost_skill", "keen_edge", 7]
	src.equipment = {"blade": "ghost_blade", "armor": "ghost_armor", "shield": "ghost_shield"}
	src.rings = ["ghost_ring"]
	src.dyes = [5, "ghost_dye", "tide_dye", "tide_dye"]
	src.dye = "ghost_dye"
	src.tempers = {"ghost_blade": 2}
	var errors := ErrorCatcher.start()
	GameState.data = GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
	check(GameState.data.skills == ["keen_edge", "ghost_skill"], "skills are kept once each, strings only (%s)" % [GameState.data.skills])
	check(GameState.data.dyes == ["ghost_dye", "tide_dye"], "and so are dyes (%s)" % [GameState.data.dyes])
	GameState.refresh_stats(p)
	check(p.slash_damage == int(GameData.item("short_sword").slash), "an unknown blade falls back to the Short Sword (%d)" % p.slash_damage)
	check(PlayerVisual.dye_look().is_empty(), "an unknown dye leaves the cloak as it is")
	for n: Dictionary in Skills.nodes():
		Skills.status(n.id)
	for i in GameData.shop("hearthroot_dyes").stock.size():
		Shop.status("hearthroot_dyes", i, p)
	await frames(2)
	p.gold = 1000
	var cost := Skills.respec_cost()
	check(Skills.respec(p), "unlearning goes through")
	check(p.gold == 1000 - cost and GameState.data.skills.is_empty(), "for its price, clearing every skill")
	check(int(GameState.data.skill_points) == int(GameData.skill("keen_edge").cost), "Keen Edge comes back once; the unknown node refunds nothing (%d)" % int(GameState.data.skill_points))
	var caught := errors.stop()
	check(caught.is_empty(), "and nothing logs an engine error (%s)" % [caught])


## Pass 191: a save naming gear in the wrong slots, unknown gear and dyes, and
## gear of the wrong shape plays on through the Equipment page (gear and the
## Cloak), the shops and a dagger throw, with no engine error.
func test_a_save_with_gear_in_the_wrong_slots_plays_on() -> void:
	var w := make_world({}, "hearthroot/market")
	await frames(3)
	var p := w.player
	var src := GameState.fresh()
	src.save_room = "hearthroot/market"
	src.equipment = {"blade": "full_plate", "armor": "elven_helm", "shield": "tide_dye", "helmet": "long_sword"}
	src.gear = ["ghost_blade", 3, "long_sword", "long_sword", "magic_shield", ["x"], "lord_dye"]
	src.dyes = ["ghost_dye", "slate_dye"]
	src.dye = "ghost_dye"
	src.abilities = {"rune_dagger": true}
	var errors := ErrorCatcher.start()
	GameState.data = GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
	var eq: Dictionary = GameState.data.equipment
	check(eq.blade == "short_sword" and eq.armor == "" and eq.shield == "" and eq.helmet == "",
		"gear worn in the wrong slot comes off, and the hand holds the Short Sword (%s)" % [eq])
	check(GameState.data.gear == ["ghost_blade", "long_sword", "magic_shield", "lord_dye", "short_sword"],
		"the kept gear is strings, once each, with the Short Sword (%s)" % [GameState.data.gear])
	GameState.refresh_stats(p)
	check(p.max_hp > 0 and p.defense == 0.0 and not p.has_shield, "and plays as nothing worn (defense %.2f)" % p.defense)
	var rows := Menus.equipment_rows()
	var labels: Array = rows.map(func(r: Dictionary) -> String: return r.label)
	check(not labels.has("Crown Gold") and labels.has("Grain Slate"), "the Cloak lists the dyes the save owns, not gear-list strays (%s)" % [labels])
	for row: Dictionary in rows:
		if row.has("id"):
			Menus.choose_equipment(String(row.id), p)
	check(GameState.data.equipment.shield == "magic_shield" and GameState.dye() == "slate_dye", "every row can be chosen (%s, %s)" % [GameState.data.equipment, GameState.dye()])
	for shop_id: String in ["hearthroot_arms", "hearthroot_dyes"]:
		for i in GameData.shop(shop_id).get("stock", []).size():
			Shop.status(shop_id, i, p)
	p.abilities["rune_dagger"] = true
	p.throw_dagger()
	await frames(30)
	var caught := errors.stop()
	check(caught.is_empty(), "and nothing logs an engine error (%s)" % [caught])


## Pass 213: a pickup's id is its room and cell, so a moved pickup would come
## back in a save that had taken it. Each move is listed, and the list is true.
func test_a_moved_pickup_stays_taken() -> void:
	for old: String in GameState.MOVED_PICKUPS:
		var now: String = GameState.MOVED_PICKUPS[old]
		var src := GameState.fresh()
		src.collected = {old: true, "haar/feather_hollow:9,5": true}
		var got := GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
		check(got.collected.has(now) and not got.collected.has(old) and got.collected.has("haar/feather_hollow:9,5"),
				"a save that took %s has taken %s (%s)" % [old, now, got.collected])
		check(_pickup_char(old) == "" and _pickup_char(now) != "", "%s is empty now and %s holds a pickup" % [old, now])
	var src := GameState.fresh()
	src.collected = {}
	check(GameState.sanitize(JSON.parse_string(JSON.stringify(src))).collected.is_empty(), "a save that took none takes none")


## Pass 217: Thane Vorrund gives up the Severance, and the Heart Gate's
## altar is bare. A save past him that never took the sword from the altar
## gets it in hand; one that took it keeps the blade it holds; one before him
## has no sword yet.
func test_a_save_past_thane_vorrund_holds_the_severance() -> void:
	check(_pickup_char("evercrown/heart_gate:40,10") == "", "the Heart Gate's altar is bare")
	var src := GameState.fresh()
	src.flags = {"boss:thane_vorrund": true}
	src.equipment.blade = "long_sword"
	src.gear = ["short_sword", "long_sword"]
	var got := GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
	check(bool(got.abilities.get("severance", false)) and got.equipment.blade == "severance" and Array(got.gear).has("severance"),
			"a save past him without the sword has it in hand (%s, %s)" % [got.equipment, got.gear])
	src.abilities["severance"] = true
	src.gear = ["short_sword", "long_sword", "severance"]
	got = GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
	check(got.equipment.blade == "long_sword", "one that took it keeps the blade it holds (%s)" % got.equipment.blade)
	src = GameState.fresh()
	got = GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
	check(not bool(got.abilities.get("severance", false)) and got.equipment.blade == "short_sword", "a save before him has no sword yet")


## Pass 221: the Severance is an ability (the reach checker's gate, and the
## sign a save took it) and gear (the Equipment page, the heart's seal). It was
## the one ability missing from a new game's list, so the round trip never
## carried it and a save could hold one half: now it is listed, and a save
## holds both or neither.
func test_the_severance_is_held_as_ability_and_gear_together() -> void:
	check(GameState.fresh().abilities.has("severance") and not bool(GameState.fresh().abilities.severance), "a new game lists the Severance, unheld")
	var src := GameState.fresh()
	src.gear = ["short_sword", "severance"]
	var got := GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
	check(got.abilities.severance is bool and got.abilities.severance, "a save with the sword in its gear holds the ability (%s)" % [got.abilities.severance])
	src = GameState.fresh()
	src.abilities.severance = true
	got = GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
	check(Array(got.gear).has("severance") and got.equipment.blade == "short_sword", "one with the ability has the sword in its gear, without taking it in hand (%s)" % [got.gear])
	src = GameState.fresh()
	src.abilities.severance = "yes"
	got = GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
	check(got.abilities.severance is bool and not got.abilities.severance and not Array(got.gear).has("severance"), "a damaged flag holds neither")


## The pickup legend at a pickup id's cell ("" for none).
func _pickup_char(pickup_id: String) -> String:
	var room := pickup_id.get_slice(":", 0)
	var cell := pickup_id.get_slice(":", 1)
	var parsed := Room.parse(FileAccess.get_file_as_string("res://levels/%s.room" % room))
	var grid: Array = parsed.grid
	var y := int(cell.get_slice(",", 1))
	var x := int(cell.get_slice(",", 0))
	# A find a `prop:` line lays (the Elven Helm) is a pickup at its cell too.
	for spec: String in parsed.lists.get("prop", []):
		var q := spec.split(",")
		if q.size() >= 3 and int(q[0]) == x and int(q[1]) == y:
			return q[2].strip_edges()
	if y >= grid.size() or x >= String(grid[y]).length():
		return ""
	var c := String(grid[y])[x]
	# Key doors keep an id the same way (pass 508 moved four down a row with their vaults).
	return c if "GXOdhnzLWF*&{(}$Jg".contains(c) else ""


## Pass 184: the Hand Dagger is now the Short Sword. A save from before
## keeps it in hand and keeps its tempers; the Throw button is bound; and the
## Rune Dagger in the Hornet Gallery grants the throw.
func test_the_hand_dagger_is_the_short_sword_and_the_rune_dagger_is_found() -> void:
	var src := GameState.fresh()
	src.equipment = {"blade": "hand_dagger", "armor": "", "shield": ""}
	src.tempers = {"hand_dagger": 2, "long_sword": 1}
	var got := GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
	check(got.equipment.blade == "short_sword", "an old save's Hand Dagger is the Short Sword (%s)" % got.equipment.blade)
	check(got.tempers.size() == 2 and int(got.tempers.short_sword) == 2 and int(got.tempers.long_sword) == 1, "with its tempers (%s)" % [got.tempers])
	check(GameData.item("short_sword").name == "Short Sword" and GameData.item("hand_dagger").is_empty(), "the item is the Short Sword")
	check(GameState.fresh().equipment.blade == "short_sword", "a new game starts with it")
	check(not bool(GameState.fresh().abilities.rune_dagger), "and without the Rune Dagger")
	check(InputMap.has_action("throw") and Controls.primary_key("throw") == KEY_B, "Throw is on B")
	var pad := false
	for ev in InputMap.action_get_events("throw"):
		pad = pad or (ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER)
	check(pad, "and on the right bumper")
	var found := []
	for f in DirAccess.get_files_at("res://levels/heartwood"):
		if f.ends_with(".room") and FileAccess.get_file_as_string("res://levels/heartwood/" + f).contains("}"):
			found.append(f)
	check(found == ["hornet_gallery.room"], "the Rune Dagger lies in the Hornet Gallery (%s)" % [found])
	var w := make_world({}, "hearthroot/market")
	await frames(3)
	var p := w.player
	GameState.data.gear.append("small_shield")
	GameState.wear("small_shield", p)
	var pick := ItemPickup.new()
	pick.kind = ItemPickup.KIND_BY_CHAR["}"]
	w.room.add_child(pick)
	pick.grant(p)
	check(bool(p.abilities.get("rune_dagger", false)), "picked up, it is yours")
	check(GameState.offhand_free() and not p.has_shield, "and it takes the off hand: the shield goes on your back")
	GameState.data.gear.erase("small_shield")


## Pass 185: the Elven Helm left the shield slot for its own. A save that
## wore it as a shield wears it as a helmet, with the Warding Shield in hand
## (the guard and parry it had); a save from before helmets gets an empty slot.
func test_a_save_with_the_helmet_in_the_shield_slot_moves_it_to_the_head() -> void:
	var src := GameState.fresh()
	src.equipment = {"blade": "long_sword", "armor": "full_plate", "shield": "elven_helm"}
	var got := GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
	check(got.equipment.helmet == "elven_helm" and got.equipment.shield == "magic_shield", "helmet on the head, Warding Shield in hand (%s)" % [got.equipment])
	check(got.equipment.blade == "long_sword" and got.equipment.armor == "full_plate", "the rest untouched")
	src.equipment = {"blade": "short_sword", "armor": "", "shield": "small_shield"}
	got = GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
	check(got.equipment.helmet == "" and got.equipment.shield == "small_shield", "an older save gains an empty helmet slot")
	check(GameData.item("elven_helm").kind == "helmet" and not GameData.item("elven_helm").has("guard"), "the helmet neither guards nor parries")


func test_a_rest_in_a_missing_room_wakes_at_the_start() -> void:
	check(World.room_exists("hearthroot/plaza"), "a real room exists")
	check(not World.room_exists("nowhere/room") and not World.room_exists("../x") and not World.room_exists(""), "a missing or odd one doesn't")


# --- Completion (pass 106) --------------------------------------------------------

func test_completion_tallies_rooms_hidden_rooms_treasures_and_bosses() -> void:
	GameState.new_game()
	var catalog := {
		"a/x": {"secret": true, "treasures": ["a/x:1,1", "a/x:2,2"]},
		"a/y": {"secret": false, "treasures": []},
	}
	var none := Completion.tally(catalog)
	check(none.percent == 0 and none.rooms_total == 2 and none.secrets_total == 1 and none.treasures_total == 2, "a new save has seen nothing (%s)" % [none])
	check(none.bosses_total == BossArena.BOSSES.size(), "and every boss counts")
	GameState.visit("a/x")
	GameState.set_flag("secret:a/x")
	GameState.collect("a/x:1,1")
	GameState.set_flag("boss:gnarlmaw")
	var some := Completion.tally(catalog)
	check(some.rooms == 1 and some.secrets == 1 and some.treasures == 1 and some.bosses == 1, "each find counts once (%s)" % [some])
	var want := int(floor((0.5 + 1.0 + 0.5 + 1.0 / BossArena.BOSSES.size()) / 4.0 * 100.0))
	check(some.percent == want, "the percent is the average of the four shares, rounded down (%d, want %d)" % [some.percent, want])
	GameState.visit("a/y")
	GameState.collect("a/x:2,2")
	for id: String in BossArena.BOSSES:
		GameState.set_flag("boss:" + id)
	check(Completion.tally(catalog).percent == 100, "everything found is 100%")
	GameState.new_game()


func test_the_whole_world_is_counted() -> void:
	var w := World.new()
	w.build_catalog()
	GameState.new_game()
	var c := Completion.tally(w.catalog)
	check(c.rooms_total > 100 and c.secrets_total >= 5 and c.treasures_total > 50, "the real world has rooms, hidden rooms and treasures to find (%s)" % [c])
	w.free()


## Pass 187: the finds a `prop:` line lays (the Elven Helm, the Glass Key)
## are treasures like the ones drawn in the grid: the percent, the Journey and
## Treasure Sense count them, under the same id the room gives the pickup.
func test_finds_laid_by_props_count_as_treasures() -> void:
	var w := make_world({}, "evercrown/threshold")
	await frames(2)
	var helm_id := "evercrown/threshold:2,20"
	check(w.catalog["evercrown/threshold"].treasures.has(helm_id), "the Elven Helm is a Threshold treasure (%s)" % [w.catalog["evercrown/threshold"].treasures])
	check(w.catalog["vorrhallow/drowned_market"].treasures.has("vorrhallow/drowned_market:49,12"), "and the Glass Key a Drowned Market one")
	var helm: ItemPickup = null
	for c in w.room.get_children():
		if c is ItemPickup and (c as ItemPickup).kind == "elven_helm":
			helm = c
	check(helm != null and helm.pickup_id == helm_id, "the pickup carries the same id (%s)" % [helm.pickup_id if helm else "none"])
	var before := int(Completion.tally(w.catalog).treasures)
	var left := MapScreen.unfound(w.catalog["evercrown/threshold"])
	GameState.collect(helm_id)
	check(int(Completion.tally(w.catalog).treasures) == before + 1, "taking it counts toward the percent")
	check(MapScreen.unfound(w.catalog["evercrown/threshold"]) == left - 1, "and Treasure Sense stops sensing it")
	GameState.new_game()


func test_the_thanks_card_counts_up_the_completion() -> void:
	var e := EndingScreen.new()
	arena.add_child(e)
	var stats := {"rooms": 50, "rooms_total": 100, "secrets": 3, "secrets_total": 7, "treasures": 40, "treasures_total": 106,
		"bosses": 13, "bosses_total": 13, "percent": 60, "clears": 2}
	e.start("Heartwood", 3725.0, false, 4, stats)
	e.skip()
	check(e.phase == "thanks" and e.stats.percent == 60, "the thanks card carries the save's completion")
	var rows := e.completion_rows()
	check(rows.size() == 4 and rows[0] == ["Rooms explored", 50, 100] and rows[3] == ["Bosses", 13, 13], "four rows of found against total (%s)" % [rows])
	e.tick(EndingScreen.COUNT_TIME + 0.1)
	await frames(1)
	check(e.visible, "it draws through the count")
	e.start("Heartwood", 10.0)
	e.skip()
	e.tick(0.5)
	await frames(1)
	check(e.stats.is_empty(), "with no tally it shows only rank, time and deaths")
	e.queue_free()


# --- Inner Rings (pass 113) -------------------------------------------------------

func _temple() -> Dictionary:
	var rows := grid_rows(30, 20)
	return {"test/a": room_text(["name: Temple", "zone: hearthroot"], rows)}


## Bible 3.1: the trials open two by two as springs are restored, and only
## built ones are offered.
func test_inner_rings_open_as_the_springs_flow() -> void:
	GameState.new_game()
	var ids := Trials.built().map(func(t: Dictionary) -> String: return t.id)
	check(ids.slice(0, 2) == ["walls", "edges"], "the first two trials are built (%s)" % [ids])
	for t: Dictionary in Trials.built():
		check(World.room_exists(t.room), "%s has its room" % t.name)
	check(not Trials.is_open(Trials.find("walls")), "with no spring flowing, they are sealed")
	GameState.set_flag("spring:heartwood")
	check(Trials.is_open(Trials.find("walls")) and Trials.is_open(Trials.find("edges")), "the first spring opens the first two")
	check(not Trials.is_open(Trials.find("thorns")), "the next two want a second spring")
	GameState.set_flag("spring:haar")
	check(Trials.is_open(Trials.find("thorns")), "which opens them")
	check(Trials.format_time(83.47) == "1:23.4" and Trials.format_time(INF) == "--", "times read m:ss.t")


## Bible 3.1: the Ringreader sends you to the trial's start, the clock runs, the bell
## clears it (a Grain Shard the first time, the best time kept), and the ring
## carries you back to where you stood.
## Pass 116: the inner rings sounds like itself: its own theme and bed, a
## shimmer as the ring carries you in, a bronze bell, and a sting for a new best.
func test_the_inner_rings_have_a_sound_of_their_own() -> void:
	for name: String in ["trials", "amb_trials"]:
		var stream := Music.stream_for(name)
		check(stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop, "%s is a looping track" % name)
	for sound: String in ["trial_begin", "trial_bell", "trial_record"]:
		check(FileAccess.file_exists("res://assets/sfx/%s.wav" % sound), "%s.wav exists" % sound)
	var w := make_world(_temple(), "test/a", cell_feet(5, 16))
	GameState.set_flag("spring:heartwood")
	var p := w.player
	await frames(5)
	for id: String in ["walls", "edges"]:
		Sfx.recent.clear()
		Menus.start_trial(w, p, Trials.find(id))
		await frames(5)
		check(Sfx.recent.has("trial_begin"), "%s: the ring carries you in with a shimmer" % id)
		check(Music.track == "trials" and Music.ambience_track == "amb_trials",
			"%s plays the trials theme over the inner rings (%s, %s)" % [id, Music.track, Music.ambience_track])
		var bell: TrialGoal = w.room.get_tree().get_first_node_in_group("trial_goal")
		Sfx.recent.clear()
		p.teleport(bell.global_position)
		await frames(3)
		check(Sfx.recent.has("trial_bell") and not Sfx.recent.has("save"), "%s: the bell rings bronze, not the save chime" % id)
		check(not Sfx.recent.has("trial_record"), "a first clear rings the shard, no record sting")
		await frames(int(TrialGoal.RING * 60) + 10)
	# A faster second walk is a new best, and stings.
	GameState.data.trials["walls"] = 999.0
	Menus.start_trial(w, p, Trials.find("walls"))
	await frames(5)
	var bell2: TrialGoal = w.room.get_tree().get_first_node_in_group("trial_goal")
	Sfx.recent.clear()
	p.teleport(bell2.global_position)
	await frames(3)
	check(Sfx.recent.has("trial_record"), "a new best plays the record sting")
	await frames(int(TrialGoal.RING * 60) + 10)
	w.queue_free()
	Trials.abandon()


func test_a_trial_runs_on_a_clock_and_the_bell_clears_it() -> void:
	var w := make_world(_temple(), "test/a", cell_feet(5, 16))
	GameState.set_flag("spring:heartwood")
	var p := w.player
	await frames(5)
	var back := p.global_position
	Menus.start_trial(w, p, Trials.find("walls"))
	await frames(5)
	check(w.room.id == "trials/walls", "the ring carries you to the trial")
	var start := Trials.start_pos(w.room_text("trials/walls"))
	check(p.global_position.distance_to(start) < 4.0, "to its start")
	check(Trials.active(), "and the trial is under way")
	await frames(60)
	check(Trials.run.time > 0.9 and Trials.run.time < 1.2, "the clock runs (%.2f s)" % Trials.run.time)
	var bell: TrialGoal = w.room.get_tree().get_first_node_in_group("trial_goal")
	check(bell != null, "the room has its bell")
	var shards := int(GameState.data.grain_shards)
	p.teleport(bell.global_position)
	await frames(3)
	check(bell.rung, "touching the bell rings it")
	check(Trials.cleared("walls"), "the trial is cleared")
	check(int(GameState.data.grain_shards) == shards + 1, "the first clear gives a Grain Shard")
	var first := Trials.best("walls")
	check(first > 0.9 and first < 1.3, "and keeps the time (%.2f s)" % first)
	await frames(int(TrialGoal.RING * 60) + 10)
	check(w.room.id == "test/a" and p.global_position.distance_to(back) < 4.0, "then you are back where you stood")
	check(not Trials.active(), "with the trial over")
	# A slower second walk keeps the best and gives no second shard.
	Menus.start_trial(w, p, Trials.find("walls"))
	await frames(5)
	await frames(120)
	bell = w.room.get_tree().get_first_node_in_group("trial_goal")
	p.teleport(bell.global_position)
	await frames(3)
	check(Trials.best("walls") == first, "a slower clear keeps the best (%.2f)" % Trials.best("walls"))
	check(int(GameState.data.grain_shards) == shards + 1, "and gives no second shard")
	await frames(int(TrialGoal.RING * 60) + 10)
	w.queue_free()
	Trials.abandon()


## Bible 3.1: in a trial a hazard costs time, never health: it sets you back on
## your last footing. Leaving from the pause menu returns you to the Ringreader.
func test_in_a_trial_hazards_cost_time_not_health() -> void:
	var w := make_world(_temple(), "test/a", cell_feet(5, 16))
	GameState.set_flag("spring:heartwood")
	var p := w.player
	await frames(5)
	var back := p.global_position
	Menus.start_trial(w, p, Trials.find("walls"))
	await frames(10)
	var hp := p.hp
	var safe := p.safe_position
	# Step onto the spikes beside the start.
	p.teleport(cell_feet(8, 27))
	await frames(3)
	check(p.hp == hp, "spikes take no health in a trial (%d -> %d)" % [hp, p.hp])
	check(p.global_position.distance_to(safe) < 4.0, "they set you back on your footing")
	check(Trials.active(), "and the clock runs on")
	Menus.leave_trial(w.get_tree())
	await frames(5)
	check(w.room.id == "test/a" and p.global_position.distance_to(back) < 4.0, "leaving the trial returns you to the Ringreader")
	check(not Trials.active() and not Trials.cleared("walls"), "uncleared")
	w.queue_free()


## Best times are saved, and a bad one in a damaged save is dropped.
func test_trial_times_are_saved_and_sanitized() -> void:
	GameState.new_game()
	GameState.data.trials = {"walls": 12.34}
	var copy := GameState.sanitize(JSON.parse_string(JSON.stringify(GameState.data)))
	check(_same(copy.trials, {"walls": 12.34}), "a best time survives a save (%s)" % [copy.trials])
	var bad: Dictionary = JSON.parse_string(JSON.stringify(GameState.data))
	bad.trials = {"walls": -3, "edges": "fast", "thorns": 20}
	copy = GameState.sanitize(bad)
	check(_same(copy.trials, {"thorns": 20.0}), "negative or non-number times are dropped (%s)" % [copy.trials])
	bad.trials = [1, 2]
	check(_same(GameState.sanitize(bad).trials, {}), "a list in their place falls back to none")
	GameState.new_game()


func _numbers(room: Node) -> Array:
	var out := []
	for c in room.get_children():
		if c is DamageNumber:
			out.append(c)
	return out


## Pass 154 (bible 14): damage numbers, an option that is off by default.
func test_damage_numbers_show_what_each_blow_dealt() -> void:
	Settings.path = TEMP_SETTINGS
	Settings.reset()
	var rooms := _town()
	var rows := grid_rows(40, 23)
	put_tiles(rows, 5, 19, "P")
	put_tiles(rows, 12, 19, "M")
	put_tiles(rows, 22, 19, "D")
	rooms["test/town"] = room_text(["name: Town", "zone: test"], rows)
	var w := make_world(rooms, "test/town")
	var mono: Blinkhop = null
	var dwarf: RotDwarf = null
	for c in w.room.get_children():
		if c is Blinkhop:
			mono = c
		elif c is RotDwarf:
			dwarf = c
	mono.max_hp = 999
	mono.hp = 999
	mono.set_physics_process(false)
	dwarf.set_physics_process(false)
	await frames(3)
	mono.take_hit(8, Vector2.RIGHT)
	check(_numbers(w.room).is_empty() and not Settings.damage_numbers, "off by default: a blow shows no number")
	Settings.adjust("numbers", 1)
	check(Settings.damage_numbers and Settings.value_text("numbers") == "On", "the option turns them on")
	check(Menus.OPTIONS.any(func(o: Array) -> bool: return o[0] == "numbers"), "from the Options menu")
	# A cut: the number is what the foe lost.
	var before := mono.hp
	mono.take_hit(8, Vector2.RIGHT)
	var nums := _numbers(w.room)
	check(nums.size() == 1 and nums[0].amount == before - mono.hp and nums[0].kind == "hit", "a cut shows the damage it dealt (%s)" % [nums.map(func(n: DamageNumber) -> String: return "%d %s" % [n.amount, n.kind])])
	check(nums[0].global_position.y < mono.center().y, "over the foe")
	# A heavy blow (the finisher, a thrust) comes in at 1.8x: gold, and larger.
	mono.take_hit(14, Vector2(1.8, 0))
	nums = _numbers(w.room)
	check(nums.size() == 2 and nums[1].kind == "heavy" and nums[1].amount == 14, "a heavy blow's number is gold")
	check(DamageNumber.SIZES.heavy > DamageNumber.SIZES.hit, "and larger")
	# A blow the shield turns deals nothing, and shows nothing.
	dwarf.facing = -1
	var hp_before := dwarf.hp
	dwarf.take_hit(8, Vector2.RIGHT)
	check(_numbers(w.room).size() == 2 and dwarf.hp == hp_before, "a blocked blow shows no number")
	# The player's own losses, in red, as dealt after armor.
	var p := w.player
	p.defense = 0.4
	var php := p.hp
	p.take_damage(20)
	nums = _numbers(w.room)
	var hurt: Array = nums.filter(func(n: DamageNumber) -> bool: return n.kind == "hurt")
	check(hurt.size() == 1 and hurt[0].amount == php - p.hp and hurt[0].amount < 20, "a hit on the player shows the HP it took, after armor (%s)" % [hurt.map(func(n: DamageNumber) -> int: return n.amount)])
	# They rise, fade and are gone.
	var y0: float = nums[0].offset().y
	await frames(20)
	check(is_instance_valid(nums[0]) and nums[0].offset().y < y0 - 8.0, "a number rises")
	await frames(40)
	check(_numbers(w.room).is_empty(), "and is gone after %.1f s" % DamageNumber.LIFE)
	Settings.reset()
	Settings.load_settings()
	check(Settings.damage_numbers, "the choice is saved")
	_restore()
	check(not Settings.damage_numbers, "and the suite runs on the default, off")



## Bible 14 (pass 309): with damage numbers on, each poison tick shows what it
## took, in the poisoned masks' green. Blightcap bites as the room's foes do since
## pass 306 (2 in the Tower, up to 4 deep), and a tick was the one loss of health
## that showed no number. A tick an Barkbalm keeps off, or one that would take
## the last point, shows nothing.
func test_damage_numbers_show_each_poison_tick() -> void:
	Settings.path = TEMP_SETTINGS
	Settings.reset()
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	w.room.zone = "evercrown"
	p.hp = 100
	p.poison()
	await frames(roundi(Player.POISON_TICK * 60.0) + 2)
	check(_numbers(w.room).is_empty() and p.hp < 100, "off: a tick shows no number")
	Settings.adjust("numbers", 1)
	var before := p.hp
	await frames(roundi(Player.POISON_TICK * 60.0))
	var nums: Array = _numbers(w.room).filter(func(n: DamageNumber) -> bool: return n.kind == "poison")
	check(nums.size() == 1 and nums[0].amount == before - p.hp and nums[0].amount == 4,
		"on: an Evercrown tick shows the 4 it took (%s)" % [nums.map(func(n: DamageNumber) -> int: return n.amount)])
	check(DamageNumber.COLORS.poison == GameHud.POISONED, "in the poisoned masks' green")
	p.hp = 1
	await frames(roundi(Player.POISON_TICK * 60.0))
	p.ointments = 1
	p.use_ointment()
	p.hp = 50
	await frames(roundi(Player.POISON_TICK * 60.0))
	check(_numbers(w.room).filter(func(n: DamageNumber) -> bool: return n.kind == "poison" and n != nums[0]).is_empty(),
		"a tick that takes nothing (the last point, an Barkbalm) shows nothing")
	p.cure_poison()
	_restore()
	check(not Settings.damage_numbers, "and the suite runs on the default, off")

## Pass 155: the third trial, the Ring of Thorns, is a pogo course: a spike
## corridor, a pit under a chain of thorn bulbs, and two bulbs up to a hanging
## slab that nothing else reaches. A simple pogo-playing hand clears it in the
## real game: it walks right, jumps off edges, steers over the next bulb and
## strikes down whenever it falls.
func test_the_ring_of_thorns_is_cleared_by_pogo() -> void:
	var t := Trials.find("thorns")
	check(Trials.built().has(t) and t.needs == ["glove", "delvers_pick"], "the Ring of Thorns is built, for the Glove and the Delver's Pick")
	check(t.desc != "", "and the Ringreader describes it")
	# Without the Delver's Pick the bell is out of reach (the checker).
	var text := FileAccess.get_file_as_string(World.room_path(t.room))
	var bare := Reach.new({t.room: text}, {"glove": true})
	check(not bare.reachable(bare.spot_of(t.room, "P")).has(Reach.key(t.room, 90, 7)), "without the Delver's Pick the bell can't be reached")
	var w := make_world(_temple(), "test/a", cell_feet(5, 16))
	GameState.set_flag("spring:heartwood")
	GameState.set_flag("spring:haar")
	GameState.data.abilities["glove"] = true
	GameState.data.abilities["delvers_pick"] = true
	var p := w.player
	GameState.apply(p)
	await frames(5)
	Menus.start_trial(w, p, t)
	await frames(5)
	check(w.room.id == "trials/thorns", "the Ringreader sends you there")
	var bell: TrialGoal = w.room.get_tree().get_first_node_in_group("trial_goal")
	var bulbs: Array = []
	for c in w.room.get_children():
		if c is ThornBulb:
			bulbs.append(c)
	bulbs.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.x < b.global_position.x)
	check(bulbs.size() == 7, "seven thorn bulbs hang in the air (%d)" % bulbs.size())
	var done := {}
	var pogos := 0
	var f := 0
	while f < 60 * 30 and not bell.rung:
		var on := p.is_on_floor()
		var target: Node2D = null
		for b: Node2D in bulbs:
			if not done.has(b) and b.global_position.x > p.global_position.x - 24.0 and b.global_position.x < p.global_position.x + 140.0:
				target = b
				break
		p.input.move_x = 1
		if on:
			done.clear()
			var off_edge := not w.room.is_solid_at(p.global_position + Vector2(10, 4))
			p.input.jump_pressed = off_edge
			p.input.jump_held = off_edge
		elif target != null and p.velocity.y > -100.0:
			var dx := target.global_position.x - p.global_position.x
			p.input.move_x = 0 if absf(dx) < 3.0 else int(signf(dx))
		var falling := not on and p.velocity.y > 0.0
		p.input.down = falling
		p.input.attack_pressed = falling and f % 4 == 0
		var vy := p.velocity.y
		await frames(1)
		f += 1
		if vy > 0.0 and p.velocity.y < -300.0:
			pogos += 1
			if target != null and absf(target.global_position.x - p.global_position.x) < 30.0:
				done[target] = true
	check(bell.rung, "the pogo hand rings the bell (%.1f s, %d pogos)" % [f / 60.0, pogos])
	check(pogos >= 5, "by pogo (%d bounces)" % pogos)
	await frames(int(TrialGoal.RING * 60) + 10)
	w.queue_free()
	Trials.abandon()


## Bible 11: the boss rush opens at 100% and runs every guardian again in
## order, each through the door you first came in by, with a third of your
## health mended between fights. It wins nothing and plays no ending; the clock
## and its best time are kept; a killing blow ends it and sends you back whole.
func test_the_boss_rush_runs_every_guardian_again() -> void:
	var w := make_world(_temple(), "test/a", cell_feet(5, 16))
	var p := w.player
	await frames(5)
	check(not BossRush.unlocked() and not Menus._rush_row().enabled, "the rush is sealed before 100%")
	GameState.set_flag("lord")
	for pair: Array in BossRush.ORDER:
		GameState.set_flag("boss:" + String(pair[0]))
		check(w.has_room(String(pair[1])), "%s's arena exists" % pair[0])
	check(Menus._rush_row().enabled, "and open after")
	var flags_before: Dictionary = GameState.data.flags.duplicate()
	var rings_before: Array = GameState.data.rings.duplicate()
	var gold_before := p.gold
	var back := p.global_position
	p.hp = 3
	BossRush.start(w, p)
	await frames(5)
	check(p.hp == p.max_hp, "the rush begins whole")
	var n := 0
	for pair: Array in BossRush.ORDER:
		var boss_id := String(pair[0])
		check(w.room.id == String(pair[1]), "rush %d is %s's arena (%s)" % [n + 1, boss_id, w.room.id])
		check(BossRush.current_boss() == boss_id, "on %s" % boss_id)
		if n < 2:
			check(Music.track == BossRush.MUSIC, "%s's arena waits under the trials' theme (%s)" % [boss_id, Music.track])
		var arena: BossArena = w.get_tree().get_first_node_in_group("boss_arena")
		check(arena != null and arena.boss_id == boss_id, "%s's arena waits" % boss_id)
		if arena == null:
			break
		# Walk in from the door until the fight starts.
		var center := w.room.size_tiles.x * Room.TILE * 0.5
		for i in 300:
			if arena.fighting:
				break
			p.input.move_x = int(signf(center - p.global_position.x))
			p.input.jump_pressed = i % 40 == 0
			p.input.jump_held = i % 40 < 10
			await frames(1)
		p.input.clear()
		check(arena.fighting and arena.boss != null, "%s fights again" % boss_id)
		if not arena.fighting:
			break
		if n == 0:
			p.hp = 4
		if n == 0:
			check(Music.track != BossRush.MUSIC, "the boss brings its own music (%s)" % Music.track)
		Sfx.recent.clear()
		arena.boss.defeated.emit()
		await frames(5)
		if n < BossRush.ORDER.size() - 1:
			check(Sfx.recent.has("rush_mend") and Music.track == BossRush.MUSIC, "%s down: the bell mends you, the theme returns" % boss_id)
		else:
			check(Sfx.recent.has("rush_won") and Sfx.recent.has("trial_record"), "the last down: the bell rings the win, and a first rush is a best")
		if n == 0:
			check(p.hp == 4 + ceili(p.max_hp / 3.0) and p.mp == p.max_mp, "a third of your health and all your magic mended (%d)" % p.hp)
		n += 1
		await frames(int(BossRush.NEXT_DELAY * 60) + 10)
	check(n == BossRush.ORDER.size(), "all %d guardians fought (%d)" % [BossRush.ORDER.size(), n])
	check(not BossRush.active() and w.room.id == "test/a" and p.global_position.distance_to(back) < 4.0,
		"the rush won, the ring carries you back to the Ringreader")
	check(GameState.data.flags == flags_before and GameState.data.rings == rings_before and p.gold == gold_before,
		"nothing is won again")
	check(int(GameState.data.get("clears", 0)) == 0, "and the Everbloom's fall plays no ending")
	var best := BossRush.best()
	check(best > 1.0 and best < INF, "the best time is kept (%.1f s)" % best)
	check(Menus._rush_row().right == Trials.format_time(best), "and shown by the Ringreader")
	# A killing blow ends the rush and returns you whole.
	BossRush.start(w, p)
	await frames(5)
	p.hp = 2
	p._invuln_timer = 0.0
	Sfx.recent.clear()
	p.take_damage(5)
	check(Sfx.recent.has("rush_fall"), "a fall tolls the bell low")
	await frames(5)
	check(not BossRush.active() and not p.dead and p.hp == p.max_hp, "a killing blow ends the rush, and you live")
	check(w.room.id == "test/a", "back at the Ringreader")
	check(BossRush.best() == best, "a fallen rush keeps no time")
	w.queue_free()
	BossRush.abandon()


## Pass 260: "nothing is won again" held only for what the arena hands out.
## The rush test above ends each fight by the arena's own signal, so a
## guardian's real death (Enemy.die) was never seen there: it still sprayed its
## gold, rolled a drop and gave its experience every rush, and so did whatever
## it called in (a Mothling, a daughter, a hound). A rush won some 3,000
## experience and a purse of gold each time. Now a death in a rush leaves none.
func test_a_boss_rush_kill_wins_no_gold_or_experience() -> void:
	var w := make_world(_temple(), "test/a", cell_feet(5, 16))
	var p := w.player
	await frames(5)
	GameState.set_flag("lord")
	for pair: Array in BossRush.ORDER:
		GameState.set_flag("boss:" + String(pair[0]))
	var xp0 := int(GameState.data.xp)
	BossRush.start(w, p)
	await frames(5)
	var arena: BossArena = w.get_tree().get_first_node_in_group("boss_arena")
	var center := w.room.size_tiles.x * Room.TILE * 0.5
	for i in 300:
		if arena.fighting:
			break
		p.input.move_x = int(signf(center - p.global_position.x))
		await frames(1)
	p.input.clear()
	check(arena.fighting and arena.boss != null, "the first guardian fights again")
	if arena.boss == null:
		BossRush.abandon()
		w.queue_free()
		return
	# A foe it calls in, struck down, and the guardian itself, dying for real.
	var brood := Blinkhop.new()
	w.room.add_child(brood)
	brood.global_position = p.global_position + Vector2(40, 0)
	await frames(2)
	brood.take_hit(brood.hp, Vector2.RIGHT)
	arena.boss.hp = 0
	arena.boss.call("_die" if arena.boss.has_method("_die") else "die")
	var gone := false
	for i in 600:
		await frames(1)
		if not BossRush.active() or BossRush.current_boss() != "gnarlmaw":
			gone = true
			break
	await frames(2)
	var coins := 0
	var drops := 0
	for n in w.room.get_children():
		coins += 1 if n is Coin else 0
		drops += 1 if n is Drop else 0
	check(gone, "the guardian falls and the rush goes on")
	check(int(GameState.data.xp) == xp0, "no experience is won (%d)" % (int(GameState.data.xp) - xp0))
	check(coins == 0 and drops == 0, "and no gold or drops are left (%d coins, %d drops)" % [coins, drops])
	BossRush.abandon()
	w.queue_free()
	await frames(2)
	# Outside a rush a foe still pays.
	var w2 := make_world(_temple(), "test/a", cell_feet(5, 16))
	await frames(3)
	var foe := Blinkhop.new()
	w2.room.add_child(foe)
	foe.global_position = w2.player.global_position + Vector2(60, 0)
	await frames(2)
	foe.take_hit(foe.hp, Vector2.RIGHT)
	check(int(GameState.data.xp) > xp0, "outside a rush a kill still pays")
	w2.queue_free()
	# Every other guardian pays through Enemy.die; one that pays on its own
	# must ask the rush first.
	for dir in ["res://scripts/bosses/", "res://scripts/enemies/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var src := FileAccess.get_file_as_string(dir + f)
				if src.contains("GameState.add_xp(") or src.contains("Coin.spray("):
					check(src.contains("BossRush.active()"), "%s pays only outside a rush" % f)


## Pass 158: the boss rush's edges. A fall while the ring is mid-fade waits
## for the fade and then carries you back, once; the clock stops at the fall;
## no shrine on the way refills or saves you; no one stands in an arena; a
## world freed mid-rush leaves no timer behind; and a new game starts clean.
func test_the_boss_rush_holds_at_its_edges() -> void:
	var w := make_world(_temple(), "test/a", cell_feet(5, 16))
	var p := w.player
	await frames(5)
	for pair: Array in BossRush.ORDER:
		GameState.set_flag("boss:" + String(pair[0]))
	GameState.set_flag("lord")
	# No one stands in the fight: Thane Vorrund's steward waits only outside a rush.
	w._enter("vorrhallow/throne_hall")
	check(w.room.get_children().any(func(c: Node) -> bool: return c is Npc), "the steward stands in the throne hall after the king falls")
	BossRush.begin("test/a", cell_feet(5, 16))
	BossRush.run.index = 7
	w.travel_to_door("vorrhallow/throne_hall", BossRush.ENTRY_DOOR)
	await frames(3)
	check(not w.room.get_children().any(func(c: Node) -> bool: return c is Npc), "but not in the rush's arena")
	# No rest on the way: the shrine by the Crown Gate neither refills nor saves.
	BossRush.run.index = 8
	BossRush.go(w)
	await frames(3)
	check(w.room.id == "vorrhallow/evercrown_gate", "on to the Crown Gate")
	var shrine: SaveShrine = null
	for c in w.room.get_children():
		if c is SaveShrine:
			shrine = c
	check(shrine != null, "whose shrine stands by the way in")
	p.hp = 3
	var saved_room = GameState.data.get("save_room", "")
	shrine.interact(p)
	check(p.hp == 3 and GameState.data.get("save_room", "") == saved_room, "the shrine allows no rest in the rush")
	# A fall while the world is mid-fade waits for it, and comes once.
	var banners := [0]
	var count := func(_a: String, _b: String) -> void: banners[0] += 1
	GameState.banner.connect(count)
	w.busy = true
	p._invuln_timer = 0.0
	p.take_damage(99)
	var at_fall := float(BossRush.run.time)
	p._invuln_timer = 0.0
	p.take_damage(99)
	check(not p.dead and BossRush.active(), "mid-fade the fall waits, and you live")
	await frames(30)
	check(is_equal_approx(float(BossRush.run.time), at_fall), "the clock stops at the fall")
	check(w.room.id == "vorrhallow/evercrown_gate", "nothing moves while the world is busy")
	w.busy = false
	await frames(12)
	check(not BossRush.active() and w.room.id == "test/a" and p.hp == p.max_hp, "once it settles, back to the Ringreader whole")
	check(banners[0] == 1, "and the rush ends once (%d banners)" % banners[0])
	GameState.banner.disconnect(count)
	# A world freed while the next arena is pending leaves nothing behind.
	BossRush.begin("test/a", cell_feet(5, 16))
	BossRush.on_boss_down(w, p)
	check(BossRush.active() and int(BossRush.run.index) == 1, "a boss down: on to the next")
	w.queue_free()
	await frames(int(BossRush.NEXT_DELAY * 60) + 10)
	check(true, "the pending move finds the world gone and does nothing")
	# A new game never starts in a rush.
	var w2 := make_world(_temple(), "test/a", cell_feet(5, 16))
	check(not BossRush.active() and not Trials.active(), "a new world starts clean")
	w2.queue_free()


## Pass 160: the Ring of Winds, the fourth trial, opened with Thorns by the
## second spring and built for the Glove and the Featherstep Boots. Ride a current over
## the spikes, climb a wall into a second, take a double jump to a high plank,
## and drop out of the last current over the bell (ride it on and it throws you
## onto spikes). The inner rings has no weather: its winds never turn.
func test_the_ring_of_winds_is_ridden_climbed_and_let_go() -> void:
	var t := Trials.find("winds")
	check(Trials.built().has(t) and t.needs == ["glove", "boots"] and t.desc != "", "the Ring of Winds is built, for the Glove and the Featherstep Boots")
	var text := FileAccess.get_file_as_string(World.room_path(t.room))
	var bell := Reach.key(t.room, 86, 11)
	for kit: Dictionary in [{"glove": true, "boots": true}, {"glove": true, "boots": true, "sky_spring": true}]:
		var reach := Reach.new({t.room: text}, kit)
		check(reach.reachable(reach.spot_of(t.room, "P")).has(bell), "the bell is reached with %s" % [kit.keys()])
	var bare := Reach.new({t.room: text}, {"glove": true})
	check(not bare.reachable(bare.spot_of(t.room, "P")).has(bell), "without the Featherstep Boots it is not")
	var calm_text := text.replace(">", ".")
	var calm := Reach.new({t.room: calm_text}, {"glove": true, "boots": true, "stride": true})
	check(not calm.reachable(calm.spot_of(t.room, "P")).has(bell), "and with no wind, not even with the Stride")
	# The Ringreader keeps it sealed, and says why, until the boots are found.
	GameState.new_game()
	GameState.set_flag("spring:heartwood")
	GameState.set_flag("spring:haar")
	GameState.data.abilities["glove"] = true
	check(Trials.is_open(t) and not Trials.ready(t) and Trials.missing(t) == ["Featherstep Boots"], "two springs open it, but it wants the Featherstep Boots (%s)" % [Trials.missing(t)])
	GameState.data.abilities["boots"] = true
	check(Trials.ready(t), "and with them it is ready")
	# In the real game: the first current carries you over the spikes to the pillar.
	var w := make_world(_temple(), "test/a", cell_feet(5, 16))
	GameState.set_flag("spring:heartwood")
	GameState.set_flag("spring:haar")
	GameState.set_flag("spring:sky")
	GameState.data.abilities["glove"] = true
	GameState.data.abilities["boots"] = true
	var p := w.player
	GameState.apply(p)
	await frames(5)
	Menus.start_trial(w, p, t)
	await frames(5)
	check(w.room.id == "trials/winds", "the Ringreader sends you there")
	var winds := w.room.get_children().filter(func(c: Node) -> bool: return c is WindCurrent)
	check(winds.size() == 3 and winds.all(func(c: WindCurrent) -> bool: return c.dir() == 1), "three currents, all blowing east even with the Sky Spring restored")
	var landed := false
	# Run to the ledge's lip and jump into the current, then let it carry you.
	var jumped := -1
	for f in 300:
		var x := p.global_position.x / Room.TILE
		if jumped < 0 and x > 7.6:
			jumped = f
		p.input.move_x = 1 if jumped < 0 or f < jumped + 12 else 0
		p.input.jump_pressed = f == jumped
		p.input.jump_held = jumped >= 0 and f < jumped + 16
		await frames(1)
		if jumped >= 0 and f > jumped + 20 and p.is_on_floor():
			landed = true
			break
	var col := int(p.global_position.x / Room.TILE)
	check(landed and col >= 35 and col <= 39 and absf(p.global_position.y - (16 * Room.TILE)) < 2.0,
		"jump into the first current and it carries you over the spikes to the pillar (col %d, row %.1f)" % [col, p.global_position.y / Room.TILE])
	w.queue_free()
	Trials.abandon()


## Pass 162: the Ring of Stillness, the fifth trial, opened by the third
## spring and built for the Glove and the Stillstone. Still a fall and climb its
## footholds, cross a pit on a curtain of water that hangs from the void, and
## climb a long fall with a dry niche halfway to wait out the glass.
func test_the_ring_of_stillness_is_climbed_in_frozen_moments() -> void:
	var t := Trials.find("stillness")
	check(Trials.built().has(t) and t.needs == ["glove", "stillstone"] and t.desc != "", "the Ring of Stillness is built, for the Glove and the Stillstone")
	var text := FileAccess.get_file_as_string(World.room_path(t.room))
	var bell := Reach.key(t.room, 68, 7)
	var reach := Reach.new({t.room: text}, {"glove": true, "stillstone": true})
	var nodes := reach.reachable(reach.spot_of(t.room, "P"))
	check(nodes.has(bell), "the bell is reached with the Glove and the Stillstone")
	check(nodes.has(Reach.key(t.room, 50, 19)), "the dry niche halfway up the last fall is a place to wait")
	var bare := Reach.new({t.room: text}, {"glove": true, "boots": true, "stride": true, "delvers_pick": true})
	check(not bare.reachable(bare.spot_of(t.room, "P")).has(Reach.key(t.room, 20, 38)), "without the glass not even the first ledge is in reach")
	GameState.new_game()
	for s: String in ["heartwood", "haar", "sky"]:
		GameState.set_flag("spring:" + s)
	GameState.data.abilities["glove"] = true
	check(Trials.is_open(t) and Trials.missing(t) == ["Stillstone"], "three springs open it, but it wants the Stillstone (%s)" % [Trials.missing(t)])
	# In the real game: still the first fall and climb it to the ledge above.
	var w := make_world(_temple(), "test/a", cell_feet(5, 16))
	for s: String in ["heartwood", "haar", "sky"]:
		GameState.set_flag("spring:" + s)
	GameState.data.abilities["glove"] = true
	GameState.data.abilities["stillstone"] = true
	var p := w.player
	GameState.apply(p)
	await frames(5)
	Menus.start_trial(w, p, t)
	await frames(5)
	check(w.room.id == "trials/stillness", "the Ringreader sends you there")
	var falls := w.room.get_children().filter(func(c: Node) -> bool: return c is Waterfall)
	check(falls.size() == 3, "three falls of time-locked water (%d)" % falls.size())
	for f in 120:
		p.input.move_x = 1 if p.global_position.x < 13.5 * Room.TILE else 0
		await frames(1)
	p.input.move_x = 0
	p.input.stillstone_pressed = true
	await frames(1)
	p.input.stillstone_pressed = false
	# A short hop from each foothold to the next, three rows up.
	var top := INF
	var hop := -100
	for f in 140:
		if p.is_on_floor() and f > hop + 3:
			hop = f
		p.input.jump_pressed = f == hop
		p.input.jump_held = f < hop + 15
		await frames(1)
		top = minf(top, p.global_position.y)
	p.input.jump_held = false
	check(top <= 40.0 * Room.TILE + 2.0, "jumping up the stilled fall reaches its top foothold (row %.1f)" % (top / Room.TILE))
	check(p.safe_position.y > 50.0 * Room.TILE, "a foothold of stilled water is never a footing to be set back to (row %.1f)" % (p.safe_position.y / Room.TILE))
	for f in 40:
		p.input.move_x = 1
		p.input.jump_pressed = f == 0
		p.input.jump_held = f < 10
		await frames(1)
	p.input.move_x = 0
	await frames(30)
	check(p.global_position.x > 15.0 * Room.TILE and absf(p.global_position.y - 39.0 * Room.TILE) < 2.0,
		"and steps off onto the ledge before time runs on (col %.1f, row %.1f)" % [p.global_position.x / Room.TILE, p.global_position.y / Room.TILE])
	w.queue_free()
	Trials.abandon()



## Pass 168 (bible 3.1): the sixth and last Ringreader Trial. A descent: ledges
## falling away over spikes, planks to drop through, and a needle of thorn bulbs
## to fall straight down. A bot that only steers its falls clears it.
func test_the_ring_of_falling_is_steered_all_the_way_down() -> void:
	var t := Trials.find("falling")
	check(Trials.built().has(t) and t.desc != "" and not t.has("needs"), "the Ring of Falling is built, for the Glove alone")
	check(Trials.built().size() == Trials.LIST.size(), "all six trials are built")
	var text := FileAccess.get_file_as_string(World.room_path(t.room))
	var reach := Reach.new({t.room: text}, {"glove": true})
	var nodes := reach.reachable(reach.spot_of(t.room, "P"))
	check(nodes.has(Reach.key(t.room, 21, 86)), "the checker falls to the bell")
	check(text.count("o") >= 6 and text.count("-") >= 24, "the needle has its thorns and the well its planks")
	var w := make_world(_temple(), "test/a", cell_feet(5, 16))
	for s: String in ["heartwood", "haar", "sky"]:
		GameState.set_flag("spring:" + s)
	GameState.data.abilities["glove"] = true
	var p := w.player
	GameState.apply(p)
	await frames(5)
	check(Trials.ready(t), "three springs open it")
	Menus.start_trial(w, p, t)
	await frames(5)
	check(w.room.id == "trials/falling", "the Ringreader sends you there")
	# Waypoints: the column to stand on (or fall toward), and whether to drop
	# through the plank underfoot once there.
	var route := [[13, false], [8, false], [13, false], [19, false], [25, false], [34, true], [34, true], [34, true], [34, false], [21, false]]
	var step := 0
	# A waypoint counts only once you have been in the air since the last one.
	var flown := true
	var set_backs := 0
	var last := p.global_position
	var lowest := 0.0
	var goal: Node = w.room.get_children().filter(func(c: Node) -> bool: return c is TrialGoal)[0]
	for f in 1200:
		var target := (float(route[step][0]) + 0.5) * Room.TILE
		var dx := target - p.global_position.x
		p.input.move_x = 0 if absf(dx) < 3.0 else int(signf(dx))
		p.input.down = false
		p.input.jump_pressed = false
		p.input.jump_held = false
		if not p.is_on_floor():
			flown = true
		elif flown and absf(dx) < 4.0:
			flown = false
			if route[step][1]:
				p.input.down = true
				p.input.jump_pressed = true
				p.input.jump_held = true
			step = mini(step + 1, route.size() - 1)
		await frames(1)
		if p.global_position.y < last.y - 24.0:
			set_backs += 1
		last = p.global_position
		lowest = maxf(lowest, p.global_position.y)
		if goal.rung:
			break
	check(goal.rung, "the bot rings the bell (lowest row %.1f, waypoint %d)" % [lowest / Room.TILE, step])
	check(set_backs == 0, "without a single set-back (%d)" % set_backs)
	var best := Trials.best("falling")
	print("  Ring of Falling: %.2f s" % best)
	check(best < float(t.grain), "a clean run beats the ring time (%.2f < %d)" % [best, t.grain])
	check(best > float(t.grain) * 0.5, "which still asks for a clean one")
	w.queue_free()
	Trials.abandon()


## Pass 164 (bible 10): the cosmetics the Inner Rings promise. Each trial has a
## ring time; ring its bell within it and the trial dyes your cloak a color of
## its own, and Ilse keeps it on her shelf to wear again for nothing.
func test_a_trial_rung_within_its_grain_dyes_the_cloak() -> void:
	var dyes := {}
	for t: Dictionary in Trials.built():
		check(float(t.get("grain", 0)) > 0.0, "%s has a ring time" % t.name)
		var item := GameData.item(String(t.get("dye", "")))
		check(String(item.get("kind", "")) == "dye" and String(item.get("color", "")) != "", "and a dye of its own (%s)" % t.get("dye", ""))
		dyes[String(t.dye)] = true
	check(dyes.size() == Trials.built().size(), "no two trials share a dye")
	var w := make_world(_temple(), "test/a", cell_feet(5, 16))
	var p := w.player
	await frames(2)
	var t := Trials.find("walls")
	var shop := "hearthroot_dyes"
	var index := -1
	var stock: Array = GameData.shop(shop).stock
	for i in stock.size():
		if String(stock[i].item) == String(t.dye):
			index = i
	check(index >= 0 and not Shop.shelf(shop).has(index), "Ilse keeps a place for it, off the shelf until it is earned")
	Trials.begin(t.id, "hearthroot/ringreader_temple", Vector2.ZERO)
	Trials.run.time = float(t.grain) + 0.5
	var slow := Trials.finish()
	check(slow.dye == "" and not GameState.owns_dye(String(t.dye)), "a clear outside the ring earns no dye")
	Trials.begin(t.id, "hearthroot/ringreader_temple", Vector2.ZERO)
	Trials.run.time = float(t.grain) - 0.5
	var quick := Trials.finish()
	check(quick.dye == String(t.dye) and GameState.owns_dye(quick.dye) and GameState.dye() == quick.dye, "within it the cloak takes the trial's dye (%s)" % quick.dye)
	check(Shop.shelf(shop).has(index), "and it is on Ilse's shelf")
	PlayerVisual.body_sets = false  # the ranger's cloak takes dyes; the body sets have none yet
	await frames(2)
	check(not PlayerVisual.dye_look().is_empty() and p.visual.material != null, "the cloak is recolored")
	PlayerVisual.body_sets = true
	GameState.data.dye = ""
	check(Shop.status(shop, index, p) == "" and Shop.buy(shop, index, p) and GameState.dye() == String(t.dye), "Ilse puts it back on for nothing")
	Trials.begin(t.id, "hearthroot/ringreader_temple", Vector2.ZERO)
	Trials.run.time = 1.0
	check(Trials.finish().dye == "", "a second quick clear does not give it twice")
	var saved := GameState.sanitize(JSON.parse_string(JSON.stringify(GameState.data)))
	check(Array(saved.dyes).has(String(t.dye)), "the save keeps it")
	# The Ringreader's list names each ring time and keeps the sealed ones sealed.
	GameState.set_flag("spring:heartwood")
	p.abilities["glove"] = true
	GameState.data.abilities["glove"] = true
	var menu := ListMenu.new()
	arena.add_child(menu)
	check(Menus.open_trials(arena.get_tree(), p), "the trials list opens")
	var rows := {}
	for r: Dictionary in menu.rows:
		rows[String(r.label)] = r
	check(String(rows["Ring of Walls"].detail).contains("Grain Slate is yours"), "Walls says its dye is yours (%s)" % rows["Ring of Walls"].detail)
	check(String(rows["Ring of Edges"].detail).contains("Ring it within 0:14.0 for Ledge Coral"), "Edges names its ring time and dye (%s)" % rows["Ring of Edges"].detail)
	check(rows["Ring of Stillness"].right == "Sealed" and not String(rows["Ring of Stillness"].detail).contains("Ring it"), "a trial still sealed stays sealed, with no ring yet")
	menu.queue_free()
	arena.get_tree().paused = false
	w.queue_free()
	Trials.abandon()


## Pass 165 (bible 13): a ring dye won rings out with its own sound over the
## trial bell; a clear that earns none rings the bell alone.
func test_a_won_dye_sounds_over_the_bell() -> void:
	GameState.new_game()
	var heard := []
	for k in 2:
		Trials.begin("edges", Trials.TEMPLE, Vector2.ZERO)
		Trials.run.time = 1.0
		var goal := TrialGoal.new()
		arena.add_child(goal)
		Sfx.recent.clear()
		goal.ring(null)
		heard.append(Sfx.recent.duplicate())
		goal.queue_free()
	Trials.abandon()
	await frames(1)
	check(GameState.owns_dye("coral_dye"), "the quick clear won the dye")
	check(heard[0].has("trial_bell") and heard[0].has("dye_won"), "the first rings the bell and the dye (%s)" % [heard[0]])
	check(heard[1].has("trial_bell") and not heard[1].has("dye_won"), "a second rings the bell alone (%s)" % [heard[1]])


## Pass 172: the Journey page shows Completion's shares mid-game (the 100% goal
## gates the Crown Gold and the Ringreader's rush) and the guardians found so far,
## never one whose arena you have not entered.
func test_the_journey_page_counts_the_world_and_the_guardians_found() -> void:
	var ids := Completion.GUARDIANS.map(func(g: Array) -> String: return g[0])
	check(ids.size() == BossArena.BOSSES.size() and BossArena.BOSSES.keys().all(func(k: String) -> bool: return ids.has(k)),
		"the Journey names every guardian the arena knows, once (%d of %d)" % [ids.size(), BossArena.BOSSES.size()])
	var w := make_world({}, "heartwood/root_chamber")
	await frames(2)
	check(String(w.catalog["vorrhallow/alpha_den"].boss) == "clockwork_alpha" and String(w.catalog["hearthroot/plaza"].get("boss", "")) == "",
		"the catalog knows which rooms are arenas")
	var found := Completion.guardians_found(w.catalog)
	check(found.size() == 1 and found[0].id == "gnarlmaw" and not found[0].beaten, "standing in the Root Chamber, only Gnarlmaw is found, still waiting")
	GameState.set_flag("boss:gnarlmaw")
	w._enter("boughs/thorn_yard")
	await frames(2)
	found = Completion.guardians_found(w.catalog)
	check(found.size() == 2 and found[0].beaten and found[1].id == "bark_captain", "a beaten guardian, then the Captain once his yard is entered, in climb order")
	var stats := Completion.tally(w.catalog)
	var rows := Completion.journey_rows(stats, found)
	check(rows[0].right == "%d%%" % int(stats.percent), "the page opens on the percent of the world")
	check(rows[4].label == "Guardians beaten" and rows[4].right == "1 / %d" % BossArena.BOSSES.size(), "and counts the guardians beaten (%s)" % rows[4].right)
	var names := rows.map(func(r: Dictionary) -> String: return r.label)
	check(names.has("Gnarlmaw") and names.has("The Bark Knight Captain") and not names.has("Snapcrown"), "it names the guardians found, and no other")
	check(rows[-1].label == "%d not yet found" % (BossArena.BOSSES.size() - 2), "and says how many are still to find (%s)" % rows[-1].label)
	var menu := ListMenu.new()
	arena.add_child(menu)
	check(Menus.open_journey(arena.get_tree(), func() -> void: pass), "the pause menu's Journey opens")
	check(menu.title == "Journey" and menu.rows.size() == rows.size(), "with those rows")
	for r: Dictionary in menu.rows:
		check(PixelFont.width(String(r.label), 9) < menu.panel.size.x * 0.7, "%s fits the panel" % r.label)
	menu.close()
	menu.queue_free()


## Pass 180: every Life Fruit and Mana Dew is counted, wherever it waits (the
## rooms, the four grocers, the guardians), and the totals are design bible 5.1's:
## 18 fruits (5 masks to 14) and 16 dews (60 MP to 220). The Journey page shows
## how many a save has taken, read from its health and magic, outside the percent.
func test_the_journey_counts_every_life_fruit_and_mana_dew() -> void:
	var w := make_world({}, "heartwood/root_chamber")
	await frames(2)
	var s := Completion.stat_items(w.catalog)
	check(int(s.fruits_total) == 18 and int(s.dews_total) == 16, "18 Life Fruits and 16 Mana Dews in all, as the bible counts them (%d, %d)" % [s.fruits_total, s.dews_total])
	var in_rooms := [0, 0]
	for id: String in w.catalog:
		in_rooms[0] += int(w.catalog[id].fruits)
		in_rooms[1] += int(w.catalog[id].dews)
	check(in_rooms[0] == 13 and in_rooms[1] == 9, "13 fruits and 9 dews lie in the rooms (%d, %d)" % in_rooms)
	check(GameState.fresh().max_hp + 18 * GameState.LIFE_FRUIT_HP == 280 and GameState.fresh().max_mp + 16 * GameState.MANA_DEW_MP == 220.0,
		"all of them make 14 masks and 220 MP")
	check(int(s.fruits) == 0 and int(s.dews) == 0, "a new save has taken none")
	var before := Completion.tally(w.catalog)
	GameState.grant_stat_item("life_fruit", w.player)
	GameState.grant_stat_item("life_fruit", w.player)
	GameState.grant_stat_item("mana_dew", w.player)
	var after := Completion.tally(w.catalog)
	check(int(after.fruits) == 2 and int(after.dews) == 1, "two fruits and a dew are counted (%d, %d)" % [after.fruits, after.dews])
	check(int(after.percent) == int(before.percent), "and they stand outside the percent")
	var rows := Completion.journey_rows(after, [])
	check(rows[5].label == "Life Fruits" and rows[5].right == "2 / 18" and rows[6].label == "Mana Dew" and rows[6].right == "1 / 16",
		"the Journey page shows them (%s, %s)" % [rows[5].right, rows[6].right])
	GameState.new_game()


## Pass 253: bible 9 said the game gives 29 skill points: 15 ranks, 9 from the
## main bosses and 7 from whole rings. But twelve guardians give one (the
## Everbloom's three forms and the Drowned Warden among them), so it gives 34.
## The Journey page now counts them, earned against the whole, and learning or
## unlearning a skill never moves the count.
func test_the_journey_counts_every_skill_point_the_game_gives() -> void:
	var w := make_world({}, "hearthroot/ringreader_temple")
	await frames(2)
	var givers := BossArena.BOSSES.keys().filter(func(id: String) -> bool: return int(BossArena.BOSSES[id].get("skill_points", 0)) > 0)
	var grains := 0
	for id: String in w.catalog:
		grains += int(w.catalog[id].get("grains", 0))
	check(GameState.RANK_XP.size() - 1 == 15 and givers.size() == 12 and grains == 15 and Trials.LIST.size() == 6,
		"15 ranks, 12 guardians that give a point, 15 Grain Shards in the rooms and 6 trials (%d, %d, %d)" % [givers.size(), grains, Trials.LIST.size()])
	var s := Completion.skill_points(w.catalog)
	check(int(s.points_total) == 34 and int(s.points) == 0, "34 points in all, as bible 9 counts them, and a new save has none (%d, %d)" % [s.points_total, s.points])
	var cost := 0
	for n: Dictionary in Skills.nodes():
		cost += int(n.cost)
	check(cost > int(s.points_total), "the tree costs more than the game gives (%d against %d)" % [cost, s.points_total])
	GameState.data.skill_points = 3
	w.player.gold = 1000
	check(Skills.learn("keen_edge", w.player) and Skills.learn("fourth_strike", w.player), "two skills learned")
	check(int(Completion.skill_points(w.catalog).points) == 3, "learning them leaves three points earned")
	check(Skills.respec(w.player) and int(Completion.skill_points(w.catalog).points) == 3, "and so does unlearning them")
	var rows := Completion.journey_rows(Completion.tally(w.catalog), [])
	check(rows[7].label == "Skill points" and rows[7].right == "3 / 34", "the Journey page shows them (%s %s)" % [rows[7].label, rows[7].right])
	GameState.new_game()


## Pass 269 (bible 10.3): the Inventory page lists what you carry to use and
## the charts you hold. An Amber Draught showed nowhere once bought, and the charts
## only on the map, so nothing said which zones were still uncharted.
func test_the_inventory_lists_supplies_and_charts() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(2)
	var labels := func() -> Array: return Menus.inventory_rows(p).map(func(r: Dictionary) -> String: return r.label)
	check(not labels.call().has("Supplies") and not labels.call().any(func(l: String) -> bool: return l.begins_with("Charts")), "nothing carried, no supplies or charts listed")
	p.ointments = 2
	p.elixirs = 1
	GameState.data.charts["hearthroot"] = true
	GameState.data.charts["vorrhallow"] = true
	var rows := Menus.inventory_rows(p)
	var by := {}
	for r: Dictionary in rows:
		by[r.label] = r
	var total := GameData.table("items").values().filter(func(i: Dictionary) -> bool: return i.get("kind", "") == "chart").size()
	check(by.has("Supplies") and by["Barkbalm"].right == "x2" and by["Amber Draught"].right == "x1", "Barkbalms and the Amber Draught show how many you carry")
	check(by.has("Charts, 2 of %d" % total) and by.has("Chart of Hearthroot") and by.has("Chart of Vorrhallow"), "each chart held, counted against every chart sold (%s)" % [labels.call()])
	check(by.has("%d not yet charted" % (total - 2)) and by["%d not yet charted" % (total - 2)].get("enabled", true) == false, "and how many are still to buy")
	var blank := rows.filter(func(r: Dictionary) -> bool: return not r.get("header", false) and String(r.get("detail", "")) == "")
	check(blank.is_empty(), "every line says what it does (%s)" % [blank])
	for zone: String in ["hearthroot", "heartwood", "tower", "haar", "boughs", "spires", "vorrhallow", "sunken"]:
		GameState.data.charts[zone] = true
	labels = func() -> Array: return Menus.inventory_rows(p).map(func(r: Dictionary) -> String: return r.label)
	check(labels.call().has("Charts, %d of %d" % [total, total]) and not labels.call().any(func(l: String) -> bool: return l.ends_with("not yet charted")), "every chart held: nothing left to buy")
	GameState.data.charts = {}
	p.ointments = 0
	p.elixirs = 0


## Bible 14 (pass 325): the mercy assist. The bible promised assist options
## and none were built. Mercy doubles a hit's invulnerability (0.8 s to 1.6 s)
## and the blink with it, while the hurt pose still lets go as soon as before.
func test_the_mercy_assist_doubles_a_hits_grace() -> void:
	Settings.path = TEMP_SETTINGS
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	check(not Settings.mercy and Settings.value_text("mercy") == "Off", "off by default")
	check(Menus.OPTIONS.any(func(o: Array) -> bool: return o[0] == "mercy"), "it is an Options row")
	p.hp = 100
	p.take_damage(10)
	check_near(p.hurt_invuln(), 0.8, 0.001, "a hit's grace is the tuning's 0.8 s")
	await frames(54)
	check(not p.invulnerable, "and is over 0.9 s later")
	p.take_damage(10)
	check(p.hp == 80, "so a second blow lands (%d)" % p.hp)
	await frames(60)
	Settings.adjust("mercy", 1)
	check(Settings.mercy and Settings.value_text("mercy") == "On", "the option turns it on")
	p.take_damage(10)
	check_near(p.hurt_invuln(), 0.8 * Settings.MERCY_MULT, 0.001, "with mercy the grace is 1.6 s")
	check(p.visual._blink_time >= 1.6 - 0.001, "and the blink lasts as long (%.2f)" % p.visual._blink_time)
	await frames(18)
	check(not p.is_hurt, "the hurt pose still lets go after 0.25 s")
	await frames(36)
	check(p.invulnerable, "0.9 s later you still can't be hurt")
	var hp := p.hp
	p.take_damage(10)
	check(p.hp == hp, "so a second blow does nothing (%d)" % p.hp)
	await frames(48)
	check(not p.invulnerable, "until 1.6 s have passed")
	Settings.reset()
	Settings.load_settings()
	check(Settings.mercy, "the choice is saved")
	_restore()
	check(not Settings.mercy, "and the suite runs on the default, off")


## Pass 343: bible 14 promised three save slots, and the game has always kept
## one (`Game.SAVE_SLOT`; three since Sean's flasks, `Game.SAVE_SLOTS`); its accessibility line names the options' steps
## (game speed 70 to 100% in tens, shake and flash names, the mercy assist's
## 0.8 s to 1.6 s). No test read any of it. These hold the line to the code,
## and the one slot's safe write and backup to what the bible now says.
func test_the_bibles_saves_and_options_are_as_built() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var tech := bible.get_slice("## 14. Technical Architecture", 1).get_slice("\n## 15. ", 0)
	var slots: Array = (load("res://scripts/game.gd") as Script).get_script_constant_map()["SAVE_SLOTS"]
	check(slots == [1, 2, 3], "three journeys (Sean, 2026-10-31): %s" % [slots])
	check(tech.contains("slots `Game.SAVE_SLOTS`, `%s` to `%s`" % [GameState.SAVE_PATH % slots[0], (GameState.SAVE_PATH % slots[-1]).get_file()]), "14 names the three saves and their paths")
	# The safe write keeps the last good copy, and a damaged save falls back to it.
	var path := "user://test_pass_343.json"
	check(GameState.write_safely(path, "{\"a\": 1}") and GameState.write_safely(path, "{\"a\": 2}"), "a save writes twice")
	check(FileAccess.get_file_as_string(path) == "{\"a\": 2}" and FileAccess.get_file_as_string(path + ".bak") == "{\"a\": 1}", "the last good copy is kept as .bak")
	check(not FileAccess.file_exists(path + ".tmp"), "no .tmp is left behind")
	for f: String in [path, path + ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	check(tech.contains("with the last good copy kept as `.bak`"), "14 says so")
	# The accessibility line's numbers.
	var speeds := Settings.SPEED_STEPS.map(func(s: float) -> int: return roundi(s * 100.0))
	speeds.sort()
	var tens := true
	for i in range(1, speeds.size()):
		tens = tens and speeds[i] - speeds[i - 1] == 10
	check(tens and tech.contains("game speed slider (%d to %d%%; steps of 10)" % [speeds[0], speeds[-1]]), "14 gives the game speed's range and steps (%s)" % [speeds])
	check(tech.contains("shake (%s)" % ", ".join(Settings.SHAKE_NAMES).to_lower()), "14 names the shake steps (%s)" % [Settings.SHAKE_NAMES])
	check(tech.contains("flashes (%s)" % ", ".join(Settings.FLASH_NAMES).to_lower()), "14 names the flash steps (%s)" % [Settings.FLASH_NAMES])
	var invuln := MovementTuning.new().hurt_invuln
	check(tech.contains("(%s s to %s s, `Settings.MERCY_MULT`" % [String.num(invuln), String.num(invuln * Settings.MERCY_MULT)]), "14 gives the mercy assist's grace (%s s, x%s)" % [invuln, Settings.MERCY_MULT])




## Pass 381 (bible 14): the accessibility line's list of options was the pass
## 09 interim's, without damage numbers or the mercy assist, and the title's
## Options and Controls rows had drifted the same way. The bible lists the page
## as built; this holds the rows, their order and their starting values to
## Menus.OPTIONS and Settings, and both menus' Options and Controls lines.
func test_the_options_page_is_the_one_the_bible_lists() -> void:
	const COUNTS := {6: "six", 7: "seven", 8: "eight", 9: "nine", 10: "ten"}
	const NAMED := {"shake": "screen shake", "flashes": "flashes", "rumble": "rumble", "numbers": "damage numbers",
		"mercy": "the mercy assist", "music": "volume", "sound": "volume", "speed": "game speed"}
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var line := bible.get_slice("*The Options page, as built (pass 381):* ", 1).get_slice(". ", 0)
	check(line.begins_with("%s rows, in this order: " % COUNTS.get(Menus.OPTIONS.size(), "?")), "14 counts the page's rows (%d)" % Menus.OPTIONS.size())
	# Each row by its label, in order, with its steps or its starting value.
	var at := 0
	for o: Array in Menus.OPTIONS:
		var label: String = o[1]
		var found := line.find(label, at)
		check(found >= at, "14 lists %s, in order" % label)
		at = maxi(at, found)
	check(line.contains("Screen shake (%s)" % ", ".join(Settings.SHAKE_NAMES).to_lower()), "14 gives the shake steps")
	check(line.contains("Screen flashes (%s)" % ", ".join(Settings.FLASH_NAMES).to_lower()), "14 gives the flash steps")
	for k: Array in [["rumble", "Rumble"], ["numbers", "Damage numbers"], ["mercy", "Assist: mercy"]]:
		check(line.contains("%s (%s to start)" % [k[1], Settings.value_text(k[0]).to_lower()]), "14 gives %s's start (%s)" % [k[1], Settings.value_text(k[0])])
	check(Settings.music_volume == Settings.sound_volume and line.contains("Music volume and Sound volume (a bar of %d, at %d to start)" % [Settings.VOLUME_MAX, Settings.music_volume]),
		"14 gives the volumes' bar and start (%d of %d)" % [Settings.music_volume, Settings.VOLUME_MAX])
	check(line.contains("Game speed (%s to start)" % Settings.value_text("speed")), "14 gives the game speed's start (%s)" % Settings.value_text("speed"))
	# What the menus say of the page names every row.
	for o: Array in Menus.OPTIONS:
		check(NAMED.has(o[0]) and Menus.OPTIONS_DETAIL.to_lower().contains(NAMED.get(o[0], "?")), "the Options row's line names %s (%s)" % [o[1], Menus.OPTIONS_DETAIL])
	check(Menus.CONTROLS_DETAIL.contains("pad"), "the Controls row's line says the pad rebinds too")
	# Both menus read those lines, not words of their own.
	var re := RegEx.create_from_string("\\{\"label\": \"(Options|Controls)\", \"detail\": ([^}]*)\\}")
	var rows := 0
	for f: String in ["res://scripts/ui/menus.gd", "res://scripts/game.gd"]:
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(f)):
			rows += 1
			var want := "Menus.OPTIONS_DETAIL" if m.get_string(1) == "Options" else "Menus.CONTROLS_DETAIL"
			check(m.get_string(2).strip_edges() in [want, want.trim_prefix("Menus.")], "%s's %s row reads %s (%s)" % [f.get_file(), m.get_string(1), want, m.get_string(2)])
	check(rows == 4, "the pause menu and the title each have an Options and a Controls row (%d)" % rows)

## Sean (2026-10-31, bible 14): three save slots shown as three colored flasks,
## with no number or letter on any; a journey's details show when its flask is
## focused (Left/Right or the mouse). Choosing a full flask takes that journey
## up, an empty one begins anew in it, and Block then Jump pours one out.
func test_three_flasks_hold_three_journeys() -> void:
	const SLOTS := [7, 8, 9]
	for s: int in SLOTS:
		GameState.delete_save(s)
	var was := GameState.slot
	GameState.new_game()
	GameState.data.save_room = "heartwood/amberlee"
	GameState.data.rank = 4
	GameState.data.gold = 1820
	GameState.data.flags["spring:heartwood"] = true
	check(GameState.save_game(7), "a journey rests in the first flask")
	GameState.new_game()
	GameState.data.save_room = "haar/lampwick"
	GameState.data.rank = 9
	check(GameState.save_game(9), "and another in the third")
	GameState.new_game()
	GameState.slot = was
	var picker := SlotPicker.new()
	picker.slots = SLOTS
	arena.add_child(picker)
	picker.open()
	check(picker.is_open and picker.saves.size() == 3, "three flasks on the shelf")
	check(not picker.saves[0].is_empty() and picker.saves[1].is_empty() and not picker.saves[2].is_empty(), "two hold a journey, one stands empty")
	check(picker.cursor in [0, 2], "the shelf opens on a journey (%d)" % picker.cursor)
	picker.cursor = 0
	var said := " / ".join(picker.details())
	check(said.contains("Amberlee") and said.contains("Heartwood") and said.contains(GameState.RANKS[4]) and said.contains("1,820 gold") and said.contains("One spring of three flows"), "a full flask tells its journey (%s)" % said)
	check(float(picker.saves[2].fill) > float(picker.saves[0].fill), "a higher rank fills its flask higher")
	picker.cursor = 1
	check(" ".join(picker.details()).begins_with("An empty flask."), "an empty one says so")
	# No flask is named by a number or a letter: a slot's own number shows nowhere.
	for i in 3:
		picker.cursor = i
		for line: String in picker.details():
			check(not line.contains(str(SLOTS[i])) and not line.to_lower().contains("slot"), "flask %d's lines never name its slot (%s)" % [i, line])
	picker.cursor = 2
	picker.move(1)
	check(picker.cursor == 0, "Right past the last flask wraps to the first")
	# The mouse focuses the flask under it.
	check(picker.flask_at(picker.flask_center(1)) == 1 and picker.flask_at(Vector2(4, 4)) == -1, "the mouse finds the flask under it")
	# Choosing.
	var got := []
	picker.chosen.connect(func(slot: int, fresh: bool) -> void: got.append([slot, fresh]))
	picker.cursor = 1
	picker.confirm()
	check(got == [[8, true]] and not picker.is_open, "an empty flask begins a new journey in its slot (%s)" % [got])
	picker.open()
	picker.cursor = 2
	picker.confirm()
	check(got.back() == [9, false], "a full one takes its journey up (%s)" % [got.back()])
	# Pouring out: Block asks, Dash keeps it, Jump pours.
	picker.open()
	picker.cursor = 0
	picker.pour()
	check(picker.pouring and picker.details()[0].begins_with("Pour this journey out"), "Block on a full flask asks first")
	picker.back()
	check(not picker.pouring and picker.is_open and GameState.has_save(7), "Dash keeps it")
	picker.pour()
	picker.confirm()
	check(not GameState.has_save(7) and picker.saves[0].is_empty() and picker.is_open, "Jump pours it out, and the flask stands empty")
	picker.cursor = 1
	picker.pour()
	check(not picker.pouring, "an empty flask has nothing to pour")
	# A damaged save reads as nothing, never as a broken flask.
	var f := FileAccess.open(GameState.SAVE_PATH % 8, FileAccess.WRITE)
	f.store_string("not a save")
	f.close()
	check(GameState.read_slot(8).is_empty() and SlotPicker.summary(GameState.read_slot(8)).is_empty(), "a damaged file is an empty flask")
	picker.free()
	for s: int in SLOTS:
		GameState.delete_save(s)
	GameState.slot = was



## Pass 359 (bible 15.3): the title's real path through the flasks. The shelf
## had been tested on its own, but never as the game drives it: Journeys row,
## shelf, a journey taken up, the ending back to the title, and another flask
## chosen on the same shelf. Each journey must rest in its own flask and never
## spill into another, and each trip must leave one world, an unpaused tree and
## one listener on each of the shelf's signals.
func test_the_title_takes_journeys_up_and_back_in_their_own_flasks() -> void:
	const SLOTS := [7, 8, 9]
	for s: int in SLOTS:
		GameState.delete_save(s)
	Settings.path = TEMP_SETTINGS
	var was := GameState.slot
	GameState.new_game()
	GameState.data.save_room = "evercrown/heart"
	GameState.data.gold = 500
	check(GameState.save_game(8), "a journey rests in the middle flask")
	GameState.new_game()
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.picker.slots = SLOTS
	var worlds := func() -> int:
		var n := 0
		for c in g.view.get_children():
			if c is World and not c.is_queued_for_deletion():
				n += 1
		return n
	for trip: int in 2:
		# The title's first row opens the shelf.
		check(g.menu.is_open and g.title_screen.visible, "trip %d: the title is up" % trip)
		g.menu.cursor = 0
		g.menu.confirm()
		check(g.picker.is_open and not g.menu.is_open and runner.get_tree().paused, "trip %d: Journeys opens the shelf over a still world" % trip)
		check(g.picker.chosen.get_connections().size() == 1 and g.picker.cancelled.get_connections().size() == 1, "trip %d: the shelf has one listener each (%d, %d)" % [trip, g.picker.chosen.get_connections().size(), g.picker.cancelled.get_connections().size()])
		# First the full flask, then an empty one.
		var pick := 1 if trip == 0 else 0
		check(trip == 1 or g.picker.cursor == 1, "the shelf opens on the journey")
		g.picker.cursor = pick
		g.picker.confirm()
		await frames(3)
		check(worlds.call() == 1 and not runner.get_tree().paused and not g.title_screen.visible and not g.picker.is_open, "trip %d: one world, playing (%d worlds)" % [trip, worlds.call()])
		check(GameState.slot == int(SLOTS[pick]), "trip %d: the journey is the chosen flask's (%d)" % [trip, GameState.slot])
		if trip == 0:
			check(int(GameState.data.gold) == 500 and String(g.world.room.id) == "evercrown/heart", "the full flask's journey is taken up where it rested")
			GameState.data.gold = 777
		else:
			check(int(GameState.data.gold) == 0 and String(g.world.room.id) == "hearthroot/west_gate", "the empty flask begins anew (%d gold)" % int(GameState.data.gold))
			g.world.use_game_state = false
		# The ending carries the hero back to the title, saving on the way.
		GameState.begin_ending()
		await frames(2)
		g.ending.skip()
		g.ending.tick(EndingScreen.THANKS_GRACE)
		g.ending.advance()
		await frames(3)
		check(worlds.call() == 0 and g.world == null, "trip %d: back at the title, no world is left" % trip)
	# Each journey kept to its own flask.
	check(int(GameState.read_slot(8).get("gold", -1)) == 777, "the first journey saved to its own flask (%s)" % GameState.read_slot(8).get("gold", -1))
	check(GameState.read_slot(7).is_empty() and GameState.read_slot(9).is_empty(), "and spilled into no other")
	g.menu.close()
	g.queue_free()
	await frames(2)
	for s: int in SLOTS:
		GameState.delete_save(s)
	GameState.slot = was
	GameState.new_game()
	_restore()


## Pass 429: a journey taken up with the buttons. Pass 359 walked the title's
## real path through the flasks, but with `confirm()`; pass 397 tapped a bare
## shelf. No test had pressed the buttons from the title into a saved journey,
## so the press that takes a flask up was never seen reaching the world: Jump
## chooses the flask while the tree is paused, and if that press were read
## again by the hero's first step, a journey would begin with a jump. Here
## Jump on Journeys opens the shelf on the full flask, Jump held takes it up,
## and the hero wakes where they rested, standing, and does not jump until
## Jump is let go and pressed again.
func test_a_journey_is_taken_up_with_the_buttons() -> void:
	const SLOTS := [7, 8, 9]
	for s: int in SLOTS:
		GameState.delete_save(s)
	Settings.path = TEMP_SETTINGS
	var was := GameState.slot
	# Where a hero stands in the West Gate, to rest there.
	var w := make_world({}, "hearthroot/west_gate")
	await frames(30)
	var rest := w.player.global_position
	check(w.player.is_on_floor(), "the West Gate has footing to rest on")
	w.queue_free()
	await frames(2)
	GameState.new_game()
	GameState.data.save_room = "hearthroot/west_gate"
	GameState.data.save_pos = [rest.x, rest.y]
	GameState.data.gold = 500
	check(GameState.save_game(8), "a journey rests in the middle flask")
	GameState.new_game()
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.picker.slots = SLOTS
	check(g.menu.is_open and g.title_screen.visible, "the game opens on the title")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap("jump")
	check(g.picker.is_open and g.picker.cursor == 1, "Jump on Journeys opens the shelf on the full flask (%d)" % g.picker.cursor)
	await frames(int(SlotPicker.INPUT_GRACE * 60.0) + 2)
	Input.action_press("jump")
	var rose := false
	for i in 20:
		await frames(1)
		if g.world != null and g.player != null and g.player.velocity.y < -1.0:
			rose = true
	check(g.world != null and not g.picker.is_open and not arena.get_tree().paused, "Jump takes the journey up and play begins")
	check(GameState.slot == 8 and int(GameState.data.gold) == 500 and String(g.world.room.id) == "hearthroot/west_gate",
		"it is the middle flask's journey, where it rested (slot %d, %d gold)" % [GameState.slot, int(GameState.data.gold)])
	var p: Player = g.player
	check(not rose and p.is_on_floor() and p.global_position.distance_to(rest) < 2.0,
		"the hero wakes standing where they rested, and the press that chose the flask is no jump (%s)" % p.global_position)
	Input.action_release("jump")
	await frames(2)
	Input.action_press("jump")
	await frames(3)
	check(p.velocity.y < 0.0, "a fresh press jumps (%.0f)" % p.velocity.y)
	Input.action_release("jump")
	g.world.use_game_state = false
	g.queue_free()
	await frames(2)
	for s: int in SLOTS:
		GameState.delete_save(s)
	GameState.slot = was
	GameState.new_game()
	_restore()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_a_journey_is_taken_up_with_the_buttons`"), "bible 14 names the test")


## Pass 430 (bible 13.3): a menu closed by its button is heard as the menu,
## never as the hero. Pass 429 found the press that takes a journey up read a
## second time by the hero. The pause menu is closed by the same buttons the
## hero moves with: Jump or Attack on Resume, Dash or Block or Pause to back
## out. Each is tapped and held in play: the menu goes, its own sound plays,
## and the hero neither jumps, swings nor dashes (no jump, dash or slash heard,
## nothing moved) until the button is let go and pressed again.
func test_a_menu_closed_by_its_button_is_not_heard_as_the_hero() -> void:
	Settings.path = TEMP_SETTINGS
	GameState.new_game()
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.menu.close()
	g.title_screen.visible = false
	g._start("hearthroot/west_gate")
	g.world.use_game_state = false
	var p: Player = g.player
	p.abilities["stride"] = true
	await frames(30)
	var menu: ListMenu = g.menu
	for button: String in ["jump", "attack", "dash", "block", "pause"]:
		await _tap("pause")
		check(menu.is_open and menu.title == "Paused", "%s: Pause opens the menu" % button)
		await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
		var at := p.global_position
		Sfx.recent.clear()
		Input.action_press(button)
		var moved := false
		for i in 20:
			await frames(1)
			if p.velocity.length() > 1.0 or p.is_attacking or p.is_dashing:
				moved = true
		var heard := Sfx.recent.duplicate()
		Input.action_release(button)
		await frames(2)
		check(not menu.is_open and not arena.get_tree().paused, "%s closes the menu and play goes on" % button.capitalize())
		check(not moved and p.global_position.distance_to(at) < 1.0, "%s, held, is not read again by the hero (%s)" % [button.capitalize(), p.global_position - at])
		check(not heard.has("jump") and not heard.has("dash") and not heard.has("slash") and not heard.has("swing"),
			"and nothing of the hero is heard (%s)" % [heard])
		await frames(10)
	Input.action_press("jump")
	await frames(3)
	check(p.velocity.y < 0.0, "a fresh Jump in play jumps (%.0f)" % p.velocity.y)
	Input.action_release("jump")
	g.queue_free()
	await frames(2)
	GameState.new_game()
	_restore()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_a_menu_closed_by_its_button_is_not_heard_as_the_hero`"), "bible 13.3 names the test")

## Pass 437: the time played is time in play. GameState runs while the game is
## paused, and it counted every second: a pause menu left open overnight
## showed on the flask and at the ending as hours played. The real Pause
## opens the menu, and three seconds there leave the clock where it was; a
## sign read for three seconds does the same; three seconds of play count.
func test_the_time_played_stops_while_the_game_is_paused() -> void:
	Settings.path = TEMP_SETTINGS
	GameState.new_game()
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.menu.close()
	g.title_screen.visible = false
	g._start("hearthroot/west_gate")
	g.world.use_game_state = false
	await frames(30)
	var menu: ListMenu = g.menu
	await _tap("pause")
	check(menu.is_open and arena.get_tree().paused, "Pause opens the menu and the game holds")
	var t0 := GameState.play_time
	for i in 180:
		await runner.get_tree().process_frame
	check(is_equal_approx(GameState.play_time, t0), "three seconds in the pause menu add nothing to the time played (%.2f s)" % (GameState.play_time - t0))
	menu.close()
	await frames(2)
	GameState.say("", ["A long sign."])
	await frames(1)
	check(g.dialog.is_open and arena.get_tree().paused, "a sign holds the game")
	t0 = GameState.play_time
	for i in 180:
		await runner.get_tree().process_frame
	check(is_equal_approx(GameState.play_time, t0), "three seconds reading add nothing either (%.2f s)" % (GameState.play_time - t0))
	g.dialog.close()
	await frames(2)
	t0 = GameState.play_time
	await frames(180)
	var played := GameState.play_time - t0
	check(not arena.get_tree().paused and absf(played - 3.0) < 0.1, "three seconds of play count as three (%.2f s)" % played)
	g.queue_free()
	await frames(2)
	GameState.new_game()
	_restore()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_the_time_played_stops_while_the_game_is_paused`"), "the bible names the test")


## Pass 475: the time played counted game time, so at 70% Game speed three
## seconds of play showed as 2.1 on the flask and the ending's card, and a
## boss's slow motion all but stopped it. It is the player's time now.
func test_the_time_played_is_real_time_at_every_game_speed() -> void:
	for speed: float in Settings.SPEED_STEPS:
		Feel.set_game_speed(speed)
		await frames(2)
		var t0 := GameState.play_time
		await frames(180)
		var played := GameState.play_time - t0
		check(absf(played - 3.0) < 0.05, "at %d%% three seconds of play count as three (%.2f s)" % [roundi(speed * 100.0), played])
	Feel.set_game_speed(1.0)
	Feel.slowmo(0.3, 30.0)
	await frames(1)
	var t1 := GameState.play_time
	await frames(60)
	var slow := GameState.play_time - t1
	Feel.reset()
	check(absf(slow - 1.0) < 0.05, "a second of a boss's slow motion counts as a second (%.2f s)" % slow)
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_the_time_played_is_real_time_at_every_game_speed`"), "the bible names the test")


## Pass 439: a sign and the other screens, one at a time. Since pass 436 a
## sign pauses the game as the pause menu and the map do, so three screens
## now hold the same pause, and each lets it go as it closes. A press that
## reached two of them at once, or a screen opened over another, would leave
## the game paused with nothing open, or running under a screen still up.
## The whole game, a hero at the East Gate's tablet and the real buttons:
## Up and Pause pressed in the same frame open the sign alone; Map and Pause
## do nothing while it is open; put away, the game runs. Then the pause menu,
## with Up pressed at the tablet under it: no sign, and closed, the game runs.
## Presses Attack until the box is put away (the East Gate's tablet has two
## pages, each typed out before it turns).
func _put_away(box: DialogBox) -> void:
	for i in 12:
		if not box.is_open:
			return
		await _tap("attack")
		await frames(int(DialogBox.INPUT_GRACE * 60.0) + 1)


func test_a_sign_and_the_pause_menu_take_turns() -> void:
	Settings.path = TEMP_SETTINGS
	GameState.new_game()
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.menu.close()
	g.title_screen.visible = false
	g._start("hearthroot/east_gate")
	g.world.use_game_state = false
	var p: Player = g.player
	p.global_position = cell_feet(12, 19)
	p.velocity = Vector2.ZERO
	await frames(20)
	var menu: ListMenu = g.menu
	var tree := arena.get_tree()
	# Up alone reads the tablet; Map and Pause open nothing over it.
	await _tap("move_up")
	check(g.dialog.is_open and tree.paused, "Up reads the tablet and the game holds")
	await frames(int(DialogBox.INPUT_GRACE * 60.0) + 2)
	await _send_action("map")
	await _tap("pause")
	check(g.dialog.is_open and not menu.is_open and not g.map_screen.is_open and tree.paused, "while it is open, Map and Pause open nothing over it")
	await _put_away(g.dialog)
	check(not g.dialog.is_open and not menu.is_open and not tree.paused and not p.frozen, "put away, nothing is open and the game runs")
	await frames(10)
	# Up and Pause in one frame: one screen opens, and closing it leaves none.
	for when in ["after the step", "before the step"]:
		if when == "before the step":
			await runner.get_tree().process_frame
		Input.action_press("move_up")
		Input.action_press("pause")
		await frames(2)
		Input.action_release("move_up")
		Input.action_release("pause")
		await frames(1)
		check(g.dialog.is_open != menu.is_open and tree.paused, "%s: Up and Pause in one frame open one screen (sign %s, menu %s)" % [when, g.dialog.is_open, menu.is_open])
		await frames(int(ListMenu.INPUT_GRACE * 60.0) + 4)
		if menu.is_open:
			await _tap("pause")
		else:
			await _put_away(g.dialog)
		for i in 3:
			await runner.get_tree().process_frame
		await frames(5)
		check(not g.dialog.is_open and not menu.is_open and not tree.paused and not p.frozen, "%s: closed, nothing is open and the game runs" % when)
		await frames(10)
	await frames(10)
	await _tap("pause")
	check(menu.is_open and tree.paused, "Pause opens the menu")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	Input.action_press("move_up")
	await frames(3)
	Input.action_release("move_up")
	await frames(2)
	check(menu.is_open and not g.dialog.is_open, "Up at the tablet under the menu reads nothing")
	await _tap("pause")
	await frames(2)
	check(not menu.is_open and not g.dialog.is_open and not tree.paused, "Pause closes the menu, and the game runs with no sign up")
	await frames(10)
	check(not g.dialog.is_open and not tree.paused, "and none opens after it")
	g.queue_free()
	await frames(2)
	GameState.new_game()
	_restore()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_a_sign_and_the_pause_menu_take_turns`"), "the bible names the test")


## Pass 441: the Barkbalm by the buttons. The source game's Barkbalm is rubbed on
## from the menu and turns every blow aside for a while. It was only ever used
## by a call (`use_ointment`), never from the pause menu with the buttons, nor
## against a real blow. The whole game, a Rot Dwarf beside the hero: Pause,
## Down to "Use Barkbalm", Jump. The menu closes, the dwarf's blows land
## nothing for the Barkbalm's ten seconds, and the next after it lands.
func test_the_ointment_is_rubbed_on_with_the_buttons() -> void:
	Settings.path = TEMP_SETTINGS
	GameState.new_game()
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.menu.close()
	g.title_screen.visible = false
	g._start("hearthroot/west_gate")
	g.world.use_game_state = false
	var p: Player = g.player
	await frames(30)
	p.ointments = 1
	p.hp = 200
	p.max_hp = 200
	var menu: ListMenu = g.menu
	await _tap("pause")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap("move_down")
	check(menu.is_open and String(menu.rows[menu.cursor].label) == "Use Barkbalm", "Pause, then Down to Use Barkbalm (%s)" % menu.rows[menu.cursor].label)
	await _tap("jump")
	check(not menu.is_open and not arena.get_tree().paused and p.ointments == 0, "Jump rubs it on, and the menu closes")
	check(p.ointment_left > Player.OINTMENT_TIME - 0.1, "a full %d seconds of it, none spent in the menu (%.2f s left)" % [int(Player.OINTMENT_TIME), p.ointment_left])
	var dwarf := RotDwarf.new()
	dwarf.position = p.position + Vector2(p.facing * 48.0, 0)
	g.world.room.add_child(dwarf)
	var hp := p.hp
	var swings := 0
	var was := ""
	for i in roundi(Player.OINTMENT_TIME * 60.0) - 30:
		await frames(1)
		if dwarf.state == "swing" and was != "swing":
			swings += 1
		was = dwarf.state
	check(swings >= 2 and p.hp == hp, "the dwarf swings %d times while it lasts, and nothing lands (HP %d)" % [swings, p.hp])
	var hurt := false
	for i in 300:
		await frames(1)
		if p.hp < hp:
			hurt = true
			break
	check(p.ointment_left == 0.0 and hurt, "worn off, his next blow lands (HP %d)" % p.hp)
	g.queue_free()
	await frames(2)
	GameState.new_game()
	_restore()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_the_ointment_is_rubbed_on_with_the_buttons`"), "the bible names the test")


## Pass 460 (bible 3.1): the Boss Rush entered and left by the buttons. Every
## rush test began it with `BossRush.start` and left by a call. The whole game,
## in the Ringreader's temple with every guardian down: Up at the Ringreader, Down to Boss
## Rush, Jump, and the ring carries the hero into the first arena; then Pause,
## Down to "Leave the rush", Jump, and he is back by the Ringreader, the clock stopped,
## the guardian's music gone and no arena still fighting.
func test_the_boss_rush_is_entered_and_left_with_the_buttons() -> void:
	Settings.path = TEMP_SETTINGS
	GameState.new_game()
	GameState.set_flag("lord")
	for pair: Array in BossRush.ORDER:
		GameState.set_flag("boss:" + String(pair[0]))
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.menu.close()
	g.title_screen.visible = false
	g._start(Trials.TEMPLE)
	g.world.use_game_state = false
	var p: Player = g.player
	var menu: ListMenu = g.menu
	await frames(30)
	p.teleport(cell_feet(21, 19))
	await frames(10)
	var by_ringreader := p.global_position
	p.hp = 5
	await _tap("move_up")
	check(menu.is_open, "Up at the Ringreader opens his menu")
	# Taken once he has spoken: the first Ringreader's reading of the glass leaf sets a flag.
	var flags_before: Dictionary = GameState.data.flags.duplicate()
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	var downs := 0
	while String(menu.rows[menu.cursor].label) != "Boss Rush" and downs < 10:
		await _tap("move_down")
		downs += 1
	check(String(menu.rows[menu.cursor].label) == "Boss Rush", "Down finds Boss Rush (%d presses)" % downs)
	Sfx.recent.clear()
	await _tap("jump")
	check(BossRush.active() and not menu.is_open and Sfx.recent.has("trial_begin"), "Jump begins the rush (%s)" % [Sfx.recent])
	check(p.hp == p.max_hp, "whole")
	var first := String(BossRush.ORDER[0][1])
	var waited := 0
	while (g.world.room.id != first or g.world.busy) and waited < 240:
		await frames(1)
		waited += 1
	check(g.world.room.id == first, "and the ring carries him into the first arena (%s)" % g.world.room.id)
	await frames(20)
	Input.action_press("move_right")
	waited = 0
	while not BossArena.any_fighting(arena.get_tree()) and waited < 240:
		await frames(1)
		waited += 1
	Input.action_release("move_right")
	await frames(30)
	var fight_track := String(Music.track)
	check(BossArena.any_fighting(arena.get_tree()) and fight_track != "", "Right walks him in: the doors seal and the guardian's music plays (%s)" % fight_track)
	await _tap("pause")
	check(menu.is_open and arena.get_tree().paused, "Pause opens the menu in the arena")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	downs = 0
	while String(menu.rows[menu.cursor].label) != "Leave the rush" and downs < 12:
		await _tap("move_down")
		downs += 1
	check(String(menu.rows[menu.cursor].label) == "Leave the rush", "Down finds Leave the rush (%d presses)" % downs)
	await _tap("jump")
	waited = 0
	while (g.world.room.id != Trials.TEMPLE or g.world.busy) and waited < 240:
		await frames(1)
		waited += 1
	await frames(30)
	check(g.world.room.id == Trials.TEMPLE and p.global_position.distance_to(by_ringreader) < 24.0, "Jump takes him back by the Ringreader (%s, %.0f px)" % [g.world.room.id, p.global_position.distance_to(by_ringreader)])
	check(not BossRush.active() and not menu.is_open and not arena.get_tree().paused, "the rush is over and the game runs")
	check(not BossArena.any_fighting(arena.get_tree()), "no arena is still fighting")
	check(String(Music.track) != fight_track, "and the guardian's music is gone (%s)" % Music.track)
	check(GameState.data.flags == flags_before, "the world is as he left it")
	g.queue_free()
	await frames(2)
	GameState.new_game()
	_restore()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_the_boss_rush_is_entered_and_left_with_the_buttons`"), "the bible names the test")



## Pass 351 (bible 15.3, Sanitizing): a hand-edited save with a flag of
## "yes" stopped the title's flask with a script error, so a full flask read
## as empty and taking it up would have begun a new journey over the old one.
## Every map the game reads as yes-or-no keeps only true and false, and the
## flask's gold groups every three digits.
func test_a_hand_edited_save_still_fills_its_flask() -> void:
	const SLOT := 7
	GameState.delete_save(SLOT)
	var save := GameState.fresh()
	save.save_room = "heartwood/amberlee"
	save.rank = 3
	save.gold = 1234567
	save.flags = {"spring:heartwood": true, "spring:haar": "yes", "spring:sky": null, "secret:x": [1], "king_gold": 2}
	save.abilities["glove"] = "on"
	save.abilities["wings"] = {}
	save.charts = {"heartwood": true, "haar": "true"}
	save.collected = {"heartwood/amberlee:3,4": true, "heartwood/amberlee:5,6": null}
	save.visited = {"heartwood/amberlee": true, "haar/lampwick": 1}
	check(GameState.write_safely(GameState.SAVE_PATH % SLOT, JSON.stringify(save)), "the hand-edited save is written")
	var read := GameState.read_slot(SLOT)
	for map: String in GameState.BOOL_MAPS:
		for k: Variant in read[map]:
			check(read[map][k] is bool, "%s.%s is true or false (%s)" % [map, k, read[map][k]])
	check(read.flags == {"spring:heartwood": true}, "only the true flag stays (%s)" % [read.flags])
	check(read.abilities.glove == false and not read.abilities.has("wings"), "a damaged ability is lost, an unknown one dropped")
	check(read.charts == {"heartwood": true} and read.collected.size() == 1 and read.visited.size() == 1, "charts, pickups and rooms keep only true")
	var picker := SlotPicker.new()
	picker.slots = [SLOT]
	arena.add_child(picker)
	picker.open()
	check(not picker.saves[0].is_empty(), "the flask is full")
	var said := " / ".join(picker.details())
	check(said.contains("Amberlee") and said.contains("1,234,567 gold") and said.contains("One spring of three flows"), "and tells its journey (%s)" % said)
	var got := []
	picker.chosen.connect(func(slot: int, fresh: bool) -> void: got.append([slot, fresh]))
	picker.confirm()
	check(got == [[SLOT, false]], "taking it up continues it, never begins anew (%s)" % [got])
	for n: int in [0, 7, 999, 1000, 65536, 1000000, -2500]:
		check(SlotPicker.grouped(n) == {0: "0", 7: "7", 999: "999", 1000: "1,000", 65536: "65,536", 1000000: "1,000,000", -2500: "-2,500"}[n], "%d is written %s" % [n, SlotPicker.grouped(n)])
	picker.free()
	GameState.delete_save(SLOT)


## Pass 357 (bible 14, Accessibility): the options promise colorblind-safe
## marks, but the three flasks were told apart by color alone, and amber, pale
## green and pale blue are the colors a colorblind player confuses most. Each
## flask now bears its spring's mark (a leaf, mist, a bolt) on its glass, full
## or empty, and the marks differ in shape, not just in color.
func test_the_flasks_are_told_apart_by_shape() -> void:
	check(SlotPicker.MARKS.size() == SlotPicker.COLORS.size() and SlotPicker.MARKS.size() == 3, "three marks for three flasks")
	var seen := {}
	for i in 3:
		var lines := SlotPicker.mark(i)
		var count := 0
		var box := Rect2()
		for line: PackedVector2Array in lines:
			count += line.size()
			for q in line:
				box = Rect2(q, Vector2.ZERO) if box.size == Vector2.ZERO and box.position == Vector2.ZERO else box.expand(q)
		check(count >= 4, "flask %d (%s) has a mark drawn (%d points)" % [i, SlotPicker.MARKS[i], count])
		check(maxf(box.size.x, box.size.y) >= 12.0 and minf(box.size.x, box.size.y) >= 6.0 and box.size.x <= SlotPicker.BODY_R * 1.6 and box.size.y <= SlotPicker.BODY_R * 1.6,
			"and it fits the flask's body, big enough to read (%s)" % [box.size])
		var shape := "%d/%s" % [lines.size(), str(lines.map(func(l: PackedVector2Array) -> int: return l.size()))]
		check(not seen.has(shape), "flask %d's mark is its own shape (%s)" % [i, shape])
		seen[shape] = true
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("Told apart by shape as well as color") and bible.contains("a leaf for the Heartwood"), "bible 14 says how the flasks are told apart")


## Pass 350 (bible 13.3): the title's flasks borrowed the rest's chime, the
## rank's fanfare and the water's splash. Every cue the shelf plays, but the
## menu cursor's `blip`, must be its own: a file that exists, played by no
## other script.
func test_the_flasks_sound_like_flasks() -> void:
	var own := FileAccess.get_file_as_string("res://scripts/ui/slot_picker.gd")
	var plays := RegEx.create_from_string("Sfx\\.play\\(\"([a-z_]+)\"")
	var cues := {}
	for m: RegExMatch in plays.search_all(own):
		cues[m.get_string(1)] = true
	check(cues.has("flask_uncork") and cues.has("flask_pour"), "the shelf uncorks and pours (%s)" % [cues.keys()])
	var others := {}
	var dirs: Array[String] = ["res://scripts"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
		for f: String in DirAccess.get_files_at(d):
			if f.ends_with(".gd") and f != "slot_picker.gd":
				for m: RegExMatch in plays.search_all(FileAccess.get_file_as_string(d + "/" + f)):
					others[m.get_string(1)] = true
	for cue: String in cues:
		if cue == "blip":
			check(others.has("blip"), "moving between flasks keeps the menu cursor's blip")
			continue
		check(FileAccess.file_exists("res://assets/sfx/%s.wav" % cue), "%s has a file" % cue)
		check(not others.has(cue), "%s is the shelf's own, played nowhere else" % cue)


## Bible 12's UI list (pass 373): the minimap. A window in the HUD's top right
## shows the map around you at half scale: your room in the middle, a room you
## walked beside it, a charted room dimmed, nothing you have neither walked nor
## charted, nothing beyond the window, and a dot where you stand. It hides
## while the map, a menu or a dialog is open, and in a Trial.
func test_the_minimap_shows_the_map_around_you() -> void:
	var w := make_world({}, "tower/kettleforge")
	await frames(3)
	GameState.visit("tower/kettleforge_lift")
	var lay := Minimap.layout(w)
	var by := {}
	for r: Dictionary in lay.rooms:
		by[r.id] = r
	check(by.has("tower/kettleforge") and by["tower/kettleforge"].how == "here", "your room is on it")
	var here: Rect2 = by["tower/kettleforge"].rect if by.has("tower/kettleforge") else Rect2()
	check(here.get_center().is_equal_approx(Minimap.SIZE * 0.5), "in the middle of the window (%s)" % here)
	check(is_equal_approx(here.size.x, MapScreen.room_rect(w.catalog["tower/kettleforge"]).size.x * Minimap.SCALE), "at half the map's scale")
	check(by.has("tower/kettleforge_lift") and by["tower/kettleforge_lift"].how == "visited", "a room you walked beside it")
	check(not by.has("tower/mine_mouth"), "a room you never walked or charted is not")
	check(not by.has("hearthroot/plaza"), "nor is anything beyond the window")
	GameState.data.charts["tower"] = true
	lay = Minimap.layout(w)
	var charted: Array = lay.rooms.filter(func(r: Dictionary) -> bool: return r.id == "tower/mine_mouth")
	check(charted.size() == 1 and charted[0].how == "charted", "a charted room shows, dimmed")
	check(here.has_point(lay.player), "the dot stands in your room (%s)" % lay.player)
	var x0: float = lay.player.x
	w.player.global_position.x += 20 * Room.TILE
	check(Minimap.layout(w).player.x > x0, "and moves with you")
	var win := Minimap.window(Vector2(640, 360))
	check(win.end.x == 640 - Minimap.MARGIN and win.position.y == Minimap.MARGIN and win.size == Minimap.SIZE, "the window sits in the top right corner (%s)" % win)
	# What hides it: the map, a menu, a dialog beside the HUD, and a Trial.
	var layer := Node.new()
	arena.add_child(layer)
	var hud := GameHud.new()
	hud.player = w.player
	var map := MapScreen.new()
	var menu := ListMenu.new()
	var dialog := DialogBox.new()
	for n: Node in [hud, map, menu, dialog]:
		layer.add_child(n)
	await frames(1)
	check(Minimap.showing(hud), "it shows while you play")
	map.is_open = true
	check(not Minimap.showing(hud), "not under the full map")
	map.is_open = false
	menu.is_open = true
	check(not Minimap.showing(hud), "nor under a menu")
	menu.is_open = false
	dialog.is_open = true
	check(not Minimap.showing(hud), "nor under a dialog")
	dialog.is_open = false
	Trials.run = {"id": "edges", "time": 0.0}
	check(not Minimap.showing(hud), "nor in a Trial, whose clock holds the top")
	Trials.run = {}
	check(Minimap.showing(hud), "and comes back after")
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("**The minimap (pass 373):**"), "bible 12 says how it is built")
	layer.queue_free()
	w.queue_free()
	await frames(2)


## Pass 389 (bible 14): the architecture section was the plan's. It named five
## autoloads that were never built (SaveSystem, EventBus, AudioDirector,
## InputRouter, RoomManager), a `scenes/` folder per player, foe, boss, room and
## screen, `.tres` resources, a `room_loader.gd`, YAML headers, a world graph
## file and GUT tests, and no test read it. Every path section 14 names must now
## exist, its autoloads must be the project's own, and its renderer line must
## be the project's.
func test_the_bibles_architecture_is_as_built() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var sec := bible.get_slice("## 14. Technical Architecture", 1).get_slice("\n## 15. ", 0)
	check(sec != "", "the bible has section 14")
	var re := RegEx.create_from_string("`([^`\\s]+/[^`\\s]*)`")
	var named := 0
	for m: RegExMatch in re.search_all(sec):
		var path := m.get_string(1)
		if path.begins_with("user://") or path.begins_with("/mnt/"):
			continue
		named += 1
		var at := "res://" + path.replace("<zone>", "hearthroot").replace("<room>", "west_gate")
		check(FileAccess.file_exists(at) or DirAccess.dir_exists_absolute(at.trim_suffix("/")), "section 14 names %s, and it exists" % path)
	check(named >= 25, "section 14 names the project's paths (%d)" % named)
	var autoloads: Array[String] = []
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key := String(prop.name)
		if key.begins_with("autoload/"):
			autoloads.append(key.trim_prefix("autoload/"))
	var line := sec.get_slice("  - `scripts/autoload/`:", 1).get_slice("\n", 0)
	check(line.contains("%s autoloads" % ["zero", "one", "two", "three", "four", "five", "six", "seven"][autoloads.size()]), "14 counts the project's %d autoloads" % autoloads.size())
	for a: String in autoloads:
		check(line.contains("`%s`" % a), "14 names the autoload %s" % a)
	for gone: String in ["SaveSystem", "EventBus", "AudioDirector", "InputRouter", "RoomManager"]:
		check(not autoloads.has(gone) and not line.contains(gone), "%s, the plan's, is neither built nor listed as built" % gone)
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus" and sec.contains("the project's default, Forward+"), "the renderer is Forward+, as 14 says")
	check(FileAccess.get_file_as_string("res://tools/screenshot.sh").contains("--rendering-driver opengl3"), "and the screenshots draw on the Compatibility renderer")
	check(sec.contains("`tests/test_runner.gd`") and not DirAccess.dir_exists_absolute("res://addons/gut"), "the tests run on the project's own runner, not GUT")


## Pass 397: the menus, driven by the real controller. A ListMenu and the
## save flasks read their buttons in _process (`Input.is_action_just_pressed`),
## and every menu test called move, adjust, confirm and back directly, so a
## menu that read the wrong action, or never read one, passed. This presses the
## buttons through `Input` itself.
func _tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(2)


func test_the_menus_answer_the_real_controller() -> void:
	var menu := ListMenu.new()
	arena.add_child(menu)
	var chose: Array[int] = []
	var nudged: Array[int] = []
	menu.open("TEST", "", func() -> Array: return [{"label": "one"}, {"label": "two"}, {"label": "three"}], func(i: int) -> void: chose.append(i))
	menu.on_adjust = func(_i: int, step: int) -> void: nudged.append(step)
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap("move_down")
	check(menu.cursor == 1, "Down moves the cursor down a row (%d)" % menu.cursor)
	await _tap("move_up")
	await _tap("move_up")
	check(menu.cursor == 2, "Up moves it up, and wraps past the top (%d)" % menu.cursor)
	await _tap("move_right")
	await _tap("move_left")
	check(nudged == [1, -1], "Right and Left change the row's value (%s)" % [nudged])
	await _tap("jump")
	await _tap("attack")
	check(chose == [2, 2], "Jump and Attack each choose the row (%s)" % [chose])
	await _tap("dash")
	check(not menu.is_open and not arena.get_tree().paused, "Dash backs out and the game runs again")
	for action: String in ["block", "pause"]:
		menu.open("TEST", "", func() -> Array: return [{"label": "one"}], func(_i: int) -> void: pass)
		await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
		await _tap(action)
		check(not menu.is_open, "%s backs out too" % action.capitalize())
	menu.free()
	# The three flasks: Left and Right walk the shelf, Jump takes one up, Dash puts it back.
	for slot: int in [97, 98, 99]:
		GameState.delete_save(slot)
	var picker := SlotPicker.new()
	picker.slots = [97, 98, 99]
	arena.add_child(picker)
	var taken: Array = []
	picker.chosen.connect(func(slot: int, fresh: bool) -> void: taken.append([slot, fresh]))
	var gone := [false]
	picker.cancelled.connect(func() -> void: gone[0] = true)
	picker.open()
	check(picker.cursor == 0, "an empty shelf opens on the first flask")
	await frames(int(SlotPicker.INPUT_GRACE * 60.0) + 2)
	await _tap("move_right")
	await _tap("move_right")
	check(picker.cursor == 2, "Right walks the shelf (%d)" % picker.cursor)
	await _tap("move_left")
	check(picker.cursor == 1, "Left walks it back (%d)" % picker.cursor)
	await _tap("jump")
	check(taken == [[98, true]] and not picker.is_open, "Jump uncorks the focused empty flask for a new journey (%s)" % [taken])
	picker.open()
	await frames(int(SlotPicker.INPUT_GRACE * 60.0) + 2)
	await _tap("dash")
	check(gone[0] and not picker.is_open, "Dash puts the shelf away")
	picker.free()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_the_menus_answer_the_real_controller`"), "bible 14 names the test")


## Pass 421: the pause menu by the buttons. Pass 397 drove a bare ListMenu
## with real taps and pass 413 a shop, but no test had pressed Pause in play:
## the game's own `_check_pause` and the pause menu's rows were only reached by
## calling `Menus.open_pause`. Here the whole game runs, Pause opens the menu
## over a frozen world, Down and Jump rub on an Barkbalm from it (bible 10.2,
## "rubbed on from the pause menu"), a second Pause finds that row refused
## while one is on, and Dash backs out to play.
func test_the_pause_menu_answers_the_real_controller() -> void:
	Settings.path = TEMP_SETTINGS
	GameState.new_game()
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.menu.close()
	g.title_screen.visible = false
	g._start("hearthroot/west_gate")
	g.world.use_game_state = false
	await frames(5)
	var p: Player = g.player
	p.ointments = 1
	var menu: ListMenu = g.menu
	check(not menu.is_open and not arena.get_tree().paused, "playing, with no menu up")
	await _tap("pause")
	check(menu.is_open and menu.title == "Paused" and arena.get_tree().paused, "Pause opens the pause menu over a frozen world")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	check(menu.cursor == 0, "on Resume")
	await _tap("move_down")
	check(String(menu.rows[menu.cursor].label) == "Use Barkbalm", "Down to Use Barkbalm (%s)" % menu.rows[menu.cursor].label)
	Sfx.recent.clear()
	await _tap("jump")
	check(p.ointments == 0 and p.ointment_left > Player.OINTMENT_TIME - 1.0, "Jump rubs it on: none left, %d s of safety" % int(Player.OINTMENT_TIME))
	check(Sfx.recent.has("heal") and not menu.is_open and not arena.get_tree().paused, "with its shimmer, and play goes on (%s)" % [Sfx.recent])
	await frames(5)
	await _tap("pause")
	check(menu.is_open, "Pause opens it again")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap("move_down")
	Sfx.recent.clear()
	await _tap("jump")
	check(menu.is_open and Sfx.recent == (["menu_refuse"] as Array[String]), "with one already on, Jump on the row says no (%s)" % [Sfx.recent])
	await _tap("dash")
	check(not menu.is_open and not arena.get_tree().paused, "Dash backs out and the game runs on")
	g.queue_free()
	await frames(2)
	GameState.new_game()
	_restore()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("The pause menu by the buttons (pass 421)"), "the bible says so")


## Pass 467: Options by the buttons, kept through a restart. Pass 421 pressed
## Pause in play, but the Options and Controls pages were only reached with
## `confirm()` and `adjust()`, and no test changed an option with the buttons,
## quit, and started the game again. Here the whole game runs: Pause, Down to
## Options, Jump; Right turns the shake up, Jump on the mercy row turns it on,
## Left three times lowers the sound; Dash back, Down to Controls, Jump on Map,
## and a real key press (N) rebinds it. Then the game is quit and a new one
## starts from the file alone, with every value and the key back.
func test_options_are_changed_with_the_buttons_and_kept_through_a_restart() -> void:
	Settings.path = TEMP_SETTINGS
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SETTINGS + suffix))
	GameState.new_game()
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.menu.close()
	g.title_screen.visible = false
	g._start("hearthroot/west_gate")
	g.world.use_game_state = false
	await frames(5)
	var menu: ListMenu = g.menu
	await _tap("pause")
	check(menu.is_open and menu.title == "Paused", "Pause opens the pause menu")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	for i in 4:
		await _tap("move_down")
	check(String(menu.rows[menu.cursor].label) == "Options", "Down four times to Options (%s)" % menu.rows[menu.cursor].label)
	await _tap("jump")
	check(menu.title == "Options" and menu.cursor == 0, "Jump opens Options on Screen shake")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap("move_right")
	check(Settings.shake == 1 and Feel.shake_scale == Settings.SHAKE_STEPS[1], "Right turns the shake one step and applies it (%s)" % Feel.shake_scale)
	for i in 4:
		await _tap("move_down")
	check(String(menu.rows[menu.cursor].label) == "Assist: mercy", "Down to the mercy assist (%s)" % menu.rows[menu.cursor].label)
	await _tap("jump")
	check(Settings.mercy and menu.title == "Options", "Jump turns mercy on, and Options stays up")
	await _tap("move_down")
	await _tap("move_down")
	check(String(menu.rows[menu.cursor].label) == "Sound volume", "Down to Sound volume (%s)" % menu.rows[menu.cursor].label)
	for i in 3:
		await _tap("move_left")
	check(Settings.sound_volume == 5, "Left three times lowers the sound to 5 (%d)" % Settings.sound_volume)
	await _tap("dash")
	check(menu.title == "Paused" and String(menu.rows[menu.cursor].label) == "Options", "Dash goes back to the pause menu, on Options, not Resume (%d)" % menu.cursor)
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap("move_down")
	await _tap("jump")
	check(menu.title == "Controls", "Down and Jump open Controls")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	var map_row := Settings.REBINDABLE.find("map")
	for i in map_row:
		await _tap("move_down")
	check(menu.cursor == map_row, "Down to the Map row (%d)" % menu.cursor)
	await _tap("jump")
	check(menu.capture.is_valid(), "Jump waits for the new key")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_N
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await frames(1)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await frames(2)
	check(not menu.capture.is_valid() and Settings.keys.get("map", 0) == KEY_N, "N is pressed, and Map is on N (%s)" % [Settings.keys])
	check(String(menu.rows[map_row].right).begins_with(Controls.key_name("map")) and Controls.key_name("map") == "N", "the row shows N (%s)" % menu.rows[map_row].right)
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap("dash")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap("dash")
	check(not menu.is_open and not arena.get_tree().paused, "Dash twice and the game runs on")
	# Quit. Nothing but the file carries over: the options go back to their
	# defaults in memory before the next game starts and reads it.
	g.queue_free()
	await frames(2)
	Settings.reset()
	Settings.apply()
	check(Settings.shake == 0 and not Settings.mercy and Controls.key_name("map") != "N", "quit: the options in memory are the defaults")
	GameState.new_game()
	var again: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(again)
	await frames(2)
	check(Settings.shake == 1 and Feel.shake_scale == Settings.SHAKE_STEPS[1], "started again: the shake is still one step up")
	check(Settings.mercy and Settings.sound_volume == 5, "mercy is still on and the sound still at 5")
	var bus := AudioServer.get_bus_index("Sfx")
	check(bus >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(bus), (5 - Settings.VOLUME_MAX) * 3.0), "and the sound bus is set from it (%.1f dB)" % AudioServer.get_bus_volume_db(bus))
	check(Controls.key_name("map") == "N", "and Map is still on N")
	# The title's Options backs out onto Options too, not onto Journeys.
	var title: ListMenu = again.menu
	check(title.is_open and title.cursor == 0, "the title menu is up, on Journeys")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap("move_down")
	await _tap("jump")
	check(title.title == "Options", "Down and Jump open Options from the title")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap("dash")
	check(title.is_open and String(title.rows[title.cursor].label) == "Options", "Dash goes back to the title, on Options (%d)" % title.cursor)
	title.close()
	again.queue_free()
	await frames(2)
	GameState.new_game()
	_restore()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("Options by the buttons, kept through a restart (pass 467)"), "the bible says so")

## Pass 398: each press of the real controller in a menu is heard as the
## bible says (13.3): the cursor blips, a value blips, a row you can't choose
## says no, backing out is quiet; on the shelf of flasks a step blips, Block
## asks with a blip, Jump pours one out or uncorks one.
func test_every_press_in_a_menu_is_heard() -> void:
	var menu := ListMenu.new()
	arena.add_child(menu)
	menu.open("TEST", "", func() -> Array: return [{"label": "one"}, {"label": "two", "enabled": false}], func(_i: int) -> void: pass)
	menu.on_adjust = func(_i: int, _step: int) -> void: pass
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	var heard := func(action: String) -> Array[String]:
		Sfx.recent.clear()
		await _tap(action)
		return Sfx.recent.duplicate()
	for action: String in ["move_down", "move_up"]:
		var got: Array[String] = await heard.call(action)
		check(got == ["blip"], "%s moves the cursor with a blip (%s)" % [action, got])
	for action: String in ["move_right", "move_left"]:
		var got: Array[String] = await heard.call(action)
		check(got == ["blip"], "%s changes a value with a blip (%s)" % [action, got])
	await _tap("move_down")
	for action: String in ["jump", "attack"]:
		var got: Array[String] = await heard.call(action)
		check(got == ["menu_refuse"], "%s on a row you can't choose says no (%s)" % [action, got])
	var right: Array[String] = await heard.call("move_right")
	check(right.is_empty(), "a row you can't choose has no value to change, and is quiet (%s)" % [right])
	var left: Array[String] = await heard.call("dash")
	check(left.is_empty() and not menu.is_open, "backing out is quiet (%s)" % [left])
	menu.free()
	# The shelf: one full flask and two empty ones.
	for slot: int in [97, 98, 99]:
		GameState.delete_save(slot)
	var was := GameState.slot
	GameState.new_game()
	GameState.data.save_room = "heartwood/amberlee"
	check(GameState.save_game(97), "a journey rests in the first flask")
	GameState.new_game()
	GameState.slot = was
	var picker := SlotPicker.new()
	picker.slots = [97, 98, 99]
	arena.add_child(picker)
	picker.open()
	picker.cursor = 0
	await frames(int(SlotPicker.INPUT_GRACE * 60.0) + 2)
	for action: String in ["move_right", "move_left"]:
		var got: Array[String] = await heard.call(action)
		check(got == ["blip"], "%s steps along the shelf with a blip (%s)" % [action, got])
	var ask: Array[String] = await heard.call("block")
	check(ask == ["blip"] and picker.pouring, "Block on a full flask asks with a blip (%s)" % [ask])
	var keep: Array[String] = await heard.call("dash")
	check(keep.is_empty() and not picker.pouring and GameState.has_save(97), "Dash keeps it, quietly (%s)" % [keep])
	await _tap("block")
	var pour: Array[String] = await heard.call("jump")
	check(pour == ["flask_pour"] and not GameState.has_save(97), "Jump pours it out, glugging (%s)" % [pour])
	var none: Array[String] = await heard.call("block")
	check(none.is_empty() and not picker.pouring, "an empty flask has nothing to pour, and is quiet (%s)" % [none])
	var uncork: Array[String] = await heard.call("jump")
	check(uncork == ["flask_uncork"] and not picker.is_open, "Jump uncorks an empty flask for a new journey (%s)" % [uncork])
	picker.free()
	for slot: int in [97, 98, 99]:
		GameState.delete_save(slot)
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_every_press_in_a_menu_is_heard`"), "bible 13.3 names the test")


func _send_action(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await frames(1)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await frames(1)


## Pass 405 (bible 3.3, 14): the map by the real buttons. The map reads its
## buttons as input events (`_unhandled_input`), and every map test called
## `toggle` and `pin` straight, so the buttons a player presses (Map to open
## and close, Jump to pin, Pause to close) were never sent. Each goes through
## the engine's input here as an action event.
func test_the_map_answers_its_buttons() -> void:
	var w := make_world({}, "hearthroot/market")
	await frames(2)
	var map := MapScreen.new()
	map.world = w
	arena.add_child(map)
	await frames(1)
	Sfx.recent.clear()
	await _send_action("map")
	check(map.is_open and arena.get_tree().paused and Sfx.recent.has("map_open"), "Map opens it, pausing the game, with a rustle (%s)" % [Sfx.recent])
	await _send_action("jump")
	check(GameState.data.pins.size() == 1 and String(GameState.data.pins[0][0]) == "hearthroot/market", "Jump drops a pin where you stand (%s)" % [GameState.data.pins])
	await _send_action("jump")
	check(GameState.data.pins.is_empty(), "and Jump again lifts it")
	await _send_action("map")
	check(not map.is_open and not arena.get_tree().paused and Sfx.recent.has("map_close"), "Map closes it and the game runs on (%s)" % [Sfx.recent])
	await _send_action("jump")
	check(GameState.data.pins.is_empty(), "with the map shut, Jump drops no pin")
	await _send_action("map")
	await _send_action("pause")
	check(not map.is_open and not arena.get_tree().paused, "Pause closes it too")
	# A dead or frozen hero cannot open it.
	w.player.frozen = true
	await _send_action("map")
	check(not map.is_open and not arena.get_tree().paused, "a frozen hero cannot open it")
	w.player.frozen = false
	map.free()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n## 14. ", 1).get_slice("\n## 15. ", 0)
	check(note.contains("`test_the_map_answers_its_buttons`"), "bible 14 names the test")


## Pass 406 (bible 13.3): rests and pins, heard through the buttons. The shrine's
## save chime was only heard by the "every sound" gate, never by a test of its
## own, and the map's pin sounds (`pin`, `pin_lift`, and `menu_refuse` when the
## map holds all it can) were never listened for. Up at a shrine and Jump on the
## open map are pressed here with the real controller, and each is heard.
func test_rests_and_pins_are_heard_through_the_buttons() -> void:
	var was := GameState.slot
	GameState.slot = 9
	var w := make_world({}, "hearthroot/market")
	var p := w.player
	p.input = PlayerInput.new()
	await frames(3)
	var shrine := SaveShrine.new()
	w.room.add_child(shrine)
	shrine.global_position = p.global_position
	await frames(2)
	p.hp = 1
	Sfx.recent.clear()
	Input.action_press("move_up")
	await frames(3)
	Input.action_release("move_up")
	await frames(1)
	check(p.hp == p.max_hp and GameState.has_save(9), "Up at a shrine rests and saves")
	check(Sfx.recent.count("save") == 1, "with the save chime, once (%s)" % [Sfx.recent])
	shrine.free()
	GameState.delete_save(9)
	GameState.slot = was
	var map := MapScreen.new()
	map.world = w
	arena.add_child(map)
	await frames(1)
	await _send_action("map")
	Sfx.recent.clear()
	await _send_action("jump")
	check(Sfx.recent == (["pin"] as Array[String]), "Jump on the map drops a pin with a tap (%s)" % [Sfx.recent])
	Sfx.recent.clear()
	await _send_action("jump")
	check(Sfx.recent == (["pin_lift"] as Array[String]), "and Jump again lifts it with its own sound (%s)" % [Sfx.recent])
	for i in GameState.MAX_PINS:
		GameState.data.pins.append(["hearthroot/gate", 8 + i * 40, 8])
	Sfx.recent.clear()
	await _send_action("jump")
	check(GameState.data.pins.size() == GameState.MAX_PINS and Sfx.recent == (["menu_refuse"] as Array[String]), "a full map refuses one more pin, and says so (%s)" % [Sfx.recent])
	GameState.data.pins.clear()
	await _send_action("map")
	map.free()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n## 13. ", 1).get_slice("\n## 14. ", 0)
	check(note.contains("`test_rests_and_pins_are_heard_through_the_buttons`"), "bible 13 names the test")


## Pass 445 (bible 5.2): the off hand changed on the Equipment page, by the
## buttons, mid-guard. Sean's off-hand rule (a shield or the Rune Dagger, and the
## Broad Sword takes both hands) was only ever swapped by a script. Here Block is
## held the whole time while the real controller walks the pause menu to the
## Equipment page and back: the Broad Sword put in hand drops the guard though
## Block is still held, and the Short Sword back in hand raises it again, the
## held button guarding as it always does, with no fresh press and so no parry.
func test_the_equipment_page_changes_hands_mid_guard() -> void:
	Settings.path = TEMP_SETTINGS
	GameState.new_game()
	GameState.data.gear.append_array(["small_shield", "dwarvish_broad_sword"])
	GameState.data.equipment.shield = "small_shield"
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.menu.close()
	g.title_screen.visible = false
	g._start("hearthroot/west_gate")
	g.world.use_game_state = false
	var p: Player = g.player
	await frames(30)
	GameState.refresh_stats(p)
	var menu: ListMenu = g.menu
	var wear := func(id: String) -> bool:
		await _tap("pause")
		await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
		for i in 8:
			if String(menu.rows[menu.cursor].label) == "Equipment":
				break
			await _tap("move_down")
		await _tap("jump")
		await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
		for i in 20:
			if String(menu.rows[menu.cursor].get("id", "")) == id:
				break
			await _tap("move_down")
		var on := String(menu.rows[menu.cursor].get("id", "")) == id
		await _tap("jump")
		for i in 4:
			if not menu.is_open:
				break
			await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
			await _tap("pause")
		await frames(3)
		return on and not menu.is_open and not arena.get_tree().paused
	Input.action_press("block")
	await frames(3)
	check(p.is_blocking, "Block held raises the Buckler")
	var went: bool = await wear.call("dwarvish_broad_sword")
	check(went and GameState.data.equipment.blade == "dwarvish_broad_sword", "the buttons put the Broad Sword in hand (%s)" % GameState.data.equipment.blade)
	check(not p.has_shield and not p.is_blocking, "two hands on the hilt, the guard is down though Block is still held")
	went = await wear.call("short_sword")
	check(went and GameState.data.equipment.blade == "short_sword" and p.has_shield, "the Short Sword back in hand, the shield comes back to the arm")
	check(p.is_blocking and p._parry_timer <= 0.0, "and the held Block guards at once, with no parry window (%.2f s)" % p._parry_timer)
	Input.action_release("block")
	await frames(2)
	check(not p.is_blocking, "let go, the guard drops")
	g.queue_free()
	await frames(2)
	GameState.new_game()
	_restore()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_the_equipment_page_changes_hands_mid_guard`"), "the bible names the test")


## Pass 447 (bible 5.2): the off hand changed while the Rune Dagger is in the
## air. Sean's rule puts a shield or the dagger in the off hand; a player can
## throw, open the pause menu before it lands, and strap on a shield. Through
## the real controller: the dagger in flight is left to finish its flight and
## come home, the shield then guards and Throw does nothing, and the dagger put
## back in the off hand throws again. Nothing is left behind or doubled.
func test_the_off_hand_changes_while_the_dagger_flies() -> void:
	Settings.path = TEMP_SETTINGS
	GameState.new_game()
	GameState.data.gear.append("small_shield")
	GameState.data.abilities["rune_dagger"] = true
	var g: Node2D = load("res://scripts/game.gd").new()
	arena.add_child(g)
	await frames(2)
	g.menu.close()
	g.title_screen.visible = false
	g._start("hearthroot/west_gate")
	g.world.use_game_state = false
	var p: Player = g.player
	p.abilities["rune_dagger"] = true
	await frames(30)
	GameState.refresh_stats(p)
	var menu: ListMenu = g.menu
	var wear := func(id: String) -> bool:
		await _tap("pause")
		await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
		for i in 8:
			if String(menu.rows[menu.cursor].label) == "Equipment":
				break
			await _tap("move_down")
		await _tap("jump")
		await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
		for i in 20:
			if String(menu.rows[menu.cursor].get("id", "")) == id:
				break
			await _tap("move_down")
		var on := String(menu.rows[menu.cursor].get("id", "")) == id
		await _tap("jump")
		for i in 4:
			if not menu.is_open:
				break
			await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
			await _tap("pause")
		await frames(1)
		return on and not menu.is_open and not arena.get_tree().paused
	var daggers := func() -> int:
		return g.world.room.get_children().filter(func(n: Node) -> bool: return n is RuneDagger).size()
	check(GameState.offhand_free() and not p.has_shield, "the off hand is free for the dagger")
	await _tap("throw")
	var flying: RuneDagger = p.rune_dagger
	check(is_instance_valid(flying) and daggers.call() == 1, "Throw lets it fly")
	var put_on: bool = await wear.call("small_shield")
	check(put_on and p.has_shield and not GameState.offhand_free(), "with it still in the air, the buttons strap the Buckler on")
	check(is_instance_valid(flying) and daggers.call() == 1, "the dagger is still in flight, alone (%d)" % daggers.call())
	for i in 90:
		await frames(1)
		if p.dagger_ready():
			break
	check(not is_instance_valid(flying) and daggers.call() == 0 and p.dagger_ready(), "it ends its flight and comes home")
	await _tap("throw")
	await frames(2)
	check(daggers.call() == 0 and p.dagger_ready(), "with the shield on the arm Throw does nothing")
	Input.action_press("block")
	await frames(3)
	check(p.is_blocking, "and Block guards")
	Input.action_release("block")
	await frames(2)
	var back: bool = await wear.call(Menus.OFFHAND_DAGGER)
	check(back and GameState.offhand_free() and not p.has_shield, "the dagger back in the off hand, the shield comes off")
	await _tap("throw")
	check(daggers.call() == 1, "and Throw lets it fly again")
	await frames(60)
	g.queue_free()
	await frames(2)
	GameState.new_game()
	_restore()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_the_off_hand_changes_while_the_dagger_flies`"), "the bible names the test")


## A save from before pass 462 spoke the old ids (design bible 14): loading it
## renames every room, zone, item, ability, boss and flag id, the card keys and
## the seeds, so the journey goes on where it was.
func test_an_old_save_comes_over_to_the_new_ids() -> void:
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/rename_map.json"))
	var old: Dictionary = map.ids.example_save
	check(old.save_room != "heartwood/spring_of_heartwood", "the example is an old save")
	var d := GameState.sanitize(old)
	check(d.save_room == "heartwood/spring_of_heartwood", "the save room is the new room (%s)" % d.save_room)
	check(bool(d.abilities.delvers_pick) and bool(d.abilities.torrent) and bool(d.abilities.wisplight) and bool(d.abilities.seers_lens) \
		and bool(d.abilities.stillstone) and bool(d.abilities.severance) and bool(d.abilities.briar_wand), "every ability under its new id (%s)" % [d.abilities])
	for k: String in old.abilities:
		check(not d.abilities.has(k) or k == "glove", "%s is not left under its old id" % k)
	check(d.spell == "wisplight" and d.equipment.blade == "severance" and d.equipment.armor == "riveted_coat" and d.equipment.helmet == "elven_helm", "the gear worn (%s, %s)" % [d.spell, d.equipment])
	check(d.keys == {"copper": 1, "gold": 2, "glass": 1, "sky": true}, "the card keys are the metal keys (%s)" % [d.keys])
	check(d.rings == ["thaw", "sun", "fall", "frost"], "the four seeds (%s)" % [d.rings])
	check(bool(d.flags.get("boss:thane_vorrund")) and bool(d.flags.get("boss:durgan")) and bool(d.flags.get("spring:haar")) and bool(d.flags.get("heartwood_restored")), "the flags (%s)" % [d.flags])
	check(d.collected.has("vorrhallow/drowned_nave:31,6") and d.visited.has("hearthroot/plaza") and d.visited.has("spires/sky_spring"), "the rooms taken from and seen")
	check(d.ringreaders.has("tower/kettleforge"), "the Ringreaders met (%s)" % [d.ringreaders])
	check(int(d.grain_shards) == 2 and bool(d.charts.get("boughs", false)), "the shards and charts")
	check(int(d.version) == GameState.VERSION, "and the save is brought up to this version")
	var again := GameState.sanitize(d)
	check(again == d, "a save with the new ids comes back as it is")
	for room: String in [d.save_room, "tower/kettleforge", "vorrhallow/drowned_nave"] + d.visited.keys():
		check(World.room_exists(room), "%s is a room in this build" % room)


## Pass 461: the game was renamed, and Godot keeps saves in a folder named for
## the game, so the first start under the new name copies the saves and the
## settings over from the old folder (named in data/rename_map.json). It never
## overwrites a file the new folder has, and copies nothing else.
func test_old_saves_come_over_to_the_new_name() -> void:
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/rename_map.json"))
	var root := OS.get_user_data_dir().path_join("rename_test")
	var new_dir := root.path_join("Yldenfall")
	var old_dir := root.path_join(String(map.user_dir_before))
	DirAccess.make_dir_recursive_absolute(new_dir)
	DirAccess.make_dir_recursive_absolute(old_dir)
	for f: String in ["save_1.json", "save_2.json", "settings.cfg", "notes.txt"]:
		var w := FileAccess.open(old_dir.path_join(f), FileAccess.WRITE)
		w.store_string("old " + f)
		w.close()
	var keep := FileAccess.open(new_dir.path_join("save_2.json"), FileAccess.WRITE)
	keep.store_string("new save_2.json")
	keep.close()
	check(GameState.bring_old_saves(new_dir) == 2, "two files come over: save_1 and the settings")
	check(FileAccess.get_file_as_string(new_dir.path_join("save_1.json")) == "old save_1.json", "the old save is copied whole")
	check(FileAccess.get_file_as_string(new_dir.path_join("save_2.json")) == "new save_2.json", "a save the new folder has is kept")
	check(not FileAccess.file_exists(new_dir.path_join("notes.txt")), "and nothing but saves and settings comes over")
	check(GameState.bring_old_saves(new_dir) == 0, "a second start copies nothing")
	check(GameState.bring_old_saves(root.path_join("nowhere").path_join("Yldenfall")) == 0, "with no old folder, nothing happens")
	for d: String in [new_dir, old_dir]:
		for f: String in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d.path_join(f))
		DirAccess.remove_absolute(d)
	DirAccess.remove_absolute(root)


## Pass 476: the music's fades, ducks and phase lifts were tweens on game time,
## so at 70% Game speed a 1.2 s fade took 1.7 s, a boss's slow motion (30%)
## stretched the fade after its death blow to four, and hitstop stalled them.
func test_the_music_moves_in_real_time_at_every_game_speed() -> void:
	for speed: float in [0.7, 0.3]:
		Feel.set_game_speed(speed)
		Music.play("hearthroot", 1.0)
		await frames(64)
		var p: AudioStreamPlayer = Music._players[Music._active]
		check(absf(p.volume_db - Music.MUSIC_DB) < 0.01, "at %d%% a 1 s fade in is whole after 1 s (%.1f dB)" % [roundi(speed * 100.0), p.volume_db])
		Music.intensify(1)
		await frames(roundi(Music.PHASE_SHIFT_TIME * 60.0) + 4)
		check(is_equal_approx(p.pitch_scale, Music.pitch_for(1)), "at %d%% the phase lift is whole in %.1f s (%.3f)" % [roundi(speed * 100.0), Music.PHASE_SHIFT_TIME, p.pitch_scale])
		Music.play("", 0.0)
		Music.intensity = 0
		await frames(2)
	Feel.set_game_speed(1.0)
	Music.play("hearthroot", 0.5)
	Engine.time_scale = 0.0
	await frames(36)
	Engine.time_scale = 1.0
	var q: AudioStreamPlayer = Music._players[Music._active]
	check(absf(q.volume_db - Music.MUSIC_DB) < 0.01, "hitstop does not stall a fade (%.1f dB)" % q.volume_db)
	Music.play("", 0.0)
	await frames(2)
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_the_music_moves_in_real_time_at_every_game_speed`"), "the bible names the test")


## Words and menus are read in real time (pass 483): the Game speed option,
## a boss's slow motion and hitstop slow the game, never the text typing out,
## a menu's input grace or the ending's cards.
func test_the_screens_run_in_real_time_at_every_game_speed() -> void:
	var line := "The roots remember every hand that ever tended the old tree."
	for mode: String in ["full", "speed 0.7", "slowmo 0.3"]:
		if mode == "speed 0.7":
			Feel.set_game_speed(0.7)
		elif mode == "slowmo 0.3":
			Feel.slowmo(0.3, 60.0)
		var box := DialogBox.new()
		arena.add_child(box)
		await frames(2)
		box.open("Elder", [line])
		var typed_at := -1
		for f in 120:
			await frames(1)
			if box.shown >= line.length():
				typed_at = f + 1
				break
		var want := int(ceil(line.length() / DialogBox.CHARS_PER_SECOND * 60.0))
		check(absi(typed_at - want) <= 3, "%s: a line types out in real time (%d frames, %d at full speed)" % [mode, typed_at, want])
		box.close()
		box.queue_free()
		var menu := ListMenu.new()
		arena.add_child(menu)
		await frames(2)
		menu.open("Test", "", func() -> Array: return [{"label": "One"}], func(_i: int) -> void: pass)
		await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
		check(menu._grace <= 0.0, "%s: a menu takes input after its grace in real time (%.3f s left)" % [mode, menu._grace])
		menu.close()
		menu.queue_free()
		var e := EndingScreen.new()
		arena.add_child(e)
		await frames(1)
		e.start("Heartwood", 3725.0)
		await frames(int(EndingScreen.CARD_TIME * 60.0) + 4)
		check(e.card == 1, "%s: the ending's first card turns after %.0f s of real time (card %d)" % [mode, EndingScreen.CARD_TIME, e.card])
		e.queue_free()
		get_tree_paused_off()
		Feel.reset()
		Feel.set_game_speed(1.0)
		await frames(2)
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("test_the_screens_run_in_real_time_at_every_game_speed"), "the bible names this test")


func get_tree_paused_off() -> void:
	runner.get_tree().paused = false


## The spells are told in the words of their names (pass 487). Sean chose the
## names on 2026-11-05 (bible 4.1), and the lines a player reads when a spell is
## found, bought or looked up had been written for the old plain ones: Deluge
## was "a bolt of water", Tempest Lance "a bolt of lightning", Emberfall "a
## fireball" and Witherbloom "a ring of black light". Each now speaks its name's
## picture, on the pickup, the scroll and the Inventory page alike, and the two
## Arcana skills named after spells read as names of their own.
func test_each_spell_is_told_in_the_words_of_its_name() -> void:
	var pictures := {"torrent": ["Deluge", "flood"], "thunder": ["Tempest Lance", "lance"], "fire": ["Emberfall", "ember"],
		"wisplight": ["Wisplight", "spirit orb"], "death": ["Witherbloom", "Blight blooms"]}
	for id: String in pictures:
		var want: Array = pictures[id]
		check(String(Spells.DATA[id].name) == want[0], "%s is called %s" % [id, Spells.DATA[id].name])
		var info := Menus.ability_info(id)
		check(info[0] == want[0] and String(info[1]).to_lower().contains(String(want[1]).to_lower()), "%s's line speaks of its %s (%s)" % [want[0], want[1], info[1]])
		var scroll := GameData.item(id + "_scroll")
		if not scroll.is_empty():
			check(String(scroll.name) == "%s Scroll" % want[0] and String(scroll.desc).contains(String(want[1])), "the %s Scroll says so too (%s)" % [want[0], scroll.desc])
	var names: Array[String] = []
	for s: Dictionary in Skills.nodes():
		names.append(String(s.name))
	check("Undertow" in names and "Deep Blight" in names, "the water and blight skills have names of their own (%s)" % [names])
	for n: String in names:
		check(not (n.contains("Deluge") or n.contains("Witherbloom") or n.contains("Tempest Lance") or n.contains("Emberfall")), "no skill wears a whole spell's name (%s)" % n)
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("test_each_spell_is_told_in_the_words_of_its_name"), "the bible names this test")

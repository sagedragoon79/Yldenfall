extends TestSuite
## Shops, gear, keys and key doors, the skill tree, ranks and the King
## (design bible 5.2, 9 and 10).


func _town(extra := {}, header := []) -> Dictionary:
	var a := grid_rows(40, 23)
	put_tiles(a, 5, 19, "P")
	for k: Vector2i in extra:
		put_tiles(a, k.x, k.y, extra[k])
	return {"test/town": room_text(["name: Town", "zone: test"] + header, a)}


func _find(room: Room, type: Variant) -> Node:
	for c in room.get_children():
		if is_instance_of(c, type):
			return c
	return null


# --- Shops and gear ------------------------------------------------------------------

func test_buying_a_blade_changes_damage() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	p.gold = 500
	check(Shop.status("hearthroot_arms", 0, p) == "", "Wayfarer's Sword is for sale")
	check(Shop.buy("hearthroot_arms", 0, p), "bought the Wayfarer's Sword")
	check(p.gold == 100 and GameState.data.equipment.blade == "long_sword", "paid 400 and equipped it")
	check(p.slash_damage == 11 and p.heavy_damage == 19 and p.reach_bonus > 0.0, "Wayfarer's Sword stats applied")
	check(Shop.status("hearthroot_arms", 0, p) == "owned", "can't buy it twice")
	check(Shop.status("hearthroot_arms", 1, p) == "gold", "can't afford the armor with 100 gold")
	check(not Shop.buy("hearthroot_arms", 1, p) and p.gold == 100, "failed purchase costs nothing")


## Pass 413 (bible 10): a shop by the buttons. Every shop test called
## `Shop.buy` or the menu's choose function itself, so the way a player shops
## (Up at the shopkeeper, Down to a row, Jump to buy, Dash to leave) was never
## played. The Hearthroot arms dealer is visited here with the real controller.
func test_a_shop_answers_the_real_controller() -> void:
	var w := make_world(_town({}, ["npc: 8, 19, arms_dealer"]), "test/town", cell_feet(8, 19))
	var p := w.player
	p.input = PlayerInput.new()
	var menu := ListMenu.new()
	arena.add_child(menu)
	await frames(3)
	p.gold = 500
	await _tap_for_real("move_up")
	check(menu.is_open and arena.get_tree().paused, "Up at the arms dealer opens his shop")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	var shelf := Shop.shelf("hearthroot_arms")
	check(shelf[menu.cursor] == 0, "on the Wayfarer's Sword's row")
	Sfx.recent.clear()
	await _tap_for_real("jump")
	check(p.gold == 100 and GameState.data.equipment.blade == "long_sword", "Jump buys it: 400 paid and the sword in hand (%d, %s)" % [p.gold, GameState.data.equipment.blade])
	check(Sfx.recent.has("coin") and menu.is_open, "with the coin's clink, and the shop stays open (%s)" % [Sfx.recent])
	await _tap_for_real("move_down")
	check(Shop.status("hearthroot_arms", shelf[menu.cursor], p) == "gold", "Down to the armor he can't afford")
	Sfx.recent.clear()
	await _tap_for_real("jump")
	check(p.gold == 100 and Sfx.recent == (["menu_refuse"] as Array[String]), "Jump on it buys nothing and says no (%d, %s)" % [p.gold, Sfx.recent])
	await _tap_for_real("dash")
	check(not menu.is_open and not arena.get_tree().paused, "Dash leaves the shop and the game runs on")
	menu.free()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("`test_a_shop_answers_the_real_controller`"), "the bible names the test")


## Pass 532 (bible 12, the gold counter): the pass-529 grade saw a shop's
## footer say "Gold 5000" over a HUD that said 4968. The HUD's counter rolls
## toward the purse, and it rolled on, from nothing, after a load and under an
## open shop. It now starts on the purse and shows the exact sum while a menu
## pauses the game, so the two readouts never disagree.
func test_the_huds_gold_agrees_with_the_shops_footer() -> void:
	var w := make_world(_town({}, ["npc: 8, 19, arms_dealer"]), "test/town", cell_feet(8, 19))
	var p := w.player
	p.input = PlayerInput.new()
	p.gold = 500
	var menu := ListMenu.new()
	arena.add_child(menu)
	var hud := GameHud.new()
	hud.player = p
	# As under the Game node, which keeps running while the world is paused (game.gd).
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	arena.add_child(hud)
	await frames(1)
	check(int(hud.get("_shown_gold")) == 500, "the counter starts on the purse, not rolling up from 0 (%.0f)" % hud.get("_shown_gold"))
	await frames(2)
	p.gold += 100
	await frames(1)
	var rolling: float = hud.get("_shown_gold")
	check(rolling > 500.0 and rolling < 600.0, "gold found in play still rolls up (%.0f)" % rolling)
	await _tap_for_real("move_up")
	check(menu.is_open and arena.get_tree().paused, "Up at the arms dealer opens his shop")
	check(int(hud.get("_shown_gold")) == 600, "with the shop open the counter shows the whole purse at once (%.0f)" % hud.get("_shown_gold"))
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap_for_real("jump")
	var foot: String = menu.get("_footer").call()
	check(p.gold == 200 and foot == "Gold 200", "the Wayfarer's Sword is bought and the footer says so (%s)" % foot)
	check(int(hud.get("_shown_gold")) == p.gold, "and the HUD beside it says the same, not a sum still rolling down (%.0f)" % hud.get("_shown_gold"))
	await _tap_for_real("dash")
	check(not menu.is_open and not arena.get_tree().paused, "Dash leaves the shop")
	check(is_equal_approx(GameHud.shown_gold_after(-1.0, 750, 0.016, false), 750.0), "an unseen counter takes the purse as it is")
	check(is_equal_approx(GameHud.shown_gold_after(100.0, 750, 0.016, true), 750.0), "a paused one shows the exact sum")
	var step := GameHud.shown_gold_after(100.0, 750, 0.016, false)
	check(step > 100.0 and step < 750.0, "a running one rolls (%.1f)" % step)
	menu.free()
	hud.free()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("`test_the_huds_gold_agrees_with_the_shops_footer`"), "the bible names the test")


func test_once_only_stock_sells_out() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	p.gold = 2000
	var mp0 := p.max_mp
	check(Shop.buy("hearthroot_items", 1, p), "bought Mana Dew")
	check(p.max_mp == mp0 + GameState.MANA_DEW_MP, "max MP grew")
	check(Shop.status("hearthroot_items", 1, p) == "sold out", "Mana Dew sold out")
	# A key is not once-only stock, but it is sold only while a door of its card
	# waits for it (pass 245): one Copper door, so one Copper Key.
	check(Shop.buy("hearthroot_items", 0, p) and Shop.status("hearthroot_items", 0, p) == "enough", "a key sells while its door waits, then says Enough")
	check(GameState.key_count("copper") == 1, "one Copper Key")


func test_armor_reduces_damage() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	GameState.data.equipment.armor = "leather_armor"
	GameState.refresh_stats(p)
	p.take_damage(20)
	check(p.hp == p.max_hp - 17, "Tanned Jerkin: 20 damage becomes 17 (hp %d)" % p.hp)


func test_no_shield_no_block() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	check(not p.has_shield, "a new game starts without a shield")
	p.input.block_held = true
	await frames(3)
	check(not p.is_blocking, "can't block without a shield")
	GameState.data.equipment.shield = "small_shield"
	GameState.refresh_stats(p)
	await frames(2)
	check(p.is_blocking, "blocks once the Buckler is bought")


# --- Keys ----------------------------------------------------------------------------

func test_jack_door_needs_a_key_and_stays_open() -> void:
	var rooms := _town({Vector2i(12, 19): "J"})
	var w := make_world(rooms, "test/town", cell_feet(9, 19))
	var p := w.player
	await frames(3)
	p.input.move_x = 1
	await frames(40)
	check(p.global_position.x < 12 * 16, "the door blocks the way (x %.0f)" % p.global_position.x)
	check(_find(w.room, KeyDoor) != null, "door still shut without a key")
	GameState.add_key("copper")
	await frames(30)
	check(_find(w.room, KeyDoor) == null or _find(w.room, KeyDoor).is_queued_for_deletion(), "the key opens it")
	check(GameState.key_count("copper") == 0, "the key is used up")
	await frames(30)
	check(p.global_position.x > 13 * 16, "walked through (x %.0f)" % p.global_position.x)
	w.texts["test/town"] = rooms["test/town"]
	w._enter("test/town")
	check(_find(w.room, KeyDoor) == null, "opened doors stay open")


## Pass 417: a card door by the buttons. The source game's key doors open when
## you walk into one holding its key, and until now every door test walked by
## a scripted intent. Here Right is held for real: a Silver door stops the hero
## and rattles once however long he leans on it, a Copper Key does nothing to it,
## stepping back and leaning again rattles again, and the Silver Key opens it on
## the touch so the held Right walks straight through.
func test_a_card_door_answers_the_real_controller() -> void:
	var rooms := _town({Vector2i(12, 19): "J"}, ["lock: 12, 19, silver"])
	var w := make_world(rooms, "test/town", cell_feet(9, 19))
	var p := w.player
	var door := _find(w.room, KeyDoor) as KeyDoor
	await frames(3)
	GameState.add_key("copper")
	Sfx.recent.clear()
	await press_for_real(p, ["move_right"])
	await frames(60)
	check(p.global_position.x < 12 * 16 and is_instance_valid(door) and not door.is_queued_for_deletion(),
		"Right held, a Silver door stops the hero holding a Copper Key (x %.0f)" % p.global_position.x)
	check(Sfx.recent.count("door_locked") == 1, "and rattles once however long he leans (%s)" % [Sfx.recent])
	check(GameState.key_count("copper") == 1, "the Copper Key is not spent")
	release_for_real(["move_right"])
	Input.action_press("move_left")
	await frames(20)
	release_for_real(["move_left"])
	await frames(10)
	Sfx.recent.clear()
	Input.action_press("move_right")
	await frames(40)
	check(Sfx.recent.count("door_locked") == 1, "stepping back and leaning again rattles again (%s)" % [Sfx.recent])
	Sfx.recent.clear()
	GameState.add_key("silver")
	await frames(40)
	check(not is_instance_valid(door) or door.is_queued_for_deletion(), "with the Silver Key, the held Right opens it")
	check(Sfx.recent.has("key_turn") and not Sfx.recent.has("door_locked"), "the key turns, no rattle (%s)" % [Sfx.recent])
	check(p.global_position.x > 13 * 16, "and walks straight through (x %.0f)" % p.global_position.x)
	check(GameState.key_count("silver") == 0 and GameState.key_count("copper") == 1, "only the Silver Key is spent")
	release_for_real(["move_right"])
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("A card door by the buttons (pass 417)"), "bible 4.5 says so")

## Pass 459 (bible 4.5, 10.2): the source game's first steps in Hearthroot, by the
## buttons. The King's purse, the key shop and a key door were each played with
## the real controller on their own (passes 413 and 417), or by a scripted Up
## (the King), but never one after another as a new player meets them. Up at
## the King, Jump through his words; Right to the Merchant, Up, Jump on the
## Copper Key, Dash; Right held into the Copper door, which opens on the touch.
func test_the_kings_gold_buys_the_key_that_opens_the_door() -> void:
	GameState.new_game()
	var rooms := _town({Vector2i(20, 19): "J"}, ["npc: 6, 19, king", "npc: 12, 19, merchant"])
	var w := make_world(rooms, "test/town", cell_feet(6, 19))
	var p := w.player
	p.input = PlayerInput.new()
	var box := DialogBox.new()
	arena.add_child(box)
	var menu := ListMenu.new()
	arena.add_child(menu)
	var door := _find(w.room, KeyDoor) as KeyDoor
	await frames(3)
	p.gold = 0
	Sfx.recent.clear()
	await _tap_for_real("move_up")
	check(p.gold == Npc.KING_GOLD and Sfx.recent.has("coin"), "Up at the King: his purse, with a clink (%d, %s)" % [p.gold, Sfx.recent])
	check(box.is_open, "and his words open")
	var presses := 0
	while box.is_open and presses < 12:
		await frames(int(DialogBox.INPUT_GRACE * 60.0) + 2)
		await _tap_for_real("jump")
		presses += 1
	check(not box.is_open and not p.frozen, "Jump turns his pages and puts them away (%d presses)" % presses)
	await frames(20)
	Input.action_press("move_right")
	var waited := 0
	while p.global_position.x < 11.6 * Room.TILE and waited < 240:
		await frames(1)
		waited += 1
	Input.action_release("move_right")
	await frames(20)
	await _tap_for_real("move_up")
	check(menu.is_open, "Right to the Merchant and Up opens his shop (x %.0f)" % p.global_position.x)
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	var stock: Array = GameData.shop("hearthroot_items").stock
	var shelf := Shop.shelf("hearthroot_items")
	var downs := 0
	while String(stock[shelf[menu.cursor]].item) != "copper_key" and downs < shelf.size():
		await _tap_for_real("move_down")
		downs += 1
	check(String(stock[shelf[menu.cursor]].item) == "copper_key", "Down finds the Copper Key (%d presses)" % downs)
	Sfx.recent.clear()
	await _tap_for_real("jump")
	check(GameState.key_count("copper") == 1 and p.gold == Npc.KING_GOLD - 150, "Jump buys it with the King's gold (%d g)" % p.gold)
	await _tap_for_real("dash")
	check(not menu.is_open and not arena.get_tree().paused, "Dash leaves the shop")
	await frames(10)
	Sfx.recent.clear()
	Input.action_press("move_right")
	waited = 0
	while p.global_position.x < 21 * Room.TILE and waited < 300:
		await frames(1)
		waited += 1
	Input.action_release("move_right")
	check(not is_instance_valid(door) or door.is_queued_for_deletion(), "Right held into the Copper door opens it")
	check(Sfx.recent.has("key_turn") and not Sfx.recent.has("door_locked"), "the key turns, no rattle (%s)" % [Sfx.recent])
	check(p.global_position.x >= 21 * Room.TILE and GameState.key_count("copper") == 0, "he walks through and the key is spent (x %.0f)" % p.global_position.x)
	box.free()
	menu.free()


func test_card_doors_take_only_their_own_key() -> void:
	# A `lock:` line turns a J into a Silver door; a `chest:` line sets one chest's gold.
	var rooms := _town({Vector2i(12, 19): "J", Vector2i(14, 19): "$"}, ["lock: 12, 19, silver", "chest: 14, 19, 900"])
	var w := make_world(rooms, "test/town", cell_feet(9, 19))
	var p := w.player
	var door := _find(w.room, KeyDoor) as KeyDoor
	check(door != null and door.kind == "silver", "the lock line makes it a Silver door")
	check((_find(w.room, Chest) as Chest).value == 900, "the chest line sets that chest's gold")
	await frames(3)
	GameState.add_key("copper")
	GameState.add_key("gold")
	Sfx.recent.clear()
	p.input.move_x = 1
	await frames(40)
	check(is_instance_valid(door) and not door.is_queued_for_deletion(), "a Copper or Gold Key won't open a Silver door")
	check(GameState.key_count("copper") == 1 and GameState.key_count("gold") == 1, "and neither is spent")
	# Pass 122: a locked door rattles its latch (not the spell-fail fizzle), once per touch.
	check(Sfx.recent.count("door_locked") == 1 and not Sfx.recent.has("fizzle"), "a locked door rattles once, no fizzle (%s)" % [Sfx.recent])
	Sfx.recent.clear()
	GameState.add_key("silver")
	await frames(30)
	check(not is_instance_valid(door) or door.is_queued_for_deletion(), "the Silver Key opens it")
	check(Sfx.recent.has("key_turn") and not Sfx.recent.has("door"), "the key turns with its own click and chime (%s)" % [Sfx.recent])
	for sound in ["door_locked", "key_turn"]:
		check(ResourceLoader.exists("res://assets/sfx/%s.wav" % sound), "%s is rendered" % sound)
	check(GameState.key_count("silver") == 0 and GameState.key_count("copper") == 1, "only the Silver Key is used up")
	check(MapScreen.key_line() == "Keys: Copper 1, Gold 1", "the map lists the keys you hold (%s)" % MapScreen.key_line())
	# Every card has its look; an unknown kind falls back to the Copper's.
	for kind in ["copper", "silver", "gold", "thorn", "glass"]:
		check(KeyDoor.DOORS.has(kind), "%s door has a look" % kind)



## Pass 471 (bible 1, 3): the key doors had worn the card suits (spade, heart,
## club, diamond, and a jester's star) of the game Yldenfall began as. Each now
## bears a mark of this world, of a shape of its own (bible 14 tells the gates
## apart by shape): an acorn, an Ylden leaf, the Reeve's crown, a thorn and a
## stillglass shard. Each door is drawn, and no suit is left in its script.
func test_the_key_doors_wear_marks_of_their_own() -> void:
	var want := {"copper": "acorn", "silver": "leaf", "gold": "crown", "thorn": "thorn", "glass": "shard"}
	var seen := {}
	for kind: String in want:
		check(String(KeyDoor.DOORS[kind].mark) == want[kind], "the %s door bears %s (%s)" % [KeyDoor.label(kind), want[kind], KeyDoor.DOORS[kind].mark])
		seen[KeyDoor.DOORS[kind].mark] = true
	check(seen.size() == want.size(), "five doors, five marks, none shared")
	var src := FileAccess.get_file_as_string("res://scripts/world/key_door.gd").to_lower()
	for suit: String in ["spade", "\"heart\"", "club", "diamond", "jester", "suit\""]:
		check(not src.contains(suit), "no card suit is left on the doors (%s)" % suit)
	# Each door stands and draws its mark without an error.
	var shapes := {}
	for kind: String in want:
		var door := KeyDoor.new()
		door.kind = kind
		arena.add_child(door)
		shapes[kind] = door
	await frames(2)
	for kind: String in want:
		check(shapes[kind].is_inside_tree(), "the %s door stands" % kind)
		shapes[kind].free()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("Marks of their own (pass 471)") and not bible.contains("card-suit glyph"), "the bible says so")

func test_the_card_keys_are_sold_and_the_joker_is_found() -> void:
	var rooms := _town({}, ["prop: 12, 19, glass_key"])
	var w := make_world(rooms, "test/town", cell_feet(5, 19))
	var p := w.player
	var prices := {}
	for shop: String in ["hearthroot_items", "amberlee_items", "kettleforge_smith", "sylvarre_items", "spires_items"]:
		var stock: Array = GameData.shop(shop).stock
		for i in stock.size():
			var item: String = stock[i].item
			if item.ends_with("_key"):
				prices[item] = int(stock[i].price)
				if item != "copper_key":
					p.gold = 5000
					check(Shop.buy(shop, i, p) and GameState.key_count(item.trim_suffix("_key")) == 1, "%s sells the %s" % [shop, item])
	check(prices.get("silver_key") == 400 and prices.get("gold_key") == 900 and prices.get("thorn_key") == 1800, "Silver 400, King 900, Thorn 1,800 (bible 10.1): %s" % prices)
	check(not prices.has("glass_key"), "no one sells the Glass Key")
	# The Glass Key lies in the Drowned Market, once.
	var market := Room.parse(FileAccess.get_file_as_string("res://levels/vorrhallow/drowned_market.room"))
	check("49, 12, glass_key" in market.lists.get("prop", []), "the Glass Key lies in the Drowned Market")
	var key := _find(w.room, ItemPickup) as ItemPickup
	check(key != null and key.kind == "glass_key", "the prop lays a Glass Key")
	check(GameState.key_count("glass") == 0, "none held yet")
	p.input.move_x = 1
	await frames(60)
	check(GameState.key_count("glass") == 1, "touching it gives the Glass Key")
	w.texts["test/town"] = rooms["test/town"]
	w._enter("test/town")
	check(_find(w.room, ItemPickup) == null, "it never comes back")


## Bible 10.2 (pass 245): each card has one door, and every grocer cuts Copper Keys,
## so a key shop stops selling a card once the keys you hold open every door of it
## still shut. A second Copper Key had been 150 g for nothing.
func test_a_key_shop_sells_no_key_without_a_door() -> void:
	GameState.new_game()
	var w := make_world(_town(), "test/town")
	await frames(2)
	var p := w.player
	var seen := {}
	for lock: Dictionary in World.world_locks():
		seen[lock.kind] = int(seen.get(lock.kind, 0)) + 1
	check(seen == {"copper": 1, "silver": 1, "gold": 1, "thorn": 1, "glass": 1, "sky": 1}, "one door of each card in the world, and the Sky Gate (%s)" % [seen])
	var stock: Array = GameData.shop("vorrhallow_keys").stock
	var at := func(item: String) -> int: return stock.find_custom(func(e: Dictionary) -> bool: return e.item == item)
	var copper: int = at.call("copper_key")
	p.gold = 5000
	check(Shop.doors_shut("copper") == 1 and Shop.status("vorrhallow_keys", copper, p) == "", "with the Copper door shut and no key, the Copper Key is for sale")
	check(Shop.buy("vorrhallow_keys", copper, p) and GameState.key_count("copper") == 1, "you buy one")
	check(Shop.status("vorrhallow_keys", copper, p) == "enough" and not Shop.buy("vorrhallow_keys", copper, p), "a second is not sold: one key opens the one door")
	check(p.gold == 5000 - 150 and GameState.key_count("copper") == 1, "and costs nothing (%d g, %d keys)" % [p.gold, GameState.key_count("copper")])
	var row: Dictionary = Menus.shop_rows("vorrhallow_keys", p)[Shop.shelf("vorrhallow_keys").find(copper)]
	check(row.right == "Enough" and not row.enabled and String(row.detail).ends_with("You have 1. Enough for every Copper door left."), "the row says why (%s, %s)" % [row.right, row.detail])
	# The door opens and spends the key: the card is done with.
	var door: Dictionary = World.world_locks().filter(func(l: Dictionary) -> bool: return l.kind == "copper")[0]
	GameState.collect(String(door.id))
	GameState.add_key("copper", -1)
	row = Menus.shop_rows("vorrhallow_keys", p)[Shop.shelf("vorrhallow_keys").find(copper)]
	check(Shop.doors_shut("copper") == 0 and Shop.status("vorrhallow_keys", copper, p) == "enough", "with its door open, no Copper Key is sold again")
	check(String(row.detail).ends_with("You have 0. Its door stands open."), "the row says the door is open (%s)" % row.detail)
	# The other cards are still for sale, and every key row fits the menu's box.
	for item: String in ["silver_key", "gold_key", "thorn_key"]:
		check(Shop.status("vorrhallow_keys", at.call(item), p) == "", "the %s is still for sale" % item)
	GameState.add_key("silver", 1)
	var width := ListMenu.PANEL.size.x - 28
	for r: Dictionary in Menus.shop_rows("vorrhallow_keys", p):
		check(PixelFont.wrap_lines(String(r.detail), width, 9).size() <= 3, "%s fits in three lines" % r.label)
	w.queue_free()


func test_every_card_door_guards_a_vault() -> void:
	# The four card vaults (bible 3, Key doors): each lock names a J, and a chest waits behind it.
	var vaults := {"haar/feather_hollow": "silver", "boughs/north_bough": "gold", "spires/spire_stair": "thorn", "vorrhallow/meteor_rise": "glass"}
	for room: String in vaults:
		var parsed := Room.parse(FileAccess.get_file_as_string("res://levels/%s.room" % room))
		var locks: Array = parsed.lists.get("lock", [])
		check(locks.size() == 1, "%s has one lock" % room)
		var l: PackedStringArray = locks[0].split(",")
		var x := int(l[0])
		var y := int(l[1])
		var grid: Array[String] = parsed.grid
		check(grid[y][x] == "J" and l[2].strip_edges() == vaults[room], "%s: a %s door at %d,%d" % [room, vaults[room], x, y])
		var inside := false
		for cx in range(1, x):
			inside = inside or grid[y][cx] == "$"
		check(inside, "%s: a chest behind it" % room)
		check(grid[y - Reach.BODY_ROWS].substr(1, x).count("#") == x, "%s: a roof over the vault, so the door is the only way in" % room)


## Design bible 5.6: the neck, two rings and a relic. Each is an icon in the
## menu with one fixed rule; a relic sleeps until its ability is found; an
## older save comes over with the places empty.
func test_trinkets_neck_two_rings_and_a_relic() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	p.gold = 9000
	var base_melee := p.melee_mult
	var base_mp := p.mp_hit_mult
	# A ring is bought like any gear, goes on the free hand, and is kept.
	var sundries: Array = GameData.shop("hearthroot_items").stock
	var at := sundries.find_custom(func(e: Dictionary) -> bool: return e.item == "amber_band")
	check(at >= 0 and Shop.buy("hearthroot_items", at, p), "the Amber Band is bought in Hearthroot")
	check(GameState.data.equipment.ring1 == "amber_band" and is_equal_approx(p.flask_mult, 1.1), "it goes on, and the flask heals a tenth more (%.2f)" % p.flask_mult)
	check(Shop.status("hearthroot_items", at, p) == "owned", "and is not sold twice")
	GameState.obtain_gear("whetstone_ring", p)
	check(GameState.data.equipment.ring2 == "whetstone_ring" and is_equal_approx(p.melee_mult, base_melee + 0.05), "a second ring takes the other hand: 5%% harder (%.2f)" % p.melee_mult)
	GameState.wear("amber_band", p)
	check(GameState.data.equipment.ring1 == "" and is_equal_approx(p.flask_mult, 1.0), "choosing a worn ring takes it off, and its rule with it")
	GameState.wear("amber_band", p)
	check(GameState.data.equipment.ring1 == "amber_band" and GameState.data.equipment.ring2 == "whetstone_ring", "and it goes back on the free hand, never on both")
	# The neck.
	GameState.obtain_gear("dewcatch_torc", p)
	check(GameState.data.equipment.neck == "dewcatch_torc" and is_equal_approx(p.mp_hit_mult, base_mp + 0.25), "the Dewcatch Torc: a quarter more mana a blow (%.2f)" % p.mp_hit_mult)
	# The relic alters a signature ability, so it sleeps until that is found.
	p.abilities.erase("stride")
	GameState.obtain_gear("stride_knot", p)
	check(GameState.data.equipment.relic == "stride_knot" and is_equal_approx(p.dash_mult, 1.0), "the Stride Knot sleeps without the Elven Stride")
	var row: Dictionary = Menus.equipment_rows().filter(func(r: Dictionary) -> bool: return r.get("id", "") == "stride_knot")[0]
	check(String(row.detail).contains("sleeps until"), "and its row says so (%s)" % row.detail)
	p.abilities["stride"] = true
	GameState.refresh_stats(p)
	check(is_equal_approx(p.dash_mult, 1.15), "with it, the dash carries 15%% farther (%.2f)" % p.dash_mult)
	# The Equipment page lists them under their own headers.
	var heads := Menus.equipment_rows().filter(func(r: Dictionary) -> bool: return r.get("header", false)).map(func(r: Dictionary) -> String: return String(r.label))
	check(heads.has("Neck") and heads.has("Rings, two worn") and heads.has("Relic"), "the page has a Neck, Rings and Relic section (%s)" % [heads])
	# Every trinket has one rule the game knows, and none is a resistance.
	var items := GameData.table("items")
	for id: String in items:
		if GameState.TRINKET_PLACES.has(String(items[id].kind)):
			var rules := ["melee", "flask", "mp_hit", "dash"].filter(func(k: String) -> bool: return items[id].has(k))
			check(rules.size() == 1, "%s has one rule (%s)" % [id, rules])
			check(not items[id].has("ward") and not items[id].has("defense"), "%s gives no resistance" % id)
	# A save: an older one comes over with the places empty; a wrong thing comes off.
	var old := GameState.fresh()
	old.equipment = {"blade": "short_sword", "armor": "", "shield": "", "helmet": ""}
	var got := GameState.sanitize(old)
	check(got.equipment.neck == "" and got.equipment.ring1 == "" and got.equipment.ring2 == "" and got.equipment.relic == "", "an older save has the new places, empty (%s)" % [got.equipment])
	old.equipment = {"blade": "short_sword", "armor": "", "shield": "", "helmet": "", "neck": "amber_band", "ring1": "amber_band", "ring2": "amber_band", "relic": 7}
	got = GameState.sanitize(old)
	check(got.equipment.neck == "" and got.equipment.ring1 == "amber_band" and got.equipment.ring2 == "" and got.equipment.relic == "", "a ring on the neck or on both hands comes off (%s)" % [got.equipment])
	check(Array(got.gear).has("amber_band"), "and what is worn is kept as gear")


func test_the_elven_helm_is_a_secret_worth_a_mask() -> void:
	# Bible 5.2: a helmet in its own slot (pass 185), found, not bought.
	var rooms := _town({}, ["prop: 12, 19, elven_helm"])
	var w := make_world(rooms, "test/town", cell_feet(5, 19))
	var p := w.player
	await frames(3)
	var hp0 := p.max_hp
	GameState.data.equipment.shield = "magic_shield"
	GameState.data.equipment.armor = "elven_plate"
	GameState.refresh_stats(p)
	var def0 := p.defense
	var helm := _find(w.room, ItemPickup) as ItemPickup
	check(helm != null and helm.kind == "elven_helm", "the prop lays the Elven Helm")
	p.input.move_x = 1
	await frames(60)
	check(GameState.data.equipment.helmet == "elven_helm", "touching it puts it on, in the helmet's own slot")
	check(GameState.data.equipment.shield == "magic_shield" and p.has_shield and p.reflects, "and the Warding Shield stays in hand")
	check(p.max_hp == hp0 + 20 and p.hp == p.max_hp, "one more mask, filled (%d -> %d)" % [hp0, p.max_hp])
	check(is_equal_approx(def0, 0.6) and is_equal_approx(p.defense, 0.64), "10%% less on top of the Elven Plate's 60%%: 64%% (%.2f)" % p.defense)
	GameState.data.equipment.armor = ""
	GameState.refresh_stats(p)
	check(is_equal_approx(p.defense, 0.1), "10%% on its own (%.2f)" % p.defense)
	var shields := 0
	var stock: Array = GameData.shop("spires_armor").stock
	p.gold = 9999
	GameState.data.equipment.shield = "small_shield"
	for i in stock.size():
		if GameData.item(stock[i].item).kind == "shield" and int(GameData.item(stock[i].item).tier) > 1:
			shields += 1
			check(Shop.status("spires_armor", i, p) != "owned", "%s is still worth buying with the helmet on" % stock[i].item)
	check(shields > 0, "the armorer sells shields")
	check(not GameData.shop("spires_armor").stock.any(func(e: Dictionary) -> bool: return e.item == "elven_helm"), "and no one sells it")
	# It survives a save: the mask comes from the gear, not from the base stat.
	check(int(GameState.data.max_hp) == hp0, "the base health is untouched")
	w.texts["test/town"] = rooms["test/town"]
	w._enter("test/town")
	check(_find(w.room, ItemPickup) == null, "it never comes back")
	# Where it lies: a hidden pocket at the Everbloom's threshold, behind fake wall.
	var t := Room.parse(FileAccess.get_file_as_string("res://levels/evercrown/threshold.room"))
	check("2, 20, elven_helm" in t.lists.get("prop", []), "it lies in the Threshold")
	var hidden := false
	for spec: String in t.lists.get("secret", []):
		var r := spec.split(",")
		hidden = hidden or (int(r[0]) <= 2 and int(r[2]) >= 2 and int(r[1]) <= 19 and int(r[3]) >= 19)
	check(hidden, "behind a secret wall")


# --- Skills and ranks --------------------------------------------------------------

func test_skill_rules() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	check(Skills.status("keen_edge") == "points", "no points, can't learn")
	GameState.data.skill_points = 3
	check(Skills.status("fourth_strike") == "locked", "Fourth Strike needs Keen Edge first")
	check(Skills.learn("keen_edge", p) and int(GameState.data.skill_points) == 2, "learned Keen Edge for 1 point")
	check(is_equal_approx(p.melee_mult, 1.1), "Keen Edge adds 10% melee damage")
	check(Skills.learn("fourth_strike", p) and p.ground_combo_length == 4, "Fourth Strike makes a 4-hit combo")
	check(Skills.status("clear_mind") == "points", "out of points")
	p.gold = 1000
	check(Skills.respec(p), "unlearned everything")
	check(p.gold == 800 and int(GameState.data.skill_points) == 3, "respec cost 200 and refunded 3 points")
	check(p.ground_combo_length == 3 and is_equal_approx(p.melee_mult, 1.0), "effects removed")
	check(Skills.respec_cost() == 400, "the next respec costs more")



## Pass 237: a skill can be learned before the ability it works through (the
## tree deepens in order, not by what you have found), and only two of nine said
## so, in their own words. Every such skill names what it uses, and until that is
## found the tree says it does nothing yet. Each "uses" is a real ability, and a
## skill that names one in its text without a "uses" is caught.
func test_the_skill_tree_says_what_a_skill_waits_on() -> void:
	GameState.new_game()
	var names := {"delvers_pick": "Delver's Pick", "torrent": "Deluge", "wisplight": "Wisplight", "thunder": "Tempest Lance", "stillstone": "Stillstone",
		"death": "Witherbloom", "stride": "Stride", "boots": "Featherstep Boots", "fire": "Emberfall"}
	var untagged := []
	var users := []
	for node: Dictionary in Skills.nodes():
		var uses := String(node.get("uses", ""))
		if uses != "":
			users.append(node.id)
			check(GameState.data.abilities.has(uses), "%s uses a real ability (%s)" % [node.id, uses])
			continue
		for a: String in names:
			if String(node.desc).contains(names[a]):
				untagged.append("%s: %s" % [node.id, a])
	check(untagged.is_empty(), "a skill that names an ability says it uses it: %s" % [untagged])
	check(users.size() == 9, "nine skills work through something found (%d)" % users.size())
	var rows := Menus.skill_rows()
	var by_id := {}
	for row: Dictionary in rows:
		by_id[row.id] = row
	for id: String in users:
		check(String(by_id[id].detail).contains("Does nothing until you find the " + Skills.waits_on(id) + "."), "on a new game %s says what it waits on" % id)
	check(not String(by_id.keen_edge.detail).contains("Does nothing"), "a skill that needs nothing says nothing")
	check(String(by_id.feather_fall.detail).ends_with("Does nothing until you find the Featherstep Boots."), "Feather Fall waits on the Featherstep Boots")
	check(String(by_id.delvers_pick_mastery.detail).contains("the Delver's Pick."), "Pick Mastery on the Delver's Pick")
	for id: String in GameState.data.abilities:
		GameState.data.abilities[id] = true
	rows = Menus.skill_rows()
	check(not rows.any(func(r: Dictionary) -> bool: return String(r.get("detail", "")).contains("Does nothing")), "with everything found, no skill waits")
	GameState.new_game()
	var width := ListMenu.PANEL.size.x - 28
	var long := []
	for row: Dictionary in Menus.skill_rows():
		if PixelFont.wrap_lines(String(row.get("detail", "")), width, 9).size() > 3:
			long.append(row.label)
	check(long.is_empty(), "every skill's line fits in three lines: %s" % [long])

func test_stat_skills() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	GameState.data.skill_points = 4
	var mp0 := p.max_mp
	var flask0 := p.flask_max
	Skills.learn("clear_mind", p)
	Skills.learn("deep_pockets", p)
	Skills.learn("gold_sense", p)
	check(p.max_mp == mp0 + 20.0, "Clear Mind: +20 max MP")
	check(p.flask_max == flask0 + 1, "Deep Pockets: +1 potion charge")
	p.gold = 0
	for i in 10:
		p.add_gold(10, true)
	check(p.gold == 110, "Gold Sense: 10%% more found gold (%d)" % p.gold)
	p.add_gold(100)
	check(p.gold == 210, "returned gold gets no bonus")


func test_fourth_strike_combo_ends_heavy() -> void:
	var w := make_world(_town({Vector2i(9, 19): "E"}), "test/town", cell_feet(7, 19))
	var p := w.player
	GameState.data.skill_points = 3
	Skills.learn("keen_edge", p)
	Skills.learn("fourth_strike", p)
	await frames(6)
	var dummy: TrainingDummy = _find(w.room, TrainingDummy)
	var seen: Array[int] = []
	var heavy: Array[bool] = []
	for i in 4:
		p.input.attack_pressed = true
		await frames(1)
		seen.append(p.combo_index)
		heavy.append(p.is_heavy_swing)
		await frames(int((0.38 if p.is_heavy_swing else 0.2) * 60.0) + 1)
	check(seen == [1, 2, 3, 4], "four hits (%s)" % [seen])
	check(heavy == [false, false, false, true], "only the fourth is heavy (%s)" % [heavy])
	var light := roundi(8 * 1.1)
	var big := roundi(14 * 1.1)
	check(dummy.hp == TrainingDummy.HP - light * 3 - big, "Keen Edge damage on every hit (dummy hp %d)" % dummy.hp)


## The Act II tier of each branch (design bible 9): each needs the node before it.
func test_act_two_skills_chain_and_apply() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	GameState.data.skill_points = 20
	check(Skills.status("rising_cut") == "locked" and Skills.status("torrent_pierce") == "locked"
		and Skills.status("quick_draught") == "locked", "the new nodes wait on the old ones")
	for id: String in ["keen_edge", "fourth_strike", "rising_cut", "delvers_pick_mastery", "clear_mind", "siphon",
			"torrent_pierce", "deep_pockets", "gold_sense", "quick_draught", "second_stride"]:
		check(Skills.learn(id, p), "learned " + id)
	check(p.rising_cut and p.spell_pierce, "Rising Cut and Undertow switch on")
	check(is_equal_approx(p.down_strike_mult, 1.5), "Pick Mastery: the down strike hits 50% harder")
	check(is_equal_approx(p.drink_mult, 0.6), "Quick Draught: drinking takes 60% as long")
	check(p.bonus_air_dashes == 1, "Second Stride: one more air dash")
	check(int(GameState.data.skill_points) == 20 - 13, "the eleven nodes cost 13 points")
	p.gold = 1000
	check(Skills.respec(p) and not p.rising_cut and p.bonus_air_dashes == 0, "a respec takes them all back")


func test_quick_draught_drinks_faster() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	GameState.data.skill_points = 3
	for id: String in ["deep_pockets", "gold_sense", "quick_draught"]:
		Skills.learn(id, p)
	await frames(6)
	p.hp = 1
	p.input.heal_pressed = true
	await frames(1)
	var n := 0
	while p.is_drinking and n < 120:
		await frames(1)
		n += 1
	var expected := p.combat.drink_time * 0.6 * 60.0
	check(p.hp > 1 and absf(n - expected) <= 2.0, "healed after %d frames (want about %d)" % [n, roundi(expected)])


func test_second_stride_gives_two_air_dashes() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	p.abilities["stride"] = true
	GameState.data.skill_points = 5
	for id: String in ["deep_pockets", "gold_sense", "quick_draught", "second_stride"]:
		Skills.learn(id, p)
	p.teleport(cell_feet(12, 6))
	await frames(2)
	var dashes := 0
	for i in 3:
		p.input.dash_pressed = true
		await frames(1)
		if p.is_dashing:
			dashes += 1
		# Past the dash and its cooldown, so each press stands alone.
		await frames(int((p.tuning.dash_time + p.tuning.ground_dash_cooldown) * 60.0) + 2)
	check(dashes == 2, "two air dashes, then no more (%d)" % dashes)
	# Landing refills both.
	var n := 0
	while not p.is_on_floor() and n < 240:
		await frames(1)
		n += 1
	await frames(1)
	check(p.air_dash_charges == 2, "landing refills both charges (%d)" % p.air_dash_charges)


func test_rising_cut_launches_small_foes_only() -> void:
	var w := make_world(_town({Vector2i(20, 19): "M", Vector2i(30, 19): "I"}), "test/town", cell_feet(8, 19))
	var p := w.player
	await frames(6)
	var m: Blinkhop = _find(w.room, Blinkhop)
	var dwarf: IronDwarf = _find(w.room, IronDwarf)
	m.hp = 999
	var nudge := await _rise_after_up_slash(p, m)
	check(nudge < 30.0, "without Rising Cut an up-slash only nudges it (%.0f px)" % nudge)
	await frames(40)
	GameState.data.skill_points = 4
	for id: String in ["keen_edge", "fourth_strike", "rising_cut"]:
		Skills.learn(id, p)
	var rise := await _rise_after_up_slash(p, m)
	check(rise > 30.0, "Rising Cut throws a Blinkhop up (%.0f px)" % rise)
	check(not dwarf.launch(), "an Iron Dwarf is too heavy to lift")
	var spitter := SapSpitter.new()
	check(not spitter.launch(), "a rooted Sap Spitter stays put")
	spitter.free()


## Pass 458 (bible 9): the Blade skills, by the buttons. Fourth Strike, Rising
## Cut and Riposte were proved with scripted intents only. Real Attack taps, each a tap after the last swing's cooldown,
## run the learned ground combo to a fourth, heavy hit on a dummy; real Up with
## Attack throws a Blinkhop into the air; a real Block pressed as a Rot Dwarf's
## blade comes down parries it and the Riposte answers with one heavy cut.
func test_the_blade_skills_answer_the_real_controller() -> void:
	var w := make_world(_town({Vector2i(9, 19): "E", Vector2i(30, 19): "M"}), "test/town", cell_feet(7, 19))
	var p := w.player
	p.input = PlayerInput.new()
	GameState.data.skill_points = 8
	for id: String in ["keen_edge", "fourth_strike", "rising_cut", "delvers_pick_mastery", "riposte"]:
		check(Skills.learn(id, p), "learned %s" % id)
	await frames(6)
	var dummy: TrainingDummy = _find(w.room, TrainingDummy)
	var seen: Array[int] = []
	var heavy: Array[bool] = []
	# With four hits the first three each cool for the light cooldown.
	var light_cool: float = p.combat.combo_cooldowns[0]
	for i in 4:
		Input.action_press("attack")
		await frames(2)
		seen.append(p.combo_index)
		heavy.append(p.is_heavy_swing)
		Input.action_release("attack")
		await frames(int(light_cool * 60.0))
	check(seen == [1, 2, 3, 4], "four real taps of Attack run the combo to a fourth hit (%s)" % [seen])
	check(heavy == [false, false, false, true], "and only the fourth is heavy (%s)" % [heavy])
	var light := roundi(8 * p.blade_mult())
	var big := roundi(14 * p.blade_mult())
	check(dummy.hp == TrainingDummy.HP - light * 3 - big, "each with Keen Edge's damage (dummy hp %d)" % dummy.hp)
	await frames(40)
	# Rising Cut: Up with Attack, both through the real controller.
	var m: Blinkhop = _find(w.room, Blinkhop)
	m.hp = 999
	m.global_position = p.global_position + Vector2(0, -Player.BODY_SIZE.y - 6)
	m.velocity = Vector2.ZERO
	var y0 := m.global_position.y
	Input.action_press("move_up")
	Input.action_press("attack")
	var top := y0
	for i in 30:
		await frames(1)
		if i == 2:
			Input.action_release("attack")
		top = minf(top, m.global_position.y)
	Input.action_release("move_up")
	check(y0 - top > 30.0, "real Up with Attack throws a Blinkhop up (%.0f px)" % (y0 - top))
	w.free()
	await frames(2)
	# Riposte: a real Block as the Rot Dwarf's blade comes down.
	var w2 := make_world(_town({Vector2i(9, 19): "D"}), "test/town", cell_feet(6, 19))
	var q := w2.player
	q.input = PlayerInput.new()
	GameState.data.skill_points = 8
	for id: String in ["keen_edge", "fourth_strike", "rising_cut", "delvers_pick_mastery", "riposte"]:
		Skills.learn(id, q)
	GameState.data.equipment.shield = "small_shield"
	GameState.refresh_stats(q)
	var dwarf: RotDwarf = _find(w2.room, RotDwarf)
	for i in 180:
		if dwarf.state == "windup" and dwarf.state_time >= RotDwarf.WINDUP - 4 / 60.0:
			break
		await frames(1)
	var hp0 := dwarf.hp
	Sfx.recent.clear()
	await _tap_for_real("block")
	await frames(6)
	check(q.hp == q.max_hp and dwarf.is_staggered(), "a real Block parries the blade (hp %d)" % q.hp)
	check(q.ripostes == 1 and Sfx.recent.has("parry") and Sfx.recent.has("heavy"), "and the Riposte answers once, heard (%d, %s)" % [q.ripostes, Sfx.recent])
	check(hp0 - dwarf.hp == roundi(q.heavy_damage * q.blade_mult()) or dwarf.dead, "for a heavy cut (%d -> %d)" % [hp0, dwarf.hp])

## Pass 464 (bible 9): Bloodletting by the buttons. It was tested only by a
## scripted Attack on a foe staggered by a call. Here the opening is made the
## way a player makes it: a real Block parries a Rot Dwarf's blade, and real
## Attack taps cut him while he reels, each heal 2 HP with its sound; once he
## is back on his feet, the same tap heals nothing.
func test_bloodletting_answers_the_real_controller() -> void:
	var w := make_world(_town({Vector2i(9, 19): "D"}), "test/town", cell_feet(6, 19))
	var p := w.player
	p.input = PlayerInput.new()
	GameState.data.skill_points = 20
	for id: String in BLADE_TO:
		check(Skills.learn(id, p), "learned %s" % id)
	GameState.data.equipment.shield = "small_shield"
	GameState.refresh_stats(p)
	check(p.bloodletting, "Bloodletting is on")
	var dwarf: RotDwarf = _find(w.room, RotDwarf)
	dwarf.max_hp = 999
	dwarf.hp = 999
	for i in 180:
		if dwarf.state == "windup" and dwarf.state_time >= RotDwarf.WINDUP - 4 / 60.0:
			break
		await frames(1)
	await _tap_for_real("block")
	await frames(4)
	check(dwarf.is_staggered() and dwarf.punishable(), "a real Block parries him open")
	p.hp = 20
	Sfx.recent.clear()
	var healed := 0
	for i in 2:
		await _close_in_for_real(p, dwarf)
		var before := p.hp
		await _tap_for_real("attack")
		await frames(int(p.combat.combo_cooldowns[0] * 60.0))
		healed += p.hp - before
	check(healed == 2 * Player.BLOODLETTING_HEAL, "two real cuts while he reels heal %d HP (%d)" % [2 * Player.BLOODLETTING_HEAL, healed])
	check(Sfx.recent.count(Player.BLOODLET_SOUND) == 2, "each with its sound (%s)" % [Sfx.recent])
	var waited := 0
	while dwarf.punishable() and waited < 180:
		await frames(1)
		waited += 1
	await frames(30)
	await _close_in_for_real(p, dwarf)
	var hp := p.hp
	var dhp := dwarf.hp
	Sfx.recent.clear()
	await _tap_for_real("attack")
	await frames(6)
	check(dwarf.hp < dhp, "on his feet again, the next cut still lands (%d -> %d)" % [dhp, dwarf.hp])
	check(p.hp <= hp and not Sfx.recent.has(Player.BLOODLET_SOUND), "but heals nothing (%d -> %d)" % [hp, p.hp])

## Walks the hero with the real Right until he stands within a cut of `foe`.
func _close_in_for_real(p: Player, foe: Node2D, reach := 22.0) -> void:
	Input.action_press("move_right")
	for i in 90:
		if foe.global_position.x - p.global_position.x <= reach:
			break
		await frames(1)
	Input.action_release("move_right")
	await frames(1)

## Holds the foe just over the player's head, up-slashes, and returns how far
## above that spot it flew.
func _rise_after_up_slash(p: Player, foe: Enemy) -> float:
	foe.global_position = p.global_position + Vector2(0, -Player.BODY_SIZE.y - 6)
	foe.velocity = Vector2.ZERO
	var y0 := foe.global_position.y
	p.input.up = true
	p.input.attack_pressed = true
	var top := y0
	for i in 30:
		await frames(1)
		top = minf(top, foe.global_position.y)
	p.input.up = false
	return y0 - top


func test_delvers_pick_mastery_hits_harder_downward() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	p.abilities["delvers_pick"] = true
	GameState.data.skill_points = 5
	for id: String in ["keen_edge", "fourth_strike", "rising_cut", "delvers_pick_mastery"]:
		Skills.learn(id, p)
	p.teleport(cell_feet(12, 10))
	await frames(2)
	p.input.down = true
	p.input.attack_pressed = true
	await frames(1)
	p.input.down = false
	check(p.attack_kind == "down", "a downward strike in the air")
	check(p._swing_damage == roundi(p.slash_damage * 1.1 * 1.5), "Keen Edge and Pick Mastery stack (%d)" % p._swing_damage)


func test_torrent_pierce_strikes_every_foe_in_line() -> void:
	var w := make_world(_town({Vector2i(14, 19): "E", Vector2i(18, 19): "E"}), "test/town", cell_feet(8, 19))
	var p := w.player
	p.abilities["torrent"] = true
	await frames(6)
	var dummies: Array[TrainingDummy] = []
	for c in w.room.get_children():
		if c is TrainingDummy:
			dummies.append(c)
	var cast := func() -> void:
		for d in dummies:
			d.hp = TrainingDummy.HP
		p.mp = p.max_mp
		p.facing = 1
		p.input.spell_pressed = true
		await frames(40)
	await cast.call()
	var hurt := dummies.filter(func(d: TrainingDummy) -> bool: return d.hp < TrainingDummy.HP).size()
	check(hurt == 1, "a plain bolt stops at the first dummy (%d hit)" % hurt)
	GameState.data.skill_points = 3
	for id: String in ["clear_mind", "siphon", "torrent_pierce"]:
		Skills.learn(id, p)
	await cast.call()
	hurt = dummies.filter(func(d: TrainingDummy) -> bool: return d.hp < TrainingDummy.HP).size()
	check(hurt == 2, "a piercing bolt strikes both (%d hit)" % hurt)


func test_xp_raises_rank_and_gives_points() -> void:
	make_world(_town(), "test/town")
	GameState.add_xp(39)
	check(int(GameState.data.rank) == 0, "39 XP is still Seedling")
	GameState.add_xp(1)
	check(GameState.rank_name() == "Sprout" and int(GameState.data.skill_points) == 1, "40 XP: Sprout and a skill point")
	GameState.add_xp(260)
	check(GameState.rank_name() == "Barkskin" and int(GameState.data.skill_points) == 4, "300 XP: Barkskin, four points")


## Design bible 5.6: a level-up is a moment. The world pauses, the hero glows,
## and health and mana are filled at once.
func test_a_level_up_pauses_glows_and_refills() -> void:
	var w := make_world(_town(), "test/town")
	await frames(3)
	var p := w.player
	p.hp = 20
	p.mp = 5.0
	Feel.last_hitstop = 0.0
	GameState.add_xp(39)
	check(p.hp == 20 and not p.visual.level_glowing(), "short of the rank nothing happens")
	GameState.add_xp(1)
	check(p.hp == p.max_hp and p.mp == p.max_mp, "the rank fills health and mana (%d, %.0f)" % [p.hp, p.mp])
	check(Feel.last_hitstop == Player.LEVEL_UP_PAUSE, "the world holds its breath for %.2f s" % Player.LEVEL_UP_PAUSE)
	check(p.visual.level_glowing(), "and the hero glows")
	Feel.reset()
	await frames(int(PlayerVisual.LEVEL_GLOW * 60.0) + 4)
	check(not p.visual.level_glowing(), "the glow fades")


func test_kills_give_xp() -> void:
	var w := make_world(_town({Vector2i(12, 19): "M"}), "test/town")
	await frames(3)
	var m: Blinkhop = _find(w.room, Blinkhop)
	var xp := m.xp
	m.take_hit(999, Vector2.RIGHT)
	await frames(2)
	check(xp > 0 and int(GameState.data.xp) == xp, "a Blinkhop kill gives %d XP (got %d)" % [xp, int(GameState.data.xp)])


func test_gym_kills_give_no_xp() -> void:
	make_world(_town(), "test/town")
	GameState.active = false
	GameState.add_xp(100)
	GameState.active = true
	check(int(GameState.data.xp) == 0, "no XP while the game state is inactive")


func test_kills_sometimes_drop_bread_or_mana() -> void:
	var w := make_world(_town({Vector2i(12, 19): "M", Vector2i(20, 19): "M"}), "test/town")
	var p := w.player
	await frames(3)
	var monos: Array = w.room.get_children().filter(func(c: Node) -> bool: return c is Blinkhop)
	Drop.bread_chance = 1.0
	monos[0].take_hit(999, Vector2.RIGHT)
	Drop.bread_chance = 0.0
	var bread: Drop = _find(w.room, Drop)
	check(bread != null and bread.kind == "bread", "a kill can leave bread")
	await frames(40)
	check(bread.is_on_floor(), "it settles on the floor")
	p.hp = 40
	p.teleport(bread.global_position)
	await frames(3)
	check(p.hp == 40 + Drop.BREAD_HEAL and not is_instance_valid(bread), "walking over it eats it: +%d health (%d)" % [Drop.BREAD_HEAL, p.hp])
	Drop.mana_chance = 1.0
	monos[1].take_hit(999, Vector2.RIGHT)
	Drop.mana_chance = 0.0
	var orb: Drop = _find(w.room, Drop)
	check(orb != null and orb.kind == "mana", "or a mana orb")
	await frames(40)
	p.mp = 10.0
	Sfx.recent.clear()
	var toasts: Array[String] = []
	var listen := func(text: String) -> void: toasts.append(text)
	GameState.toast.connect(listen)
	p.teleport(orb.global_position)
	await frames(3)
	GameState.toast.disconnect(listen)
	# Pass 301 (bible 10): like bread, it says what it gave.
	check(toasts == ["A mana orb. +12 magic."], "and says so, as bread does (%s)" % [toasts])
	check(p.mp >= 10.0 + Drop.MANA_GAIN and p.mp < 11.0 + Drop.MANA_GAIN, "which refills magic (%.1f, with a moment of regeneration)" % p.mp)
	# Pass 294 (bible 13.3): it sounds like magic poured back, not the menu's blip.
	check(Sfx.recent.has("mana_orb") and not Sfx.recent.has("blip"), "taking it plays mana_orb, not the menu's blip (%s)" % [Sfx.recent])
	check(ResourceLoader.exists("res://assets/sfx/mana_orb.wav"), "mana_orb is rendered")
	Drop.mana_chance = 1.0
	Drop.bread_chance = 0.0
	var spare := Drop.roll(w.room, cell_feet(30, 19))
	Drop.mana_chance = 0.0
	await frames(roundi(Drop.LIFETIME * 60.0) + 5)
	check(not is_instance_valid(spare), "an uneaten drop fades away")



## Bible 7 (pass 147): any foe may rarely leave one of the source game's rare
## items. The War Glove (the source game's Glove) makes every blade hit land half
## again as hard for 15 s; an Barkbalm goes in the pouch, or straight on when
## the pouch is full.
func test_rare_drops_a_war_glove_and_an_ointment() -> void:
	var w := make_world(_town({Vector2i(12, 19): "M", Vector2i(16, 19): "M", Vector2i(24, 19): "D"}), "test/town", cell_feet(8, 19))
	var p := w.player
	await frames(3)
	check(Drop.rare_chance == 0.0, "the runner keeps rare drops off")
	check_near(p.combat.war_glove_mult, 1.5, 0.0001, "the glove multiplies blade hits by 1.5")
	check_near(p.combat.war_glove_time, 15.0, 0.0001, "for 15 s")
	# Rolled with the real odds, about one kill in forty leaves a rare item, and
	# the glove is the commoner of the two.
	Drop.rare_chance = 0.025
	seed(147)
	var kinds := {}
	for i in 4000:
		var d := Drop.roll(w.room, cell_feet(30, 10))
		if d != null:
			kinds[d.kind] = int(kinds.get(d.kind, 0)) + 1
			d.free()
	var rare := int(kinds.get("glove", 0)) + int(kinds.get("ointment", 0))
	check(kinds.size() == 2 and rare > 60 and rare < 140, "about 1 kill in 40 leaves a rare item (%s)" % [kinds])
	check(int(kinds.get("glove", 0)) > int(kinds.get("ointment", 0)), "the glove more often than the ointment")
	Drop.rare_chance = 0.0
	# The glove: a Blinkhop dies to it, and the next blows hit harder.
	var monos: Array = w.room.get_children().filter(func(c: Node) -> bool: return c is Blinkhop)
	var glove := Drop.new()
	glove.kind = "glove"
	w.room.add_child(glove)
	glove.global_position = p.global_position + Vector2(0, -4)
	var plain := p.blade_mult()
	await frames(25)
	check(not is_instance_valid(glove) and p.glove_left > 14.0, "walking over the glove puts it on (%.1f s)" % p.glove_left)
	check_near(p.blade_mult(), plain * 1.5, 0.0001, "and blade hits land half again as hard")
	# A real swing: the next slash at a Blinkhop carries the glove.
	var mono: Blinkhop = monos[0]
	mono.hp = 999
	p.teleport(mono.global_position + Vector2(-22, 0))
	p.facing = 1
	await frames(2)
	p.input.attack_pressed = true
	await frames(8)
	check(999 - mono.hp == roundi(p.slash_damage * plain * 1.5), "a slash deals %d with it (the short sword's %d)" % [999 - mono.hp, p.slash_damage])
	await frames(roundi(15.0 * 60.0) + 2)
	check(p.glove_left == 0.0 and is_equal_approx(p.blade_mult(), plain), "after 15 s it wears off")
	# Dying takes a glove off.
	p.put_on_glove()
	p._invuln_timer = 0.0
	p.take_damage(9999)
	check(p.dead, "(a killing blow)")
	var n := 0
	while p.dead and n < 300:
		await frames(1)
		n += 1
	await frames(5)
	check(not p.dead and p.glove_left == 0.0, "and death takes it off")
	for f in w.room.get_children():
		if f is Enemy:
			f.queue_free()
	# The ointment: into the pouch, or straight on when the pouch is full.
	p.ointments = 0
	for i in 2:
		var jar := Drop.new()
		jar.kind = "ointment"
		w.room.add_child(jar)
		jar.global_position = p.global_position + Vector2(0, -4)
		await frames(25)
	check(p.ointments == 2 and p.ointment_left == 0.0, "an ointment goes in the pouch (%d)" % p.ointments)
	p.ointments = Shop.OINTMENT_MAX
	var full := Drop.new()
	full.kind = "ointment"
	w.room.add_child(full)
	full.global_position = p.global_position + Vector2(0, -4)
	await frames(25)
	check(p.ointments == Shop.OINTMENT_MAX and p.ointment_left > 9.0, "with the pouch full it goes straight on (%.1f s)" % p.ointment_left)


func test_tower_kills_can_leave_poison() -> void:
	var w := make_world(_town({Vector2i(12, 19): "M"}), "test/town")
	var p := w.player
	await frames(3)
	Drop.poison_chance = 1.0
	check(Drop.roll(w.room, cell_feet(30, 19)) == null, "enemies without poison_drops never leave poison")
	var mono: Blinkhop = w.room.get_children().filter(func(c: Node) -> bool: return c is Blinkhop)[0]
	mono.poison_drops = true
	mono.take_hit(999, Vector2.RIGHT)
	Drop.poison_chance = 0.0
	var vial: Drop = _find(w.room, Drop)
	check(vial != null and vial.kind == "poison", "a Tower enemy can leave a poison flask")
	var dwarf := IronDwarf.new()
	var bat := GearBat.new()
	check(dwarf.poison_drops and bat.poison_drops, "Iron Dwarves and Gear Bats leave poison")
	dwarf.free()
	bat.free()
	await frames(40)
	p.hp = 40
	p.teleport(vial.global_position)
	await frames(3)
	check(not is_instance_valid(vial) and p.poison_left > 0.0, "walking over it poisons you")
	await frames(roundi(Player.POISON_TICK * 60.0 * 3.0) + 2)
	check(p.hp == 40 - 3 * Player.POISON_DAMAGE, "poison saps %d health a second (%d)" % [Player.POISON_DAMAGE, p.hp])
	p.hp = 2
	await frames(roundi(Player.POISON_TICK * 60.0 * 2.0) + 2)
	check(p.hp == 1 and not p.dead, "but never takes the last point (%d)" % p.hp)
	await frames(roundi(Player.POISON_TIME * 60.0))
	check(p.poison_left == 0.0, "and wears off")


func test_bread_shrines_and_ointment_beat_poison() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	check(p.poison() and p.poison_left > 0.0, "poisoned")
	Drop.bread_chance = 1.0
	var bread := Drop.roll(w.room, p.global_position)
	Drop.bread_chance = 0.0
	await frames(40)
	check(not is_instance_valid(bread) and p.poison_left == 0.0, "bread settles the stomach")
	p.poison()
	p.restore()
	check(p.poison_left == 0.0, "resting at a shrine or the Ringreader cures it")
	p.ointments = 1
	p.use_ointment()
	check(not p.poison(), "an Barkbalm keeps poison off")


## Bible 7 (pass 306): poison is a foe's leaving, so it bites as hard as the
## room's foes do (5.5): a fixed 2 a tick was 16 health at most, under 6% of a
## late hero's 280 while every blow around it doubled. It still spares the last
## point, and an Barkbalm rubbed on mid-poison stops what is left of it.
func test_poison_bites_as_hard_as_the_rooms_foes() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	for zone: String in ["tower", "haar", "evercrown"]:
		w.room.zone = zone
		p.hp = 100
		check(p.poison(), "poisoned in %s" % zone)
		await frames(roundi(Player.POISON_TICK * 60.0 * 2.0) + 2)
		var bite := roundi(Player.POISON_DAMAGE * float(CombatTuning.ZONE_THREAT[zone]))
		check(p.hp == 100 - 2 * bite, "in %s each tick takes %d (%d)" % [zone, bite, p.hp])
		p.cure_poison()
	check(roundi(Player.POISON_DAMAGE * float(CombatTuning.ZONE_THREAT["evercrown"])) > Player.POISON_DAMAGE,
		"the deepest zones bite harder than the Tower")
	p.hp = 3
	p.poison()
	await frames(roundi(Player.POISON_TICK * 60.0 * 2.0) + 2)
	check(p.hp == 1 and not p.dead, "and still spares the last point (%d)" % p.hp)
	p.cure_poison()
	w.room.zone = "test"
	p.hp = 50
	p.poison()
	p.ointments = 1
	check(p.use_ointment(), "an Barkbalm goes on mid-poison")
	await frames(roundi(Player.POISON_TIME * 60.0) + 2)
	check(p.hp == 50 and p.poison_left == 0.0, "and the rest of the poison passes harmlessly (%d)" % p.hp)



## Bible 13.3 (pass 302): every drop is heard as it is taken, and says what it
## gave. Blightcap an Barkbalm keeps off was the one pickup that made no sound.
func test_every_drop_is_heard_as_it_is_taken() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	var heard := {}
	for kind: String in ["bread", "loaf", "mana", "poison", "glove", "ointment", "warded"]:
		if kind == "warded":
			p.ointments = 1
			p.use_ointment()
		var d := Drop.make(w.room, cell_feet(20, 19), "poison" if kind == "warded" else kind)
		await frames(30)
		p.teleport(d.global_position)
		Sfx.recent.clear()
		var toasts: Array[String] = []
		var listen := func(text: String) -> void: toasts.append(text)
		GameState.toast.connect(listen)
		await frames(3)
		GameState.toast.disconnect(listen)
		check(not is_instance_valid(d), "%s is taken" % kind)
		heard[kind] = Sfx.recent.duplicate()
		check(not Sfx.recent.is_empty(), "taking %s makes a sound (%s)" % [kind, Sfx.recent])
		check(not toasts.is_empty(), "and says what it gave (%s: %s)" % [kind, toasts])
		p.teleport(cell_feet(8, 19))
		p.cure_poison()
		await frames(2)
	check(heard.warded.has("ward"), "poison kept off rings like a ward (%s)" % [heard.warded])



## Bible 13.3 (pass 310): a poison tick is heard. Since pass 306 a tick takes up
## to 4 health, and it was the one loss of health with no sound. It glugs
## (`poison_tick`), quieter than a blow's `hurt`, and a tick that takes nothing
## (the last point, under an Barkbalm) is silent.
func test_every_poison_tick_is_heard() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	w.room.zone = "evercrown"
	p.hp = 100
	p.poison()
	Sfx.recent.clear()
	await frames(roundi(Player.POISON_TICK * 60.0) + 2)
	check(p.hp == 96 and Sfx.recent.has("poison_tick"), "a tick that bites glugs (%s)" % [Sfx.recent])
	check(not Sfx.recent.has("hurt") and not Sfx.recent.has("hurt_heavy"), "and is no blow")
	var tick := _peak("poison_tick")
	var hurt := _peak("hurt")
	check(tick > 0.05 and tick < hurt * 0.75, "quieter than a blow (%.2f against %.2f)" % [tick, hurt])
	p.hp = 1
	Sfx.recent.clear()
	await frames(roundi(Player.POISON_TICK * 60.0))
	check(not Sfx.recent.has("poison_tick"), "a tick at the last point is silent")
	p.hp = 50
	p.ointments = 1
	p.use_ointment()
	Sfx.recent.clear()
	await frames(roundi(Player.POISON_TICK * 60.0))
	check(not Sfx.recent.has("poison_tick"), "and so is one an Barkbalm keeps off")
	p.cure_poison()


## The loudest sample in a sound's 16-bit source wav, from 0 to 1.
func _peak(sound: String) -> float:
	var bytes := FileAccess.get_file_as_bytes("res://assets/sfx/%s.wav" % sound)
	var at := 12
	while at + 8 <= bytes.size() and bytes.slice(at, at + 4).get_string_from_ascii() != "data":
		at += 8 + bytes.decode_u32(at + 4)
	var top := 0
	for i in range(at + 8, bytes.size() - 1, 2):
		top = maxi(top, absi(bytes.decode_s16(i)))
	return top / 32768.0


## Bible 15.3 (pass 311): a resting drop checks for spikes once, as it settles,
## not every frame. The check (pass 308) scans every child of the room, so with
## the old per-frame call a spray of drops in a spiked room scanned the room
## once a frame each for the whole 10 s they lay there.
func test_a_resting_drop_checks_for_spikes_once() -> void:
	var rows := grid_rows(40, 23)
	put_tiles(rows, 5, 19, "P")
	put_tiles(rows, 2, 19, "^", 1, 1)
	put_tiles(rows, 30, 19, "^", 8, 1)
	var w := make_world({"test/town": room_text(["name: Town", "zone: test"], rows)}, "test/town")
	await frames(3)
	var drops: Array[Drop] = []
	for i in 8:
		drops.append(Drop.make(w.room, cell_feet(10 + i * 2, 19) + Vector2(0, -8), "bread"))
	var spiked := Drop.make(w.room, cell_feet(33, 19) + Vector2(0, -8), "mana")
	spiked.velocity = Vector2.ZERO
	Drop.spike_checks = 0
	await frames(120)
	check(Drop.spike_checks == drops.size() + 1, "nine drops at rest for 2 s checked %d times, once each" % Drop.spike_checks)
	check(spiked.global_position.x < 30 * 16 or spiked.global_position.x > 38 * 16, "and the one on spikes still steps off them (%.0f)" % spiked.global_position.x)
	Drop.spike_checks = 0

func test_the_ringreader_names_your_title_once() -> void:
	var w := make_world(_town({}, ["npc: 8, 19, ringreader"]), "test/town", cell_feet(9, 19))
	var p := w.player
	await frames(2)
	var ringreader: Npc = _find(w.room, Npc)
	var said := []
	var hear := func(who: String, pages: Array) -> void: said.append([who, pages])
	GameState.dialog_requested.connect(hear)
	ringreader.interact(p)
	check(said.is_empty(), "a Seedling gets no ceremony")
	GameState.add_xp(100)
	check(GameState.rank_name() == "Sapling" and GameState.unnamed_title() == "Sapling", "ranks rise in the field, unnamed (%s)" % GameState.unnamed_title())
	ringreader.interact(p)
	check(said.size() == 1 and String(said[0][1][1]).contains("SAPLING"), "the Ringreader names you by your title: %s" % [said])
	check(int(GameState.data.named_rank) == int(GameState.data.rank) and GameState.unnamed_title() == "", "and it is yours from then on")
	ringreader.interact(p)
	check(said.size() == 1, "only once per title")
	check(Npc.title_lines(14, "Elder")[0] != Npc.title_lines(1, "Sprout")[0], "higher ranks hear grander words")
	GameState.dialog_requested.disconnect(hear)

func test_the_ringreader_gives_a_grain_for_the_journey() -> void:
	make_world(_town(), "test/town")
	var m := GameState.carved_mark()
	check(m.length() == 19 and m.split(" ").size() == 4, "four groups of four letters (%s)" % m)
	check(GameState.carved_mark() == m, "the same journey gives the same ring")
	GameState.data.gold = int(GameState.data.gold) + 1
	check(GameState.carved_mark() != m, "any change to the journey changes it")
	# Pass 401: the old password, recited where the source game recited it. Resting
	# with a Ringreader saves and tells you the journey's ring; a shrine saves quietly.
	const SLOT := 9
	var was := GameState.slot
	GameState.slot = SLOT
	var w := make_world(_town({}, ["npc: 8, 19, ringreader"]), "test/town", cell_feet(9, 19))
	await frames(2)
	var ringreader: Npc = _find(w.room, Npc)
	var toasts: Array[String] = []
	var hear := func(text: String) -> void: toasts.append(text)
	GameState.toast.connect(hear)
	ringreader.rest(w.player)
	var said := GameState.carved_mark()
	check(toasts.size() == 1 and toasts[0] == "Rested. Your mark in the wood: " + said, "the Ringreader's rest recites the journey's ring (%s)" % [toasts])
	check(GameState.has_save(SLOT), "and saves the journey it names")
	var shrine := SaveShrine.new()
	w.room.add_child(shrine)
	shrine.global_position = w.player.global_position
	toasts.clear()
	shrine.interact(w.player)
	check(toasts.size() == 1 and not toasts[0].contains("grain"), "a shrine saves without one: the ring is the Ringreader's (%s)" % [toasts])
	GameState.toast.disconnect(hear)
	GameState.delete_save(SLOT)
	GameState.slot = was
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("`test_the_ringreader_gives_a_grain_for_the_journey` rests with a Ringreader"), "11 names the test")


## Pass 409 (bible 11): the source game's two first meetings, by the buttons. The
## King's 1,500 gold and the Ringreader's rest with its ring were held by scripted
## intents and direct calls (`ringreader.rest`, pass 401); a player meets them with
## Up, and chooses the Ringreader's rest from his menu with Jump. Both are played
## here with the real controller.
func test_the_king_and_the_ringreader_answer_the_real_controller() -> void:
	var w := make_world(_town({}, ["npc: 8, 19, king"]), "test/town", cell_feet(8, 19))
	var p := w.player
	p.input = PlayerInput.new()
	await frames(3)
	var gold := p.gold
	await _tap_for_real("move_up")
	check(p.gold == gold + Npc.KING_GOLD and GameState.flag("king_gold"), "Up at the King takes his 1,500 gold (%d)" % p.gold)
	await _tap_for_real("move_up")
	check(p.gold == gold + Npc.KING_GOLD, "and Up again gives no more")
	w.queue_free()
	await frames(1)
	# The Ringreader: Up opens his menu, Jump on "Rest and save" rests and recites the ring.
	var was := GameState.slot
	GameState.slot = 9
	w = make_world(_town({}, ["npc: 8, 19, ringreader"]), "test/town", cell_feet(8, 19))
	p = w.player
	p.input = PlayerInput.new()
	var menu := ListMenu.new()
	arena.add_child(menu)
	await frames(3)
	p.hp = 1
	var toasts: Array[String] = []
	var hear := func(text: String) -> void: toasts.append(text)
	GameState.toast.connect(hear)
	await _tap_for_real("move_up")
	check(menu.is_open and arena.get_tree().paused, "Up at the Ringreader opens his menu")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	Sfx.recent.clear()
	await _tap_for_real("jump")
	GameState.toast.disconnect(hear)
	check(not menu.is_open and not arena.get_tree().paused, "Jump on Rest and save closes it")
	check(p.hp == p.max_hp and GameState.has_save(9) and Sfx.recent.has("save"), "and rests, saves and chimes (%s)" % [Sfx.recent])
	check(toasts.size() == 1 and toasts[0] == "Rested. Your mark in the wood: " + GameState.carved_mark(), "and recites the journey's ring (%s)" % [toasts])
	menu.free()
	GameState.delete_save(9)
	GameState.slot = was
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("`test_the_king_and_the_ringreader_answer_the_real_controller`"), "11 names the test")


## Pass 449 (bible 5.4): the source game starts you again at the last Ringreader you
## rested with. Rest by the buttons, walk off by the buttons into the spikes,
## rise at his side, and walk back by the buttons to the purse.
func test_a_death_raises_you_at_the_ringreader_you_rested_with() -> void:
	var was := GameState.slot
	GameState.slot = 9
	var rows := grid_rows(40, 23)
	put_tiles(rows, 30, 19, "^", 3)
	put_tiles(rows, 3, 19, "P")
	var w := make_world({"test/town": room_text(["name: Town", "zone: test", "npc: 8, 19, ringreader"], rows)}, "test/town", cell_feet(8, 19))
	var p := w.player
	p.input = PlayerInput.new()
	var menu := ListMenu.new()
	arena.add_child(menu)
	await frames(3)
	await _tap_for_real("move_up")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap_for_real("jump")
	check(not menu.is_open and GameState.data.save_room == "test/town", "rested and saved at the Ringreader")
	var ringreader_x := float(GameState.data.save_pos[0])
	p.gold = 100
	p.hp = 1
	Input.action_press("move_right")
	var waited := 0
	while not p.dead and waited < 240:
		await frames(1)
		waited += 1
	Input.action_release("move_right")
	check(p.dead, "Right walks him into the spikes and he falls (%d frames)" % waited)
	check(p.gold == 40 and is_instance_valid(p.purse) and p.purse.value == 60, "60 of his 100 gold lie in a purse (%d)" % p.gold)
	var purse_x := p.purse.global_position.x if is_instance_valid(p.purse) else 0.0
	check(purse_x > 20 * 16 and purse_x < 30 * 16, "on the safe ground short of the spikes (%.0f)" % purse_x)
	await frames(int(p.combat.respawn_delay * 60.0) + 10)
	check(not p.dead and w.room.id == "test/town", "he rises again")
	check(absf(p.global_position.x - ringreader_x) < 2.0, "at the Ringreader's side (%.0f, Ringreader %.0f)" % [p.global_position.x, ringreader_x])
	check(p.hp == p.max_hp, "made whole")
	Input.action_press("move_right")
	waited = 0
	while p.gold < 100 and waited < 240:
		await frames(1)
		waited += 1
	Input.action_release("move_right")
	await frames(2)
	check(p.gold == 100 and not is_instance_valid(p.purse), "Right walks him back to the purse and the gold is his again (%d)" % p.gold)
	check(not p.dead, "and he stops short of the spikes")
	menu.free()
	GameState.delete_save(9)
	GameState.slot = was
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("`test_a_death_raises_you_at_the_ringreader_you_rested_with`"), "5.4 names the test")


## Pass 463 (bible 2, Act I): the Ringreader reads the glass leaf. The story's
## first beat had no line in the game: the stranger's leaf turned to glass, and
## the Ringreader reads in it the Heartwood Spring dammed with stillglass. The
## first Ringreader met says so over his menu, once, and from then on greets
## as before. Played with the real Up and Dash, and kept through a save.
func test_the_first_ringreader_reads_the_glass_leaf() -> void:
	GameState.new_game()
	var info := GameData.npc("ringreader")
	var reading := String(info.get("greeting_leaf", ""))
	check(reading.contains("glass") and reading.contains("Heartwood Spring") and reading.contains("stillglass"), "the reading names the glass leaf, the Heartwood Spring and the stillglass (%s)" % reading)
	var w := make_world(_town({}, ["npc: 8, 19, ringreader"]), "test/town", cell_feet(8, 19))
	var p := w.player
	p.input = PlayerInput.new()
	var menu := ListMenu.new()
	arena.add_child(menu)
	await frames(3)
	check(not GameState.flag(Npc.LEAF_READ), "a new journey has had no reading")
	await _tap_for_real("move_up")
	check(menu.is_open and menu.subtitle == reading, "Up at the first Ringreader: he reads the leaf over his menu (%s)" % menu.subtitle)
	check(GameState.flag(Npc.LEAF_READ), "and it is marked read")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap_for_real("dash")
	check(not menu.is_open, "Dash steps away")
	await frames(10)
	await _tap_for_real("move_up")
	check(menu.is_open and menu.subtitle == String(info.greeting), "Up again: the usual greeting (%s)" % menu.subtitle)
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap_for_real("dash")
	var kept: Dictionary = JSON.parse_string(JSON.stringify(GameState.data))
	check(bool(kept.flags.get(Npc.LEAF_READ, false)), "the reading is kept in the journey")
	menu.free()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("`test_the_first_ringreader_reads_the_glass_leaf`"), "the bible names the test")


## Pass 453 (bible 9): a skill learned and unlearned at a Ringreader by the buttons.
## Up opens his menu, Down and Jump open Learn skills, and Jump on the first
## row learns it: the points are paid and the blade cuts harder at once. Dash
## steps back out. Then Up, Down twice and Jump on Unlearn skills forgets it
## for its gold: the points come back and the blade is as it was.
func test_a_skill_is_learned_and_unlearned_with_the_buttons() -> void:
	var w := make_world(_town({}, ["npc: 8, 19, ringreader"]), "test/town", cell_feet(8, 19))
	var p := w.player
	p.input = PlayerInput.new()
	var menu := ListMenu.new()
	arena.add_child(menu)
	await frames(3)
	GameState.data.skill_points = 3
	p.gold = 1000
	var cut0 := p.blade_mult()
	var grace := int(ListMenu.INPUT_GRACE * 60.0) + 2
	await _tap_for_real("move_up")
	await frames(grace)
	await _tap_for_real("move_down")
	check(menu.title == "Ringreader" and menu.cursor == 1, "Up opens the Ringreader's menu and Down reaches Learn skills (%d)" % menu.cursor)
	await _tap_for_real("jump")
	check(menu.is_open and menu.title == "Skills", "Jump opens the skills (%s)" % menu.title)
	await frames(grace)
	var row: Dictionary = menu.rows[menu.cursor]
	var id := String(row.get("id", ""))
	var cost := int(GameData.skill(id).cost)
	check(id == "keen_edge" and not row.get("header", false), "the cursor waits on the first skill, past its branch's name (%s)" % id)
	await _tap_for_real("jump")
	check(GameState.data.skills.has(id) and int(GameState.data.skill_points) == 3 - cost, "Jump learns it for its %d pt (%d left)" % [cost, int(GameState.data.skill_points)])
	check(p.blade_mult() > cut0 + 0.05, "and the blade cuts harder at once (x%.2f -> x%.2f)" % [cut0, p.blade_mult()])
	await _tap_for_real("jump")
	check(int(GameState.data.skill_points) == 3 - cost, "Jump again on a learned skill spends nothing")
	await _tap_for_real("dash")
	await frames(2)
	check(not menu.is_open and not arena.get_tree().paused, "Dash steps back out to play (%s)" % menu.title)
	var price := Skills.respec_cost()
	await frames(grace)
	await _tap_for_real("move_up")
	await frames(grace)
	await _tap_for_real("move_down")
	await _tap_for_real("move_down")
	check(menu.title == "Ringreader" and menu.cursor == 2, "Down twice reaches Unlearn skills (%d)" % menu.cursor)
	await _tap_for_real("jump")
	check(GameState.data.skills.is_empty() and int(GameState.data.skill_points) == 3 and p.gold == 1000 - price,
		"Jump forgets it for %d gold and the points come back (%d pt, %d g)" % [price, int(GameState.data.skill_points), p.gold])
	check(is_equal_approx(p.blade_mult(), cut0), "and the blade is as it was (x%.2f)" % p.blade_mult())
	menu.close()
	await frames(2)
	menu.free()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("`test_a_skill_is_learned_and_unlearned_with_the_buttons`"), "9 names the test")


## Pass 454 (bible 13.3): the Ringreader's pages, heard through the buttons. Pass 398
## heard every press in a list menu, but never in the Ringreader's own pages: Down
## blips, Jump on a skill rings the rank chime, Jump on a learned one says no,
## Dash backs out quietly, Unlearn skills is heard as a mending, Unlearn with
## nothing learned says no, and Jump on a stop of the Grain Road is heard by
## the save chime once. No press that closes a page is heard as a jump.
func test_the_ringreaders_pages_are_heard_through_the_buttons() -> void:
	var a := grid_rows(40, 23)
	put_tiles(a, 5, 19, "P")
	var rooms := {"test/town": room_text(["name: Town", "zone: test", "npc: 8, 19, ringreader"], a),
		"test/far": room_text(["name: Far", "zone: test", "npc: 8, 19, ringreader"], a)}
	var w := make_world(rooms, "test/town", cell_feet(8, 19))
	var p := w.player
	p.input = PlayerInput.new()
	var menu := ListMenu.new()
	arena.add_child(menu)
	await frames(3)
	GameState.data.skill_points = 3
	GameState.meet_ringreader("test/far", Vector2(8 * Room.TILE + 8, 20 * Room.TILE))
	GameState.set_flag("spring:heartwood")
	p.gold = 1000
	var grace := int(ListMenu.INPUT_GRACE * 60.0) + 2
	var heard := func(action: String) -> Array:
		Sfx.recent.clear()
		await _tap_for_real(action)
		return Sfx.recent.duplicate()
	await _tap_for_real("move_up")
	await frames(grace)
	var got: Array = await heard.call("move_down")
	check(got == ["blip"], "Down on the Ringreader's menu blips (%s)" % [got])
	await _tap_for_real("jump")
	await frames(grace)
	check(menu.title == "Skills", "Jump opens the skills")
	got = await heard.call("jump")
	check(got == ["rank"], "Jump on a skill learns it with the rank chime (%s)" % [got])
	got = await heard.call("jump")
	check(got == ["menu_refuse"], "Jump on it again says no (%s)" % [got])
	got = await heard.call("dash")
	check(got.is_empty() and not menu.is_open, "Dash backs out to play quietly (%s)" % [got])
	await frames(grace)
	await _tap_for_real("move_up")
	await frames(grace)
	await _tap_for_real("move_down")
	await _tap_for_real("move_down")
	got = await heard.call("jump")
	check(got == ["heal"], "Jump on Unlearn skills is heard as a mending (%s)" % [got])
	got = await heard.call("jump")
	check(got == ["menu_refuse"], "and again, with nothing learned, says no (%s)" % [got])
	await _tap_for_real("move_down")
	await _tap_for_real("jump")
	check(menu.title == "Grain Road", "Down and Jump open the Grain Road")
	await frames(grace)
	got = await heard.call("jump")
	await frames(4)
	check(got.count("save") == 1 and not got.has("jump"), "Jump on a stop is heard by the save chime once, never as a jump (%s)" % [got])
	check(w.room.id == "test/far", "and walks you there")
	menu.free()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("`test_the_ringreaders_pages_are_heard_through_the_buttons`"), "13.3 names the test")


func _tap_for_real(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(2)


# --- NPCs ----------------------------------------------------------------------------

func test_king_gives_gold_once() -> void:
	var w := make_world(_town({}, ["npc: 8, 19, king"]), "test/town", cell_feet(8, 19))
	var p := w.player
	var said := []
	var listener := func(who: String, _pages: Array) -> void: said.append(who)
	GameState.dialog_requested.connect(listener)
	await frames(3)
	p.input.up_pressed = true
	await frames(2)
	check(p.gold == Npc.KING_GOLD, "the King gives 1,500 gold (%d)" % p.gold)
	p.input.up_pressed = true
	await frames(2)
	GameState.dialog_requested.disconnect(listener)
	check(p.gold == Npc.KING_GOLD, "only once")
	check(said.size() == 2 and said[0] == "Reeve Aldous", "he talks both times")


## Pass 369 (bible 9): no title costs less than the one before it, and the
## last is no leap. The Reeve gives his purse once, whatever you carry.
func test_the_titles_climb_as_the_originals_do() -> void:
	check(GameState.RANK_XP.size() == 16 and GameState.RANKS.size() == 16, "sixteen titles")
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var note := bible.get_slice("**The titles' climb (pass 369):**", 1).get_slice("\n", 0)
	check(note != "", "bible 9 has the note")
	var unwritten := []
	var steps := GameState.RANK_XP.slice(1)
	for i in steps.size():
		var gap: int = steps[i] - (0 if i == 0 else steps[i - 1])
		if not note.contains(String.num_int64(gap)):
			unwritten.append(gap)
	check(unwritten.is_empty(), "the curve's steps are in the note (not: %s)" % [unwritten])
	for list: Array in [GameState.RANK_XP]:
		var climbs := true
		for i in range(2, list.size()):
			climbs = climbs and int(list[i]) - int(list[i - 1]) >= int(list[i - 1]) - int(list[i - 2])
		check(climbs, "no title costs less than the one before it (%s)" % [list])
	var last: int = GameState.RANK_XP[15] - GameState.RANK_XP[14]
	var before: int = GameState.RANK_XP[14] - GameState.RANK_XP[13]
	check(last < before * 2, "and Ylden's Own is no leap (%d after %d)" % [last, before])
	# The King's purse, to a hero who picked up a coin on the way in.
	var w := make_world(_town({}, ["npc: 8, 19, king"]), "test/town", cell_feet(8, 19))
	var p := w.player
	await frames(3)
	p.add_gold(5)
	p.input.up_pressed = true
	await frames(2)
	check(p.gold == Npc.KING_GOLD + 5, "the Reeve gives his 1,500 to a hero already holding 5 (%d)" % p.gold)


func test_every_npc_and_shop_entry_is_valid() -> void:
	var bad: Array[String] = []
	for id: String in GameData.table("npcs"):
		var npc: Dictionary = GameData.npc(id)
		if npc.role == "shop" and GameData.shop(npc.shop).is_empty():
			bad.append("%s sells from missing shop %s" % [id, npc.shop])
		if npc.role in ["talk", "king", "physician"] and npc.get("lines", []).is_empty():
			bad.append("%s has nothing to say" % id)
		if npc.role == "physician" and npc.get("lines_treated", []).is_empty():
			bad.append("%s has nothing to say" % id)
	for shop_id: String in GameData.table("shops"):
		for entry: Dictionary in GameData.shop(shop_id).stock:
			if GameData.item(entry.item).is_empty():
				bad.append("%s sells unknown item %s" % [shop_id, entry.item])
	for node: Dictionary in Skills.nodes():
		if String(node.needs) != "" and GameData.skill(node.needs).is_empty():
			bad.append("skill %s needs unknown %s" % [node.id, node.needs])
	check(bad.is_empty(), "data tables are consistent: %s" % ", ".join(bad))


# --- Amberlee -------------------------------------------------------------------------

func test_large_shield_guards_more() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	GameState.data.equipment.shield = "small_shield"
	GameState.refresh_stats(p)
	check_near(p.guard_reduction, 0.5, 0.001, "the Buckler halves a guarded hit")
	p.gold = 900
	check(Shop.buy("amberlee_armor", 1, p), "bought the Kite Shield")
	check_near(p.guard_reduction, 0.7, 0.001, "the Kite Shield blocks 70%")
	var dummy := Node2D.new()
	w.room.add_child(dummy)
	dummy.global_position = p.global_position + Vector2(p.facing * 30, 0)
	p.input.block_held = true
	await frames(3)
	check(p.receive_attack(20, dummy, false) == "guarded" and p.hp == p.max_hp - 6, "a guarded 20 becomes 6 (hp %d)" % p.hp)
	check(Shop.status("amberlee_armor", 1, p) == "owned", "the Kite Shield shows as owned")
	check(Shop.status("hearthroot_arms", 2, p) != "owned", "a shield you never had stays for sale (pass 186)")


## Pass 225: in the source game a shield did one thing, it resisted enemy magic
## (the manual: Small 50%, Large 75%, Magic 90%, and the Elven Helm nearly
## all). The remake's shields guard and parry; now they ward a foe's sorcery
## too, guarding or not, at less than the source game so the guard still matters.
## Pass 229: the Equipment page's footer adds up what you wear, since armor
## and helmet stack by what each lets through and the ward is capped and lost
## to a two-hander. None of that showed anywhere before.
func test_the_equipment_page_adds_up_what_you_wear() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	GameState.data.gear = ["short_sword", "dwarvish_broad_sword", "leather_armor", "elven_plate", "magic_shield", "elven_helm"]
	var cases := [
		[{"blade": "short_sword", "armor": "", "shield": "", "helmet": ""}, "Armor 0%   Ward 0%", "nothing worn"],
		[{"blade": "short_sword", "armor": "leather_armor", "shield": "", "helmet": ""}, "Armor 15%   Ward 0%", "Tanned Jerkin"],
		[{"blade": "short_sword", "armor": "elven_plate", "shield": "", "helmet": "elven_helm"}, "Armor 64%   Ward 20%", "the Elven Plate under the helmet stops 64%, not 70%"],
		[{"blade": "short_sword", "armor": "elven_plate", "shield": "magic_shield", "helmet": "elven_helm"}, "Armor 64%   Ward 60%", "the Warding Shield and the helmet ward the most there is"],
		[{"blade": "dwarvish_broad_sword", "armor": "elven_plate", "shield": "magic_shield", "helmet": "elven_helm"}, "Armor 64%   Ward 20%", "a two-hander leaves only the helmet's ward"],
	]
	var hint := "Jump: choose   Dash: leave"
	for c: Array in cases:
		GameState.data.equipment = c[0]
		GameState.refresh_stats(p)
		var foot := Menus.worn_totals(p)
		check(foot == c[1], "%s: %s" % [c[2], foot])
		check(PixelFont.width(foot, 9) + 16.0 + PixelFont.width(hint, 8) <= ListMenu.PANEL.size.x - 28, "and it fits beside the hint")
	GameState.data.equipment = cases[4][0]
	var shield: Dictionary = Menus.equipment_rows().filter(func(r: Dictionary) -> bool: return r.get("id", "") == "magic_shield")[0]
	check(String(shield.detail).contains("no guard or ward"), "a slung shield's row says it neither guards nor wards")


func test_a_shield_wards_a_foes_sorcery() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	var wards := {"": 0.0, "small_shield": 0.2, "large_shield": 0.3, "magic_shield": 0.4}
	for shield: String in wards:
		GameState.data.equipment.shield = shield
		GameState.refresh_stats(p)
		check_near(p.magic_ward, wards[shield], 0.001, "%s wards %d%% of sorcery" % [shield if shield != "" else "no shield", roundi(wards[shield] * 100)])
	GameState.data.equipment.helmet = "elven_helm"
	GameState.refresh_stats(p)
	check_near(p.magic_ward, GameState.MAX_WARD, 0.001, "the Elven Helm adds 20%%, to the most there is (%.2f)" % p.magic_ward)
	GameState.data.equipment.blade = "dwarvish_broad_sword"
	GameState.refresh_stats(p)
	check_near(p.magic_ward, 0.2, 0.001, "a shield on the back of a two-hander wards nothing; the helmet still does")
	GameState.data.equipment.blade = "short_sword"
	GameState.data.equipment.shield = "magic_shield"
	Menus.choose_equipment(Menus.OFFHAND_DAGGER, p)
	check(GameState.offhand_free(), "the Rune Dagger chosen for the off hand takes the shield off")
	check_near(p.magic_ward, 0.2, 0.001, "and with it the shield's ward: only the helmet's stays (pass 313)")
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("the source game had no thrown dagger, and its shield, once bought, was always on the arm and always resisting magic"),
		"the bible says how the off hand departs from the source game's shield")
	GameState.data.equipment.blade = "short_sword"
	GameState.data.equipment.helmet = ""
	GameState.data.equipment.shield = "small_shield"
	GameState.refresh_stats(p)
	var blow := Node2D.new()
	var hex := Node2D.new()
	hex.add_to_group(Player.MAGIC)
	for n: Node2D in [blow, hex]:
		w.room.add_child(n)
		n.global_position = p.global_position + Vector2(p.facing * 30, 0)
	p.hp = p.max_hp
	Sfx.recent.clear()
	check(p.receive_attack(20, blow, false) == "hit" and p.hp == p.max_hp - 20, "a blow lands whole on an unguarded hero (hp %d)" % p.hp)
	check(not Sfx.recent.has(Player.WARD_SOUND), "and rings no ward")
	p.hp = p.max_hp
	p._invuln_timer = 0.0
	check(p.receive_attack(20, hex, false) == "hit" and p.hp == p.max_hp - 16, "a hex of 20 lands as 16 through the Buckler, unguarded (hp %d)" % p.hp)
	check(Sfx.recent.has(Player.WARD_SOUND), "and the ward rings as it turns the rest (pass 230)")
	var casters := ["res://scripts/enemies/mire_grasp.gd", "res://scripts/bosses/shadow_bolt.gd", "res://scripts/bosses/crystal_shard.gd", "res://scripts/bosses/core_beam.gd"]
	var plain := []
	for path: String in casters:
		if not FileAccess.get_file_as_string(path).contains("add_to_group(Player.MAGIC)"):
			plain.append(path.get_file())
	check(plain.is_empty(), "the hags' hex, the Likeness's bolts, Vorrund's shards and the core's beam are sorcery (not: %s)" % [plain])


func test_the_magic_shield_is_sold_in_spires_and_reflects() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	GameState.data.equipment.shield = "large_shield"
	GameState.refresh_stats(p)
	check(not p.reflects, "the Kite Shield doesn't reflect")
	var stock: Array = GameData.shop("spires_armor").stock
	check(stock[1].item == "magic_shield" and int(stock[1].price) == 3600, "Calder's armory sells the Warding Shield for 3,600 g")
	p.gold = 3600
	check(Shop.buy("spires_armor", 1, p), "bought the Warding Shield")
	check(p.reflects and p.has_shield, "it reflects small shots on a parry")
	check_near(p.guard_reduction, 0.7, 0.001, "and guards like the Kite Shield")
	check(Shop.status("spires_armor", 1, p) == "owned", "it shows as owned")
	check(Shop.status("amberlee_armor", 1, p) != "owned", "a Kite Shield you never had stays for sale (pass 186)")


func test_elixir_revives_once_and_is_limited_to_one() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	p.gold = 4000
	check(Shop.buy("amberlee_items", 0, p) and p.elixirs == 1, "bought an Amber Draught")
	check(Shop.status("amberlee_items", 0, p) == "owned", "you can carry only one")
	check(int(GameState.data.elixirs) == 1, "the Amber Draught is saved")
	p.mp = 0.0
	p.take_damage(p.max_hp + 50)
	check(not p.dead and p.hp == p.max_hp and p.elixirs == 0, "a fatal hit drinks the Amber Draught and revives you (hp %d)" % p.hp)
	# Pass 345: the manual's Amber Draught is "Medicine that will restore your magic
	# and power", so the revive fills the magic too.
	check(is_equal_approx(p.mp, p.max_mp), "and with full magic, as the source game's manual says (mp %.0f of %.0f)" % [p.mp, p.max_mp])
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("revives you in place at full health and full magic"), "5.2 says the Amber Draught fills both")
	check(p.invulnerable, "with a moment of safety")
	Feel.reset()
	await frames(150)
	p.take_damage(p.max_hp + 50)
	check(p.dead, "without an Amber Draught, a fatal hit kills")


func test_amberlee_folk_return_with_the_spring() -> void:
	GameState.new_game()
	var before := Room.from_file("res://levels/heartwood/amberlee.room")
	arena.add_child(before)
	var ids := func(room: Room) -> Array:
		var out := []
		for c in room.get_children():
			if c is Npc:
				out.append((c as Npc).npc_id)
		out.sort()
		return out
	var b: Array = ids.call(before)
	check(b == ["amberlee_miner", "amberlee_widow", "ringreader"], "before the spring: the Ringreader, a dwarf and one townswoman (%s)" % [b])
	GameState.set_flag("spring:heartwood")
	var after := Room.from_file("res://levels/heartwood/amberlee.room")
	arena.add_child(after)
	var a: Array = ids.call(after)
	check(a == ["amberlee_armorer", "amberlee_grocer", "amberlee_miner", "amberlee_widow_glad", "ringreader"], "after: the shops reopen (%s)" % [a])
	var lit := false
	for c in after.get_children():
		if c is HouseFront:
			lit = (c as HouseFront).lit()
	check(lit, "and the windows light up")
	GameState.new_game()


# --- Kettleforge freed ---------------------------------------------------------------

## Pass 175: Kettleforge keeps the source game's hospital and a larder. The physician
## mends health, magic and poison for nothing, but neither saves nor refills
## the flask (that is the Ringreader's rest); with nothing to mend he only talks.
func test_forepaws_physician_mends_you_and_its_larder_sells() -> void:
	var w := make_world(_town({}, ["npc: 8, 19, kettleforge_physician"]), "test/town", cell_feet(8, 19))
	var p := w.player
	var said := []
	var listener := func(who: String, pages: Array) -> void: said.append(pages)
	GameState.dialog_requested.connect(listener)
	await frames(3)
	var gold := p.gold
	p.input.up_pressed = true
	await frames(2)
	check(said.size() == 1 and said[0] == GameData.npc("kettleforge_physician").lines, "whole and well, he only talks")
	p.hp = 10
	p.mp = 0.0
	p.poison()
	p.flask_charges = 0
	GameState.data.save_room = ""
	p.input.up_pressed = true
	await frames(2)
	GameState.dialog_requested.disconnect(listener)
	check(p.hp == p.max_hp and is_equal_approx(p.mp, p.max_mp) and p.poison_left <= 0.0, "hurt, drained and poisoned: he mends all three (hp %d)" % p.hp)
	check(said.size() == 2 and said[1] == GameData.npc("kettleforge_physician").lines_treated, "and says what he did")
	check(p.gold == gold and p.flask_charges == 0 and String(GameState.data.save_room) == "", "for no gold, with no save and no flask refill")
	var room := Room.from_file("res://levels/tower/kettleforge.room")
	arena.add_child(room)
	var ids := room.get_children().filter(func(c: Node) -> bool: return c is Npc).map(func(c: Npc) -> String: return c.npc_id)
	check(ids.has("kettleforge_physician") and ids.has("kettleforge_grocer"), "both keep house in Kettleforge (%s)" % [ids])
	room.queue_free()
	var stock: Array = GameData.shop(GameData.npc("kettleforge_grocer").shop).stock
	check(stock.map(func(e: Dictionary) -> String: return e.item) == ["elixir", "silver_key"], "the Larder sells an Amber Draught and the Silver Key")


## Pass 457 (bible 10.3): the source game's hospital, by the buttons. Right walks
## the hero over a Tower foe's poison flask and on to Physician Halvar; one real
## Up opens his treatment as a dialog that holds the world, so the poison takes
## no tick while he works; Jump turns his pages, and the Jump that closes the
## last one does not leap. He leaves the hero whole, unpoisoned and as rich as
## he came.
func test_the_hospital_cures_poison_through_the_buttons() -> void:
	var w := make_world(_town({}, ["npc: 12, 19, kettleforge_physician"]), "test/town", cell_feet(3, 19))
	var p := w.player
	p.input = PlayerInput.new()
	var box := DialogBox.new()
	arena.add_child(box)
	await frames(3)
	Drop.make(w.room, cell_feet(6, 19), "poison")
	p.hp = 30
	var gold := p.gold
	Input.action_press("move_right")
	var waited := 0
	while p.poison_left <= 0.0 and waited < 120:
		await frames(1)
		waited += 1
	check(p.poison_left > 0.0, "Right walks him over the flask and he is poisoned (%d frames)" % waited)
	while p.global_position.x < 11.5 * Room.TILE and waited < 300:
		await frames(1)
		waited += 1
	Input.action_release("move_right")
	await frames(roundi(Player.POISON_TICK * 60.0) + 2)
	check(p.hp < 30 and p.poison_left > 0.0, "the poison bites on the way (%d)" % p.hp)
	await frames(8)
	Sfx.recent.clear()
	await _tap_for_real("move_up")
	check(box.is_open and arena.get_tree().paused and p.frozen, "one real Up at Halvar opens his treatment and holds the world")
	check(p.hp == p.max_hp and is_equal_approx(p.mp, p.max_mp) and p.poison_left <= 0.0, "health and magic made whole, poison drawn out (hp %d)" % p.hp)
	check(Sfx.recent.has("heal"), "to the mending sound (%s)" % [Sfx.recent])
	check(box.pages == GameData.npc("kettleforge_physician").lines_treated, "and he says what he did")
	var pages := box.pages.size()
	var presses := 0
	while box.is_open and presses < pages * 3:
		await frames(int(DialogBox.INPUT_GRACE * 60.0) + 2)
		await _tap_for_real("jump")
		presses += 1
	check(not box.is_open and not arena.get_tree().paused and not p.frozen, "Jump turns his pages and closes them (%d presses)" % presses)
	var leapt := false
	for i in 20:
		await frames(1)
		leapt = leapt or p.velocity.y < -1.0
	check(not leapt, "the Jump that closes the last page does not leap")
	await frames(roundi(Player.POISON_TICK * 60.0 * 2.0) + 2)
	check(p.hp == p.max_hp and p.gold == gold, "no tick follows him out, and he paid nothing (hp %d, gold %d)" % [p.hp, p.gold])
	box.free()


func test_the_kettleforge_smith_tempers_a_blade_twice() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	p.gold = 5000
	var base := p.slash_damage
	var heavy := p.heavy_damage
	check(Shop.status("kettleforge_smith", 1, p) == "locked", "the second temper waits for the first")
	check(Shop.buy("kettleforge_smith", 0, p), "bought Temper Blade I")
	check(p.slash_damage == roundi(base * 1.15) and p.heavy_damage == roundi(heavy * 1.15),
		"+15%% damage (%d -> %d)" % [base, p.slash_damage])
	check(Shop.status("kettleforge_smith", 0, p) == "owned", "one first temper per blade")
	GameState.data.meteor_shards = 1
	check(Shop.buy("kettleforge_smith", 1, p), "bought Temper Blade II")
	check(p.slash_damage == roundi(base * 1.3), "+30%% in all (%d)" % p.slash_damage)
	check(Shop.status("kettleforge_smith", 1, p) == "owned", "and that is the most a blade takes")
	check(Shop.buy("hearthroot_arms", 0, p), "a new blade")
	check(p.slash_damage == 11 and Shop.status("kettleforge_smith", 0, p) == "", "starts untempered")


func test_the_second_temper_costs_a_meteor_shard() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	p.gold = 5000
	check(Shop.buy("kettleforge_smith", 0, p), "Temper Blade I needs gold alone")
	check(Shop.status("kettleforge_smith", 1, p) == "shards", "Temper Blade II waits for a Stillglass Shard")
	check(not Shop.buy("kettleforge_smith", 1, p) and p.gold == 4300, "and can't be bought without one")
	var shard := ItemPickup.new()
	shard.kind = ItemPickup.KIND_BY_CHAR["("]
	w.room.add_child(shard)
	shard.grant(p)
	check(int(GameState.data.meteor_shards) == 1, "a Stillglass Shard picked up is carried")
	check(Shop.status("kettleforge_smith", 1, p) == "", "now the smith can fold it in")
	check(Shop.buy("kettleforge_smith", 1, p), "bought Temper Blade II")
	check(int(GameState.data.meteor_shards) == 0 and p.gold == 2700, "it spends the shard and the gold")
	check(GameState.temper_level("short_sword") == 2, "the short sword is tempered twice")
	check(Shop.buy("hearthroot_arms", 0, p) and Shop.buy("kettleforge_smith", 0, p), "a new blade, tempered once")
	check(Shop.status("kettleforge_smith", 1, p) == "shards", "each blade's second temper takes its own shard")


func test_the_world_holds_a_meteor_shard_for_every_blade() -> void:
	var found := 0
	var zones := {}
	for zone in DirAccess.get_directories_at("res://levels"):
		for f in DirAccess.get_files_at("res://levels/" + zone):
			if not f.ends_with(".room"):
				continue
			var text := FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, f])
			var n := text.substr(text.find("\n---\n") + 5).count("(")
			found += n
			if n > 0:
				zones[zone] = true
	var blades := 0
	for id: String in GameData.table("items"):
		if String(GameData.item(id).get("kind", "")) == "blade":
			blades += 1
	check(found >= blades, "%d Stillglass Shards in the world for %d blades" % [found, blades])
	check(zones.has("tower"), "one lies in the Tower, near the smith who uses them")
	check(zones.size() >= 4, "they are spread over %d zones" % zones.size())


func test_the_kettleforge_lift_runs_once_durgan_falls() -> void:
	var w := make_world({}, "tower/kettleforge")
	await frames(2)
	var cage: LiftCage = _find(w.room, LiftCage)
	check(cage != null and cage.destination()[0] == "tower/foot", "Kettleforge has a lift down to the Tower Foot")
	cage.interact(w.player)
	await frames(3)
	check(w.room.id == "tower/kettleforge", "it hangs still while Durgan holds the city")
	GameState.set_flag("boss:durgan")
	cage.interact(w.player)
	await frames(3)
	check(w.room.id == "tower/foot", "once freed, it carries you down")
	check(not w.room.is_solid_at(w.player.global_position + Vector2(0, -8)), "onto open floor")
	var back: LiftCage = _find(w.room, LiftCage)
	check(back != null and absf(back.global_position.x - w.player.global_position.x) < 24.0, "beside the cage at the bottom")
	back.interact(w.player)
	await frames(3)
	check(w.room.id == "tower/kettleforge", "and back up again")


## Pass 419: the lift by the buttons. Bible 3's elevator back to Hearthroot was
## only ever run by calling the cage's `interact` and the menu's `confirm`
## from the test. Here Up is pressed at the cage for real: while Durgan
## holds Kettleforge it hangs still and opens nothing; once she falls, Up opens
## the stops, Down moves to the Tower Foot, and Jump rides there.
func test_the_lift_answers_the_real_controller() -> void:
	var w := make_world({}, "hearthroot/east_gate")
	var p := w.player
	var menu := ListMenu.new()
	arena.add_child(menu)
	await frames(2)
	var gate: LiftCage = _find(w.room, LiftCage)
	p.teleport(Vector2(gate.global_position.x, gate.global_position.y))
	p.input = PlayerInput.new()
	await frames(10)
	check(p.is_on_floor() and absf(p.global_position.x - gate.global_position.x) < 8.0, "standing in the cage")
	await _tap_for_real("move_up")
	await frames(3)
	check(w.room.id == "hearthroot/east_gate" and not menu.is_open, "Up while Kettleforge is held: the cage hangs still")
	GameState.set_flag("boss:durgan")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap_for_real("move_up")
	check(menu.is_open and menu.title == "Kettleforge Lift" and arena.get_tree().paused, "once she falls, Up opens the lift's stops")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	var at := func() -> String: return String(menu.rows[menu.cursor].label)
	check(at.call() == "Kettleforge", "on Kettleforge first (%s)" % at.call())
	await _tap_for_real("move_down")
	check(at.call() == "Tower Foot", "Down moves to the Tower Foot (%s)" % at.call())
	await _tap_for_real("jump")
	await frames(3)
	check(w.room.id == "tower/foot" and not menu.is_open and not arena.get_tree().paused, "Jump rides there and the game runs on (in %s)" % w.room.id)
	check(not w.room.is_solid_at(w.player.global_position + Vector2(0, -8)), "onto open floor")
	menu.free()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("The lift by the buttons (pass 419)"), "the bible says so")


func test_the_lift_runs_down_the_heartwood_to_hearthroot() -> void:
	# Bible 3: the elevator shortcut back to Hearthroot. The cage offers its other stops.
	var w := make_world({}, "hearthroot/east_gate")
	await frames(2)
	var gate: LiftCage = _find(w.room, LiftCage)
	check(gate != null and gate.destination()[0] == "tower/foot", "the East Gate of Hearthroot has a lift cage up the heartwood")
	gate.interact(w.player)
	await frames(3)
	check(w.room.id == "hearthroot/east_gate", "it hangs still until Kettleforge is free")
	GameState.set_flag("boss:durgan")
	var menu := ListMenu.new()
	arena.add_child(menu)
	gate.interact(w.player)
	await frames(1)
	var labels := menu.rows.map(func(r: Dictionary) -> String: return r.label)
	check(menu.title == "Kettleforge Lift" and labels == ["Kettleforge", "Tower Foot"], "it offers the other stops (%s)" % [labels])
	menu.cursor = 0
	menu.confirm()
	await frames(3)
	check(w.room.id == "tower/kettleforge", "and carries you up to Kettleforge")
	check(not w.room.is_solid_at(w.player.global_position + Vector2(0, -8)), "onto open floor")
	var top: LiftCage = _find(w.room, LiftCage)
	top.interact(w.player)
	await frames(1)
	menu.cursor = menu.rows.map(func(r: Dictionary) -> String: return r.label).find("Hearthroot, East Gate")
	menu.confirm()
	await frames(3)
	check(w.room.id == "hearthroot/east_gate", "and all the way home again")
	check(not w.room.is_solid_at(w.player.global_position + Vector2(0, -8)), "beside the cage in Hearthroot")
	menu.queue_free()


func test_the_grain_road_joins_the_ringreaders_after_a_spring() -> void:
	var w := make_world({}, "tower/kettleforge")
	await frames(2)
	var menu := ListMenu.new()
	arena.add_child(menu)
	GameState.meet_ringreader("heartwood/amberlee", Vector2(12 * Room.TILE + 8, 20 * Room.TILE))
	var ringreader: Npc = null
	for n in w.room.get_children():
		if n is Npc and (n as Npc).npc_id == "ringreader":
			ringreader = n
	ringreader.interact(w.player)
	await frames(1)
	check(GameState.data.ringreaders.has("tower/kettleforge"), "speaking to a Ringreader marks a stop on the path")
	check(menu.title == "Ringreader" and menu.rows[3].label == "Grain Road", "the Ringreader offers the Grain Road")
	check(not menu.rows[3].enabled, "but it stays dry until a spring flows")
	menu.close()
	GameState.set_flag("spring:heartwood")
	ringreader.interact(w.player)
	await frames(1)
	check(menu.rows[3].enabled, "a restored spring opens it")
	menu.cursor = 3
	menu.confirm()
	check(menu.title == "Grain Road" and menu.rows.size() == 1 and menu.rows[0].label == "Amberlee", "it lists the other Ringreaders met")
	menu.cursor = 0
	menu.confirm()
	await frames(3)
	check(w.room.id == "heartwood/amberlee", "and walks you to one")
	check(not w.room.is_solid_at(w.player.global_position + Vector2(0, -8)), "onto open floor")
	check(absf(w.player.global_position.x - (12 * Room.TILE + 8 + Menus.GRAIN_STEP)) < 4.0, "a step from the Ringreader")
	menu.queue_free()


## Pass 451 (bible 4.4): the Grain Road by the buttons. Up at a Ringreader opens his
## menu, Down walks to "Grain Road", Jump opens it and Jump again walks you to
## the other Ringreader. Play goes on there unpaused, the menu shut, the hero standing
## on the floor a step from him, and the Jump that chose the stop is not taken
## as a jump on arrival.
func test_the_grain_road_is_walked_with_the_buttons() -> void:
	var w := make_world({}, "tower/kettleforge")
	var p := w.player
	p.input = PlayerInput.new()
	var menu := ListMenu.new()
	arena.add_child(menu)
	GameState.meet_ringreader("heartwood/amberlee", Vector2(12 * Room.TILE + 8, 20 * Room.TILE))
	GameState.set_flag("spring:heartwood")
	var ringreader: Npc = null
	for n in w.room.get_children():
		if n is Npc and (n as Npc).npc_id == "ringreader":
			ringreader = n
	p.teleport(ringreader.global_position)
	await frames(6)
	await _tap_for_real("move_up")
	check(menu.is_open and menu.title == "Ringreader", "Up at the Ringreader opens his menu (%s)" % menu.title)
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	var presses := 0
	while menu.cursor != 3 and presses < 6:
		await _tap_for_real("move_down")
		presses += 1
	check(menu.cursor == 3 and menu.rows[3].label == "Grain Road", "Down walks to the Grain Road (%d presses)" % presses)
	await _tap_for_real("jump")
	check(menu.is_open and menu.title == "Grain Road" and menu.rows[0].label == "Amberlee", "Jump opens it, listing Amberlee")
	await frames(int(ListMenu.INPUT_GRACE * 60.0) + 2)
	await _tap_for_real("jump")
	await frames(6)
	check(w.room.id == "heartwood/amberlee", "Jump on Amberlee walks you there (%s)" % w.room.id)
	check(not menu.is_open and not arena.get_tree().paused, "with the menu shut and play going on")
	check(p.is_on_floor() and absf(p.velocity.y) < 1.0, "standing on the floor: the Jump that chose the stop is not a jump (vy %.0f)" % p.velocity.y)
	check(absf(p.global_position.x - (12 * Room.TILE + 8 + Menus.GRAIN_STEP)) < 4.0, "a step from the Ringreader (%.0f)" % p.global_position.x)
	var x0 := p.global_position.x
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	check(p.global_position.x > x0 + 20.0, "and the real Right walks on at once (%.0f px)" % (p.global_position.x - x0))
	menu.queue_free()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("`test_the_grain_road_is_walked_with_the_buttons`"), "the bible names the test")


func test_the_kettleforge_forge_rings_and_throws_sparks() -> void:
	var w := make_world({}, "tower/kettleforge")
	await frames(2)
	var forge: Forge = _find(w.room, Forge)
	check(forge != null, "Kettleforge has a forge beside the smith")
	var before := forge.strikes
	await frames(int(Forge.STRIKE_EVERY * 60.0) + 5)
	check(forge.strikes > before, "the smith's hammer rings on the anvil")
	forge._next_strike = 10.0
	forge.strike()
	check(not forge.sparks.is_empty(), "each strike throws sparks")
	forge._process(0.6)
	check(forge.sparks.is_empty(), "and the sparks die away")
	# The ring carries a little way (Forge.HEAR), then is gone (pass 390).
	var anvil := forge.global_position + Forge.ANVIL
	w.player.global_position = anvil + Vector2(Forge.HEAR - 40.0, 0)
	Sfx.recent.clear()
	forge.strike()
	check(Sfx.recent.has("anvil"), "the anvil rings in the ear of a hero beside it (%s)" % [Sfx.recent])
	w.player.global_position = anvil + Vector2(Forge.HEAR + 40.0, 0)
	Sfx.recent.clear()
	forge.strike()
	check(not Sfx.recent.has("anvil"), "and is not heard past %d px" % int(Forge.HEAR))


func test_the_great_winch_turns_once_kettleforge_is_free() -> void:
	var w := make_world({}, "tower/winch_hall")
	await frames(2)
	var winch: Winch = _find(w.room, Winch)
	check(winch != null, "Winch Hall has its great winch")
	await frames(30)
	check(winch.angle == 0.0, "it stands still while Durgan holds Kettleforge")
	GameState.set_flag("boss:durgan")
	await frames(30)
	check(winch.angle > 0.0, "and turns once the dwarves are free")


func test_the_flue_damper_opens_once_durgan_falls() -> void:
	var w := make_world({}, "tower/foot")
	await frames(2)
	var shut := w.room.get_children().filter(func(n: Node) -> bool: return n is FlueDamper)
	check(shut.size() == 3, "the Tower Foot's ceiling holds a three-tile damper (%d)" % shut.size())
	check(shut.all(func(d: FlueDamper) -> bool: return not d.open), "it is shut while Durgan holds Kettleforge")
	GameState.set_flag("boss:durgan")
	w.travel("tower/winch_hall", cell_feet(5, 19))
	await frames(4)
	w.travel("tower/foot", cell_feet(20, 41))
	await frames(4)
	var opened := w.room.get_children().filter(func(n: Node) -> bool: return n is FlueDamper and not n.is_queued_for_deletion())
	check(opened.size() == 3 and opened.all(func(d: FlueDamper) -> bool: return d.open), "and stands open once the winch turns")


func test_the_smelter_crucible_pours() -> void:
	var w := make_world({}, "tower/smelter")
	await frames(2)
	var c: Crucible = _find(w.room, Crucible)
	check(c != null, "the Smelter has its crucible")
	await frames(40)
	check(not c.sparks.is_empty(), "the pour throws sparks")
	check(c.lip().y < -100.0, "from a pot hung high above the walkway")


func test_a_cartographer_chart_outlines_unseen_rooms() -> void:
	var w := make_world({}, "hearthroot/market")
	await frames(2)
	var p := w.player
	p.gold = 1000
	check(MapScreen.shown("heartwood/entrance", w.catalog["heartwood/entrance"], w.room.id) == "", "unseen rooms are hidden at first")
	var index := -1
	var stock: Array = GameData.shop("hearthroot_charts").stock
	for i in stock.size():
		if stock[i].item == "chart_heartwood":
			index = i
	check(Shop.buy("hearthroot_charts", index, p), "the Cartographer sells the Heartwood chart")
	check(Shop.status("hearthroot_charts", index, p) == "owned", "once")
	check(MapScreen.shown("heartwood/entrance", w.catalog["heartwood/entrance"], w.room.id) == "charted", "and its rooms show, dimmed")
	check(MapScreen.shown("tower/foot", w.catalog["tower/foot"], w.room.id) == "", "other zones stay hidden")
	GameState.visit("heartwood/entrance")
	check(MapScreen.shown("heartwood/entrance", w.catalog["heartwood/entrance"], w.room.id) == "visited", "a visit shows it in full")


func test_map_pins_drop_and_lift_where_you_stand() -> void:
	var w := make_world({}, "hearthroot/market")
	await frames(2)
	var map := MapScreen.new()
	map.world = w
	arena.add_child(map)
	Sfx.recent.clear()
	check(map.pin() == "placed" and GameState.data.pins.size() == 1, "Jump on the map drops a pin where you stand")
	check(map.pin() == "removed" and GameState.data.pins.is_empty(), "and again lifts it")
	check(Sfx.recent == ["pin", "pin_lift"], "a pin goes in with a tick and comes out with its own (%s)" % [Sfx.recent])
	for i in GameState.MAX_PINS:
		GameState.toggle_pin("hearthroot/market", Vector2(i * 100, 0))
	check(GameState.toggle_pin("hearthroot/market", Vector2(5000, 0)) == "full", "pins are limited to %d" % GameState.MAX_PINS)
	Sfx.recent.clear()
	check(map.pin() == "full" and Sfx.recent == ["menu_refuse"], "a full map says no, as a menu does")
	# The parchment (pass 128): the map unrolls and folds with its own sounds.
	Sfx.recent.clear()
	map.toggle()
	check(map.is_open and Sfx.recent == ["map_open"], "opening the map unrolls it (%s)" % [Sfx.recent])
	map.toggle()
	check(not map.is_open and Sfx.recent == ["map_open", "map_close"], "closing folds it (%s)" % [Sfx.recent])
	map.queue_free()


## Sylvarre (pass 50): the elves' town on the leaf road has a Ringreader, a grocer
## and a skywatcher who charts the Haar and the High Boughs.
func test_sylvarre_has_a_ringreader_a_grocer_and_a_skywatcher() -> void:
	var w := make_world({}, "boughs/sylvarre")
	await frames(2)
	var ids: Array = []
	for c in w.room.get_children():
		if c is Npc:
			ids.append((c as Npc).npc_id)
	for id: String in ["ringreader", "sylvarre_grocer", "sylvarre_cartographer", "sylvarre_elder", "sylvarre_warden", "sylvarre_weaver"]:
		check(ids.has(id), "%s lives in Sylvarre" % id)
		check(Sheet.exists("npc_" + id), "and has a sheet (npc_%s)" % id)
	for i in GameData.shop("sylvarre_items").stock.size():
		var entry: Dictionary = GameData.shop("sylvarre_items").stock[i]
		check(GameData.item(entry.item).has("name"), "the grocer's %s is a real item" % entry.item)
	var p := w.player
	p.gold = 2000
	var stock: Array = GameData.shop("sylvarre_charts").stock
	for i in stock.size():
		check(Shop.buy("sylvarre_charts", i, p), "the skywatcher sells %s" % stock[i].item)
	check(GameState.has_chart("haar") and GameState.has_chart("boughs"), "and both zones are charted")
	check(MapScreen.shown("haar/fog_cut", w.catalog["haar/fog_cut"], w.room.id) == "charted", "the Haar shows, dimmed")
	check(p.gold == 2000 - 500 - 650, "for 1,150 gold (%d left)" % p.gold)


## Lampwick (pass 145): the source game's town in the Haar, west of the Feather
## Hollow. It has a Ringreader, the key master bible 10.2 puts there, a fogwalker who
## charts the Haar, and two people who remember the drowned miners.
func test_lampwick_has_a_ringreader_a_keymaster_and_a_fogwalker() -> void:
	var w := make_world({}, "haar/lampwick")
	await frames(2)
	var ids: Array = []
	for c in w.room.get_children():
		if c is Npc:
			ids.append((c as Npc).npc_id)
	for id: String in ["ringreader", "lampwick_keymaster", "lampwick_cartographer", "lampwick_widow", "lampwick_lamplighter"]:
		check(ids.has(id), "%s lives in Lampwick" % id)
		check(Sheet.exists("npc_" + id), "and has a sheet (npc_%s)" % id)
	for id: String in ["lampwick_widow", "lampwick_lamplighter"]:
		check(GameData.npc(id).lines.size() >= 2 and GameData.npc(id).has("lines_cleared"), "%s has her say, and another once the Tree blooms" % id)
	var keys: Array = GameData.shop("lampwick_keys").stock
	var prices := {}
	for entry: Dictionary in keys:
		check(GameData.item(entry.item).has("name"), "the key master's %s is a real item" % entry.item)
		prices[entry.item] = int(entry.price)
	check(prices.get("copper_key") == 150 and prices.get("silver_key") == 400, "he cuts Copper (150 g) and Silver (400 g) keys, at bible 10.1's prices")
	var p := w.player
	p.gold = 1000
	check(Shop.buy("lampwick_keys", keys.find_custom(func(e: Dictionary) -> bool: return e.item == "silver_key"), p), "you can buy a Silver Key")
	check(GameState.key_count("silver") == 1, "and carry it to the Feather Hollow's vault next door")
	check(Shop.buy("lampwick_charts", 0, p) and GameState.has_chart("haar"), "the fogwalker sells the Haar chart")
	check(p.gold == 1000 - 400 - 500, "for 900 gold in all (%d left)" % p.gold)
	# The Ringreader is a stop on the Grain Road like any other.
	var ringreader: Npc = null
	for c in w.room.get_children():
		if c is Npc and (c as Npc).npc_id == "ringreader":
			ringreader = c
	GameState.meet_ringreader(w.room.id, ringreader.global_position)
	check(GameState.data.ringreaders.has("haar/lampwick"), "and Lampwick's Ringreader joins the Grain Road")


## Polesend (pass 148): the stilt town on the black water, under the Scorched
## Hall. Bible 10.2 puts a spell-scroll shop there: Emberfall, a zone before Carillon.
func test_polesend_has_a_ringreader_a_scribe_and_stores() -> void:
	GameState.set_flag("spring:haar")
	var w := make_world({}, "haar/polesend")
	await frames(2)
	var ids: Array = []
	for c in w.room.get_children():
		if c is Npc:
			ids.append((c as Npc).npc_id)
	for id: String in ["ringreader", "polesend_scribe", "polesend_grocer", "polesend_ferryman"]:
		check(ids.has(id), "%s lives in Polesend" % id)
		check(Sheet.exists("npc_" + id), "and has a sheet (npc_%s)" % id)
	var teague := GameData.npc("polesend_ferryman")
	check(teague.lines.size() >= 2 and teague.has("lines_cleared"), "the poler has his say, and another once the Tree blooms")
	for entry: Dictionary in GameData.shop("polesend_items").stock:
		check(GameData.item(entry.item).has("name"), "the stores' %s is a real item" % entry.item)
	var p := w.player
	p.gold = 1500
	var scroll: Dictionary = GameData.shop("polesend_scrolls").stock[0]
	check(scroll.item == "fire_scroll" and int(scroll.price) == 1200, "the scribe sells Emberfall for 1,200 g, as Carillon's does")
	check(Shop.buy("polesend_scrolls", 0, p) and p.abilities.fire, "and the scroll teaches it")
	check(Shop.status("spires_scrolls", 0, p) == "owned", "so Carillon's scroll shows as owned")
	var ringreader: Npc = null
	for c in w.room.get_children():
		if c is Npc and (c as Npc).npc_id == "ringreader":
			ringreader = c
	GameState.meet_ringreader(w.room.id, ringreader.global_position)
	check(GameState.data.ringreaders.has("haar/polesend"), "and Polesend's Ringreader joins the Grain Road")


func test_spires_sells_plate_charts_and_the_fire_scroll() -> void:
	# Bible 10.2: Carillon has a Ringreader, an armorer, the spell-scroll shop (Emberfall,
	# 1,200 g), a grocer and a cartographer.
	var w := make_world({}, "spires/spires")
	await frames(2)
	var ids: Array = []
	for c in w.room.get_children():
		if c is Npc:
			ids.append((c as Npc).npc_id)
	for id: String in ["ringreader", "spires_armorer", "spires_scribe", "spires_grocer", "spires_cartographer", "spires_mayor", "spires_bellkeeper"]:
		check(ids.has(id), "%s lives in Carillon" % id)
		check(Sheet.exists("npc_" + id), "and has a sheet (npc_%s)" % id)
	var p := w.player
	p.gold = 6100
	check(not p.abilities.get("fire", false), "the run starts without Emberfall")
	var scroll: Dictionary = GameData.shop("spires_scrolls").stock[0]
	check(scroll.item == "fire_scroll" and int(scroll.price) == 1200, "the scribe sells Emberfall for 1,200 g")
	check(Shop.buy("spires_scrolls", 0, p), "and you can buy it")
	check(p.abilities.fire and GameState.data.abilities.fire, "the scroll teaches Emberfall for good")
	check(p.equipped_spell == "fire", "with no other spell, Emberfall goes on the Spell button")
	check(Shop.status("spires_scrolls", 0, p) == "owned", "and the scroll shows as owned")
	check(Shop.buy("spires_armor", 0, p), "the armorer sells Knight's Plate")
	check(is_equal_approx(p.defense, 0.45), "which takes 45%% off a hit (%.2f)" % p.defense)
	check(Shop.buy("spires_charts", 0, p) and GameState.has_chart("spires"), "the bell-ringer sells the Carillon chart")
	check(p.gold == 6100 - 1200 - 4200 - 700, "for 6,100 gold in all (%d left)" % p.gold)
	# The Spell button's choice is saved with the rest.
	GameState.capture(p)
	check(GameState.data.spell == "fire", "the save remembers the equipped spell")
	p.equipped_spell = "torrent"
	GameState.apply(p)
	check(p.equipped_spell == "fire", "and puts it back on load")


func test_the_final_tier_comes_with_the_spring_of_sky() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	p.gold = 10000
	var arms: Array = GameData.shop("hearthroot_arms").stock
	var blade := -1
	for i in arms.size():
		if arms[i].item == "dwarvish_broad_sword":
			blade = i
	check(blade >= 0 and int(arms[blade].price) == 2800, "Hearthroot Arms stocks the Dwarvish Broad Sword at 2,800 g")
	check(not Shop.shelf("hearthroot_arms").has(blade), "but not before the Sky Spring")
	check(Shop.status("hearthroot_arms", blade, p) == "hidden" and not Shop.buy("hearthroot_arms", blade, p), "so it can't be bought")
	var stores: Array = GameData.shop("spires_items").stock
	var fruit := stores.size() - 1
	check(stores[fruit].item == "life_fruit" and int(stores[fruit].price) == 2000 and stores[fruit].get("once", false), "Carillon's grocer keeps one Life Fruit for 2,000 g")
	check(Shop.status("spires_items", fruit, p) == "hidden", "off the shelf while the storm lasts")
	GameState.set_flag("spring:sky")
	check(Shop.shelf("hearthroot_arms").has(blade) and Shop.status("hearthroot_arms", blade, p) == "", "the sky road opens and the blade comes in")
	check(Shop.buy("hearthroot_arms", blade, p) and GameState.data.equipment.blade == "dwarvish_broad_sword", "bought the Dwarvish Broad Sword")
	check(p.gold == 7200 and p.reach_bonus == 16.0 and p.arc_bonus == 20.0, "its reach and arc are yours")
	check(Shop.status("hearthroot_arms", 0, p) == "", "the Wayfarer's Sword is still for sale: only what you have counts as owned (pass 186)")
	check(Shop.buy("spires_items", fruit, p) and Shop.status("spires_items", fruit, p) == "sold out", "the fruit is sold once")
	GameState.wear("short_sword", p)
	check(Shop.status("hearthroot_arms", blade, p) == "owned", "put down, the Broad Sword is still yours")


func test_the_wisplight_scroll_is_sold_in_spires() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	var stock: Array = GameData.shop("spires_scrolls").stock
	check(stock[1].item == "wisplight_scroll" and int(stock[1].price) == 2500, "the scriptorium sells Wisplight for 2,500 g")
	p.gold = 2500
	check(not p.abilities.get("wisplight", false), "you start without it")
	check(Shop.buy("spires_scrolls", 1, p) and p.abilities.wisplight, "bought, it is learned")
	check(Shop.status("spires_scrolls", 1, p) == "owned", "and can't be bought twice")
	GameState.data.skills = ["clear_mind", "siphon", "torrent_pierce", "wisplight_swarm"]
	GameState.refresh_stats(p)
	check(p.wisplight_swarm, "the Wisp Swarm skill reaches the player")


## Pass 322: every number a skill's page names is the number the code uses.
## Each skill is learned alone and its effect read back off the hero, so a
## retuned constant can't leave the skill tree promising the old one.
func test_every_skill_page_names_the_number_it_gives() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	var desc := {}
	for n: Dictionary in Skills.nodes():
		desc[n.id] = String(n.desc)
	var saved: Array = GameState.data.skills.duplicate()
	var pct := func(x: float) -> int: return roundi(absf(x) * 100.0)
	var base_mp := p.max_mp
	var base_flask := p.flask_max
	var base_hp := p.max_hp
	var said := {}
	for id: String in ["keen_edge", "keener_edge", "delvers_pick_mastery", "siphon", "thrift", "quick_draught", "gold_sense", "clear_mind", "deep_pockets", "resilience"]:
		GameState.data.skills = [id]
		GameState.refresh_stats(p)
		match id:
			"keen_edge", "keener_edge": said[id] = "+%d%% melee damage" % pct.call(p.melee_mult - 1.0)
			"delvers_pick_mastery": said[id] = "%d%% more damage" % pct.call(p.down_strike_mult - 1.0)
			"siphon": said[id] = "%d%% more MP" % pct.call(p.mp_hit_mult - 1.0)
			"thrift": said[id] = "%d%% less MP" % pct.call(1.0 - p.spell_cost_mult)
			"quick_draught": said[id] = "%d%% faster" % pct.call(1.0 - p.drink_mult)
			"gold_sense": said[id] = "%d%% more gold" % pct.call(p.gold_mult - 1.0)
			"clear_mind": said[id] = "+%d max MP" % roundi(p.max_mp - base_mp)
			"deep_pockets": said[id] = "+%d Sapflask charge" % (p.flask_max - base_flask)
			"resilience": said[id] = "+%d mask of health" % ((p.max_hp - base_hp) / 20)
	GameState.data.skills = saved
	GameState.refresh_stats(p)
	said["bloodletting"] = "heals you %d HP" % Player.BLOODLETTING_HEAL
	said["executioner"] = "%d%% more" % pct.call(p.combat.executioner_mult - 1.0)
	said["thrust"] = "half again a heavy hit" if is_equal_approx(p.combat.thrust_mult, 1.5) else "thrust_mult %.2f" % p.combat.thrust_mult
	said["last_stand"] = "Below %d%% health, you take %d%% less damage" % [pct.call(Player.LAST_STAND_BELOW), pct.call(1.0 - Player.LAST_STAND_TAKEN)]
	said["time_thief"] = "%d s longer" % roundi(Player.TIME_THIEF_EXTRA)
	said["ring_of_death"] = "half its MP" if is_equal_approx(Player.RING_OF_DEATH_MULT, 0.5) else "mult %.2f" % Player.RING_OF_DEATH_MULT
	said["wisplight_swarm"] = "each %d damage" % int(Spells.DATA.wisplight.swarm_damage)
	said["wanderers_grace"] = "%s s longer" % String.num(Player.GRACE_INVULN)
	var wrong := []
	for id: String in said:
		if not String(desc.get(id, "")).contains(said[id]):
			wrong.append("%s should say \"%s\": \"%s\"" % [id, said[id], desc.get(id, "")])
	check(wrong.is_empty(), "every skill page names the number the code gives (%s)" % [wrong])
	check(said.size() >= 18, "and the check covers each skill with a number (%d)" % said.size())
	# The bible's list (9) names the same numbers.
	var tree := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("**Blade (melee)**", 1).get_slice("\n## ", 0)
	var nums := {"Keen Edge": said.keen_edge.get_slice(" ", 0), "Keener Edge": said.keener_edge.get_slice(" ", 0), "Pick Mastery": "+" + said.delvers_pick_mastery.get_slice(" ", 0),
		"Siphon": "+" + said.siphon.get_slice(" ", 0), "Thrift": said.thrift.get_slice(" ", 0), "Quick Draught": said.quick_draught.get_slice(" ", 0),
		"Gold Sense": "+" + said.gold_sense.get_slice(" ", 0), "Clear Mind": said.clear_mind.get_slice(" max", 0),
		"Deep Pockets": said.deep_pockets.get_slice(" Red", 0), "Resilience": said.resilience.get_slice(" of", 0), "Bloodletting": "%d HP" % Player.BLOODLETTING_HEAL,
		"Executioner": "+%d%%" % pct.call(p.combat.executioner_mult - 1.0), "Last Stand": "below %d%% HP, take %d%% less" % [pct.call(Player.LAST_STAND_BELOW), pct.call(1.0 - Player.LAST_STAND_TAKEN)],
		"Time Thief": "%d s longer" % roundi(Player.TIME_THIEF_EXTRA), "Wanderer's Grace": "+%s s" % String.num(Player.GRACE_INVULN), "Wisp Swarm": "3 orbs"}
	var stale := []
	for name: String in nums:
		var line := tree.get_slice(". %s:" % name, 1).get_slice("\n", 0)
		if not line.contains(nums[name]):
			stale.append("%s: \"%s\" lacks %s" % [name, line.strip_edges(), nums[name]])
	check(stale.is_empty(), "the bible's skill list names the code's numbers (%s)" % [stale])


## The Act III tier (pass 100): three more nodes in each branch, each after the
## one before, and a tree that now costs more than the 34 points the game gives (pass 253).
func test_act_three_skills_chain_and_apply() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	GameState.data.skill_points = 40
	var hp0 := p.max_hp
	for id: String in ["riposte", "thrift", "treasure_sense"]:
		check(Skills.status(id) == "locked", id + " waits on the end of its branch")
	for id: String in ["keen_edge", "fourth_strike", "rising_cut", "delvers_pick_mastery", "riposte", "keener_edge", "bloodletting",
			"clear_mind", "siphon", "torrent_pierce", "wisplight_swarm", "thrift", "chain_thunder", "time_thief",
			"deep_pockets", "gold_sense", "quick_draught", "second_stride", "feather_fall", "treasure_sense", "resilience", "last_stand", "second_wind"]:
		check(Skills.learn(id, p), "learned " + id)
	check(p.riposte and p.bloodletting and p.chain_thunder and p.time_thief, "Riposte, Bloodletting, Forked Storm and Time Thief switch on")
	check(p.last_stand and p.second_wind and GameState.has_skill("treasure_sense"), "Treasure Sense, Last Stand and Second Wind are learned")
	check(is_equal_approx(p.melee_mult, 1.2), "Keener Edge stacks with Keen Edge: +20%% (%.2f)" % p.melee_mult)
	check(is_equal_approx(p.spell_cost_mult, 0.85), "Thrift: spells cost 15% less")
	check(p.max_hp == hp0 + GameState.RESILIENCE_HP, "Resilience: one more mask (%d)" % p.max_hp)
	var total := 0
	for n: Dictionary in Skills.nodes():
		total += int(n.cost)
	check(total > 34, "the tree costs more than the game's 34 points, so choices matter (%d)" % total)
	p.gold = 1000
	check(Skills.respec(p) and not p.riposte and p.max_hp == hp0 and is_equal_approx(p.spell_cost_mult, 1.0), "a respec takes them all back")


func _learn_all(p: Player, ids: Array) -> void:
	GameState.data.skill_points = 60
	for id: String in ids:
		Skills.learn(id, p)


const BLADE_TO := ["keen_edge", "fourth_strike", "rising_cut", "delvers_pick_mastery", "riposte", "keener_edge", "bloodletting"]
const ARCANA_TO := ["clear_mind", "siphon", "torrent_pierce", "wisplight_swarm", "thrift", "chain_thunder", "time_thief"]
const WANDERER_TO := ["deep_pockets", "gold_sense", "quick_draught", "second_stride", "feather_fall", "treasure_sense", "resilience", "last_stand", "second_wind"]


func test_riposte_answers_a_parry_with_a_heavy_cut() -> void:
	var w := make_world(_town({Vector2i(9, 19): "D"}), "test/town", cell_feet(6, 19))
	var p := w.player
	_learn_all(p, BLADE_TO.slice(0, 5))
	GameState.data.equipment.shield = "small_shield"
	GameState.refresh_stats(p)
	var dwarf: RotDwarf = _find(w.room, RotDwarf)
	for i in 180:
		if dwarf.state == "windup" and dwarf.state_time >= RotDwarf.WINDUP - 3 / 60.0:
			break
		await frames(1)
	var hp0 := dwarf.hp
	p.input.block_pressed = true
	p.input.block_held = true
	await frames(6)
	check(p.hp == p.max_hp and dwarf.is_staggered(), "the parry lands")
	check(p.ripostes == 1, "and Riposte answers it once")
	check(hp0 - dwarf.hp == roundi(p.heavy_damage * p.melee_mult) or dwarf.dead, "for a heavy hit (%d -> %d)" % [hp0, dwarf.hp])


func test_bloodletting_heals_on_a_staggered_foe() -> void:
	var w := make_world(_town({Vector2i(8, 19): "D"}), "test/town", cell_feet(6, 19))
	var p := w.player
	_learn_all(p, BLADE_TO)
	var dwarf: RotDwarf = _find(w.room, RotDwarf)
	dwarf.max_hp = 999
	dwarf.hp = 999
	await frames(3)
	# Hold the dwarf still: this is about the heal, not its swing.
	dwarf.set_physics_process(false)
	p.hp = 50
	p.facing = 1
	Sfx.recent.clear()
	p.input.attack_pressed = true
	await frames(2)
	check(p.hp == 50, "a hit on a foe on its feet heals nothing (%d)" % p.hp)
	check(not Sfx.recent.has(Player.BLOODLET_SOUND), "and makes no Bloodletting sound")
	await frames(30)
	dwarf.stagger()
	p.input.attack_pressed = true
	await frames(2)
	check(p.hp == 50 + Player.BLOODLETTING_HEAL, "a hit on a staggered foe heals 2 (%d)" % p.hp)
	# Heard (pass 318): the heal had been silent, felt only on the masks.
	check(Sfx.recent.has(Player.BLOODLET_SOUND), "and the heal is heard (%s)" % [Sfx.recent])
	var heal := _peak(Player.BLOODLET_SOUND)
	var blow := _peak("hit")
	check(heal < blow * 0.6, "under the blow that earns it (peak %.2f against %.2f)" % [heal, blow])


## Thrust (pass 149, bible 9): the Blade branch's eighth node. Hold Attack
## through the first cut, and letting go past 0.4 s lunges for half again a
## heavy hit. In the air it strikes in place; a blow spends the charge.
func test_thrust_charges_and_lunges() -> void:
	var w := make_world(_town({Vector2i(26, 19): "M"}), "test/town", cell_feet(8, 19))
	var p := w.player
	var mono: Blinkhop = _find(w.room, Blinkhop)
	mono.max_hp = 999
	mono.hp = 999
	mono.set_physics_process(false)
	await frames(3)
	check_near(p.combat.thrust_charge, 0.4, 0.0001, "the charge takes 0.4 s")
	check_near(p.combat.thrust_mult, 1.5, 0.0001, "for half again a heavy hit")
	check(String(GameData.skill("thrust").needs) == "bloodletting" and int(GameData.skill("thrust").cost) == 2, "Thrust costs 2, after Bloodletting")
	# Without the skill, a held button is only a cut.
	p.facing = 1
	p.input.attack_pressed = true
	p.input.attack_held = true
	await frames(40)
	p.input.attack_held = false
	await frames(2)
	check(p.thrusts == 0 and not p.thrust_ready(), "without Thrust, holding Attack does nothing more")
	await frames(30)
	_learn_all(p, BLADE_TO + ["thrust"])
	check(p.thrust, "the skill reaches the player")
	# A tap is a cut, never a thrust.
	p.input.attack_pressed = true
	p.input.attack_held = true
	await frames(5)
	p.input.attack_held = false
	await frames(30)
	check(p.thrusts == 0 and p.swing_count > 0, "a tap is only a cut")
	# Held: the press cuts at once, the charge comes ready at 0.4 s.
	var x0 := p.global_position.x
	var swings := p.swing_count
	p.input.attack_pressed = true
	p.input.attack_held = true
	await frames(2)
	check(p.swing_count == swings + 1 and p.attack_kind == "side", "the press still cuts at once")
	await frames(19)
	check(not p.thrust_ready(), "not ready at 0.35 s")
	await frames(5)
	check(p.thrust_ready(), "ready by 0.43 s")
	p.input.attack_held = false
	await frames(1)
	check(p.thrusts == 1 and p.attack_kind == "thrust" and p.is_attacking, "letting go thrusts")
	await frames(12)
	var lunge := p.global_position.x - x0
	check(lunge > 35.0 and lunge < 80.0, "on the floor it lunges forward (%.0f px)" % lunge)
	# At a foe: the point reaches farther than a cut and bites for the full sum.
	await frames(30)
	p.teleport(mono.global_position + Vector2(-60, 0))
	p.facing = 1
	await frames(2)
	p.input.attack_pressed = true
	p.input.attack_held = true
	await frames(27)
	p.input.attack_held = false
	await frames(12)
	var want := roundi(p.heavy_damage * 1.5 * p.blade_mult())
	check(999 - mono.hp == want, "a thrust deals %d (heavy %d x 1.5 x %.1f), expected %d" % [999 - mono.hp, p.heavy_damage, p.blade_mult(), want])
	check(p.global_position.x < mono.global_position.x - 8.0, "and the lunge stops at the foe, not inside it")
	# In the air it strikes where you are.
	await frames(30)
	mono.queue_free()
	p.teleport(cell_feet(10, 19))
	await frames(5)
	p.input.attack_pressed = true
	p.input.attack_held = true
	await frames(16)
	p.input.jump_pressed = true
	p.input.jump_held = true
	await frames(12)
	check(not p.is_on_floor() and p.thrust_ready(), "(charged, in the air)")
	x0 = p.global_position.x
	p.input.attack_held = false
	await frames(10)
	check(p.thrusts == 3 and p.attack_kind == "thrust" and absf(p.global_position.x - x0) < 4.0, "in the air it strikes but carries you nowhere (%.1f px)" % (p.global_position.x - x0))
	p.input.jump_held = false
	# A blow spends the charge.
	var n := 0
	while not p.is_on_floor() and n < 120:
		await frames(1)
		n += 1
	await frames(30)
	p.input.attack_pressed = true
	p.input.attack_held = true
	await frames(28)
	check(p.thrust_ready(), "(charged again)")
	p._invuln_timer = 0.0
	p.take_damage(1)
	await frames(1)
	check(not p.thrust_ready(), "a blow spends the charge")
	p.input.attack_held = false
	await frames(2)
	check(p.thrusts == 3, "so letting go after it doesn't thrust")


func test_thrift_and_time_thief() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	p.abilities["torrent"] = true
	p.abilities["stillstone"] = true
	_learn_all(p, ARCANA_TO)
	await frames(3)
	p.mp = p.max_mp
	p.equipped_spell = "torrent"
	p.input.spell_pressed = true
	await frames(1)
	check_near(p.max_mp - p.mp, Spells.cost("torrent") * 0.85, 0.2, "Thrift: a Deluge costs 15% less")
	TimeStop.reset()
	p.input.stillstone_pressed = true
	await frames(1)
	check_near(TimeStop.total, TimeStop.DURATION + Player.TIME_THIEF_EXTRA, 0.01, "Time Thief: the glass holds a second longer")
	TimeStop.reset()


## Deep Blight (pass 134), the Arcana branch's last node: Witherbloom costs half.
func test_ring_of_death_halves_the_death_spell() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	p.abilities["death"] = true
	p.abilities["torrent"] = true
	_learn_all(p, ARCANA_TO.slice(0, 6))
	check(Skills.status("ring_of_death") == "locked", "Deep Blight waits on Time Thief")
	_learn_all(p, ARCANA_TO + ["ring_of_death"])
	check(p.ring_of_death and int(GameData.skill("ring_of_death").cost) == 3, "it costs 3 points and switches on")
	check_near(p.spell_cost("death"), Spells.cost("death") * 0.85 * Player.RING_OF_DEATH_MULT, 0.01, "Witherbloom costs half, after Thrift (%.1f)" % p.spell_cost("death"))
	check_near(p.spell_cost("torrent"), Spells.cost("torrent") * 0.85, 0.01, "other spells only get Thrift")
	await frames(3)
	p.mp = p.max_mp
	p.equipped_spell = "death"
	p.input.spell_pressed = true
	await frames(1)
	check_near(p.max_mp - p.mp, 17.0, 0.2, "a cast takes 17 MP, not 34 (%.1f)" % (p.max_mp - p.mp))
	p.gold = 1000
	check(Skills.respec(p) and is_equal_approx(p.spell_cost("death"), Spells.cost("death")), "a respec puts Witherbloom back at 40")


func test_chain_thunder_leaps_to_two_more_foes() -> void:
	var foes := {Vector2i(10, 19): "D", Vector2i(14, 19): "D", Vector2i(18, 19): "D", Vector2i(36, 19): "D"}
	var w := make_world(_town(foes), "test/town", cell_feet(6, 19))
	var p := w.player
	p.abilities["thunder"] = true
	_learn_all(p, ARCANA_TO.slice(0, 6))
	var dwarves: Array = w.room.get_children().filter(func(c: Node) -> bool: return c is RotDwarf)
	for d: RotDwarf in dwarves:
		d.max_hp = 999
		d.hp = 999
	await frames(3)
	p.facing = 1
	p.mp = p.max_mp
	p.equipped_spell = "thunder"
	p.input.spell_pressed = true
	await frames(20)
	var hit := dwarves.filter(func(d: RotDwarf) -> bool: return d.hp < 999)
	check(hit.size() == 3, "the bolt strikes one and leaps to two more (%d struck)" % hit.size())
	check(dwarves[3].hp == 999, "but not to one far away")


func test_treasure_sense_marks_rooms_with_something_left() -> void:
	var a := grid_rows(40, 23)
	put_tiles(a, 5, 19, "P")
	put_tiles(a, 20, 19, "L")
	put_tiles(a, 30, 19, "$")
	var w := make_world({"test/town": room_text(["name: Town", "zone: test"], a)}, "test/town")
	var p := w.player
	var info: Dictionary = w.catalog["test/town"]
	check(info.treasures == ["test/town:20,19", "test/town:30,19"], "the catalog knows the room's fruit and chest (%s)" % [info.treasures])
	check(MapScreen.unfound(info) == 2, "two things left to find")
	check(not MapScreen.senses_treasure(info, "visited"), "no mark without the skill")
	_learn_all(p, WANDERER_TO.slice(0, 6))
	check(MapScreen.senses_treasure(info, "visited") and MapScreen.senses_treasure(info, "charted"), "with Treasure Sense the map marks it, seen or charted")
	check(not MapScreen.senses_treasure(info, ""), "but never a room the map doesn't show")
	GameState.collect("test/town:20,19")
	GameState.collect("test/town:30,19")
	check(MapScreen.unfound(info) == 0 and not MapScreen.senses_treasure(info, "visited"), "and the mark goes once all is found")


func test_the_map_marks_key_doors_still_shut() -> void:
	# A Silver door and a plain Copper door in a test room.
	var rooms := _town({Vector2i(12, 19): "J", Vector2i(30, 19): "J"}, ["lock: 12, 19, silver"])
	var w := make_world(rooms, "test/town", cell_feet(5, 19))
	var info: Dictionary = w.catalog["test/town"]
	var shut := MapScreen.locked_doors(info)
	check(shut.size() == 2, "the catalog lists both doors (%s)" % [shut])
	check(shut[0].kind == "silver" and shut[0].id == "test/town:12,19" and shut[1].kind == "copper", "with their card and pickup id")
	check(MapScreen.lock_color("silver") == KeyDoor.DOORS.silver.panel and MapScreen.lock_color("sky") == KeyDoor.SHRINE, "each marked in its own door's color")
	GameState.collect("test/town:12,19")
	shut = MapScreen.locked_doors(info)
	check(shut.size() == 1 and shut[0].kind == "copper", "an opened door leaves the map")
	# The real world: every card vault and the sky gate are on the map.
	var real := World.new()
	real.build_catalog()
	var kinds := {}
	for room_id: String in real.catalog:
		for lock: Dictionary in real.catalog[room_id].locks:
			kinds[lock.kind] = room_id
	for kind: String in ["silver", "gold", "thorn", "glass", "sky"]:
		check(kinds.has(kind), "the map knows where the %s door is (%s)" % [kind, kinds])
	check(kinds.get("silver", "") == "haar/feather_hollow", "the Silver vault is in the Feather Hollow")
	real.free()


func test_wanderers_grace_lengthens_the_dash_and_a_kill_gives_it_back() -> void:
	var w := make_world(_town({Vector2i(14, 19): "D"}), "test/town", cell_feet(6, 19))
	var p := w.player
	p.abilities.stride = true
	await frames(2)
	var foe: Enemy = null
	for c in w.room.get_children():
		if c is Enemy:
			foe = c
	check(foe != null, "a foe to kill")
	_learn_all(p, WANDERER_TO)
	check(is_equal_approx(p.dash_invuln(), p.tuning.dash_invuln), "without it, a dash's usual %.2f s" % p.tuning.dash_invuln)
	p.air_dash_charges = 0
	check(not p.on_kill(), "without it, a kill gives nothing back")
	check(Skills.status("wanderers_grace") == "", "Wanderer's Grace opens after Second Wind")
	check(Skills.learn("wanderers_grace", p) and p.wanderers_grace, "learned Wanderer's Grace")
	check(is_equal_approx(p.dash_invuln(), p.tuning.dash_invuln + Player.GRACE_INVULN), "a dash lets harm through 0.1 s longer (%.2f)" % p.dash_invuln())
	p._invuln_timer = 0.0
	p.input.dash_pressed = true
	await frames(1)
	p.input.dash_pressed = false
	check(p.is_dashing and p._invuln_timer > p.tuning.dash_invuln, "and the dash really does (%.3f s left)" % p._invuln_timer)
	await frames(20)
	p.air_dash_charges = 0
	foe.die()
	var full := p.tuning.air_dash_charges + p.bonus_air_dashes
	check(p.air_dash_charges == full, "a kill gives back both air dashes (%d of %d)" % [p.air_dash_charges, full])
	check(not p.on_kill(), "and does nothing when none were spent")
	p.gold = 5000
	check(Skills.respec(p) and not p.wanderers_grace and is_equal_approx(p.dash_invuln(), p.tuning.dash_invuln), "a respec takes it back")


func test_last_stand_and_second_wind() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	_learn_all(p, WANDERER_TO)
	await frames(2)
	p.hp = 100
	p.take_damage(20)
	check(p.hp == 80, "Last Stand does nothing at good health (%d)" % p.hp)
	p._invuln_timer = 0.0
	p.hp = 15
	p.take_damage(8)
	check(p.hp == 9, "below 20%%, a hit does 25%% less (%d)" % p.hp)
	p._invuln_timer = 0.0
	p.take_damage(200)
	check(p.hp == 1 and not p.dead and p.second_wind_used, "Second Wind: a killing blow leaves you at 1 HP")
	p._invuln_timer = 0.0
	p.hp = 5
	p.take_damage(200)
	check(p.dead, "but only once between rests")
	await frames(int(p.combat.respawn_delay * 60.0) + 10)
	check(not p.dead and not p.second_wind_used, "a respawn (like a rest) gives it back")
	p.second_wind_used = true
	p.restore()
	check(not p.second_wind_used, "and so does resting at a shrine")


## Pass 136: Ilse the Dyer in the Market Row sells six cloak dyes (bible 10's
## cosmetic gold sink); one you own is worn again for free, and 100% completion
## puts the glowing Crown Gold on her shelf (bible 11).
func test_the_dyer_dyes_the_cloak() -> void:
	var w := make_world({}, "hearthroot/market")
	await frames(2)
	var dyer: Npc = null
	for c in w.room.get_children():
		if c is Npc and (c as Npc).npc_id == "hearthroot_dyer":
			dyer = c
	check(dyer != null and Sheet.exists("npc_hearthroot_dyer"), "Ilse the Dyer stands in the Market Row, with a sheet")
	var p := w.player
	var stock: Array = GameData.shop("hearthroot_dyes").stock
	var sold := stock.filter(func(e: Dictionary) -> bool: return int(e.price) > 0)
	check(sold.size() == 6, "she sells six dyes (%d)" % sold.size())
	PlayerVisual.body_sets = false  # the ranger's sheet: its own green cloak takes dyes (the key sets have their own test)
	await frames(2)
	check(GameState.dye() == "warden_dye" and PlayerVisual.dye_look().is_empty(), "a new game wears Warden Green, the cloak's own")
	check(p.visual.material == null, "so the sprite is drawn as it is")
	check(Shop.status("hearthroot_dyes", 0, p) == "worn", "which shows as worn")
	p.gold = 300
	check(Shop.buy("hearthroot_dyes", 1, p) and p.gold == 0, "Ember Red costs 300 g")
	await frames(2)
	check(GameState.dye() == "ember_dye" and PlayerVisual.dye_look()[0] == Color("d0453f"), "and goes straight on the cloak")
	var mat := p.visual.material as ShaderMaterial
	check(mat != null and mat.get_shader_parameter("dye") == Color("d0453f"), "the sprite takes the dye's shader")
	check(Shop.status("hearthroot_dyes", 2, p) == "gold", "Tide Blue is out of reach with no gold")
	check(Shop.buy("hearthroot_dyes", 0, p) and GameState.dye() == "warden_dye", "back to Warden Green, for nothing")
	await frames(2)
	check(p.visual.material == null, "and the shader comes off")
	check(Shop.status("hearthroot_dyes", 1, p) == "" and Shop.buy("hearthroot_dyes", 1, p) and p.gold == 0, "Ember again, free: it is yours")
	var lord := stock.size() - 1
	check(stock[lord].item == "lord_dye" and not Shop.shelf("hearthroot_dyes").has(lord), "the Crown Gold is not on the shelf yet")
	check(not Completion.award({"percent": 99}) and not GameState.flag("lord"), "99% of the world is not enough")
	check(Completion.award({"percent": 100}) and Shop.shelf("hearthroot_dyes").has(lord), "100% puts it on the shelf")
	check(Shop.buy("hearthroot_dyes", lord, p) and PlayerVisual.dye_look()[1], "it is given, and it glows")
	PlayerVisual.body_sets = true


## The PixelLab sets draw the cloak in a key green and keep the elf's purple
## hair (design bible 13.5): one shader recolors both, Warden Green included,
## and the hair takes the color chosen on the Equipment page. The helmed set's
## purple crest is not hair.
func test_the_key_green_cloak_and_the_hair_take_their_colors() -> void:
	GameState.new_game()
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	check(p.visual.sheet == "hero_base" and Sheet.flag("hero_base", "key_cloak", false), "the bare elf is a key-green set")
	var mat := p.visual.material as ShaderMaterial
	check(mat != null and mat.shader == PlayerVisual.KEY_SHADER, "so the sprite always wears the key shader")
	check(mat.get_shader_parameter("dye") == PlayerVisual.WARDEN_KEY, "Warden Green on the key: the cloak's own green")
	check(GameState.hair() == "violet" and not mat.get_shader_parameter("hair_on"), "a new game keeps the drawn violet hair")
	GameState.data.dye = "ember_dye"
	GameState.data.hair = "copper"
	await frames(2)
	mat = p.visual.material as ShaderMaterial
	check(mat.get_shader_parameter("dye") == Color("d0453f"), "a dye goes on the key")
	check(mat.get_shader_parameter("hair_on") and mat.get_shader_parameter("hair") == Color(PlayerVisual.HAIR.copper[1]), "the hair takes its color")
	# The shader's keys, on the colors the import keeps: the cloak's key and rim
	# greens, the hair's violets; not the tunic, the plate's violet steel or the outline.
	check(_keyed(Color8(5, 235, 5)) == "cloak" and _keyed(Color8(103, 217, 113)) == "cloak", "the key green and its rim light are cloak")
	check(_keyed(Color8(143, 43, 176)) == "hair" and _keyed(Color8(112, 33, 137)) == "hair", "the hair's violets are hair")
	check(_keyed(Color8(79, 100, 80)) == "" and _keyed(Color8(122, 108, 151)) == "" and _keyed(Color8(68, 58, 92)) == "",
		"the tunic, the violet steel and the outline are neither")
	var rows := Menus.equipment_rows()
	var labels: Array = rows.map(func(r: Dictionary) -> String: return r.label)
	var at := labels.find("Hair")
	check(at > 0 and labels.slice(at + 1) == PlayerVisual.HAIR.values().map(func(h: Array) -> String: return h[0]), "the Equipment page lists every hair color (%s)" % [labels])
	check(rows[labels.find("Copper")].right == "Worn", "marking the one chosen")
	Menus.choose_equipment(Menus.HAIR_PREFIX + "silver", p)
	check(GameState.hair() == "silver", "choosing one colors the hair")
	GameState.data.hair = "no_such_color"
	check(GameState.hair() == "violet", "an unknown color falls back to violet")
	GameState.data.equipment.armor = "elven_plate"
	GameState.data.equipment.helmet = "elven_helm"
	GameState.data.hair = "gold"
	await frames(3)
	mat = p.visual.material as ShaderMaterial
	check(p.visual.sheet == "hero_battle_helm" and not mat.get_shader_parameter("hair_on"), "under the helm no hair shows, so its crest keeps its purple")
	GameState.data.equipment.armor = ""
	GameState.data.equipment.helmet = ""
	GameState.data.dye = ""
	GameState.data.hair = ""


## Which key the hero shader puts `c` under, as hero_dye.gdshader does: "cloak", "hair" or "".
func _keyed(c: Color) -> String:
	var h := c.h
	if h >= 0.25 and h <= 0.42 and c.s > 0.5:
		return "cloak"
	if h >= 0.72 and h <= 0.9 and c.s > 0.5 and c.v > 0.35:
		return "hair"
	return ""


## A plateau that runs down a six-tile ramp, and one that ends at a lip over a pit.
func _lunge_rooms() -> Dictionary:
	var s := grid_rows(40, 23)
	put_tiles(s, 1, 14, "#", 10, 6)
	for i in 6:
		put_tiles(s, 11 + i, 14 + i, "\\")
		put_tiles(s, 11 + i, 15 + i, "#", 1, 5 - i)
	var l := grid_rows(40, 23)
	put_tiles(l, 1, 14, "#", 14, 6)
	return {"test/slope": room_text(["name: Slope", "zone: test"], s), "test/ledge": room_text(["name: Ledge", "zone: test"], l)}


func _charge_and_thrust(p: Player) -> void:
	p.facing = 1
	p.input.attack_pressed = true
	p.input.attack_held = true
	await frames(27)
	p.input.attack_held = false
	await frames(1)


## Pass 153: the lunge is as fast as a dash, so it hugs a ramp the way a ground
## dash does (pass 121), and off a lip you step down at no more than a run.
func test_thrust_lunge_rides_slopes_and_steps_off_ledges() -> void:
	var w := make_world(_lunge_rooms(), "test/slope", cell_feet(10, 13))
	var p := w.player
	_learn_all(p, BLADE_TO + ["thrust"])
	await frames(10)
	var x0 := p.global_position.x
	var y0 := p.global_position.y
	await _charge_and_thrust(p)
	var air := 0
	for i in 14:
		air += 0 if p.is_on_floor() else 1
		await frames(1)
	check(air == 0 and p.global_position.y > y0 + 24.0, "a thrust down a ramp rides it all the way (%d frames in the air, %.0f px down)" % [air, p.global_position.y - y0])
	check(p.global_position.x - x0 > 35.0, "and still lunges its length (%.0f px)" % (p.global_position.x - x0))
	# A ground dash down the same ramp, and the slide out of it, stay on it too.
	await frames(40)
	p.teleport(cell_feet(10, 13))
	await frames(10)
	GameState.data.abilities["stride"] = true
	GameState.apply(p)
	p.facing = 1
	p.input.dash_pressed = true
	await frames(1)
	check(p.is_dashing, "the dash goes")
	air = 0
	for i in 16:
		await frames(1)
		air += 0 if p.is_on_floor() else 1
	check(air == 0, "a ground dash down the ramp and its slide-out never leave it (%d frames in the air)" % air)
	w.queue_free()
	await frames(2)
	# Off a lip: the lunge ends there, at no more than a run.
	w = make_world(_lunge_rooms(), "test/ledge", cell_feet(14, 13))
	p = w.player
	_learn_all(p, BLADE_TO + ["thrust"])
	await frames(10)
	await _charge_and_thrust(p)
	var off_speed := -1.0
	var airborne := 0
	for i in 60:
		await frames(1)
		airborne += 0 if p.is_on_floor() else 1
		if airborne == 2:
			# The frame after the feet leave the lip is the first the lunge sees it.
			off_speed = absf(p.velocity.x)
		if p.is_on_floor() and p.global_position.y > 300.0:
			break
	check(off_speed >= 0.0 and off_speed <= p.tuning.run_speed + 0.5, "the lunge ends at the lip and you step off at no more than a run (%.0f px/s)" % off_speed)
	var past := p.global_position.x - 15 * Room.TILE
	check(p.is_on_floor() and past < 32.0, "and lands within two tiles of it (%.0f px out; a full-speed lunge flew 67)" % past)


## Executioner (pass 163, bible 9): the Blade branch's ninth node, after Thrust.
## Melee blows on a boss in its opening (Enemy.punishable: each boss names its
## own window) land for 35% more; a common foe gets nothing more, and a boss on
## its guard nothing either. Bloodletting heals on a boss's opening too.
func test_executioner_strikes_harder_into_a_bosss_opening() -> void:
	check(String(GameData.skill("executioner").needs) == "thrust" and int(GameData.skill("executioner").cost) == 3, "Executioner costs 3, after Thrust")
	var w := make_world(_town({Vector2i(8, 19): "D"}), "test/town", cell_feet(6, 19))
	var p := w.player
	check_near(p.combat.executioner_mult, 1.35, 0.0001, "for 35% more")
	_learn_all(p, BLADE_TO + ["thrust", "executioner"])
	check(p.executioner, "the skill switches on")
	var dwarf: RotDwarf = _find(w.room, RotDwarf)
	dwarf.max_hp = 999
	dwarf.hp = 999
	await frames(3)
	dwarf.set_physics_process(false)
	p.facing = 1
	var cut := roundi(p.slash_damage * p.blade_mult())
	var blows := []
	for step in 2:
		if step == 1:
			dwarf.add_to_group("boss")
		dwarf.stagger()
		var hp0 := dwarf.hp
		p.hp = 50
		Sfx.recent.clear()
		p.input.attack_pressed = true
		await frames(2)
		blows.append([hp0 - dwarf.hp, p.hp, Sfx.recent.has("execute")])
		await frames(40)
	check(blows[0][0] == cut, "a staggered common foe takes a plain cut (%d, a cut is %d)" % [blows[0][0], cut])
	check(blows[1][0] == roundi(cut * 1.35), "a boss in its opening takes 35%% more (%d)" % blows[1][0])
	check(blows[1][1] == 50 + Player.BLOODLETTING_HEAL, "and Bloodletting heals on it (%d)" % blows[1][1])
	check(blows[1][2] and not blows[0][2], "the blow into the opening cleaves with its own sound, a plain one does not (pass 165)")
	dwarf._stagger = 0.0
	var hp1 := dwarf.hp
	p.input.attack_pressed = true
	await frames(2)
	check(hp1 - dwarf.hp == cut, "a boss on its guard takes a plain cut (%d)" % (hp1 - dwarf.hp))
	# Every boss names its opening (bible 8), so the skill has a window in every fight.
	var dir := "res://scripts/bosses/"
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string(dir + file)
		if not src.contains("add_to_group(\"boss\")") or file in ["likeness.gd", "everbloom_core.gd"]:
			continue
		check(src.contains("func punishable() -> bool") or src.contains("func segment_punishable("), "%s names its opening" % file)


## Pass 186 (Sean): gear you buy or find is kept, and the Equipment page puts
## any of it on; tempers stay with each blade. The Dwarvish Broad Sword (once
## the Giant Blade) takes both hands: no guard or parry while you hold it.
## Pass 193: the source game sold twelve pieces of gear. Each is an item under
## its own name, or bible 5.2's table of what changed names the item that
## took its place; and every id the save renames has a row there.
func test_the_originals_twelve_pieces_of_gear_are_all_here() -> void:
	const ORIGINAL := ["Hand Dagger", "Wayfarer's Sword", "Giant Blade", "Severance",
		"Tanned Jerkin", "Riveted Coat", "Knight's Plate", "Elven Plate",
		"Buckler", "Kite Shield", "Warding Shield", "Elven Helm"]
	var names := {}
	var items := GameData.table("items")
	for id: String in items:
		names[String(items[id].get("name", ""))] = id
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var at := bible.find("**The source game's gear, and what changed")
	check(at >= 0, "bible 5.2 has the table of what changed")
	var table := {}
	for line: String in bible.substr(at, 3000).split("\n"):
		var cells := line.split("|")
		if cells.size() >= 5 and line.begins_with("| ") and not line.begins_with("| Original") and not line.begins_with("|--"):
			table[cells[1].strip_edges()] = cells[2].strip_edges()
	var missing := []
	for name: String in ORIGINAL:
		if names.has(name):
			continue
		var row := String(table.get(name, ""))
		var now := row.get_slice(" (", 0)
		if row == "" or not names.has(now):
			missing.append(name)
	check(missing.is_empty(), "every original piece of gear is an item or has a row naming its heir: %s" % [missing])
	var unrecorded := []
	for old: String in GameState.RENAMED_ITEMS:
		if not bible.substr(at, 3000).contains("from `%s`" % old):
			unrecorded.append(old)
	check(unrecorded.is_empty(), "every renamed id has a row: %s" % [unrecorded])
	check(names.has("Elven Helm") and String(items[names["Elven Helm"]].kind) == "helmet", "the Elven Helm keeps its name in its own slot")


## Every room file, as id -> Room.parse (the gym and the trials included).
func _all_rooms() -> Dictionary:
	var out := {}
	for zone in DirAccess.get_directories_at("res://levels"):
		for f in DirAccess.get_files_at("res://levels/" + zone):
			if f.ends_with(".room"):
				out[zone + "/" + f.get_basename()] = Room.parse(FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, f]))
	return out


## The rooms whose `prop:` lines lay `kind`.
func _rooms_with_prop(rooms: Dictionary, kind: String) -> Array:
	var out := []
	for id: String in rooms:
		for spec: String in rooms[id].lists.get("prop", []):
			if spec.get_slice(",", 2).strip_edges() == kind:
				out.append(id)
	return out


## Pass 233: the source game's gear and goods, each with its old name and a way
## to get it. Three blades past the one you start with, four armors, three
## shields, the Elven Helm, the Amber Draught and the Barkbalm: each is sold by a
## keeper standing in a town, laid in a room, given by a guardian or worn from
## the start, and each ladder climbs (a later blade hits harder, a later armor
## stops more, a later shield wards more). Sean's two renames keep old saves.
func test_the_originals_gear_is_all_here() -> void:
	var rooms := _all_rooms()
	var items := GameData.table("items")
	var npcs := GameData.table("npcs")
	var shops := GameData.table("shops")
	const GEAR := {"short_sword": "Short Sword", "long_sword": "Wayfarer's Sword", "dwarvish_broad_sword": "Dwarvish Broad Sword",
		"severance": "Severance", "leather_armor": "Tanned Jerkin", "riveted_coat": "Riveted Coat",
		"full_plate": "Knight's Plate", "elven_plate": "Elven Plate", "small_shield": "Buckler",
		"large_shield": "Kite Shield", "magic_shield": "Warding Shield", "elven_helm": "Elven Helm",
		"elixir": "Amber Draught", "ointment": "Barkbalm"}
	var wrong := []
	for id: String in GEAR:
		if String(items.get(id, {}).get("name", "")) != GEAR[id]:
			wrong.append(id)
	check(wrong.is_empty(), "the source game's gear keeps its names (wrong: %s)" % [wrong])
	var ways := {}
	for id: String in GameState.fresh().gear:
		ways[id] = "worn from the start"
	for id: String in rooms:
		for spec: String in rooms[id].lists.get("prop", []):
			ways[spec.get_slice(",", 2).strip_edges()] = id
	for npc: String in npcs:
		if npcs[npc].get("role", "") != "shop":
			continue
		var standing := false
		for id: String in rooms:
			for spec: String in rooms[id].lists.get("npc", []):
				standing = standing or spec.get_slice(",", 2).strip_edges() == npc
		if standing:
			for entry: Dictionary in shops[String(npcs[npc].shop)].stock:
				ways[String(entry.item)] = npc
	for boss: String in BossArena.BOSSES:
		for kind: String in ["blade", "armor"]:
			if BossArena.BOSSES[boss].has(kind):
				ways[String(BossArena.BOSSES[boss][kind])] = boss
	var lost := GEAR.keys().filter(func(id: String) -> bool: return not ways.has(id))
	check(lost.is_empty(), "and each can be had: sold, laid, given or worn (no way to: %s)" % [lost])
	var climbs := func(ids: Array, stat: String) -> bool:
		for i in range(1, ids.size()):
			if float(items[ids[i]].get(stat, 0.0)) <= float(items[ids[i - 1]].get(stat, 0.0)):
				return false
		return true
	check(climbs.call(["short_sword", "long_sword", "dwarvish_broad_sword", "severance"], "slash"), "each blade cuts deeper than the last")
	check(climbs.call(["leather_armor", "riveted_coat", "full_plate", "elven_plate"], "defense"), "each armor stops more than the last")
	check(climbs.call(["small_shield", "large_shield", "magic_shield"], "ward"), "each shield wards more than the last")
	check(GameState.RENAMED_ITEMS == {"hand_dagger": "short_sword", "giant_blade": "dwarvish_broad_sword"}, "the Hand Dagger and Giant Blade carry over as Sean renamed them")



## Pass 209: the source game's towns each kept a tool shop and sold keys. Every
## one of the eight has a keeper standing in it who sells goods (an Barkbalm or
## an Amber Draught) and one who sells Copper Keys; the four card keys are each sold a
## zone before their doors, and the Glass is never sold. Bible 10.2's item-shop
## row is held to the shelves: no shop sells anything the items table lacks.
func test_every_town_keeps_the_originals_shops() -> void:
	var rooms := _all_rooms()
	var npcs := GameData.table("npcs")
	var shops := GameData.table("shops")
	var items := GameData.table("items")
	var standing := {}
	for id: String in rooms:
		for spec: String in rooms[id].lists.get("npc", []):
			standing[spec.get_slice(",", 2).strip_edges()] = true
	var sells := {}
	for npc: String in npcs:
		if npcs[npc].get("role", "") != "shop" or not standing.has(npc):
			continue
		var shop: String = npcs[npc].shop
		var town := shop.get_slice("_", 0)
		for entry: Dictionary in shops[shop].stock:
			sells[town + ":" + String(entry.item)] = true
	var no_goods := []
	var no_keys := []
	for town: String in ["hearthroot", "amberlee", "kettleforge", "polesend", "lampwick", "sylvarre", "spires", "vorrhallow"]:
		if not (sells.has(town + ":ointment") or sells.has(town + ":elixir")):
			no_goods.append(town)
		if not sells.has(town + ":copper_key"):
			no_keys.append(town)
	check(no_goods.is_empty(), "every town sells goods, an Barkbalm or an Amber Draught (missing: %s)" % [no_goods])
	check(no_keys.is_empty(), "every town sells Copper Keys (missing: %s)" % [no_keys])
	for card: String in ["silver", "gold", "thorn"]:
		check(sells.keys().any(func(k: String) -> bool: return k.ends_with(":" + card + "_key")), "the %s Key is sold" % card.capitalize())
	check(not sells.keys().any(func(k: String) -> bool: return k.ends_with(":glass_key")), "the Glass Key is only found")
	var unknown := []
	for shop: String in shops:
		for entry: Dictionary in shops[shop].stock:
			if not items.has(String(entry.item)):
				unknown.append("%s: %s" % [shop, entry.item])
	check(unknown.is_empty(), "every shelf sells a real item (%s)" % [unknown])

## Pass 201: the source game's Acorn Charm (the end of the Tower of Suffer, in the
## corner of its guardian's room) and Briar Wand (Sylvarre, up a ladder to the
## right). The Acorn Charm was meant to raise the blade's power (a slip in the
## original's code lowered it instead); the Rod raised Deluge from 6 to 9.
func test_the_pendant_and_the_briar_wand() -> void:
	GameState.new_game()
	check(_rooms_with_prop(_all_rooms(), "pendant") == ["haar/hag_mire"], "the Acorn Charm lies in the Matriarch's Mire")
	check(_rooms_with_prop(_all_rooms(), "briar_wand") == ["boughs/sylvarre"], "the Briar Wand lies in Sylvarre")
	var room := make_room(_GOLD_ROOM)
	var p := make_player(room, Vector2i(2, 3))
	p.abilities["pendant"] = false
	p.abilities["briar_wand"] = false
	await frames(2)
	var plain := p.blade_mult()
	var bolt := Spells.cast("torrent", p) as TorrentBolt
	check(bolt.damage == Spells.DATA.torrent.damage, "without the Rod, Deluge hits for %d" % bolt.damage)
	bolt.free()
	for kind: String in ["pendant", "briar_wand"]:
		var item := ItemPickup.new()
		item.kind = kind
		item.pickup_id = "test:" + kind
		room.add_child(item)
		item.global_position = p.global_position + Vector2(0, -12)
		await frames(2)
		check(p.abilities.get(kind, false) and GameState.is_collected("test:" + kind) and bool(GameState.data.abilities.get(kind, false)),
			"touching the %s takes it, for good" % kind)
	check_near(p.blade_mult(), plain * p.combat.pendant_mult, 0.0001, "the Acorn Charm: every blade hit a tenth harder")
	bolt = Spells.cast("torrent", p) as TorrentBolt
	check(bolt.damage == roundi(Spells.DATA.torrent.damage * 1.5), "the Rod: Deluge half again as hard (%d)" % bolt.damage)
	bolt.free()
	room.free()
	GameState.new_game()


## Pass 189: the shop and the Equipment page give each blade's numbers, and
## the Equipment page changes the cloak's dye anywhere, not only at Ilse's.
func test_the_equipment_page_shows_blade_numbers_and_changes_the_cloak() -> void:
	GameState.new_game()
	check(Menus.blade_numbers("short_sword") == "Cuts 8, heavy 14.", "the Short Sword's numbers (%s)" % Menus.blade_numbers("short_sword"))
	check(Menus.blade_numbers("dwarvish_broad_sword") == "Cuts 17, heavy 32, reach +16, 30% slower.",
		"the Broad Sword says how slow it is (%s)" % Menus.blade_numbers("dwarvish_broad_sword"))
	GameState.data.tempers = {"long_sword": 2}
	var t := 1.0 + GameState.TEMPER_BONUS * 2
	check(Menus.blade_numbers("long_sword").begins_with("Cuts %d, heavy %d, reach +8." % [roundi(11 * t), roundi(19 * t)]), "with its tempers in (%s)" % Menus.blade_numbers("long_sword"))
	var dyer: Array = GameData.shop("hearthroot_dyes").stock
	check(GameData.items_of_kind("dye").size() == dyer.size(), "every dye is on Ilse's shelf (%d of %d)" % [GameData.items_of_kind("dye").size(), dyer.size()])
	check(Menus.cloak_dyes() == ["warden_dye"], "a new cloak has only Warden Green (%s)" % [Menus.cloak_dyes()])
	GameState.data.dyes = ["tide_dye"]
	GameState.earn_dye("slate_dye")
	check(Menus.cloak_dyes() == ["warden_dye", "tide_dye", "slate_dye"], "then each dye bought or won (%s)" % [Menus.cloak_dyes()])
	GameState.set_flag("lord")
	check(Menus.cloak_dyes().has("lord_dye"), "and the Crown Gold once it is yours")
	var rows := Menus.equipment_rows()
	var labels: Array = rows.map(func(r: Dictionary) -> String: return r.label)
	var at := labels.find("Cloak")
	check(at > 0 and rows[at].get("header", false) and labels.slice(at + 1, at + 5) == ["Warden Green", "Tide Blue", "Crown Gold", "Grain Slate"]
		and labels[at + 5] == "Hair", "the page ends with the Cloak and its dyes, then the Hair (%s)" % [labels])
	check(rows[labels.find("Grain Slate")].right == "Worn", "marking the one on")
	check(String(rows[1].detail).contains("Cuts 8, heavy 14."), "a blade's row gives its numbers")
	# Every row's detail fits the menu's box (three lines), the longest gear
	# worn: the Broad Sword held, so a shield's row adds why it is on your back.
	GameState.data.gear = ["short_sword", "long_sword", "dwarvish_broad_sword", "severance", "leather_armor", "riveted_coat",
		"full_plate", "elven_plate", "small_shield", "large_shield", "magic_shield", "elven_helm"]
	GameState.data.equipment = {"blade": "dwarvish_broad_sword", "armor": "elven_plate", "shield": "magic_shield", "helmet": "elven_helm"}
	GameState.data.tempers = {"dwarvish_broad_sword": 2}
	var width := ListMenu.PANEL.size.x - 28
	var long := []
	for row: Dictionary in Menus.equipment_rows():
		var n := PixelFont.wrap_lines(String(row.get("detail", "")), width, 9).size()
		if n > 3:
			long.append("%s: %d lines" % [row.label, n])
	check(long.is_empty(), "every detail fits in three lines: %s" % [long])
	var w := make_world(_town(), "test/town")
	await frames(3)
	GameState.data.dyes = ["tide_dye"]
	Menus.choose_equipment("tide_dye", w.player)
	check(GameState.dye() == "tide_dye", "choosing a dye puts it on, away from the Dyeworks")
	Menus.choose_equipment("night_dye", w.player)
	check(GameState.dye() == "tide_dye", "but not one you don't have")
	Menus.choose_equipment("tide_dye", w.player)
	check(GameState.dye() == "tide_dye", "and choosing the worn one again keeps the cloak dyed")


func test_gear_is_kept_and_swapped_and_the_broad_sword_takes_both_hands() -> void:
	var w := make_world(_town(), "test/town")
	var p := w.player
	await frames(3)
	GameState.set_flag("spring:sky")
	p.gold = 20000
	check(GameState.data.gear == ["short_sword"], "you start with the Short Sword (%s)" % [GameState.data.gear])
	var buy := func(shop: String, id: String) -> bool:
		var stock: Array = GameData.shop(shop).stock
		for i in stock.size():
			if stock[i].item == id:
				return Shop.buy(shop, i, p)
		return false
	check(buy.call("hearthroot_arms", "long_sword") and buy.call("hearthroot_arms", "dwarvish_broad_sword"), "bought the Wayfarer's Sword and the Broad Sword")
	check(buy.call("hearthroot_arms", "small_shield"), "and a Buckler")
	check(GameState.data.gear.has("long_sword") and GameState.data.gear.has("dwarvish_broad_sword"), "both blades are kept (%s)" % [GameState.data.gear])
	check(GameState.data.equipment.blade == "dwarvish_broad_sword" and GameState.two_handed(), "the new one goes in hand, two-handed")
	check(not p.has_shield and not p.reflects, "so the shield stays on your back: no guard, no parry")
	p.input.block_held = true
	p.input.block_pressed = true
	await frames(2)
	check(not p.is_blocking, "Block does nothing while it is held")
	p.input.block_held = false
	GameState.data.tempers["long_sword"] = 2
	GameState.wear("long_sword", p)
	check(GameState.data.equipment.blade == "long_sword" and p.has_shield, "swapped back to the Wayfarer's Sword, the shield comes to hand")
	check(p.slash_damage == roundi(11 * (1.0 + 2 * GameState.TEMPER_BONUS)), "with the Wayfarer's Sword's own tempers (%d)" % p.slash_damage)
	GameState.wear("long_sword", p)
	check(GameState.data.equipment.blade == "long_sword", "a blade can't be taken off")
	GameState.wear("small_shield", p)
	check(GameState.data.equipment.shield == "" and not p.has_shield, "the shield can")
	GameState.wear("magic_shield", p)
	check(GameState.data.equipment.shield == "", "gear you don't have can't be put on")
	var rows := Menus.equipment_rows()
	var labels: Array = rows.map(func(r: Dictionary) -> String: return r.label)
	check(labels.slice(0, 4) == ["Blades", "Short Sword", "Wayfarer's Sword", "Dwarvish Broad Sword"], "the Equipment page lists blades by tier (%s)" % [labels])
	check(labels.has("Off Hand") and labels.has("Buckler"), "and the shields you have, under the Off Hand")
	check(rows[2].right == "Worn", "marking what you wear")
	# A save keeps the gear, and an older save gets what it wore, renamed.
	var src := GameState.fresh()
	src.equipment = {"blade": "giant_blade", "armor": "leather_armor", "shield": "large_shield"}
	src.tempers = {"giant_blade": 1}
	src.erase("gear")
	var got := GameState.sanitize(JSON.parse_string(JSON.stringify(src)))
	check(got.equipment.blade == "dwarvish_broad_sword" and int(got.tempers.dwarvish_broad_sword) == 1, "the Giant Blade is the Dwarvish Broad Sword, tempers kept")
	check(got.gear == ["short_sword", "dwarvish_broad_sword", "leather_armor", "large_shield"], "an old save keeps what it wore (%s)" % [got.gear])


## The gold sheet (design bible 10.1, pass 197): along the critical path, a
## player who opens half the chests and fells each foe once can buy the par kit
## of the damage sheet (5.5) where its shops stand, with no grinding.
## Each step: the zone just walked, then what the par player buys before the next.
const GOLD_PATH := [
	["hearthroot", [["hearthroot_arms", "long_sword"], ["hearthroot_arms", "leather_armor"]]],
	["heartwood", [["amberlee_armor", "riveted_coat"]]],
	["tower", [["kettleforge_smith", "temper_1"]]],
	["haar", []],
	["boughs", []],
	["spires", [["kettleforge_smith", "temper_2"], ["spires_armor", "full_plate"]]],
	["vorrhallow", []],
	["evercrown", []],
]
const _GOLD_ROOM := [
	"############",
	"#..........#",
	"#..........#",
	"#..........#",
	"############",
]
const GOLD_FOES := {
	"M": "blinkhop", "H": "hornet", "D": "rot_dwarf", "T": "sap_spitter", "U": "grub_lump",
	"I": "iron_dwarf", "B": "gear_bat", "K": "minecart_rider", "A": "lantern_ghost",
	"V": "bog_puffcap", "p": "drowned_dwarf", "m": "leaf_mantis", "!": "bark_knight",
	";": "seed_bomber", "?": "marsh_hag", "t": "thunder_beetle", "y": "storm_harpy",
	"]": "spire_sentinel", "q": "crystal_dwarf", "e": "shade_knight", "j": "clockwork_hound",
	"s": "meteor_slug", "l": "spring_eel", ")": "silt_adder",
}


## [chest gold, one pass of foes' gold] in a zone's rooms. Foes pay their
## zone's threat over (Enemy.die, pass 197).
func _zone_gold(zone: String) -> Array[int]:
	var chests := 0
	var foes := 0.0
	var mean := {}
	for f in DirAccess.get_files_at("res://levels/" + zone):
		if not f.ends_with(".room"):
			continue
		var parsed := Room.parse(FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, f]))
		var each := int(parsed.header.get("chest_gold", "100"))
		var over := {}
		for spec: String in parsed.lists.get("chest", []):
			var c := spec.split(",")
			over[Vector2i(int(c[0]), int(c[1]))] = int(c[2])
		var grid: Array = parsed.grid
		for y in grid.size():
			var row: String = grid[y]
			for x in row.length():
				var ch := row[x]
				if ch == "$":
					chests += int(over.get(Vector2i(x, y), each))
				elif GOLD_FOES.has(ch):
					if not mean.has(ch):
						var foe: Enemy = load("res://scripts/enemies/%s.gd" % GOLD_FOES[ch]).new()
						mean[ch] = (foe.gold_min + foe.gold_max) * 0.5
						foe.free()
					foes += mean[ch] * (Enemy.CORRUPT_GOLD if zone == "evercrown" else 1) * float(CombatTuning.ZONE_THREAT.get(zone, 1.0))
	return [chests, roundi(foes)]


func test_the_par_kit_is_affordable_without_grinding() -> void:
	var shops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shops.json"))
	var purse := Npc.KING_GOLD
	for step: Array in GOLD_PATH:
		var zone: String = step[0]
		var gold := _zone_gold(zone)
		purse += gold[0] / 2 + gold[1]
		for buy: Array in step[1]:
			var price := -1
			for entry: Dictionary in shops[buy[0]].stock:
				if entry.item == buy[1]:
					price = int(entry.price)
			check(price > 0, "%s sells %s" % [buy[0], buy[1]])
			purse -= price
			check(purse >= 0, "after %s, half the chests and one pass of foes buy %s (%d g left)" % [zone, buy[1], purse])


func test_a_deep_zones_foes_pay_as_they_hit() -> void:
	var room := Room.from_text("zone: vorrhallow\n---\n" + "\n".join(PackedStringArray(_GOLD_ROOM)))
	arena.add_child(room)
	var foe := Blinkhop.new()
	foe.gold_min = 10
	foe.gold_max = 10
	foe.position = cell_feet(6, 3)
	room.add_child(foe)
	await frames(2)
	foe.die()
	await frames(2)
	var coins := 0
	for c in room.get_children():
		if c is Coin:
			coins += (c as Coin).value
	check(coins == 20, "a Vorrhallow foe's 10 gold comes out as 20 (%d)" % coins)


## Pass 243: the rooms hold what bible 5.1 and 11 count. The Tower and the
## Heartwood had grown 18 Potion Shards against the planned 9, so the flask could
## reach 8 charges where 5 is the most (2 + 9 / 3), and 17 Grain Shards against
## 15, two of them spare forever (15 and the trials' six make seven points).
func test_the_rooms_hold_the_finds_the_bible_counts() -> void:
	var rooms := _all_rooms()
	const COUNTS := {"L": 13, "W": 9, "F": 9, "*": 15, "(": 5}
	var found := {}
	for id: String in rooms:
		if id.begins_with("gym/"):
			continue
		for row: String in rooms[id].grid:
			for ch: String in COUNTS:
				found[ch] = int(found.get(ch, 0)) + row.count(ch)
	for ch: String in COUNTS:
		check(int(found.get(ch, 0)) == COUNTS[ch], "the rooms hold %d of '%s' (%d)" % [COUNTS[ch], ch, int(found.get(ch, 0))])
	check(int(GameState.fresh().flask_max) + COUNTS["F"] / 3 == 5, "every shard fused, the flask holds 5 charges, as 5.1 says")
	check((COUNTS["*"] + 6) % 3 == 0, "the rooms' Grain Shards and the six trials' make whole rings, none spare")



## Pass 349: bible 11's secrets table kept the plan's counts for four kinds of
## secret (18 breakable walls, 10 illusory, 12 key doors, 12 lore tablets) and
## no test read them. This counts each from the rooms: cracked-stone walls
## (each run of `C`), rooms with a fake wall (`%` or a `secret:` cover), card
## doors (each `J` door) and tablets (each cell `sign:` lines carve).
func test_the_secrets_table_counts_the_rooms() -> void:
	var rooms := _all_rooms()
	var walls := 0
	var veiled := 0
	var hiding := 0
	var doors := 0
	var tablets := 0
	for id: String in rooms:
		if id.begins_with("gym/"):
			continue
		var grid: Array = rooms[id].grid
		var fake: bool = not rooms[id].lists.get("secret", []).is_empty()
		if fake:
			hiding += 1
		for y in grid.size():
			var row: String = grid[y]
			fake = fake or row.contains("%")
			for x in row.length():
				var above: String = grid[y - 1] if y > 0 else ""
				if row[x] == "J" and not (x < above.length() and above[x] == "J"):
					doors += 1
		if fake:
			veiled += 1
		walls += _clusters(grid, "C")
		var cells := {}
		for spec: String in rooms[id].lists.get("sign", []):
			cells[spec.get_slice(",", 0).strip_edges() + "," + spec.get_slice(",", 1).strip_edges()] = true
		tablets += cells.size()
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var table := bible.get_slice("## 11. Secrets", 1).get_slice("\n## 12", 0)
	var cell := func(kind: String) -> String:
		return table.get_slice("\n| %s | " % kind, 1).get_slice(" |", 0)
	check(String(cell.call("Breakable walls (Delver's Pick)")).begins_with("%d (" % walls), "11 counts the cracked-stone walls (%d: %s)" % [walls, cell.call("Breakable walls (Delver's Pick)")])
	check(String(cell.call("Illusory walls (Seer's Lens)")).begins_with("%d rooms (" % veiled) and String(cell.call("Illusory walls (Seer's Lens)")).contains("%d of them hiding a room" % hiding), "11 counts the rooms with a fake wall, and those hiding a room (%d, %d: %s)" % [veiled, hiding, cell.call("Illusory walls (Seer's Lens)")])
	var cards := ["copper"]
	for id: String in rooms:
		for spec: String in rooms[id].lists.get("lock", []):
			cards.append(spec.get_slice(",", 2).strip_edges())
	cards.sort()
	check(doors == cards.size() and cards == ["copper", "glass", "gold", "silver", "thorn"], "one door of each card (%d doors: %s)" % [doors, cards])
	check(String(cell.call("Key doors")).begins_with("%d (" % doors), "11 counts the card doors (%d: %s)" % [doors, cell.call("Key doors")])
	check(String(cell.call("Lore tablets")).begins_with("%d (" % tablets), "11 counts the tablets (%d: %s)" % [tablets, cell.call("Lore tablets")])


## How many separate patches of `ch` the grid holds (cells touching side to
## side or top to bottom are one patch).
func _clusters(grid: Array, ch: String) -> int:
	var seen := {}
	var n := 0
	for y in grid.size():
		var row: String = grid[y]
		for x in row.length():
			if row[x] != ch or seen.has(Vector2i(x, y)):
				continue
			n += 1
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var at := c + d
					if at.y < 0 or at.y >= grid.size() or at.x < 0 or at.x >= String(grid[at.y]).length():
						continue
					if String(grid[at.y])[at.x] == ch and not seen.has(at):
						seen[at] = true
						stack.append(at)
	return n

## Pass 261 (bible 3.3, 10.2): "the Cartographer in each town sells the zone
## outline", and every zone the map draws had one but Vorrhallow and the Sunken
## Spring under it, the two zones with the most hidden rooms. Sounder Hulda
## stands in the Drowned Market once Thane Vorrund is at rest and the water is
## down, and charts both. Every zone on the map (all but the Evercrown, the Everbloom no
## one has drawn) now has a chart sold by a keeper who stands in a room.
func test_every_zone_on_the_map_has_a_chart_for_sale() -> void:
	var rooms := _all_rooms()
	var items := GameData.table("items")
	var npcs := GameData.table("npcs")
	var shops := GameData.table("shops")
	var standing := {}
	for id: String in rooms:
		for spec: String in rooms[id].lists.get("npc", []):
			standing[spec.get_slice(",", 2).strip_edges()] = true
	var sold := {}
	for npc_id: String in npcs:
		var shop := String(npcs[npc_id].get("shop", ""))
		if shop == "" or not standing.has(npc_id):
			continue
		for row: Dictionary in shops[shop].stock:
			var item: Dictionary = items.get(String(row.item), {})
			if String(item.get("kind", "")) == "chart":
				sold[String(item.zone)] = true
	var zones := {}
	for id: String in rooms:
		var zone := String(rooms[id].header.get("zone", ""))
		if not id.begins_with("trials/") and not id.begins_with("gym/") and zone != "" and zone != "evercrown":
			zones[zone] = true
	for zone: String in zones:
		check(sold.has(zone), "the %s has a chart for sale" % zone)
	# The sounder herself, once the water is down.
	var w := make_world({}, "vorrhallow/drowned_market")
	await frames(2)
	var here := func() -> bool:
		for c in w.room.get_children():
			if c is Npc and (c as Npc).npc_id == "vorrhallow_cartographer":
				return true
		return false
	check(not here.call(), "no one sounds the halls while they are drowned")
	GameState.set_flag("boss:thane_vorrund")
	w._enter("vorrhallow/drowned_market")
	await frames(2)
	check(here.call() and Sheet.exists("npc_vorrhallow_cartographer"), "once Thane Vorrund is at rest, Sounder Hulda stands in the market")
	var p := w.player
	p.gold = 1550
	check(Shop.buy("vorrhallow_charts", 0, p) and GameState.has_chart("vorrhallow"), "she sells the Vorrhallow chart")
	check(Shop.buy("vorrhallow_charts", 1, p) and GameState.has_chart("sunken"), "and the Sunken Spring's")
	check(p.gold == 0, "for 1,550 gold (%d left)" % p.gold)
	check(MapScreen.shown("sunken/spring_gate", w.catalog["sunken/spring_gate"], w.room.id) == "charted", "and the deeps show on the map, dimmed")


## Pass 265: the source game's Polesend kept a bar, where the bar maid gave useful
## word and a man at the back told stranger things. The remake's Polesend had
## none. Now the Black Water stands by its Ringreader: a house under a tavern sign,
## Barmaid Brigid at its door and Old Cormac beside her. What they tell is true
## of the world: the Acorn Charm in the far corner of the Matriarch's mire past the
## east door, the Haar Wyrm round the Haar Spring past the Dry Cistern, and a
## messenger's boots at Feather Hollow by Lampwick.
func test_polesend_keeps_the_originals_tavern() -> void:
	var rooms := _all_rooms()
	var polesend: Dictionary = rooms["haar/polesend"]
	var at := {}
	for spec: String in polesend.lists.get("npc", []):
		at[spec.get_slice(",", 2).strip_edges()] = int(spec.get_slice(",", 0))
	var houses := []
	for spec: String in polesend.lists.get("prop", []):
		if spec.get_slice(",", 2).strip_edges() == "house":
			houses.append(int(spec.get_slice(",", 0)))
	var sign_x := -100
	for spec: String in polesend.lists.get("sign", []):
		if spec.contains("tavern"):
			sign_x = int(spec.get_slice(",", 0))
	check(at.has("polesend_barmaid") and at.has("polesend_drinker"), "the bar maid and the man at the back stand in Polesend")
	var tavern := houses.filter(func(x: int) -> bool: return absi(x - sign_x) <= 5 and absi(x - int(at.get("polesend_barmaid", -100))) <= 4)
	check(tavern.size() == 1, "by a house under the tavern's sign (sign %d, houses %s)" % [sign_x, houses])
	for id: String in ["polesend_barmaid", "polesend_drinker"]:
		var npc := GameData.npc(id)
		check(npc.get("role", "") == "talk" and npc.lines.size() >= 2 and npc.has("lines_cleared"), "%s has word to give, and another once the Tree blooms" % id)
		check(ResourceLoader.exists("res://assets/sprites/npc_%s.png" % id), "%s has a sheet" % id)
	var brigid := " ".join(GameData.npc("polesend_barmaid").lines)
	check(brigid.contains("Acorn Charm") and brigid.contains("east door") and _rooms_with_prop(rooms, "pendant") == ["haar/hag_mire"], "the Acorn Charm is where Brigid says, past the east door")
	check(str(rooms["haar/hag_mire"].lists.door[0]).contains("haar/polesend"), "and the Matriarch's mire is Polesend's east door")
	check(brigid.contains("Haar Wyrm") and String(rooms["haar/spring_of_haar"].header.get("boss", "")) == "haar_wyrm" and str(rooms["haar/dry_cistern"].lists.door).contains("haar/spring_of_haar"), "the Haar Wyrm lies round the Haar Spring, past the Dry Cistern")
	var cormac := " ".join(GameData.npc("polesend_drinker").lines)
	check(cormac.contains("Feather Hollow") and str(rooms["haar/feather_hollow"].lists.door).contains("haar/lampwick"), "Cormac's Feather Hollow lies by Lampwick")


## Pass 277 (bible 10.2): the shop table gives each staple one price, but
## nothing held the shelves to it. The Kettleforge Forge sold an Barkbalm for 280
## while every other shelf asked 300, and the Cartographer row promised one in
## every town at 200 to 800 g when six towns keep one and the Hearthroot chart is
## 40. Now every shelf's staples cost what the table says, the one-per-shop
## goods stay in their ranges, and the table states each price it holds.
func test_every_shelf_asks_the_shop_tables_price() -> void:
	const FIXED := {"ointment": 300, "elixir": 1500, "copper_key": 150, "silver_key": 400, "gold_key": 900,
		"thorn_key": 1800, "fire_scroll": 1200, "wisplight_scroll": 2500}
	const RANGES := {"mana_dew": [500, 1200], "life_fruit": [800, 2000]}
	var shops := GameData.table("shops")
	var off := []
	var charts := {}
	for id: String in shops:
		var once := {}
		for entry: Dictionary in shops[id].get("stock", []):
			var item := String(entry.get("item", ""))
			var price := int(entry.get("price", 0))
			if FIXED.has(item) and price != FIXED[item]:
				off.append("%s: %s at %d, not %d" % [id, item, price, FIXED[item]])
			if RANGES.has(item):
				if price < RANGES[item][0] or price > RANGES[item][1]:
					off.append("%s: %s at %d, outside %s" % [id, item, price, RANGES[item]])
				once[item] = int(once.get(item, 0)) + 1
			if GameData.item(item).get("kind", "") == "chart":
				charts[id] = true
				if price < 40 or price > 800:
					off.append("%s: %s at %d, outside 40 to 800" % [id, item, price])
		for item: String in once:
			if once[item] > 1:
				off.append("%s: %d %s on one shelf" % [id, once[item], item])
	check(off.is_empty(), "every shelf asks the table's price: %s" % [off])
	var towns := charts.keys().map(func(id: String) -> String: return id.get_slice("_", 0))
	towns.sort()
	check(towns == ["hearthroot", "kettleforge", "lampwick", "spires", "sylvarre", "vorrhallow"], "six towns keep a cartographer, as the table says (%s)" % [towns])
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var at := bible.find("### 10.2 Shops")
	var table := bible.substr(at, bible.find("\n\n", bible.find("| Shop |", at)) - at)
	for said: String in ["Barkbalm (10 s invulnerability, 300 g", "Amber Draught (auto-revive, max 1, 1,500 g)", "Copper (150 g), Silver (400 g), Gold (900 g), Thorn (1,800 g)",
			"Emberfall (1,200 g), Wisplight (2,500 g)", "Mana Dew (one per shop, 500 to 1,200 g)", "Life Fruit (one per shop, 800 to 2,000 g)",
			"| Cartographer | Hearthroot, Kettleforge, Lampwick, Sylvarre, Carillon, Vorrhallow | each zone's chart (40 to 800 g"]:
		check(table.contains(said), "the table says it: %s" % said)



## Pass 333: bible 9 priced the planned tree at 54, the first draft's total,
## though its own list (three branches of twelve) had added up to 68 since that
## draft. These add up the list and hold the built nodes to the code.
func test_the_bible_prices_the_skill_tree_as_built() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var nine := bible.get_slice("## 9. Skill Tree", 1).get_slice("\n## 10. ", 0)
	var lists := nine.get_slice("**Blade (melee)**", 1).get_slice("\n---", 0)
	var line := RegEx.create_from_string("(?m)^\\d+\\. ([^:]+): .*\\[(\\d+)\\]\\s*$")
	var planned := {}
	var plan_total := 0
	for m: RegExMatch in line.search_all(lists):
		planned[m.get_string(1)] = int(m.get_string(2))
		plan_total += int(m.get_string(2))
	check(planned.size() == 36, "the list plans three branches of twelve (%d)" % planned.size())
	check(nine.contains("a tree planned at **%d** in all" % plan_total), "9 states the plan's total as its list adds up (%d)" % plan_total)
	var built_total := 0
	var built := 0
	var wrong := []
	for n: Dictionary in Skills.nodes():
		built += 1
		built_total += int(n.cost)
		if int(planned.get(n.name, -1)) != int(n.cost):
			wrong.append("%s: list [%s], code %d" % [n.name, planned.get(n.name, "none"), n.cost])
	check(wrong.is_empty(), "every built skill is in the list at its own cost (%s)" % [wrong])
	check(nine.contains("(%d as built, over %d nodes)" % [built_total, built]), "9 states the built tree's cost and size (%d over %d)" % [built_total, built])



## Pass 341: the gold sheet (bible 10.1) counts each zone's chests, their range
## and their gold, and the gold a pass of its foes pays, but only the par test
## read the rooms, and it never read the table. The Heartwood had grown from 9
## chests to 12, the Tower from 13 to 20 and the Haar from 8 to 9, 1,970 g the
## table didn't know, and the par purse left after Knight's Plate had grown from
## about 3,700 to over 4,800. This holds every row and that purse to the rooms.
func test_the_gold_sheet_counts_the_rooms() -> void:
	const ROWS := {"Hearthroot": "hearthroot", "Heartwood": "heartwood", "Hollin Tower": "tower", "The Haar": "haar",
		"High Boughs": "boughs", "Carillon": "spires", "Vorrhallow": "vorrhallow", "Sunken Spring": "sunken", "The Evercrown": "evercrown"}
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var ten := bible.get_slice("### 10.1 Currency", 1).get_slice("\n### 10.2", 0)
	var table := ten.get_slice("| Zone | Foe drop (after threat) |", 1).get_slice("\n\n", 0)
	for name: String in ROWS:
		var zone: String = ROWS[name]
		var chests := []
		var lo := 1 << 30
		var hi := 0
		for f in DirAccess.get_files_at("res://levels/" + zone):
			if not f.ends_with(".room"):
				continue
			var parsed := Room.parse(FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, f]))
			var each := int(parsed.header.get("chest_gold", "100"))
			var over := {}
			for spec: String in parsed.lists.get("chest", []):
				var c := spec.split(",")
				over[Vector2i(int(c[0]), int(c[1]))] = int(c[2])
			var grid: Array = parsed.grid
			for y in grid.size():
				var row: String = grid[y]
				for x in row.length():
					var ch := row[x]
					if ch == "$":
						chests.append(int(over.get(Vector2i(x, y), each)))
					elif GOLD_FOES.has(ch):
						var foe: Enemy = load("res://scripts/enemies/%s.gd" % GOLD_FOES[ch]).new()
						var mult := (Enemy.CORRUPT_GOLD if zone == "evercrown" else 1) * float(CombatTuning.ZONE_THREAT.get(zone, 1.0))
						lo = mini(lo, roundi(foe.gold_min * mult))
						hi = maxi(hi, roundi(foe.gold_max * mult))
						foe.free()
		chests.sort()
		var gold := _zone_gold(zone)
		var cells := table.get_slice("\n| %s | " % name, 1).get_slice("\n", 0).trim_suffix(" |").split(" | ")
		check(cells.size() == 4, "the gold sheet has a row for %s" % name)
		if cells.size() != 4:
			continue
		var drop := "none" if hi == 0 else "%d to %d g" % [lo, hi]
		check(cells[0].begins_with(drop), "%s's foes drop %s, and the sheet says %s" % [name, drop, cells[0]])
		var count := "none"
		if chests.size() == 2:
			count = "2: %s and %s" % [_grouped(chests[0]), _grouped(chests[1])]
		elif chests.size() > 0:
			count = "%d: %s to %s" % [chests.size(), _grouped(chests[0]), _grouped(chests[-1])]
		check(cells[1] == count, "%s's chests are %s, and the sheet says %s" % [name, count, cells[1]])
		var total := "none" if gold[0] == 0 else "%s g" % _grouped(gold[0])
		check(cells[2] == total, "%s's chests hold %s, and the sheet says %s" % [name, total, cells[2]])
		if gold[1] == 0:
			check(cells[3] == "none", "%s has no foes, as the sheet says (%s)" % [name, cells[3]])
		else:
			var said := cells[3].trim_prefix("about ").trim_suffix(" g").replace(",", "").to_int()
			check(absi(said - gold[1]) <= 10, "one pass of %s's foes pays %d, and the sheet says %s" % [name, gold[1], cells[3]])
	# The par purse left after Knight's Plate (the par test's last buy).
	var shops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shops.json"))
	var purse := Npc.KING_GOLD
	for step: Array in GOLD_PATH:
		var gold := _zone_gold(step[0])
		purse += gold[0] / 2 + gold[1]
		for buy: Array in step[1]:
			for entry: Dictionary in shops[buy[0]].stock:
				if entry.item == buy[1]:
					purse -= int(entry.price)
			if buy[1] == "full_plate":
				var left := roundi(purse / 100.0) * 100
				check(ten.contains("About %s g is left after Knight's Plate" % _grouped(left)), "10.1 gives the purse left after Knight's Plate (%d, about %s)" % [purse, _grouped(left)])


## A whole number with its thousands grouped, as the bible writes gold.
func _grouped(n: int) -> String:
	return str(n) if n < 1000 else "%d,%03d" % [n / 1000, n % 1000]


## Bible 13.6: Sean's PixelLab shops stand behind their keepers on Market Row.
func test_each_market_keeper_stands_before_their_shop() -> void:
	var market: Dictionary = _all_rooms()["hearthroot/market"]
	var keeper_at := {}
	for spec: String in market.lists.get("npc", []):
		keeper_at[spec.get_slice(",", 2).strip_edges()] = int(spec.get_slice(",", 0))
	var shop_at := {}
	for spec: String in market.lists.get("prop", []):
		shop_at[spec.get_slice(",", 2).strip_edges()] = int(spec.get_slice(",", 0))
	var shops := {"arms_dealer": "shop_arms", "merchant": "shop_sundries", "hearthroot_dyer": "shop_dyeworks", "hearthroot_cartographer": "shop_cartographer"}
	for keeper: String in shops:
		var shop: String = shops[keeper]
		check(shop in SetPiece.NAMES and Sheet.exists(shop), "%s is a packed set piece" % shop)
		check(shop_at.get(shop, -1) == keeper_at.get(keeper, -2), "%s stands before %s" % [keeper, shop])


## Bible 13.6: a set piece's building stays still; only its fire, smoke and lamps move.
func test_a_set_pieces_fire_and_smoke_move_while_the_building_stays_still() -> void:
	for name: String in SetPiece.EFFECTS:
		check(name in SetPiece.NAMES, "%s has living parts and is a set piece" % name)
		for e: Dictionary in SetPiece.EFFECTS[name]:
			check(String(e.kind) in ["fire", "smoke", "lamp", "light"], "%s: %s is a kind the piece draws" % [name, e.kind])
	var piece := SetPiece.new()
	piece.sheet = "shop_arms"
	arena.add_child(piece)
	check(piece.get_node_or_null("Glow") != null, "the smithy's forge glows")
	# Sean's hand-edited smithy animates only its smoke (above the roof), forge and lantern
	# (near their lights): the walls hold still.
	var s := Sheet.get_sheet("shop_arms")
	var img: Image = (s.tex as Texture2D).get_image()
	var cell: Vector2i = Vector2i(s.cell)
	var moved := 0
	var lights: Array[Vector2] = []
	for e: Dictionary in SetPiece.EFFECTS.shop_arms:
		lights.append((s.origin as Vector2) + (e.at as Vector2) * s.density)
	for f in range(1, s.animations.idle.seq.size()):
		for y in range(cell.y * 2 / 5, cell.y):
			for x in cell.x:
				var c := img.get_pixel(f * cell.x + x, y)
				var c0 := img.get_pixel(x, y)
				var near := lights.any(func(p: Vector2) -> bool: return p.distance_to(Vector2(x, y)) <= 22.0)
				# Transparent pixels only differ by the importer's alpha-border fix.
				if (c.a > 0.0 or c0.a > 0.0) and c != c0 and not near:
					moved += 1
	check(s.animations.idle.seq.size() > 1, "the smithy is Sean's animation")
	check(moved == 0, "the smithy's walls hold still in every frame (%d pixels moved)" % moved)
	var lo := 9.0
	var hi := 0.0
	for i in 60:
		var f := SetPiece.flicker(i * 0.05, 3.0)
		lo = minf(lo, f)
		hi = maxf(hi, f)
	check(lo >= 0.5 and hi <= 1.0 and hi - lo > 0.2, "the fire flickers (%.2f to %.2f)" % [lo, hi])
	piece.queue_free()

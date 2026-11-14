class_name Menus
extends RefCounted
## Opens the shop, Ringreader and skill tree menus on the scene's ListMenu. Each
## returns false when there is no menu (tests, headless runs).

## How far from the Ringreader the Grain Road sets you down, in pixels.
const GRAIN_STEP := 32.0


static func _menu(tree: SceneTree) -> ListMenu:
	return tree.get_first_node_in_group("list_menu") as ListMenu


static func _gold_footer(p: Player) -> Callable:
	return func() -> String: return "Gold %d" % p.gold


## A shop's rows as the menu shows them: price or why it can't be bought, and a
## detail line (pulled out of open_shop so a test can read them).
static func shop_rows(shop_id: String, p: Player) -> Array:
	var shop := GameData.shop(shop_id)
	var out := []
	for i in Shop.shelf(shop_id):
		var entry: Dictionary = shop.stock[i]
		var item := GameData.item(entry.item)
		var st := Shop.status(shop_id, i, p)
		var right := "%d g" % int(entry.price)
		if st == "owned":
			right = "Owned"
		elif st == "full":
			right = "Full"
		elif st == "sold out":
			right = "Sold out"
		elif st == "locked":
			right = "Needs I"
		elif st == "enough":
			right = "Enough"
		elif st == "shards":
			right = "Needs shard"
		elif st == "worn":
			right = "Worn"
		elif item.kind == "dye" and GameState.owns_dye(String(entry.item)):
			right = "Wear"
		var detail: String = item.desc
		if item.kind == "key":
			var kind := String(entry.item).trim_suffix("_key")
			detail += "  You have %d." % GameState.key_count(kind)
			if st == "enough":
				detail += " " + ("Its door stands open." if Shop.doors_shut(kind) == 0 else "Enough for every %s door left." % KeyDoor.label(kind))
		elif item.kind == "ointment":
			detail += "  You have %d." % p.ointments
		elif item.kind == "temper":
			var blade := String(GameState.data.equipment.blade)
			detail += "  Your %s: tempered %d of 2." % [GameData.item(blade).get("name", "blade"), GameState.temper_level(blade)]
			if Shop.shards(entry) > 0:
				detail += "  Costs a Stillglass Shard too: you carry %d." % int(GameState.data.get("meteor_shards", 0))
		elif item.kind == "blade":
			detail += "  " + blade_numbers(String(entry.item))
		out.append({"label": item.name, "right": right, "detail": detail, "enabled": st == "", "icon": String(entry.item)})
	return out


## Who keeps a shop: the first person in data/npcs.json whose "shop" it is ("" if
## nobody). Their portrait heads the shop's menu (bible 12.44).
static func keeper(shop_id: String) -> String:
	var people: Dictionary = GameData.table("npcs")
	for id: String in people:
		if String(people[id].get("shop", "")) == shop_id:
			return id
	return ""


static func open_shop(tree: SceneTree, shop_id: String, p: Player) -> bool:
	var menu := _menu(tree)
	if menu == null:
		return false
	var shop := GameData.shop(shop_id)
	var provider := func() -> Array: return shop_rows(shop_id, p)
	var on_select := func(row: int) -> void:
		var i: int = Shop.shelf(shop_id)[row]
		var wearing: bool = GameData.item(shop.stock[i].item).kind == "dye" and GameState.owns_dye(String(shop.stock[i].item))
		var dye: bool = GameData.item(shop.stock[i].item).kind == "dye"
		if Shop.buy(shop_id, i, p):
			# A dye rustles on (pass 137); worn again for free, it costs no coin.
			if not wearing:
				Sfx.play("coin", 0.0, 2.0)
			if dye:
				Sfx.play("cloth", 0.0)
			GameState.toast.emit(("Wearing: " if wearing else "Bought: ") + String(GameData.item(shop.stock[i].item).name))
	menu.open(shop.name, shop.greeting, provider, on_select, _gold_footer(p))
	menu.portrait = keeper(shop_id)
	return true


static func open_ringreader(tree: SceneTree, greeting: String, p: Player, shrine: Node2D) -> bool:
	var menu := _menu(tree)
	if menu == null:
		return false
	var provider := func() -> Array:
		var pts := int(GameState.data.skill_points)
		var rank_line := "Rank: %s. XP %d" % [GameState.rank_name(), int(GameState.data.xp)]
		if GameState.next_rank_xp() > 0:
			rank_line += " of %d for the next rank." % GameState.next_rank_xp()
		var rows := [
			{"label": "Rest and save", "detail": "Restore health, magic and potions, and record your journey. " + rank_line},
			{"label": "Learn skills", "right": "%d pt" % pts, "detail": "Spend skill points. You earn them from ranks, bosses and Grain Shards."},
			{"label": "Unlearn skills", "right": "%d g" % Skills.respec_cost(), "detail": "Forget every skill and get the points back, for a price that rises each time.",
				"enabled": not GameState.data.skills.is_empty() and p.gold >= Skills.respec_cost()},
			_grain_row(tree),
			{"label": "Leave", "detail": "Walk in the light, wanderer."},
		]
		if _here(tree) == Trials.TEMPLE:
			rows.insert(4, _trials_row())
			rows.insert(5, _rush_row())
		return rows
	var on_select := func(i: int) -> void:
		if _here(tree) == Trials.TEMPLE and i >= 4:
			# The Inner Rings and Boss Rush rows sit before Leave in the temple.
			if i == 4:
				open_trials(tree, p)
				return
			if i == 5:
				if BossRush.unlocked():
					menu.close()
					var world := tree.get_first_node_in_group("world") as World
					if world != null:
						BossRush.start(world, p)
				return
			i -= 2
		match i:
			0:
				menu.close()
				if shrine != null and shrine.has_method("rest"):
					shrine.call("rest", p)
			1:
				menu.close()
				open_skills(tree, p)
			2:
				if Skills.respec(p):
					Sfx.play("heal", 0.0)
					GameState.toast.emit("Skills forgotten. Points returned.")
			3:
				open_grain_road(tree, p)
			4:
				menu.close()
	menu.open("Ringreader", greeting, provider, on_select, _gold_footer(p))
	return true


static func _trials_row() -> Dictionary:
	var row := {"label": "Inner Rings", "detail": "Walk a ring made of nothing but footholds.",
		"enabled": Trials.springs_flowing() > 0 and not Trials.built().is_empty()}
	var done := 0
	for t: Dictionary in Trials.built():
		if Trials.cleared(t.id):
			done += 1
	row.right = "%d/%d" % [done, Trials.built().size()]
	if Trials.springs_flowing() == 0:
		row.detail = "The inner rings is dry. Restore a spring and the Ringreader will open it."
	return row


## The boss rush (design bible 11): open once the Tree is whole at 100%.
static func _rush_row() -> Dictionary:
	var row := {"label": "Boss Rush", "enabled": BossRush.unlocked(),
		"detail": "Every guardian of the Tree again, one after another. A third of your health back between fights; fall and the rush ends."}
	if not BossRush.unlocked():
		row.right = "Sealed"
		row.detail = "Sealed. Walk the whole Tree, every room, secret, treasure and guardian, and the Ringreader will open it."
	elif BossRush.best() != INF:
		row.right = Trials.format_time(BossRush.best())
	return row


## The Inner Rings (design bible 3.1): pick an open trial and the ring carries
## you to its start; you come back here when it ends.
static func open_trials(tree: SceneTree, p: Player) -> bool:
	var menu := _menu(tree)
	var world := tree.get_first_node_in_group("world") as World
	if menu == null or world == null:
		return false
	var list := Trials.built()
	var provider := func() -> Array:
		var out := []
		for t: Dictionary in list:
			var row := {"label": String(t.name), "detail": String(t.desc), "enabled": Trials.ready(t)}
			if not Trials.is_open(t):
				row.right = "Sealed"
				row.detail = "Restore %d springs to open it." % int(t.springs)
			elif not Trials.ready(t):
				row.right = "Sealed"
				row.detail = "Its footholds want the %s." % " and the ".join(Trials.missing(t))
			elif Trials.cleared(t.id):
				row.right = Trials.format_time(Trials.best(t.id))
				row.detail += "  Best %s." % Trials.format_time(Trials.best(t.id))
			else:
				row.right = "Open"
				row.detail += "  Clear it for a Grain Shard."
			# Its ring time and the dye it gives (pass 164).
			if t.has("grain") and Trials.ready(t):
				if GameState.owns_dye(String(t.dye)):
					row.detail += "  Within the ring: %s is yours." % GameData.item(t.dye).name
				else:
					row.detail += "  Ring it within %s for %s." % [Trials.format_time(float(t.grain)), GameData.item(t.dye).name]
			out.append(row)
		return out
	var on_select := func(i: int) -> void:
		var t: Dictionary = list[i]
		if not Trials.ready(t):
			return
		menu.close()
		start_trial(world, p, t)
	menu.open("Inner Rings", "The trial begins the moment you arrive. Hazards cost time, not health.", provider, on_select)
	return true


static func start_trial(world: World, p: Player, t: Dictionary) -> void:
	Trials.begin(t.id, world.room.id, p.global_position)
	Sfx.play("trial_begin", 0.0)
	GameState.flash.emit(0.2)
	world.travel(t.room, Trials.start_pos(world.room_text(t.room)))
	p.velocity = Vector2.ZERO


static func _here(tree: SceneTree) -> String:
	var world := tree.get_first_node_in_group("world") as World
	return world.room.id if world != null and world.room != null else ""


static func _grain_row(tree: SceneTree) -> Dictionary:
	var row := {"label": "Grain Road", "detail": "Follow the grain to another Ringreader you have met.",
		"enabled": GameState.grain_road_open() and not GameState.grain_stops(_here(tree)).is_empty()}
	if not GameState.grain_road_open():
		row.detail = "The path between Ringreaders is dry. Restore a spring to walk it."
	elif not row.enabled:
		row.detail = "You have met no other Ringreader yet."
	return row


## Ringreader-to-Ringreader travel (design bible 3.3). You arrive a step from the Ringreader.
static func open_grain_road(tree: SceneTree, p: Player) -> bool:
	var menu := _menu(tree)
	var world := tree.get_first_node_in_group("world") as World
	if menu == null or world == null:
		return false
	var stops := GameState.grain_stops(_here(tree))
	var provider := func() -> Array:
		var out := []
		for id: String in stops:
			var info: Dictionary = world.catalog.get(id, {})
			out.append({"label": String(info.get("name", id)), "right": String(World.ZONES.get(String(info.get("zone", "")), {}).get("name", String(info.get("zone", "")).capitalize())),
				"detail": "Close your eyes and follow the grain."})
		return out
	var on_select := func(i: int) -> void:
		menu.close()
		var at: Array = GameState.data.ringreaders[stops[i]]
		Sfx.play("save", 0.0)
		GameState.flash.emit(0.2)
		world.travel(stops[i], Vector2(float(at[0]) + GRAIN_STEP, float(at[1])))
		p.velocity = Vector2.ZERO
	menu.open("Grain Road", "Every Ringreader hears every other.", provider, on_select)
	return true


## The lift's stops: pick one and the cage carries you there.
static func open_lift(tree: SceneTree, p: Player, cage: LiftCage) -> bool:
	var menu := _menu(tree)
	if menu == null:
		return false
	var stops := cage.other_stops()
	var provider := func() -> Array:
		var out := []
		for stop: Array in stops:
			out.append({"label": String(stop[1]), "detail": "Haul the lever and ride the chain."})
		return out
	var on_select := func(i: int) -> void:
		menu.close()
		cage.ride(p, String(stops[i][0]))
	menu.open("Kettleforge Lift", "The dwarves' chain runs the length of the trunk.", provider, on_select)
	return true


## The skill tree's rows, a header for each branch. Each skill row carries its
## `id`. A skill that works through something not yet found says so (pass 237).
static func skill_rows() -> Array:
	var out := []
	var branch := ""
	for node: Dictionary in Skills.nodes():
		if node.branch != branch:
			branch = node.branch
			out.append({"label": branch, "header": true, "id": ""})
		var st := Skills.status(node.id)
		var right := "%d pt" % int(node.cost)
		if st == "learned":
			right = "Learned"
		var detail: String = node.desc
		if st == "locked":
			detail += "  Needs " + String(GameData.skill(node.needs).name) + " first."
		var waits := Skills.waits_on(node.id)
		if waits != "":
			detail += "  Does nothing until you find the %s." % waits
		out.append({"label": node.name, "right": right, "detail": detail, "enabled": st == "", "id": node.id})
	return out


static func open_skills(tree: SceneTree, p: Player) -> bool:
	var menu := _menu(tree)
	if menu == null:
		return false
	var ids: Array[String] = []
	var provider := func() -> Array:
		var out := skill_rows()
		ids.clear()
		for row: Dictionary in out:
			ids.append(String(row.id))
		return out
	var on_select := func(i: int) -> void:
		if Skills.learn(ids[i], p):
			Sfx.play("rank", 0.0)
			GameState.toast.emit("Learned: " + String(GameData.skill(ids[i]).name))
	var footer := func() -> String: return "Skill points %d" % int(GameState.data.skill_points)
	menu.open("Skills", "Each branch deepens in order. Choose well: points are scarce.", provider, on_select, footer)
	return true


## The pause menu. `p` may be null (no game running). `on_quit` runs on Quit.
static func open_pause(tree: SceneTree, p: Player, on_quit: Callable) -> bool:
	var menu := _menu(tree)
	if menu == null:
		return false
	var provider := func() -> Array:
		var oint := {"label": "Use Barkbalm", "right": "x%d" % p.ointments,
			"detail": "Nothing can hurt you for %d seconds." % int(Player.OINTMENT_TIME),
			"enabled": p.ointments > 0 and p.ointment_left <= 0.0}
		if p.ointment_left > 0.0:
			oint.detail = "One is already on: %d seconds left." % ceili(p.ointment_left)
		elif p.ointments <= 0:
			oint.detail = "You carry none. The item shops in Hearthroot and Amberlee sell them."
		return [
			{"label": "Resume", "detail": "Back to the Tree."},
			oint,
			{"label": "Equipment", "detail": "Swap between the blades, armor, shields and helmets you have, and dye your cloak."},
			{"label": "Inventory", "detail": "Your abilities, spells, relics, rings, keys and shards, and what each does."},
			{"label": "Options", "detail": OPTIONS_DETAIL},
			{"label": "Controls", "detail": CONTROLS_DETAIL},
			{"label": "Journey", "detail": "How much of the world you have seen, and the guardians you have found."},
			{"label": "Quit game", "detail": "Anything since your last rest at a shrine is lost."},
		] + ([{"label": "Leave the trial", "detail": "Stop the clock and return to the Ringreader."}] if Trials.active() else []) \
			+ ([{"label": "Leave the rush", "detail": "Stop the clock and return to the Ringreader."}] if BossRush.active() else [])
	# Backing out of a page lands on the row that opened it (pass 467), so the
	# next Jump does not resume the game from Resume.
	var back_to := func(row: int) -> Callable:
		return func() -> void:
			if open_pause(tree, p, on_quit):
				menu.cursor = row
	var on_select := func(i: int) -> void:
		var reopen: Callable = back_to.call(i)
		match i:
			0:
				menu.close()
			1:
				if p.use_ointment():
					menu.close()
			2:
				open_equipment(tree, p, reopen)
			3:
				open_inventory(tree, p, reopen)
			4:
				open_options(tree, reopen)
			5:
				open_controls(tree, reopen)
			6:
				open_journey(tree, reopen)
			7:
				menu.close()
				Trials.abandon()
				BossRush.abandon()
				on_quit.call()
			8:
				menu.close()
				if BossRush.active():
					var world := tree.get_first_node_in_group("world") as World
					if world != null:
						BossRush.back(world, p)
				else:
					leave_trial(tree)
	menu.open("Paused", "%s. Rank %s." % [_room_title(tree), GameState.rank_name()], provider, on_select, _gold_footer(p))
	return true


## A blade's numbers as you would swing it, tempers included (pass 189), so
## the shop and the Equipment page show what "slow" and "hits harder" mean.
static func blade_numbers(id: String) -> String:
	var blade := GameData.item(id)
	var temper := 1.0 + GameState.TEMPER_BONUS * GameState.temper_level(id)
	var out := "Cuts %d, heavy %d" % [roundi(int(blade.get("slash", 0)) * temper), roundi(int(blade.get("heavy", 0)) * temper)]
	if float(blade.get("reach", 0)) > 0.0:
		out += ", reach +%d" % int(blade.reach)
	var swing := float(blade.get("swing", 1.0))
	if swing > 1.0:
		out += ", %d%% slower" % roundi((swing - 1.0) * 100.0)
	return out + "."


## The cloak dyes you can put on from the Equipment page (pass 189): Warden
## Green, each one bought or won, and the Crown Gold once it is yours.
static func cloak_dyes() -> Array:
	var out := []
	for id: String in GameData.items_of_kind("dye"):
		if id == "warden_dye" or Array(GameState.data.get("dyes", [])).has(id) or (id == "lord_dye" and GameState.flag("lord")):
			out.append(id)
	return out


## Equipment rows for a hair color carry this before the PlayerVisual.HAIR id.
const HAIR_PREFIX := "hair:"
## The Off Hand row that takes the shield off to free the hand for the Rune Dagger.
const OFFHAND_DAGGER := "offhand:rune_dagger"


## The Equipment page (pause menu, pass 186): every blade, armor, shield and
## helmet you have, by slot, and your cloak's dyes (pass 189). Choose one to
## put it on; choose what you wear (not the blade or the cloak) to take it off.
## Back returns to the pause menu.
static func equipment_rows() -> Array:
	var names := {"blade": "Blades", "armor": "Armor", "shield": "Off Hand", "helmet": "Helmets", "neck": "Neck", "ring": "Rings, two worn", "relic": "Relic"}
	var dagger := bool(GameState.data.abilities.get("rune_dagger", false))
	var out := []
	for slot: String in GameState.GEAR_KINDS:
		var have: Array = Array(GameState.data.gear).filter(func(id: String) -> bool: return String(GameData.item(id).get("kind", "")) == slot)
		if have.is_empty() and not (slot == "shield" and dagger):
			continue
		have.sort_custom(func(a: String, b: String) -> bool: return int(GameData.item(a).get("tier", 0)) < int(GameData.item(b).get("tier", 0)))
		out.append({"label": names[slot], "header": true})
		if slot == "shield" and dagger:
			# The off hand holds a shield or the Rune Dagger (Sean, 2026-10-31).
			out.append({"label": "Rune Dagger", "right": "Worn" if GameState.offhand_free() else "",
				"detail": "Thrown from the off hand, so no shield: no guard, parry or ward.", "enabled": true, "id": OFFHAND_DAGGER})
		for id: String in have:
			var item := GameData.item(id)
			var worn := GameState.is_worn(id)
			var detail := String(item.desc)
			var needs := String(item.get("needs", ""))
			if needs != "" and not bool(GameState.data.abilities.get(needs, false)):
				detail += "  It sleeps until you find the %s." % ability_info(needs)[0]
			if slot == "blade":
				detail += "  " + blade_numbers(id)
			if slot == "blade" and GameState.temper_level(id) > 0:
				detail += "  Tempered %d of 2." % GameState.temper_level(id)
			if slot == "shield" and GameState.two_handed():
				detail += "  Slung with a two-hander: no guard or ward."
			if slot == "shield" and dagger:
				detail += "  On the throwing arm: no Rune Dagger."
			if worn and slot != "blade":
				detail += "  Choose it again to take it off."
			out.append({"label": item.name, "right": "Worn" if worn else "", "detail": detail, "enabled": true, "id": id})
	out.append({"label": "Cloak", "header": true})
	for id: String in cloak_dyes():
		var item := GameData.item(id)
		out.append({"label": item.name, "right": "Worn" if GameState.dye() == id else "", "detail": String(item.desc), "enabled": true, "id": id})
	# Hair (Sean, 2026-10-30): the elf's purple is keyed like the cloak, so any color, any time.
	out.append({"label": "Hair", "header": true})
	for hair: String in PlayerVisual.HAIR:
		var chosen := GameState.hair() == hair
		out.append({"label": PlayerVisual.HAIR[hair][0], "right": "Worn" if chosen else "", "detail": "Your own violet." if hair == "violet" else "A different color for your hair.", "enabled": true, "id": HAIR_PREFIX + hair})
	return out


## The Equipment page's footer (pass 229): what all you wear adds up to, as
## refresh_stats works it out. Armor and helmet stack by what each lets
## through, so the Elven Plate under the Elven Helm stops 64%, not 70%; the
## ward is the shield's and the helmet's, capped at GameState.MAX_WARD, and a
## shield on a two-hander's back gives none.
static func worn_totals(p: Player) -> String:
	return "Armor %d%%   Ward %d%%" % [roundi(p.defense * 100.0), roundi(p.magic_ward * 100.0)]


## A row chosen on the Equipment page: gear goes on (or off), a dye on the cloak,
## a color on the hair.
static func choose_equipment(id: String, p: Player) -> void:
	if id == OFFHAND_DAGGER:
		GameState.data.equipment.shield = ""
		GameState.refresh_stats(p)
		GameState.capture(p)
		Sfx.play("gear_on", 0.0)
		return
	if id.begins_with(HAIR_PREFIX):
		GameState.data.hair = id.trim_prefix(HAIR_PREFIX)
		Sfx.play("cloth", 0.0)
		return
	if GameData.item(id).get("kind", "") == "dye":
		if cloak_dyes().has(id):
			GameState.data.dye = id
	else:
		GameState.wear(id, p)
	GameState.capture(p)
	Sfx.play(equipment_sound(id), 0.0)


## What changing `id` sounds like (pass 190): a blade slides from its sheath,
## armor, a shield or a helmet buckles on, and a dye is cloth.
static func equipment_sound(id: String) -> String:
	match String(GameData.item(id).get("kind", "")):
		"blade":
			return "sheathe"
		"dye":
			return "cloth"
	return "gear_on"


static func open_equipment(tree: SceneTree, p: Player, back: Callable) -> bool:
	var menu := _menu(tree)
	if menu == null:
		return false
	# What was found since the last save (the Rune Dagger's Off Hand row) shows at once.
	GameState.capture(p)
	var provider := func() -> Array: return equipment_rows()
	var on_select := func(i: int) -> void:
		var row: Dictionary = equipment_rows()[i]
		if not row.has("id"):
			return
		choose_equipment(String(row.id), p)
	var footer := func() -> String: return worn_totals(p)
	menu.open("Equipment", "What you wear and hold. Armor stops blows; a ward turns sorcery. Tempers stay with each blade.", provider, on_select, footer)
	menu.on_back = back
	return true


## The Journey page (pause menu): Completion's shares as you stand, and the
## guardians found so far. Read only; Back returns to the pause menu.
static func open_journey(tree: SceneTree, back: Callable) -> bool:
	var menu := _menu(tree)
	var world := tree.get_first_node_in_group("world") as World
	if menu == null or world == null:
		return false
	var provider := func() -> Array:
		return Completion.journey_rows(Completion.tally(world.catalog), Completion.guardians_found(world.catalog))
	menu.open("Journey", "Rank %s. %d deaths." % [GameState.rank_name(), int(GameState.data.get("deaths", 0))], provider,
		func(_i: int) -> void: pass)
	menu.on_back = back
	return true


## The Inventory page (pause menu, pass 205): what you have found and carry,
## that the Equipment page does not show. Abilities, spells, relics, the rings
## for the gate of the Evercrown, keys and shards, each with what it does, so a found
## thing is never known only by its banner. Read only; Back returns.
const INVENTORY_GROUPS := [
	["Abilities", ["glove", "delvers_pick", "boots", "stride", "seers_lens", "stillstone", "rune_dagger"]],
	["Spells", ["torrent", "fire", "fracture", "wisplight", "thunder", "death"]],
	["Relics", ["pendant", "briar_wand"]],
]
const RING_NAMES := {"thaw": "Thaw Seed", "sun": "Sun Seed", "fall": "Fall Seed", "frost": "Frost Seed"}
const KEY_ORDER := ["copper", "silver", "gold", "thorn", "glass", "lantern", "sky"]


## The name and the line of a found ability, spell or relic.
static func ability_info(id: String) -> Array:
	if ItemPickup.INFO.has(id):
		return [String(ItemPickup.INFO[id].title), String(ItemPickup.INFO[id].text)]
	if id == "delvers_pick":
		return [String(BossArena.BOSSES.foreman.title), String(BossArena.BOSSES.foreman.text)]
	var scroll := GameData.item(id + "_scroll")
	var name := String(Spells.DATA[id].name)
	var desc := String(scroll.get("desc", "")).trim_prefix("Teaches %s: " % name)
	return [name, desc.left(1).to_upper() + desc.substr(1)]


## The name and the line of a key.
static func key_info(kind: String) -> Array:
	if kind == "glass":
		return [String(ItemPickup.INFO.glass_key.title), String(ItemPickup.INFO.glass_key.text)]
	if kind == "lantern":
		return [String(BossArena.BOSSES.gloamweaver.title), "Gloamweaver's light. It opens the way to the Haar Spring."]
	if kind == "sky":
		return [String(BossArena.BOSSES.skyrend.title), "Skyrend's key. It opens Vorrhallow's upper gate."]
	var item := GameData.item(kind + "_key")
	return [String(item.get("name", KeyDoor.label(kind) + " Key")), String(item.get("desc", ""))]


static func inventory_rows(p: Player) -> Array:
	var out := []
	for group: Array in INVENTORY_GROUPS:
		var have: Array = Array(group[1]).filter(func(id: String) -> bool: return bool(p.abilities.get(id, false)))
		if have.is_empty():
			continue
		out.append({"label": group[0], "header": true})
		for id: String in have:
			var info := ability_info(id)
			var ready: bool = group[0] == "Spells" and p.equipped_spell == id
			out.append({"label": info[0], "right": "Ready" if ready else "", "detail": info[1]})
	var rings: Array = GameState.data.get("rings", [])
	if not rings.is_empty():
		out.append({"label": "Rings, %d of 4" % rings.size(), "header": true})
		for r: String in CrownGate.RINGS:
			if rings.has(r):
				out.append({"label": RING_NAMES[r], "detail": "One of the four rings that open the gate of the Evercrown."})
	var keys := KEY_ORDER.filter(func(k: String) -> bool: return GameState.key_count(k) > 0)
	if not keys.is_empty():
		out.append({"label": "Keys", "header": true})
		for k: String in keys:
			var info := key_info(k)
			out.append({"label": info[0], "right": "x%d" % GameState.key_count(k), "detail": info[1]})
	# What you carry to use (pass 269): the HUD shows an Barkbalm only once one
	# is bought, and the Amber Draught nowhere, so a player could not see it was there.
	var supplies := []
	if p.ointments > 0:
		supplies.append({"label": "Barkbalm", "right": "x%d" % p.ointments, "detail": "Rub one on from the pause menu: nothing can hurt you for 10 seconds."})
	if p.elixirs > 0:
		supplies.append({"label": "Amber Draught", "right": "x%d" % p.elixirs, "detail": "Used by itself when a blow would fell you: it brings you back at full health."})
	if not supplies.is_empty():
		out.append({"label": "Supplies", "header": true})
		out.append_array(supplies)
	# The charts you hold (pass 269): until now only the map showed them, so
	# nothing said which zones were still uncharted.
	var charts := chart_rows()
	if not charts.is_empty():
		out.append_array(charts)
	var shards := []
	var potion := int(GameState.data.get("potion_shards", 0)) % 3
	var grain := int(GameState.data.get("grain_shards", 0)) % 3
	var meteor := int(GameState.data.get("meteor_shards", 0))
	if potion > 0:
		shards.append({"label": "Potion Shards", "right": "%d of 3" % potion, "detail": "Three fuse into a new Sapflask charge."})
	if grain > 0:
		shards.append({"label": "Grain Shards", "right": "%d of 3" % grain, "detail": "Three complete a ring and give a skill point."})
	if meteor > 0:
		shards.append({"label": "Stillglass Shards", "right": "x%d" % meteor, "detail": "The Kettleforge smith folds one into a blade's second temper."})
	if not shards.is_empty():
		out.append({"label": "Shards", "header": true})
		out.append_array(shards)
	if out.is_empty():
		out.append({"label": "Nothing yet", "detail": "What you find on the Tree is kept here."})
	return out


## The Charts group: a header counting the zones charted against every chart
## sold, each chart held, and a line on where the rest are bought.
static func chart_rows() -> Array:
	var items := GameData.table("items")
	var all := []
	for id: String in items:
		if items[id].get("kind", "") == "chart":
			all.append(id)
	var held := all.filter(func(id: String) -> bool: return GameState.has_chart(String(items[id].zone)))
	if held.is_empty():
		return []
	var out := [{"label": "Charts, %d of %d" % [held.size(), all.size()], "header": true}]
	for id: String in held:
		out.append({"label": String(items[id].name), "detail": "Its rooms are drawn on your map, dimmed until you walk them."})
	if held.size() < all.size():
		out.append({"label": "%d not yet charted" % (all.size() - held.size()), "detail": "The towns' cartographers sell the rest.", "enabled": false})
	return out


static func open_inventory(tree: SceneTree, p: Player, back: Callable) -> bool:
	var menu := _menu(tree)
	if menu == null:
		return false
	menu.open("Inventory", "What you have found, and what it does.", func() -> Array: return inventory_rows(p),
		func(_i: int) -> void: pass)
	menu.on_back = back
	return true

static func leave_trial(tree: SceneTree) -> void:
	var world := tree.get_first_node_in_group("world") as World
	if not Trials.active() or world == null:
		return
	var back_room: String = Trials.run.back_room
	var back_pos: Vector2 = Trials.run.back_pos
	Trials.abandon()
	world.travel(back_room, back_pos)


static func _room_title(tree: SceneTree) -> String:
	var w := tree.get_first_node_in_group("world")
	return String(w.get("room").title) if w != null and w.get("room") != null else "The Ylden"


## What the Options row says of the page, on the pause menu and the title
## (pass 381): every row of OPTIONS, the two volumes as one.
const OPTIONS_DETAIL := "Screen shake, flashes, rumble, damage numbers, the mercy assist, volume and game speed."

## And what the Controls row says: both pages rebind the pad as well (pass 365).
const CONTROLS_DETAIL := "Rebind the keys and the pad."

const OPTIONS := [
	["shake", "Screen shake", "How hard the screen shakes on hits and slams."],
	["flashes", "Screen flashes", "The white flash on boss kills and the Amber Draught."],
	["rumble", "Rumble", "Controller vibration."],
	["numbers", "Damage numbers", "Show the damage each blow deals, over what it strikes."],
	["mercy", "Assist: mercy", "After a hit, nothing can hurt you again for twice as long (1.6 s, not 0.8)."],
	["music", "Music volume", ""],
	["sound", "Sound volume", ""],
	["speed", "Game speed", "Slow the whole game down if the action is too fast. Everything slows evenly."],
]


## Options. `back` reopens the menu this came from.
static func open_options(tree: SceneTree, back: Callable) -> bool:
	var menu := _menu(tree)
	if menu == null:
		return false
	var provider := func() -> Array:
		var out := []
		for o: Array in OPTIONS:
			out.append({"label": o[1], "right": Settings.value_text(o[0]), "detail": o[2] + ("  " if o[2] != "" else "") + "Left and Right change it."})
		out.append({"label": "Back", "detail": ""})
		return out
	var on_select := func(i: int) -> void:
		if i < OPTIONS.size():
			Settings.adjust(OPTIONS[i][0], 1)
		else:
			back.call()
	menu.open("Options", "Saved as you change them.", provider, on_select)
	menu.on_adjust = func(i: int, step: int) -> void:
		if i < OPTIONS.size():
			Settings.adjust(OPTIONS[i][0], step)
	menu.on_back = back
	return true


const ACTION_NAMES := {
	"move_left": "Move left", "move_right": "Move right", "move_up": "Look up / enter", "move_down": "Crouch / drop",
	"jump": "Jump", "attack": "Attack", "dash": "Dash", "block": "Block / parry", "spell": "Cast spell", "spell_next": "Next spell",
	"heal": "Drink potion", "stillstone": "Stillstone", "throw": "Throw dagger", "map": "Map",
}


## Rebinding (pass 365 added the pad): choose an action, then press its new
## key or its new pad button.
static func open_controls(tree: SceneTree, back: Callable) -> bool:
	var menu := _menu(tree)
	if menu == null:
		return false
	var provider := func() -> Array:
		var out := []
		for action: String in Settings.REBINDABLE:
			var listening := menu.capture.is_valid() and menu.rows.size() > out.size() and menu.cursor == out.size()
			out.append({"label": ACTION_NAMES[action], "right": "..." if listening else "%s / %s" % [Controls.key_name(action), Controls.button_name(action)],
				"detail": "Jump to rebind, then press the new key or pad button. One taken from another action swaps with it."})
		out.append({"label": "Reset to defaults", "detail": "Put every key and pad button back the way it was."})
		out.append({"label": "Back", "detail": "Start pauses on the pad, as Esc does on the keyboard."})
		return out
	var on_select := func(i: int) -> void:
		var n := Settings.REBINDABLE.size()
		if i < n:
			menu.capture = func(event: InputEvent) -> void:
				if event is InputEventKey:
					if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
						return
					Settings.bind_key(Settings.REBINDABLE[i], int((event as InputEventKey).physical_keycode))
					Sfx.play("blip", 0.0, -4.0)
				elif event is InputEventJoypadButton:
					var b := int((event as InputEventJoypadButton).button_index)
					if b == JOY_BUTTON_START:
						return
					if Settings.bind_button(Settings.REBINDABLE[i], b):
						Sfx.play("blip", 0.0, -4.0)
					else:
						Sfx.play("menu_refuse", 0.0, -4.0)
						GameState.toast.emit("%s stays where it is." % Controls.PAD_NAMES.get(b, "That button"))
		elif i == n:
			Settings.reset_keys()
			GameState.toast.emit("Keys and buttons reset.")
		else:
			back.call()
	menu.open("Controls", "Keys and pad buttons. Esc and Start always pause.", provider, on_select)
	menu.on_back = back
	return true

class_name Shop
extends RefCounted
## Buying from a shop (data/shops.json). Pure logic, so the menu and the tests
## share it.

## Amber Draughts you can carry at once (design bible 10.2).
const ELIXIR_MAX := 1
## Barkbalms you can carry at once.
const OINTMENT_MAX := 3
## Bitterleaf Tonics you can carry at once.
const TONIC_MAX := 3


## The stock indices on the shelf now. An entry with "requires" (a GameState flag)
## stays off the shelf until that flag is set: the final tier comes in on the
## sky road once the Sky Spring is restored (design bible 10.2).
static func shelf(shop_id: String) -> Array[int]:
	var out: Array[int] = []
	var stock: Array = GameData.shop(shop_id).stock
	for i in stock.size():
		var needs := String(stock[i].get("requires", ""))
		if needs == "" or GameState.flag(needs):
			out.append(i)
	return out


## Why an entry can't be bought right now: "" (it can), "hidden" (not on the
## shelf yet), "owned", "full", "sold out", "locked" (a second temper before the
## first), "enough" (the keys you hold already open every door of that card still
## shut), "shards" (too few Stillglass Shards for an entry's "shards") or "gold".
static func status(shop_id: String, index: int, p: Player) -> String:
	var entry: Dictionary = GameData.shop(shop_id).stock[index]
	var item := GameData.item(entry.item)
	if not shelf(shop_id).has(index):
		return "hidden"
	if entry.get("once", false) and GameState.is_collected(_once_id(shop_id, index)):
		return "sold out"
	match item.kind:
		"blade", "armor", "shield", "helmet", "neck", "ring", "relic":
			# Gear you have is kept (pass 186): put it on from the Equipment page.
			if GameState.owns_gear(String(entry.item)):
				return "owned"
		"elixir":
			if p.elixirs >= ELIXIR_MAX:
				return "owned"
		"ointment":
			if p.ointments >= OINTMENT_MAX:
				return "full"
		"tonic":
			if p.tonics >= TONIC_MAX:
				return "full"
		"key":
			var kind := String(entry.item).trim_suffix("_key")
			if GameState.key_count(kind) >= doors_shut(kind):
				return "enough"
		"temper":
			var level := GameState.temper_level(String(GameState.data.equipment.blade))
			if level >= int(item.level):
				return "owned"
			if level < int(item.level) - 1:
				return "locked"
		"chart":
			if GameState.has_chart(String(item.zone)):
				return "owned"
		"spell":
			if p.abilities.get(String(item.spell), false):
				return "owned"
		"dye":
			if GameState.dye() == String(entry.item):
				return "worn"
			if GameState.owns_dye(String(entry.item)):
				return ""
	if int(GameState.data.get("meteor_shards", 0)) < shards(entry):
		return "shards"
	if p.gold < int(entry.price):
		return "gold"
	return ""


## How many of a card's doors in the world still stand shut (pass 245). Each card
## has one door, so a second key of it was gold for nothing.
static func doors_shut(kind: String) -> int:
	var n := 0
	for lock: Dictionary in World.world_locks():
		if lock.kind == kind and not GameState.is_collected(String(lock.id)):
			n += 1
	return n


## Stillglass Shards an entry costs besides its gold (design bible 5.2).
static func shards(entry: Dictionary) -> int:
	return int(entry.get("shards", 0))


static func buy(shop_id: String, index: int, p: Player) -> bool:
	if status(shop_id, index, p) != "":
		return false
	var entry: Dictionary = GameData.shop(shop_id).stock[index]
	var item := GameData.item(entry.item)
	if item.kind == "dye" and GameState.owns_dye(String(entry.item)):
		GameState.data.dye = String(entry.item)
		GameState.capture(p)
		return true
	p.gold -= int(entry.price)
	GameState.data.meteor_shards = int(GameState.data.get("meteor_shards", 0)) - shards(entry)
	match item.kind:
		"blade", "armor", "shield", "helmet", "neck", "ring", "relic":
			GameState.obtain_gear(String(entry.item), p)
		"key":
			GameState.add_key(String(entry.item).trim_suffix("_key"))
		"stat":
			GameState.grant_stat_item(entry.item, p)
		"elixir":
			p.elixirs += 1
		"ointment":
			p.ointments += 1
		"tonic":
			p.tonics += 1
		"temper":
			var tempers: Dictionary = GameState.data.get("tempers", {})
			tempers[String(GameState.data.equipment.blade)] = int(item.level)
			GameState.data.tempers = tempers
			GameState.refresh_stats(p)
		"chart":
			GameState.data.charts[String(item.zone)] = true
		"spell":
			# A scroll teaches its spell for good, and is equipped if nothing else is.
			p.abilities[String(item.spell)] = true
			if not p.abilities.get(p.equipped_spell, false):
				p.equipped_spell = String(item.spell)
		"dye":
			# A new dye goes straight on the cloak.
			var owned: Array = GameState.data.get("dyes", [])
			owned.append(String(entry.item))
			GameState.data.dyes = owned
			GameState.data.dye = String(entry.item)
	if entry.get("once", false):
		GameState.collect(_once_id(shop_id, index))
	GameState.capture(p)
	return true


static func _once_id(shop_id: String, index: int) -> String:
	return "shop:%s:%d" % [shop_id, index]

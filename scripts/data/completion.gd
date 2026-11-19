class_name Completion
extends RefCounted
## How much of the world a save has seen (design bible 9, the completion card
## after the credits): rooms visited, hidden rooms found, treasures taken and
## bosses beaten, each against the whole game, and their average as one percent.


## Tallies the save in GameState against a World catalog (World.catalog).
static func tally(catalog: Dictionary) -> Dictionary:
	var rooms := 0
	var secrets := 0
	var secrets_total := 0
	var treasures := 0
	var treasures_total := 0
	for room_id: String in catalog:
		var info: Dictionary = catalog[room_id]
		if GameState.is_visited(room_id):
			rooms += 1
		if info.get("secret", false):
			secrets_total += 1
			if GameState.flag("secret:" + room_id):
				secrets += 1
		for id: String in info.get("treasures", []):
			treasures_total += 1
			if GameState.is_collected(id):
				treasures += 1
	var bosses := 0
	for id: String in BossArena.BOSSES:
		if GameState.flag("boss:" + id):
			bosses += 1
	var out := {
		"rooms": rooms, "rooms_total": catalog.size(),
		"secrets": secrets, "secrets_total": secrets_total,
		"treasures": treasures, "treasures_total": treasures_total,
		"bosses": bosses, "bosses_total": BossArena.BOSSES.size(),
	}
	out.percent = percent(out)
	out.merge(stat_items(catalog))
	out.merge(skill_points(catalog))
	return out


## The skill points a save has earned against every one the game gives (pass
## 253, design bible 9): one a rank past Seedling, one from each guardian whose
## reward names one, and one a whole ring, from the rooms' Grain Shards and
## a shard for each Ringreader Trial's first clear. Earned is what is held plus what
## the learned skills cost, so learning or unlearning never moves it.
static func skill_points(catalog: Dictionary) -> Dictionary:
	var total := GameState.RANK_XP.size() - 1
	for id: String in BossArena.BOSSES:
		total += int(BossArena.BOSSES[id].get("skill_points", 0))
	var shards := Trials.LIST.size()
	for room_id: String in catalog:
		shards += int(catalog[room_id].get("grains", 0))
	total += shards / 3
	var earned := int(GameState.data.skill_points)
	for id: String in GameState.data.skills:
		earned += int(GameData.skill(id).get("cost", 0))
	return {"points": earned, "points_total": total}


## The Life Fruits and Mana Dews a save has taken against every one the game
## holds (pass 180): those lying in the rooms, the one each town's grocer keeps,
## and the ones guardians give. A save's count is read from its health and
## magic, which nothing else raises. Not part of the percent.
static func stat_items(catalog: Dictionary) -> Dictionary:
	var fruits_total := 0
	var dews_total := 0
	for room_id: String in catalog:
		fruits_total += int(catalog[room_id].get("fruits", 0))
		dews_total += int(catalog[room_id].get("dews", 0))
	var shops := GameData.table("shops")
	for id: String in shops:
		for entry: Dictionary in shops[id].get("stock", []):
			if entry.get("item", "") == "life_fruit":
				fruits_total += 1
			elif entry.get("item", "") == "mana_dew":
				dews_total += 1
	for id: String in BossArena.BOSSES:
		var reward: Dictionary = BossArena.BOSSES[id]
		if reward.get("stat_item", "") == "life_fruit":
			fruits_total += 1
		if reward.get("stat_item", "") == "mana_dew" or reward.get("mana_dew", false):
			dews_total += 1
	var start: Dictionary = GameState.fresh()
	return {
		"fruits": maxi(0, (int(GameState.data.max_hp) - int(start.max_hp)) / GameState.LIFE_FRUIT_HP),
		"fruits_total": fruits_total,
		"dews": maxi(0, roundi((float(GameState.data.max_mp) - float(start.max_mp)) / GameState.MANA_DEW_MP)),
		"dews_total": dews_total,
	}


## Every guardian in the order the climb meets them, with the name the
## Journey page gives it (the mini-bosses among them).
const GUARDIANS := [
	["gnarlmaw", "Gnarlmaw"], ["foreman", "The Foreman"], ["durgan", "Durgan"],
	["gloamweaver", "Gloamweaver"], ["hag_matriarch", "The Marsh Hag Matriarch"], ["haar_wyrm", "The Haar Wyrm"], ["snapcrown", "Snapcrown"],
	["bark_captain", "The Bark Knight Captain"], ["skyrend", "Skyrend"], ["thane_vorrund", "Thane Vorrund"],
	["clockwork_alpha", "The Clockwork Alpha"], ["likeness", "the Likeness"], ["drowned_warden", "The Drowned Warden"],
	["everbloom_avatar", "The Everbloom, on the throne"], ["everbloom_veins", "The Everbloom, in the veins"],
	["everbloom", "The Everbloom, at the heart"],
]


## The guardians whose arenas the save has entered, in climb order:
## [{id, name, room, beaten}]. Arenas not yet found stay off the list, so the
## page never names a fight before you have seen its door.
static func guardians_found(catalog: Dictionary) -> Array:
	var rooms := {}
	for room_id: String in catalog:
		var b: String = catalog[room_id].get("boss", "")
		if b != "":
			rooms[b] = room_id
	var out := []
	for g: Array in GUARDIANS:
		var room: String = rooms.get(g[0], "")
		if room != "" and GameState.is_visited(room):
			out.append({"id": g[0], "name": g[1], "room": room, "beaten": GameState.flag("boss:" + g[0])})
	return out


## The Journey page's rows (pause menu): the four shares and the percent,
## then each guardian found, beaten or still waiting.
static func journey_rows(stats: Dictionary, found: Array) -> Array:
	var share := func(label: String, key: String, detail: String) -> Dictionary:
		var n := int(stats.get(key, 0))
		var total := int(stats.get(key + "_total", 0))
		return {"label": label, "right": "%d / %d" % [n, total], "detail": detail}
	var out := [
		{"label": "Of the world", "right": "%d%%" % int(stats.get("percent", 0)),
			"detail": "The whole world seen earns the Crown Gold at Ilse's Dyeworks, and opens the Ringreader's rush."},
		share.call("Rooms explored", "rooms", "Every room on the Tree, the hidden ones too."),
		share.call("Hidden rooms", "secrets", "Rooms behind false walls. The Seer's Lens shows their seams."),
		share.call("Treasures", "treasures", "Chests and finds that lie in the rooms. Treasure Sense marks the map."),
		share.call("Guardians beaten", "bosses", "The great foes and their lesser kin, each in an arena of its own."),
		share.call("Life Fruits", "fruits", "In the rooms, on each grocer's shelf, and in a guardian's keeping. Two grow a leaf."),
		share.call("Mana Dew", "dews", "In the rooms, on each grocer's shelf, and in the guardians' keeping."),
		share.call("Skill points", "points", "From ranks, guardians and whole rings. The tree costs more than all of them."),
	]
	if not found.is_empty():
		out.append({"label": "Guardians found", "header": true})
	for g: Dictionary in found:
		out.append({"label": g.name, "right": "Beaten" if g.beaten else "Waits",
			"detail": "Fallen. Its arena is quiet now." if g.beaten else "Still waiting in its arena."})
	var hidden := int(stats.get("bosses_total", 0)) - found.size()
	if hidden > 0:
		out.append({"label": "%d not yet found" % hidden, "detail": "Some guardians wait off the road you have walked.", "enabled": false})
	return out


## The average of the four shares, rounded down: 100 only when all are whole.
static func percent(stats: Dictionary) -> int:
	var sum := 0.0
	var parts := 0
	for k: String in ["rooms", "secrets", "treasures", "bosses"]:
		var total := int(stats.get(k + "_total", 0))
		if total > 0:
			sum += float(stats.get(k, 0)) / total
			parts += 1
	return int(floor(sum / parts * 100.0 + 0.0001)) if parts > 0 else 0


## The whole world seen (100%): the "lord" flag puts the Crown Gold on the
## shelf at Ilse's Dyeworks, the cloak's glow (design bible 11). True if earned.
static func award(stats: Dictionary) -> bool:
	if int(stats.get("percent", 0)) < 100:
		return false
	GameState.set_flag("lord")
	return true

extends Node
## Everything that persists between rooms and across saves: abilities, stats,
## gold, collected items, visited rooms, world flags and the save point.
## Rooms and the player read from it. Saves are JSON files in user://.

## Big centered banner (item get, area names). `subtitle` may be empty.
signal banner(title: String, subtitle: String)
## A rank was gained (design bible 5.6: a level-up is a moment). `rank` is the new one.
signal leveled_up(rank: int)
## Small line of text near the bottom of the screen ("Progress saved").
signal toast(text: String)
## A full-screen white flash (boss kills); strength 0 to 1.
signal flash(strength: float)
## Asks the HUD to show a dialog box; it freezes the player until closed.
signal dialog_requested(speaker: String, pages: Array)
## The Everbloom is dead: the game shows the ending (EndingScreen).
signal ending_started

## The most of a foe's sorcery a shield and helmet together turn (pass 225).
const MAX_WARD := 0.6
const SAVE_PATH := "user://save_%d.json"
## 2 (pass 317): saves from before the off hand (Sean, 2026-10-31) are told of it.
## 3 (pass 462): ids renamed for Yldenfall; older saves come over (migrate_ids).
const VERSION := 3
## The first save version written with the Yldenfall ids.
const IDS_VERSION := 3
## The first save version written under the off-hand rule.
const OFFHAND_VERSION := 2
## Flag set on an older save that found the Rune Dagger and wears a shield:
## the next Continue tells the player the shield now holds the throwing hand.
const OFFHAND_NOTICE := "notice:offhand"
const OFFHAND_NOTICE_TEXT := ["The Off Hand", "Your shield now holds the throwing hand. To throw, choose the Rune Dagger under Off Hand (Equipment)."]
## Save maps whose every entry is true or false (pass 351; `sanitize`).
const BOOL_MAPS := ["abilities", "flags", "charts", "collected", "visited"]
## Item ids a newer build renamed: old id -> new id (sanitize carries a save over).
const RENAMED_ITEMS := {"hand_dagger": "short_sword", "giant_blade": "dwarvish_broad_sword"}
## Pickups a newer build moved: old id -> new id. A pickup's id is its room and
## cell, so a save that took it at the old cell would find it again (pass 213).
const MOVED_PICKUPS := {
	"vorrhallow/drowned_nave:31,5": "vorrhallow/drowned_nave:31,6",  # pass 67
	"boughs/north_bough:8,7": "boughs/north_bough:2,6",  # pass 211, then 216
	"boughs/north_bough:9,6": "boughs/north_bough:2,6",  # pass 216
	"spires/sky_steps:6,20": "spires/sky_steps:6,19",  # pass 219
	"haar/feather_hollow:18,7": "haar/feather_hollow:18,6",  # pass 235
	# Pass 508 gave every passage four tiles for the 2x hero: a lowered vault floor took
	# its chest, its pickup and its key door down a row.
	"evercrown/threshold:2,19": "evercrown/threshold:2,20",  # pass 508, the Elven Helm
	"boughs/north_bough:2,15": "boughs/north_bough:2,16",  # pass 508
	"boughs/north_bough:2,40": "boughs/north_bough:2,41",  # pass 508
	"boughs/north_bough:4,40": "boughs/north_bough:4,41",  # pass 508
	"haar/feather_hollow:2,19": "haar/feather_hollow:2,20",  # pass 508
	"haar/feather_hollow:4,19": "haar/feather_hollow:4,20",  # pass 508
	"haar/scorched_hall:34,11": "haar/scorched_hall:34,12",  # pass 508
	"haar/scorched_hall:37,11": "haar/scorched_hall:37,12",  # pass 508
	"haar/veiled_rise:3,20": "haar/veiled_rise:3,21",  # pass 508
	"hearthroot/east_gate:20,19": "hearthroot/east_gate:20,20",  # pass 508
	"hearthroot/west_gate:2,19": "hearthroot/west_gate:2,20",  # pass 508
	"hearthroot/west_gate:24,19": "hearthroot/west_gate:24,20",  # pass 508
	"spires/broken_shrine:32,19": "spires/broken_shrine:32,20",  # pass 508
	"spires/broken_shrine:35,19": "spires/broken_shrine:35,20",  # pass 508
	"spires/spire_stair:2,19": "spires/spire_stair:2,20",  # pass 508
	"spires/spire_stair:4,19": "spires/spire_stair:4,20",  # pass 508
	"vorrhallow/meteor_rise:2,19": "vorrhallow/meteor_rise:2,20",  # pass 508
	"vorrhallow/meteor_rise:4,19": "vorrhallow/meteor_rise:4,20",  # pass 508
}
## Breakable walls a newer build made a cell taller: new cell -> the old cell it grew from
## (pass 508, every passage four tiles tall). A save that broke the old wall has broken
## the new cell too, so no lone block is left standing in the doorway.
const GROWN_GATES := {
	"boughs/north_bough:4,16": "boughs/north_bough:4,15",
	"haar/scorched_hall:35,12": "haar/scorched_hall:35,11",
	"hearthroot/west_gate:4,20": "hearthroot/west_gate:4,19",
	"hearthroot/west_gate:23,20": "hearthroot/west_gate:23,19",
	"heartwood/dwarf_larder:5,16": "heartwood/dwarf_larder:5,17",
	"spires/spire_foot:8,16": "spires/spire_foot:8,17",
	"tower/kettleforge_stair:13,9": "tower/kettleforge_stair:13,10",
	"tower/old_flue:34,36": "tower/old_flue:34,37",
	"tower/ore_vault:19,17": "tower/ore_vault:19,18",
	"tower/slag_heap:70,15": "tower/slag_heap:70,16",
	"tower/sorting_floor:9,9": "tower/sorting_floor:9,10",
}
## The equipment slots, in the order the Equipment page lists them.
const GEAR_SLOTS := ["blade", "armor", "shield", "helmet"]

## The 16 ranks, named for a tree's growth. Each rank after Seedling gives a skill point.
const RANKS := ["Seedling", "Sprout", "Sapling", "Thornling", "Barkskin", "Wayfarer", "Ranger", "Bough-Guard",
	"Leafblade", "Heartwood", "Rootwarden", "Stormbough", "Oakheart", "Crownward", "Elder", "Ylden's Own"]
## Damage each smith temper adds to a blade (design bible 5.2).
const TEMPER_BONUS := 0.15
const RANK_XP := [0, 40, 100, 180, 300, 460, 660, 900, 1200, 1560, 2000, 2500, 3100, 3800, 4600, 5500]
const LIFE_FRUIT_HP := 10
## Resilience (skill tree): one more mask.
const RESILIENCE_HP := 20
const MANA_DEW_MP := 10.0
const RESPEC_BASE := 200
const RESPEC_MAX := 2000

## Persistent game data. Keys are documented in `fresh()`.
## The original's password alphabet, more or less: letters, digits, ? and !.
const MARK_LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZabdefghkmnpqrtwy23456789?!"

var data := {}
var slot := 1
## False in the gym: kills there give no XP and nothing is recorded.
var active := true
## Seconds played since the last save (added to data.play_time on save).
var play_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = fresh()


func _process(delta: float) -> void:
	# The time played is time in play (pass 437): a pause menu left open, the
	# map, a sign being read or the flask shelf stops the clock, as the game
	# does. This node runs while paused, so until then all of it counted.
	# It is the player's time (pass 475): at a slower Game speed or in a
	# boss's slow motion a second of play is still a second, so the frame's
	# game-time delta is turned back into real time.
	if not get_tree().paused:
		play_time += Feel.unscaled(delta)


static func fresh() -> Dictionary:
	return {
		"version": VERSION,
		"abilities": {"glove": false, "delvers_pick": false, "boots": false, "stride": false, "torrent": false, "fire": false, "thunder": false, "wisplight": false, "seers_lens": false, "stillstone": false, "death": false, "rune_dagger": false, "pendant": false, "briar_wand": false, "severance": false},
		## The spell on the Spell button (an id in `Spells.ORDER`).
		"spell": "torrent",
		"max_hp": 100,
		"max_mp": 60.0,
		"flask_max": 2,
		"gold": 0,
		"xp": 0,
		"rank": 0,
		## The highest rank a Ringreader has named you by (Yldenfall's title ceremony).
		"named_rank": 0,
		"skill_points": 0,
		"skills": [],
		"respecs": 0,
		"equipment": {"blade": "short_sword", "armor": "", "shield": "", "helmet": ""},
		## Smith tempers per blade id (0 to 2): each adds TEMPER_BONUS to its damage.
		"tempers": {},
		"keys": {},
		"rings": [],
		"potion_shards": 0,
		"grain_shards": 0,
		## Stillglass Shards carried: the Kettleforge smith folds one into each second temper.
		"meteor_shards": 0,
		## Amber Draughts carried (at most Shop.ELIXIR_MAX): one revives the player in place on death.
		"elixirs": 0,
		## Barkbalms carried (at most Shop.OINTMENT_MAX).
		"ointments": 0,
		"collected": {},
		"visited": {},
		## Room id -> [x, y] of each Ringreader you have spoken to: the Grain Road's stops.
		"ringreaders": {},
		## Zones whose outline the Cartographer sold you (zone -> true): the map shows their unseen rooms dimmed.
		"charts": {},
		## Map pins: [room id, x, y] in room pixels (at most MAX_PINS).
		"pins": [],
		"flags": {},
		"purse": {},
		"save_room": "",
		"save_pos": [0, 0],
		"play_time": 0.0,
		## Times the game has been finished on this save (the ending sets the `cleared` flag too).
		"clears": 0,
		## Times you have fallen this run (the secret ending wants none).
		"deaths": 0,
		## Inner Rings cleared: trial id -> best time in seconds (Trials).
		"trials": {},
		## Cloak dyes bought at Ilse's Dyeworks (pass 136), and the one worn ("" is Warden Green).
		"dyes": [],
		## Every blade, armor, shield and helmet you have bought or found (pass 186):
		## the Equipment page swaps between them.
		"gear": ["short_sword"],
		"dye": "",
		"hair": "",
	}


func new_game() -> void:
	data = fresh()
	play_time = 0.0


# --- Queries ---------------------------------------------------------------------

func has_ability(id: String) -> bool:
	return bool(data.abilities.get(id, false))


func is_collected(id: String) -> bool:
	return data.collected.has(id)


func collect(id: String) -> void:
	data.collected[id] = true


## The notice a loaded save is owed (pass 317): [title, subtitle] for a banner,
## or empty. It is given once: taking it clears it from the save.
func take_load_notice() -> Array:
	if not flag(OFFHAND_NOTICE):
		return []
	data.flags.erase(OFFHAND_NOTICE)
	return OFFHAND_NOTICE_TEXT.duplicate()


func flag(id: String) -> bool:
	return bool(data.flags.get(id, false))


func set_flag(id: String, value := true) -> void:
	data.flags[id] = value


## The cloak dye worn: an item id from data/items.json (kind "dye").
func dye() -> String:
	var id := String(data.get("dye", ""))
	return id if id != "" else "warden_dye"


## The hair color chosen on the Equipment page (an id of PlayerVisual.HAIR).
func hair() -> String:
	var id := String(data.get("hair", ""))
	return id if PlayerVisual.HAIR.has(id) else "violet"


## Gives a dye won rather than bought (a Ringreader Trial's ring time, pass 164):
## it goes on the cloak, and its flag puts it on Ilse's shelf to wear again.
func earn_dye(id: String) -> void:
	var owned: Array = data.get("dyes", [])
	if not owned.has(id):
		owned.append(id)
	data.dyes = owned
	data.dye = id
	set_flag("dye:" + id)


## Gear (pass 186): a blade, armor, shield or helmet you have is kept, and the
## Equipment page puts any of it on.
func owns_gear(id: String) -> bool:
	return Array(data.get("gear", [])).has(id) or GEAR_SLOTS.any(func(s: String) -> bool: return String(data.equipment.get(s, "")) == id)


## Takes `id` into your gear and puts it on (a purchase, a find, a reward).
func obtain_gear(id: String, p: Player = null) -> void:
	if not Array(data.gear).has(id):
		data.gear.append(id)
	var slot := String(GameData.item(id).get("kind", ""))
	if GEAR_SLOTS.has(slot):
		data.equipment[slot] = id
	if p != null:
		refresh_stats(p)


## Puts on gear you have, in its slot. Wearing what is already worn takes it
## off, except the blade: you always hold one.
func wear(id: String, p: Player = null) -> void:
	var slot := String(GameData.item(id).get("kind", ""))
	if not GEAR_SLOTS.has(slot) or not owns_gear(id):
		return
	if String(data.equipment.get(slot, "")) == id and slot != "blade":
		data.equipment[slot] = ""
	else:
		data.equipment[slot] = id
	if p != null:
		refresh_stats(p)


## The off hand holds a shield or the Rune Dagger, not both (Sean, 2026-10-31): the
## dagger is thrown from the left hand, the shield's arm. With no shield worn the
## hand is free to throw it.
func offhand_free() -> bool:
	return String(data.equipment.get("shield", "")) == ""


## True when the blade in hand takes both hands (the Dwarvish Broad Sword):
## the shield stays on your back, and you can't guard or parry.
func two_handed() -> bool:
	return bool(GameData.item(String(data.equipment.blade)).get("two_handed", false))


## Whether this save owns a dye. Warden Green is the cloak you start in, and
## the Crown Gold is given, not sold.
func owns_dye(id: String) -> bool:
	return id == "warden_dye" or id == "lord_dye" or Array(data.get("dyes", [])).has(id)


## The Everbloom is dead: mark the save cleared and start the ending.
func begin_ending() -> void:
	set_flag("cleared")
	if secret_ending():
		set_flag("cleared_secret")
	data.clears = int(data.get("clears", 0)) + 1
	ending_started.emit()


## Seconds played on this save, counting the time since the last save.
## The secret ending (design bible 11): the Everbloom reached without a single
## death, wearing the Drowned Warden's Elven Plate.
func secret_ending() -> bool:
	return int(data.get("deaths", 0)) == 0 and String(data.equipment.get("armor", "")) == "elven_plate"


func total_play_time() -> float:
	return float(data.get("play_time", 0.0)) + play_time


## Map pins you may place at once (design bible 3.3).
const MAX_PINS := 12
## A pin this close to where you stand is the one a press removes.
const PIN_REACH := 48.0


func has_chart(zone: String) -> bool:
	return bool(data.charts.get(zone, false))


## Places a pin where you stand, or removes the one within PIN_REACH. Returns
## "placed", "removed" or "full".
func toggle_pin(room_id: String, pos: Vector2) -> String:
	for i in data.pins.size():
		var pin: Array = data.pins[i]
		if pin[0] == room_id and Vector2(float(pin[1]), float(pin[2])).distance_to(pos) < PIN_REACH:
			data.pins.remove_at(i)
			return "removed"
	if data.pins.size() >= MAX_PINS:
		return "full"
	data.pins.append([room_id, pos.x, pos.y])
	return "placed"


## The Grain Road (design bible 3.3): Ringreader-to-Ringreader travel, open once any
## spring flows again.
func grain_road_open() -> bool:
	for k: String in data.flags:
		if k.begins_with("spring:") and bool(data.flags[k]):
			return true
	return false


func meet_ringreader(room_id: String, pos: Vector2) -> void:
	data.ringreaders[room_id] = [pos.x, pos.y]


## The Ringreaders you could walk the Grain Road to from `here` (room ids, sorted).
func grain_stops(here: String) -> Array:
	var out := []
	for k: String in data.ringreaders:
		if k != here:
			out.append(k)
	out.sort()
	return out


func visit(room_id: String) -> void:
	data.visited[room_id] = true


func is_visited(room_id: String) -> bool:
	return data.visited.has(room_id)


func has_skill(id: String) -> bool:
	return id in data.skills


## The mark a Ringreader carves for the journey so far: sixteen letters cut
## into the wood (design bible 11, easter eggs). It is never typed back in; saving is
## automatic. The same progress always gives the same ring.
func carved_mark() -> String:
	var rooms: Array = data.get("visited", {}).keys()
	rooms.sort()
	var taken: Array = data.get("collected", {}).keys()
	taken.sort()
	var src := JSON.stringify([data.get("rank", 0), data.get("xp", 0), data.get("gold", 0), data.get("abilities", {}),
		data.get("equipment", {}), data.get("rings", []), taken, rooms, data.get("flags", {}), data.get("save_room", "")], "", true)
	var h := src.sha256_buffer()
	var out := ""
	for i in 16:
		if i > 0 and i % 4 == 0:
			out += " "
		out += MARK_LETTERS[h[i] % MARK_LETTERS.length()]
	return out


func rank_name() -> String:
	return RANKS[int(data.rank)]


## XP needed for the next rank, or -1 at Ylden's Own.
func next_rank_xp() -> int:
	var r := int(data.rank)
	return RANK_XP[r + 1] if r + 1 < RANK_XP.size() else -1


func add_xp(amount: int) -> void:
	if not active or amount <= 0:
		return
	data.xp = int(data.xp) + amount
	while int(data.rank) + 1 < RANK_XP.size() and int(data.xp) >= RANK_XP[int(data.rank) + 1]:
		data.rank = int(data.rank) + 1
		data.skill_points = int(data.skill_points) + 1
		banner.emit("Rank up: " + rank_name(), "You gain a skill point. Seek a Ringreader to be named and taught.")
		Sfx.play("rank", 0.0)
		leveled_up.emit(int(data.rank))


## The title you have earned but no Ringreader has named yet ("" if none).
func unnamed_title() -> String:
	return rank_name() if int(data.rank) > int(data.get("named_rank", 0)) else ""


## A Ringreader names you by your current rank. Returns the title.
func name_title() -> String:
	data.named_rank = int(data.rank)
	return rank_name()


## How many times the Kettleforge smith has tempered blade `blade_id` (0 to 2).
func temper_level(blade_id: String) -> int:
	return int(data.get("tempers", {}).get(blade_id, 0))


func key_count(kind: String) -> int:
	return int(data.keys.get(kind, 0))


func add_key(kind: String, n := 1) -> void:
	data.keys[kind] = key_count(kind) + n


func say(speaker: String, pages: Array) -> void:
	dialog_requested.emit(speaker, pages)


# --- Player sync -------------------------------------------------------------------

## Copies persistent state onto a player in the tree and fills its health,
## magic and potions.
func apply(p: Player) -> void:
	for k: String in data.abilities:
		p.abilities[k] = bool(data.abilities[k])
	p.equipped_spell = String(data.get("spell", "torrent"))
	p.gold = int(data.gold)
	p.elixirs = int(data.elixirs)
	p.ointments = int(data.ointments)
	refresh_stats(p)
	p.restore()


## Recomputes the player's derived stats from base stats, gear and skills.
## Current health, magic and potions are clamped, not refilled.
func refresh_stats(p: Player) -> void:
	var eq: Dictionary = data.equipment
	var blade_id := String(eq.blade)
	if GameData.item(blade_id).is_empty():
		# A blade this build lacks (pass 138): the Short Sword, untempered.
		blade_id = "short_sword"
	var blade := GameData.item(blade_id)
	var temper := 1.0 + TEMPER_BONUS * temper_level(blade_id)
	p.slash_damage = roundi(int(blade.slash) * temper)
	p.heavy_damage = roundi(int(blade.heavy) * temper)
	p.reach_bonus = float(blade.reach)
	p.arc_bonus = float(blade.get("arc", 0.0))
	p.swing_mult = float(blade.get("swing", 1.0))
	# Armor and helmet stack by what each lets through (bible 5.2): Elven Plate
	# (60%) under the Elven Helm (10%) lets 0.4 x 0.9 = 36% through.
	var helmet := GameData.item(String(eq.get("helmet", "")))
	p.defense = 1.0 - (1.0 - float(GameData.item(eq.armor).get("defense", 0.0))) * (1.0 - float(helmet.get("defense", 0.0)))
	p.has_shield = eq.shield != "" and not bool(blade.get("two_handed", false))
	p.guard_reduction = float(GameData.item(eq.shield).get("guard", p.combat.guard_reduction))
	p.reflects = p.has_shield and bool(GameData.item(eq.shield).get("reflect", false))
	# A shield on the back of a two-hander wards nothing; the helmet always does.
	var ward := float(GameData.item(eq.shield).get("ward", 0.0)) if p.has_shield else 0.0
	p.magic_ward = minf(ward + float(helmet.get("ward", 0.0)), MAX_WARD)
	p.melee_mult = 1.0 + (0.1 if has_skill("keen_edge") else 0.0) + (0.1 if has_skill("keener_edge") else 0.0)
	p.riposte = has_skill("riposte")
	p.bloodletting = has_skill("bloodletting")
	p.thrust = has_skill("thrust")
	p.executioner = has_skill("executioner")
	p.spell_cost_mult = 0.85 if has_skill("thrift") else 1.0
	p.chain_thunder = has_skill("chain_thunder")
	p.time_thief = has_skill("time_thief")
	p.ring_of_death = has_skill("ring_of_death")
	p.last_stand = has_skill("last_stand")
	p.second_wind = has_skill("second_wind")
	p.wanderers_grace = has_skill("wanderers_grace")
	p.feather_fall = has_skill("feather_fall")
	p.ground_combo_length = 4 if has_skill("fourth_strike") else 3
	p.mp_hit_mult = 1.5 if has_skill("siphon") else 1.0
	p.gold_mult = 1.1 if has_skill("gold_sense") else 1.0
	p.magnet_mult = 1.6 if has_skill("gold_sense") else 1.0
	p.rising_cut = has_skill("rising_cut")
	p.down_strike_mult = 1.5 if has_skill("delvers_pick_mastery") else 1.0
	p.spell_pierce = has_skill("torrent_pierce")
	p.wisplight_swarm = has_skill("wisplight_swarm")
	p.drink_mult = 0.6 if has_skill("quick_draught") else 1.0
	p.bonus_air_dashes = 1 if has_skill("second_stride") else 0
	# The Elven Helm is worth one mask on top (bible 5.2).
	p.max_hp = int(data.max_hp) + (RESILIENCE_HP if has_skill("resilience") else 0) + int(helmet.get("hp", 0))
	p.max_mp = float(data.max_mp) + (20.0 if has_skill("clear_mind") else 0.0)
	p.flask_max = int(data.flask_max) + (1 if has_skill("deep_pockets") else 0)
	p.hp = mini(p.hp, p.max_hp)
	p.mp = minf(p.mp, p.max_mp)
	p.flask_charges = mini(p.flask_charges, p.flask_max)
	p.health_changed.emit(p.hp, p.max_hp)


## Copies the player's live state back (before saving or changing rooms).
## Max stats live only here, so they are not copied back.
func capture(p: Player) -> void:
	for k: String in p.abilities:
		data.abilities[k] = bool(p.abilities[k])
	data.spell = p.equipped_spell
	data.gold = p.gold
	data.elixirs = p.elixirs
	data.ointments = p.ointments


## Applies a permanent stat item (Life Fruit, Mana Dew, a Potion, Ring or Stillglass Shard) and
## returns the line to show under its name.
func grant_stat_item(kind: String, p: Player) -> String:
	match kind:
		"life_fruit":
			data.max_hp = int(data.max_hp) + LIFE_FRUIT_HP
			refresh_stats(p)
			p.restore()
			return "Your health grows. Two fruits make a new mask."
		"mana_dew":
			data.max_mp = float(data.max_mp) + MANA_DEW_MP
			refresh_stats(p)
			p.mp = p.max_mp
			return "Your magic grows by %d." % int(MANA_DEW_MP)
		"potion_shard":
			data.potion_shards = int(data.potion_shards) + 1
			var n := int(data.potion_shards)
			if n % 3 == 0:
				data.flask_max = int(data.flask_max) + 1
				refresh_stats(p)
				p.flask_charges = p.flask_max
				return "Three shards fuse. Your flask holds one more Sapflask."
			return "%d of 3. Three fuse into a new potion charge." % (n % 3)
		"grain_shard":
			data.grain_shards = int(data.grain_shards) + 1
			var n := int(data.grain_shards)
			if n % 3 == 0:
				data.skill_points = int(data.skill_points) + 1
				return "The ring is whole. You gain a skill point."
			return "%d of 3. Three complete a ring." % (n % 3)
		"meteor_shard":
			data.meteor_shards = int(data.meteor_shards) + 1
			return "You carry %d. The Kettleforge smith folds one into a second temper." % int(data.meteor_shards)
	return ""


# --- Save files --------------------------------------------------------------------

func save_game(to_slot := -1) -> bool:
	if to_slot >= 0:
		slot = to_slot
	data.play_time = float(data.get("play_time", 0.0)) + play_time
	play_time = 0.0
	return write_safely(SAVE_PATH % slot, JSON.stringify(data, "\t"))


## Writes `text` to `path` without ever leaving it half-written (pass 109): the
## text goes to a temp file first and is read back, then the old file becomes
## the `.bak` and the temp file takes its place. A failed write leaves the last
## good file as it was.
## The game was renamed in pass 461, and Godot keeps a game's saves in a folder
## named for it. On the first start under the new name, copy the saves and
## settings over from the old folder (its name is in data/rename_map.json), so
## no journey is lost. Never overwrites a file the new folder already has.
## Returns how many files it copied. The game calls it at start; tests don't.
## Old id -> new id, word by word (data/rename_map.json "ids", pass 462).
static var _id_words: Array = []
## Exact renames of the key and seed ids, which are plain words elsewhere.
static var _id_exact: Dictionary = {}


static func _load_id_table() -> void:
	if not _id_words.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/rename_map.json"))
	var ids: Dictionary = (parsed as Dictionary).get("ids", {}) if parsed is Dictionary else {}
	var pairs: Array = (ids.get("segments", []) as Array).duplicate()
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]).length() > String(b[0]).length())
	for pair: Array in pairs:
		for cased: Array in [[String(pair[0]), String(pair[1])], [String(pair[0]).to_upper(), String(pair[1]).to_upper()]]:
			var re := RegEx.new()
			re.compile("(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % cased[0])
			_id_words.append([re, cased[1]])
	_id_exact = ids.get("exact", {})


## An id written before pass 462 under its new name: "trunk/spring_of_trunk"
## is "heartwood/spring_of_heartwood". A new id comes back as it is.
static func rename_id(id: String) -> String:
	_load_id_table()
	for pair: Array in _id_words:
		id = (pair[0] as RegEx).sub(id, pair[1], true)
	return id


## A save written before pass 462 with every id renamed: room, zone, item,
## ability, npc, boss and flag ids wherever they are (values and map keys),
## then the card keys (by their old card names) and the four seeds.
static func migrate_ids(save: Variant) -> Variant:
	var out: Variant = _rename_ids_deep(save)
	if out is Dictionary:
		var keys: Variant = out.get("keys")
		var key_names: Dictionary = _id_exact.get("keys", {})
		if keys is Dictionary:
			var renamed := {}
			for k: Variant in keys:
				renamed[key_names.get(k, k)] = keys[k]
			out.keys = renamed
		var rings: Variant = out.get("rings")
		var ring_names: Dictionary = _id_exact.get("rings", {})
		if rings is Array:
			out.rings = (rings as Array).map(func(r: Variant) -> Variant: return ring_names.get(r, r))
	return out


static func _rename_ids_deep(v: Variant) -> Variant:
	if v is String:
		return rename_id(v)
	if v is Array:
		return (v as Array).map(func(e: Variant) -> Variant: return _rename_ids_deep(e))
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[_rename_ids_deep(k) if k is String else k] = _rename_ids_deep(v[k])
		return out
	return v


static func bring_old_saves(user_dir := OS.get_user_data_dir()) -> int:
	var map: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/rename_map.json"))
	if not map is Dictionary or not String(map.get("user_dir_before", "")):
		return 0
	var old_dir := user_dir.get_base_dir().path_join(String(map.user_dir_before))
	if old_dir == user_dir or not DirAccess.dir_exists_absolute(old_dir):
		return 0
	var copied := 0
	for file: String in DirAccess.get_files_at(old_dir):
		if not (file.begins_with("save_") or file.begins_with("settings")):
			continue
		var to := user_dir.path_join(file)
		if FileAccess.file_exists(to):
			continue
		if DirAccess.copy_absolute(old_dir.path_join(file), to) == OK:
			copied += 1
	return copied


static func write_safely(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write %s" % path)
		return false
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(tmp) != text:
		push_warning("%s did not write whole; the last good copy is kept" % path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	var real := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(real + ".bak")
		DirAccess.rename_absolute(real, real + ".bak")
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), real) == OK


func has_save(which: int) -> bool:
	var path := SAVE_PATH % which
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## What a slot holds, read whole and made safe (`sanitize`), from its `.bak`
## if the file itself is damaged; {} when it holds nothing that can be read.
## The title's flasks read it without loading (Sean, 2026-10-31). `warn` says
## aloud when a file had to be passed over.
static func read_slot(which: int, warn := false) -> Dictionary:
	var path := SAVE_PATH % which
	for p: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		# JSON.parse_string logs an engine error for a damaged file; the warning
		# below says it plainly instead (pass 215).
		var json := JSON.new()
		var loaded := sanitize(json.data if json.parse(FileAccess.get_file_as_string(p)) == OK else null)
		if not loaded.is_empty():
			if p != path and warn:
				push_warning("Save slot %d was damaged; loaded its backup" % which)
			return loaded
		if warn:
			push_warning("%s is not a save" % p)
	return {}


## When a slot was last written (unix seconds), or 0 if it has never been.
static func slot_time(which: int) -> int:
	var path := SAVE_PATH % which
	for p: String in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			return int(FileAccess.get_modified_time(p))
	return 0


## Loads a slot, or its `.bak` if the file itself is damaged. On failure the
## current data is left untouched.
func load_game(from_slot: int) -> bool:
	var loaded := read_slot(from_slot, true)
	if loaded.is_empty():
		return false
	data = loaded
	slot = from_slot
	play_time = 0.0
	return true


## Whatever a save file held, made into a whole save (pass 109): every key of
## fresh(), each of its own type, so a damaged, hand-edited or older file can
## never leave a hole or a wrong type behind. Keys a newer build added are
## kept. Returns {} when it isn't a save at all (not an object, or no sign of
## one).
static func sanitize(src: Variant) -> Dictionary:
	if not src is Dictionary or not (src as Dictionary).has("save_room"):
		return {}
	var from: Variant = (src as Dictionary).get("version", 1)
	if (int(from) if _is_number(from) else 1) < IDS_VERSION:
		src = migrate_ids(src)
	var out := fresh()
	for k: Variant in src:
		if k is String:
			out[k] = _coerce(out[k], src[k]) if out.has(k) else src[k]
	# A save from before the off hand (pass 317) that found the dagger and wears a
	# shield: Throw would now do nothing, unexplained, so the next Continue says why.
	var was: Variant = (src as Dictionary).get("version", 1)
	if (int(was) if _is_number(was) else 1) < OFFHAND_VERSION and bool(out.abilities.get("rune_dagger", false)) \
			and String(out.equipment.get("shield", "")) != "":
		out.flags[OFFHAND_NOTICE] = true
	out.version = VERSION
	# Items renamed since a save was written keep their place and temper (pass 184).
	for old: String in RENAMED_ITEMS:
		var now: String = RENAMED_ITEMS[old]
		if String(out.equipment.get("blade", "")) == old:
			out.equipment.blade = now
		if out.tempers.has(old):
			out.tempers[now] = maxi(int(out.tempers.get(now, 0)), int(out.tempers[old]))
			out.tempers.erase(old)
	# Pickups moved since a save was written stay taken (pass 213).
	for old: String in MOVED_PICKUPS:
		if out.collected.has(old):
			out.collected[MOVED_PICKUPS[old]] = true
			out.collected.erase(old)
	for cell: String in GROWN_GATES:
		if out.collected.has(GROWN_GATES[cell]):
			out.collected[cell] = true
	# Thane Vorrund has given up the Severance since pass 217; before, it lay
	# on the Heart Gate's altar, which is now bare. A save past him that never
	# took it from the altar gets it in hand, so the heart can still be cut.
	if bool(out.flags.get("boss:thane_vorrund", false)) and not bool(out.abilities.get("severance", false)):
		out.abilities.severance = true
		out.equipment.blade = "severance"
	# The Elven Helm left the shield slot for its own (pass 185). It had
	# guarded and turned shots like the Warding Shield, and with it on every
	# shield showed as owned, so the hand it held gets the Warding Shield.
	if String(out.equipment.get("shield", "")) == "elven_helm":
		out.equipment.helmet = "elven_helm"
		out.equipment.shield = "magic_shield"
	# A slot holds its own kind (pass 191): a known item worn in the wrong
	# slot (a sword as a helmet) comes off, and a blade falls back to the
	# Short Sword. An unknown id stays, as pass 138 keeps it, and plays as none.
	for slot: String in GEAR_SLOTS:
		var kind := String(GameData.item(String(out.equipment.get(slot, ""))).get("kind", ""))
		if kind != "" and kind != slot:
			out.equipment[slot] = "short_sword" if slot == "blade" else ""
	# Gear kept since pass 186: whatever is worn, and the starting blade.
	var gear: Array = _unique_strings(out.gear)
	for i in gear.size():
		gear[i] = RENAMED_ITEMS.get(gear[i], gear[i])
	for slot: String in GEAR_SLOTS:
		var worn := String(out.equipment.get(slot, ""))
		if worn != "" and not gear.has(worn):
			gear.append(worn)
	if not gear.has("short_sword"):
		gear.push_front("short_sword")
	out.gear = gear
	# The Severance is both an ability (the reach checker's gate) and gear;
	# a save holds both or neither (pass 221).
	if gear.has("severance") or bool(out.abilities.get("severance", false)):
		out.abilities.severance = true
		if not gear.has("severance"):
			gear.append("severance")
	# Containers whose entries the game reads by shape.
	out.skills = _unique_strings(out.skills)
	out.dyes = _unique_strings(out.dyes)
	out.rings = out.rings.filter(func(v: Variant) -> bool: return v is String)
	out.pins = out.pins.filter(func(v: Variant) -> bool:
		return v is Array and v.size() == 3 and v[0] is String and _is_number(v[1]) and _is_number(v[2]))
	if not _is_point(out.save_pos):
		out.save_pos = [0, 0]
	# Yes-or-no maps (pass 351): the game reads each entry with bool(), which
	# stops with a script error on a string, a list or null. A hand-edited
	# "spring:sky": "yes" made the title's flask read as empty, and taking it up
	# would have begun a new journey over the old one. Only true or false stays.
	for map: String in BOOL_MAPS:
		for k: Variant in out[map].keys():
			if not (k is String and out[map][k] is bool):
				out[map].erase(k)
	# Keys are counts (the cards) or kept-for-good flags (the Lantern and Sky Keys).
	for kind: Variant in out.keys.keys():
		var v: Variant = out.keys[kind]
		if not (kind is String and (v is bool or (_is_number(v) and float(v) >= 0.0))):
			out.keys.erase(kind)
		elif _is_number(v):
			out.keys[kind] = int(v)  # JSON keeps counts as floats; a save comes back as it went (pass 174)
	for id: Variant in out.trials.keys():
		if not _is_number(out.trials[id]) or float(out.trials[id]) < 0.0:
			out.trials.erase(id)
	for room: Variant in out.ringreaders.keys():
		if not _is_point(out.ringreaders[room]):
			out.ringreaders.erase(room)
	# The purse dropped on the last death holds its gold as "value", the name
	# World writes. Until pass 250 this asked for "gold", so every purse was
	# thrown away on load; a save that names it "gold" is read as well.
	if not out.purse.is_empty() and not out.purse.has("value") and out.purse.has("gold"):
		out.purse.value = out.purse.gold
	if not out.purse.is_empty() and not (out.purse.get("room") is String and _is_number(out.purse.get("x"))
			and _is_number(out.purse.get("y")) and _is_number(out.purse.get("value")) and float(out.purse.value) > 0.0):
		out.purse = {}
	elif not out.purse.is_empty():
		out.purse = {"room": out.purse.room, "x": float(out.purse.x), "y": float(out.purse.y), "value": int(out.purse.value)}
	# Nothing falls below a new game's: no zero health, no negative gold.
	var base := fresh()
	for k: String in base:
		if base[k] is int or base[k] is float:
			var low: float = base[k] if k in ["max_hp", "max_mp", "flask_max"] else 0.0
			out[k] = maxi(int(out[k]), int(low)) if base[k] is int else maxf(float(out[k]), low)
	return out


## The strings of `list`, each once (pass 138): a skill listed twice would be
## refunded twice by a respec.
static func _unique_strings(list: Array) -> Array:
	var out := []
	for v: Variant in list:
		if v is String and not out.has(v):
			out.append(v)
	return out


## `v` if it has the type of `default` (numbers convert, since JSON keeps every
## number as a float), else `default`. Dictionaries are merged key by key.
static func _coerce(default: Variant, v: Variant) -> Variant:
	if default is Dictionary:
		if not v is Dictionary:
			return default
		var d: Dictionary = default.duplicate(true)
		for k: Variant in v:
			if k is String:
				d[k] = _coerce(d[k], v[k]) if d.has(k) else v[k]
		return d
	if default is int or default is float:
		if not _is_number(v):
			return default
		return int(v) if default is int else float(v)
	if typeof(default) != typeof(v):
		return default
	return v


static func _is_number(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v))


static func _is_point(v: Variant) -> bool:
	return v is Array and v.size() == 2 and _is_number(v[0]) and _is_number(v[1])


func delete_save(which: int) -> void:
	var path := SAVE_PATH % which
	for p: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

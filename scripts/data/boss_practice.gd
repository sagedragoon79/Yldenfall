class_name BossPractice
extends RefCounted
## Boss practice (Sean, 2026-11-24: "playtest each bossfight without having to
## start a game from scratch"). A development tool, not a feature: the title's
## "Boss practice" row shows only when the game is launched with `--practice`.
##
## Pick a guardian and you wake at its arena's door with the kit a player has
## on reaching it by the critical path (KITS, 4.2): the abilities, the par gear
## and tempers of the damage sheet (PAR_KIT, 5.5), and the Life Fruits, Mana
## Dews and Potion Shards in reach by then (`tools/levels/practice_kits.gd`
## counts them). Nothing is saved to a journey flask.
##
## It rides on the boss rush (BossRush): a practice is a rush of one guardian,
## so the arena fights again, wins nothing, and the blow that would kill you
## ends it instead. Win or lose, a report shows what happened (`report_rows`),
## its line is added to `user://practice_log.csv` (LOG_PATH), and you go back
## to the list.

## The damage balance sheet (design bible 5.5, pass 194): the kit the critical
## path has put in your hands by each zone, as [blade, tempers, armor, shield].
## The shield joined in pass 226: since pass 225 it wards a foe's sorcery.
## (test_combat's PAR_KIT; it lives here since boss practice dresses you in it.)
const PAR_KIT := {
	"heartwood": ["long_sword", 0, "leather_armor", "small_shield"],
	"tower": ["long_sword", 0, "leather_armor", "small_shield"],
	"haar": ["long_sword", 1, "riveted_coat", "large_shield"],
	"boughs": ["long_sword", 1, "riveted_coat", "large_shield"],
	"spires": ["long_sword", 2, "riveted_coat", "large_shield"],
	"vorrhallow": ["long_sword", 2, "full_plate", "magic_shield"],
	"sunken": ["severance", 0, "full_plate", "magic_shield"],
	"evercrown": ["severance", 0, "full_plate", "magic_shield"],
}
## Pass 218: Thane Vorrund gives up the Severance (pass 217), so everything
## past his throne is fought with it.
const PAST_VORRUND_KIT := ["severance", 0, "full_plate", "magic_shield"]

## Each guardian of the rush: the abilities the critical path gives before its
## arena (the reach checker's order, test_reachability), and the stat finds in
## the rooms in reach by then: Life Fruits, Mana Dews and Potion Shards
## (`tools/levels/practice_kits.tscn`, 2026-11-24; shops' fruit not counted).
## The Evercrown's three are behind gates the checker's order doesn't open, and
## nothing more lies in reach past Thane Vorrund, so they take his counts. Spells bought in a
## shop count once their shop is on the way: Emberfall in Polesend, Wisplight in
## the Spires. The Rune Dagger waits in the Heartwood's Hornet Gallery.
const KITS := {
	"gnarlmaw": {"abilities": ["glove", "rune_dagger"], "life": 2, "dew": 4, "shards": 2},
	"foreman": {"abilities": ["glove", "rune_dagger"], "life": 2, "dew": 4, "shards": 2},
	"durgan": {"abilities": ["glove", "rune_dagger", "delvers_pick"], "life": 6, "dew": 6, "shards": 3},
	"gloamweaver": {"abilities": ["glove", "rune_dagger", "delvers_pick"], "life": 6, "dew": 6, "shards": 3},
	"haar_wyrm": {"abilities": ["glove", "rune_dagger", "delvers_pick", "boots", "torrent"], "life": 9, "dew": 9, "shards": 6},
	"snapcrown": {"abilities": ["glove", "rune_dagger", "delvers_pick", "boots", "torrent", "stride"], "life": 11, "dew": 9, "shards": 6},
	"skyrend": {"abilities": ["glove", "rune_dagger", "delvers_pick", "boots", "torrent", "stride", "fire", "thunder"], "life": 11, "dew": 9, "shards": 7},
	"thane_vorrund": {"abilities": ["glove", "rune_dagger", "delvers_pick", "boots", "torrent", "stride", "fire", "thunder", "wisplight", "seers_lens", "stillstone"], "life": 13, "dew": 9, "shards": 9},
	"likeness": {"abilities": ["glove", "rune_dagger", "delvers_pick", "boots", "torrent", "stride", "fire", "thunder", "wisplight", "seers_lens", "stillstone", "severance"], "life": 13, "dew": 9, "shards": 9},
	"drowned_warden": {"abilities": ["glove", "rune_dagger", "delvers_pick", "boots", "torrent", "stride", "fire", "thunder", "wisplight", "seers_lens", "stillstone", "severance"], "life": 13, "dew": 9, "shards": 9},
	"everbloom_avatar": {"abilities": ["glove", "rune_dagger", "delvers_pick", "boots", "torrent", "stride", "fire", "thunder", "wisplight", "seers_lens", "stillstone", "severance"], "life": 13, "dew": 9, "shards": 9},
	"everbloom_veins": {"abilities": ["glove", "rune_dagger", "delvers_pick", "boots", "torrent", "stride", "fire", "thunder", "wisplight", "seers_lens", "stillstone", "severance"], "life": 13, "dew": 9, "shards": 9},
	"everbloom": {"abilities": ["glove", "rune_dagger", "delvers_pick", "boots", "torrent", "stride", "fire", "thunder", "wisplight", "seers_lens", "stillstone", "severance"], "life": 13, "dew": 9, "shards": 9},
}
## Each guardian's name on the list and the report.
const NAMES := {
	"gnarlmaw": "Gnarlmaw", "foreman": "The Foreman", "durgan": "Durgan", "gloamweaver": "Gloamweaver",
	"haar_wyrm": "The Haar Wyrm", "snapcrown": "Snapcrown", "skyrend": "Skyrend", "thane_vorrund": "Thane Vorrund",
	"likeness": "The Likeness", "drowned_warden": "The Drowned Warden", "everbloom_avatar": "The Everbloom's Avatar",
	"everbloom_veins": "The Everbloom's Veins", "everbloom": "The Heart of the Everbloom",
}
## The guardians before each one are beaten, so the world is as a player finds
## it (the drained halls, the open gates), with their seeds and keys held.
## Abilities by the names the player knows them by.
const ABILITY_NAMES := {
	"glove": "Glove", "rune_dagger": "Rune Dagger", "delvers_pick": "Delver's Pick", "boots": "Boots",
	"torrent": "Deluge", "stride": "Stride", "fire": "Emberfall", "thunder": "Tempest Lance",
	"wisplight": "Wisplight", "seers_lens": "Seer's Lens", "stillstone": "Stillstone", "severance": "Severance",
}
const LOG_PATH := "user://practice_log.csv"
const LOG_HEAD := "when,boss,result,seconds,boss_health_left,damage_dealt,hits_landed,dps,damage_taken,hits_taken,flasks,magic_spent,spells,parries,guards,dashes,dodged,hits_by_attack,max_hp,blade,armor,shield"
## Seconds from the fight's end to the report (the banner shows first).
const REPORT_DELAY := 2.5

## The fight under way (or just over): counters the hooks add to. Empty when
## no practice runs.
static var stats := {}
## Guardians met this session: a second try skips the long reveal, as in play.
static var seen := {}
## Where the report goes once a fight ends (the game sets it): called with the
## finished stats.
static var on_end := Callable()
## The log file the report is added to (tests point it elsewhere).
static var log_path := LOG_PATH
## True while a practice world is up: GameState.save_game writes nothing.
static var running := false


static func active() -> bool:
	return BossRush.active() and bool(BossRush.run.get("practice", false))


static func boss_at(index: int) -> String:
	return String(BossRush.ORDER[index][0])


static func arena_at(index: int) -> String:
	return String(BossRush.ORDER[index][1])


static func boss_name(id: String) -> String:
	return String(NAMES.get(id, id.capitalize()))


## [blade, tempers, armor, shield] for a guardian: its zone's par kit, or the
## Severance's past Thane Vorrund.
static func gear_for(index: int) -> Array:
	var past_vorrund := index > BossRush.ORDER.find(["thane_vorrund", "vorrhallow/throne_hall"])
	if past_vorrund:
		return PAST_VORRUND_KIT
	return PAR_KIT[arena_at(index).get_slice("/", 0)]


## The list's line for a guardian: its kit.
static func kit_line(index: int) -> String:
	var kit: Dictionary = KITS[boss_at(index)]
	var gear := gear_for(index)
	var hp := 100 + GameState.LIFE_FRUIT_HP * int(kit.life)
	var flasks := 2 + int(kit.shards) / 3
	var names: Array[String] = []
	for a: String in kit.abilities:
		names.append(ABILITY_NAMES.get(a, a))
	return "%d HP, %d potions. %s%s, %s, %s. %s." % [hp, flasks, GameData.item(gear[0]).get("name", gear[0]),
		" +%d" % int(gear[1]) if int(gear[1]) > 0 else "", GameData.item(gear[2]).get("name", gear[2]),
		GameData.item(gear[3]).get("name", gear[3]), ", ".join(names)]


## Fills GameState (after new_game) with the kit for the guardian at `index`.
static func dress(index: int) -> void:
	var id := boss_at(index)
	var kit: Dictionary = KITS[id]
	var d := GameState.data
	for a: String in kit.abilities:
		d.abilities[a] = true
	var gear := gear_for(index)
	for g: String in [gear[0], gear[2], gear[3]]:
		GameState.obtain_gear(g)
	if int(gear[1]) > 0:
		d.tempers[String(gear[0])] = int(gear[1])
	d.max_hp = int(d.max_hp) + GameState.LIFE_FRUIT_HP * int(kit.life)
	d.max_mp = float(d.max_mp) + GameState.MANA_DEW_MP * int(kit.dew)
	d.potion_shards = int(kit.shards)
	d.flask_max = int(d.flask_max) + int(kit.shards) / 3
	for i in index:
		GameState.set_flag("boss:" + boss_at(i))
		var reward: Dictionary = BossArena.BOSSES.get(boss_at(i), {})
		if reward.has("key"):
			GameState.add_key(String(reward.key))
		if reward.has("ring") and not Array(d.rings).has(reward.ring):
			d.rings.append(reward.ring)
		if reward.get("mana_dew", false):
			# The Lantern Widow's Mana Dew comes with her key.
			d.max_mp = float(d.max_mp) + GameState.MANA_DEW_MP
	if seen.has(id):
		GameState.set_flag("seen:" + id)
	GameState.data.spell = "torrent" if kit.abilities.has("torrent") else String(d.get("spell", "torrent"))


## Starts the practice: a rush of one, on guardian `index`, its clock and
## counters at zero. The world must already be in the arena.
static func begin(index: int) -> void:
	BossRush.begin("", Vector2.ZERO)
	BossRush.run.index = index
	BossRush.run.practice = true
	seen[boss_at(index)] = true
	stats = {
		"boss": boss_at(index), "index": index, "time": 0.0, "started": false, "result": "",
		"dealt": 0, "landed": 0, "taken": 0, "hits_taken": 0, "by_attack": {},
		"flasks": 0, "mp": 0.0, "spells": 0, "parries": 0, "guards": 0, "dashes": 0, "dodged": 0,
		"boss_left": 1.0,
	}


## The arena the practice is in, or null.
static func arena(tree: SceneTree) -> BossArena:
	for a: Node in tree.get_nodes_in_group("boss_arena"):
		return a as BossArena
	return null


## The fight's clock runs from the boss's wake to its fall or yours.
static func tick(tree: SceneTree, delta: float) -> void:
	if not active() or stats.is_empty() or stats.result != "":
		return
	var a := arena(tree)
	if a != null and a.fighting:
		stats.started = true
	if stats.started:
		stats.time = float(stats.time) + delta
	if a != null and a.boss != null and is_instance_valid(a.boss) and a.boss.has_method("health_fraction"):
		stats.boss_left = float(a.boss.health_fraction())


## Adds `n` to the counter `what` (the player's hooks call this).
static func note(what: String, n: float = 1.0) -> void:
	if not active() or stats.is_empty() or stats.result != "":
		return
	if stats[what] is int:
		stats[what] = int(stats[what]) + roundi(n)
	else:
		stats[what] = float(stats[what]) + n


## A blow landed on the player, or turned: by what, and how it ended
## ("parried", "guarded", "hit" or "ignored"; "ignored" while dashing is a dodge).
static func note_attack(source: Node, result: String, dashing: bool) -> void:
	if not active() or stats.is_empty() or stats.result != "":
		return
	match result:
		"parried":
			note("parries")
		"guarded":
			note("guards")
			_tally(attack_name(source))
		"hit":
			_tally(attack_name(source))
		"ignored":
			if dashing:
				note("dodged")


static func _tally(name: String) -> void:
	var by: Dictionary = stats.by_attack
	by[name] = int(by.get(name, 0)) + 1
	note("hits_taken")


## A readable name for what struck: the shot's own class ("Shockwave"), or the
## guardian's move ("Durgan: charge") when it was the guardian itself.
static func attack_name(source: Node) -> String:
	if source == null or not is_instance_valid(source):
		return "Unknown"
	var who: Node = source
	var piece := ""
	if source is BossSegment and source.boss != null:
		who = source.boss
		if source.get("breath") is String:
			piece = String(source.get("breath")) + " head "
	var cls := _class_of(who)
	var state = who.get("state")
	if who.get("step") is String and piece != "":
		state = who.get("step")
	if state is String and String(state) != "" and (who.is_in_group("enemy") or who is BossSegment or piece != ""):
		var a := arena(source.get_tree()) if source.is_inside_tree() else null
		if a != null and who == a.boss:
			return "%s: %s%s" % [cls, piece, String(state).replace("_", " ")]
	return _class_of(source)


static func _class_of(n: Node) -> String:
	var s: Script = n.get_script()
	var cls: String = String(s.get_global_name()) if s != null else ""
	return words(cls if cls != "" else String(n.name))


## "HydraGeyser" as "Hydra geyser".
static func words(cls: String) -> String:
	var out := ""
	for i in cls.length():
		var c := cls[i]
		if i > 0 and c != c.to_lower() and cls[i - 1] != " ":
			out += " " + c.to_lower()
		else:
			out += c
	return out


## The fight is over: "won", "lost" or "left". Logs it and hands the report on.
static func finish(result: String) -> void:
	if not active() or stats.is_empty() or stats.result != "":
		return
	stats.result = result
	if result == "won":
		stats.boss_left = 0.0
	BossRush.run.over = true
	write_log(stats)
	if on_end.is_valid():
		on_end.call(stats.duplicate(true))


static func dps(s: Dictionary) -> float:
	return float(s.dealt) / float(s.time) if float(s.time) > 0.5 else 0.0


## The report's rows, for the list menu: {"label", "right", "detail"}.
static func report_rows(s: Dictionary) -> Array:
	var gear := gear_for(int(s.index))
	var rows := [
		{"label": "Result", "right": "Won" if s.result == "won" else "%s, boss at %d%%" % [{"lost": "Fallen", "left": "Left"}.get(s.result, s.result), roundi(float(s.boss_left) * 100.0)],
			"detail": "%s's health left: %d%%." % [boss_name(s.boss), roundi(float(s.boss_left) * 100.0)]},
		{"label": "Time", "right": Trials.format_time(float(s.time)), "detail": "From the guardian's wake to the last blow."},
		{"label": "Damage dealt", "right": str(s.dealt), "detail": "%d blows landed, %.1f damage a second." % [s.landed, dps(s)]},
		{"label": "Damage taken", "right": str(s.taken), "detail": "%d blows landed on you (guarded ones count)." % s.hits_taken},
	]
	var by: Dictionary = s.by_attack
	var names := by.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return int(by[a]) > int(by[b]))
	for n: String in names:
		rows.append({"label": "  " + n, "right": "x%d" % int(by[n]), "detail": "How often this hit you."})
	rows.append_array([
		{"label": "Potions drunk", "right": str(s.flasks), "detail": ""},
		{"label": "Magic spent", "right": str(roundi(float(s.mp))), "detail": "%d spells cast." % s.spells},
		{"label": "Parries", "right": str(s.parries), "detail": "%d blows guarded." % s.guards},
		{"label": "Dodges", "right": str(s.dodged), "detail": "Blows passed through in a dash, of %d dashes." % s.dashes},
		{"label": "Kit", "right": "%d HP" % _max_hp(s), "detail": "%s +%d, %s, %s." % [GameData.item(gear[0]).get("name", gear[0]), int(gear[1]), GameData.item(gear[2]).get("name", gear[2]), GameData.item(gear[3]).get("name", gear[3])]},
		{"label": "Log", "detail": ProjectSettings.globalize_path(log_path)},
		{"label": "Again", "detail": "Fight %s again." % boss_name(s.boss)},
		{"label": "Back to the list", "detail": "Choose another guardian."},
	])
	return rows


static func _max_hp(s: Dictionary) -> int:
	return 100 + GameState.LIFE_FRUIT_HP * int(KITS[s.boss].life)


## One CSV line for the fight.
static func log_line(s: Dictionary) -> String:
	var gear := gear_for(int(s.index))
	var by: Dictionary = s.by_attack
	var parts: Array[String] = []
	for n: String in by:
		parts.append("%s:%d" % [n, int(by[n])])
	var cells := [Time.get_datetime_string_from_system(), s.boss, s.result, "%.1f" % float(s.time),
		"%d" % roundi(float(s.boss_left) * 100.0), s.dealt, s.landed, "%.1f" % dps(s), s.taken, s.hits_taken,
		s.flasks, roundi(float(s.mp)), s.spells, s.parries, s.guards, s.dashes, s.dodged,
		"\"" + ";".join(parts).replace("\"", "'") + "\"", _max_hp(s), gear[0], gear[2], gear[3]]
	return ",".join(cells.map(func(c: Variant) -> String: return str(c)))


static func write_log(s: Dictionary) -> void:
	var fresh := not FileAccess.file_exists(log_path)
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE if not fresh else FileAccess.WRITE)
	if f == null:
		return
	if fresh:
		f.store_line(LOG_HEAD)
	f.seek_end()
	f.store_line(log_line(s))
	f.close()


static func abandon() -> void:
	stats = {}
	BossRush.abandon()

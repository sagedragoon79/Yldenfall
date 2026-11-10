class_name BossArena
extends Node2D
## Runs a boss room (room header `boss: <id>`). Roots seal every door except
## the one the player came in by; once the player is well inside, that one
## seals too and the boss wakes. Beating the boss gives its reward, sets the
## `boss:<id>` flag (so it never returns) and opens the doors.

signal started
signal won
## The boss crossed a PHASES mark (1 for the first, 2 for the second).
signal phase_broken(level: int)

## Boss id -> how to make it and what it gives.
const BOSSES := {
	"gnarlmaw": {"ring": "thaw", "ring_name": "Thaw Seed", "skill_points": 1},
	"foreman": {"ability": "delvers_pick", "title": "Delver's Pick",
		"text": "Strike down in midair to bounce off foes and spikes. Breaks cracked stone.", "music": "miniboss"},
	"durgan": {"ring": "sun", "ring_name": "Sun Seed", "skill_points": 1, "music": "durgan"},
	"gloamweaver": {"key": "lantern", "title": "Lantern Key", "skill_points": 1, "mana_dew": true,
		"text": "Its light opens the way to the Haar Spring. Your magic grows.", "music": "gloamweaver"},
	"haar_wyrm": {"ring": "fall", "ring_name": "Fall Seed", "skill_points": 1, "music": "haar_wyrm"},
	"snapcrown": {"title": "The Bloom Wilts", "skill_points": 1, "music": "snapcrown"},
	"skyrend": {"key": "sky", "title": "Sky Key", "skill_points": 1,
		"text": "The storm breaks over the Spires. Its key opens Vorrhallow's upper gate.", "music": "skyrend"},
	"thane_vorrund": {"ring": "frost", "ring_name": "Frost Seed", "skill_points": 1, "music": "vorrund",
		"blade": "severance", "title": "Severance",
		"text": "Thane Vorrund weeps at last, and gives up his grafting blade. With it, the Frost Seed."},
	"likeness": {"title": "The Mirror Breaks", "skill_points": 1, "music": "likeness",
		"text": "Your shadow is gone from the glass. Nothing now stands before the gate of the Evercrown but its four sockets."},
	"everbloom_avatar": {"title": "The Avatar Shatters", "skill_points": 1, "music": "everbloom",
		"text": "Its borrowed body breaks apart, and the light that wore it flees up the veins of the Everbloom."},
	"everbloom_veins": {"title": "The Veins Go Dark", "skill_points": 1, "music": "everbloom",
		"text": "Starved of its light, the core gutters. Above, the heart of the Everbloom lies open."},
	"everbloom": {"title": "The Heart of the Bloom Dies", "skill_points": 1, "music": "everbloom",
		"text": "The Tree's roots close over the dead heart, and the light of its springs runs home down the trunk."},
	"clockwork_alpha": {"stat_item": "life_fruit", "title": "Life Fruit", "music": "miniboss",
		"text": "A Life Fruit was locked in the Alpha's winding-chest, the king's own reward for his first hound."},
	"bark_captain": {"stat_item": "mana_dew", "title": "Mana Dew", "music": "miniboss",
		"text": "Dew gathered in the Captain's leaf-crown all the centuries it stood guard. Your magic grows."},
	"hag_matriarch": {"stat_item": "mana_dew", "title": "Mana Dew", "music": "miniboss",
		"text": "The wisp in her staff gutters out into a single drop of bog light. Your magic grows."},
	"drowned_warden": {"armor": "elven_plate", "title": "Elven Plate", "skill_points": 1, "music": "warden",
		"text": "The Warden's own harness, bronze and spring-stone: take 60% less damage. The Source is free."},
}
## How far the player must be from the entry door before the fight starts.
## Hit-stop when a phase breaks (design bible 6.7, "boss stagger").
const PHASE_HITSTOP := 0.2
const START_DISTANCE := 64.0
const OPEN_DELAY := 1.2
## A guardian's fall rings a fanfare of its own (pass 222; it had been `item`,
## the chime of any find), and the boss theme drops away fast enough for it.
const WIN_SOUND := "boss_won"
const WIN_FADE := 0.4
## Seconds from the Everbloom's death to the ending (the banner shows first).
const ENDING_DELAY := 4.0

var boss_id := ""
## True once the fight's assets are loaded (tests).
var warmed := false
var room: Room
var boss: Node2D
var fighting := false
var entry_door := 0
var seals := {}  # door number -> ArenaSeal

var _open_timer := -1.0
## Phase marks (the boss's PHASES) its health has crossed this fight.
var phases_passed := 0


func _ready() -> void:
	add_to_group("boss_arena")
	warm.call_deferred()


## Loads what the fight will need while the room itself is loading, so the
## fight doesn't hitch when it starts mid-play: the boss's sprite sheet and its
## music (pass 99; Durgan's first frame cost about 140 ms).
func warm() -> void:
	warmed = true
	if boss_id == "haar_wyrm" and defeated_before() and room != null:
		# The Haar Spring's cistern stays full for good once he is beaten.
		HaarWyrm.build_cistern(room, true)
	if boss_id == "" or defeated_before():
		return
	if Sheet.exists(boss_id):
		Sheet.get_sheet(boss_id)
	Music.stream_for(String(BOSSES.get(boss_id, {}).get("music", "boss")))


## Beaten for good, so the arena stays quiet. In a boss rush every boss of
## the rush fights again (BossRush).
func defeated_before() -> bool:
	if BossRush.active():
		return BossRush.current_boss() != boss_id
	return GameState.flag("boss:" + boss_id)


func _physics_process(delta: float) -> void:
	if room == null or defeated_before() and not fighting:
		return
	_track_phases()
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.get_parent() != room:
		return
	if _open_timer >= 0.0:
		_open_timer -= delta
		if _open_timer < 0.0:
			_open_doors()
		return
	if entry_door == 0:
		entry_door = _nearest_door(p.global_position)
		for n: int in room.doors:
			if n != entry_door:
				_seal(n)
		return
	if not fighting and _distance_to_door(entry_door, p.global_position) >= START_DISTANCE and p.is_on_floor():
		_start()


## Watches the boss's health against its PHASES marks, and its own phase.
## Crossing one is a phase break (design bible 13.3, Audio): a stinger, the music ducks under it and then
## rises a semitone, and the screen shakes.
func _track_phases() -> void:
	if not fighting or boss == null or not is_instance_valid(boss) or boss.get("state") == "dead":
		return
	var marks: Array = boss.get_script().get_script_constant_map().get("PHASES", [])
	var frac: float = boss.health_fraction()
	var crossed := 0
	for m: float in marks:
		if frac <= m:
			crossed += 1
	# A boss may reach a phase another way (the Lantern Widow comes down for good
	# once every lantern is broken): its own phase counts too, so the break rings
	# when the fight changes, and not again when its health catches up (pass 252).
	var own = boss.get("phase")
	if own is int:
		# A boss with no health marks turns by its own phase alone (the Haar
		# Wyrm's turns as each head dies): up to two breaks.
		crossed = clampi(maxi(crossed, own - 1), 0, marks.size() if not marks.is_empty() else 2)
	if crossed > phases_passed:
		phases_passed = crossed
		Sfx.play("phase_break", 0.0, 3.0)
		Music.duck(1.4, 12.0)
		Music.intensify(crossed)
		Feel.add_trauma(0.35)
		# The boss stagger hit-stop (bible 6.7): the world holds on the break.
		Feel.hitstop(PHASE_HITSTOP)
		phase_broken.emit(crossed)


func _start() -> void:
	fighting = true
	_seal(entry_door)
	match boss_id:
		"gnarlmaw":
			var r := Gnarlmaw.new()
			r.room = room
			boss = r
			r.defeated.connect(_on_defeated)
		"foreman":
			# The golem waits at the end of the hall away from the way in.
			var f := Foreman.new()
			var w := float(room.size_tiles.x * Room.TILE)
			f.arena = Rect2(Room.TILE, 4 * Room.TILE, w - 2 * Room.TILE, 16 * Room.TILE)
			var px := p_x()
			f.position = Vector2(w - 6 * Room.TILE if px < w * 0.5 else 6 * Room.TILE, f.arena.end.y)
			boss = f
			f.defeated.connect(_on_defeated)
		"durgan":
			# The drill waits across the lift from the way in, the shaft behind it.
			var z := Durgan.new()
			var w := float(room.size_tiles.x * Room.TILE)
			z.arena = Rect2(Room.TILE, 4 * Room.TILE, w - 2 * Room.TILE, 16 * Room.TILE)
			var px := p_x()
			z.position = Vector2(w - 7 * Room.TILE if px < w * 0.5 else 7 * Room.TILE, z.arena.end.y)
			var shaft := LiftShaft.new()
			shaft.area = z.arena
			shaft.boss = z
			room.add_child(shaft)
			boss = z
			z.defeated.connect(_on_defeated)
		"gloamweaver":
			# The widow waits in the dark across the chapel from the way in.
			var r := Gloamweaver.new()
			var w := float(room.size_tiles.x * Room.TILE)
			r.arena = Rect2(Room.TILE, 4 * Room.TILE, w - 2 * Room.TILE, 16 * Room.TILE)
			var px := p_x()
			r.position = Vector2(w - 8 * Room.TILE if px < w * 0.5 else 8 * Room.TILE, r.floor_y())
			boss = r
			r.defeated.connect(_on_defeated)
		"haar_wyrm":
			# The hydra lies in the tunnel's mouth behind the cistern, in the middle.
			var z := HaarWyrm.new()
			var w := float(room.size_tiles.x * Room.TILE)
			z.arena = Rect2(Room.TILE, 4 * Room.TILE, w - 2 * Room.TILE, 16 * Room.TILE)
			z.position = Vector2(w * 0.5, 10 * Room.TILE)
			boss = z
			z.defeated.connect(_on_defeated)
		"snapcrown":
			# The bloom is rooted in the middle of the crown-leaf.
			var k := Snapcrown.new()
			var w := float(room.size_tiles.x * Room.TILE)
			k.arena = Rect2(Room.TILE, 4 * Room.TILE, w - 2 * Room.TILE, 16 * Room.TILE)
			k.position = Vector2(w * 0.5, k.arena.end.y)
			boss = k
			k.defeated.connect(_on_defeated)
		"skyrend":
			# The roc comes down out of the storm over the middle island.
			var b := Skyrend.new()
			var w := float(room.size_tiles.x * Room.TILE)
			# The roost has open sky above the fight for the wide camera; the roc
			# keeps to the 16 rows above the floor.
			var top := float((room.size_tiles.y - 19) * Room.TILE)
			b.arena = Rect2(Room.TILE, top, w - 2 * Room.TILE, 16 * Room.TILE)
			boss = b
			b.defeated.connect(_on_defeated)
		"thane_vorrund":
			# The king waits before his throne, the dais at the hall's east end.
			var k := ThaneVorrund.new()
			var w := float(room.size_tiles.x * Room.TILE)
			k.arena = Rect2(Room.TILE, 4 * Room.TILE, w - 2 * Room.TILE, 16 * Room.TILE)
			k.dais = Rect2(46 * Room.TILE, 14 * Room.TILE, w - 47 * Room.TILE, 6 * Room.TILE)
			k.position = Vector2(40 * Room.TILE, k.arena.end.y)
			boss = k
			k.defeated.connect(_on_defeated)
		"likeness":
			# Your reflection, on the far side of the mirror down the middle of the hall.
			var e := Likeness.new()
			var w := float(room.size_tiles.x * Room.TILE)
			e.arena = Rect2(Room.TILE, 4 * Room.TILE, w - 2 * Room.TILE, 16 * Room.TILE)
			boss = e
			e.defeated.connect(_on_defeated)
		"everbloom_avatar":
			# The Everbloom's avatar comes down off its throne at the hall's east end.
			var a := EvilAvatar.new()
			var w := float(room.size_tiles.x * Room.TILE)
			a.arena = Rect2(Room.TILE, 4 * Room.TILE, w - 2 * Room.TILE, 16 * Room.TILE)
			a.position = Vector2(46 * Room.TILE, a.arena.end.y)
			boss = a
			a.defeated.connect(_on_defeated)
		"everbloom_veins":
			# The core hangs in the vault at the top of the shaft; its veins are in the room.
			var c := EvilCore.new()
			var w := float(room.size_tiles.x * Room.TILE)
			var h := float(room.size_tiles.y * Room.TILE)
			c.arena = Rect2(Room.TILE, 4 * Room.TILE, w - 2 * Room.TILE, h - 6 * Room.TILE)
			c.position = Vector2(w * 0.5, 6 * Room.TILE)
			boss = c
			c.defeated.connect(_on_defeated)
		"everbloom":
			# The heart hangs high over the middle of its chamber, out of any blade's reach.
			var e := EvilHeart.new()
			var w := float(room.size_tiles.x * Room.TILE)
			e.arena = Rect2(Room.TILE, 4 * Room.TILE, w - 2 * Room.TILE, 17 * Room.TILE)
			e.position = Vector2(w * 0.5, 8 * Room.TILE)
			boss = e
			e.defeated.connect(_on_defeated)
		"clockwork_alpha":
			# The Alpha waits at the far end of its den from the shaft you drop in by.
			var a := ClockworkAlpha.new()
			var w := float(room.size_tiles.x * Room.TILE)
			a.arena = Rect2(Room.TILE, 4 * Room.TILE, w - 2 * Room.TILE, float(room.size_tiles.y - 6) * Room.TILE)
			var px := p_x()
			a.position = Vector2(w - 7 * Room.TILE if px < w * 0.5 else 7 * Room.TILE, a.arena.end.y)
			boss = a
			a.defeated.connect(_on_defeated)
		"bark_captain":
			# The Captain keeps the far end of his yard from the Sylvarre door.
			var c := BarkCaptain.new()
			var cw := float(room.size_tiles.x * Room.TILE)
			c.arena = Rect2(Room.TILE, 4 * Room.TILE, cw - 2 * Room.TILE, float(room.size_tiles.y - 7) * Room.TILE)
			c.position = Vector2(cw - 7 * Room.TILE, c.arena.end.y)
			boss = c
			c.defeated.connect(_on_defeated)
		"hag_matriarch":
			# The Matriarch waits at the far end of her mire from the Polesend door.
			var m := HagMatriarch.new()
			var mw := float(room.size_tiles.x * Room.TILE)
			m.arena = Rect2(Room.TILE, 4 * Room.TILE, mw - 2 * Room.TILE, float(room.size_tiles.y - 10) * Room.TILE)
			m.position = Vector2(mw - 7 * Room.TILE, m.arena.end.y)
			boss = m
			m.defeated.connect(_on_defeated)
		"drowned_warden":
			# The Warden rises out of the middle of the Wellspring.
			var d := DrownedWarden.new()
			d.surface_y = _surface_y()
			d.lane = Vector2(14 * Room.TILE, (room.size_tiles.x - 14) * Room.TILE)
			d.position = Vector2(room.size_tiles.x * Room.TILE * 0.5, d.surface_y + DrownedWarden.LURK_DEPTH)
			boss = d
			d.defeated.connect(_on_defeated)
		_:
			push_warning("Unknown boss: " + boss_id)
			return
	room.add_child(boss)
	boss.begin()
	Music.play(BOSSES.get(boss_id, {}).get("music", "boss"), 0.5)
	started.emit()


func _on_defeated() -> void:
	if BossRush.active():
		# The rush wins nothing again and opens no doors: on to the next arena.
		Sfx.play(WIN_SOUND, 0.0)
		Music.play(BossRush.MUSIC, 2.0)
		won.emit()
		var world := get_tree().get_first_node_in_group("world") as World
		var p := get_tree().get_first_node_in_group("player") as Player
		if world != null and p != null:
			BossRush.on_boss_down(world, p)
		return
	var reward: Dictionary = BOSSES.get(boss_id, {})
	GameState.set_flag("boss:" + boss_id)
	var rings: Array = GameState.data.rings
	if reward.has("ring") and not rings.has(reward.ring):
		rings.append(reward.ring)
	var points := int(reward.get("skill_points", 0))
	GameState.data.skill_points = int(GameState.data.skill_points) + points
	Sfx.play(WIN_SOUND, 0.0)
	if reward.has("key"):
		# A key and, for the Lantern Widow, the Mana Dew she guarded.
		var p := get_tree().get_first_node_in_group("player") as Player
		GameState.add_key(reward.key)
		if reward.get("mana_dew", false) and p != null:
			GameState.grant_stat_item("mana_dew", p)
		GameState.banner.emit(reward.title, reward.text)
	elif reward.has("armor"):
		# Armor the boss wore or kept goes straight on (the Warden's Elven Plate).
		var p := get_tree().get_first_node_in_group("player") as Player
		GameState.obtain_gear(String(reward.armor), p)
		if p != null:
			GameState.capture(p)
		GameState.banner.emit(reward.title, reward.text)
	elif reward.has("blade"):
		# The blade the boss kept goes straight into your hand: Thane Vorrund
		# carried Severance, his grafting blade (pass 217).
		var p := get_tree().get_first_node_in_group("player") as Player
		GameState.data.abilities[reward.blade] = true
		GameState.obtain_gear(String(reward.blade), p)
		if p != null:
			p.abilities[reward.blade] = true
			GameState.capture(p)
		GameState.banner.emit(reward.title, reward.text)
	elif reward.has("stat_item"):
		# A mini-boss's prize: a stat item it kept (the Clockwork Alpha's Life Fruit).
		var p := get_tree().get_first_node_in_group("player") as Player
		if p != null:
			GameState.grant_stat_item(reward.stat_item, p)
			GameState.capture(p)
		GameState.banner.emit(reward.title, reward.text)
	elif reward.has("ability"):
		# The ability the boss guarded (the Foreman drops the Delver's Pick from its back).
		var p := get_tree().get_first_node_in_group("player") as Player
		GameState.data.abilities[reward.ability] = true
		if p != null:
			p.abilities[reward.ability] = true
			GameState.capture(p)
		GameState.banner.emit(reward.title, reward.text)
	elif reward.has("text"):
		# A guardian that leaves only its story (the Likeness, the Everbloom's three).
		GameState.banner.emit(reward.title, reward.text)
	else:
		GameState.banner.emit(reward.get("ring_name", reward.get("title", "Victory")), point_line(points))
	# The banner tells the story; the skill point, when it doesn't, is a toast
	# (pass 220: until then a boss with a line of its own never said it gave one).
	if points > 0 and reward.has("text"):
		GameState.toast.emit(point_line(points))
	_open_timer = OPEN_DELAY
	Music.play("", WIN_FADE)
	won.emit()
	if boss_id == "everbloom":
		# The last fight: the ending follows once the banner has had its moment.
		# The wait stops while the game is paused (pass 247: it ran on under the
		# pause menu and the ending shut it), and it belongs to the arena, so a
		# world torn down meanwhile never ends the game.
		get_tree().create_timer(ENDING_DELAY, false, false, true).timeout.connect(_begin_ending)


func _begin_ending() -> void:
	if is_inside_tree():
		GameState.begin_ending()


## True from a guardian's killing blow until the arena opens: the win is
## the player's, so nothing left in the air (a spike, a shard, the flood) can
## kill them in the boss's dying moments and lose it (pass 239).
func falling() -> bool:
	return fighting and boss != null and is_instance_valid(boss) and bool(boss.get("dead"))


## Any arena whose guardian is falling.
## Whether a guardian's fight is going on anywhere (pass 455): its doors
## sealed and the guardian up or falling.
static func any_fighting(tree: SceneTree) -> bool:
	for a: Node in tree.get_nodes_in_group("boss_arena"):
		if (a as BossArena).fighting:
			return true
	return false


static func any_falling(tree: SceneTree) -> bool:
	for a: Node in tree.get_nodes_in_group("boss_arena"):
		if (a as BossArena).falling():
			return true
	return false


## "+1 skill point", "+2 skill points".
static func point_line(points: int) -> String:
	return "+%d skill point" % points if points == 1 else "+%d skill points" % points


func _open_doors() -> void:
	fighting = false
	for n: int in seals:
		if is_instance_valid(seals[n]):
			seals[n].open()
	seals.clear()
	Music.for_room(room)


func _seal(n: int) -> void:
	if seals.has(n) or not room.doors.has(n):
		return
	var d: Dictionary = room.doors[n]
	var r: Rect2 = d.rect
	# The roots fill the doorway and the column inside it.
	var area: Rect2
	match d.edge:
		"left":
			area = Rect2(r.position.x, r.position.y, r.size.x + Room.TILE, r.size.y)
		"right":
			area = Rect2(r.position.x - Room.TILE, r.position.y, r.size.x + Room.TILE, r.size.y)
		_:
			return
	var seal := ArenaSeal.new()
	seal.style = "iron" if room.zone in ["tower", "spires", "vorrhallow", "evercrown", "sunken"] else "roots"
	seal.size = area.size
	seal.position = area.position
	room.add_child(seal)
	seals[n] = seal


## The top of the room's deep water (the Wellspring), from its SwimWater.
func _surface_y() -> float:
	for c in room.get_children():
		if c is SwimWater:
			var top := INF
			for cell: Vector2i in c.cells:
				top = minf(top, cell.y * Room.TILE)
			return top
	return float(room.size_tiles.y * Room.TILE) * 0.5


func p_x() -> float:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	return p.global_position.x if p != null else 0.0


func _nearest_door(pos: Vector2) -> int:
	var best := 0
	var best_d := INF
	for n: int in room.doors:
		var d := _distance_to_door(n, pos)
		if d < best_d:
			best_d = d
			best = n
	return best


func _distance_to_door(n: int, pos: Vector2) -> float:
	var r: Rect2 = room.doors[n].rect
	return Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y)).distance_to(pos)

class_name BossRush
extends RefCounted
## The boss rush (design bible 11): a whole clear at 100% (the `lord` flag)
## opens it at the Ringreader of the Hall of Rings. The ring carries you through
## every boss of the Tree in the order you met them, each in its own arena,
## entered by the door you first came in by. Between fights the ring mends a
## third of your health and all your magic. Nothing is won again: no rings,
## keys or skill points, and the Everbloom's death plays no ending. A blow that
## would kill you ends the rush instead and returns you to the Ringreader, whole. The
## clock runs from the first arena to the last blow; the best time is kept with
## the trials' (`GameState.data.trials`, under RECORD).
##
## Heard (pass 157): between fights the arenas play the trials' theme, the
## inner rings carrying you on, and each boss brings its own music when it
## rises. A boss down rings the bronze bell soft as the ring mends you
## (rush_mend); the win rings it three times up the chord (rush_won); a fall
## tolls it low (rush_fall).

## Boss id and its arena, in the order of the critical path (bible 4.2), the
## Drowned Warden of the optional Sunken Spring before the Evercrown.
const ORDER := [
	["gnarlmaw", "heartwood/root_chamber"],
	["foreman", "tower/foreman_hall"],
	["durgan", "tower/kettleforge_lift"],
	["gloamweaver", "haar/sunken_chapel"],
	["haar_wyrm", "haar/spring_of_haar"],
	["snapcrown", "boughs/crown_leaf"],
	["skyrend", "spires/roost"],
	["thane_vorrund", "vorrhallow/throne_hall"],
	["likeness", "vorrhallow/evercrown_gate"],
	["drowned_warden", "sunken/wellspring"],
	["everbloom_avatar", "evercrown/throne"],
	["everbloom_veins", "evercrown/veins"],
	["everbloom", "evercrown/heart"],
]
## The door of each arena the rush brings you through.
const ENTRY_DOOR := 1
## The best time's key in GameState.data.trials.
const RECORD := "boss_rush"
const UNLOCK_FLAG := "lord"
## Between fights: a third of your health back, and all your magic.
const MEND := 1.0 / 3.0
## Seconds from a boss's fall to the next arena (its banner shows first).
const NEXT_DELAY := 2.5
## While the world is mid-fade, a move waits and tries again this often.
const RETRY := 0.1
## Between fights: the trials' theme, the inner rings.
const MUSIC := "trials"

## The rush under way: {"index", "time", "back_room", "back_pos"}, or empty.
## "over" is set once it is won or lost, while the ring carries you back:
## the clock stops and a second fall does nothing.
static var run := {}


static func unlocked() -> bool:
	return GameState.flag(UNLOCK_FLAG)


static func active() -> bool:
	return not run.is_empty()


static func best() -> float:
	return float(GameState.data.trials.get(RECORD, INF))


## The boss the rush is on, or "".
static func current_boss() -> String:
	if not active() or int(run.index) >= ORDER.size():
		return ""
	return String(ORDER[int(run.index)][0])


static func begin(back_room: String, back_pos: Vector2) -> void:
	run = {"index": 0, "time": 0.0, "back_room": back_room, "back_pos": back_pos}


static func tick(delta: float) -> void:
	if active() and not run.get("over", false):
		run.time = float(run.time) + delta


## A boss of the rush has fallen. Returns true when it was the last.
static func advance() -> bool:
	run.index = int(run.index) + 1
	return int(run.index) >= ORDER.size()


## Ends a finished rush: keeps the best time. Returns {"time", "best", "record"}.
static func finish() -> Dictionary:
	if not active():
		return {}
	var t := float(run.time)
	var old := best()
	var record := t < old
	if record:
		GameState.data.trials[RECORD] = snappedf(t, 0.01)
	return {"time": t, "best": minf(t, old), "record": record}


static func abandon() -> void:
	run = {}


## Mends the player between fights.
static func mend(p: Player) -> void:
	p.hp = mini(p.max_hp, p.hp + ceili(p.max_hp * MEND))
	p.mp = p.max_mp
	p.health_changed.emit(p.hp, p.max_hp)


## Starts a rush from where the player stands (by the Ringreader): full health,
## magic and potions, then on to the first arena.
static func start(world: World, p: Player) -> void:
	begin(world.room.id, p.global_position)
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.flask_charges = p.flask_max
	p.health_changed.emit(p.hp, p.max_hp)
	Sfx.play("trial_begin", 0.0)
	go(world)


## Carries the player to the current boss's arena.
static func go(world: World) -> void:
	if not active() or current_boss() == "" or not is_instance_valid(world):
		return
	if world.busy:
		_later(world, RETRY, func() -> void: go(world))
		return
	world.travel_to_door(String(ORDER[int(run.index)][1]), ENTRY_DOOR)


## Runs `then` after `seconds` of play (the timer stops with the pause menu),
## so long as the world is still there: quitting mid-rush frees it.
static func _later(world: World, seconds: float, then: Callable) -> void:
	var ref: WeakRef = weakref(world)
	world.get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		if ref.get_ref() != null:
			then.call())


## A boss of the rush has fallen: on to the next, or the rush is won.
static func on_boss_down(world: World, p: Player) -> void:
	if not active():
		return
	if BossPractice.active():
		BossPractice.finish("won")
		return
	if advance():
		var result := finish()
		GameState.banner.emit("The Rush Is Won", "%s%s" % [Trials.format_time(result.time), "  A new best!" if result.record else "  Best " + Trials.format_time(result.best)])
		Sfx.play("rush_won", 0.0)
		if result.record:
			Sfx.play("trial_record", 0.0, -3.0)
		run.over = true
		_later(world, NEXT_DELAY, func() -> void: back(world, p))
		return
	mend(p)
	Sfx.play("rush_mend", 0.0)
	GameState.toast.emit("%d of %d. The ring mends you." % [int(run.index), ORDER.size()])
	_later(world, NEXT_DELAY, func() -> void: go(world))


## A blow that would have killed you: the rush ends and you go back whole.
static func fall(world: World, p: Player) -> void:
	if not active() or run.get("over", false):
		return
	if BossPractice.active():
		BossPractice.finish("lost")
		return
	run.over = true
	GameState.banner.emit("The Rush Ends", "Fallen at %d of %d." % [int(run.index) + 1, ORDER.size()])
	Sfx.play("rush_fall", 0.0)
	Music.play("", 0.6)
	back(world, p)


## Returns the player to where the rush began and ends it.
static func back(world: World, p: Player) -> void:
	if not active() or not is_instance_valid(world):
		return
	if world.busy:
		# Mid-fade (a fall as the ring carries you on): go once it settles.
		_later(world, RETRY, func() -> void: back(world, p))
		return
	var room_id: String = run.back_room
	var pos: Vector2 = run.back_pos
	abandon()
	p.hp = p.max_hp
	p.health_changed.emit(p.hp, p.max_hp)
	world.travel(room_id, pos)

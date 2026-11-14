class_name Drop
extends CharacterBody2D
## Food and magic that defeated enemies sometimes leave (design bible 7: drops
## are gold, MP orbs and rare items). Bread heals, as it did in Yldenfall; a
## mana orb refills magic. From the Tower on, some enemies leave Yldenfall's
## Blightcap instead: a skull-marked flask that sickens you if you walk over it.
## Rarely, any foe leaves one of the original's rare items (pass 147): a War
## Glove (the original's Glove: harder blows for a while) or an Barkbalm.
## All of them pop out, settle on the floor and wait, blinking before they vanish.

const GRAVITY := 700.0
const COLLECT_RANGE := 14.0
const LIFETIME := 10.0
## How far in from a side edge a drop comes to rest when that edge is a door:
## the second open tile, where a hop clears it and lands short of the door.
const DOOR_CLEAR := 40.0
## How many tiles up the side of a spiked pit a drop may step to rest beside it.
const SPIKE_STEP_RISE := 4
const BREAD_HEAL := 15
## The great loaf, the original's largest bread: what a slain Silt Adder leaves (pass 281).
const LOAF_HEAL := 40
const MANA_GAIN := 12.0
## The game's chances per kill (bible 5.3, Drops): bread, a mana orb, poison
## (from enemies with `poison_drops`) and a rare item (any enemy), whose War
## Glove share is GLOVE_SHARE. The test runner zeroes the live chances below.
const BREAD_CHANCE := 0.08
const MANA_CHANCE := 0.1
const POISON_CHANCE := 0.07
const RARE_CHANCE := 0.025
## The live chances. Tests set them to 0 or 1.
static var bread_chance := BREAD_CHANCE
static var mana_chance := MANA_CHANCE
static var poison_chance := POISON_CHANCE
static var rare_chance := RARE_CHANCE
const GLOVE_SHARE := 0.6

const CRUST := Color("b0662a")
const CRUMB := Color("e8b45a")
const CRUST_DARK := Color("6e3a1a")
const CRUMB_LIGHT := Color("fff0c2")
const MANA := Color("5ec8ff")
const MANA_CORE := Color("e6f8ff")
const MANA_DARK := Color("2a5e9e")
const VIAL := Color("7a3fa8")
const VIAL_DARK := Color("3a1a5a")
const VIAL_LIGHT := Color("b98ae0")
const BONE := Color("e8e2d0")
const CORK := Color("8a5a2e")
const LEATHER := Color("8a2a22")
const LEATHER_DARK := Color("4a1414")
const LEATHER_LIGHT := Color("d0503a")
const STUD := Color("f0c02e")
const JAR := Color("e8e2d0")
const JAR_DARK := Color("8a8478")
const SALVE := Color("7ee0d6")

var kind := "bread"

var _age := 0.0
## Checked for spikes since it last came to rest (pass 311): the check scans the
## room's children, so it runs once as the drop settles, not every frame after.
var _settled := false
## How many spike checks have run (for tests: one a settle, not one a frame).
static var spike_checks := 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Player.LAYER_WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6, 4)
	shape.shape = rect
	shape.position = Vector2(0, -2)
	add_child(shape)
	z_index = 2
	if velocity == Vector2.ZERO:
		velocity = Vector2(randf_range(-40, 40), -200)


## Rolls for an enemy's drop at `at`. Returns the drop made, or null.
static func roll(parent: Node, at: Vector2, can_poison := false) -> Drop:
	var r := randf()
	var k := ""
	if r < bread_chance:
		k = "bread"
	elif r < bread_chance + mana_chance:
		k = "mana"
	elif can_poison and r < bread_chance + mana_chance + poison_chance:
		k = "poison"
	elif r < bread_chance + mana_chance + (poison_chance if can_poison else 0.0) + rare_chance:
		k = "glove" if randf() < GLOVE_SHARE else "ointment"
	if k == "":
		return null
	return make(parent, at, k)


## Makes a drop of `kind` at `at`.
static func make(parent: Node, at: Vector2, kind_: String) -> Drop:
	var d := Drop.new()
	d.kind = kind_
	parent.add_child(d)
	d.global_position = at
	return d


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, 400.0)
	move_and_slide()
	_keep_in_room()
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if velocity.x == 0.0 and not _settled:
			_settled = true
			_step_off_spikes()
	else:
		_settled = false
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and not p.dead and _age > 0.3 and p.body_rect().grow(COLLECT_RANGE * 0.5).has_point(global_position + Vector2(0, -3)):
		_collect(p)
		return
	queue_redraw()



## A drop never rests on spikes (pass 308): one that falls into a spiked pit,
## a Mothling struck down over a torn leaf or a foe slain over a crystal trench,
## would cost a blow to take. It moves to the nearest floor beside the pit, up
## to SPIKE_STEP_RISE tiles above it, as a purse on torn floor does (pass 300).
func _step_off_spikes() -> void:
	spike_checks += 1
	var room := get_parent() as Room
	if room == null or not _spiked(room, global_position):
		return
	var c := int(global_position.x / Room.TILE)
	var row := int(roundf(global_position.y / Room.TILE))
	for dist in range(1, room.size_tiles.x):
		for col: int in [c - dist, c + dist]:
			if col < 0 or col >= room.size_tiles.x:
				continue
			var top := row
			while top > row - SPIKE_STEP_RISE and room.is_solid_at(Vector2(col + 0.5, top - 0.5) * Room.TILE):
				top -= 1
			var spot := Vector2((col + 0.5) * Room.TILE, top * Room.TILE)
			if room.is_solid_at(spot + Vector2(0, 8)) and not room.is_solid_at(spot - Vector2(0, 8)) and not _spiked(room, spot):
				global_position = spot
				velocity = Vector2.ZERO
				return


static func _spiked(room: Room, at: Vector2) -> bool:
	for c in room.get_children():
		if c is Spikes and absf(c.global_position.x - at.x) <= Room.TILE * 0.5 and absf(c.global_position.y - at.y) < 6.0:
			return true
	return false

## A drop never leaves its room (pass 283): one that pops past a side edge
## stops at it, and one that falls out through a gap in the floor (the Tower's
## shafts drop through to the room below) comes to rest on the floor at the
## gap's nearer edge, where you can walk to it. Coins keep to it too (pass 285).
func _keep_in_room() -> void:
	Drop.keep_in_room(self)


## Holds `body` (a drop or a coin) inside its room, as above. Frees it if the
## room's bottom row has no floor to rest it on.
static func keep_in_room(body: CharacterBody2D) -> void:
	var room := body.get_parent() as Room
	if room == null:
		return
	var at := body.global_position
	var size := Vector2(room.size_tiles) * Room.TILE
	# Nor does it rest at a side door (pass 307): a door is three tiles tall, and
	# a jump over a flask lying just inside it meets the wall above the
	# door and drops you on it, so poison there was a toll on the way out. Where
	# the two tiles inside the edge are open, it stops on the second of them.
	# Only near an edge, so a spray of coins in mid-room asks no tiles (pass 311).
	if at.x < DOOR_CLEAR or at.x > size.x - DOOR_CLEAR:
		var lo := DOOR_CLEAR if _open_inside(room, 0.0, at.y) else 8.0
		var hi := size.x - (DOOR_CLEAR if _open_inside(room, size.x, at.y) else 8.0)
		if at.x < lo or at.x > hi:
			body.global_position.x = clampf(at.x, lo, hi)
			body.velocity.x = 0.0
	if at.y <= size.y:
		return
	var last := room.size_tiles.y - 1
	var c := int(at.x / Room.TILE)
	for dist in range(1, room.size_tiles.x):
		for col in [c - dist, c + dist]:
			if col < 0 or col >= room.size_tiles.x or not room.is_solid_at(Vector2(col + 0.5, last + 0.5) * Room.TILE):
				continue
			var top := last
			while top > 0 and room.is_solid_at(Vector2(col + 0.5, top - 0.5) * Room.TILE):
				top -= 1
			body.global_position = Vector2((col + 0.5) * Room.TILE, top * Room.TILE)
			body.velocity = Vector2.ZERO
			return
	body.queue_free()



## Whether the two tiles in from the side edge at `edge_x` are open at height `y`.
static func _open_inside(room: Room, edge_x: float, y: float) -> bool:
	var step := Room.TILE if edge_x == 0.0 else -Room.TILE
	for i in [1, 2]:
		if room.is_solid_at(Vector2(edge_x + step * (i + 0.5), y - 4.0)):
			return false
	return true

func _collect(p: Player) -> void:
	var d := Dust.new()
	if kind == "bread" or kind == "loaf":
		var heal := LOAF_HEAL if kind == "loaf" else BREAD_HEAL
		p.hp = mini(p.max_hp, p.hp + heal)
		p.cure_poison()
		p.health_changed.emit(p.hp, p.max_hp)
		d.setup("heal")
		GameState.toast.emit(("A great loaf. +%d health." if kind == "loaf" else "Bread. +%d health.") % heal)
		Sfx.play("heal", 0.1, -6.0 if kind == "bread" else -3.0)
	elif kind == "poison":
		d.setup("debris")
		if p.poison():
			GameState.toast.emit("Blightcap! It will pass, or bread will settle it.")
			Sfx.play("hurt", 0.1, -6.0)
		else:
			GameState.toast.emit("The Barkbalm keeps the poison off.")
			# Every drop is heard as it is taken (pass 302): the ring of a ward
			# turning harm, the sound the shield's ward makes against sorcery.
			Sfx.play("ward", 0.05, -6.0)
	elif kind == "glove":
		d.setup("might")
		p.put_on_glove()
	elif kind == "ointment":
		d.setup("coin")
		Sfx.play("item", 0.0, -4.0)
		if p.ointments < Shop.OINTMENT_MAX:
			p.ointments += 1
			GameState.toast.emit("A Barkbalm! It is on your belt.")
		elif p.ointment_left <= 0.0:
			# The pouch is full: it goes straight on, as the original's did.
			p.ointments += 1
			p.use_ointment()
		else:
			GameState.toast.emit("A Barkbalm, but your pouch is full.")
	else:
		p.mp = minf(p.max_mp, p.mp + MANA_GAIN)
		d.setup("coin")
		# Every drop says what it gave (pass 301), as bread does.
		GameState.toast.emit("A mana orb. +%d magic." % roundi(MANA_GAIN))
		Sfx.play("mana_orb", 0.04, -2.0)
	get_parent().add_child(d)
	d.global_position = global_position + Vector2(0, -4)
	queue_free()


func _draw() -> void:
	if _age > LIFETIME - 2.5 and int(_age * 10.0) % 2 == 0:
		return
	# Drawn at 2x render density (design bible 12.1): `_px` takes half-pixels.
	if kind == "bread":
		# A round loaf with two scores across the crust.
		_px(-7, -9, 14, 9, CRUST_DARK)
		_px(-8, -7, 16, 6, CRUST_DARK)
		_px(-6, -10, 12, 9, CRUST)
		_px(-7, -8, 14, 6, CRUST)
		_px(-5, -9, 4, 1, CRUMB)
		_px(-3, -7, 2, 2, CRUMB)
		_px(1, -8, 2, 2, CRUMB)
		_px(3, -6, 2, 2, CRUMB)
		_px(-4, -10, 3, 1, CRUMB_LIGHT)
		_px(-8, -1, 16, 1, CRUST_DARK)
	elif kind == "loaf":
		# A long braided loaf, twice the bread's length, three scores across it.
		_px(-14, -11, 28, 11, CRUST_DARK)
		_px(-16, -8, 32, 7, CRUST_DARK)
		_px(-13, -12, 26, 11, CRUST)
		_px(-15, -9, 30, 7, CRUST)
		for x in [-9, -2, 5]:
			_px(x, -10, 3, 2, CRUMB)
			_px(x + 1, -8, 3, 2, CRUMB)
		_px(-11, -12, 6, 1, CRUMB_LIGHT)
		_px(-3, -12, 4, 1, CRUMB_LIGHT)
		_px(-16, -1, 32, 1, CRUST_DARK)
	elif kind == "poison":
		# A squat violet flask with a cork and a bone-white skull.
		_px(-6, -12, 12, 12, VIAL_DARK)
		_px(-7, -10, 14, 8, VIAL_DARK)
		_px(-3, -16, 6, 5, VIAL_DARK)
		_px(-2, -15, 4, 3, CORK)
		_px(-5, -11, 10, 10, VIAL)
		_px(-6, -9, 12, 6, VIAL)
		_px(-4, -10, 2, 3, VIAL_LIGHT)
		_px(-2, -9, 5, 4, BONE)
		_px(-1, -8, 1, 1, VIAL_DARK)
		_px(1, -8, 1, 1, VIAL_DARK)
		_px(-1, -5, 3, 1, BONE)
		# A bubble rising off the neck.
		var b := fmod(_age * 1.4, 1.0)
		if b < 0.7:
			_px(1, -17 - roundi(b * 8.0), 2, 2, VIAL_LIGHT)
	elif kind == "glove":
		# A red leather fighting glove, fingers up, with a gold-studded cuff.
		var y := -2 + roundi(sin(_age * 4.0) * 1.0)
		_px(-6, y - 16, 12, 16, LEATHER_DARK)
		_px(-5, y - 15, 10, 14, LEATHER)
		_px(-5, y - 15, 2, 6, LEATHER_LIGHT)
		_px(-1, y - 15, 1, 6, LEATHER_DARK)
		_px(2, y - 15, 1, 6, LEATHER_DARK)
		_px(-8, y - 10, 3, 5, LEATHER_DARK)
		_px(-7, y - 9, 2, 3, LEATHER)
		_px(-6, y - 4, 12, 4, LEATHER_DARK)
		_px(-5, y - 3, 10, 2, STUD)
		_px(-3, y - 3, 1, 1, LEATHER_DARK)
		_px(1, y - 3, 1, 1, LEATHER_DARK)
		# A red glint that pulses.
		if fmod(_age, 1.2) < 0.25:
			_px(3, y - 14, 2, 2, Color("fff0c2"))
	elif kind == "ointment":
		# A squat white jar with a teal salve showing under the lid.
		_px(-6, -12, 12, 12, JAR_DARK)
		_px(-5, -11, 10, 10, JAR)
		_px(-6, -14, 12, 3, Color("8d4e16"))
		_px(-4, -10, 8, 2, SALVE)
		_px(-4, -8, 2, 5, Color("f7f1de"))
	else:
		var y := -13 + roundi(sin(_age * 5.0) * 2.0)
		_px(-5, y, 10, 12, MANA_DARK)
		_px(-6, y + 2, 12, 8, MANA_DARK)
		_px(-4, y + 1, 8, 10, MANA)
		_px(-5, y + 3, 10, 6, MANA)
		_px(-2, y + 3, 3, 3, MANA_CORE)
		_px(-3, y + 2, 2, 1, MANA_CORE)


func _px(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(x * 0.5, y * 0.5, w * 0.5, h * 0.5), color)

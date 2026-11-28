class_name DrownedWarden
extends Enemy
## The Drowned Warden (design bible 8.10): the guardian the first dwarves built
## to keep the source of every spring, a colossus of pale limestone and green
## bronze standing waist-deep in the Wellspring, a trident in its fist and the
## spring's light for eyes. The hardest fight in the game, and the only one in
## water: it wades the pool between the islands and you fight it from the
## islands, the planks and the water itself.
##
## Its attacks, each with a tell of at least Enemy.MIN_TELEGRAPH:
## - Thrust (near): it draws the trident back, aimed at you, the tines
##   glowing (tell), then drives it out along that line. Parry it and it
##   reels, open to every blow.
## - Wave (far, and every few attacks): it raises both arms and the water
##   churns (tell), then a wave runs across the surface toward you. Jump it, or
##   dive under it. In the third phase a second wave follows from the far side.
## - Geyser (phase 2+): it sinks out of sight and stalks you under the water,
##   a trail of bubbles the only sign. The water boils under you (tell), then
##   it bursts up through the spot in a column of water, and hangs there,
##   streaming, open to every blow.
## - Undertow (phase 3): its chest opens on the spring's light (tell) and the
##   current drags you toward it; then it raises the trident (tell) and slams
##   down around itself. The slam can be parried.
## Its stone turns half of every blow from the front; from above, from behind,
## reeling or hanging after a geyser, it takes them all. At two-thirds and
## one-third of its life it roars and the next phase begins.

signal defeated

const DISPLAY_NAME := "The Drowned Warden"
const EPITHET := "Keeper of the Source"
const MAX_HP := 680
const PHASES := [0.66, 0.33]
const WADE_SPEED := 46.0
const WADE_TIME := [1.1, 0.9, 0.7]
const THRUST_RANGE := 190.0
const THRUST_TELL := 0.6
const THRUST_TIME := 0.22
const THRUST_REACH := 150.0
const THRUST_DAMAGE := 18
const WAVE_TELL := 0.7
const DIVE_TIME := 0.5
const STALK_SPEED := 220.0
const STALK_TIME := 1.1
const GEYSER_TELL := 0.6
const GEYSER_TIME := 0.3
const GEYSER_WIDTH := 44.0
const GEYSER_DAMAGE := 20
const EXPOSED := 1.3
const UNDERTOW_TELL := 0.6
const UNDERTOW_TIME := 1.4
const UNDERTOW_PULL := 85.0
const SLAM_TELL := 0.45
const SLAM_DAMAGE := 22
## From 70 px over the surface to 60 under it: a 54 px hero dragged off a ledge sinks
## that far before he floats up, and the slam still reaches him (2026-11-28; it was 30).
const SLAM_SIZE := Vector2(120, 130)
const RECOVER := 0.7
const STAGGER := 1.4
const ROAR := 1.0
const ARMOR := 0.5
const INTRO_TIME := 1.8
const DYING_TIME := 2.0
## How far its feet stand below the surface while it wades, and while it lurks.
const WADE_DEPTH := 26.0
const LURK_DEPTH := 120.0
const SPEEDS := [1.0, 0.88, 0.75]
## The drawing is laid out at this fraction of its size.
const SCALE := 1.25

const OUTLINE := Color("0c1a22")
const STONE := Color("b8b4a8")
const STONE_LIGHT := Color("e2ddd0")
const STONE_DARK := Color("7a786e")
const BRONZE := Color("3e8a6e")
const BRONZE_LIGHT := Color("6ac0a0")
const BRONZE_DARK := Color("1e4a3a")
const LAMP := Color("8af0e8")
const LAMP_CORE := Color("f0fff8")
const WEED := Color("3a6a3a")

## The water's surface (y) and the run of it the Warden wades (x from, x to).
var surface_y := 320.0
var lane := Vector2(208, 752)
var phase := 1
var aim := Vector2.RIGHT
var _count := 0
var _struck := false
var _geyser_x := 0.0
var _waves := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	max_hp = MAX_HP
	contact_damage = 14
	gold_min = 200
	gold_max = 260
	xp = 600
	body_size = Vector2(52, 104)
	knockback = 0.0
	launchable = false
	uses_gravity = false
	state = "dormant"
	_rng.seed = 2611


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	# It wades straight through the islands; they hide its lower half.
	collision_mask = 0
	z_index = -1


## Starts the fight: it rises out of the deep water.
func begin() -> void:
	global_position.y = surface_y + LURK_DEPTH
	face_player()
	set_state("intro")
	Sfx.play("flood", 0.0, -2.0)
	Feel.add_trauma(0.4)
	GameState.banner.emit(DISPLAY_NAME, EPITHET)


func health_fraction() -> float:
	return clampf(float(hp) / max_hp, 0.0, 1.0)


func tell(base: float) -> float:
	return maxf(Enemy.MIN_TELEGRAPH, base * SPEEDS[phase - 1])


## Its opening (Enemy.punishable): staggered, or exposed after a slam.
func punishable() -> bool:
	return open()


func open() -> bool:
	return state in ["staggered", "exposed"]


func submerged() -> bool:
	return state in ["dive", "stalk", "geyser_tell"]


func _modify_damage(damage: int, dir: Vector2) -> int:
	if state in ["dormant", "intro", "roar", "dying"] or submerged():
		return 0
	if open() or dir.y > 0.0 or (dir.x != 0.0 and signf(dir.x) == float(facing)):
		return damage
	return maxi(1, roundi(damage * ARMOR))


func take_hit(damage: int, dir: Vector2) -> void:
	super.take_hit(damage, dir)
	_hitstun = 0.0
	velocity = Vector2.ZERO
	if dead:
		return
	if phase < 3 and health_fraction() <= PHASES[phase - 1]:
		phase += 1
		set_state("roar")
		Sfx.play("roar", 0.0, -2.0)
		Feel.add_trauma(0.5)


func _on_blocked(_dir: Vector2) -> void:
	pass


## A parried thrust or slam leaves it reeling.
func stagger() -> void:
	if dead or state in ["dormant", "intro", "roar", "dying"] or submerged():
		return
	set_state("staggered")
	_flash = 0.1


func _think(delta: float) -> void:
	velocity = Vector2.ZERO
	var wade_y := surface_y + WADE_DEPTH
	match state:
		"dormant":
			pass
		"intro":
			global_position.y = lerpf(surface_y + LURK_DEPTH, wade_y, minf(1.0, state_time / INTRO_TIME))
			if state_time >= INTRO_TIME:
				Sfx.play("roar", 0.0, -4.0)
				set_state("wade")
		"wade":
			global_position.y = move_toward(global_position.y, wade_y, 120.0 * delta)
			face_player()
			var dx := _player_dx()
			if absf(dx) > 40.0:
				velocity.x = signf(dx) * WADE_SPEED
			_keep_in_lane()
			if state_time >= WADE_TIME[phase - 1]:
				_choose(absf(dx))
		"thrust_tell":
			# It tracks you for most of the tell, then the aim sets.
			if state_time < tell(THRUST_TELL) * 0.7:
				face_player()
				aim = _aim_at_player()
			if state_time >= tell(THRUST_TELL):
				_struck = false
				set_state("thrust")
				Sfx.play("dash", 0.05, 0.0)
		"thrust":
			if not _struck and _thrust_hits():
				_struck = true
			if state_time >= THRUST_TIME:
				set_state("recover")
		"wave_tell":
			if state_time >= tell(WAVE_TELL):
				_raise_wave(float(signf(_player_dx())) if _player_dx() != 0.0 else float(facing), global_position.x)
				_waves = 1
				set_state("wave")
		"wave":
			# In the third phase a second wave comes from the far side of the pool.
			if phase == 3 and _waves == 1 and state_time >= 0.6:
				var p := player()
				var from := lane.y if p != null and p.global_position.x < (lane.x + lane.y) * 0.5 else lane.x
				_raise_wave(-1.0 if from == lane.y else 1.0, from)
				_waves = 2
			if state_time >= RECOVER + (0.6 if phase == 3 else 0.0):
				set_state("wade")
		"dive":
			global_position.y = lerpf(wade_y, surface_y + LURK_DEPTH, minf(1.0, state_time / DIVE_TIME))
			if state_time >= DIVE_TIME:
				collision_layer = 0
				set_state("stalk")
		"stalk":
			var dx := _player_dx()
			if absf(dx) > 6.0:
				velocity.x = signf(dx) * minf(STALK_SPEED, absf(dx) / delta)
			_keep_in_lane()
			if absf(dx) <= 6.0 or state_time >= STALK_TIME:
				_geyser_x = clampf(global_position.x, lane.x, lane.y)
				global_position.x = _geyser_x
				set_state("geyser_tell")
				Sfx.play("swell", 0.0, -2.0)
		"geyser_tell":
			if state_time >= tell(GEYSER_TELL):
				collision_layer = Player.LAYER_ENEMY
				_struck = false
				set_state("geyser")
				Sfx.play("flood", 0.0, 0.0)
				Feel.add_trauma(0.4)
		"geyser":
			global_position.y = lerpf(surface_y + LURK_DEPTH, surface_y - 10.0, minf(1.0, state_time / GEYSER_TIME))
			if not _struck and hit_player_in_rect(geyser_rect(), GEYSER_DAMAGE, false) != "":
				_struck = true
			if state_time >= GEYSER_TIME:
				set_state("exposed")
		"exposed":
			# Streaming water, held up on the spout's last push: open.
			if state_time >= EXPOSED:
				set_state("wade")
		"undertow_tell":
			if state_time >= tell(UNDERTOW_TELL):
				set_state("undertow")
				Sfx.play("swell", 0.0, 0.0)
		"undertow":
			var p := player()
			if p != null and not p.dead:
				var dx := global_position.x - p.global_position.x
				if absf(dx) > 24.0:
					p.pull = Vector2(signf(dx) * UNDERTOW_PULL, 0)
			if state_time >= UNDERTOW_TIME:
				face_player()
				set_state("slam_tell")
				Sfx.play("tell_heavy", 0.05, -2.0)
		"slam_tell":
			if state_time >= tell(SLAM_TELL):
				_struck = false
				set_state("slam")
				Sfx.play("heavy", 0.0, 2.0)
				Feel.add_trauma(0.45)
		"slam":
			if not _struck:
				_struck = true
				hit_player_in_rect(slam_rect(), SLAM_DAMAGE)
			if state_time >= 0.2:
				set_state("recover")
		"recover":
			if state_time >= RECOVER:
				set_state("wade")
		"staggered":
			global_position.y = move_toward(global_position.y, wade_y + 10.0, 60.0 * delta)
			if state_time >= STAGGER:
				set_state("wade")
		"roar":
			global_position.y = move_toward(global_position.y, wade_y, 120.0 * delta)
			collision_layer = Player.LAYER_ENEMY
			if state_time >= ROAR:
				set_state("wade")
		_:
			set_state("wade")


func _choose(dist: float) -> void:
	_count += 1
	var pick := "thrust" if dist <= THRUST_RANGE else "wave"
	if _count % 3 == 0:
		pick = "wave"
		if phase >= 2:
			pick = "dive"
	if phase == 3 and _count % 4 == 0:
		pick = "undertow"
	face_player()
	if pick == "dive":
		set_state("dive")
		Sfx.play("dive", 0.0, 0.0)
	else:
		set_state(pick + "_tell")
		# Heard as it starts (bible 13.3): the wave swells, the trident is drawn
		# back, the undertow gathers.
		if pick == "wave":
			Sfx.play("swell", 0.05, -4.0)
		else:
			Sfx.play("tell_blade" if pick == "thrust" else "tell_charge", 0.05, -2.0)


func _keep_in_lane() -> void:
	if global_position.x <= lane.x and velocity.x < 0.0 or global_position.x >= lane.y and velocity.x > 0.0:
		velocity.x = 0.0
	global_position.x = clampf(global_position.x, lane.x, lane.y)


## Where the trident's tines start: its fist at shoulder height.
func hand() -> Vector2:
	return global_position + Vector2(facing * 22.0, -62.0) * SCALE


func _aim_at_player() -> Vector2:
	var p := player()
	if p == null:
		return Vector2(facing, 0)
	var to := p.body_rect().get_center() - hand()
	# It can't stab back over its own shoulder.
	if signf(to.x) != float(facing):
		to.x = facing * absf(to.y) * 0.2 + facing
	return to.normalized()


## Checks the thrust along the trident's line, out to THRUST_REACH.
func _thrust_hits() -> bool:
	var reach := THRUST_REACH * minf(1.0, state_time / (THRUST_TIME * 0.5))
	var n := int(reach / 12.0)
	for i in n + 1:
		var at := hand() + aim * minf(i * 12.0, reach)
		if hit_player_in_rect(Rect2(at - Vector2(7, 7), Vector2(14, 14)), THRUST_DAMAGE) != "":
			return true
	return false


func geyser_rect() -> Rect2:
	return Rect2(_geyser_x - GEYSER_WIDTH * 0.5, surface_y - 96.0, GEYSER_WIDTH, LURK_DEPTH + 120.0)


func slam_rect() -> Rect2:
	return Rect2(global_position.x - SLAM_SIZE.x * 0.5, surface_y - 70.0, SLAM_SIZE.x, SLAM_SIZE.y)


func _raise_wave(dir: float, from_x: float) -> void:
	var w := TidalWave.new()
	w.dir = dir
	w.lane = lane + Vector2(-160.0, 160.0)
	get_parent().add_child(w)
	w.global_position = Vector2(from_x + dir * 30.0, surface_y)
	Sfx.play("flood", 0.1, -6.0)
	Feel.add_trauma(0.2)


func _player_dx() -> float:
	var p := player()
	return p.global_position.x - global_position.x if p != null else 0.0


func die() -> void:
	if state == "dying":
		return
	set_state("dying")
	dead = true
	collision_layer = 0
	velocity = Vector2.ZERO
	Feel.boss_kill(1.2)
	Feel.add_trauma(0.9)
	Sfx.play("roar", 0.0, 2.0)


func _process(delta: float) -> void:
	if state != "dying":
		return
	state_time += delta
	# It crumbles and sinks back into the spring it kept.
	global_position.y += 30.0 * delta
	if int(state_time * 10.0) % 3 == 0:
		var d := Dust.new()
		d.setup("debris")
		get_parent().add_child(d)
		d.global_position = global_position + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-80, -10))
	queue_redraw()
	if state_time >= DYING_TIME:
		state = "dead"
		defeated.emit()
		super.die()


# --- Drawing ------------------------------------------------------------------
# Code-drawn at 2x density: the origin is at its feet (under the water), x
# mirrored by facing. The water is drawn over its lower half by the room.

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	if submerged():
		wash(false)
		_draw_lurking(t)
		return
	var white := flashing() or (state.ends_with("_tell") and telegraph_pulse())
	var f := float(facing)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(f, 1) * SCALE)
	var bob := sin(t * 1.6) * 1.5
	var raise := 0.0
	if state in ["wave_tell", "slam_tell"]:
		raise = minf(1.0, state_time / 0.3)
	# The robe of weed and chain trailing in the water below the waist.
	for i in 5:
		var x := -18.0 + i * 9.0
		draw_line(Vector2(x, -30 + bob), Vector2(x + sin(t * 2.0 + i) * 4.0, 6), WEED, 3.0)
	# The torso: a great block of carved stone banded in bronze.
	_rect(-24, -78 + bob, 48, 50, OUTLINE)
	_rect(-22, -76 + bob, 44, 46, STONE)
	_rect(-22, -76 + bob, 44, 4, STONE_LIGHT)
	_rect(-22, -36 + bob, 44, 6, STONE_DARK)
	_rect(-23, -58 + bob, 46, 5, BRONZE_DARK)
	_rect(-23, -58 + bob, 46, 2, BRONZE_LIGHT)
	# The chest lamp: shuttered, or open on the spring's light.
	var chest := 0.25 + 0.1 * sin(t * 2.0)
	if state in ["undertow_tell", "undertow"]:
		chest = 0.6 + 0.4 * absf(sin(state_time * 10.0))
	elif open():
		chest = 0.9
	draw_circle(Vector2(0, -48 + bob), 7.0, OUTLINE)
	draw_circle(Vector2(0, -48 + bob), 5.5, Color(LAMP, chest))
	draw_circle(Vector2(0, -48 + bob), 2.5, Color(LAMP_CORE, chest))
	if chest > 0.5:
		draw_circle(Vector2(0, -48 + bob), 14.0, Color(LAMP, 0.15 * chest))
	# Shoulders: bronze pauldrons.
	for side in [-1.0, 1.0]:
		var sx: float = side * 26.0
		draw_circle(Vector2(sx, -72 + bob), 11.0, OUTLINE)
		draw_circle(Vector2(sx, -72 + bob), 9.5, BRONZE)
		draw_circle(Vector2(sx - 2.0, -75 + bob), 4.0, BRONZE_LIGHT)
	# The head: a dwarf-king's helm with a broad crest and lamp eyes.
	_rect(-12, -100 + bob, 24, 22, OUTLINE)
	_rect(-10, -98 + bob, 20, 19, STONE)
	_rect(-14, -104 + bob, 28, 7, BRONZE_DARK)
	_rect(-12, -106 + bob, 24, 4, BRONZE)
	_rect(-2, -114 + bob, 4, 9, BRONZE)
	var eyes := 0.6 + 0.2 * sin(t * 3.0)
	if white or state.ends_with("_tell"):
		eyes = 1.0
	_rect(-7, -92 + bob, 5, 3, Color(LAMP, eyes))
	_rect(3, -92 + bob, 5, 3, Color(LAMP, eyes))
	# A beard of green-stained stone.
	_rect(-9, -82 + bob, 18, 10, STONE_DARK)
	for i in 4:
		_rect(-8 + i * 5, -74 + bob, 3, 6, BRONZE_DARK)
	# The trident arm, and the trident along the aim (or held upright).
	var dir := Vector2(0, -1)
	var shaft := 96.0
	match state:
		"thrust_tell":
			dir = Vector2(aim.x * f, aim.y)
			shaft = 70.0
		"thrust":
			dir = Vector2(aim.x * f, aim.y)
			shaft = 70.0 + THRUST_REACH * minf(1.0, state_time / (THRUST_TIME * 0.5)) * 0.6
		"slam_tell":
			dir = Vector2(0.2, -1).normalized()
		"slam", "recover":
			dir = Vector2(1, 0.6).normalized() if state == "slam" or state_time < 0.2 else Vector2(0, -1)
	var fist := Vector2(22, -62 + bob - raise * 18.0)
	if state == "thrust_tell":
		fist -= dir * 14.0
	_rect(18, -70 + bob - raise * 10.0, 8, 14, STONE_DARK)
	var butt := fist - dir * 26.0
	var tip := fist + dir * shaft
	draw_line(butt, tip, OUTLINE, 5.0)
	draw_line(butt, tip, BRONZE, 3.0)
	var side_v := Vector2(-dir.y, dir.x)
	var glow := white or state in ["thrust_tell", "slam_tell"]
	for k in [-1.0, 0.0, 1.0]:
		var base: Vector2 = tip + side_v * k * 7.0
		draw_line(tip - dir * 4.0 + side_v * k * 7.0, base + dir * 12.0, OUTLINE, 4.0)
		draw_line(tip - dir * 4.0 + side_v * k * 7.0, base + dir * 12.0, LAMP if glow else BRONZE_LIGHT, 2.0)
	draw_line(tip - dir * 4.0 + side_v * -7.0, tip - dir * 4.0 + side_v * 7.0, BRONZE, 3.0)
	_rect(-26, -70 + bob - raise * 22.0, 8, 16, STONE_DARK)
	draw_circle(fist, 6.0, STONE)
	if state in ["exposed", "geyser"]:
		# Water streaming off it from the geyser.
		for i in 6:
			var x := -22.0 + i * 9.0
			var k := fmod(t * 2.0 + i * 0.3, 1.0)
			draw_rect(Rect2(x, -100 + k * 90.0, 2, 6), Color(LAMP_CORE, 0.6 * (1.0 - k)))
	wash(white)
	draw_set_transform(Vector2.ZERO)


## Under the water: a dark shape and a trail of bubbles; boiling at the spot it
## will burst up through.
func _draw_lurking(t: float) -> void:
	var top := surface_y - global_position.y
	if state == "geyser_tell":
		var k := state_time / maxf(0.01, tell(GEYSER_TELL))
		var on := int(state_time * (10.0 + 20.0 * k)) % 2 == 0
		for i in 9:
			var x := -GEYSER_WIDTH * 0.5 + i * GEYSER_WIDTH / 8.0
			var y := top - 2.0 - absf(sin(t * 18.0 + i)) * (3.0 + 8.0 * k)
			draw_rect(Rect2(x, y, 3, 3), Color(LAMP_CORE, 0.9 if on else 0.5))
		draw_rect(Rect2(-GEYSER_WIDTH * 0.5, top - 1.0, GEYSER_WIDTH, 3.0), Color(LAMP, 0.4 + 0.5 * k))
		for i in 6:
			var y := fmod(t * 90.0 + i * 20.0, -top + 10.0)
			draw_rect(Rect2(sin(t * 5.0 + i) * 10.0, -y, 3, 3), Color(LAMP_CORE, 0.7))
		return
	draw_circle(Vector2(0, -50), 30.0, Color(OUTLINE, 0.35))
	draw_circle(Vector2(0, -50), 4.0, Color(LAMP, 0.5))
	for i in 5:
		var y := fmod(t * 70.0 + i * 24.0, maxf(1.0, 60.0 - top))
		draw_rect(Rect2(sin(t * 4.0 + i) * 8.0 - 2.0, -60.0 - y, 2, 2), Color(LAMP_CORE, 0.6))


func _rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x, y, w, h), c)

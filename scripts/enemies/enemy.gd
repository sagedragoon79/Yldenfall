class_name Enemy
extends CharacterBody2D
## Base for all enemies: health, hit reactions, stagger, telegraphs, death,
## gold drops and optional respawning. Subclasses implement `_think()` and `_draw()`.
## The node origin is at the enemy's feet (or center, for fliers).

signal died(enemy: Enemy)

const GRAVITY := 1200.0
const MAX_FALL := 500.0
## How far below its room's floor line a falling foe goes before it is lost (px).
const FALL_MARGIN := 24.0
## Wind-ups shorter than this are unfair (design bible section 7).
const MIN_TELEGRAPH := 0.35
## How far above the hero's feet a head-height blow is aimed (bible 6.15): inside
## a standing body (40 px), over a crouched one (26 px), so a crouch ducks it.
const HEAD_HEIGHT := 36.0
## How long a body takes to break up after its death.
const DISSOLVE := 0.45
const DISSOLVE_SHADER := preload("res://shaders/dissolve.gdshader")
const WASH_SHADER := preload("res://shaders/wash.gdshader")

@export var max_hp := 24
@export var contact_damage := 20
@export var gold_min := 2
@export var gold_max := 5
## Experience for the kill (ranks, design bible 9).
@export var xp := 5
## Seconds until the enemy returns at its spawn point; 0 = gone for good.
@export var respawn_time := 0.0
## May this enemy leave poison (Drop.poison_chance)? The Tower and beyond.
@export var poison_drops := false
## A drop this foe always leaves instead of rolling for one (Drop kinds; the
## Silt Adder's great loaf, pass 281). Empty: it rolls, as every foe did.
@export var sure_drop := ""
## Grown through with stillglass (the Evercrown, design bible 8.9): tougher, richer,
## and it leaves a MeteorSeed that bursts where it dies. Set before it enters the tree.
@export var corrupted := false

## What corruption does to a foe's health, gold and experience.
const CORRUPT_HP := 1.5
const CORRUPT_GOLD := 2
const CORRUPT_XP := 2

var hp := 0
var dead := false
var facing := -1
var state := "idle"
var state_time := 0.0
## Seconds of game time this foe has lived: it slows with the Game speed option
## and stands still through hitstop (pass 474). Idle sways that move a hurtbox
## read it, never the wall clock.
var game_time := 0.0
var home := Vector2.ZERO
var body_size := Vector2(18, 18)
var body_centered := false
var uses_gravity := true
## Rising Cut launches: how hard, how long it hangs helpless, how big a foe it lifts.
## How long a hit stops a foe's thinking; the heavy finisher's lasts 1.8x (0.32 s).
const HITSTUN := 0.18
## A slow (Lithic Fracture, design bible 4, pass 497): while it holds, a foe's own
## clock, its thinking and its movement all run at SLOW_FACTOR of real time for
## SLOW_TIME seconds. It only ever lengthens a telegraph, never shortens one, so no
## tell can drop below MIN_TELEGRAPH. Bosses take it too.
const SLOW_FACTOR := 0.5
const SLOW_TIME := 3.0
const LAUNCH_SPEED := 330.0
const LAUNCH_STUN := 0.5
const LAUNCH_MAX_HP := 40
## False for foes rooted in place (Sap Spitter): Rising Cut can't lift them.
var launchable := true
var knockback := 140.0
var hits_taken := 0
## True once it has gone down with its master (`perish`), not to a blow.
var perished := false
## True once it has fallen out of its room (`_fall_out_of_room`, pass 298).
var fell := false
## True while a thrown blade's hit lands (`take_throw`, pass 188): a sting, not
## a blow, so it chips no bark, breaks no hex and never reaches the Heart.
var thrown := false

var _flash := 0.0
var _hitstun := 0.0
var _stagger := 0.0
var _slow := 0.0
var _respawn_timer := 0.0
var _dissolver: Tween
static var _wash_material: ShaderMaterial
## Whether this foe last drew itself white without the wash: `draw_sheet` in
## white, or a foe's own white overlay (`drawn_white`).
var _sheet_white := false


func _ready() -> void:
	collision_layer = Player.LAYER_ENEMY
	collision_mask = Player.LAYER_WORLD
	# A 45-degree slope is floor, as it is for the player (design bible 6.1).
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 4.0
	add_to_group("enemy")
	add_to_group("pogo")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	shape.shape = rect
	shape.position = Vector2.ZERO if body_centered else Vector2(0, -body_size.y * 0.5)
	add_child(shape)
	if corrupted and not is_in_group("boss"):
		_corrupt()
	hp = max_hp
	home = global_position


func _corrupt() -> void:
	max_hp = ceili(max_hp * CORRUPT_HP)
	gold_min *= CORRUPT_GOLD
	gold_max *= CORRUPT_GOLD
	xp *= CORRUPT_XP
	poison_drops = true
	# A violet cast over the body, with the crystal and its eye drawn on top.
	self_modulate = Color(0.86, 0.74, 1.0)
	add_child(CorruptionGrowth.new())


func player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func set_state(s: String) -> void:
	state = s
	state_time = 0.0


func center() -> Vector2:
	return global_position if body_centered else global_position + Vector2(0, -body_size.y * 0.5)


func _physics_process(delta: float) -> void:
	if dead:
		if respawn_time > 0.0:
			_respawn_timer -= delta
			if _respawn_timer <= 0.0:
				_respawn()
		return
	# A slow runs the foe's clock, its thinking and its movement at half time, but
	# counts down in real time, so it lasts its SLOW_TIME seconds (pass 497).
	var step := delta
	if _slow > 0.0:
		_slow -= delta
		step = delta * SLOW_FACTOR
	game_time += step
	state_time += step
	_flash -= delta
	if _stagger > 0.0:
		_stagger -= delta
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		if not uses_gravity:
			velocity.y = move_toward(velocity.y, 0.0, 600.0 * delta)
		if _stagger <= 0.0:
			set_state("idle")
	elif _hitstun > 0.0:
		_hitstun -= delta
		velocity = velocity.move_toward(Vector2(0, velocity.y if uses_gravity else 0.0), 700.0 * delta)
	else:
		_think(step)
		if _slow > 0.0:
			# Half speed afoot, and in the air for a flier; gravity is left real.
			velocity.x *= SLOW_FACTOR
			if not uses_gravity:
				velocity.y *= SLOW_FACTOR
	if uses_gravity:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	_fall_out_of_room()
	queue_redraw()


## A foe knocked through a gap in its room's floor (a Tower shaft, the Heartwood's
## drops) falls to its death (pass 291). It used to fall on below the room for
## good, its gold, drop and experience lost with it. Now it dies as it leaves,
## and its coins and drop come to rest at the gap's edge (Drop.keep_in_room).
func _fall_out_of_room() -> void:
	var room := get_parent() as Room
	if room == null or not uses_gravity or is_in_group("boss"):
		return
	if global_position.y > room.size_tiles.y * Room.TILE + FALL_MARGIN:
		fell = true
		die()


## Override: AI for one frame.
func _think(_delta: float) -> void:
	pass


## Override: return the damage actually taken (e.g. 0 when a shield blocks it).
func _modify_damage(damage: int, _dir: Vector2) -> int:
	return damage


## A hit from a thrown blade (the Rune Dagger). `_modify_damage` reads `thrown`.
func take_throw(damage: int, dir: Vector2) -> void:
	thrown = true
	take_hit(damage, dir)
	thrown = false


func take_hit(damage: int, dir: Vector2) -> void:
	if dead:
		return
	hits_taken += 1
	var dealt := _modify_damage(damage, dir)
	if dealt <= 0:
		_on_blocked(dir)
		return
	hp -= dealt
	_flash = 0.08
	# A heavy blow comes in at 1.8x (the finisher, a thrust): its number is gold.
	DamageNumber.spawn(get_parent(), center() + Vector2(0, -14), dealt, "heavy" if dir.length() > 1.5 else "hit")
	var d := Dust.new()
	d.setup("hit")
	get_parent().add_child(d)
	d.global_position = center()
	if hp <= 0:
		die()
		return
	velocity = dir * knockback
	if dir.y < 0.0 and uses_gravity:
		velocity.y = -knockback
	# A heavy blow comes in longer (dir 1.8x, the combo finisher): it reels longer.
	_hitstun = HITSTUN * maxf(dir.length(), 1.0)


func _on_blocked(dir: Vector2) -> void:
	var d := Dust.new()
	d.setup("guard")
	get_parent().add_child(d)
	d.global_position = center() - Vector2(dir.x * 10.0, 0)
	Sfx.play("guard")
	turn_blade()


## A blade turned at arm's length pushes the hero back; a bolt, a burst or a
## thrown blade turned from across the room does not (pass 442). Every guard
## that turns a blow calls this, a guardian's own too (pass 444).
func turn_blade() -> void:
	var p := player()
	if p:
		p.blade_turned()


## Rising Cut (skill tree): an up-slash throws a small foe into the air, helpless
## until it lands. Bosses, fliers and anything heavier than LAUNCH_MAX_HP stay put.
## Returns whether it went up.
func launch() -> bool:
	if dead or not launchable or not uses_gravity or max_hp > LAUNCH_MAX_HP or is_in_group("boss"):
		return false
	velocity = Vector2(0, -LAUNCH_SPEED)
	_hitstun = LAUNCH_STUN
	return true


## Called by the player on a successful parry.
func stagger() -> void:
	if dead:
		return
	_stagger = 1.0
	_flash = 0.1
	set_state("stagger")
	velocity.x = -facing * 80.0


func is_staggered() -> bool:
	return _stagger > 0.0


## Lithic Fracture's wave slows a foe (design bible 4, pass 497): for `duration`
## seconds its clock, thinking and movement run at SLOW_FACTOR. A fresh cast
## refreshes the time rather than stacking the factor.
func slow(duration := SLOW_TIME) -> void:
	if dead:
		return
	_slow = maxf(_slow, duration)


func is_slowed() -> bool:
	return _slow > 0.0


## The foe's opening: while it is true, its guard is down and blows land in full
## (design bible 8: every boss has a stagger window). Bloodletting and
## Executioner read it. A parry stagger by default; each boss names its own window.
func punishable() -> bool:
	return is_staggered()


## Goes down with its master (design bible 5.5, pass 266): a guardian's brood
## dies with the guardian. It dissolves like any foe, but no blow felled it, so
## it pays no gold, drop or experience, counts as no kill (Wanderer's Grace),
## and adds no kill hitstop or shake to the guardian's own death.
func perish() -> void:
	if dead:
		return
	perished = true
	hp = 0
	die()


func die() -> void:
	dead = true
	collision_layer = 0
	velocity = Vector2.ZERO
	if is_in_group("boss"):
		# A boss has played its own death by the time it gets here: it goes at once.
		visible = false
	else:
		_dissolve()
	var d := Dust.new()
	d.setup("debris")
	get_parent().add_child(d)
	d.global_position = center()
	# Risk pays (design bible 10.1, pass 197): a deep zone's foes hit harder
	# (Room.threat, 5.5) and drop that much more gold.
	# A boss rush wins nothing again (bible 11, pass 260): no gold, drops or
	# experience from a guardian or anything it calls in.
	if not BossRush.active() and not perished:
		var room := get_parent() as Room
		Coin.spray(get_parent(), center(), roundi(randi_range(gold_min, gold_max) * (room.threat() if room != null else 1.0)))
		if sure_drop != "":
			Drop.make(get_parent(), center(), sure_drop)
		else:
			Drop.roll(get_parent(), center(), poison_drops)
		GameState.add_xp(xp)
	var p := get_tree().get_first_node_in_group("player") as Player
	if not perished:
		if p != null:
			p.on_kill()
		# A fall is a kill but no blow (pass 298): it dies below the screen a
		# moment after the blow that sent it, so a kill's freeze and shake then
		# would hitch the game for nothing you can see.
		if not fell:
			Feel.hitstop(p.combat.kill_hitstop if p != null else CombatTuning.new().kill_hitstop)
			Feel.add_trauma(0.25)
	Sfx.play("enemy_die")
	if corrupted:
		var seed := MeteorSeed.new()
		seed.position = get_parent().to_local(center())
		get_parent().add_child.call_deferred(seed)
	died.emit(self)
	if respawn_time > 0.0:
		_respawn_timer = respawn_time
	elif not visible:
		queue_free()


## The death (bible 7): the body flashes white and breaks up into glowing motes
## over DISSOLVE seconds, then is gone (freed, unless it respawns).
func _dissolve() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = DISSOLVE_SHADER
	material = mat
	if _dissolver != null:
		_dissolver.kill()
	_dissolver = create_tween()
	_dissolver.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.0, 1.0, DISSOLVE)
	_dissolver.tween_callback(_dissolved)


func _dissolved() -> void:
	_dissolver = null
	if not dead:
		return
	visible = false
	material = null
	if respawn_time <= 0.0:
		queue_free()


## True while the body breaks up after its death.
func dissolving() -> bool:
	return dead and visible


func _respawn() -> void:
	if _dissolver != null:
		_dissolver.kill()
		_dissolver = null
	material = null
	dead = false
	perished = false
	fell = false
	hp = max_hp
	visible = true
	collision_layer = Player.LAYER_ENEMY
	global_position = home
	velocity = Vector2.ZERO
	_stagger = 0.0
	_hitstun = 0.0
	_slow = 0.0
	set_state("idle")
	reset_physics_interpolation()


## Damages the player if `rect` overlaps them. Returns the player's resolution.
func hit_player_in_rect(rect: Rect2, damage: int, parryable := true) -> String:
	var p := player()
	if p == null or p.dead or not rect.intersects(p.body_rect()):
		return ""
	return p.receive_attack(damage, self, parryable)


func face_player() -> void:
	var p := player()
	if p:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 2.0:
			facing = int(signf(dx))


func player_offset() -> Vector2:
	var p := player()
	if p == null or p.dead:
		return Vector2(INF, INF)
	return p.global_position + Vector2(0, -20) - center()


## From this foe's centre to the hero's head height (HEAD_HEIGHT above the
## feet, standing or crouched): where a blow meant to be ducked is aimed.
func player_head_offset() -> Vector2:
	var p := player()
	if p == null or p.dead:
		return Vector2(INF, INF)
	return p.global_position + Vector2(0, -HEAD_HEIGHT) - center()


## True while the enemy should be drawn white (hit flash or telegraph pulse).
func flashing() -> bool:
	return _flash > 0.0


## Washes everything this foe draws white while `on` (call it from `_draw`): a
## code-drawn foe's flash follows its own silhouette, never a box around it.
## Leaves the death's dissolve alone.
func wash(on: bool) -> void:
	if _wash_material == null:
		_wash_material = ShaderMaterial.new()
		_wash_material.shader = WASH_SHADER
	if on and not dead:
		material = _wash_material
	elif material == _wash_material:
		material = null


## True while this foe's drawing is washed white.
func washed() -> bool:
	return _wash_material != null and material == _wash_material


## True when this foe's last drawing went white, washed (`wash`) or drawn
## from a sheet in white (`draw_sheet`): the hit flash and the tell's pulse.
func drawn_white() -> bool:
	return washed() or _sheet_white


func telegraph_pulse() -> bool:
	return int(state_time * 16.0) % 2 == 0


## Draws frame `anim` of `sheet` (assets/sprites, from tools/art/castgen.py) at
## time `t`, facing this enemy's way, washed white while flashing or telegraphing.
## Returns the frame drawn.
func draw_sheet(sheet: String, anim: String, t: float, white := false, offset := Vector2.ZERO) -> int:
	var f := Sheet.frame_at(sheet, anim, t)
	_sheet_white = white
	draw_set_transform(offset, 0.0, Vector2(facing, 1))
	Sheet.draw(self, sheet, anim, f)
	if white:
		Sheet.draw(self, sheet, anim, f, Color(1, 1, 1, 0.85), true)
	draw_set_transform(Vector2.ZERO)
	return f

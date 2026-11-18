class_name DrownedDwarf
extends Enemy
## A Drowned Dwarf of the Haar (design bible 7): one of the Lampwick miners the
## marsh took, risen with the anchor he was drowned on. He lies sunk in the mire
## with only his helm's crest and a trickle of bubbles showing; he can't be hit
## and does no harm there. Come within about five tiles and he hauls himself
## out (0.7 s, half again damage while half out of the mud), then shambles after
## you. Close in, he heaves the anchor overhead, water pouring off it, for 0.6 s
## (the telegraph), and brings it down in front of him for 18. The slam can be
## parried. It buries the anchor in the mud for 0.8 s, when every blow lands at
## half again. Lose him for 3 s and he sinks back into the mire to wait.
## Legend `p`.

const WALK_SPEED := 26.0
## Wakes when you come this near (about five tiles), level with him.
const WAKE_X := 80.0
const WAKE_Y := 48.0
const RISE := 0.7
const SINK := 0.7
## Heaves when you are this close in front.
const REACH := 40.0
const HEAVE := 0.6
const SLAM_ACTIVE := 0.15
const SLAM_DAMAGE := 18
const SLAM_SIZE := Vector2(38, 30)
const MIRED := 0.8
## Half again damage while rising and while the anchor is buried.
const SOFT := 1.5
## Out of sight (farther than LOSE_X, or off his level) this long, he sinks.
const LOSE_X := 160.0
const LOSE_TIME := 3.0
const CONTACT := 10

var _slammed := false
var _lost := 0.0
var _died_at := -1.0


func _init() -> void:
	# Undead: the Hollowmist Cloak hides you from it (design bible 5.6).
	undead = true
	max_hp = 46
	gold_min = 7
	gold_max = 11
	xp = 18
	contact_damage = 0
	body_size = Vector2(18, 30)
	knockback = 30.0
	state = "sunk"


func _ready() -> void:
	super()
	_submerge()


## Under the mire he is out of reach: nothing hits him and he hits nothing.
func _submerge() -> void:
	set_state("sunk")
	collision_layer = 0
	contact_damage = 0


func is_sunk() -> bool:
	return state == "sunk"


func is_soft() -> bool:
	return state in ["rise", "mired"]


func _modify_damage(damage: int, _dir: Vector2) -> int:
	return ceili(damage * SOFT) if is_soft() else damage


func _respawn() -> void:
	super()
	_submerge()


func _think(delta: float) -> void:
	var off := player_offset()
	var seen := off.x != INF and absf(off.x) < LOSE_X and absf(off.y) < WAKE_Y * 2.0
	match state:
		"sunk":
			velocity.x = 0.0
			if off.x != INF and absf(off.x) < WAKE_X and absf(off.y) < WAKE_Y:
				face_player()
				collision_layer = Player.LAYER_ENEMY
				set_state("rise")
				Sfx.play("splash", 0.1, -2.0)
		"rise":
			velocity.x = 0.0
			if state_time >= RISE:
				contact_damage = CONTACT
				_lost = 0.0
				set_state("walk")
		"idle", "walk":
			if state == "idle":
				set_state("walk")
			_lost = 0.0 if seen else _lost + delta
			if _lost >= LOSE_TIME:
				velocity.x = 0.0
				contact_damage = 0
				set_state("sink")
				Sfx.play("splash", 0.1, -6.0)
				return
			if off.x != INF and absf(off.y) < WAKE_Y:
				face_player()
				if absf(off.x) < REACH:
					velocity.x = 0.0
					set_state("windup")
					Sfx.play("anchor_heave", 0.08, -3.0)
					return
			if is_on_floor() and (_wall_ahead() or not _floor_ahead()):
				velocity.x = 0.0
			else:
				velocity.x = facing * WALK_SPEED
		"windup":
			velocity.x = 0.0
			if state_time >= HEAVE:
				_slammed = false
				set_state("slam")
				Sfx.play("anchor_slam", 0.05, -3.0)
		"slam":
			velocity.x = 0.0
			if not _slammed:
				if hit_player_in_rect(_slam_rect(), SLAM_DAMAGE, true) != "":
					_slammed = true
			if state_time >= SLAM_ACTIVE:
				# The anchor buries itself in the mud.
				var d := Dust.new()
				d.setup("land")
				get_parent().add_child(d)
				d.global_position = global_position + Vector2(facing * 24.0, 0)
				Feel.add_trauma(0.15)
				set_state("mired")
				Sfx.play("splat", 0.05)
		"mired":
			velocity.x = 0.0
			if state_time >= MIRED:
				set_state("walk")
		"sink":
			velocity.x = 0.0
			if state_time >= SINK:
				_submerge()
		_:
			set_state("walk")


func _slam_rect() -> Rect2:
	var x := facing * (body_size.x * 0.5 + SLAM_SIZE.x * 0.5) - SLAM_SIZE.x * 0.5
	return Rect2(global_position + Vector2(x, -SLAM_SIZE.y), SLAM_SIZE)


func _wall_ahead() -> bool:
	return test_move(global_transform, Vector2(facing * 4, 0))


func _floor_ahead() -> bool:
	var t := global_transform.translated(Vector2(facing * (body_size.x * 0.5 + 2), 0))
	return test_move(t, Vector2(0, 6))


func die() -> void:
	_died_at = Time.get_ticks_msec() * 0.001
	super.die()


func _process(_delta: float) -> void:
	# The dissolve runs after death, when the body no longer redraws itself: keep
	# the fall playing under it.
	if dead and dissolving():
		queue_redraw()


## The animation and its time for what he is doing now (docs/art/enemy-style-guide.md 4).
func anim_now() -> Array:
	if dead:
		return ["death", Time.get_ticks_msec() * 0.001 - _died_at]
	if is_staggered():
		return ["stagger", state_time]
	if state in ["sunk", "rise", "sink", "slam", "mired"]:
		return [state, state_time]
	if state == "windup":
		return ["heave", state_time]
	if _hitstun > 0.0:
		return ["hurt", HITSTUN - _hitstun]
	if absf(velocity.x) < 1.0:
		return ["idle", Time.get_ticks_msec() * 0.001]
	return ["walk", Time.get_ticks_msec() * 0.001]


func _draw() -> void:
	var white := flashing() or (state == "windup" and telegraph_pulse())
	var now := anim_now()
	draw_sheet("drowned_dwarf", now[0], now[1], white)
	if state == "sunk":
		# A trickle of bubbles off the crest gives him away, even in the fog.
		var clock := Time.get_ticks_msec() * 0.001
		for i in 3:
			var k := fmod(clock * 0.8 + i / 3.0, 1.0)
			var p := Vector2(-2.0 + sin(clock * 3.0 + i * 2.0) * 2.0 + i * 2.0, -5.0 - k * 18.0)
			draw_arc(p, 1.6 + i * 0.5, 0.0, TAU, 10, Color(0.82, 0.95, 0.95, 0.9 * (1.0 - k)), 1.0)

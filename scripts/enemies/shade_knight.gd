class_name ShadeKnight
extends Enemy
## A Shade Knight of Vorrhallow (design bible 7): the drowned ghost of one of King
## Vorrund's household guard, still in his armour, a tower shield on his left arm.
## A parry fight. His shield turns every blow from the front. He advances behind
## it, then draws his blade back (it glows: the telegraph) and thrusts, then
## cuts again. Parry either and he reels, shield wide, open to every blow.
## Let the pair finish and he stands winded a moment, shield low. Batter his
## shield instead and he answers with a quick riposte. Strike from behind or
## from above and his shield doesn't help him. Legend `e`.

const WALK_SPEED := 26.0
const SIGHT := Vector2(160, 56)
## He opens his combo when you are this near (px, centre to centre).
const REACH := 64.0
const THRUST_TELL := 0.55
const THRUST_TIME := 0.18
const THRUST_SPEED := 170.0
const CUT_TELL := 0.38
const CUT_TIME := 0.14
const RIPOSTE_TELL := 0.36
const WINDED := 0.7
const COOLDOWN := 0.6
const THRUST_DAMAGE := 18
const CUT_DAMAGE := 14
## Blows on his shield before he ripostes.
const RIPOSTE_AFTER := 2
## His blade's reach in front of the body.
const BLADE_REACH := 30.0

var _struck := false
var _cool := 0.0
var _battered := 0
## Which cut comes after the tell: "thrust" or "cut".
var _next := "thrust"
## His combo's second blow is a high cut at your head (bible 6.15): crouch under
## it or parry it. A riposte's cut stays at the chest.
var _high := false
## The high cut's blade, measured up from his feet (px): from HIGH_CUT_TOP down
## HIGH_CUT_HEIGHT, over a crouched hero (Player crouch 26 px) and through a standing one.
const HIGH_CUT_TOP := 46.0
const HIGH_CUT_HEIGHT := 18.0


func _init() -> void:
	max_hp = 56
	gold_min = 10
	gold_max = 16
	xp = 28
	contact_damage = 12
	body_size = Vector2(20, 30)
	knockback = 40.0
	launchable = false


## True while his shield is up and facing you.
func guarding() -> bool:
	return state in ["idle", "walk", "thrust_tell", "cut_tell", "riposte_tell"] and not is_staggered()


func _modify_damage(damage: int, dir: Vector2) -> int:
	# The tower shield turns anything from the front unless he is reeling or winded.
	if dir.y > 0.0 or not guarding():
		return damage
	if dir.x != 0.0 and signf(dir.x) == facing:
		return damage  # from behind
	if dir.x == 0.0:
		return damage
	_battered += 1
	if _battered >= RIPOSTE_AFTER and state in ["idle", "walk"]:
		_battered = 0
		_open("riposte_tell", "cut")
	return 0


func _think(delta: float) -> void:
	_cool -= delta
	var off := player_offset()
	var seen := off.x != INF and absf(off.x) < SIGHT.x and absf(off.y) < SIGHT.y
	match state:
		"idle", "walk":
			if state == "idle":
				set_state("walk")
			if seen:
				face_player()
				if absf(off.x) < REACH and _cool <= 0.0 and is_on_floor():
					_open("thrust_tell", "thrust")
					return
				velocity.x = 0.0 if _edge_ahead() or absf(off.x) < REACH * 0.6 else facing * WALK_SPEED
			else:
				velocity.x = 0.0
		"thrust_tell", "cut_tell", "riposte_tell":
			velocity.x = 0.0
			var tell: float = {"thrust_tell": THRUST_TELL, "cut_tell": CUT_TELL, "riposte_tell": RIPOSTE_TELL}[state]
			if state_time >= tell:
				_struck = false
				set_state(_next)
				Sfx.play("slash", 0.1, -2.0)
		"thrust":
			velocity.x = 0.0 if _edge_ahead() else facing * THRUST_SPEED
			_strike(THRUST_DAMAGE)
			if state == "thrust" and state_time >= THRUST_TIME:
				velocity.x = 0.0
				face_player()
				_open("cut_tell", "cut")
		"cut":
			velocity.x = 0.0
			_strike(CUT_DAMAGE)
			if state == "cut" and state_time >= CUT_TIME:
				set_state("winded")
		"winded":
			velocity.x = 0.0
			if state_time >= WINDED:
				_cool = COOLDOWN
				_battered = 0
				set_state("walk")
		_:
			set_state("walk")


func _open(tell: String, next: String) -> void:
	velocity.x = 0.0
	face_player()
	_next = next
	_high = tell == "cut_tell"
	set_state(tell)
	Sfx.play("swell", 0.15, -8.0)


func _strike(damage: int) -> void:
	if _struck:
		return
	var res := hit_player_in_rect(blade_rect(), damage)
	if res != "":
		_struck = true


## Where his blade cuts.
func blade_rect() -> Rect2:
	var c := center()
	var w := BLADE_REACH + body_size.x * 0.5
	var x := c.x if facing > 0 else c.x - w
	if _high and state in ["cut_tell", "cut"]:
		return Rect2(x, global_position.y - HIGH_CUT_TOP, w, HIGH_CUT_HEIGHT)
	return Rect2(x, c.y - 14.0, w, 24.0)


func _edge_ahead() -> bool:
	if not is_on_floor():
		return false
	if test_move(global_transform, Vector2(facing * 4, 0)):
		return true
	var t := global_transform.translated(Vector2(facing * (body_size.x * 0.5 + 2), 0))
	return not test_move(t, Vector2(0, 6))


## The sheet's animation for each state (docs/art/enemy-style-guide.md 4).
const ANIMS := {
	"idle": "idle", "walk": "walk", "thrust_tell": "thrust_tell", "riposte_tell": "thrust_tell",
	"cut_tell": "cut_tell", "thrust": "thrust", "cut": "cut", "winded": "winded",
}
## Where his blade's point is, in each tell (world px from his feet, facing right),
## for the cold light that gathers there.
const TIP := {"thrust_tell": Vector2(-10, -5), "cut_tell": Vector2(-23, -39)}
const GLOW := Color("7ff0e0")

var _died_at := -1.0


func die() -> void:
	_died_at = Time.get_ticks_msec() * 0.001
	super.die()


func _process(_delta: float) -> void:
	# The dissolve runs after death, when the body no longer redraws itself: keep
	# the collapse playing under it.
	if dead and dissolving():
		queue_redraw()


## The animation and its time for what he is doing now.
func anim_now() -> Array:
	if dead:
		return ["death", Time.get_ticks_msec() * 0.001 - _died_at]
	if is_staggered():
		return ["stagger", state_time]
	if _hitstun > 0.0:
		return ["hurt", HITSTUN - _hitstun]
	var a: String = ANIMS.get(state, "idle")
	if a == "walk" and absf(velocity.x) < 1.0:
		a = "idle"
	return [a, state_time if a != "idle" and a != "walk" else Time.get_ticks_msec() * 0.001]


func _draw() -> void:
	var telling := state.ends_with("_tell")
	var now := anim_now()
	var white := flashing() or (telling and telegraph_pulse())
	draw_sheet("shade_knight", now[0], now[1], white)
	if telling and TIP.has(ANIMS[state]):
		# The drawn blade gathers a cold light at its point: the tell.
		var tip: Vector2 = TIP[ANIMS[state]] * Vector2(facing, 1)
		var k := 0.5 + 0.5 * absf(sin(state_time * 14.0))
		draw_circle(tip, 5.0, Color(GLOW, 0.25 * k))
		draw_rect(Rect2(tip.x - 0.5, tip.y - 4, 1, 8), Color(GLOW, 0.8 * k))
		draw_rect(Rect2(tip.x - 4, tip.y - 0.5, 8, 1), Color(GLOW, 0.8 * k))

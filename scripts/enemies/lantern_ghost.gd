class_name LanternGhost
extends Enemy
## A Lantern Ghost of the Haar (design bible 7): the soul of a drowned dwarf,
## a hooded wisp that drifts through wood and stone. Out in the fog it is all but
## invisible; it shows only near light (Fog.clear_at): your own pocket of sight,
## a lantern, a shrine. It drifts toward you, and once close its eyes flare (a
## wind-up that always shows, even in the murk), then it lunges and fades back.
## Legend `A`.

const SIGHT := 170.0
const DRIFT_SPEED := 38.0
const REACH := 64.0
const WINDUP := 0.55
const LUNGE_SPEED := 230.0
const LUNGE_TIME := 0.42
const FADE_TIME := 0.9
const COOLDOWN := 0.6
## Faintest it gets in full fog, and how bright its wind-up always is.
const MIN_ALPHA := 0.07
const WINDUP_ALPHA := 0.75
const LUNGE_DAMAGE := 18
const TOUCH_DAMAGE := 10

const SHEET := "lantern_ghost"
## The sheet's animation for each state (docs/art/enemy-style-guide.md 4).
const ANIMS := {
	"idle": "idle", "drift": "idle", "return": "idle", "windup": "lunge_tell",
	"lunge": "lunge", "fade": "fade",
}
## Its eyes in the hood (world px from its middle, facing right), where the
## wind-up's flare is drawn, per animation.
const EYES := {"idle": Vector2(0, -8), "lunge_tell": Vector2(-3, -8)}
const EYE := Color("f4e48c")

var _dir := Vector2.ZERO
var _cooldown := 0.0
## How visible it is now, 0..1.
var seen := 1.0
var _died_at := -1.0


func _init() -> void:
	max_hp = 18
	gold_min = 3
	gold_max = 6
	xp = 7
	body_size = Vector2(14, 18)
	body_centered = true
	uses_gravity = false
	knockback = 120.0
	contact_damage = TOUCH_DAMAGE


func _ready() -> void:
	super()
	# A ghost: it drifts through the Tree's wood.
	collision_mask = 0


func _think(delta: float) -> void:
	_cooldown -= delta
	var off := player_offset()
	var close := off.x != INF and off.length() < SIGHT
	contact_damage = LUNGE_DAMAGE if state == "lunge" else TOUCH_DAMAGE
	match state:
		"idle":
			var t := Time.get_ticks_msec() * 0.001
			var bob := home + Vector2(sin(t * 0.7) * 14.0, sin(t * 1.4) * 5.0)
			velocity = (bob - global_position) * 2.0
			if close:
				set_state("drift")
		"drift":
			if not close:
				set_state("return")
			else:
				face_player()
				velocity = velocity.move_toward(off.normalized() * DRIFT_SPEED, 120.0 * delta)
				if _cooldown <= 0.0 and off.length() < REACH:
					velocity = Vector2.ZERO
					set_state("windup")
					Sfx.play("wail", 0.08, -4.0)
		"windup":
			velocity = Vector2.ZERO
			face_player()
			if state_time >= WINDUP:
				_dir = off.normalized() if off.x != INF else Vector2(facing, 0)
				set_state("lunge")
				Sfx.play("whoosh", 0.08, -4.0)
		"lunge":
			velocity = _dir * LUNGE_SPEED
			if state_time >= LUNGE_TIME:
				set_state("fade")
		"fade":
			velocity = velocity.move_toward(-_dir * 30.0, 300.0 * delta)
			if state_time >= FADE_TIME:
				_cooldown = COOLDOWN
				set_state("drift" if close else "return")
		"return":
			var d := home - global_position
			velocity = d.normalized() * DRIFT_SPEED * 1.5
			if d.length() < 6.0 or state_time > 4.0:
				set_state("idle")
			elif close:
				set_state("drift")
		_:
			set_state("drift")


func _process(_delta: float) -> void:
	var fog := Fog.current(get_tree())
	var clear := fog.clear_at(center()) if fog != null else 1.0
	seen = lerpf(MIN_ALPHA, 1.0, clear)
	if state == "windup":
		seen = maxf(seen, WINDUP_ALPHA)
	elif state == "fade":
		seen *= 1.0 - 0.6 * clampf(state_time / FADE_TIME, 0.0, 1.0)
	# The dissolve runs after death, when the body no longer redraws itself: keep
	# the collapse playing under it.
	if dead and dissolving():
		queue_redraw()


func die() -> void:
	_died_at = Time.get_ticks_msec() * 0.001
	super.die()


## The animation and its time for what it is doing now.
func anim_now() -> Array:
	if dead:
		return ["death", Time.get_ticks_msec() * 0.001 - _died_at]
	if _hitstun > 0.0:
		return ["hurt", HITSTUN - _hitstun]
	var a: String = ANIMS.get(state, "idle")
	return [a, state_time if a != "idle" else Time.get_ticks_msec() * 0.001]


func _draw() -> void:
	var white := flashing() or (state == "windup" and telegraph_pulse())
	var now := anim_now()
	var f := Sheet.frame_at(SHEET, now[0], now[1])
	# A ghost: drawn as faint as the fog lets it be seen.
	var a := seen if not dead else 1.0
	var over := flash_overlay(white, maxf(a, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	Sheet.draw(self, SHEET, now[0], f, Color(1, 1, 1, a))
	if white:
		Sheet.draw(self, SHEET, now[0], f, over, true)
	if state == "windup" and EYES.has(now[0]):
		# The eyes flare in the wind-up, bright even in the murk.
		var e: Vector2 = EYES[now[0]]
		var k := 0.6 + 0.4 * absf(sin(state_time * 12.0))
		draw_circle(e, 3.0, Color(EYE, 0.3 * k))
		draw_circle(e, 1.0, Color(1, 1, 0.85, k))
	draw_set_transform(Vector2.ZERO)

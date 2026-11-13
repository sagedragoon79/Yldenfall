class_name DamageNumber
extends Node2D
## A damage number (design bible 14, an option, off by default; pass 154): the
## damage a blow actually dealt pops up over what it struck, rises and fades.
## A foe's number is white, a heavy blow's (the finisher, a thrust, a Riposte)
## gold and twice the size, and the player's own losses are red (a poison
## tick's green, like the poisoned masks).

const LIFE := 0.7
const RISE := 18.0
const FADE := 0.25
const OUTLINE := Color(0.05, 0.04, 0.06)
const COLORS := {"hit": Color("ffffff"), "heavy": Color("ffd25a"), "hurt": Color("ff5a4a"), "poison": GameHud.POISONED}
const SIZES := {"hit": 10, "heavy": 20, "hurt": 10, "poison": 10}

var amount := 0
var kind := "hit"
## A colour of its own (a blow of fire, ice or lightning: DamageKind.COLORS).
var tint := Color(0, 0, 0, 0)
var _life := LIFE
var _drift := 0.0
## Numbers alternate a little left and right, so a flurry doesn't stack into one.
static var _side := 1.0


## Adds a number for `amount` to `parent` at global `at`, when the option is on.
## Returns it, or null when numbers are off (or there is nothing to show).
static func spawn(parent: Node, at: Vector2, amount_dealt: int, number_kind := "hit") -> DamageNumber:
	if not Settings.damage_numbers or amount_dealt <= 0 or parent == null:
		return null
	var n := DamageNumber.new()
	n.amount = amount_dealt
	n.kind = number_kind
	_side = -_side
	n._drift = _side * 5.0
	parent.add_child(n)
	n.global_position = at
	return n


func _ready() -> void:
	z_index = 20


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	queue_redraw()


## How far it has risen: quick at first, settling (ease out).
func offset() -> Vector2:
	var t := 1.0 - _life / LIFE
	var k := 1.0 - (1.0 - t) * (1.0 - t)
	return Vector2(_drift * k, -RISE * k)


func _draw() -> void:
	var text := str(amount)
	var size: int = SIZES.get(kind, 10)
	var alpha := clampf(_life / FADE, 0.0, 1.0)
	var c: Color = tint if tint.a > 0.0 else COLORS.get(kind, Color.WHITE)
	c.a = alpha
	var o := OUTLINE
	o.a = alpha
	var at := offset() + Vector2(-PixelFont.width(text, size) * 0.5, 0)
	PixelFont.draw(self, at, text, size, c, o)

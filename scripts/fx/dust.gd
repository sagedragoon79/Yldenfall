class_name Dust
extends Node2D
## One-shot pixel particle puff: run, land, jump, wall, feathers, pogo, debris.

const KINDS := {
	"run": {"count": 3, "speed": Vector2(40, 15), "life": 0.25, "color": Color("cdbfa6"), "size": 2, "rise": -20.0},
	"dash": {"count": 10, "speed": Vector2(260, 50), "life": 0.35, "color": Color("cdbfa6"), "size": 3, "rise": -30.0},
	"airdash": {"count": 6, "speed": Vector2(90, 30), "life": 0.22, "color": Color("f3f0e2"), "size": 2, "rise": 0.0},
	"jump": {"count": 5, "speed": Vector2(55, 10), "life": 0.25, "color": Color("cdbfa6"), "size": 2, "rise": -10.0},
	"land": {"count": 8, "speed": Vector2(90, 15), "life": 0.3, "color": Color("cdbfa6"), "size": 3, "rise": -15.0},
	"wall": {"count": 1, "speed": Vector2(15, 10), "life": 0.25, "color": Color("cdbfa6"), "size": 2, "rise": -25.0},
	"walljump": {"count": 6, "speed": Vector2(50, 50), "life": 0.3, "color": Color("cdbfa6"), "size": 2, "rise": 0.0},
	"glide": {"count": 2, "speed": Vector2(30, 20), "life": 0.6, "color": Color("f3f0e2"), "size": 2, "rise": -20.0},
	"feathers": {"count": 7, "speed": Vector2(60, 40), "life": 0.45, "color": Color("f3f0e2"), "size": 2, "rise": 40.0},
	"pogo": {"count": 8, "speed": Vector2(80, 50), "life": 0.25, "color": Color("ffe27a"), "size": 2, "rise": 0.0},
	"hit": {"count": 6, "speed": Vector2(120, 90), "life": 0.2, "color": Color("fff4d6"), "size": 2, "rise": 0.0},
	"splash": {"count": 9, "speed": Vector2(90, 90), "life": 0.35, "color": Color("7cc4f0"), "size": 2, "rise": 250.0},
	"parry": {"count": 12, "speed": Vector2(160, 160), "life": 0.3, "color": Color("fff1a8"), "size": 2, "rise": 0.0},
	"guard": {"count": 5, "speed": Vector2(90, 60), "life": 0.2, "color": Color("c9c4d6"), "size": 2, "rise": 0.0},
	"heal": {"count": 10, "speed": Vector2(30, 40), "life": 0.6, "color": Color("ff8a8a"), "size": 2, "rise": -60.0},
	"coin": {"count": 4, "speed": Vector2(40, 40), "life": 0.25, "color": Color("ffe27a"), "size": 1, "rise": 0.0},
	"debris": {"count": 10, "speed": Vector2(90, 120), "life": 0.6, "color": Color("8a7d6b"), "size": 3, "rise": 300.0},
	"sap": {"count": 9, "speed": Vector2(80, 70), "life": 0.4, "color": Color("ffb84a"), "size": 2, "rise": 260.0},
	"bark": {"count": 14, "speed": Vector2(150, 150), "life": 0.8, "color": Color("6e4a2c"), "size": 4, "rise": 320.0},
	"embers": {"count": 12, "speed": Vector2(110, 110), "life": 0.45, "color": Color("f8a040"), "size": 2, "rise": -60.0},
	"might": {"count": 2, "speed": Vector2(18, 14), "life": 0.4, "color": Color("ff5a3c"), "size": 2, "rise": -50.0},
}

## The puffs the feet kick off the ground: they take the ground's look
## (pass 264), as the steps take its sound.
const GROUND := ["run", "dash", "jump", "land"]
## Ground that kicks up something other than pale dust: marsh mud, amber sap,
## and spray from standing water (`Room.surface_at`).
const GROUND_TINT := {"mud": Color("5e4c36"), "sap": Color("ffb84a"), "wade": Color("7cc4f0")}

## Spray off standing water: drops WADE_DROP px across, strung WADE_SPREAD px
## either side of where they leave the surface (12.143).
const WADE_DROP := 1
const WADE_SPREAD := 4

## The kind this puff was set up as (tests).
var kind := ""
## The ground it was kicked off, if it took that ground's look (tests).
var surface := ""
var _particles: Array = []  # [pos, vel, life, max_life]
var _color := Color.WHITE
var _size := 2
var _rise := 0.0


func setup(kind_name: String, facing := 1, ground := "") -> void:
	kind = kind_name
	var k: Dictionary = KINDS.get(kind, KINDS["run"])
	_color = k["color"]
	_size = k["size"]
	_rise = k["rise"]
	var speed: Vector2 = k["speed"]
	if kind in GROUND and GROUND_TINT.has(ground):
		surface = ground
		_color = GROUND_TINT[ground]
		# Mud, sap and water are heavy: flung, they fall back rather than drift.
		_rise = 260.0
		if ground == "wade":
			# Spray leaps higher and wider than dust, out of the surface, in single
			# drops (pass 666, 12.143): a 2 px puff born on one point read as a
			# flat square on the wader's hip.
			speed = Vector2(speed.x * 0.8 + 20.0, 130.0)
			_size = WADE_DROP
	var count := int(k["count"]) + (3 if surface == "wade" else 0)
	for i in count:
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 0.2))
		if kind in ["run", "airdash"]:
			dir.x = -absf(dir.x) * facing
		if kind == "dash":
			# Kicked hard back off the heel, low along the floor.
			dir = Vector2(-randf_range(0.4, 1.0) * facing, randf_range(-1.0, 0.0))
		if kind in ["debris", "hit", "pogo", "walljump", "splash", "parry", "guard", "coin", "sap", "bark", "embers"]:
			dir = Vector2.from_angle(randf() * TAU)
		if surface == "wade":
			# Spray: thrown up out of the water, falling back into it.
			dir.y = -randf_range(0.6, 1.4)
			dir.x *= 0.7
		var life: float = k["life"] * randf_range(0.7, 1.2)
		var at := Vector2.ZERO
		if surface == "wade":
			# Strung along the line, never piled on one point.
			at.x = float(i % (2 * WADE_SPREAD + 1) - WADE_SPREAD)
		_particles.append([at, dir * speed, life, life])
	z_index = 2


func _physics_process(delta: float) -> void:
	var alive := false
	for p: Array in _particles:
		p[2] -= delta
		if p[2] > 0.0:
			alive = true
			p[1] = p[1] * 0.92 + Vector2(0, _rise) * delta
			p[0] += p[1] * delta
	if not alive:
		queue_free()
	queue_redraw()


func _draw() -> void:
	for p: Array in _particles:
		if p[2] <= 0.0:
			continue
		var k: float = p[2] / p[3]
		var s := maxf(1.0, round(_size * k + 0.4))
		draw_rect(Rect2((p[0] as Vector2).round(), Vector2(s, s)), Color(_color, k))

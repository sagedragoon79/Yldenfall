class_name MeteorEmbers
extends Node2D
## A patch of embers where a stillglass glob splashed on the floor: it burns
## whoever stands in it for LIFE seconds, then dies down. The origin is on the
## floor's surface.

## What its blow is made of (design bible 5.6).
const DAMAGE_KIND := DamageKind.FIRE
const LIFE := 1.4
const WIDTH := 22.0
const HEIGHT := 8.0
const DAMAGE := 8
const HOT := Color("ff7a2a")
const CORE := Color("ffe08a")

var _t := 0.0
var _hit := false


func _ready() -> void:
	z_index = 1
	add_to_group("enemy_projectile")


func hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(WIDTH * 0.5, HEIGHT), Vector2(WIDTH, HEIGHT))


func _physics_process(delta: float) -> void:
	if TimeStop.active():
		return  # held still by the Stillstone
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	if not _hit:
		var p := get_tree().get_first_node_in_group("player") as Player
		if p != null and not p.dead and hit_rect().intersects(p.body_rect()):
			_hit = p.receive_attack(DAMAGE, self, false) != ""
	queue_redraw()


func _draw() -> void:
	var k := 1.0 - _t / LIFE
	for i in 7:
		var x := -WIDTH * 0.5 + i * (WIDTH / 6.0)
		var h := (2.0 + float((i * 5) % 4)) * (0.6 + 0.4 * sin(_t * 18.0 + i * 1.7)) * k
		draw_rect(Rect2(x - 1.0, -h, 2.0, h), Color(HOT, 0.85 * k))
		draw_rect(Rect2(x - 0.5, -h * 0.5, 1.0, h * 0.5), Color(CORE, k))
	draw_rect(Rect2(-WIDTH * 0.5, -1.0, WIDTH, 1.0), Color(HOT, 0.6 * k))

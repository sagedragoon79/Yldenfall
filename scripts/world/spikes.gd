class_name Spikes
extends Area2D
## A tile of floor spikes. Hurts on touch, and can be pogoed with the Delver's Pick.
##
## Read with a double rim so the hazard pops on any floor (bible 12.24, pass 527): a
## dark iron SILHOUETTE carries it over pale floors, a near-white steel RIM and tip
## carry it over the dark ones (haar, evercrown) the independent grade flagged. All
## four tones are master-palette (neutral ramp), so the hazard is on the ramp too.

const SILHOUETTE := Color("2f2c3a")  ## dark iron body — reads over pale floors
const FACE := Color("867ba2")        ## the lit left face
const RIM := Color("ece8ed")         ## near-white catchlight + tip — reads over dark floors
const BASE := Color("131217")        ## a contact shadow seating the cluster


func _ready() -> void:
	collision_layer = Player.LAYER_HAZARD
	collision_mask = 0
	monitoring = false
	add_to_group("hazard")
	add_to_group("pogo")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 9)
	shape.shape = rect
	shape.position = Vector2(0, -4.5)
	add_child(shape)


func _draw() -> void:
	# A contact shadow under the whole cluster, so the spikes seat on a pale floor.
	draw_rect(Rect2(-8.0, 0.0, 16.0, 1.0), Color(BASE, 0.55))
	for i in 4:
		var x := -8.0 + i * 4.0
		# The dark body: the full triangle, the silhouette over a pale floor.
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 2, -10), Vector2(x + 4, 0)]), SILHOUETTE)
		# The lit left face.
		draw_colored_polygon(PackedVector2Array([Vector2(x + 1, 0), Vector2(x + 2, -10), Vector2(x + 2, 0)]), FACE)
		# The bright catchlight down the leading edge, and a hot tip cap: the rim the
		# eye finds over a dark floor.
		draw_line(Vector2(x, 0), Vector2(x + 2, -10), RIM, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 1.3, -7), Vector2(x + 2, -10), Vector2(x + 2.7, -7)]), RIM)

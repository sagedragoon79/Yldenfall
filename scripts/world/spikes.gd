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
## Teeth in a tile's cluster.
const TEETH := 4


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
	for i in TEETH:
		var x := -8.0 + i * 4.0
		# The dark body: the full triangle, the silhouette over a pale floor.
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 2, -10), Vector2(x + 4, 0)]), SILHOUETTE)
		# The lit left face.
		draw_colored_polygon(PackedVector2Array([Vector2(x + 1, 0), Vector2(x + 2, -10), Vector2(x + 2, 0)]), FACE)
	draw_rim(self, Vector2.ZERO, 1.0)


## The bright catchlight down each tooth's leading edge and its hot tip cap: the rim
## the eye finds over a dark floor. `at` is the cluster's bottom centre on `canvas`.
## Standing water draws it again over itself, so what hurts shows through (bible 12.49).
## `far_edge` also traces each tooth's shaded edge in the face tone: under water the
## dark body is lost, and the two edges together keep the point's shape.
static func draw_rim(canvas: CanvasItem, at: Vector2, alpha: float, far_edge := false) -> void:
	var rim := Color(RIM, alpha)
	for i in TEETH:
		var x := at.x - 8.0 + i * 4.0
		if far_edge:
			canvas.draw_line(Vector2(x + 4, at.y), Vector2(x + 2, at.y - 10), Color(FACE, alpha), 1.0)
		canvas.draw_line(Vector2(x, at.y), Vector2(x + 2, at.y - 10), rim, 1.0)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x + 1.3, at.y - 7), Vector2(x + 2, at.y - 10), Vector2(x + 2.7, at.y - 7)]), rim)

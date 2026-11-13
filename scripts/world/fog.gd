class_name Fog
extends Node2D
## The Haar's fog (design bible 3.2): a murk over the room that hides all but a
## pocket around the player and every light: the lanterns of the decor and
## anything in the group "light" with a `light_radius`. Restoring the Spring of
## Haar lifts it by half: thinner, and the player sees further.
## Until then the fog is the Haar Wyrm's steam (8.4): warm, and rising in wisps.
## Once the spring runs the steam stops and what is left is a cool mist that
## drifts sideways (`steaming`).
## The fog is on in zones listed in ZONES; a room's `fog:` header sets its
## density (0 turns it off).

const SHADER := preload("res://shaders/fog.gdshader")
const ZONES := {"haar": 0.88}
const MAX_LIGHTS := 48
const VISION := 112.0
const LANTERN_RADIUS := 64.0
const SPRING_FLAG := "spring:haar"
const SPRING_VISION := 1.5
const SPRING_DENSITY := 0.5

## Cells in the drift lattice the shader samples (one texel each).
const DRIFT_SIZE := 64

static var _drift: ImageTexture

var density := 0.0
var lights: Array[Vector3] = []

var _room: Room
var _rect: ColorRect
var _mat: ShaderMaterial
## The fog renders here at one texel per world pixel (a quarter of the
## fragments of drawing it at the game's 2x detail), then _sprite shows it.
var _view: SubViewport
var _sprite: Sprite2D


func _ready() -> void:
	z_index = 4
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("drift_tex", drift_texture())
	_view = SubViewport.new()
	_view.transparent_bg = true
	_view.disable_3d = true
	_view.size = Vector2i(16, 16)
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(_rect)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = _view.get_texture()
	add_child(_sprite)
	visible = false


## A tileable lattice of random values, made once: the shader's drifting murk.
static func drift_texture() -> ImageTexture:
	if _drift == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1987
		var img := Image.create(DRIFT_SIZE, DRIFT_SIZE, false, Image.FORMAT_L8)
		for y in DRIFT_SIZE:
			for x in DRIFT_SIZE:
				var v := rng.randf()
				img.set_pixel(x, y, Color(v, v, v))
		_drift = ImageTexture.create_from_image(img)
	return _drift


## Turns the fog on or off for `room`.
func set_room(room: Room) -> void:
	_room = room
	density = 0.0
	if room != null:
		density = float(room.header.get("fog", ZONES.get(room.zone, 0.0)))
		if GameState.flag(SPRING_FLAG):
			density *= SPRING_DENSITY
	visible = density > 0.0
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	_mat.set_shader_parameter("density", density)
	_mat.set_shader_parameter("steam", 1.0 if steaming() else 0.0)
	_update()


## True while the fog is still the Haar Wyrm's steam: warm and rising.
func steaming() -> bool:
	return density > 0.0 and not GameState.flag(SPRING_FLAG)


func vision() -> float:
	return VISION * (SPRING_VISION if GameState.flag(SPRING_FLAG) else 1.0)


func _process(_delta: float) -> void:
	if visible:
		_update()


func _update() -> void:
	lights.clear()
	if density <= 0.0 or _room == null or not is_instance_valid(_room):
		return
	var view := _view_rect()
	# Whole world pixels, so the scaled-up texels land on the world's pixel grid.
	var origin := view.position.floor()
	var size := Vector2i(ceili(view.end.x - origin.x), ceili(view.end.y - origin.y))
	if _view.size != size:
		_view.size = size
		_rect.size = Vector2(size)
	_sprite.position = origin
	_mat.set_shader_parameter("origin", origin)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null:
		lights.append(Vector3(p.global_position.x, p.global_position.y - 14.0, vision()))
	# Lights that matter to play first (a boss's lanterns, a hag's wisp and her
	# mark, spells, abilities): few and often moving, always lit wherever the
	# camera is. Only then the decor's lanterns, so they can never crowd one out.
	for n in get_tree().get_nodes_in_group("light"):
		var n2 := n as Node2D
		if n2 != null and lights.size() < MAX_LIGHTS:
			lights.append(Vector3(n2.global_position.x, n2.global_position.y, float(n2.get("light_radius"))))
	var decor := _room.get_node_or_null("Decor") as Decor
	var near := view.grow(LANTERN_RADIUS)
	if decor != null:
		for g in decor.glows:
			if lights.size() < MAX_LIGHTS and near.has_point(g):
				lights.append(Vector3(g.x, g.y, LANTERN_RADIUS))
	var packed := PackedVector3Array(lights)
	packed.resize(MAX_LIGHTS)
	_mat.set_shader_parameter("lights", packed)
	_mat.set_shader_parameter("light_count", lights.size())


## How much a light clears the fog at `world_pos`: 1 in a light's pocket, 0 out
## in the murk (1 everywhere when there is no fog). Matches the shader's falloff.
func clear_at(world_pos: Vector2) -> float:
	if density <= 0.0:
		return 1.0
	var clear := 0.0
	for l in lights:
		var d := world_pos.distance_to(Vector2(l.x, l.y))
		clear = maxf(clear, 1.0 - smoothstep(l.z * 0.45, l.z, d))
	return clear


## How much of the scene shows through at `world_pos` (1 - the fog's opacity there).
func visibility_at(world_pos: Vector2) -> float:
	return clampf(1.0 - density * (1.0 - clear_at(world_pos)), 0.0, 1.0)


## The fog over the current scene, or null.
static func current(tree: SceneTree) -> Fog:
	var w := tree.get_first_node_in_group("world") as World
	return w.fog if w != null else null


func _view_rect() -> Rect2:
	var vp := get_viewport()
	var t := vp.get_canvas_transform()
	var origin := -t.origin / t.get_scale()
	var size := vp.get_visible_rect().size / t.get_scale()
	return Rect2(origin - Vector2(8, 8), size + Vector2(16, 16))

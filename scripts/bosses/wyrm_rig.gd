class_name WyrmRig
extends Node2D
## The Haar Wyrm on a skeleton: a prototype (Sean, 2026-11-19) to judge a rig against
## drawing every frame. `HaarWyrm.use_rig` puts it in the fight in place of the
## code-drawn heads and necks; the fight itself is untouched and still moves the heads.
##
## The skeleton is a `Skeleton2D`: a body bone, and from each of the three stumps on its
## shoulders a chain of neck bones that ends in a head bone. Each bone carries one part
## of Sean's PixelLab art (packed by tools/art/wyrm_rig_pack.py): the neck sections are
## the eight tapering cups of his trim sheets, stacked from the widest at the stump to the
## narrowest at the skull. A cup sits in the one below it, so a neck can telescope: it
## shows less of each section to shorten and more to reach (`STACK_MIN` to `STACK_MAX`).
##
## Nothing here is animated by hand. Each frame the neck is laid along a curve from its
## stump to where the fight has put the head: up out of the stump, and into the skull from
## behind. The curve bends more when the head comes close, and its belly trails the head
## a little, so a snap of the head runs down the neck. The heads keep their frame-by-frame
## clips (jaws, the glowing throat): a jaw can't be done with bones this size.

const DIR := "res://assets/bosses/haar_wyrm/"
## The art is drawn at twice the world's detail.
const ART := 0.5
## Bones in each neck, in head order (west, middle, east).
const BONES := [20, 13, 20]
## Which trim sheet each neck is cut from: the middle head faces us.
const VIEWS := ["side", "front", "side"]
## How much of a section shows above the one it sits in: at rest, and the least and the
## most a neck may telescope to.
const STACK := 0.58
const STACK_MIN := 0.36
const STACK_MAX := 0.76
## Where the body stands, from the boss: the middle of its feet, on the tunnel's floor.
const BODY_AT := Vector2(0, 105)
## Which way each stump points.
const STUMP_DIRS := [Vector2(-0.3, -1.0), Vector2(0.0, -1.0), Vector2(0.3, -1.0)]
## The dark of the tunnel: the body and the root of each neck stand in it.
const SHADOW := Color(0.2, 0.15, 0.24)
const DRENCHED := Color(0.7, 0.88, 1.0)
const LIMP := Color(0.6, 0.62, 0.61)
## How much of a neck, from the stump, is still in the tunnel's dark.
const SHADOW_REACH := 0.4
## How fast the belly of a neck catches up with its head.
const TRAIL := 5.0
const CURVE_STEPS := 40
## Sections toward the head are drawn over those toward the body.
const HEADWARD_ON_TOP := true

const WASH := "shader_type canvas_item;
uniform float white = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb, vec3(1.0), white);
	COLOR = c;
}"


## One neck and its head.
class Neck:
	var index := 0
	var view := "side"
	var flip := false
	var bones: Array[Bone2D] = []
	var skins: Array[Sprite2D] = []
	var head_bone: Bone2D
	var head_skin: Sprite2D
	var head_layout := {}
	## Each bone's section height in world pixels, and their sum.
	var heights := PackedFloat32Array()
	var total := 0.0
	## The joints as last solved, in the rig's space (one more than the bones).
	var joints := PackedVector2Array()
	## How much of each section shows (see STACK).
	var stack := STACK
	var trail := Vector2.ZERO
	var rot := 0.0
	var clip := "idle"
	var frame := 0
	var shown := false
	var material: ShaderMaterial


var skeleton: Skeleton2D
var body_bone: Bone2D
var body_skin: Sprite2D
var necks: Array[Neck] = []
var layout := {}

var _back: Node2D
var _skin: Node2D
var _time := 0.0
var _body_clip := "cloaked"
var _body_time := 0.0
var _shader: Shader


func _init() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(DIR + "rig.json"))
	_shader = Shader.new()
	_shader.code = WASH


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The body stands in the tunnel, behind everything the fight draws.
	_back = Node2D.new()
	_back.name = "Back"
	_back.z_index = -1
	add_child(_back)
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	_skin = Node2D.new()
	_skin.name = "Skin"
	add_child(_skin)

	var body: Dictionary = layout["body"]
	body_bone = _bone("body", skeleton, 16.0)
	body_bone.position = BODY_AT - (_point(body["joints"]["ground"]) - _cell_centre(body)) * ART
	body_skin = Sprite2D.new()
	body_skin.texture = load(DIR + String(body["sheet"]))
	body_skin.region_enabled = true
	body_skin.scale = Vector2(ART, ART)
	_back.add_child(body_skin)
	_set_cell(body_skin, body, 0)

	# The side necks first, the middle one over them: its head comes toward us.
	for i: int in [0, 2, 1]:
		necks.append(_build_neck(i))
	necks.sort_custom(func(a: Neck, b: Neck) -> bool: return a.index < b.index)
	for n in necks:
		_skin.move_child(n.head_skin, -1)
	_skin.move_child(necks[1].head_skin, -1)


func _bone(bone_name: String, parent: Node, length: float) -> Bone2D:
	var b := Bone2D.new()
	b.name = bone_name
	b.set_autocalculate_length_and_angle(false)
	b.set_length(length)
	b.set_bone_angle(0.0)
	parent.add_child(b)
	b.rest = b.transform
	return b


func _build_neck(i: int) -> Neck:
	var n := Neck.new()
	n.index = i
	n.view = VIEWS[i]
	# The spines run down the outside of the bend: the west neck is the east one mirrored.
	n.flip = i == 0
	n.material = ShaderMaterial.new()
	n.material.shader = _shader
	var sheet: Dictionary = layout["neck_" + n.view]
	var tex: Texture2D = load(DIR + String(sheet["sheet"]))
	var cell := _point(sheet["cell"])
	var sections: Array = sheet["sections"]
	var parent: Node = body_bone
	var count: int = BONES[i]
	var sprites: Array[Sprite2D] = []
	for k in count:
		var s: int = mini(k * sections.size() / count, sections.size() - 1)
		var sec: Dictionary = sections[s]
		var foot := _point(sec["foot"])
		var rim := _point(sec["rim"])
		if n.flip:
			foot.x = cell.x - foot.x
			rim.x = cell.x - rim.x
		var h := foot.distance_to(rim) * ART
		n.heights.append(h)
		n.total += h
		var b := _bone("neck%d_%d" % [i, k], parent, h * STACK)
		n.bones.append(b)
		parent = b
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.region_enabled = true
		sp.region_rect = Rect2(s * cell.x, 0, cell.x, cell.y)
		sp.centered = false
		sp.offset = -foot
		sp.flip_h = n.flip
		sp.scale = Vector2(ART, ART)
		sp.material = n.material
		# The section's own lean, so its foot-to-rim line lies along the bone.
		sp.set_meta("lean", -(rim - foot).angle())
		sprites.append(sp)
		n.skins.append(sp)
	if not HEADWARD_ON_TOP:
		sprites.reverse()
	for sp in sprites:
		_skin.add_child(sp)
	n.head_bone = _bone("head%d" % i, parent, 12.0)
	n.head_layout = layout["head_east" if n.view == "side" else "head_south"]
	n.head_skin = Sprite2D.new()
	n.head_skin.texture = load(DIR + String(n.head_layout["sheet"]))
	n.head_skin.region_enabled = true
	n.head_skin.scale = Vector2(ART, ART)
	n.head_skin.material = n.material
	_skin.add_child(n.head_skin)
	_set_cell(n.head_skin, n.head_layout, 0)
	n.joints.resize(count + 1)
	return n


static func _point(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _cell_centre(part: Dictionary) -> Vector2:
	return _point(part["cell"]) * 0.5


static func _set_cell(sp: Sprite2D, part: Dictionary, cell: int) -> void:
	var size := _point(part["cell"])
	var columns: int = int(part["columns"])
	sp.region_rect = Rect2((cell % columns) * size.x, (cell / columns) * size.y, size.x, size.y)


## Where neck `i` leaves the body, in the rig's space.
func stump(i: int) -> Vector2:
	var body: Dictionary = layout["body"]
	var stumps: Array = body["joints"]["stumps"]
	return body_bone.position + (_point(stumps[i]) - _cell_centre(body)) * ART


## From a head's middle to a joint of its art (`neck` or `mouth`), turned and mirrored
## as the head is.
func head_joint(n: Neck, joint: String, face: float, rot: float) -> Vector2:
	var off := (_point(n.head_layout["joints"][joint]) - _cell_centre(n.head_layout)) * ART
	if n.view == "side":
		off.x *= face
	return off.rotated(rot)


## Where head `i`'s breath leaves its jaws, for a head whose middle is at `centre`.
func mouth(i: int, centre: Vector2, face: float) -> Vector2:
	return centre + head_joint(necks[i], "mouth", face, necks[i].rot)


## The shortest and the longest a neck can be.
func reach(i: int) -> Vector2:
	return Vector2(necks[i].total * STACK_MIN, necks[i].total * STACK_MAX)


## Poses the whole rig from the fight. Call once a frame.
func pose(boss: HaarWyrm, delta: float) -> void:
	_time += delta
	var fade := 1.0
	if boss.state == "dying":
		fade = 1.0 - clampf(boss.state_time / HaarWyrm.DYING_TIME, 0.0, 1.0)
	_pose_body(boss, delta, fade)
	for n in necks:
		var h := boss.heads[n.index]
		if not is_instance_valid(h):
			continue
		var blink := h.mode == "tell" and int(h.mode_time * 12.0) % 2 == 0 and h.mode_time > boss.tell(boss._tell_of(h)) - 0.35
		pose_head(n.index, to_local(h.global_position), {
			"mode": h.mode, "time": h.mode_time, "face": boss._face(h), "aim": h.aim, "breath": h.breath,
			"weak": h.weak, "dead": h.dead, "white": 1.0 if h.flash > 0.0 else (0.6 if blink else 0.0),
			"tell": boss.tell(boss._tell_of(h)), "fade": fade,
		}, delta)


func _pose_body(boss: HaarWyrm, delta: float, fade: float) -> void:
	var body: Dictionary = layout["body"]
	var want := "cloaked"
	if boss.state == "dying":
		want = "flail"
	elif boss.state == "fight" and boss.step == "rage":
		want = "shift"
	if want != _body_clip:
		_body_clip = want
		_body_time = 0.0
	_body_time += delta
	var clip: Dictionary = body["clips"][_body_clip]
	var f := int(_body_time * float(clip["fps"])) % int(clip["count"])
	_set_cell(body_skin, body, int(clip["start"]) + f)
	# The stills Sean cloaked are dark already; a lit clip is put in the same dark.
	var tint := Color.WHITE if _body_clip == "cloaked" else SHADOW.lightened(0.25)
	if boss.state == "dying":
		tint = SHADOW.lerp(Color.WHITE, clampf(boss.state_time / 0.5, 0.0, 1.0))
	body_skin.modulate = Color(tint, fade)
	# It breathes: the stumps, and so the necks, ride on it.
	var breath := sin(_time * 1.1) * 1.0
	body_bone.position.y = BODY_AT.y - (_point(body["joints"]["ground"]).y - _cell_centre(body).y) * ART + breath * 0.5
	body_skin.position = body_bone.position
	body_skin.scale = Vector2(ART, ART * (1.0 + breath * 0.006))


## Poses one neck and its head. `centre` is the middle of the head in the rig's space;
## `s` is what the head is doing (see `pose`).
func pose_head(i: int, centre: Vector2, s: Dictionary, delta: float) -> void:
	var n := necks[i]
	var mode: String = s.get("mode", "idle")
	var shown := mode != "hidden"
	for sp in n.skins:
		sp.visible = shown
	n.head_skin.visible = shown
	if not shown:
		n.shown = false
		return
	var face: float = s.get("face", 1.0)
	var time: float = s.get("time", 0.0)
	var breath: String = s.get("breath", HydraHead.PLUME)

	# The head: its turn, and its frame.
	var want := _head_turn(n, mode, breath, face, s.get("aim", Vector2.DOWN), time)
	if not n.shown:
		n.rot = want
		n.trail = centre
	n.rot = lerp_angle(n.rot, want, 1.0 - exp(-10.0 * delta))
	_head_frame(n, mode, breath, time, float(s.get("tell", 1.0)))
	n.head_skin.position = centre
	n.head_skin.rotation = n.rot
	n.head_skin.flip_h = n.view == "side" and face < 0.0

	# The neck: from the stump to the back of the skull.
	n.trail = n.trail.lerp(centre, 1.0 - exp(-TRAIL * delta))
	n.shown = true
	var root := stump(i)
	var tip := centre + head_joint(n, "neck", face, n.rot)
	var up: Vector2 = (STUMP_DIRS[i] as Vector2).normalized()
	var into: Vector2
	var grip := 0.5
	if n.view == "side":
		# From behind and below. A head that looks back toward its own body turns its neck
		# round behind it, coming in from above, as far as the neck has slack to spare.
		var slack := clampf((n.total * STACK - root.distance_to(tip)) / (n.total * STACK * 0.4), 0.0, 1.0)
		var back := smoothstep(-0.2, 0.6, Vector2(face, 0).dot((root - tip).normalized())) * slack
		into = Vector2(-face * 0.8, lerpf(0.6, -0.5, back)).normalized().rotated(n.rot)
		grip = lerpf(0.5, 1.5, back)
	else:
		# The middle head faces us: its neck comes from below, or over the top once the
		# head hangs lower than its stump. It bows to one side then, so it never folds
		# flat on itself.
		var over := smoothstep(-70.0, -10.0, tip.y - root.y)
		up = Vector2(-0.7 * over, -1.0).normalized()
		into = Vector2(-0.9 * over, lerpf(1.0, -1.0, over)).normalized()
		grip = lerpf(0.5, 1.0, over)
	var lag := (n.trail - centre) * 0.6
	var sway := Vector2(sin(_time * 0.9 + i * 2.1), cos(_time * 0.7 + i)) * 3.0
	if s.get("dead", false):
		sway = Vector2.ZERO
	solve(n, root, tip, up, into, lag + sway, grip)

	# The bones, then the skin on them.
	var xf := global_transform
	for k in n.bones.size():
		var b := n.bones[k]
		b.global_position = xf * n.joints[k]
		b.global_rotation = global_rotation + (n.joints[k + 1] - n.joints[k]).angle()
		b.set_length(n.joints[k].distance_to(n.joints[k + 1]))
	n.head_bone.global_position = xf * tip
	n.head_bone.global_rotation = global_rotation + n.rot

	# Its color: the tunnel's dark at the root, and what has happened to the head.
	var state_tint := Color.WHITE
	if s.get("dead", false):
		state_tint = LIMP
	elif s.get("weak", false):
		state_tint = DRENCHED
	var out := 1.0
	if mode == "emerge":
		out = clampf(time / HaarWyrm.EMERGE_TIME, 0.0, 1.0)
	var fade: float = s.get("fade", 1.0)
	n.material.set_shader_parameter("white", float(s.get("white", 0.0)))
	for k in n.skins.size():
		var sp := n.skins[k]
		sp.position = n.joints[k]
		sp.rotation = (n.joints[k + 1] - n.joints[k]).angle() + float(sp.get_meta("lean"))
		var lit := smoothstep(0.0, SHADOW_REACH, float(k) / n.skins.size()) * out
		sp.modulate = Color(SHADOW.lerp(Color.WHITE, lit) * state_tint, fade)
	n.head_skin.modulate = Color(SHADOW.lerp(Color.WHITE, out) * state_tint, fade)


## How far the head is turned, nose down for a side head (in radians).
func _head_turn(n: Neck, mode: String, breath: String, face: float, aim: Vector2, time: float) -> float:
	if n.view != "side":
		match mode:
			"limp":
				return 0.45
			"weak":
				return 0.18 + sin(_time * 1.5) * 0.03
			"rage":
				return sin(_time * 30.0) * 0.08
		return sin(_time * 0.8) * 0.04
	var to_aim := clampf(wrapf(aim.angle() - (0.0 if face > 0.0 else PI), -PI, PI), -1.1, 1.1)
	var nod := 0.0
	match mode:
		"idle", "rise":
			nod = sin(_time * 1.2 + n.index) * 0.05
		"tell":
			if breath == HydraHead.GEYSER:
				return to_aim
			nod = -0.3
		"breathe":
			if breath == HydraHead.GEYSER:
				return to_aim
			nod = 0.5
		"sag":
			nod = 0.4 + sin(time * 5.0) * 0.04
		"weak":
			nod = 0.55 + sin(_time * 1.5) * 0.03
		"rage":
			nod = -0.25 + sin(_time * 30.0 + n.index) * 0.1
		"limp":
			nod = 1.15
	return nod * face


## The head's frame, from its clips.
func _head_frame(n: Neck, mode: String, breath: String, time: float, tell: float) -> void:
	var clip := "idle"
	var f := 0
	var clips: Dictionary = n.head_layout["clips"]
	if n.view == "side":
		match mode:
			"tell":
				# It draws back: the first part of the clip, over the whole wind-up.
				clip = "pull"
				f = int(clampf(time / tell, 0.0, 1.0) * 8.0)
			"breathe":
				clip = "open"
			"sag":
				clip = "roar"
				f = int(time * 7.0) % int(clips[clip]["count"])
			"rage":
				clip = "jaw"
				f = int(time * 16.0) % int(clips[clip]["count"])
			"limp":
				clip = "roar"
				f = 5
	else:
		match mode:
			"tell":
				# The jaws open slowly on the glow in its throat.
				clip = "glow"
				f = int(clampf(time / tell, 0.0, 1.0) * 5.0)
			"breathe":
				clip = "glow"
				f = 4 + int(time * 8.0) % 2
			"sag":
				clip = "roar"
				f = int(time * 7.0) % int(clips[clip]["count"])
			"rage":
				clip = "glow"
				f = int(time * 14.0) % int(clips[clip]["count"])
	n.clip = clip
	n.frame = mini(f, int(clips[clip]["count"]) - 1)
	_set_cell(n.head_skin, n.head_layout, int(clips[clip]["start"]) + n.frame)


## Lays neck `n` along a curve from `root` to `tip`: out of the stump along `up`, into
## the skull along `into`, pushed sideways by `push`. The curve bends more to take up a
## neck that is too long and straightens for one that is too short; between the two the
## sections telescope (`n.stack`). `grip` is how far the skull's end of the curve holds
## its line, against the stump's.
func solve(n: Neck, root: Vector2, tip: Vector2, up: Vector2, into: Vector2, push: Vector2, grip := 0.5) -> void:
	var span := root.distance_to(tip)
	var low := n.total * STACK_MIN
	var high := n.total * STACK_MAX
	var handle := maxf(span * 0.42, 10.0)
	var pts := _curve(root, tip, up, into * grip, push, handle)
	var length := _length(pts)
	if length < low:
		# Too close: bend until the shortest neck fits.
		var a := handle
		var b := handle + low * 1.5
		for _i in 14:
			handle = (a + b) * 0.5
			pts = _curve(root, tip, up, into * grip, push, handle)
			length = _length(pts)
			if length < low:
				a = handle
			else:
				b = handle
	elif length > high:
		# Too far: straighten, as far as a straight line.
		var a := 0.0
		var b := handle
		for _i in 14:
			handle = (a + b) * 0.5
			pts = _curve(root, tip, up, into * grip, push * (handle / b), handle)
			length = _length(pts)
			if length > high:
				b = handle
			else:
				a = handle
	n.stack = length / n.total
	# The joints, each its section's share of the way along.
	var along := 0.0
	var seg := 0
	var walked := 0.0
	n.joints[0] = root
	for k in n.bones.size():
		along += n.heights[k] / n.total * length
		while seg < pts.size() - 2 and walked + pts[seg].distance_to(pts[seg + 1]) < along:
			walked += pts[seg].distance_to(pts[seg + 1])
			seg += 1
		var d := pts[seg].distance_to(pts[seg + 1])
		n.joints[k + 1] = pts[seg].lerp(pts[seg + 1], clampf((along - walked) / maxf(d, 0.001), 0.0, 1.0))
	n.joints[n.bones.size()] = tip


static func _curve(root: Vector2, tip: Vector2, up: Vector2, into: Vector2, push: Vector2, handle: float) -> PackedVector2Array:
	var c1 := root + up * handle + push
	var c2 := tip + into * handle + push
	var pts := PackedVector2Array()
	pts.resize(CURVE_STEPS + 1)
	for i in CURVE_STEPS + 1:
		pts[i] = root.bezier_interpolate(c1, c2, tip, float(i) / CURVE_STEPS)
	return pts


static func _length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total

class_name WyrmRig
extends Node2D
## The Haar Wyrm on a skeleton (design bible 8.4; Sean, 2026-11-19): how the fight is
## drawn. It began as a prototype to judge a rig against drawing every frame, and Sean
## kept it. `HaarWyrm` still runs the fight and moves the heads; this only shows them.
##
## The skeleton is a `Skeleton2D`: a body bone, and from each of the three stumps on its
## shoulders a chain of neck bones that ends in a head bone. Each bone carries one part
## of Sean's PixelLab art (packed by tools/art/wyrm_rig_pack.py): the neck sections are
## the eight tapering cups of his trim sheets, stacked from the widest at the stump to the
## narrowest at the skull. A cup sits in the one below it, so a neck can telescope: it
## shows less of each section to shorten and more to reach (`STACK_MIN` to `STACK_MAX`).
##
## Nothing here is animated by hand. Each frame the neck is laid along a curve from its
## stump to where the fight has put the head: up out of the stump, round behind the head
## and into the base of the skull. The curve bends more when the head comes close, and
## its belly trails the head a little, so a snap of the head runs down the neck.
##
## A head has five views, west, south-west, south, south-east and east (`look`, -2 to 2;
## the western two are the eastern two mirrored). It watches the player and turns through
## them one view at a time, so it never flips from one side to the other. In each view it
## keeps its frame-by-frame clips (jaws, the glowing throat): a jaw can't be done with
## bones this size.

const DIR := "res://assets/bosses/haar_wyrm/"
## The art is drawn at twice the world's detail.
const ART := 0.5
## Bones in each neck, in head order (west, middle, east). The side necks are long
## enough to pass a head that looks back at its body and curl round behind it.
const BONES := [26, 17, 26]
## Which trim sheet each neck is cut from: the middle neck comes toward us.
const VIEWS := ["side", "front", "side"]
## A head's art by how far it is turned from facing us: south, three-quarter, profile.
const HEAD_VIEWS := ["head_south", "head_se", "head_east"]
## How long a head shows each view as it turns through them.
const TURN_STEP := 0.09
## A head only turns once what it watches is this far (in views) past the one it shows.
const TURN_SLACK := 0.65
## How much of a section shows above the one it sits in: at rest, and the least and the
## most a neck may telescope to.
const STACK := 0.58
const STACK_MIN := 0.3
const STACK_MAX := 0.76
## How far behind the skull the neck holds its line before it turns in: at ease, and
## for a head that looks back toward its own body (the curl round behind it).
const HOOK := 26.0
const HOOK_BACK := 58.0
## In profile the whole curl shows, so it is wider.
const HOOK_PROFILE := 84.0
## Where the body stands, from the boss: the middle of its feet, on the tunnel's floor,
## which is level with the lip of the cistern sunk in the arena's floor before it.
const BODY_AT := Vector2(0, 145)
## Which way each stump points.
const STUMP_DIRS := [Vector2(-0.3, -1.0), Vector2(0.0, -1.0), Vector2(0.3, -1.0)]
## The dark of the tunnel: the body and the root of each neck stand in it. Measured from
## Sean's own cloaked body against its lit art, so a neck's root is the color of the
## shoulder it grows from.
const SHADOW := Color(0.32, 0.24, 0.4)
const DRENCHED := Color(0.7, 0.88, 1.0)
const LIMP := Color(0.6, 0.62, 0.61)
const STEAM := Color("f4f7f6")
const STEAM_HOT := Color("fff1dc")
const DRIP := Color("9fd0f0")
const EYE := Color("f4d24c")
## The reveal (HaarWyrm.EYES_AT): how long a pair of eyes takes to open, and the snort.
const EYES_OPEN := 0.4
const SNORT := 1.2
## How much of a neck, from the stump, is still in the tunnel's dark.
const SHADOW_REACH := 0.4
## How fast the belly of a neck catches up with its head.
const TRAIL := 5.0
const CURVE_STEPS := 40
## The three-quarter roar clip goes pale on some frames (PixelLab drift): the frames that
## hold their color, opening and closing.
const ROAR_THREE_QUARTER := [1, 2, 3, 4, 5, 7, 8, 7, 5, 4, 3, 2]
## The fog head's channel: the frames of its glow clip with the jaws wide on the pulsing
## core in its throat, held for as long as the fog lasts.
const CHANNEL := [3, 4, 5, 4, 3, 2]
const CHANNEL_FPS := 7.0
## Sections toward the head are drawn over those toward the body.
const HEADWARD_ON_TOP := true

## The head's flash. COLOR already holds the art's pixel times the sprite's tint here;
## multiplying by the texture again would darken every pixel by itself.
const WASH := "shader_type canvas_item;
uniform float white = 0.0;
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), white);
}"


## One neck and its head.
class Neck:
	var index := 0
	## The neck's trim sheet: "side" or "front".
	var view := "side"
	var flip := false
	var bones: Array[Bone2D] = []
	var skins: Array[Sprite2D] = []
	var head_bone: Bone2D
	var head_skin: Sprite2D
	## The head's shadowed twin, laid over it while it is still in the tunnel's dark.
	var shade_skin: Sprite2D
	## The view the head shows: -2 west, -1 south-west, 0 south, 1 south-east, 2 east.
	var look := 0
	## The view it is turning toward, and how long it has shown this one.
	var look_want := 0
	var look_time := 0.0
	## The art of the view it shows (a part of rig.json).
	var head_layout := {}
	## Each bone's section height in world pixels, and their sum.
	var heights := PackedFloat32Array()
	var total := 0.0
	## The joints as last solved, in the rig's space (one more than the bones).
	var joints := PackedVector2Array()
	## How much of each section shows (see STACK).
	var stack := STACK
	var trail := Vector2.ZERO
	## How the neck leaves the skull, eased so a turn of the head swings it round.
	var into := Vector2.DOWN
	var rot := 0.0
	var clip := "idle"
	var frame := 0
	var shown := false
	## The head's white flash (a blow, the end of a wind-up). The neck never flashes:
	## a white neck reads as a ghost of it.
	var material: ShaderMaterial
	## What the head was last told (see `pose_head`), for the steam and the drips.
	var told := {}
	var centre := Vector2.ZERO
	## How far its eyes have opened in the reveal, while it is still in the tunnel.
	var eyes := 0.0

	## 1 for a head turned east (or facing us), -1 for one turned west: its art's mirror.
	func side() -> float:
		return -1.0 if look < 0 else 1.0


var skeleton: Skeleton2D
var body_bone: Bone2D
var body_skin: Sprite2D
var necks: Array[Neck] = []
var layout := {}

var _back: Node2D
var _skin: Node2D
var _fx: Node2D
var _time := 0.0
var _body_clip := "cloaked"
var _body_time := 0.0
var _shader: Shader
var _head_art := {}


func _init() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(DIR + "rig.json"))
	_shader = Shader.new()
	_shader.code = WASH


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for v: String in HEAD_VIEWS:
		_head_art[v] = load(DIR + String(layout[v]["sheet"]))
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
		_skin.move_child(n.shade_skin, -1)
	_skin.move_child(necks[1].head_skin, -1)
	_skin.move_child(necks[1].shade_skin, -1)
	# Steam, drips and the glow in a throat, over everything.
	_fx = Node2D.new()
	_fx.name = "Fx"
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


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
		# The section's own lean, so its foot-to-rim line lies along the bone.
		sp.set_meta("lean", -(rim - foot).angle())
		sprites.append(sp)
		n.skins.append(sp)
	if not HEADWARD_ON_TOP:
		sprites.reverse()
	for sp in sprites:
		_skin.add_child(sp)
	n.head_bone = _bone("head%d" % i, parent, 12.0)
	# At rest the side heads are in profile, looking out; the middle one faces us.
	n.look = [-2, 0, 2][i]
	n.look_want = n.look
	n.head_skin = Sprite2D.new()
	n.head_skin.region_enabled = true
	n.head_skin.scale = Vector2(ART, ART)
	n.head_skin.material = n.material
	_skin.add_child(n.head_skin)
	n.shade_skin = Sprite2D.new()
	n.shade_skin.region_enabled = true
	n.shade_skin.scale = Vector2(ART, ART)
	n.shade_skin.visible = false
	_skin.add_child(n.shade_skin)
	_wear_view(n)
	_set_cell(n.head_skin, n.head_layout, 0)
	n.joints.resize(count + 1)
	return n


## Puts on the art of the view the head shows.
func _wear_view(n: Neck) -> void:
	var key: String = HEAD_VIEWS[absi(n.look)]
	n.head_layout = layout[key]
	n.head_skin.texture = _head_art[key]
	n.shade_skin.texture = _head_art[key]


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


## From a head's middle to a point of its art, mirrored and turned as the head is.
func _from_centre(n: Neck, point: Array) -> Vector2:
	var off := (_point(point) - _cell_centre(n.head_layout)) * ART
	off.x *= n.side()
	return off.rotated(n.rot)


## From a head's middle to a joint of the view it shows (`neck` or `mouth`).
func head_joint(n: Neck, joint: String) -> Vector2:
	return _from_centre(n, n.head_layout["joints"][joint])


## Where head `i`'s breath leaves its jaws, for a head whose middle is at `centre`.
func mouth(i: int, centre: Vector2) -> Vector2:
	return centre + head_joint(necks[i], "mouth")


## The shortest and the longest a neck can be.
func reach(i: int) -> Vector2:
	return Vector2(necks[i].total * STACK_MIN, necks[i].total * STACK_MAX)


## The view that faces along `dir` (y down): 0 for straight down at us, 2 for due east.
static func view_toward(dir: Vector2) -> float:
	if dir == Vector2.ZERO:
		return 0.0
	return clampf(atan2(dir.x, maxf(dir.y, 0.0)) / (PI / 4.0), -2.0, 2.0)


## Poses the whole rig from the fight. Call once a frame.
func pose(boss: HaarWyrm, delta: float) -> void:
	_time += delta
	var fade := 1.0
	if boss.state == "dying":
		fade = 1.0 - clampf(boss.state_time / HaarWyrm.DYING_TIME, 0.0, 1.0)
	_pose_body(boss, delta, fade)
	var p := boss.player()
	for n in necks:
		var h := boss.heads[n.index]
		if not is_instance_valid(h):
			continue
		var blink := h.mode == "tell" and int(h.mode_time * 12.0) % 2 == 0 and h.mode_time > boss.tell(boss._tell_of(h)) - 0.35
		var s := {
			"mode": h.mode, "time": h.mode_time, "face": boss._face(h), "aim": h.aim, "breath": h.breath,
			"weak": h.weak, "dead": h.dead, "white": 1.0 if h.flash > 0.0 else (0.6 if blink else 0.0),
			"tell": boss.tell(boss._tell_of(h)), "fade": fade,
			"intro": boss._intro_t if boss.state == "intro" else -1.0,
		}
		if p != null:
			# It watches the hero.
			s["watch"] = p.body_rect().get_center() - h.global_position
		pose_head(n.index, to_local(h.global_position), s, delta)
	_fx.queue_redraw()


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
	# The tunnel is black until the heads come out of it.
	if boss.state == "dormant":
		fade = 0.0
	elif boss.state == "intro":
		fade = smoothstep(float(HaarWyrm.EMERGE_AT[0]) - 0.2, float(HaarWyrm.EMERGE_AT[2]) + HaarWyrm.EMERGE_TIME, boss._intro_t)
	var clip: Dictionary = body["clips"][_body_clip]
	var f := int(_body_time * float(clip["fps"])) % int(clip["count"])
	_set_cell(body_skin, body, int(clip["start"]) + f)
	# The stills Sean cloaked are dark already; a lit clip is put in the same dark.
	var tint := Color.WHITE if _body_clip == "cloaked" else SHADOW
	if boss.state == "dying":
		tint = SHADOW.lerp(Color.WHITE, clampf(boss.state_time / 0.5, 0.0, 1.0))
	body_skin.modulate = Color(tint, fade)
	# It breathes: the stumps, and so the necks, ride on it.
	var breath := sin(_time * 1.1) * 1.0
	body_bone.position.y = BODY_AT.y - (_point(body["joints"]["ground"]).y - _cell_centre(body).y) * ART + breath * 0.5
	body_skin.position = body_bone.position
	body_skin.scale = Vector2(ART, ART * (1.0 + breath * 0.006))


## Poses one neck and its head. `centre` is the middle of the head in the rig's space;
## `s` is what the head is doing (see `pose`): `watch` is the way to what it looks at
## (without it, it looks along `face`, in profile).
func pose_head(i: int, centre: Vector2, s: Dictionary, delta: float) -> void:
	var n := necks[i]
	var mode: String = s.get("mode", "idle")
	n.told = s
	n.centre = centre
	# A head still in the tunnel shows nothing, until its eyes open in the reveal.
	var intro: float = s.get("intro", -1.0)
	var eyes := 0.0
	if mode == "hidden" and intro >= 0.0:
		eyes = clampf((intro - float(HaarWyrm.EYES_AT[i])) / EYES_OPEN, 0.0, 1.0)
	n.eyes = eyes
	var shown := mode != "hidden" or eyes > 0.0
	for sp in n.skins:
		sp.visible = shown
	n.head_skin.visible = shown
	n.shade_skin.visible = false
	if not shown:
		n.shown = false
		return
	var time: float = s.get("time", 0.0)
	var breath: String = s.get("breath", HydraHead.PLUME)

	# The head: the view it turns to, one at a time.
	var want := _want_look(n, mode, breath, s)
	if not n.shown:
		n.look = want
		n.look_time = 0.0
	n.look_time += delta
	if n.look != want and n.look_time >= TURN_STEP:
		n.look += signi(want - n.look)
		n.look_time = 0.0
	_wear_view(n)

	# Its tilt, and its frame.
	var tilt := _head_tilt(n, mode, breath, s.get("aim", Vector2.DOWN), time)
	if not n.shown:
		n.rot = tilt
		n.trail = centre
	n.rot = lerp_angle(n.rot, tilt, 1.0 - exp(-10.0 * delta))
	_head_frame(n, mode, breath, time, float(s.get("tell", 1.0)))
	if mode == "hidden" and n.look == 0:
		_reveal_frame(n, intro)
	n.head_skin.position = centre
	n.head_skin.rotation = n.rot
	n.head_skin.flip_h = n.look < 0

	# The neck: from the stump, round behind the head, to the base of the skull.
	var root := stump(i)
	var tip := centre + head_joint(n, "neck")
	var up: Vector2 = (STUMP_DIRS[i] as Vector2).normalized()
	# How far the head is turned to a side: -1 west, 0 facing us, 1 east.
	var turned := clampf(float(n.look), -1.0, 1.0)
	var into: Vector2
	var hook := HOOK
	if n.view == "side":
		# From below the head and a little behind it. A head that looks back toward its
		# own body has its neck pass under it and curl up to the base of the skull. (It
		# comes from below, not straight from behind: a neck that ran behind the head
		# showed only the tip of its curl, like a cut pipe.)
		var back := smoothstep(-0.2, 0.6, Vector2(turned, 0).dot((root - tip).normalized()))
		into = Vector2(-0.55 * turned, 0.85).normalized().rotated(n.rot * absf(turned) * 0.5)
		hook = lerpf(HOOK, HOOK_PROFILE if absi(n.look) == 2 else HOOK_BACK, back)
		# A curl needs room: close to its stump the neck has none to spare for one.
		hook = minf(hook, maxf(HOOK, root.distance_to(tip) * 0.45))
		if s.get("dead", false):
			# A dead head only hangs: nothing holds a curl in its neck.
			hook = HOOK
	else:
		# The middle head's neck comes from below, or over the top once the head hangs
		# lower than its stump. It bows to one side then, so it never folds flat on
		# itself, and it swings out behind the head when the head turns aside.
		var over := smoothstep(-70.0, -10.0, tip.y - root.y)
		up = Vector2(-0.7 * over, -1.0).normalized()
		into = Vector2(-0.9 * over - 0.85 * turned, lerpf(1.0, -1.0, over)).normalized()
		hook = lerpf(0.5, 1.0, over) * maxf(root.distance_to(tip) * 0.42, 10.0)
	if not n.shown:
		n.into = into
	n.into = n.into.slerp(into, 1.0 - exp(-8.0 * delta)) if n.into.dot(into) > -0.99 else into
	n.trail = n.trail.lerp(centre, 1.0 - exp(-TRAIL * delta))
	n.shown = true
	var lag := (n.trail - centre) * 0.6
	var sway := Vector2(sin(_time * 0.9 + i * 2.1), cos(_time * 0.7 + i)) * 3.0
	if s.get("dead", false):
		sway = Vector2.ZERO
	solve(n, root, tip, up, n.into, lag + sway, hook)

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
	elif mode == "hidden":
		out = 0.0
	var fade: float = s.get("fade", 1.0)
	if mode == "hidden":
		fade *= eyes
	n.material.set_shader_parameter("white", float(s.get("white", 0.0)))
	for k in n.skins.size():
		var sp := n.skins[k]
		sp.position = n.joints[k]
		sp.rotation = (n.joints[k + 1] - n.joints[k]).angle() + float(sp.get_meta("lean"))
		var lit := smoothstep(0.0, SHADOW_REACH, float(k) / n.skins.size()) * out
		sp.modulate = Color(SHADOW.lerp(Color.WHITE, lit) * state_tint, fade)
	# The head's own shadow is in its art. Facing us, its clips carry it (`wake`,
	# `recede`); turned aside it wears its shadowed twin, which draws off as it comes out.
	n.head_skin.modulate = Color(state_tint, fade)
	if n.look != 0 and out < 1.0:
		n.shade_skin.visible = true
		n.shade_skin.position = n.head_skin.position
		n.shade_skin.rotation = n.head_skin.rotation
		n.shade_skin.flip_h = n.head_skin.flip_h
		# It blinks while it waits.
		var blink := mode == "hidden" and fmod(_time + i, 4.0) < 0.12
		var twin: Dictionary = n.head_layout["clips"]["shut" if blink else "shadow"]
		_set_cell(n.shade_skin, n.head_layout, int(twin["start"]))
		n.shade_skin.modulate = Color(1, 1, 1, (1.0 - out) * fade)
		if mode == "hidden":
			n.head_skin.visible = false


## The view a head wants to show for what it is doing.
func _want_look(n: Neck, mode: String, breath: String, s: Dictionary) -> int:
	var face: float = s.get("face", 1.0)
	var watch: Vector2 = s.get("watch", Vector2(face, 0.0))
	match mode:
		"limp":
			# It hangs as it died.
			return n.look
		"hidden":
			# In the dark the middle head faces us; the others look out at an angle.
			if n.index == 1:
				n.look_want = 0
			else:
				n.look_want = 1 if (watch.x if watch.x != 0.0 else face) > 0.0 else -1
			return n.look_want
		"tell", "breathe":
			if breath == HydraHead.FOG:
				# The glow in its throat is drawn facing us.
				n.look_want = 0
				return 0
			if breath == HydraHead.PLUME:
				# The plume pours along the floor: strict profile, the way it will roll.
				n.look_want = 2 if face > 0.0 else -2
				return n.look_want
			# The geyser head looks down its aim.
			watch = s.get("aim", watch)
		"rage":
			if n.index == 1:
				n.look_want = 0
				return 0
	# Otherwise it watches: it turns once its mark is well past the view it holds.
	var toward := view_toward(watch)
	if absf(toward - n.look_want) > TURN_SLACK:
		n.look_want = roundi(toward)
	return n.look_want


## How far the head is tilted, nose down (in radians, already mirrored).
func _head_tilt(n: Neck, mode: String, breath: String, aim: Vector2, time: float) -> float:
	var turned := absi(n.look)
	if turned == 0:
		match mode:
			"limp":
				return 0.45
			"weak":
				return 0.18 + sin(_time * 1.5) * 0.03
			"rage":
				return sin(_time * 30.0) * 0.08
		return sin(_time * 0.8) * 0.04
	var side := n.side()
	# The way the art looks with no tilt: due east in profile, down and east at an angle.
	var rest := 0.0 if turned == 2 else 0.88
	var limit := 1.1 if turned == 2 else 0.6
	var to_aim := clampf(wrapf(aim.angle() - (rest if side > 0.0 else PI - rest), -PI, PI), -limit, limit)
	# A three-quarter head nods half as far: it is already looking down.
	var nods := 1.0 if turned == 2 else 0.5
	var nod := 0.0
	match mode:
		"idle", "rise", "emerge", "hidden":
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
	return nod * nods * side


## The head's frame, from the clips of the view it shows.
func _head_frame(n: Neck, mode: String, breath: String, time: float, tell: float) -> void:
	var clip := "idle"
	var f := 0
	var clips: Dictionary = n.head_layout["clips"]
	var turned := absi(n.look)
	if turned == 0:
		match mode:
			"emerge":
				# The shadow draws off it as it comes out.
				clip = "recede"
				f = int(clampf(time / HaarWyrm.EMERGE_TIME, 0.0, 1.0) * (int(clips[clip]["count"]) - 1))
			"tell":
				# The jaws open slowly on the glow in its throat.
				clip = "glow"
				f = int(clampf(time / tell, 0.0, 1.0) * 5.0)
			"breathe":
				# The channel: its jaws stay wide on the pulsing core for as long as it lasts.
				clip = "glow"
				f = CHANNEL[int(time * CHANNEL_FPS) % CHANNEL.size()]
			"sag":
				clip = "roar"
				f = int(time * 7.0) % int(clips[clip]["count"])
			"rage":
				clip = "glow"
				f = int(time * 14.0) % int(clips[clip]["count"])
	else:
		match mode:
			"tell":
				# It draws back: the start of the clip, over the whole wind-up. (The
				# three-quarter clip breathes fire after that, which is not this beast.)
				clip = "pull"
				f = int(clampf(time / tell, 0.0, 1.0) * (8.0 if turned == 2 else 5.0))
			"breathe":
				clip = "open"
			"sag":
				clip = "roar"
				f = _roar_frame(turned, int(time * 7.0), int(clips[clip]["count"]))
			"rage":
				clip = "jaw" if clips.has("jaw") else "roar"
				f = int(time * 16.0) % int(clips[clip]["count"])
				if clip == "roar":
					f = _roar_frame(turned, int(time * 16.0), int(clips[clip]["count"]))
			"limp":
				clip = "roar"
				f = 5
	n.clip = clip
	n.frame = mini(f, int(clips[clip]["count"]) - 1)
	_set_cell(n.head_skin, n.head_layout, int(clips[clip]["start"]) + n.frame)


## The roar's frame at `step`: every frame in profile, the ones that keep their color
## in three-quarter view.
static func _roar_frame(turned: int, step: int, count: int) -> int:
	if turned == 1:
		return ROAR_THREE_QUARTER[step % ROAR_THREE_QUARTER.size()]
	return step % count


## A head that faces us in the reveal: its eyes open, it waits, and it snorts.
func _reveal_frame(n: Neck, intro: float) -> void:
	var clips: Dictionary = n.head_layout["clips"]
	var count := int(clips["wake"]["count"])
	var opened := clampf((intro - float(HaarWyrm.EYES_AT[n.index])) / EYES_OPEN, 0.0, 1.0)
	var snort := (intro - float(HaarWyrm.SNORTS_AT[n.index])) / SNORT
	var f := int(opened * 2.0)
	if snort >= 1.0:
		f = count - 1
	elif snort > 0.0:
		f = 2 + int(snort * (count - 3))
	elif fmod(_time + n.index, 4.0) < 0.12 and opened >= 1.0:
		f = 0
	n.clip = "wake"
	n.frame = clampi(f, 0, count - 1)
	_set_cell(n.head_skin, n.head_layout, int(clips["wake"]["start"]) + n.frame)


## Steam at the jaws, the glow in the geyser's throat and the drips off a doused head.
func _draw_fx() -> void:
	for n in necks:
		if not n.shown or n.told.is_empty():
			continue
		var s := n.told
		var mode: String = s.get("mode", "idle")
		var fade: float = s.get("fade", 1.0)
		if mode == "hidden":
			# The reveal: its eyes burn in the dark, so they read from across the room.
			if fmod(_time + n.index, 4.0) >= 0.12:
				for e: Array in n.head_layout["joints"]["eyes"]:
					var at := n.centre + _from_centre(n, e)
					_fx.draw_rect(Rect2(at - Vector2(4, 2), Vector2(8, 4)), Color(EYE, 0.16 * n.eyes))
					_fx.draw_rect(Rect2(at - Vector2(2, 1), Vector2(4, 2)), Color(EYE, 0.85 * n.eyes))
			continue
		if s.get("dead", false):
			continue
		var jaws := n.centre + head_joint(n, "mouth")
		if s.get("weak", false):
			# Water runs off it.
			for k in 3:
				var drop := fmod(_time * 1.6 + k * 0.37 + n.index * 0.2, 1.0)
				var at := n.centre + Vector2(n.side() * (-8.0 + k * 9.0), 10.0 + drop * 44.0)
				_fx.draw_rect(Rect2(at, Vector2(2, 3)), Color(DRIP, (1.0 - drop) * 0.9 * fade))
			continue
		if mode in ["tell", "breathe"] or mode == "idle" and fmod(_time + n.index * 1.3, 5.0) < 0.5:
			# A snort at rest, pressure before a breath.
			for k in 3:
				var ph := fmod(_time * 1.3 + k * 0.4, 1.0)
				_fx.draw_circle(jaws + Vector2((k - 1) * 2.0, -ph * 28.0), 3.0 + ph * 4.0, Color(STEAM, (1.0 - ph) * 0.55 * fade))
		if mode == "tell" and String(s.get("breath", "")) == HydraHead.GEYSER:
			# The throat glows hotter as the pressure builds.
			var heat := clampf(float(s.get("time", 0.0)) / float(s.get("tell", 1.0)), 0.0, 1.0)
			_fx.draw_circle(jaws, 4.0 + heat * 5.0, Color(STEAM_HOT, (0.35 + 0.5 * heat) * fade))


## Lays neck `n` along a curve from `root` to `tip`: out of the stump along `up`, into
## the skull along `into`, pushed sideways by `push`. `hook` is how far behind the skull
## the curve holds that line before it turns in (a long hook is a curl round the head).
## The curve bends more to take up a neck that is too long and straightens for one that
## is too short; between the two the sections telescope (`n.stack`).
func solve(n: Neck, root: Vector2, tip: Vector2, up: Vector2, into: Vector2, push: Vector2, hook := HOOK) -> void:
	var span := root.distance_to(tip)
	var low := n.total * STACK_MIN
	var high := n.total * STACK_MAX
	var handle := maxf(span * 0.42, 10.0)
	var grip := hook / handle
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

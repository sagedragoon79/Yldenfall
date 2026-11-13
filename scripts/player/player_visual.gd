class_name PlayerVisual
extends Node2D
## The elf's sprite: plays the sheet (tools/art/spritegen.py with the Autosprite
## clips from art/autosprite/, assets/sprites/player.*) and draws the shield,
## and the blade and potion where the frame does not already show them, from
## each frame's hand point. Handles squash and stretch, facing and hurt
## blinking. Origin is at the feet.

const SHEET_NAME := "player"
const SHEET := "res://assets/sprites/player.png"
## The hero's body sets (paper doll, design bible 13.4): one sheet per armor
## worn, from Sean's Autosprite characters. A clip its set does not have yet
## plays from SHEET_NAME.
const ARMOR_SHEETS := {
	"": "hero_base",
	"leather_armor": "hero_leather",
	"riveted_coat": "hero_riveted",
	"full_plate": "hero_plate",
	"elven_plate": "hero_battle",
}
## Armor and helmet worn together that have a body set of their own, drawn with
## the helmet on (Sean's Elven Plate + Elven Helm character): the helmet
## layer is not drawn over it.
const HELMED_SHEETS := {"elven_plate": "hero_battle_helm"}
## Swords are drawn into the attack clips (design bible 13.5): each body set has
## its attacks again with every blade but the Short Sword, as the sheet
## "<set>_<suffix>" (hero_plate_long_sword). The Short Sword is the set's own.
const BLADE_SHEETS := {"long_sword": "long_sword", "dwarvish_broad_sword": "broad_sword", "severance": "severance"}
## The clips a blade sheet holds: the attacks and the Rune Dagger flicked from the left
## hand (its idle is only the importer's reference for scale).
const BLADE_CLIPS := ["slash1", "slash2", "slash3", "slash_up", "throw", "throw_up"]
## Shields are drawn into the block pose the same way: "<set>_<shield>" holds the
## set's block with that shield up (hero_plate_large_shield). Without one the
## code-drawn shield is held over the clip.
const SHIELD_SHEETS := ["small_shield", "large_shield", "magic_shield"]

const OUTLINE := Color("120f19")
const STEEL := Color("cec5d3")
const STEEL_EDGE := Color("ece8ed")
const STEEL_DARK := Color("867ba2")
const HILT := Color("cb8d16")
const SHIELD := Color("aa6336")
const SHIELD_BOSS := Color("cec5d3")
const POTION := Color("c02a20")
const GLASS := Color("e68c75")
const OINTMENT := Color("f0c02e")
const POISON := Color("8fd14f")
## The Elven Helm layer: the helm of the PixelLab helmed elf (tools/art/helmetgen.py), drawn
## at the sheets' 2x density with its top-left this far from the frame's crown.
const HELMET := preload("res://assets/sprites/elven_helm.png")
const HELMET_OFFSET := Vector2(-5.5, -4)
## In a body set's run the head leans into the stride, so the helmet tips
## forward with it (radians) and sits this far from the crown instead; upright,
## the leaning hair would show over the visor.
const HELMET_RUN_TILT := 0.26
const HELMET_RUN_OFFSET := Vector2(-4.5, -5.5)
## Blade length in pixels before the weapon's reach bonus.
const BLADE_LENGTH := 11.0
## Animations that hold on until they finish even when the action behind them
## ends (the recovery frames of a swing). A pogo's strike ends the moment it
## lands, so the Delver's Pick's blow plays out over the bounce.
const FINISH := ["slash1", "slash2", "slash3", "slash_up", "strike_down", "cast", "throw", "throw_up", "crouch_slash"]
## The frame of each swing clip where the blade travels (every hero sheet draws
## its own blur of the blade there); the frames before it are the windup, with
## the sword still raised or drawn back. The smear waits for it (pass 537).
const STRIKE_FRAME := {"slash1": 1, "slash2": 1, "slash3": 2, "slash_up": 1}
## Poses an unfinished swing may play over.
## The speed share (MovementTuning.speed_fraction) at or under which moving is a walk.
const WALK_POSE := 0.7
const OVERRIDABLE := ["idle", "walk", "run", "rise", "apex", "fall", "crouch"]
## The crouch's own clips (bible 6.15): the held pose and its low cut. Until a
## set has them, the crouch plays its idle (and the low cut its first slash)
## drawn CROUCH_SHAPE squat, the placeholder until the 128 px hero's art.
const CROUCH_CLIPS := ["crouch", "crouch_slash"]
const CROUCH_SHAPE := Vector2(1.08, 0.66)
## How fast the body sinks into the crouch and rises out of it, per second.
const CROUCH_EASE := 30.0

const DYE_SHADER := preload("res://shaders/cloak_dye.gdshader")
## The PixelLab sets draw the cloak in a key green and keep the purple hair; this
## recolors both (manifest flag "key_cloak", design bible 13.5).
const KEY_SHADER := preload("res://shaders/hero_dye.gdshader")
## Warden Green on a key-green cloak: the lit tone of the code cloak's GREEN.
const WARDEN_KEY := Color("4f8a4c")
## Hair colors, chosen on the Equipment page: id -> [name, lit tone]. Violet is
## the art's own purple, left as drawn.
const HAIR := {
	"violet": ["Violet", ""],
	"copper": ["Copper", "c8743c"],
	"raven": ["Raven", "4a4458"],
	"silver": ["Silver", "dcd8e8"],
	"gold": ["Gold", "e8c460"],
	"ash": ["Ash", "a49c98"],
}

## "anim:frame" holds the player in one frame (screenshots: --shot-pose).
static var forced := ""
## Off, the ranger's sheet plays everything (tests of the cloak it wears).
static var body_sets := true

var player: Player
## Squash and stretch (design bible 6.7, pass 360): the shape each move sets
## the sprite to (x across, y up), before it eases back. A landing's is the
## hardest one, for a fall at full speed; a slower fall squashes less.
const SQUASH := {
	"jump": Vector2(0.85, 1.2), "double_jump": Vector2(0.8, 1.25), "wall_jump": Vector2(1.15, 0.9),
	"land": Vector2(1.25, 0.8), "dash": Vector2(1.3, 0.8), "pogo": Vector2(0.8, 1.2), "pod": Vector2(0.75, 1.25),
	"glide": Vector2(1.2, 0.88), "stroke": Vector2(1.1, 0.9), "heavy": Vector2(1.2, 0.9), "thrust": Vector2(1.3, 0.85),
	"throw": Vector2(1.06, 0.97), "cast": Vector2(1.1, 0.95), "parry": Vector2(1.15, 0.9),
	"crouch": Vector2(1.12, 0.88),
}
## How fast a squash eases back to the sprite's own shape, per second
## (1 - e^(-16t): over half of it in 3 frames, nearly all in 0.2 s).
const SQUASH_RECOVERY := 16.0
var squash_scale := Vector2.ONE
## The placeholder crouch's squat (CROUCH_SHAPE), eased in and out.
var crouch_scale := Vector2.ONE
var pose := "idle"
## The animation playing, its time and the frame shown.
var anim := "idle"
var anim_time := 0.0
var frame := 0
## The sheet `anim` plays from (the worn armor's set, or SHEET_NAME).
var sheet := SHEET_NAME

var _dye_worn := ""
var _blink_time := 0.0
var _red_time := 0.0
## The level-up glow (design bible 5.6): how long is left of LEVEL_GLOW.
const LEVEL_GLOW := 0.7
var _level_time := 0.0
var _swings := 0
var _throws := 0


## The sheet: {"cell", "origin", "columns", "animations", ...} (see Sheet).
static func data() -> Dictionary:
	return Sheet.get_sheet(SHEET_NAME)


func squash(amount: Vector2) -> void:
	squash_scale = amount


## Sets one of the named shapes (SQUASH), `strength` of the way from the
## sprite's own shape (a landing scales it by the fall).
func squash_for(move: String, strength := 1.0) -> void:
	squash(Vector2.ONE.lerp(SQUASH[move], clampf(strength, 0.0, 1.0)))


## The level-up's chromatic glow: red and cyan ghosts split from the hero and
## close back in, under a pale gold cast.
func flash_level_up() -> void:
	_level_time = LEVEL_GLOW


func level_glowing() -> bool:
	return _level_time > 0.0


func flash_hurt() -> void:
	_blink_time = player.hurt_invuln()
	_red_time = 0.12


func _physics_process(delta: float) -> void:
	squash_scale = squash_scale.lerp(Vector2.ONE, 1.0 - exp(-delta * SQUASH_RECOVERY))
	crouch_scale = crouch_scale.lerp(crouch_goal(), 1.0 - exp(-delta * CROUCH_EASE))
	var shape := shape_scale()
	scale = Vector2(look_dir(player) * shape.x, shape.y)
	_blink_time -= delta
	_red_time -= delta
	_level_time -= delta
	visible = player.dead or not (_blink_time > 0.0 and _red_time <= 0.0 and int(_blink_time * 20.0) % 2 == 0)
	pose = current_pose(player)
	var next := anim_for(player, pose)
	var restart := player.swing_count != _swings
	_swings = player.swing_count
	if player.throws != _throws:
		# A Rune Dagger thrown (design bible 13.5): the flick plays out over the
		# legs' poses, forward or up as the dagger went, where the set has it.
		_throws = player.throws
		var up := is_instance_valid(player.rune_dagger) and player.rune_dagger.dir.y < 0.0
		var flick := "throw_up" if up else "throw"
		if pose in OVERRIDABLE and Sheet.has_anim(sheet_for(flick), flick):
			next = flick
			restart = true
	if anim in FINISH and not finished() and pose in OVERRIDABLE and not restart:
		next = anim
	if next != anim or restart:
		anim = next
		anim_time = 0.0
	var rate := 1.0
	if anim == "run":
		rate = clampf(absf(player.velocity.x) / player.tuning.run_speed, 0.4, 1.3)
	elif anim == "walk":
		rate = clampf(absf(player.velocity.x) / (player.tuning.run_speed * player.tuning.walk_fraction), 0.6, 1.6)
	elif pose == "climb":
		# The reach cycles only while you climb; holding still, you hang.
		rate = 1.6 if player.velocity.y != 0.0 else 0.0
	anim_time += delta * rate
	sheet = sheet_for(anim)
	frame = Sheet.frame_at(sheet, anim, anim_time)
	if forced != "":
		var parts := forced.split(":")
		anim = parts[0]
		sheet = sheet_for(anim)
		frame = int(parts[1]) if parts.size() > 1 else 0
	queue_redraw()


static func current_pose(p: Player) -> String:
	if p.dead:
		return "death"
	if p.is_hurt:
		return "hurt"
	if p.on_ladder:
		return "climb"
	if p.is_dashing:
		return "dash"
	if p.is_wall_sliding:
		return "wall"
	if p.is_attacking:
		return "attack_" + p.attack_kind
	if p.is_drinking:
		return "drink"
	if p.is_blocking:
		return "block"
	if p.is_casting:
		return "cast"
	if p.crouching:
		return "crouch"
	if p.is_gliding:
		# Feather Fall: the cloak-spread hang of the apex, held.
		return "apex"
	if not p.is_on_floor():
		if absf(p.velocity.y) < 60.0:
			return "apex"
		return "rise" if p.velocity.y < 0.0 else "fall"
	if absf(p.velocity.x) > 10.0:
		# A light lean on the stick walks (pass 183).
		if p.input.move_x != 0 and p.tuning.speed_fraction(p.input.tilt) <= WALK_POSE:
			return "walk"
		return "run"
	return "idle"


## The sheet animation for a pose.
static func anim_for(p: Player, body_pose: String) -> String:
	match body_pose:
		"attack_side":
			if p.is_heavy_swing:
				return "slash3"
			return "slash2" if p.combo_index == 2 else "slash1"
		"attack_thrust":
			# The point driven out: the opening cut's reach, held.
			return "slash1"
		"attack_up":
			return "slash_up"
		"attack_low":
			return "crouch_slash" if Sheet.has_anim(sheet_for("crouch_slash"), "crouch_slash") else "slash1"
		"crouch":
			return "crouch" if Sheet.has_anim(sheet_for("crouch"), "crouch") else "idle"
		"attack_down":
			return "strike_down"
		"climb":
			# Reaching up a ladder: the wall pose's reach, turned to the rungs.
			return "wall"
		"walk":
			# Until the sheet has a walk clip, the run plays slowed to the pace.
			return "walk" if Sheet.has_anim(sheet_for("walk"), "walk") else "run"
	return body_pose


## The worn armor's body sheet, or "" when there is none for it.
static func armor_sheet() -> String:
	if not body_sets:
		return ""
	var worn := String(GameState.data.equipment.get("armor", ""))
	var name: String = ARMOR_SHEETS.get(worn, "")
	var helmed: String = HELMED_SHEETS.get(worn, "")
	if helmed != "" and String(GameState.data.equipment.get("helmet", "")) == "elven_helm" and Sheet.exists(helmed):
		return helmed
	return name if name != "" and Sheet.exists(name) else ""


## The sheet that plays `name`: the worn armor's set if it has the clip, and
## for an attack, the set's clips with the worn blade if it has them.
static func sheet_for(name: String) -> String:
	var body := armor_sheet()
	if body == "":
		return SHEET_NAME
	var blade: String = BLADE_SHEETS.get(String(GameState.data.equipment.get("blade", "")), "")
	if blade != "" and name in BLADE_CLIPS:
		var held := body + "_" + blade
		if Sheet.exists(held) and Sheet.has_anim(held, name):
			return held
	var shield := String(GameState.data.equipment.get("shield", ""))
	if name == "block" and shield in SHIELD_SHEETS:
		var guard := body + "_" + shield
		if Sheet.exists(guard) and Sheet.has_anim(guard, name):
			return guard
	return body if Sheet.has_anim(body, name) else SHEET_NAME


## Where a swing's blade travels in the sheet that plays `name`: [the sequence step
## of its strike frame (STRIKE_FRAME), the clip's fps]; [0, 0.0] with no windup.
static func strike_step(name: String) -> Array:
	if not STRIKE_FRAME.has(name):
		return [0, 0.0]
	var held := sheet_for(name)
	if not Sheet.has_anim(held, name):
		return [0, 0.0]
	var a: Dictionary = Sheet.get_sheet(held).animations[name]
	var seq: Array = a.seq
	for i in seq.size():
		if int(seq[i]) >= int(STRIKE_FRAME[name]):
			return [i, float(a.fps)]
	return [0, 0.0]


## Seconds from a swing's start to its strike frame; 0 for a clip with no windup.
static func strike_time(name: String) -> float:
	var s := strike_step(name)
	return 0.0 if s[1] == 0.0 else s[0] / s[1]


## The frame of `name` shown at time `t`.
static func frame_at(name: String, t: float) -> int:
	return Sheet.frame_at(SHEET_NAME, name, t)


## The sprite's shape now: the move's squash times the crouch's squat.
func shape_scale() -> Vector2:
	return squash_scale * crouch_scale


## The squat the sprite eases toward: CROUCH_SHAPE while crouched on a clip
## not drawn crouching (the placeholder), else its own shape.
func crouch_goal() -> Vector2:
	if player.crouching and not anim in CROUCH_CLIPS:
		return CROUCH_SHAPE
	return Vector2.ONE


func finished() -> bool:
	return Sheet.finished(sheet, anim, anim_time)


## Which way the sprite is drawn. A wall slide is drawn gripping the wall (the
## sheet's pose reaches forward with a foot on it), while `facing` points away
## from the wall so a wall jump or a swing still goes outward (playtest).
static func look_dir(p: Player) -> int:
	return p.wall_dir if p.is_wall_sliding and p.wall_dir != 0 else p.facing


## The current frame's metadata: hand and neck points (relative to the feet,
## facing right) and, in a swing, the blade angle.
func frame_info() -> Dictionary:
	return Sheet.info(sheet, anim, frame)


## The neck in world space, where the scarf hangs from.
func neck_position() -> Vector2:
	var n: Array = frame_info().neck
	return point(Vector2(n[0], n[1]))


## A frame point (relative to the feet, facing right) in world space.
func point(p: Vector2) -> Vector2:
	var shape := shape_scale()
	return global_position + Vector2(p.x * look_dir(player) * shape.x, p.y * shape.y)


## Draws one frame of the sheet (or its flat silhouette, tinted) with the feet at the origin.
static func draw_frame(ci: CanvasItem, name: String, f: int, tint: Color, flat: bool) -> void:
	Sheet.draw(ci, SHEET_NAME, name, f, tint, flat)


## The cloak dye worn (pass 136): [lit color, glows]. Warden Green, the
## sheet's own cloak, returns an empty array: nothing to recolor.
static func dye_look() -> Array:
	var item := GameData.item(GameState.dye())
	if String(item.get("color", "")) == "":
		return []
	return [Color(String(item.color)), bool(item.get("glow", false))]


## The hair color chosen (an id of HAIR): [lit color], or empty for the art's own violet.
static func hair_look() -> Array:
	var tone := String(HAIR.get(GameState.hair(), ["", ""])[1])
	return [] if tone == "" else [Color(tone)]


## Puts the worn dye's shader on the sprite when the dye, the hair or the sheet
## changes. A key-green set always has it (Warden Green is a dye like any other
## there); the ranger's sheet only for a dye that is not its own green. The other
## body sets' greens are a tunic and elven steel, so they are drawn undyed.
func _sync_dye() -> void:
	var keyed: bool = sheet != SHEET_NAME and Sheet.flag(sheet, "key_cloak", false)
	var worn := GameState.dye() if sheet == SHEET_NAME or keyed else ""
	var state := "%s|%s|%s" % [worn, GameState.hair() if keyed else "", keyed]
	if state == _dye_worn:
		return
	_dye_worn = state
	var look := dye_look() if worn != "" else []
	if keyed:
		var mat := ShaderMaterial.new()
		mat.shader = KEY_SHADER
		mat.set_shader_parameter("dye", WARDEN_KEY if look.is_empty() else look[0])
		mat.set_shader_parameter("glow", false if look.is_empty() else look[1])
		var hair: Array = hair_look() if Sheet.flag(sheet, "hair", true) else []
		mat.set_shader_parameter("hair_on", not hair.is_empty())
		if not hair.is_empty():
			mat.set_shader_parameter("hair", hair[0])
		material = mat
		return
	if look.is_empty():
		material = null
		return
	var mat := ShaderMaterial.new()
	mat.shader = DYE_SHADER
	mat.set_shader_parameter("dye", look[0])
	mat.set_shader_parameter("glow", look[1])
	material = mat


func _draw() -> void:
	_sync_dye()
	var tint := Color(1.0, 0.45, 0.45) if _red_time > 0.0 else Color.WHITE
	var ill := player.shown_condition()
	if ill != "" and _red_time <= 0.0:
		# A condition lays its own cast over the hero (poison's sickly green,
		# burn's orange, chill's pale blue, a curse's violet), throbbing.
		var t := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		tint = Color.WHITE.lerp(POISON if ill == Condition.POISON else Condition.COLORS[ill], 0.35 + 0.2 * t)
	if _level_time > 0.0:
		# The split is widest at the start and closes as the glow fades.
		var k := clampf(_level_time / LEVEL_GLOW, 0.0, 1.0)
		var split := roundf(1.0 + 4.0 * k)
		draw_set_transform(Vector2(-split, 0.0))
		Sheet.draw(self, sheet, anim, frame, Color(1.0, 0.25, 0.3, 0.55 * k), false)
		draw_set_transform(Vector2(split, 0.0))
		Sheet.draw(self, sheet, anim, frame, Color(0.25, 0.95, 1.0, 0.55 * k), false)
		draw_set_transform(Vector2.ZERO)
		tint = tint.lerp(Color(1.6, 1.5, 1.1), 0.7 * k)
	Sheet.draw(self, sheet, anim, frame, tint, false)
	var oint := player.ointment_left
	if oint > 0.0:
		# The Barkbalm: a gold sheen that pulses, and flickers as it runs out.
		var a := 0.38 + 0.14 * sin(Time.get_ticks_msec() * 0.008)
		if oint < 2.0 and int(oint * 8.0) % 2 == 0:
			a *= 0.3
		Sheet.draw(self, sheet, anim, frame, Color(OINTMENT, a), true)
	var info := frame_info()
	if player.cloak and player.cloak.shown():
		player.cloak.draw_hood(self, info, tint)
	var hand := Vector2(info.hand[0], info.hand[1])
	if String(GameState.data.equipment.get("helmet", "")) == "elven_helm" and not sheet in HELMED_SHEETS.values():
		# Its own layer over the head (paper-doll): the hero's sheet is bare-headed.
		var crown: Array = info.get("head", [info.neck[0], info.neck[1] - 16])
		_draw_helmet(Vector2(crown[0], crown[1]), tint)
	if info.has("blade"):
		_draw_blade(hand, deg_to_rad(float(info.blade)), BLADE_LENGTH + player.reach_bonus * 0.75, tint)
	if anim == "block" and not shield_drawn():
		_draw_shield(hand + Vector2(2, 0), tint)
	elif anim == "drink" and not info.get("art_prop", false):
		draw_rect(Rect2(hand + Vector2(-2, -6), Vector2(4, 6)), OUTLINE)
		draw_rect(Rect2(hand + Vector2(-1, -5), Vector2(2, 4)), POTION * tint)
		draw_rect(Rect2(hand + Vector2(-1, -5), Vector2(1, 1)), GLASS * tint)


func _draw_blade(hand: Vector2, angle: float, length: float, tint: Color) -> void:
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal()
	var base := hand + dir * 2.0
	var tip := base + dir * length
	# A broad blade (the Dwarvish Broad Sword's arc) is drawn two pixels thicker.
	var broad := 2.0 if player.arc_bonus > 0.0 else 0.0
	# Outline, steel with a bright edge, then the crossguard and pommel.
	draw_line(base, tip + dir, OUTLINE, 4.0 + broad)
	draw_line(base, tip, STEEL * tint, 2.0 + broad)
	draw_line(base + side * 0.5, tip + side * 0.5, STEEL_EDGE * tint, 1.0)
	draw_line(base - side * 0.5 + dir * 2.0, tip - side * 0.5 - dir, STEEL_DARK * tint, 1.0)
	draw_line(base - side * (3.0 + broad), base + side * (3.0 + broad), OUTLINE, 3.0)
	draw_line(base - side * 2.0, base + side * 2.0, HILT * tint, 1.0)
	draw_rect(Rect2((hand - dir * 2.0).round() - Vector2(1, 1), Vector2(2, 2)), HILT * tint)


## The Elven Helm, facing +x (the node's scale mirrors it), its dome on
## `crown` (the top of the head, found in the sheet's pixels by
## autosprite_import.head_point).
func _draw_helmet(crown: Vector2, tint: Color) -> void:
	var run := anim == "run" and sheet != SHEET_NAME
	draw_set_transform(crown, HELMET_RUN_TILT if run else 0.0)
	var at := HELMET_RUN_OFFSET if run else HELMET_OFFSET
	draw_texture_rect(HELMET, Rect2(at, HELMET.get_size() * 0.5), false, tint)
	draw_set_transform(Vector2.ZERO)


## Whether the playing sheet's art holds the shield (a "<set>_<shield>" sheet).
func shield_drawn() -> bool:
	return SHIELD_SHEETS.any(func(h: String) -> bool: return sheet.ends_with("_" + h))


func _draw_shield(at: Vector2, tint: Color) -> void:
	var r := Rect2(at + Vector2(-2, -7), Vector2(6, 14))
	draw_rect(r.grow(1.0), OUTLINE)
	draw_rect(r, SHIELD * tint)
	draw_rect(Rect2(r.position + Vector2(1, 0), Vector2(1, r.size.y)), Color(SHIELD.lightened(0.25), 1.0) * tint)
	draw_rect(Rect2(r.position + Vector2(2, 5), Vector2(2, 4)), SHIELD_BOSS * tint)

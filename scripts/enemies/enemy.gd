class_name Enemy
extends CharacterBody2D
## Base for all enemies: health, hit reactions, stagger, telegraphs, death,
## gold drops and optional respawning. Subclasses implement `_think()` and `_draw()`.
## The node origin is at the enemy's feet (or center, for fliers).

signal died(enemy: Enemy)

const GRAVITY := 1200.0
const MAX_FALL := 500.0
## How far below its room's floor line a falling foe goes before it is lost (px).
const FALL_MARGIN := 24.0
## Wind-ups shorter than this are unfair (design bible section 7).
const MIN_TELEGRAPH := 0.35
## How far above the hero's feet a head-height blow is aimed (bible 6.15): inside
## a standing body (40 px), over a crouched one (26 px), so a crouch ducks it.
const HEAD_HEIGHT := 36.0
## How long a body takes to break up after its death.
const DISSOLVE := 0.45
const DISSOLVE_SHADER := preload("res://shaders/dissolve.gdshader")
const WASH_SHADER := preload("res://shaders/wash.gdshader")
## How white a foe is drawn (bible 6.7): `FLASH_WASH` on the frame a blow lands
## and through every tell's pulse, `FLASH_SOFT_WASH` for the rest of a hit flash,
## pale enough that the foe's inner lines still read. The two `SHEET_` values are
## the same pair for a foe drawn from a sheet (the alpha of its white overlay).
const FLASH_WASH := 0.72
## Since pass 607 the soft phase is lighter and warm: the pass 605 grade still read the
## struck foe as "a see-through ghost", because 40 to 45 percent of white over a dark
## foe made a flat lavender-grey near the backdrop's own hue. At 0.3 of a warm cream
## (`SOFT_TINT`) the foe keeps most of its colors and reads lit by the blow.
const FLASH_SOFT_WASH := 0.3
const SOFT_TINT := Color(1.0, 0.92, 0.76)
## The recoil (bible 6.7, pass 592): through its hitstun a foe drawn from a sheet
## leans away from the blow, its head thrown back along the push (`RECOIL_LEAN`, a
## shear: world pixels across per pixel up) and squashed wide (`RECOIL_SQUASH`),
## easing upright as the hitstun runs out. The knockback alone moved the whole
## body a few pixels, so a struck foe stood still in the hit frame.
const RECOIL_LEAN := 0.3
const RECOIL_SQUASH := 0.1
const SHEET_WHITE := 0.85
## Since pass 646 a sheet foe's soft phase is lighter still (0.3 before): the pass 645
## grade called the fight's contact points "mush", and the struck foe under a cream
## tint was a muddy, low-contrast shape. The blow now shows as a lit edge instead.
const SHEET_SOFT_WHITE := 0.15
## The struck edge (bible 6.7, pass 646): through a hit flash a sheet foe wears a
## crescent of warm white `STRUCK_EDGE_WIDTH` world pixels wide inside its outline,
## on the side the blow came from, the cut's light on its body, while the rest of it
## keeps its own colors and the dark rim parts it from the swing's white arc.
const STRUCK_EDGE := Color(1.0, 0.96, 0.86)
const STRUCK_EDGE_WIDTH := 1.0
## A tell's pulse (bible 6.7, passes 585 and 586) is a warm tint and a rim, never
## a white cutout. A foe drawn from a sheet wears a rim of `TELL_TINT` one pixel
## wide (`TELL_RIM`), which carries the warning, and only a light tint over its body
## (`SHEET_TELL`), so its own colors and the pose that warns of the blow read
## through. A code-drawn foe or guardian has no rim, so its body is mixed toward the
## tint by `TELL_WASH`, still less than half. White stays the color of a blow that landed.
const TELL_TINT := Color(1.0, 0.82, 0.38)
const TELL_WASH := 0.45
const SHEET_TELL := 0.2
const TELL_RIM := 0.9
const RIM_STEPS: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
## A struck foe keeps its edge (bible 6.7, pass 602): a hit flash's white overlay
## also washed out a sheet foe's own dark outline, so its pale body melted into the
## white sword, the arc and a pale sky, and the pass 600 grade read it as going
## see-through. Through the flash a sheet foe wears a dark rim one pixel wide, in the
## outline's near-black, as a tell wears its warm one.
const HIT_RIM_COLOR := Color("120c16")
const HIT_RIM := 0.95
## A blow knocks chips off the foe (bible 6.7, pass 621), in tones read off its sheet:
## colors darker than `CHIP_DARK` are outline and deep shade and are passed over, and
## the lighter tone is looked for among the `CHIP_TOP` commonest.
const CHIP_DARK := 0.3
const CHIP_TOP := 6
static var _chip_colors := {}
## A tell gathers on the weapon (bible 12.88, pass 611). The pass 610 grade read the
## rim and tint over a whole foe as "a flat yellow full-body tint, a debug overlay".
## A foe drawn from a sheet with a point in `TELL_POINTS` keeps its body in its own
## colors through a wind-up. A four-point glint sits on the weapon instead and grows
## from `GLINT_MIN` to `GLINT_MAX` (the length of an arm, world pixels) over
## `GLINT_GATHER` seconds, `GLINT_PULSE` longer on the pulse's lit beats. On those
## beats the rim is drawn only near the weapon: once inside each square of
## `TELL_REACH` (half its side, world pixels) at `TELL_REACH_RIM`, so it is nearly
## solid at the weapon and gone a foe's shoulder away. A small foe's squares shrink
## with its cell (`TELL_REACH_CELL`: the cell's shorter side, world pixels, at which
## they are full size), so the rim never closes around a whole body.
const GLINT_MIN := 2.5
const GLINT_MAX := 7.0
const GLINT_PULSE := 1.5
const GLINT_GATHER := 0.35
const GLINT_CORE := Color(1.0, 0.97, 0.86)
const TELL_REACH: Array[float] = [5.0, 8.0, 12.0]
const TELL_REACH_CELL := 56.0
const TELL_REACH_RIM := 0.45
## A tell is keyed off what stands behind it (bible 12.151, pass 674). The pass 670
## grade read tells "drawn in the background's values": the Rot Dwarf's gold rim and
## glint over the Heartwood gate's tan planks, the same hue and value. Outside the
## warm rim, near the weapon, runs a keyline of near-black (`TELL_KEY`) one more pixel
## out (`TELL_KEY_STEP`), at `TELL_KEY_RIM` in each square, and the glint sits on a
## dark backing `GLINT_KEY` (half pixels) wider than its arms, so the warning has a
## value break on a light ground as well as a dark one.
const TELL_KEY := Color("120c16")
## A foe that carries its own light is keyed off it (bible 12.154, pass 677). The pass
## 675 grade read the Crystal Dwarf as "lost in pink glow and the water band": his
## steel, lifted by `FoeLight`, was the glow's own middle value, and nothing closed
## his shape. A foe with a `FoeGlow` (`light_keyed`, set by the glow) wears a keyline
## of near-black (`TELL_KEY`) round its whole silhouette, `LIGHT_KEY_STEPS` px wide,
## at `LIGHT_KEY_RIM`, drawn first, so the glow lies behind a dark edge and the body
## stands in front of it as the silhouette 12.52 meant.
const LIGHT_KEY_STEPS := 2
const LIGHT_KEY_RIM := 0.95
## Every sheet foe is keyed off its ground (bible 12.155, pass 678). The pass 675 grade
## read the canopy bridge's mantis and Bark Knight "on the green": a lime body and an
## olive one at the canopy air's own value, and neither sheet closes its shape in a
## dark line. Every sheet foe now wears the same near-black keyline, `FOE_KEY_STEPS`
## px wide, round its whole silhouette (a foe with its own light keeps its wider one),
## so a foe has a value break on a light ground as well as a dark one, and the cast,
## drawn by several hands, shares one edge.
const FOE_KEY_STEPS := 1
const TELL_KEY_RIM := 0.5
const TELL_KEY_STEP := 2.0
const GLINT_KEY := 2.0
## A wind-up shows on the body (bible 12.109, pass 633). The pass 630 grade read the
## glint alone as "a few-pixel sparkle with no pose or color change". Through a
## wind-up with a point, a sheet foe **rears**: it leans back from the way it faces
## (`REAR_LEAN`, a shear: world pixels its head moves per pixel up) and stretches
## tall and narrow (`REAR_STRETCH`), eased in over `REAR_TIME` seconds, and snaps
## upright as the blow goes. And the weapon's **light** falls on it: its silhouette
## in `TELL_TINT`, once inside each square of `LIGHT_REACH` (half its side, world
## pixels, scaled to the cell like the rim) at `LIGHT_STEP`, so it is warm at the
## weapon and gone in its own colors by the far side of the body. The light gathers
## with the glint and does not pulse: a tint that blinks over a whole foe is the
## overlay pass 611 took off.
const REAR_LEAN := 0.16
const REAR_STRETCH := 0.09
const REAR_TIME := 0.16
const LIGHT_REACH: Array[float] = [5.0, 8.0, 11.0, 14.0, 17.0, 20.0, 23.0]
const LIGHT_STEP := 0.05
## Where the glint sits: per sheet and wind-up animation, the striking end of the
## weapon (or the horn, the jaws, the fist) in the cell's own pixels, placed by eye
## on the frame. A list is a point per frame, for a wind-up whose weapon travels.
## A sheet or animation with no point keeps the whole rim and the tint.
const TELL_POINTS := {
	"bark_knight": {"brace": Vector2(102, 82), "bare_brace": Vector2(114, 80)},
	"blinkhop": {"windup": Vector2(57, 26)},
	"bog_puffcap": {"windup": Vector2(40, 49)},
	"clockwork_hound": {"wind": Vector2(90, 60)},
	"crystal_dwarf": {"windup": Vector2(82, 44)},
	"drowned_dwarf": {"heave": Vector2(84, 66)},
	"gear_bat": {"windup": Vector2(79, 44)},
	"hornet": {"windup": Vector2(50, 48)},
	"iron_dwarf": {"windup": Vector2(50, 50)},
	"leaf_mantis": {"unfold": [Vector2(116, 66), Vector2(115, 56), Vector2(109, 44), Vector2(109, 44)]},
	"marsh_hag": {"hex": Vector2(64, 34)},
	"meteor_slug": {"swell": Vector2(58, 40)},
	"minecart_rider": {"rev": Vector2(92, 94)},
	"mothling": {"windup": Vector2(50, 36)},
	"rot_dwarf": {"windup": Vector2(38, 22)},
	"sap_spitter": {"windup": Vector2(37, 30)},
	"seed_bomber": {"windup": Vector2(62, 60)},
	"shade_knight": {"thrust_tell": Vector2(66, 92), "cut_tell": Vector2(38, 30)},
	"silt_adder": {"coil": Vector2(72, 44)},
	"spire_sentinel": {"raise": [Vector2(89, 49), Vector2(70, 48), Vector2(67, 48), Vector2(67, 48)]},
	"storm_harpy": {"windup": Vector2(84, 36)},
	"thunder_beetle": {"charge": Vector2(98, 44)},
}

@export var max_hp := 24
@export var contact_damage := 20
@export var gold_min := 2
@export var gold_max := 5
## Experience for the kill (ranks, design bible 9).
@export var xp := 5
## Seconds until the enemy returns at its spawn point; 0 = gone for good.
@export var respawn_time := 0.0
## May this enemy leave poison (Drop.poison_chance)? The Tower and beyond.
@export var poison_drops := false
## A drop this foe always leaves instead of rolling for one (Drop kinds; the
## Silt Adder's great loaf, pass 281). Empty: it rolls, as every foe did.
@export var sure_drop := ""
## Grown through with stillglass (the Evercrown, design bible 8.9): tougher, richer,
## and it leaves a MeteorSeed that bursts where it dies. Set before it enters the tree.
@export var corrupted := false

## What corruption does to a foe's health, gold and experience.
const CORRUPT_HP := 1.5
const CORRUPT_GOLD := 2
const CORRUPT_XP := 2

var hp := 0
var dead := false
var facing := -1
var state := "idle"
var state_time := 0.0
## Seconds of game time this foe has lived: it slows with the Game speed option
## and stands still through hitstop (pass 474). Idle sways that move a hurtbox
## read it, never the wall clock.
var game_time := 0.0
var home := Vector2.ZERO
var body_size := Vector2(18, 18)
var body_centered := false
var uses_gravity := true
## Rising Cut launches: how hard, how long it hangs helpless, how big a foe it lifts.
## How long a hit stops a foe's thinking; the heavy finisher's lasts 1.8x (0.32 s).
const HITSTUN := 0.18
## A slow (Lithic Fracture, design bible 4, pass 497): while it holds, a foe's own
## clock, its thinking and its movement all run at SLOW_FACTOR of real time for
## SLOW_TIME seconds. It only ever lengthens a telegraph, never shortens one, so no
## tell can drop below MIN_TELEGRAPH. Bosses take it too.
const SLOW_FACTOR := 0.5
const SLOW_TIME := 3.0
const LAUNCH_SPEED := 330.0
const LAUNCH_STUN := 0.5
const LAUNCH_MAX_HP := 40
## False for foes rooted in place (Sap Spitter): Rising Cut can't lift them.
var launchable := true
## A lesser ghost or undead (design bible 5.6): the Hollowmist Cloak hides you
## from it until you strike it.
var undead := false
var _provoked := false
var knockback := 140.0
var hits_taken := 0
## True once it has gone down with its master (`perish`), not to a blow.
var perished := false
## True once it has fallen out of its room (`_fall_out_of_room`, pass 298).
var fell := false
## True while a thrown blade's hit lands (`take_throw`, pass 188): a sting, not
## a blow, so it chips no bark, breaks no hex and never reaches the Heart.
var thrown := false

var _flash := 0.0
## The struck foe reads through the cut (bible 6.7, pass 599): for STRUCK_TIME
## after a blow lands (or a parry staggers it), a foe draws at STRUCK_Z, above the
## swing's smear (SlashFx, z 2) and the hero, under the spark (z 4), so its flash
## and recoil show whole and the smear shows only either side of it. Its own z
## comes back after. Counted on the game clock, so the hit-stop holds it.
const STRUCK_Z := 3
const STRUCK_TIME := 0.2
var _struck_for := 0.0
var _struck_raised := false
var _rest_z := 0
var _hitstun := 0.0
## The hitstun the last blow set, and the way it pushed (1 right, -1 left).
var _hitstun_full := 0.0
var _blow_side := 1.0
## The shear the last sheet frame was drawn with (`recoil_lean` as drawn).
var _lean_drawn := 0.0
var _stagger := 0.0
var _slow := 0.0
var _respawn_timer := 0.0
var _dissolver: Tween
static var _wash_material: ShaderMaterial
static var _soft_wash_material: ShaderMaterial
static var _tell_wash_material: ShaderMaterial
## The hit flash as it was last drawn, and the frame its white pop was drawn on
## (`_flash_is_soft`).
var _flash_drawn := 0.0
var _flash_pop_frame := -1
## Whether this foe last drew itself white without the wash: `draw_sheet` in
## white, or a foe's own white overlay (`drawn_white`).
var _sheet_white := false
var _sheet_white_alpha := 0.0
## Whether this foe's last drawing wore the tell's tint (and not a blow's white).
var _tell_drawn := false
## Whether this foe's last sheet drawing wore the dark rim of a hit flash (pass 602).
var _hit_rim_drawn := false
## The side of this foe's last sheet drawing that wore the struck edge: -1 left, 1 right, 0 none.
var _struck_edge_drawn := 0
## The arm of the glint this foe's last sheet drawing wore, in world pixels (0: none),
## and where it sat, relative to the sheet's origin, before facing.
var _glint_drawn := 0.0
## Whether the last tell drawn wore its dark keyline (12.151), and its glint a backing.
var _key_drawn := false
var _glint_keyed := false
## True for a foe that carries its own light (a `FoeGlow` sets it), and whether its
## last sheet drawing wore the dark keyline that parts it from that light (12.154).
var light_keyed := false
var _light_key_drawn := false
## How many pixels wide the keyline was in this foe's last sheet drawing (12.155).
var _key_steps_drawn := 0
var _glint_at := Vector2.ZERO
## How far into its rear this foe's last sheet frame was drawn (0 to 1), and the
## most of the weapon's light that lay on it (an alpha; 0 with none).
var _rear_drawn := 0.0
var _light_drawn := 0.0
## The sheet this foe last drew itself from through `draw_sheet` ("" for none).
var _sheet_drawn := ""
## The chips the last blow knocked off this foe (tests; freed when they have fallen).
var chips: HitChips
## The material this foe rests in: its room's light (`FoeLight`, bible 12.43),
## or null outside a zone. The flash, the tell and the death replace it.
var _rest_material: ShaderMaterial


func _ready() -> void:
	collision_layer = Player.LAYER_ENEMY
	collision_mask = Player.LAYER_WORLD
	# A 45-degree slope is floor, as it is for the player (design bible 6.1).
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 4.0
	add_to_group("enemy")
	add_to_group("pogo")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	shape.shape = rect
	shape.position = Vector2.ZERO if body_centered else Vector2(0, -body_size.y * 0.5)
	add_child(shape)
	if corrupted and not is_in_group("boss"):
		_corrupt()
	hp = max_hp
	home = global_position
	_rest_material = FoeLight.material_for(FoeLight.zone_of(self), FoeLight.id_of(self))
	material = _rest_material
	# The pool on the ground under the foe (bible 12.110); guardians draw their own ground.
	if not is_in_group("boss"):
		add_child(ContactShadow.make(shadow_half(), true))


## Half the width of the foe's contact shadow: its body and two pixels each side.
func shadow_half() -> float:
	return body_size.x * 0.5 + 2.0


func _corrupt() -> void:
	max_hp = ceili(max_hp * CORRUPT_HP)
	gold_min *= CORRUPT_GOLD
	gold_max *= CORRUPT_GOLD
	xp *= CORRUPT_XP
	poison_drops = true
	# A violet cast over the body, with the crystal and its eye drawn on top.
	self_modulate = Color(0.86, 0.74, 1.0)
	add_child(CorruptionGrowth.new())


func player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func set_state(s: String) -> void:
	state = s
	state_time = 0.0


func center() -> Vector2:
	return global_position if body_centered else global_position + Vector2(0, -body_size.y * 0.5)


func _physics_process(delta: float) -> void:
	_raise_while_struck(delta)
	if dead:
		if respawn_time > 0.0:
			_respawn_timer -= delta
			if _respawn_timer <= 0.0:
				_respawn()
		return
	# A slow runs the foe's clock, its thinking and its movement at half time, but
	# counts down in real time, so it lasts its SLOW_TIME seconds (pass 497).
	var step := delta
	if _slow > 0.0:
		_slow -= delta
		step = delta * SLOW_FACTOR
	game_time += step
	state_time += step
	_flash -= delta
	if _stagger > 0.0:
		_stagger -= delta
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		if not uses_gravity:
			velocity.y = move_toward(velocity.y, 0.0, 600.0 * delta)
		if _stagger <= 0.0:
			set_state("idle")
	elif _hitstun > 0.0:
		_hitstun -= delta
		velocity = velocity.move_toward(Vector2(0, velocity.y if uses_gravity else 0.0), 700.0 * delta)
	else:
		_think(step)
		if _slow > 0.0:
			# Half speed afoot, and in the air for a flier; gravity is left real.
			velocity.x *= SLOW_FACTOR
			if not uses_gravity:
				velocity.y *= SLOW_FACTOR
	if uses_gravity:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	_fall_out_of_room()
	queue_redraw()


## A foe knocked through a gap in its room's floor (a Tower shaft, the Heartwood's
## drops) falls to its death (pass 291). It used to fall on below the room for
## good, its gold, drop and experience lost with it. Now it dies as it leaves,
## and its coins and drop come to rest at the gap's edge (Drop.keep_in_room).
func _fall_out_of_room() -> void:
	var room := get_parent() as Room
	if room == null or not uses_gravity or is_in_group("boss"):
		return
	if global_position.y > room.size_tiles.y * Room.TILE + FALL_MARGIN:
		fell = true
		die()


## Override: AI for one frame.
func _think(_delta: float) -> void:
	pass


## Override: return the damage actually taken (e.g. 0 when a shield blocks it).
func _modify_damage(damage: int, _dir: Vector2) -> int:
	return damage


## A hit from a thrown blade (the Rune Dagger). `_modify_damage` reads `thrown`.
func take_throw(damage: int, dir: Vector2) -> void:
	thrown = true
	take_hit(damage, dir)
	thrown = false


func take_hit(damage: int, dir: Vector2) -> void:
	if dead:
		return
	_provoked = true
	hits_taken += 1
	var dealt := _modify_damage(damage, dir)
	if dealt <= 0:
		_on_blocked(dir)
		return
	hp -= dealt
	_flash = 0.08
	_struck_for = STRUCK_TIME
	# A heavy blow comes in at 1.8x (the finisher, a thrust): its number is gold.
	DamageNumber.spawn(get_parent(), center() + Vector2(0, -14), dealt, "heavy" if dir.length() > 1.5 else "hit")
	var d := Dust.new()
	d.setup("hit")
	get_parent().add_child(d)
	d.global_position = center()
	chips = HitChips.spawn(get_parent(), center(), dir, chip_colors())
	if hp <= 0:
		die()
		return
	velocity = dir * knockback
	if dir.y < 0.0 and uses_gravity:
		velocity.y = -knockback
	# A heavy blow comes in longer (dir 1.8x, the combo finisher): it reels longer.
	_hitstun = HITSTUN * maxf(dir.length(), 1.0)
	_hitstun_full = _hitstun
	_blow_side = signf(dir.x) if dir.x != 0.0 else float(-facing)


## The colors a blow chips off this foe (bible 6.7, pass 621): its body's main tone
## and a lighter one, read off its sheet (the one it last drew from, or the one named
## for its script). A foe with no sheet is chipped in pale bone (`HitChips.BONE`).
func chip_colors() -> Array[Color]:
	var sheet := _sheet_drawn
	if sheet == "":
		var id := FoeLight.id_of(self)
		if id != "" and Sheet.exists(id):
			sheet = id
	return sheet_chip_colors(sheet) if sheet != "" else HitChips.BONE


## The two tones chipped off a foe drawn from `sheet`, read once from its first cell:
## of the cell's opaque colors lighter than its outline and deep shade (`CHIP_DARK`),
## the commonest, and the lightest of the `CHIP_TOP` commonest.
static func sheet_chip_colors(sheet: String) -> Array[Color]:
	if not _chip_colors.has(sheet):
		var s := Sheet.get_sheet(sheet)
		var cell: Vector2 = s.cell
		var img := (s.tex as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		var counts := {}
		for y in int(cell.y):
			for x in int(cell.x):
				var c := img.get_pixel(x, y)
				if c.a > 0.9 and c.get_luminance() >= CHIP_DARK:
					var key := Color(c.r, c.g, c.b).to_html(false)
					counts[key] = int(counts.get(key, 0)) + 1
		var keys := counts.keys()
		keys.sort_custom(func(a: String, b: String) -> bool:
			return counts[a] > counts[b] or (counts[a] == counts[b] and a < b))
		if keys.is_empty():
			# A foe all in shade has nothing lighter to chip: pale bone.
			_chip_colors[sheet] = HitChips.BONE
			return _chip_colors[sheet]
		var out: Array[Color] = []
		if not keys.is_empty():
			var main := Color(keys[0] as String)
			var light := main
			for i in range(1, mini(CHIP_TOP, keys.size())):
				var c := Color(keys[i] as String)
				if c.get_luminance() > light.get_luminance():
					light = c
			out = [main, light]
		_chip_colors[sheet] = out if not out.is_empty() else HitChips.BONE
	return _chip_colors[sheet]


func _on_blocked(dir: Vector2) -> void:
	var d := Dust.new()
	d.setup("guard")
	get_parent().add_child(d)
	d.global_position = center() - Vector2(dir.x * 10.0, 0)
	Sfx.play("guard")
	turn_blade()


## A blade turned at arm's length pushes the hero back; a bolt, a burst or a
## thrown blade turned from across the room does not (pass 442). Every guard
## that turns a blow calls this, a guardian's own too (pass 444).
func turn_blade() -> void:
	var p := player()
	if p:
		p.blade_turned()


## Rising Cut (skill tree): an up-slash throws a small foe into the air, helpless
## until it lands. Bosses, fliers and anything heavier than LAUNCH_MAX_HP stay put.
## Returns whether it went up.
func launch() -> bool:
	if dead or not launchable or not uses_gravity or max_hp > LAUNCH_MAX_HP or is_in_group("boss"):
		return false
	velocity = Vector2(0, -LAUNCH_SPEED)
	_hitstun = LAUNCH_STUN
	_hitstun_full = 0.0
	return true


## Called by the player on a successful parry.
func stagger() -> void:
	if dead:
		return
	_stagger = 1.0
	_flash = 0.1
	_struck_for = STRUCK_TIME
	set_state("stagger")
	velocity.x = -facing * 80.0


## Draws this foe at STRUCK_Z while a blow's flash and recoil play (pass 599), and
## at its own z again after; z is only touched as the window opens and closes.
func _raise_while_struck(delta: float) -> void:
	_struck_for = maxf(0.0, _struck_for - delta)
	var struck := _struck_for > 0.0
	if struck == _struck_raised:
		return
	_struck_raised = struck
	if struck:
		_rest_z = z_index
		z_index = maxi(z_index, STRUCK_Z)
	else:
		z_index = _rest_z


## True when this foe's last sheet drawing wore a hit flash's dark rim (pass 602).
func hit_rim_drawn() -> bool:
	return _hit_rim_drawn


## The side the struck edge was lit on in this foe's last sheet drawing, in world
## terms: -1 its left, 1 its right, 0 none (pass 646).
func struck_edge_drawn() -> int:
	return _struck_edge_drawn


## Which side a blow's light falls on: the side it came from, against its push.
func struck_side() -> int:
	return -int(_blow_side) if _blow_side != 0.0 else facing


## True while a blow's flash and recoil draw this foe above the swing (pass 599).
func drawn_struck() -> bool:
	return _struck_raised


func is_staggered() -> bool:
	return _stagger > 0.0


## Lithic Fracture's wave slows a foe (design bible 4, pass 497): for `duration`
## seconds its clock, thinking and movement run at SLOW_FACTOR. A fresh cast
## refreshes the time rather than stacking the factor.
func slow(duration := SLOW_TIME) -> void:
	if dead:
		return
	_slow = maxf(_slow, duration)


func is_slowed() -> bool:
	return _slow > 0.0


## The foe's opening: while it is true, its guard is down and blows land in full
## (design bible 8: every boss has a stagger window). Bloodletting and
## Executioner read it. A parry stagger by default; each boss names its own window.
func punishable() -> bool:
	return is_staggered()


## Goes down with its master (design bible 5.5, pass 266): a guardian's brood
## dies with the guardian. It dissolves like any foe, but no blow felled it, so
## it pays no gold, drop or experience, counts as no kill (Wanderer's Grace),
## and adds no kill hitstop or shake to the guardian's own death.
func perish() -> void:
	if dead:
		return
	perished = true
	hp = 0
	die()


func die() -> void:
	dead = true
	collision_layer = 0
	velocity = Vector2.ZERO
	if is_in_group("boss"):
		# A boss has played its own death by the time it gets here: it goes at once.
		visible = false
	else:
		_dissolve()
	var d := Dust.new()
	d.setup("debris")
	get_parent().add_child(d)
	d.global_position = center()
	# Risk pays (design bible 10.1, pass 197): a deep zone's foes hit harder
	# (Room.threat, 5.5) and drop that much more gold.
	# A boss rush wins nothing again (bible 11, pass 260): no gold, drops or
	# experience from a guardian or anything it calls in.
	if not BossRush.active() and not perished:
		var room := get_parent() as Room
		Coin.spray(get_parent(), center(), roundi(randi_range(gold_min, gold_max) * (room.threat() if room != null else 1.0)))
		if sure_drop != "":
			Drop.make(get_parent(), center(), sure_drop)
		else:
			Drop.roll(get_parent(), center(), poison_drops)
		GameState.add_xp(xp)
	var p := get_tree().get_first_node_in_group("player") as Player
	if not perished:
		if p != null:
			p.on_kill()
		# A fall is a kill but no blow (pass 298): it dies below the screen a
		# moment after the blow that sent it, so a kill's freeze and shake then
		# would hitch the game for nothing you can see.
		if not fell:
			Feel.hitstop(p.combat.kill_hitstop if p != null else CombatTuning.new().kill_hitstop)
			Feel.add_trauma(0.25)
	Sfx.play("enemy_die")
	if corrupted:
		var seed := MeteorSeed.new()
		seed.position = get_parent().to_local(center())
		get_parent().add_child.call_deferred(seed)
	died.emit(self)
	if respawn_time > 0.0:
		_respawn_timer = respawn_time
	elif not visible:
		queue_free()


## The death (bible 7): the body flashes white and breaks up into glowing motes
## over DISSOLVE seconds, then is gone (freed, unless it respawns).
func _dissolve() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = DISSOLVE_SHADER
	material = mat
	if _dissolver != null:
		_dissolver.kill()
	_dissolver = create_tween()
	_dissolver.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.0, 1.0, DISSOLVE)
	_dissolver.tween_callback(_dissolved)


func _dissolved() -> void:
	_dissolver = null
	if not dead:
		return
	visible = false
	material = _rest_material
	if respawn_time <= 0.0:
		queue_free()


## True while the body breaks up after its death.
func dissolving() -> bool:
	return dead and visible


func _respawn() -> void:
	if _dissolver != null:
		_dissolver.kill()
		_dissolver = null
	material = _rest_material
	dead = false
	perished = false
	fell = false
	hp = max_hp
	visible = true
	collision_layer = Player.LAYER_ENEMY
	global_position = home
	velocity = Vector2.ZERO
	_stagger = 0.0
	_hitstun = 0.0
	_slow = 0.0
	set_state("idle")
	reset_physics_interpolation()


## Damages the player if `rect` overlaps them. Returns the player's resolution.
## True while the hero, under the Hollowmist Cloak, is hidden from this foe:
## it is undead and has not been struck. It neither sees nor touches them.
func ignores_player() -> bool:
	if not undead or _provoked:
		return false
	var p := player()
	return p != null and p.spectral


func hit_player_in_rect(rect: Rect2, damage: int, parryable := true) -> String:
	var p := player()
	if p == null or p.dead or ignores_player() or not rect.intersects(p.body_rect()):
		return ""
	return p.receive_attack(damage, self, parryable)


func face_player() -> void:
	var p := player()
	if p and not ignores_player():
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 2.0:
			facing = int(signf(dx))


func player_offset() -> Vector2:
	var p := player()
	if p == null or p.dead or ignores_player():
		return Vector2(INF, INF)
	return p.global_position + Vector2(0, -20) - center()


## From this foe's centre to the hero's head height (HEAD_HEIGHT above the
## feet, standing or crouched): where a blow meant to be ducked is aimed.
func player_head_offset() -> Vector2:
	var p := player()
	if p == null or p.dead or ignores_player():
		return Vector2(INF, INF)
	return p.global_position + Vector2(0, -HEAD_HEIGHT) - center()


## True while the enemy should be drawn white (hit flash or telegraph pulse).
func flashing() -> bool:
	return _flash > 0.0


## True when a hit flash is past its pop (bible 6.7, pass 567): the frame a blow
## lands the foe is drawn white (`FLASH_WASH`), and for the rest of the flash,
## the hit-stop included, in a pale tint that keeps its inner lines
## (`FLASH_SOFT_WASH`). A tell's pulse is never soft. Call it once per drawing.
func _flash_is_soft() -> bool:
	if _flash <= 0.0:
		_flash_drawn = 0.0
		return false
	var frame := Engine.get_process_frames()
	if _flash > _flash_drawn:
		_flash_pop_frame = frame
	_flash_drawn = _flash
	return frame != _flash_pop_frame


## Washes everything this foe draws white while `on` (call it from `_draw`): a
## code-drawn foe's flash follows its own silhouette, never a box around it.
## With no blow behind it, in a state named for a tell, the wash is the tell's
## tint (`TELL_TINT`, `TELL_WASH`). Leaves the death's dissolve alone.
func wash(on: bool) -> void:
	if _wash_material == null:
		_wash_material = ShaderMaterial.new()
		_wash_material.shader = WASH_SHADER
		_wash_material.set_shader_parameter("amount", FLASH_WASH)
		_soft_wash_material = ShaderMaterial.new()
		_soft_wash_material.shader = WASH_SHADER
		_soft_wash_material.set_shader_parameter("amount", FLASH_SOFT_WASH)
		_soft_wash_material.set_shader_parameter("tint", SOFT_TINT)
		_tell_wash_material = ShaderMaterial.new()
		_tell_wash_material.shader = WASH_SHADER
		_tell_wash_material.set_shader_parameter("amount", TELL_WASH)
		_tell_wash_material.set_shader_parameter("tint", TELL_TINT)
	var soft := _flash_is_soft()
	_tell_drawn = on and not dead and _telling()
	if _tell_drawn:
		material = _tell_wash_material
	elif on and not dead:
		material = _soft_wash_material if soft else _wash_material
	elif washed():
		material = _rest_material


## True when a whitened drawing is a tell's pulse: no blow is flashing, and the
## foe is in a state named for a wind-up.
func _telling() -> bool:
	return _flash <= 0.0 and (state.ends_with("_tell") or state == "windup")


## True while this foe's drawing is washed white.
func washed() -> bool:
	return _wash_material != null and (material == _wash_material or material == _soft_wash_material
			or material == _tell_wash_material)


## How strongly this foe's last drawing was whitened, 0 to 1: the wash's amount,
## or a sheet's white overlay. 0 when it was drawn in its own colors.
func white_strength() -> float:
	if washed():
		if material == _tell_wash_material:
			return TELL_WASH
		return FLASH_SOFT_WASH if material == _soft_wash_material else FLASH_WASH
	return _sheet_white_alpha if _sheet_white else 0.0


## True when this foe's last drawing wore the tell's tint: a warning, where
## white is a blow that landed.
func tell_drawn() -> bool:
	return _tell_drawn and drawn_white()


## True when this foe's last drawing went white, washed (`wash`) or drawn
## from a sheet in white (`draw_sheet`): the hit flash and the tell's pulse.
func drawn_white() -> bool:
	return washed() or _sheet_white


func telegraph_pulse() -> bool:
	return int(state_time * 16.0) % 2 == 0


## Draws frame `anim` of `sheet` (assets/sprites, from tools/art/castgen.py) at
## time `t`, facing this enemy's way, washed white while flashing or telegraphing.
## Returns the frame drawn.
func draw_sheet(sheet: String, anim: String, t: float, white := false, offset := Vector2.ZERO) -> int:
	_sheet_drawn = sheet
	var f := Sheet.frame_at(sheet, anim, t)
	var over := flash_overlay(white)
	var glint := not dead and _flash <= 0.0 and has_tell_point(sheet, anim)
	_hit_rim_drawn = white and not _tell_drawn
	_glint_drawn = 0.0
	_light_drawn = 0.0
	_rear_drawn = rear_at(state_time) if glint else 0.0
	_key_drawn = false
	_glint_keyed = false
	_light_key_drawn = false
	_key_steps_drawn = 0
	if not dead:
		# Keyed off its ground (12.155), or off its own light, wider (12.154): its
		# silhouette in near-black, a pixel out all round, under everything else; a
		# tell's or a blow's rim lies over it.
		var steps := key_steps()
		for k in range(steps, 0, -1):
			for step: Vector2 in RIM_STEPS:
				draw_set_transform_matrix(_sheet_transform(offset + step * float(k)))
				Sheet.draw(self, sheet, anim, f, Color(TELL_KEY, LIGHT_KEY_RIM), true)
		_key_steps_drawn = steps
		_light_key_drawn = light_keyed
	if _tell_drawn and glint:
		# The tell lights the weapon, not the foe: the rim only near the point.
		_sheet_white_alpha = 0.0
		var at := tell_point(sheet, anim, f)
		# The keyline first, one pixel outside where the warm rim will lie (12.151).
		for reach: float in TELL_REACH:
			var half := Vector2(reach, reach) * tell_reach_scale(sheet) * float(Sheet.get_sheet(sheet).density)
			var part := Rect2(at - half, half * 2.0)
			for step: Vector2 in RIM_STEPS:
				draw_set_transform_matrix(_sheet_transform(offset + step * TELL_KEY_STEP))
				Sheet.draw_part(self, sheet, anim, f, part, Color(TELL_KEY, TELL_KEY_RIM), true)
		_key_drawn = true
		for reach: float in TELL_REACH:
			var half := Vector2(reach, reach) * tell_reach_scale(sheet) * float(Sheet.get_sheet(sheet).density)
			var part := Rect2(at - half, half * 2.0)
			for step: Vector2 in RIM_STEPS:
				draw_set_transform_matrix(_sheet_transform(offset + step))
				Sheet.draw_part(self, sheet, anim, f, part, Color(TELL_TINT, TELL_REACH_RIM), true)
	elif _tell_drawn or _hit_rim_drawn:
		var rim := Color(TELL_TINT, TELL_RIM) if _tell_drawn else Color(HIT_RIM_COLOR, HIT_RIM)
		if _tell_drawn:
			for step: Vector2 in RIM_STEPS:
				draw_set_transform_matrix(_sheet_transform(offset + step * TELL_KEY_STEP))
				Sheet.draw(self, sheet, anim, f, Color(TELL_KEY, TELL_RIM), true)
			_key_drawn = true
		for step: Vector2 in RIM_STEPS:
			draw_set_transform_matrix(_sheet_transform(offset + step))
			Sheet.draw(self, sheet, anim, f, rim, true)
	_struck_edge_drawn = 0
	if _hit_rim_drawn and not dead:
		# The struck edge: the body in white, then the body itself set back from the
		# blow by the edge's width, so a crescent of the white shows inside the outline
		# on the blow's side. The rim is drawn again about the set-back body.
		var side := struck_side()
		var back := Vector2(-side * STRUCK_EDGE_WIDTH, 0.0)
		for step: Vector2 in RIM_STEPS:
			draw_set_transform_matrix(_sheet_transform(offset + back + step))
			Sheet.draw(self, sheet, anim, f, Color(HIT_RIM_COLOR, HIT_RIM), true)
		draw_set_transform_matrix(_sheet_transform(offset))
		Sheet.draw(self, sheet, anim, f, STRUCK_EDGE, true)
		offset += back
		_struck_edge_drawn = side
	draw_set_transform_matrix(_sheet_transform(offset))
	Sheet.draw(self, sheet, anim, f)
	if white and not (_tell_drawn and glint):
		Sheet.draw(self, sheet, anim, f, over, true)
	if glint:
		_draw_body_light(sheet, anim, f)
		_draw_glint(sheet, tell_point(sheet, anim, f), _tell_drawn)
	draw_set_transform(Vector2.ZERO)
	return f


## True when `anim` of `sheet` is a wind-up with a point for the glint.
static func has_tell_point(sheet: String, anim: String) -> bool:
	return TELL_POINTS.has(sheet) and (TELL_POINTS[sheet] as Dictionary).has(anim)


## The glint's point on frame `frame` of a wind-up, in the cell's own pixels.
static func tell_point(sheet: String, anim: String, frame: int) -> Vector2:
	var p: Variant = TELL_POINTS[sheet][anim]
	if p is Array:
		return (p as Array)[clampi(frame, 0, (p as Array).size() - 1)]
	return p


## How much of `TELL_REACH` a sheet's foe gets: less for a small cell.
static func tell_reach_scale(sheet: String) -> float:
	var s := Sheet.get_sheet(sheet)
	var cell: Vector2 = s.cell
	return minf(1.0, minf(cell.x, cell.y) / float(s.density) / TELL_REACH_CELL)


## How far a foe has reared `time` seconds into a wind-up, 0 to 1: quick at first,
## so the pose reads from the wind-up's first frames, and whole by `REAR_TIME`.
static func rear_at(time: float) -> float:
	var x := clampf(time / REAR_TIME, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


## How far into its rear this foe's last sheet frame was drawn (0 upright).
func rear_drawn() -> float:
	return _rear_drawn


## The weapon's light on a foe's body `dist` world pixels from the tell's point
## (the larger of the two axes), `time` seconds into the wind-up, for a foe whose
## squares are scaled by `scale` (`tell_reach_scale`): an alpha of `TELL_TINT`.
static func body_light(dist: float, time: float, scale := 1.0) -> float:
	var through := 1.0
	var step := LIGHT_STEP * clampf(time / GLINT_GATHER, 0.0, 1.0)
	for reach: float in LIGHT_REACH:
		if dist <= reach * scale:
			through *= 1.0 - step
	return 1.0 - through


## The most of the weapon's light this foe's last sheet drawing wore (0 with none).
func light_drawn() -> float:
	return _light_drawn


## The weapon's light on the body: the frame's silhouette in the tell's tint, once
## in each square about the point. Drawn under the sheet's transform.
func _draw_body_light(sheet: String, anim: String, f: int) -> void:
	var step := LIGHT_STEP * clampf(state_time / GLINT_GATHER, 0.0, 1.0)
	if step <= 0.0:
		return
	var at := tell_point(sheet, anim, f)
	var k := tell_reach_scale(sheet) * float(Sheet.get_sheet(sheet).density)
	for reach: float in LIGHT_REACH:
		var half := Vector2(reach, reach) * k
		Sheet.draw_part(self, sheet, anim, f, Rect2(at - half, half * 2.0), Color(TELL_TINT, step), true)
	_light_drawn = body_light(0.0, state_time)


## How long the glint's arms are `time` seconds into a wind-up, lit or between beats.
static func glint_arm(time: float, lit: bool) -> float:
	var k := clampf(time / GLINT_GATHER, 0.0, 1.0)
	return lerpf(GLINT_MIN, GLINT_MAX, k) + (GLINT_PULSE if lit else 0.0)


## The arm of the glint this foe's last sheet drawing wore (0 when it wore none).
func glint_drawn() -> float:
	return _glint_drawn


## Whether this foe's last sheet drawing wore the keyline off its own light (12.154).
func light_key_drawn() -> bool:
	return _light_key_drawn


## How wide this foe's keyline is (bible 12.155): a foe with its own light's wider
## one (12.154), or every other sheet foe's.
func key_steps() -> int:
	return LIGHT_KEY_STEPS if light_keyed else FOE_KEY_STEPS


## How many pixels wide the keyline was in this foe's last sheet drawing; 0 when none
## was drawn (dead, or a foe drawn in code rather than from a sheet).
func key_steps_drawn() -> int:
	return 0 if dead else _key_steps_drawn


## Whether this foe's last tell wore its dark keyline outside the warm rim (12.151).
func tell_keyed() -> bool:
	return _key_drawn


## Whether this foe's last glint sat on its dark backing (12.151).
func glint_keyed() -> bool:
	return _glint_keyed and _glint_drawn > 0.0


## Where that glint sat, in world pixels from this foe's origin, facing included.
func glint_at() -> Vector2:
	return Vector2(_glint_at.x * facing, _glint_at.y)


## The glint on the weapon (bible 12.88): a hot core and four tapering arms in the
## tell's gold, with a short spark on each diagonal. Drawn under the sheet's
## transform, in half pixels like the sprite it sits on.
func _draw_glint(sheet: String, point: Vector2, lit: bool) -> void:
	var s := Sheet.get_sheet(sheet)
	var c: Vector2 = (point - (s.origin as Vector2)) / float(s.density)
	var arm := glint_arm(state_time, lit)
	_glint_drawn = arm
	_glint_at = c
	var gold := Color(TELL_TINT, 0.95)
	# The backing (12.151): the arms and core in near-black, a little wider and longer,
	# so the gold reads on a pale or warm ground too.
	var key := Color(TELL_KEY, 0.85)
	for d: Vector2 in RIM_STEPS:
		var side := Vector2(absf(d.y), absf(d.x))
		_glint_bar(c, d, 0.0, arm * 0.55 + GLINT_KEY * 0.5, side, 1.0 + GLINT_KEY, key)
		_glint_bar(c, d, arm * 0.55, arm + GLINT_KEY * 0.5, side, 0.5 + GLINT_KEY, key)
	var back := (1.5 if lit else 1.0) + GLINT_KEY * 0.5
	draw_rect(Rect2(c - Vector2(back, back), Vector2(back, back) * 2.0), key)
	_glint_keyed = true
	for d: Vector2 in RIM_STEPS:
		var side := Vector2(absf(d.y), absf(d.x))
		# A thick root, a thin tip.
		_glint_bar(c, d, 0.0, arm * 0.55, side, 1.0, gold)
		_glint_bar(c, d, arm * 0.55, arm, side, 0.5, gold)
		_glint_bar(c, d, 0.0, arm * 0.4, side, 0.5, GLINT_CORE)
	var spark := maxf(1.0, arm * 0.3)
	for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n := 1.0
		while n <= spark:
			draw_rect(Rect2(c + d * n - Vector2(0.25, 0.25), Vector2(0.5, 0.5)), Color(TELL_TINT, 0.8))
			n += 0.5
	var core := 1.5 if lit else 1.0
	draw_rect(Rect2(c - Vector2(core, core), Vector2(core, core) * 2.0), GLINT_CORE)


## One bar of a glint's arm: from `from` to `to` along `dir`, `thick` across.
func _glint_bar(c: Vector2, dir: Vector2, from: float, to: float, side: Vector2, thick: float, color: Color) -> void:
	var a := c + dir * from - side * thick * 0.5
	var b := c + dir * to + side * thick * 0.5
	draw_rect(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()), color)


## How far into its recoil this foe is, 0 to 1: 1 the frame a blow lands, easing
## to 0 as the hitstun runs out (quadratic, so the snap back is quick at the end).
func recoil() -> float:
	if dead or _hitstun <= 0.0 or _hitstun_full <= 0.0:
		return 0.0
	var k := clampf(_hitstun / _hitstun_full, 0.0, 1.0)
	return k * k


## The shear a sheet foe is drawn with now: world pixels its head moves along the
## blow per pixel up (positive is right). 0 outside a recoil.
func recoil_lean() -> float:
	return _blow_side * RECOIL_LEAN * recoil()


## The shear this foe's last sheet frame was drawn with (0 drawn upright).
func lean_drawn() -> float:
	return _lean_drawn


## Where a sheet frame is drawn: facing this foe's way, at `offset`, leaning and
## squashed through a recoil about its feet (the sheet's origin).
func _sheet_transform(offset: Vector2) -> Transform2D:
	var k := recoil()
	_lean_drawn = recoil_lean()
	# The rear (12.109): back from the facing, taller and narrower.
	var lean := recoil_lean() - float(facing) * REAR_LEAN * _rear_drawn
	var sx := float(facing) * (1.0 + RECOIL_SQUASH * k) * (1.0 - REAR_STRETCH * 0.5 * _rear_drawn)
	var sy := (1.0 - RECOIL_SQUASH * 0.6 * k) * (1.0 + REAR_STRETCH * _rear_drawn)
	# A point h pixels up (y = -h) moves `lean` * h along x.
	return Transform2D(Vector2(sx, 0.0), Vector2(-lean * sy, sy), offset)


## The color of the flat overlay a foe drawn from a sheet wears while `white`:
## the white pop on the frame a blow lands, the pale tint for the rest of a hit
## flash, the tell's tint with no blow behind it. `k` scales its alpha (a foe
## half seen). Call it once per drawing, whether `white` or not.
func flash_overlay(white: bool, k := 1.0) -> Color:
	var soft := _flash_is_soft()
	_sheet_white = white
	_tell_drawn = white and _flash <= 0.0
	if _tell_drawn:
		_sheet_white_alpha = SHEET_TELL
		return Color(TELL_TINT, SHEET_TELL * k)
	_sheet_white_alpha = SHEET_SOFT_WHITE if soft else SHEET_WHITE
	return Color(SOFT_TINT if soft else Color.WHITE, _sheet_white_alpha * k)

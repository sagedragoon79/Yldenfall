class_name SaveShrine
extends Interactable
## Meditation Shrine: press Up to rest. Restores health, magic and potions,
## saves the game and becomes the respawn point.

## What a rest says when the save file could not be written (pass 255).
const NOT_SAVED := "Rested, but the journey could not be saved."

const STONE := Color("6b6380")
const STONE_DARK := Color("4a4458")
const STONE_LIGHT := Color("8d84a3")
const RUNE := Color("7ee0d6")

## How far its glow clears the Haar's fog.
var light_radius := 80.0
## The cool pool its rune casts onto the shrine's stone and the floor (RoomLight
## reads these).
var glow_color := RUNE
var glow_radius := 96.0
var _glow := 0.0


func _ready() -> void:
	super()
	prompt_height = 34.0
	z_index = -1
	# Its rune burns through the Haar's fog (see Fog).
	add_to_group("light")
	# And casts a pool of rune-light onto the stone around it (design bible 12.10).
	add_to_group(RoomLight.GROUP)


func _process(delta: float) -> void:
	super(delta)
	_glow = move_toward(_glow, 0.0, delta * 0.8)


## Said by a shrine pressed while a guardian's fight goes on (pass 455).
const NO_REST_IN_FIGHT := "The shrine is silent while the guardian stands."


func interact(p: Player) -> void:
	if BossRush.active():
		# The rush allows no rest: a shrine on the way would refill you and
		# save in the middle of it.
		GameState.toast.emit("The ring allows no rest in the rush.")
		return
	if BossArena.any_fighting(get_tree()):
		# Nor while a guardian stands (bible 8, pass 455): The Likeness's gate
		# has a shrine inside her arena, and a rest there mid-fight made you
		# whole, refilled the flask and saved with her still up.
		Sfx.play("menu_refuse", 0.0, -4.0)
		GameState.toast.emit(NO_REST_IN_FIGHT)
		return
	p.restore()
	_glow = 1.0
	var world := get_tree().get_first_node_in_group("world") as World
	var saved := true
	if world != null:
		saved = world.save_at(global_position)
	else:
		p.spawn_point = global_position
	var d := Dust.new()
	d.setup("heal")
	get_parent().add_child(d)
	d.global_position = global_position + Vector2(0, -16)
	Sfx.play("save", 0.0)
	GameState.toast.emit("Rested. Progress saved." if saved else NOT_SAVED)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	draw_circle(Vector2(0, -16), 14.0 + pulse * 2.0 + _glow * 8.0, Color(RUNE, 0.08 + _glow * 0.2))
	# Base and obelisk.
	draw_rect(Rect2(-12, -4, 24, 4), STONE_DARK)
	draw_rect(Rect2(-10, -6, 20, 2), STONE)
	draw_rect(Rect2(-6, -28, 12, 22), STONE)
	draw_rect(Rect2(-6, -28, 2, 22), STONE_LIGHT)
	draw_rect(Rect2(4, -28, 2, 22), STONE_DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -28), Vector2(0, -33), Vector2(6, -28)]), STONE_LIGHT)
	# Glowing rune.
	var rune := RUNE.lerp(Color.WHITE, _glow * 0.6)
	rune.a = 0.6 + pulse * 0.4
	draw_rect(Rect2(-1, -24, 2, 12), rune)
	draw_rect(Rect2(-3, -20, 6, 2), rune)
	draw_rect(Rect2(-3, -14, 2, 2), rune)
	draw_rect(Rect2(1, -14, 2, 2), rune)
	draw_prompt()

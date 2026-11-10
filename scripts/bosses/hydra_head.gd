class_name HydraHead
extends BossSegment
## One of the Haar Wyrm's three heads (design bible 8.4): a hitbox the boss moves
## and a light in the fog. Each head has its own health and its own breath. The
## boss runs its moves (`mode`); the head only keeps the numbers.
##
## A head can't be beaten below HEAD_FLOOR while its scales are hot: only a full
## cistern douses it (`weak`), and only a weakened head can be brought down. A
## head at 0 dies and hangs limp; the fight ends when all three have.

## The breaths, one to a head for the whole fight.
const PLUME := "plume"
const GEYSER := "geyser"
const FOG := "fog"

## How far its glow clears the fog (see Fog).
var light_radius := 64.0
## Which breath this head owns.
var breath := PLUME
var hp := 100
var max_hp := 100
## Doused by a full cistern: open to the killing blows until the hydra rages.
var weak := false
## What the head is doing: hidden, emerge, idle, tell, breathe, sag, weak, rage, limp.
var mode := "hidden"
var mode_time := 0.0
## Where a move started and where it goes.
var from := Vector2.ZERO
var to := Vector2.ZERO
## The geyser's aim, locked late in its tell (a unit vector).
var aim := Vector2.DOWN


func _ready() -> void:
	radius = 14.0
	super._ready()


func set_mode(m: String) -> void:
	mode = m
	mode_time = 0.0
	from = global_position


## Where its breath leaves the jaws (the geyser stays on them).
func mouth_point() -> Vector2:
	if boss != null and boss.has_method("mouth_of"):
		return boss.mouth_of(self)
	return global_position


func fraction() -> float:
	return clampf(float(hp) / max_hp, 0.0, 1.0)


## Out in the arena and alive: hittable and a light.
func set_out(on: bool) -> void:
	set_active(on and not dead)
	if on and not dead:
		add_to_group("light")
	else:
		remove_from_group("light")


## The head is dead: it hangs limp, no hitbox and no light.
func kill() -> void:
	dead = true
	weak = false
	set_active(false)
	remove_from_group("light")
	set_mode("limp")

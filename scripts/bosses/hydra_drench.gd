class_name HydraDrench
extends Node2D
## The douse (Sean, 2026-11-22: "a vfx for water coming out of the pipe into the cistern.
## Ideally dousing a head"): when the brimming cistern douses a head, that head's own pipe
## bursts. A thick jet arcs out of its spout onto the head, splashes off it in sheets with
## a cloud of steam off the hot scales, and then the head hangs dripping until it rises.
## Drawn only; the douse itself is `HaarWyrm._weaken`.

## How long the jet takes to reach the head, how long it pours on it, and how long it
## takes to run out.
const REACH := 0.22
const POUR := 0.8
const EBB := 0.3
const WATER := Color("4aa3df")
const WATER_LIGHT := Color("bfe8ff")
const WATER_DEEP := Color("2a5d9c")
const FOAM := Color("eef8ff")
const STEAM := Color("f4f7f6")

## Where the water leaves the spout (world), and the head it falls on.
var from := Vector2.ZERO
var target: Node2D
## How long it lasts in all (the jet, then the drips until the head rises).
var life := 6.5
var t := 0.0
var _last_at := Vector2.ZERO


func _ready() -> void:
	z_as_relative = false
	# Over the heads and the cistern; under the grate's own layer it would hide behind.
	z_index = 4
	top_level = true
	global_position = Vector2.ZERO
	_last_at = _at()


## The head's place now (where it was, if it is gone).
func _at() -> Vector2:
	if target != null and is_instance_valid(target):
		_last_at = target.global_position
	return _last_at


## 0 to 1: how much of the jet is there (it reaches out, pours, then runs dry).
func jet() -> float:
	if t < REACH + POUR:
		return 1.0
	return clampf(1.0 - (t - REACH - POUR) / EBB, 0.0, 1.0)


## True while the water is landing on the head.
func pouring() -> bool:
	return t >= REACH and t < REACH + POUR + EBB


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _point(a: Vector2, c: Vector2, b: Vector2, k: float) -> Vector2:
	return a.lerp(c, k).lerp(c.lerp(b, k), k)


func _draw() -> void:
	var to := _at()
	var now := Time.get_ticks_msec() * 0.001
	# An arc out of the spout and down onto the head, its top well above both.
	var ctl := (from + to) * 0.5 + Vector2(0, -minf(70.0, 30.0 + from.distance_to(to) * 0.35))
	var reach := clampf(t / REACH, 0.0, 1.0)
	var j := jet()
	if j > 0.0:
		var steps := 24
		var tail := clampf((t - REACH - POUR) / EBB, 0.0, 1.0)
		for i in steps:
			var k0 := float(i) / steps
			var k1 := float(i + 1) / steps
			if k1 > reach or k0 < tail:
				continue
			var p0 := _point(from, ctl, to, k0)
			var p1 := _point(from, ctl, to, k1)
			var w := (3.5 + sin(now * 18.0 + k0 * 9.0) * 0.6) * j
			draw_line(p0, p1, Color(WATER_DEEP, 0.85), w * 2.0 + 2.0)
			draw_line(p0, p1, Color(WATER, 0.95), w * 2.0)
			draw_line(p0 + Vector2(0, -w * 0.4), p1 + Vector2(0, -w * 0.4), Color(WATER_LIGHT, 0.95), maxf(w * 0.6, 1.0))
		# Beads streaming off the jet's edges.
		for i in 10:
			var k := fmod(now * 1.6 + float(i) * 0.1, 1.0)
			if k > reach or k < tail:
				continue
			var p := _point(from, ctl, to, k)
			var side := -1.0 if i % 2 == 0 else 1.0
			draw_rect(Rect2(p + Vector2(side * (3.0 + fmod(i * 1.7, 3.0)), 4.0 + k * 3.0), Vector2(1, 2)), Color(WATER_LIGHT, 0.8))
		# A burst of spray at the spout as the pipe lets go.
		var burst := clampf(1.0 - t / 0.5, 0.0, 1.0)
		if burst > 0.0:
			for i in 8:
				var a := -PI * 0.5 + (float(i) - 3.5) * 0.35
				var r := (1.0 - burst) * 18.0 + 3.0
				draw_rect(Rect2(from + Vector2(cos(a), sin(a)) * r, Vector2(2, 2)), Color(FOAM, burst))
	if pouring():
		var k := clampf((t - REACH) / 0.25, 0.0, 1.0) * j
		# Sheets of water breaking off the head, both ways and down.
		for i in 8:
			var ph := fmod(now * 2.4 + float(i) * 0.125, 1.0)
			var side := -1.0 if i % 2 == 0 else 1.0
			var sx := side * (6.0 + ph * (16.0 + float(i % 3) * 5.0))
			var sy := -6.0 * sin(ph * PI) + ph * ph * 22.0
			var size := 3.0 - ph * 1.5
			draw_rect(Rect2(to + Vector2(sx, sy), Vector2(size, size)), Color(WATER_LIGHT, 0.9 * (1.0 - ph) * k))
			draw_rect(Rect2(to + Vector2(sx * 0.6, sy * 0.8 + 2.0), Vector2(1, 2)), Color(WATER, 0.8 * (1.0 - ph) * k))
		# White water on the head itself.
		for i in 5:
			var a := now * 6.0 + float(i) * 1.3
			draw_circle(to + Vector2(cos(a) * 7.0, sin(a) * 3.0 - 4.0), 1.5, Color(FOAM, 0.45 * k))
	# Steam boiling off the hot scales: thick while the water hits, thinning after.
	var hiss := clampf((t - REACH) / 0.2, 0.0, 1.0) * clampf(1.0 - (t - REACH - POUR - EBB) / 2.0, 0.15, 1.0)
	if t >= REACH and hiss > 0.0:
		for i in 7:
			var ph := fmod(now * 0.7 + float(i) * 0.143, 1.0)
			var px := sin(float(i) * 2.3 + now) * (6.0 + ph * 10.0)
			draw_circle(to + Vector2(px, -8.0 - ph * 40.0), 3.0 + ph * 7.0, Color(STEAM, (1.0 - ph) * 0.22 * hiss))
	# After: the head hangs dripping.
	if t >= REACH + POUR * 0.5:
		var fade := clampf((life - t) / 1.0, 0.0, 1.0)
		for i in 5:
			var ph := fmod(now * 1.1 + float(i) * 0.2 + float(i * i) * 0.07, 1.0)
			var dx := (float(i) - 2.0) * 4.0
			draw_rect(Rect2(to + Vector2(dx, 6.0 + ph * 34.0), Vector2(1, 2 + int(ph * 2.0))), Color(WATER_LIGHT, 0.8 * (1.0 - ph) * fade))

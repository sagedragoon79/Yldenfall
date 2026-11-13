class_name DamageKind
extends RefCounted
## What a blow is made of (design bible 5.6). Every attack has one kind. A source
## names its own with `const DAMAGE_KIND`; one that names none is physical. The
## hero's Warding gems resist a kind each, and all of them together never past
## RESIST_CAP, so a hero can be immune to one kind of magic and never to all.

const PHYSICAL := "physical"
const FIRE := "fire"
const ICE := "ice"
const LIGHTNING := "lightning"
## The kinds a Warding gem can resist (physical is armor's work).
const MAGIC := [FIRE, ICE, LIGHTNING]
## All Warding together: 1.0 is one whole immunity.
const RESIST_CAP := 1.0
## The colour a kind's damage number takes (the hero's own losses).
const COLORS := {FIRE: Color("ff8a3a"), ICE: Color("9adcf5"), LIGHTNING: Color("f5e86a")}


## The kind of `source`'s blows.
static func of(source: Object) -> String:
	if source == null:
		return PHYSICAL
	var k: Variant = source.get("DAMAGE_KIND")
	return k if k is String and k != "" else PHYSICAL


## `resist` (kind to 0..1) held to the rules: magic kinds only, each 0 to 1, and
## no more than RESIST_CAP in all. Past the cap every kind is scaled down alike.
static func capped(resist: Dictionary) -> Dictionary:
	var out := {}
	var total := 0.0
	for k: String in MAGIC:
		var v := clampf(float(resist.get(k, 0.0)), 0.0, 1.0)
		if v > 0.0:
			out[k] = v
			total += v
	if total > RESIST_CAP:
		for k: String in out:
			out[k] = float(out[k]) * RESIST_CAP / total
	return out


## `amount` of `kind` after `resist`. A resisted blow still lands for 1 unless
## the resistance is whole, which is immunity.
static func reduce(amount: int, kind: String, resist: Dictionary) -> int:
	var r := float(capped(resist).get(kind, 0.0))
	if r <= 0.0 or amount <= 0:
		return amount
	if r >= 1.0:
		return 0
	return maxi(1, roundi(amount * (1.0 - r)))

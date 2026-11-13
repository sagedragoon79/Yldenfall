class_name Condition
extends RefCounted
## What a blow can leave behind (design bible 5.6). A source names one with
## `const CONDITION`; the hero's Hardiness gems give each a chance not to take
## hold, and all of them together never past RESIST_CAP. A condition is never
## the blow's own damage: armor and Warding answer that.

const POISON := "poison"
## Damage over time; water puts it out.
const BURN := "burn"
## Slower on your feet.
const CHILL := "chill"
## The flask will not open.
const CURSE := "curse"
const ALL := [POISON, BURN, CHILL, CURSE]
const RESIST_CAP := 1.0
## The cast each lays over the hero, and the line said when it takes hold.
const COLORS := {POISON: Color("8fd14f"), BURN: Color("ff8a3a"), CHILL: Color("9adcf5"), CURSE: Color("a070d8")}
const TAKES := {POISON: "Poisoned!", BURN: "You are burning! Water puts it out.", CHILL: "Chilled: your legs are slow.", CURSE: "Cursed: your flask will not open."}
const FADES := {BURN: "The burning stops.", CHILL: "The chill leaves you.", CURSE: "The curse lifts."}


## The condition `source`'s blows carry ("" for none).
static func of(source: Object) -> String:
	if source == null:
		return ""
	var c: Variant = source.get("CONDITION")
	return c if c is String else ""


## `hardiness` (condition to 0..1) held to the rules: each 0 to 1, and no more
## than RESIST_CAP in all. Past the cap every one is scaled down alike.
static func capped(hardiness: Dictionary) -> Dictionary:
	var out := {}
	var total := 0.0
	for c: String in ALL:
		var v := clampf(float(hardiness.get(c, 0.0)), 0.0, 1.0)
		if v > 0.0:
			out[c] = v
			total += v
	if total > RESIST_CAP:
		for c: String in out:
			out[c] = float(out[c]) * RESIST_CAP / total
	return out

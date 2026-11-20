class_name Sheet
extends RefCounted
## Reads the code-generated character sheets in assets/sprites/ (written by
## tools/art/pixelrig.py): <name>.png, <name>_mask.png (flat silhouette) and
## <name>.json (cell size, origin, and per animation its row, frames with
## metadata, playback sequence, fps and loop). Cached per name.
##
## A sheet with "density": 2 is drawn at double detail: its cells and origin
## are in sheet pixels, two per world pixel (GameCamera.DETAIL), while frame
## metadata (hand, neck, eye) stays in world pixels.

const DIR := "res://assets/sprites/"

static var _cache := {}


static func exists(name: String) -> bool:
	return ResourceLoader.exists(DIR + name + ".json")


## {"tex", "mask", "cell": Vector2, "origin": Vector2, "density": float, "animations"}.
static func get_sheet(name: String) -> Dictionary:
	if not _cache.has(name):
		var d: Dictionary = (load(DIR + name + ".json") as JSON).data
		_cache[name] = {
			"tex": load(DIR + name + ".png"),
			"mask": load(DIR + name + "_mask.png"),
			"cell": Vector2(d.cell[0], d.cell[1]),
			"origin": Vector2(d.origin[0], d.origin[1]),
			"columns": int(d.columns),
			"density": float(d.get("density", 1)),
			"own_palette": bool(d.get("own_palette", false)),
			"flags": d.get("flags", {}),
			"animations": d.animations,
		}
	return _cache[name]


## A sheet-wide switch from the manifest's "flags" (e.g. "scarf": false).
static func flag(name: String, key: String, default: Variant) -> Variant:
	return get_sheet(name).flags.get(key, default)


static func has_anim(name: String, anim: String) -> bool:
	return get_sheet(name).animations.has(anim)


## The frame of `anim` shown `t` seconds into it.
static func frame_at(name: String, anim: String, t: float) -> int:
	var a: Dictionary = get_sheet(name).animations[anim]
	var seq: Array = a.seq
	var i := int(t * float(a.fps))
	i = i % seq.size() if a.loop else mini(i, seq.size() - 1)
	return int(seq[i])


## True once a non-looping animation has played through.
static func finished(name: String, anim: String, t: float) -> bool:
	var a: Dictionary = get_sheet(name).animations[anim]
	return not a.loop and t * float(a.fps) >= float(a.seq.size())


static func length(name: String, anim: String) -> float:
	var a: Dictionary = get_sheet(name).animations[anim]
	return float(a.seq.size()) / float(a.fps)


static func info(name: String, anim: String, frame: int) -> Dictionary:
	return get_sheet(name).animations[anim].frames[frame]


static func region(name: String, anim: String, frame: int) -> Rect2:
	var s := get_sheet(name)
	var cell: Vector2 = s.cell
	return Rect2(Vector2(frame, float(s.animations[anim].row)) * cell, cell)


## Draws a frame with the sheet's origin at (0, 0). `flat` draws the
## silhouette instead, tinted (hit flashes, afterimages).
static func draw(ci: CanvasItem, name: String, anim: String, frame: int, tint := Color.WHITE, flat := false) -> void:
	var s := get_sheet(name)
	var tex: Texture2D = s.mask if flat else s.tex
	ci.draw_texture_rect_region(tex, dest_rect(name), region(name, anim, frame), tint)


## Draws only `part` of a frame (a rectangle in the cell's own pixels, clipped to
## the cell), where the whole frame would have put it.
static func draw_part(ci: CanvasItem, name: String, anim: String, frame: int, part: Rect2, tint := Color.WHITE, flat := false) -> void:
	var s := get_sheet(name)
	var p := part.intersection(Rect2(Vector2.ZERO, s.cell as Vector2))
	if p.size.x <= 0.0 or p.size.y <= 0.0:
		return
	var tex: Texture2D = s.mask if flat else s.tex
	var k: float = 1.0 / s.density
	var src := Rect2(region(name, anim, frame).position + p.position, p.size)
	ci.draw_texture_rect_region(tex, Rect2(dest_rect(name).position + p.position * k, p.size * k), src, tint)


## Where a frame lands, in world pixels relative to the origin: a density-2
## cell covers half as many world pixels as it has sheet pixels.
static func dest_rect(name: String) -> Rect2:
	var s := get_sheet(name)
	var k: float = 1.0 / s.density
	return Rect2(-(s.origin as Vector2) * k, (s.cell as Vector2) * k)

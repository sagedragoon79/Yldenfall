class_name UiArt
extends RefCounted
## The menus' pictures (design bible 12.44): an icon for every item and a
## portrait for every person with a look, both drawn by tools/art/icongen.py at
## 2x density like the HUD's icons, so one texel is half a UI pixel.

const ICONS := "res://assets/ui/item_icons"
const PORTRAITS := "res://assets/ui/portraits"
## An icon's side in UI pixels.
const ICON_SIZE := 14.0
## A portrait's side in UI pixels.
const PORTRAIT_SIZE := 40.0
## A picture on a row you can't choose is drawn this faint.
const DIM := Color(1, 1, 1, 0.4)

static var _atlases := {}


## {texture, cell, columns, index: {id: n}} for one atlas, read once.
static func _atlas(path: String, key: String) -> Dictionary:
	if not _atlases.has(path):
		var out := {"texture": null, "cell": 1, "columns": 1, "index": {}}
		var file := FileAccess.open(path + ".json", FileAccess.READ)
		if file != null and ResourceLoader.exists(path + ".png"):
			var meta: Dictionary = JSON.parse_string(file.get_as_text())
			out.texture = load(path + ".png") as Texture2D
			out.cell = int(meta.cell)
			out.columns = int(meta.columns)
			out.index = meta[key]
		_atlases[path] = out
	return _atlases[path]


static func _region(a: Dictionary, id: String) -> Rect2:
	var n := int(a.index[id])
	return Rect2((n % int(a.columns)) * a.cell, (n / int(a.columns)) * a.cell, a.cell, a.cell)


static func has_icon(item_id: String) -> bool:
	var a := _atlas(ICONS, "items")
	return a.texture != null and a.index.has(item_id)


## Where an item's icon sits in the atlas, in texels (an empty Rect2 if it has none).
static func icon_region(item_id: String) -> Rect2:
	return _region(_atlas(ICONS, "items"), item_id) if has_icon(item_id) else Rect2()


static func icon_texture() -> Texture2D:
	return _atlas(ICONS, "items").texture


## Draws an item's icon with its top left corner at `pos`, ICON_SIZE UI pixels
## square. Returns false, and draws nothing, for an item with no icon.
static func draw_icon(ci: CanvasItem, item_id: String, pos: Vector2, modulate := Color.WHITE) -> bool:
	if not has_icon(item_id):
		return false
	ci.draw_texture_rect_region(icon_texture(), Rect2(pos.round(), Vector2.ONE * ICON_SIZE), icon_region(item_id), modulate)
	return true


static func has_portrait(npc_id: String) -> bool:
	var a := _atlas(PORTRAITS, "people")
	return a.texture != null and a.index.has(npc_id)


static func portrait_region(npc_id: String) -> Rect2:
	return _region(_atlas(PORTRAITS, "people"), npc_id) if has_portrait(npc_id) else Rect2()


static func portrait_texture() -> Texture2D:
	return _atlas(PORTRAITS, "people").texture


## Draws a person's portrait with its top left corner at `pos`, PORTRAIT_SIZE UI
## pixels square. Returns false, and draws nothing, for someone with none.
static func draw_portrait(ci: CanvasItem, npc_id: String, pos: Vector2) -> bool:
	if not has_portrait(npc_id):
		return false
	ci.draw_texture_rect_region(portrait_texture(), Rect2(pos.round(), Vector2.ONE * PORTRAIT_SIZE), portrait_region(npc_id))
	return true

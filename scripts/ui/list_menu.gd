class_name ListMenu
extends Control
## A centered panel with a title, a list of rows and a description of the
## selected row. Shops, the Ringreader and the skill tree all use it. The game is
## paused while it is open.
##
## Rows come from a provider callable (so they refresh after each choice):
## each row is {label, right (text on the right), detail, enabled, header, icon,
## compare (a shop's ware against what you have: Menus.compare)}.
## Header rows are section titles and can't be selected. A row's `icon` is an
## item id: its picture leads the row (UiArt, bible 12.44), and when any row has
## one every label is set in by ICON_INSET so the names stay in a column.
##
## Optional hooks, cleared on each open(): `on_adjust(index, step)` runs on
## Left/Right (option values), `on_back` runs instead of closing on Dash (sub
## menus), and `capture(event)` takes the next key or pad button press (rebinding).
##
## The panel's corner names its controls as key caps (pass 594, bible 12.79): the
## key or pad button the action is bound to, drawn in a small frame, then a verb
## that says what it does here ("Buy", "Leave"). Set `confirm_verb` and
## `back_verb` after open(); both reset on each open().

signal closed

const PANEL := Rect2(150, 46, 340, 268)
const BG := Color(0.07, 0.06, 0.11, 0.95)
const BORDER := Color("c9b98f")
const TEXT := Color("f1ead2")
const DIM := Color("6b6380")
const ACCENT := Color("ffd24a")
const CURSOR := Color(1, 0.86, 0.4, 0.14)
const ROW_H := 16.0
const INPUT_GRACE := 0.12
## How far a label moves right in a list whose rows carry icons.
const ICON_INSET := 18.0
## The frame around a portrait, and its gap from the panel's corner.
const PORTRAIT_PAD := 2.0
const PORTRAIT_MARGIN := 10.0
const PORTRAIT_BACK := Color("2a2440")
## The frame (pass 605): the pass 600 grade saw the shop as "a plain dark box, two
## thirds empty, with a thin flat border". Every menu now wears a double frame, a
## dark line either side of the light one, with gold corner brackets (`BRACKET` px,
## as the HUD's plate and the minimap wear them) and a rule under its heading.
const FRAME_DARK := Color("1d1a2b")
const BRACKET := 8.0
const BRACKET_COLOR := Color("d8b060")
## The counter (pass 605): in a list of items with room to spare below its rows,
## the chosen item stands on a lit shelf at COUNTER_SCALE times its icon's size, so
## a shop of three wares no longer leaves its middle empty. It needs COUNTER_MIN
## px of room.
const COUNTER_SCALE := 3.0
const COUNTER_MIN := 56.0
## The comparison (pass 616, bible 12.93): when the chosen row carries a `compare`,
## its item stands COMPARE_ICON_AT of the way along the counter and a table of
## what you have against what it gives fills the counter from COMPARE_FROM on.
const COMPARE_ICON_AT := 0.2
const COMPARE_FROM := 0.4
const COMPARE_MARGIN := 10.0
const COMPARE_LINE := 11.0
## The room right of the `now` column for the mark that points up or down.
const COMPARE_MARK := 12.0
const BETTER := Color("9bd66a")
const WORSE := Color("e0605a")
## The lamplight pooled on the counter: a smooth radial glow, never hard rings.
const COUNTER_LIGHT := Color(1.0, 0.82, 0.45, 0.22)
static var _glow: GradientTexture2D
const SHELF := Color("5a4a3c")
const SHELF_LIT := Color("8a7458")
## The portrait's backing, lit warm from above like a shop's lamp (pass 605).
const PORTRAIT_LAMP := Color("4a3a4e")
## The key caps in the panel's corner.
const CAP_FACE := Color("2a2440")
const CAP_EDGE := Color("8a7f9e")
const CAP_TEXT := Color("f1ead2")
const CAP_SHADOW := Color(0, 0, 0, 0.6)
## The pixel font's ascent and the descent its letters use (assets/fonts/pixel.json).
const CAP_ASCENT := 8
const CAP_DESCENT := 2
const CAP_PAD := 2.0
const CAP_GAP := 3.0
const PROMPT_GAP := 9.0
## Default verbs: confirm a row, and back out (a sub menu) or close.
const CONFIRM_VERB := "Choose"
const BACK_VERB := "Back"
const CLOSE_VERB := "Close"

var title := ""
var subtitle := ""
var rows: Array = []
var cursor := 0
var is_open := false
## Where the panel sits; menus may move it (the title menu sits under the logo).
var panel := PANEL
## The person whose menu this is (an id in data/npcs.json): their portrait sits
## in the panel's top right corner. Cleared on each open(); set it after.
var portrait := ""
## What confirming a row does here ("Buy", "Learn"); "" for a page you only read.
## Reset on each open().
var confirm_verb := CONFIRM_VERB
## What backing out does here ("Leave"); "" picks Back or Close. Reset on each open().
var back_verb := ""

var on_adjust := Callable()
var on_back := Callable()
var capture := Callable()
## The frame the menu last closed on, so the key that closed it can't reopen it.
var closed_frame := -1

var _provider: Callable
var _on_select: Callable
var _footer: Callable
var _grace := 0.0
var _scroll := 0
var _flash := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group("list_menu")
	visible = false


## Opens the menu. `provider` returns the rows; `on_select(index)` runs on
## confirm; `footer` returns a status line (gold, points).
func open(menu_title: String, menu_subtitle: String, provider: Callable, on_select: Callable, footer := Callable()) -> void:
	title = menu_title
	subtitle = menu_subtitle
	_provider = provider
	_on_select = on_select
	_footer = footer
	on_adjust = Callable()
	on_back = Callable()
	capture = Callable()
	portrait = ""
	confirm_verb = CONFIRM_VERB
	back_verb = ""
	cursor = 0
	_scroll = 0
	refresh()
	_skip_headers(1)
	is_open = true
	visible = true
	_grace = INPUT_GRACE
	get_tree().paused = true


func refresh() -> void:
	rows = _provider.call()
	cursor = clampi(cursor, 0, maxi(rows.size() - 1, 0))


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	capture = Callable()
	closed_frame = Engine.get_process_frames()
	get_tree().paused = false
	closed.emit()


## Runs the selected row's action. Disabled rows buzz and flash.
func confirm() -> void:
	if rows.is_empty():
		return
	var row: Dictionary = rows[cursor]
	if not row.get("enabled", true):
		_flash = 0.25
		Sfx.play("menu_refuse", 0.0, -4.0)
		return
	_on_select.call(cursor)
	if is_open:
		refresh()


func move(step: int) -> void:
	if rows.is_empty():
		return
	cursor = wrapi(cursor + step, 0, rows.size())
	_skip_headers(step)
	Sfx.play("blip", 0.0, -8.0)


func _skip_headers(step: int) -> void:
	for i in rows.size():
		if not rows[cursor].get("header", false):
			return
		cursor = wrapi(cursor + step, 0, rows.size())


## Left/Right on the selected row, for menus with values.
func adjust(step: int) -> void:
	if rows.is_empty() or not on_adjust.is_valid() or not rows[cursor].get("enabled", true):
		return
	on_adjust.call(cursor, step)
	Sfx.play("blip", 0.0, -6.0)
	if is_open:
		refresh()


## Dash, Block or Pause: back out of a sub menu, or close.
func back() -> void:
	if on_back.is_valid():
		on_back.call()
	else:
		close()


func _input(event: InputEvent) -> void:
	if not is_open or not capture.is_valid():
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	if key or (event is InputEventJoypadButton and event.pressed):
		get_viewport().set_input_as_handled()
		var take := capture
		capture = Callable()
		_grace = INPUT_GRACE
		take.call(event)
		if is_open:
			refresh()


func _process(delta: float) -> void:
	if not is_open:
		return
	# Screens are read in real time (pass 483): the Game speed option, slow
	# motion and hitstop slow the game, not its words and menus.
	delta = Feel.unscaled(delta)
	_grace -= delta
	_flash = maxf(_flash - delta, 0.0)
	if _grace <= 0.0 and not capture.is_valid():
		if Input.is_action_just_pressed("move_down"):
			move(1)
		elif Input.is_action_just_pressed("move_up"):
			move(-1)
		elif Input.is_action_just_pressed("move_left"):
			adjust(-1)
		elif Input.is_action_just_pressed("move_right"):
			adjust(1)
		elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack"):
			confirm()
		elif Input.is_action_just_pressed("dash") or Input.is_action_just_pressed("block") or Input.is_action_just_pressed("pause"):
			back()
	queue_redraw()


## Whether the portrait is shown: someone is named and has one.
func shows_portrait() -> bool:
	return portrait != "" and UiArt.has_portrait(portrait)


## The portrait's frame, in the panel's top right corner.
func portrait_frame() -> Rect2:
	var side := UiArt.PORTRAIT_SIZE + PORTRAIT_PAD * 2.0
	return Rect2(panel.end.x - PORTRAIT_MARGIN - side, panel.position.y + PORTRAIT_MARGIN, side, side)


## How wide the subtitle may run: up to the portrait when there is one.
func subtitle_width() -> float:
	return panel.size.x - 28.0 - (portrait_frame().size.x + 8.0 if shows_portrait() else 0.0)


## Where the rows begin (below the heading, the subtitle and any portrait), in
## panel space, as `_draw` lays them out.
func rows_top() -> float:
	var y := panel.position.y + 22 + 14
	if subtitle != "":
		var lines := PixelFont.wrap_lines(subtitle, subtitle_width(), 9).size()
		y += (PixelFont.height() + 1) * lines + 2
	y += 4
	if shows_portrait():
		y = maxf(y, portrait_frame().end.y + 6.0)
	return y


## The description box at the panel's foot.
func detail_box() -> Rect2:
	return Rect2(panel.position.x + 8, panel.end.y - 62, panel.size.x - 16, 38)


## The counter where the chosen item stands (pass 605): the room between the last
## row and the description, when the rows carry icons, the chosen row has one and
## there is at least COUNTER_MIN px of room. Rect2() when there is none.
func counter_rect(top: float = -1.0) -> Rect2:
	if rows.is_empty() or not has_icons():
		return Rect2()
	if String(rows[cursor].get("icon", "")) == "" or not UiArt.has_icon(String(rows[cursor].icon)):
		return Rect2()
	var start := rows_top() if top < 0.0 else top
	var fit := maxi(1, int((panel.end.y - 66 - start) / ROW_H))
	var shown := mini(rows.size() - _scroll, fit)
	var below := start + shown * ROW_H + 2.0
	var room := detail_box().position.y - 2.0 - below
	if room < COUNTER_MIN:
		return Rect2()
	return Rect2(panel.position.x + 8, below, panel.size.x - 16, room)


## The item on the counter (pass 605), or "" when there is no counter.
func counter_item() -> String:
	return String(rows[cursor].icon) if counter_rect() != Rect2() else ""


## What the chosen row is weighed against (pass 616): its `compare`, {caption, rows},
## or {} when the row has none or there is no counter to show it on.
func compare_shown() -> Dictionary:
	if rows.is_empty() or counter_rect() == Rect2():
		return {}
	var against: Dictionary = rows[cursor].get("compare", {})
	return against if not Array(against.get("rows", [])).is_empty() else {}


## Where the chosen item stands on the counter `r`: its middle, or COMPARE_ICON_AT
## of the way along when a comparison takes the rest (pass 616).
func counter_center(r: Rect2) -> Vector2:
	var c := r.get_center()
	if not compare_shown().is_empty():
		c.x = roundf(r.position.x + r.size.x * COMPARE_ICON_AT)
	return c


## The comparison's table on the counter `r`: the part right of the item.
func compare_rect(r: Rect2) -> Rect2:
	var left := roundf(r.position.x + r.size.x * COMPARE_FROM)
	return Rect2(left, r.position.y, r.end.x - COMPARE_MARGIN - left, r.size.y)


## The comparison as it is laid out in `t`, for drawing and for tests: each line
## is {y (baseline), caption} or {y, label, was, now, dir}, with the columns'
## right edges in `was_x` and `now_x`, the arrow's left in `arrow_x` and the
## mark's middle in `mark_x`. Lines that do not fit are left out.
func compare_layout(t: Rect2) -> Dictionary:
	var against := compare_shown()
	var lines := []
	if String(against.get("caption", "")) != "":
		lines.append({"caption": String(against.caption)})
	lines.append_array(Array(against.get("rows", [])))
	lines = lines.slice(0, maxi(1, int(t.size.y / COMPARE_LINE)))
	var top := roundf(t.get_center().y - lines.size() * COMPARE_LINE * 0.5)
	var now_w := 0.0
	var out := []
	for i in lines.size():
		var line: Dictionary = lines[i].duplicate()
		line["y"] = top + i * COMPARE_LINE + 9.0
		now_w = maxf(now_w, PixelFont.width(String(line.get("now", "")), 9))
		out.append(line)
	var now_x := t.end.x - COMPARE_MARK
	var arrow_x := now_x - now_w - 12.0
	return {"lines": out, "now_x": now_x, "arrow_x": arrow_x, "was_x": arrow_x - 5.0, "mark_x": t.end.x - 4.0}


## Draws the comparison: what you have, an arrow, what the ware gives, and a mark
## that points up (better) or down (worse), so color is never the only sign.
func _draw_compare(t: Rect2) -> void:
	var lay := compare_layout(t)
	var soft := DIM.lightened(0.45)
	for line: Dictionary in lay.lines:
		var y: float = line.y
		if line.has("caption"):
			_text(Vector2(t.position.x, y), String(line.caption), 9, soft)
			continue
		var dir := int(line.get("dir", 0))
		var tone := BETTER if dir > 0 else (WORSE if dir < 0 else TEXT)
		_text(Vector2(t.position.x, y), String(line.label), 9, Color("c9b98f"))
		var now := String(line.now)
		_text(Vector2(lay.now_x - PixelFont.width(now, 9), y), now, 9, tone)
		var was := String(line.get("was", ""))
		if was != "":
			_text(Vector2(lay.was_x - PixelFont.width(was, 9), y), was, 9, soft)
			var ax: float = lay.arrow_x
			draw_rect(Rect2(ax, y - 4.0, 5.0, 1.0), soft)
			draw_colored_polygon(PackedVector2Array([Vector2(ax + 4.0, y - 6.5), Vector2(ax + 7.0, y - 3.5), Vector2(ax + 4.0, y - 0.5)]), soft)
		var mx: float = lay.mark_x
		if dir > 0:
			draw_colored_polygon(PackedVector2Array([Vector2(mx - 3.0, y - 1.0), Vector2(mx, y - 6.0), Vector2(mx + 3.0, y - 1.0)]), BETTER)
		elif dir < 0:
			draw_colored_polygon(PackedVector2Array([Vector2(mx - 3.0, y - 6.0), Vector2(mx, y - 1.0), Vector2(mx + 3.0, y - 6.0)]), WORSE)


## Draws the chosen item on its shelf in `r`, in a pool of lamplight.
func _draw_counter(r: Rect2) -> void:
	var side := UiArt.ICON_SIZE * COUNTER_SCALE
	var c := counter_center(r)
	if not compare_shown().is_empty():
		_draw_compare(compare_rect(r))
	# The icon's art stops a few texels short of its cell's foot, so the shelf
	# rises into the cell and the item stands on it.
	var shelf_y := roundf(c.y + side * 0.5 - 3.0)
	var glow := ListMenu.counter_glow()
	draw_texture_rect(glow, Rect2(c.x - side, shelf_y - side * 1.45, side * 2.0, side * 2.0), false)
	draw_rect(Rect2(c.x - side * 0.7, shelf_y + 3.0, side * 1.4, 1.0), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(c.x - side * 0.65, shelf_y, side * 1.3, 3.0), SHELF)
	draw_rect(Rect2(c.x - side * 0.65, shelf_y, side * 1.3, 1.0), SHELF_LIT)
	var at := Vector2(roundf(c.x - side * 0.5), shelf_y - side + 3.0)
	var id := String(rows[cursor].icon)
	var enabled: bool = rows[cursor].get("enabled", true)
	draw_texture_rect_region(UiArt.icon_texture(), Rect2(at, Vector2.ONE * side), UiArt.icon_region(id), Color.WHITE if enabled else UiArt.DIM)


## The counter's pool of lamplight: a radial gradient from COUNTER_LIGHT at the
## middle to clear at the rim, made once.
static func counter_glow() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, COUNTER_LIGHT)
		g.set_color(1, Color(COUNTER_LIGHT, 0.0))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 64
		_glow.height = 64
	return _glow


## The gold corner brackets of the frame, as rects (pass 605).
func frame_brackets() -> Array[Rect2]:
	return Minimap.bracket_rects(panel.grow(3), BRACKET)


## Whether any row carries an icon, so every label is set in.
func has_icons() -> bool:
	for row: Dictionary in rows:
		if String(row.get("icon", "")) != "" and UiArt.has_icon(String(row.icon)):
			return true
	return false


## Where row `index`'s icon goes for rows starting at `y` (its top left corner).
func icon_pos(index: int, y: float) -> Vector2:
	return Vector2(panel.position.x + 14.0, y + (index - _scroll) * ROW_H + floorf((ROW_H - 1.0 - UiArt.ICON_SIZE) * 0.5))


func _draw() -> void:
	if not is_open:
		return
	draw_rect(panel.grow(3), FRAME_DARK)
	draw_rect(panel.grow(2), BORDER)
	draw_rect(panel.grow(1), FRAME_DARK)
	draw_rect(panel, BG)
	for b: Rect2 in frame_brackets():
		draw_rect(b, BRACKET_COLOR)
	var x := panel.position.x + 14
	var y := panel.position.y + 22
	_text(Vector2(x, y), title, 14, ACCENT)
	y += 14
	if subtitle != "":
		var lines := PixelFont.draw_wrapped(self, Vector2(x, y), subtitle, subtitle_width(), 9, Color("c9b98f"), 1)
		y += (PixelFont.height() + 1) * lines + 2
	y += 4
	if shows_portrait():
		var frame := portrait_frame()
		draw_rect(frame.grow(2), FRAME_DARK)
		draw_rect(frame.grow(1), BORDER)
		draw_rect(frame, PORTRAIT_BACK)
		# Lamplight from above: four bands from the lamp's warmth down to the dark.
		for k in 4:
			var band := Rect2(frame.position.x, frame.position.y + frame.size.y * k / 8.0, frame.size.x, frame.size.y / 8.0)
			draw_rect(band, PORTRAIT_LAMP.lerp(PORTRAIT_BACK, k / 4.0))
		UiArt.draw_portrait(self, portrait, frame.position + Vector2.ONE * PORTRAIT_PAD)
		for b: Rect2 in Minimap.bracket_rects(frame.grow(2), 4.0):
			draw_rect(b, BRACKET_COLOR)
		# The rows start under the portrait, so no price runs behind it.
		y = maxf(y, frame.end.y + 6.0)
	# A rule under the heading, from a small diamond, so the list stands apart from it.
	var rule_y := roundf(y - 4.0)
	draw_rect(Rect2(x, rule_y, panel.end.x - 14 - x, 1), Color(BORDER, 0.22))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 6, rule_y + 0.5), Vector2(x - 3, rule_y - 2.5), Vector2(x, rule_y + 0.5), Vector2(x - 3, rule_y + 3.5)]), Color(BRACKET_COLOR, 0.8))
	var inset := ICON_INSET if has_icons() else 0.0
	# Long lists scroll to keep the cursor in view.
	var fit := maxi(1, int((panel.end.y - 66 - y) / ROW_H))
	if cursor < _scroll:
		_scroll = cursor
	elif cursor >= _scroll + fit:
		_scroll = cursor - fit + 1
	_scroll = clampi(_scroll, 0, maxi(rows.size() - fit, 0))
	if _scroll > 0:
		_text(Vector2(panel.end.x - 18, y - 2), "^", 9, DIM.lightened(0.3))
	if _scroll + fit < rows.size():
		_text(Vector2(panel.end.x - 18, y + fit * ROW_H + 4), "v", 9, DIM.lightened(0.3))
	for i in range(_scroll, mini(rows.size(), _scroll + fit)):
		var row: Dictionary = rows[i]
		var top := y + (i - _scroll) * ROW_H
		if row.get("header", false):
			_text(Vector2(x, top + 11), String(row.label).to_upper(), 8, DIM.lightened(0.3))
			continue
		var enabled: bool = row.get("enabled", true)
		if i == cursor:
			var c := CURSOR if _flash <= 0.0 else Color(0.9, 0.25, 0.3, 0.3)
			draw_rect(Rect2(panel.position.x + 6, top, panel.size.x - 12, ROW_H - 1), c)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 6, top + 4), Vector2(x - 2, top + 7.5), Vector2(x - 6, top + 11)]), ACCENT)
		if inset > 0.0:
			UiArt.draw_icon(self, String(row.get("icon", "")), icon_pos(i, y), Color.WHITE if enabled else UiArt.DIM)
		_text(Vector2(x + 2 + inset, top + 12), row.label, 10, TEXT if enabled else DIM)
		var right: String = row.get("right", "")
		if right != "":
			var w := PixelFont.width(right, 10)
			_text(Vector2(panel.end.x - 14 - w, top + 12), right, 10, ACCENT if enabled else DIM)
	# The chosen item on its counter, in the room the rows leave.
	var counter := counter_rect(y)
	if counter != Rect2():
		_draw_counter(counter)
	# Description of the selected row.
	var detail: String = rows[cursor].get("detail", "") if not rows.is_empty() else ""
	var box := detail_box()
	draw_rect(box, Color(1, 1, 1, 0.04))
	PixelFont.draw_wrapped(self, box.position + Vector2(6, 12), detail, box.size.x - 12, 9, Color("c9b98f"), 1)
	var foot: String = _footer.call() if _footer.is_valid() else ""
	_text(Vector2(x, panel.end.y - 9), foot, 9, ACCENT)
	_draw_prompts(Vector2(panel.end.x - 14, panel.end.y - 9))


## The controls named in the panel's corner, in order: each is {cap, verb}, where
## `cap` is the bound key or pad button and "" means the verb stands alone.
func prompts() -> Array:
	if capture.is_valid():
		return [{"cap": "", "verb": "Press a key or button"}, {"cap": cap_name("pause"), "verb": "Cancel"}]
	var out: Array = []
	if on_adjust.is_valid():
		out.append({"cap": cap_name("move_left") + "/" + cap_name("move_right"), "verb": "Change"})
	elif not rows.is_empty() and confirm_verb != "":
		out.append({"cap": cap_name("jump"), "verb": confirm_verb})
	var back_word := back_verb if back_verb != "" else (BACK_VERB if on_back.is_valid() else CLOSE_VERB)
	out.append({"cap": cap_name("dash"), "verb": back_word})
	return out


## What a key cap shows for `action`: its pad button while a pad is plugged in,
## else its first key, in short ("Space", "C", "A", "<" for Left).
static func cap_name(action: String) -> String:
	var pad := not Input.get_connected_joypads().is_empty()
	var name: String = Controls.button_name(action) if pad else Controls.key_name(action)
	if pad and name == "-":
		name = Controls.key_name(action)
	match name:
		"Left", "Pad left":
			return "<"
		"Right", "Pad right":
			return ">"
	return name


## How wide prompts() draws, so the row can sit flush right.
func prompts_width() -> float:
	var w := 0.0
	for pr: Dictionary in prompts():
		if w > 0.0:
			w += PROMPT_GAP
		if String(pr.cap) != "":
			w += PixelFont.width(pr.cap, 8) + CAP_PAD * 2.0 + CAP_GAP
		w += PixelFont.width(pr.verb, 8)
	return w


## A key cap's frame for text `w` wide (padding included) with its baseline at
## `base`: two rows clear above a capital and below it, where a "p" descends.
static func cap_rect_at(x: float, base: float, w: float) -> Rect2:
	var top := base - float(CAP_ASCENT) - 2.0
	return Rect2(x, top, roundf(w), float(CAP_ASCENT + CAP_DESCENT) + 3.0)


## Draws the prompts ending at `right_base` (the text's baseline at its right end).
func _draw_prompts(right_base: Vector2) -> void:
	var x := right_base.x - prompts_width()
	var base := right_base.y
	for pr: Dictionary in prompts():
		var cap := String(pr.cap)
		if cap != "":
			var cw := PixelFont.width(cap, 8) + CAP_PAD * 2.0
			var cap_rect := cap_rect_at(roundf(x), base, cw)
			# A drop shadow under the cap, so it reads as a key, not a box.
			draw_rect(Rect2(cap_rect.position + Vector2(1, cap_rect.size.y), Vector2(cap_rect.size.x, 1)), CAP_SHADOW)
			draw_rect(cap_rect, CAP_EDGE)
			draw_rect(cap_rect.grow(-1), CAP_FACE)
			_text(Vector2(roundf(x) + CAP_PAD, base), cap, 8, CAP_TEXT)
			x += cw + CAP_GAP
		_text(Vector2(x, base), String(pr.verb), 8, DIM.lightened(0.35))
		x += PixelFont.width(String(pr.verb), 8) + PROMPT_GAP


func _text(pos: Vector2, s: String, size: int, color: Color) -> void:
	PixelFont.draw(self, pos, s, size, color)

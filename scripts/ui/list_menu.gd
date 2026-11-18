class_name ListMenu
extends Control
## A centered panel with a title, a list of rows and a description of the
## selected row. Shops, the Ringreader and the skill tree all use it. The game is
## paused while it is open.
##
## Rows come from a provider callable (so they refresh after each choice):
## each row is {label, right (text on the right), detail, enabled, header, icon}.
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
	draw_rect(panel.grow(2), BORDER)
	draw_rect(panel, BG)
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
		draw_rect(frame.grow(1), BORDER)
		draw_rect(frame, PORTRAIT_BACK)
		UiArt.draw_portrait(self, portrait, frame.position + Vector2.ONE * PORTRAIT_PAD)
		# The rows start under the portrait, so no price runs behind it.
		y = maxf(y, frame.end.y + 6.0)
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
	# Description of the selected row.
	var detail: String = rows[cursor].get("detail", "") if not rows.is_empty() else ""
	var box := Rect2(panel.position.x + 8, panel.end.y - 62, panel.size.x - 16, 38)
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

extends TestSuite
## Ground movement and jump feel: the numbers in design bible section 6.

const FLAT := [
	"##############################",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"##############################",
]

const LEDGE := [
	"#####################",
	"#...................#",
	"#...................#",
	"#...................#",
	"#####...............#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#####################",
]


func _settle(p: Player) -> void:
	await frames(6)


func test_settles_on_floor() -> void:
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(3, 11))
	await _settle(p)
	check(p.is_on_floor(), "player should rest on the floor")


func test_run_speed_and_acceleration() -> void:
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(3, 11))
	await _settle(p)
	var t := p.tuning
	var frames_to_max := -1
	for i in 30:
		p.input.move_x = 1
		await frames(1)
		if frames_to_max < 0 and is_equal_approx(p.velocity.x, t.run_speed):
			frames_to_max = i + 1
	check_near(p.velocity.x, t.run_speed, 0.01, "max run speed")
	check(frames_to_max > 0 and frames_to_max <= 7, "reaches max speed within 7 frames (got %d)" % frames_to_max)
	# Releasing stops quickly.
	var stop_frames := 0
	p.input.move_x = 0
	while absf(p.velocity.x) > 0.0 and stop_frames < 30:
		await frames(1)
		stop_frames += 1
	check(stop_frames <= 5, "stops within 5 frames (got %d)" % stop_frames)


## Pass 183 (Sean): a stick walks into a run the farther it leans. A light tilt
## walks at 40% of a run, the pace climbs with the tilt, and a full lean (or a
## key, or the d-pad) is the same run as ever, so jumps and dashes don't change.
func test_the_stick_walks_into_a_run_the_farther_it_leans() -> void:
	var t := MovementTuning.new()
	check(t.walk_fraction == 0.4 and t.walk_tilt == 0.45 and t.run_tilt == 0.9, "the bible's walk numbers (6.1)")
	check(t.speed_fraction(0.2) == 0.4 and t.speed_fraction(0.45) == 0.4, "a light tilt walks")
	check_near(t.speed_fraction(0.675), 0.7, 0.001, "halfway up the band, halfway to a run")
	check(t.speed_fraction(0.9) == 1.0 and t.speed_fraction(1.0) == 1.0, "near full tilt, a full run")
	var last := 0.0
	var climbs := true
	for i in 21:
		var f := t.speed_fraction(i / 20.0)
		climbs = climbs and f >= last
		last = f
	check(climbs, "the pace never drops as the stick leans further")
	# The real input: keys are full tilt; a stick's lean comes through.
	var input := PlayerInput.new()
	Input.action_press("move_right")
	input.poll()
	check(input.move_x == 1 and input.tilt == 1.0, "a key runs (tilt %.2f)" % input.tilt)
	Input.action_release("move_right")
	Input.action_press("move_left", 0.3)
	input.poll()
	check(input.move_x == -1 and is_equal_approx(input.tilt, 0.3), "a stick leaned 0.3 left walks (tilt %.2f)" % input.tilt)
	Input.action_release("move_left")
	input.poll()
	check(input.move_x == 0 and input.tilt == 1.0, "let go, nothing")
	# On the floor.
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(3, 11))
	await _settle(p)
	p.input.move_x = 1
	p.input.tilt = 0.3
	await frames(20)
	check_near(p.velocity.x, t.run_speed * t.walk_fraction, 0.5, "a light lean walks at %.0f px/s" % (t.run_speed * t.walk_fraction))
	check(PlayerVisual.current_pose(p) == "walk", "and looks it")
	var anim := PlayerVisual.anim_for(p, "walk")
	check(anim == ("walk" if Sheet.has_anim(PlayerVisual.sheet_for("walk"), "walk") else "run"), "the walk clip, or the run slowed until it exists (%s)" % anim)
	p.input.tilt = 1.0
	await frames(20)
	check_near(p.velocity.x, t.run_speed, 0.01, "lean all the way and it is the same run as a key")
	check(PlayerVisual.current_pose(p) == "run", "and looks it")
	p.input.move_x = 0


func test_full_jump_height_and_apex_time() -> void:
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(10, 11))
	await _settle(p)
	var start_y := p.global_position.y
	var min_y := start_y
	var apex_frame := 0
	p.input.jump_pressed = true
	p.input.jump_held = true
	for i in 70:
		await frames(1)
		if p.global_position.y < min_y:
			min_y = p.global_position.y
			apex_frame = i
	var t := p.tuning
	check_near(start_y - min_y, t.jump_height, 3.0, "full jump height (px)")
	check_near(apex_frame / 60.0, t.jump_time_to_apex, 0.07, "time to apex (s)")
	check(p.is_on_floor(), "lands again")


func test_tap_jump_is_short() -> void:
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(10, 11))
	await _settle(p)
	var start_y := p.global_position.y
	var min_y := start_y
	p.input.jump_pressed = true
	p.input.jump_held = true
	await frames(1)
	p.input.jump_held = false
	for i in 40:
		await frames(1)
		min_y = minf(min_y, p.global_position.y)
	var h := start_y - min_y
	check(h > 10.0 and h < 26.0, "tap jump height between 10 and 26 px (got %.1f)" % h)


func test_fall_speed_caps() -> void:
	var room := make_room(LEDGE)
	var p := make_player(room, Vector2i(10, 1))
	p.abilities["glove"] = false
	var max_vy := 0.0
	for i in 40:
		await frames(1)
		max_vy = maxf(max_vy, p.velocity.y)
	check(max_vy <= p.tuning.max_fall_speed + 0.01, "fall speed capped at %.0f (got %.1f)" % [p.tuning.max_fall_speed, max_vy])


func _walk_off_ledge(p: Player) -> int:
	# Runs right off the ledge; returns once the player has left the floor.
	for i in 60:
		p.input.move_x = 1
		await frames(1)
		if not p.is_on_floor():
			return i
	return -1


func test_coyote_time_allows_late_jump() -> void:
	var room := make_room(LEDGE)
	var p := make_player(room, Vector2i(2, 3), {"boots": false})
	await _settle(p)
	await _walk_off_ledge(p)
	await frames(4)  # 5 frames off the ledge = 0.083 s < 0.10 s coyote
	p.input.jump_pressed = true
	p.input.jump_held = true
	await frames(1)
	check(p.velocity.y < -300.0, "jump 5 frames after leaving the ledge (vy %.1f)" % p.velocity.y)


func test_coyote_time_expires() -> void:
	var room := make_room(LEDGE)
	var p := make_player(room, Vector2i(2, 3), {"boots": false})
	await _settle(p)
	await _walk_off_ledge(p)
	await frames(8)  # 9 frames = 0.15 s, past coyote and buffer leeway
	p.input.jump_pressed = true
	p.input.jump_held = true
	await frames(1)
	check(p.velocity.y > 0.0, "no jump 9 frames after leaving the ledge (vy %.1f)" % p.velocity.y)


func test_jump_buffer_before_landing() -> void:
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(10, 4), {"boots": false})
	var pressed := false
	var rose := false
	for i in 90:
		if not pressed and p.velocity.y > 0.0:
			# Press once the floor is about 5 frames of fall away.
			var look := Vector2(0, p.velocity.y / 60.0 * 5.0)
			if p.test_move(p.global_transform, look):
				p.input.jump_pressed = true
				p.input.jump_held = true
				pressed = true
		await frames(1)
		if pressed and p.velocity.y < -300.0:
			rose = true
			break
	check(pressed, "reached the press window")
	check(rose, "buffered jump fires on landing")


func test_corner_correction_slides_past_ceiling_edge() -> void:
	var rows := [
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"#...#......#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"############",
	]
	# Block at cell (4,4) spans x 64..80. Player half-width is 6, so x = 62 overlaps by 4 px.
	var room := make_room(rows)
	var p := make_player(room, Vector2i(3, 8))
	p.position.x = 62.0
	await _settle(p)
	var start_y := p.global_position.y
	var min_y := start_y
	p.input.jump_pressed = true
	p.input.jump_held = true
	for i in 30:
		await frames(1)
		min_y = minf(min_y, p.global_position.y)
	check(start_y - min_y > 55.0, "corner correction lets the jump continue (rise %.1f)" % (start_y - min_y))
	check(p.global_position.x <= 58.5, "nudged sideways off the corner (x %.1f)" % p.global_position.x)


func test_one_way_platform_and_drop_through() -> void:
	var rows := [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"#........#",
		"#.------.#",
		"#........#",
		"#........#",
		"#........#",
		"##########",
	]
	var room := make_room(rows)
	var p := make_player(room, Vector2i(4, 8))
	await _settle(p)
	# Jump up through the platform from below.
	p.input.jump_pressed = true
	p.input.jump_held = true
	await frames(45)
	p.input.jump_held = false
	await frames(10)
	var platform_y := 5 * Room.TILE
	check(p.is_on_floor() and absf(p.global_position.y - platform_y) < 1.5, "jumped up onto the one-way platform (y %.1f)" % p.global_position.y)
	# Down + jump drops through.
	p.input.down = true
	p.input.jump_pressed = true
	await frames(1)
	p.input.down = false
	await frames(20)
	check(p.global_position.y > platform_y + 20.0, "dropped through the platform (y %.1f)" % p.global_position.y)


## Pass 368 (bible 6.1): a thumb pushing a stick sideways drifts a little up
## or down, and past the 0.35 deadzone that drift read as Down or Up. A running
## jump on a one-way platform dropped through it, an air slash became a pogo,
## and a run past a door walked in. A stick now counts up or down only from
## `stick_vertical_angle` off level; keys and the d-pad are always as pressed.
func test_a_sideways_stick_drifting_down_is_not_down() -> void:
	var t := MovementTuning.new()
	check(t.stick_vertical_angle == 35.0, "the bible's angle (6.1)")
	var input := PlayerInput.new()
	_stick(25.0, -1.0)
	input.poll(t)
	check(Input.is_action_pressed("move_down") and input.move_x == 1 and not input.down,
		"a stick 25 degrees under level runs and is not Down")
	_stick(40.0, -1.0)
	input.poll(t)
	check(input.down and input.move_x == 1, "40 degrees under level is Down and right")
	_stick(90.0, -1.0)
	input.poll(t)
	check(input.down, "straight down is Down")
	_stick(25.0, 1.0)
	input.poll(t)
	check(not input.up and not input.up_pressed, "25 degrees over level is not Up")
	_stick(60.0, 1.0)
	input.poll(t)
	check(input.up and input.up_pressed, "swung on to 60 degrees, Up is pressed as it starts to count")
	input.poll(t)
	check(input.up and not input.up_pressed, "and held, it is not pressed again")
	input.clear()
	input.poll(t)
	check(input.up and not input.up_pressed, "nor after control comes back (a door, a dialog)")
	_stick(0.0, 0.0)
	for b: JoyButton in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT]:
		_pad(b, true)
	input.poll(t)
	check(input.down and input.move_x == 1, "the d-pad's diagonal is always Down and right")
	for b: JoyButton in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT]:
		_pad(b, false)
	# The real controller: a running jump off a one-way platform, thumb drifting.
	for case: Array in [[25.0, false], [60.0, true]]:
		var rows := ["########################################"]
		for y in 8:
			rows.append("#" + ".".repeat(38) + "#")
		rows.append("#" + "-".repeat(38) + "#")
		for y in 4:
			rows.append("#" + ".".repeat(38) + "#")
		rows.append("########################################")
		var room := make_room(rows)
		var p := make_player(room, Vector2i(4, 8))
		await _settle(p)
		var floor_y := p.global_position.y
		p.input = PlayerInput.new()
		_stick(case[0], -1.0)
		await frames(6)
		_pad(JOY_BUTTON_A, true)
		await frames(1)
		_pad(JOY_BUTTON_A, false)
		await frames(12)
		_stick(0.0, 0.0)
		var dropped: bool = p.global_position.y > floor_y + 8.0
		check(dropped == case[1], "%.0f degrees under level and Jump: %s (y %.0f from %.0f)" % [
			case[0], "drops through" if case[1] else "jumps, never drops", p.global_position.y, floor_y])
		room.queue_free()
		await frames(1)
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("| Stick angle (pass 368) |"), "bible 6.1 has the row")


## Leans the left stick `degrees` from level, rightward; `up` 1 leans up, -1
## down, 0 lets go.
func _stick(degrees: float, up: float) -> void:
	var v := Vector2(cos(deg_to_rad(degrees)), -up * sin(deg_to_rad(degrees))) if up != 0.0 else Vector2.ZERO
	for a: Array in [[JOY_AXIS_LEFT_X, v.x], [JOY_AXIS_LEFT_Y, v.y]]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = a[0]
		ev.axis_value = a[1]
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _pad(button: JoyButton, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _drift_room() -> Room:
	var rows := ["##############################"]
	for y in 28:
		rows.append("#...vvvvvv...................#")
	rows.append("##############################")
	return make_room(rows)


## Bible 8.9: in a wrong-gravity pocket the player keeps GravityDrift.PULL of
## their weight: a full jump rises well past the 9 tiles the checker allows,
## and a fall drifts down slowly.
func test_wrong_gravity_lifts_a_jump_and_slows_a_fall() -> void:
	var room := _drift_room()
	var p := make_player(room, Vector2i(6, 28))
	await _settle(p)
	var start_y := p.global_position.y
	var min_y := start_y
	p.input.jump_pressed = true
	p.input.jump_held = true
	var fastest := 0.0
	for i in 240:
		await frames(1)
		min_y = minf(min_y, p.global_position.y)
		fastest = maxf(fastest, p.velocity.y)
		if i > 10 and p.is_on_floor():
			break
	var rise := start_y - min_y
	check(rise >= 9.5 * Room.TILE, "a jump in the drift rises past nine tiles (%d px)" % rise)
	check(rise > p.tuning.jump_height * 2.0, "over twice a normal jump")
	check(fastest <= p.tuning.max_fall_speed * GravityDrift.PULL + 1.0, "and the fall drifts (%d px/s)" % fastest)
	check(p.is_on_floor(), "it lands again")
	# Outside the pocket, the jump is a plain jump.
	var q := make_player(room, Vector2i(20, 28))
	p.queue_free()
	await _settle(q)
	start_y = q.global_position.y
	min_y = start_y
	q.input.jump_pressed = true
	q.input.jump_held = true
	for i in 70:
		await frames(1)
		min_y = minf(min_y, q.global_position.y)
	check_near(start_y - min_y, q.tuning.jump_height, 3.0, "outside it a jump is a normal jump")


## Bible 12.16: the drift pocket is drawn as a feathered shaft of light, not a
## flat translucent box. Its wash profile fades to nothing at the two sides,
## brightens toward the core, and fades in at the floor and out at the crown, so
## it reads as a column you pass through rather than a solid glass volume.
func test_the_drift_pocket_reads_as_a_feathered_column() -> void:
	var w := 96.0
	# The two sides feather away; the interior and core carry the wash.
	check(GravityDrift.column_alpha(0.0, w) < 0.03, "the left edge feathers to nothing")
	check(GravityDrift.column_alpha(w, w) < 0.03, "the right edge feathers to nothing")
	check(GravityDrift.column_alpha(w * 0.5, w) > 0.5, "the interior carries the wash")
	check(GravityDrift.column_alpha(w * 0.5, w) > GravityDrift.column_alpha(16.0, w),
			"and the core is brighter than the interior's edge")
	# The vertical envelope fades the shaft in at the floor and out at the crown.
	var h := 400.0
	check(GravityDrift.rise_alpha(0.0, h) < 0.03, "the crown fades out")
	check(GravityDrift.rise_alpha(h, h) < 0.03, "the floor fades in")
	check(GravityDrift.rise_alpha(h * 0.5, h) > 0.99, "the body is full")


## A pool 10 tiles deep (rows 8-17) with a stone bank on its right whose top is
## level with the water (row 8).
func _pool_room() -> Room:
	var rows := ["##############################"]
	for y in range(1, 8):
		rows.append("#............................#")
	for y in range(8, 18):
		rows.append("#aaaaaaaaaaaaaaaa#############")
	rows.append("##############################")
	return make_room(rows)


## Bible 6.8: in deep water the player floats up to the surface, sinks while
## Down is held, strokes up with jump, moves slower, and jumps out from the surface.
func test_swimming_floats_sinks_strokes_and_jumps_out() -> void:
	var room := _pool_room()
	var p := make_player(room, Vector2i(6, 16))
	await frames(4)
	check(p.swimming, "deep in the pool the player is swimming")
	var surface := 8.0 * Room.TILE
	# Floats up to the surface and bobs there with the head out.
	for i in 240:
		await frames(1)
	var mid := p.body_rect().get_center().y
	check(absf(mid - surface) < 6.0, "floats up until the body's middle sits at the surface (%.1f vs %.1f)" % [mid, surface])
	check(p.global_position.y - Player.BODY_SIZE.y < surface, "with the head above the water")
	# Holding Down sinks, no faster than swim_sink.
	p.input.down = true
	var fastest := 0.0
	for i in 60:
		await frames(1)
		fastest = maxf(fastest, p.velocity.y)
	p.input.down = false
	check(p.global_position.y > surface + 3.0 * Room.TILE, "holding Down sinks (feet at %.0f)" % p.global_position.y)
	check(fastest <= p.tuning.swim_sink + 0.5, "slowly (%.0f px/s)" % fastest)
	# A jump press under water is a stroke up.
	var y0 := p.global_position.y
	p.input.jump_pressed = true
	await frames(1)
	check_near(p.velocity.y, -p.tuning.swim_stroke, 30.0, "a jump press under water is a stroke up")
	for i in 20:
		await frames(1)
	check(p.global_position.y < y0 - Room.TILE, "and it carries the body up (%.0f -> %.0f)" % [y0, p.global_position.y])
	# Swimming across is slower than running.
	p.input.move_x = 1
	var top := 0.0
	for i in 40:
		await frames(1)
		top = maxf(top, absf(p.velocity.x))
	p.input.move_x = 0
	check_near(top, p.tuning.run_speed * p.tuning.swim_speed_multiplier, 2.0, "swimming across is slower than a run")
	# At the surface, a jump is a full jump out onto the bank.
	p.global_position = Vector2(15 * Room.TILE + 8, surface + 20.0)
	p.velocity = Vector2.ZERO
	for i in 60:
		await frames(1)
	p.input.move_x = 1
	p.input.jump_pressed = true
	p.input.jump_held = true
	await frames(1)
	p.input.jump_held = true
	for i in 50:
		await frames(1)
		p.input.jump_held = true
		if p.is_on_floor():
			break
	p.input.move_x = 0
	check(p.is_on_floor() and not p.swimming and p.global_position.x > 17 * Room.TILE, "from the surface a jump carries you out onto the bank (%s)" % p.global_position)


## A 50-wide room with a current blowing east (`>`) across rows 6-9, cols 2-47,
## and a shelf on the floor (cols 20-24, top row 8) standing up into it.
func _wind_room() -> Room:
	var rows := ["##################################################"]
	for y in range(1, 18):
		var row := "#" + ".".repeat(48) + "#"
		if y >= 6 and y <= 9:
			row = "#." + ">".repeat(46) + ".#"
		if y >= 8:
			row = row.substr(0, 20) + "#####" + row.substr(25)
		rows.append(row)
	rows.append("##################################################")
	return make_room(rows)


## Bible 6.9: in the air in a current the player is carried along it and borne
## level; there's no headway against it; Down drops out; on a floor it does nothing.
func test_a_current_carries_you_and_bears_you_level() -> void:
	GameState.new_game()
	var room := _wind_room()
	var p := make_player(room, Vector2i(8, 9))
	p.global_position = Vector2(8 * Room.TILE, 8 * Room.TILE + 4)
	p.velocity = Vector2.ZERO
	await frames(2)
	var y0 := p.global_position.y
	var x0 := p.global_position.x
	for i in 40:
		await frames(1)
	check(p.velocity.x > p.tuning.wind_speed - 10.0, "with no input it is carried at the wind's speed (%.0f px/s)" % p.velocity.x)
	check(absf(p.global_position.y - y0) < Room.TILE, "and borne level, not falling (%.1f px)" % (p.global_position.y - y0))
	check(p.global_position.x > x0 + 80.0, "downwind (%.0f px)" % (p.global_position.x - x0))
	# Running against it: still carried downwind, slowly.
	p.global_position = Vector2(30 * Room.TILE, 8 * Room.TILE + 4)
	p.velocity = Vector2.ZERO
	p.input.move_x = -1
	await frames(2)
	x0 = p.global_position.x
	for i in 40:
		await frames(1)
	check(p.global_position.x > x0, "running against it makes no headway (%.0f px)" % (p.global_position.x - x0))
	p.input.move_x = 0
	# Down drops out.
	p.input.down = true
	y0 = p.global_position.y
	for i in 20:
		await frames(1)
	check(p.global_position.y > y0 + Room.TILE, "holding Down drops you out of it (%.0f px)" % (p.global_position.y - y0))
	p.input.down = false


func test_a_current_doesnt_move_you_on_a_floor() -> void:
	GameState.new_game()
	var room := _wind_room()
	var p := make_player(room, Vector2i(22, 7))
	for i in 20:
		await frames(1)
	var x0 := p.global_position.x
	for i in 30:
		await frames(1)
	check(p.is_on_floor() and absf(p.global_position.x - x0) < 1.0, "standing on the shelf in the current, you brace and stay put")


func test_the_spring_of_sky_turns_the_wind() -> void:
	GameState.new_game()
	var room := _wind_room()
	var w: WindCurrent = null
	for c in room.get_children():
		if c is WindCurrent:
			w = c
	check(w != null and w.dir() == 1, "a `>` current blows east")
	GameState.set_flag("spring:sky")
	check(w.dir() == -1, "once the Sky Spring is restored it blows west")
	var p := make_player(room, Vector2i(8, 9))
	p.global_position = Vector2(30 * Room.TILE, 8 * Room.TILE + 4)
	await frames(2)
	var x0 := p.global_position.x
	for i in 30:
		await frames(1)
	check(p.global_position.x < x0 - 60.0, "and carries you west (%.0f px)" % (p.global_position.x - x0))
	GameState.new_game()


func test_wind_numbers_match_the_bible() -> void:
	var t := MovementTuning.new()
	check(t.wind_speed == 200.0 and t.wind_drag == 2400.0, "wind speed and drag are the bible's (6.9)")
	check(t.wind_speed > t.run_speed, "faster than a run, so there is no headway against it")


func test_sap_numbers_match_bible_6_12() -> void:
	var t := MovementTuning.new()
	check(t.sap_speed == 0.5 and t.sap_jump == 0.72, "sap holds the run to half and a jump to 72% (6.12)")
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("### 6.12 Sap") and bible.contains("| Run | 50% of the pace"), "the bible has the sap section and its numbers")
	# A jump at 72% of its speed rises about half as high: (0.72)^2 of 72 px.
	check(absf(t.jump_height * t.sap_jump * t.sap_jump - 37.3) < 0.5, "about 37 px, a little over two tiles")


func test_swim_numbers_match_the_bible() -> void:
	var t := MovementTuning.new()
	check(t.swim_speed_multiplier == 0.7 and t.swim_float == 50.0 and t.swim_sink == 120.0, "swim speed, float and sink are the bible's (6.8)")
	check(t.swim_drag == 520.0 and t.swim_stroke == 230.0, "drag and stroke too")
	check(t.swim_stroke < t.jump_velocity, "a stroke is weaker than a jump")



# --- Bible 6.2 to 6.6, pinned (pass 107) -------------------------------------------

const LIP := [
	"################",
	"#..............#",
	"#..............#",
	"#..............#",
	"#..............#",
	"#..............#",
	"#..............#",
	"#..............#",
	"#.........######",
	"#.........######",
	"#.........######",
	"#.........######",
	"################",
]
## LIP's ledge: its top edge and its left face.
const LIP_TOP := 128.0
const LIP_FACE := 160.0


func test_movement_numbers_match_bible_6_2_to_6_6() -> void:
	var t := MovementTuning.new()
	# 6.2
	check_near(t.coyote_time, 0.10, 0.0001, "coyote time")
	check_near(t.jump_buffer_time, 0.12, 0.0001, "jump buffer")
	check(t.corner_correction_px == 6, "corner correction 6 px")
	check(t.ledge_correction_px == 4, "ledge correction 4 px")
	check(t.head_correction_px == 4, "head correction 4 px (pass 139)")
	# 6.3
	check_near(t.wall_slide_speed, 90.0, 0.0001, "wall slide speed")
	check_near(t.wall_stick_time, 0.08, 0.0001, "wall stick")
	check_near(t.wall_jump_x, 220.0, 0.0001, "wall jump outward")
	check_near(t.wall_jump_y, 380.0, 0.0001, "wall jump up")
	check_near(t.wall_climb_jump_x, 120.0, 0.0001, "climb jump outward")
	check_near(t.wall_jump_lock, 0.10, 0.0001, "wall jump input lock")
	check_near(t.wall_climb_jump_lock, 0.06, 0.0001, "climb jump input lock")
	check_near(t.wall_jump_blend, 0.10, 0.0001, "control blends back over 0.10 s")
	check_near(t.wall_coyote_time, 0.08, 0.0001, "wall coyote")
	# 6.4
	check_near(t.double_jump_height, 48.0, 0.0001, "double jump height")
	check_near(t.double_jump_velocity, 326.0, 1.0, "double jump velocity")
	# 6.5
	check_near(t.dash_speed, 380.0, 0.0001, "dash speed")
	check_near(t.dash_time, 0.15, 0.0001, "dash time")
	check_near(t.dash_invuln, 0.10, 0.0001, "dash invulnerability")
	check(t.air_dash_charges == 1, "one air dash")
	check_near(t.ground_dash_cooldown, 0.25, 0.0001, "ground dash cooldown")
	check_near(t.ground_dash_snap, 10.0, 0.0001, "ground dash snap")
	check_near(t.dash_buffer_time, 0.10, 0.0001, "dash buffer")
	# 6.6
	check_near(t.pogo_bounce, 380.0, 0.0001, "pogo bounce")
	check_near(t.pogo_bounce_held, 420.0, 0.0001, "pogo bounce, jump held")
	check_near(t.down_strike_active, 0.14, 0.0001, "down-strike active")
	# Pass 256: the swing's own timing, in the tuning since the prototype but
	# never in 6.6's table nor held by a test.
	check_near(t.slash_active, 0.10, 0.0001, "a slash or up-slash cuts for 0.10 s")
	check_near(t.attack_cooldown, 0.28, 0.0001, "an up-slash or down-strike recovers for 0.28 s")
	check(Player.DOWN_STRIKE_SIZE == Vector2(28, 24), "down-strike hitbox 28x24")
	# Pass 208: the rest of 6.6 and 6.10, until now only read back from the
	# tuning by their play tests, and the pogo's hit-stop, a literal in the player.
	check_near(t.pogo_hitstop, 0.045, 0.0001, "pogo hit-stop 45 ms")
	check_near(t.pod_bounce, 600.0, 0.0001, "bounce-pod launch")
	# 6.10
	check_near(t.glide_fall_speed, 60.0, 0.0001, "glide fall speed")
	check_near(t.glide_brake, 1500.0, 0.0001, "glide brake")
	# 5.3, the slash's push back
	check_near(t.slash_recoil, 120.0, 0.0001, "slash recoil")


## Pass 256: an up-slash cuts for `slash_active` and the next swing waits out
## `attack_cooldown`, however fast Attack is pressed.
func test_an_up_slash_cuts_then_recovers_as_6_6_says() -> void:
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(3, 11))
	await _settle(p)
	var t := p.tuning
	p.input.up = true
	p.input.attack_pressed = true
	await frames(1)
	check(p.attack_kind == "up" and p.is_attacking, "Up and Attack on the floor is an up-slash")
	var cutting := 0
	var next := -1
	var last := p._attack_timer
	for i in 40:
		p.input.attack_pressed = true
		await frames(1)
		if p._attack_timer > last:
			next = i + 1
			break
		if p._attack_timer > 0.0:
			cutting += 1
		last = p._attack_timer
	p.input.up = false
	check(absi(cutting - roundi(t.slash_active * 60.0)) <= 1, "it cuts for about %d frames (%d)" % [roundi(t.slash_active * 60.0), cutting])
	check(absi(next - roundi(t.attack_cooldown * 60.0)) <= 1, "and with Attack pressed every frame the next swing comes %d frames on (%d)" % [roundi(t.attack_cooldown * 60.0), next])


## Pass 328: the pinned tests above hold each number to a literal copied from
## the bible, so a number changed in the tuning and its test together would
## leave section 6 saying the old one. This reads the text itself: every
## number MovementTuning exports must be written somewhere in section 6, in one
## of the ways the bible writes numbers (165, 1,800, 0.10 s, 45 ms, 40%, x1.6).
func test_every_movement_number_is_written_in_bible_6() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var six := bible.get_slice("## 6. Movement", 1).get_slice("\n## 7. ", 0)
	var t := MovementTuning.new()
	var unwritten := []
	var count := 0
	for prop: Dictionary in t.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (prop.type in [TYPE_FLOAT, TYPE_INT]):
			continue
		count += 1
		var f := float(t.get(prop.name))
		if not written_exactly_in(six, f):
			unwritten.append("%s %s" % [prop.name, String.num(f)])
	check(count >= 50, "every exported movement number is read (%d)" % count)
	check(unwritten.is_empty(), "every movement number is written in bible 6 (not: %s)" % [unwritten])


## Pass 200: 6.1 and the core of 6.2 were only read back from the tuning by the
## behaviour tests, so a changed number moved the test with it. These hold the
## numbers to the bible, and the tests after them hold what each one does.
func test_movement_numbers_match_bible_6_1_and_6_2() -> void:
	var t := MovementTuning.new()
	# 6.1
	check_near(t.run_speed, 165.0, 0.0001, "max run speed")
	check_near(t.ground_accel, 1800.0, 0.0001, "ground acceleration")
	check_near(t.ground_decel, 2600.0, 0.0001, "ground deceleration")
	check_near(t.turn_multiplier, 1.6, 0.0001, "turnaround boost")
	# 6.2
	check_near(t.jump_height, 72.0, 0.0001, "full jump height")
	check_near(t.jump_time_to_apex, 0.36, 0.0001, "time to apex")
	check_near(t.gravity, 1111.0, 1.0, "rising gravity, derived 2h/t^2")
	check_near(t.jump_velocity, 400.0, 0.5, "jump velocity, derived 2h/t")
	check_near(t.fall_gravity_multiplier, 1.6, 0.0001, "falling gravity x 1.6")
	check_near(t.jump_cut_multiplier, 0.45, 0.0001, "jump cut x 0.45")
	check_near(t.apex_threshold, 40.0, 0.0001, "apex hang below 40 px/s")
	check_near(t.apex_gravity_multiplier, 0.5, 0.0001, "apex hang x 0.5")
	check_near(t.max_fall_speed, 520.0, 0.0001, "max fall speed")
	check_near(t.max_fast_fall_speed, 620.0, 0.0001, "max fall speed holding Down")
	check_near(t.air_accel, 1400.0, 0.0001, "air acceleration")
	check_near(t.air_decel, 900.0, 0.0001, "air deceleration")
	# 5.3, Damage taken
	check_near(t.hurt_invuln, 0.8, 0.0001, "0.8 s invulnerability after a hit")


## Bible 6.1: pushing against your own run brakes at deceleration x 1.6, harder
## than letting go, so a turn comes round in a few frames.
func test_a_turn_brakes_harder_than_letting_go() -> void:
	var drops: Array[float] = []
	for reverse in [false, true]:
		var room := make_room(FLAT)
		var p := make_player(room, Vector2i(3, 11))
		await _settle(p)
		p.input.move_x = 1
		await frames(12)
		var before := p.velocity.x
		p.input.move_x = -1 if reverse else 0
		await frames(1)
		drops.append(before - p.velocity.x)
		var turned := -1
		for i in 20:
			if p.velocity.x <= -p.tuning.run_speed + 0.01:
				turned = i + 1
				break
			await frames(1)
		if reverse:
			check(turned > 0 and turned <= 9, "a turn is at full speed the other way within 9 frames (got %d)" % turned)
		room.free()
	var t := MovementTuning.new()
	check_near(drops[0], t.ground_decel / 60.0, 0.5, "letting go brakes at the deceleration")
	check_near(drops[1], t.ground_decel * t.turn_multiplier / 60.0, 0.5, "a turn brakes at 1.6x it")


## Bible 6.2: letting go of Jump on the way up keeps 0.45 of the rise.
func test_letting_go_of_jump_cuts_the_rise() -> void:
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(10, 11))
	await _settle(p)
	p.input.jump_pressed = true
	p.input.jump_held = true
	await frames(4)
	var before := p.velocity.y
	p.input.jump_held = false
	await frames(1)
	var g := p.tuning.gravity / 60.0
	check(before < -250.0, "still rising fast before the release (%.0f)" % before)
	check_near(p.velocity.y, before * p.tuning.jump_cut_multiplier + g, 0.5, "the release keeps 0.45 of the rise")
	room.free()


## Bible 6.2: a fall pulls 1.6x as hard as the rise, tops out at 520 px/s, and
## at 620 px/s while Down is held.
func test_a_fall_pulls_harder_and_down_falls_faster() -> void:
	var fastest: Array[float] = []
	var pull := 0.0
	for down in [false, true]:
		var room := make_room(LEDGE)
		var p := make_player(room, Vector2i(10, 1), {"glove": false})
		var top := 0.0
		for i in 40:
			var before := p.velocity.y
			p.input.down = down
			await frames(1)
			if not down and pull == 0.0 and before > 100.0 and p.velocity.y < p.tuning.max_fall_speed:
				pull = p.velocity.y - before
			top = maxf(top, p.velocity.y)
		fastest.append(top)
		room.free()
	var t := MovementTuning.new()
	check_near(pull, t.gravity * t.fall_gravity_multiplier / 60.0, 0.5, "a fall pulls at 1.6x the rising gravity")
	check_near(fastest[0], t.max_fall_speed, 0.01, "a fall tops out at 520 px/s")
	check_near(fastest[1], t.max_fast_fall_speed, 0.01, "holding Down it tops out at 620 px/s")


## Frames off a ledge before Jump is pressed -> whether it jumped.
func _jump_after_ledge(k: int) -> bool:
	var room := make_room(LEDGE)
	var p := make_player(room, Vector2i(2, 3), {"boots": false, "glove": false})
	await _settle(p)
	await _walk_off_ledge(p)
	await frames(k - 1)
	p.input.jump_pressed = true
	p.input.jump_held = true
	await frames(1)
	var jumped := p.velocity.y < -300.0
	room.free()
	return jumped


func test_coyote_time_is_a_tenth_of_a_second() -> void:
	# 0.10 s is 6 frames: a jump on the 6th frame off the ledge still counts.
	var last := 0
	for k in range(4, 10):
		if await _jump_after_ledge(k):
			last = k
	check(last == 6, "the last frame a ledge jump counts is the 6th, 0.10 s (got %d)" % last)


## Drops from row 4 onto FLAT's floor with Jump pressed `early` frames before
## the first frame on the floor (`land`, measured first); returns whether it jumped.
func _buffered_landing(early: int, land: int) -> bool:
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(10, 4), {"boots": false})
	var jumped := false
	for i in land + 4:
		if i == land - early:
			p.input.jump_pressed = true
			p.input.jump_held = true
		await frames(1)
		if p.velocity.y < -300.0:
			jumped = true
			break
	room.free()
	return jumped


func test_jump_buffer_holds_a_press_for_0_12_s() -> void:
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(10, 4), {"boots": false})
	var land := 0
	for i in 90:
		await frames(1)
		if p.is_on_floor():
			land = i + 1  # the next frame starts on the floor
			break
	room.free()
	check(land > 10, "the drop takes a while (%d frames)" % land)
	# 0.12 s is 7.2 frames: a press 7 frames early still jumps, 8 is too early.
	check(await _buffered_landing(7, land), "a press 7 frames (0.117 s) before landing jumps")
	check(await _buffered_landing(3, land), "a press 3 frames before landing jumps")
	check(not await _buffered_landing(8, land), "a press 8 frames (0.133 s) before landing is dropped")


## Jumps under a block that overhangs the body by `overlap` px; returns the rise.
func _rise_under_corner(overlap: float) -> float:
	var rows := [
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"#...#......#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"############",
	]
	# The block at cell (4,4) starts at x 64; the body is 12 wide.
	var room := make_room(rows)
	var p := make_player(room, Vector2i(3, 8), {"boots": false})
	p.position.x = 64.0 - 6.0 + overlap
	await _settle(p)
	var start_y := p.global_position.y
	var min_y := start_y
	p.input.jump_pressed = true
	p.input.jump_held = true
	for i in 30:
		await frames(1)
		min_y = minf(min_y, p.global_position.y)
	room.free()
	return start_y - min_y


func test_corner_correction_reaches_6_px_and_no_further() -> void:
	check(await _rise_under_corner(6.0) > 55.0, "a 6 px overhang is slid past")
	check(await _rise_under_corner(7.0) < 40.0, "a 7 px overhang bumps the head")


## Falls toward LIP's ledge from `depth` px below its top, already touching it.
func _clip_lip(depth: float, glove: bool) -> bool:
	var room := make_room(LIP)
	var p := make_player(room, Vector2i(3, 3), {"glove": glove})
	await frames(1)  # a body collides only from its second frame
	p.position = Vector2(LIP_FACE - 6.0 - 0.3, LIP_TOP + depth)
	p.velocity = Vector2(p.tuning.run_speed, 0.0)
	for i in 12:
		p.input.move_x = 1
		await frames(1)
	var up := p.is_on_floor() and p.global_position.y <= LIP_TOP + 0.5
	room.free()
	return up


func test_ledge_correction_lifts_you_4_px_onto_a_ledge() -> void:
	for glove in [false, true]:
		var with := "with" if glove else "without"
		check(await _clip_lip(2.0, glove), "%s the glove, clipping a ledge by 2 px steps onto it" % with)
		check(await _clip_lip(4.0, glove), "%s the glove, clipping it by 4 px steps onto it" % with)
		check(not await _clip_lip(5.0, glove), "%s the glove, 5 px below the top is too far" % with)



# --- Pass 111: the core moves on special terrain ---------------------------------

const ONE_WAY_LEDGE := [
	"#####################",
	"#...................#",
	"#...................#",
	"#...................#",
	"#----...............#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#...................#",
	"#####################",
]


func _jump_after_one_way_edge(k: int) -> bool:
	var room := make_room(ONE_WAY_LEDGE)
	var p := make_player(room, Vector2i(2, 3), {"boots": false, "glove": false})
	await _settle(p)
	await _walk_off_ledge(p)
	await frames(k - 1)
	p.input.jump_pressed = true
	p.input.jump_held = true
	await frames(1)
	var jumped := p.velocity.y < -300.0
	room.free()
	return jumped


## Bible 6.2: coyote time off a one-way platform's end is the same 0.10 s.
func test_coyote_time_off_a_one_way_platform() -> void:
	var last := 0
	for k in range(4, 10):
		if await _jump_after_one_way_edge(k):
			last = k
	check(last == 6, "the last frame a jump off a one-way's end counts is the 6th (got %d)" % last)


## Falls past the end of ONE_WAY_LEDGE's platform with the feet `d` px under its
## top, moving toward it; returns whether the player ends up standing on it.
func _clip_one_way_lip(d: float) -> bool:
	var room := make_room(ONE_WAY_LEDGE)
	var p := make_player(room, Vector2i(10, 13), {"boots": false, "glove": false})
	await frames(3)
	var lip := 5.0 * Room.TILE
	var top := 4.0 * Room.TILE
	p.teleport(Vector2(lip + Player.BODY_SIZE.x * 0.5 + 1.5, top + d))
	p.velocity = Vector2(-120, 0)
	var stood := false
	for i in 12:
		p.input.move_x = -1
		await frames(1)
		if p.is_on_floor() and p.global_position.y < top + 1.0:
			stood = true
	room.free()
	return stood


## Bible 6.2: ledge correction lifts you onto a one-way platform's lip as it does
## a solid ledge's. A one-way has no side to bump, so before pass 111 a clip of
## even 1 px fell straight past it.
func test_ledge_correction_lifts_you_onto_a_one_way_lip() -> void:
	for d in [1.0, 2.0, 4.0]:
		check(await _clip_one_way_lip(d), "a %.0f px clip steps up onto the one-way" % d)
	check(not await _clip_one_way_lip(5.0), "a 5 px clip doesn't")
	# Dropping through while running along it isn't lifted back up.
	var room := make_room(ONE_WAY_LEDGE)
	var p := make_player(room, Vector2i(2, 3), {"boots": false, "glove": false})
	await _settle(p)
	p.input.move_x = 1
	await frames(2)
	p.input.down = true
	p.input.jump_pressed = true
	await frames(1)
	p.input.down = false
	for i in 30:
		p.input.move_x = 1
		await frames(1)
	check(p.global_position.y > 8.0 * Room.TILE, "a drop-through on the run still drops (y %.0f)" % p.global_position.y)


## Bible 6.8: bobbing at the surface lifts the body clear of the water for a few
## frames. Water counts as footing for coyote time, so a jump pressed at any point
## of the bob jumps out on that frame (before pass 111 it could wait 6 frames, or
## come out as a weak stroke).
func test_a_jump_at_the_surface_jumps_out_at_any_point_of_the_bob() -> void:
	var late := 0
	var out_of_water := 0
	for phase in 20:
		var room := _pool_room()
		var p := make_player(room, Vector2i(6, 10), {"boots": false})
		await frames(240 + phase)
		if not p.swimming:
			out_of_water += 1
		p.input.jump_pressed = true
		p.input.jump_held = true
		await frames(1)
		if p.velocity.y > -300.0:
			late += 1
		room.free()
	check(out_of_water > 0, "the bob does lift the body out of the water (%d of 20 frames)" % out_of_water)
	check(late == 0, "a jump at every point of the bob jumps out at once (%d late)" % late)


## Bible 6.9: a wind current doesn't change coyote time.
func test_coyote_time_holds_in_a_wind_current() -> void:
	var rows := [
		"#####################",
		"#...................#",
		"#.....>>>>>>>>>>....#",
		"#.....>>>>>>>>>>....#",
		"#######>>>>>>>>>....#",
		"#.....>>>>>>>>>>....#",
		"#...................#",
		"#...................#",
		"#...................#",
		"#####################",
	]
	var last := 0
	for k in range(4, 10):
		var room := make_room(rows)
		var p := make_player(room, Vector2i(4, 3), {"boots": false, "glove": false})
		await _settle(p)
		await _walk_off_ledge(p)
		await frames(k - 1)
		p.input.jump_pressed = true
		p.input.jump_held = true
		await frames(1)
		if p.velocity.y < -300.0:
			last = k
		room.free()
	check(last == 6, "off a ledge into the wind, the 6th frame is still the last (got %d)" % last)


## Bible 8.9: in a drift pocket you fall slowly, but the jump buffer is still 0.12 s.
func test_the_jump_buffer_holds_in_a_drift_pocket() -> void:
	var rows := ["##############################"]
	for y in 12:
		rows.append("#...vvvvvv...................#")
	rows.append("##############################")
	var room := make_room(rows)
	var p := make_player(room, Vector2i(6, 3), {"boots": false})
	var land := 0
	for i in 400:
		await frames(1)
		if p.is_on_floor():
			land = i + 1
			break
	room.free()
	check(land > 30, "the drop is slow in the pocket (%d frames)" % land)
	for early in [7, 8]:
		room = make_room(rows)
		p = make_player(room, Vector2i(6, 3), {"boots": false})
		var jumped := false
		for i in land + 4:
			if i == land - early:
				p.input.jump_pressed = true
				p.input.jump_held = true
			await frames(1)
			if p.velocity.y < -300.0:
				jumped = true
				break
		room.free()
		check(jumped == (early == 7), "a press %d frames before landing %s" % [early, "jumps" if early == 7 else "is dropped"])


## Pass 115: a ramp up four tiles, a plateau, and a ramp back down (design bible 6.1).
const RAMP := [
	"##############################",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............/######\\........#",
	"#.........../########\\.......#",
	"#........../##########\\......#",
	"#........./############\\.....#",
	"##############################",
]


## Bible 6.1: slopes up to 45 degrees are floor. You run up at full speed (along
## the slope), run down without leaving the ground, and stand still on one.
func test_slopes_keep_your_speed_and_your_footing() -> void:
	var room := make_room(RAMP)
	var p := make_player(room, Vector2i(4, 11))
	await _settle(p)
	var airborne := 0
	var up_speeds: Array[float] = []
	var down_speeds: Array[float] = []
	var x0 := p.global_position.x
	for i in 150:
		p.input.move_x = 1
		var before := p.global_position
		await frames(1)
		if not p.is_on_floor():
			airborne += 1
		var step := (p.global_position - before) * 60.0
		var x := p.global_position.x
		if x > 11.5 * 16 and x < 13.5 * 16:
			up_speeds.append(step.length())
		elif x > 21.5 * 16 and x < 23.5 * 16:
			down_speeds.append(step.length())
		if x > 26 * 16:
			break
	check(airborne == 0, "never leaves the ground over the ramps (%d frames in the air)" % airborne)
	check(not up_speeds.is_empty() and up_speeds.min() > p.tuning.run_speed * 0.9,
		"runs up at full speed along the slope (slowest %.0f px/s)" % (up_speeds.min() if not up_speeds.is_empty() else 0.0))
	check(not down_speeds.is_empty() and down_speeds.max() < p.tuning.run_speed * 1.1 and down_speeds.min() > p.tuning.run_speed * 0.9,
		"and down at the same speed (%.0f to %.0f px/s)" % [down_speeds.min() if not down_speeds.is_empty() else 0.0, down_speeds.max() if not down_speeds.is_empty() else 0.0])
	check(absf(p.global_position.y - 12 * 16) < 1.0, "and is back on the floor below (y %.1f)" % p.global_position.y)
	check(p.visual.position.y == 0.0, "where the sprite stands on its own feet again")
	check(p.global_position.x > x0 + 300.0, "having crossed it all")
	# Stand still halfway up a ramp: no creeping down it.
	p.teleport(Vector2(12.5 * 16, 9.5 * 16 - 2.0))
	p.input.move_x = 0
	await frames(20)
	var rest := p.global_position
	await frames(40)
	check(p.is_on_floor() and rest.distance_to(p.global_position) < 0.5,
		"stands still on a slope (moved %.2f px)" % rest.distance_to(p.global_position))
	# The box rests on its corner; the sprite is drawn down onto the slope.
	check(p.visual.position.y > Player.BODY_SIZE.x * 0.5 - 1.5, "the feet are drawn on the slope (sunk %.1f px)" % p.visual.position.y)
	# And a jump from a slope is the same jump as from flat ground.
	var vy: Array[float] = []
	for at: Vector2 in [Vector2(5.5 * 16, 12 * 16), rest]:
		p.teleport(at)
		p.velocity = Vector2.ZERO
		await frames(10)
		p.input.jump_pressed = true
		p.input.jump_held = true
		await frames(1)
		p.input.jump_pressed = false
		vy.append(-p.velocity.y)
		await frames(50)
	p.input.jump_held = false
	check(vy[0] > 300.0 and absf(vy[1] - vy[0]) < 1.0, "a jump from a slope is a full jump (%.1f, flat %.1f)" % [vy[1], vy[0]])
	room.free()


## Pass 121: a ground stride hugs the floor (bible 6.5). Down a slope the
## dash's 6 px a frame used to carry you off the ramp into the air for a third
## of a second; now it rides the slope down, as it already rode one up. A
## ledge deeper than the snap still drops away, and an air dash never snaps.
func test_a_ground_stride_follows_a_slope() -> void:
	var room := make_room(RAMP)
	var p := make_player(room, Vector2i(4, 11), {"stride": true})
	await _settle(p)
	# [start, dir, label]: down off the plateau's edge, down from mid-ramp, up a ramp.
	for run: Array in [[Vector2(17.5 * 16, 8 * 16), 1, "off the plateau down the ramp"],
			[Vector2(21.7 * 16, 9.4 * 16), 1, "down from mid-ramp"],
			[Vector2(8.5 * 16, 12 * 16), 1, "up a ramp"],
			[Vector2(16.5 * 16, 8 * 16), -1, "down the west ramp"]]:
		p.teleport(run[0])
		p.velocity = Vector2.ZERO
		await frames(15)
		check(p.is_on_floor(), "standing to start (%s)" % run[2])
		var start := p.global_position
		p.input.move_x = run[1]
		p.input.dash_pressed = true
		await frames(1)
		p.input.dash_pressed = false
		var air := 0
		var path := 0.0
		var last := p.global_position
		while p.is_dashing:
			await frames(1)
			path += last.distance_to(p.global_position)
			last = p.global_position
			if not p.is_on_floor():
				air += 1
		p.input.move_x = 0
		check(air == 0, "a ground stride %s keeps its footing (%d frames in the air)" % [run[2], air])
		check(path > p.tuning.dash_speed * p.tuning.dash_time * 0.9, "and covers a full stride along the floor (%.0f px)" % path)
		check(absf(p.global_position.y - start.y) > 8.0 or run[2] == "up a ramp" and p.global_position.y < start.y, "following the slope (%.0f px)" % (p.global_position.y - start.y))
		await frames(20)
	room.free()
	# Off a real ledge (a whole tile and more) the stride still sails out.
	room = make_room(LEDGE)
	p = make_player(room, Vector2i(2, 3), {"stride": true})
	await _settle(p)
	p.input.move_x = 1
	p.input.dash_pressed = true
	await frames(1)
	p.input.dash_pressed = false
	var y0 := p.global_position.y
	var flew := false
	while p.is_dashing:
		await frames(1)
		flew = flew or (not p.is_on_floor() and absf(p.global_position.y - y0) < 1.0)
	p.input.move_x = 0
	check(flew, "a stride off a ledge flies level out over the drop")
	room.free()
	check(MovementTuning.new().ground_dash_snap == 10.0, "the ground stride snaps from 10 px")


## A slope's face is floor, not a wall: with the Climbing Glove, falling against
## it never catches you in a wall slide, and the ledge clip leaves it alone.
func test_a_slope_is_floor_not_a_wall() -> void:
	var room := make_room(RAMP)
	var p := make_player(room, Vector2i(4, 11), {"glove": true})
	await _settle(p)
	var slid := false
	var walled := false
	# Fall onto each ramp's face, pushing into it.
	for start: Array in [[Vector2(10.6 * 16, 7 * 16), 1], [Vector2(23.4 * 16, 7 * 16), -1]]:
		p.teleport(start[0])
		p.velocity = Vector2.ZERO
		for i in 60:
			p.input.move_x = start[1]
			await frames(1)
			slid = slid or p.is_wall_sliding
			walled = walled or p.wall_dir != 0
			if p.is_on_floor() and i > 5:
				break
		check(p.is_on_floor(), "lands on the slope (%s)" % ("/" if start[1] > 0 else "\\"))
	p.input.move_x = 0
	check(not walled, "a slope is never a wall")
	check(not slid, "and never catches you in a slide")
	# A real wall still does.
	p.teleport(Vector2(1.5 * 16 + 1.0, 6 * 16))
	p.velocity = Vector2.ZERO
	var caught := false
	for i in 30:
		p.input.move_x = -1
		await frames(1)
		caught = caught or p.is_wall_sliding
	p.input.move_x = 0
	check(caught, "while the room's wall still catches you")
	room.free()


## Things that ask the room what is solid (seeds, globs, bolts) see the diagonal.
func test_a_slope_is_solid_below_its_diagonal() -> void:
	var room := make_room(RAMP)
	# `/` at (10, 11) rises east; `\` at (23, 11) rises west.
	check(room.is_solid_at(Vector2(10 * 16 + 14, 11 * 16 + 6)), "/ is solid under its high side")
	check(not room.is_solid_at(Vector2(10 * 16 + 2, 11 * 16 + 6)), "/ is open over its low side")
	check(room.is_solid_at(Vector2(23 * 16 + 2, 11 * 16 + 6)), "\\ is solid under its high side")
	check(not room.is_solid_at(Vector2(23 * 16 + 14, 11 * 16 + 6)), "\\ is open over its low side")
	room.free()


## Bible 6.11 (pass 124): a shaft with a ladder up through the floor of a loft,
## and a short ladder hanging in the air on the right.
const LADDERS := [
	"####################",
	"#..................#",
	"#..................#",
	"#..................#",
	"#########\"#########",
	"#........\"........#",
	"#........\"....\"...#",
	"#........\"....\"...#",
	"#........\"....\"...#",
	"#........\"........#",
	"#........\"........#",
	"####################",
]


## Pass 408 (bible 6.7): the moves that read Down or Up as held, through the
## real controller. Passes 384 to 400 pressed each move through `Input`, but a
## drop through a one-way floor (Down held, Jump pressed), a ladder (Up or
## Down held at its rungs) and a pogo (Down held, Attack pressed above spikes)
## were only ever scripted. Each needs two buttons read together, held and
## pressed, and is played here with `Input` alone.
func test_drops_ladders_and_pogo_through_the_real_controller() -> void:
	var t := MovementTuning.new()
	# Down held, then Jump: through the one-way floor, not up from it.
	var room := make_room([
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"#........#",
		"#.------.#",
		"#........#",
		"#........#",
		"#........#",
		"##########",
	])
	var p := make_player(room, Vector2i(4, 4))
	p.input = PlayerInput.new()
	await _settle(p)
	var platform_y := 5 * Room.TILE
	check(p.is_on_floor() and absf(p.global_position.y - platform_y) < 1.5, "standing on the one-way floor")
	Input.action_press("move_down")
	await frames(4)
	check(p.is_on_floor(), "Down alone does not drop through")
	await press_for_real(p, ["jump"])
	var rose := p.velocity.y < 0.0
	release_for_real(["jump", "move_down"])
	await frames(20)
	check(not rose and p.global_position.y > platform_y + 20.0, "Down held with Jump drops through it (y %.1f)" % p.global_position.y)
	room.free()
	# Up held at a ladder climbs it; let go, you hang; Jump lets go.
	room = make_room(LADDERS)
	p = make_player(room, Vector2i(9, 10))
	p.input = PlayerInput.new()
	await frames(3)
	p.global_position.x = 9.5 * 16.0 + 5.0
	Input.action_press("move_up")
	await frames(2)
	check(p.on_ladder, "Up held at a ladder takes hold")
	await frames(10)
	check(p.on_ladder and is_equal_approx(p.velocity.y, -t.ladder_speed), "and climbs at ladder speed (vy %.0f)" % p.velocity.y)
	release_for_real(["move_up"])
	await frames(1)
	var y := p.global_position.y
	await frames(20)
	check(p.on_ladder and absf(p.global_position.y - y) < 0.5, "let go of Up, you hang")
	Input.action_press("move_down")
	await frames(3)
	check(p.on_ladder and is_equal_approx(p.velocity.y, t.ladder_speed), "Down held climbs back down (vy %.0f)" % p.velocity.y)
	release_for_real(["move_down"])
	await press_for_real(p, ["jump"])
	check(not p.on_ladder, "Jump lets go of the ladder")
	release_for_real(["jump"])
	room.free()
	# Down held and Attack over spikes: a pogo, with no hurt.
	var spikes := ["####################"]
	for i in 9:
		spikes.append("#..................#")
	spikes.append("#..^^^^^^^^^^^^^^..#")
	spikes.append("####################")
	room = make_room(spikes)
	p = make_player(room, Vector2i(9, 3), {"boots": true})
	p.input = PlayerInput.new()
	Input.action_press("move_down")
	var bounced := false
	var struck := false
	for i in 90:
		if not struck and p.velocity.y > 0.0 and p.global_position.y > 11 * 16 - 9 - 28.0:
			Input.action_press("attack")
			struck = true
		await frames(1)
		if p.velocity.y < -300.0:
			bounced = true
			break
	release_for_real(["move_down", "attack"])
	check(bounced, "Down held and Attack over the spikes bounces off them")
	check(p.hp == p.max_hp, "and takes no hurt (hp %d)" % p.hp)
	room.free()
	var line := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 6.7 ", 1).get_slice("- **Input", 1).get_slice("\n", 0)
	check(line.contains("`test_drops_ladders_and_pogo_through_the_real_controller`"), "6.7's Input line names the test")

## Pass 438: the moves heard through the buttons. Bible 6.7 promises distinct
## jump, double jump, wall jump, dash, pogo and land sounds, and pass 422 heard
## the fight through the real controller, but the moves' own sounds were only
## ever heard under a scripted intent. Each is pressed through `Input` here and
## must be heard once, alone, in the step that makes the move (a landing
## layers the surface's step under its thud, 6.7's layered footsteps).
func _heard(sound: String) -> int:
	return Sfx.recent.count(sound)


func test_the_moves_are_heard_through_the_buttons() -> void:
	var moves := ["jump", "double_jump", "wall_jump", "dash", "pogo", "land"]
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(6, 11), {"boots": true, "stride": true, "glove": true})
	await _settle(p)
	# Jump, then Jump again in the air.
	Sfx.recent.clear()
	await press_for_real(p, ["jump"])
	check(Sfx.recent == ["jump"], "Jump is heard once, alone, as the hero leaves the floor (%s)" % [Sfx.recent])
	await frames(10)
	release_for_real(["jump"])
	await frames(2)
	Sfx.recent.clear()
	await press_for_real(p, ["jump"])
	check(Sfx.recent == ["double_jump"], "Jump in the air is the double jump's own sound (%s)" % [Sfx.recent])
	release_for_real(["jump"])
	Sfx.recent.clear()
	var landed := false
	for i in 120:
		await frames(1)
		if p.is_on_floor():
			landed = true
			break
	check(landed and _heard("land") == 1, "coming down is heard once, as the hero lands (%s)" % [Sfx.recent])
	check(Sfx.recent.filter(func(s: String) -> bool: return s != "land" and not s.begins_with("step")).is_empty(),
		"with nothing but the surface's step under it (%s)" % [Sfx.recent])
	await frames(20)
	# Dash along the floor.
	Sfx.recent.clear()
	await press_for_real(p, ["dash"])
	release_for_real(["dash"])
	check(_heard("dash") == 1 and not Sfx.recent.has("jump"), "Dash is heard once, on its press (%s)" % [Sfx.recent])
	await frames(30)
	room.free()
	# Wall jump: up against the left wall, Left held, Jump.
	room = make_room(FLAT)
	p = make_player(room, Vector2i(2, 11), {"boots": true, "glove": true})
	await _settle(p)
	await press_for_real(p, ["jump", "move_left"])
	release_for_real(["jump"])
	var sliding := false
	for i in 60:
		await frames(1)
		if p.wall_dir != 0 and not p.is_on_floor() and p.velocity.y > 0.0:
			sliding = true
			break
	check(sliding, "held Left, the hero slides on the wall")
	Sfx.recent.clear()
	Input.action_press("jump")
	await frames(2)
	release_for_real(["jump", "move_left"])
	check(Sfx.recent == ["wall_jump"], "Jump off the wall is the wall jump's own sound, once (%s)" % [Sfx.recent])
	await frames(40)
	room.free()
	# Pogo: Down held and Attack over spikes.
	var spikes := ["####################"]
	for i in 9:
		spikes.append("#..................#")
	spikes.append("#..^^^^^^^^^^^^^^..#")
	spikes.append("####################")
	room = make_room(spikes)
	p = make_player(room, Vector2i(9, 3), {"boots": true})
	p.input = PlayerInput.new()
	Input.action_press("move_down")
	var struck := false
	var at := -1
	Sfx.recent.clear()
	for i in 90:
		if not struck and p.velocity.y > 0.0 and p.global_position.y > 11 * 16 - 9 - 28.0:
			Input.action_press("attack")
			struck = true
			Sfx.recent.clear()
		await frames(1)
		if p.velocity.y < -300.0:
			at = i
			break
	release_for_real(["move_down", "attack"])
	check(at >= 0 and _heard("pogo") == 1 and not Sfx.recent.has("hurt"), "the pogo off the spikes is heard once, with no hurt (%s)" % [Sfx.recent])
	room.free()
	for m: String in moves:
		check(FileAccess.file_exists("res://assets/sfx/%s.wav" % m), "%s has a sound of its own" % m)
	var line := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 6.7 ", 1)
	check(line.contains("`test_the_moves_are_heard_through_the_buttons`"), "6.7 names the test")



func test_ladders_climb_hang_and_step_off_the_top() -> void:
	var room := make_room(LADDERS)
	var p := make_player(room, Vector2i(9, 10))
	await frames(3)
	var x_mid := 9.5 * 16.0
	p.global_position.x = x_mid + 5.0
	p.input.up = true
	await frames(1)
	check(p.on_ladder, "Up at a ladder takes hold of it")
	await frames(20)
	check(p.on_ladder and is_equal_approx(p.velocity.y, -MovementTuning.new().ladder_speed), "it climbs at ladder speed, with no gravity (vy %.0f)" % p.velocity.y)
	check(absf(p.global_position.x - x_mid) < 0.5, "and centers you on the rungs (x %.1f)" % p.global_position.x)
	check(PlayerVisual.current_pose(p) == "climb", "in the climbing pose")
	p.input.up = false
	var y := p.global_position.y
	await frames(30)
	check(p.on_ladder and absf(p.global_position.y - y) < 0.5, "let go of Up and you hang there")
	p.input.up = true
	for i in 120:
		await frames(1)
		if not p.on_ladder:
			break
	p.input.up = false
	await frames(5)
	check(not p.on_ladder and p.is_on_floor(), "over the top you step onto it")
	check(absf(p.global_position.y - 4 * 16.0) < 1.0, "standing on the ladder's top plank (y %.1f)" % p.global_position.y)
	# Back down: Down on the top plank climbs on.
	p.input.down = true
	await frames(2)
	check(p.on_ladder, "Down on the top takes hold again")
	for i in 120:
		await frames(1)
		if not p.on_ladder:
			break
	p.input.down = false
	await frames(3)
	check(p.is_on_floor() and absf(p.global_position.y - 11 * 16.0) < 1.0, "and climbing down onto the floor lets go (y %.1f)" % p.global_position.y)
	room.free()


func test_ladders_jump_off_hits_and_hanging_ends() -> void:
	var room := make_room(LADDERS)
	var p := make_player(room, Vector2i(9, 10))
	await frames(3)
	p.input.up = true
	await frames(30)
	p.input.up = false
	check(p.on_ladder, "on the ladder")
	var x0 := p.global_position.x
	p.input.move_x = 1
	p.input.jump_pressed = true
	p.input.jump_held = true
	await frames(1)
	check(not p.on_ladder and p.velocity.y < -300.0, "Jump leaves with a full jump (vy %.0f)" % p.velocity.y)
	await frames(10)
	check(p.global_position.x > x0 + 10.0, "off to the side you pressed")
	p.input.move_x = 0
	p.input.jump_held = false
	p.input.up = true
	await frames(1)
	check(not p.on_ladder, "and can't catch the same ladder again straight away")
	p.input.up = false
	# A blow knocks you off.
	p.teleport(Vector2(9.5 * 16.0, 11 * 16.0))
	await frames(3)
	p.input.up = true
	await frames(20)
	p.input.up = false
	check(p.on_ladder, "back on the ladder")
	p.take_damage(1)
	await frames(1)
	check(not p.on_ladder, "a blow knocks you off the rungs")
	await frames(20)
	# The hanging ladder: climb down off its bottom and you fall.
	p.teleport(Vector2(14.5 * 16.0, 8 * 16.0 + 2.0))
	p.input.up = true
	await frames(1)
	p.input.up = false
	check(p.on_ladder, "you catch a hanging ladder from the air")
	p.input.down = true
	for i in 90:
		await frames(1)
		if not p.on_ladder:
			break
	p.input.down = false
	check(not p.on_ladder, "climb off its bottom and you let go")
	await frames(30)
	check(p.is_on_floor(), "and drop to the floor")
	room.free()


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await frames(1)
	return cond.call()


## Bible 6.11 (pass 280): taking hold of a ladder refreshes the double jump
## and the air dash; a swing in progress can't take hold until it ends; and on
## the rungs there are no attacks: a swing, a throw or a spell pressed there
## does nothing, and you stay on.
func test_a_ladder_refreshes_air_moves_and_holds_no_attacks() -> void:
	var room := make_room(LADDERS)
	var p := make_player(room, Vector2i(9, 10), {"rune_dagger": true})
	await frames(3)
	# From the air, with the double jump and the air dash spent.
	p.teleport(Vector2(14.5 * 16.0, 7 * 16.0))
	await frames(2)
	check(not p.is_on_floor(), "in the air beside the hanging ladder")
	p.has_double_jump = false
	p.air_dash_charges = 0
	p.input.up = true
	await frames(1)
	p.input.up = false
	check(p.on_ladder, "you catch the hanging ladder from the air")
	check(p.has_double_jump and p.air_dash_charges >= 1, "and taking hold gives back the double jump and the air dash (%s, %d)" % [p.has_double_jump, p.air_dash_charges])
	p.input.down = true
	await _until(func() -> bool: return not p.on_ladder, 120)
	p.input.down = false
	await frames(30)
	# Mid-swing at the foot of the long ladder: Up waits for the swing to end.
	p.teleport(Vector2(9.5 * 16.0, 11 * 16.0))
	await frames(3)
	p.input.attack_pressed = true
	await frames(1)
	check(p.is_attacking, "a swing starts")
	p.input.up = true
	await frames(1)
	check(not p.on_ladder, "mid-swing, Up does not take hold")
	await _until(func() -> bool: return p.on_ladder, 60)
	check(p.on_ladder and not p.is_attacking, "once the swing ends, it does")
	await frames(20)
	p.input.up = false
	await frames(2)
	# On the rungs: no swing, no throw, no spell.
	var y := p.global_position.y
	var mp := p.mp
	var throws := p.throws
	var kids := room.get_child_count()
	p.input.attack_pressed = true
	await frames(1)
	p.input.throw_pressed = true
	await frames(1)
	p.input.spell_pressed = true
	await frames(10)
	check(p.on_ladder and absf(p.global_position.y - y) < 0.5, "you stay on the rungs (y %.1f -> %.1f)" % [y, p.global_position.y])
	check(not p.is_attacking, "a swing pressed on a ladder does not swing")
	check(p.throws == throws, "nor does a throw throw")
	check(p.mp >= mp and room.get_child_count() == kids, "nor a spell cast (mp %.0f -> %.0f, nodes %d -> %d)" % [mp, p.mp, kids, room.get_child_count()])
	room.free()


## Dash on a ladder (bible 6.11, pass 240): a stride leaves the rungs and
## dashes; a press that can't dash (no Elven Stride yet) keeps you on them.
func test_a_dash_only_lets_go_of_a_ladder_when_it_dashes() -> void:
	var room := make_room(LADDERS)
	var p := make_player(room, Vector2i(9, 10), {"stride": false})
	await frames(3)
	p.input.up = true
	await frames(30)
	p.input.up = false
	check(p.on_ladder, "on the ladder")
	var y := p.global_position.y
	p.input.dash_pressed = true
	await frames(1)
	await frames(20)
	check(p.on_ladder and not p.is_dashing and absf(p.global_position.y - y) < 0.5, "without the Elven Stride a dash press keeps you on the rungs (y %.1f -> %.1f)" % [y, p.global_position.y])
	p.abilities["stride"] = true
	p.input.move_x = 1
	p.input.dash_pressed = true
	await frames(1)
	check(not p.on_ladder and p.is_dashing, "with it, the stride leaves the ladder and dashes")
	await frames(9)
	check(p.global_position.x > 9.5 * 16.0 + 40.0, "off to the side (x %.1f)" % p.global_position.x)
	p.input.move_x = 0
	room.free()


## The camera on a ladder (bible 6.7, pass 130): it leads the way you climb.
func test_the_camera_leads_the_way_up_or_down_a_ladder() -> void:
	check(GameCamera.CLIMB_LEAD == 64.0 and GameCamera.CLIMB_LEAD_EASE == 0.5, "the climb lead is 64 px, eased over 0.5 s")
	var room := make_room(LADDERS)
	var p := make_player(room, Vector2i(9, 10))
	var cam := GameCamera.new()
	cam.target = p
	cam.view_size = Vector2(160, 90)
	cam.set_room_limits(room.pixel_rect())
	arena.add_child(cam)
	await frames(30)
	check(absf(cam._climb_lead) < 0.5, "off a ladder there is no lead")
	p.input.up = true
	await frames(40)
	check(p.on_ladder and cam._climb_lead < -0.8 * GameCamera.CLIMB_LEAD, "climbing up, it looks up the ladder (%.1f)" % cam._climb_lead)
	check(absf(cam._look_ahead) < 0.3 * GameCamera.LOOK_AHEAD, "and stops looking sideways (%.1f)" % cam._look_ahead)
	p.input.up = false
	await frames(30)
	check(p.on_ladder and cam._climb_lead < -0.8 * GameCamera.CLIMB_LEAD, "hanging still keeps the lead (%.1f)" % cam._climb_lead)
	p.input.down = true
	await frames(30)
	check(cam._climb_lead > 0.8 * GameCamera.CLIMB_LEAD, "climbing down, it looks down (%.1f)" % cam._climb_lead)
	for i in 120:
		await frames(1)
		if not p.on_ladder:
			break
	p.input.down = false
	await frames(40)
	check(not p.on_ladder and absf(cam._climb_lead) < 0.1 * GameCamera.CLIMB_LEAD, "off the ladder it eases back (%.1f)" % cam._climb_lead)
	cam.queue_free()


func test_ladder_numbers_match_bible_6_11() -> void:
	var t := MovementTuning.new()
	check(t.ladder_speed == 90.0, "ladder speed 90 px/s")
	check(t.ladder_snap == 240.0, "ladder snap 240 px/s")
	check(t.ladder_regrab == 0.25, "regrab 0.25 s")
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("### 6.11 Ladders"), "the bible has the ladder section")
	check(bible.contains("| Climb speed | 90 px/s"), "and its numbers")



## Pass 137 (bible 13.3): a field that takes hold of you is heard. A wind
## current's gust catches you; a wrong-gravity pocket shimmers as it lifts your
## weight and hums down as you leave it, and the edge does not chatter.
func test_wind_and_wrong_gravity_are_heard() -> void:
	var rows := ["##############################"]
	for y in 12:
		rows.append("#...vvvvvv...................#")
	rows.append("##############################")
	var room := make_room(rows)
	Sfx.recent.clear()
	var p := make_player(room, Vector2i(6, 3), {"boots": false})
	await frames(4)
	check(Sfx.recent.count("drift_in") == 1, "the pocket lifts your weight with a shimmer, once (%s)" % [Sfx.recent])
	for i in 300:
		await frames(1)
		if p.is_on_floor():
			break
	p.input.move_x = 1
	for i in 120:
		await frames(1)
		if Sfx.recent.has("drift_out"):
			break
	p.input.move_x = 0
	check(Sfx.recent.has("drift_out") and not p.gravity_scale < 1.0, "and walking out, the weight returns with a hum")
	check(Sfx.recent.count("drift_in") == 1 and Sfx.recent.count("drift_out") == 1, "each cue sounds once at the edge")
	room.free()

	rows = [
		"#####################",
		"#...................#",
		"#.....>>>>>>>>>>....#",
		"#.....>>>>>>>>>>....#",
		"#######>>>>>>>>>....#",
		"#.....>>>>>>>>>>....#",
		"#...................#",
		"#...................#",
		"#...................#",
		"#####################",
	]
	room = make_room(rows)
	p = make_player(room, Vector2i(4, 3), {"boots": false, "glove": false})
	await _settle(p)
	Sfx.recent.clear()
	check(not Sfx.recent.has("wind_catch"), "no gust on the ledge")
	await _walk_off_ledge(p)
	await frames(10)
	check(Sfx.recent.count("wind_catch") == 1, "off the ledge, the current catches you with a gust, once (%s)" % [Sfx.recent])
	check(Player.FIELD_CUE_GAP == 0.3, "a cue waits 0.3 s before it may sound again")
	room.free()



## Pass 139 (bible 6.2, 6.5): a mid-air dash that clips the top of a tunnel's
## mouth with the head by up to 4 px slides in; 5 px stops on the lip.
const TUNNEL := [
	"######################",
	"#.........############",
	"#.........############",
	"#.........############",
	"#.........############",
	"#.........############",
	"#.........############",
	"#.........############",
	"#.........############",
	"#.........############",
	"#....................#",
	"#....................#",
	"#....................#",
	"#.........############",
	"#.........############",
	"#.........############",
	"######################",
]


func _dash_into_tunnel(clip: float) -> bool:
	var room := make_room(TUNNEL)
	var p := make_player(room, Vector2i(5, 15), {"stride": true, "boots": false})
	await _settle(p)
	# Hang with the head `clip` px above the tunnel's ceiling (y 160), just short of its mouth.
	p.teleport(Vector2(9 * 16 + 2, 160.0 - clip + 40.0))
	p.velocity = Vector2.ZERO
	p.input.move_x = 1
	p.input.dash_pressed = true
	await frames(12)
	p.input.move_x = 0
	var inside := p.global_position.x > 10 * 16 + 20
	room.free()
	return inside


func test_head_correction_slides_a_dash_into_a_tunnel() -> void:
	check(await _dash_into_tunnel(2.0), "clipping the tunnel's top by 2 px, the dash slides in")
	check(await _dash_into_tunnel(4.0), "by 4 px, it still slides in")
	check(not await _dash_into_tunnel(5.0), "by 5 px, it stops on the lip")


## Pass 264 (bible 6.5): what the feet kick up takes the ground's look, as the
## steps take its sound. A landing on stone puffs pale dust, in the Haar's marsh
## it flings dark mud, and in Vorrhallow's standing water it throws spray that
## falls back. The run, the jump and a dash along the floor do the same.
func test_what_the_feet_kick_up_takes_the_ground_s_look() -> void:
	var landing := func(room: Room) -> Dust:
		for i in 90:
			await frames(1)
			for c in room.get_children():
				if c is Dust and c.kind == "land":
					return c
		return null
	var stone := Room.from_text(room_text(["name: T", "zone: tower", "surface: stone"], grid_rows(10, 23)), "t/stone")
	arena.add_child(stone)
	var p := make_player(stone, Vector2i(5, 12))
	var d: Dust = await landing.call(stone)
	check(d != null and d.surface == "" and d._color == Dust.KINDS["land"]["color"], "a landing on stone puffs pale dust")
	stone.queue_free()
	await frames(1)
	var marsh := Room.from_text(room_text(["name: T", "zone: haar"], grid_rows(10, 23)), "t/marsh")
	arena.add_child(marsh)
	p = make_player(marsh, Vector2i(5, 12))
	d = await landing.call(marsh)
	check(d != null and d.surface == "mud" and d._color == Dust.GROUND_TINT["mud"], "in the marsh it flings mud (%s)" % (d.surface if d else "none"))
	await frames(10)
	p.input.move_x = 1
	var kicked := ""
	for i in 40:
		await frames(1)
		for c in marsh.get_children():
			if c is Dust and c.kind == "run":
				kicked = c.surface
	p.input.move_x = 0
	check(kicked == "mud", "and the run kicks up mud too (%s)" % kicked)
	marsh.queue_free()
	await frames(1)
	var w := make_world({}, "vorrhallow/flooded_hall")
	await frames(3)
	var tide: Tide = w.room.tide
	var wade := Vector2(w.room.size_tiles.x * 0.5 * Room.TILE, (tide.row + 1) * Room.TILE)
	while w.room.tiles.get_cell_source_id(w.room.cell_at(wade + Vector2(0, 2))) == -1 or w.room.tiles.get_cell_source_id(w.room.cell_at(wade + Vector2(0, -Room.TILE + 2))) != -1:
		wade.x += Room.TILE
	w.player.teleport(wade - Vector2(0, Room.TILE * 5))
	d = await landing.call(w.room)
	check(d != null and d.surface == "wade" and d._color == Dust.GROUND_TINT["wade"], "in standing water a landing throws spray (%s)" % (d.surface if d else "none"))
	if d != null:
		var up := 0
		for q: Array in d._particles:
			if (q[1] as Vector2).y < 0.0:
				up += 1
		check(up == d._particles.size() and d._rise > 0.0, "thrown up, every drop, to fall back (%d of %d)" % [up, d._particles.size()])
	GameState.set_flag(Tide.DRAIN_FLAG)
	w._enter("vorrhallow/flooded_hall")
	await frames(3)
	w.player.teleport(wade - Vector2(0, Room.TILE * 5))
	d = await landing.call(w.room)
	check(d != null and d.surface == "", "drained, the hall's floor puffs dust again")
	GameState.data.flags.erase(Tide.DRAIN_FLAG)


## Pass 272: bible 4.4 says Vorrhallow's standing water (pass 259) is not deep
## enough to swim, and that it neither slows you nor hides a hazard. Nothing
## held that: a tide cell that read as swimming water, or a drag on the wade,
## would have passed every test. Here, in the Flooded Hall's water: the run
## reaches full speed, a jump rises its full height, and the spike pit under
## the surface still bites, all without a stroke of swimming.
func test_wading_neither_slows_nor_floats_nor_hides_the_spikes() -> void:
	var w := make_world({}, "vorrhallow/flooded_hall", cell_feet(10, 19))
	for c in w.room.get_children():
		if c is Enemy:
			c.queue_free()
	await frames(3)
	var p := w.player
	var t := p.tuning
	var tide: Tide = w.room.tide
	check(tide != null and not tide.drained(), "the hall stands in water")
	if tide == null:
		return
	await _settle(p)
	check(w.room.surface_at(p.global_position + Vector2(0, 2)) == "wade", "the hero stands in it (%s)" % w.room.surface_at(p.global_position + Vector2(0, 2)))
	# Run east through the water, short of the pit (tiles 26-29).
	var swam := false
	var top := 0.0
	p.input.move_x = 1
	for i in 36:
		await frames(1)
		swam = swam or p.swimming
		top = maxf(top, p.velocity.x)
	p.input.move_x = 0
	check(not swam, "wading is not swimming")
	check_near(top, t.run_speed, 1.0, "the run reaches full speed in the water (px/s)")
	await _settle(p)
	var start_y := p.global_position.y
	var min_y := start_y
	p.input.jump_pressed = true
	p.input.jump_held = true
	for i in 70:
		await frames(1)
		swam = swam or p.swimming
		min_y = minf(min_y, p.global_position.y)
	p.input.jump_held = false
	check_near(start_y - min_y, t.jump_height, 3.0, "a jump out of the water rises its full height (px)")
	check(not swam, "and never takes a stroke")
	# The pit under the surface: water to the spikes, and the spikes still bite.
	var pit := Vector2i(27, 20)
	check(tide.has_point(Vector2(pit) * Room.TILE + Vector2(8, 8)), "the spike pit is full of water")
	p.max_hp = 999
	p.hp = 999
	p.teleport(w.room.to_global(Vector2(pit.x * Room.TILE + Room.TILE * 0.5, pit.y * Room.TILE + 4)))
	for i in 40:
		await frames(1)
		swam = swam or p.swimming
		if p.hp < 999:
			break
	check(p.hp < 999, "the spikes under the water still hurt (hp %d)" % p.hp)
	check(not swam, "and the pit is waded, not swum")


## Bible 6 (pass 312): poison never touches movement. Since pass 306 a tick takes
## up to 4 health, and passes 309 and 310 gave it a number and a sound, but it is
## no blow: no knockback, no hurt flash, no invulnerability, no lost dash or
## climb. A poisoned hero and a well one, given the same hands, move frame for
## frame alike through a dash, a wall slide and a ladder climb, with a tick
## landing inside each.
func test_a_poison_tick_never_touches_movement() -> void:
	var rows := grid_rows(40, 23)
	put_tiles(rows, 30, 4, "#", 3, 16)
	put_tiles(rows, 6, 8, "\"", 1, 12)
	put_tiles(rows, 4, 19, "P")
	var paths := []
	var states := []
	for sick: bool in [false, true]:
		var w := make_world({"test/a": room_text(["name: A", "zone: test"], rows)}, "test/a", cell_feet(18, 19))
		var p := w.player
		p.abilities.stride = true
		p.abilities.glove = true
		await frames(3)
		if sick:
			p.poison()
		var path: Array[Vector2] = []
		var seen := {}
		for f in 150:
			var i := p.input
			i.dash_pressed = f == 6
			i.jump_pressed = f == 40
			i.jump_held = f >= 40 and f < 60
			i.move_x = 1 if f < 100 else 0
			if f == 100:
				p.teleport(cell_feet(6, 19))
			i.up = f > 102
			if sick and f in [8, 45, 70, 130]:
				p._poison_tick = 0.0001
			await frames(1)
			path.append(p.global_position)
			if sick and f in [8, 45, 70, 130]:
				seen[f] = "dash" if p.is_dashing else ("slide" if p.is_wall_sliding else ("ladder" if p.on_ladder else ("air" if not p.is_on_floor() else "floor")))
		paths.append(path)
		states.append([p.hp, p.max_hp, seen])
		p.cure_poison()
		w.queue_free()
		await frames(2)
	var seen: Dictionary = states[1][2]
	check(seen.get(8) == "dash" and seen.get(45) == "air" and seen.get(70) == "slide" and seen.get(130) == "ladder", "ticks land in a dash, a jump, a wall slide and a climb (%s)" % seen)
	check(states[1][0] < states[0][0], "and bite (%d against %d)" % [states[1][0], states[0][0]])
	var first := -1
	for f in paths[0].size():
		if not (paths[0][f] as Vector2).is_equal_approx(paths[1][f]):
			first = f
			break
	check(first == -1, "poisoned and well heroes move alike, frame for frame (first apart at %d)" % first)


## Bible 6 (pass 320): a Rune Dagger throw never touches movement. Since Sean's
## flick (2026-10-30) the throw plays a low ready crouch over the legs, but it is
## drawn, not done: no stop, no slow, no nudge, no lost jump or wall slide. A
## hero who throws on the run, at the top of a jump and in a wall slide moves
## frame for frame with one who never throws.
func test_a_dagger_throw_never_touches_movement() -> void:
	var rows := grid_rows(40, 23)
	put_tiles(rows, 30, 4, "#", 3, 16)
	var paths := []
	var states := []
	const AT := [6, 50, 100]
	for thrower: bool in [false, true]:
		var w := make_world({"test/a": room_text(["name: A", "zone: test"], rows)}, "test/a", cell_feet(18, 19))
		var p := w.player
		p.abilities.glove = true
		p.abilities.rune_dagger = true
		GameState.data.equipment.shield = ""
		await frames(3)
		var path: Array[Vector2] = []
		var seen := {}
		for f in 130:
			var i := p.input
			i.jump_pressed = f == 44
			i.jump_held = f >= 44 and f < 64
			i.move_x = 1
			i.throw_pressed = thrower and f in AT
			await frames(1)
			path.append(p.global_position)
			if thrower and f in AT:
				seen[f] = "slide" if p.is_wall_sliding else ("air" if not p.is_on_floor() else "run")
		paths.append(path)
		states.append([p.throws, seen])
		w.queue_free()
		await frames(2)
	var seen: Dictionary = states[1][1]
	check(seen.get(6) == "run" and seen.get(50) == "air" and seen.get(100) == "slide", "throws go on the run, in a jump and in a wall slide (%s)" % seen)
	check(int(states[1][0]) == AT.size() and int(states[0][0]) == 0, "and each one flies (%d thrown)" % states[1][0])
	var first := -1
	for f in paths[0].size():
		if not (paths[0][f] as Vector2).is_equal_approx(paths[1][f]):
			first = f
			break
	check(first == -1, "a thrower and a hero who never throws move alike, frame for frame (first apart at %d)" % first)


## Pass 336: the fields that move you from outside `MovementTuning` were each
## written only in their zone's or guardian's section, and their tests read the
## constant back. Bible 6.14 gathers them; each row must write its constant.
func test_every_field_number_is_written_in_bible_6_14() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var table := bible.get_slice("### 6.14 ", 1).get_slice("\n## 7. ", 0)
	var fields := {
		"GravityDrift.PULL": GravityDrift.PULL, "LeafFall.WEIGHT": LeafFall.WEIGHT,
		"Updraft.LIFT": Updraft.LIFT, "Player.UPDRAFT_ACCEL": Player.UPDRAFT_ACCEL,
		"World.RISE_SPEED": absf(World.RISE_SPEED), "Player.BIG_DROP": Player.BIG_DROP,
	}
	for name: String in fields:
		var at := table.find("`%s`" % name)
		if not check(at >= 0, "6.14 names %s" % name):
			continue
		var row := table.substr(table.rfind("\n", at) + 1).get_slice("\n", 0)
		check(written_exactly_in(row, float(fields[name])), "6.14's row writes %s, %s (%s)" % [name, String.num(fields[name]), row])


## Pass 344: the check above finds a number anywhere in section 6, in any of
## its forms (0.8 is also "1", "80%" and "800 ms"), so two tuning numbers the
## section never named passed on coincidence: `hurt_invuln` (0.8, found in the
## land squash's "1.25x0.8") and `slash_recoil` (120, found in the climb jump).
## This holds each number to its own subsection, written as the bible writes a
## number there (the number itself, two places, a whole px, a thousands comma, ms or a
## percent).
func test_every_movement_number_is_written_where_it_belongs() -> void:
	const HOME := {
		"6.1": ["run_speed", "ground_accel", "ground_decel", "turn_multiplier", "walk_fraction", "walk_tilt", "run_tilt", "stick_vertical_angle"],
		"6.2": ["jump_height", "jump_time_to_apex", "fall_gravity_multiplier", "jump_cut_multiplier", "apex_threshold",
			"apex_gravity_multiplier", "max_fall_speed", "max_fast_fall_speed", "air_accel", "air_decel", "coyote_time",
			"jump_buffer_time", "corner_correction_px", "ledge_correction_px", "head_correction_px", "gravity", "jump_velocity"],
		"6.3": ["wall_slide_speed", "wall_stick_time", "wall_jump_x", "wall_jump_y", "wall_climb_jump_x", "wall_jump_lock",
			"wall_climb_jump_lock", "wall_jump_blend", "wall_coyote_time"],
		"6.4": ["double_jump_height", "double_jump_velocity"],
		"6.5": ["dash_speed", "dash_time", "dash_invuln", "air_dash_charges", "ground_dash_cooldown", "dash_buffer_time", "ground_dash_snap"],
		"6.6": ["pogo_bounce", "pogo_bounce_held", "pogo_hitstop", "pod_bounce", "slash_active", "down_strike_active", "attack_cooldown"],
		"6.7": ["hurt_invuln", "slash_recoil"],
		"6.8": ["swim_speed_multiplier", "swim_float", "swim_sink", "swim_drag", "swim_stroke"],
		"6.9": ["wind_speed", "wind_drag"],
		"6.10": ["glide_fall_speed", "glide_brake"],
		"6.11": ["ladder_speed", "ladder_snap", "ladder_regrab"],
		"6.12": ["sap_speed", "sap_jump"],
	}
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var six := bible.get_slice("## 6. Movement", 1).get_slice("\n## 7. ", 0)
	var t := MovementTuning.new()
	var homed := {}
	var astray := []
	for sec: String in HOME:
		var text := six.get_slice("\n### %s " % sec, 1).get_slice("\n### ", 0)
		# 6.7 is the juice list, full of numbers; its two tuning numbers have
		# a line of their own.
		if sec == "6.7":
			text = text.get_slice("- **Hurt and recoil", 1).get_slice("\n", 0)
		for prop: String in HOME[sec]:
			homed[prop] = true
			var f := float(t.get(prop))
			var found := written_exactly_in(text, f)
			if not found:
				astray.append("%s %s not in %s" % [prop, String.num(f), sec])
	check(astray.is_empty(), "every movement number is written in its own subsection (%s)" % [astray])
	var unhomed := []
	for prop: Dictionary in t.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.type in [TYPE_FLOAT, TYPE_INT] and not homed.has(prop.name):
			unhomed.append(prop.name)
	check(unhomed.is_empty(), "every tuning number has a home subsection (%s)" % [unhomed])


## Pass 352 (bible 6.7): the camera's and the shake's numbers were held only by
## tests that copied them as literals, the look-down by none, and the follow
## rate, focus point and shake reach by no text. Every number `GameCamera` and
## `Feel` define is written on its own line of 6.7 (the render density in 12.1).
func test_every_camera_number_is_written_on_its_line() -> void:
	var feel: Script = load("res://scripts/autoload/feel.gd")
	var home := {
		"- **Camera:**": [GameCamera, ["DEADZONE", "LOOK_AHEAD", "LOOK_AHEAD_EASE", "LOOK_DOWN", "LOOK_DOWN_DELAY", "LOOK_UP",
			"CLIMB_LEAD", "CLIMB_LEAD_EASE", "FOLLOW_SPEED", "FOCUS_OFFSET"]],
		"- **Wide camera": [GameCamera, ["WIDE", "ZOOM_EASE"]],
		"- **Screen shake:**": [feel, ["TRAUMA_DECAY", "MAX_SHAKE_OFFSET"]],
		"- **Hit-stop:**": [feel, ["BOSS_KILL_HITSTOP", "BOSS_KILL_SLOWMO", "BOSS_KILL_FLASH"]],
		"### 12.1 ": [GameCamera, ["DETAIL"]],
	}
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	var homed := {}
	var astray := []
	for line: String in home:
		# The juice list's lines are 6.7's own; other sections have lines of
		# the same name.
		var within := bible if line.begins_with("###") else bible.get_slice("\n### 6.7 ", 1).get_slice("\n### ", 0)
		var text := within.get_slice(line, 1)
		text = text.get_slice("\n### ", 0) if line.begins_with("###") else text.get_slice("\n- ", 0)
		check(text != "", "the bible has the line %s" % line)
		var script: Script = home[line][0]
		var consts := script.get_script_constant_map()
		for name: String in home[line][1]:
			homed[script.resource_path + name] = true
			var v: Variant = consts[name]
			# A pair is written as its two parts (16x24, 10 px across and 7 up
			# or down); a part of 0 says nothing.
			var parts: Array = [absf(v.x), absf(v.y)] if v is Vector2 else [float(v)]
			for f: float in parts:
				if f != 0.0 and not written_exactly_in(text, f):
					astray.append("%s %s not on %s" % [name, String.num(f), line])
	check(astray.is_empty(), "every camera and shake number is written on its own line (%s)" % [astray])
	var unhomed := []
	for script: Script in [GameCamera, feel]:
		var consts := script.get_script_constant_map()
		for name: String in consts:
			if typeof(consts[name]) in [TYPE_FLOAT, TYPE_INT, TYPE_VECTOR2] and not homed.has(script.resource_path + name):
				unhomed.append(name)
	check(unhomed.is_empty(), "every camera and shake number has a line (%s)" % [unhomed])


## Pass 355 (levels/README.md): the README gives the room builder safe jumps,
## "a little under the real movement", and pass 331 found its room sizes out
## of date, but no test had ever made its jumps. Each one it names is read from
## the text and made from a standstill with the real controller: a ledge `up`
## rows above the floor whose near edge is `across` tiles from where you
## stand, with the README's 3 tiles of headroom over the ledge.
func test_the_readmes_safe_jumps_are_real() -> void:
	var readme := FileAccess.get_file_as_string("res://levels/README.md")
	var line := readme.get_slice("Safe numbers for layouts", 1).get_slice("Leave", 0).replace("\n", " ")
	var re := RegEx.create_from_string("(\\d+) (?:tiles )?up with (\\d+) across")
	var jumps := []
	for m in re.search_all(line):
		jumps.append([int(m.get_string(1)), int(m.get_string(2))])
	check(jumps == [[4, 2], [3, 4], [2, 5]], "the README names three safe jumps (%s)" % [jumps])
	var headroom := int(readme.get_slice("Leave ", 1).get_slice(" clear tiles of headroom", 0))
	# Four since pass 508: the 2x hero stands about 60 px tall (Reach.BODY_ROWS).
	check(headroom == Reach.BODY_ROWS, "and %d tiles of headroom (%d)" % [Reach.BODY_ROWS, headroom])
	check(readme.contains("reachable from the floor go 4 rows above it") and [4, 2] in jumps, "a platform 4 rows up is one of them")
	for j: Array in jumps:
		var up: int = j[0]
		var across: int = j[1]
		# Floor top at row 16; you stand in column 3; the ledge's top is `up`
		# rows higher, from column 3 + across to the far wall.
		var rows := grid_rows(24, 19)
		var top := 16 - up
		put_tiles(rows, 3 + across, top, "#", 24 - 4 - across, up)
		# The ceiling over the ledge sits `headroom` clear tiles above it.
		put_tiles(rows, 3 + across, 0, "#", 24 - 4 - across, top - headroom)
		var room := make_room(rows.map(func(r: Array) -> String: return "".join(PackedStringArray(r))))
		var p := make_player(room, Vector2i(3, 15))
		await frames(6)
		p.input.move_x = 1
		p.input.jump_pressed = true
		p.input.jump_held = true
		await frames(1)
		p.input.jump_pressed = false
		var landed := false
		for i in 120:
			await frames(1)
			if p.is_on_floor() and p.velocity.y >= 0.0 and i > 4:
				landed = absf(p.global_position.y - float(top * Room.TILE)) <= 1.0
				break
		check(landed, "%d up with %d across: a standstill jump lands on the ledge (feet at %.0f, ledge at %d)" % [up, across, p.global_position.y, top * Room.TILE])
		room.queue_free()
		await frames(1)


## Bible 6.8 (pass 376): swimming keeps the land's moves. Deep water hands back
## a spent double jump and air dash; a dash under water runs at the land's dash
## speed and holds its line (no float, no drag, no swim slowdown); a swing cuts
## a foe in the water as on land. The one land move the water takes is the
## Thrust's charge, a lunge along a floor that a swimmer has not got.
func test_swimming_keeps_the_lands_moves() -> void:
	var room := _pool_room()
	var p := make_player(room, Vector2i(4, 14), {"boots": true, "stride": true})
	await frames(30)
	check(p.swimming, "in the pool")
	p.has_double_jump = false
	p.air_dash_charges = 0
	await frames(1)
	check(p.has_double_jump and p.air_dash_charges >= p.tuning.air_dash_charges, "the water hands back a spent double jump and air dash")
	# A dash under water: the land's speed, and a level line.
	p.facing = 1
	var y0 := p.global_position.y
	var x0 := p.global_position.x
	p.input.dash_pressed = true
	await frames(1)
	p.input.dash_pressed = false
	var fastest := 0.0
	var drift := 0.0
	var dashed := 0
	for i in 12:
		if p.is_dashing:
			dashed += 1
			fastest = maxf(fastest, absf(p.velocity.x))
			drift = maxf(drift, absf(p.global_position.y - y0))
		await frames(1)
	check(dashed > 0, "a dash goes under water")
	check_near(fastest, p.tuning.dash_speed, 1.0, "at the land's dash speed, not a swimmer's")
	check(drift < 1.0, "and holds its line: the water neither floats nor sinks it (%.1f px)" % drift)
	check(p.global_position.x - x0 >= p.tuning.dash_speed * p.tuning.dash_time * 0.9, "carrying the land's distance (%.0f px)" % (p.global_position.x - x0))
	# A swing cuts a foe in the water.
	p.global_position = Vector2(4 * Room.TILE + 8, 14 * Room.TILE)
	p.velocity = Vector2.ZERO
	await frames(20)
	var dummy := TrainingDummy.new()
	room.add_child(dummy)
	dummy.global_position = p.global_position + Vector2(30, 0)
	await frames(2)
	p.facing = 1
	p.input.attack_pressed = true
	await frames(1)
	p.input.attack_pressed = false
	await frames(12)
	check(p.swimming and dummy.hits_taken >= 1, "a swing cuts a foe in the water (%d)" % dummy.hits_taken)
	# The Thrust does not charge while swimming.
	p.thrust = true
	p.input.attack_held = true
	await frames(int(p.combat.thrust_charge * 60.0) + 20)
	p.input.attack_held = false
	check(p.attack_kind != "thrust", "the Thrust's charge, a lunge along a floor, is not taken in the water")
	check(FileAccess.get_file_as_string("res://docs/design-bible.md").contains("`test_swimming_keeps_the_lands_moves`"), "6.8 names the test")
	room.free()


## Pass 384 (bible 6.7, Input): "every action responds on the same frame it is
## pressed" was the one line of the juice checklist no test held. Every move
## test scripts the player's intent, so the path from a real button through
## `Input` and `PlayerInput.poll` to the move was never timed. Each move here is
## pressed through `Input` itself (the real controller, not a scripted intent)
## and must answer in the first physics step that sees the press.
## Pass 392: the held buttons, through the real controller. Pass 384 timed
## every press, but the moves that read a button held or let go (the jump cut,
## a tap's short hop, the apex hang, the fast fall) were only ever scripted.
## A release is seen in the step it is made, so each answers on that step.
func test_every_held_button_answers_on_its_frame() -> void:
	var t := MovementTuning.new()
	var g := t.gravity / 60.0
	# Letting go of Jump on the way up keeps 0.45 of the rise, in the step it is let go.
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(10, 11))
	await _settle(p)
	await press_for_real(p, ["jump"])
	await frames(2)
	var before := p.velocity.y
	check(before < -250.0 and Input.is_action_pressed("jump"), "rising fast with Jump held (%.0f)" % before)
	release_for_real(["jump"])
	await frames(1)
	check_near(p.velocity.y, before * t.jump_cut_multiplier + g, 0.5, "the release cuts the rise on its frame")
	room.free()
	# A tap: pressed and let go at once, a short hop of about 18 px.
	room = make_room(FLAT)
	p = make_player(room, Vector2i(10, 11))
	await _settle(p)
	var start_y := p.global_position.y
	var min_y := start_y
	await press_for_real(p, ["jump"])
	release_for_real(["jump"])
	for i in 40:
		await frames(1)
		min_y = minf(min_y, p.global_position.y)
	var h := start_y - min_y
	check(h > 10.0 and h < 26.0, "a tap hops about 18 px (%.1f)" % h)
	room.free()
	# Held over the top, Jump halves gravity while |vy| < 40 px/s.
	room = make_room(FLAT)
	p = make_player(room, Vector2i(10, 11))
	await _settle(p)
	await press_for_real(p, ["jump"])
	var hang := 0.0
	for i in 40:
		var vy := p.velocity.y
		await frames(1)
		if absf(vy) < t.apex_threshold - g and absf(p.velocity.y) < t.apex_threshold and not p.is_on_floor():
			hang = p.velocity.y - vy
			break
	check_near(hang, g * t.apex_gravity_multiplier, 0.5, "held Jump hangs at the apex at half gravity (%.2f)" % hang)
	release_for_real(["jump"])
	room.free()
	# Down held through a fall tops out at 620 px/s, and let go, falls back to 520.
	room = make_room(LEDGE)
	p = make_player(room, Vector2i(10, 1), {"glove": false})
	p.input = PlayerInput.new()
	Input.action_press("move_down")
	var top := 0.0
	for i in 40:
		await frames(1)
		top = maxf(top, p.velocity.y)
		if top >= t.max_fast_fall_speed:
			break
	check_near(top, t.max_fast_fall_speed, 0.01, "Down held falls at 620 px/s")
	release_for_real(["move_down"])
	await frames(1)
	check_near(p.velocity.y, t.max_fall_speed, 0.01, "let go, the fall drops back to 520 px/s on its frame")
	room.free()
	var line := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 6.7 ", 1).get_slice("- **Input", 1).get_slice("\n", 0)
	check(line.contains("`test_every_held_button_answers_on_its_frame`"), "6.7's Input line names the test")


func test_every_move_answers_on_the_frame_it_is_pressed() -> void:
	var t := MovementTuning.new()
	var grav := t.gravity / 60.0
	# On the floor: a jump, a dash, a slash and an up-slash.
	for move: Array in [[["jump"], "jump"], [["dash"], "dash"], [["attack"], "side"], [["move_up", "attack"], "up"]]:
		var room := make_room(FLAT)
		var p := make_player(room, Vector2i(10, 11))
		await _settle(p)
		await press_for_real(p, move[0])
		match String(move[1]):
			"jump":
				check(p.velocity.y < -t.jump_velocity + grav + 1.0, "a jump leaves the floor on its frame (vy %.0f)" % p.velocity.y)
			"dash":
				check(p.is_dashing and absf(p.velocity.x) == t.dash_speed, "a dash runs at %.0f px/s on its frame (%.0f)" % [t.dash_speed, p.velocity.x])
			_:
				check(p.is_attacking and p.attack_kind == move[1], "%s swings a %s slash on its frame (%s)" % [" + ".join(move[0]), move[1], p.attack_kind])
		release_for_real(move[0])
		room.free()
	# In the air, rising from a jump: a double jump, an air dash and a down-strike.
	for move: Array in [[["jump"], "double"], [["dash"], "air dash"], [["move_down", "attack"], "down"]]:
		var room := make_room(FLAT)
		var p := make_player(room, Vector2i(10, 11))
		await _settle(p)
		p.input.jump_pressed = true
		p.input.jump_held = true
		await frames(12)
		check(not p.is_on_floor() and p.has_double_jump, "in the air with the double jump unspent")
		await press_for_real(p, move[0])
		match String(move[1]):
			"double":
				check(not p.has_double_jump and p.velocity.y < -t.double_jump_velocity + grav + 1.0,
					"a double jump goes on its frame (vy %.0f)" % p.velocity.y)
			"air dash":
				check(p.is_dashing and absf(p.velocity.x) == t.dash_speed and p.velocity.y == 0.0,
					"an air dash goes level on its frame (%s)" % p.velocity)
			_:
				check(p.is_attacking and p.attack_kind == "down", "Down + Attack strikes down on its frame (%s)" % p.attack_kind)
		release_for_real(move[0])
		room.free()
	# On a wall with the Climbing Glove: a jump away from it.
	var wall_rows := ["################"]
	for y in 18:
		wall_rows.append("#..............#")
	wall_rows.append("################")
	var room_w := make_room(wall_rows)
	var w := make_player(room_w, Vector2i(14, 6))
	w.input.move_x = 1
	await frames(20)
	check(w.is_wall_sliding, "sliding down the right wall")
	await press_for_real(w, ["move_left", "jump"])
	check(absf(w.velocity.x + t.wall_jump_x) < 1.0 and w.velocity.y < -340.0, "a wall jump leaps off on its frame (%s)" % w.velocity)
	release_for_real(["move_left", "jump"])
	room_w.free()
	# Deep in the water: a stroke up.
	var pool := _pool_room()
	var s := make_player(pool, Vector2i(6, 16))
	await frames(4)
	check(s.swimming, "swimming deep in the pool")
	await press_for_real(s, ["jump"])
	check(absf(s.velocity.y + t.swim_stroke) < 30.0, "a stroke goes on its frame (vy %.0f)" % s.velocity.y)
	release_for_real(["jump"])
	pool.free()
	# The clock the frames run on.
	check(ProjectSettings.get_setting("physics/common/physics_ticks_per_second") == 60, "physics runs at 60 steps a second")
	check(ProjectSettings.get_setting("physics/common/physics_interpolation") == true, "with physics interpolation for the drawing")
	check(ProjectSettings.get_setting("application/run/max_fps") == 0, "and the game puts no cap of its own on the frame rate")
	check(ProjectSettings.get_setting("display/window/vsync/vsync_mode") == DisplayServer.VSYNC_ENABLED, "which follows the display's vsync")
	var line := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 6.7 ", 1).get_slice("- **Input", 1).get_slice("\n", 0)
	check(line.contains("`test_every_move_answers_on_the_frame_it_is_pressed`"), "6.7's Input line names the test")



## Pass 400: the timing windows, through the real controller. Coyote time and
## the jump buffer were held to the frame (0.10 s is 6 frames, 0.12 s is 7) only
## with a scripted intent, which the next step reads. A button pressed through
## `Input` is first seen a step after it goes down (`press_for_real`), so each
## press here goes down a step earlier and must be seen on the step it
## stands for: the windows are counted from the step the game sees the press.
func _real_jump_after_ledge(k: int) -> bool:
	var room := make_room(LEDGE)
	var p := make_player(room, Vector2i(2, 3), {"boots": false, "glove": false})
	await _settle(p)
	p.input = PlayerInput.new()
	Input.action_press("move_right")
	for i in 60:
		await frames(1)
		if not p.is_on_floor():
			break
	await frames(k - 2)
	Input.action_press("jump")
	await frames(1)
	var seen := Input.is_action_just_pressed("jump")
	await frames(1)
	var jumped := seen and p.velocity.y < -300.0
	release_for_real(["move_right", "jump"])
	room.free()
	return jumped


func _real_buffered_landing(early: int, land: int) -> bool:
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(10, 4), {"boots": false})
	p.input = PlayerInput.new()
	var jumped := false
	for i in land + 4:
		if i == land - early - 1:
			Input.action_press("jump")
		await frames(1)
		if p.velocity.y < -300.0:
			jumped = true
			break
	release_for_real(["jump"])
	room.free()
	return jumped


func test_the_timing_windows_hold_through_the_real_controller() -> void:
	var last := 0
	for k in range(4, 10):
		if await _real_jump_after_ledge(k):
			last = k
	check(last == 6, "pressed for real, the last frame a ledge jump counts is the 6th, 0.10 s (got %d)" % last)
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(10, 4), {"boots": false})
	var land := 0
	for i in 90:
		await frames(1)
		if p.is_on_floor():
			land = i + 1
			break
	room.free()
	check(await _real_buffered_landing(7, land), "pressed for real 7 frames (0.117 s) before landing, it jumps")
	check(await _real_buffered_landing(1, land), "and 1 frame before")
	check(not await _real_buffered_landing(8, land), "8 frames (0.133 s) before is dropped")
	var line := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 6.7 ", 1).get_slice("- **Input", 1).get_slice("\n", 0)
	check(line.contains("Timing windows, too (pass 400)"), "bible 6.7's Input line says so")


## Pass 416: running, wall sliding and gliding, through the real controller.
## Passes 384 to 408 pressed every jump, dash, drop and climb for real, but the
## moves that read a direction or Jump held over many frames (the run and its
## turn, the slide down a wall and its short stick, Feather Fall's glide) were
## only ever driven by a scripted intent.
func test_running_sliding_and_gliding_through_the_real_controller() -> void:
	var t := MovementTuning.new()
	# Right held runs up to 165 px/s within 7 frames; Left held turns at 1.6x the brake.
	var room := make_room(FLAT)
	var p := make_player(room, Vector2i(3, 11))
	await _settle(p)
	await press_for_real(p, ["move_right"])
	var to_max := -1
	for i in 30:
		if to_max < 0 and is_equal_approx(p.velocity.x, t.run_speed):
			to_max = i + 3
		await frames(1)
	check(to_max > 0 and to_max <= 7, "Right held runs at %.0f px/s within 7 frames (got %d)" % [t.run_speed, to_max])
	var before := p.velocity.x
	release_for_real(["move_right"])
	Input.action_press("move_left")
	await frames(1)
	var turn_brake := before - p.velocity.x
	check_near(turn_brake, t.ground_decel * t.turn_multiplier / 60.0, 0.5, "Left held turns at 1.6x the brake (%.1f a frame)" % turn_brake)
	release_for_real(["move_left"])
	var stop := 0
	while absf(p.velocity.x) > 0.0 and stop < 30:
		await frames(1)
		stop += 1
	check(stop <= 5, "let go, the run stops within 5 frames (got %d)" % stop)
	room.free()
	# Right held against a wall slides down it at 90 px/s; Left sticks for 0.08 s first.
	var wall_rows := ["################"]
	for y in 18:
		wall_rows.append("#..............#")
	wall_rows.append("################")
	room = make_room(wall_rows)
	p = make_player(room, Vector2i(14, 4))
	await press_for_real(p, ["move_right"])
	await frames(30)
	check(p.is_wall_sliding and is_equal_approx(p.velocity.y, t.wall_slide_speed),
		"Right held into a wall slides at %.0f px/s (%s, vy %.0f)" % [t.wall_slide_speed, p.is_wall_sliding, p.velocity.y])
	release_for_real(["move_right"])
	Input.action_press("move_left")
	var stuck := 0
	for i in 20:
		await frames(1)
		if not p.is_wall_sliding:
			break
		stuck += 1
	var stick_frames := roundi(t.wall_stick_time * 60.0)
	check(stuck >= stick_frames - 1 and stuck <= stick_frames + 1,
		"Left held, the hero sticks about %d frames before letting go (got %d)" % [stick_frames, stuck])
	release_for_real(["move_left"])
	room.free()
	# Jump held after the double jump glides at 60 px/s; let go, it falls.
	var tall := ["################"]
	for y in 40:
		tall.append("#..............#")
	tall.append("################")
	room = make_room(tall)
	p = make_player(room, Vector2i(7, 5), {"boots": true})
	p.feather_fall = true
	await frames(2)
	await press_for_real(p, ["jump"])
	check(not p.has_double_jump, "Jump in the air spends the double jump")
	await frames(60)
	check(p.is_gliding and is_equal_approx(p.velocity.y, t.glide_fall_speed),
		"Jump held after it glides at %.0f px/s (%s, vy %.0f)" % [t.glide_fall_speed, p.is_gliding, p.velocity.y])
	release_for_real(["jump"])
	await frames(5)
	check(not p.is_gliding and p.velocity.y > t.glide_fall_speed, "let go, the hero falls (vy %.0f)" % p.velocity.y)
	room.free()
	var line := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 6.7 ", 1).get_slice("- **Input", 1).get_slice("\n", 0)
	check(line.contains("Running, sliding and gliding, too (pass 416)"), "bible 6.7's Input line says so")


## Pass 424: swimming, through the real controller. Pass 384 pressed a stroke
## for real, but the rest of the water (Down held to sink, letting go to float
## back up, a direction held to swim across, and Right and Jump at the surface
## to climb out onto the bank) was only ever driven by a scripted intent.
## Pass 432 (bible 6.7): a press the player means is never swallowed.
## Passes 429 to 431 drop the presses of the hero's first step back after
## waking, a pause, or a dialog, because a menu or the box had already read
## them. But the hero is also held still with no screen to read a press: a
## door's scroll or fade freezes them, and so does dying. A Jump pressed in the
## very frame such a hold ends belongs to the player, and must jump. Here the
## hold ends and Jump is pressed in the same frame, with nothing between: once
## as a door would end it (frozen), once on the respawn after a fall.
func test_a_jump_pressed_as_a_hold_ends_is_kept() -> void:
	var room := make_room([
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"#........#",
		"##########",
	])
	var p := make_player(room, Vector2i(4, 4))
	p.input = PlayerInput.new()
	await _settle(p)
	# A door's hold: frozen for the scroll, let go, and Jump pressed at once.
	p.frozen = true
	await frames(10)
	# As a door ends its hold: in a frame's process, after its physics step,
	# the way a dialog box reads the press that puts it away.
	await runner.get_tree().process_frame
	Input.action_press("jump")
	p.frozen = false
	await frames(3)
	check(p.velocity.y < 0.0, "Jump pressed as a door lets the hero go jumps (%.0f)" % p.velocity.y)
	release_for_real(["jump"])
	await _settle(p)
	# Dying: the fall, the wait, and Jump pressed the moment the hero is back.
	p.take_damage(p.hp + 10)
	check(p.dead, "a blow fells the hero")
	var back := false
	for i in 240:
		await runner.get_tree().process_frame
		if not p.dead:
			back = true
			break
	Input.action_press("jump")
	await frames(3)
	check(back and p.velocity.y < 0.0, "Jump pressed as the hero rises again jumps (%.0f)" % p.velocity.y)
	release_for_real(["jump"])
	room.free()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(note.contains("`test_a_jump_pressed_as_a_hold_ends_is_kept`"), "6.7 names the test")


func test_swimming_through_the_real_controller() -> void:
	var t := MovementTuning.new()
	var room := _pool_room()
	var p := make_player(room, Vector2i(6, 16))
	p.input = PlayerInput.new()
	var surface := 8.0 * Room.TILE
	for i in 240:
		await frames(1)
	check(p.swimming and absf(p.body_rect().get_center().y - surface) < 6.0, "with nothing held the hero floats up to the surface")
	# Down held sinks at swim_sink, no faster.
	Input.action_press("move_down")
	var fastest := 0.0
	for i in 60:
		await frames(1)
		fastest = maxf(fastest, p.velocity.y)
	check(p.global_position.y > surface + 3.0 * Room.TILE and is_equal_approx(fastest, t.swim_sink),
		"Down held sinks at %.0f px/s (%.0f, feet at %.0f)" % [t.swim_sink, fastest, p.global_position.y])
	release_for_real(["move_down"])
	for i in 30:
		await frames(1)
	check(is_equal_approx(p.velocity.y, -t.swim_float), "let go, the hero floats back up at %.0f px/s (%.0f)" % [t.swim_float, p.velocity.y])
	# Right held swims across at 0.7 of a run.
	Input.action_press("move_right")
	var top := 0.0
	for i in 40:
		await frames(1)
		top = maxf(top, absf(p.velocity.x))
	release_for_real(["move_right"])
	check_near(top, t.run_speed * t.swim_speed_multiplier, 0.5, "Right held swims at 0.7 of a run (%.1f)" % top)
	# At the surface by the bank, Right and Jump held climb out onto it.
	p.global_position = Vector2(15 * Room.TILE + 8, surface + 20.0)
	p.velocity = Vector2.ZERO
	for i in 60:
		await frames(1)
	Input.action_press("move_right")
	Input.action_press("jump")
	var out := false
	for i in 90:
		await frames(1)
		if p.is_on_floor() and not p.swimming:
			out = true
			break
	release_for_real(["move_right", "jump"])
	check(out and p.global_position.x > 17 * Room.TILE and p.global_position.y <= surface + 0.5,
		"Right and Jump held at the surface climb out onto the bank (%s)" % p.global_position)
	room.free()
	var line := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 6.7 ", 1).get_slice("- **Input", 1).get_slice("\n", 0)
	check(line.contains("Swimming, too (pass 424)"), "bible 6.7's Input line says so")


## Pass 470: the dash under the Game speed option, by the real controller.
## Game speed (bible 14, 70% to 100%) slows the game by shortening each
## physics step, so "everything slows evenly". The dash ran on a timer that
## moved a whole last step at a run, so at 70% (a step of 0.7 of a frame) it
## stopped 0.01 s early and fell 4 px short of its 57 px stride. Its last step
## is now part dash, part run: at every speed the dash covers its stride, and
## no more than one run step beyond it.
func test_the_dash_keeps_its_stride_at_every_game_speed() -> void:
	var t := MovementTuning.new()
	var stride := t.dash_speed * t.dash_time
	for speed: float in Settings.SPEED_STEPS:
		Feel.set_game_speed(speed)
		var step := speed / 60.0
		var room := make_room(FLAT)
		var p := make_player(room, Vector2i(3, 11))
		await _settle(p)
		p.input = PlayerInput.new()
		await frames(10)
		var x0 := p.global_position.x
		Input.action_press("dash")
		var dashed := false
		var reach := -1.0
		for i in 40:
			await frames(1)
			if i == 1:
				Input.action_release("dash")
			if p.is_dashing:
				dashed = true
			elif dashed and reach < 0.0:
				reach = p.global_position.x - x0
		check(dashed and reach >= stride - 0.01 and reach <= stride + t.run_speed * step + 0.01,
			"at %d%% game speed, a real Dash covers its %.0f px stride (%.2f px, no more than %.2f)" % [roundi(speed * 100.0), stride, reach, stride + t.run_speed * step])
		room.free()
	Feel.set_game_speed(1.0)
	var line := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 6.5 ", 1).get_slice("\n### ", 0)
	check(line.contains("The dash at every game speed (pass 470)"), "bible 6.5 says so")



## Pass 478: passes 470 and 472 found the dash and combat at every game speed,
## and pass 400 held coyote time and the jump buffer through the real controller,
## but only at full speed. Game speed (14) is an assist, so a window counted in
## frames on screen may only widen as the game slows.
func test_the_timing_windows_only_widen_as_the_game_slows() -> void:
	var t := MovementTuning.new()
	var coyote: Array[int] = []
	var buffer: Array[int] = []
	for speed: float in Settings.SPEED_STEPS:
		Feel.set_game_speed(speed)
		var last := 0
		for k in range(4, 14):
			if await _real_jump_after_ledge(k):
				last = k
		coyote.append(last)
		var room := make_room(FLAT)
		var p := make_player(room, Vector2i(10, 4), {"boots": false})
		var land := 0
		for i in 120:
			await frames(1)
			if p.is_on_floor():
				land = i + 1
				break
		room.free()
		var early := 0
		for e in range(1, 16):
			if await _real_buffered_landing(e, land):
				early = e
		buffer.append(early)
		var steps := 60.0 / speed
		check(absf(last - t.coyote_time * steps) <= 1.0, "at %d%% a ledge jump counts up to the %dth frame (%.1f frames of 0.10 s)" % [roundi(speed * 100.0), last, t.coyote_time * steps])
		check(absf(early - t.jump_buffer_time * steps) <= 1.0, "at %d%% a jump pressed %d frames before landing is kept (%.1f frames of 0.12 s)" % [roundi(speed * 100.0), early, t.jump_buffer_time * steps])
	Feel.set_game_speed(1.0)
	for i in range(1, coyote.size()):
		check(coyote[i] >= coyote[i - 1] and buffer[i] >= buffer[i - 1], "neither window narrows as the game slows (coyote %s, buffer %s)" % [coyote, buffer])
	var line := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("\n### 6.7 ", 1).get_slice("- **Input", 1).get_slice("\n", 0)
	check(line.contains("Timing windows at every game speed (pass 478)"), "bible 6.7's Input line says so")



## A press in hitstop is kept, once (pass 486). A blow, a pogo or a hit freezes
## the game for 45 to 150 ms, and a player's thumb does not wait for it: Jump
## held, or Dash tapped, with the real buttons while the game is frozen does
## exactly what it does in play (never lost and never twice), and Jump tapped
## and let go inside the freeze is the shortest hop in play, never a lower one.
func test_a_press_in_hitstop_is_kept_once() -> void:
	var seen := {}
	for when: String in ["play", "hitstop", "slowmo"]:
		for press: String in ["jump flick", "jump tap", "jump hold", "dash tap"]:
			if press == "jump flick" and when != "play":
				continue
			var room := make_room(FLAT)
			var p := make_player(room, Vector2i(3, 11))
			p.input = PlayerInput.new()
			await _settle(p)
			var y0 := p.global_position.y
			var x0 := p.global_position.x
			if when == "hitstop":
				Feel.hitstop_enabled = true
				Feel.hitstop(30.0)
				Feel.hitstop_enabled = false
				check(Feel.is_frozen(), "%s: the game is frozen" % press)
			elif when == "slowmo":
				Feel.slowmo(0.3, 30.0)
			await frames(2)
			var act := press.get_slice(" ", 0)
			Input.action_press(act)
			await frames(1 if press.ends_with("flick") else 3)
			if not press.ends_with("hold"):
				Input.action_release(act)
			await frames(3)
			if when == "hitstop":
				Feel.reset()
			var rose := 0.0
			var moved := 0.0
			for i in (100 if when == "slowmo" else 30):
				await frames(1)
				rose = maxf(rose, y0 - p.global_position.y)
				moved = maxf(moved, absf(p.global_position.x - x0))
			Input.action_release(act)
			Feel.reset()
			seen["%s %s" % [when, press]] = Vector2(moved, rose)
			room.queue_free()
			await frames(2)
	for press: String in ["jump hold", "dash tap"]:
		var want: Vector2 = seen["play " + press]
		check(want.length() > 20.0, "in play, %s goes somewhere (%s)" % [press, want])
		var got: Vector2 = seen["hitstop " + press]
		check(got.distance_to(want) <= 1.0, "%s in hitstop does what it does in play (%s, %s)" % [press, got, want])
	# A tap begun and let go inside the freeze had no game time to rise: it is
	# the shortest hop in play, the one-frame flick, never lower (pass 486).
	var flick: float = seen["play jump flick"].y
	var tap: float = seen["hitstop jump tap"].y
	check(flick > 10.0 and flick < seen["play jump tap"].y, "in play a flick is the shortest hop (%.1f px, a tap %.1f)" % [flick, seen["play jump tap"].y])
	check(absf(tap - flick) <= 1.0, "a tap in hitstop is that hop, no lower (%.1f px, a flick %.1f)" % [tap, flick])
	# In slow motion a held jump and a dash still go as far, within a step;
	# a tap there is shorter in game time, so it is a lower hop, never none.
	for press: String in ["jump hold", "dash tap"]:
		var got: Vector2 = seen["slowmo " + press]
		check(got.distance_to(seen["play " + press]) <= 4.0, "%s in slow motion goes as far (%s, %s)" % [press, got, seen["play " + press]])
	check(seen["slowmo jump tap"].y > 10.0, "a tap in slow motion is still a hop (%.1f px)" % seen["slowmo jump tap"].y)
	var bible := FileAccess.get_file_as_string("res://docs/design-bible.md")
	check(bible.contains("test_a_press_in_hitstop_is_kept_once"), "the bible names this test")

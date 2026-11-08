extends Node
## Headless test runner. Run with:
##   godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
## Exits with code 1 if any check fails.

const SUITES := [
	preload("res://tests/test_movement.gd"),
	preload("res://tests/test_abilities.gd"),
	preload("res://tests/test_world.gd"),
	preload("res://tests/test_combat.gd"),
	preload("res://tests/test_enemies.gd"),
	preload("res://tests/test_soak.gd"),
	preload("res://tests/test_rooms.gd"),
	preload("res://tests/test_economy.gd"),
	preload("res://tests/test_reachability.gd"),
	preload("res://tests/test_boss.gd"),
	preload("res://tests/test_animation.gd"),
	preload("res://tests/test_systems.gd"),
	preload("res://tests/test_edge_shade.gd"),
	preload("res://tests/test_backdrop.gd"),
	preload("res://tests/test_time_tint.gd"),
	preload("res://tests/test_room_light.gd"),
	preload("res://tests/test_lore_tablet.gd"),
	preload("res://tests/test_tileset_factory.gd"),
]

var _passed := 0
var _failed := 0
var _failures: Array[String] = []
var _filter := ""
## --trace prints what is alive after each test (pass 367), to find a test that leaves things behind.
var _trace := false
## Every option as a fresh reset() leaves it (pass 327), for the leak check.
var _clean_settings := {}
## Every save file in user:// and its hash when the test began (pass 399).
var _clean_saves := {}
## The flask every test starts on (pass 407): the game's own default.
const CLEAN_SLOT := 1
## The least play, in minutes of game time, a whole run's soaks may cover
## (pass 383, design bible 15.3). A full run plays about 50; a soak cut short
## or dropped fails the run instead of quietly shrinking it.
const SOAK_FLOOR_MINUTES := 45
## Physics frames played by the soaks (test_soak.gd), and how many ran (pass 383).
var _soak_frames := 0
var _journeys_wiped := 0
var _music_hushed := 0
var _soak_tests := 0


func _ready() -> void:
	_clean_slate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")
		elif arg == "--trace":
			_trace = true
	await get_tree().physics_frame
	for suite_script: GDScript in SUITES:
		var suite: TestSuite = suite_script.new()
		suite.runner = self
		for m in suite.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_") or (_filter != "" and not name.contains(_filter)):
				continue
			var arena := Node2D.new()
			add_child(arena)
			suite.arena = arena
			suite.current_test = name
			var before := _failed
			Sfx.missing.clear()
			suite.allows_engine_errors = false
			var errors := ErrorCatcher.start(false)
			var frame0 := Engine.get_physics_frames()
			await Callable(suite, name).call()
			if suite_script.resource_path.ends_with("test_soak.gd"):
				_soak_frames += Engine.get_physics_frames() - frame0
				_soak_tests += 1
			# An engine error the game carries on past is still a bug (pass 215).
			var logged := errors.stop()
			if not logged.is_empty() and not suite.allows_engine_errors:
				record(name, false, "logged engine errors: %s" % [logged.slice(0, 4)])
			# A sound played by a name with no file is silence, not an error (pass 207).
			if not Sfx.missing.is_empty():
				record(name, false, "played sounds that do not exist: %s" % [Sfx.missing])
			# Statics outlive the test that set them (pass 231): a test must put
			# back what it changed, and the slate is wiped clean either way.
			if GameState.data != GameState.fresh():
				_journeys_wiped += 1
			if Music.track != "" or Music.ambience_track != "" or Music.intensity != 0:
				_music_hushed += 1
			var leaks := _leaks()
			if not leaks.is_empty():
				record(name, false, "left global state changed: %s" % [leaks])
			# A save the test made and left is swept away, so it can't leak into the
			# next test or the next run; one that was there before is never touched.
			for f: String in changed_saves():
				if not _clean_saves.has(f):
					DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
			print("%s %s" % ["PASS" if _failed == before else "FAIL", name])
			arena.queue_free()
			await get_tree().physics_frame
			_clean_slate()
			if _trace:
				print("  TRACE objects %d nodes %d orphans %d resources %d" % [Performance.get_monitor(Performance.OBJECT_COUNT),
					get_tree().get_node_count(), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
					Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TestSuite.SETTINGS_PATH + suffix))
	print("\nJourneys wiped: %d tests left GameState.data changed, and the next began fresh (pass 415)" % _journeys_wiped)
	print("Music hushed: %d tests left a track, an ambience or a phase lift playing, and the next began in silence (pass 423)" % _music_hushed)
	if _soak_tests > 0:
		print("\nSoak: %d tests played %.1f minutes of the game (%d physics frames)" % [_soak_tests, _soak_frames / 3600.0, _soak_frames])
	if _filter == "":
		record("soak time", _soak_frames >= SOAK_FLOOR_MINUTES * 3600,
			"a whole run's soaks play at least %d minutes of the game (%.1f)" % [SOAK_FLOOR_MINUTES, _soak_frames / 3600.0])
	if _filter == "":
		var unheard := unheard_sounds()
		record("every sound heard", unheard.is_empty(),
			"a whole run plays every sound in assets/sfx at least once (not heard: %s)" % [unheard])
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	for f in _failures:
		print("  - " + f)
	get_tree().quit(1 if _failed > 0 else 0)


## Sounds a prop plays on a voice of its own, not through Sfx, each with the
## test that hears it.
const OWN_VOICE := {"falls_pour": "test_the_aqueducts_fall_is_heard_near_it (AqueductSpill loops it)"}


## Sound files no test has played since the run began (pass 390, bible 13.3).
func unheard_sounds() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(Sfx.SFX_DIR):
		var file := f.trim_suffix(".remap").trim_suffix(".import")
		var sound := file.get_basename()
		if file.ends_with(".wav") and not Sfx.heard.has(sound) and not OWN_VOICE.has(sound) and not out.has(sound):
			out.append(sound)
	return out


## The state every test starts from: default options (their file kept apart
## from the player's), no hitstop, rumble or sound, no random drops (they would
## make kills nondeterministic; tests that check drops turn them on and back
## off), and no stopped time, trial, rush or forced pose.
func _clean_slate() -> void:
	Settings.reset()
	Settings.keys = {}
	Settings.path = TestSuite.SETTINGS_PATH
	Settings.apply()
	_clean_settings = Settings.snapshot()
	Feel.hitstop_enabled = false
	Feel.rumble_enabled = false
	Feel.reset()
	Sfx.volume_db = -80.0
	Drop.bread_chance = 0.0
	Drop.mana_chance = 0.0
	Drop.poison_chance = 0.0
	Drop.rare_chance = 0.0
	TimeStop.reset()
	Trials.run = {}
	BossRush.run = {}
	PlayerVisual.forced = ""
	PlayerVisual.body_sets = true
	# A menu left open leaves the game paused, and the next test's world
	# would stand still (pass 399).
	get_tree().paused = false
	# Every test begins on the first flask (pass 407), so a test that writes
	# a save without choosing a test slot is caught by the save check below.
	GameState.slot = CLEAN_SLOT
	# Every test begins a fresh journey (pass 415). A bare hero (make_player,
	# no World) reads his gear, gold and keys from GameState.data, so a shield
	# or blade the last test obtained would ride into the next one.
	GameState.new_game()
	GameState.active = true
	# And in silence (pass 423). Music.play does nothing when asked for the
	# track already playing, so a track the last test left would let a check
	# that a fight, a zone or the ending "plays its music" pass with no play.
	Music.play("", 0.0)
	Music.ambience("", 0.0)
	Music.intensity = 0
	_clean_saves = saves_on_disk()
	# A button pressed through the real controller (press_for_real, pass 386)
	# stays down until released, and the next test's hero would read it.
	for a in held_actions():
		Input.action_release(a)


## Global state a test left changed (pass 231). Statics outlive the test that
## set them, so a leak changes what every later test sees.
func _leaks() -> Array[String]:
	var out: Array[String] = []
	if TimeStop.active():
		out.append("time stopped")
	if Trials.active():
		out.append("a trial running")
	if BossRush.active():
		out.append("a boss rush running")
	if PlayerVisual.forced != "":
		out.append("a forced pose (%s)" % PlayerVisual.forced)
	if not PlayerVisual.body_sets:
		out.append("body sets off")
	if Settings.path != TestSuite.SETTINGS_PATH or Settings.snapshot() != _clean_settings:
		out.append("settings changed")
	if Drop.bread_chance != 0.0 or Drop.mana_chance != 0.0 or Drop.poison_chance != 0.0 or Drop.rare_chance != 0.0:
		out.append("drop chances on")
	var held := held_actions()
	if not held.is_empty():
		out.append("buttons held (%s)" % ", ".join(held))
	if Feel.hitstop_enabled or Feel.rumble_enabled or Feel.game_speed != 1.0 or Feel.shake_scale != 1.0 or Sfx.volume_db != -80.0:
		out.append("feel or volume changed")
	if get_tree().paused:
		out.append("the game left paused")
	if GameState.slot != CLEAN_SLOT:
		out.append("save slot left on %d" % GameState.slot)
	if not GameState.active:
		out.append("the gym's no-record mode left on")
	var changed := changed_saves()
	if not changed.is_empty():
		out.append("saves changed (%s)" % ", ".join(changed))
	return out


## The save files in user:// (journeys, their backups, half-written ones),
## each with its MD5 (pass 399). The suite shares user:// with the game, so a
## test that writes or pours out a flask the player owns (slots 1 to 3) would
## take a real journey; every test must leave the files as it found them.
func saves_on_disk() -> Dictionary:
	var out := {}
	for f: String in DirAccess.get_files_at("user://"):
		if f.begins_with("save_"):
			out[f] = FileAccess.get_md5("user://" + f)
	return out


## Save files a test wrote, changed or removed since it began, sorted.
func changed_saves() -> PackedStringArray:
	var now := saves_on_disk()
	var out := PackedStringArray()
	for f: String in now:
		if _clean_saves.get(f, "") != now[f]:
			out.append(f)
	for f: String in _clean_saves:
		if not now.has(f):
			out.append(f)
	out.sort()
	return out


## Input actions the real controller holds down now (pass 391).
func held_actions() -> PackedStringArray:
	var out := PackedStringArray()
	for a: StringName in InputMap.get_actions():
		if not String(a).begins_with("ui_") and Input.is_action_pressed(a):
			out.append(String(a))
	return out


func record(test: String, ok: bool, msg: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		_failures.append("%s: %s" % [test, msg])

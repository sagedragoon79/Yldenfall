extends TestSuite
## WyrmRig: the Haar Wyrm on a skeleton (design bible 8.4; Sean, 2026-11-19).
## The fight is covered in test_boss.gd; these cover the rig that draws it.

const SPRING_ROOM := "haar/spring_of_haar"
## Where the hero stands for most of the fight, from the boss: in the cistern below it,
## which is sunk in the floor.
const HERO := Vector2(0, 198)


func _rig() -> WyrmRig:
	var rig := WyrmRig.new()
	arena.add_child(rig)
	return rig


## Poses head `i` at `centre` until its neck has settled.
func _settle(rig: WyrmRig, i: int, centre: Vector2, state: Dictionary) -> void:
	for _f in 90:
		rig.pose_head(i, centre, state, 1.0 / 60.0)


func test_wyrm_rig_is_a_skeleton_of_bones() -> void:
	var rig := _rig()
	check(rig.skeleton is Skeleton2D and rig.body_bone.get_parent() == rig.skeleton, "a Skeleton2D with the body as its root bone")
	check(rig.necks.size() == 3, "three necks (%d)" % rig.necks.size())
	for n in rig.necks:
		check(n.bones.size() == WyrmRig.BONES[n.index], "neck %d has its bones (%d)" % [n.index, n.bones.size()])
		check(n.bones[0].get_parent() == rig.body_bone, "neck %d grows from the body" % n.index)
		var chained := true
		for k in range(1, n.bones.size()):
			chained = chained and n.bones[k].get_parent() == n.bones[k - 1]
		check(chained, "each bone of neck %d hangs from the one before it" % n.index)
		check(n.head_bone.get_parent() == n.bones[-1], "the head is the last bone of neck %d" % n.index)
		check(n.skins.size() == n.bones.size(), "one section of art to a bone")
		# The widest sections at the stump, the narrowest at the skull.
		check(n.heights[0] > n.heights[-1], "neck %d tapers toward its head (%.1f to %.1f)" % [n.index, n.heights[0], n.heights[-1]])
	check(rig.necks[1].view == "front" and rig.necks[0].view == "side" and rig.necks[2].view == "side", "the middle neck comes toward us; the others are seen from the side")
	check(rig.necks[0].look == -2 and rig.necks[1].look == 0 and rig.necks[2].look == 2, "at rest the side heads look out in profile and the middle one faces us")
	check(rig.necks[0].skins[0].flip_h and not rig.necks[2].skins[0].flip_h, "the west neck is the east one mirrored")
	rig.queue_free()


func test_wyrm_rig_neck_reaches_wherever_the_fight_puts_its_head() -> void:
	var rig := _rig()
	for i in 3:
		var spots: Array[Vector2] = [HaarWyrm.HOMES[i], HaarWyrm.SAG[i], HaarWyrm.DROOP[i]]
		spots.append(HaarWyrm.HOMES[i] + Vector2(0, -22))
		spots.append(Vector2(HaarWyrm.HOMES[i].x * 0.8, HaarWyrm.HANG))
		for spot in spots:
			# In profile each way, and watching the hero in the cistern.
			for state: Dictionary in [{"face": 1.0}, {"face": -1.0}, {"watch": HERO - spot}]:
				state["mode"] = "idle"
				_settle(rig, i, spot, state)
				var n := rig.necks[i]
				var how := "at %s looking %d" % [spot, n.look]
				check(n.joints[-1].distance_to(spot + rig.head_joint(n, "neck")) < 0.01, "neck %d ends under its skull %s" % [i, how])
				check(n.joints[0].distance_to(rig.stump(i)) < 0.01, "neck %d begins at its stump" % i)
				check(n.stack >= WyrmRig.STACK_MIN - 0.02 and n.stack <= WyrmRig.STACK_MAX + 0.02, "neck %d telescopes within its limits %s (%.2f)" % [i, how, n.stack])
				# No section is pulled clear of the one it sits in, or pushed through it.
				var worst := 0.0
				var shares := ""
				for k in n.bones.size():
					var share := n.joints[k].distance_to(n.joints[k + 1]) / n.heights[k]
					worst = maxf(worst, absf(share - n.stack))
					shares += "%.2f " % share
				check(is_equal_approx(n.bones[0].get_length(), n.joints[0].distance_to(n.joints[1])), "the first bone of neck %d is as long as its section shows" % i)
				check(worst < 0.25, "every section of neck %d shows about the same share (off by %.2f %s: stack %.2f, %s)" % [i, worst, how, n.stack, shares])
	rig.queue_free()


## Sean, 2026-11-19: at full reach the necks were pulled thin where they met the heads.
## "Either need a few more neck sections, or don't swing the head so far left/right."
## The heads' places are the fight's, so the necks got the sections.
func test_wyrm_rig_necks_are_long_enough_for_the_fight() -> void:
	var rig := _rig()
	for i in 3:
		# Out at rest, watching the hero in the cistern: where a head spends the fight.
		_settle(rig, i, HaarWyrm.HOMES[i], {"mode": "idle", "watch": HERO - (HaarWyrm.HOMES[i] as Vector2)})
		var n := rig.necks[i]
		check(n.stack < 0.68, "neck %d is at ease at rest, not pulled thin (it shows %.2f of each section; %.2f is its limit)" % [i, n.stack, WyrmRig.STACK_MAX])
		# Reared up before a breath, the farthest the fight sends it.
		var far: Vector2 = HaarWyrm.HOMES[i] + Vector2(signf(HaarWyrm.HOMES[i].x) * 10.0, -22.0)
		_settle(rig, i, far, {"mode": "idle", "watch": HERO - far})
		check(n.stack < WyrmRig.STACK_MAX - 0.03, "neck %d has slack left at its farthest reach (%.2f)" % [i, n.stack])
	rig.queue_free()


func test_wyrm_rig_bones_follow_the_joints() -> void:
	var rig := _rig()
	rig.position = Vector2(300, 120)
	_settle(rig, 2, HaarWyrm.HOMES[2], {"mode": "idle", "face": 1.0})
	var n := rig.necks[2]
	var worst := 0.0
	for k in n.bones.size():
		worst = maxf(worst, n.bones[k].global_position.distance_to(rig.global_position + n.joints[k]))
		worst = maxf(worst, n.skins[k].global_position.distance_to(rig.global_position + n.joints[k]))
	check(worst < 0.01, "each bone, and the art on it, sits on its joint (off by %.3f)" % worst)
	check(n.head_bone.global_position.distance_to(rig.global_position + n.joints[-1]) < 0.01, "the head bone sits on the last joint")
	check(n.head_skin.position.distance_to(HaarWyrm.HOMES[2]) < 0.01, "the head's art is centred where the fight has the head")
	rig.queue_free()


## Sean, 2026-11-19: "The necks need to curl around more before connecting to the base of
## the head." A head that looks back toward its own body used to take its neck in under
## the jaw; now the neck passes the head and comes round behind it.
func test_wyrm_rig_neck_curls_round_behind_a_head_that_looks_back() -> void:
	var rig := _rig()
	# The west head, out at rest, in profile: looking east at its body, then west, away.
	var at: Vector2 = HaarWyrm.HOMES[0]
	var n := rig.necks[0]
	_settle(rig, 0, at, {"mode": "idle", "face": 1.0})
	var tip := n.joints[-1]
	var behind := at.x
	var under := tip.y
	for j in n.joints.slice(n.joints.size() - 12):
		behind = minf(behind, j.x)
		under = maxf(under, j.y)
	check(n.look == 2 and under > tip.y + 14.0, "looking back at its body, its neck passes under the head (%.0f px below where it joins)" % (under - tip.y))
	check(behind < at.x - 4.0, "and curls up behind it (%.0f px past its middle)" % (at.x - behind))
	var before := n.joints[-4]
	check(before.x < tip.x and before.y > tip.y, "so it comes into the base of the skull from below and behind, not in under the jaw (%s to %s)" % [before, tip])
	_settle(rig, 0, at, {"mode": "idle", "face": -1.0})
	behind = at.x
	for j in n.joints:
		behind = minf(behind, j.x)
	check(n.look == -2 and behind > at.x - 4.0, "looking away from its body, the neck has no need to pass it (%.0f)" % (at.x - behind))
	rig.queue_free()


## Sean, 2026-11-19: "can we have pseudo animation where it moves from facing one way
## like East then go to SE to S to SW to W ... more natural head movement."
func test_wyrm_rig_head_turns_through_its_views() -> void:
	check(is_equal_approx(WyrmRig.view_toward(Vector2(1, 0)), 2.0) and is_equal_approx(WyrmRig.view_toward(Vector2(1, 1)), 1.0) and is_equal_approx(WyrmRig.view_toward(Vector2(0, 1)), 0.0) and is_equal_approx(WyrmRig.view_toward(Vector2(-1, 1)), -1.0) and is_equal_approx(WyrmRig.view_toward(Vector2(-1, 0)), -2.0), "east, south-east, south, south-west and west are views 2 to -2")
	check(is_equal_approx(WyrmRig.view_toward(Vector2(1, -1)), 2.0), "a mark above a head is watched in profile: it has no view from below")
	var rig := _rig()
	var n := rig.necks[2]
	var at: Vector2 = HaarWyrm.HOMES[2]
	_settle(rig, 2, at, {"mode": "idle", "watch": Vector2(1, 0)})
	check(n.look == 2 and not n.head_skin.flip_h and n.head_layout == rig.layout["head_east"], "watching due east, the east profile")
	# Its mark crosses to the west at once: the head turns through every view between.
	var seen: Array[int] = [n.look]
	var frames_taken := 0
	for _f in 120:
		rig.pose_head(2, at, {"mode": "idle", "watch": Vector2(-1, 0)}, 1.0 / 60.0)
		frames_taken += 1
		if n.look != seen[-1]:
			seen.append(n.look)
		if n.look == -2:
			break
	check(seen == [2, 1, 0, -1, -2], "it turns east, south-east, south, south-west, west, one view at a time (%s)" % [seen])
	check(frames_taken / 60.0 >= WyrmRig.TURN_STEP * 3.5, "and holds each view a moment: a turn, not a flip (%.2f s)" % (frames_taken / 60.0))
	check(n.head_skin.flip_h and n.head_layout == rig.layout["head_east"], "west is the east profile mirrored")
	# The views between are their own art.
	_settle(rig, 2, at, {"mode": "idle", "watch": Vector2(-1, 1)})
	check(n.look == -1 and n.head_skin.flip_h and n.head_layout == rig.layout["head_se"] and n.head_skin.texture == rig._head_art["head_se"], "south-west is the three-quarter head, mirrored")
	_settle(rig, 2, at, {"mode": "idle", "watch": Vector2(0, 1)})
	check(n.look == 0 and not n.head_skin.flip_h and n.head_layout == rig.layout["head_south"], "south is the head face on")
	# A mark that wavers on the line between two views doesn't make the head twitch.
	var turns := 0
	var last := n.look
	for f in 120:
		var waver := 0.5 + 0.1 * sin(f * 0.7)
		rig.pose_head(2, at, {"mode": "idle", "watch": Vector2(sin(waver * PI / 4.0), cos(waver * PI / 4.0))}, 1.0 / 60.0)
		if n.look != last:
			turns += 1
			last = n.look
	check(turns == 0, "a mark on the line between two views doesn't make it twitch (%d turns)" % turns)
	# The fight's own rules: the plume in strict profile, the fog face on.
	_settle(rig, 2, at, {"mode": "tell", "face": -1.0, "breath": HydraHead.PLUME, "watch": Vector2(0, 1), "tell": 0.9})
	check(n.look == -2, "a plume is breathed in strict profile, the way it will roll")
	_settle(rig, 1, HaarWyrm.HOMES[1], {"mode": "tell", "breath": HydraHead.FOG, "watch": Vector2(1, 0.2), "tell": 3.0})
	check(rig.necks[1].look == 0, "the fog head faces us for its breath, whatever it was watching")
	rig.queue_free()


func test_wyrm_rig_head_shows_what_it_is_doing() -> void:
	var rig := _rig()
	var n := rig.necks[2]
	var at: Vector2 = HaarWyrm.HOMES[2]
	rig.pose_head(2, at, {"mode": "hidden"}, 0.016)
	check(not n.head_skin.visible and not n.skins[0].visible, "a head still in the tunnel shows nothing")
	_settle(rig, 2, at, {"mode": "idle", "face": 1.0})
	check(n.head_skin.visible and n.clip == "idle", "an idle head is its still (%s)" % n.clip)
	check(n.skins[0].modulate.r < 0.5 and n.skins[-1].modulate.r > 0.95, "the root of a neck stands in the tunnel's dark; its far end is lit")
	_settle(rig, 2, at, {"mode": "tell", "face": 1.0, "breath": HydraHead.PLUME, "time": 0.8, "tell": 0.9})
	check(n.clip == "pull" and n.frame > 0 and n.rot < -0.1, "a head winding up draws back and rears (%s %d, %.2f)" % [n.clip, n.frame, n.rot])
	# The geyser head looks down its aim: in profile for a flat shot, turned to it.
	var flat := Vector2(1, 0.2).normalized()
	_settle(rig, 2, at, {"mode": "breathe", "face": 1.0, "breath": HydraHead.GEYSER, "aim": flat})
	check(n.clip == "open" and n.look == 2 and absf(n.rot - flat.angle()) < 0.05, "the geyser head opens its jaws along a flat aim, in profile (%s, look %d, %.2f)" % [n.clip, n.look, n.rot])
	var west := Vector2(-1, 0.2).normalized()
	_settle(rig, 2, at, {"mode": "breathe", "face": -1.0, "breath": HydraHead.GEYSER, "aim": west})
	check(n.look == -2 and n.head_skin.flip_h and absf(n.rot + flat.angle()) < 0.05, "and the same when it aims west (%.2f)" % n.rot)
	var jaws := rig.mouth(2, at) - at
	check(jaws.x < -4.0 and jaws.y > 6.0, "its breath leaves its jaws, to the west of its middle (%s)" % jaws)
	_settle(rig, 2, at, {"mode": "breathe", "face": 1.0, "breath": HydraHead.GEYSER, "aim": Vector2(1, 1).normalized()})
	check(n.clip == "open" and n.look == 1 and absf(n.rot) < 0.3, "aiming steeply down, it is the three-quarter head with its jaws open (%s, look %d, %.2f)" % [n.clip, n.look, n.rot])
	_settle(rig, 2, HaarWyrm.DROOP[2], {"mode": "weak", "face": -1.0, "weak": true})
	check(n.head_skin.modulate.b > n.head_skin.modulate.r + 0.1, "a doused head is drenched blue")
	_settle(rig, 2, Vector2(136, 70), {"mode": "limp", "face": 1.0, "dead": true})
	check(absf(n.rot) > 0.9 and is_equal_approx(n.head_skin.modulate.r, WyrmRig.LIMP.r), "a dead head hangs nose down, grey (%.2f)" % n.rot)
	_settle(rig, 2, at, {"mode": "idle", "face": 1.0, "white": 1.0})
	check(is_equal_approx(float(n.material.get_shader_parameter("white")), 1.0) and n.head_skin.material == n.material, "a struck head flashes white")
	var plain := true
	for sp in n.skins:
		plain = plain and sp.material == null
	check(plain, "and its neck does not: only the head flashes")
	check(not ("texture(TEXTURE" in WyrmRig.WASH), "the flash only whitens: it never multiplies the art by itself, which darkened it")
	# The middle head faces us for its breath and has its own clips.
	var m := rig.necks[1]
	_settle(rig, 1, HaarWyrm.HOMES[1], {"mode": "tell", "face": 1.0, "breath": HydraHead.FOG, "time": 2.9, "tell": 3.0})
	check(m.clip == "glow" and m.frame >= 4 and not m.head_skin.flip_h, "the fog head's jaws open on the glow in its throat (%s %d)" % [m.clip, m.frame])
	# Its breath is a channel (Sean, 2026-11-19): the jaws stay wide on the pulsing core.
	var held := {}
	for f in 120:
		rig.pose_head(1, HaarWyrm.HOMES[1], {"mode": "breathe", "breath": HydraHead.FOG, "time": f / 60.0}, 1.0 / 60.0)
		held[m.frame] = true
		check(m.clip == "glow" and m.frame in WyrmRig.CHANNEL, "the fog head holds its jaws wide through its whole breath (frame %d)" % m.frame) if not (m.frame in WyrmRig.CHANNEL) else null
	check(held.size() >= 3, "and the core in its throat pulses (%d frames)" % held.size())
	# In three-quarter view the roar skips the frames PixelLab left pale.
	for step in 40:
		check(WyrmRig._roar_frame(1, step, 17) not in [6, 9, 10, 11, 12, 13], "a three-quarter roar never shows a pale frame") if WyrmRig._roar_frame(1, step, 17) in [6, 9, 10, 11, 12, 13] else null
	# Every view has a frame for everything a head does.
	for look: Vector2 in [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		for mode: String in ["idle", "emerge", "rise", "tell", "breathe", "sag", "weak", "rage", "limp"]:
			rig.necks[0].shown = false
			rig.pose_head(0, HaarWyrm.HOMES[0], {"mode": mode, "watch": look, "aim": look, "breath": HydraHead.GEYSER, "time": 0.4, "tell": 1.0}, 0.016)
			var h := rig.necks[0]
			check(h.head_layout["clips"].has(h.clip), "a head looking %s has a frame to %s (%s)" % [look, mode, h.clip])
	rig.queue_free()


func test_wyrm_rig_opens_its_eyes_in_the_dark() -> void:
	var rig := _rig()
	for i in 3:
		var n := rig.necks[i]
		var at: Vector2 = HaarWyrm.HIDDEN[i]
		rig.pose_head(i, at, {"mode": "hidden"}, 0.016)
		check(not n.head_skin.visible and n.eyes == 0.0, "head %d shows nothing in the tunnel before the fight" % i)
		rig.pose_head(i, at, {"mode": "hidden", "intro": float(HaarWyrm.EYES_AT[i]) - 0.05}, 0.016)
		check(not n.shown, "nor in the reveal before its own eyes open")
		rig._time = 1.0 - i
		rig.pose_head(i, at, {"mode": "hidden", "watch": HERO - at, "intro": float(HaarWyrm.EYES_AT[i]) + WyrmRig.EYES_OPEN}, 0.016)
		check(n.shown and is_equal_approx(n.eyes, 1.0), "head %d's eyes open at its moment in the reveal (%.2f)" % [i, n.eyes])
		check(n.skins[-1].modulate.r < 0.45, "and its neck is still in the dark (%.2f)" % n.skins[-1].modulate.r)
		if i != 1:
			check(absi(n.look) == 1 and n.shade_skin.visible and not n.head_skin.visible, "a side head waits as its shadowed twin, turned to the room (look %d)" % n.look)
		else:
			check(n.look == 0 and n.clip == "wake" and n.frame == 2, "the middle head faces us, its eyes opened (%s %d)" % [n.clip, n.frame])
			rig.pose_head(i, at, {"mode": "hidden", "intro": float(HaarWyrm.SNORTS_AT[i]) + WyrmRig.SNORT * 0.5}, 0.016)
			check(n.frame > 4, "and it snorts when its turn comes (frame %d)" % n.frame)
	# Coming out, the shadow draws off: half way, a side head's twin is half gone.
	var e := rig.necks[2]
	rig.pose_head(2, HaarWyrm.HOMES[2], {"mode": "emerge", "time": HaarWyrm.EMERGE_TIME * 0.5, "watch": Vector2(-1, 1)}, 0.016)
	check(e.head_skin.visible and e.shade_skin.visible and absf(e.shade_skin.modulate.a - 0.5) < 0.01, "the shadow draws off a side head as it comes out (%.2f)" % e.shade_skin.modulate.a)
	var m := rig.necks[1]
	rig.pose_head(1, HaarWyrm.HOMES[1], {"mode": "emerge", "time": HaarWyrm.EMERGE_TIME * 0.5, "watch": Vector2(0, 1)}, 0.016)
	check(m.clip == "recede" and m.frame > 4, "and off the middle head, in its own frames (%s %d)" % [m.clip, m.frame])
	rig.pose_head(2, HaarWyrm.HOMES[2], {"mode": "idle", "watch": Vector2(-1, 1)}, 0.016)
	check(not e.shade_skin.visible, "out in the arena a head wears no shadow")
	rig.queue_free()


func _wake(with_rig: bool) -> HaarWyrm:
	var was := HaarWyrm.use_rig
	HaarWyrm.use_rig = with_rig
	var w := make_world({}, SPRING_ROOM)
	w.player.max_hp = 9999
	w.player.hp = 9999
	await frames(3)
	w.player.teleport(cell_feet(7, 19))
	var z: HaarWyrm = null
	for _f in 300:
		await frames(1)
		for b in runner.get_tree().get_nodes_in_group("boss"):
			if b is HaarWyrm:
				z = b
		if z != null:
			break
	HaarWyrm.use_rig = was
	return z


func test_wyrm_rig_is_what_the_fight_wears() -> void:
	check(HaarWyrm.use_rig, "the Haar Wyrm is drawn on its rig unless the game is started with --wyrm-drawn")
	var z: HaarWyrm = await _wake(true)
	check(z != null and z.rig != null, "the Haar Wyrm builds its rig")
	if z == null or z.rig == null:
		return
	await frames(2)
	check(z.rig.body_skin.modulate.a < 0.01, "the tunnel is black as the reveal begins: no body")
	var was := z.state
	z.state = "dormant"
	z.rig.pose(z, 0.016)
	check(z.rig.body_skin.modulate.a < 0.01, "and black while it sleeps")
	z.state = was
	z.skip_intro()
	for _f in 300:
		await frames(1)
		if z.state == "fight" and z.heads[2].mode == "idle":
			break
	await frames(30)
	check(z.rig.body_skin.modulate.a > 0.99, "once the heads are out the body shows in the tunnel's dark")
	for i in 3:
		var h := z.heads[i]
		var n := z.rig.necks[i]
		check(n.head_skin.visible and n.head_skin.global_position.distance_to(h.global_position) < 0.01, "head %d's art rides on the head the fight moves and the player strikes" % i)
		check(h.radius == 14.0, "the rig changes nothing about what can be hit")
	# The hero is far to the west, on the floor: every head has turned to watch him.
	check(z.rig.necks[0].look < 0 and z.rig.necks[1].look < 0 and z.rig.necks[2].look < 0, "the heads watch the hero (%d, %d, %d)" % [z.rig.necks[0].look, z.rig.necks[1].look, z.rig.necks[2].look])
	var g := z.heads[2]
	check(z.mouth_of(g).distance_to(z.rig.mouth(2, g.global_position)) < 0.01, "the geyser leaves the rigged head's jaws")


func test_wyrm_rig_can_be_set_aside() -> void:
	var z: HaarWyrm = await _wake(false)
	check(z != null and z.rig == null, "with the rig off, the Haar Wyrm is its code-drawn self")
	if z == null:
		return
	var g := z.heads[2]
	check(z.mouth_of(g).distance_to(g.global_position + Vector2(z._face(g) * 22.0, 6.0)) < 0.01, "and its breath leaves where it always did")


## The side head was drawn with a stub of neck behind its cheek spines (green scales over
## a brown throat) that fit neither the style nor the colors of the neck sections
## (Sean, 2026-11-19): the packer cuts it from every frame.
func test_wyrm_rig_side_heads_carry_no_neck_of_their_own() -> void:
	var rig := _rig()
	var part: Dictionary = rig.layout["head_east"]
	var img: Image = (load(WyrmRig.DIR + String(part["sheet"])) as Texture2D).get_image()
	var cell := Vector2i(int(part["cell"][0]), int(part["cell"][1]))
	var columns := int(part["columns"])
	# On the 92 px still: the middle of the stub that was, and the cheek that stays.
	var origin := (cell - Vector2i(92, 92)) / 2
	var stub := origin + Vector2i(16, 56)
	var cheek := origin + Vector2i(58, 54)
	for clip: String in ["idle", "shut", "shadow"]:
		var i := int(part["clips"][clip]["start"])
		var at := Vector2i((i % columns) * cell.x, (i / columns) * cell.y)
		check(img.get_pixelv(at + stub).a < 0.05, "the %s side head has no neck of its own behind its cheek" % clip)
		check(img.get_pixelv(at + cheek).a > 0.9, "and the %s head itself is whole" % clip)
	# Every frame: nothing left where the still's stub hung lowest (the brown throat).
	var left := 0
	var cells := 0
	for clip: String in part["clips"]:
		if clip == "open":
			continue
		for k in int(part["clips"][clip]["count"]):
			var i := int(part["clips"][clip]["start"]) + k
			var at := Vector2i((i % columns) * cell.x, (i / columns) * cell.y)
			cells += 1
			for y in range(76, 84):
				for x in range(26, 44):
					if img.get_pixelv(at + origin + Vector2i(x, y)).a > 0.05:
						left += 1
	check(left == 0, "no frame of the side head keeps its throat (%d pixels left over %d frames)" % [left, cells])
	# The neck ends under the skull, so its open rim never shows.
	var joint := WyrmRig._point(part["joints"]["neck"]) - Vector2(origin)
	check(joint.x > 40.0 and joint.x < 60.0 and joint.y > 44.0 and joint.y < 62.0, "the neck ends under the skull, not behind it (%s)" % joint)
	rig.queue_free()


## Sean, 2026-11-19: "the neck holes on the body need to be seamless with the neck
## sections." A neck's first section sat on its stump's rim, wider than the hole under it.
func test_wyrm_rig_necks_are_seated_in_their_stumps() -> void:
	var rig := _rig()
	var body: Dictionary = rig.layout["body"]
	var rims := [Vector2(85, 21), Vector2(127, 11), Vector2(168, 21)]
	var origin := (WyrmRig._point(body["cell"]) - Vector2(256, 128)) * 0.5
	for i in 3:
		var seat := WyrmRig._point(body["joints"]["stumps"][i]) - origin
		var rim: Vector2 = rims[i]
		var deep := seat.y - rim.y
		# As deep as a section sits in the one below it.
		var section := rig.necks[i].heights[0] / WyrmRig.ART
		check(is_equal_approx(seat.x, rim.x) and deep > section * 0.3 and deep < section * 0.5, "neck %d is seated down inside its stump, not perched on its rim (%.0f px deep, a %.0f px section)" % [i, deep, section])
		# The root is the color of the shoulder it grows from.
		_settle(rig, i, HaarWyrm.HOMES[i], {"mode": "idle", "watch": HERO})
		var root := rig.necks[i].skins[0].modulate
		check(absf(root.r - WyrmRig.SHADOW.r) < 0.01 and absf(root.b - WyrmRig.SHADOW.b) < 0.01, "and its root wears the cloaked body's own shadow")
	rig.queue_free()



## Sean, 2026-11-19: the fog is a channel. "That's where we insert the VFX of the heat
## radiation ripples and screen heat distortion effect."
func test_wyrm_fog_is_a_channel_of_heat_off_the_jaws() -> void:
	var fog := HydraFog.new()
	fog.bounds = Rect2(16, 64, 928, 256)
	# (In a holder: a lambda copies a local, and the jaws move below.)
	var held := [Vector2(480, 112)]
	var jaws: Vector2 = held[0]
	fog.source = func() -> Vector2: return held[0]
	arena.add_child(fog)
	check(fog.haze != null and fog.haze.material is ShaderMaterial, "the fog lays a heat haze over the arena")
	var mat := fog.haze.material as ShaderMaterial
	check("hint_screen_texture" in HydraFog.HAZE_SHADER and "floor(push" in HydraFog.HAZE_SHADER, "the haze bends the screen behind it, in whole pixels")
	check(fog.rings().is_empty() and not fog.haze.visible, "before the breath there is no heat in the air")
	# Half way into the fill.
	fog._time = HydraFog.FILL * 0.5
	fog._lay_haze()
	check(fog.haze.visible and is_equal_approx(float(mat.get_shader_parameter("strength")), 0.5), "the haze thickens as the fog fills (%.2f)" % float(mat.get_shader_parameter("strength")))
	check((mat.get_shader_parameter("source") as Vector2).distance_to(jaws - fog.bounds.position) < 0.01, "and it radiates from the jaws of the head that breathes it")
	check(fog.haze.position.distance_to(fog.bounds.position) < 0.01 and fog.haze.size == fog.bounds.size, "over the whole arena")
	check(fog.rings().size() == 1, "the first ring of heat has left the jaws (%d)" % fog.rings().size())
	# Thick: a train of rings, each farther and fainter than the one behind it.
	fog._time = HydraFog.FILL + 1.7
	fog._lay_haze()
	var rings := fog.rings()
	check(rings.size() == HydraFog.RINGS and is_equal_approx(float(mat.get_shader_parameter("strength")), 1.0), "at its thickest, %d rings are in the air (%d)" % [HydraFog.RINGS, rings.size()])
	var ordered := true
	for i in range(1, rings.size()):
		ordered = ordered and rings[i][0] > rings[i - 1][0] and rings[i][1] < rings[i - 1][1]
	check(ordered and rings[-1][0] < HydraFog.RING_REACH, "each farther from the jaws and fainter than the one behind it (%s)" % [rings])
	# The jaws move: the heat comes off them where they are now.
	jaws = Vector2(500, 96)
	held[0] = jaws
	fog._lay_haze()
	check((mat.get_shader_parameter("source") as Vector2).distance_to(jaws - fog.bounds.position) < 0.01, "the heat follows the jaws as the head moves")
	# The breath over, no new ring leaves, and the haze thins with the fog.
	fog._time = HydraFog.FILL + HydraFog.BURN + HydraFog.FADE * 0.5
	fog._lay_haze()
	var late := fog.rings()
	check(late.size() < HydraFog.RINGS and (late.is_empty() or late[0][0] > HydraFog.RING_REACH * 0.25), "once the breath ends no new ring leaves the jaws (%s)" % [late])
	check(is_equal_approx(float(mat.get_shader_parameter("strength")), 0.5), "and the haze thins as the fog fades")
	# With no head to breathe it (a test, a tool), it still has a place to come from.
	fog.source = Callable()
	check(fog.bounds.has_point(fog.source_point()), "a fog with no head still has a source inside the arena")
	fog.queue_free()


func test_wyrm_fog_leaves_the_water_clear() -> void:
	var z: HaarWyrm = await _wake(true)
	if z == null:
		check(false, "the Haar Wyrm wakes")
		return
	var fog := HydraFog.new()
	fog.bounds = z.arena
	fog.cistern = z.cistern
	z.get_parent().add_child(fog)
	fog._time = HydraFog.FILL
	fog._lay_haze()
	var mat := fog.haze.material as ShaderMaterial
	check((mat.get_shader_parameter("clear") as Vector4).z == 0.0 and fog.clear_rect().size == Vector2.ZERO, "a dry cistern is no shelter: the haze covers it")
	# The cistern is sunk under the arena's floor (Sean, 2026-11-20): the fog fills its pit.
	var pit := z.cistern.inside
	var all := fog.reach()
	check(pit.position.y >= fog.bounds.end.y - 0.01 and all.encloses(pit) and all.encloses(fog.bounds), "the fog reaches down into the sunken cistern (%s)" % all)
	check(fog.haze.size == all.size and fog.haze.position.distance_to(all.position) < 0.01, "and its haze with it")
	var hole: Vector4 = mat.get_shader_parameter("pit")
	check(is_equal_approx(float(mat.get_shader_parameter("floor_at")), fog.bounds.size.y), "under the floor's level")
	check(is_equal_approx(hole.x, pit.position.x - all.position.x) and is_equal_approx(hole.y, pit.position.y - all.position.y) and is_equal_approx(hole.z, pit.size.x) and is_equal_approx(hole.w, pit.size.y), "it wavers only in the pit, not in the stone round it (%s)" % hole)
	z.cistern.fill_now()
	fog._lay_haze()
	var clear: Vector4 = mat.get_shader_parameter("clear")
	var water := fog.clear_rect()
	check(water.size.x > 100.0 and water.size.y > 10.0, "a full cistern's water is clear of the heat (%s)" % water)
	check(is_equal_approx(clear.x, water.position.x - fog.bounds.position.x) and is_equal_approx(clear.z, water.size.x) and is_equal_approx(clear.w, water.size.y), "and the haze leaves exactly that water alone")
	# On the rig the heat comes off the fog head's own jaws.
	z.skip_intro()
	for _f in 300:
		await frames(1)
		if z.state == "fight":
			break
	var h := z.head_for(HydraHead.FOG)
	var real := HydraFog.new()
	real.bounds = z.arena
	real.source = z.mouth_of.bind(h)
	z.get_parent().add_child(real)
	check(real.source_point().distance_to(z.mouth_of(h)) < 0.01 and real.source_point().distance_to(h.global_position) < 30.0, "the fight hands the fog its head's jaws to radiate from")
	real.queue_free()
	fog.queue_free()



## Sean, 2026-11-20: the cistern is sunk in the floor, with a small lip. Everything that
## stood on its rim came down with it.
func test_wyrm_stands_at_the_lip_of_its_sunken_cistern() -> void:
	var z: HaarWyrm = await _wake(true)
	if z == null:
		check(false, "the Haar Wyrm wakes")
		return
	var lip := z.cistern.lip_rect()
	var pit := z.cistern.inside
	var feet := z.global_position.y + WyrmRig.BODY_AT.y
	check(feet <= lip.position.y and lip.position.y - feet < 12.0, "the body's claws are on the cistern's lip (%.0f at a lip of %.0f)" % [feet, lip.position.y])
	check(absf(z.global_position.x - pit.get_center().x) < 0.5, "in the middle of it")
	for i in 3:
		var droop: float = z.global_position.y + (HaarWyrm.DROOP[i] as Vector2).y
		check(droop < lip.position.y and lip.position.y - droop < 48.0, "a doused head %d droops just over the lip (%.0f px above it)" % [i, lip.position.y - droop])
		var hidden: float = z.global_position.y + (HaarWyrm.HIDDEN[i] as Vector2).y
		check(hidden < feet, "head %d waits in the tunnel above its floor" % i)
	# Every head is struck from the floor's level: the side heads from the floor, the
	# middle one from the grate over the cistern. With room to spare (Sean's playtest
	# of the pit: 6 px of margin was thin).
	var p := z.get_tree().get_first_node_in_group("player") as Player
	var reach := p.tuning.jump_height + Player.BODY_SIZE.y + 24.0
	for i in 3:
		var sag: float = z.global_position.y + (HaarWyrm.SAG[i] as Vector2).y
		check(z.arena.end.y - sag <= reach - 16.0, "head %d sags well within a jumping blade of the floor (%.0f px up, %.0f in reach)" % [i, z.arena.end.y - sag, reach])
	var mid_x: float = z.global_position.x + (HaarWyrm.SAG[1] as Vector2).x
	check(mid_x > pit.position.x and mid_x < pit.end.x, "and the middle head sags over the grate")



## Sean, 2026-11-20: "the neck opening showing on head knock down/vulnerability". A doused
## head's neck curled under it, and the curl showed below the head, open end and all.
func test_wyrm_rig_doused_head_hangs_from_its_neck() -> void:
	var rig := _rig()
	for i: int in [0, 2]:
		var at: Vector2 = HaarWyrm.DROOP[i]
		for state: Dictionary in [{"face": 1.0}, {"face": -1.0}, {"watch": HERO - at}]:
			state["mode"] = "weak"
			state["weak"] = true
			_settle(rig, i, at, state)
			var n := rig.necks[i]
			var how := "head %d looking %d" % [i, n.look]
			check(is_equal_approx(n.hang, 1.0), "doused, %s hangs from its neck" % how)
			var tip: Vector2 = n.joints[-1]
			var lowest := -INF
			for j: Vector2 in n.joints:
				lowest = maxf(lowest, j.y)
			check(lowest <= maxf(tip.y, rig.stump(i).y) + 2.0, "no part of the neck hangs below the skull it holds (%s: %.0f px under it)" % [how, lowest - tip.y])
			check(n.joints[-4].y < tip.y - 6.0, "the neck comes down into the skull from above (%s: %.0f px)" % [how, tip.y - n.joints[-4].y])
			check(n.stack >= WyrmRig.STACK_MIN - 0.02 and n.stack <= WyrmRig.STACK_MAX + 0.02, "and telescopes within its limits (%s: %.2f)" % [how, n.stack])
	# Up again, it holds its curl as before.
	_settle(rig, 2, HaarWyrm.HOMES[2], {"mode": "idle", "watch": HERO - (HaarWyrm.HOMES[2] as Vector2)})
	check(rig.necks[2].hang == 0.0, "risen again, the head is held up on its neck")
	rig.queue_free()

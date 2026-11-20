extends TestSuite
## WyrmRig: the Haar Wyrm on a skeleton (design bible 8.4; Sean, 2026-11-19).
## The fight is covered in test_boss.gd; these cover the rig that draws it.

const SPRING_ROOM := "haar/spring_of_haar"


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
	check(rig.necks[1].view == "front" and rig.necks[0].view == "side" and rig.necks[2].view == "side", "the middle head faces us; the others are in profile")
	check(rig.necks[0].skins[0].flip_h and not rig.necks[2].skins[0].flip_h, "the west neck is the east one mirrored")
	rig.queue_free()


func test_wyrm_rig_neck_reaches_wherever_the_fight_puts_its_head() -> void:
	var rig := _rig()
	for i in 3:
		var spots: Array[Vector2] = [HaarWyrm.HOMES[i], HaarWyrm.SAG[i], HaarWyrm.DROOP[i]]
		spots.append(HaarWyrm.HOMES[i] + Vector2(0, -22))
		spots.append(Vector2(HaarWyrm.HOMES[i].x * 0.8, 70.0))
		for spot in spots:
			for face: float in [1.0, -1.0]:
				_settle(rig, i, spot, {"mode": "idle", "face": face})
				var n := rig.necks[i]
				var want := spot + rig.head_joint(n, "neck", face, n.rot)
				check(n.joints[-1].distance_to(want) < 0.01, "neck %d ends at the back of its skull at %s" % [i, spot])
				check(n.joints[0].distance_to(rig.stump(i)) < 0.01, "neck %d begins at its stump" % i)
				check(n.stack >= WyrmRig.STACK_MIN - 0.02 and n.stack <= WyrmRig.STACK_MAX + 0.02, "neck %d telescopes within its limits at %s (%.2f)" % [i, spot, n.stack])
				# No section is pulled clear of the one it sits in, or pushed through it.
				var worst := 0.0
				var shares := ""
				for k in n.bones.size():
					var share := n.joints[k].distance_to(n.joints[k + 1]) / n.heights[k]
					worst = maxf(worst, absf(share - n.stack))
					shares += "%.2f " % share
				check(is_equal_approx(n.bones[0].get_length(), n.joints[0].distance_to(n.joints[1])), "the first bone of neck %d is as long as its section shows" % i)
				# A head that looks back at its own body turns its neck round behind it: a
				# tighter bend, so the sections there bunch a little more.
				var looks_back: bool = i != 1 and face * (HaarWyrm.HOMES[i] as Vector2).x < 0.0
				check(worst < (0.25 if looks_back else 0.15), "every section of neck %d shows about the same share (off by %.2f at %s: stack %.2f, %s)" % [i, worst, spot, n.stack, shares])
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
	_settle(rig, 2, at, {"mode": "breathe", "face": 1.0, "breath": HydraHead.GEYSER, "aim": Vector2(1, 1).normalized()})
	check(n.clip == "open" and absf(n.rot - PI / 4.0) < 0.05, "the geyser head opens its jaws along its aim (%s, %.2f)" % [n.clip, n.rot])
	_settle(rig, 2, at, {"mode": "breathe", "face": -1.0, "breath": HydraHead.GEYSER, "aim": Vector2(-1, 1).normalized()})
	check(n.head_skin.flip_h and absf(n.rot + PI / 4.0) < 0.05, "and the same when it faces west (%.2f)" % n.rot)
	var jaws := rig.mouth(2, at, -1.0) - at
	check(jaws.x < -4.0 and jaws.y > 10.0, "its breath leaves its jaws, down and to the west of its middle (%s)" % jaws)
	_settle(rig, 2, HaarWyrm.DROOP[2], {"mode": "weak", "face": -1.0, "weak": true})
	check(n.head_skin.modulate.b > n.head_skin.modulate.r + 0.1, "a doused head is drenched blue")
	_settle(rig, 2, Vector2(136, 70), {"mode": "limp", "face": 1.0, "dead": true})
	check(n.rot > 0.9 and is_equal_approx(n.head_skin.modulate.r, WyrmRig.LIMP.r), "a dead head hangs nose down, grey (%.2f)" % n.rot)
	_settle(rig, 2, at, {"mode": "idle", "face": 1.0, "white": 1.0})
	check(is_equal_approx(float(n.material.get_shader_parameter("white")), 1.0) and n.head_skin.material == n.material, "a struck head flashes white")
	var plain := true
	for sp in n.skins:
		plain = plain and sp.material == null
	check(plain, "and its neck does not: only the head flashes")
	check(not ("texture(TEXTURE" in WyrmRig.WASH), "the flash only whitens: it never multiplies the art by itself, which darkened it")
	# The middle head faces us and has its own clips.
	var m := rig.necks[1]
	_settle(rig, 1, HaarWyrm.HOMES[1], {"mode": "tell", "face": 1.0, "breath": HydraHead.FOG, "time": 2.9, "tell": 3.0})
	check(m.clip == "glow" and m.frame >= 4 and not m.head_skin.flip_h, "the fog head's jaws open on the glow in its throat (%s %d)" % [m.clip, m.frame])
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
		rig.pose_head(i, at, {"mode": "hidden", "intro": float(HaarWyrm.EYES_AT[i]) + WyrmRig.EYES_OPEN}, 0.016)
		check(n.shown and is_equal_approx(n.eyes, 1.0), "head %d's eyes open at its moment in the reveal (%.2f)" % [i, n.eyes])
		check(n.skins[-1].modulate.r < 0.3, "and its neck is still in the dark (%.2f)" % n.skins[-1].modulate.r)
		if n.view == "side":
			check(n.shade_skin.visible and not n.head_skin.visible, "a side head waits as its shadowed twin")
		else:
			check(n.clip == "wake" and n.frame == 2, "the middle head's eyes have opened (%s %d)" % [n.clip, n.frame])
			rig.pose_head(i, at, {"mode": "hidden", "intro": float(HaarWyrm.SNORTS_AT[i]) + WyrmRig.SNORT * 0.5}, 0.016)
			check(n.frame > 4, "and it snorts when its turn comes (frame %d)" % n.frame)
	# Coming out, the shadow draws off: half way, a side head's twin is half gone.
	var e := rig.necks[2]
	rig.pose_head(2, HaarWyrm.HOMES[2], {"mode": "emerge", "time": HaarWyrm.EMERGE_TIME * 0.5, "face": 1.0}, 0.016)
	check(e.head_skin.visible and e.shade_skin.visible and absf(e.shade_skin.modulate.a - 0.5) < 0.01, "the shadow draws off a side head as it comes out (%.2f)" % e.shade_skin.modulate.a)
	var m := rig.necks[1]
	rig.pose_head(1, HaarWyrm.HOMES[1], {"mode": "emerge", "time": HaarWyrm.EMERGE_TIME * 0.5}, 0.016)
	check(m.clip == "recede" and m.frame > 4, "and off the middle head, in its own frames (%s %d)" % [m.clip, m.frame])
	rig.pose_head(2, HaarWyrm.HOMES[2], {"mode": "idle", "face": 1.0}, 0.016)
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
	var g := z.heads[2]
	check(z.mouth_of(g).distance_to(z.rig.mouth(2, g.global_position, z._face(g))) < 0.01, "the geyser leaves the rigged head's jaws")


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

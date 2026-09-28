extends TestSuite
## Visual karakter (GDD 4.1, 12.2, 31, 37.4, 130.2): kontrak node, anggaran
## segitiga & draw call, proporsi emas, rambut tidak menutupi mata, determinisme,
## ekspresi, dan pose membawa barang. Semua diperiksa dari struktur node dan meta
## MeshBuilder ("tris", "aabb"), tanpa renderer, sehingga berjalan headless.

const PARTS: Array[String] = ["Body", "Head", "Face", "EyeL", "EyeR", "BrowL", "BrowR", "Mouth", "Hair", "Hat",
	"Apron", "ArmL", "ArmR", "LegL", "LegR", "CarryAnchor", "ShadowBlob"]
const MOODS: Array[String] = ["senang", "netral", "kesal", "sedih", "kaget"]


func tests() -> Array:
	return [
		{"id": "ACC_31_CHARACTER_RIG", "name": "every character variant has the full rig within the triangle and draw-call budget", "fn": _rig},
		{"id": "ACC_130_PROPORTIONS", "name": "golden proportions: 0.90 m, head 42%, torso 30%, legs 28%, eye line ~45%", "fn": _proportions},
		{"id": "ACC_31_HAIR_CLEAR", "name": "hair and hats never cover the eyes or brows", "fn": _hair_clear},
		{"id": "ACC_31_DETERMINISM", "name": "the same customer seed builds the same character; seeds vary", "fn": _determinism},
		{"id": "ACC_31_EXPRESSIONS", "name": "expressions reshape eyes, brows and mouth; carry pose holds items", "fn": _expressions},
	]


## Semua varian yang benar-benar muncul di game, plus spec kosong.
func _all_specs() -> Array:
	var out: Array = []
	out.append(["player female", CharacterFactory.spec_for_player("wanita")])
	out.append(["player male", CharacterFactory.spec_for_player("pria")])
	for def: StaffDefinition in DataRegistry.staff_list():
		out.append([String(def.id), CharacterFactory.spec_for_staff(String(def.id))])
	for arch: String in CharacterFactory.ARCHETYPE_VISUAL.keys():
		for seed_i: int in [1, 7, 42]:
			out.append(["%s/%d" % [arch, seed_i], CharacterFactory.spec_for_customer(arch, seed_i)])
	for seed_j in 12:
		out.append(["generic/%d" % seed_j, CharacterFactory.spec_for_customer("customer_generic", 100 + seed_j)])
	out.append(["driver", CharacterFactory.spec_for_customer("driver_rotifood", 3, false)])
	out.append(["driver in rain", CharacterFactory.spec_for_customer("driver_rotifood", 3, true)])
	out.append(["courier", CharacterFactory.spec_for_customer("courier_supply", 5)])
	out.append(["Pak Lurah", CharacterFactory.spec_for_lurah()])
	out.append(["empty spec", {}])
	return out


func _rig() -> void:
	var worst: int = 0
	var worst_name: String = ""
	var started: int = Time.get_ticks_usec()
	var specs: Array = _all_specs()
	for entry: Array in specs:
		var who: String = entry[0]
		var ch: Node3D = CharacterFactory.build(entry[1])
		var missing: PackedStringArray = PackedStringArray()
		for p: String in PARTS:
			if CharacterFactory.part(ch, p) == null:
				missing.append(p)
		check(missing.is_empty(), "%s: rig parts present (missing %s)" % [who, ", ".join(missing)])
		check(ch.get_node_or_null("Body/ArmL") != null and ch.get_node_or_null("Body/ArmR") != null,
			"%s: arms hang from the body so they bob with it" % who)
		var tris: int = CharacterFactory.triangle_count(ch)
		if tris > worst:
			worst = tris
			worst_name = who
		check(tris >= 500 and tris <= 2000, "%s: %d triangles within 500-2000 (GDD 12.2)" % [who, tris])
		var draws: int = CharacterFactory.mesh_count(ch)
		check(draws <= 14, "%s: %d draw calls, at most 14" % [who, draws])
		for mi: MeshInstance3D in _meshes(ch):
			if mi.mesh == null:
				continue
			check(mi.material_override != null, "%s/%s: shared vertex-colour material" % [who, mi.name])
			check(mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s/%s: no shadow casting (blob instead)" % [who, mi.name])
		ch.free()
	var avg_ms: float = float(Time.get_ticks_usec() - started) / 1000.0 / float(specs.size())
	print("      %d variants, heaviest %s with %d triangles, %.1f ms per build" % [specs.size(), worst_name, worst, avg_ms])
	check(avg_ms < 60.0, "building one character stays cheap for actor pooling (%.1f ms)" % avg_ms)


func _proportions() -> void:
	var spec: Dictionary = {"hair_style": "cepak", "hat": "none", "height": 1.0, "mood": "netral"}
	var ch: Node3D = CharacterFactory.build(spec)
	runner.add_child(ch)
	var feet: float = minf(_world_aabb(ch, "LegL/LegLMesh").position.y, _world_aabb(ch, "LegR/LegRMesh").position.y)
	var head_box: AABB = _world_aabb(ch, "Head/HeadMesh")
	var chin: float = head_box.position.y
	var top: float = head_box.end.y
	var hip: float = (CharacterFactory.part(ch, "LegL")).global_position.y
	var total: float = top - feet
	near(feet, 0.0, 0.004, "feet stand on the floor")
	near(total, 0.90, 0.03, "total height about 0.90 m (GDD 130.2)")
	near((top - chin) / total, 0.42, 0.03, "head about 42% of the height")
	near((chin - hip) / total, 0.30, 0.03, "torso about 30% of the height")
	near((hip - feet) / total, 0.28, 0.03, "legs about 28% of the height")
	var eye_y: float = (CharacterFactory.part(ch, "EyeL")).global_position.y
	near((eye_y - chin) / (top - chin), 0.45, 0.04, "eye line about 45% of the head from the chin")
	near((CharacterFactory.part(ch, "ArmL")).global_position.y, EquipmentFactory.CHEST_HEIGHT, 0.001,
		"shoulder line is the counter chest height")
	var eye_r: float = (CharacterFactory.part(ch, "EyeR")).global_position.x
	var eye_l: float = (CharacterFactory.part(ch, "EyeL")).global_position.x
	check(eye_l < 0.0 and eye_r > 0.0 and absf(eye_l + eye_r) < 0.001, "eyes are mirrored across the face")
	check(_world_aabb(ch, "ShadowBlob").position.y < 0.01, "shadow blob lies on the floor")
	ch.get_parent().remove_child(ch)
	ch.free()


func _hair_clear() -> void:
	var brow_top: float = CharacterFactory.BROW_Y + 0.006
	check(CharacterFactory.BROW_Y - 0.006 > CharacterFactory.EYE_Y + CharacterFactory.EYE_RADII.y, "brows sit above the eyes")
	check(CharacterFactory.BANG_BOTTOM > brow_top, "fringe line sits above the brows")
	check(CharacterFactory.BRIM_Y > CharacterFactory.BANG_BOTTOM, "hat brims sit above the fringe tips so the bangs peek out")
	for style: String in CharacterFactory.HAIR_STYLES.keys():
		var low: float = CharacterFactory.lowest_hair_over_eyes(style)
		check(low >= brow_top, "%s: hair in front of the eyes ends at %.3f m, above the brows (%.3f m)" % [style, low, brow_top])
	# Setiap kombinasi gaya rambut x topi dirakit tanpa error.
	for style2: String in CharacterFactory.HAIR_STYLES.keys():
		for hat: String in ["none", "topi_koki", "toque", "bandana", "bando", "bando_kelinci", "hachimaki", "topi_pet", "helm", "peci"]:
			var ch: Node3D = CharacterFactory.build({"hair_style": style2, "hat": hat, "apron": Palette.PASTEL_MINT})
			check(CharacterFactory.triangle_count(ch) <= 2200, "%s + %s stays near the budget" % [style2, hat])
			ch.free()


func _determinism() -> void:
	for arch: String in CharacterFactory.ARCHETYPE_VISUAL.keys():
		var a: Dictionary = CharacterFactory.spec_for_customer(arch, 77)
		var b: Dictionary = CharacterFactory.spec_for_customer(arch, 77)
		eq(str(a), str(b), "%s spec is deterministic" % arch)
		var ca: Node3D = CharacterFactory.build(a)
		var cb: Node3D = CharacterFactory.build(b)
		eq(CharacterFactory.triangle_count(ca), CharacterFactory.triangle_count(cb), "%s triangle count is deterministic" % arch)
		eq(_boxes(ca), _boxes(cb), "%s geometry is deterministic" % arch)
		ca.free()
		cb.free()
	var looks: Dictionary = {}
	for seed_i in 24:
		var sp: Dictionary = CharacterFactory.spec_for_customer("customer_generic", seed_i)
		looks["%s|%s|%s|%s" % [sp["hair_style"], sp["cloth"], sp["skin"], sp["hair"]]] = true
	check(looks.size() >= 16, "generic customers look varied (%d distinct of 24)" % looks.size())


func _expressions() -> void:
	var ch: Node3D = CharacterFactory.build(CharacterFactory.spec_for_customer("customer_generic", 5))
	var eye: Node3D = CharacterFactory.part(ch, "EyeL")
	var mouth: Node3D = CharacterFactory.part(ch, "Mouth")
	var base_eye: Vector3 = eye.get_meta("base_scale")
	CharacterFactory.set_expression(ch, "senang")
	check(eye.scale.y < base_eye.y, "happy eyes squint into a smile")
	check(mouth.basis.y.y > 0.0, "happy mouth opens upward")
	CharacterFactory.set_expression(ch, "kesal")
	for side: String in ["L", "R"]:
		var ends: Array = _brow_ends(CharacterFactory.part(ch, "Brow" + side))
		check(float(ends[0]) < float(ends[1]), "annoyed: inner end of Brow%s drops" % side)
	CharacterFactory.set_expression(ch, "sedih")
	for side2: String in ["L", "R"]:
		var ends2: Array = _brow_ends(CharacterFactory.part(ch, "Brow" + side2))
		check(float(ends2[0]) > float(ends2[1]), "sad: inner end of Brow%s rises" % side2)
	check(mouth.basis.y.y < 0.0, "sad mouth turns into a frown")
	CharacterFactory.set_expression(ch, "kaget")
	check(eye.scale.y > base_eye.y, "surprised eyes widen")
	CharacterFactory.set_expression(ch, "no_such_mood")
	eq(ch.get_meta("mood"), "netral", "unknown mood falls back to neutral")
	for mood: String in MOODS:
		CharacterFactory.set_expression(ch, mood)
		eq(ch.get_meta("mood"), mood, "mood %s applies" % mood)
	# Pose membawa barang (GDD 4.2, 31.2): lengan maju dan ayunannya diredam.
	var arm: Node3D = CharacterFactory.part(ch, "ArmR")
	var rest: Vector3 = arm.rotation
	ProceduralAnimationSystem.set_carry_pose(ch, true)
	check(arm.rotation.x > deg_to_rad(40.0), "carrying swings both arms forward to hold the item")
	ProceduralAnimationSystem.walk(ch, 0.37, 1.0)
	check(absf(arm.rotation.x - CharacterFactory.carry_arm_rotation(1.0).x) < 0.1, "carrying arms barely swing while walking")
	ProceduralAnimationSystem.set_carry_pose(ch, false)
	near(arm.rotation.x, rest.x, 0.001, "putting the item down restores the arm pose")
	ProceduralAnimationSystem.walk(ch, 0.37, 1.0)
	check(absf(arm.rotation.x - rest.x) > 0.05, "free arms swing while walking")
	ch.free()
	# Kurir yang memeluk kardus sudah dirakit dengan lengan maju.
	var courier: Node3D = CharacterFactory.build(CharacterFactory.spec_for_courier())
	check((CharacterFactory.part(courier, "ArmL")).rotation.x > deg_to_rad(40.0), "courier hugs the parcel")
	courier.free()


## [y ujung dalam, y ujung luar] sebuah alis dalam ruang Face.
func _brow_ends(brow: Node3D) -> Array:
	var a: Vector3 = brow.position + brow.basis.x * 0.017
	var b: Vector3 = brow.position - brow.basis.x * 0.017
	var inner: Vector3 = a if absf(a.x) < absf(b.x) else b
	var outer: Vector3 = b if absf(a.x) < absf(b.x) else a
	return [inner.y, outer.y]


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c: Node in n.get_children():
		out.append_array(_meshes(c))
	return out


## Kotak batas dunia sebuah mesh dari meta "aabb" (karakter harus di dalam tree).
func _world_aabb(ch: Node3D, path: String) -> AABB:
	var mi: MeshInstance3D = ch.get_node(NodePath(path))
	var box: AABB = mi.get_meta("aabb")
	return mi.global_transform * box


func _boxes(ch: Node3D) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for mi: MeshInstance3D in _meshes(ch):
		parts.append("%s:%s:%d" % [mi.name, str(mi.get_meta("aabb")), int(mi.get_meta("tris"))])
	return "|".join(parts)

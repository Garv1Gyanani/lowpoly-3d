class_name DesertTerrainBuilder
extends RefCounted

## Sculpted Fractured-Slab & Chiseled-Pillar Canyon Environment:
## - Smooth sunlit desert basin (strictly y=0 across the 64x64 buildable map & Route 163)
## - Chiseled vertical cliff monoliths with angular vertical fracture grooves & flat ledges
## - Tilted tectonic sandstone & weathered-taupe shear slabs leaning into cliff bases
## - Clustered angular scree & pebble fans spilling onto the smooth sand at cliff toes

static var _scatter_cache: Array = []


static func _h(seed_val: int, salt: int) -> float:
	var n := (seed_val * 374761393 + salt * 668265263 + 1442695041) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


static func height_at(x: float, z: float) -> float:
	var flat_x := maxf(0.0, absf(x) - 72.0)
	var flat_z := (-124.0 - z) if z < -124.0 else ((z - 24.0) if z > 24.0 else 0.0)
	var radial := sqrt(flat_x * flat_x + flat_z * flat_z)
	if radial <= 0.001:
		return 0.0
	var blend := clampf(radial / 56.0, 0.0, 1.0)
	var smooth := blend * blend * (3.0 - 2.0 * blend)
	# Keep the Monument Valley floor vast, low, and expansive all the way to the distant horizon
	# so isolated Mitten Buttes tower high into the open sky!
	var w1 := sin(x * 0.032 + z * 0.026) * 0.65
	var w2 := cos(x * 0.058 - z * 0.042) * 0.35
	var side_rise := clampf((absf(x) - 145.0) * 0.025, 0.0, 2.8) if absf(x) > 145.0 else 0.0
	return maxf(0.0, (w1 + w2 + 0.65 + side_rise) * smooth)


static func build_backdrop_node() -> Node3D:
	var kit := MeshKit.new()
	_build_terrain(kit)
	_build_highway(kit)
	_build_canyon_cliffs_and_slabs(kit)
	_build_telephone_poles(kit)
	return kit.build_node("WorldBackdrop", true)


static func _build_terrain(kit: MeshKit) -> void:
	var xs: Array[float] = [-460, -330, -235, -165, -118, -90, -72, -48, -24, 0, 24, 48, 72, 90, 118, 165, 235, 330, 460]
	var zs: Array[float] = [-460, -340, -255, -195, -158, -138, -124, -96, -64, -40, -16, 4, 16, 24, 42, 75, 130]
	var grid: Array = []
	for z in zs:
		var row: Array[Vector3] = []
		for x in xs:
			row.append(Vector3(x, height_at(x, z), z))
		grid.append(row)

	for r in range(zs.size() - 1):
		for c in range(xs.size() - 1):
			var v00: Vector3 = grid[r][c]
			var v10: Vector3 = grid[r][c + 1]
			var v11: Vector3 = grid[r + 1][c + 1]
			var v01: Vector3 = grid[r + 1][c]
			var avg_y := (v00.y + v10.y + v11.y + v01.y) * 0.25
			var avg_z := (v00.z + v11.z) * 0.5
			var rise_mix := clampf(avg_y / 6.5, 0.0, 1.0)
			var far_mix := clampf((-130.0 - avg_z) / 180.0, 0.0, 0.55) if avg_z < -130.0 else 0.0
			# Smooth, clean warm desert sand so sharp scree shards & fractured cliffs pop!
			var facet_tint := 0.0 if (r + c) % 2 == 0 else 0.032
			var col := DesertPalette.SAND.lerp(Color("ca8370"), clampf(rise_mix * 0.55 + far_mix * 0.45, 0.0, 0.75))
			col = col.lerp(DesertPalette.SAND_DARK, facet_tint)
			if (r + c) % 2 == 0:
				kit.add_tri(v00, v01, v11, col)
				kit.add_tri(v00, v11, v10, col)
			else:
				kit.add_tri(v00, v01, v10, col)
				kit.add_tri(v10, v01, v11, col)


static func _build_highway(kit: MeshKit) -> void:
	var hz := OutpostLayout.HIGHWAY_CENTER_Z
	kit.add_ground_rect(0.0, 0.016, hz, 520.0, 4.9, DesertPalette.ASPHALT_SHOULDER)
	kit.add_ground_rect(0.0, 0.028, hz, 520.0, 3.85, DesertPalette.ASPHALT)
	kit.add_ground_rect(0.0, 0.038, hz - 1.70, 520.0, 0.11, DesertPalette.ROAD_WHITE)
	kit.add_ground_rect(0.0, 0.038, hz + 1.70, 520.0, 0.11, DesertPalette.ROAD_WHITE)
	var dx := -150.0
	while dx <= 150.0:
		kit.add_ground_rect(dx, 0.042, hz, 1.5, 0.13, DesertPalette.ROAD_YELLOW)
		dx += 3.2


# ==============================================================================
# ICONIC MONUMENT VALLEY SANDSTONE BUTTES, MITTEN SPIRES & TIERED TALUS SKIRTS
# ==============================================================================

## Builds a natural CONCAVE sweeping talus pedestal ("Organ Rock Shale") with organic irregular spurs,
## subtle horizontal shale clifflets, and real 3D facet shading (zero artificial radial stripes!).
static func _add_tiered_talus_pedestal(
	kit: MeshKit,
	base_rx: float,
	base_rz: float,
	top_rx: float,
	top_rz: float,
	top_shift_x: float,
	pedestal_h: float,
	seed_val: int
) -> void:
	const SEGMENTS := 20
	# True concave talus profile: wide gentle toe -> dark shale micro-cliff -> mid talus sweep ->
	# upper shale bench -> steep upper talus collar hugging the sheer sandstone wall!
	var y_fracs: Array[float] = [-0.05, 0.12, 0.19, 0.52, 0.59, 1.00]
	var r_lerps: Array[float] = [0.00, 0.26, 0.29, 0.66, 0.69, 1.00]

	# Organic multi-harmonic radial shape (irregular geological lobes & gullies, NOT even-odd stripes!)
	var rad_mods: Array[float] = []
	for i in range(SEGMENTS):
		var ang := (float(i) / float(SEGMENTS)) * TAU
		var lobe := sin(ang * 3.0 + _h(seed_val, 1) * 5.0) * 0.09 + cos(ang * 5.0 + _h(seed_val, 2) * 5.0) * 0.07
		var crag := (_h(seed_val, 10 + i) - 0.5) * 0.13
		rad_mods.append(1.0 + lobe + crag)

	var rings: Array = []
	for t_idx in range(y_fracs.size()):
		var ring: Array[Vector3] = []
		var rl := r_lerps[t_idx]
		var rx := lerpf(base_rx, top_rx, rl)
		var rz := lerpf(base_rz, top_rz, rl)
		var sx := top_shift_x * rl
		var vy := pedestal_h * y_fracs[t_idx]
		for i in range(SEGMENTS):
			var ang := (float(i) / float(SEGMENTS)) * TAU + float(t_idx % 2) * 0.04
			var mod_f := lerpf(rad_mods[i], 1.0 + (_h(seed_val, 40 + i) - 0.5) * 0.08, rl * 0.55)
			var y_j := (_h(seed_val, t_idx * 23 + i) - 0.5) * pedestal_h * (0.035 if t_idx > 0 and t_idx < 5 else 0.0)
			ring.append(Vector3(sx + cos(ang) * rx * mod_f, vy + y_j, sin(ang) * rz * mod_f))
		rings.append(ring)

	var toe_col := DesertPalette.TERRACOTTA.lerp(DesertPalette.SAND_DARK, 0.22)
	var shale_cliff := DesertPalette.CLIFF_DEEP.lerp(DesertPalette.CLIFF_CREVICE, 0.28)
	var talus_mid := DesertPalette.CLIFF_ROSE
	var talus_upper := DesertPalette.CLIFF_ROSE.lerp(DesertPalette.CLIFF_DEEP, 0.18)

	for band in range(y_fracs.size() - 1):
		var r0: Array = rings[band]
		var r1: Array = rings[band + 1]
		var base_c: Color
		if band == 0:
			base_c = toe_col
		elif band == 1 or band == 3:
			# Steep dark rust-maroon Organ Rock shale clifflet risers (like bottom of West Mitten!)
			base_c = shale_cliff
		elif band == 2:
			base_c = talus_mid
		else:
			base_c = talus_upper
		for i in range(SEGMENTS):
			var nxt := (i + 1) % SEGMENTS
			var v_tint := (_h(seed_val, band * 31 + i) - 0.5) * 0.05
			var fcol := base_c.lightened(maxf(0.0, v_tint)).darkened(maxf(0.0, -v_tint))
			# Triangulate alternating diagonals for organic chiseled low-poly rock facets!
			if (i + band) % 2 == 0:
				kit.add_tri(r0[nxt], r0[i], r1[i], fcol)
				kit.add_tri(r0[nxt], r1[i], r1[nxt], fcol)
			else:
				kit.add_tri(r0[nxt], r0[i], r1[nxt], fcol)
				kit.add_tri(r0[i], r1[i], r1[nxt], fcol)

	# Cap top of pedestal
	var top_ring: Array = rings[rings.size() - 1]
	var tc := Vector3(top_shift_x, pedestal_h, 0.0)
	for i in range(SEGMENTS):
		var nxt := (i + 1) % SEGMENTS
		kit.add_tri(tc, top_ring[nxt], top_ring[i], talus_mid)

	# 7 Organic Protruding Rocky Talus Buttress Spurs & Ledge Outcrops around the skirt!
	for s_i in range(7):
		var ang := (float(s_i) / 7.0) * TAU + _h(seed_val, 80 + s_i) * 0.45
		var dist_f := 0.46 + _h(seed_val, 90 + s_i) * 0.24
		var ox := top_shift_x * (1.0 - dist_f) + cos(ang) * base_rx * dist_f
		var oz := sin(ang) * base_rz * dist_f
		var oy := pedestal_h * (0.10 + (1.0 - dist_f) * 0.42)
		var sw := base_rx * (0.14 + _h(seed_val, 100 + s_i) * 0.10)
		var sh := pedestal_h * (0.18 + _h(seed_val, 110 + s_i) * 0.14)
		kit.add_frustum(ox, oy - sh * 0.35, oz, sw, sw * 0.72, sw * 0.52, sw * 0.40, sh, 6, DesertPalette.CLIFF_DEEP, DesertPalette.CLIFF_ROSE, ang, 0.20, seed_val + s_i)


## Builds a sheer, deeply-fluted vertical De Chelly sandstone fortress block (16-ribbed polygonal
## column with dark maroon vertical crevices, horizontal strata bands, and a stepped eroded caprock crown!).
static func _add_fluted_sandstone_fortress(
	kit: MeshKit,
	pos: Vector3,
	w: float,
	h: float,
	d: float,
	yaw: float,
	crown_bias_x: float,
	seed_val: int
) -> void:
	kit.push_tx(pos, yaw)
	var hw := w * 0.5
	var hd := d * 0.5

	# 16-point deeply fluted sandstone cliff outline (CCW around +Y: front -> right -> back -> left!)
	# Alternating protruding sandstone pilasters & recessed maroon vertical chimney clefts!
	var raw_pts: Array[Vector2] = [
		Vector2(-hw * 0.88, hd * 0.86),
		Vector2(-hw * 0.54, hd * 1.02),
		Vector2(-hw * 0.22, hd * 0.78), # Deep front-left vertical cleft!
		Vector2(hw * 0.14, hd * 1.04),  # Bold central sunlit sandstone rib!
		Vector2(hw * 0.46, hd * 0.80),  # Deep front-right vertical cleft!
		Vector2(hw * 0.84, hd * 0.96),
		Vector2(hw * 1.00, hd * 0.46),
		Vector2(hw * 0.80, 0.0),        # Side cleft
		Vector2(hw * 0.98, -hd * 0.48),
		Vector2(hw * 0.84, -hd * 0.92),
		Vector2(hw * 0.32, -hd * 0.78),
		Vector2(-hw * 0.16, -hd * 0.98),
		Vector2(-hw * 0.58, -hd * 0.80),
		Vector2(-hw * 0.90, -hd * 0.90),
		Vector2(-hw * 1.00, -hd * 0.42),
		Vector2(-hw * 0.78, hd * 0.12), # Left cleft
	]
	var n := raw_pts.size()
	var pts: Array[Vector2] = []
	for i in range(n):
		var p := raw_pts[i]
		var jx := 1.0 + (_h(seed_val, i * 5 + 1) - 0.5) * 0.10
		var jz := 1.0 + (_h(seed_val, i * 5 + 2) - 0.5) * 0.10
		pts.append(Vector2(p.x * jx, p.y * jz))

	# 4 vertical cliff rings: base -> mid-lower -> mid-upper ledge -> main rim (nearly 88-deg sheer!)
	var y_tiers: Array[float] = [0.0, h * 0.42, h * 0.76, h * 0.88]
	var tapers: Array[float] = [1.02, 0.98, 0.95, 0.92]
	var cliff_rings: Array = []
	for t_i in range(4):
		var r: Array[Vector3] = []
		var tap := tapers[t_i]
		var vy := y_tiers[t_i]
		for i in range(n):
			r.append(Vector3(pts[i].x * tap, vy, pts[i].y * tap))
		cliff_rings.append(r)

	var rib_lit := DesertPalette.CLIFF_ROSE
	var rib_warm := DesertPalette.CLIFF_CORAL_TOP.lerp(DesertPalette.CLIFF_ROSE, 0.55)
	var cleft_dark := DesertPalette.CLIFF_DEEP.lerp(DesertPalette.CLIFF_CREVICE, 0.46)

	# Detect recessed cleft segments so vertical chimney grooves hold rich maroon shadow!
	for band in range(3):
		var r0: Array = cliff_rings[band]
		var r1: Array = cliff_rings[band + 1]
		for i in range(n):
			var nxt := (i + 1) % n
			var rad_avg := (pts[i].length() + pts[nxt].length()) * 0.5
			var ref_rad := sqrt(hw * hw + hd * hd) * 0.86
			var is_recessed := rad_avg < ref_rad
			var base_c := cleft_dark if is_recessed else (rib_warm if band == 2 else rib_lit)
			if band == 0:
				base_c = base_c.darkened(0.06)
			kit.add_quad(r0[i], r0[nxt], r1[nxt], r1[i], base_c)

	# Main Rim Tabletop (88% height)
	var rim_ring: Array = cliff_rings[3]
	var rim_c := Vector3(0.0, h * 0.88, 0.0)
	for i in range(n):
		var nxt := (i + 1) % n
		kit.add_tri(rim_c, rim_ring[i], rim_ring[nxt], DesertPalette.CLIFF_CORAL_TOP)

	# Stepped Eroded Caprock Tier 1 (74% width, 88% -> 95% height)
	var cap1_b: Array[Vector3] = []
	var cap1_t: Array[Vector3] = []
	var shift1 := crown_bias_x * hw * 0.16
	for i in range(n):
		var p := pts[i]
		cap1_b.append(Vector3(shift1 + p.x * 0.74, h * 0.875, p.y * 0.72))
		cap1_t.append(Vector3(shift1 + p.x * 0.68, h * 0.95, p.y * 0.66))
	for i in range(n):
		var nxt := (i + 1) % n
		var ccol := DesertPalette.CLIFF_DEEP if (i % 2 == 0) else DesertPalette.CLIFF_ROSE
		kit.add_quad(cap1_b[i], cap1_b[nxt], cap1_t[nxt], cap1_t[i], ccol)
	var c1_center := Vector3(shift1, h * 0.95, 0.0)
	for i in range(n):
		var nxt := (i + 1) % n
		kit.add_tri(c1_center, cap1_t[i], cap1_t[nxt], DesertPalette.CLIFF_CORAL_TOP)

	# Asymmetric Eroded Summit Knoll / Caprock Crown (like West & East Mitten's upper summit ledge!)
	if absf(crown_bias_x) > 0.01:
		var shift2 := crown_bias_x * hw * 0.36
		var cap2_b: Array[Vector3] = []
		var cap2_t: Array[Vector3] = []
		for i in range(n):
			var p := pts[i]
			cap2_b.append(Vector3(shift2 + p.x * 0.42, h * 0.945, p.y * 0.46))
			cap2_t.append(Vector3(shift2 + p.x * 0.36, h * 1.00, p.y * 0.40))
		for i in range(n):
			var nxt := (i + 1) % n
			kit.add_quad(cap2_b[i], cap2_b[nxt], cap2_t[nxt], cap2_t[i], DesertPalette.CLIFF_ROSE)
		var c2_center := Vector3(shift2, h * 1.00, 0.0)
		for i in range(n):
			var nxt := (i + 1) % n
			kit.add_tri(c2_center, cap2_t[i], cap2_t[nxt], DesertPalette.CLIFF_CORAL_TOP.lightened(0.04))

	kit.pop_tx()


## Builds a slender, vertical fluted sandstone "Thumb" spire (with slightly blocky caprock head!).
static func _add_sandstone_spire(
	kit: MeshKit,
	pos: Vector3,
	w: float,
	h: float,
	d: float,
	yaw: float,
	seed_val: int
) -> void:
	kit.push_tx(pos, yaw)
	const N := 10
	var hw := w * 0.5
	var hd := d * 0.5
	var y_tiers: Array[float] = [0.0, h * 0.52, h * 0.86, h * 0.90, h * 1.00]
	# Subtle neck-in at 0.86 then blocky caprock head flare at 0.90 (just like West Mitten's Thumb!)
	var scales: Array[float] = [1.06, 0.92, 0.82, 0.90, 0.84]
	var rings: Array = []
	for t_i in range(y_tiers.size()):
		var r: Array[Vector3] = []
		var sc := scales[t_i]
		var vy := y_tiers[t_i]
		for i in range(N):
			var ang := (float(i) / float(N)) * TAU + 0.25
			var flute := 1.0 + (0.12 if i % 2 == 0 else -0.10) * (0.8 + _h(seed_val, i) * 0.4)
			r.append(Vector3(cos(ang) * hw * sc * flute, vy, sin(ang) * hd * sc * flute))
		rings.append(r)

	for band in range(y_tiers.size() - 1):
		var r0: Array = rings[band]
		var r1: Array = rings[band + 1]
		for i in range(N):
			var nxt := (i + 1) % N
			var col := DesertPalette.CLIFF_CREVICE if (band == 2) else (DesertPalette.CLIFF_DEEP if i % 2 == 1 else DesertPalette.CLIFF_ROSE)
			kit.add_quad(r0[nxt], r0[i], r1[i], r1[nxt], col)

	var top_r: Array = rings[rings.size() - 1]
	var tc := Vector3(0.0, h, 0.0)
	for i in range(N):
		var nxt := (i + 1) % N
		kit.add_tri(tc, top_r[nxt], top_r[i], DesertPalette.CLIFF_CORAL_TOP)
	kit.pop_tx()


## Scatters natural weathered red-sandstone talus boulders & dry olive-sage scrub around a butte's toe!
static func add_scree_fan(
	kit: MeshKit,
	center: Vector3,
	spread_x: float,
	spread_z: float,
	count: int,
	seed_val: int
) -> void:
	for i in range(count):
		var ang := _h(seed_val, i * 5 + 1) * TAU
		var rad_t := 0.68 + 0.38 * _h(seed_val, i * 5 + 2)
		var sx := center.x + cos(ang) * spread_x * rad_t
		var sz := center.z + sin(ang) * spread_z * rad_t
		var sy := height_at(sx, sz)
		if i % 3 == 0:
			# Sparse olive-sage desert scrub dotting the lower talus apron
			var br := 0.36 + _h(seed_val, i * 7 + 3) * 0.42
			add_bush(kit, Vector3(sx, sy, sz), br, ang)
		else:
			var rw := 0.35 + pow(_h(seed_val, i * 7 + 4), 2.0) * 1.45
			var rd := rw * (0.58 + _h(seed_val, i * 7 + 5) * 0.42)
			var rh := rw * (0.24 + _h(seed_val, i * 7 + 6) * 0.26)
			kit.push_tx(Vector3(sx, sy - rh * 0.25, sz), ang * 1.9)
			kit.add_tapered_box(0, 0, 0, rw, rd, rw * 0.65, rd * 0.60, rh, DesertPalette.CLIFF_DEEP, DesertPalette.CLIFF_CORAL_TOP, rw * 0.10, 0.0)
			kit.pop_tx()


## Composes an iconic Monument Valley Mitten Butte (West Mitten / East Mitten):
## Shared sweeping multi-tier talus skirt + sheer fluted Fortress ("Hand") + saddle crag + vertical "Thumb" spire!
static func add_mitten_butte(
	kit: MeshKit,
	cx: float,
	cz: float,
	scale_f: float,
	yaw: float,
	thumb_on_right: bool,
	seed_val: int
) -> void:
	var gy := height_at(cx, cz) - 0.35
	kit.push_tx(Vector3(cx, gy, cz), yaw)
	var s := scale_f
	var m := 1.0 if thumb_on_right else -1.0

	var ped_h := 11.4 * s
	# 1. Main CONCAVE 360-deg talus skirt whose upper neck tucks straight inside the Hand (zero flat shelf!)
	_add_tiered_talus_pedestal(kit, 25.5 * s, 18.0 * s, 5.6 * s, 3.6 * s, -3.4 * m * s, ped_h * 0.90, seed_val)
	# Merged Thumb talus spur centered right beneath the Thumb spire & saddle crag!
	kit.push_tx(Vector3(6.4 * m * s, 0.0, 0.1 * s), 0.0)
	_add_tiered_talus_pedestal(kit, 15.5 * s, 13.0 * s, 2.2 * s, 1.4 * s, 0.6 * m * s, ped_h * 0.86, seed_val + 7)
	kit.pop_tx()

	# 2. Sheer Fluted Vertical Sandstone Fortress Block ("The Hand")
	_add_fluted_sandstone_fortress(
		kit,
		Vector3(-3.6 * m * s, ped_h * 0.72, 0.0),
		13.2 * s,
		17.2 * s,
		9.2 * s,
		0.05 * m,
		-0.85 * m,
		seed_val + 17
	)

	# 3. Eroded Saddle Crag nestled in the notch beside the Hand (just like West Mitten!)
	_add_sandstone_spire(
		kit,
		Vector3(3.8 * m * s, ped_h * 0.78, -0.2 * s),
		2.5 * s,
		8.8 * s,
		2.4 * s,
		0.22 * m,
		seed_val + 31
	)

	# 4. Iconic Slender Vertical "Thumb" Spire rising across the sky-notch on the same talus pedestal!
	_add_sandstone_spire(
		kit,
		Vector3(7.6 * m * s, ped_h * 0.74, 0.2 * s),
		2.9 * s,
		14.2 * s,
		2.8 * s,
		-0.12 * m,
		seed_val + 47
	)
	kit.pop_tx()

	add_scree_fan(kit, Vector3(cx, 0.0, cz), 25.0 * s, 18.0 * s, 38, seed_val + 83)


## Composes a classic Monument Valley Flat-Topped Fortress Butte / Spire Mesa (Merrick Butte / Three Sisters)!
static func add_monument_mesa(
	kit: MeshKit,
	cx: float,
	cz: float,
	w_scale: float,
	h_scale: float,
	yaw: float,
	with_sister_spires: bool,
	seed_val: int
) -> void:
	var gy := height_at(cx, cz) - 0.35
	kit.push_tx(Vector3(cx, gy, cz), yaw)
	var ped_h := 10.5 * h_scale
	_add_tiered_talus_pedestal(kit, 22.0 * w_scale, 16.0 * w_scale, 6.2 * w_scale, 4.2 * w_scale, 0.0, ped_h * 0.88, seed_val)
	if with_sister_spires:
		# Narrow fortress fin + Three Sisters style vertical sandstone needles!
		_add_fluted_sandstone_fortress(kit, Vector3(-4.5 * w_scale, ped_h * 0.75, 0.0), 9.2 * w_scale, 15.2 * h_scale, 6.8 * w_scale, 0.06, -0.5, seed_val + 11)
		_add_sandstone_spire(kit, Vector3(2.8 * w_scale, ped_h * 0.78, 0.4 * w_scale), 2.4 * w_scale, 13.8 * h_scale, 2.3 * w_scale, 0.15, seed_val + 23)
		_add_sandstone_spire(kit, Vector3(6.2 * w_scale, ped_h * 0.76, -0.3 * w_scale), 2.1 * w_scale, 12.2 * h_scale, 2.1 * w_scale, -0.18, seed_val + 37)
		_add_sandstone_spire(kit, Vector3(9.0 * w_scale, ped_h * 0.72, 0.2 * w_scale), 1.9 * w_scale, 9.8 * h_scale, 1.9 * w_scale, 0.28, seed_val + 49)
	else:
		# Classic Merrick Butte broad fluted fortress mesa
		_add_fluted_sandstone_fortress(kit, Vector3(0.0, ped_h * 0.74, 0.0), 14.8 * w_scale, 16.4 * h_scale, 9.8 * w_scale, 0.04, 0.45, seed_val + 13)
	kit.pop_tx()
	add_scree_fan(kit, Vector3(cx, 0.0, cz), 22.5 * w_scale, 16.5 * w_scale, 30, seed_val + 71)


## Builds the low, flat, expansive distant horizon plateau line across the far valley pass
## (matching the flat hazy plateau line between the two Mittens in the reference photo!).
static func _add_horizon_mesa_rim(kit: MeshKit, pos: Vector3, w: float, h: float, d: float, yaw: float) -> void:
	kit.push_tx(pos, yaw)
	var c_side := DesertPalette.DISTANT_CANYON
	var c_top := DesertPalette.DISTANT_CANYON_TOP
	kit.add_tapered_box(0.0, -1.5, 0.0, w, d, w * 0.86, d * 0.72, h * 0.48, c_side.darkened(0.04), c_top)
	kit.add_tapered_box(0.0, h * 0.45 - 1.5, 0.0, w * 0.84, d * 0.70, w * 0.80, d * 0.64, h * 0.55, c_side, c_top)
	kit.pop_tx()


static func _build_canyon_cliffs_and_slabs(kit: MeshKit) -> void:
	# 1. HERO MONUMENT VALLEY VIEW NORTH OF THE OUTPOST:
	#    West Mitten Butte (closer midground-left, Thumb on inner right) &
	#    East Mitten Butte (deeper midground-right, Thumb on inner left),
	#    proportioned & positioned so 100% of both crowns rise cleanly into the blue sky below the top HUD!
	add_mitten_butte(kit, -36.0, -152.0, 0.96, 0.14, true, 101)
	add_mitten_butte(kit, 40.0, -182.0, 0.90, -0.16, false, 202)

	# 2. Low, flat expansive distant horizon mesa tableland far across the central pass (z ~ -340)
	_add_horizon_mesa_rim(kit, Vector3(6.0, 0.0, -340.0), 210.0, 7.6, 26.0, -0.04)
	_add_horizon_mesa_rim(kit, Vector3(-175.0, 0.0, -325.0), 160.0, 8.8, 28.0, 0.10)
	_add_horizon_mesa_rim(kit, Vector3(185.0, 0.0, -320.0), 165.0, 9.0, 28.0, -0.10)

	# 3. Well-isolated West & East Valley Rim Monuments (Merrick Butte & Three Sisters Spires)
	add_monument_mesa(kit, -110.0, -76.0, 1.00, 0.94, 1.08, false, 404)
	add_monument_mesa(kit, 110.0, -80.0, 0.98, 0.96, -1.12, true, 606)
	# Far southern perimeter mesas for 360-deg camera orbit continuity
	add_monument_mesa(kit, -126.0, 46.0, 0.86, 0.80, 2.15, false, 707)
	add_monument_mesa(kit, 128.0, 50.0, 0.88, 0.82, -2.18, false, 808)


static func _build_telephone_poles(kit: MeshKit) -> void:
	const POLE_Z := 16.8
	const POLE_H := 3.85
	var wire_col := Color("564438")
	var poles: Array[float] = []
	var x := -108.0
	while x <= 108.0:
		poles.append(x)
		var py := height_at(x, POLE_Z)
		kit.add_box(x, py, POLE_Z, 0.19, POLE_H, 0.19, DesertPalette.WOOD_DARK)
		kit.add_box(x, py + POLE_H - 0.42, POLE_Z, 0.15, 0.14, 1.15, DesertPalette.WOOD)
		kit.add_box(x, py + POLE_H - 0.28, POLE_Z - 0.44, 0.09, 0.12, 0.09, DesertPalette.CREAM)
		kit.add_box(x, py + POLE_H - 0.28, POLE_Z + 0.44, 0.09, 0.12, 0.09, DesertPalette.CREAM)
		x += 13.5
	for i in range(poles.size() - 1):
		var x0 := poles[i]
		var x1 := poles[i + 1]
		var y0 := height_at(x0, POLE_Z) + POLE_H - 0.24
		var y1 := height_at(x1, POLE_Z) + POLE_H - 0.24
		for z_off in [-0.44, 0.44]:
			kit.add_sagging_wire(Vector3(x0, y0, POLE_Z + z_off), Vector3(x1, y1, POLE_Z + z_off), wire_col, 0.34, 0.032, 5)


static func build_clouds_node() -> Node3D:
	var root := Node3D.new()
	root.name = "SkyClouds"
	return root


static func _get_scatter() -> Array:
	if not _scatter_cache.is_empty():
		return _scatter_cache
	var seed_val := 1640531527
	var guard := 0
	while _scatter_cache.size() < 110 and guard < 1200:
		guard += 1
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var x := -112.0 + (float(seed_val) / float(0x7fffffff)) * 224.0
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var z := -136.0 + (float(seed_val) / float(0x7fffffff)) * 178.0
		if z > 5.5 and z < 22.0:
			continue
		# Keep clean smooth sand right around the starter roadside cart & entry road
		if absf(x) < 11.0 and z > -32.0 and z < 8.0:
			continue
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var roll := float(seed_val) / float(0x7fffffff)
		var kind := 1 if roll < 0.50 else (0 if roll < 0.78 else 2)
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var sc := 0.75 + (float(seed_val) / float(0x7fffffff)) * 0.70
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var rot := (float(seed_val) / float(0x7fffffff)) * TAU
		_scatter_cache.append([x, z, kind, sc, rot])
	return _scatter_cache


static func add_saguaro(kit: MeshKit, pos: Vector3, s: float, rot_y: float) -> void:
	kit.push_tx(pos, rot_y)
	kit.add_frustum(0, 0, 0, 0.22 * s, 0.22 * s, 0.18 * s, 0.18 * s, 2.08 * s, 6, DesertPalette.CACTUS, DesertPalette.VEGETATION)
	kit.add_box(0, 2.08 * s, 0, 0.14 * s, 0.10 * s, 0.14 * s, DesertPalette.GOLD)
	kit.add_box(0.30 * s, 0.90 * s, 0, 0.34 * s, 0.21 * s, 0.21 * s, DesertPalette.CACTUS)
	kit.add_box(0.40 * s, 1.06 * s, 0, 0.21 * s, 0.64 * s, 0.21 * s, DesertPalette.CACTUS)
	kit.add_box(-0.28 * s, 0.64 * s, 0, 0.30 * s, 0.19 * s, 0.19 * s, DesertPalette.VEGETATION)
	kit.add_box(-0.36 * s, 0.80 * s, 0, 0.19 * s, 0.52 * s, 0.19 * s, DesertPalette.VEGETATION)
	kit.pop_tx()


static func add_bush(kit: MeshKit, pos: Vector3, radius: float, phase: float) -> void:
	kit.add_frustum(pos.x, pos.y, pos.z, radius * 0.90, radius * 0.84, radius * 0.54, radius * 0.48, radius * 0.70, 6, DesertPalette.VEGETATION, Color("7b8c64"), phase)
	kit.add_frustum(pos.x + radius * 0.36, pos.y, pos.z + radius * 0.18, radius * 0.50, radius * 0.46, radius * 0.24, radius * 0.24, radius * 0.46, 5, DesertPalette.VEGETATION_DARK, DesertPalette.VEGETATION, phase + 0.6)


## Low-slung, weathered Monument Valley red-sandstone valley outcrop + flat stone chips (zero boxy cubes!).
static func add_rock(kit: MeshKit, pos: Vector3, radius: float, h: float, phase: float) -> void:
	var s_id := int(absf(pos.x * 13.0 + pos.z * 7.0 + phase * 19.0)) + 1
	var c_side := DesertPalette.CLIFF_DEEP if (s_id % 3 == 0) else DesertPalette.CLIFF_ROSE
	var c_top := DesertPalette.CLIFF_CORAL_TOP
	kit.push_tx(pos, phase)
	# Primary low-profile 7-faceted asymmetric sandstone wedge emerging smoothly from sand
	var rx := radius * (1.15 + _h(s_id, 1) * 0.35)
	var rz := radius * (0.82 + _h(s_id, 2) * 0.30)
	var rh := h * (0.36 + _h(s_id, 3) * 0.20)
	kit.add_frustum(0.0, -0.08, 0.0, rx, rz, rx * 0.56, rz * 0.48, rh, 7, c_side, c_top, 0.3, 0.18, s_id)
	# Companion lower flat sandstone shelf overlapping one side
	kit.add_frustum(rx * 0.58, -0.06, rz * 0.22, rx * 0.62, rz * 0.54, rx * 0.40, rz * 0.34, rh * 0.54, 6, DesertPalette.CLIFF_DEEP, c_top, 1.1, 0.16, s_id + 9)
	# 3 tiny flat scree stones flush on the desert soil
	for i in range(3):
		var ang := float(i) * 1.65 + 0.4
		var dist := radius * (0.88 + _h(s_id, i + 5) * 0.45)
		var cw := 0.14 + _h(s_id, i + 9) * 0.18
		kit.add_tapered_box(cos(ang) * dist, -0.02, sin(ang) * dist, cw, cw * 0.72, cw * 0.64, cw * 0.50, cw * 0.18, DesertPalette.CLIFF_DEEP, c_top)
	kit.pop_tx()


static func add_street_lamp(kit: MeshKit, pos: Vector3) -> void:
	kit.push_tx(pos, 0.0)
	kit.add_box(0, 0, 0, 0.13, 2.35, 0.13, DesertPalette.WOOD_DARK)
	kit.add_box(0, 2.25, 0.20, 0.11, 0.11, 0.46, DesertPalette.WOOD_DARK)
	kit.add_box(0, 1.96, 0.36, 0.22, 0.28, 0.22, DesertPalette.CREAM, Color(-1, 0, 0), 1)
	kit.add_frustum(0, 2.24, 0.36, 0.20, 0.20, 0.04, 0.04, 0.14, 4, DesertPalette.METAL_DARK, Color(-1, 0, 0), PI * 0.25)
	kit.pop_tx()


static func add_welcome_sign(kit: MeshKit, pos: Vector3, rot_y: float) -> void:
	kit.push_tx(pos, rot_y)
	kit.add_box(-0.80, 0, 0, 0.17, 2.85, 0.17, DesertPalette.WOOD_DARK)
	kit.add_box(0.80, 0, 0, 0.17, 2.85, 0.17, DesertPalette.WOOD_DARK)
	kit.add_box(0, 1.4, 0, 2.25, 1.25, 0.16, DesertPalette.WOOD)
	kit.add_flush_rect_z(0, 2.02, 0.08, 2.04, 1.04, DesertPalette.CREAM, true, 1)
	kit.add_box(0, 2.65, 0, 2.45, 0.16, 0.26, DesertPalette.TERRACOTTA)
	kit.add_box(0, 2.71, 0.32, 0.34, 0.11, 0.20, DesertPalette.METAL_DARK, Color(-1, 0, 0), 1)
	kit.add_front_sign_text(0, 2.02, 0.095, 1.95, 0.95, "OLJATO\nOUTPOST", DesertPalette.SANDSTONE_DARK, true)
	kit.pop_tx()


static func build_flora_and_roads_node(state) -> Node3D:
	var kit := MeshKit.new()
	_build_roads(kit, state.road_network, state.parking_lots)
	for lot in state.parking_lots:
		if not state.relocating_lot_id.is_empty() and lot["id"] == state.relocating_lot_id:
			continue
		BuildingBuilder.add_parking_lot(kit, lot)
	for item in _get_scatter():
		var x: float = item[0]
		var z: float = item[1]
		if state.is_world_point_occupied(x, z):
			continue
		var gy := height_at(x, z)
		var kind: int = item[2]
		var sc: float = item[3]
		var rot: float = item[4]
		if kind == 0:
			add_saguaro(kit, Vector3(x, gy, z), sc, rot)
		elif kind == 1:
			add_rock(kit, Vector3(x, gy, z), 0.72 + sc * 0.62, 0.52 + sc * 0.42, rot)
		else:
			add_bush(kit, Vector3(x, gy, z), 0.38 + sc * 0.22, rot)

	if state.outpost_stage() >= 5:
		add_welcome_sign(kit, Vector3(-18.0, 0.0, 19.2), PI - 0.2)

	_add_parcel_trait_markers(kit, state)
	return kit.build_node("OutpostStatic", true)


static func _add_parcel_trait_markers(kit: MeshKit, state) -> void:
	for px in range(OutpostLayout.PARCEL_COUNT_X):
		for pz in range(OutpostLayout.PARCEL_COUNT_Z):
			var p := Vector2i(px, pz)
			var tr_id: int = state.world_grid.parcel_trait(p)
			if tr_id != GameCatalog.ParcelTrait.OIL_SEEP and tr_id != GameCatalog.ParcelTrait.AQUIFER and tr_id != GameCatalog.ParcelTrait.WIND_CORRIDOR:
				continue
			var c := OutpostLayout.parcel_center(px, pz)
			if state.is_world_point_occupied(c.x, c.z):
				continue
			if tr_id == GameCatalog.ParcelTrait.OIL_SEEP:
				kit.add_frustum(c.x, 0.015, c.z, 2.35, 1.95, 2.15, 1.75, 0.05, 8, Color("242029"), Color("332c3a"), 0.2)
				add_rock(kit, Vector3(c.x + 1.5, 0.0, c.z - 1.0), 0.75, 0.55, 0.7)
			elif tr_id == GameCatalog.ParcelTrait.AQUIFER:
				kit.add_frustum(c.x, 0.014, c.z, 2.55, 1.95, 2.35, 1.75, 0.04, 8, DesertPalette.ARROYO_DARK, DesertPalette.ARROYO_SAND, 0.4)
				kit.add_frustum(c.x, 0.025, c.z, 1.65, 1.25, 1.55, 1.15, 0.04, 8, DesertPalette.WATER, Color("76cad6"), 0.4)
				add_rock(kit, Vector3(c.x + 1.9, 0.0, c.z + 0.5), 0.65, 0.45, 0.3)
				add_bush(kit, Vector3(c.x - 1.75, 0.0, c.z - 0.65), 0.48, 1.1)
			elif tr_id == GameCatalog.ParcelTrait.WIND_CORRIDOR:
				add_rock(kit, Vector3(c.x - 0.8, 0.0, c.z), 0.75, 0.55, 0.5)
				kit.add_box(c.x + 0.9, 0.0, c.z, 0.12, 2.1, 0.12, DesertPalette.WOOD_DARK)
				kit.add_box(c.x + 1.38, 1.85, c.z, 0.82, 0.24, 0.08, DesertPalette.TURQUOISE)


static func _collect_lot_driveway_edges(parking_lots: Array) -> Dictionary:
	var open_edges: Dictionary = {}
	for lot in parking_lots:
		if not lot.get("is_connected", false):
			continue
		var spec: Dictionary = GameCatalog.PARKING_LOTS[lot["kind"]]
		var sz := OutpostLayout.rotated_size(spec["grid_w"], spec["grid_d"], lot["rot"])
		var gx: int = lot["grid_x"]
		var gz: int = lot["grid_z"]
		var side := BuildingBuilder.lot_effective_side(lot)
		match side:
			GameCatalog.LotEntrySide.SOUTH:
				for dx in range(sz.x):
					open_edges["%d,%d,N" % [gx + dx, gz + sz.y]] = true
			GameCatalog.LotEntrySide.NORTH:
				for dx in range(sz.x):
					open_edges["%d,%d,S" % [gx + dx, gz - 1]] = true
			GameCatalog.LotEntrySide.EAST:
				for dz in range(sz.y):
					open_edges["%d,%d,W" % [gx + sz.x, gz + dz]] = true
			GameCatalog.LotEntrySide.WEST:
				for dz in range(sz.y):
					open_edges["%d,%d,E" % [gx - 1, gz + dz]] = true
	return open_edges


static func _build_roads(kit: MeshKit, road_net: RoadNetwork, parking_lots: Array = []) -> void:
	const CS := OutpostLayout.GRID_CELL_SIZE
	const HALF := CS * 0.5
	var open_edges := _collect_lot_driveway_edges(parking_lots)

	for cell: Vector2i in road_net.tiles.keys():
		var tier: int = road_net.tiles[cell]
		var c := OutpostLayout.cell_center_v(cell)
		var conn := road_net.is_connected_to_highway(cell)
		var has_n := road_net.has_road(Vector2i(cell.x, cell.y - 1))
		var has_s := road_net.has_road(Vector2i(cell.x, cell.y + 1)) or cell.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z
		var has_w := road_net.has_road(Vector2i(cell.x - 1, cell.y))
		var has_e := road_net.has_road(Vector2i(cell.x + 1, cell.y))
		var has_nw := road_net.has_road(Vector2i(cell.x - 1, cell.y - 1))
		var has_ne := road_net.has_road(Vector2i(cell.x + 1, cell.y - 1))
		var has_sw := road_net.has_road(Vector2i(cell.x - 1, cell.y + 1)) or cell.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z
		var has_se := road_net.has_road(Vector2i(cell.x + 1, cell.y + 1)) or cell.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z

		var open_n := has_n or open_edges.has("%d,%d,N" % [cell.x, cell.y])
		var open_s := has_s or open_edges.has("%d,%d,S" % [cell.x, cell.y])
		var open_w := has_w or open_edges.has("%d,%d,W" % [cell.x, cell.y])
		var open_e := has_e or open_edges.has("%d,%d,E" % [cell.x, cell.y])

		var sh_col: Color
		var sf_col: Color
		var margin := 0.20
		if tier == GameCatalog.RoadTier.DIRT:
			sh_col = Color("ba8a66")
			sf_col = Color("9e6f4e") if conn else Color("916d54")
			margin = 0.24
		elif tier == GameCatalog.RoadTier.GRAVEL:
			sh_col = Color("ab9d90")
			sf_col = Color("82776d") if conn else Color("787068")
			margin = 0.18
		else:
			sh_col = DesertPalette.ASPHALT_SHOULDER
			sf_col = DesertPalette.ASPHALT if conn else Color("565359")
			margin = 0.20

		kit.add_ground_rect(c.x, 0.018, c.z, CS, CS, sh_col)

		var x0 := c.x - HALF + (0.0 if open_w else margin)
		var x1 := c.x + HALF - (0.0 if open_e else margin)
		var z0 := c.z - HALF + (0.0 if open_n else margin)
		var z1 := c.z + HALF - (0.0 if open_s else margin)
		kit.add_ground_rect((x0 + x1) * 0.5, 0.030, (z0 + z1) * 0.5, x1 - x0, z1 - z0, sf_col)

		var fil := margin * 1.45
		if has_n and has_w and not has_nw:
			kit.add_tri(Vector3(c.x - HALF, 0.033, c.z - HALF), Vector3(c.x - HALF, 0.033, c.z - HALF + fil), Vector3(c.x - HALF + fil, 0.033, c.z - HALF), sh_col)
		if has_n and has_e and not has_ne:
			kit.add_tri(Vector3(c.x + HALF - fil, 0.033, c.z - HALF), Vector3(c.x + HALF, 0.033, c.z - HALF + fil), Vector3(c.x + HALF, 0.033, c.z - HALF), sh_col)
		if has_s and has_w and not has_sw:
			kit.add_tri(Vector3(c.x - HALF, 0.033, c.z + HALF - fil), Vector3(c.x - HALF, 0.033, c.z + HALF), Vector3(c.x - HALF + fil, 0.033, c.z + HALF), sh_col)
		if has_s and has_e and not has_se:
			kit.add_tri(Vector3(c.x + HALF, 0.033, c.z + HALF - fil), Vector3(c.x + HALF - fil, 0.033, c.z + HALF), Vector3(c.x + HALF, 0.033, c.z + HALF), sh_col)

		var is_ns_west := has_e and not has_w and (has_n or has_s) and not road_net.has_road(Vector2i(cell.x + 2, cell.y))
		var is_ns_east := has_w and not has_e and (has_n or has_s) and not road_net.has_road(Vector2i(cell.x - 2, cell.y))
		var is_ew_north := has_s and not has_n and (has_w or has_e) and not road_net.has_road(Vector2i(cell.x, cell.y + 2))
		var is_ew_south := has_n and not has_s and (has_w or has_e) and not road_net.has_road(Vector2i(cell.x, cell.y - 2))
		var is_single_ns := (has_n or has_s) and not has_w and not has_e
		var is_single_ew := (has_w or has_e) and not has_n and not has_s

		var straight_ns_seam := is_ns_west and has_n and has_s and has_ne and has_se
		var straight_ew_seam := is_ew_north and has_w and has_e and has_sw and has_se

		if tier == GameCatalog.RoadTier.DIRT:
			var rut_col := Color("855a3c") if conn else Color("7a5a44")
			if is_ns_west or is_ns_east or is_single_ns:
				var lane_cx := c.x + (0.06 if is_ns_west else (-0.06 if is_ns_east else 0.0))
				kit.add_ground_rect(lane_cx - 0.34, 0.036, c.z, 0.20, CS - 0.12, rut_col)
				kit.add_ground_rect(lane_cx + 0.34, 0.036, c.z, 0.20, CS - 0.12, rut_col)
			elif is_ew_north or is_ew_south or is_single_ew:
				var lane_cz := c.z + (0.06 if is_ew_north else (-0.06 if is_ew_south else 0.0))
				kit.add_ground_rect(c.x, 0.036, lane_cz - 0.34, CS - 0.12, 0.20, rut_col)
				kit.add_ground_rect(c.x, 0.036, lane_cz + 0.34, CS - 0.12, 0.20, rut_col)
			if not open_w and not open_n and (has_e or has_s):
				kit.add_box(c.x - HALF + 0.12, 0.0, c.z - HALF + 0.12, 0.11, 0.56, 0.11, DesertPalette.WOOD_DARK)
			if not open_e and not open_n and (has_w or has_s):
				kit.add_box(c.x + HALF - 0.12, 0.0, c.z - HALF + 0.12, 0.11, 0.56, 0.11, DesertPalette.WOOD_DARK)

		elif tier == GameCatalog.RoadTier.GRAVEL:
			var crown_col := Color("9e9388")
			var edge_col := Color("beb4a8")
			if straight_ns_seam:
				kit.add_ground_rect(c.x + HALF, 0.038, c.z, 0.14, 1.05, crown_col)
			elif straight_ew_seam:
				kit.add_ground_rect(c.x, 0.038, c.z + HALF, 1.05, 0.14, crown_col)
			elif is_single_ns:
				kit.add_ground_rect(c.x, 0.038, c.z, 0.10, 0.90, crown_col)
			elif is_single_ew:
				kit.add_ground_rect(c.x, 0.038, c.z, 0.90, 0.10, crown_col)
			if not open_w:
				kit.add_ground_rect(x0 + 0.08, 0.037, (z0 + z1) * 0.5, 0.07, z1 - z0, edge_col)
			if not open_e:
				kit.add_ground_rect(x1 - 0.08, 0.037, (z0 + z1) * 0.5, 0.07, z1 - z0, edge_col)
			if not open_n:
				kit.add_ground_rect((x0 + x1) * 0.5, 0.037, z0 + 0.08, x1 - x0, 0.07, edge_col)
			if not open_s:
				kit.add_ground_rect((x0 + x1) * 0.5, 0.037, z1 - 0.08, x1 - x0, 0.07, edge_col)

		else:
			const CURB_H := 0.08
			const CURB_W := 0.18
			if not open_w:
				kit.add_box(c.x - HALF + CURB_W * 0.5, 0.018, c.z, CURB_W, CURB_H, CS, DesertPalette.CONCRETE)
				kit.add_ground_rect(x0 + 0.12, 0.039, (z0 + z1) * 0.5, 0.08, z1 - z0, DesertPalette.ROAD_WHITE)
			if not open_e:
				kit.add_box(c.x + HALF - CURB_W * 0.5, 0.018, c.z, CURB_W, CURB_H, CS, DesertPalette.CONCRETE)
				kit.add_ground_rect(x1 - 0.12, 0.039, (z0 + z1) * 0.5, 0.08, z1 - z0, DesertPalette.ROAD_WHITE)
			if not open_n:
				kit.add_box(c.x, 0.018, c.z - HALF + CURB_W * 0.5, CS, CURB_H, CURB_W, DesertPalette.CONCRETE)
				kit.add_ground_rect((x0 + x1) * 0.5, 0.039, z0 + 0.12, x1 - x0, 0.08, DesertPalette.ROAD_WHITE)
			if not open_s:
				kit.add_box(c.x, 0.018, c.z + HALF - CURB_W * 0.5, CS, CURB_H, CURB_W, DesertPalette.CONCRETE)
				kit.add_ground_rect((x0 + x1) * 0.5, 0.039, z1 - 0.12, x1 - x0, 0.08, DesertPalette.ROAD_WHITE)

			if straight_ns_seam:
				kit.add_ground_rect(c.x + HALF, 0.042, c.z, 0.11, 1.12, DesertPalette.ROAD_YELLOW)
			elif straight_ew_seam:
				kit.add_ground_rect(c.x, 0.042, c.z + HALF, 1.12, 0.11, DesertPalette.ROAD_YELLOW)
			elif is_single_ns:
				kit.add_ground_rect(c.x, 0.042, c.z, 0.09, 0.92, DesertPalette.ROAD_YELLOW)
			elif is_single_ew:
				kit.add_ground_rect(c.x, 0.042, c.z, 0.92, 0.09, DesertPalette.ROAD_YELLOW)

			if cell.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z and is_ns_west:
				kit.add_ground_rect(c.x + 0.05, 0.043, c.z + 0.65, 1.45, 0.16, DesertPalette.ROAD_WHITE)

			if not open_n and (has_w or has_e) and posmod(cell.x, 4) == 0:
				add_street_lamp(kit, Vector3(c.x, 0.0, c.z - HALF + 0.10))
			elif not open_w and (has_n or has_s) and posmod(cell.y, 4) == 0:
				add_street_lamp(kit, Vector3(c.x - HALF + 0.10, 0.0, c.z))

	for cl in road_net.highway_junction_clusters():
		var cl_cells: Array = cl["cells"]
		if cl_cells.is_empty():
			continue
		var min_x: int = cl["min_x"]
		var max_x: int = cl["max_x"]
		var best_tier := GameCatalog.RoadTier.DIRT
		for c_v in cl_cells:
			best_tier = maxi(best_tier, road_net.tile_tier(c_v))

		var j_margin := 0.24 if best_tier == GameCatalog.RoadTier.DIRT else (0.18 if best_tier == GameCatalog.RoadTier.GRAVEL else 0.20)
		var j_sh := Color("ba8a66") if best_tier == GameCatalog.RoadTier.DIRT else (Color("ab9d90") if best_tier == GameCatalog.RoadTier.GRAVEL else DesertPalette.ASPHALT_SHOULDER)
		var j_sf := Color("9e6f4e") if best_tier == GameCatalog.RoadTier.DIRT else (Color("82776d") if best_tier == GameCatalog.RoadTier.GRAVEL else DesertPalette.ASPHALT)

		var top_z := float(OutpostLayout.HIGHWAY_ENTRY_ROW_Z) * CS + HALF
		var bot_z := 11.82 if best_tier == GameCatalog.RoadTier.PAVED else 11.54
		var y_sf := 0.0395 if best_tier == GameCatalog.RoadTier.PAVED else 0.032
		var tx0 := float(min_x) * CS - HALF + j_margin
		var tx1 := float(max_x) * CS + HALF - j_margin
		var flare_w := 1.18

		var sh_poly: Array[Vector3] = [
			Vector3(tx0 - j_margin, 0.021, top_z),
			Vector3(tx0 - flare_w - j_margin, 0.021, 11.48),
			Vector3(tx1 + flare_w + j_margin, 0.021, 11.48),
			Vector3(tx1 + j_margin, 0.021, top_z),
		]
		kit.add_ground_poly(sh_poly, j_sh)

		var sf_poly: Array[Vector3] = [
			Vector3(tx0, y_sf, top_z),
			Vector3(tx0 - flare_w, y_sf, bot_z),
			Vector3(tx1 + flare_w, y_sf, bot_z),
			Vector3(tx1, y_sf, top_z),
		]
		kit.add_ground_poly(sf_poly, j_sf)

		if best_tier == GameCatalog.RoadTier.PAVED and max_x > min_x:
			var jcx := float(min_x + max_x) * 0.5 * CS
			kit.add_ground_rect(jcx, 0.042, top_z + 0.28, 0.11, 0.45, DesertPalette.ROAD_YELLOW)

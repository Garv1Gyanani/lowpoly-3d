class_name DesertTerrainBuilder
extends RefCounted

## Sculpted Monument Valley desert terrain, Route 163 highway, distant Mitten Buttes
## & plateaus, south-shoulder telephone poles + sagging wires, deterministic flora
## scatter (with O(1) occupancy clearing), street lamps, clouds & welcome billboard.

static var _scatter_cache: Array = []


static func height_at(x: float, z: float) -> float:
	var flat_x := maxf(0.0, absf(x) - 72.0)
	var flat_z := (-124.0 - z) if z < -124.0 else ((z - 24.0) if z > 24.0 else 0.0)
	var radial := sqrt(flat_x * flat_x + flat_z * flat_z)
	if radial <= 0.001:
		return 0.0
	var blend := clampf(radial / 40.0, 0.0, 1.0)
	var smooth := blend * blend * (3.0 - 2.0 * blend)
	var w1 := sin(x * 0.045 + z * 0.035) * 2.3
	var w2 := cos(x * 0.08 - z * 0.055) * 1.3
	var far_rise := clampf((-160.0 - z) * 0.06, 0.0, 6.0) if z < -160.0 else 0.0
	var side_rise := clampf((absf(x) - 110.0) * 0.05, 0.0, 6.0) if absf(x) > 110.0 else 0.0
	return maxf(0.0, (w1 + w2 + 1.9 + far_rise + side_rise) * smooth)


static func build_backdrop_node() -> Node3D:
	var kit := MeshKit.new()
	_build_terrain(kit)
	_build_highway(kit)
	_build_monument_mesas(kit)
	_build_telephone_poles(kit)
	return kit.build_node("WorldBackdrop", true)


static func _build_terrain(kit: MeshKit) -> void:
	var xs: Array[float] = [-340, -260, -200, -150, -110, -90, -72, -48, -24, 0, 24, 48, 72, 90, 110, 150, 200, 260, 340]
	var zs: Array[float] = [-380, -300, -240, -190, -160, -140, -124, -96, -64, -40, -16, 4, 16, 24, 40, 70, 110]
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
			var avg_x := (v00.x + v10.x) * 0.5
			var avg_z := (v00.z + v11.z) * 0.5
			var avg_y := (v00.y + v10.y + v11.y + v01.y) * 0.25
			var earth_mix := clampf(avg_y / 6.0, 0.0, 1.0)
			var far_mix := clampf((-124.0 - avg_z) / 160.0, 0.0, 0.55) if avg_z < -124.0 else 0.0
			var ripple := 0.045 * (0.5 + 0.5 * sin(avg_x * 0.11 + avg_z * 0.13))
			var facet_tint := (0.0 if (r + c) % 2 == 0 else 0.055) + ripple
			var col := DesertPalette.SAND.lerp(Color("d68d5b"), clampf(earth_mix * 0.65 + far_mix * 0.55, 0.0, 0.85))
			col = col.lerp(DesertPalette.SAND_DARK, clampf(facet_tint, 0.0, 0.16))
			if (r + c) % 2 == 0:
				kit.add_tri(v00, v01, v11, col)
				kit.add_tri(v00, v11, v10, col)
			else:
				kit.add_tri(v00, v01, v10, col)
				kit.add_tri(v10, v01, v11, col)

	var washes := [
		[Vector3(-48, 0.015, -70), Vector3(-40, 0.015, -64), Vector3(-22, 0.015, -68), Vector3(-28, 0.015, -74)],
		[Vector3(-28, 0.015, -74), Vector3(-22, 0.015, -68), Vector3(2, 0.015, -72), Vector3(-2, 0.015, -78)],
		[Vector3(24, 0.015, -6), Vector3(34, 0.015, -2), Vector3(48, 0.015, -10), Vector3(40, 0.015, -14)],
		[Vector3(30, 0.015, -96), Vector3(44, 0.015, -90), Vector3(58, 0.015, -98), Vector3(46, 0.015, -104)],
	]
	for wp in washes:
		var typed: Array[Vector3] = [wp[0], wp[1], wp[2], wp[3]]
		kit.add_ground_poly(typed, DesertPalette.ARROYO_SAND)


static func _build_highway(kit: MeshKit) -> void:
	var hz := OutpostLayout.HIGHWAY_CENTER_Z
	# Single continuous non-overlapping highway layers (zero seam Z-fighting!)
	kit.add_ground_rect(0.0, 0.016, hz, 480.0, 4.9, DesertPalette.ASPHALT_SHOULDER)
	kit.add_ground_rect(0.0, 0.028, hz, 480.0, 3.85, DesertPalette.ASPHALT)
	kit.add_ground_rect(0.0, 0.038, hz - 1.70, 480.0, 0.11, DesertPalette.ROAD_WHITE)
	kit.add_ground_rect(0.0, 0.038, hz + 1.70, 480.0, 0.11, DesertPalette.ROAD_WHITE)
	var dx := -150.0
	while dx <= 150.0:
		kit.add_ground_rect(dx, 0.042, hz, 1.5, 0.13, DesertPalette.ROAD_YELLOW)
		dx += 3.2


static func _build_monument_mesas(kit: MeshKit) -> void:
	_build_mitten_butte(kit, -62.0, -205.0, 2.7, 1, true, true, false)
	_build_flat_plateau(kit, -165.0, -235.0, 38.0, 22.0, 34.0, 2)
	_build_flat_plateau(kit, 10.0, -275.0, 40.0, 20.0, 30.0, 3)
	_build_mitten_butte(kit, 60.0, -228.0, 2.0, 4, false, false, true)
	_build_mitten_butte(kit, 118.0, -192.0, 2.45, 5, false, false, false)

	var outcrops := [
		[-96.0, -70.0, 9.0, 6.5, 6.0, 6],
		[94.0, -52.0, 9.5, 6.8, 6.6, 7],
		[-100.0, -5.0, 7.6, 5.8, 5.0, 8],
		[98.0, 2.0, 8.0, 6.0, 5.4, 9],
		[-30.0, -150.0, 8.4, 6.0, 5.6, 10],
		[36.0, -146.0, 7.8, 5.6, 5.2, 11],
	]
	for o in outcrops:
		var gy := height_at(o[0], o[1])
		kit.add_frustum(o[0], gy - 0.35, o[1], o[2], o[3], o[2] * 0.62, o[3] * 0.62, o[4], 6, DesertPalette.SANDSTONE, DesertPalette.TERRACOTTA, 0.0, 0.16, o[5])


static func _build_mitten_butte(kit: MeshKit, cx: float, cz: float, s: float, seed_val: int, left_but: bool, right_thumb: bool, left_thumb: bool) -> void:
	var base_y := height_at(cx, cz) - 0.6
	var talus := Color("b85b3c")
	var cliff := Color("bc5838")
	var rib := Color("a24531")
	var cap := Color("d67346")
	kit.add_frustum(cx, base_y, cz, 11.2 * s, 8.5 * s, 6.4 * s, 4.9 * s, 4.8 * s, 10, talus, cliff, 0.0, 0.14, seed_val)
	kit.add_frustum(cx, base_y + 4.5 * s, cz, 6.3 * s, 4.9 * s, 5.2 * s, 4.0 * s, 2.0 * s, 9, rib, cliff, 0.0, 0.12, seed_val + 10)
	kit.add_frustum(cx, base_y + 6.2 * s, cz, 5.0 * s, 3.8 * s, 4.7 * s, 3.6 * s, 4.5 * s, 9, cliff, cap, 0.0, 0.15, seed_val + 20)
	kit.add_frustum(cx, base_y + 10.6 * s, cz, 4.8 * s, 3.7 * s, 4.6 * s, 3.5 * s, 1.2 * s, 9, cap, cap, 0.0, 0.14, seed_val + 22)
	kit.add_frustum(cx, base_y + 11.7 * s, cz, 4.6 * s, 3.5 * s, 4.3 * s, 3.3 * s, 3.8 * s, 9, cliff, cap, 0.0, 0.15, seed_val + 24)
	kit.add_frustum(cx - 2.3 * s, base_y + 5.8 * s, cz + 1.9 * s, 2.1 * s, 1.7 * s, 1.7 * s, 1.4 * s, 8.6 * s, 6, rib, cap, 0.0, 0.10, seed_val + 30)
	kit.add_frustum(cx + 2.1 * s, base_y + 5.8 * s, cz + 2.0 * s, 2.2 * s, 1.8 * s, 1.8 * s, 1.5 * s, 8.9 * s, 6, cap, DesertPalette.TERRACOTTA, 0.0, 0.10, seed_val + 40)
	kit.add_frustum(cx, base_y + 15.3 * s, cz, 4.2 * s, 3.2 * s, 3.5 * s, 2.7 * s, 1.6 * s, 8, cap, DesertPalette.TERRACOTTA, 0.0, 0.08, seed_val + 50)
	if left_but:
		kit.add_frustum(cx - 6.0 * s, base_y + 3.4 * s, cz + 0.5 * s, 1.55 * s, 1.45 * s, 1.05 * s, 1.0 * s, 9.4 * s, 6, rib, cap, 0.0, 0.09, seed_val + 60)
	if right_thumb:
		kit.add_frustum(cx + 6.4 * s, base_y + 3.2 * s, cz + 1.0 * s, 1.45 * s, 1.35 * s, 0.72 * s, 0.70 * s, 9.6 * s, 6, cap, DesertPalette.TERRACOTTA, 0.0, 0.08, seed_val + 70)
	if left_thumb:
		kit.add_frustum(cx - 6.0 * s, base_y + 3.0 * s, cz + 0.8 * s, 1.35 * s, 1.25 * s, 0.65 * s, 0.65 * s, 8.6 * s, 6, cliff, cap, 0.0, 0.08, seed_val + 80)


static func _build_flat_plateau(kit: MeshKit, cx: float, cz: float, rx: float, rz: float, h: float, seed_val: int) -> void:
	var base_y := height_at(cx, cz) - 0.6
	var skirt_h := h * 0.42
	kit.add_frustum(cx, base_y, cz, rx, rz, rx * 0.72, rz * 0.72, skirt_h, 8, Color("b56652"), DesertPalette.SANDSTONE, 0.0, 0.12, seed_val)
	kit.add_frustum(cx, base_y + skirt_h - 0.2, cz, rx * 0.70, rz * 0.70, rx * 0.62, rz * 0.62, h * 0.58, 8, DesertPalette.SANDSTONE, DesertPalette.TERRACOTTA, 0.0, 0.10, seed_val + 15)


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
	var kit := MeshKit.new()
	var puffs := [
		[Vector3(30.0, 62.0, -250.0), 13.0, 4.0, 6.8, 7],
		[Vector3(46.0, 65.0, -252.0), 15.0, 6.0, 7.6, 7],
		[Vector3(64.0, 68.0, -255.0), 17.0, 8.4, 8.6, 7],
		[Vector3(82.0, 65.0, -254.0), 15.0, 6.6, 7.8, 7],
		[Vector3(-70.0, 63.0, -262.0), 14.0, 4.2, 6.6, 6],
		[Vector3(-54.0, 65.0, -264.0), 12.5, 5.0, 6.0, 6],
		[Vector3(-140.0, 58.0, -230.0), 13.0, 4.4, 6.4, 6],
		[Vector3(150.0, 60.0, -220.0), 12.0, 4.0, 6.0, 6],
	]
	for p in puffs:
		var pos: Vector3 = p[0]
		kit.add_frustum(pos.x, pos.y, pos.z, p[1], p[3], p[1] * 0.66, p[3] * 0.66, p[2], p[4], DesertPalette.CLOUD_SUNLIT, DesertPalette.CLOUD_SUNLIT)
	return kit.build_node("SkyClouds", false)


static func _get_scatter() -> Array:
	if not _scatter_cache.is_empty():
		return _scatter_cache
	var seed_val := 1640531527
	var guard := 0
	while _scatter_cache.size() < 150 and guard < 1000:
		guard += 1
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var x := -112.0 + (float(seed_val) / float(0x7fffffff)) * 224.0
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var z := -150.0 + (float(seed_val) / float(0x7fffffff)) * 192.0
		if z > 6.5 and z < 20.5:
			continue
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var roll := float(seed_val) / float(0x7fffffff)
		var kind := 0 if roll < 0.34 else (1 if roll < 0.62 else 2)
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var sc := 0.75 + (float(seed_val) / float(0x7fffffff)) * 0.65
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
	kit.add_box(0.40 * s, 1.70 * s, 0, 0.11 * s, 0.08 * s, 0.11 * s, DesertPalette.CREAM)
	kit.add_box(-0.28 * s, 0.64 * s, 0, 0.30 * s, 0.19 * s, 0.19 * s, DesertPalette.VEGETATION)
	kit.add_box(-0.36 * s, 0.80 * s, 0, 0.19 * s, 0.52 * s, 0.19 * s, DesertPalette.VEGETATION)
	kit.pop_tx()


static func add_bush(kit: MeshKit, pos: Vector3, radius: float, phase: float) -> void:
	kit.add_frustum(pos.x, pos.y, pos.z, radius * 0.90, radius * 0.84, radius * 0.54, radius * 0.48, radius * 0.70, 6, DesertPalette.VEGETATION, Color("8c946a"), phase)
	kit.add_frustum(pos.x + radius * 0.36, pos.y, pos.z + radius * 0.18, radius * 0.50, radius * 0.46, radius * 0.24, radius * 0.24, radius * 0.46, 5, DesertPalette.VEGETATION_DARK, DesertPalette.VEGETATION, phase + 0.6)


static func add_rock(kit: MeshKit, pos: Vector3, radius: float, h: float, phase: float) -> void:
	kit.add_frustum(pos.x, pos.y, pos.z, radius, radius * 0.78, radius * 0.56, radius * 0.44, h, 6, DesertPalette.TERRACOTTA, DesertPalette.SANDSTONE_LIGHT, phase)
	kit.add_frustum(pos.x + radius * 0.68, pos.y, pos.z + radius * 0.32, radius * 0.46, radius * 0.40, radius * 0.24, radius * 0.22, h * 0.48, 5, DesertPalette.SANDSTONE, DesertPalette.TERRACOTTA, phase + 1.1)


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
	# Deterministic flora scatter (auto-cleared under roads/lots/buildings)
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
			add_rock(kit, Vector3(x, gy - 0.08, z), 0.7 + sc * 0.6, 0.45 + sc * 0.35, rot)
		else:
			add_bush(kit, Vector3(x, gy, z), 0.38 + sc * 0.22, rot)

	if state.outpost_stage() >= 5:
		add_welcome_sign(kit, Vector3(-18.0, 0.0, 19.2), PI - 0.2)

	_add_parcel_trait_markers(kit, state)
	return kit.build_node("OutpostStatic", true)


static func _add_parcel_trait_markers(kit: MeshKit, state) -> void:
	# Subtle low-poly environmental clues on Oil Seep, Aquifer, and Wind Corridor parcels
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
				# Dark crude oil pool + sandstone rim
				kit.add_frustum(c.x, 0.015, c.z, 2.35, 1.95, 2.15, 1.75, 0.05, 8, Color("242029"), Color("332c3a"), 0.2)
				kit.add_frustum(c.x + 1.4, 0.01, c.z - 1.0, 0.85, 0.72, 0.55, 0.45, 0.55, 6, DesertPalette.SANDSTONE_DARK, DesertPalette.SANDSTONE, 0.7)
				kit.add_frustum(c.x - 1.5, 0.01, c.z + 0.9, 0.65, 0.58, 0.38, 0.32, 0.40, 5, DesertPalette.SANDSTONE_DARK, DesertPalette.TERRACOTTA, 1.4)
			elif tr_id == GameCatalog.ParcelTrait.AQUIFER:
				# Shallow desert spring pool + lush reeds
				kit.add_frustum(c.x, 0.014, c.z, 2.55, 1.95, 2.35, 1.75, 0.04, 8, DesertPalette.ARROYO_DARK, DesertPalette.ARROYO_SAND, 0.4)
				kit.add_frustum(c.x, 0.025, c.z, 1.65, 1.25, 1.55, 1.15, 0.04, 8, DesertPalette.WATER, Color("76cad6"), 0.4)
				add_bush(kit, Vector3(c.x + 1.85, 0.0, c.z + 0.5), 0.55, 0.3)
				add_bush(kit, Vector3(c.x - 1.75, 0.0, c.z - 0.65), 0.48, 1.1)
			elif tr_id == GameCatalog.ParcelTrait.WIND_CORRIDOR:
				# Wind-swept sandstone cairn + wooden wind-sock post
				add_rock(kit, Vector3(c.x - 0.8, -0.05, c.z), 0.75, 0.55, 0.5)
				kit.add_box(c.x + 0.9, 0.0, c.z, 0.12, 2.1, 0.12, DesertPalette.WOOD_DARK)
				kit.add_box(c.x + 1.38, 1.85, c.z, 0.82, 0.24, 0.08, DesertPalette.TURQUOISE)


static func _collect_lot_driveway_edges(parking_lots: Array) -> Dictionary:
	# Maps "gx,gz,side_char" -> true where a connected parking lot's apron opens onto that road tile
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
			sh_col = Color("cfa977")
			sf_col = Color("b28b59") if conn else Color("a38868")
			margin = 0.24
		elif tier == GameCatalog.RoadTier.GRAVEL:
			sh_col = Color("b0a18e")
			sf_col = Color("867b6f") if conn else Color("7c746b")
			margin = 0.18
		else:
			sh_col = DesertPalette.ASPHALT_SHOULDER
			sf_col = DesertPalette.ASPHALT if conn else Color("5e5955")
			margin = 0.20

		# 1. Full-tile base shoulder (y = 0.018)
		kit.add_ground_rect(c.x, 0.018, c.z, CS, CS, sh_col)

		# 2. Seamless merged road surface (y = 0.030): extends flush to shared road/driveway edges (zero gaps!)
		var x0 := c.x - HALF + (0.0 if open_w else margin)
		var x1 := c.x + HALF - (0.0 if open_e else margin)
		var z0 := c.z - HALF + (0.0 if open_n else margin)
		var z1 := c.z + HALF - (0.0 if open_s else margin)
		kit.add_ground_rect((x0 + x1) * 0.5, 0.030, (z0 + z1) * 0.5, x1 - x0, z1 - z0, sf_col)

		# 3. Inner 90-degree corner shoulder fillets so turns look smoothly radiused
		var fil := margin * 1.45
		if has_n and has_w and not has_nw:
			kit.add_tri(Vector3(c.x - HALF, 0.033, c.z - HALF), Vector3(c.x - HALF, 0.033, c.z - HALF + fil), Vector3(c.x - HALF + fil, 0.033, c.z - HALF), sh_col)
		if has_n and has_e and not has_ne:
			kit.add_tri(Vector3(c.x + HALF - fil, 0.033, c.z - HALF), Vector3(c.x + HALF, 0.033, c.z - HALF + fil), Vector3(c.x + HALF, 0.033, c.z - HALF), sh_col)
		if has_s and has_w and not has_sw:
			kit.add_tri(Vector3(c.x - HALF, 0.033, c.z + HALF - fil), Vector3(c.x - HALF, 0.033, c.z + HALF), Vector3(c.x - HALF + fil, 0.033, c.z + HALF), sh_col)
		if has_s and has_e and not has_se:
			kit.add_tri(Vector3(c.x + HALF, 0.033, c.z + HALF - fil), Vector3(c.x + HALF - fil, 0.033, c.z + HALF), Vector3(c.x + HALF, 0.033, c.z + HALF), sh_col)

		# 4. Detect exact 2-lane straight corridor vs intersection geometry
		var is_ns_west := has_e and not has_w and (has_n or has_s) and not road_net.has_road(Vector2i(cell.x + 2, cell.y))
		var is_ns_east := has_w and not has_e and (has_n or has_s) and not road_net.has_road(Vector2i(cell.x - 2, cell.y))
		var is_ew_north := has_s and not has_n and (has_w or has_e) and not road_net.has_road(Vector2i(cell.x, cell.y + 2))
		var is_ew_south := has_n and not has_s and (has_w or has_e) and not road_net.has_road(Vector2i(cell.x, cell.y - 2))
		var is_single_ns := (has_n or has_s) and not has_w and not has_e
		var is_single_ew := (has_w or has_e) and not has_n and not has_s

		# True straight 2-lane corridor seam (suppressed cleanly inside intersections & outer turn caps)
		var straight_ns_seam := is_ns_west and has_n and has_s and has_ne and has_se
		var straight_ew_seam := is_ew_north and has_w and has_e and has_sw and has_se

		# 5. Tier-specific surface details, curbs & lane lines
		if tier == GameCatalog.RoadTier.DIRT:
			# Subtle warm wheel-rut tracks down each lane (authentic desert two-track!)
			var rut_col := Color("9a7446") if conn else Color("8c7457")
			if is_ns_west or is_ns_east or is_single_ns:
				var lane_cx := c.x + (0.06 if is_ns_west else (-0.06 if is_ns_east else 0.0))
				kit.add_ground_rect(lane_cx - 0.34, 0.036, c.z, 0.20, CS - 0.12, rut_col)
				kit.add_ground_rect(lane_cx + 0.34, 0.036, c.z, 0.20, CS - 0.12, rut_col)
			elif is_ew_north or is_ew_south or is_single_ew:
				var lane_cz := c.z + (0.06 if is_ew_north else (-0.06 if is_ew_south else 0.0))
				kit.add_ground_rect(c.x, 0.036, lane_cz - 0.34, CS - 0.12, 0.20, rut_col)
				kit.add_ground_rect(c.x, 0.036, lane_cz + 0.34, CS - 0.12, 0.20, rut_col)
			# Small wooden trail guideposts on outer corners
			if not open_w and not open_n and (has_e or has_s):
				kit.add_box(c.x - HALF + 0.12, 0.0, c.z - HALF + 0.12, 0.11, 0.56, 0.11, DesertPalette.WOOD_DARK)
			if not open_e and not open_n and (has_w or has_s):
				kit.add_box(c.x + HALF - 0.12, 0.0, c.z - HALF + 0.12, 0.11, 0.56, 0.11, DesertPalette.WOOD_DARK)

		elif tier == GameCatalog.RoadTier.GRAVEL:
			# Subtle lighter compacted gravel crown along 2-lane seam + crisp edge stones
			var crown_col := Color("a29688")
			var edge_col := Color("c2b7a8")
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
			# PAVED ASPHALT: raised concrete curbs, white fog lines, yellow dashed 2-lane centerlines & streetlamps
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

			# Yellow dashed center divider right down the 2-lane seam (emitted once by west/north tile)
			if straight_ns_seam:
				kit.add_ground_rect(c.x + HALF, 0.042, c.z, 0.11, 1.12, DesertPalette.ROAD_YELLOW)
			elif straight_ew_seam:
				kit.add_ground_rect(c.x, 0.042, c.z + HALF, 1.12, 0.11, DesertPalette.ROAD_YELLOW)
			elif is_single_ns:
				kit.add_ground_rect(c.x, 0.042, c.z, 0.09, 0.92, DesertPalette.ROAD_YELLOW)
			elif is_single_ew:
				kit.add_ground_rect(c.x, 0.042, c.z, 0.92, 0.09, DesertPalette.ROAD_YELLOW)

			# Stop bar at Route 163 southbound exit lane
			if cell.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z and is_ns_west:
				kit.add_ground_rect(c.x + 0.05, 0.043, c.z + 0.65, 1.45, 0.16, DesertPalette.ROAD_WHITE)

			# Outer-curb streetlamps every 4 cells along paved roads (never blocking driveways)
			if not open_n and (has_w or has_e) and posmod(cell.x, 4) == 0:
				add_street_lamp(kit, Vector3(c.x, 0.0, c.z - HALF + 0.10))
			elif not open_w and (has_n or has_s) and posmod(cell.y, 4) == 0:
				add_street_lamp(kit, Vector3(c.x - HALF + 0.10, 0.0, c.z))

	# 6. Wide flared Route 163 highway bellmouth junctions (grouped by contiguous entry span)
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
		var j_sh := Color("cfa977") if best_tier == GameCatalog.RoadTier.DIRT else (Color("b0a18e") if best_tier == GameCatalog.RoadTier.GRAVEL else DesertPalette.ASPHALT_SHOULDER)
		var j_sf := Color("b28b59") if best_tier == GameCatalog.RoadTier.DIRT else (Color("867b6f") if best_tier == GameCatalog.RoadTier.GRAVEL else DesertPalette.ASPHALT)

		var top_z := float(OutpostLayout.HIGHWAY_ENTRY_ROW_Z) * CS + HALF # 11.0
		var bot_z := 11.82 if best_tier == GameCatalog.RoadTier.PAVED else 11.54
		var y_sf := 0.0395 if best_tier == GameCatalog.RoadTier.PAVED else 0.032
		var tx0 := float(min_x) * CS - HALF + j_margin
		var tx1 := float(max_x) * CS + HALF - j_margin
		var flare_w := 1.18

		# Shoulder flare
		var sh_poly: Array[Vector3] = [
			Vector3(tx0 - j_margin, 0.021, top_z),
			Vector3(tx0 - flare_w - j_margin, 0.021, 11.48),
			Vector3(tx1 + flare_w + j_margin, 0.021, 11.48),
			Vector3(tx1 + j_margin, 0.021, top_z),
		]
		kit.add_ground_poly(sh_poly, j_sh)

		# Road surface bellmouth (for PAVED, cleanly bridges & interrupts Route 163 north white fog line!)
		var sf_poly: Array[Vector3] = [
			Vector3(tx0, y_sf, top_z),
			Vector3(tx0 - flare_w, y_sf, bot_z),
			Vector3(tx1 + flare_w, y_sf, bot_z),
			Vector3(tx1, y_sf, top_z),
		]
		kit.add_ground_poly(sf_poly, j_sf)

		# Yellow center dash extending into paved junction throat
		if best_tier == GameCatalog.RoadTier.PAVED and max_x > min_x:
			var jcx := float(min_x + max_x) * 0.5 * CS
			kit.add_ground_rect(jcx, 0.042, top_z + 0.28, 0.11, 0.45, DesertPalette.ROAD_YELLOW)

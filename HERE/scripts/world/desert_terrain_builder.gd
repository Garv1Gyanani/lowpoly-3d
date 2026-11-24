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
	_build_roads(kit, state.road_network)
	for lot in state.parking_lots:
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

	return kit.build_node("OutpostStatic", true)


static func _build_roads(kit: MeshKit, road_net: RoadNetwork) -> void:
	const CS := OutpostLayout.GRID_CELL_SIZE
	for cell: Vector2i in road_net.tiles.keys():
		var tier: int = road_net.tiles[cell]
		var c := OutpostLayout.cell_center_v(cell)
		var conn := road_net.is_connected_to_highway(cell)
		var has_n := road_net.has_road(Vector2i(cell.x, cell.y - 1))
		var has_s := road_net.has_road(Vector2i(cell.x, cell.y + 1)) or cell.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z
		var has_w := road_net.has_road(Vector2i(cell.x - 1, cell.y))
		var has_e := road_net.has_road(Vector2i(cell.x + 1, cell.y))

		var sh_col: Color
		var sf_col: Color
		var st_col := Color(-1, 0, 0)
		if tier == GameCatalog.RoadTier.DIRT:
			sh_col = Color("c5a172")
			sf_col = Color("a88356") if conn else Color("9c8468")
		elif tier == GameCatalog.RoadTier.GRAVEL:
			sh_col = Color("a99b89")
			sf_col = Color("83786c") if conn else Color("7b736a")
			st_col = Color("b8aea0")
		else:
			sh_col = DesertPalette.ASPHALT_SHOULDER
			sf_col = Color("5d5650") if conn else Color("6b655f")
			st_col = DesertPalette.ROAD_YELLOW

		# Exact non-overlapping road geometry: shoulder (y=0.020), center + edge connector tabs (y=0.032), stripes (y=0.044)
		var rw := 1.56 if tier == GameCatalog.RoadTier.DIRT else 1.72
		var arm_len := (CS - rw) * 0.5
		var arm_off := rw * 0.5 + arm_len * 0.5
		kit.add_ground_rect(c.x, 0.020, c.z, CS, CS, sh_col)
		kit.add_ground_rect(c.x, 0.032, c.z, rw, rw, sf_col)
		if has_n:
			kit.add_ground_rect(c.x, 0.032, c.z - arm_off, rw, arm_len, sf_col)
		if has_s:
			kit.add_ground_rect(c.x, 0.032, c.z + arm_off, rw, arm_len, sf_col)
		if has_w:
			kit.add_ground_rect(c.x - arm_off, 0.032, c.z, arm_len, rw, sf_col)
		if has_e:
			kit.add_ground_rect(c.x + arm_off, 0.032, c.z, arm_len, rw, sf_col)

		if cell.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z:
			var htw := rw * 0.5
			var hbw := (rw + 1.45) * 0.5
			var flare: Array[Vector3] = [
				Vector3(c.x - htw, 0.031, c.z + CS * 0.5),
				Vector3(c.x - hbw, 0.031, 11.48),
				Vector3(c.x + hbw, 0.031, 11.48),
				Vector3(c.x + htw, 0.031, c.z + CS * 0.5),
			]
			kit.add_ground_poly(flare, sf_col)

		if st_col.r >= 0.0:
			if (has_w or has_e) and not (has_n and has_s):
				kit.add_ground_rect(c.x, 0.044, c.z, 0.78, 0.10, st_col)
			if (has_n or has_s) and not (has_w and has_e):
				kit.add_ground_rect(c.x, 0.044, c.z, 0.10, 0.78, st_col)

		if tier == GameCatalog.RoadTier.PAVED and ((cell.x + cell.y) % 3 == 0) and not has_n and (has_w or has_e):
			add_street_lamp(kit, Vector3(c.x, 0.0, c.z - 0.96))

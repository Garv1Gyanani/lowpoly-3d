class_name BuildingBuilder
extends RefCounted

## All 8 Desert Outpost modular buildings (Lv1-Lv5), 3 Parking Lot archetypes,
## and 5 Decorations — built procedurally with MeshKit for zero-flicker GPU rendering.


static func build_plot_node(btype: int, level: int, anim_time: float = 0.0, material_override: Material = null) -> Node3D:
	var kit := MeshKit.new()
	match btype:
		GameCatalog.BusinessType.VENDOR_STALL:
			if level <= 1:
				_build_vendor_cart(kit, anim_time)
			else:
				_build_vendor_stall(kit, level, anim_time)
		GameCatalog.BusinessType.CONVENIENCE_STORE:
			_build_outpost_mart(kit, level, anim_time)
		GameCatalog.BusinessType.FOOD_STAND:
			_build_food_stand(kit, level, anim_time)
		GameCatalog.BusinessType.DESERT_DINER:
			_build_desert_diner(kit, level, anim_time)
		GameCatalog.BusinessType.GAS_STATION:
			_build_gas_station(kit, level, anim_time)
		GameCatalog.BusinessType.OASIS_PLAZA:
			_build_oasis_plaza(kit, level, anim_time)
		GameCatalog.BusinessType.DESERT_MOTEL:
			_build_desert_motel(kit, level)
		GameCatalog.BusinessType.LOOKOUT_CAMP:
			_build_lookout_camp(kit, level, anim_time)
	return kit.build_node("Building_%d_Lv%d" % [btype, level], material_override == null, material_override)


static func build_decoration_node(kind: int, anim_time: float = 0.0, material_override: Material = null) -> Node3D:
	var kit := MeshKit.new()
	match kind:
		GameCatalog.DecorationKind.SAGUARO_CLUSTER:
			DesertTerrainBuilder.add_saguaro(kit, Vector3.ZERO, 1.05, 0.5)
			DesertTerrainBuilder.add_bush(kit, Vector3(0.6, 0.0, 0.3), 0.45, 0.4)
		GameCatalog.DecorationKind.WOODEN_SIGNPOST:
			kit.push_tx(Vector3.ZERO, 0.18)
			kit.add_box(0, 0, 0, 0.15, 2.0, 0.15, DesertPalette.WOOD_DARK)
			kit.add_box(0.38, 1.55, 0, 0.95, 0.26, 0.09, DesertPalette.CREAM)
			kit.add_box(-0.34, 1.18, 0, 0.85, 0.24, 0.09, DesertPalette.TERRACOTTA)
			kit.pop_tx()
		GameCatalog.DecorationKind.PICNIC_SET:
			kit.push_tx(Vector3.ZERO, 0.08)
			kit.add_box(0, 0, 0, 1.15, 0.58, 0.72, DesertPalette.WOOD_LIGHT)
			kit.add_box(0, 0, -0.58, 1.05, 0.34, 0.28, DesertPalette.WOOD)
			kit.add_box(0, 0, 0.58, 1.05, 0.34, 0.28, DesertPalette.WOOD)
			kit.pop_tx()
		GameCatalog.DecorationKind.DESERT_LAMP:
			kit.add_box(0, 0, 0, 0.14, 2.4, 0.14, DesertPalette.WOOD_DARK)
			kit.add_box(0, 2.4, 0, 0.32, 0.34, 0.32, DesertPalette.CREAM, Color(-1, 0, 0), 1)
		GameCatalog.DecorationKind.CAMPFIRE_RING:
			kit.add_frustum(0, 0, 0, 0.56, 0.56, 0.48, 0.48, 0.20, 7, DesertPalette.METAL)
			var flick := 0.75 + sin(anim_time * 9.0) * 0.2
			kit.add_frustum(0, 0.16, 0, 0.28, 0.28, 0.05, 0.05, 0.58 * flick, 5, Color("ff8c32"), Color("ffc14d"), 0.0, 0.0, 1, 2)
	return kit.build_node("Deco_%d" % kind, material_override == null, material_override)


static func build_parking_ghost_node(kind: int, rot: int, valid: bool) -> Node3D:
	var kit := MeshKit.new()
	var fake_lot := {
		"kind": kind,
		"grid_x": 0,
		"grid_z": 0,
		"rot": rot,
		"is_connected": false,
		"connected_side": -1,
	}
	var spec: Dictionary = GameCatalog.PARKING_LOTS[kind]
	var sz := OutpostLayout.rotated_size(spec["grid_w"], spec["grid_d"], rot)
	var center := OutpostLayout.footprint_center(0, 0, sz.x, sz.y)
	kit.push_tx(-center, 0.0)
	add_parking_lot(kit, fake_lot, true)
	kit.pop_tx()
	return kit.build_node("ParkingGhost", false, DesertPalette.get_ghost_material(valid))


static func lot_effective_side(lot: Dictionary) -> int:
	var cs: int = lot.get("connected_side", -1)
	if cs >= 0:
		return cs
	match int(lot["rot"]) & 3:
		0: return GameCatalog.LotEntrySide.SOUTH
		1: return GameCatalog.LotEntrySide.WEST
		2: return GameCatalog.LotEntrySide.NORTH
		_: return GameCatalog.LotEntrySide.EAST


static func lot_pull_in_dir(side: int) -> Vector3:
	match side:
		GameCatalog.LotEntrySide.SOUTH: return Vector3(0, 0, -1)
		GameCatalog.LotEntrySide.NORTH: return Vector3(0, 0, 1)
		GameCatalog.LotEntrySide.EAST: return Vector3(-1, 0, 0)
		_: return Vector3(1, 0, 0)


static func lot_bay_row_axis(side: int) -> Vector3:
	match side:
		GameCatalog.LotEntrySide.SOUTH: return Vector3(1, 0, 0)
		GameCatalog.LotEntrySide.NORTH: return Vector3(-1, 0, 0)
		GameCatalog.LotEntrySide.EAST: return Vector3(0, 0, -1)
		_: return Vector3(0, 0, 1)


static func lot_parked_yaw(side: int) -> float:
	match side:
		GameCatalog.LotEntrySide.SOUTH: return -PI * 0.5
		GameCatalog.LotEntrySide.NORTH: return PI * 0.5
		GameCatalog.LotEntrySide.EAST: return PI
		_: return 0.0


static func lot_oriented_dims(lot: Dictionary) -> Vector2:
	var spec: Dictionary = GameCatalog.PARKING_LOTS[lot["kind"]]
	var sz := OutpostLayout.rotated_size(spec["grid_w"], spec["grid_d"], lot["rot"])
	var ww := float(sz.x) * OutpostLayout.GRID_CELL_SIZE
	var wd := float(sz.y) * OutpostLayout.GRID_CELL_SIZE
	var side := lot_effective_side(lot)
	if side == GameCatalog.LotEntrySide.SOUTH or side == GameCatalog.LotEntrySide.NORTH:
		return Vector2(ww, wd)
	return Vector2(wd, ww)


static func add_parking_lot(kit: MeshKit, lot: Dictionary, is_ghost: bool = false) -> void:
	var kind: int = lot["kind"]
	var spec: Dictionary = GameCatalog.PARKING_LOTS[kind]
	var sz := OutpostLayout.rotated_size(spec["grid_w"], spec["grid_d"], lot["rot"])
	var ww := float(sz.x) * OutpostLayout.GRID_CELL_SIZE - 0.14
	var wd := float(sz.y) * OutpostLayout.GRID_CELL_SIZE - 0.14
	var c := OutpostLayout.footprint_center(lot["grid_x"], lot["grid_z"], sz.x, sz.y)

	var base_col := Color("b89668") if kind == GameCatalog.ParkingLotKind.DIRT_PULL_OFF else (Color("8c7e70") if kind == GameCatalog.ParkingLotKind.GRAVEL_LOT else Color("5d5650"))
	var border_col := Color("9e7c52") if kind == GameCatalog.ParkingLotKind.DIRT_PULL_OFF else (Color("756a5e") if kind == GameCatalog.ParkingLotKind.GRAVEL_LOT else DesertPalette.CONCRETE)

	kit.add_ground_rect(c.x, 0.022, c.z, ww + 0.18, wd + 0.18, border_col)
	kit.add_ground_rect(c.x, 0.031, c.z, ww, wd, base_col)

	var side := lot_effective_side(lot)
	var dims := lot_oriented_dims(lot)
	var span := dims.x
	var depth := dims.y
	var u := lot_bay_row_axis(side)
	var f := lot_pull_in_dir(side)
	var count: int = spec["spaces"]
	var usable_span := span - 0.36
	var bay_pitch := usable_span / float(count)

	if lot.get("is_connected", false):
		var apron := c - f * (depth * 0.5 + 0.11)
		var is_ns := side == GameCatalog.LotEntrySide.SOUTH or side == GameCatalog.LotEntrySide.NORTH
		kit.add_ground_rect(apron.x, 0.035, apron.z, span * 0.88 if is_ns else 0.24, 0.24 if is_ns else span * 0.88, base_col)

	var stop_col := DesertPalette.WOOD if kind == GameCatalog.ParkingLotKind.DIRT_PULL_OFF else DesertPalette.CONCRETE
	var stripe_col := Color("9a784e") if kind == GameCatalog.ParkingLotKind.DIRT_PULL_OFF else (Color("c9beb0") if kind == GameCatalog.ParkingLotKind.GRAVEL_LOT else Color("e5dec9"))
	var bay_yaw := lot_parked_yaw(side)
	var stop_w := clampf(bay_pitch * 0.64, 0.70, 1.15)
	for i in range(count):
		var u_off := ((float(i) + 0.5) / float(count) - 0.5) * usable_span
		var sp := c + u * u_off + f * (depth * 0.5 - 0.42)
		kit.push_tx(sp, bay_yaw)
		kit.add_box(0, 0.03, 0, 0.16, 0.12, stop_w, stop_col)
		kit.pop_tx()

	if not is_ghost:
		var stripe_len := depth * 0.72
		var is_ns := side == GameCatalog.LotEntrySide.SOUTH or side == GameCatalog.LotEntrySide.NORTH
		for i in range(count + 1):
			var u_off := (float(i) / float(count) - 0.5) * usable_span
			var lc := c + u * u_off + f * (depth * 0.06)
			kit.add_ground_rect(lc.x, 0.042, lc.z, 0.08 if is_ns else stripe_len, stripe_len if is_ns else 0.08, stripe_col)
		if kind == GameCatalog.ParkingLotKind.PAVED_LOT:
			var rail := c + f * (depth * 0.5 - 0.10)
			kit.push_tx(rail, bay_yaw)
			kit.add_box(0, 0.03, 0, 0.18, 0.14, span - 0.24, DesertPalette.CONCRETE)
			kit.pop_tx()

		var corner := c - u * (span * 0.5 + 0.06) + f * (depth * 0.5 - 0.12)
		var sign_yaw := bay_yaw - PI * 0.5
		if kind == GameCatalog.ParkingLotKind.DIRT_PULL_OFF:
			kit.push_tx(corner, sign_yaw)
			kit.add_box(0, 0, 0, 0.12, 1.65, 0.12, DesertPalette.WOOD_DARK)
			kit.add_box(0, 1.08, 0, 1.18, 0.48, 0.12, DesertPalette.CREAM)
			kit.add_box(0, 1.56, 0, 1.28, 0.08, 0.18, DesertPalette.TERRACOTTA)
			kit.add_front_sign_text(0, 1.32, 0.065, 1.06, 0.38, "PARKING", DesertPalette.SANDSTONE_DARK, false)
			kit.pop_tx()
		else:
			DesertTerrainBuilder.add_street_lamp(kit, corner)
			if kind == GameCatalog.ParkingLotKind.PAVED_LOT:
				var other := c + u * (span * 0.5 + 0.06) + f * (depth * 0.5 - 0.12)
				DesertTerrainBuilder.add_street_lamp(kit, other)


# --- 1A. LEVEL 1 DRINKS CART ---
static func _build_vendor_cart(kit: MeshKit, anim_time: float) -> void:
	kit.add_ground_rect(0, 0.025, 0.15, 2.25, 1.55, DesertPalette.TERRACOTTA)
	kit.add_ground_rect(0, 0.030, 0.15, 1.80, 1.15, DesertPalette.CREAM_DARK)
	for wx in [-0.77, 0.77]:
		kit.add_box(wx, 0.0, 0.05, 0.12, 0.58, 0.58, DesertPalette.WOOD_DARK)
		var pos_x: bool = wx > 0.0
		kit.add_flush_rect_x(wx + (0.06 if pos_x else -0.06), 0.29, 0.05, 0.42, 0.42, DesertPalette.WOOD_LIGHT, pos_x)
		kit.add_flush_rect_x(wx + (0.072 if pos_x else -0.072), 0.29, 0.05, 0.16, 0.16, DesertPalette.METAL_DARK, pos_x)
	kit.add_box(-0.56, 0.0, 0.44, 0.09, 0.34, 0.09, DesertPalette.WOOD_DARK, Color(-1, 0, 0), 0, true, true)
	kit.add_box(0.56, 0.0, 0.44, 0.09, 0.34, 0.09, DesertPalette.WOOD_DARK, Color(-1, 0, 0), 0, true, true)
	kit.add_box(0, 0.34, 0.08, 1.42, 0.64, 0.90, DesertPalette.WOOD, Color(-1, 0, 0), 0, true, true)
	kit.add_box(0, 0.98, 0.08, 1.56, 0.09, 1.00, DesertPalette.CREAM)
	kit.add_box(0.965, 0.82, -0.18, 0.51, 0.08, 0.08, DesertPalette.WOOD_LIGHT)
	kit.add_box(0.965, 0.82, 0.34, 0.51, 0.08, 0.08, DesertPalette.WOOD_LIGHT)
	kit.add_box(1.26, 0.82, 0.08, 0.08, 0.08, 0.58, DesertPalette.WOOD_DARK)
	kit.add_box(-0.36, 1.07, 0.04, 0.56, 0.42, 0.48, DesertPalette.TURQUOISE, Color(-1, 0, 0), 0, true, true)
	kit.add_box(-0.36, 1.49, 0.04, 0.60, 0.07, 0.52, DesertPalette.CREAM)
	kit.add_frustum(0.18, 1.07, 0.14, 0.16, 0.16, 0.14, 0.14, 0.34, 6, DesertPalette.GOLD, DesertPalette.CREAM)
	kit.add_box(0.18, 1.41, 0.14, 0.18, 0.05, 0.18, DesertPalette.WOOD_DARK)
	kit.add_box(0.46, 1.07, 0.24, 0.10, 0.22, 0.10, DesertPalette.AWNING_RED)
	kit.add_box(0.58, 1.07, 0.24, 0.10, 0.24, 0.10, DesertPalette.WATER)
	kit.add_box(0.46, 1.07, -0.14, 0.28, 0.16, 0.22, DesertPalette.METAL_DARK)
	kit.add_flush_rect_z(0, 0.67, 0.535, 1.14, 0.44, DesertPalette.WOOD_DARK, true)
	kit.add_flush_rect_z(0, 0.67, 0.555, 1.04, 0.36, DesertPalette.CREAM, true)
	kit.add_front_sign_text(0, 0.67, 0.57, 1.00, 0.34, "DRINKS", DesertPalette.SANDSTONE_DARK, false)
	kit.add_box(-1.14, 0.0, 0.06, 0.46, 0.42, 0.44, DesertPalette.WOOD_LIGHT)
	kit.add_frustum(-1.14, 0.42, 0.06, 0.14, 0.14, 0.10, 0.10, 0.28, 6, DesertPalette.WATER)
	kit.add_box(-0.48, 1.07, -0.26, 0.08, 1.15, 0.08, DesertPalette.WOOD_DARK, Color(-1, 0, 0), 0, true, true)
	var ux := -0.48
	var uz := -0.26
	var apex := Vector3(ux, 2.62, uz)
	for i in range(6):
		var a0 := (float(i) / 6.0) * TAU
		var a1 := (float(i + 1) / 6.0) * TAU
		var p0 := Vector3(ux + cos(a0) * 1.12, 2.22, uz + sin(a0) * 1.12)
		var p1 := Vector3(ux + cos(a1) * 1.12, 2.22, uz + sin(a1) * 1.12)
		kit.add_tri(p1, p0, apex, DesertPalette.TERRACOTTA if i % 2 == 0 else DesertPalette.CREAM, true)
	kit.add_box(ux, 2.62, uz, 0.12, 0.10, 0.12, DesertPalette.WOOD_DARK)
	kit.add_box(-0.08, 2.16, -0.14, 0.04, 0.22, 0.04, DesertPalette.METAL_DARK)
	kit.add_box(-0.08, 1.96, -0.14, 0.15, 0.20, 0.15, DesertPalette.CREAM, Color(-1, 0, 0), 1)
	EntityBuilder.add_vendor_character(kit, Vector3(0.24, 0.0, -0.56), anim_time)


# --- 1B. LEVEL 2-5 VENDOR STALL ---
static func _build_vendor_stall(kit: MeshKit, level: int, anim_time: float) -> void:
	kit.add_ground_rect(0, 0.025, 1.48, 1.85, 0.58, DesertPalette.TERRACOTTA)
	kit.add_ground_rect(0, 0.030, 1.48, 1.32, 0.36, DesertPalette.CREAM)
	kit.add_box(0, 0, 0, 3.4, 0.18, 2.5, DesertPalette.WOOD_LIGHT)
	kit.add_box(0, 0.18, -0.90, 2.61, 2.05, 0.18, DesertPalette.WOOD)
	kit.add_box(0, 1.32, -0.74, 2.2, 0.08, 0.22, DesertPalette.WOOD_LIGHT)
	for bx in [-0.75, -0.45, -0.15, 0.45, 0.72]:
		kit.add_box(bx, 1.40, -0.74, 0.11, 0.26, 0.11, DesertPalette.TURQUOISE if bx < 0 else DesertPalette.AWNING_RED)
	for x in [-1.38, 1.38]:
		kit.add_box(x, 0.18, -0.90, 0.15, 2.18, 0.15, DesertPalette.WOOD_DARK, Color(-1, 0, 0), 0, true, true)
		kit.add_box(x, 0.18, 0.80, 0.15, 1.92, 0.15, DesertPalette.WOOD_DARK, Color(-1, 0, 0), 0, true, true)
	kit.add_box(0, 0.18, 0.68, 2.70, 0.88, 0.58, DesertPalette.WOOD, Color(-1, 0, 0), 0, true, true)
	kit.add_box(0, 1.06, 0.68, 2.86, 0.10, 0.72, DesertPalette.CREAM)
	kit.add_box(-0.88, 1.16, 0.68, 0.12, 0.26, 0.12, DesertPalette.WATER)
	kit.add_box(-0.70, 1.16, 0.68, 0.12, 0.24, 0.12, DesertPalette.AWNING_RED)
	kit.add_box(-0.52, 1.16, 0.68, 0.12, 0.26, 0.12, DesertPalette.GOLD)
	kit.add_box(0.88, 1.16, 0.66, 0.28, 0.30, 0.28, DesertPalette.TERRACOTTA)
	kit.add_box(-1.08, 0.18, 0.14, 0.68, 0.64, 0.52, DesertPalette.TURQUOISE)
	kit.add_box(-1.08, 0.82, 0.14, 0.72, 0.10, 0.56, DesertPalette.CREAM)
	kit.add_box(1.10, 0.18, -0.14, 0.52, 0.48, 0.48, DesertPalette.WOOD_LIGHT)
	kit.add_box(1.06, 0.66, -0.16, 0.40, 0.34, 0.38, DesertPalette.TERRACOTTA)
	EntityBuilder.add_vendor_character(kit, Vector3(0.10, 0.18, -0.08), anim_time)
	kit.add_sloped_awning(0, 2.44, 2.06, 0.02, 3.35, 2.32, DesertPalette.AWNING_RED, DesertPalette.CREAM, 6)
	for lx in [-1.15, -0.58, 0.0, 0.58, 1.15]:
		kit.add_box(lx, 1.82, 1.08, 0.10, 0.10, 0.10, DesertPalette.CREAM, Color(-1, 0, 0), 1)
	kit.add_box(-2.0, 0, 0.92, 0.62, 0.84, 0.12, DesertPalette.WOOD_DARK)
	kit.add_flush_rect_z(-2.0, 0.44, 0.98, 0.50, 0.60, Color("333b3d"), true)
	if level >= 3:
		kit.add_marquee_sign(0, 2.45, -0.50, 2.35, 0.62, "DRINKS", DesertPalette.WOOD_DARK, DesertPalette.CREAM, DesertPalette.SANDSTONE_DARK, 0.18)
		kit.add_patio_umbrella_table(2.10, 0, 0.50, DesertPalette.TURQUOISE)
		kit.add_potted_cactus(-1.85, 0, -0.45)
	if level >= 4:
		kit.add_flush_rect_z(0, 0.64, 0.97, 1.65, 0.46, DesertPalette.TURQUOISE, true)
		kit.add_flush_rect_z(0, 0.64, 0.985, 1.15, 0.28, DesertPalette.GOLD, true)
		kit.add_box(2.55, 0, 1.25, 0.12, 2.35, 0.12, DesertPalette.WOOD_DARK)
		kit.add_sagging_wire(Vector3(1.38, 2.15, 0.80), Vector3(2.55, 2.28, 1.25), DesertPalette.WOOD_DARK, 0.18, 0.036, 5, 3)
	if level >= 5:
		kit.add_patio_umbrella_table(-2.15, 0, -0.10, DesertPalette.GOLD, DesertPalette.CREAM, 0.88)
		kit.add_box(1.42, 2.33, -0.90, 0.08, 1.25, 0.08, DesertPalette.WOOD_DARK)
		var fl := sin(anim_time * 4.5) * 0.12
		kit.add_tri(Vector3(1.46, 3.52, -0.90), Vector3(1.46, 3.16, -0.90), Vector3(2.18, 3.34, -0.90 + fl), DesertPalette.GOLD, true)


# --- 2. OUTPOST MART ---
static func _build_outpost_mart(kit: MeshKit, level: int, anim_time: float) -> void:
	kit.add_box(0, 0, 0.22, 4.9, 0.20, 3.8, DesertPalette.CONCRETE)
	kit.add_box(0, 0.20, -0.22, 4.45, 2.55, 2.75, DesertPalette.CREAM, Color(-1, 0, 0), 0, true, true)
	# Split terracotta wainscot cleanly left & right of front door frame (never intersects doorway!)
	kit.add_box(-1.39, 0.20, 1.185, 1.69, 0.48, 0.05, DesertPalette.TERRACOTTA)
	kit.add_box(1.39, 0.20, 1.185, 1.69, 0.48, 0.05, DesertPalette.TERRACOTTA)
	kit.add_adobe_parapet_roof(0, 2.75, -0.22, 4.48, 2.78, 0.32, DesertPalette.SANDSTONE)
	kit.add_framed_door(0, 0.20, 1.16, 0.92, 1.58)
	kit.add_framed_front_window(-1.42, 1.30, 1.16, 1.16, 0.96)
	kit.add_framed_front_window(1.42, 1.30, 1.16, 1.16, 0.96)
	kit.add_right_window(2.23, 1.35, -0.22, 1.10, 0.90)
	for px in [-2.0, -0.72, 0.72, 2.0]:
		kit.add_box(px, 0.20, 1.88, 0.14, 1.82, 0.14, DesertPalette.WOOD, Color(-1, 0, 0), 0, true, true)
	kit.add_sloped_awning(0, 2.38, 2.02, 1.56, 4.65, 1.05, DesertPalette.TURQUOISE, DesertPalette.CREAM, 8)
	if level >= 2:
		kit.add_box(-1.60, 0.20, 1.48, 0.78, 0.60, 0.42, DesertPalette.CREAM_DARK)
		kit.add_frustum(-2.12, 0.20, 1.46, 0.22, 0.22, 0.20, 0.20, 0.56, 7, DesertPalette.WOOD)
		kit.add_box(1.70, 0.20, 1.44, 0.62, 1.24, 0.42, DesertPalette.AWNING_RED)
		kit.add_flush_rect_z(1.70, 1.00, 1.65, 0.46, 0.56, DesertPalette.CREAM, true, 1)
	kit.add_potted_cactus(0.72, 0.20, 1.50)
	for lx in [-1.35, 0.0, 1.35]:
		kit.add_box(lx, 1.84, 1.88, 0.10, 0.10, 0.10, DesertPalette.CREAM, Color(-1, 0, 0), 1)
	kit.add_marquee_sign(0, 3.07, 1.06, 3.05, 0.86, "MART", DesertPalette.TURQUOISE)
	if level >= 3:
		kit.add_box(-2.72, 0.20, -0.30, 1.12, 1.90, 2.15, DesertPalette.CREAM_DARK, Color(-1, 0, 0), 0, true, true)
		kit.add_box(-2.72, 2.10, -0.30, 1.24, 0.20, 2.30, DesertPalette.TERRACOTTA)
		kit.add_box(1.25, 2.81, -0.65, 0.78, 0.56, 0.68, DesertPalette.METAL)
		kit.add_box(-1.45, 2.81, -0.90, 0.44, 0.78, 0.44, DesertPalette.SANDSTONE)
	if level >= 4:
		kit.add_flush_rect_z(0, 2.52, 1.16, 4.25, 0.14, DesertPalette.GOLD, true)
		kit.add_box(2.62, 0.20, 0.20, 0.72, 1.35, 1.45, DesertPalette.WOOD)
		kit.add_sloped_awning(2.62, 1.65, 1.48, 0.20, 0.86, 1.55, DesertPalette.TERRACOTTA)
	if level >= 5:
		kit.add_tapered_box(-0.35, 2.81, -0.75, 1.55, 0.88, 1.55, 0.72, 0.24, DesertPalette.METAL_DARK, Color("2b4663"), 0.0, 0.08)
		kit.add_box(1.85, 3.07, 1.06, 0.08, 0.72, 0.08, DesertPalette.METAL_DARK)
		kit.push_tx(Vector3(1.85, 3.74, 1.06), anim_time * 1.6)
		kit.add_box(0, 0, 0, 0.56, 0.07, 0.08, DesertPalette.GOLD)
		kit.add_box(0, 0, 0, 0.08, 0.07, 0.56, DesertPalette.GOLD)
		kit.pop_tx()


# --- 3. TACO & COFFEE STAND ---
static func _build_food_stand(kit: MeshKit, level: int, anim_time: float) -> void:
	kit.add_box(0, 0, 0.1, 3.75, 0.16, 2.85, DesertPalette.CONCRETE)
	kit.add_box(0, 0.16, -0.18, 2.85, 2.02, 1.95, DesertPalette.TERRACOTTA, Color(-1, 0, 0), 0, true, true)
	kit.add_box(0, 2.18, -0.18, 3.0, 0.24, 2.10, DesertPalette.CREAM)
	kit.add_front_window(0, 1.38, 0.80, 1.88, 0.84, Color("3e2d24"))
	kit.add_flush_rect_z(-1.18, 1.38, 0.81, 0.36, 0.68, Color("2f3638"), true)
	kit.add_box(0, 0.90, 0.95, 2.25, 0.11, 0.42, DesertPalette.WOOD_LIGHT)
	for sx in [-0.70, 0.0, 0.70]:
		kit.add_box(sx, 0.16, 1.22, 0.11, 0.52, 0.11, DesertPalette.METAL_DARK)
		kit.add_box(sx, 0.68, 1.22, 0.32, 0.10, 0.32, DesertPalette.AWNING_RED)
		kit.add_box(sx, 0.78, 1.35, 0.26, 0.20, 0.05, DesertPalette.METAL_DARK)
	kit.add_sloped_awning(0, 2.18, 1.86, 1.16, 2.95, 0.88, DesertPalette.WOOD, DesertPalette.CREAM, 6)
	var pcols := [DesertPalette.AWNING_RED, DesertPalette.GOLD, DesertPalette.TURQUOISE, DesertPalette.CREAM, DesertPalette.TERRACOTTA, DesertPalette.GOLD]
	for i in range(pcols.size()):
		var px := -1.12 + i * 0.45
		kit.add_tri(Vector3(px - 0.15, 1.72, 1.60), Vector3(px + 0.15, 1.72, 1.60), Vector3(px, 1.48, 1.60), pcols[i], true)
	for lx in [-0.85, 0.0, 0.85]:
		kit.add_box(lx, 1.72, 1.42, 0.10, 0.10, 0.10, DesertPalette.CREAM, Color(-1, 0, 0), 1)
	if level >= 2:
		kit.add_marquee_sign(0, 2.42, 0.52, 2.15, 0.60, "CAFE", DesertPalette.WOOD_DARK, DesertPalette.CREAM, DesertPalette.SANDSTONE_DARK, 0.18)
		kit.add_frustum(0, 2.42, -0.38, 0.38, 0.38, 0.48, 0.48, 0.78, 8, DesertPalette.CREAM, DesertPalette.WOOD_DARK)
		kit.add_frustum(0, 3.18, -0.38, 0.36, 0.36, 0.14, 0.14, 0.14, 8, DesertPalette.CREAM)
		kit.add_box(0.48, 2.66, -0.38, 0.22, 0.32, 0.11, DesertPalette.CREAM)
		for s in range(2):
			var phase := fmod(anim_time * 0.7 + s * 0.5, 1.0)
			var sy := 3.36 + phase * 0.72
			var sx := sin(anim_time * 2.2 + s * 2.0) * 0.12
			var sz := 0.16 * (1.0 - phase * 0.45)
			kit.add_box(sx, sy, -0.38, sz, sz, sz, DesertPalette.CREAM, Color(-1, 0, 0), 2)
	if level >= 3:
		kit.add_patio_umbrella_table(-2.0, 0.16, 0.45, DesertPalette.AWNING_RED, DesertPalette.CREAM, 0.94)
		kit.add_potted_cactus(1.56, 0.16, 0.88)
	if level >= 4:
		kit.add_patio_umbrella_table(2.02, 0.16, 0.45, DesertPalette.TURQUOISE, DesertPalette.CREAM, 0.94)
		kit.add_box(0, 2.42, -0.18, 3.06, 0.06, 2.16, DesertPalette.GOLD, Color(-1, 0, 0), 1)
	if level >= 5:
		for px in [-2.45, 2.45]:
			kit.add_box(px, 0.16, 1.35, 0.12, 2.20, 0.12, DesertPalette.WOOD_DARK)
		kit.add_sagging_wire(Vector3(-2.45, 2.30, 1.35), Vector3(2.45, 2.30, 1.35), DesertPalette.WOOD_DARK, 0.24, 0.036, 5, 5)


# --- 4. ROUTE 163 DESERT DINER ---
static func _build_desert_diner(kit: MeshKit, level: int, anim_time: float) -> void:
	kit.add_box(0, 0, 0.22, 6.0, 0.22, 4.35, DesertPalette.CONCRETE)
	for i in range(6):
		kit.add_ground_rect(-2.5 + i * 1.0, 0.228, 2.16, 0.98, 0.38, DesertPalette.AWNING_RED if i % 2 == 0 else DesertPalette.CREAM)
	kit.add_box(0, 0.22, -0.28, 5.15, 2.62, 3.02, DesertPalette.CREAM, Color(-1, 0, 0), 0, true, true)
	for cx in [-2.52, 2.52]:
		kit.add_frustum(cx, 0.22, -0.28, 0.46, 1.48, 0.46, 1.48, 2.60, 6, DesertPalette.METAL, DesertPalette.CREAM_DARK)
	kit.add_box(0, 2.38, -0.28, 5.75, 0.30, 3.16, DesertPalette.AWNING_RED, Color(-1, 0, 0), 0, true, true)
	kit.add_box(0, 2.16, -0.28, 5.72, 0.18, 3.12, DesertPalette.TURQUOISE, Color(-1, 0, 0), 0, true, true)
	kit.add_box(0, 2.72, -0.28, 5.82, 0.09, 3.24, DesertPalette.AWNING_RED, Color(-1, 0, 0), 1, true, true)
	kit.add_box(0, 2.84, -0.28, 5.84, 0.26, 3.26, DesertPalette.CREAM_DARK)
	kit.add_tapered_box(0, 3.10, 0.35, 4.20, 1.45, 5.10, 1.85, 0.24, DesertPalette.TURQUOISE, DesertPalette.CREAM, 0.0, 0.28)
	kit.add_box(0, 0.22, 1.38, 1.62, 1.94, 0.70, DesertPalette.CREAM, Color(-1, 0, 0), 0, true, true)
	kit.add_box(-0.78, 0.22, 1.72, 0.14, 1.94, 0.14, DesertPalette.METAL, Color(-1, 0, 0), 0, true, true)
	kit.add_box(0.78, 0.22, 1.72, 0.14, 1.94, 0.14, DesertPalette.METAL, Color(-1, 0, 0), 0, true, true)
	kit.add_box(0, 2.16, 1.66, 2.10, 0.14, 0.82, DesertPalette.METAL)
	kit.add_box(0, 2.18, 2.10, 2.12, 0.06, 0.06, DesertPalette.TURQUOISE, Color(-1, 0, 0), 1)
	kit.add_framed_door(0, 0.22, 1.73, 0.90, 1.68)
	kit.add_potted_cactus(-1.06, 0.22, 1.78)
	kit.add_potted_cactus(1.06, 0.22, 1.78)
	kit.add_framed_front_window(-1.72, 1.36, 1.24, 1.42, 1.02, DesertPalette.METAL_DARK)
	kit.add_framed_front_window(1.72, 1.36, 1.24, 1.42, 1.02, DesertPalette.METAL_DARK)
	kit.add_right_window(2.88, 1.36, -0.28, 1.30, 0.96)
	kit.add_left_window(-2.88, 1.36, -0.28, 1.30, 0.96)
	kit.add_box(-1.90, 3.10, -1.05, 0.66, 0.78, 0.66, DesertPalette.METAL)
	kit.add_box(-1.90, 3.88, -1.05, 0.78, 0.12, 0.78, DesertPalette.METAL_DARK)
	kit.add_box(1.75, 3.10, -0.95, 0.92, 0.42, 0.78, DesertPalette.METAL_DARK)
	kit.add_marquee_sign(0, 3.34, 0.92, 3.20, 1.04, "DINER", DesertPalette.AWNING_RED, DesertPalette.CREAM, DesertPalette.SANDSTONE_DARK, 0.24)
	if level >= 2:
		for tx in [-2.05, 2.05]:
			kit.add_patio_umbrella_table(tx, 0.22, 1.90, DesertPalette.TURQUOISE, DesertPalette.CREAM, 0.90)
	if level >= 3:
		kit.add_box(0, 4.38, 0.92, 0.14, 0.54, 0.14, DesertPalette.METAL)
		kit.push_tx(Vector3(0, 4.92, 0.92), anim_time * 0.9)
		kit.add_box(0, 0, 0, 0.50, 0.50, 0.20, DesertPalette.GOLD, Color(-1, 0, 0), 1)
		kit.pop_tx()
	if level >= 4:
		for fx in [-2.35, 2.35]:
			kit.add_tapered_box(fx, 3.34, 0.50, 0.16, 1.20, 0.12, 0.65, 0.72, DesertPalette.AWNING_RED, DesertPalette.GOLD, 0.0, 0.25)
	if level >= 5:
		for sx in [-1.85, 1.85]:
			kit.add_box(sx, 3.34, 0.92, 0.10, 0.42, 0.10, DesertPalette.METAL)
			kit.push_tx(Vector3(sx, 3.76, 0.92), -anim_time * 1.2)
			kit.add_box(0, 0, 0, 0.32, 0.32, 0.14, DesertPalette.TURQUOISE, Color(-1, 0, 0), 1)
			kit.pop_tx()


# --- 5. CANYON GAS STATION & GARAGE ---
static func _build_gas_station(kit: MeshKit, level: int, anim_time: float) -> void:
	kit.add_box(0, 0, 0.2, 5.5, 0.18, 4.4, DesertPalette.CONCRETE)
	kit.add_box(0.25, 0.18, -1.12, 4.75, 2.48, 1.82, DesertPalette.CREAM, Color(-1, 0, 0), 0, true, true)
	kit.add_adobe_parapet_roof(0.25, 2.66, -1.12, 4.78, 1.85, 0.26, DesertPalette.TERRACOTTA, DesertPalette.SAND_DARK, false)
	kit.add_box(-0.78, 0.18, -0.18, 1.88, 1.75, 0.06, DesertPalette.METAL)
	for sy in [0.55, 0.92, 1.29, 1.66]:
		kit.add_flush_rect_z(-0.78, sy, -0.15, 1.84, 0.05, DesertPalette.METAL_DARK, true)
	kit.add_framed_front_window(1.42, 1.30, -0.21, 1.28, 0.90)
	const CY := 2.75
	kit.add_box(-1.55, 0.18, 1.05, 0.30, CY - 0.18, 0.30, DesertPalette.CREAM_DARK, Color(-1, 0, 0), 0, true, true)
	kit.add_box(1.55, 0.18, 1.05, 0.30, CY - 0.18, 0.30, DesertPalette.CREAM_DARK, Color(-1, 0, 0), 0, true, true)
	kit.add_box(0, CY, 1.05, 4.75, 0.38, 2.12, DesertPalette.CREAM)
	kit.add_box(0, CY + 0.08, 1.05, 4.86, 0.22, 2.22, DesertPalette.AWNING_RED, Color(-1, 0, 0), 0, true, true)
	for lx in [-0.95, 0.95]:
		kit.add_box(lx, CY - 0.06, 1.05, 1.15, 0.06, 0.55, DesertPalette.CREAM, Color(-1, 0, 0), 1, true, true)
	kit.add_box(0, 0.18, 1.05, 2.85, 0.15, 0.72, DesertPalette.CONCRETE)
	for bx in [-1.32, 1.32]:
		kit.add_frustum(bx, 0.33, 1.05, 0.09, 0.09, 0.08, 0.08, 0.62, 6, DesertPalette.GOLD)
	for px in [-0.66, 0.66]:
		kit.add_box(px, 0.33, 1.05, 0.52, 1.12, 0.40, DesertPalette.AWNING_RED, Color(-1, 0, 0), 0, true, true)
		kit.add_box(px, 1.45, 1.05, 0.44, 0.14, 0.34, DesertPalette.CREAM)
		kit.add_box(px + 0.30, 0.66, 1.05, 0.07, 0.54, 0.07, DesertPalette.ASPHALT)
		kit.add_box(px + 0.30, 1.12, 1.05, 0.10, 0.14, 0.12, DesertPalette.METAL)
		kit.add_flush_rect_z(px, 1.08, 1.25, 0.35, 0.32, DesertPalette.CREAM, true, 1)
	if level >= 2:
		kit.add_box(2.58, 0.18, 1.98, 0.22, 4.35, 0.22, DesertPalette.METAL_DARK)
		kit.add_marquee_sign(2.58, 3.40, 1.98, 1.56, 1.22, "GAS\n3.49", DesertPalette.AWNING_RED, DesertPalette.CREAM, DesertPalette.SANDSTONE_DARK, 0.26)
	if level >= 3:
		kit.add_frustum(-2.35, 0.18, -0.45, 0.32, 0.32, 0.32, 0.32, 0.48, 8, DesertPalette.ASPHALT)
		kit.add_frustum(-2.35, 0.18, 0.36, 0.26, 0.26, 0.26, 0.26, 0.78, 8, DesertPalette.TURQUOISE)
		kit.add_box(-1.95, 0.18, 0.02, 0.48, 0.64, 0.36, DesertPalette.AWNING_RED)
	if level >= 4:
		kit.add_tapered_box(0.25, 2.72, -1.15, 2.6, 0.95, 2.6, 0.78, 0.22, DesertPalette.METAL_DARK, Color("2b4663"), 0.0, 0.10)
		kit.add_box(-2.38, 0.18, 1.75, 0.34, 1.15, 0.30, DesertPalette.TURQUOISE)
	if level >= 5:
		kit.add_box(2.58, 4.62, 1.98, 0.12, 0.42, 0.12, DesertPalette.METAL)
		kit.push_tx(Vector3(2.58, 5.05, 1.98), anim_time * 1.1)
		kit.add_frustum(0, 0, 0, 0.42, 0.16, 0.32, 0.14, 0.48, 6, DesertPalette.GOLD, Color(-1, 0, 0), 0.0, 0.0, 1, 1)
		kit.pop_tx()


# --- 6. OASIS SOUVENIR PLAZA ---
static func _add_palm_tree(kit: MeshKit, x: float, y_bottom: float, z: float, s: float, anim_time: float, lean_x: float) -> void:
	var cur_x := x
	var cur_y := y_bottom
	for i in range(4):
		var f0 := float(i) / 4.0
		var f1 := float(i + 1) / 4.0
		var r0 := (0.17 - f0 * 0.06) * s
		var r1 := (0.17 - f1 * 0.06) * s
		var seg_h := (2.25 / 4.0) * s
		kit.add_frustum(cur_x, cur_y, z, r0, r0, r1, r1, seg_h + 0.04, 6, DesertPalette.WOOD if i % 2 == 0 else DesertPalette.WOOD_LIGHT)
		cur_x += (lean_x / 4.0) * s * (float(i) + 0.5)
		cur_y += seg_h
	for coc in [Vector2(-0.08, 0.06), Vector2(0.08, 0.05), Vector2(0.0, -0.08)]:
		kit.add_box(cur_x + coc.x * s, cur_y - 0.08 * s, z + coc.y * s, 0.11 * s, 0.11 * s, 0.11 * s, DesertPalette.WOOD_DARK)
	var breeze := sin(anim_time * 1.8 + x) * 0.04
	for i in range(6):
		var a := (float(i) / 6.0) * TAU + 0.3
		var dx := cos(a)
		var dz := sin(a)
		var px := -dz * 0.18 * s
		var pz := dx * 0.18 * s
		var root := Vector3(cur_x, cur_y + 0.04 * s, z)
		var mid := Vector3(cur_x + dx * 0.58 * s, cur_y + (0.20 + breeze) * s, z + dz * 0.58 * s)
		var tip := Vector3(cur_x + dx * 1.08 * s, cur_y - (0.18 - breeze) * s, z + dz * 1.08 * s)
		var col := DesertPalette.CACTUS if i % 2 == 0 else DesertPalette.VEGETATION
		kit.add_quad(root - Vector3(px * 0.4, 0, pz * 0.4), root + Vector3(px * 0.4, 0, pz * 0.4), mid + Vector3(px, 0, pz), mid - Vector3(px, 0, pz), col, true)
		kit.add_tri(mid - Vector3(px, 0, pz), mid + Vector3(px, 0, pz), tip, DesertPalette.VEGETATION, true)


static func _build_oasis_plaza(kit: MeshKit, level: int, anim_time: float) -> void:
	kit.add_box(0, 0, 0, 4.0, 0.16, 3.1, DesertPalette.CREAM_DARK)
	var shimmer := 0.08 * sin(anim_time * 2.5)
	var pool_col := DesertPalette.WATER.lerp(DesertPalette.NEON_TURQUOISE, 0.18 + shimmer)
	kit.add_box(0.32, 0.16, 0.32, 2.15, 0.06, 1.50, pool_col)
	kit.add_box(0.32, 0.16, -0.48, 2.32, 0.11, 0.15, DesertPalette.CREAM)
	kit.add_box(0.32, 0.16, 1.12, 2.32, 0.11, 0.15, DesertPalette.CREAM)
	for lx in [-0.20, 0.85]:
		kit.add_box(lx, 0.16, -0.84, 0.54, 0.18, 0.36, DesertPalette.WOOD_LIGHT)
		kit.add_box(lx, 0.34, -0.84, 0.46, 0.05, 0.30, DesertPalette.TERRACOTTA)
	kit.add_box(-1.32, 0.16, -0.26, 1.16, 1.72, 1.92, DesertPalette.TERRACOTTA, Color(-1, 0, 0), 0, true, true)
	kit.add_box(-1.32, 1.88, -0.26, 1.34, 0.18, 2.10, DesertPalette.CREAM)
	kit.add_framed_front_window(-1.32, 1.06, 0.70, 0.72, 0.66)
	for x in [-0.42, 1.32]:
		kit.add_box(x, 0.16, -1.10, 0.15, 2.04, 0.15, DesertPalette.WOOD, Color(-1, 0, 0), 0, true, true)
	for rx in [-0.20, 0.22, 0.64, 1.06]:
		kit.add_box(rx, 2.20, -0.96, 0.10, 0.08, 0.64, DesertPalette.WOOD_DARK)
	kit.add_box(0.45, 2.28, -1.10, 2.05, 0.56, 0.22, DesertPalette.WOOD_LIGHT)
	kit.add_front_sign_text(0.45, 2.56, -0.98, 1.90, 0.44, "OASIS", DesertPalette.CREAM, true)
	kit.add_box(1.70, 0.16, 1.18, 0.12, 1.12, 0.12, DesertPalette.WOOD_DARK, Color(-1, 0, 0), 0, true, true)
	kit.add_box(1.70, 1.28, 1.18, 0.22, 0.24, 0.22, DesertPalette.CREAM, Color(-1, 0, 0), 1)
	if level >= 2:
		_add_palm_tree(kit, 1.56, 0.16, -0.84, 1.0, anim_time, 0.18)
		kit.add_potted_cactus(-1.60, 0.16, 1.08)
	if level >= 3:
		kit.add_patio_umbrella_table(-1.35, 0.16, 1.25, DesertPalette.TURQUOISE, DesertPalette.CREAM, 0.80)
	if level >= 4:
		_add_palm_tree(kit, -1.85, 0.16, -1.15, 0.84, anim_time + 1.2, -0.16)
		kit.add_frustum(1.42, 0.16, 0.28, 0.34, 0.30, 0.18, 0.16, 0.55, 6, DesertPalette.SANDSTONE)
	if level >= 5:
		kit.add_sagging_wire(Vector3(-1.32, 2.04, 0.65), Vector3(1.70, 1.42, 1.18), DesertPalette.WOOD_DARK, 0.18, 0.036, 5, 4)
		kit.add_frustum(0.45, 2.84, -1.10, 0.32, 0.12, 0.08, 0.08, 0.36, 6, DesertPalette.GOLD, Color(-1, 0, 0), 0.0, 0.0, 1, 1)


# --- 7. RED ROCK DESERT MOTEL ---
static func _build_desert_motel(kit: MeshKit, level: int) -> void:
	kit.add_box(0, 0, 0.18, 6.8, 0.20, 4.2, DesertPalette.CONCRETE)
	var stories := 2 if level >= 2 else 1
	var wall_h := 4.05 if stories == 2 else 2.20
	kit.add_box(0.2, 0.20, -0.68, 5.8, wall_h, 2.2, DesertPalette.CREAM, Color(-1, 0, 0), 0, true, true)
	kit.add_adobe_parapet_roof(0.2, 0.20 + wall_h, -0.68, 5.82, 2.24, 0.30, DesertPalette.TERRACOTTA)
	for rx in [-1.62, 0.20, 2.02]:
		kit.add_framed_door(rx - 0.32, 0.20, 0.42, 0.54, 1.42, DesertPalette.WOOD_DARK, DesertPalette.TURQUOISE, false)
		kit.add_box(rx - 0.01, 1.34, 0.47, 0.11, 0.16, 0.08, DesertPalette.CREAM, Color(-1, 0, 0), 1)
		kit.add_framed_front_window(rx + 0.38, 1.08, 0.42, 0.70, 0.68)
		kit.add_box(rx + 0.38, 0.38, 0.53, 0.44, 0.24, 0.20, DesertPalette.METAL)
	if stories == 2:
		kit.add_box(0.2, 2.16, 0.78, 5.85, 0.15, 0.76, DesertPalette.WOOD)
		kit.add_box(0.2, 2.82, 1.12, 5.85, 0.10, 0.10, DesertPalette.WOOD_LIGHT)
		for px in [-2.60, -0.90, 0.82, 2.60]:
			kit.add_box(px, 0.20, 1.12, 0.13, 1.96, 0.13, DesertPalette.WOOD_DARK, Color(-1, 0, 0), 0, true, true)
			kit.add_box(px, 2.31, 1.12, 0.13, 0.51, 0.13, DesertPalette.WOOD_DARK, Color(-1, 0, 0), 0, true, true)
		for s in range(6):
			var frac := float(s + 1) / 6.0
			var sy := 0.20 + frac * 1.94
			var sz := 2.02 - frac * 1.18
			kit.add_box(3.42, 0.20, sz, 0.64, sy - 0.28, 0.18, DesertPalette.WOOD, Color(-1, 0, 0), 0, true, true)
			kit.add_box(3.42, sy - 0.08, sz + 0.02, 0.68, 0.08, 0.19, DesertPalette.WOOD_LIGHT)
		kit.add_box(3.72, 0.20, 0.96, 0.12, 2.72, 0.12, DesertPalette.WOOD_DARK)
		kit.add_box(3.72, 0.20, 2.04, 0.12, 0.96, 0.12, DesertPalette.WOOD_DARK)
		kit.add_sagging_wire(Vector3(3.72, 1.14, 2.04), Vector3(3.72, 2.86, 0.96), DesertPalette.WOOD_LIGHT, 0.0, 0.06, 2)
		for rx in [-1.62, 0.20, 2.02]:
			kit.add_framed_door(rx - 0.32, 2.31, 0.42, 0.54, 1.38, DesertPalette.WOOD_DARK, DesertPalette.TERRACOTTA, false)
			kit.add_box(rx - 0.01, 3.42, 0.47, 0.11, 0.16, 0.08, DesertPalette.CREAM, Color(-1, 0, 0), 1)
			kit.add_framed_front_window(rx + 0.38, 3.12, 0.42, 0.70, 0.66)
	kit.add_marquee_sign(0.2, 0.50 + wall_h, 0.32, 2.85, 0.98, "MOTEL", DesertPalette.SANDSTONE_DARK, DesertPalette.CREAM, DesertPalette.UI_INK, 0.24)
	if level >= 3:
		kit.add_box(-3.0, 0.20, 1.0, 1.62, 1.35, 1.72, DesertPalette.WOOD_LIGHT)
		kit.add_gable_roof(-3.0, 1.55, 1.0, 1.84, 0.72, 1.94, DesertPalette.SANDSTONE, DesertPalette.WOOD)
		kit.add_box(-3.55, 1.60, 0.65, 0.34, 1.05, 0.34, DesertPalette.SANDSTONE_DARK)
		kit.add_framed_front_window(-3.0, 0.92, 1.86, 0.56, 0.52)
	if level >= 4:
		kit.add_patio_umbrella_table(0.25, 0.20, 1.72, DesertPalette.TERRACOTTA, DesertPalette.CREAM, 0.85)
		kit.add_potted_cactus(-1.75, 0.20, 1.55)
	if level >= 5:
		kit.add_frustum(-1.95, 0.26 + wall_h, -0.85, 0.56, 0.56, 0.52, 0.52, 0.95, 8, DesertPalette.WOOD)
		kit.add_frustum(-1.95, 1.21 + wall_h, -0.85, 0.64, 0.64, 0.08, 0.08, 0.38, 8, DesertPalette.TERRACOTTA)
		kit.add_sagging_wire(Vector3(-2.60, 2.75, 1.12), Vector3(2.60, 2.75, 1.12), DesertPalette.WOOD_DARK, 0.18, 0.036, 5, 5)


# --- 8. MESA LOOKOUT WATER TOWER & CAMP ---
static func _build_lookout_camp(kit: MeshKit, level: int, anim_time: float) -> void:
	kit.add_ground_rect(0, 0.025, 0, 6.2, 4.4, Color("cda876"))
	const TX := 1.50
	const TZ := -0.80
	for lx in [-0.68, 0.68]:
		for lz in [-0.68, 0.68]:
			kit.add_box(TX + lx, 0, TZ + lz, 0.17, 3.80, 0.17, DesertPalette.WOOD_DARK, Color(-1, 0, 0), 0, true, true)
	kit.add_box(TX, 1.25, TZ + 0.68, 1.48, 0.10, 0.10, DesertPalette.WOOD)
	kit.add_box(TX, 2.55, TZ + 0.68, 1.48, 0.10, 0.10, DesertPalette.WOOD)
	kit.add_box(TX, 1.78, TZ, 1.52, 0.13, 1.52, DesertPalette.WOOD)
	for r in range(1, 8):
		kit.add_box(TX - 0.18, r * 0.48, TZ + 0.76, 0.34, 0.06, 0.06, DesertPalette.WOOD_LIGHT)
	kit.add_box(TX, 3.80, TZ, 2.10, 0.18, 2.10, DesertPalette.WOOD_LIGHT)
	kit.add_box(TX, 4.36, TZ + 0.98, 2.10, 0.09, 0.09, DesertPalette.WOOD)
	kit.add_box(TX, 4.36, TZ - 0.98, 2.10, 0.09, 0.09, DesertPalette.WOOD)
	kit.add_frustum(TX, 3.98, TZ, 0.86, 0.86, 0.82, 0.82, 1.65, 8, DesertPalette.WOOD, DesertPalette.WOOD_DARK)
	for hy in [4.38, 4.86, 5.32]:
		kit.add_frustum(TX, hy, TZ, 0.88, 0.88, 0.88, 0.88, 0.07, 8, DesertPalette.METAL_DARK)
	kit.add_frustum(TX, 5.63, TZ, 1.02, 1.02, 0.08, 0.08, 0.72, 8, DesertPalette.TERRACOTTA, DesertPalette.SANDSTONE_DARK)

	kit.add_box(-1.50, 0, -0.70, 2.70, 2.02, 2.18, DesertPalette.CREAM, Color(-1, 0, 0), 0, true, true)
	kit.add_adobe_parapet_roof(-1.50, 2.02, -0.70, 2.72, 2.20, 0.24, DesertPalette.SANDSTONE)
	kit.add_framed_door(-1.50, 0, 0.39, 0.68, 1.32, DesertPalette.WOOD_DARK, DesertPalette.WOOD, false)
	kit.add_framed_front_window(-2.24, 1.08, 0.39, 0.56, 0.56)
	kit.add_framed_front_window(-0.76, 1.08, 0.39, 0.56, 0.56)
	kit.add_box(-0.22, 0, 0.42, 0.08, 0.92, 0.08, DesertPalette.WOOD_DARK)
	kit.add_box(-0.22, 0.62, 0.44, 0.56, 0.42, 0.07, DesertPalette.CREAM)
	kit.add_marquee_sign(-1.50, 2.26, 0.30, 1.95, 0.56, "TOURS", DesertPalette.SANDSTONE_DARK, DesertPalette.CREAM, DesertPalette.UI_INK, 0.16)
	if level >= 2:
		_add_tent(kit, Vector3(-1.95, 0, 1.45), DesertPalette.CREAM, DesertPalette.TERRACOTTA)
		_add_tent(kit, Vector3(2.05, 0, 1.45), DesertPalette.TURQUOISE, DesertPalette.CREAM)
	if level >= 3:
		kit.add_patio_umbrella_table(-2.75, 0, 0.25, DesertPalette.GOLD, DesertPalette.CREAM, 0.85)
	if level >= 4:
		kit.add_sagging_wire(Vector3(-0.15, 2.20, 0.35), Vector3(TX - 0.68, 3.80, TZ + 0.68), DesertPalette.WOOD_DARK, 0.25, 0.036, 5, 4)
	if level >= 5:
		kit.add_box(TX, 6.32, TZ, 0.07, 1.05, 0.07, DesertPalette.WOOD_DARK)
		var wave := sin(anim_time * 4.8) * 0.14
		kit.add_tri(Vector3(TX, 7.34, TZ), Vector3(TX, 6.90, TZ), Vector3(TX + 0.82, 7.12, TZ + wave), DesertPalette.AWNING_RED, true)
	const FX := 0.05
	const FZ := 1.35
	kit.add_frustum(FX, 0, FZ, 0.54, 0.54, 0.48, 0.48, 0.18, 7, DesertPalette.METAL)
	kit.add_box(FX - 0.85, 0, FZ + 0.15, 0.24, 0.24, 0.78, DesertPalette.WOOD)
	kit.add_box(FX + 0.85, 0, FZ + 0.15, 0.24, 0.24, 0.78, DesertPalette.WOOD)
	var flick := 0.72 + sin(anim_time * 9.5) * 0.18
	kit.add_frustum(FX, 0.15, FZ, 0.28, 0.28, 0.04, 0.04, 0.58 * flick, 5, Color("ff8c32"), Color("ffc14d"), 0.0, 0.0, 1, 2)


static func _add_tent(kit: MeshKit, pos: Vector3, wall_col: Color, trim_col: Color) -> void:
	kit.push_tx(pos, 0.15)
	kit.add_gable_roof(0, 0, 0, 1.18, 0.96, 1.36, wall_col, trim_col)
	kit.add_flush_rect_z(0, 0.29, 0.68, 0.42, 0.58, DesertPalette.WOOD_DARK, true)
	kit.pop_tx()

class_name EntityBuilder
extends RefCounted

## All 5 detailed low-poly vehicles (Compact Car, Pickup Truck, SUV, Camper RV, Tourist Van)
## plus animated Visitor and Vendor characters built with MeshKit.

const WHEEL_Y := 0.18
const GLASS_TINT := Color("435f70")
const GLASS_SHEEN := Color("7fa3b5")


static func build_vehicle_node(kind: int, body_col: Color, headlights_on: bool = false, reversing: bool = false) -> Node3D:
	var kit := MeshKit.new()
	match kind:
		GameCatalog.VehicleKind.COMPACT_CAR:
			_build_compact_car(kit, body_col, headlights_on, reversing)
		GameCatalog.VehicleKind.PICKUP_TRUCK:
			_build_pickup_truck(kit, body_col, headlights_on, reversing)
		GameCatalog.VehicleKind.SUV:
			_build_suv(kit, body_col, headlights_on, reversing)
		GameCatalog.VehicleKind.CAMPER_RV:
			_build_camper_rv(kit, body_col, headlights_on, reversing)
		GameCatalog.VehicleKind.DELIVERY_TRUCK:
			_build_delivery_truck(kit, body_col, headlights_on, reversing)
		_:
			_build_tourist_van(kit, body_col, headlights_on, reversing)
	return kit.build_node("Vehicle_%d" % kind, true)


static func _add_wheels_and_bumpers(kit: MeshKit, length: float, width: float, headlights_on: bool, reversing: bool, grill_h: float = 0.16) -> void:
	for wx in [-length * 0.31, length * 0.31]:
		for wz in [-width * 0.48, width * 0.48]:
			kit.add_box(wx, 0.0, wz, 0.40, 0.36, 0.16, DesertPalette.ASPHALT)
			var pos_z: bool = wz > 0.0
			kit.add_flush_rect_z(wx, 0.18, wz + (0.08 if pos_z else -0.08), 0.20, 0.20, DesertPalette.CREAM_DARK, pos_z)
			kit.add_flush_rect_z(wx, 0.18, wz + (0.092 if pos_z else -0.092), 0.08, 0.08, DesertPalette.METAL_DARK, pos_z)

	kit.add_box(length * 0.515, WHEEL_Y + 0.02, 0, 0.09, 0.12, width * 0.96, DesertPalette.METAL)
	kit.add_box(-length * 0.515, WHEEL_Y + 0.02, 0, 0.09, 0.12, width * 0.96, DesertPalette.METAL)
	kit.add_box(-length * 0.54, WHEEL_Y - 0.02, width * 0.28, 0.14, 0.07, 0.07, DesertPalette.METAL_DARK)

	var fx := length * 0.50
	var rx := -length * 0.50
	kit.add_flush_rect_x(fx, WHEEL_Y + 0.25, 0, width * 0.42, grill_h, DesertPalette.METAL_DARK, true)
	kit.add_flush_rect_x(fx + 0.008, WHEEL_Y + 0.25, 0, width * 0.36, 0.04, DesertPalette.CREAM_DARK, true)
	kit.add_flush_rect_x(rx, WHEEL_Y + 0.22, 0, width * 0.26, 0.13, DesertPalette.CREAM, false)

	var head_col := Color("fff2c2")
	var tail_col := Color("ff4d42")
	for wz in [-width * 0.34, width * 0.34]:
		kit.add_flush_rect_x(fx, WHEEL_Y + 0.27, wz, 0.18, 0.13, head_col, true, 1 if headlights_on else 0)
		kit.add_flush_rect_x(rx, WHEEL_Y + 0.27, wz, 0.16, 0.12, tail_col, false, 1)
		kit.add_flush_rect_x(rx, WHEEL_Y + 0.27, wz * 0.62, 0.08, 0.09, Color.WHITE if reversing else DesertPalette.CREAM_DARK, false, 2 if reversing else 0)


static func _build_compact_car(kit: MeshKit, body_col: Color, hl: bool, rev: bool) -> void:
	const L := 1.92
	const W := 0.98
	_add_wheels_and_bumpers(kit, L, W, hl, rev)
	kit.add_box(0, WHEEL_Y, 0, L, 0.40, W, body_col)
	for pos_z in [true, false]:
		kit.add_flush_rect_z(0, WHEEL_Y + 0.28, W * 0.5 if pos_z else -W * 0.5, L * 0.88, 0.06, DesertPalette.CREAM_DARK, pos_z)
	kit.add_tapered_box(-0.06, WHEEL_Y + 0.40, 0, L * 0.58, W * 0.88, L * 0.36, W * 0.74, 0.42, body_col, DesertPalette.CREAM, -0.04)
	for mz in [-W * 0.50, W * 0.50]:
		kit.add_box(0.24, WHEEL_Y + 0.44, mz, 0.08, 0.07, 0.10, DesertPalette.METAL_DARK)
	kit.add_cabin_windows(-0.06, WHEEL_Y + 0.40, 0, L * 0.58, W * 0.88, L * 0.36, W * 0.74, 0.42, GLASS_TINT, GLASS_SHEEN, -0.04)


static func _build_pickup_truck(kit: MeshKit, body_col: Color, hl: bool, rev: bool) -> void:
	const L := 2.40
	const W := 1.08
	_add_wheels_and_bumpers(kit, L, W, hl, rev)
	kit.add_box(0, WHEEL_Y, 0, L, 0.44, W, body_col)
	for pos_z in [true, false]:
		kit.add_flush_rect_z(0, WHEEL_Y + 0.30, W * 0.5 if pos_z else -W * 0.5, L * 0.90, 0.06, DesertPalette.CREAM_DARK, pos_z)
	kit.add_box(-0.62, WHEEL_Y + 0.44, 0, 1.04, 0.05, W * 0.86, DesertPalette.WOOD_DARK)
	for rz in [-W * 0.45, W * 0.45]:
		kit.add_box(-0.62, WHEEL_Y + 0.46, rz, 1.06, 0.12, 0.07, DesertPalette.WOOD_LIGHT)
		for px in [-1.06, -0.62, -0.18]:
			kit.add_box(px, WHEEL_Y + 0.44, rz, 0.07, 0.22, 0.07, DesertPalette.WOOD_DARK)
	kit.add_box(-0.56, WHEEL_Y + 0.49, -0.16, 0.48, 0.34, 0.42, DesertPalette.WOOD)
	kit.add_box(-0.56, WHEEL_Y + 0.83, -0.16, 0.50, 0.05, 0.44, DesertPalette.WOOD_LIGHT)
	kit.add_box(-0.90, WHEEL_Y + 0.49, 0.20, 0.24, 0.32, 0.16, DesertPalette.AWNING_RED)
	kit.add_box(-0.90, WHEEL_Y + 0.81, 0.20, 0.09, 0.06, 0.09, DesertPalette.GOLD)
	kit.add_tapered_box(0.32, WHEEL_Y + 0.44, 0, 0.94, W * 0.90, 0.72, W * 0.80, 0.54, body_col, DesertPalette.CREAM, -0.06)
	for mz in [-W * 0.52, W * 0.52]:
		kit.add_box(0.56, WHEEL_Y + 0.52, mz, 0.08, 0.08, 0.11, DesertPalette.METAL_DARK)
	kit.add_cabin_windows(0.32, WHEEL_Y + 0.44, 0, 0.94, W * 0.90, 0.72, W * 0.80, 0.54, GLASS_TINT, GLASS_SHEEN, -0.06)


static func _build_suv(kit: MeshKit, body_col: Color, hl: bool, rev: bool) -> void:
	const L := 2.28
	const W := 1.08
	_add_wheels_and_bumpers(kit, L, W, hl, rev)
	kit.add_box(0, WHEEL_Y, 0, L, 0.46, W, body_col)
	kit.add_box(L * 0.54, WHEEL_Y + 0.14, 0, 0.07, 0.24, W * 0.56, DesertPalette.METAL_DARK)
	kit.add_box(-L * 0.54, WHEEL_Y + 0.22, 0, 0.16, 0.42, 0.42, DesertPalette.ASPHALT)
	kit.add_flush_rect_x(-L * 0.62, WHEEL_Y + 0.43, 0, 0.22, 0.22, DesertPalette.CREAM, false)
	for pos_z in [true, false]:
		kit.add_flush_rect_z(0, WHEEL_Y + 0.30, W * 0.5 if pos_z else -W * 0.5, L * 0.88, 0.07, DesertPalette.ASPHALT, pos_z)
	kit.add_tapered_box(-0.18, WHEEL_Y + 0.46, 0, L * 0.70, W * 0.90, L * 0.56, W * 0.80, 0.48, body_col, DesertPalette.CREAM, -0.06)
	for mz in [-W * 0.52, W * 0.52]:
		kit.add_box(0.46, WHEEL_Y + 0.52, mz, 0.08, 0.08, 0.11, DesertPalette.METAL_DARK)
	kit.add_box(-0.24, WHEEL_Y + 0.94, 0, 1.12, 0.07, W * 0.74, DesertPalette.METAL_DARK)
	kit.add_box(-0.46, WHEEL_Y + 1.01, -0.14, 0.50, 0.22, 0.34, DesertPalette.TERRACOTTA)
	kit.add_box(0.06, WHEEL_Y + 1.01, 0.14, 0.46, 0.18, 0.24, DesertPalette.VEGETATION)
	kit.add_box(-0.46, WHEEL_Y + 1.01, 0.22, 0.22, 0.20, 0.14, DesertPalette.GOLD)
	kit.add_cabin_windows(-0.18, WHEEL_Y + 0.46, 0, L * 0.70, W * 0.90, L * 0.56, W * 0.80, 0.48, GLASS_TINT, GLASS_SHEEN, -0.06)


static func _build_camper_rv(kit: MeshKit, stripe_col: Color, hl: bool, rev: bool) -> void:
	const L := 3.05
	const W := 1.18
	_add_wheels_and_bumpers(kit, L, W, hl, rev, 0.20)
	kit.add_box(0, WHEEL_Y, 0, L, 0.44, W, DesertPalette.CREAM)
	kit.add_box(-0.34, WHEEL_Y + 0.44, 0, 2.36, 0.72, W, DesertPalette.CREAM)
	kit.add_tapered_box(1.06, WHEEL_Y + 0.44, 0, 0.56, W * 0.94, 0.40, W * 0.88, 0.38, DesertPalette.CREAM, Color(-1, 0, 0), -0.06)
	kit.add_tapered_box(1.04, WHEEL_Y + 0.82, 0, 0.68, W * 0.96, 0.56, W * 0.92, 0.34, DesertPalette.CREAM, DesertPalette.CREAM, -0.04)
	var rx := -L * 0.50
	var hz := W * 0.50
	for pos_z in [true, false]:
		var zw := hz if pos_z else -hz
		kit.add_flush_rect_z(0, WHEEL_Y + 0.34, zw, L * 0.96, 0.14, stripe_col, pos_z)
		kit.add_flush_rect_z(-0.34, WHEEL_Y + 0.48, zw, 2.32, 0.07, DesertPalette.GOLD, pos_z)
		for wx in [-0.96, -0.18]:
			kit.add_flush_rect_z(wx, WHEEL_Y + 0.82, zw, 0.56, 0.28, GLASS_TINT, pos_z)
			kit.add_flush_rect_z(wx - 0.14, WHEEL_Y + 0.82, zw + (0.008 if pos_z else -0.008), 0.10, 0.22, GLASS_SHEEN, pos_z)
	kit.add_flush_rect_z(0.46, WHEEL_Y + 0.54, hz + 0.022, 0.40, 0.84, DesertPalette.CREAM_DARK, true)
	kit.add_flush_rect_z(0.46, WHEEL_Y + 0.78, hz + 0.040, 0.24, 0.22, GLASS_TINT, true)
	kit.add_flush_rect_x(1.34, WHEEL_Y + 0.98, 0, W * 0.68, 0.14, GLASS_TINT, true)
	kit.add_flush_rect_x(rx, WHEEL_Y + 0.36, 0, W * 0.96, 0.15, stripe_col, false)
	kit.add_flush_rect_x(rx, WHEEL_Y + 0.82, 0, W * 0.62, 0.28, GLASS_TINT, false)
	kit.add_cabin_windows(1.06, WHEEL_Y + 0.44, 0, 0.56, W * 0.94, 0.40, W * 0.88, 0.38, GLASS_TINT, GLASS_SHEEN, -0.06)
	kit.add_box(-0.34, WHEEL_Y + 1.06, W * 0.52, 1.88, 0.11, 0.11, DesertPalette.TERRACOTTA)
	kit.add_box(-0.62, WHEEL_Y + 1.16, 0, 0.64, 0.20, 0.64, DesertPalette.CREAM_DARK)
	kit.add_box(0.24, WHEEL_Y + 1.16, 0, 0.74, 0.06, 0.68, Color("2d435c"))
	for lz in [-0.36, 0.0, 0.36]:
		kit.add_box(1.30, WHEEL_Y + 1.13, lz, 0.06, 0.05, 0.08, DesertPalette.GOLD)
	kit.add_box(-L * 0.52, WHEEL_Y + 0.62, 0.38, 0.06, 0.92, 0.05, DesertPalette.METAL)
	kit.add_box(-L * 0.52, WHEEL_Y + 0.62, 0.18, 0.06, 0.92, 0.05, DesertPalette.METAL)


static func _build_tourist_van(kit: MeshKit, body_col: Color, hl: bool, rev: bool) -> void:
	const L := 2.55
	const W := 1.12
	_add_wheels_and_bumpers(kit, L, W, hl, rev)
	kit.add_box(0, WHEEL_Y, 0, L, 0.44, W, body_col)
	kit.add_box(L * 0.52, WHEEL_Y + 0.20, 0, 0.11, 0.34, 0.34, DesertPalette.ASPHALT)
	kit.add_tapered_box(-0.02, WHEEL_Y + 0.44, 0, L * 0.98, W * 0.98, L * 0.88, W * 0.88, 0.48, DesertPalette.CREAM, DesertPalette.CREAM)
	for mz in [-W * 0.53, W * 0.53]:
		kit.add_box(L * 0.34, WHEEL_Y + 0.50, mz, 0.08, 0.08, 0.10, DesertPalette.METAL_DARK)
	kit.add_box(-0.20, WHEEL_Y + 0.92, 0, 1.40, 0.07, W * 0.78, DesertPalette.WOOD)
	kit.add_box(-0.12, WHEEL_Y + 0.99, 0.16, 1.68, 0.07, 0.32, DesertPalette.GOLD)
	kit.add_box(-0.12, WHEEL_Y + 1.06, 0.16, 1.38, 0.03, 0.10, DesertPalette.AWNING_RED)
	kit.add_box(-0.36, WHEEL_Y + 0.99, -0.22, 0.44, 0.22, 0.28, DesertPalette.AWNING_RED)
	kit.add_cabin_windows(-0.02, WHEEL_Y + 0.44, 0, L * 0.98, W * 0.98, L * 0.88, W * 0.88, 0.48, GLASS_TINT, GLASS_SHEEN, 0.0, 0.16, 0.16, 0.08)


static func _build_delivery_truck(kit: MeshKit, accent_col: Color, hl: bool, rev: bool) -> void:
	const L := 3.05
	const W := 1.18
	_add_wheels_and_bumpers(kit, L, W, hl, rev, 0.22)
	# Heavy chassis frame
	kit.add_box(0, WHEEL_Y, 0, L, 0.34, W * 0.94, DesertPalette.METAL_DARK)
	# Forward cab (terracotta / accent)
	kit.add_box(1.00, WHEEL_Y + 0.30, 0, 0.92, 0.78, W * 0.92, accent_col)
	kit.add_tapered_box(0.96, WHEEL_Y + 1.08, 0, 0.88, W * 0.90, 0.74, W * 0.82, 0.16, accent_col, DesertPalette.CREAM)
	kit.add_flush_rect_x(1.46, WHEEL_Y + 0.78, 0, W * 0.76, 0.34, GLASS_TINT, true)
	for pos_z in [true, false]:
		var zw := W * 0.46 if pos_z else -W * 0.46
		kit.add_flush_rect_z(1.06, WHEEL_Y + 0.78, zw, 0.44, 0.30, GLASS_TINT, pos_z)
	# Tall cream cargo box with turquoise freight stripe
	kit.add_box(-0.46, WHEEL_Y + 0.34, 0, 1.98, 1.18, W, DesertPalette.CREAM, Color(-1, 0, 0), 0, true, true)
	kit.add_box(-0.46, WHEEL_Y + 1.52, 0, 2.00, 0.08, W * 1.01, DesertPalette.CREAM_DARK)
	for pos_z in [true, false]:
		var zw := W * 0.50 if pos_z else -W * 0.50
		kit.add_flush_rect_z(-0.46, WHEEL_Y + 0.92, zw, 1.90, 0.24, DesertPalette.TURQUOISE, pos_z)
		kit.add_flush_rect_z(-0.46, WHEEL_Y + 0.68, zw, 1.90, 0.09, DesertPalette.GOLD, pos_z)
	# Rear roll-up cargo door
	kit.add_flush_rect_x(-1.45, WHEEL_Y + 0.92, 0, W * 0.82, 0.96, DesertPalette.METAL, false)


static func build_visitor_node(shirt_col: Color, hat_col: Color) -> Node3D:
	var kit := MeshKit.new()
	var leg_col := Color("475769")
	var skin_col := Color("ebc09b")
	kit.add_box(0, 0.0, -0.08, 0.13, 0.10, 0.12, DesertPalette.WOOD_DARK)
	kit.add_box(0, 0.0, 0.08, 0.13, 0.10, 0.12, DesertPalette.WOOD_DARK)
	kit.add_box(0, 0.10, -0.08, 0.12, 0.25, 0.11, leg_col)
	kit.add_box(0, 0.10, 0.08, 0.12, 0.25, 0.11, leg_col)
	kit.add_box(0, 0.34, 0, 0.24, 0.42, 0.32, shirt_col)
	kit.add_box(0, 0.38, -0.21, 0.10, 0.30, 0.09, skin_col)
	kit.add_box(0, 0.38, 0.21, 0.10, 0.30, 0.09, skin_col)
	kit.add_box(-0.18, 0.40, 0, 0.12, 0.32, 0.24, DesertPalette.WOOD_LIGHT)
	kit.add_box(-0.18, 0.66, 0, 0.10, 0.09, 0.26, DesertPalette.TERRACOTTA)
	kit.add_box(0, 0.76, 0, 0.24, 0.25, 0.24, skin_col)
	kit.add_flush_rect_x(0.12, 0.90, 0, 0.18, 0.06, DesertPalette.ASPHALT, true)
	kit.add_box(0, 1.01, 0, 0.42, 0.06, 0.42, hat_col)
	kit.add_box(0, 1.07, 0, 0.24, 0.10, 0.24, hat_col)
	return kit.build_node("Visitor", true)


static func add_vendor_character(kit: MeshKit, local_pos: Vector3, anim_time: float) -> void:
	var bob := absf(sin(anim_time * 3.5)) * 0.04
	var wave := sin(anim_time * 3.5) * 0.06
	kit.push_tx(local_pos + Vector3(0, bob, 0), 0.0)
	kit.add_box(-0.08, 0.0, 0, 0.12, 0.26, 0.14, Color("475769"))
	kit.add_box(0.08, 0.0, 0, 0.12, 0.26, 0.14, Color("475769"))
	kit.add_box(0, 0.24, 0, 0.40, 0.52, 0.30, DesertPalette.TERRACOTTA)
	kit.add_flush_rect_z(0, 0.44, 0.15, 0.28, 0.42, DesertPalette.CREAM, true)
	var skin := Color("e7ba93")
	kit.add_box(-0.25, 0.36 + wave, 0.04, 0.10, 0.28, 0.10, skin)
	kit.add_box(0.25, 0.36 - wave, 0.04, 0.10, 0.28, 0.10, skin)
	kit.add_box(0, 0.76, 0, 0.30, 0.30, 0.30, skin)
	kit.add_box(0, 1.04, 0, 0.60, 0.07, 0.60, DesertPalette.SAND)
	kit.add_box(0, 1.11, 0, 0.34, 0.05, 0.34, DesertPalette.AWNING_RED)
	kit.add_box(0, 1.16, 0, 0.32, 0.13, 0.32, DesertPalette.SAND_DARK)
	kit.pop_tx()


static func build_crew_node(crew_kind: int) -> Node3D:
	var kit := MeshKit.new()
	var spec: Dictionary = GameCatalog.OUTPOST_CREW.get(crew_kind, GameCatalog.OUTPOST_CREW[GameCatalog.CrewKind.GRID_TECH])
	var shirt: Color = spec["shirt"]
	var hat: Color = spec["hat"]
	var skin := Color("ebc09b")
	var pants := Color("3b4a5c") if crew_kind != GameCatalog.CrewKind.PUMP_ENGINEER else Color("2b5a78")
	# Boots & legs
	kit.add_box(0, 0.0, -0.09, 0.14, 0.11, 0.13, DesertPalette.WOOD_DARK)
	kit.add_box(0, 0.0, 0.09, 0.14, 0.11, 0.13, DesertPalette.WOOD_DARK)
	kit.add_box(0, 0.11, -0.09, 0.13, 0.26, 0.12, pants)
	kit.add_box(0, 0.11, 0.09, 0.13, 0.26, 0.12, pants)
	# Torso & safety/utility vest
	kit.add_box(0, 0.37, 0, 0.27, 0.44, 0.36, shirt)
	if crew_kind == GameCatalog.CrewKind.GRID_TECH:
		kit.add_box(0, 0.50, 0, 0.29, 0.08, 0.38, DesertPalette.CREAM)
	# Arms & head
	kit.add_box(0, 0.40, -0.23, 0.11, 0.31, 0.10, skin)
	kit.add_box(0, 0.40, 0.23, 0.11, 0.31, 0.10, skin)
	kit.add_box(0, 0.81, 0, 0.25, 0.26, 0.25, skin)
	# Hardhat / cap
	kit.add_box(0, 1.06, 0, 0.34, 0.06, 0.34, hat)
	kit.add_box(0, 1.12, 0, 0.28, 0.12, 0.28, hat)
	# Role-distinct handheld / backpack prop
	if crew_kind == GameCatalog.CrewKind.GRID_TECH:
		kit.add_box(-0.18, 0.42, 0, 0.14, 0.32, 0.26, DesertPalette.METAL_DARK)
		kit.add_box(0.18, 0.42, 0.23, 0.24, 0.08, 0.08, DesertPalette.GOLD)
	elif crew_kind == GameCatalog.CrewKind.PUMP_ENGINEER:
		kit.add_box(-0.18, 0.44, 0, 0.14, 0.30, 0.24, DesertPalette.TERRACOTTA)
		kit.add_box(0.20, 0.42, 0.23, 0.30, 0.09, 0.09, DesertPalette.METAL)
	else:
		# Logistics Runner carrying a wooden supply crate in front!
		kit.add_box(0.28, 0.44, 0, 0.30, 0.26, 0.34, DesertPalette.WOOD_LIGHT)
		kit.add_box(0.28, 0.56, 0, 0.32, 0.04, 0.36, DesertPalette.GOLD)
	return kit.build_node("Crew_%d" % crew_kind, true)


static func build_store_staff_node(role_spec: Dictionary) -> Node3D:
	var kit := MeshKit.new()
	var shirt: Color = role_spec.get("shirt", DesertPalette.TURQUOISE)
	var hat: Color = role_spec.get("hat", DesertPalette.CREAM)
	var skin := Color("e7ba93")
	kit.add_box(-0.08, 0.0, 0, 0.12, 0.28, 0.12, Color("475769"))
	kit.add_box(0.08, 0.0, 0, 0.12, 0.28, 0.12, Color("475769"))
	kit.add_box(0, 0.28, 0, 0.34, 0.44, 0.24, shirt)
	kit.add_flush_rect_z(0, 0.46, 0.125, 0.22, 0.32, DesertPalette.CREAM, true)
	kit.add_box(-0.22, 0.36, 0, 0.09, 0.28, 0.09, skin)
	kit.add_box(0.22, 0.36, 0, 0.09, 0.28, 0.09, skin)
	kit.add_box(0, 0.72, 0, 0.24, 0.25, 0.24, skin)
	kit.add_box(0, 0.96, 0, 0.42, 0.06, 0.42, hat)
	kit.add_box(0, 1.02, 0, 0.24, 0.10, 0.24, hat)
	return kit.build_node("StoreStaff", true)

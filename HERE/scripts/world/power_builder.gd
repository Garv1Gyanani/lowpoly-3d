class_name PowerBuilder
extends RefCounted

## Procedural low-poly 3D builders for Desert Outpost Phase 1 Power assets:
## Windmills (with animated Rotor child), Solar Array Farms, Diesel Generators,
## Battery Banks (with live SOC LED bar), Rooftop Solar Panels, Wood Poles,
## Steel Transmission Towers, and sagging overhead power wires.

const SOLAR_CELL_DARK := Color("203a58")
const SOLAR_CELL_LIGHT := Color("2d537a")
const SOLAR_FRAME := Color("d5dce0")
const GEN_OCHRE := Color("d49830")
const BATTERY_BODY := Color("d7ccb8")


static func build_utility_node(kind: int, meta: Dictionary = {}, material_override: Material = null) -> Node3D:
	if kind >= GameCatalog.UtilityKind.WATER_WELL:
		return SupplyBuilder.build_utility_node(kind, meta, material_override)
	var root := Node3D.new()
	root.name = "Utility_%d" % kind
	var kit := MeshKit.new()
	var cast_sh := material_override == null

	match kind:
		GameCatalog.UtilityKind.WINDMILL:
			_add_windmill_base(kit)
			root.add_child(kit.build_node("Mast", cast_sh, material_override))
			var rotor := _build_windmill_rotor(material_override)
			rotor.name = "Rotor"
			rotor.position = Vector3(0.0, 5.05, 0.42)
			root.add_child(rotor)
			return root
		GameCatalog.UtilityKind.SOLAR_ARRAY:
			_add_solar_array(kit)
		GameCatalog.UtilityKind.DIESEL_GEN:
			_add_diesel_gen(kit)
		GameCatalog.UtilityKind.BATTERY_BANK:
			var cap := float(GameCatalog.UTILITIES[GameCatalog.UtilityKind.BATTERY_BANK]["battery_kwh"])
			var soc := clampf(float(meta.get("stored_kwh", cap * 0.65)) / maxf(1.0, cap), 0.0, 1.0)
			_add_battery_bank(kit, soc)

	root.add_child(kit.build_node("Body", cast_sh, material_override))
	return root


static func _add_windmill_base(kit: MeshKit) -> void:
	# Concrete foundation pad (2x2 footprint = 4x4m)
	kit.add_box(0, 0, 0, 2.6, 0.22, 2.6, DesertPalette.CONCRETE)
	kit.add_frustum(0, 0.22, 0, 0.56, 0.56, 0.40, 0.40, 0.42, 8, DesertPalette.METAL)
	# Tapered white/cream turbine tower
	kit.add_frustum(0, 0.62, 0, 0.34, 0.34, 0.16, 0.16, 4.35, 8, DesertPalette.CREAM, DesertPalette.CREAM_DARK)
	# Red/terracotta aviation stripe near top
	kit.add_frustum(0, 3.85, 0, 0.22, 0.22, 0.19, 0.19, 0.42, 8, DesertPalette.AWNING_RED)
	# Nacelle housing + tail vane
	kit.add_box(0, 4.86, -0.08, 0.52, 0.44, 1.05, DesertPalette.CREAM)
	kit.add_box(0, 5.00, -0.68, 0.08, 0.42, 0.48, DesertPalette.TURQUOISE)
	# Small transformer box at base
	kit.add_box(0.86, 0.22, 0.68, 0.58, 0.62, 0.48, DesertPalette.METAL_DARK)
	kit.add_box(0.86, 0.84, 0.68, 0.14, 0.12, 0.14, DesertPalette.GOLD, Color(-1, 0, 0), 1)


static func _build_windmill_rotor(material_override: Material = null) -> Node3D:
	var kit := MeshKit.new()
	# Hub spinner
	kit.add_frustum(0, -0.14, 0, 0.16, 0.16, 0.08, 0.08, 0.28, 6, DesertPalette.TURQUOISE)
	# 3 blades oriented in XY plane (rotated around Z)
	for i in range(3):
		var ang := float(i) * (TAU / 3.0)
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var p0 := Vector3(dir.x * 0.14 - perp.x * 0.11, dir.y * 0.14 - perp.y * 0.11, 0.04)
		var p1 := Vector3(dir.x * 0.14 + perp.x * 0.11, dir.y * 0.14 + perp.y * 0.11, 0.04)
		var p2 := Vector3(dir.x * 1.92 + perp.x * 0.05, dir.y * 1.92 + perp.y * 0.05, 0.02)
		var p3 := Vector3(dir.x * 1.92 - perp.x * 0.05, dir.y * 1.92 - perp.y * 0.05, 0.02)
		kit.add_quad(p0, p1, p2, p3, DesertPalette.CREAM, true)
		var tip0 := Vector3(dir.x * 1.55 - perp.x * 0.06, dir.y * 1.55 - perp.y * 0.06, 0.03)
		var tip1 := Vector3(dir.x * 1.55 + perp.x * 0.06, dir.y * 1.55 + perp.y * 0.06, 0.03)
		var tip2 := Vector3(dir.x * 1.94 + perp.x * 0.04, dir.y * 1.94 + perp.y * 0.04, 0.03)
		var tip3 := Vector3(dir.x * 1.94 - perp.x * 0.04, dir.y * 1.94 - perp.y * 0.04, 0.03)
		kit.add_quad(tip0, tip1, tip2, tip3, DesertPalette.AWNING_RED, true)
	return kit.build_node("RotorMesh", material_override == null, material_override)


static func _add_solar_array(kit: MeshKit) -> void:
	# 3x3 footprint = 6x6m gravel/concrete yard
	kit.add_ground_rect(0, 0.022, 0, 5.5, 5.5, Color("9c8c78"))
	kit.add_box(0, 0, 0, 5.2, 0.12, 5.2, DesertPalette.CONCRETE)
	# 2 rows of 3 tilted solar panel modules
	for rz in [-1.25, 1.15]:
		for rx in [-1.62, 0.0, 1.62]:
			kit.add_box(rx, 0.12, rz - 0.18, 0.14, 0.96, 0.14, DesertPalette.METAL_DARK)
			kit.add_box(rx, 0.12, rz + 0.35, 0.14, 0.52, 0.14, DesertPalette.METAL_DARK)
			_add_tilted_solar_panel(kit, Vector3(rx, 0.85, rz + 0.08), 1.42, 1.42, 0.34)
	# Inverter cabinet at corner
	kit.add_box(2.15, 0.12, -2.05, 0.62, 1.15, 0.56, DesertPalette.CREAM_DARK)
	kit.add_box(2.15, 1.27, -2.05, 0.66, 0.08, 0.60, DesertPalette.METAL_DARK)
	kit.add_box(2.15, 0.96, -1.75, 0.24, 0.12, 0.06, DesertPalette.NEON_TURQUOISE, Color(-1, 0, 0), 1)


static func _add_diesel_gen(kit: MeshKit) -> void:
	# 2x2 footprint = 4x4m
	kit.add_box(0, 0, 0, 3.4, 0.20, 3.2, DesertPalette.CONCRETE)
	# Generator enclosure
	kit.add_box(-0.18, 0.20, -0.10, 2.35, 1.38, 1.48, GEN_OCHRE, Color(-1, 0, 0), 0, true, true)
	kit.add_box(-0.18, 1.58, -0.10, 2.42, 0.12, 1.56, DesertPalette.METAL_DARK)
	# Dark radiator grille & vents
	kit.add_flush_rect_z(-0.18, 0.90, 0.65, 1.72, 0.72, DesertPalette.METAL_DARK, true)
	kit.add_flush_rect_z(-0.18, 0.90, 0.67, 1.52, 0.10, DesertPalette.METAL, true)
	kit.add_flush_rect_z(-0.18, 0.68, 0.67, 1.52, 0.10, DesertPalette.METAL, true)
	kit.add_flush_rect_z(-0.18, 1.12, 0.67, 1.52, 0.10, DesertPalette.METAL, true)
	# Tall exhaust muffler pipe
	kit.add_frustum(-1.05, 1.66, -0.45, 0.12, 0.12, 0.10, 0.10, 1.15, 6, DesertPalette.METAL_DARK)
	kit.add_frustum(-1.05, 2.80, -0.45, 0.14, 0.14, 0.14, 0.14, 0.12, 6, DesertPalette.METAL)
	# Red/rust fuel drums beside enclosure
	for dz in [-0.46, 0.34]:
		kit.add_frustum(1.26, 0.20, dz, 0.30, 0.30, 0.30, 0.30, 0.92, 8, DesertPalette.AWNING_RED, DesertPalette.SANDSTONE_DARK)
	# Status beacon
	kit.add_box(0.72, 1.70, 0.42, 0.16, 0.18, 0.16, DesertPalette.GOLD, Color(-1, 0, 0), 1)


static func _add_battery_bank(kit: MeshKit, soc: float) -> void:
	# 2x2 footprint = 4x4m
	kit.add_box(0, 0, 0, 3.4, 0.20, 3.2, DesertPalette.CONCRETE)
	# Twin industrial battery packs
	for bx in [-0.80, 0.80]:
		kit.add_box(bx, 0.20, -0.12, 1.25, 1.65, 1.62, BATTERY_BODY, Color(-1, 0, 0), 0, true, true)
		kit.add_box(bx, 1.85, -0.12, 1.32, 0.12, 1.68, DesertPalette.METAL_DARK)
		kit.add_box(bx, 0.20, 0.71, 0.98, 1.32, 0.06, DesertPalette.METAL_DARK)
	# Glowing vertical SOC LED strips (teal > 60%, gold 25..60%, coral < 25%)
	var led_col := DesertPalette.NEON_TURQUOISE if soc >= 0.60 else (DesertPalette.GOLD if soc >= 0.25 else DesertPalette.NEON_CORAL)
	var bar_h := maxf(0.14, 1.10 * soc)
	for bx in [-0.80, 0.80]:
		kit.add_box(bx, 0.32, 0.76, 0.24, bar_h, 0.06, led_col, Color(-1, 0, 0), 2)
	# Top copper busbar linking the twin packs
	kit.add_box(0, 1.97, -0.12, 1.85, 0.10, 0.22, DesertPalette.TERRACOTTA)


static func _add_tilted_solar_panel(kit: MeshKit, center: Vector3, w: float, d: float, tilt_drop: float) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var y_back := center.y + tilt_drop * 0.5
	var y_front := center.y - tilt_drop * 0.5
	# Outer silver frame
	var f0 := Vector3(center.x - hw, y_back, center.z - hd)
	var f1 := Vector3(center.x + hw, y_back, center.z - hd)
	var f2 := Vector3(center.x + hw, y_front, center.z + hd)
	var f3 := Vector3(center.x - hw, y_front, center.z + hd)
	kit.add_quad(f0, f1, f2, f3, SOLAR_FRAME, true)
	# Inner photovoltaic cells (slightly raised)
	var ihw := hw - 0.07
	var ihd := hd - 0.07
	var c0 := Vector3(center.x - ihw, y_back + 0.025, center.z - ihd)
	var c1 := Vector3(center.x + ihw, y_back + 0.025, center.z - ihd)
	var c2 := Vector3(center.x + ihw, y_front + 0.025, center.z + ihd)
	var c3 := Vector3(center.x - ihw, y_front + 0.025, center.z + ihd)
	kit.add_quad(c0, c1, c2, c3, SOLAR_CELL_DARK, true)
	# Subtle center grid highlight stripe
	var m0 := Vector3(center.x - ihw, (y_back + y_front) * 0.5 + 0.032, center.z - 0.03)
	var m1 := Vector3(center.x + ihw, (y_back + y_front) * 0.5 + 0.032, center.z - 0.03)
	var m2 := Vector3(center.x + ihw, (y_back + y_front) * 0.5 + 0.032, center.z + 0.03)
	var m3 := Vector3(center.x - ihw, (y_back + y_front) * 0.5 + 0.032, center.z + 0.03)
	kit.add_quad(m0, m1, m2, m3, SOLAR_CELL_LIGHT, true)


static func add_rooftop_solar(kit: MeshKit, btype: int, level: int) -> void:
	match btype:
		GameCatalog.BusinessType.CONVENIENCE_STORE:
			_add_tilted_solar_panel(kit, Vector3(-0.75, 2.96, -0.35), 1.35, 1.15, 0.24)
			_add_tilted_solar_panel(kit, Vector3(0.75, 2.96, -0.35), 1.35, 1.15, 0.24)
		GameCatalog.BusinessType.FOOD_STAND:
			_add_tilted_solar_panel(kit, Vector3(-0.68, 2.55, -0.22), 1.10, 0.95, 0.20)
			_add_tilted_solar_panel(kit, Vector3(0.68, 2.55, -0.22), 1.10, 0.95, 0.20)
		GameCatalog.BusinessType.DESERT_DINER:
			_add_tilted_solar_panel(kit, Vector3(-0.68, 3.24, -0.58), 1.25, 1.05, 0.22)
			_add_tilted_solar_panel(kit, Vector3(0.68, 3.24, -0.58), 1.25, 1.05, 0.22)
		GameCatalog.BusinessType.GAS_STATION:
			# Mounted cleanly along top of the iconic fuel canopy!
			_add_tilted_solar_panel(kit, Vector3(-1.35, 3.28, 1.05), 1.25, 1.30, 0.24)
			_add_tilted_solar_panel(kit, Vector3(0.0, 3.28, 1.05), 1.25, 1.30, 0.24)
			_add_tilted_solar_panel(kit, Vector3(1.35, 3.28, 1.05), 1.25, 1.30, 0.24)
		GameCatalog.BusinessType.DESERT_MOTEL:
			var roof_y := 4.46 if level >= 2 else 2.60
			_add_tilted_solar_panel(kit, Vector3(-0.60, roof_y, -0.70), 1.45, 1.15, 0.24)
			_add_tilted_solar_panel(kit, Vector3(1.05, roof_y, -0.70), 1.45, 1.15, 0.24)
		GameCatalog.BusinessType.LOOKOUT_CAMP:
			_add_tilted_solar_panel(kit, Vector3(-1.50, 2.24, -0.70), 1.75, 1.10, 0.24)


static func build_power_lines_node(state) -> Node3D:
	var kit := MeshKit.new()
	var has_geo := false

	for cell: Vector2i in state.world_grid.power_poles.keys():
		has_geo = true
		var meta: Dictionary = state.world_grid.power_poles[cell]
		var pkind: int = int(meta.get("kind", GameCatalog.PowerLineKind.WOOD_POLE))
		var wc := OutpostLayout.cell_center_v(cell)
		if pkind == GameCatalog.PowerLineKind.STEEL_TOWER:
			_add_steel_tower(kit, wc)
		else:
			_add_wood_pole(kit, wc)

	var wire_col := Color("43352c")
	for sp in state.power_network.overhead_spans:
		has_geo = true
		var a: Vector3 = sp["a"]
		var b: Vector3 = sp["b"]
		var dist := a.distance_to(b)
		var sag := clampf(dist * 0.042, 0.14, 0.72)
		var is_tower := bool(sp.get("is_tower", false))
		var r := 0.036 if is_tower else 0.028
		kit.add_sagging_wire(a, b, wire_col, sag, r, 6)
		if is_tower:
			var side := (b - a).cross(Vector3.UP).normalized() * 0.55
			kit.add_sagging_wire(a + side, b + side, wire_col, sag * 1.05, r * 0.85, 5)
			kit.add_sagging_wire(a - side, b - side, wire_col, sag * 1.05, r * 0.85, 5)

	if not has_geo:
		var empty := Node3D.new()
		empty.name = "PowerLinesEmpty"
		return empty
	return kit.build_node("PowerLines", true)


static func _add_wood_pole(kit: MeshKit, pos: Vector3) -> void:
	kit.add_box(pos.x, 0.0, pos.z, 0.22, 3.65, 0.22, DesertPalette.WOOD_DARK)
	kit.add_box(pos.x, 3.22, pos.z, 1.15, 0.14, 0.14, DesertPalette.WOOD)
	kit.add_box(pos.x - 0.44, 3.36, pos.z, 0.09, 0.14, 0.09, DesertPalette.CREAM)
	kit.add_box(pos.x + 0.44, 3.36, pos.z, 0.09, 0.14, 0.09, DesertPalette.CREAM)
	kit.add_box(pos.x, 3.36, pos.z, 0.09, 0.14, 0.09, DesertPalette.TURQUOISE)


static func _add_steel_tower(kit: MeshKit, pos: Vector3) -> void:
	# Concrete footing
	kit.add_box(pos.x, 0.0, pos.z, 1.15, 0.22, 1.15, DesertPalette.CONCRETE)
	# 4 angled steel lattice legs
	for lx in [-0.36, 0.36]:
		for lz in [-0.36, 0.36]:
			kit.add_box(pos.x + lx * 0.72, 0.22, pos.z + lz * 0.72, 0.11, 5.45, 0.11, DesertPalette.METAL)
	# Horizontal braces
	for hy in [1.4, 2.8, 4.2, 5.2]:
		var w := lerpf(0.84, 0.56, hy / 5.5)
		kit.add_box(pos.x, hy, pos.z, w, 0.10, w, DesertPalette.METAL_DARK)
	# Wide twin cross-arms & turquoise insulators
	kit.add_box(pos.x, 5.35, pos.z, 1.95, 0.14, 0.18, DesertPalette.METAL)
	kit.add_box(pos.x, 4.65, pos.z, 1.45, 0.12, 0.16, DesertPalette.METAL)
	for ix in [-0.82, 0.0, 0.82]:
		kit.add_box(pos.x + ix, 5.48, pos.z, 0.11, 0.18, 0.11, DesertPalette.NEON_TURQUOISE, Color(-1, 0, 0), 1)

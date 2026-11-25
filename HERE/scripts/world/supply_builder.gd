class_name SupplyBuilder
extends RefCounted

## Procedural low-poly 3D builders for Phase 2 Water & Supply Chain structures:
## Water Well, Pressurized Water Tower, Freight Supply Depot, Oil Pumpjack (with animated Beam),
## Mini Fuel Refinery, Desert Greenhouse, and Desert Craft Workshop.

const GLASS_GREEN := Color("69b8b4")
const CRUDE_BLACK := Color("28242e")
const REFINERY_SILVER := Color("c2c9cc")


static func build_utility_node(kind: int, _meta: Dictionary = {}, material_override: Material = null) -> Node3D:
	var root := Node3D.new()
	root.name = "SupplyUtility_%d" % kind
	var kit := MeshKit.new()
	var cast_sh := material_override == null

	match kind:
		GameCatalog.UtilityKind.WATER_WELL:
			_add_water_well(kit)
		GameCatalog.UtilityKind.WATER_TOWER:
			_add_water_tower(kit)
		GameCatalog.UtilityKind.FREIGHT_DEPOT:
			_add_freight_depot(kit)
		GameCatalog.UtilityKind.OIL_PUMPJACK:
			_add_oil_pumpjack_base(kit)
			root.add_child(kit.build_node("Frame", cast_sh, material_override))
			var beam := _build_pumpjack_beam(material_override)
			beam.name = "Beam"
			beam.position = Vector3(0.0, 2.45, 0.0)
			root.add_child(beam)
			return root
		GameCatalog.UtilityKind.MINI_REFINERY:
			_add_mini_refinery(kit)
		GameCatalog.UtilityKind.DESERT_GREENHOUSE:
			_add_desert_greenhouse(kit)
		GameCatalog.UtilityKind.CRAFT_WORKSHOP:
			_add_craft_workshop(kit)

	root.add_child(kit.build_node("Body", cast_sh, material_override))
	return root


static func _add_water_well(kit: MeshKit) -> void:
	kit.add_box(0, 0, 0, 3.3, 0.18, 3.3, DesertPalette.CONCRETE)
	# Circular stone wellhead + water glint
	kit.add_frustum(-0.55, 0.18, 0.25, 0.72, 0.72, 0.68, 0.68, 0.74, 8, DesertPalette.SANDSTONE, DesertPalette.SANDSTONE_LIGHT)
	kit.add_frustum(-0.55, 0.88, 0.25, 0.56, 0.56, 0.56, 0.56, 0.06, 8, DesertPalette.WATER)
	# Timber pump gantry over well
	for px in [-1.10, 0.0]:
		kit.add_box(px, 0.18, 0.25, 0.14, 2.15, 0.14, DesertPalette.WOOD_DARK)
	kit.add_box(-0.55, 2.28, 0.25, 1.38, 0.16, 0.28, DesertPalette.TERRACOTTA)
	kit.add_box(-0.55, 0.90, 0.25, 0.10, 1.35, 0.10, DesertPalette.METAL_DARK)
	# Blue pressure tank & electric pump motor
	kit.add_frustum(0.88, 0.18, -0.35, 0.54, 0.54, 0.54, 0.54, 1.48, 8, DesertPalette.WATER, Color("3c8da1"))
	kit.add_frustum(0.88, 1.66, -0.35, 0.54, 0.54, 0.22, 0.22, 0.22, 8, Color("3c8da1"))
	kit.add_box(0.88, 0.18, 0.68, 0.62, 0.55, 0.52, DesertPalette.METAL_DARK)
	kit.add_box(0.88, 0.73, 0.68, 0.16, 0.12, 0.16, DesertPalette.NEON_TURQUOISE, Color(-1, 0, 0), 1)


static func _add_water_tower(kit: MeshKit) -> void:
	kit.add_box(0, 0, 0, 3.2, 0.18, 3.2, DesertPalette.CONCRETE)
	for lx in [-0.88, 0.88]:
		for lz in [-0.88, 0.88]:
			kit.add_box(lx, 0.18, lz, 0.18, 3.25, 0.18, DesertPalette.WOOD_DARK, Color(-1, 0, 0), 0, true, true)
	kit.add_box(0, 1.25, 0.88, 1.85, 0.10, 0.10, DesertPalette.WOOD)
	kit.add_box(0, 2.35, -0.88, 1.85, 0.10, 0.10, DesertPalette.WOOD)
	kit.add_frustum(0, 0.18, 0, 0.22, 0.22, 0.22, 0.22, 3.30, 8, DesertPalette.METAL)
	# Platform deck & wood-stave barrel tank
	kit.add_box(0, 3.40, 0, 2.45, 0.18, 2.45, DesertPalette.WOOD_LIGHT)
	kit.add_frustum(0, 3.58, 0, 1.05, 1.05, 1.02, 1.02, 1.75, 10, DesertPalette.WOOD, DesertPalette.WOOD_LIGHT)
	for hy in [3.95, 4.45, 4.95]:
		kit.add_frustum(0, hy, 0, 1.08, 1.08, 1.08, 1.08, 0.08, 10, DesertPalette.METAL_DARK)
	kit.add_frustum(0, 5.33, 0, 1.22, 1.22, 0.10, 0.10, 0.78, 10, DesertPalette.TERRACOTTA, DesertPalette.SANDSTONE_DARK)
	kit.add_box(0, 6.10, 0, 0.12, 0.28, 0.12, DesertPalette.WATER, Color(-1, 0, 0), 1)


static func _add_freight_depot(kit: MeshKit) -> void:
	# 3x2 footprint = 6x4m
	kit.add_box(0, 0, 0, 5.5, 0.24, 3.6, DesertPalette.CONCRETE)
	# Main corrugated warehouse bay
	kit.add_box(-0.75, 0.24, -0.35, 3.65, 2.15, 2.45, DesertPalette.CREAM_DARK, Color(-1, 0, 0), 0, true, true)
	kit.add_box(-0.75, 2.39, -0.35, 3.85, 0.22, 2.65, DesertPalette.TERRACOTTA)
	# Roll-up loading bay doors
	for dx in [-1.55, 0.05]:
		kit.add_flush_rect_z(dx, 1.15, 0.89, 1.18, 1.48, DesertPalette.METAL, true)
		kit.add_flush_rect_z(dx, 1.50, 0.91, 1.12, 0.06, DesertPalette.METAL_DARK, true)
		kit.add_flush_rect_z(dx, 1.05, 0.91, 1.12, 0.06, DesertPalette.METAL_DARK, true)
	kit.add_sloped_awning(-0.75, 2.25, 1.98, 1.25, 3.70, 0.92, DesertPalette.TURQUOISE, DesertPalette.CREAM, 6)
	# Outdoor pallet & crate yard on right side
	kit.add_box(1.85, 0.24, 0.25, 1.15, 0.10, 1.15, DesertPalette.WOOD_DARK)
	kit.add_box(1.62, 0.34, 0.10, 0.56, 0.52, 0.52, DesertPalette.WOOD_LIGHT)
	kit.add_box(2.15, 0.34, 0.35, 0.52, 0.48, 0.52, DesertPalette.GOLD)
	kit.add_box(1.82, 0.86, 0.18, 0.50, 0.44, 0.48, DesertPalette.TERRACOTTA)
	kit.add_marquee_sign(-0.75, 2.62, 0.78, 2.40, 0.58, "DEPOT", DesertPalette.WOOD_DARK, DesertPalette.CREAM, DesertPalette.UI_INK, 0.16)


static func _add_oil_pumpjack_base(kit: MeshKit) -> void:
	# 2x2 footprint = 4x4m
	kit.add_ground_rect(0, 0.022, 0, 3.6, 3.6, CRUDE_BLACK)
	kit.add_box(0, 0, 0, 3.2, 0.20, 2.6, DesertPalette.CONCRETE)
	# Wellhead pipe on front (+X)
	kit.add_frustum(1.18, 0.20, 0, 0.22, 0.22, 0.18, 0.18, 1.15, 8, DesertPalette.METAL_DARK)
	kit.add_box(1.18, 1.35, 0, 0.34, 0.16, 0.34, DesertPalette.AWNING_RED)
	# Steel Samson A-frame tripod
	for lz in [-0.45, 0.45]:
		kit.add_box(-0.35, 0.20, lz, 0.16, 2.25, 0.16, DesertPalette.METAL_DARK)
		kit.add_box(0.35, 0.20, lz, 0.16, 2.25, 0.16, DesertPalette.METAL_DARK)
	kit.add_box(0, 2.32, 0, 0.92, 0.18, 1.12, DesertPalette.METAL)
	# Rear electric drive motor & crank box
	kit.add_box(-1.05, 0.20, 0, 0.78, 0.88, 0.92, DesertPalette.GOLD)
	kit.add_box(-1.05, 1.08, 0, 0.18, 0.14, 0.18, DesertPalette.AWNING_RED, Color(-1, 0, 0), 1)


static func _build_pumpjack_beam(material_override: Material = null) -> Node3D:
	var kit := MeshKit.new()
	# Walking beam spanning -1.25 to +1.25 along X
	kit.add_box(0, 0, 0, 2.55, 0.24, 0.28, DesertPalette.AWNING_RED)
	# Iconic curved horsehead on +X side
	kit.add_box(1.22, -0.45, 0, 0.38, 1.12, 0.36, DesertPalette.METAL_DARK)
	kit.add_box(1.22, 0.15, 0, 0.42, 0.26, 0.40, DesertPalette.GOLD)
	# Counterweight pitman arm on -X side
	kit.add_box(-1.15, -0.35, 0, 0.48, 0.72, 0.56, DesertPalette.METAL)
	return kit.build_node("BeamMesh", material_override == null, material_override)


static func _add_mini_refinery(kit: MeshKit) -> void:
	# 3x2 footprint = 6x4m
	kit.add_box(0, 0, 0, 5.5, 0.22, 3.6, DesertPalette.CONCRETE)
	# Twin silver distillation columns
	kit.add_frustum(-1.65, 0.22, -0.45, 0.58, 0.58, 0.52, 0.52, 3.45, 10, REFINERY_SILVER, DesertPalette.METAL)
	kit.add_frustum(-1.65, 3.67, -0.45, 0.52, 0.52, 0.16, 0.16, 0.35, 10, DesertPalette.METAL_DARK)
	kit.add_frustum(-0.45, 0.22, -0.45, 0.46, 0.46, 0.42, 0.42, 2.65, 10, REFINERY_SILVER, DesertPalette.METAL)
	# Connecting overhead pipes & catwalk
	kit.add_box(-1.05, 2.15, -0.45, 1.45, 0.16, 0.16, DesertPalette.GOLD)
	kit.add_box(-1.05, 1.45, -0.45, 1.45, 0.14, 0.65, DesertPalette.METAL_DARK)
	# Horizontal refined fuel storage tank on right
	kit.add_box(1.45, 0.22, -0.25, 2.15, 0.45, 1.15, DesertPalette.METAL_DARK)
	kit.add_box(1.45, 0.67, -0.25, 2.25, 1.12, 1.28, DesertPalette.CREAM)
	kit.add_flush_rect_z(1.45, 1.22, 0.40, 1.95, 0.26, DesertPalette.GOLD, true)
	# Control shed & flare stack
	kit.add_box(-0.95, 0.22, 0.88, 1.55, 1.18, 1.10, DesertPalette.METAL)
	kit.add_box(-0.95, 1.40, 0.88, 1.62, 0.10, 1.18, DesertPalette.TERRACOTTA)
	kit.add_box(-0.95, 0.92, 1.44, 0.62, 0.36, 0.06, DesertPalette.NEON_WARM, Color(-1, 0, 0), 1)


static func _add_desert_greenhouse(kit: MeshKit) -> void:
	# 3x2 footprint = 6x4m
	kit.add_box(0, 0, 0, 5.4, 0.20, 3.6, DesertPalette.CONCRETE)
	# Warm adobe low walls
	kit.add_box(0, 0.20, 0, 4.95, 0.68, 3.15, DesertPalette.SANDSTONE_LIGHT, Color(-1, 0, 0), 0, true, true)
	# Translucent-style glasshouse body + gable roof ribs
	kit.add_box(0, 0.88, 0, 4.80, 1.12, 3.00, GLASS_GREEN)
	kit.add_gable_roof(0, 2.00, 0, 4.96, 0.88, 3.16, Color("8cd4cf"), DesertPalette.CREAM)
	# White structural frame ribs
	for rx in [-2.20, -1.10, 0.0, 1.10, 2.20]:
		kit.add_box(rx, 0.88, 1.52, 0.10, 1.14, 0.08, DesertPalette.CREAM)
		kit.add_box(rx, 0.88, -1.52, 0.10, 1.14, 0.08, DesertPalette.CREAM)
	# Lush raised plant beds outside front entrance
	kit.add_box(-1.55, 0.20, 1.58, 1.25, 0.36, 0.44, DesertPalette.WOOD)
	kit.add_box(-1.55, 0.56, 1.58, 1.10, 0.24, 0.34, DesertPalette.CACTUS)
	kit.add_box(1.55, 0.20, 1.58, 1.25, 0.36, 0.44, DesertPalette.WOOD)
	kit.add_box(1.55, 0.56, 1.58, 1.10, 0.24, 0.34, DesertPalette.VEGETATION)


static func _add_craft_workshop(kit: MeshKit) -> void:
	# 2x2 footprint = 4x4m
	kit.add_box(0, 0, 0, 3.5, 0.18, 3.5, DesertPalette.CREAM_DARK)
	# Adobe workshop room
	kit.add_box(-0.35, 0.18, -0.35, 2.45, 1.95, 2.25, DesertPalette.TERRACOTTA, Color(-1, 0, 0), 0, true, true)
	kit.add_adobe_parapet_roof(-0.35, 2.13, -0.35, 2.48, 2.28, 0.26, DesertPalette.SANDSTONE)
	kit.add_framed_door(-0.35, 0.18, 0.78, 0.72, 1.36)
	# Beehive clay pottery kiln beside studio
	kit.add_frustum(1.18, 0.18, -0.25, 0.56, 0.56, 0.34, 0.34, 1.15, 8, DesertPalette.SANDSTONE_LIGHT, DesertPalette.CREAM_DARK)
	kit.add_frustum(1.18, 1.33, -0.25, 0.24, 0.24, 0.18, 0.18, 0.32, 8, DesertPalette.SANDSTONE_DARK)
	kit.add_box(1.18, 0.45, 0.24, 0.28, 0.32, 0.12, Color("ff8c32"), Color(-1, 0, 0), 2)
	# Display bench with colorful painted pottery
	kit.add_box(0.55, 0.18, 1.15, 1.45, 0.48, 0.46, DesertPalette.WOOD_LIGHT)
	kit.add_frustum(0.15, 0.66, 1.15, 0.16, 0.16, 0.12, 0.12, 0.30, 6, DesertPalette.TURQUOISE)
	kit.add_frustum(0.55, 0.66, 1.15, 0.18, 0.18, 0.10, 0.10, 0.36, 6, DesertPalette.GOLD)
	kit.add_frustum(0.95, 0.66, 1.15, 0.15, 0.15, 0.14, 0.14, 0.26, 6, DesertPalette.AWNING_RED)

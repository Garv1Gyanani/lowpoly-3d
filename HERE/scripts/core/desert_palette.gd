class_name DesertPalette
extends RefCounted

## Official Desert Outpost color palette & shared materials for Godot 4 Mobile.

# Core desert & fractured red-rock canyon palette (warm peach-sand + rich rose-crimson cliffs + deep plum shade)
const SAND := Color("cc9670")
const SAND_LIGHT := Color("dcab86")
const SAND_DARK := Color("b27e5c")
const ARROYO_SAND := Color("ba8663")
const ARROYO_DARK := Color("9c6b4d")
const SANDSTONE := Color("c64c2c")
const SANDSTONE_DARK := Color("842b22")
const SANDSTONE_LIGHT := Color("e2784a")
const TERRACOTTA := Color("c24727")
const CLIFF_ROSE := Color("d6582e")
const CLIFF_CORAL_TOP := Color("e8844e")
const CLIFF_DEEP := Color("8f3124")
const CLIFF_CREVICE := Color("521f26")
const SLAB_TAUPE := Color("ad492e")
const SLAB_TAUPE_TOP := Color("d66f46")
const DISTANT_CANYON := Color("c49092")
const DISTANT_CANYON_TOP := Color("dab0ac")
const WOOD := Color("79543b")
const WOOD_LIGHT := Color("9a6f4f")
const WOOD_DARK := Color("563a27")
const VEGETATION := Color("657852")
const VEGETATION_DARK := Color("475739")
const CACTUS := Color("547544")
const SKY := Color("bce7ef")
const SKY_HORIZON := Color("edd3c9")
const CREAM := Color("f4ead6")
const CREAM_DARK := Color("dccbb0")

# Monument Valley shadow & atmospheric accents
const SHADOW_PLUM := Color("4c3248")
const SHADOW_CONTACT := Color("332030")
const CLOUD_SUNLIT := Color("fff6ee")
const CLOUD_WARM_BOUNCE := Color("f3cfc2")

# Supporting desert outpost accents
const ASPHALT := Color("454852")
const ASPHALT_SHOULDER := Color("8c7668")
const ROAD_YELLOW := Color("edbe58")
const ROAD_WHITE := Color("ebe4d4")
const CONCRETE := Color("cbbba9")
const AWNING_RED := Color("c9533e")
const TURQUOISE := Color("4b9b95")
const WINDOW_DAY := Color("4c6a7a")
const WINDOW_NIGHT := Color("ffd57e")
const NEON_WARM := Color("ffb657")
const NEON_CORAL := Color("ff7a5a")
const NEON_TURQUOISE := Color("64e2d5")
const METAL := Color("80878b")
const METAL_DARK := Color("4d5358")
const GOLD := Color("f4bf48")
const GOLD_POPUP := Color("ffe082")
const EMERALD_POPUP := Color("8ef5a8")
const WATER := Color("57aebd")

# Handcrafted western HUD tones
const UI_WOOD_FRAME := Color("3e2618")
const UI_WOOD_DEEP := Color("533522")
const UI_WOOD_BODY := Color("744c31")
const UI_WOOD_RIM := Color("a5764c")
const UI_PARCHMENT := Color("f6ecda")
const UI_PARCHMENT_DARK := Color("e7d6b7")
const UI_INK := Color("331e12")
const UI_INK_MUTED := Color("765941")
const UI_GOLD_TOP := Color("f8cc58")
const UI_GOLD_BASE := Color("c88d26")
const UI_GREEN_TOP := Color("64b86b")
const UI_GREEN_BASE := Color("397a41")
const UI_TERRA_TOP := Color("dc6f46")
const UI_TERRA_BASE := Color("a34526")
const UI_STONE_TOP := Color("948a7e")
const UI_STONE_BASE := Color("655d54")

static var _opaque_mat: StandardMaterial3D
static var _unlit_mat: StandardMaterial3D
static var _night_emissive_mat: StandardMaterial3D
static var _always_emissive_mat: StandardMaterial3D
static var _ghost_valid_mat: StandardMaterial3D
static var _ghost_invalid_mat: StandardMaterial3D
static var _display_font: Font
static var _ui_font: Font


static func get_display_font() -> Font:
	if _display_font == null:
		if ResourceLoader.exists("res://assets/fonts/Bungee-Regular.ttf"):
			_display_font = load("res://assets/fonts/Bungee-Regular.ttf")
	return _display_font


static func get_ui_font() -> Font:
	if _ui_font == null:
		if ResourceLoader.exists("res://assets/fonts/Fredoka.ttf"):
			_ui_font = load("res://assets/fonts/Fredoka.ttf")
	return _ui_font


static func get_opaque_material() -> StandardMaterial3D:
	if _opaque_mat == null:
		_opaque_mat = StandardMaterial3D.new()
		_opaque_mat.vertex_color_use_as_albedo = true
		_opaque_mat.roughness = 0.92
		_opaque_mat.metallic = 0.0
		_opaque_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return _opaque_mat


static func get_unlit_material() -> StandardMaterial3D:
	if _unlit_mat == null:
		_unlit_mat = StandardMaterial3D.new()
		_unlit_mat.vertex_color_use_as_albedo = true
		_unlit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_unlit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _unlit_mat


static func get_night_emissive_material() -> StandardMaterial3D:
	if _night_emissive_mat == null:
		_night_emissive_mat = StandardMaterial3D.new()
		_night_emissive_mat.vertex_color_use_as_albedo = true
		_night_emissive_mat.roughness = 0.65
		_night_emissive_mat.emission_enabled = true
		_night_emissive_mat.emission = WINDOW_NIGHT
		_night_emissive_mat.emission_energy_multiplier = 0.0
	return _night_emissive_mat


static func get_always_emissive_material() -> StandardMaterial3D:
	if _always_emissive_mat == null:
		_always_emissive_mat = StandardMaterial3D.new()
		_always_emissive_mat.vertex_color_use_as_albedo = true
		_always_emissive_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_always_emissive_mat.emission_enabled = true
		_always_emissive_mat.emission = Color("ffd57e")
		_always_emissive_mat.emission_energy_multiplier = 1.4
	return _always_emissive_mat


static func get_ghost_material(valid: bool) -> StandardMaterial3D:
	if valid:
		if _ghost_valid_mat == null:
			_ghost_valid_mat = StandardMaterial3D.new()
			_ghost_valid_mat.albedo_color = Color(0.35, 0.85, 0.45, 0.52)
			_ghost_valid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_ghost_valid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_ghost_valid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return _ghost_valid_mat
	else:
		if _ghost_invalid_mat == null:
			_ghost_invalid_mat = StandardMaterial3D.new()
			_ghost_invalid_mat.albedo_color = Color(0.92, 0.34, 0.25, 0.55)
			_ghost_invalid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_ghost_invalid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_ghost_invalid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return _ghost_invalid_mat


static func update_night_glow(night_factor: float, sunset_factor: float) -> void:
	var mat := get_night_emissive_material()
	var glow := clampf(night_factor * 1.65 + sunset_factor * 0.55, 0.0, 1.85)
	mat.emission_energy_multiplier = glow
	mat.emission = WINDOW_DAY.lerp(WINDOW_NIGHT, clampf(glow * 0.85, 0.0, 1.0))
